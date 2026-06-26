import SwiftUI

/// Live sparkline used on the connect dashboard. Draws a smooth area+line of the
/// recent speed window, auto-scaled. No external chart dependency (works iOS16).
public struct Sparkline: View {
    let values: [Double]
    var color: Color
    var fill: Bool

    public init(values: [Double], color: Color = BitColor.accent, fill: Bool = true) {
        self.values = values
        self.color = color
        self.fill = fill
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let maxV = max(values.max() ?? 1, 1)
            let pts = points(in: CGSize(width: w, height: h), maxV: maxV)

            ZStack {
                if fill {
                    areaPath(pts, height: h)
                        .fill(LinearGradient(colors: [color.opacity(0.32), color.opacity(0.02)],
                                             startPoint: .top, endPoint: .bottom))
                }
                linePath(pts)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .bitGlow(color, radius: 8, opacity: 0.5)
                // leading dot at the newest value
                if let last = pts.last {
                    Circle().fill(color).frame(width: 5, height: 5).position(last)
                }
            }
        }
    }

    private func points(in size: CGSize, maxV: Double) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            let y = size.height - CGFloat(v / maxV) * size.height * 0.92 - 2
            return CGPoint(x: CGFloat(i) * stepX, y: y)
        }
    }

    private func linePath(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        return p
    }

    private func areaPath(_ pts: [CGPoint], height: CGFloat) -> Path {
        var p = linePath(pts)
        guard let first = pts.first, let last = pts.last else { return p }
        p.addLine(to: CGPoint(x: last.x, y: height))
        p.addLine(to: CGPoint(x: first.x, y: height))
        p.closeSubpath()
        return p
    }
}

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
                Text(label).font(BitFont.mono(13, weight: .semibold)).foregroundStyle(BitColor.text)
            }
            .frame(width: 58, height: 58)
            .animation(.easeInOut(duration: 0.5), value: value)
            Text(caption).font(BitFont.mono(10)).foregroundStyle(BitColor.muted)
        }
    }
}
