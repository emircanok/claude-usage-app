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
        let nowMs = Date().timeIntervalSince1970 * 1000

        // The access token is owned and refreshed by Claude Code. This app never
        // writes to the Keychain: mutating Claude Code's item rotates the shared
        // refresh token (logging Claude Code out) and resets the item's ACL
        // (storming the user with keychain prompts). If the token has expired we
        // simply wait for Claude Code to refresh it on its next command.
        if let expiresAt = oauth.expiresAt, expiresAt <= nowMs {
            applyTokenExpired()
            return
        }

        do {
            let response = try await UsageClient.fetch(accessToken: oauth.accessToken)
            apply(response)
        } catch UsageClientError.unauthorized {
            // Token lapsed between read and call — Claude Code will refresh it.
            applyTokenExpired()
        } catch let UsageClientError.http(code) where code == 429 {
            // Rate limited: keep last good data, show a calm state.
            status = .rateLimited
        } catch {
            if usage == nil { status = .error(.connection) }
        }
    }

    // MARK: - Helpers

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
