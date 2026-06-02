import Foundation
import Security

enum KeychainError: Error {
    case notFound
    case unexpectedData
    case malformed
    case status(OSStatus)
}

/// The credential blob Claude Code stores in the macOS Keychain.
struct ClaudeCredentials: Decodable {
    struct OAuth: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Double? // epoch milliseconds
    }

    let claudeAiOauth: OAuth
}

enum KeychainReader {
    /// Service name under which Claude Code stores its OAuth credentials.
    static let service = "Claude Code-credentials"

    // MARK: - Read

    /// Reads the raw credential JSON blob. The first access triggers a macOS
    /// keychain prompt; the user grants "Always Allow" once. Synchronous and
    /// blocking, so call off the main thread.
    static func readData() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        guard let data = item as? Data else { throw KeychainError.unexpectedData }
        return data
    }

    static func readCredentials() throws -> ClaudeCredentials {
        try JSONDecoder().decode(ClaudeCredentials.self, from: readData())
    }

    // MARK: - Write-back

    /// Updates only the three OAuth token fields in place, preserving every
    /// other field in the blob (mcpOAuth, organizationUuid, scopes, etc.).
    /// Uses `SecItemUpdate` so the item's ACL is kept intact — Claude Code
    /// keeps its access and reads the same refreshed token.
    static func updateTokens(accessToken: String,
                             refreshToken: String,
                             expiresAt: Double) throws {
        let data = try readData()
        guard
            var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            var oauth = root["claudeAiOauth"] as? [String: Any]
        else {
            throw KeychainError.malformed
        }

        oauth["accessToken"] = accessToken
        oauth["refreshToken"] = refreshToken
        oauth["expiresAt"] = expiresAt
        root["claudeAiOauth"] = oauth

        let updatedData = try JSONSerialization.data(withJSONObject: root)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let attributes: [String: Any] = [kSecValueData as String: updatedData]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }
}
