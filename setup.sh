#!/bin/bash
# CMT ZIVPN PRO - ULTIMATE CALENDAR & CLOCK SCRIPT
set -euo pipefail

# 1. Install Dependencies
apt-get update -y && apt-get install -y curl jq python3 python3-flask >/dev/null

# 2. Setup Directory
mkdir -p /etc/zivpn

# 3. Create web.py with New UI Features
cat > /etc/zivpn/web.py <<'PY'
import os, json, datetime
from flask import Flask, render_template_string, request, redirect, session

app = Flask(__name__)
app.secret_key = "CMT_FINAL_GOD_MODE_2026"

ADMIN_USER = "admin"
ADMIN_PASS = "admin"
LOGO_URL = "https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png"

HTML = """<!doctype html>
<html lang="my" translate="no">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
    <title>CMT ZIVPN PRO PANEL</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.95); --cyan: #00d4ff; --glow: #ff4500; --yellow: #ffaa00; --purple: #9b59b6; --green: #2ecc71; --red: #ff4444; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 100px; overflow-x: hidden; }
        #bgCanvas { position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: -1; }

        @keyframes rainbow {
            0% { border-color: #ff0000; box-shadow: 0 0 10px #ff0000; }
            33% { border-color: #00d4ff; box-shadow: 0 0 10px #00d4ff; }
            66% { border-color: #2ecc71; box-shadow: 0 0 10px #2ecc71; }
            100% { border-color: #ff0000; box-shadow: 0 0 10px #ff0000; }
        }

        /* ✅ Big Logo & Title Section */
        .header { background: rgba(0,0,0,0.85); padding: 25px 15px; border-bottom: 3px solid var(--cyan); text-align: center; position: sticky; top: 0; z-index: 100; }
        .logo-box { margin-bottom: 15px; }
        .logo-img { width: 90px; height: 90px; border-radius: 50%; border: 4px solid #fff; box-shadow: 0 0 25px rgba(255,255,255,0.6); }
        .main-title { font-size: 1.8em; font-weight: 900; color: var(--cyan); text-shadow: 0 0 15px var(--cyan); letter-spacing: 2px; }
        
        /* ✅ Thailand Live Clock */
        .th-clock { font-size: 1.3em; font-weight: bold; color: var(--yellow); margin-top: 10px; text-shadow: 0 0 10px var(--yellow); }

        .container { padding: 15px; width: 95%; max-width: 1000px; margin: auto; }
        .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 20px; }
        .grid-box { background: var(--card); border: 2px solid var(--cyan); border-radius: 15px; padding: 18px 5px; text-align: center; animation: rainbow 6s linear infinite; }
        .grid-val { font-size: 1.2em; font-weight: bold; color: var(--cyan); }
        .grid-label { font-size: 0.65em; color: #888; text-transform: uppercase; }

        .table-card { background: var(--card); border-radius: 15px; border: 1.5px solid var(--cyan); padding: 5px; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; min-width: 500px; }
        th { text-align: left; padding: 12px; color: var(--cyan); border-bottom: 2px solid #1e293b; }
        td { padding: 15px 12px; border-bottom: 1px solid #1e293b; }

        /* ✅ Bottom Navbar */
        .footer-nav { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(10, 14, 26, 0.98); display: flex; justify-content: space-around; align-items: center; padding: 15px 0; border-top: 2px solid var(--cyan); z-index: 1000; }
        .nav-btn { font-size: 2em; cursor: pointer; transition: 0.3s; color: #fff; }
        .nav-btn:active { transform: scale(1.4); }

        /* ✅ Calendar Modal UI */
        .modal { display: none; position: fixed; z-index: 2000; left: 0; top: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); backdrop-filter: blur(10px); }
        .modal-content { background: var(--card); margin: 10% auto; padding: 25px; border-radius: 25px; border: 3px solid var(--cyan); width: 90%; max-width: 450px; text-align: center; box-shadow: 0 0 40px var(--cyan); }
        .cal-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 8px; margin-top: 20px; }
        .cal-head { color: var(--cyan); font-weight: bold; font-size: 0.8em; padding-bottom: 10px; }
        .cal-day { background: #1a1e2e; padding: 12px 5px; border-radius: 10px; font-weight: bold; border: 1px solid #333; }
        .cal-today { background: var(--cyan); color: #000; box-shadow: 0 0 15px var(--cyan); border: none; }
    </style>
</head>
<body onload="initAll();">
<canvas id="bgCanvas"></canvas>

{% if not session.get('auth') %}
    <div style="max-width: 330px; margin: 15vh auto; background: var(--card); padding: 40px; border-radius: 35px; text-align: center; border: 3px solid var(--glow);">
        <img src="{{ logo }}" width="90" style="border-radius:50%; margin-bottom:20px; border:3px solid #fff;">
        <h2 style="color:var(--cyan);">CMT LOGIN</h2>
        <form method="post" action="/login_check"><input name="u" placeholder="Admin" style="width:100%; padding:15px; margin:10px 0; border-radius:10px; border:1px solid #333; background:#000; color:#fff;" required><input name="p" type="password" placeholder="Pass" style="width:100%; padding:15px; margin:10px 0; border-radius:10px; border:1px solid #333; background:#000; color:#fff;" required><button style="width:100%; padding:15px; border-radius:10px; background:var(--cyan); font-weight:bold; cursor:pointer;">LOGIN</button></form>
    </div>
{% else %}
    <div class="header">
        <div class="logo-box"><img src="{{ logo }}" class="logo-img"></div>
        <div class="main-title">CMT ZIVPN PRO PANEL</div>
        <div id="thClock" class="th-clock">🇹🇭 Loading Time...</div>
    </div>

    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><div class="grid-label">CPU</div><div class="grid-val">0.5%</div></div>
            <div class="grid-box"><div class="grid-label">RAM</div><div class="grid-val">15%</div></div>
            <div class="grid-box"><div class="grid-label">DISK</div><div class="grid-val">10%</div></div>
        </div>

        <div class="table-card">
            <table>
                <thead><tr><th>NAME</th><th>PASS</th><th>EXP</th><th>STATUS</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan); font-weight:bold;">{{ u.user }}</td>
                        <td>{{ u.password }}</td>
                        <td style="color:#ff69b4;">{{ u.expires }}</td>
                        <td><span style="color:#ff4444; font-size:0.8em;">● Offline</span></td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>

    <div class="footer-nav">
        <div class="nav-btn" style="color:var(--cyan);" onclick="openM('calM')"><i class="fas fa-calendar-alt"></i></div>
        <div class="nav-btn" onclick="location.reload()"><i class="fas fa-sync-alt"></i></div>
        <a href="/logout" class="nav-btn" style="color:var(--red);"><i class="fas fa-power-off"></i></a>
    </div>

    <div id="calM" class="modal"><div class="modal-content">
        <h3 style="color:var(--cyan);">CMT CALENDAR</h3>
        <p id="calMonth" style="color:#888; font-weight:bold;"></p>
        <div class="cal-grid">
            <div class="cal-head">Sun</div><div class="cal-head">Mon</div><div class="cal-head">Tue</div><div class="cal-head">Wed</div><div class="cal-head">Thu</div><div class="cal-head">Fri</div><div class="cal-head">Sat</div>
        </div>
        <button onclick="closeM('calM')" style="margin-top:25px; background:none; border:none; color:#888; cursor:pointer;">ပိတ်မည်</button>
    </div></div>

    <script>
        function openM(id) { document.getElementById(id).style.display = "block"; if(id==='calM') renderCal(); }
        function closeM(id) { document.getElementById(id).style.display = "none"; }

        function startClock(){
            setInterval(() => {
                let d = new Date();
                let th = new Date(d.getTime() + (d.getTimezoneOffset() * 60000) + (7 * 3600000));
                document.getElementById('thClock').innerHTML = "🇹🇭 TH TIME: " + th.toLocaleTimeString();
            }, 1000);
        }

        function renderCal(){
            let d = new Date();
            let th = new Date(d.getTime() + (d.getTimezoneOffset() * 60000) + (7 * 3600000));
            let yr = th.getFullYear(), mo = th.getMonth(), today = th.getDate();
            document.getElementById('calMonth').innerHTML = th.toLocaleString('default', { month: 'long' }) + " " + yr;
            let grid = document.querySelector(".cal-grid");
            document.querySelectorAll(".cal-d-no").forEach(e => e.remove());
            let firstDay = new Date(yr, mo, 1).getDay();
            let lastDate = new Date(yr, mo + 1, 0).getDate();
            for(let i=0; i<firstDay; i++){ let e=document.createElement("div"); e.className="cal-d-no"; grid.appendChild(e); }
            for(let i=1; i<=lastDate; i++){
                let e=document.createElement("div"); e.className="cal-day cal-d-no"; e.innerHTML=i;
                if(i===today) e.classList.add("cal-today");
                grid.appendChild(e);
            }
        }

        function initAll(){ startClock(); initCanvas(); }
        function initCanvas(){
            const c = document.getElementById('bgCanvas'), ctx = c.getContext('2d');
            c.width = window.innerWidth; c.height = window.innerHeight;
            let p = [];
            for(let i=0; i<50; i++) p.push({x:Math.random()*c.width, y:Math.random()*c.height, vx:(Math.random()-0.5)*0.8, vy:(Math.random()-0.5)*0.8});
            function draw(){
                ctx.clearRect(0,0,c.width,c.height);
                p.forEach((pt,i)=>{
                    pt.x+=pt.vx; pt.y+=pt.vy;
                    if(pt.x<0||pt.x>c.width) pt.vx*=-1; if(pt.y<0||pt.y>c.height) pt.vy*=-1;
                    ctx.beginPath(); ctx.arc(pt.x, pt.y, 2, 0, Math.PI*2); ctx.fillStyle="rgba(0,212,255,0.2)"; ctx.fill();
                    for(let j=i+1; j<p.length; j++){
                        let d = Math.hypot(pt.x-p[j].x, pt.y-p[j].y);
                        if(d<110){ ctx.beginPath(); ctx.moveTo(pt.x,pt.y); ctx.lineTo(p[j].x,p[j].y); ctx.strokeStyle="rgba(0,212,255,"+(1-d/110)+")"; ctx.stroke(); }
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
        except: pass
    return render_template_string(HTML, logo=LOGO_URL, users=users)

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

# 4. Final Service Restart
systemctl daemon-reload
systemctl restart zivpn-web
echo "✅ CMT ULTIMATE PANEL UPDATED!"
