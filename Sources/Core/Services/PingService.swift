import Foundation
import Network

/// Latency measurement. Opens a timed TCP connection to the server's real
/// host:port (parsed from its config/key) and measures time-to-ready. For demo
/// catalog entries (no real host) it falls back to a believable nominal value.
public actor PingService {
    public init() {}

    public func ping(_ server: Server) async -> PingResult {
        if let (host, port) = Self.hostPort(server) {
            let ms = await Self.tcpConnectMs(host: host, port: port)
            return PingResult(serverId: server.id, ms: ms)   // nil ⇒ unreachable (honest)
        }
        // Demo/catalog node without a real endpoint — nominal with light jitter.
        try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.1...0.35) * 1_000_000_000))
        if !server.available && Bool.random() { return PingResult(serverId: server.id, ms: nil) }
        return PingResult(serverId: server.id, ms: max(4, server.pingMs + Int.random(in: -6...18)))
    }

    /// Real host:port for the user's own server (config holds the VLESS/… key).
    static func hostPort(_ server: Server) -> (String, UInt16)? {
        guard let cfg = server.config, let out = SingBoxConfig.parseOutbound(cfg),
              let host = out["server"] as? String, !host.isEmpty,
              let port = out["server_port"] as? Int, (1...65535).contains(port) else { return nil }
        return (host, UInt16(port))
    }

    /// Time (ms) to establish a TCP connection, or nil on timeout/failure.
    static func tcpConnectMs(host: String, port: UInt16, timeout: Double = 3) async -> Int? {
        await withCheckedContinuation { (cont: CheckedContinuation<Int?, Never>) in
            let conn = NWConnection(host: NWEndpoint.Host(host),
                                    port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
            let start = DispatchTime.now().uptimeNanoseconds
            let lock = NSLock()
            var done = false
            func finish(_ ms: Int?) {
                lock.lock(); defer { lock.unlock() }
                if done { return }
                done = true
                conn.cancel()
                cont.resume(returning: ms)
            }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(Int(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000))
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }
    }
}
