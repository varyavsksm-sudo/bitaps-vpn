import Foundation

// MARK: - Accent themes (our individuality)
// Lives in Shared so both the app and the widget extension can use it
// (BitColor in Theme.swift depends on it).

public enum AccentTheme: String, CaseIterable, Identifiable, Sendable, Codable {
    case sunset     // brand default — orange
    case neon       // electric blue/cyan
    case emerald
    case lavender
    case crimson

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .sunset:   return "Закат"
        case .neon:     return "Неон"
        case .emerald:  return "Изумруд"
        case .lavender: return "Лаванда"
        case .crimson:  return "Багровый"
        }
    }
    /// (main, soft) hex pair.
    public var hexes: (UInt32, UInt32) {
        switch self {
        case .sunset:   return (0xff7a1a, 0xffae3d)
        case .neon:     return (0x2de2ff, 0x6aa8ff)
        case .emerald:  return (0x19d98a, 0x6ff0bd)
        case .lavender: return (0xa779ff, 0xd0b3ff)
        case .crimson:  return (0xff4d6d, 0xff9bad)
        }
    }
}
