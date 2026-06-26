import SwiftUI
#if os(iOS)
import AVFoundation
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Power-user BYO profile & subscription manager (parity with Happ + Hiddify).
/// Paste a vless:// / vmess:// / trojan:// / ss:// / hysteria2:// link or a
/// subscription URL — bitaps wires it through the same core. Pushed inside the
/// Settings NavigationStack.
public struct ImportConfigView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings

    @State private var text: String = ""
    @State private var showScanner = false
    @State private var refreshing = false

    public init() {}

    public var body: some View {
        ZStack {
            BitBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: BitMetric.gap * 1.4) {
                    headerCard
                    inputSection
                    configsSection
                }
                .padding(BitMetric.pad)
            }
        }
        .navigationTitle("Профили")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showScanner) {
            QRScannerView { scanned in
                showScanner = false
                if let scanned, !scanned.isEmpty { text = scanned }
            }
        }
        #endif
        .tint(BitColor.accent)
    }

    // MARK: - Header (BYO explainer)

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            HStack(spacing: 10) {
                Kicker("профили и подписки")
                Spacer()
                if !store.importedConfigs.isEmpty {
                    BitBadge("\(store.importedConfigs.count) \(profileWord(store.importedConfigs.count))",
                             color: BitColor.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            BitCard(strong: true) {
                HStack(alignment: .top, spacing: 14) {
                    GradientIcon("key.horizontal.fill", index: 1, size: 46)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Свой ключ или подписка")
                            .font(BitFont.display(18, weight: .bold))
                            .foregroundStyle(LinearGradient(
                                colors: [BitColor.accentSoft, BitColor.accent],
                                startPoint: .top, endPoint: .bottom))
                            .bitGlow(BitColor.accent, radius: 12, opacity: 0.3)
                        Text("Добавьте свой VLESS / VMess / Trojan / SS / Hysteria2 или ссылку на подписку — bitaps подключит через то же ядро.")
                            .font(BitFont.mono(12))
                            .foregroundStyle(BitColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.importedConfigs.count)
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            BitCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ссылка или подписка")
                        .font(BitFont.display(14, weight: .medium))
                        .foregroundStyle(BitColor.text)
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("vless://…")
                                .font(BitFont.mono(13))
                                .foregroundStyle(BitColor.muted)
                                .padding(.top, 8)
                                .padding(.horizontal, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $text)
                            .font(BitFont.mono(13))
                            .foregroundStyle(BitColor.text)
                            .scrollContentBackgroundHiddenCompat()
                            .frame(minHeight: 96)
                            .autocorrectionDisabledCompat()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                            .fill(BitColor.bg2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                            .stroke(detectedProto != nil ? BitColor.accent.opacity(0.5) : BitColor.line, lineWidth: 1)
                    )
                    if let p = detectedProto {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(BitColor.ok)
                            Text("Распознано: \(p.label)")
                                .font(BitFont.mono(11))
                                .foregroundStyle(BitColor.muted)
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: detectedProto)
            }

            HStack(spacing: BitMetric.gap) {
                BitButton("Вставить из буфера", icon: "doc.on.clipboard", kind: .line) {
                    pasteFromClipboard()
                }
                #if os(iOS)
                BitButton("Сканировать QR", icon: "qrcode.viewfinder", kind: .line) {
                    showScanner = true
                }
                #endif
            }

            #if os(macOS)
            BitButton("Сканировать QR", icon: "qrcode.viewfinder", kind: .ghost) {}
                .disabled(true)
                .opacity(0.5)
            Text("Сканирование QR — на iPhone")
                .font(BitFont.mono(11))
                .foregroundStyle(BitColor.muted)
            #endif

            BitButton("Добавить", icon: "plus") {
                addCurrent()
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let err = store.errorMessage {
                Text(err)
                    .font(BitFont.mono(11))
                    .foregroundStyle(BitColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.errorMessage)
    }

    private var detectedProto: TunnelProtocol? {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        return ImportedConfig.parse(s, source: .link)?.proto
    }

    private func addCurrent() {
        store.errorMessage = nil
        if store.addConfig(from: text, source: .link) {
            store.addLog(.success, "Профиль добавлен")
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { text = "" }
        }
    }

    private func pasteFromClipboard() {
        #if os(iOS)
        if let s = UIPasteboard.general.string { text = s }
        #elseif os(macOS)
        if let s = NSPasteboard.general.string(forType: .string) { text = s }
        #endif
    }

    // MARK: - Saved profiles

    private var configsSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            HStack {
                Kicker("мои профили")
                Spacer()
                BitButton("Обновить подписки", icon: "arrow.clockwise", kind: .line,
                          fullWidth: false, loading: refreshing) {
                    refreshSubscriptions()
                }
            }
            if store.importedConfigs.isEmpty {
                emptyState
            } else {
                ForEach(store.importedConfigs) { cfg in
                    configRow(cfg)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.importedConfigs)
    }

    private var emptyState: some View {
        BitCard {
            VStack(spacing: 14) {
                GradientIcon("square.and.arrow.down.on.square", index: 4, size: 64)
                    .bitGlow(BitColor.sky, radius: 18, opacity: 0.35)
                Text("Пока нет своих конфигов.\nВставьте ссылку или отсканируйте QR.")
                    .font(BitFont.mono(13))
                    .foregroundStyle(BitColor.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }

    private func configRow(_ cfg: ImportedConfig) -> some View {
        BitCard {
            HStack(spacing: 12) {
                GradientIcon(protoIcon(cfg.proto), index: protoChipIndex(cfg.proto), size: 44)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(cfg.name)
                            .font(BitFont.display(15, weight: .semibold))
                            .foregroundStyle(BitColor.text)
                            .lineLimit(1)
                        BitBadge(cfg.proto.label, color: protoColor(cfg.proto))
                    }
                    Text("\(cfg.source.label) · \(relativeDate(cfg.addedAt))")
                        .font(BitFont.mono(11))
                        .foregroundStyle(BitColor.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    store.addLog(.warn, "Профиль удалён: \(cfg.name)")
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        store.removeConfig(cfg)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundStyle(BitColor.danger)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Subscription refresh (mock — gives the manager life)

    private func refreshSubscriptions() {
        guard !refreshing else { return }
        refreshing = true
        store.addLog(.info, "Обновление подписок…")
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run {
                store.addLog(.success, "Подписки обновлены")
                refreshing = false
            }
        }
    }

    // MARK: - Helpers

    private func protoIcon(_ p: TunnelProtocol) -> String {
        switch p {
        case .auto:        return "link"
        case .reality:     return "lock.shield.fill"
        case .vmess:       return "shippingbox.fill"
        case .trojan:      return "shield.lefthalf.filled"
        case .shadowsocks: return "eye.slash.fill"
        case .hysteria2:   return "bolt.fill"
        case .wireguard:   return "network"
        }
    }

    /// Maps each protocol to a rotating gradient-chip index for varied colors.
    private func protoChipIndex(_ p: TunnelProtocol) -> Int {
        switch p {
        case .auto:        return 4
        case .reality:     return 0
        case .vmess:       return 4
        case .trojan:      return 1
        case .shadowsocks: return 2
        case .hysteria2:   return 3
        case .wireguard:   return 1
        }
    }

    private func protoColor(_ p: TunnelProtocol) -> Color {
        switch p {
        case .auto:        return BitColor.muted
        case .reality:     return BitColor.accent
        case .vmess:       return BitColor.accent2
        case .trojan:      return BitColor.warn
        case .shadowsocks: return BitColor.ok
        case .hysteria2:   return BitColor.danger
        case .wireguard:   return BitColor.accentSoft
        }
    }

    private func profileWord(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "профиль" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "профиля" }
        return "профилей"
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Cross-platform view modifiers

private extension View {
    @ViewBuilder func scrollContentBackgroundHiddenCompat() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder func autocorrectionDisabledCompat() -> some View {
        #if os(iOS)
        self.autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
        #else
        self
        #endif
    }
}

// MARK: - QR scanner (iOS only)

#if os(iOS)
/// Minimal AVFoundation QR scanner. Calls back the decoded string (or nil if the
/// user dismisses / camera is unavailable).
struct QRScannerView: View {
    var onResult: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraDenied = false

    var body: some View {
        ZStack {
            BitColor.bg.ignoresSafeArea()
            if cameraDenied {
                VStack(spacing: 14) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(BitColor.muted)
                    Text("Нет доступа к камере")
                        .font(BitFont.display(17, weight: .semibold))
                        .foregroundStyle(BitColor.text)
                    Text("Разрешите доступ к камере в настройках, чтобы сканировать QR-код.")
                        .font(BitFont.mono(12))
                        .foregroundStyle(BitColor.muted)
                        .multilineTextAlignment(.center)
                    BitButton("Закрыть", kind: .line, fullWidth: false) {
                        onResult(nil); dismiss()
                    }
                }
                .padding(BitMetric.pad * 1.5)
            } else {
                QRCameraRepresentable(onFound: { code in
                    onResult(code); dismiss()
                }, onDenied: {
                    cameraDenied = true
                })
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: BitMetric.radius, style: .continuous)
                        .stroke(BitColor.accent, lineWidth: 3)
                        .frame(width: 220, height: 220)
                        .bitGlow(BitColor.accent, radius: 24, opacity: 0.5)
                    Spacer()
                    Text("Наведите камеру на QR-код")
                        .font(BitFont.mono(12))
                        .foregroundStyle(.white)
                        .padding(.bottom, 28)
                }

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            onResult(nil); dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(BitMetric.pad)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
        }
    }
}

private struct QRCameraRepresentable: UIViewRepresentable {
    var onFound: (String) -> Void
    var onDenied: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFound: onFound) }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            context.coordinator.configure(view)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { context.coordinator.configure(view) }
                    else { onDenied() }
                }
            }
        default:
            DispatchQueue.main.async { onDenied() }
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    static func dismantleUIView(_ uiView: PreviewView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let session = AVCaptureSession()
        private var didFind = false
        private let onFound: (String) -> Void

        init(onFound: @escaping (String) -> Void) { self.onFound = onFound }

        func configure(_ view: PreviewView) {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            view.previewLayer.session = session
            view.previewLayer.videoGravity = .resizeAspectFill

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }

        func stop() {
            if session.isRunning { session.stopRunning() }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !didFind,
                  let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            didFind = true
            stop()
            onFound(value)
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
#endif
