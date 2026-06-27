import SwiftUI

// MARK: - Home (main connect screen) — compact, tap-driven control panel
//
// Fits ~1 screen. The big customizable PowerButton is the centerpiece; the rest
// is purely connection control — mode selector, current-server card and a live
// stats row. All tools/config live in the Settings tab, so nothing here
// duplicates it. The 🛡 streak chip taps through to the Protection screen.

public struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings

    @State private var showServers = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                BitBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        header
                        powerBlock
                        modeSelector
                        serverCard
                        liveRow
                        protectionCheck
                        Color.clear.frame(height: 6)
                    }
                    .padding(.horizontal, BitMetric.pad)
                    .padding(.top, 6)
                    .padding(.bottom, 20)
                    .frame(maxWidth: 580)            // centred & padded on macOS
                    .frame(maxWidth: .infinity)
                }
            }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .sheet(isPresented: $showServers) {
            ServerPickerSheet(isPresented: $showServers)
                .environmentObject(store)
        }
    }

    // MARK: 1 · Header

    private var header: some View {
        HStack(spacing: 8) {
            BitLogo(size: 24, spinning: store.status.isBusy)
            Spacer()
            NavigationLink { ProtectionView() } label: { streakChip }
                .buttonStyle(.plain)
            shieldPill
        }
    }

    // 🛡 streak — days under protection (glass capsule, gradient number)
    private var streakChip: some View {
        HStack(spacing: 5) {
            Text("🛡")
                .font(.system(size: 12))
            Text("\(store.protectedDays)")
                .font(BitFont.mono(12, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [BitColor.accentSoft, BitColor.accent],
                                                startPoint: .top, endPoint: .bottom))
                .bitGlow(BitColor.accent, radius: 8, opacity: 0.4)
            Text("дн.")
                .font(BitFont.mono(11, weight: .medium))
                .foregroundStyle(BitColor.muted)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(BitColor.accent.opacity(0.30), lineWidth: 1))
    }

    private var shieldPill: some View {
        let active = store.isConnected
        return HStack(spacing: 6) {
            Circle()
                .fill(active ? BitColor.ok : BitColor.muted)
                .frame(width: 8, height: 8)
                .bitGlow(active ? BitColor.ok : .clear, radius: 8, opacity: active ? 0.8 : 0)
            Text(LocalizedStringKey(active ? "защищено" : "не защищено"))
                .font(BitFont.mono(12, weight: .medium))
                .foregroundStyle(active ? BitColor.ok : BitColor.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(BitColor.panel))
        .overlay(Capsule().stroke(active ? BitColor.ok.opacity(0.4) : BitColor.line, lineWidth: 1))
        .bitGlow(active ? BitColor.ok : .clear, radius: 16, opacity: active ? 0.35 : 0)
        .animation(.easeInOut(duration: 0.3), value: active)
    }

    // MARK: 2 · Power block (centerpiece — customizable connect button)

    private var powerBlock: some View {
        VStack(spacing: 8) {
            // Soft glow halo BEHIND the (untouched) PowerButton.
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: store.isConnected
                                ? [BitColor.accent.opacity(0.45), BitColor.accent.opacity(0.0)]
                                : [BitColor.accent.opacity(0.18), .clear],
                            center: .center, startRadius: 6, endRadius: 150)
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 24)
                    .animation(.easeInOut(duration: 0.5), value: store.isConnected)

                PowerButton(status: store.status, style: settings.connectButton) {
                    store.toggleConnection()
                }
            }

            Text(LocalizedStringKey(store.status.title))
                .font(BitFont.display(22, weight: .bold))
                .foregroundStyle(BitColor.text)
                .animation(.easeInOut(duration: 0.25), value: store.status)

            Text(store.isConnected ? store.sessionTime : Fmt.duration(0))
                .font(BitFont.mono(34, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(
                    store.isConnected
                        ? AnyShapeStyle(LinearGradient(colors: [BitColor.accentSoft, BitColor.accent],
                                                       startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(BitColor.muted)
                )
                .bitGlow(store.isConnected ? BitColor.accent : .clear,
                         radius: 18, opacity: store.isConnected ? 0.4 : 0)
                .animation(.easeInOut(duration: 0.3), value: store.isConnected)
        }
    }

    // MARK: 2b · Use-case mode selector (one-tap presets)

    private var modeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(UseCaseMode.allCases) { mode in
                    modeChip(mode)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private func modeChip(_ mode: UseCaseMode) -> some View {
        let selected = settings.useCase == mode
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                settings.useCase = mode
            }
            store.applyMode(mode)
        } label: {
            HStack(spacing: 8) {
                GradientIcon(mode.icon, index: mode.chipIndex, size: 28)
                Text(LocalizedStringKey(mode.label))
                    .font(BitFont.display(14, weight: .semibold))
                    .foregroundStyle(selected ? BitColor.text : BitColor.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(
                Capsule().stroke(selected ? BitColor.accent.opacity(0.65) : BitColor.line,
                                 lineWidth: selected ? 1.5 : 1)
            )
            .bitGlow(selected ? BitColor.accent : .clear, radius: 14, opacity: selected ? 0.45 : 0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.25), value: selected)
    }

    // MARK: 3 · Compact current-server card → opens inline picker sheet

    private var serverCard: some View {
        Button {
            showServers = true
        } label: {
            BitCard(padding: 14) {
                HStack(spacing: 13) {
                    if let flag = store.selectedServer?.flag {
                        Text(LocalizedStringKey(flag))
                            .font(.system(size: 26))
                            .frame(width: 46, height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(BitColor.chipGradient(4).opacity(0.22))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(BitColor.sky.opacity(0.35), lineWidth: 1)
                            )
                    } else {
                        GradientIcon("antenna.radiowaves.left.and.right", index: 4, size: 46)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(LocalizedStringKey(store.selectedServer?.city ?? "Сервер не выбран"))
                            .font(BitFont.display(16, weight: .bold))
                            .foregroundStyle(BitColor.text)
                        Text(LocalizedStringKey(subtitleText))
                            .font(BitFont.mono(11))
                            .foregroundStyle(BitColor.muted)
                    }

                    Spacer()

                    if let s = store.selectedServer {
                        BitBadge(s.proto.label, color: BitColor.accent2)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(BitColor.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var subtitleText: String {
        guard let s = store.selectedServer else { return "выберите локацию" }
        let live = store.ping(for: s)?.ms ?? s.pingMs
        return "\(live) ms · \(s.qualityLabel)"
    }

    // MARK: 4 · Single compact live row (↓ / ↑ / IP)

    private var liveRow: some View {
        BitCard(padding: 12) {
            HStack(spacing: 14) {
                liveMetric(symbol: "arrow.down", tint: BitColor.accent,
                           value: Fmt.speed(store.stats.downloadBps))
                Rectangle().fill(BitColor.line).frame(width: 1, height: 18)
                liveMetric(symbol: "arrow.up", tint: BitColor.accent2,
                           value: Fmt.speed(store.stats.uploadBps))
                Spacer(minLength: 6)
                HStack(spacing: 5) {
                    Image(systemName: "globe")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(BitColor.ok)
                    Text(LocalizedStringKey(store.stats.ip ?? "—"))
                        .font(BitFont.mono(11, weight: .medium))
                        .foregroundStyle(BitColor.muted)
                        .lineLimit(1)
                }
            }
            .animation(.easeOut(duration: 0.3), value: store.stats.downloadBps)
        }
    }

    private func liveMetric(symbol: String, tint: Color, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold))
            Text(LocalizedStringKey(value)).font(BitFont.mono(12, weight: .semibold))
        }
        .foregroundStyle(tint)
    }

    // MARK: 5 · Check my protection (IP / leaks) — trust on the front page

    private var protectionCheck: some View {
        NavigationLink {
            LeakCheckView()
        } label: {
            BitCard(padding: 14) {
                HStack(spacing: 13) {
                    GradientIcon("checkerboard.shield", index: 1, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Проверить защиту")
                            .font(BitFont.display(15, weight: .bold))
                            .foregroundStyle(BitColor.text)
                        Text("Мой IP · DNS / WebRTC утечки")
                            .font(BitFont.mono(11))
                            .foregroundStyle(BitColor.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(BitColor.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inline server picker sheet

private struct ServerPickerSheet: View {
    @EnvironmentObject var store: AppStore
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            BitBackground()

            VStack(spacing: 0) {
                HStack {
                    Kicker("выбор локации")
                    Spacer()
                    Button {
                        Task { await store.pingAll() }
                    } label: {
                        HStack(spacing: 5) {
                            if store.isPinging {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "bolt.fill").font(.system(size: 11, weight: .bold))
                            }
                            Text("Пинг")
                                .font(BitFont.mono(11, weight: .semibold))
                        }
                        .foregroundStyle(BitColor.accent)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(BitColor.accent.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isPinging)

                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(BitColor.muted)
                            .padding(8)
                            .background(Circle().fill(BitColor.panel))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                }
                .padding(.horizontal, BitMetric.pad)
                .padding(.top, BitMetric.pad)
                .padding(.bottom, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(store.serverGroups) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Text(LocalizedStringKey(group.title))
                                        .font(BitFont.display(15, weight: .semibold))
                                        .foregroundStyle(BitColor.text)
                                    if group.comingSoon {
                                        BitBadge("скоро", color: BitColor.muted)
                                    }
                                }
                                VStack(spacing: 8) {
                                    ForEach(group.servers) { server in
                                        ServerRow(
                                            server: server,
                                            ping: store.ping(for: server)?.ms,
                                            selected: server.id == store.selectedServer?.id
                                        ) {
                                            if server.available {
                                                store.connectTo(server)   // тап = подключиться
                                                isPresented = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, BitMetric.pad)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
    }
}

private struct ServerRow: View {
    let server: Server
    let ping: Int?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BitCard(padding: 13, strong: selected) {
                HStack(spacing: 12) {
                    Text(LocalizedStringKey(server.flag)).font(.system(size: 26))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(LocalizedStringKey(server.city))
                                .font(BitFont.display(15, weight: .medium))
                                .foregroundStyle(BitColor.text)
                            if server.premium {
                                BitBadge("VIP", color: BitColor.accent)
                            }
                            if !server.available {
                                BitBadge("скоро", color: BitColor.muted)
                            }
                        }
                        HStack(spacing: 8) {
                            Text("\(ping ?? server.pingMs) ms")
                                .font(BitFont.mono(11))
                                .foregroundStyle(BitColor.muted)
                            LoadBar(pct: server.loadPct)
                                .frame(width: 56)
                        }
                    }

                    Spacer()

                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(BitColor.accent)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(BitColor.muted)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(server.available ? 1 : 0.5)
        .disabled(!server.available)
    }
}
