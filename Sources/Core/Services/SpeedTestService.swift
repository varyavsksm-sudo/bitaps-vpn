import Foundation

/// Real throughput measurement: downloads/uploads a sized payload through the
/// current connection (= through the VPN when connected) and times it, plus a
/// real latency/jitter probe. Uses Cloudflare's open speed endpoints.
public actor SpeedTestService {
    public init() {}
    /// On by default — this is a real test. (A mock fallback remains for previews.)
    public static var useRealTest = true

    public func run(via server: Server?) async -> SpeedTestResult {
        guard Self.useRealTest else { return mockRun(via: server) }
        let (ms, jitter) = await measureLatency()
        let down = await measureDownload(bytes: 25_000_000)   // 25 MB
        let up = await measureUpload(bytes: 8_000_000)        // 8 MB
        return SpeedTestResult(downMbps: down, upMbps: up, pingMs: ms, jitterMs: jitter)
    }

    // MARK: - Real measurement

    private static func session() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        cfg.timeoutIntervalForRequest = 30
        return URLSession(configuration: cfg)
    }

    private func measureDownload(bytes: Int) async -> Double {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(bytes)") else { return 0 }
        let t0 = DispatchTime.now().uptimeNanoseconds
        guard let (data, _) = try? await Self.session().data(from: url) else { return 0 }
        let secs = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e9
        guard secs > 0.01, !data.isEmpty else { return 0 }
        return Double(data.count) * 8 / secs / 1_000_000          // Mbps
    }

    private func measureUpload(bytes: Int) async -> Double {
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else { return 0 }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let payload = Data(count: bytes)
        let t0 = DispatchTime.now().uptimeNanoseconds
        guard (try? await Self.session().upload(for: req, from: payload)) != nil else { return 0 }
        let secs = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e9
        guard secs > 0.01 else { return 0 }
        return Double(bytes) * 8 / secs / 1_000_000               // Mbps
    }

    private func measureLatency() async -> (ms: Int, jitter: Int) {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=0") else { return (0, 0) }
        var samples: [Double] = []
        for _ in 0..<5 {
            let t0 = DispatchTime.now().uptimeNanoseconds
            if (try? await Self.session().data(from: url)) != nil {
                samples.append(Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000)  // ms
            }
        }
        guard !samples.isEmpty else { return (0, 0) }
        let best = samples.min() ?? 0
        let mean = samples.reduce(0, +) / Double(samples.count)
        let jitter = samples.map { abs($0 - mean) }.reduce(0, +) / Double(samples.count)
        return (Int(best.rounded()), max(0, Int(jitter.rounded())))
    }

    // MARK: - Mock (previews only)

    private func mockRun(via server: Server?) -> SpeedTestResult {
        let ping = server?.pingMs ?? 30
        let quality = max(0.2, 1.0 - Double(ping) / 220.0)
        let down = (300...1900).randomElement().map(Double.init)! * quality
        return SpeedTestResult(downMbps: down, upMbps: down * 0.25,
                               pingMs: ping, jitterMs: 4)
    }
}
