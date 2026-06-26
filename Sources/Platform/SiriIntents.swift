import Foundation
#if canImport(AppIntents)
import AppIntents

/// Siri / Shortcuts commands. Real connect logic talks to the tunnel manager;
/// here the intents post a request the app handles when active. Compile-ready
/// skeleton so "Добавить в Siri" works once provisioning is in place.
@available(iOS 16.0, macOS 13.0, *)
public struct ConnectIntent: AppIntent {
    public static var title: LocalizedStringResource = "Подключить bitaps VPN"
    public static var openAppWhenRun = true
    public init() {}
    public func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .siriConnect, object: nil)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct DisconnectIntent: AppIntent {
    public static var title: LocalizedStringResource = "Отключить bitaps VPN"
    public init() {}
    public func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .siriDisconnect, object: nil)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct FastestIntent: AppIntent {
    public static var title: LocalizedStringResource = "Подключиться к быстрейшему серверу"
    public static var openAppWhenRun = true
    public init() {}
    public func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .siriFastest, object: nil)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct BitapsShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ConnectIntent(), phrases: ["Подключи \(.applicationName)", "Включи ВПН в \(.applicationName)"])
        AppShortcut(intent: DisconnectIntent(), phrases: ["Отключи \(.applicationName)"])
        AppShortcut(intent: FastestIntent(), phrases: ["Быстрейший сервер в \(.applicationName)"])
    }
}
#endif

public extension Notification.Name {
    static let siriConnect    = Notification.Name("bitaps.siri.connect")
    static let siriDisconnect = Notification.Name("bitaps.siri.disconnect")
    static let siriFastest    = Notification.Name("bitaps.siri.fastest")
}
