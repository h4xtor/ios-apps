import Foundation
import Combine

/// Persists the TV address in UserDefaults and the pairing credentials in the
/// keychain, keyed per address so two sets can live side by side.
@MainActor
final class ConfigStore: ObservableObject {

    @Published var address: String {
        didSet { defaults.set(address, forKey: Keys.address) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let address = "philips.tv.address"
    }

    static let defaultAddress = "192.168.0.110"

    init() {
        let stored = UserDefaults.standard.string(forKey: Keys.address)
        self.address = stored?.isEmpty == false ? stored! : Self.defaultAddress
    }

    // MARK: Credentials

    func credentials(for address: String? = nil) -> (username: String, password: String)? {
        let host = address ?? self.address
        guard let encoded = Keychain.get("cred." + host),
              let data = Data(base64Encoded: encoded),
              let pair = try? JSONDecoder().decode([String].self, from: data),
              pair.count == 2
        else { return nil }
        return (pair[0], pair[1])
    }

    func setCredentials(_ username: String, _ password: String, for address: String? = nil) {
        let host = address ?? self.address
        guard let data = try? JSONEncoder().encode([username, password]) else { return }
        Keychain.set(data.base64EncodedString(), for: "cred." + host)
    }

    func forgetCredentials(for address: String? = nil) {
        let host = address ?? self.address
        Keychain.delete("cred." + host)
    }

    func isPaired(_ address: String? = nil) -> Bool {
        credentials(for: address) != nil
    }

    // MARK: Validation

    /// Philips sets only ever live on the local network. Reject anything that
    /// is not a private IPv4 literal — it keeps the app from being pointed at
    /// a hostname that resolves somewhere unexpected.
    static func validate(address raw: String) -> Result<String, TVError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.invalidAddress("Skriv TV'ets IP-adresse."))
        }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4,
              parts.allSatisfy({ part in
                  guard let value = Int(part), part.count <= 3 else { return false }
                  return (0...255).contains(value) && (part.count == 1 || !part.hasPrefix("0"))
              })
        else {
            return .failure(.invalidAddress("Det er ikke en gyldig IPv4-adresse."))
        }

        guard let first = Int(parts[0]), let second = Int(parts[1]) else {
            return .failure(.invalidAddress("Det er ikke en gyldig IPv4-adresse."))
        }

        let isPrivate =
            first == 10 ||
            (first == 172 && (16...31).contains(second)) ||
            (first == 192 && second == 168)

        guard isPrivate else {
            return .failure(.invalidAddress("TV'et skal ligge på dit lokale net (10.x, 172.16–31.x eller 192.168.x)."))
        }

        return .success(trimmed)
    }
}
