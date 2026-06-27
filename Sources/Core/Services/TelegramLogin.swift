import Foundation
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Native Telegram login via the official Telegram OAuth page, presented in a
/// system web sheet (`ASWebAuthenticationSession`). Returns the signed auth
/// payload — exactly the JSON the `telegram-auth` Supabase edge function
/// validates (id, first_name, last_name, username, photo_url, auth_date, hash).
///
/// Requirements (configured outside the app, one-time):
///  • The bot's login domain in @BotFather must be `bitapsvpn.com`
///    (already set). Telegram checks `origin` against it.
///  • Telegram redirects to `return_to` with `#tgAuthResult=<base64url(json)>`.
///    If Telegram refuses the custom-scheme return, host a one-line redirect
///    page on that domain that forwards `location.hash` to `bitapsvpn://auth`.
@MainActor
public final class TelegramLogin: NSObject {
    public static let botID = "8820784988"
    public static let origin = "https://bitapsvpn.com"
    public static let callbackScheme = "bitapsvpn"

    #if canImport(AuthenticationServices)
    private var session: ASWebAuthenticationSession?
    #endif

    public override init() {}

    /// Present Telegram OAuth; resolves to the auth-payload JSON, or nil on
    /// cancel/failure.
    public func authorize() async -> String? {
        #if canImport(AuthenticationServices)
        var comps = URLComponents(string: "https://oauth.telegram.org/auth")!
        comps.queryItems = [
            URLQueryItem(name: "bot_id", value: Self.botID),
            URLQueryItem(name: "origin", value: Self.origin),
            URLQueryItem(name: "request_access", value: "write"),
            URLQueryItem(name: "return_to", value: "\(Self.callbackScheme)://auth"),
        ]
        guard let url = comps.url else { return nil }
        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            let s = ASWebAuthenticationSession(url: url, callbackURLScheme: Self.callbackScheme) { callback, _ in
                cont.resume(returning: Self.parse(callback))
            }
            s.presentationContextProvider = self
            self.session = s
            if !s.start() { cont.resume(returning: nil) }
        }
        #else
        return nil
        #endif
    }

    /// Decode `tgAuthResult` (base64url) from the callback fragment into the flat
    /// JSON the backend HMAC-validates.
    private static func parse(_ url: URL?) -> String? {
        guard let frag = url?.fragment,
              let r = frag.range(of: "tgAuthResult=") else { return nil }
        var b64 = String(frag[r.upperBound...])
        b64 = b64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64.append("=") }
        guard let data = Data(base64Encoded: b64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

#if canImport(AuthenticationServices)
extension TelegramLogin: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
        return window ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
#endif
