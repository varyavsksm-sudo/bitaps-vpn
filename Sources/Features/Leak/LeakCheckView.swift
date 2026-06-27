import SwiftUI

/// «Проверка утечек / Мой IP» — security screen showing the current IP,
/// geolocation and DNS/WebRTC/IPv6 leak status.
public struct LeakCheckView: View {
    @EnvironmentObject var store: AppStore
    public init() {}

    public var body: some View {
        ZStack {
            BitBackground()
            ScrollView {
                VStack(spacing: BitMetric.gap) {
                    hero
                    if let r = store.leak {
                        ipCard(r)
                        checksCard(r)
                    } else {
                        BitCard {
                            Text("Запустите проверку, чтобы увидеть свой IP и возможные утечки.")
                                .font(BitFont.mono(13)).foregroundStyle(BitColor.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    BitButton(store.isCheckingLeak ? "Проверяю…" : "Проверить",
                              icon: "shield.checkerboard", kind: .solid, loading: store.isCheckingLeak) {
                        Task { await store.runLeakCheck() }
                    }
                }
                .padding(BitMetric.pad)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Проверка утечек")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var hero: some View {
        let secure = store.leak?.allSecure ?? false
        let has = store.leak != nil
        let color = has ? (secure ? BitColor.ok : BitColor.warn) : BitColor.muted
        return BitCard {
            VStack(spacing: 12) {
                Image(systemName: has ? (secure ? "checkmark.shield.fill" : "exclamationmark.shield.fill") : "shield")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(color)
                    .bitGlow(color, radius: 24, opacity: has ? 0.5 : 0)
                Text(LocalizedStringKey(has ? (secure ? "Вы защищены" : "Возможны утечки") : "Статус неизвестен"))
                    .font(BitFont.display(20, weight: .bold)).foregroundStyle(BitColor.text)
                Text(LocalizedStringKey(has ? (secure ? "IP скрыт, утечек не найдено" : "Подключите VPN, чтобы закрыть утечки")
                         : "Нажмите «Проверить»"))
                    .font(BitFont.mono(12)).foregroundStyle(BitColor.muted)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func ipCard(_ r: LeakReport) -> some View {
        BitCard {
            VStack(alignment: .leading, spacing: 12) {
                Kicker("ваш адрес")
                row(GradientIcon("network", index: 0, size: 36), "IP-адрес",
                    Text(LocalizedStringKey(r.ip)).font(BitFont.mono(15, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [BitColor.accentSoft, BitColor.accent],
                                                        startPoint: .top, endPoint: .bottom)))
                row(GradientIcon("mappin.and.ellipse", index: 1, size: 36), "Местоположение",
                    Text("\(r.country) · \(r.city)").font(BitFont.mono(13)).foregroundStyle(BitColor.text))
                row(GradientIcon("building.2.fill", index: 2, size: 36), "Провайдер",
                    Text(LocalizedStringKey(r.isp)).font(BitFont.mono(13)).foregroundStyle(BitColor.text))
            }
        }
    }

    private func checksCard(_ r: LeakReport) -> some View {
        BitCard {
            VStack(alignment: .leading, spacing: 12) {
                Kicker("проверки")
                check("DNS", r.dnsSecure)
                Divider().overlay(BitColor.line)
                check("WebRTC", r.webrtcSecure)
                Divider().overlay(BitColor.line)
                check("IPv6", r.ipv6Secure)
            }
        }
    }

    private func row<V: View>(_ icon: GradientIcon, _ title: String, _ value: V) -> some View {
        HStack(spacing: 12) {
            icon
            Text(LocalizedStringKey(title)).font(BitFont.display(14, weight: .medium)).foregroundStyle(BitColor.text)
            Spacer(minLength: 8)
            value
        }
    }

    private func check(_ name: String, _ ok: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 18)).foregroundStyle(ok ? BitColor.ok : BitColor.warn)
            Text(LocalizedStringKey(name)).font(BitFont.display(15, weight: .medium)).foregroundStyle(BitColor.text)
            Spacer()
            Text(LocalizedStringKey(ok ? "защищено" : "утечка")).font(BitFont.mono(12))
                .foregroundStyle(ok ? BitColor.ok : BitColor.warn)
        }
    }
}
