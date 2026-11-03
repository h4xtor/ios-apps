import Foundation
import CryptoKit

// MARK: - Errors

enum TVError: LocalizedError, Equatable {
    case invalidAddress(String)
    case notPaired
    case unauthorized
    case http(status: Int, path: String, detail: String)
    case transport(String)
    case decoding(String)
    case pairing(String)
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .invalidAddress(let message):      return message
        case .notPaired:                        return "TV'et er ikke parret endnu. Tryk Par TV og indtast PIN-koden fra skærmen."
        case .unauthorized:                     return "TV'et afviste de gemte legitimationsoplysninger. Par TV'et igen."
        case .http(let status, let path, let detail):
            return "TV'et afviste \(path) (HTTP \(status))" + (detail.isEmpty ? "." : ": \(detail)")
        case .transport(let message):           return message
        case .decoding(let message):            return "TV'et sendte uventet data: \(message)"
        case .pairing(let message):             return message
        case .rejected(let message):            return message
        }
    }
}

// MARK: - Client

/// Thin async wrapper around the Philips JointSpace API (v6, 2016+ sets).
/// One actor-free class, one serial gate, one digest challenge at a time.
final class PhilipsTVClient: NSObject, @unchecked Sendable {

    private(set) var address: String
    private(set) var apiVersion: Int

    private let secureSession: URLSession
    private let pacer = Pacer(interval: 0.12)
    private let timeout: TimeInterval = 8

    static let httpPort  = 1925
    static let httpsPort = 1926

    init(address: String, apiVersion: Int = 6) {
        self.address = address
        self.apiVersion = apiVersion

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 15
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil

        self.secureSession = URLSession(
            configuration: configuration,
            delegate: SelfSignedTrust(address: address),
            delegateQueue: nil
        )
        super.init()
    }

    deinit {
        secureSession.invalidateAndCancel()
    }

    // MARK: URL building

