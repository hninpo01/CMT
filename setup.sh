#!/bin/bash
# CMT ZIVPN PRO - ORIGINAL GRID LAYOUT FIXED
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

# 3. Create web.py (Original Grid UI)
cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, hmac, datetime
from flask import Flask, render_template_string, request, redirect, session, url_for

app = Flask(__name__)
app.secret_key = os.environ.get("WEB_SECRET", "CMT_SECRET")
ADMIN_USER = os.environ.get("WEB_ADMIN_USER", "admin")
ADMIN_PASS = os.environ.get("WEB_ADMIN_PASSWORD", "admin")

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
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.9); --cyan: #00d4ff; --glow: #ff4500; --yellow: #ffaa00; --purple: #9b59b6; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; }
        
        .header { background: rgba(0,0,0,0.6); padding: 12px; text-align: center; border-bottom: 2px solid var(--cyan); display: flex; justify-content: space-between; align-items: center; }
        .header img { border-radius: 50%; width: 40px; height: 40px; background: #fff; }

        .container { padding: 12px; max-width: 500px; margin: auto; }
        
        /* ✅ 13058 Grid Style (6 Boxes) */
        .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-bottom: 15px; }
        .grid-box { background: var(--card); border: 1.5px solid var(--cyan); border-radius: 10px; padding: 10px; text-align: center; }
        .grid-val { font-size: 0.9em; font-weight: bold; color: var(--cyan); }
        .grid-label { font-size: 0.55em; color: #888; text-transform: uppercase; margin-top: 3px; }

        /* ✅ Second Row Grid (3 Boxes) */
        .action-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-bottom: 15px; }
        .action-box { background: var(--card); border: 1.5px solid var(--purple); border-radius: 10px; padding: 15px; text-align: center; cursor: pointer; }
        .action-box i { font-size: 1.2em; color: var(--yellow); display: block; margin-bottom: 5px; }
        .action-label { font-size: 0.65em; color: #fff; }

        .search-bar { background: #000; border: 1px solid #333; padding: 10px; border-radius: 8px; width: 100%; color: #fff; margin-bottom: 15px; box-sizing: border-box; }

        .table-card { background: var(--card); border-radius: 12px; border: 1.5px solid var(--cyan); padding: 5px; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; min-width: 400px; }
        th { text-align: left; padding: 8px; color: var(--cyan); border-bottom: 1px solid #1e293b; font-size: 0.7em; }
        td { padding: 10px 8px; border-bottom: 1px solid #1e293b; font-size: 0.8em; }
        
        .bottom-nav { position: fixed; bottom: 0; width: 100%; background: #0a0e1a; display: flex; justify-content: space-around; padding: 12px 0; border-top: 1px solid var(--cyan); }
    </style>
</head>
<body>
{% if not session.get('auth') %}
    <div style="max-width: 300px; margin: 25vh auto; background: var(--card); padding: 30px; border-radius: 20px; border: 2px solid var(--glow); text-align: center;">
        <h3 style="color:var(--cyan)">CMT LOGIN</h3>
        <form method="post" action="/login_check"><input name="u" placeholder="Admin" style="width:90%; padding:10px; margin-bottom:10px;"><input name="p" type="password" placeholder="Pass" style="width:90%; padding:10px;"><button style="margin-top:15px; width:100%; padding:10px; background:var(--glow); border:none; color:#fff; border-radius:8px;">LOGIN</button></form>
    </div>
{% else %}
    <div class="header">
        <img src="https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png">
        <b style="font-size:0.8em; color:var(--cyan);">CMT ZIVPN PRO PANEL</b>
        <i class="fas fa-cog" style="color:var(--cyan);"></i>
    </div>

    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><div class="grid-label">CPU</div><div class="grid-val">0.3%</div></div>
            <div class="grid-box"><div class="grid-label">RAM</div><div class="grid-val">12.0%</div></div>
            <div class="grid-box"><div class="grid-label">DISK</div><div class="grid-val">9.0%</div></div>
            <div class="grid-box" style="border-color:var(--purple);"><div class="grid-label">အသုံးပြုသူ</div><div class="grid-val">4</div></div>
            <div class="grid-box" style="border-color:var(--green);"><div class="grid-label">အွန်လိုင်း</div><div class="grid-val">0</div></div>
            <div class="grid-box" style="border-color:var(--yellow);"><div class="grid-label">ဝန်ဆောင်မှု</div><div class="grid-val">12%</div></div>
        </div>

        <div class="action-grid">
            <div class="action-box"><i class="fas fa-user-plus"></i><div class="action-label">အကောင့်သစ်</div></div>
            <div class="action-box"><i class="fas fa-headset"></i><div class="action-label">ဆက်သွယ်ရန်</div></div>
            <div class="action-box"><i class="fas fa-tools"></i><div class="action-label">ကိတ်တင်များ</div></div>
        </div>

        <input type="text" class="search-bar" placeholder="ဝယ်သူအမည်ဖြင့် ရှာဖွေရန်...">

        <div class="table-card">
            <table>
                <thead><tr><th>အမည်</th><th>ကောက်ပက်</th><th>သက်တမ်း</th><th>Status</th><th>Act</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan);">{{ u.user }}</td>
                        <td>{{ u.port }}</td>
                        <td style="color:#ff69b4;">{{ u.expires }}</td>
                        <td style="color:var(--glow);">Offline</td>
                        <td><i class="fas fa-edit" style="color:var(--yellow);"></i> <i class="fas fa-trash" style="color:var(--glow);"></i></td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>

    <div class="bottom-nav">
        <a href="/" style="color:var(--cyan); font-size:1.5em;"><i class="fas fa-home"></i></a>
        <a href="/logout" style="color:#555; font-size:1.5em;"><i class="fas fa-power-off"></i></a>
    </div>
{% endif %}
</body></html>"""

@app.route("/")
def index():
    users = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: users = json.load(f)
    return render_template_string(HTML, users=users)

@app.route("/login_check", methods=["POST"])
def login_check():
    if hmac.compare_digest(request.form.get("u"), ADMIN_USER) and hmac.compare_digest(request.form.get("p"), ADMIN_PASS):
        session["auth"] = True
    return redirect("/")

@app.route("/logout")
def logout(): session.clear(); return redirect("/")

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

systemctl daemon-reload && systemctl restart zivpn-web
echo "✅ ORIGINAL GRID LAYOUT RESTORED! http://$(hostname -I | awk '{print $1}'):8080"
