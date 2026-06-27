import Foundation

// MARK: - VPN connection state

/// Lifecycle of the tunnel. Mirrors NEVPNStatus but is our own type so the UI
/// layer never imports NetworkExtension directly.
public enum VPNStatus: String, Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case reasserting   // re-establishing after network change

    public var isBusy: Bool { self == .connecting || self == .disconnecting || self == .reasserting }
    public var isActive: Bool { self == .connected || self == .reasserting }

    public var title: String {
        switch self {
        case .disconnected:  return NSLocalizedString("Отключено", comment: "")
        case .connecting:    return NSLocalizedString("Подключение…", comment: "")
        case .connected:     return NSLocalizedString("Подключено", comment: "")
        case .disconnecting: return NSLocalizedString("Отключение…", comment: "")
        case .reasserting:   return NSLocalizedString("Переподключение…", comment: "")
        }
    }
}

/// Live counters surfaced on the connect screen.
public struct ConnectionStats: Equatable, Sendable {
    public var downloadBps: Double   // bytes / second
    public var uploadBps: Double
    public var totalDown: Int64      // bytes this session
    public var totalUp: Int64
    public var ip: String?
    public var connectedSince: Date?

    public init(downloadBps: Double = 0, uploadBps: Double = 0,
                totalDown: Int64 = 0, totalUp: Int64 = 0,
                ip: String? = nil, connectedSince: Date? = nil) {
        self.downloadBps = downloadBps
        self.uploadBps = uploadBps
        self.totalDown = totalDown
        self.totalUp = totalUp
        self.ip = ip
        self.connectedSince = connectedSince
    }

    public static let zero = ConnectionStats()
}

// MARK: - Servers

public enum TunnelProtocol: String, Codable, Sendable, CaseIterable, Identifiable {
    case auto       // pick best for the node
    case reality    // VLESS + Reality (sing-box) — primary, DPI-resistant
    case vmess
    case trojan
    case shadowsocks
    case hysteria2
    case wireguard  // fallback for foreign nodes

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .auto:        return NSLocalizedString("Авто", comment: "")
        case .reality:     return "VLESS + Reality"
        case .vmess:       return "VMess"
        case .trojan:      return "Trojan"
        case .shadowsocks: return "Shadowsocks"
        case .hysteria2:   return "Hysteria2"
        case .wireguard:   return "WireGuard"
        }
    }
    /// Subset we expose as the primary choice in Settings (managed nodes).
    public static var primary: [TunnelProtocol] { [.auto, .reality, .wireguard] }
}

// MARK: - Routing

public enum RoutingMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case all        // everything through the tunnel
    case rules      // rule-based (geosite/geoip)
    case bypassRu   // foreign traffic via VPN, RU sites direct (fast, DPI-bypass)

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .all:      return NSLocalizedString("Весь трафик", comment: "")
        case .rules:    return NSLocalizedString("По правилам", comment: "")
        case .bypassRu: return NSLocalizedString("РФ напрямую", comment: "")
        }
    }
    public var detail: String {
        switch self {
        case .all:      return NSLocalizedString("Всё идёт через VPN — максимальная приватность", comment: "")
        case .rules:    return NSLocalizedString("Гибкие правила geosite/geoip", comment: "")
        case .bypassRu: return NSLocalizedString("Зарубежное — через VPN, российские сайты — напрямую (быстрее)", comment: "")
        }
    }
    public var systemImage: String {
        switch self {
        case .all:      return "globe"
        case .rules:    return "slider.horizontal.3"
        case .bypassRu: return "arrow.triangle.branch"
        }
    }
}

// MARK: - Imported (BYO) configs — power-user parity with Happ

public enum ConfigSource: String, Sendable, Codable {
    case link, qr, clipboard, subscription
    public var label: String {
        switch self {
        case .link:         return NSLocalizedString("Ссылка", comment: "")
        case .qr:           return NSLocalizedString("QR-код", comment: "")
        case .clipboard:    return NSLocalizedString("Буфер обмена", comment: "")
        case .subscription: return NSLocalizedString("Подписка", comment: "")
        }
    }
}

