#!/bin/bash
# CMT ZIVPN PRO - ORIGINAL UI + REMIT + CALENDAR
set -euo pipefail

# 1. Install Dependencies
apt-get update -y && apt-get install -y curl ufw jq python3 python3-flask conntrack iptables openssl >/dev/null

# 2. Setup Directories
mkdir -p /etc/zivpn
ENVF="/etc/zivpn/web.env"

# Admin Credentials (အရှေ့က Login ဝင်ဖို့ နာမည်နဲ့ စကားဝှက်)
echo "WEB_ADMIN_USER=admin" > "$ENVF"
echo "WEB_ADMIN_PASSWORD=admin" >> "$ENVF"
echo "WEB_SECRET=$(openssl rand -hex 16)" >> "$ENVF"

# 3. Create web.py (Original Design + New Features)
cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, hmac, datetime
from flask import Flask, render_template_string, request, redirect, session, url_for

app = Flask(__name__)
app.secret_key = os.environ.get("WEB_SECRET", "CMT_SECRET")
ADMIN_USER = os.environ.get("WEB_ADMIN_USER", "admin")
ADMIN_PASS = os.environ.get("WEB_ADMIN_PASSWORD", "admin")
OFFICIAL_LOGO = "https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png"

# ပေါက်ဈေး သိမ်းဆည်းရန်
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
            hrs, rem = divmod(int(up_sec), 3600)
            mins, _ = divmod(rem, 60)
            return f"{hrs}နာရီ {mins}မိနစ်"
    except: return "0နာရီ 0မိနစ်"

