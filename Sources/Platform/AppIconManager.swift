import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Switches the home-screen app icon (personalization). iOS supports alternate
/// icons via setAlternateIconName; the alternate PNGs are added to the bundle
/// and declared in build settings (ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS).
/// No-op on platforms without alternate icons.
public enum AppIconManager {
    public static func setIcon(_ option: AppIconOption) {
        #if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(option.altName) { _ in }
        #endif
    }
}
