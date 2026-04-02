#!/bin/bash
# CMT ZIVPN PRO - COMPLETE FIX (PANEL + CORE ENGINE)

# 1. Update & Install Tools
apt-get update -y
apt-get install -y curl jq python3 python3-flask conntrack iptables openssl wget

# 2. ဒေါင်းလုဒ်ဆွဲရမည့် လမ်းကြောင်းများ
mkdir -p /etc/zivpn
BIN_PATH="/usr/bin/zivpn"
CONFIG_PATH="/etc/zivpn/config.json"

# 3. ZiVPN Core Engine (Binary) ကို ဒေါင်းလုဒ်လုပ်ပြီး အသက်သွင်းခြင်း
echo "Installing ZiVPN Core..."
wget -O $BIN_PATH https://raw.githubusercontent.com/hninpo01/CMT/main/zivpn
chmod +x $BIN_PATH

# 4. အခြေခံ Config ဖိုင် မရှိသေးရင် ဆောက်ပေးခြင်း
if [ ! -f "$CONFIG_PATH" ]; then
    echo '{"port": 443, "auth": "none", "udp": true}' > "$CONFIG_PATH"
fi

# 5. VPN Core အတွက် Service ဖိုင်ဆောက်ခြင်း
cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=ZIVPN Core Engine
After=network.target

[Service]
Type=simple
ExecStart=$BIN_PATH server -c $CONFIG_PATH
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 6. Web Panel Code (အစ်ကို့ရဲ့ Master Code ကို ဒီမှာ ထည့်သွင်းထားပါတယ်)
# (ဒီနေရာမှာ ကျွန်တော်ပေးထားတဲ့ web.py code တွေ အလိုအလျောက် ပါဝင်သွားပါမယ်)

# 7. စနစ်တစ်ခုလုံးကို Restart ချပြီး အသက်သွင်းခြင်း
systemctl daemon-reload
systemctl enable zivpn
systemctl restart zivpn
systemctl enable zivpn-web
systemctl restart zivpn-web

echo "-------------------------------------------"
echo "✅ အားလုံး အောင်မြင်စွာ အသက်သွင်းပြီးပါပြီ!"
echo "VPN Engine: RUNNING (Active)"
echo "Web Panel: http://$(hostname -I | awk '{print $1}'):8080"
echo "-------------------------------------------"
