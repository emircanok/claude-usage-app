import SwiftUI
import Observation

@MainActor
@Observable
final class UsageViewModel {
    /// Semantic error categories. Stored instead of a localized message so the
    /// text is resolved at display time and re-localizes when the user switches
    /// language.
    enum ErrorKind: Equatable {
        case keychain
        case connection
    }

    enum Status: Equatable {
        case loading
        case ok
        case tokenExpired
        case rateLimited
        case error(ErrorKind)
    }

    /// Polling cadence. The User-Agent header is the main rate-limit guard;
    /// 5 minutes is comfortable.
    private static let pollInterval: TimeInterval = 300

    /// Refresh proactively when the token expires within this window.
    private static let refreshBufferMs: Double = 60_000

    private(set) var status: Status = .loading
    private(set) var usage: UsageResponse?
    private(set) var lastUpdated: Date?

    /// Menu bar label image. Observed by the App so the label updates on change.
    private(set) var labelImage: NSImage = LabelRenderer.image(text: "…", color: .secondary)

    private let notifications = NotificationManager()
    private var timer: Timer?

    func start() {
        notifications.requestAuthorization()
        Task { await refresh() }

        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func refresh() async {
        let credentials: ClaudeCredentials
        do {
            credentials = try await Task.detached(priority: .utility) {
                try KeychainReader.readCredentials()
            }.value
        } catch KeychainError.notFound {
            applyTokenExpired()
            return
        } catch {
            if usage == nil { status = .error(.keychain) }
            return
        }

        let oauth = credentials.claudeAiOauth
        var accessToken = oauth.accessToken
        let nowMs = Date().timeIntervalSince1970 * 1000

        // Proactive refresh: token already expired or about to.
        if (oauth.expiresAt ?? 0) <= nowMs + Self.refreshBufferMs,
           let refreshToken = oauth.refreshToken,
           let refreshed = await refreshAndStore(refreshToken: refreshToken) {
            accessToken = refreshed
        }

        do {
            let response = try await UsageClient.fetch(accessToken: accessToken)
            apply(response)
        } catch UsageClientError.unauthorized {
            // Token expired between read and call — try a reactive refresh once.
            if let refreshToken = oauth.refreshToken,
               let refreshed = await refreshAndStore(refreshToken: refreshToken),
               let response = try? await UsageClient.fetch(accessToken: refreshed) {
                apply(response)
            } else {
                applyTokenExpired()
            }
        } catch let UsageClientError.http(code) where code == 429 {
            // Rate limited: keep last good data, show a calm state.
            status = .rateLimited
        } catch {
            if usage == nil { status = .error(.connection) }
        }
    }

    // MARK: - Helpers

    /// Refreshes the access token and writes the new credentials back to the
    /// Keychain so Claude Code stays in sync. Returns the new access token, or
    /// nil on failure (caller falls back to the token-expired state).
    private func refreshAndStore(refreshToken: String) async -> String? {
        do {
            let refreshed = try await TokenRefresher.refresh(refreshToken: refreshToken)
            do {
                try await Task.detached(priority: .utility) {
                    try KeychainReader.updateTokens(
                        accessToken: refreshed.accessToken,
                        refreshToken: refreshed.refreshToken,
                        expiresAt: refreshed.expiresAt
                    )
                }.value
            } catch {
                // Refresh succeeded but persistence failed; use the token for
                // this session and log so the keychain divergence is visible.
                NSLog("Keychain write-back failed: \(error)")
            }
            return refreshed.accessToken
        } catch {
            NSLog("Token refresh failed: \(error)")
            return nil
        }
    }

    private func apply(_ response: UsageResponse) {
        usage = response
        status = .ok
        lastUpdated = Date()

        let utilization = response.fiveHour?.utilization ?? 0
        labelImage = LabelRenderer.image(
            text: "\(Int(utilization.rounded()))%",
            color: UsageColor.color(for: utilization)
        )

        if let fiveHour = response.fiveHour {
            notifications.evaluate(fiveHour: fiveHour)
        }
    }

    private func applyTokenExpired() {
        status = .tokenExpired
        labelImage = LabelRenderer.image(text: "--", color: .secondary)
    }
}
