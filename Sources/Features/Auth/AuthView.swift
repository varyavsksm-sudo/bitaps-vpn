import SwiftUI

/// Login screen. Telegram-first auth (with a demo fallback in this build),
/// an inline email-code path, and a "try demo" ghost option.
public struct AuthView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openURL) private var openURL

    @State private var showEmail = false
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var loadingTelegram = false
    @State private var loadingEmail = false
    @State private var loadingDemo = false

    private let termsURL = URL(string: "https://bitaps-vpn.surge.sh/terms.html")!
    private let privacyURL = URL(string: "https://bitaps-vpn.surge.sh/privacy.html")!

    public init() {}

    public var body: some View {
        ZStack {
            BitBackground()

            ScrollView {
                VStack(spacing: 26) {
                    Spacer(minLength: 52)

                    header

                    VStack(spacing: BitMetric.gap) {
                        telegramButton
                        emailSection
                        demoButton
                    }
                    .frame(maxWidth: 420)

                    finePrint
                        .frame(maxWidth: 420)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, BitMetric.pad)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 16) {
            BitLogo(size: 36, spinning: true)
                .bitGlow(BitColor.accent, radius: 40, opacity: 0.6)
                .padding(.bottom, 4)

            Text("Войдите в аккаунт")
                .font(BitFont.display(30, weight: .bold))
                .foregroundStyle(LinearGradient(
                    colors: [BitColor.accentSoft, BitColor.accent],
                    startPoint: .top, endPoint: .bottom))
                .bitGlow(BitColor.accent, radius: 22, opacity: 0.4)
                .multilineTextAlignment(.center)

            Text("Один аккаунт — все устройства")
                .font(BitFont.mono(13))
                .foregroundStyle(BitColor.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Telegram

    private var telegramButton: some View {
        BitButton("Войти через Telegram", icon: "paperplane.fill",
                  kind: .solid, loading: loadingTelegram) {
            openURL(TelegramAuth.loginURL())
            loadingTelegram = true
            Task {
                await store.loginWithTelegram()
                loadingTelegram = false
            }
        }
    }

    // MARK: - Email

    private var emailSection: some View {
        VStack(spacing: BitMetric.gap) {
            BitButton("Войти по email", icon: "envelope",
                      kind: .line) {
                withAnimation(.easeInOut(duration: 0.25)) { showEmail.toggle() }
            }

            if showEmail {
                BitCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            GradientIcon("envelope.fill", index: 4, size: 38)
                            Kicker("вход по почте")
                        }

                        field(text: $email, placeholder: "you@example.com",
                              icon: "envelope")
                            #if os(iOS)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            #endif

                        if codeSent {
                            field(text: $code, placeholder: "Код из письма",
                                  icon: "number")
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                        }

                        BitButton(codeSent ? "Войти" : "Получить код",
                                  icon: codeSent ? "arrow.right" : "paperplane",
                                  kind: .solid, loading: loadingEmail) {
                            if codeSent {
                                loadingEmail = true
                                Task {
                                    await store.loginWithTelegram()
                                    loadingEmail = false
                                }
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) { codeSent = true }
                            }
                        }

                        if codeSent {
                            Text("Код отправлен на \(email.isEmpty ? "почту" : email)")
                                .font(BitFont.mono(11))
                                .foregroundStyle(BitColor.muted)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func field(text: Binding<String>, placeholder: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(BitColor.accent)
                .frame(width: 18)
            TextField(placeholder, text: text)
                .font(BitFont.mono(14))
                .foregroundStyle(BitColor.text)
                .textFieldStyle(.plain)
                #if os(iOS)
                .autocorrectionDisabled(true)
                #endif
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                .fill(BitColor.bg2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                .stroke(BitColor.line, lineWidth: 1)
        )
    }

    // MARK: - Demo

    private var demoButton: some View {
        BitButton("Попробовать демо", icon: "play.circle",
                  kind: .ghost, loading: loadingDemo) {
            loadingDemo = true
            Task {
                await store.loginDemo()
                loadingDemo = false
            }
        }
    }

    // MARK: - Fine print

    private var finePrint: some View {
        VStack(spacing: 4) {
            Text("Продолжая, вы принимаете")
                .font(BitFont.mono(11))
                .foregroundStyle(BitColor.muted)
            HStack(spacing: 4) {
                Button {
                    openURL(termsURL)
                } label: {
                    Text("оферту")
                        .font(BitFont.mono(11, weight: .semibold))
                        .foregroundStyle(BitColor.accent)
                }
                .buttonStyle(.plain)

                Text("и")
                    .font(BitFont.mono(11))
                    .foregroundStyle(BitColor.muted)

                Button {
                    openURL(privacyURL)
                } label: {
                    Text("политику")
                        .font(BitFont.mono(11, weight: .semibold))
                        .foregroundStyle(BitColor.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.top, 6)
    }
}
