#!/bin/bash
# CMT ZIVPN PRO - ULTIMATE FEATURE EDITION
set -euo pipefail
apt-get update -y && apt-get install -y curl ufw jq python3 python3-flask conntrack iptables openssl >/dev/null

mkdir -p /etc/zivpn
BIN="/usr/local/bin/zivpn"; CFG="/etc/zivpn/config.json"; USERS="/etc/zivpn/users.json"; ENVF="/etc/zivpn/web.env"

# Admin Login (Default: admin/admin)
echo "WEB_ADMIN_USER=admin" > "$ENVF"
echo "WEB_ADMIN_PASSWORD=admin" >> "$ENVF"
echo "WEB_SECRET=$(openssl rand -hex 16)" >> "$ENVF"

# Networking Setup
sysctl -w net.ipv4.ip_forward=1 >/dev/null
iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || true
iptables -t nat -A POSTROUTING -j MASQUERADE 2>/dev/null || true

# Python Script
cat > /etc/zivpn/web.py <<PY
import os, json, subprocess, hmac, datetime
from flask import Flask, render_template_string, request, redirect, session, url_for

app = Flask(__name__)
app.secret_key = os.environ.get("WEB_SECRET")
ADMIN_USER = os.environ.get("WEB_ADMIN_USER")
ADMIN_PASS = os.environ.get("WEB_ADMIN_PASSWORD")

OFFICIAL_LOGO = "https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png"

def get_uptime():
    try:
        with open('/proc/uptime', 'r') as f:
            up_sec = float(f.readline().split()[0])
            return str(datetime.timedelta(seconds=int(up_sec)))
    except: return "0:00:00"

