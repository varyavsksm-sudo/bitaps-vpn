import SwiftUI

/// Circular gauge (0…1) used for load / signal style readouts.
public struct RingGauge: View {
    var value: Double            // 0…1
    var color: Color
    var label: String
    var caption: String

    public init(value: Double, color: Color = BitColor.accent, label: String, caption: String) {
        self.value = value; self.color = color; self.label = label; self.caption = caption
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(BitColor.line, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: max(0.001, min(value, 1)))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .bitGlow(color, radius: 8, opacity: 0.5)
                Text(LocalizedStringKey(label)).font(BitFont.mono(13, weight: .semibold)).foregroundStyle(BitColor.text)
            }
            .frame(width: 58, height: 58)
            .animation(.easeInOut(duration: 0.5), value: value)
            Text(LocalizedStringKey(caption)).font(BitFont.mono(10)).foregroundStyle(BitColor.muted)
        }
    }
}
