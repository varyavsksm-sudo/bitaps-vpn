//
//  PacketTunnelProvider.swift
//  PacketTunnel  (bundle id: app.bitaps.vpn.PacketTunnel)
//
//  NetworkExtension packet-tunnel provider for the bitaps VPN app.
//
//  ┌──────────────────────────────────────────────────────────────────────┐
//  │  WIRED SKELETON + MOCK PATH                                            │
//  │                                                                        │
//  │  This file establishes the tunnel interface so the OS shows "VPN on"   │
//  │  *before* the real packet engine exists. To actually move packets      │
//  │  this target needs the Libbox.xcframework — a gomobile build of        │
//  │  sing-box (https://github.com/SagerNet/sing-box) — added to the        │
//  │  PacketTunnel target. Until then, setTunnelNetworkSettings() brings    │
//  │  up the utun interface and the system UI reports the VPN as connected, │
//  │  but traffic is not yet routed through sing-box.                       │
//  │                                                                        │
//  │  The // TODO: libbox markers below show exactly where the real engine  │
//  │  (BoxService.start / .close) plugs in once the framework is linked.    │
//  └──────────────────────────────────────────────────────────────────────┘
//
//  Cross-platform: builds on iOS 16+ and macOS 13+. NetworkExtension's
//  packet-tunnel API is identical on both, so no platform guards are needed
//  inside the class — only the whole-file canImport guard below.
//

import Foundation

#if canImport(NetworkExtension)
import NetworkExtension
import os.log
#if canImport(Libbox)
import Libbox
#endif

/// Packet-tunnel provider. The system instantiates this class inside the
/// extension process when the user (or the app, via NETunnelProviderManager)
/// starts the VPN. All configuration is passed through `startTunnel(options:)`.
final class PacketTunnelProvider: NEPacketTunnelProvider {

    private let log = OSLog(subsystem: "app.bitaps.vpn.PacketTunnel", category: "tunnel")

    /// Tunnel-local addressing. The OS only needs *a* valid interface address;
    /// real egress is decided by the engine, not by this address.
    private enum Net {
        static let tunnelRemoteAddress = "127.0.0.1"
        static let ipv4Address         = "10.66.0.2"
        static let ipv4SubnetMask       = "255.255.255.0"
        static let dnsServers           = ["1.1.1.1", "1.0.0.1"]
    }

    /// Raw config + chosen server passed from the container app.
    private var configJSON: String?
    private var serverID: String?

    #if canImport(Libbox)
    private lazy var platformInterface = ExtensionPlatformInterface(self)
    private var commandServer: LibboxCommandServer?
    #else
    private var boxService: Any?   // mock marker (nil => mock mode)
    #endif

    // MARK: - Start

