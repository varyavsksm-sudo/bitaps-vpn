import Foundation

/// Turns a share-link key (the `vpn_key` the bot issues) into a full sing-box
/// client config JSON that the PacketTunnel (libbox) runs.
///
/// Supports the schemes the app accepts: vless:// (incl. Reality), vmess://,
/// trojan://, ss://, hysteria2://. Pure Swift, no dependencies — unit-testable.
public enum SingBoxConfig {

    /// Routing policy for the generated config.
    public enum Routing: String, Sendable {
        case global   // everything through the proxy
        case rules    // smart: RU + private direct, the rest through the proxy
        case direct   // bypass (debug): everything direct
    }

    /// Build the full config. Returns `nil` if the key can't be parsed.
    public static func generate(fromKey key: String,
                                routing: Routing = .rules,
                                remoteDNS: String = "https://1.1.1.1/dns-query",
                                directDNS: String = "8.8.8.8",
                                mtu: Int = 9000) -> String? {
        guard let outbound = parseOutbound(key.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        let config: [String: Any] = [
            "log": ["level": "warn", "timestamp": true],
            "dns": dns(remoteDNS: remoteDNS, directDNS: directDNS, routing: routing),
            "inbounds": [[
                "type": "tun",
                "tag": "tun-in",
                "interface_name": "bitaps-tun",
                "address": ["172.19.0.1/30", "fdfe:dcba:9876::1/126"],
                "mtu": mtu,
                "auto_route": true,
                "strict_route": true,
                "stack": "system",
            ]],
            "outbounds": [
                outbound,
                ["type": "direct", "tag": "direct"],
            ],
            "route": route(routing: routing),
        ]
        guard JSONSerialization.isValidJSONObject(config),
              let data = try? JSONSerialization.data(withJSONObject: config,
                                                     options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return json
    }

    // MARK: - DNS

    private static func dns(remoteDNS: String, directDNS: String, routing: Routing) -> [String: Any] {
        // New DNS server format (sing-box 1.12+; legacy "address" was removed in 1.14).
        var rules: [[String: Any]] = []
        if routing == .rules {
            // Russian + offline sites resolve via the direct resolver.
            rules.append(["rule_set": ["geosite-ru"], "server": "direct"] as [String: Any])
        }
        return [
            "servers": [
                dnsServer("remote", remoteDNS, "proxy"),
                dnsServer("direct", directDNS, "direct"),
            ],
            "rules": rules,
            "final": routing == .direct ? "direct" : "remote",
            "strategy": "prefer_ipv4",
        ]
    }

    /// One DNS server in the new typed format (udp/tls/https/quic + server host).
    private static func dnsServer(_ tag: String, _ addr: String, _ detour: String) -> [String: Any] {
        var s: [String: Any] = ["tag": tag, "detour": detour]
        if addr.hasPrefix("https://") {
            s["type"] = "https"; s["server"] = URL(string: addr)?.host ?? addr
        } else if addr.hasPrefix("tls://") {
            s["type"] = "tls"; s["server"] = String(addr.dropFirst("tls://".count))
        } else if addr.hasPrefix("quic://") {
            s["type"] = "quic"; s["server"] = String(addr.dropFirst("quic://".count))
        } else {
            s["type"] = "udp"; s["server"] = addr
        }
        return s
    }

    // MARK: - Route

    private static func route(routing: Routing) -> [String: Any] {
        // New rule-action format (sing-box 1.11+): dns hijack + reject instead of
        // the removed dns/block outbounds; geo matching via remote rule_sets.
        var rules: [[String: Any]] = [
            ["action": "sniff"],
            ["protocol": "dns", "action": "hijack-dns"],
            ["ip_is_private": true, "outbound": "direct"],
            ["rule_set": ["geosite-ads"], "action": "reject"],
        ]
        var ruleSets: [[String: Any]] = [
            ruleSet("geosite-ads", "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs"),
        ]
        if routing == .rules {
            // RU geoip/geosite go direct; everything else through the proxy.
            rules.append(["rule_set": ["geoip-ru", "geosite-ru"], "outbound": "direct"] as [String: Any])
            ruleSets.append(ruleSet("geoip-ru", "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs"))
            ruleSets.append(ruleSet("geosite-ru", "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ru.srs"))
        }
        return [
            "rules": rules,
            "rule_set": ruleSets,
            "final": routing == .direct ? "direct" : "proxy",
            "auto_detect_interface": true,
        ]
    }

    private static func ruleSet(_ tag: String, _ url: String) -> [String: Any] {
        ["type": "remote", "tag": tag, "format": "binary", "url": url, "download_detour": "proxy"]
    }

    // MARK: - Outbound parsing

    /// Parse one share link into a sing-box outbound dict (tag "proxy").
    static func parseOutbound(_ key: String) -> [String: Any]? {
        guard let scheme = key.split(separator: ":").first.map(String.init)?.lowercased() else { return nil }
        switch scheme {
        case "vless":     return parseVLESS(key)
        case "trojan":    return parseTrojan(key)
        case "vmess":     return parseVMess(key)
        case "ss":        return parseShadowsocks(key)
        case "hysteria2", "hy2": return parseHysteria2(key)
        default:          return nil
        }
    }

    // vless://uuid@host:port?type=&security=&sni=&pbk=&sid=&fp=&flow=&host=&path=&serviceName=#name
    private static func parseVLESS(_ key: String) -> [String: Any]? {
        guard let c = URLComponents(string: key),
              let uuid = c.user, let host = c.host, let port = c.port else { return nil }
        let q = queryDict(c)
        var out: [String: Any] = [
            "type": "vless", "tag": "proxy",
            "server": host, "server_port": port,
            "uuid": uuid, "packet_encoding": "xudp",
        ]
        let security = (q["security"] ?? "none").lowercased()
        if let flow = q["flow"], !flow.isEmpty { out["flow"] = flow }
        if security == "reality" || security == "tls" || security == "xtls" {
            out["tls"] = tlsBlock(security: security, q: q, defaultSNI: host)
        }
        if let transport = transportBlock(q) { out["transport"] = transport }
        return out
    }

    // trojan://password@host:port?security=tls&sni=&type=#name
    private static func parseTrojan(_ key: String) -> [String: Any]? {
        guard let c = URLComponents(string: key),
              let pass = c.user, let host = c.host, let port = c.port else { return nil }
        let q = queryDict(c)
        var out: [String: Any] = [
            "type": "trojan", "tag": "proxy",
            "server": host, "server_port": port, "password": pass,
        ]
        let security = (q["security"] ?? "tls").lowercased()
        if security != "none" { out["tls"] = tlsBlock(security: security, q: q, defaultSNI: host) }
        if let transport = transportBlock(q) { out["transport"] = transport }
        return out
    }

    // vmess://base64({v,ps,add,port,id,aid,net,type,host,path,tls,sni,scy})
    private static func parseVMess(_ key: String) -> [String: Any]? {
        let b64 = String(key.dropFirst("vmess://".count))
        guard let data = base64Pad(b64), let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let host = (j["add"] as? String) ?? ""
        let port = intValue(j["port"]) ?? 443
        guard !host.isEmpty, let id = j["id"] as? String else { return nil }
        var out: [String: Any] = [
            "type": "vmess", "tag": "proxy",
            "server": host, "server_port": port,
            "uuid": id, "security": (j["scy"] as? String) ?? "auto",
            "alter_id": intValue(j["aid"]) ?? 0,
        ]
        if let tls = j["tls"] as? String, tls == "tls" {
            out["tls"] = tlsBlock(security: "tls",
                                  q: ["sni": (j["sni"] as? String) ?? (j["host"] as? String) ?? host],
                                  defaultSNI: host)
        }
        let net = (j["net"] as? String) ?? "tcp"
        if let transport = transportBlock(["type": net,
                                           "host": (j["host"] as? String) ?? "",
                                           "path": (j["path"] as? String) ?? "",
                                           "serviceName": (j["path"] as? String) ?? ""]) {
            out["transport"] = transport
        }
        return out
    }

    // ss://base64(method:password)@host:port#name  OR  ss://base64(method:password@host:port)#name
    private static func parseShadowsocks(_ key: String) -> [String: Any]? {
        var body = String(key.dropFirst("ss://".count))
        if let hash = body.firstIndex(of: "#") { body = String(body[..<hash]) }
        // Form A: userinfo is base64, host:port in clear.
        if let at = body.firstIndex(of: "@") {
            let userinfo = String(body[..<at])
            let hostPort = String(body[body.index(after: at)...])
            guard let decoded = base64Pad(userinfo).flatMap({ String(data: $0, encoding: .utf8) }),
                  let colon = decoded.firstIndex(of: ":"),
                  let (host, port) = splitHostPort(hostPort) else { return nil }
            let method = String(decoded[..<colon])
            let password = String(decoded[decoded.index(after: colon)...])
            return ["type": "shadowsocks", "tag": "proxy", "server": host,
                    "server_port": port, "method": method, "password": password]
        }
        // Form B: the whole thing is base64.
        guard let decoded = base64Pad(body).flatMap({ String(data: $0, encoding: .utf8) }),
              let at = decoded.firstIndex(of: "@"),
              let colon = decoded[..<at].firstIndex(of: ":"),
              let (host, port) = splitHostPort(String(decoded[decoded.index(after: at)...])) else { return nil }
        let method = String(decoded[..<colon])
        let password = String(decoded[decoded.index(after: colon)..<at])
        return ["type": "shadowsocks", "tag": "proxy", "server": host,
                "server_port": port, "method": method, "password": password]
    }

    // hysteria2://password@host:port?sni=&insecure=#name
    private static func parseHysteria2(_ key: String) -> [String: Any]? {
        guard let c = URLComponents(string: key.replacingOccurrences(of: "hy2://", with: "hysteria2://")),
              let pass = c.user, let host = c.host, let port = c.port else { return nil }
        let q = queryDict(c)
        var tls: [String: Any] = ["enabled": true, "server_name": q["sni"] ?? host]
        if q["insecure"] == "1" { tls["insecure"] = true }
        return ["type": "hysteria2", "tag": "proxy", "server": host,
                "server_port": port, "password": pass, "tls": tls]
    }

    // MARK: - Shared builders

    private static func tlsBlock(security: String, q: [String: String], defaultSNI: String) -> [String: Any] {
        var tls: [String: Any] = [
            "enabled": true,
            "server_name": q["sni"] ?? q["host"] ?? defaultSNI,
        ]
        if let alpn = q["alpn"], !alpn.isEmpty {
            tls["alpn"] = alpn.split(separator: ",").map(String.init)
        }
        if q["allowInsecure"] == "1" || q["insecure"] == "1" { tls["insecure"] = true }
        let fp = q["fp"], hasFP = !(fp?.isEmpty ?? true)
        if security == "reality" {
            var reality: [String: Any] = ["enabled": true]
            if let pbk = q["pbk"] { reality["public_key"] = pbk }
            if let sid = q["sid"] { reality["short_id"] = sid }
            tls["reality"] = reality
            tls["utls"] = ["enabled": true, "fingerprint": hasFP ? fp! : "chrome"]
        } else if hasFP {
            tls["utls"] = ["enabled": true, "fingerprint": fp!]
        }
        return tls
    }

    /// ws / grpc / httpupgrade transport (nil for plain tcp).
    private static func transportBlock(_ q: [String: String]) -> [String: Any]? {
        switch (q["type"] ?? "tcp").lowercased() {
        case "ws":
            var t: [String: Any] = ["type": "ws"]
            if let path = q["path"], !path.isEmpty { t["path"] = path }
            if let host = q["host"], !host.isEmpty { t["headers"] = ["Host": host] }
            return t
        case "grpc":
            return ["type": "grpc", "service_name": q["serviceName"] ?? q["path"] ?? ""]
        case "httpupgrade":
            var t: [String: Any] = ["type": "httpupgrade"]
            if let path = q["path"], !path.isEmpty { t["path"] = path }
            if let host = q["host"], !host.isEmpty { t["host"] = host }
            return t
        default:
            return nil
        }
    }

    // MARK: - Helpers

    private static func queryDict(_ c: URLComponents) -> [String: String] {
        var d: [String: String] = [:]
        for item in c.queryItems ?? [] { d[item.name] = item.value }
        return d
    }

    private static func splitHostPort(_ s: String) -> (String, Int)? {
        guard let colon = s.lastIndex(of: ":"),
              let port = Int(s[s.index(after: colon)...]) else { return nil }
        return (String(s[..<colon]), port)
    }

    private static func intValue(_ v: Any?) -> Int? {
        if let i = v as? Int { return i }
        if let s = v as? String { return Int(s) }
        if let n = v as? NSNumber { return n.intValue }
        return nil
    }

    /// Base64 (standard or URL-safe, with or without padding) → Data.
    private static func base64Pad(_ s: String) -> Data? {
        var str = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while str.count % 4 != 0 { str.append("=") }
        return Data(base64Encoded: str)
    }
}
