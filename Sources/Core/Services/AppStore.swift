import SwiftUI
import Combine

/// Single source of truth for the whole app. Every screen observes this.
/// Owns the API + tunnel behind their protocols, so swapping Mock→real is a
/// one-line change with zero UI edits.
@MainActor
public final class AppStore: ObservableObject, VPNTunnelDelegate {

    // Session / routing
    @Published public var user: User?
    @Published public var hasOnboarded: Bool
    @Published public var isLoggedIn: Bool = false
    @Published public var isBootstrapping = false

    // VPN
    @Published public private(set) var status: VPNStatus = .disconnected
    @Published public private(set) var stats: ConnectionStats = .zero
    @Published public var selectedServer: Server?

    // Data
    @Published public var serverGroups: [ServerGroup] = []
    @Published public var plans: [Plan] = []
    @Published public var subscription: Subscription?
    @Published public var devices: [Device] = []

    // Ping / latency (serverId -> result)
    @Published public var pings: [String: PingResult] = [:]
    @Published public var isPinging = false

    // Landing-style content (mirrors index.html)
    @Published public var infra: InfraStatus = .demo

    // Personal cabinet (mirrors account.html)
    @Published public var accessKey: AccessKey?
    @Published public var referral: Referral?
    @Published public var faq: [FAQItem] = []

    // New features: multi-hop, favorites/recents, pause, gamification, trusted nets, split tunnel, speed history
    @Published public var multiHop = MultiHop()
    @Published public var favorites: Set<String> = []
    @Published public var recents: [String] = []
    @Published public var pausedUntil: Date?
    @Published public var protectedDays: Int = 12
    @Published public var trustedNetworks: [TrustedNetwork] = [TrustedNetwork(ssid: "Home_WiFi")]
    @Published public var splitApps: [AppEntry] = AppEntry.demo
    @Published public var speedHistory: [SpeedTestResult] = []
    @Published public var schedules: [ScheduleRule] = ScheduleRule.demo
    @Published public var smartRules: [SmartRule] = SmartRule.demo
    @Published public var leak: LeakReport?
    @Published public var isCheckingLeak = false

    // BYO configs (power-user parity with Happ)
    @Published public var importedConfigs: [ImportedConfig] = []

    // Lifetime + session traffic log
    @Published public var trafficLog: [TrafficLogEntry] = []
    @Published public var lifetimeDown: Int64 = 0
    @Published public var lifetimeUp: Int64 = 0
    private var activeLogID: String?

    // Diagnostics log + speed test + live chart buffer
    @Published public var logs: [LogEntry] = []
    @Published public var speedTestResult: SpeedTestResult?
    @Published public var isSpeedTesting = false
    /// Rolling window of recent download/upload speeds for the live sparkline.
    @Published public var recentDown: [Double] = Array(repeating: 0, count: 40)
    @Published public var recentUp: [Double] = Array(repeating: 0, count: 40)
    private let speedTester = SpeedTestService()

    // UI feedback
    @Published public var errorMessage: String?

    private let api: BitAPI
    private var tunnel: VPNTunnel
    private let pinger = PingService()
    private var clockCancellable: AnyCancellable?
    @Published public var elapsed: TimeInterval = 0

    /// All servers flattened, available first.
    public var allServers: [Server] { serverGroups.flatMap(\.servers) }
    public var availableServers: [Server] { allServers.filter(\.available) }
    public func ping(for server: Server) -> PingResult? { pings[server.id] }

    public init(api: BitAPI = APIFactory.make(), tunnel: VPNTunnel? = nil) {
        self.api = api
        self.tunnel = tunnel ?? TunnelFactory.make()
        self.hasOnboarded = UserDefaults.standard.bool(forKey: "bitaps.onboarded")
        self.tunnel.delegate = self
        loadPersisted()
        startClock()
    }

    private func loadPersisted() {
        let d = UserDefaults.standard
        lifetimeDown = Int64(d.integer(forKey: "bitaps.lifeDown"))
        lifetimeUp = Int64(d.integer(forKey: "bitaps.lifeUp"))
        if let data = d.data(forKey: "bitaps.configs"),
           let cfgs = try? JSONDecoder().decode([ImportedConfig].self, from: data) {
            importedConfigs = cfgs
        }
        if let data = d.data(forKey: "bitaps.log"),
           let log = try? JSONDecoder().decode([TrafficLogEntry].self, from: data) {
            trafficLog = log
        }
    }

