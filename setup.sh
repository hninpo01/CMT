#!/bin/bash
# CMT ZIVPN PRO - ULTIMATE STABLE FIX

# 1. Install Dependencies
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl python3-pip wget >/dev/null

# 2. Setup Directories
mkdir -p /etc/zivpn

# 3. Create Basic Config
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

# 4. Create web.py (Using a cleaner method to avoid syntax errors)
cat > /etc/zivpn/web.py <<'PY'
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

HTML = """<!doctype html>
<html lang="my">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>CMT ZIVPN PRO</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root { --bg: #050810; --neon: #00d4ff; --card: rgba(16, 22, 42, 0.95); }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 50px; }
        .header { background: linear-gradient(135deg, #00c6ff, #0072ff); padding: 20px; text-align: center; border-radius: 0 0 20px 20px; box-shadow: 0 5px 15px rgba(0,0,0,0.5); }
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
    <div class="header"><h2 style="margin:0;"><i class="fas fa-shield-alt"></i> CMT ZIVPN PRO</h2></div>
    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><small>CPU</small><br><b style="color:var(--neon);">0.3%</b></div>
            <div class="grid-box"><small>RAM</small><br><b style="color:var(--neon);">12%</b></div>
            <div class="grid-box"><small>UPTIME</small><br><b style="color:var(--neon);">{{ uptime }}</b></div>
        </div>
        <div class="main-card">
            <h3 style="color:var(--neon); text-align:center; margin-top:0;">REMIT & CALENDAR</h3>
            <label>📅 SELECT DATE</label>
            <input type="date" id="mDate" class="input-group" style="color:white; text-align:center; cursor:pointer;" onclick="this.showPicker()">
            <div style="background:rgba(0,212,255,0.05); padding:10px; border-radius:12px; border:1px dashed #334155; margin-bottom:15px; text-align:center;">
                <form method="POST" action="/set_rate">
                    <small>၁ သိန်းလျှင် = </small>
                    <input type="number" name="rate" value="{{ rate }}" style="width:60px; background:none; border:1px solid var(--neon); color:var(--neon); text-align:center;">
                    <button style="background:var(--neon); border:none; padding:3px 10px; border-radius:5px; font-weight:bold; cursor:pointer;">OK</button>
                </form>
            </div>
            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:12px;">
                <div class="input-group"><label style="font-size:0.7rem; color:#888;">MMK</label><input type="number" id="mmk" oninput="m2t()" placeholder="0"></div>
                <div class="input-group"><label style="font-size:0.7rem; color:#888;">THB</label><input type="number" id="thb" oninput="t2m()" placeholder="0"></div>
            </div>
            <div style="margin-top:20px; display:flex; justify-content:center; gap:30px; font-size:1.8rem;">
                <a href="https://t.me/CMT_1411" style="color:#0088cc;"><i class="fab fa-telegram"></i></a>
                <a href="https://m.me/ChitMinThu1239" style="color:#00c6ff;"><i class="fab fa-facebook-messenger"></i></a>
            </div>
        </div>
    </div>
    <script>
        document.getElementById('mDate').valueAsDate = new Date();
        let rate = {{ rate }};
        function m2t() { let m = document.getElementById('mmk').value; if(m) document.getElementById('thb').value = Math.round((m/100000)*rate); else document.getElementById('thb').value = ""; }
        function t2m() { let t = document.getElementById('thb').value; if(t) document.getElementById('mmk').value = Math.round((t/rate)*100000); else document.getElementById('mmk').value = ""; }
    </script>
</body>
</html>"""

@app.route("/")
def index(): return render_template_string(HTML, uptime=get_uptime(), rate=get_rate())

@app.route("/set_rate", methods=["POST"])
def set_rate_route():
    try:
        new_rate = int(request.form.get("rate"))
        with open(RATE_FILE, "w") as f: json.dump({"rate": new_rate}, f)
    except: pass
    return redirect("/")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
PY

# 5. Create Web Service Systemd
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

# 6. Restart All Services
systemctl daemon-reload
systemctl enable zivpn-web
systemctl restart zivpn-web

echo "✅ Setup Finished! http://$(hostname -I | awk '{print $1}'):8080"
