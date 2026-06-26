import Foundation

/// Demo backend. Data matches the landing page (bitaps-vpn.surge.sh) and the bot:
/// tariffs 199/499/899/1490 ₽, 3-day trial, up to 10 devices, VLESS+Reality.
public actor MockAPI: BitAPI {
    private var user: User?
    private var subscription: Subscription = .demoTrial
    private var devices: [Device] = Device.demoList

    public init() {}

    public func currentUser() async -> User? { user }

    public func loginWithTelegram(token: String) async throws -> User {
        try await Self.fakeLatency()
        let u = User(id: "tg_\(token.prefix(6))", displayName: "Варвара",
                     telegramHandle: "@varya", isDemo: false)
        user = u
        return u
    }

    public func loginDemo() async -> User {
        try? await Self.fakeLatency()
        let u = User(id: "demo", displayName: "Демо-режим", isDemo: true)
        user = u
        return u
    }

    public func logout() async { user = nil }

    public func fetchServers() async throws -> [ServerGroup] {
        try await Self.fakeLatency()
        return ServerGroup.demoGroups
    }

    public func fetchPlans() async throws -> [Plan] {
        try await Self.fakeLatency()
        return Plan.catalog
    }

    public func fetchSubscription() async throws -> Subscription {
        try await Self.fakeLatency()
        return subscription
    }

    public func fetchDevices() async throws -> [Device] {
        try await Self.fakeLatency()
        return devices
    }

    public func renew(plan: Plan) async throws -> Subscription {
        try await Self.fakeLatency()
        let newExpiry = Calendar.current.date(byAdding: .month, value: plan.months,
                                              to: max(subscription.expires ?? Date(), Date())) ?? Date()
        subscription = Subscription(status: .active, planTitle: plan.title, expires: newExpiry,
                                    deviceLimit: 10, devicesUsed: devices.count)
        return subscription
    }

    public func removeDevice(_ id: String) async throws {
        try await Self.fakeLatency()
        devices.removeAll { $0.id == id && !$0.current }
    }

    // MARK: - Cabinet

    private var key = AccessKey(
        vless: "vless://3a7c9f1e-2b4d-4a8c-9e1f-7d6b5c4a3e2f@msk.bitaps.app:443?security=reality&encryption=none&pbk=Xj2k…&sni=www.microsoft.com&sid=9a3f&type=tcp&flow=xtls-rprx-vision#bitaps-РФ")

    public func fetchAccessKey() async throws -> AccessKey {
        try await Self.fakeLatency(); return key
    }
    public func fetchReferral() async throws -> Referral {
        try await Self.fakeLatency()
        return Referral(code: "VARYA46",
                        link: "https://t.me/bitaps_vpn_auth_bot?start=ref_VARYA46",
                        invited: 3, subscribed: 2, bonusDays: 30)
    }
    public func fetchFAQ() async -> [FAQItem] {
        [
            FAQItem(q: "Сколько устройств можно подключить?",
                    a: "До 10 устройств одновременно по одной подписке."),
            FAQItem(q: "Вы ведёте логи?",
                    a: "Нет. Мы не храним логи вашей активности — только техническую информацию для работы сервиса."),
            FAQItem(q: "Как продлить подписку?",
                    a: "В разделе «Подписка» нажмите «Продлить» — оплата проходит через Telegram Stars."),
            FAQItem(q: "VPN не подключается — что делать?",
                    a: "Смените локацию или протокол на «Авто», проверьте интернет. Если не помогло — напишите в поддержку.")
        ]
    }
    public func regenerateKey() async throws -> AccessKey {
        try await Self.fakeLatency()
        let uuid = UUID().uuidString.lowercased()
        key = AccessKey(vless: "vless://\(uuid)@msk.bitaps.app:443?security=reality&pbk=Xj2k…&sni=www.microsoft.com&sid=9a3f&flow=xtls-rprx-vision#bitaps-РФ")
        return key
    }
    public func sendSupport(message: String) async throws {
        try await Self.fakeLatency()
    }

    private static func fakeLatency() async throws {
        try await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.3...0.7) * 1_000_000_000))
    }
}

