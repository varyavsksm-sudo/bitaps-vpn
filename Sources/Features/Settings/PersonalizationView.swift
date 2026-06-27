import SwiftUI

/// Персонализация — единый экран, где приложение делается «своим»: альтернативная
/// иконка, акцентный цвет и вид кнопки подключения. Пушится из настроек, поэтому
/// своего NavigationStack не заводит. Всё на стеклянных карточках (BitCard).
public struct PersonalizationView: View {
    @EnvironmentObject var settings: Settings

    public init() {}

    private let iconColumns = [GridItem(.adaptive(minimum: 96), spacing: BitMetric.gap)]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BitMetric.gap * 1.7) {
                header
                appIconSection
                accentSection
                connectButtonSection
            }
            .padding(BitMetric.pad)
        }
        .background(BitBackground())
        .navigationTitle("Персонализация")
    }

    // MARK: - Header

    private var header: some View {
        BitCard(strong: true) {
            HStack(spacing: 14) {
                GradientIcon("paintpalette.fill", index: 1, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Сделай bitaps своим")
                        .font(BitFont.display(18, weight: .semibold))
                        .foregroundStyle(BitColor.text)
                    Text("Иконка, цвет и кнопка — под твой вкус")
                        .font(BitFont.mono(12))
                        .foregroundStyle(BitColor.muted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - 1. Иконка приложения

    private var appIconSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("иконка приложения")
            BitCard {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: iconColumns, spacing: BitMetric.gap) {
                        ForEach(AppIconOption.allCases) { option in
                            iconTile(option)
                        }
                    }
                    Text("На iOS меняет иконку на домашнем экране")
                        .font(BitFont.mono(11))
                        .foregroundStyle(BitColor.muted)
                }
            }
        }
    }

    private func iconTile(_ option: AppIconOption) -> some View {
        let selected = settings.appIcon == option
        let color = Color(hex: option.hex)
        return Button {
            settings.appIcon = option
            AppIconManager.setIcon(option)
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    iconPreview(color: color, selected: selected)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white, color)
                            .background(Circle().fill(BitColor.bg2).padding(2))
                            .offset(x: 6, y: -6)
                    }
                }
                Text(LocalizedStringKey(option.label))
                    .font(BitFont.mono(12, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? BitColor.text : BitColor.muted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
    }

    /// Превью иконки: скруглённый квадрат с «шестерёнкой-B» в выбранном цвете.
    private func iconPreview(color: Color, selected: Bool) -> some View {
        let side: CGFloat = 72
        return RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
            .fill(
                LinearGradient(colors: [color.opacity(0.95), color.opacity(0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: side, height: side)
            .overlay(gearGlyph(color: color, side: side))
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                    .stroke(BitColor.accent, lineWidth: selected ? 2.5 : 0)
                    .padding(-4)
            )
            .shadow(color: color.opacity(0.45), radius: 10, x: 0, y: 6)
            .scaleEffect(selected ? 1.05 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
    }

    /// Простая шестерёнка (зубцы + тело + ступица) с «B» — узнаваемый знак bitaps.
    private func gearGlyph(color: Color, side: CGFloat) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: side * 0.04, style: .continuous)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: side * 0.12, height: side * 0.16)
                    .offset(y: -side * 0.32)
                    .rotationEffect(.degrees(Double(i) / 8 * 360))
            }
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: side * 0.56, height: side * 0.56)
            Circle()
                .fill(color)
                .frame(width: side * 0.40, height: side * 0.40)
            Text("B")
                .font(BitFont.display(side * 0.28, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - 2. Акцент

    private var accentSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("акцент")
            BitCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Цвет акцента")
                            .font(BitFont.display(15, weight: .medium))
                            .foregroundStyle(BitColor.text)
                        Spacer()
                        Text(LocalizedStringKey(settings.accent.label))
                            .font(BitFont.mono(13))
                            .foregroundStyle(BitColor.accent)
                    }
                    HStack(spacing: 16) {
                        ForEach(AccentTheme.allCases) { theme in
                            accentSwatch(theme)
                        }
                        Spacer(minLength: 0)
                    }
                    Text("Цвет акцента всего приложения")
                        .font(BitFont.mono(11))
                        .foregroundStyle(BitColor.muted)
                }
            }
        }
    }

    private func accentSwatch(_ theme: AccentTheme) -> some View {
        let selected = settings.accent == theme
        return Button {
            settings.accent = theme
        } label: {
            Circle()
                .fill(Color(hex: theme.hexes.0))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(BitColor.text, lineWidth: selected ? 2 : 0)
                        .padding(-4)
                )
                .bitGlow(Color(hex: theme.hexes.0), radius: selected ? 12 : 0,
                         opacity: selected ? 0.6 : 0)
                .scaleEffect(selected ? 1.12 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.label)
    }

    // MARK: - 3. Кнопка подключения

    private var connectButtonSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("кнопка подключения")
            BitCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Вид кнопки")
                            .font(BitFont.display(15, weight: .medium))
                            .foregroundStyle(BitColor.text)
                        Spacer()
                        Text(LocalizedStringKey(settings.connectButton.label))
                            .font(BitFont.mono(13))
                            .foregroundStyle(BitColor.accent)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(ConnectButtonStyle.allCases) { style in
                                connectStylePreview(style)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Text("Так будет выглядеть большая кнопка на главном экране")
                        .font(BitFont.mono(11))
                        .foregroundStyle(BitColor.muted)
                }
            }
        }
    }

    private func connectStylePreview(_ style: ConnectButtonStyle) -> some View {
        let selected = settings.connectButton == style
        return Button {
            settings.connectButton = style
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(BitColor.panel)
                        .frame(width: 112, height: 112)
                        .overlay(
                            Circle().stroke(selected ? BitColor.accent : BitColor.line,
                                            lineWidth: selected ? 2 : 1)
                        )
                    PowerButton(status: .connected, style: style) {}
                        .scaleEffect(0.4)
                        .frame(width: 112, height: 112)
                        .allowsHitTesting(false)
                }
                .bitGlow(BitColor.accent, radius: selected ? 14 : 0, opacity: selected ? 0.5 : 0)
                Text(LocalizedStringKey(style.label))
                    .font(BitFont.mono(12, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? BitColor.text : BitColor.muted)
            }
            .scaleEffect(selected ? 1.05 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.label)
    }
}
