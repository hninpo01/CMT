#!/bin/bash
# CMT ZIVPN PRO - ORIGINAL STABLE UI
set -euo pipefail

# 1. Install Dependencies
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl >/dev/null

# 2. Setup Directories
mkdir -p /etc/zivpn
ENVF="/etc/zivpn/web.env"

# Admin Credentials
echo "WEB_ADMIN_USER=admin" > "$ENVF"
echo "WEB_ADMIN_PASSWORD=admin" >> "$ENVF"
echo "WEB_SECRET=$(openssl rand -hex 16)" >> "$ENVF"

# 3. Networking Setup
sysctl -w net.ipv4.ip_forward=1 >/dev/null
iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || true
iptables -t nat -A POSTROUTING -j MASQUERADE 2>/dev/null || true

# 4. Create web.py (Original ZiVPN Pro Design)
cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, hmac, datetime
from flask import Flask, render_template_string, request, redirect, session, url_for

app = Flask(__name__)
app.secret_key = os.environ.get("WEB_SECRET", "CMT_SECRET_KEY")
ADMIN_USER = os.environ.get("WEB_ADMIN_USER", "admin")
ADMIN_PASS = os.environ.get("WEB_ADMIN_PASSWORD", "admin")
OFFICIAL_LOGO = "https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png"

def get_usage(port):
    if not port: return "0.0 MB"
    try:
        out = subprocess.run(f"iptables -L ZIVPN_TRAFFIC -n -v -x | grep 'dpt:{port}'", shell=True, capture_output=True, text=True).stdout
        bytes_total = sum(int(line.split()[1]) for line in out.strip().split('\n') if line)
        if bytes_total > 1024**3: return f"{round(bytes_total/1024**3, 2)} GB"
        return f"{round(bytes_total/1024**2, 2)} MB"
    except: return "0.0 MB"

def get_uptime():
    try:
        with open('/proc/uptime', 'r') as f:
            up_sec = float(f.readline().split()[0])
            hrs, rem = divmod(int(up_sec), 3600)
            mins, _ = divmod(rem, 60)
            return f"{hrs}h {mins}m"
    except: return "0h 0m"

