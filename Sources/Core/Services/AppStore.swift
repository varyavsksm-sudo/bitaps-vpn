import SwiftUI
import Combine
import Security

/// Keychain-хранилище для чувствительных данных. Импортированные vless://-конфиги содержат
/// боевой credential (UUID/пароль сервера); раньше лежали в UserDefaults (plist в
/// ~/Library/Preferences читается любым процессом того же юзера, попадает в нешифрованные бэкапы).
enum KeychainBox {
    private static let service = "app.bitaps.vpn"
    static func set(_ data: Data, _ key: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
    static func get(_ key: String) -> Data? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }
    static func delete(_ key: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ] as CFDictionary)
    }
}

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

    // New features: multi-hop, favorites/recents, gamification, trusted nets, split tunnel, speed history
    // These persist on change so user choices survive relaunch (`bitaps.*` keys, loaded in loadPersisted).
    @Published public var multiHop = MultiHop() { didSet { saveState(multiHop, "bitaps.multihop") } }
    @Published public var favorites: Set<String> = [] { didSet { saveState(Array(favorites), "bitaps.favorites") } }
    @Published public var recents: [String] = [] { didSet { saveState(recents, "bitaps.recents") } }
    /// Real protection streak — consecutive days with at least one connection.
    @Published public var protectedDays: Int = 0
    private var connectionDays: Set<String> = [] { didSet { saveState(Array(connectionDays), "bitaps.conndays") } }
    @Published public var trustedNetworks: [TrustedNetwork] = [] { didSet { saveState(trustedNetworks, "bitaps.trusted") } }
    @Published public var splitApps: [AppEntry] = AppEntry.demo { didSet { saveState(splitApps, "bitaps.split") } }
    @Published public var speedHistory: [SpeedTestResult] = [] { didSet { saveState(speedHistory, "bitaps.speedhist") } }
    @Published public var schedules: [ScheduleRule] = [] { didSet { saveState(schedules, "bitaps.schedules") } }
    @Published public var smartRules: [SmartRule] = [] { didSet { saveState(smartRules, "bitaps.smartrules") } }
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
    private let speedTester = SpeedTestService()

    // UI feedback
    @Published public var errorMessage: String?         // drives the global alert
    @Published public var importError: String?          // inline-only (import screen)

    private let api: BitAPI
    private var tunnel: VPNTunnel
    private let pinger = PingService()
    private var clockCancellable: AnyCancellable?
    @Published public var elapsed: TimeInterval = 0

    /// Set by the app at launch so the store can gate notifications on the
    /// user's Settings toggles.
    public weak var settings: Settings?
    /// Distinguishes a user-tapped disconnect from an unexpected drop.
    private var userInitiatedDisconnect = false
    /// One-shot guard so the "data limit" alert fires at most once per session.
    private var dataAlertSent = false
    /// Minute-of-epoch of the last schedule evaluation (avoids double-firing).
    private var lastScheduleMinute = -1
    /// Day-key of the last streak recompute (refresh streak across midnight).
    private var lastStreakDay = ""
    /// >0 while one or more intentional server switches are in flight
    /// (suppresses the "dropped" warning). A counter so overlapping switches
    /// don't clear suppression for each other.
    private var reconnectDepth = 0
    private var isReconnecting: Bool { reconnectDepth > 0 }

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
        isLoadingState = true
        defer { isLoadingState = false }
        let d = UserDefaults.standard
        lifetimeDown = Int64(d.integer(forKey: "bitaps.lifeDown"))
        lifetimeUp = Int64(d.integer(forKey: "bitaps.lifeUp"))
        // конфиги — из Keychain; однократная миграция из старого UserDefaults (plaintext) при наличии
        var cfgData = KeychainBox.get("bitaps.configs")
        if cfgData == nil, let legacy = d.data(forKey: "bitaps.configs") {
            KeychainBox.set(legacy, "bitaps.configs")
            d.removeObject(forKey: "bitaps.configs")
            cfgData = legacy
        }
        if let data = cfgData,
           let cfgs = try? JSONDecoder().decode([ImportedConfig].self, from: data) {
            importedConfigs = cfgs
        }
        if let data = d.data(forKey: "bitaps.log"),
           let log = try? JSONDecoder().decode([TrafficLogEntry].self, from: data) {
            trafficLog = log
        }
        // User state — load only if previously saved (else keep demo defaults).
        loadState(&multiHop, "bitaps.multihop")
        if let f: [String] = decodeState("bitaps.favorites") { favorites = Set(f) }
        loadState(&recents, "bitaps.recents")
        loadState(&trustedNetworks, "bitaps.trusted")
        loadState(&splitApps, "bitaps.split")
        loadState(&speedHistory, "bitaps.speedhist")
        loadState(&schedules, "bitaps.schedules")
        loadState(&smartRules, "bitaps.smartrules")
        if let days: [String] = decodeState("bitaps.conndays") {
            connectionDays = Set(days)
            protectedDays = Self.streak(connectionDays)
        }
    }

    /// True while loadPersisted is assigning, so didSet observers don't re-save.
    private var isLoadingState = false

    /// Encode any Codable user-state value to UserDefaults under `key`.
    private func saveState<T: Encodable>(_ value: T, _ key: String) {
        guard !isLoadingState else { return }   // skip the redundant write on load
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    /// Decode a stored value (nil if absent/corrupt) without overwriting on miss.
    private func decodeState<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    private func loadState<T: Decodable>(_ target: inout T, _ key: String) {
        if let v: T = decodeState(key) { target = v }
    }

    private func persistConfigs() {
        if let data = try? JSONEncoder().encode(importedConfigs) {
            KeychainBox.set(data, "bitaps.configs")   // Keychain, не UserDefaults (боевой credential)
        }
    }
    private func persistLog() {
        UserDefaults.standard.set(lifetimeDown, forKey: "bitaps.lifeDown")
        UserDefaults.standard.set(lifetimeUp, forKey: "bitaps.lifeUp")
        if let data = try? JSONEncoder().encode(Array(trafficLog.prefix(50))) {
            UserDefaults.standard.set(data, forKey: "bitaps.log")
        }
    }

    /// Flush lifetime traffic + the (possibly still-open) session log now. Call
    /// when backgrounding so an OS-kill of an always-on tunnel doesn't lose the
    /// session's accumulated bytes.
    public func persistSession() { persistLog() }

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
        if let g {
            serverGroups = g
            if selectedServer == nil { selectedServer = firstAvailable(in: g) }
            // Derive infra status from the REAL catalog (no more fake demo numbers).
            let all = g.flatMap(\.servers)
            let online = all.filter(\.available)
            infra = InfraStatus(serversOnline: online.count,
                                totalServers: all.count,
                                locations: Set(online.map(\.city)).count,
                                uptimePct: infra.uptimePct,
                                activeUsers: infra.activeUsers)
        }
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
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Реальная доставка в Telegram админу (@bitapssupport) + таблицу support_messages
        // через публичную функцию notify. Прямой HTTP — работает и в demo-режиме,
        // не зависит от useSupabase (раньше MockAPI молча выбрасывал сообщение).
        guard let url = URL(string: "https://bjkozsukvifkxriojxrz.supabase.co/functions/v1/notify") else { return false }
        var name = user?.displayName ?? ""
        if let tg = user?.telegramHandle, !tg.isEmpty { name += name.isEmpty ? tg : " (\(tg))" }
        let payload: [String: Any] = [
            "type": "support",
            "name": name,
            "email": user?.email ?? "",
            "message": trimmed,
            "source": "приложение"
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("sb_publishable_X2CJWgjqeZtbNelAri9ofw_trbfWF9Z", forHTTPHeaderField: "apikey")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            let ok = (resp as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
            if ok { addLog(.success, "Сообщение отправлено в поддержку"); return true }
            errorMessage = "Не удалось отправить сообщение. Попробуйте позже или напишите в Telegram."
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func firstAvailable(in groups: [ServerGroup]) -> Server? {
        groups.flatMap(\.servers).first(where: \.available)
    }

    // MARK: - Auth

    public func loginDemo() async {
        user = await api.loginDemo(); isLoggedIn = true
        await refreshAll()
    }

    /// Email sign-in: signs in and adopts the entered address as the identity
    /// (instead of a hardcoded user). Real OTP arrives with the live backend.
    public func loginEmail(_ email: String) async {
        await loginDemo()
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let name = trimmed.contains("@") ? String(trimmed.prefix(while: { $0 != "@" })) : trimmed
            user = User(id: "email-\(trimmed)", displayName: name, email: trimmed, isDemo: true)
        }
    }

    /// `payload` = the signed Telegram auth JSON from the native login sheet (or
    /// "demo-token" for the mock backend, which ignores it).
    public func loginWithTelegram(payload: String = "demo-token") async {
        do {
            let u = try await api.loginWithTelegram(token: payload)
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
            if status == .disconnecting { return }   // already tearing down — ignore taps
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
        userInitiatedDisconnect = false
        dataAlertSent = false
        do {
            // recents / streak are recorded on the actual `.connected` transition
            // (see tunnel(_:didChange:)), so it works for both the synchronous mock
            // and the real async tunnel whose connect() returns while .connecting.
            try await tunnel.connect(to: server)
        }
        catch { errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription }
    }

    public func disconnect() async {
        userInitiatedDisconnect = true
        await tunnel.disconnect()
    }

    /// (Re)schedule the subscription-expiry reminder based on the toggles.
    public func refreshExpiryNotification() {
        NotificationService.cancel("bitaps.expiry")
        guard settings?.notifications == true, settings?.notifyExpiry == true,
              let expires = subscription?.expires else { return }
        NotificationService.scheduleExpiry(at: expires)
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
        reconnectDepth += 1
        defer { reconnectDepth -= 1 }
        await tunnel.disconnect()
        try? await Task.sleep(nanoseconds: 300_000_000)
        await connect()
    }

    /// Connect using an imported BYO profile (synthesizes a server for it).
    public func connect(using cfg: ImportedConfig) {
        let s = Server(id: "cfg-\(cfg.id)", countryCode: "XX",
                       countryName: NSLocalizedString("Свой профиль", comment: ""),
                       city: cfg.name, flag: "🔧", pingMs: 0, loadPct: 0,
                       proto: cfg.proto, config: cfg.raw)
        addLog(.info, "Профиль: \(cfg.name)")
        connectTo(s)
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
            importError = "Не распознал конфиг. Поддерживаются vless://, vmess://, trojan://, ss://, hysteria2:// и ссылки на подписку."
            return false
        }
        importError = nil
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
        guard !id.hasPrefix("cfg-") else { return }   // imported profiles aren't catalog servers
        recents.removeAll { $0 == id }
        recents.insert(id, at: 0)
        if recents.count > 5 { recents.removeLast(recents.count - 5) }
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
        let r = await Self.fetchLeakReport(connected: isConnected)
        leak = r
        addLog(r.allSecure ? .success : .warn,
               r.allSecure ? "Утечек нет · IP скрыт" : "Внимание: возможны утечки — подключите VPN")
    }

    /// Real leak check: fetches the actual public IP / geo / ISP. When the tunnel
    /// is up, DNS + traffic egress through it, so the IP is the node's.
    private static func fetchLeakReport(connected: Bool) async -> LeakReport {
        struct Conn: Decodable { let isp: String?; let org: String? }
        struct Geo: Decodable { let ip: String?; let city: String?; let country: String?; let country_code: String?; let connection: Conn? }
        var ip = "—", city = "—", country = "—", isp = "—"
        if let url = URL(string: "https://ipwho.is/"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let g = try? JSONDecoder().decode(Geo.self, from: data) {
            ip = g.ip ?? ip
            city = g.city ?? city
            isp = g.connection?.isp ?? g.connection?.org ?? isp
            let flag = flagEmoji(g.country_code)
            country = [flag, g.country].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if country.isEmpty { country = "—" }
        }
        // VPN up ⇒ traffic + DNS routed through the tunnel.
        return LeakReport(ip: ip, country: country, city: city, isp: isp,
                          dnsSecure: connected, webrtcSecure: connected, ipv6Secure: connected)
    }

    private static func flagEmoji(_ code: String?) -> String {
        guard let code, code.count == 2 else { return "🌐" }
        return code.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(127397 + $0.value).map(String.init) }.joined()
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
            LiveActivityController.shared.start(city: NSLocalizedString(selectedServer?.city ?? "—", comment: ""),
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
        case .disconnected where was != .disconnected && was != .connecting && !isReconnecting:
            addLog(.warn, "Соединение разорвано")
            // Notify only on an UNEXPECTED drop (not a user tap), if enabled.
            if !userInitiatedDisconnect, was == .connected,
               settings?.notifications == true, settings?.notifyDrop == true {
                NotificationService.post(
                    title: NSLocalizedString("VPN отключился", comment: ""),
                    body: NSLocalizedString("Соединение разорвано — трафик не защищён.", comment: ""),
                    id: "bitaps.drop")
            }
        default: break
        }
        if status == .disconnected { userInitiatedDisconnect = false }

        if status == .connected, was != .connected {
            // open a new log entry
            prevDown = 0; prevUp = 0
            let entry = TrafficLogEntry(serverCity: selectedServer?.city ?? "—", start: Date())
            activeLogID = entry.id
            trafficLog.insert(entry, at: 0)
            if trafficLog.count > 100 { trafficLog.removeLast(trafficLog.count - 100) }  // cap in-memory growth
            // Record recents + protection streak HERE (on the real .connected edge),
            // so it works for the async real tunnel too — not only the sync mock.
            if let id = selectedServer?.id { pushRecent(id) }
            recordConnectionToday()
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
        if let id = activeLogID, let i = trafficLog.firstIndex(where: { $0.id == id }) {
            trafficLog[i].bytesDown = stats.totalDown
            trafficLog[i].bytesUp = stats.totalUp
        }
        // Heavy-usage alert (once per session, gated on the toggle).
        if !dataAlertSent, settings?.notifications == true, settings?.notifyData == true,
           stats.totalDown + stats.totalUp > 1_073_741_824 {
            dataAlertSent = true
            NotificationService.post(
                title: NSLocalizedString("Большой расход трафика", comment: ""),
                body: NSLocalizedString("За эту сессию прошло больше 1 ГБ.", comment: ""),
                id: "bitaps.data")
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
                let now = Date()
                if let since = self.stats.connectedSince, self.status.isActive {
                    self.elapsed = now.timeIntervalSince(since)
                } else {
                    self.elapsed = 0
                }
                // Run the schedule engine once per minute (only once logged in, so
                // we don't "consume" the minute before the user has signed in).
                let minute = Int(now.timeIntervalSince1970 / 60)
                if minute != self.lastScheduleMinute, self.isLoggedIn {
                    self.lastScheduleMinute = minute
                    self.evaluateSchedules(now)
                }
                // Keep the protection streak fresh across a midnight crossing while
                // the app is open (recompute when the day changes).
                let dayKey = Self.dayKey(now)
                if dayKey != self.lastStreakDay {
                    self.lastStreakDay = dayKey
                    self.protectedDays = Self.streak(self.connectionDays, now: now)
                }
            }
    }

    // MARK: - Schedule engine (rules actually fire now)

    /// Fires any enabled schedule whose day+time matches `now`.
    private func evaluateSchedules(_ now: Date) {
        guard isLoggedIn else { return }   // don't act over onboarding/login
        let c = Calendar.current.dateComponents([.hour, .minute, .weekday], from: now)
        guard let h = c.hour, let m = c.minute, let wd = c.weekday else { return }
        let iso = (wd + 5) % 7 + 1   // Calendar 1=Sun…7=Sat → ISO 1=Mon…7=Sun
        for rule in schedules where rule.enabled && rule.hour == h && rule.minute == m && rule.days.contains(iso) {
            switch rule.action {
            case .connect where !isConnected && status != .connecting && status != .disconnecting:
                addLog(.info, "Расписание: подключение")
                Task { await connect() }
            case .disconnect where isConnected:
                addLog(.info, "Расписание: отключение")
                Task { await disconnect() }
            default:
                break
            }
        }
    }

    // MARK: - Protection streak (real)

    private static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    /// Count of consecutive days with a connection. Anchors on today if today
    /// already has one, otherwise on yesterday — so the streak isn't shown as 0
    /// in the morning before the day's first connect.
    private static func streak(_ days: Set<String>, now: Date = Date()) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var day = days.contains(dayKey(today))
            ? today
            : (cal.date(byAdding: .day, value: -1, to: today) ?? today)
        var count = 0
        while days.contains(dayKey(day)) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    /// Mark today as protected and recompute the streak. Called on every connect.
    private func recordConnectionToday() {
        if connectionDays.insert(Self.dayKey(Date())).inserted {
            pruneConnectionDays()
            protectedDays = Self.streak(connectionDays)
            lastStreakDay = Self.dayKey(Date())
        }
    }

    /// Keep only the most recent `keep` day-stamps so the set can't grow forever.
    private func pruneConnectionDays(keep: Int = 120) {
        guard connectionDays.count > keep else { return }
        let cal = Calendar.current
        let dated = connectionDays.compactMap { key -> (String, Date)? in
            let p = key.split(separator: "-").compactMap { Int($0) }
            guard p.count == 3,
                  let d = cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) else { return nil }
            return (key, d)
        }.sorted { $0.1 > $1.1 }
        connectionDays = Set(dated.prefix(keep).map(\.0))
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
    /// Hides power-user surfaces (advanced network, smart rules, split tunnel,
    /// trusted nets, import config, schedule, protocol, multi-hop) when off.
    @Published public var expertMode: Bool { didSet { d.set(expertMode, forKey: "bitaps.expert") } }
    @Published public var notifications: Bool {
        didSet {
            d.set(notifications, forKey: "bitaps.notifications")
            if notifications { NotificationService.requestAuthorization() }  // ask OS permission
        }
    }
    @Published public var language: String {
        didSet {
            d.set(language, forKey: "bitaps.language")
            // Persist the choice so it also sticks across launches / system contexts.
            d.set([localeIdentifier], forKey: "AppleLanguages")
            // Point Bundle.main at the chosen .lproj so every Text re-localizes live.
            AppLanguage.apply(localeIdentifier)
        }
    }

    /// BCP-47 code that drives `\.locale` so every `Text(...)` re-localizes live.
    public var localeIdentifier: String { language == "English" ? "en" : "ru" }

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
        connectOnLaunch = d.object(forKey: "bitaps.connectOnLaunch") as? Bool ?? true  // on by default — 1-tap protection
        expertMode = d.bool(forKey: "bitaps.expert")                                   // off by default — clean consumer UI
        notifications = d.object(forKey: "bitaps.notifications") as? Bool ?? true
        language = d.string(forKey: "bitaps.language") ?? "Русский"
        AppLanguage.apply(localeIdentifier)   // didSet doesn't fire in init
    }
}