    private func persistConfigs() {
        if let data = try? JSONEncoder().encode(importedConfigs) {
            UserDefaults.standard.set(data, forKey: "bitaps.configs")
        }
    }
    private func persistLog() {
        UserDefaults.standard.set(lifetimeDown, forKey: "bitaps.lifeDown")
        UserDefaults.standard.set(lifetimeUp, forKey: "bitaps.lifeUp")
        if let data = try? JSONEncoder().encode(Array(trafficLog.prefix(50))) {
            UserDefaults.standard.set(data, forKey: "bitaps.log")
        }
    }

    // MARK: - Bootstrap

    public func bootstrap() async {
        isBootstrapping = true
        defer { isBootstrapping = false }
        if let u = await api.currentUser() { user = u; isLoggedIn = true }
        await refreshAll()
    }

    public func refreshAll() async {
        async let groups = try? await api.fetchServers()
        async let plansList = try? await api.fetchPlans()
        async let sub = try? await api.fetchSubscription()
        async let devs = try? await api.fetchDevices()
        let (g, p, s, d) = await (groups, plansList, sub, devs)
        if let g { serverGroups = g; if selectedServer == nil { selectedServer = firstAvailable(in: g) } }
        if let p { plans = p }
        if let s { subscription = s }
        if let d { devices = d }
        accessKey = try? await api.fetchAccessKey()
        referral = try? await api.fetchReferral()
        faq = await api.fetchFAQ()
    }

    // MARK: - Cabinet actions

    public func regenerateKey() async {
        do { accessKey = try await api.regenerateKey(); addLog(.success, "Ключ доступа обновлён") }
        catch { errorMessage = error.localizedDescription }
    }

    public func sendSupport(_ message: String) async -> Bool {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        do { try await api.sendSupport(message: message); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }

    private func firstAvailable(in groups: [ServerGroup]) -> Server? {
        groups.flatMap(\.servers).first(where: \.available)
    }

    // MARK: - Auth

    public func loginDemo() async {
        user = await api.loginDemo(); isLoggedIn = true
        await refreshAll()
    }

    public func loginWithTelegram() async {
        // In the real flow the bot returns a token via deep-link callback.
        do {
            let u = try await api.loginWithTelegram(token: "demo-token")
            user = u; isLoggedIn = true
            await refreshAll()
        } catch {
            // Fall back to demo so the app is always usable in this build.
            await loginDemo()
        }
    }

    public func logout() async {
        await disconnect()
        await api.logout()
        user = nil; isLoggedIn = false
    }

    public func completeOnboarding() {
        hasOnboarded = true
        UserDefaults.standard.set(true, forKey: "bitaps.onboarded")
    }

    // MARK: - VPN control

    public var isConnected: Bool { status.isActive }

    public func toggleConnection() {
        Task {
            if status.isActive || status == .connecting {
                await disconnect()
            } else {
                await connect()
            }
        }
    }

    public func connect() async {
        guard let server = selectedServer ?? firstAvailable(in: serverGroups) else {
            errorMessage = "Нет доступного сервера"; return
        }
        if let sub = subscription, sub.status == .expired {
            errorMessage = AppError.subscriptionExpired.errorDescription; return
        }
        selectedServer = server
        do {
            try await tunnel.connect(to: server)
            pushRecent(server.id)
        }
        catch { errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription }
    }

    public func disconnect() async {
        await tunnel.disconnect()
    }

    public func select(_ server: Server) {
        guard server.available else { errorMessage = AppError.serverUnavailable.errorDescription; return }
        let wasConnected = status.isActive
        selectedServer = server
        if wasConnected { Task { await reconnect(to: server) } }
    }

    /// Convenience: tap a server anywhere → connect to it right away (или
    /// переподключиться, если уже на связи). One tap, no extra steps.
    public func connectTo(_ server: Server) {
        guard server.available else { errorMessage = AppError.serverUnavailable.errorDescription; return }
        selectedServer = server
        Task {
            if status.isActive { await reconnect(to: server) } else { await connect() }
        }
    }

    private func reconnect(to server: Server) async {
        await tunnel.disconnect()
        try? await Task.sleep(nanoseconds: 300_000_000)
        await connect()
    }

    // MARK: - Ping & auto-fastest

    /// Measures latency to every available server (concurrently) and stores results.
    public func pingAll() async {
        guard !isPinging else { return }
        isPinging = true
        defer { isPinging = false }
        let servers = availableServers
        await withTaskGroup(of: PingResult.self) { group in
            for s in servers { group.addTask { await self.pinger.ping(s) } }
            for await r in group { pings[r.serverId] = r }
        }
    }

    /// Fastest available server by measured ping (falls back to nominal pingMs).
    public var fastestServer: Server? {
        availableServers.min { a, b in
            (pings[a.id]?.ms ?? a.pingMs) < (pings[b.id]?.ms ?? b.pingMs)
        }
    }

    /// Connect, optionally to the fastest measured node (used by "Авто").
    public func connectFastest() async {
        if pings.isEmpty { await pingAll() }
        if let f = fastestServer { selectedServer = f }
        await connect()
    }

    // MARK: - BYO configs (import — Happ parity)

    @discardableResult
    public func addConfig(from text: String, source: ConfigSource) -> Bool {
        guard let cfg = ImportedConfig.parse(text, source: source) else {
            errorMessage = "Не распознал конфиг. Поддерживаются vless://, vmess://, trojan://, ss://, hysteria2:// и ссылки на подписку."
            return false
        }
        importedConfigs.insert(cfg, at: 0)
        persistConfigs()
        return true
    }

    public func removeConfig(_ cfg: ImportedConfig) {
        importedConfigs.removeAll { $0.id == cfg.id }
        persistConfigs()
    }

    // MARK: - Favorites / recents

    public func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
    }
    public func isFavorite(_ id: String) -> Bool { favorites.contains(id) }
    public var favoriteServers: [Server] { allServers.filter { favorites.contains($0.id) } }
    public var recentServers: [Server] { recents.compactMap { id in allServers.first { $0.id == id } } }
    private func pushRecent(_ id: String) {
        recents.removeAll { $0 == id }
        recents.insert(id, at: 0)
        if recents.count > 5 { recents.removeLast(recents.count - 5) }
    }