public struct ImportedConfig: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public var name: String
    public var proto: TunnelProtocol
    public var raw: String           // vless:// … / ss:// … / subscription URL
    public var source: ConfigSource
    public var addedAt: Date

    public init(id: String = UUID().uuidString, name: String, proto: TunnelProtocol,
                raw: String, source: ConfigSource, addedAt: Date = Date()) {
        self.id = id; self.name = name; self.proto = proto
        self.raw = raw; self.source = source; self.addedAt = addedAt
    }

    /// Best-effort parse of a proxy URI to detect protocol + a display name.
    public static func parse(_ text: String, source: ConfigSource) -> ImportedConfig? {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let scheme = s.split(separator: ":").first.map(String.init)?.lowercased() else { return nil }
        let proto: TunnelProtocol
        switch scheme {
        case "vless":               proto = .reality
        case "vmess":               proto = .vmess
        case "trojan":              proto = .trojan
        case "ss", "shadowsocks":   proto = .shadowsocks
        case "hysteria2", "hy2":    proto = .hysteria2
        case "wireguard", "wg":     proto = .wireguard
        case "http", "https":       proto = .auto   // subscription URL
        default: return nil
        }
        // name from #fragment if present
        let frag = s.components(separatedBy: "#").dropFirst().joined(separator: "#")
        let name = frag.removingPercentEncoding?.nilIfEmpty
            ?? (scheme == "http" || scheme == "https" ? NSLocalizedString("Подписка", comment: "") : proto.label)
        let src: ConfigSource = (scheme == "http" || scheme == "https") ? .subscription : source
        return ImportedConfig(name: name, proto: proto, raw: s, source: src)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Ping / latency

public struct PingResult: Identifiable, Equatable, Sendable {
    public var id: String { serverId }
    public let serverId: String
    public let ms: Int?     // nil => timeout/unreachable
    public init(serverId: String, ms: Int?) { self.serverId = serverId; self.ms = ms }
    public var ok: Bool { ms != nil }
}

// MARK: - Connect button style (customizable hero button)

public enum ConnectButtonStyle: String, CaseIterable, Identifiable, Sendable, Codable {
    case ring     // glowing ring + power glyph (default)
    case gear     // the bitaps gear spins
    case orb      // filled glowing orb with pulse waves
    case pulse    // minimal glyph + concentric pulsing rings
    case arc      // speedometer-style gauge arc

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .ring:  return NSLocalizedString("Кольцо", comment: "")
        case .gear:  return NSLocalizedString("Шестерёнка", comment: "")
        case .orb:   return NSLocalizedString("Сфера", comment: "")
        case .pulse: return NSLocalizedString("Пульс", comment: "")
        case .arc:   return NSLocalizedString("Дуга", comment: "")
        }
    }
}

// MARK: - Use-case modes (one-tap presets — convenience + individuality)

public enum UseCaseMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case auto, streaming, gaming, privacy, work
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .auto: return NSLocalizedString("Авто", comment: ""); case .streaming: return NSLocalizedString("Стриминг", comment: "")
        case .gaming: return NSLocalizedString("Игры", comment: ""); case .privacy: return NSLocalizedString("Приватность", comment: ""); case .work: return NSLocalizedString("Работа", comment: "")
        }
    }
    public var icon: String {
        switch self {
        case .auto: return "wand.and.stars"; case .streaming: return "play.tv.fill"
        case .gaming: return "gamecontroller.fill"; case .privacy: return "lock.shield.fill"; case .work: return "briefcase.fill"
        }
    }
    public var tagline: String {
        switch self {
        case .auto: return NSLocalizedString("Сами подберём лучший узел и правила", comment: "")
        case .streaming: return NSLocalizedString("4K без буферизации, разблок сервисов", comment: "")
        case .gaming: return NSLocalizedString("Минимальный пинг, без потерь пакетов", comment: "")
        case .privacy: return NSLocalizedString("Максимум шифрования и анонимности", comment: "")
        case .work: return NSLocalizedString("Стабильный канал, тихий фон", comment: "")
        }
    }
    public var chipIndex: Int {
        switch self { case .auto: return 0; case .streaming: return 3; case .gaming: return 4; case .privacy: return 1; case .work: return 2 }
    }
}

// MARK: - Multi-hop (Double VPN)

public struct MultiHop: Equatable, Sendable, Codable {
    public var enabled: Bool
    public var entryId: String?
    public var exitId: String?
    public init(enabled: Bool = false, entryId: String? = nil, exitId: String? = nil) {
        self.enabled = enabled; self.entryId = entryId; self.exitId = exitId
    }
}

// MARK: - Gamification

