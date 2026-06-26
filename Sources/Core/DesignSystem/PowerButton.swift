import SwiftUI

/// The big customizable connect button. Pick a style in Settings — each is a
/// distinct, animated take on the same tap-to-connect control.
public struct PowerButton: View {
    let status: VPNStatus
    var style: ConnectButtonStyle
    let action: () -> Void

    @State private var spin = false
    @State private var pulse = false
    @State private var wave = false

    public init(status: VPNStatus, style: ConnectButtonStyle = .ring, action: @escaping () -> Void) {
        self.status = status
        self.style = style
        self.action = action
    }

    private var color: Color {
        switch status {
        case .connected:                                 return BitColor.accent
        case .connecting, .reasserting, .disconnecting:  return BitColor.accentSoft
        case .disconnected:                              return BitColor.muted
        }
    }
    private var glow: Double {
        switch status {
        case .connected:               return 0.6
        case .connecting, .reasserting: return 0.35
        default:                       return 0.0
        }
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                switch style {
                case .ring:  ringStyle
                case .gear:  gearStyle
                case .orb:   orbStyle
                case .pulse: pulseStyle
                case .arc:   arcStyle
                }
            }
            .frame(width: 280, height: 280)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
            withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) { wave = true }
        }
        .animation(.easeInOut(duration: 0.4), value: status)
    }

    // MARK: shared glyph

    private func glyph(_ size: CGFloat = 58) -> some View {
        PowerGlyph()
            .stroke(status.isActive ? BitColor.accent : BitColor.text,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.9, height: size)
            .scaleEffect(pulse && status.isActive ? 1.05 : 1)
    }

    private func halo(_ r: CGFloat = 150) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(glow), .clear],
                                 center: .center, startRadius: 40, endRadius: r))
            .frame(width: r * 2, height: r * 2)
    }

    // MARK: 1 · ring

    private var ringStyle: some View {
        ZStack {
            halo()
            Circle()
                .trim(from: 0, to: status.isBusy ? 0.22 : 1)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 210, height: 210)
                .rotationEffect(.degrees(spin && status.isBusy ? 360 : 0))
            Circle().fill(BitColor.bg2).frame(width: 168, height: 168)
                .overlay(Circle().stroke(BitColor.line, lineWidth: 1))
                .bitGlow(color, radius: 30, opacity: glow)
            glyph()
        }
    }

    // MARK: 2 · gear

    private var gearStyle: some View {
        ZStack {
            halo(140)
            // the cog spins while connecting and stays turning when connected
            ZStack {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color)
                        .frame(width: 22, height: 34)
                        .offset(y: -116)
                        .rotationEffect(.degrees(Double(i) / 10 * 360))
                }
                Circle().fill(color).frame(width: 198, height: 198)
                Circle().fill(BitColor.bg2).frame(width: 150, height: 150)
                    .overlay(Circle().stroke(color.opacity(0.4), lineWidth: 2))
            }
            .rotationEffect(.degrees(spin && (status.isActive || status.isBusy) ? 360 : 0))
            .bitGlow(color, radius: 28, opacity: glow)
            // brand "B" in the hub (stays upright)
            Text("B")
                .font(BitFont.display(58, weight: .bold))
                .foregroundStyle(status.isActive ? BitColor.accent : BitColor.text)
                .scaleEffect((pulse && (status.isActive || status.isBusy)) ? 1.06 : 1)
        }
    }

    // MARK: 3 · orb

    private var orbStyle: some View {
        ZStack {
            // expanding waves when connected
            if status.isActive {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(color.opacity(0.5), lineWidth: 2)
                        .frame(width: 150, height: 150)
                        .scaleEffect(wave ? 1.7 : 1)
                        .opacity(wave ? 0 : 0.6)
                        .animation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.7), value: wave)
                }
            }
            Circle()
                .fill(RadialGradient(
                    colors: status.isActive
                        ? [BitColor.accentSoft, BitColor.accent, BitColor.accent.opacity(0.6)]
                        : [BitColor.bg2, BitColor.bg2],
                    center: .init(x: 0.35, y: 0.3), startRadius: 6, endRadius: 130))
                .frame(width: 188, height: 188)
                .overlay(Circle().stroke(color.opacity(0.6), lineWidth: 1))
                .bitGlow(color, radius: 40, opacity: glow)
            PowerGlyph()
                .stroke(status.isActive ? Color.black.opacity(0.85) : BitColor.text,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .frame(width: 52, height: 58)
                .scaleEffect(pulse && status.isActive ? 1.05 : 1)
        }
    }

    // MARK: 4 · pulse

    private var pulseStyle: some View {
        ZStack {
            halo(130)
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(color.opacity(0.45), lineWidth: 2)
                    .frame(width: 120 + CGFloat(i) * 40, height: 120 + CGFloat(i) * 40)
                    .scaleEffect(status.isActive && wave ? 1.25 : 1)
                    .opacity(status.isActive ? (wave ? 0.1 : 0.5) : 0.25)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.3), value: wave)
            }
            Circle().fill(BitColor.bg2).frame(width: 116, height: 116)
                .overlay(Circle().stroke(color, lineWidth: 2))
                .bitGlow(color, radius: 24, opacity: glow)
            glyph(50)
        }
    }

    // MARK: 5 · arc (speedometer)

    private var arcStyle: some View {
        ZStack {
            halo(140)
            // track
            Circle()
                .trim(from: 0.08, to: 0.92)
                .stroke(BitColor.line, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 210, height: 210)
                .rotationEffect(.degrees(90))
            // fill
            Circle()
                .trim(from: 0.08, to: status.isActive ? 0.92 : (status.isBusy ? 0.5 : 0.08))
                .stroke(BitColor.accentGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 210, height: 210)
                .rotationEffect(.degrees(90))
                .bitGlow(color, radius: 18, opacity: glow)
            Circle().fill(BitColor.bg2).frame(width: 150, height: 150)
                .overlay(Circle().stroke(BitColor.line, lineWidth: 1))
            glyph(52)
        }
    }
}

/// The power symbol: a vertical stroke plus a broken ring opening at the top.
private struct PowerGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        p.move(to: CGPoint(x: cx, y: rect.minY))
        p.addLine(to: CGPoint(x: cx, y: rect.minY + rect.height * 0.45))
        let r = rect.width * 0.5
        let center = CGPoint(x: cx, y: rect.minY + rect.height * 0.5)
        p.addArc(center: center, radius: r,
                 startAngle: .degrees(-65), endAngle: .degrees(245), clockwise: false)
        return p
    }
}
