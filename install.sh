#!/bin/bash

set -e

# Update system and install dependencies
sudo apt-get update
sudo apt-get install -y jq openssl qrencode curl

# Get user config
curl -s https://raw.githubusercontent.com/YoungDeveloper2025/vless-tcp-http/master/default.json -o config.json

name=$(jq -r '.name' config.json)
email=$(jq -r '.email' config.json)
port=$(jq -r '.port' config.json)

# Fake HTTP host
fakeHost="www.divar.ir"

# Install Xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version v1.8.23

# Get base Xray config
json=$(curl -s https://raw.githubusercontent.com/YoungDeveloper2025/vless-tcp-http/master/config.json)

# Generate UUID
uuid=$(xray uuid)
serverIp=$(curl -s ipv4.wtfismyip.com/text)

# Build VLESS URL (TCP + HTTP)
url="vless://$uuid@$serverIp:$port?type=tcp&encryption=none&security=none&headerType=http&host=$fakeHost#$name"

# Build final Xray config
newJson=$(echo "$json" | jq \
  --arg uuid "$uuid" \
  --arg port "$port" \
  --arg email "$email" \
  --arg host "$fakeHost" \
  '
  .inbounds[0].port = ($port | tonumber) |
  .inbounds[0].settings.clients[0].email = $email |
  .inbounds[0].settings.clients[0].id = $uuid |
  .inbounds[0].streamSettings = {
    "network": "tcp",
    "security": "none",
    "tcpSettings": {
      "header": {
        "type": "http",
        "request": {
          "version": "1.1",
          "method": "GET",
          "path": ["/"],
          "headers": {
            "Host": [$host],
            "User-Agent": [
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
            ],
            "Accept-Encoding": ["gzip, deflate"],
            "Connection": ["keep-alive"],
            "Pragma": "no-cache"
          }
        }
      }
    }
  }
  ')

# Write config and restart Xray
echo "$newJson" | sudo tee /usr/local/etc/xray/config.json > /dev/null
sudo systemctl restart xray

# Output results
echo ""
echo "=============================="
echo " VLESS TCP HTTP CONFIG "
echo "=============================="
echo ""
echo "$url"
echo ""

qrencode -s 120 -t ANSIUTF8 "$url"
echo ""
qrencode -s 50 -o qr.png "$url"

echo ""
echo "Done ✅"
