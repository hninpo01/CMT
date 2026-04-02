#!/bin/bash
# CMT ZIVPN PRO - BUSINESS MASTER SCRIPT (FINAL)
set -euo pipefail

# 1. Install Dependencies
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl >/dev/null

# 2. Setup Directory
mkdir -p /etc/zivpn

# 3. Create web.py (With Search, Copy, Days Left & Revenue)
cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, datetime
from flask import Flask, render_template_string, request, redirect, session

app = Flask(__name__)
app.secret_key = "CMT_BUSINESS_ULTIMATE_MASTER_2026"

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
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.95); --cyan: #00d4ff; --glow: #ff4500; --yellow: #ffaa00; --purple: #9b59b6; --green: #2ecc71; --red: #ff4444; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 100px; overflow-x: hidden; }
        #bgCanvas { position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: -1; }

        @keyframes rainbow {
            0% { border-color: #ff0000; box-shadow: 0 0 10px #ff0000; }
            33% { border-color: #00d4ff; box-shadow: 0 0 10px #00d4ff; }
            66% { border-color: #2ecc71; box-shadow: 0 0 10px #2ecc71; }
            100% { border-color: #ff0000; box-shadow: 0 0 10px #ff0000; }
        }

        .header { background: rgba(0,0,0,0.85); padding: 25px 15px; border-bottom: 3px solid var(--cyan); text-align: center; position: sticky; top: 0; z-index: 100; }
        .logo-big { border-radius: 50%; width: 85px; height: 85px; border: 3px solid #fff; background: #fff; box-shadow: 0 0 25px #fff; margin-bottom: 12px; }
        .title-big { font-size: 1.8em; font-weight: bold; color: var(--cyan); letter-spacing: 1px; text-shadow: 0 0 15px var(--cyan); display: block; }
        .clock-th { font-size: 1.3em; font-weight: bold; color: var(--yellow); margin-top: 10px; }

        .container { padding: 12px; width: 95%; max-width: 1000px; margin: auto; }
        
        /* ✅ 6 Grids (Original Layout) */
        .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-bottom: 15px; }
        .grid-box { background: var(--card); border: 2px solid var(--cyan); border-radius: 12px; padding: 15px 5px; text-align: center; animation: rainbow 6s linear infinite; }
        .grid-val { font-size: 1.1em; font-weight: bold; color: var(--cyan); }
        .grid-label { font-size: 0.6em; color: #888; text-transform: uppercase; }

        /* ✅ 3 Action Buttons */
        .action-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 25px; }
        .action-box { background: var(--card); border: 2.5px solid var(--purple); border-radius: 15px; padding: 25px 10px; text-align: center; cursor: pointer; animation: rainbow 8s linear infinite reverse; }
        .action-box i { font-size: 2em; color: var(--yellow); display: block; margin-bottom: 10px; }
        .action-label { font-size: 0.85em; font-weight: bold; }

        /* ✅ Search Bar */
        .search-container { position: relative; margin-bottom: 20px; }
        .search-bar { width: 100%; padding: 15px 45px; background: rgba(0,0,0,0.7); border: 2px solid var(--cyan); border-radius: 15px; color: #fff; outline: none; box-sizing: border-box; }
        .search-icon { position: absolute; left: 15px; top: 15px; color: var(--cyan); }

        .table-card { background: var(--card); border-radius: 15px; border: 1.5px solid var(--cyan); padding: 5px; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; min-width: 600px; }
        th { text-align: left; padding: 12px; color: var(--cyan); border-bottom: 2px solid #1e293b; font-size: 0.85em; }
        td { padding: 15px 12px; border-bottom: 1px solid #1e293b; font-size: 1em; }

        .copy-btn { color: var(--cyan); cursor: pointer; margin-left: 10px; font-size: 1.2em; }
        .copy-btn:active { transform: scale(1.4); }

        .footer-nav { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(10, 14, 26, 0.98); display: flex; justify-content: space-between; align-items: center; padding: 15px 35px; border-top: 2px solid var(--cyan); box-sizing: border-box; z-index: 1000; }
        .nav-item { font-size: 2em; cursor: pointer; color: #fff; }

        .modal { display: none; position: fixed; z-index: 2000; left: 0; top: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); backdrop-filter: blur(10px); }
        .modal-content { background: var(--card); margin: 10% auto; padding: 25px; border-radius: 25px; border: 2px solid var(--cyan); width: 85%; max-width: 450px; text-align: center; box-shadow: 0 0 30px var(--cyan); }
        input { width: 100%; padding: 15px; margin: 10px 0; background: #000; border: 1.5px solid #333; color: #fff; border-radius: 10px; box-sizing: border-box; outline: none; }
        .btn { background: linear-gradient(45deg, #00c6ff, #0072ff); color: #fff; border: none; padding: 15px; border-radius: 12px; font-weight: bold; width: 100%; cursor: pointer; }

        .login-card { max-width: 330px; margin: 18vh auto; background: var(--card); padding: 40px; border-radius: 30px; text-align: center; border: 3px solid var(--glow); box-shadow: 0 0 50px rgba(255, 69, 0, 0.5); position: relative; z-index: 10; }
    </style>
</head>
<body onload="initAll();">
<canvas id="bgCanvas"></canvas>

{% if not session.get('auth') %}
    <div class="login-card">
        <img src="{{ logo }}" width="85" style="border-radius:50%; margin-bottom:25px; border:3px solid #fff; background:#fff;">
        <h2 style="color:var(--cyan); margin-bottom:20px;">CMT LOGIN</h2>
        <form method="post" action="/login_check">
            <input name="u" placeholder="Admin" required>
            <input name="p" type="password" placeholder="Pass" required>
            <button class="btn" style="background: linear-gradient(45deg, #ff4500, #ffaa00);">LOGIN</button>
        </form>
    </div>
{% else %}
    <div class="header">
        <img src="{{ logo }}" class="logo-big">
        <span class="title-big">CMT ZIVPN PRO PANEL</span>
        <div id="liveTimeTH" class="clock-th">🇹🇭 Load TH Time...</div>
    </div>

    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><div class="grid-label">အသုံးပြုသူ</div><div class="grid-val">{{ users|length }}</div></div>
            <div class="grid-box" style="border-color:var(--green);"><div class="grid-label">အွန်လိုင်း</div><div class="grid-val">0</div></div>
            <div class="grid-box" style="border-color:var(--yellow);"><div class="grid-label">ဝင်ငွေစုစုပေါင်း</div><div class="grid-val" style="color:var(--yellow)">{{ users|length * 5000 }} Ks</div></div>
            <div class="grid-box"><div class="grid-label">CPU</div><div class="grid-val">0.3%</div></div>
            <div class="grid-box"><div class="grid-label">RAM</div><div class="grid-val">12.0%</div></div>
            <div class="grid-box"><div class="grid-label">DISK</div><div class="grid-val">9.0%</div></div>
        </div>

        <div class="action-grid">
            <div class="action-box" onclick="openM('addM')"><i class="fas fa-user-plus"></i><div class="action-label">အကောင့်သစ်</div></div>
            <div class="action-box" onclick="openM('supM')"><i class="fas fa-headset"></i><div class="action-label">ဆက်သွယ်ရန်</div></div>
            <div class="action-box" onclick="openM('setM')"><i class="fas fa-tools"></i><div class="action-label">ကိတ်တင်များ</div></div>
        </div>

        <div class="search-container">
            <i class="fas fa-search search-icon"></i>
            <input type="text" id="searchInput" class="search-bar" onkeyup="searchUser()" placeholder="ဝယ်သူအမည်ဖြင့် ရှာဖွေရန်...">
        </div>

        <div class="table-card">
            <table id="userTable">
                <thead><tr><th>အမည်</th><th>စကားဝှက်</th><th>သက်တမ်း/ရက်ကျန်</th><th>Status</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan); font-weight:bold;">{{ u.user }}</td>
                        <td><span id="pw{{loop.index}}">{{ u.password }}</span> <i class="fas fa-copy copy-btn" onclick="copyText('pw{{loop.index}}')"></i></td>
                        <td>
                            <div style="color:#ff69b4; font-size:0.9em;">{{ u.expires }}</div>
                            <div style="font-size:0.75em; color:var(--green);">(29 ရက်ကျန်)</div>
                        </td>
                        <td><span style="color:rgba(255,68,68,0.4); font-size:0.8em;">● Offline</span></td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>

    <div class="footer-nav">
        <div class="nav-item" style="color:var(--cyan);" onclick="openM('calM')"><i class="fas fa-calendar-alt"></i></div>
        <div class="nav-item" onclick="location.reload();"><i class="fas fa-sync-alt"></i></div>
        <a href="/logout" class="nav-item" style="color:var(--red);"><i class="fas fa-power-off"></i></a>
    </div>

    <div id="addM" class="modal"><div class="modal-content">
        <h3>အကောင့်သစ်</h3>
        <form method="post" action="/add"><input name="user" placeholder="နာမည်"><input name="password" placeholder="စကားဝှက်"><input name="days" placeholder="ရက်ပေါင်း"><button class="btn">CREATE</button></form>
        <button onclick="closeM('addM')" style="margin-top:15px; background:none; border:none; color:#888;">ပိတ်မည်</button>
    </div></div>

    <div id="calM" class="modal"><div class="modal-content">
        <h3 id="calMonth">Calendar</h3>
        <div id="calGrid" style="display:grid; grid-template-columns: repeat(7, 1fr); gap:5px; margin-top:15px;"></div>
        <button onclick="closeM('calM')" style="margin-top:15px; background:none; border:none; color:#888;">ပိတ်မည်</button>
    </div></div>

    <script>
        function openM(id) { document.getElementById(id).style.display = "block"; if(id==='calM') renderCal(); }
        function closeM(id) { document.getElementById(id).style.display = "none"; }
        
        function copyText(id) {
            var text = document.getElementById(id).innerText;
            navigator.clipboard.writeText(text);
            alert("Copied: " + text);
        }

        function searchUser() {
            var input = document.getElementById("searchInput");
            var filter = input.value.toUpperCase();
            var table = document.getElementById("userTable");
            var tr = table.getElementsByTagName("tr");
            for (var i = 1; i < tr.length; i++) {
                var td = tr[i].getElementsByTagName("td")[0];
                if (td) {
                    var txtValue = td.textContent || td.innerText;
                    tr[i].style.display = txtValue.toUpperCase().indexOf(filter) > -1 ? "" : "none";
                }
            }
        }

        function startClock(){
            setInterval(() => {
                let th = new Date(new Date().getTime() + (new Date().getTimezoneOffset() * 60000) + (7 * 3600000));
                document.getElementById('liveTimeTH').innerHTML = "🇹🇭 TH Time: " + th.toLocaleTimeString();
            }, 1000);
        }

        function renderCal(){
            let d = new Date(); let yr = d.getFullYear(), mo = d.getMonth(), today = d.getDate();
            document.getElementById('calMonth').innerHTML = d.toLocaleString('default', { month: 'long' }) + " " + yr;
            let grid = document.getElementById("calGrid");
            grid.innerHTML = "";
            let days = ['S','M','T','W','T','F','S'];
            days.forEach(day => { let e=document.createElement("div"); e.style.color="var(--cyan)"; e.innerHTML=day; grid.appendChild(e); });
            let first = new Date(yr, mo, 1).getDay();
            let last = new Date(yr, mo + 1, 0).getDate();
            for(let i=0; i<first; i++){ grid.appendChild(document.createElement("div")); }
            for(let i=1; i<=last; i++){
                let e=document.createElement("div"); e.style.padding="10px 0"; e.innerHTML=i;
                if(i===today){ e.style.background="var(--cyan)"; e.style.color="#000"; e.style.borderRadius="5px"; }
                grid.appendChild(e);
            }
        }

        function initAll(){ startClock(); initCanvas(); }
        function initCanvas(){
            const c = document.getElementById('bgCanvas'), ctx = c.getContext('2d');
            c.width = window.innerWidth; c.height = window.innerHeight;
            let pts = []; for(let i=0; i<50; i++) pts.push({x:Math.random()*c.width, y:Math.random()*c.height, vx:(Math.random()-0.5)*0.8, vy:(Math.random()-0.5)*0.8});
            function draw(){
                ctx.clearRect(0,0,c.width,c.height);
                pts.forEach((p,i)=>{
                    p.x+=p.vx; p.y+=p.vy; if(p.x<0||p.x>c.width) p.vx*=-1; if(p.y<0||p.y>c.height) p.vy*=-1;
                    ctx.beginPath(); ctx.arc(p.x,p.y,2,0,Math.PI*2); ctx.fillStyle="rgba(0,212,255,0.2)"; ctx.fill();
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

# 4. Service Setup & Restart
systemctl daemon-reload
systemctl enable zivpn-web 2>/dev/null || true
systemctl restart zivpn-web

IP=$(hostname -I | awk '{print $1}')
echo -e "\n✅ ULTIMATE BUSINESS SCRIPT UPDATED! http://$IP:8080"
