import SwiftUI

// MARK: - Glow

public extension View {
    /// Soft orange glow used across cards and the power ring.
    func bitGlow(_ color: Color = BitColor.accent, radius: CGFloat = 28, opacity: Double = 0.35) -> some View {
        self.shadow(color: color.opacity(opacity), radius: radius)
    }
}

// MARK: - Card

public struct BitCard<Content: View>: View {
    let content: Content
    var padding: CGFloat
    var strong: Bool
    public init(padding: CGFloat = BitMetric.pad, strong: Bool = false, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.strong = strong
    }
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: BitMetric.radius, style: .continuous)
        return content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(.ultraThinMaterial))                       // frosted glass
            .background(                                                       // warm tint
                shape.fill(LinearGradient(
                    colors: strong
                        ? [Color.white.opacity(0.12), Color.white.opacity(0.04)]
                        : [Color.white.opacity(0.07), Color.white.opacity(0.02)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(                                                          // edge highlight
                shape.stroke(LinearGradient(
                    colors: [Color.white.opacity(0.20), Color.white.opacity(0.04)],
                    startPoint: .top, endPoint: .bottom), lineWidth: 1)
            )
            .clipShape(shape)
            .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 12)
    }
}

// MARK: - Gradient icon chip (premium colorful tile icons)

public struct GradientIcon: View {
    let systemName: String
    var index: Int
    var size: CGFloat
    public init(_ systemName: String, index: Int = 0, size: CGFloat = 42) {
        self.systemName = systemName; self.index = index; self.size = size
    }
    public var body: some View {
        RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
            .fill(BitColor.accent.opacity(0.12))
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                    .stroke(BitColor.accent.opacity(0.30), lineWidth: 1)
            )
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(BitColor.accent)
            )
    }
}

// MARK: - Buttons

public enum BitButtonStyleKind { case solid, line, ghost }

public struct BitButton: View {
    let title: String
    var icon: String?
    var kind: BitButtonStyleKind
    var fullWidth: Bool
    var loading: Bool
    let action: () -> Void

    public init(_ title: String, icon: String? = nil, kind: BitButtonStyleKind = .solid,
                fullWidth: Bool = true, loading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.kind = kind
        self.fullWidth = fullWidth
        self.loading = loading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading {
                    ProgressView().controlSize(.small)
                } else if let icon {
                    Image(systemName: icon)
                }
                Text(title).font(BitFont.display(16, weight: .semibold))
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 13)
            .padding(.horizontal, 18)
            .foregroundStyle(foreground)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                    .stroke(kind == .line ? BitColor.line : .clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(loading)
        .bitGlow(kind == .solid ? BitColor.accent : .clear,
                 radius: 20, opacity: kind == .solid ? 0.45 : 0)
    }

    @ViewBuilder private var background: some View {
        switch kind {
        case .solid: BitColor.accentGradient
        case .line:  Color.clear
        case .ghost: BitColor.panel
        }
    }
    private var foreground: Color {
        switch kind {
        case .solid: return .black
        case .line, .ghost: return BitColor.text
        }
    }
}

// MARK: - Toggle

public struct BitToggle: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    @Binding var isOn: Bool
    var enabled: Bool

    public init(_ title: String, subtitle: String? = nil, systemImage: String? = nil,
                isOn: Binding<Bool>, enabled: Bool = true) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self._isOn = isOn
        self.enabled = enabled
    }

    public var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(BitColor.accent)
                    .frame(width: 22)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(BitFont.display(15, weight: .medium)).foregroundStyle(BitColor.text)
                if let subtitle {
                    Text(subtitle).font(BitFont.mono(12)).foregroundStyle(BitColor.muted)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(BitColor.accent).disabled(!enabled)
        }
        .opacity(enabled ? 1 : 0.5)
    }
}

// MARK: - Badge

public struct BitBadge: View {
    let text: String
    var color: Color
    var filled: Bool
    public init(_ text: String, color: Color = BitColor.accent, filled: Bool = false) {
        self.text = text
        self.color = color
        self.filled = filled
    }
    public var body: some View {
        Text(text)
            .font(BitFont.mono(11, weight: .semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(filled ? .black : color)
            .background(
                Capsule().fill(filled ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.14)))
            )
    }
}

// MARK: - Section header (kicker)

public struct Kicker: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text("// " + text)
            .font(BitFont.mono(12, weight: .medium))
            .foregroundStyle(BitColor.accent)
            .textCase(.lowercase)
    }
}

// MARK: - Load bar (server load)

public struct LoadBar: View {
    let pct: Int
    public init(pct: Int) { self.pct = pct }
    var color: Color {
        switch pct {
        case ..<50: return BitColor.ok
        case ..<80: return BitColor.warn
        default:    return BitColor.danger
        }
    }
    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(BitColor.line)
                Capsule().fill(color).frame(width: geo.size.width * CGFloat(pct) / 100)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Brand wordmark — see GearLogo.swift (gear + "bitaps")

// MARK: - Background — deep space with starfield (matches the bitaps landing)

public struct BitBackground: View {
    @Environment(\.colorScheme) private var scheme
    public init() {}
    public var body: some View {
        ZStack {
            BitColor.bg.ignoresSafeArea()
            if scheme == .dark {
                // Site theme: dark space + subtle starfield + faint edge glows.
                Starfield().ignoresSafeArea().opacity(0.7)
                RadialGradient(colors: [BitColor.accent.opacity(0.16), .clear],
                               center: .top, startRadius: 0, endRadius: 420)
                    .ignoresSafeArea()
                RadialGradient(colors: [BitColor.accent2.opacity(0.10), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 380)
                    .ignoresSafeArea()
            } else {
                RadialGradient(colors: [BitColor.accent.opacity(0.10), .clear],
                               center: .top, startRadius: 0, endRadius: 460)
                    .ignoresSafeArea()
            }
        }
    }

    private func blob(_ color: Color, _ opacity: Double, size: CGFloat) -> some View {
        Circle().fill(color.opacity(opacity)).frame(width: size, height: size)
    }
}

/// Subtle twinkling starfield drawn with Canvas — deterministic layout so it
/// never reshuffles, with a slow gentle twinkle. A few stars glow accent.
public struct Starfield: View {
    private let stars: [Star]
    struct Star { let x, y, r: CGFloat; let o: Double; let accent: Bool }

    public init(count: Int = 110) {
        // Seeded LCG → stable positions across redraws.
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(UInt64(1) << 53)
        }
        var arr: [Star] = []
        for _ in 0..<count {
            arr.append(Star(x: CGFloat(next()), y: CGFloat(next()),
                            r: CGFloat(0.4 + next() * 1.5),
                            o: 0.12 + next() * 0.6,
                            accent: next() > 0.93))
        }
        stars = arr
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1.1)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for (i, s) in stars.enumerated() {
                    let twinkle = 0.7 + 0.3 * sin(t * 0.7 + Double(i) * 1.7)
                    let color = s.accent ? BitColor.accent : Color.white
                    let d = s.r * 2
                    let rect = CGRect(x: s.x * size.width, y: s.y * size.height, width: d, height: d)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(s.o * twinkle)))
                }
            }
        }
    }
}
