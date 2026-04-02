#!/bin/bash
# CMT ZIVPN PRO - ULTIMATE NEON SCRIPT
set -euo pipefail

# 1. Install Dependencies
apt-get update -y && apt-get install -y curl ufw jq python3 python3-flask conntrack iptables openssl >/dev/null

# 2. Setup Directories
mkdir -p /etc/zivpn

# 3. Create web.py (With All UI Features)
cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, datetime
from flask import Flask, render_template_string, request, redirect, session

app = Flask(__name__)
app.secret_key = "CMT_ULTIMATE_STABLE_2026"

ADMIN_USER = "admin"
ADMIN_PASS = "admin"
LOGO_URL = "https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png"

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
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
    <title>CMT ZIVPN PRO PANEL</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.95); --cyan: #00d4ff; --glow: #ff4500; --yellow: #ffaa00; --purple: #9b59b6; --green: #2ecc71; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 70px; overflow-x: hidden; }
        #bgCanvas { position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: -1; }

        @keyframes rainbow {
            0% { border-color: #ff0000; box-shadow: 0 0 10px #ff0000; }
            33% { border-color: #00d4ff; box-shadow: 0 0 10px #00d4ff; }
            66% { border-color: #2ecc71; box-shadow: 0 0 10px #2ecc71; }
            100% { border-color: #ff0000; box-shadow: 0 0 10px #ff0000; }
        }

        .header { background: rgba(0,0,0,0.8); padding: 15px; border-bottom: 2px solid var(--cyan); display: flex; justify-content: space-between; align-items: center; position: sticky; top: 0; z-index: 100; }
        .header img { border-radius: 50%; width: 42px; height: 42px; border: 2px solid #fff; }
        .container { padding: 12px; width: 95%; max-width: 1000px; margin: auto; }
        
        .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-bottom: 15px; }
        .grid-box { background: var(--card); border: 2px solid var(--cyan); border-radius: 12px; padding: 15px 5px; text-align: center; animation: rainbow 6s linear infinite; }
        .grid-val { font-size: 1.1em; font-weight: bold; color: var(--cyan); }
        .grid-label { font-size: 0.6em; color: #888; text-transform: uppercase; margin-top: 3px; }

        .action-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-bottom: 20px; }
        .action-box { background: var(--card); border: 2.5px solid var(--purple); border-radius: 15px; padding: 20px 5px; text-align: center; cursor: pointer; animation: rainbow 8s linear infinite reverse; }
        .action-box i { font-size: 1.8em; color: var(--yellow); display: block; margin-bottom: 8px; }
        .action-label { font-size: 0.75em; font-weight: bold; color: #fff; }

        .table-card { background: var(--card); border-radius: 15px; border: 1.5px solid var(--cyan); padding: 5px; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; min-width: 500px; }
        th { text-align: left; padding: 10px; color: var(--cyan); border-bottom: 2px solid #1e293b; font-size: 0.85em; }
        td { padding: 12px 10px; border-bottom: 1px solid #1e293b; font-size: 0.9em; }

        .status-off { color: rgba(255, 68, 68, 0.4); font-size: 0.8em; }
        .status-on { color: var(--green); text-shadow: 0 0 5px var(--green); }

        .modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); backdrop-filter: blur(8px); }
        .modal-content { background: var(--card); margin: 15% auto; padding: 25px; border-radius: 20px; border: 2px solid var(--cyan); width: 85%; max-width: 400px; text-align: center; box-shadow: 0 0 30px var(--cyan); }
        input { width: 100%; padding: 14px; margin: 10px 0; background: #000; border: 1.5px solid #333; color: #fff; border-radius: 10px; box-sizing: border-box; outline: none; }
        .btn { background: linear-gradient(45deg, #00c6ff, #0072ff); color: #fff; border: none; padding: 15px; border-radius: 12px; font-weight: bold; width: 100%; cursor: pointer; }
        .social-link { display: flex; align-items: center; justify-content: center; gap: 12px; text-decoration: none; padding: 14px; border-radius: 12px; margin-bottom: 10px; color: #fff; font-weight: bold; font-size: 0.9em; }
        .login-card { max-width: 330px; margin: 18vh auto; background: var(--card); padding: 40px; border-radius: 30px; text-align: center; border: 3px solid var(--glow); box-shadow: 0 0 50px rgba(255, 69, 0, 0.5); }
    </style>
</head>
<body onload="initCanvas();">
<canvas id="bgCanvas"></canvas>

{% if not session.get('auth') %}
    <div class="login-card">
        <img src="{{ logo_url }}" width="85" style="border-radius:50%; margin-bottom:25px; border:3px solid #fff; background:#fff; box-shadow: 0 0 20px #fff;">
        <h2 style="color:var(--cyan); margin-bottom:20px;">CMT LOGIN</h2>
        <form method="post" action="/login_check">
            <input name="u" placeholder="Admin Name" required>
            <input name="p" type="password" placeholder="Pass" required>
            <button class="btn" style="background: linear-gradient(45deg, #ff4500, #ffaa00);">LOGIN</button>
        </form>
    </div>
{% else %}
    <div class="header">
        <div style="display:flex; align-items:center; gap:12px;">
            <img src="{{ logo_url }}">
            <b style="color:var(--cyan); letter-spacing:1px; font-size:0.9em;">CMT ZIVPN PRO PANEL</b>
        </div>
        <a href="/logout" style="color:var(--cyan); font-size:1.4em;"><i class="fas fa-power-off"></i></a>
    </div>

    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><div class="grid-label">CPU</div><div class="grid-val">0.3%</div></div>
            <div class="grid-box"><div class="grid-label">RAM</div><div class="grid-val">12.0%</div></div>
            <div class="grid-box"><div class="grid-label">DISK</div><div class="grid-val">9.0%</div></div>
            <div class="grid-box" style="border-color:var(--purple);"><div class="grid-label">အသုံးပြုသူ</div><div class="grid-val">{{ users|length }}</div></div>
            <div class="grid-box" style="border-color:var(--green);"><div class="grid-label">အွန်လိုင်း</div><div class="grid-val">0</div></div>
            <div class="grid-box" style="border-color:var(--yellow);"><div class="grid-label">ဝန်ဆောင်မှု</div><div class="grid-val">12%</div></div>
        </div>

        <div class="action-grid">
            <div class="action-box" onclick="openM('addM')"><i class="fas fa-user-plus"></i><div class="action-label">အကောင့်သစ်</div></div>
            <div class="action-box" onclick="openM('supM')"><i class="fas fa-headset"></i><div class="action-label">ဆက်သွယ်ရန်</div></div>
            <div class="action-box" onclick="openM('setM')"><i class="fas fa-tools"></i><div class="action-label">စက်တင်များ</div></div>
        </div>

        <div class="table-card">
            <table>
                <thead><tr><th>အမည်</th><th>စကားဝှက်</th><th>သက်တမ်း</th><th>Status</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan); font-weight:bold;">{{ u.user }}</td>
                        <td>{{ u.password }}</td>
                        <td style="color:#ff69b4;">{{ u.expires }}</td>
                        <td><span class="status-off">● Offline</span></td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>

    <div id="addM" class="modal"><div class="modal-content">
        <h3 style="color:var(--cyan);">အကောင့်သစ်</h3>
        <form method="post" action="/add"><input name="user" placeholder="နာမည်"><input name="password" placeholder="စကားဝှက်"><input name="days" placeholder="ရက်ပေါင်း"><button class="btn">ဆောက်မည်</button></form>
        <button onclick="closeM('addM')" style="background:none; border:none; color:#888; margin-top:20px;">ပိတ်မည်</button>
    </div></div>

    <div id="supM" class="modal"><div class="modal-content">
        <h3 style="color:var(--cyan); margin-bottom:20px;">CONTACT</h3>
        <a href="https://t.me/CMT_1411" class="social-link" style="background:#0088cc;"><i class="fab fa-telegram-plane"></i> Telegram</a>
        <a href="https://m.me/ChitMinThu1239" class="social-link" style="background:linear-gradient(45deg, #00c6ff, #bc00ff);"><i class="fab fa-facebook-messenger"></i> Messenger</a>
        <button onclick="closeM('supM')" style="background:none; border:none; color:#888; margin-top:20px;">ပိတ်မည်</button>
    </div></div>

    <div id="setM" class="modal"><div class="modal-content">
        <h3 style="color:var(--cyan);">Settings</h3>
        <form method="post" action="/change_pass"><input name="new_p" type="password" placeholder="စကားဝှက်အသစ်"><button class="btn">SAVE ADMIN PASS</button></form>
        <button onclick="closeM('setM')" style="background:none; border:none; color:#888; margin-top:20px;">ပိတ်မည်</button>
    </div></div>

    <script>
        function openM(id) { document.getElementById(id).style.display = "block"; }
        function closeM(id) { document.getElementById(id).style.display = "none"; }
        function initCanvas(){
            const canvas = document.getElementById('bgCanvas'), ctx = canvas.getContext('2d');
            canvas.width = window.innerWidth; canvas.height = window.innerHeight;
            let pts = [];
            for(let i=0; i<60; i++) pts.push({x:Math.random()*canvas.width, y:Math.random()*canvas.height, vx:(Math.random()-0.5)*0.8, vy:(Math.random()-0.5)*0.8});
            function draw(){
                ctx.clearRect(0,0,canvas.width,canvas.height);
                pts.forEach((p,i)=>{
                    p.x+=p.vx; p.y+=p.vy;
                    if(p.x<0||p.x>canvas.width) p.vx*=-1; if(p.y<0||p.y>canvas.height) p.vy*=-1;
                    ctx.beginPath(); ctx.arc(p.x, p.y, 2, 0, Math.PI*2); ctx.fillStyle="rgba(0,212,255,0.15)"; ctx.fill();
                    for(let j=i+1; j<pts.length; j++){
                        let d = Math.hypot(p.x-pts[j].x, p.y-pts[j].y);
                        if(d<110){ ctx.beginPath(); ctx.moveTo(p.x,p.y); ctx.lineTo(pts[j].x,pts[j].y); ctx.strokeStyle="rgba(0,212,255,"+(1-d/110)+")"; ctx.stroke(); }
                    }
                }); requestAnimationFrame(draw);
            } draw();
        }
    </script>
{% endif %}
</body></html>"""

@app.route("/")
def index():
    users = []
    if os.path.exists("/etc/zivpn/users.json"):
        try:
            with open("/etc/zivpn/users.json","r") as f: users = json.load(f)
        except: users = []
    return render_template_string(HTML, logo_url=LOGO_URL, users=users, uptime=get_uptime())

@app.route("/login_check", methods=["POST"])
def login_check():
    if request.form.get("u") == ADMIN_USER and request.form.get("p") == ADMIN_PASS:
        session["auth"] = True
    return redirect("/")

@app.route("/logout")
def logout(): session.clear(); return redirect("/")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
PY

# 4. Final Setup & Service Restart
systemctl daemon-reload
systemctl enable zivpn-web 2>/dev/null || true
systemctl restart zivpn-web

IP=$(hostname -I | awk '{print $1}')
echo -e "\n✅ Update Done! Website: http://$IP:8080"