    // MARK: - Pause

    public var isPaused: Bool {
        guard let until = pausedUntil else { return false }
        return until > Date()
    }
    public func pause(minutes: Int) {
        pausedUntil = Date().addingTimeInterval(Double(minutes) * 60)
        addLog(.warn, "VPN на паузе \(minutes) мин")
        Task { await disconnect() }
    }
    public func resume() {
        pausedUntil = nil
        addLog(.info, "Пауза снята")
        Task { await connect() }
    }

    // MARK: - Use-case mode / multi-hop

    public func applyMode(_ mode: UseCaseMode) {
        addLog(.info, "Режим: \(mode.label)")
        if mode == .gaming || mode == .streaming { Task { await connectFastest() } }
    }
    public func setMultiHop(entry: Server?, exit: Server?) {
        multiHop = MultiHop(enabled: entry != nil && exit != nil, entryId: entry?.id, exitId: exit?.id)
        if let e = entry { addLog(.info, "Двойной VPN: \(e.city) → \(exit?.city ?? "—")") }
    }

    // MARK: - Gamification

    public var totalGB: Double { Double(lifetimeDown + lifetimeUp) / 1_073_741_824 }
    public var achievements: [Achievement] { Achievement.catalog(protectedDays: protectedDays, totalGB: totalGB) }

    // MARK: - Split tunnel / trusted nets

