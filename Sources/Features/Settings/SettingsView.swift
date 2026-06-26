import SwiftUI

/// Account + all preferences screen. Grouped scroll of BitCards.
/// Binds toggles/pickers straight to the shared `Settings` object and wires
/// account actions to `AppStore`.
public struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings
    @Environment(\.openURL) private var openURL

    @State private var loggingOut = false
    @State private var newTrustedSSID = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                BitBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: BitMetric.gap * 1.7) {
                        profileSection
                        personalizationSection
                        advancedSection
                        securitySection
                        devicesSection
                        themeSection
                        connectionSection
                        trustedSection
                        protocolSection
                        splitAppsSection
                        otherSection
                        logoutSection
                        Text("bitaps vpn · v1.0")
                            .font(BitFont.mono(11))
                            .foregroundStyle(BitColor.muted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                    .padding(BitMetric.pad)
                }
            }
            .navigationTitle("Настройки")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
        .tint(BitColor.accent)
    }

    // MARK: - 1. Профиль

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("профиль")
            BitCard {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(BitColor.accentGradient)
                        Text(initials)
                            .font(BitFont.display(22, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    .frame(width: 56, height: 56)
                    .bitGlow(BitColor.accent, radius: 18, opacity: 0.4)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(store.user?.displayName ?? "Гость")
                                .font(BitFont.display(18, weight: .semibold))
                                .foregroundStyle(BitColor.text)
                            if store.user?.isDemo == true {
                                BitBadge("demo", color: BitColor.warn)
                            }
                        }
                        if let handle = accountHandle {
                            Text(handle)
                                .font(BitFont.mono(13))
                                .foregroundStyle(BitColor.muted)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var initials: String {
        let name = store.user?.displayName ?? "Гость"
        let parts = name.split(separator: " ").prefix(2)
        let chars = parts.compactMap { $0.first }.map(String.init)
        return chars.joined().uppercased().isEmpty ? "?" : chars.joined().uppercased()
    }

    private var accountHandle: String? {
        if let tg = store.user?.telegramHandle, !tg.isEmpty {
            return tg.hasPrefix("@") ? tg : "@" + tg
        }
        if let mail = store.user?.email, !mail.isEmpty { return mail }
        return nil
    }

    // MARK: - 1b. Персонализация (single clean entry → PersonalizationView)

    private var personalizationSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("персонализация")
            BitCard(padding: BitMetric.pad * 0.6) {
                NavigationLink {
                    PersonalizationView()
                } label: {
                    navRowLabel(icon: "paintpalette.fill", index: 3,
                                title: "Персонализация",
                                detail: personalizationDetail)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var personalizationDetail: String {
        "\(settings.appIcon.label) · кнопка «\(settings.connectButton.label)»"
    }

    // MARK: - 2. Дополнительно (инструменты power-user)

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("дополнительно")
            BitCard(padding: BitMetric.pad * 0.6) {
                VStack(alignment: .leading, spacing: 0) {
                    NavigationLink {
                        AdvancedNetworkView()
                    } label: {
                        navRowLabel(icon: "network", index: 0,
                                    title: "Сеть и маршрутизация",
                                    detail: networkDetail)
                    }
                    .buttonStyle(.plain)

                    rowDivider

                    NavigationLink {
                        LogsView()
                    } label: {
                        navRowLabel(icon: "doc.text.magnifyingglass", index: 1,
                                    title: "Журнал",
                                    detail: logsDetail)
                    }
                    .buttonStyle(.plain)

                    rowDivider

                    NavigationLink {
                        SpeedTestView()
                    } label: {
                        navRowLabel(icon: "speedometer", index: 2,
                                    title: "Спид-тест",
                                    detail: speedDetail)
                    }
                    .buttonStyle(.plain)

                    rowDivider

                    NavigationLink {
                        ImportConfigView()
                    } label: {
                        navRowLabel(icon: "square.and.arrow.down.on.square", index: 3,
                                    title: "Свой конфиг",
                                    detail: configsDetail)
                    }
                    .buttonStyle(.plain)

                    rowDivider

                    NavigationLink {
                        StatsView()
                    } label: {
                        navRowLabel(icon: "chart.bar.xaxis", index: 4,
                                    title: "Статистика",
                                    detail: statsDetail)
                    }
                    .buttonStyle(.plain)
                    rowDivider
                    NavigationLink {
                        SchedulerView()
                    } label: {
                        navRowLabel(icon: "clock.fill", index: 0,
                                    title: "Расписание",
                                    detail: "\(store.schedules.filter(\.enabled).count) активных")
                    }
                    .buttonStyle(.plain)
                    rowDivider
                    NavigationLink {
                        SmartRulesView()
                    } label: {
                        navRowLabel(icon: "arrow.triangle.branch", index: 1,
                                    title: "Умные правила",
                                    detail: "\(store.smartRules.count) правил")
                    }
                    .buttonStyle(.plain)
                    rowDivider
                    NavigationLink {
                        LeakCheckView()
                    } label: {
                        navRowLabel(icon: "shield.checkerboard", index: 2,
                                    title: "Проверка утечек",
                                    detail: "IP и DNS/WebRTC")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("безопасность")
            BitCard {
                VStack(alignment: .leading, spacing: 14) {
                    BitToggle("Блокировка входа",
                              subtitle: AppLockManager.available ? "Спрашивать Face ID / код при открытии"
                                                                 : "Недоступно на этом устройстве",
                              systemImage: "faceid",
                              isOn: $settings.appLock,
                              enabled: AppLockManager.available)
                    Divider().overlay(BitColor.line)
                    BitToggle("Обрыв соединения", subtitle: "Уведомлять, если VPN отвалился",
                              systemImage: "bolt.horizontal.circle", isOn: $settings.notifyDrop)
                    Divider().overlay(BitColor.line)
                    BitToggle("Подписка истекает", subtitle: "Напомнить за пару дней",
                              systemImage: "calendar.badge.exclamationmark", isOn: $settings.notifyExpiry)
                    Divider().overlay(BitColor.line)
                    BitToggle("Лимит трафика", subtitle: "Сигнал при большом расходе",
                              systemImage: "chart.bar.fill", isOn: $settings.notifyData)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "mic.fill").font(.system(size: 12)).foregroundStyle(BitColor.accent)
                Text("Siri: «Подключи bitaps», «Отключи bitaps», «Быстрейший сервер в bitaps».")
                    .font(BitFont.mono(11)).foregroundStyle(BitColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
        }
    }

    private var rowDivider: some View {
        Divider()
            .overlay(BitColor.line)
            .padding(.leading, 52)
            .padding(.vertical, 4)
    }

    private var networkDetail: String {
        var parts: [String] = [settings.connectionMode.label]
        if settings.warp { parts.append("WARP") }
        return parts.joined(separator: " · ")
    }

    private var logsDetail: String {
        store.logs.isEmpty ? "диагностика ядра" : "\(store.logs.count) записей"
    }

    private var speedDetail: String {
        if let r = store.speedTestResult {
            return String(format: "↓ %.0f · ↑ %.0f Mbps", r.downMbps, r.upMbps)
        }
        return "проверить скорость канала"
    }

    private var configsDetail: String {
        store.importedConfigs.isEmpty
            ? "vless:// · подписки · QR"
            : "\(store.importedConfigs.count) сохр."
    }

    private var statsDetail: String {
        "↓ \(Fmt.bytes(store.lifetimeDown)) · ↑ \(Fmt.bytes(store.lifetimeUp))"
    }

    private func navRowLabel(icon: String, index: Int, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            GradientIcon(icon, index: index, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BitFont.display(15, weight: .semibold))
                    .foregroundStyle(BitColor.text)
                Text(detail)
                    .font(BitFont.mono(12))
                    .foregroundStyle(BitColor.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BitColor.muted)
        }
        .padding(.horizontal, BitMetric.pad * 0.5)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - 3. Устройства

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("устройства")
            BitCard {
                VStack(alignment: .leading, spacing: 0) {
                    if store.devices.isEmpty {
                        Text("Нет привязанных устройств")
                            .font(BitFont.mono(13))
                            .foregroundStyle(BitColor.muted)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(Array(store.devices.enumerated()), id: \.element.id) { idx, device in
                            deviceRow(device)
                            if idx < store.devices.count - 1 {
                                Divider().overlay(BitColor.line).padding(.vertical, 10)
                            }
                        }
                    }
                    if let sub = store.subscription {
                        Text("До \(sub.deviceLimit) устройств")
                            .font(BitFont.mono(11))
                            .foregroundStyle(BitColor.muted)
                            .padding(.top, 12)
                    }
                }
            }
        }
    }

    private func deviceRow(_ device: Device) -> some View {
        HStack(spacing: 12) {
            Image(systemName: device.platform.systemImage)
                .font(.system(size: 18))
                .foregroundStyle(BitColor.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(device.name)
                        .font(BitFont.display(15, weight: .medium))
                        .foregroundStyle(BitColor.text)
                    if device.current {
                        BitBadge("это устройство", color: BitColor.ok)
                    }
                }
                Text("активно \(relativeDate(device.lastActive))")
                    .font(BitFont.mono(11))
                    .foregroundStyle(BitColor.muted)
            }
            Spacer(minLength: 0)
            if !device.current {
                Button {
                    Task { await store.removeDevice(device) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundStyle(BitColor.danger)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - 4. Тема

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("тема")
            BitCard {
                Picker("Тема", selection: themeBinding) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private var themeBinding: Binding<AppTheme> {
        Binding(get: { settings.theme }, set: { settings.theme = $0 })
    }

    // MARK: - 5. Оформление (акцент)

    private var accentSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("оформление")
            BitCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Цвет акцента")
                            .font(BitFont.display(15, weight: .medium))
                            .foregroundStyle(BitColor.text)
                        Spacer()
                        Text(settings.accent.label)
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
                .frame(width: 30, height: 30)
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

    // MARK: - 6. Маршрутизация

    private var routingSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("маршрутизация")
            VStack(spacing: BitMetric.gap) {
                ForEach(RoutingMode.allCases) { mode in
                    routingCard(mode)
                }
            }
            BitCard {
                gradientToggle("Авто-выбор сервера",
                               subtitle: "Подключаться к самому быстрому серверу",
                               icon: "bolt.horizontal.fill", index: 2,
                               isOn: $settings.autoConnectFastest)
            }
        }
    }

    private func routingCard(_ mode: RoutingMode) -> some View {
        let selected = settings.routingMode == mode
        let idx = RoutingMode.allCases.firstIndex(of: mode) ?? 0
        return Button {
            settings.routingMode = mode
        } label: {
            HStack(spacing: 14) {
                GradientIcon(mode.systemImage, index: idx, size: 40)
                    .opacity(selected ? 1 : 0.85)
                    .saturation(selected ? 1 : 0.85)
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.label)
                        .font(BitFont.display(15, weight: .medium))
                        .foregroundStyle(BitColor.text)
                    Text(mode.detail)
                        .font(BitFont.mono(12))
                        .foregroundStyle(BitColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? BitColor.accent : BitColor.line)
            }
            .padding(BitMetric.pad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: BitMetric.radius, style: .continuous)
                    .fill(selected ? BitColor.accent.opacity(0.08) : BitColor.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BitMetric.radius, style: .continuous)
                    .stroke(selected ? BitColor.accent : BitColor.line, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 7. Подключение

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("подключение")
            BitCard {
                VStack(alignment: .leading, spacing: 18) {
                    gradientToggle("Подключаться при запуске",
                                   subtitle: "Включать VPN сразу после открытия приложения",
                                   icon: "bolt.fill", index: 0,
                                   isOn: $settings.connectOnLaunch)
                    Divider().overlay(BitColor.line)
                    gradientToggle("Автоподключение в небезопасных сетях",
                                   subtitle: "Открытый Wi-Fi и неизвестные сети",
                                   icon: "wifi.exclamationmark", index: 1,
                                   isOn: $settings.autoConnect)
                    Divider().overlay(BitColor.line)
                    gradientToggle("Kill-switch",
                                   subtitle: "Блокировать трафик без VPN",
                                   icon: "shield.lefthalf.filled", index: 3,
                                   isOn: $settings.killSwitch)
                    Divider().overlay(BitColor.line)
                    gradientToggle("Cloudflare WARP",
                                   subtitle: "Доп. обёртка для обхода блокировок",
                                   icon: "cloud.bolt.fill", index: 4,
                                   isOn: $settings.warp)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(BitColor.accent)
                Text("Тонкая настройка MTU, DNS, MUX и фрагментации — в разделе «Сеть и маршрутизация».")
                    .font(BitFont.mono(11))
                    .foregroundStyle(BitColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
            .animation(.easeInOut(duration: 0.25), value: settings.warp)
        }
    }

    /// A premium toggle row: colorful gradient chip + the standard BitToggle body
    /// (no flat accent icon — the chip carries the color).
    private func gradientToggle(_ title: String, subtitle: String, icon: String, index: Int,
                                isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            GradientIcon(icon, index: index, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BitFont.display(15, weight: .semibold))
                    .foregroundStyle(BitColor.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(BitFont.mono(12))
                    .foregroundStyle(BitColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: isOn).labelsHidden().tint(BitColor.accent)
        }
    }

    // MARK: - 8. Протокол + DNS

    private var protocolSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("протокол")
            BitCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Протокол туннеля")
                            .font(BitFont.display(15, weight: .medium))
                            .foregroundStyle(BitColor.text)
                        Spacer()
                        Picker("Протокол", selection: protoBinding) {
                            ForEach(TunnelProtocol.primary) { p in
                                Text(p.label).tag(p)
                            }
                        }
                        .labelsHidden()
                        .tint(BitColor.accent)
                    }
                    Text("Полный список протоколов доступен для импортированных конфигов")
                        .font(BitFont.mono(11))
                        .foregroundStyle(BitColor.muted)
                    Divider().overlay(BitColor.line)
                    HStack {
                        Text("DNS")
                            .font(BitFont.display(15, weight: .medium))
                            .foregroundStyle(BitColor.text)
                        Spacer()
                        Menu {
                            ForEach(dnsOptions, id: \.self) { opt in
                                Button(opt) { settings.dns = opt }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(settings.dns)
                                    .font(BitFont.mono(13))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(BitColor.accent)
                        }
                    }
                }
            }
        }
    }

    private let dnsOptions = [
        "Авто (через VPN)",
        "Cloudflare 1.1.1.1",
        "Google 8.8.8.8",
        "AdGuard",
        "Свой…"
    ]

    private var protoBinding: Binding<TunnelProtocol> {
        Binding(get: { settings.proto }, set: { settings.proto = $0 })
    }

    // MARK: - 8b. Доверенные сети

    private var trustedSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("доверенные сети")
            BitCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        GradientIcon("wifi", index: 4, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Доверенные сети")
                                .font(BitFont.display(15, weight: .semibold))
                                .foregroundStyle(BitColor.text)
                            Text("Не подключаться автоматически в этих Wi-Fi")
                                .font(BitFont.mono(12))
                                .foregroundStyle(BitColor.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }

                    if store.trustedNetworks.isEmpty {
                        Text("Список пуст — добавьте свою домашнюю сеть")
                            .font(BitFont.mono(12))
                            .foregroundStyle(BitColor.muted)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.trustedNetworks.enumerated()), id: \.element.id) { idx, net in
                                trustedRow(net)
                                if idx < store.trustedNetworks.count - 1 {
                                    Divider().overlay(BitColor.line).padding(.vertical, 8)
                                }
                            }
                        }
                    }

                    Divider().overlay(BitColor.line)

                    HStack(spacing: 10) {
                        Image(systemName: "wifi.router")
                            .font(.system(size: 15))
                            .foregroundStyle(BitColor.accent)
                            .frame(width: 22)
                        TextField("SSID сети", text: $newTrustedSSID)
                            .font(BitFont.mono(14))
                            .foregroundStyle(BitColor.text)
                            .textFieldStyle(.plain)
                            #if os(iOS)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.done)
                            #endif
                            .onSubmit(addTrusted)
                        BitButton("Добавить", icon: "plus", kind: .line, fullWidth: false, action: addTrusted)
                            .fixedSize()
                    }
                }
            }
        }
    }

    private func trustedRow(_ net: TrustedNetwork) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi")
                .font(.system(size: 15))
                .foregroundStyle(BitColor.ok)
                .frame(width: 22)
            Text(net.ssid)
                .font(BitFont.display(15, weight: .medium))
                .foregroundStyle(BitColor.text)
            Spacer(minLength: 0)
            Button {
                store.removeTrusted(net)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .foregroundStyle(BitColor.danger)
            }
            .buttonStyle(.plain)
        }
    }

    private func addTrusted() {
        let s = newTrustedSSID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        store.addTrusted(s)
        newTrustedSSID = ""
    }

    // MARK: - 9. Раздельный туннель (per-app bypass)

    private var splitAppsSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("раздельный туннель")
            BitCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        GradientIcon("square.split.2x1", index: 1, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Раздельный туннель")
                                .font(BitFont.display(15, weight: .semibold))
                                .foregroundStyle(BitColor.text)
                            Text("Исключённые приложения идут мимо VPN — напрямую")
                                .font(BitFont.mono(12))
                                .foregroundStyle(BitColor.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 8)

                    Divider().overlay(BitColor.line).padding(.bottom, 8)

                    ForEach(Array(store.splitApps.enumerated()), id: \.element.id) { idx, app in
                        splitAppRow(app, index: idx)
                        if idx < store.splitApps.count - 1 {
                            Divider().overlay(BitColor.line).padding(.vertical, 8)
                        }
                    }

                    #if os(iOS)
                    Divider().overlay(BitColor.line).padding(.top, 8)
                    Text("На iOS список приложений управляется системой — показан демо-набор.")
                        .font(BitFont.mono(11))
                        .foregroundStyle(BitColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                    #endif
                }
            }
        }
    }

    private func splitAppRow(_ app: AppEntry, index: Int) -> some View {
        HStack(spacing: 14) {
            GradientIcon(app.symbol, index: index % 5, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(BitFont.display(15, weight: .semibold))
                    .foregroundStyle(BitColor.text)
                Text(app.excluded ? "мимо VPN — напрямую" : "через VPN")
                    .font(BitFont.mono(12))
                    .foregroundStyle(app.excluded ? BitColor.warn : BitColor.ok)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: splitBinding(app))
                .labelsHidden()
                .tint(BitColor.accent)
        }
    }

    /// `on` = excluded (bypasses the tunnel). Toggling routes through the store.
    private func splitBinding(_ app: AppEntry) -> Binding<Bool> {
        Binding(
            get: { store.splitApps.first { $0.id == app.id }?.excluded ?? app.excluded },
            set: { _ in store.toggleSplit(app) }
        )
    }

    // MARK: - 10. Прочее

    private var otherSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("прочее")
            BitCard {
                VStack(alignment: .leading, spacing: 18) {
                    gradientToggle("Уведомления",
                                   subtitle: "Статус подключения и окончание подписки",
                                   icon: "bell.fill", index: 0,
                                   isOn: $settings.notifications)
                    Divider().overlay(BitColor.line)
                    HStack(spacing: 14) {
                        GradientIcon("globe", index: 1, size: 38)
                        Text("Язык")
                            .font(BitFont.display(15, weight: .semibold))
                            .foregroundStyle(BitColor.text)
                        Spacer()
                        Picker("Язык", selection: languageBinding) {
                            Text("Русский").tag("Русский")
                            Text("English").tag("English")
                        }
                        .labelsHidden()
                        .tint(BitColor.accent)
                    }
                    Divider().overlay(BitColor.line)
                    linkRow(icon: "lifepreserver", index: 2, title: "Поддержка",
                            detail: "@\(TelegramAuth.botUsername)") {
                        openURL(TelegramAuth.loginURL())
                    }
                    Divider().overlay(BitColor.line)
                    linkRow(icon: "doc.text", index: 3, title: "Оферта", detail: "открыть") {
                        if let u = URL(string: "https://bitaps-vpn.surge.sh/terms.html") { openURL(u) }
                    }
                    Divider().overlay(BitColor.line)
                    linkRow(icon: "hand.raised", index: 4, title: "Политика конфиденциальности", detail: "открыть") {
                        if let u = URL(string: "https://bitaps-vpn.surge.sh/privacy.html") { openURL(u) }
                    }
                }
            }
        }
    }

    private var languageBinding: Binding<String> {
        Binding(get: { settings.language == "English" ? "English" : "Русский" },
                set: { settings.language = $0 })
    }

    private func linkRow(icon: String, index: Int, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                GradientIcon(icon, index: index, size: 38)
                Text(title)
                    .font(BitFont.display(15, weight: .semibold))
                    .foregroundStyle(BitColor.text)
                Spacer()
                Text(detail)
                    .font(BitFont.mono(12))
                    .foregroundStyle(BitColor.muted)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BitColor.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 11. Выход

    private var logoutSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            BitButton("Выйти из аккаунта", icon: "rectangle.portrait.and.arrow.right",
                      kind: .line, loading: loggingOut) {
                loggingOut = true
                Task {
                    await store.logout()
                    loggingOut = false
                }
            }
            .foregroundStyle(BitColor.danger)
        }
        .padding(.top, 4)
    }
}