public struct Achievement: Identifiable, Equatable, Sendable {
    public let id: String
    public let icon: String
    public let title: String
    public let detail: String
    public var unlocked: Bool
    public init(id: String, icon: String, title: String, detail: String, unlocked: Bool) {
        self.id = id; self.icon = icon; self.title = title; self.detail = detail; self.unlocked = unlocked
    }
    public static func catalog(protectedDays: Int, totalGB: Double) -> [Achievement] {
        [
            Achievement(id: "first", icon: "bolt.fill", title: NSLocalizedString("Первое подключение", comment: ""), detail: NSLocalizedString("Запустил bitaps", comment: ""), unlocked: true),
            Achievement(id: "week", icon: "flame.fill", title: NSLocalizedString("Неделя под защитой", comment: ""), detail: NSLocalizedString("7 дней подряд", comment: ""), unlocked: protectedDays >= 7),
            Achievement(id: "month", icon: "crown.fill", title: NSLocalizedString("Месяц без утечек", comment: ""), detail: NSLocalizedString("30 дней подряд", comment: ""), unlocked: protectedDays >= 30),
            Achievement(id: "gb10", icon: "arrow.down.circle.fill", title: NSLocalizedString("10 ГБ под щитом", comment: ""), detail: NSLocalizedString("Защищён трафик", comment: ""), unlocked: totalGB >= 10),
            Achievement(id: "gb100", icon: "shield.lefthalf.filled", title: NSLocalizedString("100 ГБ под щитом", comment: ""), detail: NSLocalizedString("Серьёзный объём", comment: ""), unlocked: totalGB >= 100),
            Achievement(id: "friends", icon: "person.2.fill", title: NSLocalizedString("Позвал друзей", comment: ""), detail: NSLocalizedString("Пригласил 3+", comment: ""), unlocked: false)
        ]
    }
}

// MARK: - Alternate app icons (personalization)

public enum AppIconOption: String, CaseIterable, Identifiable, Sendable, Codable {
    case classic, neon, emerald, lavender, crimson, mono
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .classic: return NSLocalizedString("Закат", comment: ""); case .neon: return NSLocalizedString("Неон", comment: ""); case .emerald: return NSLocalizedString("Изумруд", comment: "")
        case .lavender: return NSLocalizedString("Лаванда", comment: ""); case .crimson: return NSLocalizedString("Багровый", comment: ""); case .mono: return NSLocalizedString("Моно", comment: "")
        }
    }
    /// nil = primary icon; otherwise the alternate icon name (added in the asset/plist).
    public var altName: String? { self == .classic ? nil : "AppIcon-\(rawValue)" }
    public var hex: UInt32 {
        switch self {
        case .classic: return 0xff7a1a; case .neon: return 0x2de2ff; case .emerald: return 0x19d98a
        case .lavender: return 0xa779ff; case .crimson: return 0xff4d6d; case .mono: return 0x9aa3b2
        }
    }
}

// MARK: - Trusted networks & split tunnel

public struct TrustedNetwork: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public var ssid: String
    public init(id: String = UUID().uuidString, ssid: String) { self.id = id; self.ssid = ssid }
}

public struct AppEntry: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public var name: String
    public var symbol: String      // SF Symbol approximation
    public var excluded: Bool      // true => bypasses the tunnel
    public init(id: String = UUID().uuidString, name: String, symbol: String, excluded: Bool = false) {
        self.id = id; self.name = name; self.symbol = symbol; self.excluded = excluded
    }
    public static let demo: [AppEntry] = [
        AppEntry(name: NSLocalizedString("Сбербанк Онлайн", comment: ""), symbol: "rublesign.circle.fill", excluded: true),
        AppEntry(name: NSLocalizedString("Госуслуги", comment: ""), symbol: "building.columns.fill", excluded: true),
        AppEntry(name: "YouTube", symbol: "play.rectangle.fill"),
        AppEntry(name: "Telegram", symbol: "paperplane.fill"),
        AppEntry(name: "Safari", symbol: "safari.fill"),
        AppEntry(name: NSLocalizedString("Игры", comment: ""), symbol: "gamecontroller.fill")
    ]
}

// MARK: - Scheduler (auto connect/disconnect by time)

public enum ScheduleAction: String, CaseIterable, Identifiable, Sendable, Codable {
    case connect, disconnect
    public var id: String { rawValue }
    public var label: String { self == .connect ? NSLocalizedString("Подключить", comment: "") : NSLocalizedString("Отключить", comment: "") }
    public var icon: String { self == .connect ? "power" : "power.dotted" }
}

