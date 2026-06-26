import SwiftUI

@main
struct BitapsVPNApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var settings = Settings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(settings)
                .tint(BitColor.accent)
                .preferredColorScheme(settings.theme.colorScheme)
                .task { await store.bootstrap() }
        }
        #if os(macOS)
        .defaultSize(width: 420, height: 760)
        .windowResizability(.contentMinSize)
        #endif

        // Menu bar item: quick connect / switch location.
        #if os(macOS)
        MenuBarExtra("bitaps VPN", systemImage: store.isConnected ? "shield.fill" : "shield") {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(settings)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}

/// Top-level routing: onboarding → login → main app.
struct RootView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings
    @State private var unlocked = false

    var body: some View {
        ZStack {
            BitBackground()
            content
            if settings.appLock && !unlocked { lockScreen }
        }
        .id(settings.accent)        // rebuild so the new accent recolors everything
        .tint(BitColor.accent)
        .preferredColorScheme(settings.theme.colorScheme)
        .onAppear { promptUnlockIfNeeded() }
        .onReceive(NotificationCenter.default.publisher(for: .siriConnect)) { _ in
            Task { await store.connect() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .siriDisconnect)) { _ in
            Task { await store.disconnect() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .siriFastest)) { _ in
            Task { await store.connectFastest() }
        }
        .alert("Что-то пошло не так", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("Ок", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private func promptUnlockIfNeeded() {
        guard settings.appLock, !unlocked else { return }
        AppLockManager.authenticate { ok in withAnimation { unlocked = ok } }
    }

    private var lockScreen: some View {
        ZStack {
            BitBackground()
            VStack(spacing: 18) {
                GearMark(size: 64)
                Text("bitaps заблокирован")
                    .font(BitFont.display(20, weight: .bold))
                    .foregroundStyle(BitColor.text)
                BitButton("Разблокировать", icon: "faceid", kind: .solid, fullWidth: false) {
                    promptUnlockIfNeeded()
                }
            }
            .padding(30)
        }
        .transition(.opacity)
    }

    @ViewBuilder private var content: some View {
        if !store.hasOnboarded {
            OnboardingView()
                .transition(.opacity)
        } else if !store.isLoggedIn {
            AuthView()
                .transition(.opacity)
        } else {
            MainShell()
                .transition(.opacity)
        }
    }
}

/// Platform-specific chrome around the five main screens.
struct MainShell: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        #if os(macOS)
        MacRootView()
        #else
        iOSRootView()
        #endif
    }
}

// MARK: - iOS tab navigation

#if !os(macOS)
struct iOSRootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Главная", systemImage: "bolt.horizontal.circle") }
            ServersView()
                .tabItem { Label("Серверы", systemImage: "globe") }
            AccountView()
                .tabItem { Label("Кабинет", systemImage: "person.crop.circle") }
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        .tint(BitColor.accent)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
#endif

// MARK: - macOS sidebar navigation

#if os(macOS)
struct MacRootView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case home = "Главная", servers = "Серверы", account = "Кабинет", settings = "Настройки"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .home: return "bolt.horizontal.circle"
            case .servers: return "globe"
            case .account: return "person.crop.circle"
            case .settings: return "gearshape"
            }
        }
    }
    @State private var tab: Tab = .home

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $tab) { t in
                Label(t.rawValue, systemImage: t.icon).tag(t)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .safeAreaInset(edge: .top) {
                BitLogo(size: 20).padding()
            }
        } detail: {
            Group {
                switch tab {
                case .home: HomeView()
                case .servers: ServersView()
                case .account: AccountView()
                case .settings: SettingsView()
                }
            }
            .frame(minWidth: 380, minHeight: 620)
        }
    }
}
#endif
