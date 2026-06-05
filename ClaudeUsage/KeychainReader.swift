import Foundation
import Security

enum KeychainError: Error {
    case notFound
    case unexpectedData
    case status(OSStatus)
}

/// The credential blob Claude Code stores in the macOS Keychain.
struct ClaudeCredentials: Decodable {
    struct OAuth: Decodable {
        let accessToken: String
        let expiresAt: Double? // epoch milliseconds
    }

    let claudeAiOauth: OAuth
}

/// Read-only access to Claude Code's OAuth credentials.
///
/// This app deliberately NEVER writes to the Keychain item. The item belongs to
/// Claude Code, and mutating it is destructive in two ways:
///   1. The OAuth refresh token rotates — writing back a refreshed token
///      invalidates the one Claude Code holds, logging the user out.
///   2. macOS resets the item's access-control list when another app modifies
///      it, revoking Claude Code's "Always Allow" grant and re-triggering the
///      keychain prompt on every read.
/// Claude Code owns token refresh; we only read the current access token to
/// query usage, and show a "token expired" hint when it lapses.
enum KeychainReader {
    /// Service name under which Claude Code stores its OAuth credentials.
    static let service = "Claude Code-credentials"

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
}
