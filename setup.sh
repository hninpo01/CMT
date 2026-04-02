#!/bin/bash
# CMT ZIVPN PRO - ORIGINAL DESIGN (CALENDAR REMOVED)
set -euo pipefail

# 1. Install Dependencies
apt-get update -y && apt-get install -y curl ufw jq python3 python3-flask conntrack iptables openssl >/dev/null

# 2. Setup Directories
mkdir -p /etc/zivpn
ENVF="/etc/zivpn/web.env"

# Admin Credentials
echo "WEB_ADMIN_USER=admin" > "$ENVF"
echo "WEB_ADMIN_PASSWORD=admin" >> "$ENVF"
echo "WEB_SECRET=$(openssl rand -hex 16)" >> "$ENVF"

# 3. Create Web Script (Original Dashboard Style)
cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, hmac, datetime
from flask import Flask, render_template_string, request, redirect, session, url_for

app = Flask(__name__)
app.secret_key = os.environ.get("WEB_SECRET", "CMT_STABLE")
ADMIN_USER = os.environ.get("WEB_ADMIN_USER", "admin")
ADMIN_PASS = os.environ.get("WEB_ADMIN_PASSWORD", "admin")
OFFICIAL_LOGO = "https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png"

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
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.9); --cyan: #00d4ff; --glow: #ff4500; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 80px; overflow-x: hidden; }
        .header { background: rgba(0,0,0,0.6); padding: 12px 15px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); }
        .header img { border-radius: 50%; width: 42px; height: 42px; border: 2px solid #fff; background: #fff; }
        .container { padding: 15px; max-width: 500px; margin: auto; }
        .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 20px; }
        .grid-box { background: var(--card); border: 1.2px solid var(--cyan); border-radius: 12px; padding: 10px; text-align: center; }
        .grid-val { font-size: 0.9em; font-weight: bold; color: var(--cyan); }
        .grid-label { font-size: 0.6em; color: #888; text-transform: uppercase; margin-top: 4px; }
        .card { background: var(--card); padding: 20px; border-radius: 15px; border: 1.5px solid var(--glow); margin-bottom: 20px; }
        input { width: 100%; padding: 12px; margin: 8px 0; background: rgba(0,0,0,0.7); border: 1px solid #334155; color: #fff; border-radius: 10px; box-sizing: border-box; outline: none; }
        .btn { background: linear-gradient(45deg, #ff4500, #ffaa00); color: #fff; border: none; padding: 14px; border-radius: 10px; font-weight: bold; width: 100%; cursor: pointer; }
        .table-card { background: var(--card); border-radius: 15px; border: 1.5px solid var(--cyan); padding: 10px; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; min-width: 450px; }
        th { text-align: left; padding: 10px; color: var(--cyan); border-bottom: 1.5px solid #1e293b; font-size: 0.8em; }
        td { padding: 10px; border-bottom: 1px solid #1e293b; font-size: 0.9em; }
    </style>
</head>
<body>
{% if not session.get('auth') %}
    <div style="max-width: 300px; margin: 25vh auto; background: var(--card); padding: 30px; border-radius: 20px; text-align: center; border: 2px solid var(--glow);">
        <h2 style="color:var(--cyan)">CMT LOGIN</h2>
        <form method="post" action="/login_check"><input name="u" placeholder="Admin"><input name="p" type="password" placeholder="Pass"><button class="btn" style="margin-top:10px;">LOGIN</button></form>
    </div>
{% else %}
    <div class="header">
        <div style="display:flex;align-items:center;gap:10px;"><img src="{{ logo }}"><b>CMT ZIVPN PRO</b></div>
        <div style="display:flex;gap:12px; font-size:1.3em;">
            <a href="https://t.me/CMT_1411" style="color:#0088cc;"><i class="fab fa-telegram-plane"></i></a>
            <a href="https://m.me/ChitMinThu1239" style="color:#00c6ff;"><i class="fab fa-facebook-messenger"></i></a>
        </div>
    </div>
    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><div class="grid-val">0.3%</div><div class="grid-label">CPU</div></div>
            <div class="grid-box"><div class="grid-val">12%</div><div class="grid-label">RAM</div></div>
            <div class="grid-box"><div class="grid-val">9.0%</div><div class="grid-label">DISK</div></div>
            <div class="grid-box"><div class="grid-val">{{ users|length }}</div><div class="grid-label">USERS</div></div>
            <div class="grid-box"><div class="grid-val">0</div><div class="grid-label">ONLINE</div></div>
            <div class="grid-box"><div class="grid-val">{{ uptime }}</div><div class="grid-label">UPTIME</div></div>
        </div>
        <div class="card">
            <h4 style="margin:0 0 10px 0; color:var(--glow);">CREATE USER</h4>
            <form method="post" action="/add"><input name="user" placeholder="Name"><input name="pass" placeholder="Password"><input name="days" placeholder="Days"><button class="btn">CREATE</button></form>
        </div>
        <div class="table-card">
            <table>
                <thead><tr><th>USER</th><th>EXPIRY</th><th>STATUS</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr><td style="color:var(--cyan);">{{ u.user }}</td><td>{{ u.expires }}</td><td><i class="fas fa-circle" style="color:#ff4500;"></i></td></tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>
    <div style="position:fixed; bottom:0; width:100%; background:rgba(10,14,26,0.95); display:flex; justify-content:space-around; padding:15px 0; border-top:2px solid var(--cyan);">
        <a href="/" style="color:var(--cyan); font-size:1.8em;"><i class="fas fa-home"></i></a>
        <a href="/logout" style="color:#555; font-size:1.8em;"><i class="fas fa-power-off"></i></a>
    </div>
{% endif %}
</body></html>"""

@app.route("/")
def index():
    users = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: users = json.load(f)
    return render_template_string(HTML, logo=OFFICIAL_LOGO, uptime=get_uptime(), users=users)

@app.route("/login_check", methods=["POST"])
def login_check():
    if hmac.compare_digest(request.form.get("u"), ADMIN_USER) and hmac.compare_digest(request.form.get("p"), ADMIN_PASS):
        session["auth"] = True
    return redirect("/")

@app.route("/logout")
def logout(): session.clear(); return redirect("/")

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

# 4. Service Restart
systemctl daemon-reload
systemctl restart zivpn-web 2>/dev/null || true
echo "✅ ORIGINAL UI RESTORED! http://$(hostname -I | awk '{print $1}'):8080"
