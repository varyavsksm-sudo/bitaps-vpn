import Foundation

/// Latency measurement. Mock returns a realistic value derived from the node's
/// nominal ping with jitter; the real implementation would open a timed TCP
/// connection to the node (or send an ICMP echo) and measure round-trip time.
public actor PingService {
    public init() {}

    /// Set true once a real reachability probe is wired in.
    public static var useRealProbe = false

    public func ping(_ server: Server) async -> PingResult {
        if Self.useRealProbe {
            return await realProbe(server)
        }
        // Mock: simulate the measurement delay, then jitter around nominal ping.
        let base = server.pingMs
        let simulatedDelay = UInt64(Double.random(in: 0.15...0.5) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: simulatedDelay)
        // unavailable nodes occasionally "time out"
        if !server.available && Bool.random() {
            return PingResult(serverId: server.id, ms: nil)
        }
        let jitter = Int.random(in: -6...18)
        return PingResult(serverId: server.id, ms: max(4, base + jitter))
    }

    /// TODO: real TCP-connect timing to server host:port. Placeholder uses nominal.
    private func realProbe(_ server: Server) async -> PingResult {
        // let start = DispatchTime.now()
        // open NWConnection to host:443, wait .ready, measure delta…
        return PingResult(serverId: server.id, ms: server.pingMs)
    }
}
