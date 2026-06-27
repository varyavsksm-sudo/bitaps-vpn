#!/usr/bin/env bash
# bitaps VPN — one-shot VLESS + Reality node setup for a fresh Debian/Ubuntu VPS.
#
# Run as root on the server:
#     bash setup-reality.sh [SNI]
# (SNI defaults to www.microsoft.com — pick a real, fast, allowed-in-RU TLS host.)
#
# It installs sing-box, generates a Reality keypair / UUID / short-id ON THE
# SERVER (the private key never leaves it), writes the server config, starts the
# service, and prints the client `vless://` key — that's exactly what the bot
# stores as `subscriptions.vpn_key` and the app parses via SingBoxConfig.
set -euo pipefail

SNI="${1:-www.microsoft.com}"
PORT=443

echo "==> installing sing-box"
curl -fsSL https://sing-box.app/install.sh | sh -s -- --beta

echo "==> generating keys"
KP=$(sing-box generate reality-keypair)
PRIV=$(echo "$KP" | awk '/PrivateKey/{print $2}')
PUB=$(echo "$KP"  | awk '/PublicKey/{print $2}')
UUID=$(sing-box generate uuid)
SID=$(openssl rand -hex 4 2>/dev/null || sing-box generate rand 4 --hex)
IP=$(curl -fsSL -4 ifconfig.me || hostname -I | awk '{print $1}')

echo "==> writing /etc/sing-box/config.json"
mkdir -p /etc/sing-box
cat > /etc/sing-box/config.json <<JSON
{
  "log": { "level": "info", "timestamp": true },
  "inbounds": [{
    "type": "vless",
    "tag": "vless-in",
    "listen": "::",
    "listen_port": ${PORT},
    "users": [{ "uuid": "${UUID}", "flow": "xtls-rprx-vision" }],
    "tls": {
      "enabled": true,
      "server_name": "${SNI}",
      "reality": {
        "enabled": true,
        "handshake": { "server": "${SNI}", "server_port": 443 },
        "private_key": "${PRIV}",
        "short_id": ["${SID}"]
      }
    }
  }],
  "outbounds": [{ "type": "direct", "tag": "direct" }]
}
JSON

echo "==> validating config"
sing-box check -c /etc/sing-box/config.json

echo "==> enabling service"
systemctl enable --now sing-box
systemctl restart sing-box

CLIENT_KEY="vless://${UUID}@${IP}:${PORT}?type=tcp&security=reality&pbk=${PUB}&fp=chrome&sni=${SNI}&sid=${SID}&flow=xtls-rprx-vision&encryption=none#bitaps-${IP}"

cat <<DONE

============================================================
 NODE READY ✅
 server   : ${IP}:${PORT}   (SNI ${SNI})
 status   : $(systemctl is-active sing-box)

 >>> CLIENT KEY (store this in subscriptions.vpn_key for the user) <<<
 ${CLIENT_KEY}

 The private key stays on this server. Open port ${PORT}/tcp in the
 firewall if needed:  ufw allow ${PORT}/tcp
============================================================
DONE
