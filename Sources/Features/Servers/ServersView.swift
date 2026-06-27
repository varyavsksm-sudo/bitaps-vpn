import SwiftUI

/// Server picker — locations grouped by `store.serverGroups`.
/// Tapping an available row selects it (and reconnects if a tunnel is up).
/// Unavailable rows (the foreign "скоро" group) are dimmed and non-tappable.
/// Adds a Happ-style "Авто" hero (fastest node) + live ping measurement.
public struct ServersView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings

    @State private var sortByPing = false
    @State private var didInitialPing = false
    @State private var livePulse = false
    @State private var query = ""

    public init() {}

    /// Case-insensitive match on city / country.
    private func matches(_ server: Server) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        return server.city.lowercased().contains(q)
            || server.countryName.lowercased().contains(q)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                BitBackground()
                content
            }
            .navigationTitle("Серверы")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) { pingButton }
                #else
                ToolbarItem(placement: .automatic) { pingButton }
                #endif
            }
            .task {
                guard !didInitialPing else { return }
                didInitialPing = true
                await store.pingAll()
            }
            .onChange(of: settings.expertMode) { expert in
                // Leaving expert mode hides the only multi-hop control — turn it
                // off so it can't stay silently enabled with no way to disable it.
                if !expert, store.multiHop.enabled { store.multiHop = MultiHop() }
            }
        }
    }

    // MARK: - Ping toolbar control

    @ViewBuilder private var pingButton: some View {
        Button {
            Task { await store.pingAll() }
        } label: {
            if store.isPinging {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(BitColor.accent)
            }
        }
        .disabled(store.isPinging)
        .help("Проверить пинг")
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                mapHeader

                infraRow

                autoHero

                if settings.expertMode { multiHopCard }   // double-VPN — expert only

                searchField

                favoritesSection

                recentsSection

                controlsRow

                ForEach(filteredGroups) { group in
                    groupSection(group)
                }

                if store.serverGroups.isEmpty {
                    Text("Загружаем серверы…")
                        .font(BitFont.mono(13))
                        .foregroundStyle(BitColor.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else if filteredGroups.isEmpty {
                    Text(String(format: NSLocalizedString("Ничего не нашлось по запросу «%@»", comment: ""), query))
                        .font(BitFont.mono(13))
                        .foregroundStyle(BitColor.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                }
            }
            .padding(BitMetric.pad)
        }
        .refreshable {
            await store.refreshAll()
        }
    }

    /// Groups with each server filtered by the search query; empty groups dropped.
    private var filteredGroups: [ServerGroup] {
        store.serverGroups.compactMap { group in
            let matched = group.servers.filter(matches)
            guard !matched.isEmpty else { return nil }
            return ServerGroup(id: group.id, title: group.title,
                               servers: matched, comingSoon: group.comingSoon)
        }
    }

    // MARK: - Search field

    @ViewBuilder private var searchField: some View {
        BitCard(padding: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BitColor.accent)
                TextField("Поиск города или страны", text: $query)
                    .font(BitFont.display(15, weight: .medium))
                    .foregroundStyle(BitColor.text)
                    .textFieldStyle(.plain)
                    #if os(iOS)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    #endif
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(BitColor.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Двойной VPN (multi-hop)

    @ViewBuilder private var multiHopCard: some View {
        let entry = store.multiHop.entryId.flatMap { id in store.availableServers.first { $0.id == id } }
        let exit = store.multiHop.exitId.flatMap { id in store.availableServers.first { $0.id == id } }
        BitCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    GradientIcon("arrow.triangle.swap", index: 1, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("Двойной VPN")
                                .font(BitFont.display(16, weight: .semibold))
                                .foregroundStyle(BitColor.text)
                            BitBadge("PRO", color: BitColor.violet)
                        }
                        Text("Трафик через два узла — двойное шифрование")
                            .font(BitFont.mono(11))
                            .foregroundStyle(BitColor.muted)
                    }
                    Spacer(minLength: 8)
                }

                BitToggle("Включить двойной VPN", isOn: multiHopBinding)

                if store.multiHop.enabled {
                    HStack(spacing: 10) {
                        hopMenu(title: "Вход", current: entry) { picked in
                            store.setMultiHop(entry: picked, exit: exit)
                        }
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(BitColor.accent)
                            .bitGlow(BitColor.accent, radius: 8, opacity: 0.4)
                        hopMenu(title: "Выход", current: exit) { picked in
                            store.setMultiHop(entry: entry, exit: picked)
                        }
                    }

                    if let e = entry, let x = exit {
                        (Text(verbatim: "\(e.flag) ") + Text(LocalizedStringKey(e.city)) + Text(verbatim: " → \(x.flag) ") + Text(LocalizedStringKey(x.city)))
                            .font(BitFont.mono(12, weight: .semibold))
                            .foregroundStyle(LinearGradient(colors: [BitColor.accentSoft, BitColor.accent],
                                                            startPoint: .top, endPoint: .bottom))
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("Выберите вход и выход")
                            .font(BitFont.mono(11))
                            .foregroundStyle(BitColor.muted)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .bitGlow(BitColor.violet, radius: 18, opacity: store.multiHop.enabled ? 0.22 : 0.0)
    }

    /// Toggling multi-hop on without a route picks no servers yet; off clears it.
    private var multiHopBinding: Binding<Bool> {
        Binding(
            get: { store.multiHop.enabled },
            set: { on in
                if on {
                    let avail = store.availableServers
                    let e = store.multiHop.entryId.flatMap { id in avail.first { $0.id == id } } ?? avail.first
                    let x = store.multiHop.exitId.flatMap { id in avail.first { $0.id == id } }
                        ?? avail.first { $0.id != e?.id } ?? avail.first
                    store.setMultiHop(entry: e, exit: x)
                } else {
                    store.setMultiHop(entry: nil, exit: nil)
                }
            }
        )
    }

    @ViewBuilder private func hopMenu(title: String, current: Server?,
                                      onPick: @escaping (Server) -> Void) -> some View {
        Menu {
            ForEach(store.availableServers) { s in
                Button {
                    onPick(s)
                } label: {
                    Label {
                        Text(verbatim: "\(s.flag) ") + Text(LocalizedStringKey(s.city))
                    } icon: {
                        Image(systemName: current?.id == s.id ? "checkmark" : "circle")
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(title))
                    .font(BitFont.mono(10, weight: .semibold))
                    .foregroundStyle(BitColor.accent)
                Group {
                    if let c = current {
                        Text(verbatim: "\(c.flag) ") + Text(LocalizedStringKey(c.city))
                    } else {
                        Text(LocalizedStringKey("Выбрать"))
                    }
                }
                    .font(BitFont.display(14, weight: .semibold))
                    .foregroundStyle(BitColor.text)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Capsule(style: .continuous).fill(BitColor.panel))
            .overlay(Capsule(style: .continuous).stroke(BitColor.line, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
    }

    // MARK: - Favorites & recents

    @ViewBuilder private var favoritesSection: some View {
        let servers = store.favoriteServers.filter(matches)
        if !servers.isEmpty {
            VStack(alignment: .leading, spacing: BitMetric.gap) {
                Kicker("Избранное")
                serverList(servers)
            }
        }
    }

    @ViewBuilder private var recentsSection: some View {
        let servers = store.recentServers.filter(matches)
        if !servers.isEmpty {
            VStack(alignment: .leading, spacing: BitMetric.gap) {
                Kicker("Недавние")
                serverList(servers)
            }
        }
    }

    /// Shared glass list of rows used by favorites/recents/groups.
    @ViewBuilder private func serverList(_ servers: [Server]) -> some View {
        BitCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(servers.enumerated()), id: \.element.id) { idx, server in
                    ServerRow(
                        server: server,
                        isSelected: server == store.selectedServer,
                        isFavorite: store.isFavorite(server.id),
                        measured: store.ping(for: server),
                        onTap: { store.connectTo(server) },
                        onToggleFavorite: { store.toggleFavorite(server.id) }
                    )
                    if idx < servers.count - 1 {
                        Rectangle()
                            .fill(BitColor.line)
                            .frame(height: 1)
                            .padding(.leading, 68)
                    }
                }
            }
        }
    }

    // MARK: - World map header ("Глобальная сеть")

    @ViewBuilder private var mapHeader: some View {
        BitCard(padding: BitMetric.pad) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Kicker("Глобальная сеть")
                        Text("Серверы, которые на связи")
                            .font(BitFont.display(18, weight: .semibold))
                            .foregroundStyle(BitColor.text)
                    }
                    Spacer(minLength: 8)
                    livePulseBadge
                }

                WorldMapView(servers: store.allServers,
                             selectedId: store.selectedServer?.id,
                             onTap: { server in store.connectTo(server) })
                    .frame(maxWidth: .infinity)

                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(BitColor.accent)
                    Text("Нажмите точку на карте, чтобы подключиться")
                        .font(BitFont.mono(11))
                        .foregroundStyle(BitColor.muted)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Text("🇷🇺 Россия — онлайн · 🌍 зарубежные — скоро")
                    .font(BitFont.mono(11))
                    .foregroundStyle(BitColor.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .bitGlow(BitColor.accent, radius: 22, opacity: 0.18)
    }

    // MARK: - Infra status row ("инфраструктура в реальном времени")

    @ViewBuilder private var infraRow: some View {
        let infra = store.infra
        HStack(spacing: BitMetric.gap) {
            infraTile(value: "\(infra.serversOnline)",
                      caption: "серверов\nонлайн",
                      icon: "server.rack",
                      index: 2)
            infraTile(value: "\(infra.locations)",
                      caption: "локаций",
                      icon: "mappin.and.ellipse",
                      index: 4)
            infraTile(value: String(format: "%.1f%%", infra.uptimePct),
                      caption: "аптайм",
                      icon: "checkmark.shield.fill",
                      index: 0)
        }
    }

    @ViewBuilder private func infraTile(value: String, caption: String,
                                        icon: String, index: Int) -> some View {
        BitCard(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                GradientIcon(icon, index: index, size: 34)
                Text(LocalizedStringKey(value))
                    .font(BitFont.display(22, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [BitColor.accentSoft, BitColor.accent],
                                                    startPoint: .top, endPoint: .bottom))
                    .bitGlow(BitColor.accent, radius: 8, opacity: 0.25)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(LocalizedStringKey(caption))
                    .font(BitFont.mono(10))
                    .foregroundStyle(BitColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Green pulsing "на связи" pill.
    @ViewBuilder private var livePulseBadge: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(BitColor.ok.opacity(0.3))
                    .frame(width: livePulse ? 16 : 8, height: livePulse ? 16 : 8)
                    .opacity(livePulse ? 0 : 0.9)
                Circle()
                    .fill(BitColor.ok)
                    .frame(width: 7, height: 7)
                    .bitGlow(BitColor.ok, radius: 6, opacity: 0.8)
            }
            .frame(width: 16, height: 16)
            Text("на связи")
                .font(BitFont.mono(11, weight: .semibold))
                .foregroundStyle(BitColor.ok)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(BitColor.ok.opacity(0.12)))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                livePulse = true
            }
        }
    }

    // MARK: - "Авто" hero

    @ViewBuilder private var autoHero: some View {
        let fastest = store.fastestServer
        Button {
            Task { await store.connectFastest() }
        } label: {
            BitCard(strong: true) {
                HStack(spacing: 14) {
                    GradientIcon("bolt.fill", index: 0, size: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("Быстрый сервер")
                                .font(BitFont.display(17, weight: .semibold))
                                .foregroundStyle(BitColor.text)
                            BitBadge("АВТО", color: BitColor.accent)
                        }
                        Text(LocalizedStringKey(autoSubtitle(fastest)))
                            .font(BitFont.mono(12))
                            .foregroundStyle(BitColor.muted)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BitColor.accent)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: BitMetric.radius, style: .continuous)
                    .stroke(BitColor.accent, lineWidth: 1.5)
            )
            .bitGlow(BitColor.accent, radius: 20, opacity: 0.25)
        }
        .buttonStyle(.plain)
    }

    private func autoSubtitle(_ fastest: Server?) -> String {
        guard let f = fastest else { return "Подбираем лучший узел…" }
        if let p = store.ping(for: f), let ms = p.ms {
            return "\(f.city) · \(ms) ms"
        }
        return "\(f.city) · \(f.pingMs) ms"
    }

    // MARK: - Controls (sort + ping)

    @ViewBuilder private var controlsRow: some View {
        HStack(spacing: BitMetric.gap) {
            Button {
                sortByPing.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(LocalizedStringKey(sortByPing ? "По пингу" : "По группам"))
                }
                .font(BitFont.mono(12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(sortByPing ? Color.black : BitColor.text)
                .background(
                    Capsule().fill(sortByPing ? AnyShapeStyle(BitColor.accentGradient)
                                              : AnyShapeStyle(BitColor.panel))
                )
                .overlay(Capsule().stroke(BitColor.line, lineWidth: sortByPing ? 0 : 1))
            }
            .buttonStyle(.plain)

            Button {
                Task { await store.pingAll() }
            } label: {
                HStack(spacing: 6) {
                    if store.isPinging {
                        ProgressView().controlSize(.small)
                        Text("Замеряю…")
                    } else {
                        Image(systemName: "bolt.fill")
                        Text("Проверить пинг")
                    }
                }
                .font(BitFont.mono(12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(BitColor.text)
                .background(Capsule().fill(BitColor.panel))
                .overlay(Capsule().stroke(BitColor.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(store.isPinging)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Group section

    @ViewBuilder private func groupSection(_ group: ServerGroup) -> some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker(group.title)

            if group.comingSoon {
                Text("Зарубежные узлы скоро — сейчас доступна Россия")
                    .font(BitFont.mono(12))
                    .foregroundStyle(BitColor.muted)
            }

            serverList(orderedServers(group.servers))
        }
    }

    /// Sort within a group by measured-or-nominal ping (available first) when enabled,
    /// otherwise keep the server-defined order.
    private func orderedServers(_ servers: [Server]) -> [Server] {
        guard sortByPing else { return servers }
        return servers.sorted { a, b in
            if a.available != b.available { return a.available && !b.available }
            let pa = store.ping(for: a)?.ms ?? a.pingMs
            let pb = store.ping(for: b)?.ms ?? b.pingMs
            return pa < pb
        }
    }
}

// MARK: - Row

private struct ServerRow: View {
    let server: Server
    let isSelected: Bool
    let isFavorite: Bool
    let measured: PingResult?
    let onTap: () -> Void
    let onToggleFavorite: () -> Void

    private var dimmed: Bool { !server.available }

    var body: some View {
        Button(action: { if server.available { onTap() } }) {
            HStack(spacing: 12) {
                flagChip
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(LocalizedStringKey(server.city))
                            .font(BitFont.display(16, weight: .semibold))
                            .foregroundStyle(BitColor.text)
                        if server.premium {
                            BitBadge("PRO", color: BitColor.accentSoft)
                        }
                        if !server.available {
                            BitBadge("Скоро", color: BitColor.muted)
                        }
                    }
                    Text(LocalizedStringKey(server.countryName))
                        .font(BitFont.mono(12))
                        .foregroundStyle(BitColor.muted)
                }

                Spacer(minLength: 8)

                if server.available {
                    VStack(alignment: .trailing, spacing: 6) {
                        pingLabel
                        HStack(spacing: 6) {
                            LoadBar(pct: server.loadPct)
                                .frame(width: 80)
                            Text("\(server.loadPct)%")
                                .font(BitFont.mono(11))
                                .foregroundStyle(BitColor.muted)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }

                starButton
                    .frame(width: 26)

                selectionMark
                    .frame(width: 22)
            }
            .padding(.horizontal, BitMetric.pad)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .opacity(dimmed ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!server.available)
    }

    /// Star toggle — fills + glows when the server is a favorite.
    @ViewBuilder private var starButton: some View {
        Button(action: onToggleFavorite) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isFavorite ? BitColor.accentSoft : BitColor.muted)
                .bitGlow(BitColor.accentSoft, radius: 8, opacity: isFavorite ? 0.5 : 0)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Frosted-glass chip with a soft accent ring holding the country flag emoji.
    @ViewBuilder private var flagChip: some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        Text(LocalizedStringKey(server.flag))
            .font(.system(size: 22))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(shape.fill(.ultraThinMaterial))
            .background(shape.fill(LinearGradient(
                colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
                startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(shape.stroke(BitColor.line, lineWidth: 1))
            .clipShape(shape)
            .overlay(
                isSelected
                    ? shape.stroke(BitColor.accent.opacity(0.7), lineWidth: 1.5)
                    : nil
            )
    }

    /// Live measured ping (colored by latency) when available; otherwise the
    /// nominal value, muted.
    @ViewBuilder private var pingLabel: some View {
        if let m = measured {
            Text(LocalizedStringKey(m.ms.map { "\($0) ms" } ?? "—"))
                .font(BitFont.mono(12, weight: .semibold))
                .foregroundStyle(pingColor(m.ms))
        } else {
            Text("\(server.pingMs) ms")
                .font(BitFont.mono(12, weight: .semibold))
                .foregroundStyle(BitColor.muted)
        }
    }

    private func pingColor(_ ms: Int?) -> Color {
        guard let ms else { return BitColor.danger }
        switch ms {
        case ..<60:  return BitColor.ok
        case ..<120: return BitColor.warn
        default:     return BitColor.danger
        }
    }

    @ViewBuilder private var selectionMark: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BitColor.accent)
                .bitGlow(BitColor.accent, radius: 10, opacity: 0.5)
        } else if server.available {
            Circle()
                .stroke(BitColor.line, lineWidth: 1.5)
                .frame(width: 18, height: 18)
        }
    }
}

#if DEBUG
struct ServersView_Previews: PreviewProvider {
    static var previews: some View {
        ServersView()
            .environmentObject(AppStore())
            .environmentObject(Settings())
            .preferredColorScheme(.dark)
    }
}
#endif
