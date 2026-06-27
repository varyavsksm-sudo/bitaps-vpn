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
                .task {
                    store.settings = settings              // let the store gate notifications
                    await store.bootstrap()
                    // "Подключаться при запуске" — actually connect once we're ready.
                    if settings.connectOnLaunch, store.isLoggedIn, !store.isConnected {
                        await store.connect()
                    }
                    store.refreshExpiryNotification()
                }
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
                .environment(\.locale, Locale(identifier: settings.localeIdentifier))
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}

/// Top-level routing: onboarding → login → main app.
struct RootView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    @State private var authInProgress = false

    var body: some View {
        ZStack {
            BitBackground()
            content
            if settings.appLock && !unlocked { lockScreen }
            #if os(iOS)
            // Cover content while inactive so the app-switcher snapshot can't leak
            // an unlocked screen (the real re-prompt still happens on .background).
            if settings.appLock && unlocked && scenePhase != .active { privacyCover }
            #endif
        }
        // Rebuild only on LANGUAGE change (the localization bundle swizzle needs
        // fresh views). Accent must NOT be here — it updates live via @Published
        // and forcing a rebuild would reset navigation back to Home. [color bug]
        .id(settings.language)
        .environment(\.locale, Locale(identifier: settings.localeIdentifier))
        .tint(BitColor.accent)
        .preferredColorScheme(settings.theme.colorScheme)
        .onAppear { promptUnlockIfNeeded() }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                if settings.appLock { unlocked = false }
                store.persistSession()              // don't lose session bytes on OS-kill
            case .inactive:
                #if os(macOS)
                // macOS backgrounds via .inactive (focus loss / cmd-tab); .background
                // only fires on window close — so re-arm the lock here on Mac.
                if settings.appLock { unlocked = false }
                #endif
            case .active:
                promptUnlockIfNeeded()
            default:
                break
            }
        }
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
            Text(LocalizedStringKey(store.errorMessage ?? ""))
        }
    }

    private func promptUnlockIfNeeded() {
        guard settings.appLock, !unlocked, !authInProgress else { return }
        authInProgress = true
        AppLockManager.authenticate { ok in
            authInProgress = false
            withAnimation { unlocked = ok }
        }
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

    /// Opaque cover shown while the app is inactive, so the OS multitasking
    /// snapshot doesn't reveal an unlocked screen.
    private var privacyCover: some View {
        ZStack {
            BitBackground()
            GearMark(size: 64)
        }
        .ignoresSafeArea()
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
                Label(LocalizedStringKey(t.rawValue), systemImage: t.icon).tag(t)
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
