import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Личный кабинет («Кабинет») — зеркало account.html на сайте.
/// Управление подпиской, ключом доступа, рефералкой, B-box, поддержкой и аккаунтом.
public struct AccountView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings
    @Environment(\.openURL) private var openURL

    // Локальный UI-стейт
    @State private var copiedKey = false
    @State private var copiedRef = false
    @State private var showRegenAlert = false
    @State private var regenerating = false
    @State private var expandedFAQ: Set<String> = []
    @State private var showBoxOrder = false
    @State private var supportMessage = ""
    @State private var supportSent = false
    @State private var sendingSupport = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BitMetric.gap + 6) {
                    profileCard
                    subscriptionCard
                    accessKeyCard
                    referralCard
                    bboxCard
                    supportCard
                    faqCard
                    footer
                }
                .padding(BitMetric.pad)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(BitBackground())
            .navigationTitle("Кабинет")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }

    // MARK: - 1. Профиль

    private var profileCard: some View {
        BitCard(strong: true) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(BitColor.accentGradient)
                        .frame(width: 64, height: 64)
                        .bitGlow(BitColor.accent, radius: 16, opacity: 0.5)
                    Text(LocalizedStringKey(initials))
                        .font(BitFont.display(24, weight: .bold))
                        .foregroundStyle(.black)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedStringKey(store.user?.displayName ?? "Гость"))
                        .font(BitFont.display(20, weight: .bold))
                        .foregroundStyle(BitColor.text)
                    Text(LocalizedStringKey(handleLine))
                        .font(BitFont.mono(12))
                        .foregroundStyle(BitColor.muted)
                    HStack(spacing: 6) {
                        if let sub = store.subscription {
                            BitBadge(sub.status.label, color: statusColor(sub.status), filled: true)
                        }
                        if store.user?.isDemo == true {
                            BitBadge("DEMO", color: BitColor.muted)
                        }
                    }
                    .padding(.top, 1)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var initials: String {
        let name = store.user?.displayName ?? "Г"
        let parts = name.split(separator: " ").prefix(2)
        let chars = parts.compactMap { $0.first }.map(String.init)
        let joined = chars.joined().uppercased()
        return joined.isEmpty ? "Г" : joined
    }

    private var handleLine: String {
        store.user?.telegramHandle ?? store.user?.email ?? "demo"
    }

    private func statusColor(_ s: SubscriptionStatus) -> Color {
        switch s {
        case .active, .trial: return BitColor.ok
        case .expired:        return BitColor.danger
        case .none:           return BitColor.muted
        }
    }

    // MARK: - 2. Подписка (центр композиции)

    private var subscriptionCard: some View {
        BitCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    GradientIcon("crown.fill", index: 1, size: 42)
                    Kicker("подписка")
                    Spacer(minLength: 0)
                }
                HStack(alignment: .center, spacing: 18) {
                    RingGauge(value: ringValue,
                              color: ringColor,
                              label: ringLabel,
                              caption: "осталось")

                    VStack(alignment: .leading, spacing: 7) {
                        Text(LocalizedStringKey(store.subscription?.planTitle ?? "Нет тарифа"))
                            .font(BitFont.display(22, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [BitColor.accentSoft, BitColor.accent],
                                                            startPoint: .top, endPoint: .bottom))
                            .bitGlow(BitColor.accent, radius: 14, opacity: 0.35)
                        Label(expiresLine, systemImage: "calendar")
                            .font(BitFont.mono(12))
                            .foregroundStyle(BitColor.muted)
                        Label(devicesLine, systemImage: "iphone")
                            .font(BitFont.mono(12))
                            .foregroundStyle(BitColor.muted)
                    }
                    Spacer(minLength: 0)
                }

                NavigationLink {
                    SubscriptionView()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Продлить подписку")
                            .font(BitFont.display(16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .padding(.horizontal, 18)
                    .foregroundStyle(.black)
                    .background(BitColor.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous))
                    .bitGlow(BitColor.accent, radius: 20, opacity: 0.45)
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Image(systemName: "star.fill").font(.system(size: 11))
                    Text("оплата через Telegram Stars ⭐️")
                }
                .font(BitFont.mono(11))
                .foregroundStyle(BitColor.muted)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var daysLeft: Int { store.subscription?.daysLeft ?? 0 }

    private var ringValue: Double { min(Double(daysLeft) / 30.0, 1) }

    private var ringLabel: String { String(format: NSLocalizedString("%lldд", comment: ""), daysLeft) }

    private var ringColor: Color {
        switch daysLeft {
        case ..<3:  return BitColor.danger
        case ..<7:  return BitColor.warn
        default:    return BitColor.accent
        }
    }

    private var expiresLine: String {
        guard let date = store.subscription?.expires else { return NSLocalizedString("бессрочно", comment: "") }
        let f = DateFormatter()
        f.locale = AppLanguage.currentLocale
        f.dateStyle = .medium
        f.timeStyle = .none
        return String(format: NSLocalizedString("до %@", comment: ""), f.string(from: date))
    }

    private var devicesLine: String {
        guard let sub = store.subscription else { return NSLocalizedString("Устройства: —", comment: "") }
        return String(format: NSLocalizedString("Устройства: %lld/%lld", comment: ""), sub.devicesUsed, sub.deviceLimit)
    }

    // MARK: - 3. Ключ доступа

    private var accessKeyCard: some View {
        BitCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    GradientIcon("qrcode", index: 4, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Kicker("ключ доступа")
                        Text("Для роутера и ручной настройки в другом клиенте")
                            .font(BitFont.mono(12))
                            .foregroundStyle(BitColor.muted)
                    }
                    Spacer(minLength: 0)
                }

                QRView(store.accessKey?.vless ?? "", size: 150)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: BitMetric.radius, style: .continuous)
                            .fill(.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BitMetric.radius, style: .continuous)
                            .stroke(BitColor.accent.opacity(0.35), lineWidth: 1)
                    )
                    .bitGlow(BitColor.accent, radius: 20, opacity: 0.3)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(LocalizedStringKey(store.accessKey?.masked ?? "ключ ещё не выпущен"))
                    .font(BitFont.mono(13))
                    .foregroundStyle(BitColor.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                            .fill(BitColor.panelStrong)
                    )

                HStack(spacing: BitMetric.gap) {
                    BitButton(copiedKey ? "Скопировано ✓" : "Копировать",
                              icon: copiedKey ? "checkmark" : "doc.on.clipboard",
                              kind: .line) {
                        if let v = store.accessKey?.vless { copyToClipboard(v) }
                        flash($copiedKey)
                    }
                    BitButton("Обновить ключ", icon: "arrow.clockwise", kind: .ghost,
                              loading: regenerating) {
                        showRegenAlert = true
                    }
                }
            }
        }
        .alert("Обновить ключ?", isPresented: $showRegenAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Обновить", role: .destructive) {
                regenerating = true
                Task {
                    await store.regenerateKey()
                    regenerating = false
                }
            }
        } message: {
            Text("Старый ключ перестанет работать. Все устройства потребуют новый ключ.")
        }
    }

    // MARK: - 4. Рефералка

    private var referralCard: some View {
        BitCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    GradientIcon("gift.fill", index: 3, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Kicker("пригласи друзей")
                        Text("Приглашай — получай бонусные дни")
                            .font(BitFont.display(17, weight: .semibold))
                            .foregroundStyle(BitColor.text)
                    }
                    Spacer(minLength: 0)
                }
                Text("За каждого друга с подпиской — бонусные дни")
                    .font(BitFont.mono(12))
                    .foregroundStyle(BitColor.muted)

                HStack(spacing: BitMetric.gap) {
                    statTile("\(store.referral?.invited ?? 0)", "друзей", index: 1)
                    statTile("\(store.referral?.subscribed ?? 0)", "с подпиской", index: 2)
                    statTile("\(store.referral?.bonusDays ?? 0)", "дней получено", index: 0)
                }

                Text(LocalizedStringKey(store.referral?.link ?? "—"))
                    .font(BitFont.mono(12))
                    .foregroundStyle(BitColor.accentSoft)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Capsule().fill(BitColor.panelStrong))

                HStack(spacing: BitMetric.gap) {
                    BitButton(copiedRef ? "Скопировано ✓" : "Копировать",
                              icon: copiedRef ? "checkmark" : "doc.on.clipboard",
                              kind: .line) {
                        if let l = store.referral?.link { copyToClipboard(l) }
                        flash($copiedRef)
                    }
                    #if os(iOS)
                    if let link = store.referral?.link {
                        ShareLink(item: link) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Поделиться").font(BitFont.display(16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13).padding(.horizontal, 18)
                            .foregroundStyle(BitColor.text)
                            .background(BitColor.panel)
                            .clipShape(RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    #endif
                }
            }
        }
    }

    private func statTile(_ value: String, _ caption: String, index: Int) -> some View {
        VStack(spacing: 4) {
            Text(LocalizedStringKey(value))
                .font(BitFont.display(26, weight: .bold))
                .foregroundStyle(BitColor.chipGradient(index))
                .bitGlow(BitColor.chipShadow(index), radius: 10, opacity: 0.35)
            Text(LocalizedStringKey(caption))
                .font(BitFont.mono(10))
                .foregroundStyle(BitColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                .fill(BitColor.panelStrong)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                .stroke(BitColor.chipShadow(index).opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - 5. B-box

    private var bboxCard: some View {
        BitCard(strong: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    GradientIcon("wifi.router", index: 0, size: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("B-box — VPN для всего дома")
                            .font(BitFont.display(17, weight: .bold))
                            .foregroundStyle(BitColor.text)
                        BitBadge("hardware", color: BitColor.accent)
                    }
                    Spacer(minLength: 0)
                }
                Text("Умная коробочка для роутера: тихая, компактная, защищает все устройства сразу — без настроек.")
                    .font(BitFont.mono(12))
                    .foregroundStyle(BitColor.muted)
                BitButton("Заказать B-box", icon: "shippingbox.fill", kind: .solid) {
                    showBoxOrder = true
                }
            }
        }
        .bitGlow(BitColor.accent, radius: 22, opacity: 0.18)
        .sheet(isPresented: $showBoxOrder) {
            BBoxOrderView()
                .environmentObject(store)
                #if os(macOS)
                .frame(minWidth: 420, minHeight: 540)
                #endif
        }
    }

    /// Личный контакт в Telegram (ник + ссылка). Используется в заказе и поддержке.
    private func contactRow(label: String) -> some View {
        Button {
            openURL(TelegramAuth.personalURL())
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(BitColor.accent2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(LocalizedStringKey(label))
                        .font(BitFont.mono(11))
                        .foregroundStyle(BitColor.muted)
                    Text(LocalizedStringKey(TelegramAuth.personalHandle))
                        .font(BitFont.mono(13, weight: .semibold))
                        .foregroundStyle(BitColor.text)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BitColor.muted)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 6. Поддержка

    private var supportCard: some View {
        BitCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    GradientIcon("bubble.left.and.bubble.right.fill", index: 2, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Kicker("поддержка")
                        Text("Опишите вопрос — ответим на вашу почту, обычно в течение дня.")
                            .font(BitFont.mono(12))
                            .foregroundStyle(BitColor.muted)
                    }
                    Spacer(minLength: 0)
                }

                ZStack(alignment: .topLeading) {
                    if supportMessage.isEmpty {
                        Text("Опишите вопрос…")
                            .font(BitFont.mono(13))
                            .foregroundStyle(BitColor.muted)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    TextEditor(text: $supportMessage)
                        .font(BitFont.mono(13))
                        .foregroundStyle(BitColor.text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 92)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        #if os(iOS)
                        .textInputAutocapitalization(.sentences)
                        #endif
                }
                .background(
                    RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                        .fill(BitColor.panelStrong)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                        .stroke(BitColor.line, lineWidth: 1)
                )

                BitButton(supportSent ? "Сообщение отправлено!" : "Отправить сообщение",
                          icon: supportSent ? "checkmark.circle.fill" : "paperplane.fill",
                          kind: .solid, loading: sendingSupport) {
                    let msg = supportMessage
                    sendingSupport = true
                    Task {
                        let ok = await store.sendSupport(msg)
                        sendingSupport = false
                        if ok {
                            supportMessage = ""
                            flash($supportSent, after: 2.0)
                        }
                    }
                }

                contactRow(label: "Или написать напрямую")
            }
        }
    }

    // MARK: - 7. FAQ (аккордеон)

    private var faqCard: some View {
        BitCard {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    GradientIcon("questionmark.circle.fill", index: 0, size: 42)
                    Kicker("частые вопросы")
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 4)
                ForEach(Array(store.faq.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { Divider().overlay(BitColor.line) }
                    faqRow(item)
                }
            }
        }
    }

    private func faqRow(_ item: FAQItem) -> some View {
        let expanded = expandedFAQ.contains(item.id)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    if expanded { expandedFAQ.remove(item.id) } else { expandedFAQ.insert(item.id) }
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Text(LocalizedStringKey(item.q))
                        .font(BitFont.display(15, weight: .medium))
                        .foregroundStyle(BitColor.text)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(BitColor.accent)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if expanded {
                Text(LocalizedStringKey(item.a))
                    .font(BitFont.mono(13))
                    .foregroundStyle(BitColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - 8. Подвал

    private var footer: some View {
        BitCard {
            VStack(alignment: .leading, spacing: 14) {
                BitButton("Выйти", icon: "rectangle.portrait.and.arrow.right", kind: .line) {
                    Task { await store.logout() }
                }
                HStack(spacing: 6) {
                    BitLogo(size: 13)
                    Text("· 1.0")
                }
                .font(BitFont.mono(11))
                .foregroundStyle(BitColor.muted)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Helpers

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    /// Кратковременно зажигает булев флаг (для «Скопировано ✓» и т.п.).
    private func flash(_ flag: Binding<Bool>, after: Double = 1.4) {
        withAnimation(.easeInOut(duration: 0.2)) { flag.wrappedValue = true }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(after * 1_000_000_000))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) { flag.wrappedValue = false }
            }
        }
    }
}

// MARK: - B-box order (in-app form, no Mini App)

/// Простая форма заказа B-box прямо в приложении.
struct BBoxOrderView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var city = ""
    @State private var address = ""
    @State private var placing = false
    @State private var done = false

    private var canOrder: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        phone.trimmingCharacters(in: .whitespaces).count >= 6 &&
        !city.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            BitBackground()
            if done { successView } else { form }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Заказ B-box").font(BitFont.display(24, weight: .bold))
                            .foregroundStyle(BitColor.text)
                        Text("VPN для всего дома · 15 000 ₽")
                            .font(BitFont.mono(13)).foregroundStyle(BitColor.accent)
                    }
                    Spacer()
                    closeButton
                }
                BitCard {
                    VStack(spacing: 12) {
                        field("Имя", text: $name)
                        field("Телефон", text: $phone, phone: true)
                        field("Город", text: $city)
                        field("Адрес доставки", text: $address)
                    }
                }
                Text("Доставка по России. После заказа свяжемся для подтверждения и оплаты.")
                    .font(BitFont.mono(11)).foregroundStyle(BitColor.muted)
                BitButton("Оформить заказ", icon: "shippingbox.fill", kind: .solid, loading: placing) {
                    placing = true
                    store.addLog(.info, "Оформление заказа B-box…")
                    // Actually submit the order through the support channel.
                    let order = """
                    Заказ B-box
                    Имя: \(name)
                    Телефон: \(phone)
                    Город: \(city)
                    Адрес: \(address)
                    """
                    Task {
                        let ok = await store.sendSupport(order)
                        placing = false
                        if ok {
                            store.addLog(.success, "Заказ B-box принят")
                            withAnimation { done = true }
                        }
                    }
                }
                .disabled(!canOrder || placing)
                .opacity(canOrder ? 1 : 0.5)
            }
            .padding(BitMetric.pad)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(BitColor.ok.opacity(0.15)).frame(width: 96, height: 96)
                Image(systemName: "checkmark").font(.system(size: 40, weight: .bold))
                    .foregroundStyle(BitColor.ok)
            }
            .bitGlow(BitColor.ok, radius: 24, opacity: 0.4)
            Text("Заказ принят!").font(BitFont.display(22, weight: .bold)).foregroundStyle(BitColor.text)
            Text("Свяжемся с вами по телефону\nдля подтверждения и доставки.")
                .font(BitFont.mono(13)).foregroundStyle(BitColor.muted)
                .multilineTextAlignment(.center)
            BitButton("Готово", kind: .solid, fullWidth: false) { dismiss() }
                .padding(.top, 6)
        }
        .padding(30)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BitColor.muted).padding(9)
                .background(Circle().fill(BitColor.panel))
        }
        .buttonStyle(.plain)
    }

    private func field(_ title: String, text: Binding<String>, phone: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedStringKey(title)).font(BitFont.mono(11)).foregroundStyle(BitColor.muted)
            TextField("", text: text)
                .font(BitFont.display(15))
                .foregroundStyle(BitColor.text)
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                    .fill(BitColor.panelStrong))
                .overlay(RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                    .stroke(BitColor.line, lineWidth: 1))
                #if os(iOS)
                .keyboardType(phone ? .phonePad : .default)
                #endif
        }
    }
}
