import SwiftUI

/// The bitaps mark — a cog/gear with a "b" in the hub. Built compositionally
/// (rounded teeth + body + hub + upright "b") so it matches the app icon and
/// reads crisply at any size. The gear spins while connecting; the "b" stays
/// upright. Used in the wordmark, splash, menu bar and onboarding.
public struct GearMark: View {
    var size: CGFloat
    var spinning: Bool
    @State private var angle: Double = 0

    public init(size: CGFloat = 26, spinning: Bool = false) {
        self.size = size
        self.spinning = spinning
    }

    private var toothCount: Int { 8 }

    public var body: some View {
        ZStack {
            // --- the gear (this part spins) ---
            ZStack {
                // teeth
                ForEach(0..<toothCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                        .fill(BitColor.accentGradient)
                        .frame(width: size * 0.18, height: size * 0.26)
                        .offset(y: -size * 0.45)
                        .rotationEffect(.degrees(Double(i) / Double(toothCount) * 360))
                }
                // body
                Circle()
                    .fill(BitColor.accentGradient)
                    .frame(width: size * 0.78, height: size * 0.78)
                // hub (adapts to theme)
                Circle()
                    .fill(BitColor.bg2)
                    .frame(width: size * 0.54, height: size * 0.54)
                    .overlay(Circle().stroke(BitColor.accent.opacity(0.45), lineWidth: max(1, size * 0.012)))
            }
            .rotationEffect(.degrees(angle))

            // --- the "B" (stays upright) ---
            Text("B")
                .font(BitFont.display(size * 0.40, weight: .bold))
                .foregroundStyle(BitColor.accent)
        }
        .frame(width: size, height: size)
        .bitGlow(BitColor.accent, radius: size * 0.4, opacity: 0.4)
        .onAppear { if spinning { startSpin() } }
        .onChange(of: spinning) { now in
            if now { startSpin() } else { withAnimation(.easeOut(duration: 0.4)) { } }
        }
    }

    private func startSpin() {
        withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
            angle = 360
        }
    }
}

/// Wordmark: gear + "bitaps" (aps in accent). The brand lockup.
public struct BitLogo: View {
    var size: CGFloat
    var spinning: Bool
    public init(size: CGFloat = 22, spinning: Bool = false) {
        self.size = size
        self.spinning = spinning
    }
    public var body: some View {
        HStack(spacing: size * 0.34) {
            GearMark(size: size * 1.15, spinning: spinning)
            HStack(spacing: 0) {
                Text("bit").foregroundStyle(BitColor.text)
                Text("aps").foregroundStyle(BitColor.accent)
            }
            .font(BitFont.display(size, weight: .bold))
        }
    }
}