    public func toggleSplit(_ app: AppEntry) {
        if let i = splitApps.firstIndex(where: { $0.id == app.id }) { splitApps[i].excluded.toggle() }
    }
    public func addTrusted(_ ssid: String) {
        let s = ssid.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return }
        trustedNetworks.append(TrustedNetwork(ssid: s))
    }
    public func removeTrusted(_ n: TrustedNetwork) { trustedNetworks.removeAll { $0.id == n.id } }

    // MARK: - Scheduler

    public func addSchedule(_ rule: ScheduleRule) { schedules.append(rule) }
    public func removeSchedule(_ rule: ScheduleRule) { schedules.removeAll { $0.id == rule.id } }
    public func toggleSchedule(_ rule: ScheduleRule) {
        if let i = schedules.firstIndex(where: { $0.id == rule.id }) { schedules[i].enabled.toggle() }
    }

    // MARK: - Smart rules

    public func addRule(pattern: String, action: RuleAction) {
        let p = pattern.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty else { return }
        smartRules.insert(SmartRule(pattern: p, action: action), at: 0)
    }
    public func removeRule(_ rule: SmartRule) { smartRules.removeAll { $0.id == rule.id } }
    public func cycleRuleAction(_ rule: SmartRule) {
        guard let i = smartRules.firstIndex(where: { $0.id == rule.id }) else { return }
        let all = RuleAction.allCases
        let next = all[(all.firstIndex(of: smartRules[i].action)! + 1) % all.count]
        smartRules[i].action = next
    }

    // MARK: - Leak check

    public func runLeakCheck() async {
        guard !isCheckingLeak else { return }
        isCheckingLeak = true
        leak = nil
        addLog(.info, "Проверка утечек…")
        defer { isCheckingLeak = false }
        try? await Task.sleep(nanoseconds: 1_400_000_000)
        let r = isConnected ? LeakReport.demoProtected : LeakReport.demoExposed
        leak = r
        addLog(r.allSecure ? .success : .warn,
               r.allSecure ? "Утечек нет · IP скрыт" : "Внимание: возможны утечки — подключите VPN")
    }

    // MARK: - Diagnostics log

    public func addLog(_ level: LogLevel, _ text: String) {
        logs.insert(LogEntry(level: level, text: text), at: 0)
        if logs.count > 200 { logs.removeLast(logs.count - 200) }
    }
    public func clearLogs() { logs.removeAll() }

    // MARK: - Speed test

    public func runSpeedTest() async {
        guard !isSpeedTesting else { return }
        isSpeedTesting = true
        speedTestResult = nil
        addLog(.info, "Запуск спид-теста…")
        defer { isSpeedTesting = false }
        let r = await speedTester.run(via: selectedServer)
        speedTestResult = r
        speedHistory.insert(r, at: 0)
        if speedHistory.count > 10 { speedHistory.removeLast(speedHistory.count - 10) }
        addLog(.success, String(format: "Спид-тест: ↓%.0f / ↑%.0f Mbps · %d ms", r.downMbps, r.upMbps, r.pingMs))
    }

    // MARK: - Subscription

    public func renew(_ plan: Plan) async {
        do { subscription = try await api.renew(plan: plan) }
        catch { errorMessage = error.localizedDescription }
    }

    public func removeDevice(_ device: Device) async {
        do { try await api.removeDevice(device.id); devices.removeAll { $0.id == device.id } }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - VPNTunnelDelegate

    private var prevDown: Int64 = 0
    private var prevUp: Int64 = 0

    public func tunnel(_ tunnel: VPNTunnel, didChange status: VPNStatus) {
        let was = self.status
        self.status = status

        // Live Activity (Dynamic Island / Lock Screen) — no-op off iOS.
        if status == .connecting, was == .disconnected {
            LiveActivityController.shared.start(city: selectedServer?.city ?? "—",
                                                flag: selectedServer?.flag ?? "🌐")
        }
        LiveActivityController.shared.update(statusText: status.title, connected: status.isActive,
                                             down: stats.downloadBps, up: stats.uploadBps,
                                             startedAt: stats.connectedSince)

        // Diagnostics log lines (Hiddify-style)
        switch status {
        case .connecting where was == .disconnected:
            addLog(.info, "Подключение к \(selectedServer?.city ?? "серверу") · \(selectedServer?.proto.label ?? "")")
            addLog(.info, "Запуск ядра sing-box…")
        case .connected where was != .connected:
            addLog(.success, "Туннель установлен · IP \(stats.ip ?? "—")")
        case .disconnected where was != .disconnected && was != .connecting:
            addLog(.warn, "Соединение разорвано")
        default: break
        }

        if status == .connected, was != .connected {
            // open a new log entry
            prevDown = 0; prevUp = 0
            recentDown = Array(repeating: 0, count: 40)
            recentUp = Array(repeating: 0, count: 40)
            let entry = TrafficLogEntry(serverCity: selectedServer?.city ?? "—", start: Date())
            activeLogID = entry.id
            trafficLog.insert(entry, at: 0)
        } else if status == .disconnected, let id = activeLogID {
            if let i = trafficLog.firstIndex(where: { $0.id == id }) {
                trafficLog[i].end = Date()
            }
            activeLogID = nil
            persistLog()
            LiveActivityController.shared.end()
        }
    }

    public func tunnel(_ tunnel: VPNTunnel, didUpdate stats: ConnectionStats) {
        // Accumulate lifetime via deltas (session totals reset to 0 on disconnect).
        if stats.totalDown >= prevDown {
            lifetimeDown += stats.totalDown - prevDown
            lifetimeUp += stats.totalUp - prevUp
        }
        prevDown = stats.totalDown
        prevUp = stats.totalUp
        self.stats = stats
        // Feed the live chart (drop oldest, append newest).
        recentDown.removeFirst(); recentDown.append(stats.downloadBps)
        recentUp.removeFirst(); recentUp.append(stats.uploadBps)
        if let id = activeLogID, let i = trafficLog.firstIndex(where: { $0.id == id }) {
            trafficLog[i].bytesDown = stats.totalDown
            trafficLog[i].bytesUp = stats.totalUp
        }
        if status.isActive {
            LiveActivityController.shared.update(statusText: status.title, connected: true,
                                                 down: stats.downloadBps, up: stats.uploadBps,
                                                 startedAt: stats.connectedSince)
        }
    }

    // MARK: - Session clock

    private func startClock() {
        clockCancellable = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if let since = self.stats.connectedSince, self.status.isActive {
                    self.elapsed = Date().timeIntervalSince(since)
                } else {
                    self.elapsed = 0
                }
            }
    }

    public var sessionTime: String { Fmt.duration(elapsed) }
}