    override func startTunnel(options: [String: NSObject]?,
                             completionHandler: @escaping (Error?) -> Void) {
        os_log("startTunnel", log: log, type: .info)

        // 1. Read the payload the container app handed us.
        //    "config" — the full sing-box JSON for the selected server.
        //    "server" — the server id (handy for logging / reconnects).
        self.configJSON = (options?["config"] as? String)
            ?? (options?["config"] as? NSString as String?)
        self.serverID = (options?["server"] as? String)
            ?? (options?["server"] as? NSString as String?)

        if configJSON == nil {
            os_log("startTunnel: no 'config' in options — using mock interface only",
                   log: log, type: .error)
        } else {
            os_log("startTunnel: got config (%{public}d bytes) for server %{public}@",
                   log: log, type: .info,
                   configJSON?.utf8.count ?? 0, serverID ?? "—")
        }

        #if canImport(Libbox)
        // Real engine: libbox parses the config and, when it brings up its tun
        // inbound, calls our platform interface's openTun — which sets the
        // tunnel network settings and hands sing-box the tun fd.
        do {
            try startLibbox()
            os_log("tunnel started (engine=libbox)", log: log, type: .info)
            completionHandler(nil)
        } catch {
            os_log("startLibbox failed: %{public}@", log: log, type: .error, error.localizedDescription)
            completionHandler(error)
        }
        #else
        // НЕТ движка (Libbox.xcframework не слинкован в этой сборке). НЕ поднимаем
        // туннель с дефолтным маршрутом — иначе он перехватит весь трафик и будет его
        // ронять: ОС покажет «подключено», а интернета нет (blackhole). Честно
        // отказываемся, чтобы трафик пользователя не уходил в неработающий TUN.
        os_log("startTunnel: sing-box (Libbox) не слинкован — отказ, чтобы не блокировать трафик",
               log: log, type: .error)
        let noEngine = NSError(domain: "app.bitaps.vpn", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "VPN-движок не собран в этой сборке. Туннель не запущен, чтобы не блокировать интернет."
        ])
        completionHandler(noEngine)
        #endif
    }

    #if canImport(Libbox)
    /// Set up libbox, start a command server (which drives the box service), and
    /// load the sing-box config. openTun is invoked by libbox during this call.
    private func startLibbox() throws {
        guard let config = configJSON else {
            throw NSError(domain: "bitaps.PacketTunnel", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "missing config"])
        }
        let base = NSTemporaryDirectory().appending("bitaps")
        let work = base + "/work", temp = base + "/temp"
        for p in [base, work, temp] {
            try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true)
        }
        let opts = LibboxSetupOptions()
        opts.basePath = base
        opts.workingPath = work
        opts.tempPath = temp
        opts.logMaxLines = 3000
        var setupErr: NSError?
        LibboxSetup(opts, &setupErr)
        if let setupErr { throw setupErr }

        var serverErr: NSError?
        guard let server = LibboxNewCommandServer(platformInterface, platformInterface, &serverErr) else {
            throw serverErr ?? NSError(domain: "bitaps.PacketTunnel", code: -1,
                                       userInfo: [NSLocalizedDescriptionKey: "create command server failed"])
        }
        try server.start()
        commandServer = server
        try server.startOrReloadService(config, options: LibboxOverrideOptions())
    }

    /// Reload the running service (used on a server switch without a full restart).
    func reloadService() {
        guard let config = configJSON, let server = commandServer else { return }
        try? server.startOrReloadService(config, options: LibboxOverrideOptions())
    }
    #endif

    // MARK: - Stop

    override func stopTunnel(with reason: NEProviderStopReason,
                            completionHandler: @escaping () -> Void) {
        os_log("stopTunnel: reason=%{public}d", log: log, type: .info, reason.rawValue)

        #if canImport(Libbox)
        try? commandServer?.closeService()
        platformInterface.reset()
        try? commandServer?.close()
        commandServer = nil
        #else
        boxService = nil
        #endif
        configJSON = nil
        serverID = nil
        completionHandler()
    }

    // MARK: - App ↔ extension messaging

    /// The container app can send small control messages (e.g. ask for live
    /// stats or trigger a reconnect). We echo a tiny status payload for now.
    override func handleAppMessage(_ messageData: Data,
                                  completionHandler: ((Data?) -> Void)?) {
        let request = String(data: messageData, encoding: .utf8) ?? ""
        os_log("handleAppMessage: %{public}@", log: log, type: .debug, request)

        #if canImport(Libbox)
        let status = commandServer == nil ? "stopped" : "running"
        #else
        let status = boxService == nil ? "mock" : "running"
        #endif
        let reply = "{\"server\":\"\(serverID ?? "")\",\"engine\":\"\(status)\"}"
        completionHandler?(reply.data(using: .utf8))
    }

    // MARK: - Sleep / wake

    override func sleep(completionHandler: @escaping () -> Void) {
        // TODO: pause / flush libbox before the device sleeps if needed.
        os_log("sleep", log: log, type: .debug)
        completionHandler()
    }

    override func wake() {
        // TODO: resume libbox / re-validate the connection after wake.
        os_log("wake", log: log, type: .debug)
    }

    // MARK: - Helpers

    /// Build the NEPacketTunnelNetworkSettings that define the virtual
    /// interface: address, routes and DNS. This is what makes the OS treat
    /// us as the active network path.
    private func makeTunnelSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(
            tunnelRemoteAddress: Net.tunnelRemoteAddress)

        // IPv4: single tunnel address + default route so all traffic goes
        // through the interface.
        let ipv4 = NEIPv4Settings(addresses: [Net.ipv4Address],
                                  subnetMasks: [Net.ipv4SubnetMask])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        // DNS through the tunnel for everything.
        let dns = NEDNSSettings(servers: Net.dnsServers)
        dns.matchDomains = [""]   // match all domains => capture all DNS
        settings.dnsSettings = dns

        // A conservative MTU that survives most underlying links.
        settings.mtu = 1500

        return settings
    }

    /// MOCK engine: no real tunneling. We keep a benign read-loop running so
    /// the interface is "alive" and the OS keeps reporting the VPN as on.
    /// This is replaced entirely by BoxService once Libbox is linked.
    private func startMockEngine() {
        // boxService stays nil => callers know we're in mock mode.
        // Drain packets so the OS read buffer doesn't back up. We simply
        // discard them (no upstream to forward to yet).
        readPacketsLoop()
    }

    /// Recursively read and discard packets while in mock mode.
    private func readPacketsLoop() {
        packetFlow.readPackets { [weak self] _, _ in
            guard let self else { return }
            // TODO: hand these packets to libbox instead of discarding.
            // In mock mode we drop them and keep looping.
            self.readPacketsLoop()
        }
    }
}

#endif // canImport(NetworkExtension)
