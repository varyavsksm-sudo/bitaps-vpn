import SwiftUI

/// Traffic & session statistics. Pushed inside the Settings NavigationStack,
/// so it uses `.navigationTitle` and never creates its own stack.
public struct StatsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings

    public init() {}

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    public var body: some View {
        ZStack {
            BitBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    lifetimeCards
                    sessionSection
                    historySection
                }
                .padding(BitMetric.pad)
            }
        }
        .navigationTitle("Статистика")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Lifetime totals

    @ViewBuilder private var lifetimeCards: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("за всё время")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: BitMetric.gap) {
                    totalCard(title: "Всего скачано",
                              value: Fmt.bytes(store.lifetimeDown),
                              icon: "arrow.down", chip: 0,
                              glow: BitColor.accent)
                    totalCard(title: "Всего отдано",
                              value: Fmt.bytes(store.lifetimeUp),
                              icon: "arrow.up", chip: 4,
                              glow: BitColor.sky)
                }
                VStack(spacing: BitMetric.gap) {
                    totalCard(title: "Всего скачано",
                              value: Fmt.bytes(store.lifetimeDown),
                              icon: "arrow.down", chip: 0,
                              glow: BitColor.accent)
                    totalCard(title: "Всего отдано",
                              value: Fmt.bytes(store.lifetimeUp),
                              icon: "arrow.up", chip: 4,
                              glow: BitColor.sky)
                }
            }
        }
    }

    @ViewBuilder private func totalCard(title: String, value: String,
                                        icon: String, chip: Int, glow: Color) -> some View {
        BitCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    GradientIcon(icon, index: chip, size: 36)
                    Text(LocalizedStringKey(title))
                        .font(BitFont.mono(12))
                        .foregroundStyle(BitColor.muted)
                }
                Text(LocalizedStringKey(value))
                    .font(BitFont.display(28, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [BitColor.accentSoft, glow],
                                                    startPoint: .top, endPoint: .bottom))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .bitGlow(glow, radius: 14, opacity: 0.3)
            }
        }
        .bitGlow(glow, radius: 22, opacity: 0.18)
    }

    // MARK: - Current session

    @ViewBuilder private var sessionSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("текущая сессия")
            BitCard {
                if store.isConnected {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(LocalizedStringKey(store.selectedServer?.city ?? "—"))
                                .font(BitFont.display(18, weight: .semibold))
                                .foregroundStyle(BitColor.text)
                            Spacer()
                            BitBadge(store.sessionTime, color: BitColor.accent)
                        }

                        HStack(spacing: BitMetric.gap) {
                            liveStat(icon: "arrow.down", chip: 0,
                                     value: Fmt.speed(store.stats.downloadBps),
                                     color: BitColor.accent)
                            liveStat(icon: "arrow.up", chip: 4,
                                     value: Fmt.speed(store.stats.uploadBps),
                                     color: BitColor.sky)
                        }

                        Rectangle().fill(BitColor.line).frame(height: 1)

                        infoRow("IP-адрес", store.stats.ip ?? "—")
                        infoRow("Протокол", store.selectedServer?.proto.label ?? "—")
                    }
                } else {
                    Text("Не подключено")
                        .font(BitFont.mono(13))
                        .foregroundStyle(BitColor.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    @ViewBuilder private func liveStat(icon: String, chip: Int, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            GradientIcon(icon, index: chip, size: 30)
            Text(LocalizedStringKey(value))
                .font(BitFont.mono(15, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [BitColor.accentSoft, color],
                                                startPoint: .top, endPoint: .bottom))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(LocalizedStringKey(label))
                .font(BitFont.mono(12))
                .foregroundStyle(BitColor.muted)
            Spacer()
            Text(LocalizedStringKey(value))
                .font(BitFont.mono(12, weight: .medium))
                .foregroundStyle(BitColor.text)
        }
    }

    // MARK: - History

    @ViewBuilder private var historySection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("история подключений")
            if store.trafficLog.isEmpty {
                BitCard {
                    Text("Пока нет истории")
                        .font(BitFont.mono(13))
                        .foregroundStyle(BitColor.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            } else {
                BitCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(store.trafficLog.enumerated()), id: \.element.id) { idx, entry in
                            historyRow(entry)
                            if idx < store.trafficLog.count - 1 {
                                Rectangle()
                                    .fill(BitColor.line)
                                    .frame(height: 1)
                                    .padding(.leading, BitMetric.pad)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func historyRow(_ entry: TrafficLogEntry) -> some View {
        HStack(spacing: 12) {
            GradientIcon("antenna.radiowaves.left.and.right",
                         index: (entry.serverCity.hashValue & 0x7fff_ffff) % 5, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(entry.serverCity))
                    .font(BitFont.display(15, weight: .semibold))
                    .foregroundStyle(BitColor.text)
                Text(LocalizedStringKey(Self.timeFormatter.string(from: entry.start)))
                    .font(BitFont.mono(11))
                    .foregroundStyle(BitColor.muted)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(LocalizedStringKey(Fmt.duration(entry.duration)))
                    .font(BitFont.mono(12, weight: .semibold))
                    .foregroundStyle(BitColor.text)
                HStack(spacing: 8) {
                    Text("↓\(Fmt.bytes(entry.bytesDown))")
                        .foregroundStyle(BitColor.accent)
                    Text("↑\(Fmt.bytes(entry.bytesUp))")
                        .foregroundStyle(BitColor.accent2)
                }
                .font(BitFont.mono(11, weight: .medium))
            }
        }
        .padding(.horizontal, BitMetric.pad)
        .padding(.vertical, 12)
    }
}

#if DEBUG
struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            StatsView()
                .environmentObject(AppStore())
                .environmentObject(Settings())
        }
        .preferredColorScheme(.dark)
    }
}
#endif
