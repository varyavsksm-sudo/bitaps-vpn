import SwiftUI

/// Gamification screen — streak, shielded traffic and achievements.
/// Pushed inside the Home NavigationStack, so it uses `.navigationTitle`
/// and never creates its own stack.
public struct ProtectionView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings

    public init() {}

    /// Progress towards the next streak milestone (7 → 30 → 90 days).
    private var streakProgress: Double {
        let d = Double(store.protectedDays)
        let target: Double = d < 7 ? 7 : (d < 30 ? 30 : 90)
        return min(max(d / target, 0.001), 1)
    }

    private var unlockedCount: Int { store.achievements.filter(\.unlocked).count }

    public var body: some View {
        ZStack {
            BitBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    heroCard
                    statsRow
                    achievementsSection
                }
                .padding(BitMetric.pad)
            }
        }
        .navigationTitle("Защита")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Hero streak card

    @ViewBuilder private var heroCard: some View {
        BitCard(strong: true) {
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    GradientIcon("flame.fill", index: 0, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Серия защиты")
                            .font(BitFont.display(17, weight: .semibold))
                            .foregroundStyle(BitColor.text)
                        Text("ты под щитом каждый день")
                            .font(BitFont.mono(12))
                            .foregroundStyle(BitColor.muted)
                    }
                    Spacer(minLength: 8)
                    BitBadge("\(unlockedCount)/\(store.achievements.count)", color: BitColor.accent)
                }

                ZStack {
                    Circle()
                        .stroke(BitColor.line, lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: streakProgress)
                        .stroke(BitColor.accentGradient,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .bitGlow(BitColor.accent, radius: 16, opacity: 0.5)
                        .animation(.easeInOut(duration: 0.6), value: streakProgress)
                    VStack(spacing: 2) {
                        Text("\(store.protectedDays)")
                            .font(BitFont.display(54, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [BitColor.accentSoft, BitColor.accent],
                                                            startPoint: .top, endPoint: .bottom))
                            .bitGlow(BitColor.accent, radius: 16, opacity: 0.4)
                        Text("дней под защитой")
                            .font(BitFont.mono(12))
                            .foregroundStyle(BitColor.muted)
                    }
                }
                .frame(width: 180, height: 180)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .bitGlow(BitColor.accent, radius: 26, opacity: 0.2)
    }

    // MARK: - Shielded traffic tiles

    @ViewBuilder private var statsRow: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("под щитом")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: BitMetric.gap) { statTiles }
                VStack(spacing: BitMetric.gap) { statTiles }
            }
        }
    }

    @ViewBuilder private var statTiles: some View {
        statTile(title: "Защищено трафика",
                 value: String(format: NSLocalizedString("%.1f ГБ", comment: ""), store.totalGB),
                 icon: "shield.lefthalf.filled", chip: 2, glow: BitColor.teal)
        statTile(title: "Скачано",
                 value: Fmt.bytes(store.lifetimeDown),
                 icon: "arrow.down", chip: 0, glow: BitColor.accent)
        statTile(title: "Отдано",
                 value: Fmt.bytes(store.lifetimeUp),
                 icon: "arrow.up", chip: 4, glow: BitColor.sky)
    }

    @ViewBuilder private func statTile(title: String, value: String,
                                       icon: String, chip: Int, glow: Color) -> some View {
        BitCard {
            VStack(alignment: .leading, spacing: 12) {
                GradientIcon(icon, index: chip, size: 34)
                Text(LocalizedStringKey(value))
                    .font(BitFont.display(20, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [BitColor.accentSoft, glow],
                                                    startPoint: .top, endPoint: .bottom))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .bitGlow(glow, radius: 12, opacity: 0.3)
                Text(LocalizedStringKey(title))
                    .font(BitFont.mono(11))
                    .foregroundStyle(BitColor.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .bitGlow(glow, radius: 18, opacity: 0.15)
    }

    // MARK: - Achievements grid

    @ViewBuilder private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            HStack {
                Kicker("достижения")
                Spacer()
                Text(String(format: NSLocalizedString("%lld из %lld", comment: ""), unlockedCount, store.achievements.count))
                    .font(BitFont.mono(12, weight: .medium))
                    .foregroundStyle(BitColor.muted)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: BitMetric.gap),
                                GridItem(.flexible(), spacing: BitMetric.gap)],
                      spacing: BitMetric.gap) {
                ForEach(Array(store.achievements.enumerated()), id: \.element.id) { idx, a in
                    achievementTile(a, index: idx)
                }
            }
        }
    }

    @ViewBuilder private func achievementTile(_ a: Achievement, index: Int) -> some View {
        let glow = BitColor.chipShadow(index)
        BitCard {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    GradientIcon(a.icon, index: index, size: 40)
                        .saturation(a.unlocked ? 1 : 0)
                        .opacity(a.unlocked ? 1 : 0.4)
                    if !a.unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(BitColor.muted)
                            .padding(4)
                            .background(Circle().fill(BitColor.bg2))
                            .overlay(Circle().stroke(BitColor.line, lineWidth: 1))
                            .offset(x: 6, y: -6)
                    }
                }
                Text(LocalizedStringKey(a.title))
                    .font(BitFont.display(14, weight: .semibold))
                    .foregroundStyle(a.unlocked ? BitColor.text : BitColor.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LocalizedStringKey(a.detail))
                    .font(BitFont.mono(11))
                    .foregroundStyle(BitColor.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        }
        .opacity(a.unlocked ? 1 : 0.7)
        .bitGlow(a.unlocked ? glow : .clear, radius: 18, opacity: a.unlocked ? 0.22 : 0)
    }
}

#if DEBUG
struct ProtectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProtectionView()
                .environmentObject(AppStore())
                .environmentObject(Settings())
        }
        .preferredColorScheme(.dark)
    }
}
#endif
