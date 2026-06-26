import SwiftUI
import WidgetKit

#if os(iOS)

// MARK: - App Group storage

private enum WidgetStore {
    static let suite = "group.app.bitaps.vpn"
    static var defaults: UserDefaults? { UserDefaults(suiteName: suite) }

    static func read() -> (status: String, city: String, flag: String, connected: Bool) {
        let d = defaults
        return (
            status: d?.string(forKey: "wstatus") ?? "Отключено",
            city: d?.string(forKey: "wcity") ?? "—",
            flag: d?.string(forKey: "wflag") ?? "🌐",
            connected: d?.bool(forKey: "wconnected") ?? false
        )
    }
}

// MARK: - Timeline

struct StatusEntry: TimelineEntry {
    let date: Date
    let status: String
    let city: String
    let flag: String
    let connected: Bool

    static let placeholder = StatusEntry(date: Date(), status: "Отключено",
                                         city: "—", flag: "🌐", connected: false)
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry()], policy: .after(next)))
    }

    private func entry() -> StatusEntry {
        let s = WidgetStore.read()
        return StatusEntry(date: Date(), status: s.status, city: s.city,
                           flag: s.flag, connected: s.connected)
    }
}

// MARK: - Views

struct StatusWidgetEntryView: View {
    var entry: StatusEntry
    @Environment(\.widgetFamily) private var family

    private var glyphColor: Color { entry.connected ? BitColor.accent : BitColor.muted }

    var body: some View {
        Group {
            if family == .systemMedium {
                medium
            } else {
                small
            }
        }
        .bitWidgetBackground()
    }

    private var wordmark: some View {
        HStack(spacing: 0) {
            Text("bit").foregroundStyle(BitColor.text)
            Text("aps").foregroundStyle(BitColor.accent)
        }
        .font(BitFont.display(15, weight: .bold))
    }

    private var powerGlyph: some View {
        Image(systemName: "power")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(glyphColor)
            .shadow(color: entry.connected ? BitColor.accent.opacity(0.5) : .clear, radius: 10)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                wordmark
                Spacer()
                powerGlyph
            }
            Spacer(minLength: 0)
            Text(entry.status)
                .font(BitFont.display(16, weight: .semibold))
                .foregroundStyle(BitColor.text)
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(entry.flag)
                Text(entry.city)
                    .font(BitFont.mono(12))
                    .foregroundStyle(BitColor.muted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack {
                powerGlyph
                    .font(.system(size: 34, weight: .bold))
            }
            .frame(width: 56)
            VStack(alignment: .leading, spacing: 6) {
                wordmark
                Text(entry.status)
                    .font(BitFont.display(18, weight: .semibold))
                    .foregroundStyle(BitColor.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(entry.flag)
                    Text(entry.city)
                        .font(BitFont.mono(13))
                        .foregroundStyle(BitColor.muted)
                        .lineLimit(1)
                }
                if entry.connected {
                    Text("// защищено")
                        .font(BitFont.mono(11, weight: .medium))
                        .foregroundStyle(BitColor.accent)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Background helper (iOS17 container vs older)

private extension View {
    @ViewBuilder
    func bitWidgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.padding(14)
                .containerBackground(for: .widget) { BitColor.bg }
        } else {
            self.padding(14)
                .background(BitColor.bg)
        }
    }
}

// MARK: - Widget

struct StatusWidget: Widget {
    let kind = "BitapsStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusProvider()) { entry in
            StatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("bitaps — статус")
        .description("Подключение и сервер bitaps VPN под рукой.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#endif
