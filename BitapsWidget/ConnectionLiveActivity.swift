import SwiftUI
import WidgetKit

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

// MARK: - Shared glyph helpers

@available(iOS 16.1, *)
private func powerGlyph(_ connected: Bool, size: CGFloat = 16) -> some View {
    Image(systemName: "power")
        .font(.system(size: size, weight: .bold))
        .foregroundStyle(connected ? BitColor.accent : BitColor.muted)
}

@available(iOS 16.1, *)
private func liveTimer(_ startedAt: Date?, connected: Bool) -> some View {
    Group {
        if connected, let startedAt {
            Text(startedAt, style: .timer)
                .font(BitFont.mono(14, weight: .medium))
                .foregroundStyle(BitColor.text)
        } else {
            Text("—")
                .font(BitFont.mono(14, weight: .medium))
                .foregroundStyle(BitColor.muted)
        }
    }
}

// Local speed formatter (widget is a separate target — no app-only helpers).
private func wSpeed(_ bps: Double) -> String {
    let mbps = bps / 1_000_000
    if mbps >= 1 { return String(format: "%.0f Mbps", mbps) }
    return String(format: "%.0f Kbps", bps / 1000)
}

@available(iOS 16.1, *)
private func speeds(_ state: ConnectionAttributes.ContentState) -> some View {
    HStack(spacing: 10) {
        Label(wSpeed(state.downBps), systemImage: "arrow.down")
        Label(wSpeed(state.upBps), systemImage: "arrow.up")
    }
    .font(BitFont.mono(11, weight: .medium))
    .foregroundStyle(BitColor.muted)
    .labelStyle(.titleAndIcon)
}

// MARK: - Lock Screen view

@available(iOS 16.1, *)
private struct LockScreenView: View {
    let context: ActivityViewContext<ConnectionAttributes>
    var state: ConnectionAttributes.ContentState { context.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(context.attributes.serverFlag)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 0) {
                        Text("bit").foregroundStyle(BitColor.text)
                        Text("aps").foregroundStyle(BitColor.accent)
                    }
                    .font(BitFont.display(15, weight: .bold))
                    Text(context.attributes.serverCity)
                        .font(BitFont.mono(12))
                        .foregroundStyle(BitColor.muted)
                        .lineLimit(1)
                }
                Spacer()
                powerGlyph(state.connected, size: 20)
            }
            HStack {
                Text(state.statusText)
                    .font(BitFont.display(15, weight: .semibold))
                    .foregroundStyle(BitColor.text)
                Spacer()
                liveTimer(state.startedAt, connected: state.connected)
            }
            speeds(state)
        }
        .padding(14)
    }
}

// MARK: - Live Activity widget

@available(iOS 16.1, *)
struct ConnectionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ConnectionAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(BitColor.bg.opacity(0.9))
                .activitySystemActionForegroundColor(BitColor.accent)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Text(context.attributes.serverFlag)
                        Text(context.attributes.serverCity)
                            .font(BitFont.mono(13, weight: .medium))
                            .foregroundStyle(BitColor.text)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    liveTimer(state.startedAt, connected: state.connected)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(state.statusText)
                            .font(BitFont.display(14, weight: .semibold))
                            .foregroundStyle(state.connected ? BitColor.accent : BitColor.muted)
                        Spacer()
                        speeds(state)
                    }
                }
            } compactLeading: {
                powerGlyph(state.connected, size: 14)
            } compactTrailing: {
                liveTimer(state.startedAt, connected: state.connected)
            } minimal: {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(state.connected ? BitColor.accent : BitColor.muted)
            }
            .keylineTint(BitColor.accent)
        }
    }
}

#endif
