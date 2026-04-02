#!/bin/bash
# CMT ZIVPN PRO - ULTIMATE AUTO-FIX

# 1. Install Dependencies
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl python3-pip wget >/dev/null

# 2. Setup Directories
mkdir -p /etc/zivpn

# 3. Download ZiVPN Core Engine (Fixed Link)
echo "Downloading ZiVPN Core Engine..."
wget -O /usr/bin/zivpn https://raw.githubusercontent.com/hninpo01/ZiVPN/main/zivpn
chmod +x /usr/bin/zivpn

# 4. Create Basic Config if not exists
if [ ! -f "/etc/zivpn/config.json" ]; then
cat > /etc/zivpn/config.json <<EOF
{
  "api": {
    "services": [
      {
        "type": "udp",
        "server": "$(hostname -I | awk '{print $1}')",
        "server_port": 53,
        "password": "455"
      }
    ]
  }
}
EOF
fi

# 5. Create Systemd Service
cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=ZIVPN Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 6. Restart All Services
systemctl daemon-reload
systemctl enable zivpn
systemctl restart zivpn
systemctl restart zivpn-web

echo "-------------------------------------------"
echo "✅ အားလုံး အဆင်ပြေသွားပါပြီ အစ်ကို!"
echo "Web Panel: http://$(hostname -I | awk '{print $1}'):8080"
echo "VPN Core Status: $(systemctl is-active zivpn)"
echo "-------------------------------------------"
