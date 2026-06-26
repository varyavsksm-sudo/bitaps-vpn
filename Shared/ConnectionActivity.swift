import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Shared between the app and the widget extension. Describes the Live Activity
/// (Dynamic Island + Lock Screen) that tracks VPN connection status — our answer
/// to Happ's "Connection Status" Live Activity, with bitaps branding.
public struct ConnectionAttributes: Codable, Hashable, Sendable {
    // Static (set once when the activity starts)
    public var serverCity: String
    public var serverFlag: String
    public init(serverCity: String, serverFlag: String) {
        self.serverCity = serverCity
        self.serverFlag = serverFlag
    }

    /// Dynamic values pushed as the session runs.
    public struct ContentState: Codable, Hashable, Sendable {
        public var statusText: String     // "Подключено" / "Подключение…"
        public var connected: Bool
        public var downBps: Double
        public var upBps: Double
        public var startedAt: Date?
        public init(statusText: String, connected: Bool, downBps: Double = 0,
                    upBps: Double = 0, startedAt: Date? = nil) {
            self.statusText = statusText
            self.connected = connected
            self.downBps = downBps
            self.upBps = upBps
            self.startedAt = startedAt
        }
    }
}

#if canImport(ActivityKit) && os(iOS)
extension ConnectionAttributes: ActivityAttributes {}
#endif
