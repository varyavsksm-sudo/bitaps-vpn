import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Renders a string as a QR code (CoreImage, works on iOS + macOS). Used to
/// show the access key for quick import into a router / other client.
public struct QRView: View {
    let string: String
    var size: CGFloat
    public init(_ string: String, size: CGFloat = 160) {
        self.string = string
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white)
            if let img = Self.make(string) {
                img.interpolation(.none).resizable().scaledToFit().padding(10)
            } else {
                Image(systemName: "qrcode").font(.system(size: size * 0.5)).foregroundStyle(.black)
            }
        }
        .frame(width: size, height: size)
    }

    static func make(_ string: String) -> Image? {
        let ctx = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let out = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 9, y: 9)),
              let cg = ctx.createCGImage(out, from: out.extent) else { return nil }
        #if canImport(UIKit)
        return Image(uiImage: UIImage(cgImage: cg))
        #elseif canImport(AppKit)
        return Image(nsImage: NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)))
        #else
        return nil
        #endif
    }
}
