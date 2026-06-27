import Foundation

// MARK: - Live in-app language switching
//
// SwiftUI's `Text("literal")` resolves its key through `Bundle.main`'s
// `localizedString(forKey:value:table:)`. The `\.locale` environment only drives
// number/date formatting — it does NOT pick which `.lproj` table is used. So to
// flip the whole UI language at runtime we swap the table source itself: we
// re-class `Bundle.main` to a subclass that delegates every lookup to the chosen
// `<code>.lproj` sub-bundle. Combined with a full view rebuild (RootView `.id`),
// every visible string re-localizes instantly — no app restart needed.

private var kAssociatedLanguageBundle: UInt8 = 0

private final class LocalizedMainBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = objc_getAssociatedObject(self, &kAssociatedLanguageBundle) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

public enum AppLanguage {
    /// Point `Bundle.main` at the `<code>.lproj` table (e.g. "en" / "ru").
    /// Call at launch and on every language change, then rebuild the view tree.
    public static func apply(_ code: String) {
        _ = swizzleOnce
        let lproj = Bundle.main.path(forResource: code, ofType: "lproj").flatMap { Bundle(path: $0) }
        objc_setAssociatedObject(Bundle.main, &kAssociatedLanguageBundle,
                                 lproj, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Re-class `Bundle.main` exactly once so our override takes effect.
    private static let swizzleOnce: Void = {
        object_setClass(Bundle.main, LocalizedMainBundle.self)
    }()

    /// The locale the user picked in-app — for DateFormatter/RelativeDateTimeFormatter
    /// so dates/months follow the chosen language, not the system.
    public static var currentLocale: Locale {
        let en = UserDefaults.standard.string(forKey: "bitaps.language") == "English"
        return Locale(identifier: en ? "en_US" : "ru_RU")
    }
}