    private func url(path: String, secure: Bool) -> URL? {
        let scheme = secure ? "https" : "http"
        let port = secure ? Self.httpsPort : Self.httpPort
        let cleaned = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: "\(scheme)://\(address):\(port)/\(apiVersion)/\(cleaned)")
    }

    // MARK: Core request

    func request(
        _ method: String,
        _ path: String,
        json: [String: Any]? = nil,
        authenticated: Bool = true,
        secure: Bool = true,
        credentials: (username: String, password: String)? = nil,
        retries: Int = 2
    ) async throws -> [String: Any] {

        guard let url = url(path: path, secure: secure) else {
            throw TVError.invalidAddress("Kunne ikke bygge adressen til TV'et.")
        }

        var body: Data?
        if let json {
            body = try JSONSerialization.data(withJSONObject: json, options: [])
        }

        var resolvedCredentials: (username: String, password: String)?
        if authenticated {
            guard let creds = credentials ?? StoredCredentials.shared.credentials(for: address) else {
                throw TVError.notPaired
            }
            resolvedCredentials = creds
        }

        var lastError: Error?

        for attempt in 0...retries {
            await pace()

            var request = URLRequest(url: url)
            request.httpMethod = method
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if body != nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            request.setValue("H4XTOR-Philips-Remote-iOS/1.0", forHTTPHeaderField: "User-Agent")

            do {
                var (data, response) = try await secureSession.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw TVError.transport("TV'et sendte ikke et HTTP-svar.")
                }

                // Digest round-trip
                if http.statusCode == 401,
                   let header = http.value(forHTTPHeaderField: "WWW-Authenticate"),
                   let challenge = DigestAuth.Challenge(header: header),
                   let creds = resolvedCredentials {

                    var authed = request
                    let uri = "/\(apiVersion)/\(path.hasPrefix("/") ? String(path.dropFirst()) : path)"
                    authed.setValue(
                        DigestAuth.authorization(
                            challenge: challenge,
                            username: creds.username,
                            password: creds.password,
                            method: method,
                            uri: uri
                        ),
                        forHTTPHeaderField: "Authorization"
                    )
                    (data, response) = try await secureSession.data(for: authed)
                    guard let retried = response as? HTTPURLResponse else {
                        throw TVError.transport("TV'et sendte ikke et HTTP-svar.")
                    }
                    return try decode(retried, data: data, path: path)
                }

                return try decode(http, data: data, path: path)

            } catch let error as TVError {
                throw error
            } catch {
                lastError = error
                if attempt < retries {
                    let backoff = 0.3 * pow(2, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                    continue
                }
            }
        }

        let detail = lastError?.localizedDescription
        throw TVError.transport(
            "Ingen kontakt til TV'et på \(address)."
                + (detail.map { " \($0)" } ?? " Kontrollér strøm, Wi-Fi og IP-adresse.")
        )
    }

    private func decode(_ response: HTTPURLResponse, data: Data, path: String) throws -> [String: Any] {
        switch response.statusCode {
        case 200...299:
            guard !data.isEmpty else { return [:] }
            guard let object = try? JSONSerialization.jsonObject(with: data),
                  let dictionary = object as? [String: Any] else {
                throw TVError.decoding(path)
            }
            return dictionary
        case 401:
            throw TVError.unauthorized
        default:
            let detail = String(data: data, encoding: .utf8)?
                .replacingOccurrences(of: "\n", with: " ")
                .prefix(180) ?? ""
            throw TVError.http(status: response.statusCode, path: path, detail: String(detail))
        }
    }

    private func pace() async {
        await pacer.wait()
    }

    // MARK: Discovery

    @discardableResult
    func testConnection() async throws -> (info: [String: Any], latencyMS: Int) {
        let started = Date()
        let system = try await request("GET", "system", authenticated: false, secure: false, retries: 1)
        let latency = Int(Date().timeIntervalSince(started) * 1000)

        if let api = system["api_version"] as? [String: Any],
           let major = api["Major"] as? Int, major > 0 {
            apiVersion = major
        }
        return (system, latency)
    }

    func loadSnapshot() async throws -> TVSnapshot {
        var snapshot = TVSnapshot()
        let (system, latency) = try await testConnection()
        snapshot.system = system
        snapshot.latencyMS = latency

        guard StoredCredentials.shared.credentials(for: address) != nil else {
            snapshot.warnings.append("TV'et svarer, men appen er ikke parret endnu.")
            return snapshot
        }

        if let payload = try? await request("GET", "applications") {
            snapshot.applications = Self.parseApplications(payload)
        } else {
            snapshot.warnings.append("Kunne ikke hente app-listen.")
        }

        if let payload = try? await request("GET", "channeldb/tv/channelLists/all") {
            snapshot.channels = Self.parseChannels(payload)
        }

        if let payload = try? await request("GET", "audio/volume") {
            snapshot.volume = VolumeState(
                current: payload["current"] as? Int ?? 0,
                min: payload["min"] as? Int ?? 0,
                max: payload["max"] as? Int ?? 60,
                muted: payload["muted"] as? Bool ?? false
            )
        }

        if let payload = try? await request("GET", "powerstate") {
            snapshot.powerState = payload["powerstate"] as? String ?? "Unknown"
        }

        if let payload = try? await request("GET", "activities/current"),
           let component = payload["component"] as? [String: Any] {
            snapshot.activity = (component["packageName"] as? String) ?? ""
        }

        if let payload = try? await request("GET", "activities/tv"),
           let channel = payload["channel"] as? [String: Any] {
            snapshot.currentChannel = channel["name"] as? String
                ?? (channel["ccid"].map { "Kanal \($0)" } ?? "")
        }

        if let payload = try? await request("GET", "ambilight/power") {
            snapshot.ambilightPower = (payload["power"] as? String)?.lowercased() == "on"
        }

        if let payload = try? await request("GET", "ambilight/currentconfiguration") {
            snapshot.ambilightStyle = payload["styleName"] as? String ?? ""
            snapshot.ambilightSetting = payload["menuSetting"] as? String ?? ""
        }

        return snapshot
    }

    // MARK: Parsing

    static func parseApplications(_ payload: [String: Any]) -> [TVApplication] {
        guard let raw = payload["applications"] as? [[String: Any]] else { return [] }
        return raw.enumerated().compactMap { index, item in
            guard let intent = item["intent"] as? [String: Any] else { return nil }
            let label = (item["label"] as? String)?.trimmingCharacters(in: .whitespaces)
                ?? "App \(index + 1)"
            let identifier = (item["id"] as? String) ?? label
            return TVApplication(
                id: identifier,
                label: label,
                intent: intent,
                type: item["type"] as? String ?? "app"
            )
        }
        .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    static func parseChannels(_ payload: [String: Any]) -> [TVChannel] {
        guard let raw = payload["Channel"] as? [[String: Any]] else { return [] }
        let listID = payload["id"] as? String ?? "all"
        return raw.compactMap { item in
            guard let ccid = item["ccid"] as? Int else { return nil }
            return TVChannel(
                ccid: ccid,
                preset: item["preset"] as? String ?? "",
                name: item["name"] as? String ?? "Kanal \(ccid)",
                listID: listID
            )
        }
    }

    // MARK: Commands

    @discardableResult
    func sendKey(_ key: String) async throws -> [String: Any] {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_")
        guard !key.isEmpty, key.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw TVError.rejected("Ugyldig fjernbetjeningskommando.")
        }
        return try await request("POST", "input/key", json: ["key": key], retries: 1)
    }

    @discardableResult
    func setVolume(_ value: Int, muted: Bool? = nil) async throws -> VolumeState {
        let current = try await request("GET", "audio/volume")
        let minValue = current["min"] as? Int ?? 0
        let maxValue = current["max"] as? Int ?? 60
        let target = Swift.max(minValue, Swift.min(maxValue, value))
        let isMuted = muted ?? (current["muted"] as? Bool ?? false)

        _ = try await request("POST", "audio/volume", json: ["current": target, "muted": isMuted])
        return VolumeState(current: target, min: minValue, max: maxValue, muted: isMuted)
    }

    @discardableResult
    func launch(_ app: TVApplication) async throws -> [String: Any] {
        try await request("POST", "activities/launch", json: ["intent": app.intent])
    }

    @discardableResult
    func tune(_ channel: TVChannel) async throws -> [String: Any] {
        try await request(
            "POST",
            "activities/tv",
            json: [
                "channelList": ["id": channel.listID],
                "channel": ["ccid": channel.ccid]
            ]
        )
    }

    @discardableResult
    func selectSource(_ route: SourceRoute) async throws -> [String: Any] {
        let uri: String
        if route.service.hasPrefix("content://") {
            uri = route.service
        } else {
            var unreserved = CharacterSet.alphanumerics
            unreserved.insert(charactersIn: "-._~")
            let encoded = route.service.addingPercentEncoding(withAllowedCharacters: unreserved)
                ?? route.service
            uri = "content://android.media.tv/passthrough/" + encoded
        }

        let intent: [String: Any] = [
            "extras": ["uri": uri],
            "action": "org.droidtv.playtv.SELECTURI",
            "component": [
                "packageName": "org.droidtv.playtv",
                "className": "org.droidtv.playtv.PlayTvActivity"
            ]
        ]
        return try await request("POST", "activities/launch", json: ["intent": intent])
    }

    @discardableResult
    func setPower(_ state: String) async throws -> [String: Any] {
        let normalized = state == "On" ? "On" : "Standby"
        return try await request("POST", "powerstate", json: ["powerstate": normalized])
    }

    @discardableResult
    func setAmbilight(power: Bool) async throws -> [String: Any] {
        try await request("POST", "ambilight/power", json: ["power": power ? "On" : "Off"])
    }

    @discardableResult
    func setAmbilight(style: String, setting: String) async throws -> [String: Any] {
        let payload: [String: Any] = [
            "styleName": style,
            "isExpert": false,
            "menuSetting": setting
        ]
        return try await request("POST", "ambilight/currentconfiguration", json: payload)
    }

    func recordings() async throws -> [[String: Any]] {
        let payload = try await request("GET", "recordings/list")
        return payload["recordings"] as? [[String: Any]] ?? []
    }

    // MARK: Pairing

    struct PendingPairing {
        let deviceID: String
        let device: [String: Any]
        let authKey: String
        let timestamp: Any
        let timeout: Int
    }

    func startPairing() async throws -> PendingPairing {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let deviceID = String((0..<16).map { _ in alphabet.randomElement()! })

        let device: [String: Any] = [
            "device_name": "H4XTOR Remote",
            "device_os": PairingConstant.deviceOS,
            "app_id": PairingConstant.appID,
            "app_name": PairingConstant.appName,
            "type": "native",
            "id": deviceID
        ]

        let response = try await request(
            "POST",
            "pair/request",
            json: ["scope": ["read", "write", "control"], "device": device],
            authenticated: false,
            secure: true,
            retries: 1
        )

        guard let authKey = response["auth_key"] as? String,
              let timestamp = response["timestamp"] else {
            let message = response["error_text"] as? String
            throw TVError.pairing(message ?? "TV'et returnerede ingen parringsdata.")
        }

        return PendingPairing(
            deviceID: deviceID,
            device: device,
            authKey: authKey,
            timestamp: timestamp,
            timeout: response["timeout"] as? Int ?? 60
        )
    }

    static func pairingSignature(timestamp: Any, pin: String) throws -> String {
        let normalized = pin.trimmingCharacters(in: .whitespaces)
        guard normalized.count == 4, normalized.allSatisfy(\.isNumber) else {
            throw TVError.pairing("PIN-koden skal være fire cifre.")
        }

        let stamp: String
        if let value = timestamp as? Int { stamp = String(value) }
        else if let value = timestamp as? Double { stamp = String(Int(value)) }
        else if let value = timestamp as? String { stamp = value }
        else { throw TVError.pairing("TV'et sendte et ugyldigt tidsstempel.") }

        let message = Data((stamp + normalized).utf8)
        let key = SymmetricKey(data: PairingConstant.secret)
        let code = HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key)
        let hex = code.map { String(format: "%02x", $0) }.joined()
        return Data(hex.utf8).base64EncodedString()
    }

    func completePairing(_ pending: PendingPairing, pin: String) async throws {
        let signature = try Self.pairingSignature(timestamp: pending.timestamp, pin: pin)

        let response = try await request(
            "POST",
            "pair/grant",
            json: [
                "auth": [
                    "auth_AppId": "1",
                    "pin": pin.trimmingCharacters(in: .whitespaces),
                    "auth_timestamp": pending.timestamp,
                    "auth_signature": signature
                ],
                "device": pending.device
            ],
            authenticated: true,
            secure: true,
            credentials: (pending.deviceID, pending.authKey),
            retries: 0
        )

        if let errorID = response["error_id"] as? String,
           errorID != "SUCCESS", errorID != "SUCCESS_PAIRING" {
            throw TVError.pairing(response["error_text"] as? String ?? "TV'et afviste PIN-koden.")
        }

        StoredCredentials.shared.set(pending.deviceID, pending.authKey, for: address)
    }
}

