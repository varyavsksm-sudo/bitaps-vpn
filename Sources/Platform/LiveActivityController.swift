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

    // Last known server, so `update()` can refresh the widget mirror even when no
    // Live Activity is running (Live Activities may be disabled by the user).
    private var lastCity = "—"
    private var lastFlag = "🌐"

    @available(iOS 16.1, *)
    private var activity: Activity<ConnectionAttributes>? {
        get { current as? Activity<ConnectionAttributes> }
        set { current = newValue }
    }

    // MARK: - Lifecycle

    public func start(city: String, flag: String) {
        let connecting = NSLocalizedString("Подключение…", comment: "")
        // Clear any stale Live Activity FIRST (end() resets lastCity/lastFlag),
        // then adopt the new server so update() mirrors the right city.
        if #available(iOS 16.1, *), activity != nil { end() }
        lastCity = city; lastFlag = flag
        writeWidgetState(status: connecting, city: city, flag: flag, connected: false)

        guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = ConnectionAttributes(serverCity: city, serverFlag: flag)
        let state = ConnectionAttributes.ContentState(statusText: connecting,
                                                      connected: false)
        do {
            activity = try Activity.request(attributes: attributes,
                                            contentState: state,
                                            pushType: nil)
        } catch {
            activity = nil
        }
    }

    public func update(statusText: String, connected: Bool,
                       down: Double, up: Double, startedAt: Date?) {
        // Always refresh the widget mirror, even without a running Live Activity.
        writeWidgetState(status: statusText, city: lastCity, flag: lastFlag, connected: connected)
        guard #available(iOS 16.1, *), let activity else { return }
        let state = ConnectionAttributes.ContentState(statusText: statusText,
                                                      connected: connected,
                                                      downBps: down, upBps: up,
                                                      startedAt: startedAt)
        Task { await activity.update(using: state) }
    }

    public func end() {
        let disconnected = NSLocalizedString("Отключено", comment: "")
        writeWidgetState(status: disconnected, city: "—", flag: "🌐", connected: false)
        lastCity = "—"; lastFlag = "🌐"
        guard #available(iOS 16.1, *), let activity else { return }
        let final = ConnectionAttributes.ContentState(statusText: disconnected,
                                                      connected: false)
        Task { await activity.end(using: final, dismissalPolicy: .immediate) }
        self.activity = nil
    }

    // MARK: - App Group mirror for the home-screen widget

    private var lastMirror = ""

    public func writeWidgetState(status: String, city: String, flag: String, connected: Bool) {
        // The widget only shows status/city/flag/connected — which don't change
        // every second. Skip the whole write+reload when nothing changed, avoiding
        // per-tick App-Group writes and timeline churn (battery / OS throttling).
        let snapshot = "\(status)|\(city)|\(flag)|\(connected)"
        guard snapshot != lastMirror else { return }
        lastMirror = snapshot
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
