import Foundation

/// Real backend client for Supabase project `bjkozsukvifkxriojxrz` — the same one
/// powering @bitaps_vpn_auth_bot and the account.html Mini App.
///
/// Contract (from supabase/functions):
///  • Auth: `telegram-auth` validates the Telegram login signature → returns a
///    magic-link `token_hash`; the app exchanges it at GoTrue `/auth/v1/verify`
///    for a session JWT. (Acquiring the Telegram signature natively needs the
///    Telegram login UI on a real device — that's the one remaining auth gap.)
///  • Account: table `subscriptions` keyed by `telegram_id`, columns
///    `plan, expires_at, vpn_key, device_limit`. The VLESS key the bot issued is
///    `vpn_key` — that IS the user's server.
///  • Payments: edge functions `web-pay` / `crypto-pay`; confirmation arrives via
///    `platega-webhook` and updates `subscriptions`.
///
/// Flip on with `APIFactory.useSupabase = true`. Until a session exists the calls
/// throw and AppStore degrades gracefully (demo data / empty states).
public actor SupabaseAPI: BitAPI {
    private let baseURL = URL(string: "https://bjkozsukvifkxriojxrz.supabase.co")!
    private var accessToken: String?
    private var telegramId: Int?
    private var cachedUser: User?
    private var cachedKey: String?            // vpn_key (also parsed into the server)

    public init() {}

    // MARK: - Auth

    public func currentUser() async -> User? { cachedUser }

    /// `token` = the Telegram login payload (the signed items from the login widget
    /// / bot deep-link), JSON-encoded. Posted to `telegram-auth`, then the returned
    /// magic-link token is exchanged at GoTrue for a session JWT.
    public func loginWithTelegram(token: String) async throws -> User {
        struct AuthOut: Decodable { let email: String?; let token_hash: String? }
        let out: AuthOut = try await send("/functions/v1/telegram-auth",
                                          method: "POST", body: Data(token.utf8), authorized: false)
        guard let hash = out.token_hash else { throw AppError.network("Telegram auth failed") }

        struct VerifyOut: Decodable {
            struct U: Decodable {
                struct M: Decodable { let telegram_id: Int?; let name: String? }
                let email: String?; let user_metadata: M?
            }
            let access_token: String
            let user: U?
        }
        let verifyBody = try JSONSerialization.data(withJSONObject: ["type": "magiclink", "token_hash": hash])
        let v: VerifyOut = try await send("/auth/v1/verify", method: "POST", body: verifyBody, authorized: false)
        accessToken = v.access_token
        telegramId = v.user?.user_metadata?.telegram_id
        let u = User(id: telegramId.map(String.init) ?? "tg",
                     displayName: v.user?.user_metadata?.name ?? "bitaps",
                     telegramHandle: nil,
                     email: v.user?.email,
                     isDemo: false)
        cachedUser = u
        return u
    }

    public func loginDemo() async -> User {
        let u = User(id: "demo", displayName: "Демо-режим", isDemo: true)
        cachedUser = u
        return u
    }

    public func logout() async { accessToken = nil; telegramId = nil; cachedUser = nil; cachedKey = nil }

    // MARK: - Account data (subscriptions table)

    private struct SubRow: Decodable {
        let plan: String?
        let expires_at: String?
        let vpn_key: String?
        let device_limit: Int?
    }
    private func subscriptionRow() async throws -> SubRow {
        guard let tg = telegramId else { throw AppError.network("Не авторизован") }
        let path = "/rest/v1/subscriptions?select=plan,expires_at,vpn_key,device_limit&telegram_id=eq.\(tg)"
        let rows: [SubRow] = try await send(path)
        guard let row = rows.first else { throw AppError.network("Подписка не найдена") }
        cachedKey = row.vpn_key
        return row
    }

    public func fetchSubscription() async throws -> Subscription {
        let row = try await subscriptionRow()
        let expires = row.expires_at.flatMap(Self.parseDate)
        let active = (expires.map { $0 > Date() }) ?? false
        return Subscription(status: active ? .active : .expired,
                            planTitle: row.plan ?? "—",
                            expires: expires,
                            deviceLimit: row.device_limit ?? 1,
                            devicesUsed: 1)
    }

    public func fetchAccessKey() async throws -> AccessKey {
        if cachedKey == nil { _ = try? await subscriptionRow() }
        guard let key = cachedKey, !key.isEmpty else { throw AppError.network("Ключ ещё не выпущен") }
        return AccessKey(vless: key)
    }

    /// The server IS the issued key — parse the vpn_key into a single server group.
    public func fetchServers() async throws -> [ServerGroup] {
        if cachedKey == nil { _ = try? await subscriptionRow() }
        guard let key = cachedKey, let cfg = ImportedConfig.parse(key, source: .subscription) else {
            return []   // no key yet → empty; UI shows "сервер не выбран"
        }
        // Stable id — there's exactly one "my key" server, so a fixed id keeps the
        // picker selection and recents stable across refreshes (cfg.id is random).
        let s = Server(id: "mine-server", countryCode: "XX",
                       countryName: NSLocalizedString("Свой профиль", comment: ""),
                       city: cfg.name, flag: "🔧", pingMs: 0, loadPct: 0,
                       proto: cfg.proto, config: key)
        return [ServerGroup(id: "mine", title: NSLocalizedString("Мой сервер", comment: ""), servers: [s])]
    }

    public func fetchPlans() async throws -> [Plan] { Plan.catalog }

    public func fetchDevices() async throws -> [Device] {
        // device_limit is enforced server-side; the per-device list isn't exposed
        // by the current backend, so show just this device.
        [Device(id: "current", name: Self.deviceName, platform: Self.platform,
                lastActive: Date(), current: true)]
    }

    public func removeDevice(_ id: String) async throws { /* server-managed; no endpoint yet */ }

    // MARK: - Payments (edge functions; webhook confirms → subscriptions)

    public func renew(plan: Plan) async throws -> Subscription {
        struct PayOut: Decodable { let url: String? }
        let body = try JSONSerialization.data(withJSONObject: ["plan": plan.id, "telegram_id": telegramId as Any])
        _ = try? await send("/functions/v1/web-pay", method: "POST", body: body) as PayOut
        return try await fetchSubscription()   // unchanged until platega-webhook lands
    }

    // MARK: - Cabinet extras

    public func fetchReferral() async throws -> Referral {
        // Real counter: server-side RPC counts subscriptions.referred_by == me
        // (SECURITY DEFINER, reads telegram_id from the session JWT, bypasses RLS).
        struct Stats: Decodable { let invited: Int; let subscribed: Int; let bonus_days: Int }
        let stats: Stats = (try? await send("/rest/v1/rpc/app_referral_stats",
                                            method: "POST", body: Data("{}".utf8)))
            ?? Stats(invited: 0, subscribed: 0, bonus_days: 0)
        return Referral(code: telegramId.map(String.init) ?? "—",
                        link: "https://t.me/\(TelegramAuth.botUsername)?start=ref_\(telegramId ?? 0)",
                        invited: stats.invited, subscribed: stats.subscribed, bonusDays: stats.bonus_days)
    }

    public func fetchFAQ() async -> [FAQItem] {
        // Same FAQ as the site/bot (no FAQ table — this is the source content).
        [
            FAQItem(q: "Сколько устройств можно подключить?",
                    a: "По умолчанию 1 устройство. Нужно больше — добавьте в боте дополнительные (+50 ₽/мес за каждое)."),
            FAQItem(q: "Вы ведёте логи?",
                    a: "Нет. Мы не храним историю и трафик — приватность по умолчанию."),
            FAQItem(q: "Как продлить подписку?",
                    a: "Кнопка «Продлить» → оплата в Telegram, срок продлится автоматически."),
            FAQItem(q: "VPN не подключается?",
                    a: "Проверьте, что ключ скопирован полностью, попробуйте другой сервер или напишите в поддержку."),
        ]
    }

    public func regenerateKey() async throws -> AccessKey {
        cachedKey = nil                        // no rotate endpoint yet → re-fetch
        return try await fetchAccessKey()
    }

    public func sendSupport(message: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "telegram_id": telegramId as Any,
            "message": message,
        ])
        try await sendRaw("/rest/v1/support_messages", method: "POST", body: body,
                          extraHeaders: ["Prefer": "return=minimal"])
    }

    // MARK: - HTTP

    private func send<T: Decodable>(_ path: String, method: String = "GET",
                                    body: Data? = nil, authorized: Bool = true) async throws -> T {
        let data = try await sendRaw(path, method: method, body: body, authorized: authorized)
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw AppError.network("Ответ сервера не распознан") }
    }

    @discardableResult
    private func sendRaw(_ path: String, method: String = "GET", body: Data? = nil,
                         authorized: Bool = true, extraHeaders: [String: String] = [:]) async throws -> Data {
        // Build via URLComponents so a query string in `path` survives — using
        // appendingPathComponent would percent-encode the "?" and drop the query.
        guard var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw AppError.network("Bad URL")
        }
        if let q = path.firstIndex(of: "?") {
            comps.path = String(path[..<q])
            comps.percentEncodedQuery = String(path[path.index(after: q)...])
        } else {
            comps.path = path
        }
        guard let url = comps.url else { throw AppError.network("Bad URL") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if authorized, let accessToken { req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        for (k, v) in extraHeaders { req.setValue(v, forHTTPHeaderField: k) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AppError.network("Нет ответа") }
        guard (200..<300).contains(http.statusCode) else { throw AppError.network("HTTP \(http.statusCode)") }
        return data
    }

    // MARK: - Helpers

    private static func parseDate(_ s: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: s)
    }

    private static var deviceName: String {
        #if os(iOS)
        return "iPhone"
        #elseif os(macOS)
        return "Mac"
        #else
        return "bitaps"
        #endif
    }
    private static var platform: DevicePlatform {
        #if os(macOS)
        return .mac
        #else
        return .iPhone
        #endif
    }
}

/// Real keys. The anon (publishable) key is safe to ship in a client — row access
/// is still gated by RLS + the per-user session JWT.
public enum Secrets {
    public static let supabaseAnonKey = "sb_publishable_X2CJWgjqeZtbNelAri9ofw_trbfWF9Z"
}
