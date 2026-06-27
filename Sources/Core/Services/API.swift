import Foundation

/// Backend abstraction. `MockAPI` returns the demo data the site/bot advertise;
/// `SupabaseAPI` is the skeleton that will hit the real Supabase project
/// (ref bjkozsukvifkxriojxrz) sharing the same account as @bitaps_vpn_auth_bot.
public protocol BitAPI: Sendable {
    func currentUser() async -> User?
    func loginWithTelegram(token: String) async throws -> User
    func loginDemo() async -> User
    func logout() async

    func fetchServers() async throws -> [ServerGroup]
    func fetchPlans() async throws -> [Plan]
    func fetchSubscription() async throws -> Subscription
    func fetchDevices() async throws -> [Device]

    /// Mock/stub: pretend to start a Telegram Stars / payment flow and extend.
    func renew(plan: Plan) async throws -> Subscription
    func removeDevice(_ id: String) async throws

    // Personal cabinet (mirrors account.html)
    func fetchAccessKey() async throws -> AccessKey
    func fetchReferral() async throws -> Referral
    func fetchFAQ() async -> [FAQItem]
    func regenerateKey() async throws -> AccessKey
    func sendSupport(message: String) async throws
}

/// Builds the Telegram login deep link into @bitaps_vpn_auth_bot.
public enum TelegramAuth {
    public static let botUsername = "bitaps_vpn_auth_bot"

    public static func loginURL() -> URL {
        // The bot issues a one-time login token; the app then polls / receives it.
        URL(string: "https://t.me/\(botUsername)?start=app_login")!
    }
    public static func subscribeURL() -> URL {
        URL(string: "https://t.me/\(botUsername)?start=subscribe")!
    }

    /// Personal Telegram for live support / orders.
    public static let personalHandle = "@bitapssupport"
    public static func personalURL() -> URL {
        URL(string: "https://t.me/\(personalHandle.drop(while: { $0 == "@" }))")!
    }

}

public enum APIFactory {
    public static var useSupabase = false
    public static func make() -> BitAPI {
        useSupabase ? SupabaseAPI() : MockAPI()
    }
}