// MARK: - Persisted user preferences

/// Uses @Published (so the UI updates live — @AppStorage inside an
/// ObservableObject does NOT emit objectWillChange) with manual UserDefaults
/// persistence via didSet.
@MainActor
public final class Settings: ObservableObject {
    private let d = UserDefaults.standard

    @Published public var theme: AppTheme { didSet { d.set(theme.rawValue, forKey: "bitaps.theme") } }
    @Published public var accent: AccentTheme {
        didSet { d.set(accent.rawValue, forKey: "bitaps.accent"); BitColor.accentTheme = accent }
    }
    @Published public var connectButton: ConnectButtonStyle { didSet { d.set(connectButton.rawValue, forKey: "bitaps.connbtn") } }
    @Published public var useCase: UseCaseMode { didSet { d.set(useCase.rawValue, forKey: "bitaps.usecase") } }
    @Published public var appIcon: AppIconOption { didSet { d.set(appIcon.rawValue, forKey: "bitaps.appicon") } }
    @Published public var appLock: Bool { didSet { d.set(appLock, forKey: "bitaps.applock") } }
    @Published public var notifyDrop: Bool { didSet { d.set(notifyDrop, forKey: "bitaps.ntfdrop") } }
    @Published public var notifyExpiry: Bool { didSet { d.set(notifyExpiry, forKey: "bitaps.ntfexp") } }
    @Published public var notifyData: Bool { didSet { d.set(notifyData, forKey: "bitaps.ntfdata") } }
    @Published public var routingMode: RoutingMode { didSet { d.set(routingMode.rawValue, forKey: "bitaps.routing") } }
    @Published public var connectionMode: ConnectionMode { didSet { d.set(connectionMode.rawValue, forKey: "bitaps.connmode") } }
    @Published public var autoConnectFastest: Bool { didSet { d.set(autoConnectFastest, forKey: "bitaps.autofastest") } }
    @Published public var proto: TunnelProtocol { didSet { d.set(proto.rawValue, forKey: "bitaps.protocol") } }

