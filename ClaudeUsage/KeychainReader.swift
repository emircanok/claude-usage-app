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
    ///
    /// The item is created by Claude Code; when *this* app modifies its data,
    /// macOS resets the item's access control list / partition list to trust
    /// only the modifying app. That revokes the "Always Allow" grant Claude
    /// Code's `security` tool relies on, so its next read re-triggers the
    /// keychain prompt — repeatedly, as long as this app keeps writing. To
    /// avoid that, the ACL is explicitly repaired after every write so the
    /// item keeps trusting both this app and the `security` tool.
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

        repairAccessControl()
    }

    // MARK: - Access control repair

    /// Re-applies an access control list that trusts exactly this app and the
    /// system `security` tool (which Claude Code shells out to for keychain
    /// access). Called after every data write because modifying another app's
    /// keychain item resets its ACL/partition list, which would otherwise
    /// revoke Claude Code's "Always Allow" grant and storm the user with
    /// keychain prompts. Best-effort: failures are logged, not fatal.
    private static func repairAccessControl() {
        // Resolve the underlying (file-keychain) item reference.
        let refQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnRef as String: true,
        ]
        var ref: CFTypeRef?
        guard SecItemCopyMatching(refQuery as CFDictionary, &ref) == errSecSuccess,
              let ref, CFGetTypeID(ref) == SecKeychainItemGetTypeID()
        else {
            NSLog("ACL repair skipped: keychain item ref unavailable")
            return
        }
        let item = ref as! SecKeychainItem

        // Trust this app and /usr/bin/security (Claude Code's keychain client).
        var selfApp: SecTrustedApplication?
        var securityTool: SecTrustedApplication?
        SecTrustedApplicationCreateFromPath(nil, &selfApp)
        SecTrustedApplicationCreateFromPath("/usr/bin/security", &securityTool)
        let trusted = [selfApp, securityTool].compactMap { $0 }
        guard !trusted.isEmpty else { return }

        var access: SecAccess?
        guard SecAccessCreate(service as CFString, trusted as CFArray, &access) == errSecSuccess,
              let access
        else {
            NSLog("ACL repair skipped: SecAccessCreate failed")
            return
        }

        let status = SecKeychainItemSetAccess(item, access)
        if status != errSecSuccess {
            NSLog("ACL repair failed: SecKeychainItemSetAccess status \(status)")
        }
    }
}
