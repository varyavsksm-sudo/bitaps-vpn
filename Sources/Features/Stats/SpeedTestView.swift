import SwiftUI

/// Polished speed test. Pushed inside the Settings NavigationStack, so it uses
/// `.navigationTitle` and never creates its own stack. The dial is the
/// centerpiece: idle → "Запустить", testing → animated sweep, done → big Mbps.
public struct SpeedTestView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings

    public init() {}

    // Drives the indeterminate sweep while testing.
    @State private var sweep: Double = 0

    public var body: some View {
        ZStack {
            BitBackground()
            ScrollView {
                VStack(spacing: 24) {
                    dial
                    runButton
                    resultGrid
                    historySection
                    caption
                }
                .padding(BitMetric.pad)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Спид-тест")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { startSweep() }
        .onChange(of: store.isSpeedTesting) { testing in
            if testing { startSweep() } else { stopSweep() }
        }
        .onDisappear { stopSweep() }
    }

    private func startSweep() {
        guard store.isSpeedTesting else { return }
        sweep = 0
        withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
            sweep = 1
        }
    }

    /// Cancel the repeating sweep when the test ends or the view goes away,
    /// otherwise the repeatForever animation keeps mutating `sweep` in the background.
    private func stopSweep() {
        withAnimation(.easeOut(duration: 0.2)) { sweep = 0 }
    }

    // MARK: - Dial

    @ViewBuilder private var dial: some View {
        let result = store.speedTestResult
        // Normalize the down-speed onto the ring (0…200 Mbps span).
        let progress = min((result?.downMbps ?? 0) / 200, 1)

        let arcGradient = AngularGradient(
            colors: [BitColor.accentSoft, BitColor.accent, BitColor.magenta, BitColor.violet, BitColor.accentSoft],
            center: .center)

        ZStack {
            // Aurora glow halo behind the dial.
            Circle()
                .fill(BitColor.accent.opacity(0.10))
                .blur(radius: 40)

            // Track
            Circle()
                .stroke(BitColor.line, lineWidth: 14)

            if store.isSpeedTesting {
                // Indeterminate sweep arc.
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(arcGradient,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(sweep * 360 - 90))
                    .bitGlow(BitColor.accent, radius: 22, opacity: 0.6)
            } else {
                // Filled to the measured result (or empty when idle).
                Circle()
                    .trim(from: 0, to: max(0.0001, progress))
                    .stroke(arcGradient,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .bitGlow(BitColor.accent, radius: 20, opacity: 0.55)
                    .animation(.easeOut(duration: 0.7), value: progress)
            }

            dialCenter(result: result)
        }
        .frame(width: 240, height: 240)
        .padding(.top, 8)
    }

    @ViewBuilder private func dialCenter(result: SpeedTestResult?) -> some View {
        if store.isSpeedTesting {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(BitColor.accent)
                Text("Измеряю…")
                    .font(BitFont.mono(13, weight: .medium))
                    .foregroundStyle(BitColor.muted)
            }
            .transition(.opacity)
        } else if let result {
            VStack(spacing: 2) {
                Text("\(Int(result.downMbps))")
                    .font(BitFont.display(64, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [BitColor.accentSoft, BitColor.accent],
                                                    startPoint: .top, endPoint: .bottom))
                    .monospacedDigit()
                    .bitGlow(BitColor.accent, radius: 18, opacity: 0.4)
                Text("Mbps ↓")
                    .font(BitFont.mono(14, weight: .semibold))
                    .foregroundStyle(BitColor.accent)
            }
            .transition(.scale.combined(with: .opacity))
        } else {
            VStack(spacing: 10) {
                GradientIcon("gauge.with.dots.needle.bottom.50percent", index: 0, size: 54)
                Text("Запустить")
                    .font(BitFont.display(20, weight: .semibold))
                    .foregroundStyle(BitColor.text)
            }
        }
    }

    // MARK: - Run button

    @ViewBuilder private var runButton: some View {
        BitButton(store.isSpeedTesting ? "Идёт измерение…" : "Запустить тест",
                  icon: store.isSpeedTesting ? nil : "bolt.fill",
                  loading: store.isSpeedTesting) {
            Task { await store.runSpeedTest() }
        }
        .disabled(store.isSpeedTesting)
        .opacity(store.isSpeedTesting ? 0.7 : 1)
    }

    // MARK: - Result grid (2×2)

    @ViewBuilder private var resultGrid: some View {
        let r = store.speedTestResult
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("результат")
            VStack(spacing: BitMetric.gap) {
                HStack(spacing: BitMetric.gap) {
                    metricCell(icon: "arrow.down", chip: 0,
                               title: "Скачивание",
                               value: r.map { "\(Int($0.downMbps))" } ?? "—",
                               unit: "Mbps",
                               color: BitColor.accent)
                    metricCell(icon: "arrow.up", chip: 4,
                               title: "Отдача",
                               value: r.map { "\(Int($0.upMbps))" } ?? "—",
                               unit: "Mbps",
                               color: BitColor.sky)
                }
                HStack(spacing: BitMetric.gap) {
                    metricCell(icon: "timer", chip: 2,
                               title: "Пинг",
                               value: r.map { "\($0.pingMs)" } ?? "—",
                               unit: "ms",
                               color: BitColor.teal)
                    metricCell(icon: "waveform.path", chip: 3,
                               title: "Джиттер",
                               value: r.map { "\($0.jitterMs)" } ?? "—",
                               unit: "ms",
                               color: BitColor.magenta)
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: store.speedTestResult)
    }

    @ViewBuilder private func metricCell(icon: String, chip: Int, title: String,
                                         value: String, unit: String, color: Color) -> some View {
        BitCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    GradientIcon(icon, index: chip, size: 32)
                    Text(LocalizedStringKey(title))
                        .font(BitFont.mono(11, weight: .medium))
                        .foregroundStyle(BitColor.muted)
                }
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(LocalizedStringKey(value))
                        .font(BitFont.display(28, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [BitColor.accentSoft, color],
                                                        startPoint: .top, endPoint: .bottom))
                        .monospacedDigit()
                    Text(LocalizedStringKey(unit))
                        .font(BitFont.mono(12, weight: .medium))
                        .foregroundStyle(BitColor.muted)
                }
            }
        }
        .bitGlow(color, radius: 18, opacity: 0.14)
    }

    // MARK: - History

    private static let stampFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLanguage.currentLocale
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()

    @ViewBuilder private var historySection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("история")
            let items = store.speedHistory.reversed().map { $0 }
            if items.isEmpty {
                BitCard {
                    HStack(spacing: 12) {
                        GradientIcon("clock.arrow.circlepath", index: 2, size: 36)
                        Text("Пока нет замеров")
                            .font(BitFont.mono(13, weight: .medium))
                            .foregroundStyle(BitColor.muted)
                        Spacer()
                    }
                }
            } else {
                VStack(spacing: BitMetric.gap) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, r in
                        historyRow(r)
                    }
                }
            }
        }
    }

    @ViewBuilder private func historyRow(_ r: SpeedTestResult) -> some View {
        BitCard {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        speedTag(symbol: "arrow.down", value: r.downMbps, color: BitColor.accent)
                        speedTag(symbol: "arrow.up", value: r.upMbps, color: BitColor.sky)
                    }
                    Text(LocalizedStringKey(Self.stampFmt.string(from: r.at)))
                        .font(BitFont.mono(11))
                        .foregroundStyle(BitColor.muted.opacity(0.85))
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    miniStat(icon: "timer", value: "\(r.pingMs)", unit: "ms", color: BitColor.teal)
                    miniStat(icon: "waveform.path", value: "\(r.jitterMs)", unit: "ms", color: BitColor.magenta)
                }
            }
        }
    }

    @ViewBuilder private func speedTag(symbol: String, value: Double, color: Color) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            Text("\(Int(value))")
                .font(BitFont.display(22, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [BitColor.accentSoft, color],
                                                startPoint: .top, endPoint: .bottom))
                .monospacedDigit()
            Text("Mbps")
                .font(BitFont.mono(10, weight: .medium))
                .foregroundStyle(BitColor.muted)
        }
    }

    @ViewBuilder private func miniStat(icon: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(LocalizedStringKey(value))
                .font(BitFont.mono(13, weight: .semibold))
                .foregroundStyle(BitColor.text)
                .monospacedDigit()
            Text(LocalizedStringKey(unit))
                .font(BitFont.mono(10))
                .foregroundStyle(BitColor.muted)
        }
    }

    // MARK: - Caption

    @ViewBuilder private var caption: some View {
        VStack(spacing: 6) {
            if let city = store.selectedServer?.city {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text(String(format: NSLocalizedString("Тест через узел %@", comment: ""), NSLocalizedString(city, comment: "")))
                }
                .font(BitFont.mono(12, weight: .medium))
                .foregroundStyle(BitColor.muted)
            }
            if !store.isConnected {
                Text("Подключитесь для точного результата")
                    .font(BitFont.mono(11))
                    .foregroundStyle(BitColor.muted.opacity(0.8))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.bottom, 8)
    }
}
