#!/bin/bash
# CMT ZIVPN PRO - ORIGINAL DESIGN VERSION

# 1. Install Dependencies
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl python3-pip wget >/dev/null

# 2. Setup Directories
mkdir -p /etc/zivpn

# 3. Create Web Script (ZiVPN Original Design)
cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, hmac, datetime
from flask import Flask, render_template_string, request, redirect, session

app = Flask(__name__)
app.secret_key = "CMT_SECRET"
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
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.9); --cyan: #00d4ff; --glow: #ff4500; --yellow: #ffaa00; --green: #2ecc71; --purple: #9b59b6; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; overflow-x: hidden; }
        
        /* ✅ Original Header Style (As in 13058.jpg) */
        .header { background: rgba(0,0,0,0.6); padding: 12px 15px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); }
        .header img { border-radius: 50%; width: 42px; height: 42px; border: 2px solid #fff; background: #fff; }
        .header b { font-size: 0.9em; letter-spacing: 1px; color: var(--cyan); }
        
        .container { padding: 15px; max-width: 500px; margin: auto; }
        .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 15px; }
        .grid-box { background: var(--card); border: 1.2px solid var(--cyan); border-radius: 12px; padding: 10px; text-align: center; box-shadow: 0 0 10px rgba(0, 212, 255, 0.15); }
        .grid-val { font-size: 0.95em; font-weight: bold; color: var(--cyan); }
        .grid-label { font-size: 0.6em; color: #888; text-transform: uppercase; margin-top: 4px; }

        /* ✅ Main Card Design (Long Single Card) */
        .main-card { background: var(--card); border: 1.5px solid var(--cyan); border-radius: 20px; padding: 20px; box-shadow: 0 0 20px rgba(0, 212, 255, 0.2); }
        .sub-title { font-size: 0.95em; font-weight: bold; color: var(--cyan); margin: 20px 0 15px; border-bottom: 1px solid #1e293b; padding-bottom: 10px; }
        
        input, select { width: 100%; padding: 12px; margin: 6px 0; background: rgba(0,0,0,0.7); border: 1px solid #1e293b; color: #fff; border-radius: 10px; box-sizing: border-box; outline: none; }
        .btn { background: linear-gradient(45deg, #00c6ff, #0072ff); color: #fff; border: none; padding: 14px; border-radius: 10px; font-weight: bold; width: 100%; cursor: pointer; }
        
        /* Interactive Calendar */
        .date-input::-webkit-calendar-picker-indicator { filter: invert(1); cursor: pointer; transform: scale(1.3); }

        /* Social Icons */
        .social-row { display: flex; gap: 10px; }
        .social-btn { width: 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 1.1em; color: #fff; text-decoration: none; border: 1px solid rgba(255,255,255,0.2); }
    </style>
</head>
<body>
    <div class="header">
        <div style="display:flex;align-items:center;gap:10px;"><img src="https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png"><b>CMT ZIVPN PRO</b></div>
        <div class="social-row">
            <a href="https://t.me/CMT_1411" class="social-btn" style="background:#0088cc;"><i class="fab fa-telegram-plane"></i></a>
            <a href="https://m.me/ChitMinThu1239" class="social-btn" style="background:#0072ff;"><i class="fab fa-facebook-messenger"></i></a>
        </div>
    </div>

    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><div class="grid-val">0.3%</div><div class="grid-label">CPU</div></div>
            <div class="grid-box"><div class="grid-val">12%</div><div class="grid-label">RAM</div></div>
            <div class="grid-box"><div class="grid-val">9.0%</div><div class="grid-label">DISK</div></div>
            <div class="grid-box"><div class="grid-val">{{ users|length }}</div><div class="grid-label">USERS</div></div>
            <div class="grid-box"><div class="grid-val">0</div><div class="grid-label">ONLINE</div></div>
            <div class="grid-box"><div class="grid-val">12%</div><div class="grid-label">LOAD</div></div>
        </div>

        <div class="main-card">
            <div class="sub-title"><i class="fas fa-calendar-alt"></i> REMIT & CALENDAR</div>
            <div style="text-align:center; margin-bottom:15px;">
                <label style="font-size:0.75em; color:#888;">📅 DATE</label>
                <input type="date" id="cDate" class="date-input" onclick="this.showPicker()" style="text-align:center; border-color:var(--cyan);">
            </div>
            
            <div style="background:rgba(0,212,255,0.05); padding:10px; border-radius:10px; border:1px dashed var(--cyan); margin-bottom:15px; text-align:center;">
                <form method="POST" action="/set_rate">
                    <small>၁ သိန်း = </small>
                    <input type="number" name="rate" value="{{ rate }}" style="width:65px; display:inline; padding:5px; border-color:var(--cyan);">
                    <button style="background:var(--cyan); border:none; border-radius:5px; padding:5px 12px; font-weight:bold; color:black; cursor:pointer;">OK</button>
                </form>
            </div>

            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:12px;">
                <div><label style="font-size:0.7em; color:#aaa;">MMK</label><input type="number" id="mmk" oninput="m2t()" placeholder="0"></div>
                <div><label style="font-size:0.7em; color:#aaa;">THB</label><input type="number" id="thb" oninput="t2m()" placeholder="0"></div>
            </div>

            <div class="sub-title"><i class="fas fa-user-plus"></i> CREATE ACCOUNT</div>
            <form method="post" action="/add">
                <input name="user" placeholder="Username" required>
                <input name="password" placeholder="Password" required>
                <input name="days" placeholder="Days" required>
                <button class="btn" style="background:linear-gradient(45deg, #ff4500, #ffaa00);">CREATE USER</button>
            </form>
        </div>
    </div>

    <script>
        document.getElementById('cDate').valueAsDate = new Date();
        let rate = {{ rate }};
        function m2t() { let m = document.getElementById('mmk').value; if(m) document.getElementById('thb').value = Math.round((m/100000)*rate); }
        function t2m() { let t = document.getElementById('thb').value; if(t) document.getElementById('mmk').value = Math.round((t/rate)*100000); }
    </script>
</body>
</html>"""

@app.route("/")
def index():
    users = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: users = json.load(f)
    return render_template_string(HTML, uptime=get_uptime(), rate=get_rate(), users=users)

@app.route("/set_rate", methods=["POST"])
def set_rate_route():
    with open(RATE_FILE, "w") as f: json.dump({"rate": int(request.form.get("rate"))}, f)
    return redirect("/")

@app.route("/add", methods=["POST"])
def add():
    return redirect("/")

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

# 4. Service Setup
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

systemctl daemon-reload && systemctl enable zivpn-web && systemctl restart zivpn-web
echo "✅ ORIGINAL DESIGN UPDATED: http://$(hostname -I | awk '{print $1}'):8080"