// MARK: - Credential bridge

/// The client is deliberately free of SwiftUI. This small bridge lets it read
/// the same keychain entries the UI writes.
final class StoredCredentials: @unchecked Sendable {
    static let shared = StoredCredentials()
    private init() {}

    func credentials(for address: String) -> (username: String, password: String)? {
        guard let encoded = Keychain.get("cred." + address),
              let data = Data(base64Encoded: encoded),
              let pair = try? JSONDecoder().decode([String].self, from: data),
              pair.count == 2
        else { return nil }
        return (pair[0], pair[1])
    }

    func set(_ username: String, _ password: String, for address: String) {
        guard let data = try? JSONEncoder().encode([username, password]) else { return }
        Keychain.set(data.base64EncodedString(), for: "cred." + address)
    }
}

// MARK: - Pacing

/// Philips' web server falls over on burst traffic. Every request waits at
/// least 120 ms after the previous one started, and the actor keeps that
/// invariant without a blocking lock.
private actor Pacer {
    private var lastRequestAt = Date.distantPast
    private let interval: TimeInterval

    init(interval: TimeInterval) {
        self.interval = interval
    }

    func wait() async {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRequestAt)

        if elapsed < interval {
            let delay = interval - elapsed
            lastRequestAt = now.addingTimeInterval(delay)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        } else {
            lastRequestAt = now
        }
    }
}

// MARK: - Trust

/// Philips sets present a self-signed certificate. Trust it only for the exact
/// host we were configured with; everything else follows normal ATS rules.
final class SelfSignedTrust: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let address: String

    init(address: String) {
        self.address = address
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == address,
              let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        var error: CFError?
        let trusted = SecTrustEvaluateWithError(trust, &error)
        if trusted {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            // Self-signed pin: accept this host only.
            completionHandler(.useCredential, URLCredential(trust: trust))
        }
    }
}