HTML = """<!doctype html>
<html lang="my" translate="no">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>CMT ZIVPN PRO</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.85); --glow: #ff4500; --cyan: #00d4ff; --yellow: #ffaa00; --green: #2ecc71; --purple: #9b59b6; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; overflow-x: hidden; }
        #bgCanvas { position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: -1; background: #050810; }

        @keyframes rainbowText {
            0% { background-position: 0% 50%; }
            50% { background-position: 100% 50%; }
            100% { background-position: 0% 50%; }
        }
        .rainbow-text {
            font-weight: bold;
            background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #9b59b6, #ff0000);
            background-size: 300% 300%;
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            animation: rainbowText 5s linear infinite;
        }

        .header { background: rgba(0,0,0,0.6); backdrop-filter: blur(15px); padding: 15px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); box-shadow: 0 0 20px var(--cyan); }
        .header img { border-radius: 50%; border: 2px solid #fff; width: 45px; height: 45px; background: #fff; }
        
        .container { padding: 15px; }
        .grid-menu { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin-bottom: 20px; }
        .grid-box { background: var(--card); border: 2px solid var(--glow); border-radius: 15px; padding: 12px; text-align: center; box-shadow: 0 0 15px rgba(255, 69, 0, 0.4); backdrop-filter: blur(5px); }
        .grid-val { font-size: 1.3em; font-weight: bold; color: var(--yellow); text-shadow: 0 0 10px var(--yellow); }
        
        .card { background: var(--card); padding: 20px; border-radius: 20px; border: 2px solid var(--glow); margin-bottom: 20px; box-shadow: 0 0 25px rgba(255, 69, 0, 0.5); }
        input { width: 100%; padding: 12px; margin: 8px 0; background: rgba(0,0,0,0.7); border: 1.5px solid #444; color: #fff !important; border-radius: 10px; box-sizing: border-box; }
        .btn { background: linear-gradient(45deg, #ff4500, #ffaa00); color: #fff; border: none; padding: 12px; border-radius: 10px; font-weight: bold; width: 100%; cursor: pointer; }
        
        .btn-action { padding: 5px 10px; border-radius: 8px; color: white; text-decoration: none; font-size: 0.8em; margin-left: 5px; }
        .btn-tg { background: #0088cc; }
        .btn-msg { background: #2ecc71; }

        .table-card { background: var(--card); border-radius: 15px; border: 2px solid var(--cyan); padding: 10px; overflow-x: auto; box-shadow: 0 0 15px rgba(0, 212, 255, 0.3); }
        table { width: 100%; border-collapse: collapse; min-width: 500px; }
        th { text-align: left; padding: 10px; color: var(--cyan); font-size: 0.8em; border-bottom: 2px solid #1e293b; }
        td { padding: 12px 10px; border-bottom: 1px solid #1e293b; font-size: 0.9em; }

        .copy-btn { color: var(--cyan); cursor: pointer; margin-left: 5px; font-size: 0.9em; }
        .copy-btn:active { transform: scale(1.2); }

        .bottom-nav { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(10, 14, 26, 0.95); display: flex; justify-content: space-around; padding: 15px 0; border-top: 2px solid #4e73df; }
        .nav-item { color: #555; font-size: 1.5em; }
        .nav-item.active { color: var(--cyan); text-shadow: 0 0 10px var(--cyan); }
    </style>
</head>
<body>
<canvas id="bgCanvas"></canvas>
{% if not session.get('auth') %}
    <div style="max-width: 320px; margin: 20vh auto; background: var(--card); padding: 35px; border-radius: 25px; text-align: center; border: 3px solid var(--glow);">
        <img src="{{ logo }}" width="80" style="background:#fff; border-radius:15px; margin-bottom:20px;">
        <h2 class="rainbow-text">CMT LOGIN</h2>
        <form method="post" action="/login_check"><input name="u" placeholder="Admin Name" required><input name="p" type="password" placeholder="Password" required><button class="btn" style="margin-top:15px;">LOGIN</button></form>
    </div>
{% else %}
    <div class="header">
        <div style="display:flex;align-items:center;gap:10px;"><img src="{{ logo }}"><b class="rainbow-text" style="font-size: 1.1em;">CMT ZIVPN PRO</b></div>
        <div>
            <a href="https://t.me/Zero_Free_Vpn" class="btn-action btn-tg"><i class="fab fa-telegram-plane"></i></a>
            <a href="#" class="btn-action btn-msg"><i class="fas fa-comment-dots"></i></a>
        </div>
    </div>
    <div class="container">
        <div style="text-align:center; margin-bottom:15px;"><small>Server IP: <span id="sip">{{ ip }}</span> <i class="fas fa-copy copy-btn" onclick="copyText('sip')"></i></small></div>
        <div class="grid-menu">
            <div class="grid-box"><div style="font-size: 0.6em;">USERS</div><div class="grid-val">{{ users|length }}</div></div>
            <div class="grid-box" style="border-color:var(--green);"><div style="font-size: 0.6em;">ONLINE</div><div class="grid-val" style="color:var(--green);">{{ active_count }}</div></div>
        </div>
        <div class="card">
            <form method="post" action="/add"><input name="user" placeholder="Name" required><input name="password" placeholder="Pass" required><input name="days" placeholder="Days" required><button class="btn">CREATE USER</button></form>
        </div>
        <div class="table-card">
            <table>
                <thead><tr><th>USER</th><th>PASS</th><th>EXPIRY</th><th>STATUS</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan);">{{ u.user }}</td>
                        <td><span id="pw{{loop.index}}">{{ u.password }}</span> <i class="fas fa-copy copy-btn" onclick="copyText('pw{{loop.index}}')"></i></td>
                        <td style="color:#ff69b4;">{{ u.expires }}</td>
                        <td><i class="fas fa-circle" style="color:{{ '#2ecc71' if u.online else '#e74c3c' }}; font-size: 0.7em;"></i> {{ 'Online' if u.online else 'Offline' }}</td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>
    <div class="bottom-nav">
        <a href="/" class="nav-item active"><i class="fas fa-home"></i></a>
        <a href="/logout" class="nav-item"><i class="fas fa-power-off"></i></a>
    </div>
{% endif %}

<script>
    function copyText(id) {
        var text = document.getElementById(id).innerText;
        navigator.clipboard.writeText(text);
        alert("Copied: " + text);
    }

    /* ✅ Network Lines Script */
    const canvas = document.getElementById('bgCanvas');
    const ctx = canvas.getContext('2d');
    let pts = [];
    function init() { canvas.width = window.innerWidth; canvas.height = window.innerHeight; }
    window.onresize = init; init();

    class Pt {
        constructor() { this.x = Math.random()*canvas.width; this.y = Math.random()*canvas.height; this.vx = (Math.random()-0.5)*0.6; this.vy = (Math.random()-0.5)*0.6; }
        up() { this.x+=this.vx; this.y+=this.vy; if(this.x<0||this.x>canvas.width)this.vx*=-1; if(this.y<0||this.y>canvas.height)this.vy*=-1; }
        dr() { ctx.beginPath(); ctx.arc(this.x,this.y,1.5,0,Math.PI*2); ctx.fillStyle='rgba(0,212,255,0.4)'; ctx.fill(); }
    }
    for(let i=0;i<70;i++) pts.push(new Pt());
    function anim() {
        ctx.clearRect(0,0,canvas.width,canvas.height);
        pts.forEach((p,i)=>{
            p.up(); p.dr();
            for(let j=i+1;j<pts.length;j++){
                let d = Math.hypot(p.x-pts[j].x, p.y-pts[j].y);
                if(d<100){ ctx.beginPath(); ctx.moveTo(p.x,p.y); ctx.lineTo(pts[j].x,pts[j].y); ctx.strokeStyle='rgba(255,69,0,'+(1-d/100)+')'; ctx.lineWidth=0.5; ctx.stroke(); }
            }
        });
        requestAnimationFrame(anim);
    }
    anim();
</script>
</body></html>"""

