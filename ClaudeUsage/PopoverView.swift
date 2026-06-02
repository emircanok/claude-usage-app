import SwiftUI

struct PopoverView: View {
    let model: UsageViewModel
    private let loc = LocalizationManager.shared

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var now = Date()

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            switch model.status {
            case .loading:
                Label(loc.t(.loading), systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            case .tokenExpired:
                tokenExpiredView
            case .rateLimited:
                Label(loc.t(.rateLimited), systemImage: "clock.arrow.circlepath")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case let .error(kind):
                Label(loc.t(kind == .keychain ? .errorKeychain : .errorConnection),
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            case .ok:
                content
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 280)
        .onReceive(ticker) { now = $0 }
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            Task { await model.refresh() }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .foregroundStyle(.tint)
            Text(loc.t(.claudeUsage))
                .font(.headline)
            Spacer()
            languageMenu
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help(loc.t(.refresh))
        }
    }

    private var languageMenu: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    loc.language = language
                } label: {
                    if loc.language == language {
                        Label(loc.displayName(for: language), systemImage: "checkmark")
                    } else {
                        Text(loc.displayName(for: language))
                    }
                }
            }
        } label: {
            Image(systemName: "globe")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(loc.t(.language))
    }

    @ViewBuilder
    private var content: some View {
        if let usage = model.usage {
            VStack(spacing: 10) {
                if let fiveHour = usage.fiveHour {
                    usageRow(title: loc.t(.fiveHour), window: fiveHour)
                }
                if let sevenDay = usage.sevenDay {
                    usageRow(title: loc.t(.weekly), window: sevenDay)
                }
                if let sonnet = usage.sevenDaySonnet {
                    usageRow(title: loc.t(.weeklySonnet), window: sonnet)
                }
                if let opus = usage.sevenDayOpus {
                    usageRow(title: loc.t(.weeklyOpus), window: opus)
                }
            }

            if let updated = model.lastUpdated {
                Text(loc.updated(at: updated.formatted(date: .omitted, time: .shortened)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func usageRow(title: String, window: UsageWindow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(window.utilization.rounded()))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(UsageColor.color(for: window.utilization))
            }
            ProgressView(value: min(window.utilization, 100), total: 100)
                .tint(UsageColor.color(for: window.utilization))
            if let resetsAt = window.resetsAt {
                Text(loc.resetsIn(resetsAt.resetCountdown(from: now)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var tokenExpiredView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(loc.t(.tokenExpired), systemImage: "key.slash")
                .foregroundStyle(.orange)
            Text(loc.t(.tokenExpiredHelp))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Toggle(loc.t(.launchAtLogin), isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLogin.setEnabled(newValue)
                }

            Spacer()

            Button(loc.t(.quit)) { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
    }
}
