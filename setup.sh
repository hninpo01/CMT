#!/bin/bash
# CMT ZIVPN PRO - ULTIMATE AUTO-FIX

# 1. Install Dependencies
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl python3-pip wget >/dev/null

# 2. Setup Directories
mkdir -p /etc/zivpn

# 3. Download ZiVPN Core Engine
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

# 5. Create Systemd Service for Core
cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=ZiVPN Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# ---------------------------------------------------------
# ✅ Section: Create web.py (With Remit + Calendar + Auto Rate)
# ---------------------------------------------------------
cat > /etc/zivpn/web.py <<PY
import os, json, subprocess, hmac, datetime
from flask import Flask, render_template_string, request, redirect, session

app = Flask(__name__)
app.secret_key = "CMT_SECRET_KEY"
ADMIN_USER = "admin"
ADMIN_PASS = "admin"

RATE_FILE = "/etc/zivpn/today_rate.json"
if not os.path.exists(RATE_FILE):
    with open(RATE_FILE, "w") as f: json.dump({"rate": 810}, f)

def get_rate():
    try:
        with open(RATE_FILE, "r") as f: return json.load(f)["rate"]
    except: return 810

def get_uptime():
    try:
        with open('/proc/uptime', 'r') as f:
            up_sec = float(f.readline().split()[0])
            return str(datetime.timedelta(seconds=int(up_sec)))
    except: return "0:00:00"

HTML = \"\"\"<!doctype html>
<html lang="my">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>CMT ZIVPN PRO</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root { --bg: #050810; --neon: #00d4ff; --card: rgba(16, 22, 42, 0.95); }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 50px; }
        .header { background: linear-gradient(135deg, #00c6ff, #0072ff); padding: 20px; text-align: center; border-radius: 0 0 20px 20px; }
        .container { padding: 15px; max-width: 500px; margin: auto; }
        .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 20px; }
        .grid-box { background: var(--card); border: 1.5px solid var(--neon); border-radius: 12px; padding: 10px; text-align: center; }
        .main-card { background: var(--card); border: 2px solid var(--neon); border-radius: 25px; padding: 25px; box-shadow: 0 0 20px rgba(0,212,255,0.3); }
        .input-group { background: rgba(0,0,0,0.5); border: 1px solid #1e293b; border-radius: 15px; padding: 12px; margin-bottom: 15px; }
        .input-group input { width: 100%; border: none; background: transparent; color: white; font-size: 1rem; outline: none; }
        .btn { background: linear-gradient(45deg, #00c6ff, #0072ff); color: white; border: none; padding: 15px; border-radius: 12px; font-weight: bold; width: 100%; cursor: pointer; }
    </style>
</head>
<body>
    <div class="header"><h2>CMT ZIVPN PRO</h2></div>
    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><small>CPU</small><br><b>0.3%</b></div>
            <div class="grid-box"><small>RAM</small><br><b>12%</b></div>
            <div class="grid-box"><small>UPTIME</small><br><b>{{ uptime }}</b></div>
        </div>

        <div class="main-card">
            <h3 style="color:var(--neon); text-align:center;">REMIT & SETTINGS</h3>
            <label>📅 SELECT DATE</label>
            <input type="date" id="mDate" class="input-group" style="color:white; text-align:center;" onclick="this.showPicker()">
            
            <div style="text-align:center; margin: 15px 0;">
                <form method="POST" action="/set_rate">
                    <small>RATE: 1L = </small>
                    <input type="number" name="rate" value="{{ rate }}" style="width:60px; background:none; border:1px solid var(--neon); color:var(--neon); text-align:center;">
                    <button style="background:var(--neon); border:none; padding:3px 10px; border-radius:5px;">OK</button>
                </form>
            </div>

            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px;">
                <div class="input-group"><label>MMK</label><input type="number" id="mmk" oninput="m2t()"></div>
                <div class="input-group"><label>THB</label><input type="number" id="thb" oninput="t2m()"></div>
            </div>
            
            <div style="margin-top:20px; display:flex; justify-content:center; gap:20px; font-size:1.5rem;">
                <a href="https://t.me/CMT_1411" style="color:#0088cc;"><i class="fab fa-telegram"></i></a>
                <a href="https://m.me/ChitMinThu1239" style="color:#00c6ff;"><i class="fab fa-facebook-messenger"></i></a>
            </div>
        </div>
    </div>
    <script>
        document.getElementById('mDate').valueAsDate = new Date();
        let rate = {{ rate }};
        function m2t() { let m = document.getElementById('mmk').value; if(m) document.getElementById('thb').value = Math.round((m/100000)*rate); }
        function t2m() { let t = document.getElementById('thb').value; if(t) document.getElementById('mmk').value = Math.round((t/rate)*100000); }
    </script>
</body>
</html>\"\"\"

@app.route("/")
def index(): return render_template_string(HTML, uptime=get_uptime(), rate=get_rate())

@app.route("/set_rate", methods=["POST"])
def set_rate_route():
    with open(RATE_FILE, "w") as f: json.dump({"rate": int(request.form.get("rate"))}, f)
    return redirect("/")

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

# 6. Create Web Service Systemd
cat > /etc/systemd/system/zivpn-web.service <<EOF
[Unit]
Description=ZiVPN Web Panel
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /etc/zivpn/web.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 7. Restart All Services
systemctl daemon-reload
systemctl enable zivpn zivpn-web
systemctl restart zivpn zivpn-web

echo "-------------------------------------------------------"
echo "✅ CMT ZIVPN PRO Setup Completed!"
echo "Web Panel: http://$(hostname -I | awk '{print $1}'):8080"
echo "-------------------------------------------------------"
