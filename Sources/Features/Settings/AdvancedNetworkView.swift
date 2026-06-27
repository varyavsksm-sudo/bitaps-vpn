import SwiftUI

/// Hiddify-parity advanced network screen: connection mode, routing, anti-DPI
/// toggles, DNS and MTU. Pushed inside the Settings NavigationStack (no new
/// stack here). Cross-platform iOS16 / macOS13.
struct AdvancedNetworkView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings

    var body: some View {
        ZStack {
            BitBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: BitMetric.gap * 1.4) {
                    header
                    modeCard
                    routingCard
                    shieldCard
                    dnsCard
                    mtuCard
                    footer
                }
                .padding(BitMetric.pad)
            }
        }
        .navigationTitle("Сеть и маршрутизация")
        .animation(.easeInOut(duration: 0.25), value: settings.connectionMode)
        .animation(.easeInOut(duration: 0.25), value: settings.routingMode)
        .animation(.easeInOut(duration: 0.25), value: settings.warp)
    }

    // MARK: - Header

    private var header: some View {
        BitCard(strong: true) {
            HStack(spacing: 14) {
                GearMark(size: 38, spinning: store.isConnected)
                VStack(alignment: .leading, spacing: 4) {
                    Kicker("низкоуровневая настройка")
                    Text("Тонкая настройка туннеля")
                        .font(BitFont.display(20, weight: .bold))
                        .foregroundStyle(LinearGradient(
                            colors: [BitColor.accentSoft, BitColor.accent],
                            startPoint: .top, endPoint: .bottom))
                        .bitGlow(BitColor.accent, radius: 14, opacity: 0.35)
                    Text("Режим, маршруты, анти-DPI и DNS. Меняй, только если знаешь, что делаешь.")
                        .font(BitFont.mono(12))
                        .foregroundStyle(BitColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Connection mode

    private var modeCard: some View {
        BitCard {
            VStack(alignment: .leading, spacing: 12) {
                cardTitle("Режим подключения", icon: "point.3.connected.trianglepath.dotted", index: 0)
                Picker("Режим", selection: $settings.connectionMode) {
                    ForEach(ConnectionMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.label)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack(spacing: 8) {
                    Image(systemName: connectionModeIcon)
                        .font(.system(size: 13))
                        .foregroundStyle(BitColor.accent)
                    Text(LocalizedStringKey(connectionModeCaption))
                        .font(BitFont.mono(12))
                        .foregroundStyle(BitColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
                .id(settings.connectionMode)
            }
        }
    }

    private var connectionModeIcon: String {
        switch settings.connectionMode {
        case .proxy:  return "wand.and.stars"
        case .global: return "globe"
        case .direct: return "arrow.up.arrow.down"
        }
    }

    private var connectionModeCaption: String {
        switch settings.connectionMode {
        case .proxy:  return "Умный режим: правила решают, что идёт через VPN, а что напрямую. Рекомендуем."
        case .global: return "Весь трафик устройства заворачивается в туннель без исключений."
        case .direct: return "Интерфейс VPN поднят, но трафик идёт напрямую — для отладки."
        }
    }

    // MARK: - Routing

    private var routingCard: some View {
        BitCard {
            VStack(alignment: .leading, spacing: 12) {
                cardTitle("Маршрутизация", icon: "arrow.triangle.branch", index: 1)
                VStack(spacing: 8) {
                    ForEach(RoutingMode.allCases) { mode in
                        routingRow(mode)
                    }
                }
            }
        }
    }

    private func routingRow(_ mode: RoutingMode) -> some View {
        let selected = settings.routingMode == mode
        return Button {
            settings.routingMode = mode
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 15))
                    .foregroundStyle(selected ? BitColor.accent : BitColor.muted)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(mode.label))
                        .font(BitFont.display(15, weight: .medium))
                        .foregroundStyle(BitColor.text)
                    Text(LocalizedStringKey(mode.detail))
                        .font(BitFont.mono(11))
                        .foregroundStyle(BitColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? BitColor.accent : BitColor.line)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                    .fill(selected ? BitColor.accent.opacity(0.10) : BitColor.panelStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                    .stroke(selected ? BitColor.accent.opacity(0.55) : BitColor.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Anti-DPI / shield toggles

    private var shieldCard: some View {
        BitCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    cardTitle("Защита и обход", icon: "shield.lefthalf.filled", index: 2)
                    Spacer()
                    BitBadge("\(activeShieldCount)/5", color: BitColor.accent)
                }
                BitToggle("Прямой доступ к локальной сети",
                          subtitle: "Принтеры, NAS и роутер минуют туннель",
                          systemImage: "house",
                          isOn: $settings.bypassLAN)
                divider
                BitToggle("IPv6",
                          subtitle: "Пропускать IPv6-трафик через туннель",
                          systemImage: "6.circle",
                          isOn: $settings.ipv6)
                divider
                BitToggle("Мультиплексирование (MUX)",
                          subtitle: "Несколько потоков в одном соединении — меньше задержек",
                          systemImage: "rectangle.stack",
                          isOn: $settings.mux)
                divider
                BitToggle("TLS-фрагментация (анти-DPI)",
                          subtitle: "Дробит TLS-хендшейк, чтобы обмануть DPI",
                          systemImage: "scissors",
                          isOn: $settings.tlsFragment)
                divider
                BitToggle("Cloudflare WARP",
                          subtitle: "Доп. слой через сеть Cloudflare для трудных регионов",
                          systemImage: "cloud",
                          isOn: $settings.warp)
            }
        }
    }

    private var activeShieldCount: Int {
        [settings.bypassLAN, settings.ipv6,
         settings.mux, settings.tlsFragment, settings.warp].filter { $0 }.count
    }

    // MARK: - DNS

    private var dnsCard: some View {
        BitCard {
            VStack(alignment: .leading, spacing: 12) {
                cardTitle("DNS", icon: "network", index: 3)

                dnsField(title: "DNS через VPN",
                         hint: "DoH/DoT, например https://1.1.1.1/dns-query",
                         icon: "lock.shield",
                         text: $settings.remoteDNS)
                divider
                dnsField(title: "Прямой DNS",
                         hint: "Для трафика мимо туннеля, например 8.8.8.8",
                         icon: "arrow.up.forward",
                         text: $settings.directDNS)
                divider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Стратегия доменов")
                        .font(BitFont.display(13, weight: .medium))
                        .foregroundStyle(BitColor.text)
                    Picker("Стратегия", selection: $settings.domainStrategy) {
                        ForEach(DomainStrategy.allCases) { s in
                            Text(LocalizedStringKey(s.label)).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        }
    }

    private func dnsField(title: String, hint: String, icon: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(BitColor.accent)
                    .frame(width: 18)
                Text(LocalizedStringKey(title))
                    .font(BitFont.display(13, weight: .medium))
                    .foregroundStyle(BitColor.text)
            }
            TextField(LocalizedStringKey(hint), text: text)
                .font(BitFont.mono(13))
                .foregroundStyle(BitColor.text)
                .textFieldStyle(.plain)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                        .fill(BitColor.panelStrong)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                        .stroke(BitColor.line, lineWidth: 1)
                )
                #if os(iOS)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                #endif
        }
    }

    // MARK: - MTU

    private var mtuCard: some View {
        BitCard {
            VStack(alignment: .leading, spacing: 12) {
                cardTitle("MTU", icon: "ruler", index: 4)
                HStack(spacing: 14) {
                    Button { adjustMTU(-20) } label: {
                        stepperGlyph("minus")
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.mtu <= 1200)

                    VStack(spacing: 2) {
                        Text("\(settings.mtu)")
                            .font(BitFont.mono(28, weight: .semibold))
                            .foregroundStyle(LinearGradient(
                                colors: [BitColor.accentSoft, BitColor.accent],
                                startPoint: .top, endPoint: .bottom))
                            .bitGlow(BitColor.accent, radius: 10, opacity: 0.3)
                            .contentTransitionNumeric()
                        Text("байт")
                            .font(BitFont.mono(10))
                            .foregroundStyle(BitColor.muted)
                    }
                    .frame(maxWidth: .infinity)

                    Button { adjustMTU(20) } label: {
                        stepperGlyph("plus")
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.mtu >= 1500)
                }
                LoadBar(pct: Int(Double(settings.mtu - 1200) / 300.0 * 100))
                    .animation(.easeInOut(duration: 0.25), value: settings.mtu)
                Text("Меньший MTU помогает на нестабильных сетях, больший — быстрее. По умолчанию 1500.")
                    .font(BitFont.mono(11))
                    .foregroundStyle(BitColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func adjustMTU(_ delta: Int) {
        settings.mtu = min(1500, max(1200, settings.mtu + delta))
    }

    private func stepperGlyph(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(BitColor.text)
            .frame(width: 46, height: 46)
            .background(
                RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                    .fill(BitColor.panelStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                    .stroke(BitColor.line, lineWidth: 1)
            )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(BitColor.muted)
            Text("⚠️ Эти настройки активируются вместе с боевым VPN-ядром (скоро). Сейчас сохраняются, но к туннелю ещё не применяются.")
                .font(BitFont.mono(11))
                .foregroundStyle(BitColor.muted)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func cardTitle(_ text: String, icon: String, index: Int) -> some View {
        HStack(spacing: 12) {
            GradientIcon(icon, index: index, size: 34)
            Text(LocalizedStringKey(text))
                .font(BitFont.display(17, weight: .bold))
                .foregroundStyle(BitColor.text)
        }
    }

    private var divider: some View {
        Rectangle().fill(BitColor.line).frame(height: 1)
    }
}

// MARK: - contentTransition shim (iOS16/macOS13 safe)

private extension View {
    @ViewBuilder func contentTransitionNumeric() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.contentTransition(.numericText())
        } else {
            self
        }
    }
}
