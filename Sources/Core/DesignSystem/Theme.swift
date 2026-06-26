import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Adaptive color helper (cross-platform light/dark)

public extension Color {
    /// Build a color that resolves differently in light vs dark mode on both
    /// UIKit (iOS) and AppKit (macOS).
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif canImport(AppKit)
        self = Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
        #else
        self = dark
        #endif
    }

    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

// MARK: - Brand palette (taken 1:1 from the landing CSS)

public enum BitColor {
    /// Currently selected accent theme (set from Settings). Drives `accent`/`accentSoft`.
    /// Views that must recolor live are re-`id`'d on the accent at the root.
    public static var accentTheme: AccentTheme = .sunset

    // Accents (same in both light/dark; brand default = sunset orange)
    public static var accent: Color { Color(hex: accentTheme.hexes.0) }
    public static var accentSoft: Color { Color(hex: accentTheme.hexes.1) }
    public static let accent2 = Color(hex: 0x2d8bff)

    // Premium aurora palette — used for background blobs and gradient icon chips.
    public static let violet  = Color(hex: 0x7b5cff)
    public static let magenta = Color(hex: 0xff3d7f)
    public static let teal    = Color(hex: 0x19c8a8)
    public static let sky     = Color(hex: 0x3aa0ff)
    public static let gold     = Color(hex: 0xe9c46a)   // kept for compat
    public static let goldDeep = Color(hex: 0xb8860b)

    /// Rich gradient chips for tile icons (rotated by index).
    public static func chipGradient(_ i: Int) -> LinearGradient {
        let pairs: [(Color, Color)] = [
            (Color(hex: 0xff9d3d), Color(hex: 0xff6a00)),   // orange
            (Color(hex: 0x9b7bff), Color(hex: 0x6a4bff)),   // violet
            (Color(hex: 0x3ad6c0), Color(hex: 0x14a890)),   // teal
            (Color(hex: 0xff5d8f), Color(hex: 0xff2d6d)),   // magenta
            (Color(hex: 0x59b4ff), Color(hex: 0x2d7bff)),   // sky
        ]
        let p = pairs[((i % pairs.count) + pairs.count) % pairs.count]
        return LinearGradient(colors: [p.0, p.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    public static func chipShadow(_ i: Int) -> Color {
        [Color(hex: 0xff6a00), Color(hex: 0x6a4bff), Color(hex: 0x14a890),
         Color(hex: 0xff2d6d), Color(hex: 0x2d7bff)][((i % 5) + 5) % 5]
    }

    // Surfaces
    public static let bg = Color(light: Color(hex: 0xf3f6fc), dark: Color(hex: 0x06040c))
    public static let bg2 = Color(light: Color(hex: 0xffffff), dark: Color(hex: 0x0c0a14))
    public static let panel = Color(light: Color(hex: 0xffffff),
                                    dark: Color(.sRGB, white: 1, opacity: 0.03))
    public static let panelStrong = Color(light: Color(hex: 0xffffff),
                                          dark: Color(.sRGB, white: 1, opacity: 0.06))

    // Text
    public static let text = Color(light: Color(hex: 0x0f1828), dark: Color(hex: 0xe8edf5))
    public static let muted = Color(light: Color(hex: 0x5a6781), dark: Color(hex: 0x8a96ab))

    // Hairlines
    public static let line = Color(light: Color(.sRGB, red: 16/255, green: 26/255, blue: 48/255, opacity: 0.10),
                                   dark: Color(.sRGB, white: 1, opacity: 0.08))

    // Status colors
    public static let ok    = Color(hex: 0x39d98a)
    public static let warn  = Color(hex: 0xffae3d)
    public static let danger = Color(hex: 0xff5470)

    public static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentSoft],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Typography (Space Grotesk + JetBrains Mono, with safe fallbacks)

public enum BitFont {
    // Font family names; fall back to system if the .ttf isn't bundled yet.
    static let display = "Space Grotesk"
    static let mono = "JetBrains Mono"

    private static let hasDisplay: Bool = {
        #if canImport(UIKit)
        return UIFont(name: display, size: 12) != nil
        #else
        return NSFont(name: display, size: 12) != nil
        #endif
    }()
    private static let hasMono: Bool = {
        #if canImport(UIKit)
        return UIFont(name: mono, size: 12) != nil
        #else
        return NSFont(name: mono, size: 12) != nil
        #endif
    }()

    public static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        hasDisplay ? .custom(display, size: size).weight(weight)
                   : .system(size: size, weight: weight, design: .rounded)
    }

    public static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        hasMono ? .custom(mono, size: size).weight(weight)
                : .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Metrics

public enum BitMetric {
    public static let radius: CGFloat = 18
    public static let radiusSmall: CGFloat = 12
    public static let pad: CGFloat = 16
    public static let gap: CGFloat = 12
}

// MARK: - Theme preference

public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .system: return "Как на устройстве"
        case .light:  return "Светлая"
        case .dark:   return "Тёмная"
        }
    }
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
