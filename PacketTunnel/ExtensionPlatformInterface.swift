import Foundation
import Network
#if canImport(NetworkExtension)
import NetworkExtension
#endif

#if canImport(Libbox)
import Libbox

/// Bridges sing-box (libbox) to the NetworkExtension packet tunnel. Adapted from
/// SagerNet/sing-box-for-apple's `ExtensionPlatformInterface`, trimmed to what a
/// consumer VPN needs (the SSH / shell / tailscale / system-proxy helpers are
/// stubbed out). Implements both the platform interface and the command-server
/// handler — `LibboxNewCommandServer` is given this object for both.
final class ExtensionPlatformInterface: NSObject {
    private weak var tunnel: NEPacketTunnelProvider?
    private var networkSettings: NEPacketTunnelNetworkSettings?
    private var nwMonitor: NWPathMonitor?

    init(_ tunnel: NEPacketTunnelProvider) { self.tunnel = tunnel }

    func reset() { networkSettings = nil }

    private func err(_ message: String) -> NSError {
        NSError(domain: "bitaps.PacketTunnel", code: -1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}

// MARK: - LibboxPlatformInterface

extension ExtensionPlatformInterface: LibboxPlatformInterfaceProtocol {

    /// The crux: translate libbox's tun options into NEPacketTunnelNetworkSettings,
    /// bring the interface up, and hand sing-box the tun file descriptor.
    func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        guard let options, let ret0_, let tunnel else { throw err("nil openTun args") }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        if options.getAutoRoute() {
            settings.mtu = NSNumber(value: options.getMTU())

            // DNS
            if let mode = options.getDNSMode(), mode.value != LibboxDNSModeDisabled {
                let it = try options.getDNSServerAddress()
                var servers: [String] = []
                while it.hasNext() { servers.append(it.next()) }
                if !servers.isEmpty { settings.dnsSettings = NEDNSSettings(servers: servers) }
            }

            // IPv4 address + routes (default route unless libbox specified ranges)
            var v4addr: [String] = [], v4mask: [String] = []
            if let a4 = options.getInet4Address() {
                while a4.hasNext() { if let p = a4.next() { v4addr.append(p.address()); v4mask.append(p.mask()) } }
            }
            let v4 = NEIPv4Settings(addresses: v4addr, subnetMasks: v4mask)
            var v4routes: [NEIPv4Route] = []
            if let r4 = options.getInet4RouteAddress(), r4.hasNext() {
                while r4.hasNext() { if let p = r4.next() { v4routes.append(NEIPv4Route(destinationAddress: p.address(), subnetMask: p.mask())) } }
            } else {
                v4routes = [NEIPv4Route.default()]
            }
            var v4excl: [NEIPv4Route] = []
            if let e4 = options.getInet4RouteExcludeAddress() {
                while e4.hasNext() { if let p = e4.next() { v4excl.append(NEIPv4Route(destinationAddress: p.address(), subnetMask: p.mask())) } }
            }
            v4.includedRoutes = v4routes
            v4.excludedRoutes = v4excl
            settings.ipv4Settings = v4

            // IPv6 address + routes
            var v6addr: [String] = [], v6pfx: [NSNumber] = []
            if let a6 = options.getInet6Address() {
                while a6.hasNext() { if let p = a6.next() { v6addr.append(p.address()); v6pfx.append(NSNumber(value: p.prefix())) } }
            }
            let v6 = NEIPv6Settings(addresses: v6addr, networkPrefixLengths: v6pfx)
            var v6routes: [NEIPv6Route] = []
            if let r6 = options.getInet6RouteAddress(), r6.hasNext() {
                while r6.hasNext() { if let p = r6.next() { v6routes.append(NEIPv6Route(destinationAddress: p.address(), networkPrefixLength: NSNumber(value: p.prefix()))) } }
            } else {
                v6routes = [NEIPv6Route.default()]
            }
            var v6excl: [NEIPv6Route] = []
            if let e6 = options.getInet6RouteExcludeAddress() {
                while e6.hasNext() { if let p = e6.next() { v6excl.append(NEIPv6Route(destinationAddress: p.address(), networkPrefixLength: NSNumber(value: p.prefix()))) } }
            }
            v6.includedRoutes = v6routes
            v6.excludedRoutes = v6excl
            settings.ipv6Settings = v6
        }

        networkSettings = settings
        // Apply synchronously (libbox calls openTun on its own thread).
        let sem = DispatchSemaphore(value: 0)
        var applyError: Error?
        tunnel.setTunnelNetworkSettings(settings) { e in applyError = e; sem.signal() }
        sem.wait()
        if let applyError { throw applyError }

        if let fd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            ret0_.pointee = fd
            return
        }
        let fd = LibboxGetTunnelFileDescriptor()
        if fd != -1 { ret0_.pointee = fd } else { throw err("missing tun file descriptor") }
    }

