import Foundation
import Observation

/// User-selectable UI language. `.system` follows the macOS preferred language;
/// `.en` / `.tr` force a specific language regardless of the system setting.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case tr

    var id: String { rawValue }
}

/// Single source of truth for the app's UI language. `@Observable` so SwiftUI
/// views re-render immediately when the user switches language; the choice is
/// persisted in `UserDefaults`. Add a new language by extending `AppLanguage`,
/// the `resolved` mapping, and every `L10n` translation.
@MainActor
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    private static let defaultsKey = "preferredLanguage"

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey) }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.defaultsKey)
        language = AppLanguage(rawValue: raw ?? "") ?? .system
    }

    /// The concrete language to display, resolving `.system` against the OS.
    var resolved: AppLanguage {
        switch language {
        case .en: return .en
        case .tr: return .tr
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("tr") ? .tr : .en
        }
    }

    /// Localized string for a static key.
    func t(_ key: L10n) -> String {
        resolved == .tr ? key.tr : key.en
    }

    // MARK: - Parameterized strings (word order differs per language)

    func updated(at time: String) -> String {
        resolved == .tr ? "Güncellendi: \(time)" : "Updated: \(time)"
    }

    func resetsIn(_ countdown: String) -> String {
        resolved == .tr ? "\(countdown) içinde sıfırlanır" : "resets in \(countdown)"
    }

    func usageNotificationTitle(percent: Int) -> String {
        resolved == .tr ? "Claude kullanımı %\(percent)" : "Claude usage \(percent)%"
    }

    /// Display label for a language option in the picker.
    func displayName(for language: AppLanguage) -> String {
        switch language {
        case .system: return resolved == .tr ? "Sistem" : "System"
        case .en: return "English"
        case .tr: return "Türkçe"
        }
    }
}

/// Static UI strings with their English and Turkish translations.
enum L10n {
    case loading
    case rateLimited
    case claudeUsage
    case refresh
    case language
    case fiveHour
    case weekly
    case weeklySonnet
    case weeklyOpus
    case tokenExpired
    case tokenExpiredHelp
    case launchAtLogin
    case quit
    case errorKeychain
    case errorConnection
    case notifyFillingBody
    case notifyAlmostFullBody

    var en: String {
        switch self {
        case .loading: return "Loading…"
        case .rateLimited: return "Rate limited — will retry shortly"
        case .claudeUsage: return "Claude Usage"
        case .refresh: return "Refresh"
        case .language: return "Language"
        case .fiveHour: return "5-hour"
        case .weekly: return "Weekly"
        case .weeklySonnet: return "Weekly · Sonnet"
        case .weeklyOpus: return "Weekly · Opus"
        case .tokenExpired: return "Token expired"
        case .tokenExpiredHelp: return "Run any Claude Code command to refresh."
        case .launchAtLogin: return "Launch at login"
        case .quit: return "Quit"
        case .errorKeychain: return "Could not read Keychain"
        case .errorConnection: return "Connection error"
        case .notifyFillingBody: return "Your 5-hour limit is filling up."
        case .notifyAlmostFullBody: return "Your 5-hour limit is almost full."
        }
    }

    var tr: String {
        switch self {
        case .loading: return "Yükleniyor…"
        case .rateLimited: return "Hız sınırı aşıldı — birazdan yeniden denenecek"
        case .claudeUsage: return "Claude Usage"
        case .refresh: return "Yenile"
        case .language: return "Dil"
        case .fiveHour: return "5 saatlik"
        case .weekly: return "Haftalık"
        case .weeklySonnet: return "Haftalık · Sonnet"
        case .weeklyOpus: return "Haftalık · Opus"
        case .tokenExpired: return "Token süresi doldu"
        case .tokenExpiredHelp: return "Yenilemek için herhangi bir Claude Code komutu çalıştırın."
        case .launchAtLogin: return "Girişte başlat"
        case .quit: return "Çıkış"
        case .errorKeychain: return "Keychain okunamadı"
        case .errorConnection: return "Bağlantı hatası"
        case .notifyFillingBody: return "5 saatlik limitiniz dolmaya başlıyor."
        case .notifyAlmostFullBody: return "5 saatlik limitiniz neredeyse doldu."
        }
    }
}