public struct ScheduleRule: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public var enabled: Bool
    public var action: ScheduleAction
    public var hour: Int
    public var minute: Int
    public var days: Set<Int>          // 1=Mon … 7=Sun
    public init(id: String = UUID().uuidString, enabled: Bool = true, action: ScheduleAction,
                hour: Int, minute: Int, days: Set<Int>) {
        self.id = id; self.enabled = enabled; self.action = action
        self.hour = hour; self.minute = minute; self.days = days
    }
    public var timeString: String { String(format: "%02d:%02d", hour, minute) }
    public var daysString: String {
        if days.count == 7 { return NSLocalizedString("Каждый день", comment: "") }
        if days == [1,2,3,4,5] { return NSLocalizedString("Будни", comment: "") }
        if days == [6,7] { return NSLocalizedString("Выходные", comment: "") }
        let names = [NSLocalizedString("Пн", comment: ""),NSLocalizedString("Вт", comment: ""),NSLocalizedString("Ср", comment: ""),NSLocalizedString("Чт", comment: ""),NSLocalizedString("Пт", comment: ""),NSLocalizedString("Сб", comment: ""),NSLocalizedString("Вс", comment: "")]
        return days.sorted().compactMap { $0 >= 1 && $0 <= 7 ? names[$0-1] : nil }.joined(separator: ", ")
    }
    public static let demo: [ScheduleRule] = [
        ScheduleRule(action: .connect, hour: 9, minute: 0, days: [1,2,3,4,5]),
        ScheduleRule(enabled: false, action: .disconnect, hour: 23, minute: 30, days: [1,2,3,4,5,6,7])
    ]
}

// MARK: - Smart routing rules (per domain / app)

public enum RuleAction: String, CaseIterable, Identifiable, Sendable, Codable {
    case viaVPN, direct, block
    public var id: String { rawValue }
    public var label: String {
        switch self { case .viaVPN: return NSLocalizedString("Через VPN", comment: ""); case .direct: return NSLocalizedString("Напрямую", comment: ""); case .block: return NSLocalizedString("Блок", comment: "") }
    }
    public var hex: UInt32 {
        switch self { case .viaVPN: return 0xff7a1a; case .direct: return 0x19c8a8; case .block: return 0xff4d6d }
    }
}

public struct SmartRule: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public var pattern: String         // domain or app name
    public var action: RuleAction
    public init(id: String = UUID().uuidString, pattern: String, action: RuleAction) {
        self.id = id; self.pattern = pattern; self.action = action
    }
    public static let demo: [SmartRule] = [
        SmartRule(pattern: "youtube.com", action: .viaVPN),
        SmartRule(pattern: "*.sberbank.ru", action: .direct),
        SmartRule(pattern: "gosuslugi.ru", action: .direct),
        SmartRule(pattern: "ads.doubleclick.net", action: .block)
    ]
}

// MARK: - Leak check / My IP

public struct LeakReport: Equatable, Sendable {
    public var ip: String
    public var country: String
    public var city: String
    public var isp: String
    public var dnsSecure: Bool
    public var webrtcSecure: Bool
    public var ipv6Secure: Bool
    public init(ip: String, country: String, city: String, isp: String,
                dnsSecure: Bool, webrtcSecure: Bool, ipv6Secure: Bool) {
        self.ip = ip; self.country = country; self.city = city; self.isp = isp
        self.dnsSecure = dnsSecure; self.webrtcSecure = webrtcSecure; self.ipv6Secure = ipv6Secure
    }
    public var allSecure: Bool { dnsSecure && webrtcSecure && ipv6Secure }
    public static let demoProtected = LeakReport(ip: "185.244.214.10", country: NSLocalizedString("🇳🇱 Нидерланды", comment: ""), city: NSLocalizedString("Амстердам", comment: ""),
        isp: "bitaps VPN", dnsSecure: true, webrtcSecure: true, ipv6Secure: true)
    public static let demoExposed = LeakReport(ip: "95.142.16.7", country: NSLocalizedString("🇷🇺 Россия", comment: ""), city: NSLocalizedString("Москва", comment: ""),
        isp: NSLocalizedString("Ростелеком", comment: ""), dnsSecure: false, webrtcSecure: true, ipv6Secure: false)
}

// MARK: - Accent themes — moved to Shared/AccentTheme.swift (shared with widget)

// MARK: - Diagnostics log (Hiddify-style)

public enum LogLevel: String, Sendable, Codable {
    case info, warn, error, success
    public var color: UInt32 {
        switch self {
        case .info:    return 0x8a96ab
        case .warn:    return 0xffae3d
        case .error:   return 0xff5470
        case .success: return 0x39d98a
        }
    }
}