    // MARK: default-interface monitor (sing-box auto_detect_interface)

    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        guard let listener else { return }
        let monitor = NWPathMonitor()
        nwMonitor = monitor
        let semaphore = DispatchSemaphore(value: 0)
        monitor.pathUpdateHandler = { [weak self] path in
            self?.update(listener, path)
            semaphore.signal()
            monitor.pathUpdateHandler = { [weak self] path in self?.update(listener, path) }
        }
        monitor.start(queue: DispatchQueue.global())
        semaphore.wait()
    }

    private func update(_ listener: LibboxInterfaceUpdateListenerProtocol, _ path: Network.NWPath) {
        guard path.status != .unsatisfied, let iface = path.availableInterfaces.first else {
            listener.updateDefaultInterface("", interfaceIndex: -1, isExpensive: false, isConstrained: false)
            return
        }
        listener.updateDefaultInterface(iface.name, interfaceIndex: Int32(iface.index),
                                        isExpensive: path.isExpensive, isConstrained: path.isConstrained)
    }

    func closeDefaultInterfaceMonitor(_: LibboxInterfaceUpdateListenerProtocol?) throws {
        nwMonitor?.cancel(); nwMonitor = nil
    }

    func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        guard let nwMonitor else { throw err("interface monitor not started") }
        let path = nwMonitor.currentPath
        var out: [LibboxNetworkInterface] = []
        if path.status != .unsatisfied {
            for it in path.availableInterfaces {
                let i = LibboxNetworkInterface()
                i.name = it.name
                i.index = Int32(it.index)
                switch it.type {
                case .wifi:          i.type = LibboxInterfaceTypeWIFI
                case .cellular:      i.type = LibboxInterfaceTypeCellular
                case .wiredEthernet: i.type = LibboxInterfaceTypeEthernet
                default:             i.type = LibboxInterfaceTypeOther
                }
                out.append(i)
            }
        }
        return InterfaceArray(out)
    }

    final class InterfaceArray: NSObject, LibboxNetworkInterfaceIteratorProtocol {
        private var it: IndexingIterator<[LibboxNetworkInterface]>
        private var cur: LibboxNetworkInterface?
        init(_ a: [LibboxNetworkInterface]) { it = a.makeIterator() }
        func hasNext() -> Bool { cur = it.next(); return cur != nil }
        func next() -> LibboxNetworkInterface? { cur }
    }

    // MARK: capability flags / unsupported helpers

    func underNetworkExtension() -> Bool { true }
    func includeAllNetworks() -> Bool { false }
    func usePlatformAutoDetectControl() -> Bool { true }
    func autoDetectControl(_ fd: Int32) throws {}
    func useProcFS() -> Bool { false }
    func usePlatformShell() -> Bool { false }
    func clearDNSCache() {}
    func registerMyInterface(_ name: String?) {}
    func tailscaleHostname() -> String { "" }

    func readWIFIState() -> LibboxWIFIState? { nil }
    func localDNSTransport() -> LibboxLocalDNSTransportProtocol? { nil }
    func send(_ notification: LibboxNotification?) throws {}

    func checkPlatformShell() throws { throw err("shell not supported") }
    func openShellSession(_ user: LibboxPlatformUser?, command: String?, environ: LibboxStringIteratorProtocol?,
                          term: String?, rows: Int32, cols: Int32) throws -> LibboxShellSessionProtocol {
        throw err("shell not supported")
    }
    func findConnectionOwner(_ ipProtocol: Int32, sourceAddress: String?, sourcePort: Int32,
                             destinationAddress: String?, destinationPort: Int32) throws -> LibboxConnectionOwner {
        throw err("connection owner lookup not supported")
    }
    func lookupSFTPServer(_ error: NSErrorPointer) -> String { error?.pointee = err("not supported"); return "" }
    func lookupUser(_ username: String?) throws -> LibboxPlatformUser { throw err("not supported") }
    func readSystemSSHHostKey(_ error: NSErrorPointer) -> String { error?.pointee = err("not supported"); return "" }
    func startNeighborMonitor(_ listener: LibboxNeighborUpdateListenerProtocol?) throws {}
    func closeNeighborMonitor(_ listener: LibboxNeighborUpdateListenerProtocol?) throws {}
}

// MARK: - LibboxCommandServerHandler

extension ExtensionPlatformInterface: LibboxCommandServerHandlerProtocol {
    func serviceReload() throws {
        (tunnel as? PacketTunnelProvider)?.reloadService()
    }
    func serviceStop() throws {
        tunnel?.cancelTunnelWithError(nil)
    }
    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        let s = LibboxSystemProxyStatus()
        s.available = false
        s.enabled = false
        return s
    }
    func setSystemProxyEnabled(_ enabled: Bool) throws {}
    func connectSSHAgent(_ ret0_: UnsafeMutablePointer<Int32>?) throws { throw err("not supported") }
    func triggerNativeCrash() throws { throw err("not supported") }
    func writeDebugMessage(_ message: String?) {}
}

#endif // canImport(Libbox)
