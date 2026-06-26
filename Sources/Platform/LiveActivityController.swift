import Foundation
import SwiftUI

#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import WidgetKit

/// Drives the connection Live Activity (Dynamic Island + Lock Screen) and keeps
/// the App Group mirror that the home-screen widget reads. Every entry point is
/// no-throw and safe to call on devices where Live Activities are unsupported.
public final class LiveActivityController {
    public static let shared = LiveActivityController()
    private init() {}

    private static let suite = "group.app.bitaps.vpn"

    // Hold the running activity behind `Any` so the property itself needs no
    // availability annotation; we down-cast inside guarded blocks.
    private var current: Any?

    @available(iOS 16.1, *)
    private var activity: Activity<ConnectionAttributes>? {
        get { current as? Activity<ConnectionAttributes> }
        set { current = newValue }
    }

    // MARK: - Lifecycle

    public func start(city: String, flag: String) {
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Replace any stale activity first.
        if activity != nil { end() }

        let attributes = ConnectionAttributes(serverCity: city, serverFlag: flag)
        let state = ConnectionAttributes.ContentState(statusText: "Подключение…",
                                                      connected: false)
        do {
            activity = try Activity.request(attributes: attributes,
                                            contentState: state,
                                            pushType: nil)
        } catch {
            activity = nil
        }
        writeWidgetState(status: "Подключение…", city: city, flag: flag, connected: false)
    }

    public func update(statusText: String, connected: Bool,
                       down: Double, up: Double, startedAt: Date?) {
        guard #available(iOS 16.1, *) else { return }
        let state = ConnectionAttributes.ContentState(statusText: statusText,
                                                      connected: connected,
                                                      downBps: down, upBps: up,
                                                      startedAt: startedAt)
        guard let activity else { return }
        Task { await activity.update(using: state) }
        let city = activity.attributes.serverCity
        let flag = activity.attributes.serverFlag
        writeWidgetState(status: statusText, city: city, flag: flag, connected: connected)
    }

    public func end() {
        guard #available(iOS 16.1, *) else { return }
        guard let activity else { return }
        let final = ConnectionAttributes.ContentState(statusText: "Отключено",
                                                      connected: false)
        Task { await activity.end(using: final, dismissalPolicy: .immediate) }
        self.activity = nil
        writeWidgetState(status: "Отключено", city: "—", flag: "🌐", connected: false)
    }

    // MARK: - App Group mirror for the home-screen widget

    public func writeWidgetState(status: String, city: String, flag: String, connected: Bool) {
        let d = UserDefaults(suiteName: Self.suite)
        d?.set(status, forKey: "wstatus")
        d?.set(city, forKey: "wcity")
        d?.set(flag, forKey: "wflag")
        d?.set(connected, forKey: "wconnected")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#else

/// No-op stub so non-iOS targets (macOS) compile against the same API.
public final class LiveActivityController {
    public static let shared = LiveActivityController()
    private init() {}

    public func start(city: String, flag: String) {}
    public func update(statusText: String, connected: Bool,
                       down: Double, up: Double, startedAt: Date?) {}
    public func end() {}
    public func writeWidgetState(status: String, city: String, flag: String, connected: Bool) {}
}

#endif
