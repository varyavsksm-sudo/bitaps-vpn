import SwiftUI
import WidgetKit

#if os(iOS)

/// Entry point for the bitaps WidgetKit extension (iOS only).
/// Bundles the home-screen status widget and — where ActivityKit is available —
/// the connection Live Activity (Lock Screen + Dynamic Island).
@main
struct BitapsWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        StatusWidget()
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            ConnectionLiveActivity()
        }
        #endif
    }
}

#endif
