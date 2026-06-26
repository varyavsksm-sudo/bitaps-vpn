import SwiftUI

/// Подписка: текущий статус + выбор/продление тарифа.
/// Оплата идёт через Telegram Stars (deep-link в @bitaps_vpn_auth_bot).
/// СБП и крипта — заявлены как «скоро».
public struct SubscriptionView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openURL) private var openURL

    /// Выбранный тариф для нижней CTA (по умолчанию — «выгодный» или первый).
    @State private var selected: Plan?
    @State private var renewing = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BitMetric.gap + 8) {
                header
                currentStatusCard
                plansSection
                paymentNote
            }
            .padding(BitMetric.pad)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(BitBackground())
        .navigationTitle("Подписка")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if selected == nil {
                selected = store.plans.first(where: { $0.best }) ?? store.plans.first
            }
        }
        .safeAreaInset(edge: .bottom) { ctaBar }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker("billing")
            Text("Ваша подписка")
                .font(BitFont.display(30, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [BitColor.text, BitColor.text.opacity(0.7)],
                                   startPoint: .top, endPoint: .bottom)
                )
            Text("Один аккаунт — все устройства. Продлевайте, когда удобно.")
                .font(BitFont.mono(13))
                .foregroundStyle(BitColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Current status

    private var currentStatusCard: some View {
        BitCard(strong: true) {
            VStack(alignment: .leading, spacing: 16) {
                if let sub = store.subscription {
                    HStack(alignment: .top, spacing: 14) {
                        GradientIcon("crown.fill", index: 0, size: 46)
                            .bitGlow(BitColor.accent, radius: 16, opacity: 0.4)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sub.planTitle)
                                .font(BitFont.display(20, weight: .bold))
                                .foregroundStyle(BitColor.text)
                            Text("Текущий тариф")
                                .font(BitFont.mono(11))
                                .foregroundStyle(BitColor.muted)
                        }
                        Spacer(minLength: 0)
                        BitBadge(sub.status.label, color: statusColor(sub.status), filled: true)
                    }

                    Divider().overlay(BitColor.line)

                    statRow(icon: "clock.fill", index: 2, label: "Осталось",
                            value: daysLeftText(sub))
                    statRow(icon: "calendar", index: 4, label: "Действует до",
                            value: expiresText(sub))
                    statRow(icon: "iphone", index: 1, label: "Устройства",
                            value: "\(sub.devicesUsed)/\(sub.deviceLimit)")
                } else {
                    HStack(spacing: 14) {
                        GradientIcon("lock.open.fill", index: 3, size: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Активной подписки нет")
                                .font(BitFont.display(18, weight: .bold))
                                .foregroundStyle(BitColor.text)
                            Text("Выберите тариф ниже — полный доступ откроется сразу.")
                                .font(BitFont.mono(12))
                                .foregroundStyle(BitColor.muted)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func statRow(icon: String, index: Int, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            GradientIcon(icon, index: index, size: 28)
            Text(label)
                .font(BitFont.mono(12))
                .foregroundStyle(BitColor.muted)
            Spacer()
            Text(value)
                .font(BitFont.mono(14, weight: .semibold))
                .foregroundStyle(BitColor.text)
        }
    }

    private func statusColor(_ s: SubscriptionStatus) -> Color {
        switch s {
        case .active, .trial: return BitColor.ok
        case .expired:        return BitColor.danger
        case .none:           return BitColor.muted
        }
    }

    private func daysLeftText(_ sub: Subscription) -> String {
        guard let d = sub.daysLeft else { return "—" }
        return d > 0 ? "\(d) дн." : "истекла"
    }

    private func expiresText(_ sub: Subscription) -> String {
        guard let date = sub.expires else { return "—" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap + 2) {
            Kicker("тарифы")
            ForEach(Array(store.plans.enumerated()), id: \.element.id) { idx, plan in
                planCard(plan, index: idx)
            }
        }
    }

    private func planCard(_ plan: Plan, index: Int) -> some View {
        let isSelected = selected?.id == plan.id
        let highlight = plan.best || isSelected
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                selected = plan
            }
        } label: {
            BitCard(strong: highlight) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        GradientIcon(planIcon(plan), index: index, size: 40)
                        Text(plan.title)
                            .font(BitFont.display(18, weight: .bold))
                            .foregroundStyle(BitColor.text)
                        Spacer(minLength: 0)
                        if plan.best {
                            BitBadge("Выгодно", color: BitColor.accent, filled: true)
                        }
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(BitColor.accent)
                                .bitGlow(BitColor.accent, radius: 10, opacity: 0.5)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(plan.pricePerMonth) ₽")
                            .font(BitFont.display(34, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [BitColor.accentSoft, BitColor.accent],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .bitGlow(BitColor.accent, radius: 14, opacity: highlight ? 0.4 : 0.18)
                        Text("/мес")
                            .font(BitFont.mono(13))
                            .foregroundStyle(BitColor.muted)
                    }

                    Text("Итого \(plan.total) ₽ за \(plan.months) мес")
                        .font(BitFont.mono(12, weight: .medium))
                        .foregroundStyle(BitColor.accentSoft)

                    if !plan.features.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(plan.features, id: \.self) { feature in
                                HStack(alignment: .top, spacing: 9) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(BitColor.ok)
                                        .padding(.top, 1)
                                    Text(feature)
                                        .font(BitFont.mono(12))
                                        .foregroundStyle(BitColor.text.opacity(0.85))
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: BitMetric.radius, style: .continuous)
                .stroke(borderStyle(highlight: highlight),
                        lineWidth: highlight ? 1.8 : 0)
        )
        .bitGlow(BitColor.accent, radius: 22, opacity: highlight ? 0.3 : 0)
        .scaleEffect(isSelected ? 1.0 : 0.995)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isSelected)
    }

    private func planIcon(_ plan: Plan) -> String {
        if plan.best { return "bolt.fill" }
        if plan.months >= 12 { return "infinity" }
        if plan.months >= 3 { return "star.fill" }
        return "leaf.fill"
    }

    private func borderStyle(highlight: Bool) -> LinearGradient {
        highlight
            ? LinearGradient(colors: [BitColor.accent, BitColor.accentSoft, BitColor.violet],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Payment note

    private var paymentNote: some View {
        BitCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    GradientIcon("star.fill", index: 0, size: 36)
                    Text("Оплата через Telegram Stars")
                        .font(BitFont.display(15, weight: .bold))
                        .foregroundStyle(BitColor.text)
                }
                Text("Продление оформляется в боте @\(TelegramAuth.botUsername) — быстро и без карты.")
                    .font(BitFont.mono(12))
                    .foregroundStyle(BitColor.muted)
                HStack(spacing: 10) {
                    GradientIcon("clock.badge", index: 2, size: 28)
                    Text("СБП / крипта — скоро")
                        .font(BitFont.mono(12, weight: .medium))
                        .foregroundStyle(BitColor.muted)
                    BitBadge("soon", color: BitColor.muted)
                }
            }
        }
    }

    // MARK: - CTA bar

    private var ctaBar: some View {
        VStack(spacing: 8) {
            if let plan = selected {
                BitButton(ctaTitle(plan),
                          icon: "star.fill",
                          kind: .solid,
                          loading: renewing) {
                    pay(plan)
                }
                Text("Нажимая, вы откроете оплату в Telegram")
                    .font(BitFont.mono(10))
                    .foregroundStyle(BitColor.muted)
            }
        }
        .padding(.horizontal, BitMetric.pad)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            LinearGradient(colors: [BitColor.accent.opacity(0.5), BitColor.violet.opacity(0.3), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
    }

    private func ctaTitle(_ plan: Plan) -> String {
        let isActive = store.subscription?.status == .active || store.subscription?.status == .trial
        return (isActive ? "Продлить — " : "Выбрать — ") + "\(plan.total) ₽"
    }

    private func pay(_ plan: Plan) {
        renewing = true
        // Реальная оплата — в Telegram. Параллельно отмечаем продление в сторе (mock).
        openURL(TelegramAuth.subscribeURL())
        Task {
            await store.renew(plan)
            renewing = false
        }
    }
}
