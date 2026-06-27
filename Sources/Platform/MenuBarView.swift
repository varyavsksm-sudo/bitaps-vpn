#if os(macOS)
import SwiftUI
import AppKit

/// Content of the macOS menu-bar popover (MenuBarExtra .window style).
/// Compact ~300pt panel: brand, connection status, connect button, live speeds,
/// a location picker and a footer with open-app / quit actions.
struct MenuBarView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings

    private var allAvailableServers: [Server] {
        store.serverGroups.flatMap(\.servers).filter(\.available)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            statusCard
            locationPicker
            footer
        }
        .padding(16)
        .frame(width: 300)
        .background(BitColor.bg2)
        .preferredColorScheme(settings.theme.colorScheme)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            BitLogo(size: 20)
            Spacer()
            BitBadge(store.status.title,
                     color: statusColor,
                     filled: store.isConnected)
        }
    }

    private var statusColor: Color {
        switch store.status {
        case .connected:                       return BitColor.ok
        case .connecting, .reasserting,
             .disconnecting:                   return BitColor.warn
        case .disconnected:                    return BitColor.muted
        }
    }

    // MARK: Status card

    private var statusCard: some View {
        BitCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                // current server line
                HStack(spacing: 8) {
                    if let s = store.selectedServer {
                        Text(s.flag).font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(LocalizedStringKey(s.city))
                                .font(BitFont.display(15, weight: .semibold))
                                .foregroundStyle(BitColor.text)
                            Text(LocalizedStringKey(s.countryName))
                                .font(BitFont.mono(11))
                                .foregroundStyle(BitColor.muted)
                        }
                    } else {
                        Text("Сервер не выбран")
                            .font(BitFont.display(14, weight: .medium))
                            .foregroundStyle(BitColor.muted)
                    }
                    Spacer()
                    if store.isConnected {
                        Text(store.sessionTime)
                            .font(BitFont.mono(13, weight: .semibold))
                            .foregroundStyle(BitColor.accent)
                    }
                }

                // live speeds when connected
                if store.isConnected {
                    HStack(spacing: 14) {
                        speed(icon: "arrow.down", value: store.stats.downloadBps, color: BitColor.accent2)
                        speed(icon: "arrow.up", value: store.stats.uploadBps, color: BitColor.accentSoft)
                        Spacer()
                    }
                }

                BitButton(store.isConnected ? "Отключиться" : "Подключиться",
                          icon: store.isConnected ? "bolt.slash.fill" : "bolt.fill",
                          kind: store.isConnected ? .line : .solid,
                          loading: store.status.isBusy) {
                    store.toggleConnection()
                }
            }
        }
    }

    private func speed(icon: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
            Text(Fmt.speed(value))
                .font(BitFont.mono(12, weight: .medium))
                .foregroundStyle(BitColor.text)
        }
    }

    // MARK: Location picker

    private var locationPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker("локация")
            Menu {
                ForEach(allAvailableServers) { server in
                    Button {
                        store.select(server)
                    } label: {
                        Text(verbatim: "\(server.flag)  ") + Text(LocalizedStringKey(server.city)) + Text(verbatim: ", ") + Text(LocalizedStringKey(server.countryName)) + Text(verbatim: " · \(server.pingMs) ms")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if let s = store.selectedServer {
                        Text(s.flag)
                        (Text(LocalizedStringKey(s.city)) + Text(verbatim: ", ") + Text(LocalizedStringKey(s.countryName)))
                            .font(BitFont.display(14, weight: .medium))
                            .foregroundStyle(BitColor.text)
                    } else {
                        Text("Выбрать сервер")
                            .font(BitFont.display(14, weight: .medium))
                            .foregroundStyle(BitColor.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(BitColor.muted)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                        .fill(BitColor.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                        .stroke(BitColor.line, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .disabled(allAvailableServers.isEmpty)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            BitButton("Открыть приложение", icon: "macwindow", kind: .ghost) {
                openMainWindow()
            }
            Button {
                Task { await store.logout() }
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BitColor.danger)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous)
                            .fill(BitColor.danger.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .help("Выйти из аккаунта")
        }
    }

    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
#endif
