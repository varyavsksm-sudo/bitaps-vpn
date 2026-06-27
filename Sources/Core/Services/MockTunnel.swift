import Foundation

/// Fully simulates a VPN session: connecting delay, live up/down speeds that
/// wander, a session timer, a fake assigned IP, and clean disconnect. Lets the
/// entire UI be exercised with zero infrastructure.
@MainActor
public final class MockTunnel: VPNTunnel {
    public weak var delegate: VPNTunnelDelegate?
    public private(set) var currentServer: Server?
    public private(set) var status: VPNStatus = .disconnected {
        didSet { delegate?.tunnel(self, didChange: status) }
    }

    private var ticker: Task<Void, Never>?
    private var stats = ConnectionStats.zero

    public init() {}

    public func connect(to server: Server) async throws {
        guard server.available else { throw AppError.serverUnavailable }
        ticker?.cancel()
        currentServer = server
        status = .connecting

        // Realistic-ish handshake delay (0.9…1.8s).
        let delay = UInt64((0.9 + Double(server.pingMs) / 200.0) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: delay)
        guard status == .connecting else { return } // cancelled mid-handshake

        stats = ConnectionStats(ip: Self.fakeIP(for: server), connectedSince: Date())
        delegate?.tunnel(self, didUpdate: stats)
        status = .connected
        startTicking()
    }

    public func disconnect() async {
        ticker?.cancel(); ticker = nil
        status = .disconnecting
        try? await Task.sleep(nanoseconds: 450_000_000)
        currentServer = nil
        // Finalize first (status change closes the traffic-log entry with the real
        // accumulated bytes and clears activeLogID), THEN zero the live stats so the
        // reset update can't overwrite the saved totals with 0.
        status = .disconnected
        stats = .zero
        delegate?.tunnel(self, didUpdate: stats)
    }

    private func startTicking() {
        ticker = Task { [weak self] in
            var down = 14_000_000.0  // ~112 Mbit start
            var up = 2_400_000.0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, self.status.isActive else { break }
                // wander the speeds a little so the UI feels alive
                down = Self.wander(down, base: 14_000_000, spread: 9_000_000)
                up = Self.wander(up, base: 2_400_000, spread: 1_200_000)
                self.stats.downloadBps = down
                self.stats.uploadBps = up
                self.stats.totalDown += Int64(down)
                self.stats.totalUp += Int64(up)
                self.delegate?.tunnel(self, didUpdate: self.stats)
            }
        }
    }

    private static func wander(_ v: Double, base: Double, spread: Double) -> Double {
        let drift = Double.random(in: -spread...spread) * 0.25
        let pull = (base - v) * 0.1
        return max(base * 0.2, v + drift + pull)
    }

    private static func fakeIP(for server: Server) -> String {
        // deterministic-ish per server so it doesn't flicker
        let h = server.id.hashValue & 0x7fff_ffff
        return "\(85 + h % 60).\(h / 7 % 200).\(h / 13 % 200).\(h / 17 % 200)"
    }
}