HTML = """<!doctype html>
<html lang="my" translate="no">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>CMT ZIVPN PRO</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.9); --cyan: #00d4ff; --glow: #ff4500; --yellow: #ffaa00; --green: #2ecc71; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; overflow-x: hidden; }
        #bgCanvas { position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: -1; }
        
        .header { background: rgba(0,0,0,0.6); padding: 12px 15px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); }
        .header img { border-radius: 50%; width: 42px; height: 42px; border: 2px solid #fff; background: #fff; }
        
        .container { padding: 15px; max-width: 500px; margin: auto; }
        .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 20px; }
        .grid-box { background: var(--card); border: 1.5px solid var(--cyan); border-radius: 12px; padding: 10px; text-align: center; }
        .grid-val { font-size: 1em; font-weight: bold; color: var(--cyan); }
        .grid-label { font-size: 0.6em; color: #888; text-transform: uppercase; }

        .main-card { background: var(--card); border: 2px solid var(--cyan); border-radius: 20px; padding: 20px; box-shadow: 0 0 20px rgba(0, 212, 255, 0.2); }
        .sub-title { font-size: 0.95em; font-weight: bold; color: var(--cyan); margin: 15px 0 10px; display: flex; align-items: center; gap: 8px; }
        
        input, select { width: 100%; padding: 12px; margin: 6px 0; background: rgba(0,0,0,0.7); border: 1.2px solid #334155; color: #fff; border-radius: 10px; box-sizing: border-box; outline: none; }
        .btn { background: linear-gradient(45deg, #00c6ff, #0072ff); color: #fff; border: none; padding: 14px; border-radius: 10px; font-weight: bold; width: 100%; cursor: pointer; }
        .btn-create { background: linear-gradient(45deg, #ff4500, #ffaa00); }
        
        .calendar-input::-webkit-calendar-picker-indicator { filter: invert(1); cursor: pointer; transform: scale(1.3); }
        .table-card { background: var(--card); border-radius: 15px; border: 2px solid var(--cyan); padding: 10px; overflow-x: auto; margin-top: 20px; }
        table { width: 100%; border-collapse: collapse; min-width: 450px; }
        th { text-align: left; padding: 10px; color: var(--cyan); border-bottom: 1px solid #1e293b; font-size: 0.8em; }
        td { padding: 10px; border-bottom: 1px solid #1e293b; font-size: 0.9em; }
    </style>
</head>
<body>
<canvas id="bgCanvas"></canvas>

{% if not session.get('auth') %}
    <div style="max-width: 320px; margin: 20vh auto; background: var(--card); padding: 35px; border-radius: 25px; text-align: center; border: 2.5px solid var(--glow);">
        <img src="{{ logo }}" width="80" style="background:#fff; border-radius:50%; margin-bottom:20px; box-shadow: 0 0 15px #fff;">
        <h2 style="color:var(--cyan); margin-bottom:20px;">CMT ADMIN LOGIN</h2>
        <form method="post" action="/login_check">
            <input name="u" placeholder="Admin Name" required>
            <input name="p" type="password" placeholder="Pass" required>
            <button class="btn" style="margin-top:15px;">DASHBOARD LOGIN</button>
        </form>
    </div>
{% else %}
    <div class="header">
        <div style="display:flex;align-items:center;gap:10px;"><img src="{{ logo }}"><b>CMT ZIVPN PRO</b></div>
        <div style="display:flex;gap:15px; font-size:1.3em;">
            <a href="https://t.me/CMT_1411" style="color:#0088cc;"><i class="fab fa-telegram-plane"></i></a>
            <a href="https://m.me/ChitMinThu1239" style="color:#00c6ff;"><i class="fab fa-facebook-messenger"></i></a>
        </div>
    </div>

    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><div class="grid-val">0.3%</div><div class="grid-label">CPU</div></div>
            <div class="grid-box"><div class="grid-val">12%</div><div class="grid-label">RAM</div></div>
            <div class="grid-box"><div class="grid-val">{{ uptime }}</div><div class="grid-label">UPTIME</div></div>
        </div>

        <div class="main-card">
            <div class="sub-title"><i class="fas fa-calendar-check"></i> REMIT & CALENDAR</div>
            <input type="date" id="rDate" class="calendar-input" onclick="this.showPicker()" style="text-align:center;">
            
            <div style="text-align:center; background:rgba(0,212,255,0.05); padding:10px; border-radius:12px; margin:15px 0; border:1px dashed var(--cyan);">
                <form method="POST" action="/set_rate">
                    <small>၁ သိန်း = </small>
                    <input type="number" name="rate" value="{{ rate }}" style="width:60px; display:inline; padding:5px; border-color:var(--cyan);">
                    <button style="background:var(--cyan); border:none; border-radius:5px; padding:5px 10px; font-weight:bold; color:black; cursor:pointer;">OK</button>
                </form>
            </div>

            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px;">
                <div><label style="font-size:0.7em; color:#aaa;">MMK</label><input type="number" id="mmk" oninput="m2t()" placeholder="0"></div>
                <div><label style="font-size:0.7em; color:#aaa;">THB</label><input type="number" id="thb" oninput="t2m()" placeholder="0"></div>
            </div>

            <div class="divider" style="height:1px; background:#1e293b; margin:20px 0;"></div>

            <div class="sub-title"><i class="fas fa-user-plus"></i> CREATE ACCOUNT</div>
            <form method="post" action="/add">
                <input name="user" placeholder="Username" required>
                <input name="password" placeholder="Password" required>
                <input name="days" placeholder="30" required>
                <button class="btn btn-create">CREATE USER</button>
            </form>
        </div>

        <div class="table-card">
            <table>
                <thead><tr><th>USER</th><th>EXPIRY</th><th>STATUS</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan); font-weight:bold;">{{ u.user }}</td>
                        <td style="color:#ff69b4;">{{ u.expires }}</td>
                        <td><i class="fas fa-circle" style="color:{{ 'var(--green)' if u.online else 'var(--glow)' }};"></i></td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>

    <div style="position:fixed; bottom:0; left:0; width:100%; background:rgba(10,14,26,0.95); display:flex; justify-content:space-around; padding:15px 0; border-top:2px solid var(--cyan);">
        <a href="/" style="color:var(--cyan); font-size:1.8em;"><i class="fas fa-home"></i></a>
        <a href="/logout" style="color:#555; font-size:1.8em;"><i class="fas fa-power-off"></i></a>
    </div>
{% endif %}

<script>
    document.getElementById('rDate').valueAsDate = new Date();
    let rate = {{ rate }};
    function m2t() { let m = document.getElementById('mmk').value; if(m) document.getElementById('thb').value = Math.round((m/100000)*rate); }
    function t2m() { let t = document.getElementById('thb').value; if(t) document.getElementById('mmk').value = Math.round((t/rate)*100000); }

    // Background Animation
    const canvas = document.getElementById('bgCanvas'), ctx = canvas.getContext('2d');
    let pts = [];
    function init() { canvas.width = window.innerWidth; canvas.height = window.innerHeight; }
    window.onresize = init; init();
    class Pt { constructor() { this.x=Math.random()*canvas.width; this.y=Math.random()*canvas.height; this.vx=(Math.random()-0.5)*1; this.vy=(Math.random()-0.5)*1; } up() { this.x+=this.vx; this.y+=this.vy; if(this.x<0||this.x>canvas.width)this.vx*=-1; if(this.y<0||this.y>canvas.height)this.vy*=-1; } }
    for(let i=0;i<40;i++) pts.push(new Pt());
    function anim() { ctx.clearRect(0,0,canvas.width,canvas.height); pts.forEach((p,i)=>{ p.up(); for(let j=i+1;j<pts.length;j++){ let d = Math.hypot(p.x-pts[j].x, p.y-pts[j].y); if(d<100){ ctx.beginPath(); ctx.moveTo(p.x,p.y); ctx.lineTo(pts[j].x,pts[j].y); ctx.strokeStyle='rgba(0,212,255,'+(1-d/100)+')'; ctx.stroke(); } } }); requestAnimationFrame(anim); } anim();
</script>
</body></html>"""

@app.route("/")
def index():
    if not session.get("auth"): return render_template_string(HTML, logo=OFFICIAL_LOGO)
    users = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r", encoding="utf-8") as f: users = json.load(f)
    return render_template_string(HTML, logo=OFFICIAL_LOGO, uptime=get_uptime(), rate=get_rate(), users=users, active_count=0)

@app.route("/login_check", methods=["POST"])
def login_check():
    if hmac.compare_digest(request.form.get("u"), ADMIN_USER) and hmac.compare_digest(request.form.get("p"), ADMIN_PASS):
        session["auth"] = True
    return redirect("/")

@app.route("/set_rate", methods=["POST"])
def set_rate_route():
    if session.get("auth"):
        with open(RATE_FILE, "w") as f: json.dump({"rate": int(request.form.get("rate"))}, f)
    return redirect("/")

@app.route("/logout")
def logout(): session.clear(); return redirect("/")

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

systemctl daemon-reload && systemctl restart zivpn-web
echo "✅ SUCCESS! Final Layout Updated: http://$(hostname -I | awk '{print $1}'):8080"