@app.route("/")
def index():
    if not session.get("auth"): return render_template_string(HTML, logo=OFFICIAL_LOGO)
    users = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: users = json.load(f)
    conntrack = subprocess.run("conntrack -L -p udp 2>/dev/null", shell=True, capture_output=True, text=True).stdout
    active_count = 0
    for u in users:
        u["online"] = f"dport={u.get('port')}" in conntrack if u.get("port") else False
        if u["online"]: active_count += 1
    ip = subprocess.run("curl -s icanhazip.com", shell=True, capture_output=True, text=True).stdout.strip()
    return render_template_string(HTML, logo=OFFICIAL_LOGO, users=users, active_count=active_count, ip=ip)

@app.route("/login_check", methods=["POST"])
def login_check():
    if hmac.compare_digest(request.form.get("u"), ADMIN_USER) and hmac.compare_digest(request.form.get("p"), ADMIN_PASS):
        session["auth"] = True
    return redirect("/")

@app.route("/add", methods=["POST"])
def add():
    if not session.get("auth"): return redirect("/")
    u, p, d = request.form.get("user"), request.form.get("password"), request.form.get("days")
    exp = (datetime.datetime.now() + datetime.timedelta(days=int(d))).strftime("%Y-%m-%d") if d.isdigit() else d
    with open("/etc/zivpn/users.json","r") as f: users = json.load(f)
    port = str(max([int(x.get("port", 6000)) for x in users] + [6000]) + 1)
    users.insert(0, {"user":u, "password":p, "expires":exp, "port":port})
    with open("/etc/zivpn/users.json","w") as f: json.dump(users, f, indent=2)
    with open("/etc/zivpn/config.json","r") as f: cfg = json.load(f)
    cfg["auth"]["config"] = [x["password"] for x in users]
    with open("/etc/zivpn/config.json","w") as f: json.dump(cfg, f, indent=2)
    subprocess.run("systemctl restart zivpn", shell=True)
    return redirect("/")

@app.route("/logout")
def logout(): session.clear(); return redirect("/")

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

systemctl daemon-reload && systemctl restart zivpn-web
echo -e "\n✅ ALL-IN-ONE Update Done! http://$(hostname -I | awk '{print $1}'):8080"
