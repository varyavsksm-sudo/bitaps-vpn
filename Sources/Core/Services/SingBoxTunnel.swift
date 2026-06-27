import Foundation
#if canImport(NetworkExtension)
@preconcurrency import NetworkExtension
#endif

/// Real tunnel driver. Talks to the PacketTunnel NetworkExtension which embeds
/// sing-box (libbox) and runs VLESS+Reality. This is a wired-up SKELETON:
/// every step is laid out and compiles, the libbox bits are marked TODO so the
/// app keeps building before the Go xcframework + provisioning exist.
///
/// To go live:
///   1. Add Libbox.xcframework (gomobile build of sing-box) to PacketTunnel.
///   2. Set TunnelFactory.useSingBox = true.
///   3. Fill the VLESS+Reality config from the API in `makeConfig(for:)`.
@MainActor
public final class SingBoxTunnel: VPNTunnel {
    public weak var delegate: VPNTunnelDelegate?
    public private(set) var currentServer: Server?
    public private(set) var status: VPNStatus = .disconnected {
        didSet { delegate?.tunnel(self, didChange: status) }
    }

    #if canImport(NetworkExtension)
    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    #endif

    public init() {}

    public func connect(to server: Server) async throws {
        guard server.available else { throw AppError.serverUnavailable }
        currentServer = server
        status = .connecting

        #if canImport(NetworkExtension)
        let manager = try await loadOrCreateManager()
        self.manager = manager
        observeStatus(manager)
        do {
            let options: [String: NSObject] = [
                "server": server.id as NSString,
                // TODO: pass the per-user VLESS+Reality config json fetched from the API.
                "config": makeConfig(for: server) as NSString
            ]
            try manager.connection.startVPNTunnel(options: options)
        } catch {
            status = .disconnected
            throw AppError.tunnel(error.localizedDescription)
        }
        #else
        // Platform without NetworkExtension: nothing to do.
        status = .disconnected
        throw AppError.tunnel("NetworkExtension недоступен")
        #endif
    }

    public func disconnect() async {
        status = .disconnecting
        #if canImport(NetworkExtension)
        manager?.connection.stopVPNTunnel()
        #endif
        currentServer = nil
    }

    // MARK: - NEVPNManager plumbing

    #if canImport(NetworkExtension)
    private func loadOrCreateManager() async throws -> NETunnelProviderManager {
        let all = try await NETunnelProviderManager.loadAllFromPreferences()
        let manager = all.first ?? NETunnelProviderManager()
        let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "app.bitaps.vpn.PacketTunnel"
        proto.serverAddress = "bitaps VPN"
        manager.protocolConfiguration = proto
        manager.localizedDescription = "bitaps VPN"
        manager.isEnabled = true

        // On-demand: reconnect automatically (parity with Happ auto-connect /
        // "untrusted Wi-Fi"). Toggled from Settings — TODO: read the live values.
        let connectRule = NEOnDemandRuleConnect()
        connectRule.interfaceTypeMatch = .any
        manager.onDemandRules = [connectRule]
        manager.isOnDemandEnabled = false   // enabled when user turns on auto-connect

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        return manager
    }

    private func observeStatus(_ manager: NETunnelProviderManager) {
        if let statusObserver { NotificationCenter.default.removeObserver(statusObserver) }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: manager.connection, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.map(manager.connection.status) }
        }
    }

    private func map(_ s: NEVPNStatus) {
        switch s {
        case .connecting:    status = .connecting
        case .connected:     status = .connected
        case .disconnecting: status = .disconnecting
        case .reasserting:   status = .reasserting
        case .disconnected, .invalid: status = .disconnected
        @unknown default:    status = .disconnected
        }
    }
    #endif

    /// Builds the sing-box client config from the server's per-user key
    /// (`server.config` = the `vpn_key` / imported share link). Empty string if
    /// there's no key — the provider then keeps the tun up without an outbound.
    private func makeConfig(for server: Server) -> String {
        guard let key = server.config, !key.isEmpty,
              let json = SingBoxConfig.generate(fromKey: key, routing: routing) else {
            return ""
        }
        return json
    }

    /// Routing policy for the generated config — defaults to smart (RU direct,
    /// rest via proxy). Set from Settings before connecting when wired.
    public var routing: SingBoxConfig.Routing = .rules
}
