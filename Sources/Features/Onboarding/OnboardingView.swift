import SwiftUI

/// Splash + 3-slide intro shown before the user has onboarded.
/// Page-style carousel on iOS, manual paging fallback on macOS (TabView
/// `.page` style isn't available on macOS).
public struct OnboardingView: View {
    @EnvironmentObject var store: AppStore

    @State private var page = 0

    private let slides: [Slide] = [
        Slide(symbol: "bolt.horizontal.circle.fill",
              isLogo: true,
              colorIndex: 0,
              title: "bitaps VPN",
              subtitle: "Свобода и приватность\nв один тап"),
        Slide(symbol: "lock.shield.fill",
              isLogo: false,
              colorIndex: 1,
              title: "Приватность",
              subtitle: "Без логов и слежки.\nVLESS + Reality прячет\nтрафик под обычный сайт."),
        Slide(symbol: "bolt.fill",
              isLogo: false,
              colorIndex: 2,
              title: "Скорость",
              subtitle: "До 2 Гбит/с и обход\nлюбых блокировок.\nБез тормозов."),
    ]

    public init() {}

    private var isLast: Bool { page >= slides.count - 1 }

    public var body: some View {
        ZStack {
            BitBackground()

            VStack(spacing: 0) {
                // Top bar: skip
                HStack {
                    Spacer()
                    Button(action: { store.completeOnboarding() }) {
                        Text("Пропустить")
                            .font(BitFont.mono(13, weight: .medium))
                            .foregroundStyle(BitColor.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, BitMetric.pad)
                .padding(.top, 8)

                // Slides
                #if os(iOS)
                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { idx, slide in
                        SlideView(slide: slide).tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                #else
                macSlides
                #endif

                // Dots
                HStack(spacing: 9) {
                    ForEach(slides.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == page
                                  ? AnyShapeStyle(BitColor.accentGradient)
                                  : AnyShapeStyle(BitColor.line))
                            .frame(width: i == page ? 26 : 8, height: 8)
                            .bitGlow(i == page ? BitColor.accent : .clear,
                                     radius: 10, opacity: i == page ? 0.6 : 0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: page)
                    }
                }
                .padding(.bottom, 24)

                // Primary action
                BitButton(isLast ? "Поехали" : "Далее",
                          icon: isLast ? "arrow.right" : nil) {
                    if isLast {
                        store.completeOnboarding()
                    } else {
                        withAnimation(.easeInOut(duration: 0.35)) { page += 1 }
                    }
                }
                .padding(.horizontal, BitMetric.pad)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 520)
        }
    }

    // MARK: - macOS manual paging

    #if os(macOS)
    private var macSlides: some View {
        ZStack {
            SlideView(slide: slides[page])
                .id(page)
                .transition(.opacity)

            HStack {
                arrow(system: "chevron.left", disabled: page == 0) {
                    withAnimation(.easeInOut(duration: 0.3)) { page = max(0, page - 1) }
                }
                Spacer()
                arrow(system: "chevron.right", disabled: isLast) {
                    withAnimation(.easeInOut(duration: 0.3)) { page = min(slides.count - 1, page + 1) }
                }
            }
            .padding(.horizontal, 6)
        }
        .animation(.easeInOut(duration: 0.3), value: page)
    }

    private func arrow(system: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(BitColor.text)
                .frame(width: 40, height: 40)
                .background(Circle().fill(BitColor.panelStrong))
                .overlay(Circle().stroke(BitColor.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0 : 1)
        .disabled(disabled)
    }
    #endif
}

// MARK: - Slide model + view

private struct Slide {
    let symbol: String
    let isLogo: Bool
    let colorIndex: Int
    let title: String
    let subtitle: String
}

private struct SlideView: View {
    let slide: Slide
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            // Icon / logo mark
            ZStack {
                Circle()
                    .fill(BitColor.chipShadow(slide.colorIndex).opacity(0.16))
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                Circle()
                    .stroke(LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.03)],
                        startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    .frame(width: 196, height: 196)

                if slide.isLogo {
                    GearMark(size: 96, spinning: true)
                        .bitGlow(BitColor.accent, radius: 36, opacity: 0.55)
                } else {
                    GradientIcon(slide.symbol, index: slide.colorIndex, size: 116)
                        .bitGlow(BitColor.chipShadow(slide.colorIndex), radius: 34, opacity: 0.55)
                }
            }
            .scaleEffect(appeared ? 1 : 0.86)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 14) {
                Text(LocalizedStringKey(slide.title))
                    .font(BitFont.display(36, weight: .bold))
                    .foregroundStyle(LinearGradient(
                        colors: [BitColor.accentSoft, BitColor.accent],
                        startPoint: .top, endPoint: .bottom))
                    .bitGlow(BitColor.accent, radius: 24, opacity: 0.4)
                    .multilineTextAlignment(.center)

                Text(LocalizedStringKey(slide.subtitle))
                    .font(BitFont.mono(15))
                    .foregroundStyle(BitColor.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) { appeared = true }
        }
    }
}
