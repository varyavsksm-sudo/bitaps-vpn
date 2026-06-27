import Foundation

// MARK: - Fmt — human formatting helpers (bytes / speed / duration)

public enum Fmt {
    /// 1536 → "1.5 КБ", 0 → "0 Б"
    public static func bytes(_ n: Int64) -> String {
        let units = [NSLocalizedString("Б", comment: ""), NSLocalizedString("КБ", comment: ""), NSLocalizedString("МБ", comment: ""), NSLocalizedString("ГБ", comment: ""), NSLocalizedString("ТБ", comment: ""), NSLocalizedString("ПБ", comment: "")]
        var x = Double(max(0, n)); var i = 0
        while x >= 1024 && i < units.count - 1 { x /= 1024; i += 1 }
        return i == 0 ? "\(Int(x)) \(units[i])" : String(format: "%.1f %@", x, units[i])
    }

    /// bytes/second → "12 Mbps" / "640 Kbps"
    public static func speed(_ bps: Double) -> String {
        let mbps = bps / 1_000_000
        if mbps >= 1 { return String(format: "%.0f Mbps", mbps) }
        return String(format: "%.0f Kbps", max(0, bps) / 1000)
    }

    /// seconds → "1:02:05" (with hours) or "02:05"
    public static func duration(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%02d:%02d", m, sec)
    }
}

// MARK: - AppError — user-facing errors across services

public enum AppError: LocalizedError {
    case network(String)
    case tunnel(String)
    case serverUnavailable
    case subscriptionExpired

    public var errorDescription: String? {
        switch self {
        case .network(let m):      return String(format: NSLocalizedString("Нет связи: %@", comment: ""), m)
        case .tunnel(let m):       return String(format: NSLocalizedString("Ошибка VPN: %@", comment: ""), m)
        case .serverUnavailable:   return NSLocalizedString("Сервер недоступен", comment: "")
        case .subscriptionExpired: return NSLocalizedString("Подписка истекла", comment: "")
        }
    }
}
