import Foundation

/// Measures real throughput. Mock returns a believable result derived from the
/// node's nominal ping (closer node => faster). Real impl would download/upload
/// a sized payload through the tunnel and time it.
public actor SpeedTestService {
    public init() {}
    public static var useRealTest = false

    public func run(via server: Server?) async -> SpeedTestResult {
        if Self.useRealTest { return await realRun(via: server) }
        // simulate a multi-second test
        try? await Task.sleep(nanoseconds: 2_200_000_000)
        let ping = server?.pingMs ?? 30
        // up to ~2 Gbit/s claim on the best nodes; scale down with ping/load
        let quality = max(0.2, 1.0 - Double(ping) / 220.0)
        let down = (300...1900).randomElement().map(Double.init)! * quality
        let up = down * Double.random(in: 0.18...0.32)
        return SpeedTestResult(downMbps: down, upMbps: up,
                               pingMs: ping + Int.random(in: -3...6),
                               jitterMs: Int.random(in: 1...9))
    }

    private func realRun(via server: Server?) async -> SpeedTestResult {
        // TODO: GET a known-size object through the tunnel, time it; same for upload.
        SpeedTestResult(downMbps: 0, upMbps: 0, pingMs: server?.pingMs ?? 0, jitterMs: 0)
    }
}
