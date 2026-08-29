#!/bin/bash
set -e
# Update system and install dependencies
sudo apt-get update
sudo apt-get install -y jq openssl qrencode curl
# Get user config
curl -fsSL https://raw.githubusercontent.com/YoungDeveloper2025/vless-tcp-http/main/default.json -o config.json
name=$(jq -r '.name' config.json)
email=$(jq -r '.email' config.json)
port=$(jq -r '.port' config.json)
# Validate required values
if [ -z "$name" ] || [ "$name" = "null" ]; then
echo "Error: name is missing in default.json"
exit 1
fi
if [ -z "$email" ] || [ "$email" = "null" ]; then
echo "Error: email is missing in default.json"
exit 1
fi
if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
echo "Error: invalid port in default.json"
exit 1
fi
# Fake HTTP host
fakeHost="amp-api-edge.apps.apple.com"
# Install latest stable Xray
bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
# Get base Xray config
json=$(curl -fsSL https://raw.githubusercontent.com/YoungDeveloper2025/vless-tcp-http/main/config.json)
# Generate UUID
uuid=$(xray uuid)
# Get server public IPv4
serverIp=$(curl -4fsSL https://ipv4.wtfismyip.com/text | tr -d '[:space:]')
if [ -z "$serverIp" ]; then
echo "Error: unable to detect server IPv4"
exit 1
fi
# Build VLESS URL
url="vless://$uuid@$serverIp:$port?type=tcp&encryption=none&security=none&headerType=http&host=$fakeHost#$name"
# Build final Xray config
newJson=$(echo "$json" | jq \
--arg uuid "$uuid" \
--argjson port "$port" \
--arg email "$email" \
--arg host "$fakeHost" \
'
.inbounds[0].port = $port |
.inbounds[0].settings.clients[0].email = $email |
.inbounds[0].settings.clients[0].id = $uuid |
.inbounds[0].streamSettings = {
"method": "raw",
"security": "none",
"rawSettings": {
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
# Validate generated JSON
echo "$newJson" | jq empty
# Write Xray config
echo "$newJson" | sudo tee /usr/local/etc/xray/config.json > /dev/null
# Validate Xray config before restart
if ! sudo xray run -test -config /usr/local/etc/xray/config.json; then
echo "Error: Xray configuration is invalid"
exit 1
fi
# Enable and restart Xray
sudo systemctl enable xray
sudo systemctl restart xray
# Check service
if ! sudo systemctl is-active --quiet xray; then
echo "Error: Xray failed to start"
sudo systemctl status xray --no-pager
exit 1
fi
# Output results
echo ""
echo "=============================="
echo " VLESS RAW HTTP CONFIG "
echo "=============================="
echo ""
echo "Xray version:"
xray version | head -n 1
echo ""
echo "$url"
echo ""
qrencode -t ANSIUTF8 "$url"
echo ""
qrencode -s 10 -o qr.png "$url"
echo ""
echo "QR saved to: $(pwd)/qr.png"
echo ""
echo "Done ✅"
