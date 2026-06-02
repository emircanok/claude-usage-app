import UserNotifications

/// Sends a one-shot macOS notification when 5-hour usage crosses 75% and 90%.
/// State is persisted so we don't re-notify across polls or relaunches, and is
/// cleared when the window resets or usage drops back below 75%.
@MainActor
final class NotificationManager {
    private let defaults = UserDefaults.standard
    private let firedKey = "firedThreshold" // stored as "<windowId>|<level>"

    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(fiveHour: UsageWindow) {
        let windowId = fiveHour.resetsAt
            .map { ISO8601DateFormatter().string(from: $0) } ?? "none"

        let stored = defaults.string(forKey: firedKey)
        let parts = stored?.components(separatedBy: "|") ?? []
        let storedWindow = parts.first
        let firedLevel = (storedWindow == windowId) ? (Int(parts.last ?? "0") ?? 0) : 0

        let utilization = fiveHour.utilization
        var newLevel = firedLevel

        if utilization < 75 {
            newLevel = 0 // window reset or usage dropped
        }
        if utilization >= 75, firedLevel < 75 {
            notify(title: "Claude usage \(Int(utilization))%",
                   body: "Your 5-hour limit is filling up.")
            newLevel = 75
        }
        if utilization >= 90, firedLevel < 90 {
            notify(title: "Claude usage \(Int(utilization))%",
                   body: "Your 5-hour limit is almost full.")
            newLevel = 90
        }

        defaults.set("\(windowId)|\(newLevel)", forKey: firedKey)
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
