import Foundation
import CommonCrypto

/// Philips TVs authenticate with HTTP Digest (MD5) over their self-signed
/// HTTPS endpoint. URLSession's built-in digest handling needs a delegate
/// round-trip and is awkward to combine with a custom trust policy, so the
/// header is built here and retried once on 401.
enum DigestAuth {

    struct Challenge {
        var realm: String = ""
        var nonce: String = ""
        var qop: String?
        var opaque: String?
        var algorithm: String? = "MD5"

        init?(header: String) {
            let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix("digest") else { return nil }
            let body = trimmed.dropFirst("digest".count)

            var fields: [String: String] = [:]

            for pair in Self.split(body) {
                let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else { continue }
                let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                var value = parts[1].trimmingCharacters(in: .whitespaces)
                if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                    value = String(value.dropFirst().dropLast())
                }
                fields[key] = value
            }

            guard let nonce = fields["nonce"], let realm = fields["realm"] else { return nil }
            self.nonce = nonce
            self.realm = realm
            self.opaque = fields["opaque"]
            self.algorithm = fields["algorithm"] ?? "MD5"

            if let qop = fields["qop"] {
                // "auth,auth-int" -> prefer auth
                self.qop = qop.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespaces)
                }.contains("auth") ? "auth" : qop
            }
        }

        private static func split(_ body: Substring) -> [String] {
            var result: [String] = []
            var current = ""
            var inQuotes = false
            for char in body {
                if char == "\"" { inQuotes.toggle() }
                if char == "," && !inQuotes {
                    result.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            }
            if !current.trimmingCharacters(in: .whitespaces).isEmpty {
                result.append(current)
            }
            return result
        }
    }

    static func authorization(
        challenge: Challenge,
        username: String,
        password: String,
        method: String,
        uri: String
    ) -> String {
        let cnonce = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let nc = "00000001"

        let ha1 = md5("\(username):\(challenge.realm):\(password)")
        let ha2 = md5("\(method):\(uri)")

        let response: String
        if let qop = challenge.qop, qop == "auth" {
            response = md5("\(ha1):\(challenge.nonce):\(nc):\(cnonce):\(qop):\(ha2)")
        } else {
            response = md5("\(ha1):\(challenge.nonce):\(ha2)")
        }

        var parts = [
            #"username="\#(username)""#,
            #"realm="\#(challenge.realm)""#,
            #"nonce="\#(challenge.nonce)""#,
            #"uri="\#(uri)""#,
            #"response="\#(response)""#,
            #"algorithm=MD5"#
        ]
        if let qop = challenge.qop, qop == "auth" {
            parts.append(#"qop=auth"#)
            parts.append(#"nc=\#(nc)"#)
            parts.append(#"cnonce="\#(cnonce)""#)
        }
        if let opaque = challenge.opaque {
            parts.append(#"opaque="\#(opaque)""#)
        }
        return "Digest " + parts.joined(separator: ", ")
    }

    static func md5(_ string: String) -> String {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