public struct LogEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let time: Date
    public let level: LogLevel
    public let text: String
    public init(id: String = UUID().uuidString, time: Date = Date(), level: LogLevel, text: String) {
        self.id = id; self.time = time; self.level = level; self.text = text
    }
}

// MARK: - Speed test

public struct SpeedTestResult: Equatable, Sendable, Codable {
    public var downMbps: Double
    public var upMbps: Double
    public var pingMs: Int
    public var jitterMs: Int
    public var at: Date
    public init(downMbps: Double, upMbps: Double, pingMs: Int, jitterMs: Int, at: Date = Date()) {
        self.downMbps = downMbps; self.upMbps = upMbps
        self.pingMs = pingMs; self.jitterMs = jitterMs; self.at = at
    }
}

// MARK: - Connection mode (Global / Rule / Direct) — Hiddify-style

public enum ConnectionMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case proxy   // smart rules (default)
    case global  // everything through proxy
    case direct  // bypass — VPN interface up, traffic direct (testing)

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .proxy:  return NSLocalizedString("Умный", comment: "")
        case .global: return NSLocalizedString("Глобальный", comment: "")
        case .direct: return NSLocalizedString("Прямой", comment: "")
        }
    }
}

// MARK: - Domain resolution strategy (DNS)

public enum DomainStrategy: String, CaseIterable, Identifiable, Sendable, Codable {
    case preferIPv4 = "prefer_ipv4"
    case preferIPv6 = "prefer_ipv6"
    case ipv4Only = "ipv4_only"
    case ipv6Only = "ipv6_only"
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .preferIPv4: return NSLocalizedString("Сначала IPv4", comment: "")
        case .preferIPv6: return NSLocalizedString("Сначала IPv6", comment: "")
        case .ipv4Only:   return NSLocalizedString("Только IPv4", comment: "")
        case .ipv6Only:   return NSLocalizedString("Только IPv6", comment: "")
        }
    }
}

// MARK: - Traffic log

public struct TrafficLogEntry: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public var serverCity: String
    public var start: Date
    public var end: Date?
    public var bytesDown: Int64
    public var bytesUp: Int64
    public init(id: String = UUID().uuidString, serverCity: String, start: Date,
                end: Date? = nil, bytesDown: Int64 = 0, bytesUp: Int64 = 0) {
        self.id = id; self.serverCity = serverCity; self.start = start
        self.end = end; self.bytesDown = bytesDown; self.bytesUp = bytesUp
    }
    public var duration: TimeInterval { (end ?? Date()).timeIntervalSince(start) }
}

public struct Server: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let countryCode: String   // ISO, e.g. "RU"
    public let countryName: String
    public let city: String
    public let flag: String          // emoji
    public var pingMs: Int
    public var loadPct: Int          // 0…100
    public var premium: Bool
    public var available: Bool       // false => NSLocalizedString("скоро", comment: "")
    public var proto: TunnelProtocol
    public var mapX: Double          // 0…1 position on the world map
    public var mapY: Double
    /// Raw share-link key (vless:// …) for servers that carry their own config —
    /// the per-user `vpn_key` or an imported profile. nil for catalog servers.
    public var config: String?

    public init(id: String, countryCode: String, countryName: String, city: String,
                flag: String, pingMs: Int, loadPct: Int, premium: Bool = false,
                available: Bool = true, proto: TunnelProtocol = .reality,
                mapX: Double = 0.5, mapY: Double = 0.5, config: String? = nil) {
        self.id = id
        self.countryCode = countryCode
        self.countryName = countryName
        self.city = city
        self.flag = flag
        self.pingMs = pingMs
        self.loadPct = loadPct
        self.premium = premium
        self.available = available
        self.proto = proto
        self.mapX = mapX
        self.mapY = mapY
        self.config = config
    }

    public var qualityLabel: String {
        switch pingMs {
        case ..<40:  return NSLocalizedString("быстрый узел", comment: "")
        case ..<90:  return NSLocalizedString("стабильный", comment: "")
        default:     return NSLocalizedString("далёкий", comment: "")
        }
    }
}

public struct ServerGroup: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let title: String
    public var servers: [Server]
    public var comingSoon: Bool

    public init(id: String, title: String, servers: [Server], comingSoon: Bool = false) {
        self.id = id
        self.title = title
        self.servers = servers
        self.comingSoon = comingSoon
    }
}

// MARK: - Subscription & billing

