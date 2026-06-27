import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Live diagnostics console (Hiddify-style). Pushed inside the Settings
/// NavigationStack — it never creates its own. A terminal-style card streams
/// `store.logs` (newest first) with a timestamp, a level dot and the message in
/// monospace. Detailed sing-box lines will land here once the real core is wired.
public struct LogsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings

    @State private var copied = false

    public init() {}

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    public var body: some View {
        ZStack {
            BitBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: BitMetric.gap * 1.4) {
                    header
                    console
                    footnote
                }
                .padding(BitMetric.pad)
            }
        }
        .navigationTitle("Журнал")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    // MARK: - Header / actions

    private var header: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            BitCard(strong: true) {
                HStack(spacing: 14) {
                    GradientIcon("terminal", index: 2, size: 46)
                    VStack(alignment: .leading, spacing: 4) {
                        Kicker("diagnostics")
                        Text("Журнал ядра")
                            .font(BitFont.display(20, weight: .bold))
                            .foregroundStyle(LinearGradient(
                                colors: [BitColor.accentSoft, BitColor.accent],
                                startPoint: .top, endPoint: .bottom))
                            .bitGlow(BitColor.accent, radius: 14, opacity: 0.35)
                        Text("Живой поток событий туннеля")
                            .font(BitFont.mono(12))
                            .foregroundStyle(BitColor.muted)
                    }
                    Spacer(minLength: 0)
                    BitBadge(String(format: NSLocalizedString("%lld строк", comment: ""), store.logs.count),
                             color: store.logs.isEmpty ? BitColor.muted : BitColor.accent)
                        .animation(.easeInOut(duration: 0.2), value: store.logs.count)
                }
            }
            HStack(spacing: BitMetric.gap) {
                BitButton(copied ? "Скопировано" : "Копировать",
                          icon: copied ? "checkmark" : "doc.on.doc",
                          kind: .line, fullWidth: true) { copyAll() }
                    .disabled(store.logs.isEmpty)
                    .opacity(store.logs.isEmpty ? 0.5 : 1)
                BitButton("Очистить", icon: "trash", kind: .ghost, fullWidth: true) {
                    withAnimation(.easeInOut(duration: 0.2)) { store.clearLogs() }
                }
                .disabled(store.logs.isEmpty)
                .opacity(store.logs.isEmpty ? 0.5 : 1)
            }
        }
    }

    // MARK: - Console

    private var console: some View {
        BitCard(strong: true) {
            VStack(alignment: .leading, spacing: 10) {
                terminalChrome
                Divider().overlay(BitColor.line)
                if store.logs.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(store.logs) { entry in
                                row(entry)
                                    .transition(.opacity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 420)
                    .animation(.easeInOut(duration: 0.2), value: store.logs.count)
                }
            }
        }
    }

    private var terminalChrome: some View {
        HStack(spacing: 7) {
            ForEach([BitColor.danger, BitColor.warn, BitColor.ok], id: \.self) { c in
                Circle().fill(c.opacity(0.8)).frame(width: 9, height: 9)
            }
            Text("bitaps://core/log")
                .font(BitFont.mono(11))
                .foregroundStyle(BitColor.muted)
                .padding(.leading, 4)
            Spacer()
            if store.isConnected {
                HStack(spacing: 5) {
                    Circle().fill(BitColor.ok).frame(width: 6, height: 6).bitGlow(BitColor.ok, radius: 6, opacity: 0.7)
                    Text("live").font(BitFont.mono(10, weight: .semibold)).foregroundStyle(BitColor.ok)
                }
            }
        }
    }

    private func row(_ entry: LogEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(LocalizedStringKey(Self.timeFmt.string(from: entry.time)))
                .font(BitFont.mono(11))
                .foregroundStyle(BitColor.muted)
            Circle()
                .fill(Color(hex: entry.level.color))
                .frame(width: 7, height: 7)
                .padding(.top, 3)
            Text(LocalizedStringKey(entry.text))
                .font(BitFont.mono(12))
                .foregroundStyle(BitColor.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            GradientIcon("text.alignleft", index: 4, size: 56)
                .bitGlow(BitColor.sky, radius: 16, opacity: 0.3)
            Text("Журнал пуст — подключитесь, чтобы увидеть события.")
                .font(BitFont.mono(12))
                .foregroundStyle(BitColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }

    private var footnote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(BitColor.accent)
            Text("Подробные логи ядра sing-box появятся здесь, когда боевое ядро будет подключено.")
                .font(BitFont.mono(11))
                .foregroundStyle(BitColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Clipboard

    private func copyAll() {
        let lines = store.logs.map { e in
            "\(Self.timeFmt.string(from: e.time)) [\(e.level.rawValue)] \(e.text)"
        }.joined(separator: "\n")
        #if os(iOS)
        UIPasteboard.general.string = lines
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines, forType: .string)
        #endif
        withAnimation(.easeInOut(duration: 0.2)) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.2)) { copied = false }
        }
    }
}
