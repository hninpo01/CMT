#!/bin/bash
# CMT ZIVPN PRO - ULTIMATE MASTER FIX

# 1. Install Dependencies
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl >/dev/null

# 2. Setup Directories
mkdir -p /etc/zivpn

# 3. Create web.py (With Big Panel, Rainbow Glow & Interactive Modals)
cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, datetime
from flask import Flask, render_template_string, request, redirect, session

app = Flask(__name__)
app.secret_key = "CMT_PHOENIX_BIG_2026"
ADMIN_USER = "admin"
ADMIN_PASS = "admin"

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
    <title>CMT ZIVPN PRO PANEL</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.95); --cyan: #00d4ff; --glow: #ff4500; --yellow: #ffaa00; --purple: #9b59b6; --green: #2ecc71; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 50px; overflow: hidden; }
        #bgCanvas { position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: -1; }

        @keyframes rainbowBorder {
            0% { border-color: #ff0000; box-shadow: 0 0 10px #ff0000; }
            33% { border-color: #2ecc71; box-shadow: 0 0 10px #2ecc71; }
            66% { border-color: #00d4ff; box-shadow: 0 0 10px #00d4ff; }
            100% { border-color: #ff0000; box-shadow: 0 0 10px #ff0000; }
        }

        .header { background: rgba(0,0,0,0.7); padding: 15px; border-bottom: 2px solid var(--cyan); display: flex; justify-content: space-between; align-items: center; position: sticky; top: 0; z-index: 100; }
        .header img { border-radius: 50%; width: 45px; height: 45px; border: 2px solid #fff; }
        .container { padding: 15px; max-width: 850px; margin: auto; }
        
        .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 20px; }
        .grid-box { background: var(--card); border: 2px solid var(--cyan); border-radius: 12px; padding: 15px; text-align: center; animation: rainbowBorder 5s linear infinite; }
        .grid-val { font-size: 1.1em; font-weight: bold; color: var(--cyan); }
        .grid-label { font-size: 0.65em; color: #888; text-transform: uppercase; margin-top: 5px; }

        .action-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 25px; }
        .action-box { background: var(--card); border: 2px solid var(--purple); border-radius: 15px; padding: 25px 10px; text-align: center; cursor: pointer; transition: 0.3s; animation: rainbowBorder 8s linear infinite; }
        .action-box i { font-size: 2em; color: var(--yellow); display: block; margin-bottom: 10px; }
        .action-label { font-size: 0.85em; font-weight: bold; }

        .table-card { background: var(--card); border-radius: 15px; border: 1.5px solid var(--cyan); padding: 10px; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; min-width: 550px; }
        th { text-align: left; padding: 12px; color: var(--cyan); border-bottom: 2px solid #1e293b; font-size: 0.9em; }
        td { padding: 15px 12px; border-bottom: 1px solid #1e293b; font-size: 1em; }

        .modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.85); backdrop-filter: blur(5px); }
        .modal-content { background: var(--card); margin: 15% auto; padding: 25px; border-radius: 20px; border: 2px solid var(--cyan); width: 85%; max-width: 450px; text-align: center; }
        input { width: 100%; padding: 15px; margin: 10px 0; background: #000; border: 1.5px solid #333; color: #fff; border-radius: 10px; box-sizing: border-box; outline: none; }
        .btn { background: linear-gradient(45deg, #00c6ff, #0072ff); color: #fff; border: none; padding: 15px; border-radius: 10px; font-weight: bold; width: 100%; cursor: pointer; }
        .social-btn { display: flex; align-items: center; justify-content: center; gap: 10px; text-decoration: none; padding: 15px; border-radius: 10px; margin-bottom: 10px; color: white; font-weight: bold; }
    </style>
</head>
<body onload="initCanvas();">
<canvas id="bgCanvas"></canvas>
{% if not session.get('auth') %}
    <div style="max-width: 320px; margin: 20vh auto; background: var(--card); padding: 40px; border-radius: 25px; text-align: center; border: 2.5px solid var(--glow);">
        <h3 style="color:var(--cyan);">CMT LOGIN</h3>
        <form method="post" action="/login_check"><input name="u" placeholder="Admin"><input name="p" type="password" placeholder="Pass"><button class="btn">LOGIN</button></form>
    </div>
{% else %}
    <div class="header">
        <div style="display:flex; align-items:center; gap:12px;"><img src="https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png"><b style="color:var(--cyan); letter-spacing:1px;">CMT ZIVPN PRO PANEL</b></div>
        <a href="/logout" style="color:var(--cyan); font-size:1.5em;"><i class="fas fa-power-off"></i></a>
    </div>

    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><div class="grid-label">CPU</div><div class="grid-val">0.3%</div></div>
            <div class="grid-box"><div class="grid-label">RAM</div><div class="grid-val">12.0%</div></div>
            <div class="grid-box"><div class="grid-label">DISK</div><div class="grid-val">9.0%</div></div>
        </div>
        <div class="action-grid">
            <div class="action-box" onclick="openM('addM')"><i class="fas fa-user-plus"></i><div class="action-label">အကောင့်သစ်</div></div>
            <div class="action-box" onclick="openM('supM')"><i class="fas fa-headset"></i><div class="action-label">ဆက်သွယ်ရန်</div></div>
            <div class="action-box" onclick="openM('setM')"><i class="fas fa-tools"></i><div class="action-label">ကိတ်တင်များ</div></div>
        </div>
        <div class="table-card">
            <table>
                <thead><tr><th>အမည်</th><th>စကားဝှက်</th><th>သက်တမ်း</th><th>Status</th><th>Act</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan); font-weight:bold;">{{ u.user }}</td>
                        <td style="color:#fff;">{{ u.password }}</td>
                        <td style="color:#ff69b4;">{{ u.expires }}</td>
                        <td><span style="color:{{ 'var(--green)' if u.online else '#555' }}">● {{ 'Online' if u.online else 'Offline' }}</span></td>
                        <td><form method="post" action="/delete" style="display:inline;" onsubmit="return confirm('ဖျက်မှာ သေချာလား?')"><input type="hidden" name="user" value="{{u.user}}"><button type="submit" style="background:none; border:none; color:#ff4444; font-size:1.2em; cursor:pointer;"><i class="fas fa-trash-alt"></i></button></form></td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>

    <div id="addM" class="modal"><div class="modal-content">
        <h3 style="color:var(--cyan);">အကောင့်သစ်ဖွင့်ရန်</h3>
        <form method="post" action="/add"><input name="user" placeholder="နာမည်"><input name="pass" placeholder="စကားဝှက်"><input name="days" placeholder="ရက်ပေါင်း"><button class="btn">CREATE USER</button></form>
        <button onclick="closeM('addM')" style="background:none; border:none; color:#888; margin-top:15px; cursor:pointer;">ပိတ်မည်</button>
    </div></div>

    <div id="supM" class="modal"><div class="modal-content">
        <h3 style="color:var(--cyan); margin-bottom:20px;">ဆက်သွယ်ရန်</h3>
        <a href="https://t.me/CMT_1411" class="social-btn" style="background:#0088cc;"><i class="fab fa-telegram-plane"></i> Telegram</a>
        <a href="https://www.facebook.com/ChitMinThu1239" class="social-btn" style="background:#1877f2;"><i class="fab fa-facebook-f"></i> Facebook</a>
        <button onclick="closeM('supM')" style="background:none; border:none; color:#888; margin-top:15px; cursor:pointer;">ပိတ်မည်</button>
    </div></div>

    <div id="setM" class="modal"><div class="modal-content">
        <h3 style="color:var(--cyan);">Settings</h3>
        <form method="post" action="/change_admin"><input name="new_p" type="password" placeholder="စကားဝှက်အသစ်"><button class="btn">SAVE ADMIN PASS</button></form>
        <button onclick="closeM('setM')" style="background:none; border:none; color:#888; margin-top:15px; cursor:pointer;">ပိတ်မည်</button>
    </div></div>

    <script>
        function openM(id) { document.getElementById(id).style.display = "block"; }
        function closeM(id) { document.getElementById(id).style.display = "none"; }
        function initCanvas(){
            const canvas = document.getElementById('bgCanvas'), ctx = canvas.getContext('2d');
            canvas.width = window.innerWidth; canvas.height = window.innerHeight;
            let pts = [];
            for(let i=0; i<60; i++) pts.push({x:Math.random()*canvas.width, y:Math.random()*canvas.height, vx:(Math.random()-0.5)*1, vy:(Math.random()-0.5)*1});
            function draw(){
                ctx.clearRect(0,0,canvas.width,canvas.height);
                pts.forEach((p,i)=>{
                    p.x+=p.vx; p.y+=p.vy;
                    if(p.x<0||p.x>canvas.width) p.vx*=-1; if(p.y<0||p.y>canvas.height) p.vy*=-1;
                    ctx.beginPath(); ctx.arc(p.x, p.y, 2, 0, Math.PI*2); ctx.fillStyle="rgba(0,212,255,0.2)"; ctx.fill();
                    for(let j=i+1; j<pts.length; j++){
                        let d = Math.hypot(p.x-pts[j].x, p.y-pts[j].y);
                        if(d<120){ ctx.beginPath(); ctx.moveTo(p.x,p.y); ctx.lineTo(pts[j].x,pts[j].y); ctx.strokeStyle="rgba(0,212,255,"+(1-d/120)+")"; ctx.stroke(); }
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
        with open("/etc/zivpn/users.json","r") as f: users = json.load(f)
    return render_template_string(HTML, users=users, uptime=get_uptime())

@app.route("/login_check", methods=["POST"])
def login_check():
    if request.form.get("u") == ADMIN_USER and request.form.get("p") == ADMIN_PASS:
        session["auth"] = True
    return redirect("/")

@app.route("/logout")
def logout(): session.clear(); return redirect("/")

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

# 4. Restart Services
systemctl daemon-reload
systemctl restart zivpn-web
echo "✅ SUCCESS! Panel updated and running."
