import Foundation

/// Abstraction over the actual tunnel. The UI/Store only ever talks to this.
/// Two implementations: `MockTunnel` (works now, fakes everything realistically)
/// and `SingBoxTunnel` (skeleton wired to the NetworkExtension + libbox).
@MainActor
public protocol VPNTunnel: AnyObject {
    var delegate: VPNTunnelDelegate? { get set }
    var currentServer: Server? { get }
    var status: VPNStatus { get }

    func connect(to server: Server) async throws
    func disconnect() async
}

@MainActor
public protocol VPNTunnelDelegate: AnyObject {
    func tunnel(_ tunnel: VPNTunnel, didChange status: VPNStatus)
    func tunnel(_ tunnel: VPNTunnel, didUpdate stats: ConnectionStats)
}

/// Selects the active tunnel implementation. Flip `useSingBox` once the
/// NetworkExtension + libbox build is in place.
public enum TunnelFactory {
    public static var useSingBox = false

    @MainActor public static func make() -> VPNTunnel {
        useSingBox ? SingBoxTunnel() : MockTunnel()
    }
}