// MARK: - Demo data

public extension Plan {
    static let catalog: [Plan] = [
        Plan(id: "m1", months: 1, pricePerMonth: 199, total: 199, title: "1 месяц",
             features: ["Все локации", "Безлимит трафика", "VLESS + Reality", "Поддержка 24/7"]),
        Plan(id: "m3", months: 3, pricePerMonth: 166, total: 499, title: "3 месяца",
             features: ["Всё из «1 месяца»", "Дешевле помесячно", "YouTube без рекламы", "Поддержка 24/7"]),
        Plan(id: "m6", months: 6, pricePerMonth: 150, total: 899, title: "6 месяцев",
             features: ["Всё из «3 месяцев»", "Выгодный месяц", "Приоритетная поддержка", "Без логов"]),
        Plan(id: "m12", months: 12, pricePerMonth: 124, total: 1490, title: "12 месяцев",
             features: ["Всё из «6 месяцев»", "Максимальная выгода", "Выделенный IP-адрес", "Лучшая цена"],
             best: true)
    ]
}

public extension Subscription {
    static var demoTrial: Subscription {
        Subscription(status: .trial, planTitle: "Пробный период",
                     expires: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
                     deviceLimit: 10, devicesUsed: 2)
    }
}

public extension Device {
    static var demoList: [Device] {
        [
            Device(id: "d1", name: "iPhone 15 Pro", platform: .iPhone, lastActive: Date(), current: true),
            Device(id: "d2", name: "MacBook Air", platform: .mac,
                   lastActive: Date().addingTimeInterval(-3600))
        ]
    }
}

public extension ServerGroup {
    /// 🇷🇺 RU node (live mock, Yandex Cloud) + foreign nodes marked "скоро".
    static var demoGroups: [ServerGroup] {
        let ru = [
            Server(id: "ru-msk-1", countryCode: "RU", countryName: "Россия", city: "Москва",
                   flag: "🇷🇺", pingMs: 12, loadPct: 34, premium: false, available: true, proto: .reality,
                   mapX: 0.604, mapY: 0.205),
            Server(id: "ru-spb-1", countryCode: "RU", countryName: "Россия", city: "Санкт-Петербург",
                   flag: "🇷🇺", pingMs: 21, loadPct: 41, premium: false, available: true, proto: .reality,
                   mapX: 0.585, mapY: 0.185)
        ]
        let foreign = [
            Server(id: "nl-ams-1", countryCode: "NL", countryName: "Нидерланды", city: "Амстердам",
                   flag: "🇳🇱", pingMs: 48, loadPct: 22, premium: true, available: false, proto: .reality,
                   mapX: 0.514, mapY: 0.235),
            Server(id: "de-fra-1", countryCode: "DE", countryName: "Германия", city: "Франкфурт",
                   flag: "🇩🇪", pingMs: 52, loadPct: 18, premium: true, available: false, proto: .wireguard,
                   mapX: 0.524, mapY: 0.25),
            Server(id: "fi-hel-1", countryCode: "FI", countryName: "Финляндия", city: "Хельсинки",
                   flag: "🇫🇮", pingMs: 45, loadPct: 27, premium: true, available: false, proto: .reality,
                   mapX: 0.572, mapY: 0.18),
            Server(id: "tr-ist-1", countryCode: "TR", countryName: "Турция", city: "Стамбул",
                   flag: "🇹🇷", pingMs: 63, loadPct: 31, premium: true, available: false, proto: .reality,
                   mapX: 0.585, mapY: 0.305)
        ]
        return [
            ServerGroup(id: "ru", title: "🇷🇺 Россия", servers: ru, comingSoon: false),
            ServerGroup(id: "intl", title: "🌍 Зарубежные", servers: foreign, comingSoon: true)
        ]
    }
}
