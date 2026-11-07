import Foundation

/// Validate configuration before calling an SDK that asserts on malformed keys.
/// This only checks the public key's shape; Clerk still verifies the instance.
public enum AccountConfiguration {
    public static func publishableKey(_ value: String) -> String? { validated(value)?.key }
    public static func instanceID(_ value: String) -> String? { validated(value)?.host }
    private static func validated(_ value: String) -> (key: String, host: String)? {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.hasPrefix("pk_test_") || key.hasPrefix("pk_live_") else { return nil }
        let encoded = String(key.dropFirst(8))
        guard !encoded.isEmpty, encoded.count % 4 != 1,
              let bytes = Data(base64Encoded: encoded + String(repeating: "=", count: (4 - encoded.count % 4) % 4)),
              let decoded = String(data: bytes, encoding: .utf8), decoded.hasSuffix("$") else { return nil }
        let host = String(decoded.dropLast())
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
        guard host.count <= 253, labels.count > 1, labels.allSatisfy({
            !$0.isEmpty && $0.count <= 63 && $0.first != "-" && $0.last != "-" && $0.allSatisfy { allowed.contains($0) }
        }) else { return nil }
        return (key, host.lowercased())
    }
}