HTML = """<!doctype html>
<html lang="my" translate="no">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>CMT ZIVPN PRO</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.9); --cyan: #00d4ff; --glow: #ff4500; --yellow: #ffaa00; --green: #2ecc71; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 80px; overflow-x: hidden; }
        
        .header { background: rgba(0,0,0,0.6); padding: 12px 15px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); }
        .header img { border-radius: 50%; width: 45px; height: 45px; border: 2px solid #fff; background: #fff; }
        
        .container { padding: 15px; max-width: 500px; margin: auto; }
        .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 20px; }
        .grid-box { background: var(--card); border: 1.5px solid var(--cyan); border-radius: 12px; padding: 12px; text-align: center; }
        .grid-val { font-size: 1.1em; font-weight: bold; color: var(--cyan); }
        .grid-label { font-size: 0.6em; color: #aaa; text-transform: uppercase; margin-top: 5px; }

        .card { background: var(--card); padding: 25px; border-radius: 20px; border: 2.5px solid var(--glow); margin-bottom: 20px; box-shadow: 0 0 25px rgba(255, 69, 0, 0.4); }
        input { width: 100%; padding: 14px; margin: 8px 0; background: rgba(0,0,0,0.7); border: 1.5px solid #334155; color: #fff; border-radius: 12px; box-sizing: border-box; outline: none; }
        .btn { background: linear-gradient(45deg, #ff4500, #ffaa00); color: #fff; border: none; padding: 15px; border-radius: 12px; font-weight: bold; width: 100%; cursor: pointer; }
        
        .table-card { background: var(--card); border-radius: 15px; border: 2.5px solid var(--cyan); padding: 12px; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; min-width: 450px; }
        th { text-align: left; padding: 12px; color: var(--cyan); border-bottom: 2px solid #1e293b; font-size: 0.85em; }
        td { padding: 12px; border-bottom: 1px solid #1e293b; font-size: 0.9em; }
        .bottom-nav { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(10, 14, 26, 0.95); display: flex; justify-content: space-around; padding: 15px 0; border-top: 2px solid var(--cyan); }
    </style>
</head>
<body>
{% if not session.get('auth') %}
    <div style="max-width: 320px; margin: 20vh auto; background: var(--card); padding: 35px; border-radius: 25px; text-align: center; border: 3px solid var(--glow);">
        <img src="{{ logo }}" width="80" style="background:#fff; border-radius:50%; margin-bottom:20px;">
        <h2 style="color:var(--cyan); margin-bottom:20px;">CMT LOGIN</h2>
        <form method="post" action="/login_check"><input name="u" placeholder="Admin Name"><input name="p" type="password" placeholder="Pass"><button class="btn" style="margin-top:15px;">LOGIN</button></form>
    </div>
{% else %}
    <div class="header">
        <div style="display:flex;align-items:center;gap:12px;"><img src="{{ logo }}"><b>CMT ZIVPN PRO</b></div>
        <div style="display:flex; gap:15px;">
            <a href="https://t.me/CMT_1411" style="color:var(--cyan); font-size:1.5em;"><i class="fab fa-telegram-plane"></i></a>
            <a href="https://m.me/ChitMinThu1239" style="color:var(--cyan); font-size:1.5em;"><i class="fab fa-facebook-messenger"></i></a>
        </div>
    </div>
    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><div class="grid-val">0.3%</div><div class="grid-label">CPU</div></div>
            <div class="grid-box"><div class="grid-val">12%</div><div class="grid-label">RAM</div></div>
            <div class="grid-box"><div class="grid-val">9.0%</div><div class="grid-label">DISK</div></div>
            <div class="grid-box"><div class="grid-val">{{ users|length }}</div><div class="grid-label">အသုံးပြုသူ</div></div>
            <div class="grid-box"><div class="grid-val">0</div><div class="grid-label">အွန်လိုင်း</div></div>
            <div class="grid-box"><div class="grid-val">{{ uptime }}</div><div class="grid-label">UPTIME</div></div>
        </div>
        <div class="card">
            <form method="post" action="/add"><input name="user" placeholder="နာမည်"><input name="password" placeholder="စကားဝှက်"><input name="days" placeholder="ရက်ပေါင်း"><button class="btn">CREATE USER</button></form>
        </div>
        <div class="table-card">
            <table>
                <thead><tr><th>အမည်</th><th>ဒေတာ</th><th>သက်တမ်း</th><th>Status</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr><td style="color:var(--cyan);">{{ u.user }}</td><td style="color:var(--yellow);">{{ u.usage }}</td><td>{{ u.expires }}</td><td><i class="fas fa-circle" style="color:#ff4500;"></i></td></tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>
    <div class="bottom-nav"><a href="/" style="color:var(--cyan); font-size:1.8em;"><i class="fas fa-home"></i></a><a href="/logout" style="color:#555; font-size:1.8em;"><i class="fas fa-power-off"></i></a></div>
{% endif %}
</body></html>"""

@app.route("/")
def index():
    if not session.get("auth"): return render_template_string(HTML, logo=OFFICIAL_LOGO)
    users = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json", "r", encoding="utf-8") as f: users = json.load(f)
    for u in users: u["usage"] = get_usage(u.get("port"))
    return render_template_string(HTML, logo=OFFICIAL_LOGO, users=users, uptime=get_uptime())

@app.route("/login_check", methods=["POST"])
def login_check():
    if hmac.compare_digest(request.form.get("u"), ADMIN_USER) and hmac.compare_digest(request.form.get("p"), ADMIN_PASS):
        session["auth"] = True
    return redirect("/")

@app.route("/add", methods=["POST"])
def add():
    if not session.get("auth"): return redirect("/")
    u, p, d = request.form.get("user"), request.form.get("password"), request.form.get("days")
    exp = (datetime.datetime.now() + datetime.timedelta(days=int(d))).strftime("%Y-%m-%d")
    users = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json", "r", encoding="utf-8") as f: users = json.load(f)
    port = str(max([int(x.get("port", 6000)) for x in users] + [6000]) + 1)
    users.insert(0, {"user":u, "password":p, "expires":exp, "port":port})
    with open("/etc/zivpn/users.json", "w", encoding="utf-8") as f: json.dump(users, f, indent=2, ensure_ascii=False)
    return redirect("/")

@app.route("/logout")
def logout(): session.clear(); return redirect("/")

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

# 5. Service Restart
systemctl daemon-reload && systemctl restart zivpn-web
echo "✅ SUCCESS! Original UI Restored: http://$(hostname -I | awk '{print $1}'):8080"
