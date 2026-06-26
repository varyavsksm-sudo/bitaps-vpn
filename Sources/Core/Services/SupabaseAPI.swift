import Foundation

/// Real backend skeleton — Supabase project `bjkozsukvifkxriojxrz`, the same one
/// powering @bitaps_vpn_auth_bot and the account.html Mini App. Endpoints are
/// laid out and compile; network calls are TODO until anon key + RLS are wired.
///
/// To go live:
///   1. Drop the anon key into `Secrets.supabaseAnonKey`.
///   2. Add the edge function routes (servers, subscription, devices, issue-config).
///   3. Set APIFactory.useSupabase = true.
public actor SupabaseAPI: BitAPI {
    private let baseURL = URL(string: "https://bjkozsukvifkxriojxrz.supabase.co")!
    private var accessToken: String?
    private var cachedUser: User?

    public init() {}

    public func currentUser() async -> User? { cachedUser }

    public func loginWithTelegram(token: String) async throws -> User {
        // POST /functions/v1/telegram-bot { action: "app_login", token }
        // returns { access_token, user }. TODO: implement request.
        throw AppError.network("SupabaseAPI ещё не подключён — используется MockAPI")
    }

    public func loginDemo() async -> User {
        User(id: "demo", displayName: "Демо-режим", isDemo: true)
    }

    public func logout() async { accessToken = nil; cachedUser = nil }

    public func fetchServers() async throws -> [ServerGroup] {
        // GET /rest/v1/servers?select=* (RLS by subscription tier)
        throw AppError.network("not wired")
    }
    public func fetchPlans() async throws -> [Plan] { Plan.catalog }
    public func fetchSubscription() async throws -> Subscription {
        throw AppError.network("not wired")
    }
    public func fetchDevices() async throws -> [Device] {
        throw AppError.network("not wired")
    }
    public func renew(plan: Plan) async throws -> Subscription {
        // Opens Telegram Stars invoice via the bot; webhook updates Supabase.
        throw AppError.network("not wired")
    }
    public func removeDevice(_ id: String) async throws {
        throw AppError.network("not wired")
    }
    public func fetchAccessKey() async throws -> AccessKey { throw AppError.network("not wired") }
    public func fetchReferral() async throws -> Referral { throw AppError.network("not wired") }
    public func fetchFAQ() async -> [FAQItem] { [] }
    public func regenerateKey() async throws -> AccessKey { throw AppError.network("not wired") }
    public func sendSupport(message: String) async throws { throw AppError.network("not wired") }

    // MARK: - request helper (ready for use)

    private func request(_ path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let accessToken {
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return req
    }
}

/// Placeholder for keys. Real values go into an xcconfig / build settings, not git.
public enum Secrets {
    public static let supabaseAnonKey = "REPLACE_SUPABASE_ANON_KEY"
}