    // Advanced network (Hiddify parity)
    @Published public var bypassLAN: Bool { didSet { d.set(bypassLAN, forKey: "bitaps.bypasslan") } }
    @Published public var ipv6: Bool { didSet { d.set(ipv6, forKey: "bitaps.ipv6") } }
    @Published public var mux: Bool { didSet { d.set(mux, forKey: "bitaps.mux") } }
    @Published public var tlsFragment: Bool { didSet { d.set(tlsFragment, forKey: "bitaps.tlsfrag") } }
    @Published public var warp: Bool { didSet { d.set(warp, forKey: "bitaps.warp") } }
    @Published public var mtu: Int { didSet { d.set(mtu, forKey: "bitaps.mtu") } }
    @Published public var remoteDNS: String { didSet { d.set(remoteDNS, forKey: "bitaps.rdns") } }
    @Published public var directDNS: String { didSet { d.set(directDNS, forKey: "bitaps.ddns") } }
    @Published public var domainStrategy: DomainStrategy { didSet { d.set(domainStrategy.rawValue, forKey: "bitaps.domstrat") } }
    @Published public var autoConnect: Bool { didSet { d.set(autoConnect, forKey: "bitaps.autoconnect") } }
    @Published public var killSwitch: Bool { didSet { d.set(killSwitch, forKey: "bitaps.killswitch") } }
    @Published public var connectOnLaunch: Bool { didSet { d.set(connectOnLaunch, forKey: "bitaps.connectOnLaunch") } }
    @Published public var notifications: Bool { didSet { d.set(notifications, forKey: "bitaps.notifications") } }
    @Published public var dns: String { didSet { d.set(dns, forKey: "bitaps.dns") } }
    @Published public var language: String { didSet { d.set(language, forKey: "bitaps.language") } }

    public init() {
        let d = UserDefaults.standard
        theme = AppTheme(rawValue: d.string(forKey: "bitaps.theme") ?? "") ?? .dark
        let acc = AccentTheme(rawValue: d.string(forKey: "bitaps.accent") ?? "") ?? .sunset
        accent = acc
        BitColor.accentTheme = acc
        connectButton = ConnectButtonStyle(rawValue: d.string(forKey: "bitaps.connbtn") ?? "") ?? .ring
        useCase = UseCaseMode(rawValue: d.string(forKey: "bitaps.usecase") ?? "") ?? .auto
        appIcon = AppIconOption(rawValue: d.string(forKey: "bitaps.appicon") ?? "") ?? .classic
        appLock = d.bool(forKey: "bitaps.applock")
        notifyDrop = d.object(forKey: "bitaps.ntfdrop") as? Bool ?? true
        notifyExpiry = d.object(forKey: "bitaps.ntfexp") as? Bool ?? true
        notifyData = d.bool(forKey: "bitaps.ntfdata")
        routingMode = RoutingMode(rawValue: d.string(forKey: "bitaps.routing") ?? "") ?? .bypassRu
        connectionMode = ConnectionMode(rawValue: d.string(forKey: "bitaps.connmode") ?? "") ?? .proxy
        autoConnectFastest = d.bool(forKey: "bitaps.autofastest")
        proto = TunnelProtocol(rawValue: d.string(forKey: "bitaps.protocol") ?? "") ?? .auto
        bypassLAN = d.object(forKey: "bitaps.bypasslan") as? Bool ?? true
        ipv6 = d.bool(forKey: "bitaps.ipv6")
        mux = d.bool(forKey: "bitaps.mux")
        tlsFragment = d.object(forKey: "bitaps.tlsfrag") as? Bool ?? true
        warp = d.bool(forKey: "bitaps.warp")
        mtu = d.object(forKey: "bitaps.mtu") as? Int ?? 1500
        remoteDNS = d.string(forKey: "bitaps.rdns") ?? "https://1.1.1.1/dns-query"
        directDNS = d.string(forKey: "bitaps.ddns") ?? "8.8.8.8"
        domainStrategy = DomainStrategy(rawValue: d.string(forKey: "bitaps.domstrat") ?? "") ?? .preferIPv4
        autoConnect = d.bool(forKey: "bitaps.autoconnect")
        killSwitch = d.object(forKey: "bitaps.killswitch") as? Bool ?? true
        connectOnLaunch = d.bool(forKey: "bitaps.connectOnLaunch")
        notifications = d.object(forKey: "bitaps.notifications") as? Bool ?? true
        dns = d.string(forKey: "bitaps.dns") ?? "Авто (через VPN)"
        language = d.string(forKey: "bitaps.language") ?? "Русский"
    }
}