public struct Plan: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let months: Int
    public let pricePerMonth: Int   // ₽
    public let total: Int           // ₽
    public let title: String
    public let features: [String]
    public let best: Bool

    public init(id: String, months: Int, pricePerMonth: Int, total: Int,
                title: String, features: [String], best: Bool = false) {
        self.id = id
        self.months = months
        self.pricePerMonth = pricePerMonth
        self.total = total
        self.title = title
        self.features = features
        self.best = best
    }
}

public enum SubscriptionStatus: String, Sendable, Codable {
    case trial, active, expired, none

    public var label: String {
        switch self {
        case .trial:   return NSLocalizedString("Пробный период", comment: "")
        case .active:  return NSLocalizedString("Активна", comment: "")
        case .expired: return NSLocalizedString("Истекла", comment: "")
        case .none:    return NSLocalizedString("Нет подписки", comment: "")
        }
    }
}

public struct Subscription: Equatable, Sendable, Codable {
    public var status: SubscriptionStatus
    public var planTitle: String
    public var expires: Date?
    public var deviceLimit: Int
    public var devicesUsed: Int

    public init(status: SubscriptionStatus, planTitle: String, expires: Date?,
                deviceLimit: Int, devicesUsed: Int) {
        self.status = status
        self.planTitle = planTitle
        self.expires = expires
        self.deviceLimit = deviceLimit
        self.devicesUsed = devicesUsed
    }

    public var daysLeft: Int? {
        guard let expires else { return nil }
        let secs = expires.timeIntervalSinceNow
        return secs > 0 ? Int(secs / 86_400) : 0
    }
}

// MARK: - Devices & user

public enum DevicePlatform: String, Sendable, Codable {
    case iPhone, iPad, mac, other
    public var systemImage: String {
        switch self {
        case .iPhone: return "iphone"
        case .iPad:   return "ipad"
        case .mac:    return "laptopcomputer"
        case .other:  return "desktopcomputer"
        }
    }
}

public struct Device: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public var name: String
    public var platform: DevicePlatform
    public var lastActive: Date
    public var current: Bool

    public init(id: String, name: String, platform: DevicePlatform, lastActive: Date, current: Bool = false) {
        self.id = id
        self.name = name
        self.platform = platform
        self.lastActive = lastActive
        self.current = current
    }
}

public struct User: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public var displayName: String
    public var telegramHandle: String?
    public var email: String?
    public var isDemo: Bool

    public init(id: String, displayName: String, telegramHandle: String? = nil,
                email: String? = nil, isDemo: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.telegramHandle = telegramHandle
        self.email = email
        self.isDemo = isDemo
    }
}

// MARK: - Personal cabinet (mirrors account.html on the site)

/// The user's access key (VLESS link) for manual / router setup.
public struct AccessKey: Equatable, Sendable, Codable {
    public var vless: String
    public var createdAt: Date
    public init(vless: String, createdAt: Date = Date()) { self.vless = vless; self.createdAt = createdAt }
    /// Shortened for display: keeps scheme + a head/tail.
    public var masked: String {
        guard vless.count > 28 else { return vless }
        return vless.prefix(18) + "…" + vless.suffix(8)
    }
}

/// Referral program — invite friends, earn bonus days.
public struct Referral: Equatable, Sendable, Codable {
    public var code: String
    public var link: String
    public var invited: Int            // friends who joined
    public var subscribed: Int         // friends who bought a plan
    public var bonusDays: Int          // days earned so far
    public init(code: String, link: String, invited: Int, subscribed: Int, bonusDays: Int) {
        self.code = code; self.link = link
        self.invited = invited; self.subscribed = subscribed; self.bonusDays = bonusDays
    }
}

public struct FAQItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let q: String
    public let a: String
    public init(id: String = UUID().uuidString, q: String, a: String) { self.id = id; self.q = q; self.a = a }
}

// MARK: - Landing-style content (mirrors index.html sections)

/// Live infrastructure status — "Серверы, которые на связи".
public struct InfraStatus: Equatable, Sendable {
    public var serversOnline: Int
    public var totalServers: Int
    public var locations: Int
    public var uptimePct: Double
    public var activeUsers: Int
    public init(serversOnline: Int, totalServers: Int, locations: Int, uptimePct: Double, activeUsers: Int) {
        self.serversOnline = serversOnline; self.totalServers = totalServers
        self.locations = locations; self.uptimePct = uptimePct; self.activeUsers = activeUsers
    }
    public static let demo = InfraStatus(serversOnline: 32, totalServers: 32, locations: 12,
                                         uptimePct: 99.9, activeUsers: 14_280)
}
