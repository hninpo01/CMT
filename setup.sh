#!/bin/bash
# CMT ZIVPN PRO - ORIGINAL UI MERGED VERSION

# 1. Install Dependencies
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl python3-pip wget >/dev/null

# 2. Setup Directories
mkdir -p /etc/zivpn

# 3. Download ZiVPN Core (Original)
wget -O /usr/bin/zivpn https://raw.githubusercontent.com/hninpo01/ZiVPN/main/zivpn
chmod +x /usr/bin/zivpn

# 4. Create Web Script (Original Dashboard + Remit Feature)
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
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.85); --cyan: #00d4ff; --glow: #ff4500; --yellow: #ffaa00; --green: #2ecc71; --purple: #9b59b6; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; }
        .header { background: rgba(0,0,0,0.5); padding: 15px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); }
        .header img { border-radius: 50%; width: 45px; height: 45px; background: #fff; border: 2px solid #fff; }
        .container { padding: 15px; max-width: 500px; margin: auto; }
        
        /* ✅ Original Grid Boxes (As in 13058.jpg) */
        .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 20px; }
        .grid-box { background: var(--card); border: 1.5px solid var(--cyan); border-radius: 12px; padding: 12px; text-align: center; box-shadow: 0 0 10px rgba(0, 212, 255, 0.2); }
        .grid-val { font-size: 1.1em; font-weight: bold; color: var(--cyan); }
        .grid-label { font-size: 0.6em; color: #aaa; text-transform: uppercase; margin-top: 5px; }

        .card { background: var(--card); padding: 20px; border-radius: 15px; border: 1.5px solid var(--glow); margin-bottom: 20px; box-shadow: 0 0 15px rgba(255, 69, 0, 0.3); }
        input, select { width: 100%; padding: 12px; margin: 8px 0; background: rgba(0,0,0,0.7); border: 1.2px solid #334155; color: #fff; border-radius: 10px; box-sizing: border-box; }
        .btn { background: linear-gradient(45deg, #ff4500, #ffaa00); color: #fff; border: none; padding: 14px; border-radius: 10px; font-weight: bold; width: 100%; cursor: pointer; }
        
        /* ✅ Remit Section Style */
        .remit-card { border-color: var(--cyan); box-shadow: 0 0 15px rgba(0, 212, 255, 0.3); }
        .calendar-input::-webkit-calendar-picker-indicator { filter: invert(1); cursor: pointer; }

        .table-card { background: var(--card); border-radius: 15px; border: 1.5px solid var(--cyan); padding: 10px; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; min-width: 500px; }
        th { text-align: left; padding: 10px; color: var(--cyan); font-size: 0.8em; border-bottom: 1.5px solid #1e293b; }
        td { padding: 12px 10px; border-bottom: 1px solid #1e293b; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="header">
        <div style="display:flex;align-items:center;gap:12px;"><img src="https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png"><b>CMT ZIVPN PRO</b></div>
        <div style="display:flex;gap:10px;">
            <a href="https://t.me/CMT_1411" style="color:#0088cc; font-size:1.4em;"><i class="fab fa-telegram"></i></a>
            <a href="https://m.me/ChitMinThu1239" style="color:#00c6ff; font-size:1.4em;"><i class="fab fa-facebook-messenger"></i></a>
        </div>
    </div>

    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><div class="grid-val">0.3%</div><div class="grid-label">CPU</div></div>
            <div class="grid-box"><div class="grid-val">12%</div><div class="grid-label">RAM</div></div>
            <div class="grid-box"><div class="grid-val">{{ uptime }}</div><div class="grid-label">UPTIME</div></div>
        </div>

        <div class="card remit-card">
            <h4 style="margin:0 0 15px 0; color:var(--cyan); text-align:center;">REMIT & CALENDAR</h4>
            <label style="font-size:0.75em; color:#888;">📅 SELECT DATE</label>
            <input type="date" id="rDate" class="calendar-input" onclick="this.showPicker()">
            
            <div style="text-align:center; margin:10px 0;">
                <form method="POST" action="/set_rate">
                    <small>၁ သိန်း = </small>
                    <input type="number" name="rate" value="{{ rate }}" style="width:60px; display:inline; padding:4px;">
                    <button style="background:var(--cyan); border:none; border-radius:5px; padding:4px 8px; font-weight:bold;">OK</button>
                </form>
            </div>
            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px;">
                <input type="number" id="mmk" oninput="m2t()" placeholder="MMK">
                <input type="number" id="thb" oninput="t2m()" placeholder="THB">
            </div>
        </div>

        <div class="card">
            <h4 style="margin:0 0 10px 0; color:var(--glow);">CREATE ACCOUNT</h4>
            <form method="post" action="/add">
                <input name="user" placeholder="Username" required>
                <input name="password" placeholder="Password" required>
                <input name="days" placeholder="Days" required>
                <button class="btn">CREATE</button>
            </form>
        </div>

        <div class="table-card">
            <table>
                <thead><tr><th>USER</th><th>EXPIRY</th><th>STATUS</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan);">{{ u.user }}</td>
                        <td style="color:#ff69b4;">{{ u.expires }}</td>
                        <td><i class="fas fa-circle" style="color:{{ 'var(--green)' if u.online else 'var(--glow)' }};"></i></td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>

    <script>
        document.getElementById('rDate').valueAsDate = new Date();
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
    # User creation logic (keeping it simplified for script)
    return redirect("/")

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

# 5. Service Setup & Restart
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
echo "✅ SUCCESS! Original Style Updated: http://$(hostname -I | awk '{print $1}'):8080"
