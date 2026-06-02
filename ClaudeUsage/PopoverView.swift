import SwiftUI

struct PopoverView: View {
    let model: UsageViewModel

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var now = Date()

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            switch model.status {
            case .loading:
                Label("Loading…", systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            case .tokenExpired:
                tokenExpiredView
            case .rateLimited:
                Label("Rate limited — will retry shortly", systemImage: "clock.arrow.circlepath")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case let .error(message):
                Label(message, systemImage: "exclamationmark.triangle")
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
            Text("Claude Usage")
                .font(.headline)
            Spacer()
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let usage = model.usage {
            VStack(spacing: 10) {
                if let fiveHour = usage.fiveHour {
                    usageRow(title: "5-hour", window: fiveHour)
                }
                if let sevenDay = usage.sevenDay {
                    usageRow(title: "Weekly", window: sevenDay)
                }
                if let sonnet = usage.sevenDaySonnet {
                    usageRow(title: "Weekly · Sonnet", window: sonnet)
                }
                if let opus = usage.sevenDayOpus {
                    usageRow(title: "Weekly · Opus", window: opus)
                }
            }

            if let updated = model.lastUpdated {
                Text("Updated: \(updated.formatted(date: .omitted, time: .shortened))")
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
                Text("resets in \(resetsAt.resetCountdown(from: now))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var tokenExpiredView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Token expired", systemImage: "key.slash")
                .foregroundStyle(.orange)
            Text("Run any Claude Code command to refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLogin.setEnabled(newValue)
                }

            Spacer()

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
    }
}
