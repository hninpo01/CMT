#!/bin/bash
# CMT ZIVPN PRO - FINAL LAYOUT & LOGO FIX
set -euo pipefail
apt-get update -y && apt-get install -y curl ufw jq python3 python3-flask conntrack iptables openssl >/dev/null

mkdir -p /etc/zivpn
BIN="/usr/local/bin/zivpn"; CFG="/etc/zivpn/config.json"; USERS="/etc/zivpn/users.json"; ENVF="/etc/zivpn/web.env"

echo "WEB_ADMIN_USER=admin" > "$ENVF"
echo "WEB_ADMIN_PASSWORD=admin" >> "$ENVF"
echo "WEB_SECRET=$(openssl rand -hex 16)" >> "$ENVF"

sysctl -w net.ipv4.ip_forward=1 >/dev/null
iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || true
iptables -t nat -A POSTROUTING -j MASQUERADE 2>/dev/null || true

cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, hmac, datetime
from flask import Flask, render_template_string, request, redirect, session, url_for

app = Flask(__name__)
app.secret_key = os.environ.get("WEB_SECRET")
ADMIN_USER = os.environ.get("WEB_ADMIN_USER")
ADMIN_PASS = os.environ.get("WEB_ADMIN_PASSWORD")
OFFICIAL_LOGO = "https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png"

def get_usage(port):
    if not port: return "0.0 MB"
    try:
        subprocess.run(f"iptables -L ZIVPN_TRAFFIC -n | grep -q 'dpt:{port}' || iptables -A ZIVPN_TRAFFIC -p udp --dport {port} -j RETURN", shell=True)
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
            mins, secs = divmod(rem, 60)
            return f"{hrs}နာရီ {mins}မိနစ်"
    except: return "0နာရီ 0မိနစ်"

HTML = """<!doctype html>
<html lang="my" translate="no">
<head>
    <meta charset="UTF-12"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>CMT ZIVPN PRO</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.88); --glow: #ff4500; --cyan: #00d4ff; --yellow: #ffaa00; --green: #2ecc71; --purple: #9b59b6; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; overflow-x: hidden; }
        #bgCanvas { position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: -1; background: #050810; }
        @keyframes rainbowBG { 0% { background-position: 0% 50%; } 50% { background-position: 100% 50%; } 100% { background-position: 0% 50%; } }
        .rainbow-text { font-weight: bold; background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #9b59b6, #ff0000); background-size: 300% 300%; -webkit-background-clip: text; -webkit-text-fill-color: transparent; animation: rainbowBG 5s linear infinite; }
        .title-container { text-align: center; padding: 15px 0; border-bottom: 2px solid var(--cyan); background: rgba(0,0,0,0.6); backdrop-filter: blur(10px); }
        .main-title { font-size: 2.2em; letter-spacing: 2px; text-shadow: 0 0 15px var(--cyan); }
        .header { background: rgba(0,0,0,0.5); padding: 10px 15px; display: flex; align-items: center; justify-content: space-between; backdrop-filter: blur(10px); }
        .header img { border-radius: 50%; border: 2px solid #fff; width: 45px; height: 45px; background: #fff; box-shadow: 0 0 10px #fff; }
        .clock-center { flex-grow: 1; text-align: center; display: flex; flex-direction: column; align-items: center; }
        .clock-time { font-size: 1.2em; font-weight: bold; text-shadow: 0 0 10px var(--cyan); }
        .social-row { display: flex; gap: 12px; }
        .btn-social { width: 38px; height: 38px; display: flex; align-items: center; justify-content: center; border-radius: 50%; color: white; text-decoration: none; font-size: 1.3em; transition: 0.3s; box-shadow: 0 0 10px rgba(255,255,255,0.2); }
        .container { padding: 15px; }
        .grid-menu { display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; margin-bottom: 20px; }
        .grid-box { background: var(--card); border: 2px solid var(--glow); border-radius: 15px; padding: 15px; text-align: center; backdrop-filter: blur(5px); }
        .grid-box.full { grid-column: span 2; border-color: var(--purple); }
        .grid-val { font-size: 1.4em; font-weight: bold; color: var(--yellow); text-shadow: 0 0 10px var(--yellow); }
        .grid-label { font-size: 0.7em; color: #aaa; text-transform: uppercase; }
        .card { background: var(--card); padding: 25px; border-radius: 20px; border: 2.5px solid var(--glow); margin-bottom: 20px; backdrop-filter: blur(5px); }
        input { width: 100%; padding: 15px 20px; margin: 12px 0; background: linear-gradient(90deg, #ff000022, #00d4ff22); background-size: 400%; animation: rainbowBG 8s infinite; color: #fff !important; border: 2px solid var(--cyan); border-radius: 12px; outline: none; font-weight: bold; }
        .main-btn { background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #ff0000); background-size: 300%; animation: rainbowBG 4s linear infinite; color: #fff; border: none; padding: 15px; border-radius: 12px; font-weight: bold; width: 100%; cursor: pointer; text-shadow: 1px 1px 5px #000; box-shadow: 0 0 15px rgba(255,0,0,0.4); }
        .table-card { background: var(--card); border-radius: 15px; border: 2.5px solid var(--cyan); padding: 12px; overflow-x: auto; backdrop-filter: blur(5px); }
        table { width: 100%; border-collapse: collapse; min-width: 550px; }
        th { text-align: left; padding: 12px; color: var(--cyan); border-bottom: 2px solid #1e293b; font-size: 0.8em; }
        td { padding: 15px 12px; border-bottom: 1px solid #1e293b; font-size: 0.9em; }
        .copy-btn { color: var(--cyan); cursor: pointer; margin-left: 8px; transition: 0.2s; }
        .copy-btn:active { transform: scale(1.4); color: var(--yellow); }
        .delete-btn { color: #ff4444; background: none; border: none; font-size: 1.2em; cursor: pointer; }
        .bottom-nav { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(10, 14, 26, 0.95); display: flex; justify-content: space-around; padding: 15px 0; border-top: 2px solid var(--cyan); backdrop-filter: blur(15px); }
        .nav-item { color: #555; font-size: 1.8em; }
        .nav-item.active { color: var(--cyan); text-shadow: 0 0 10px var(--cyan); }
    </style>
</head>
<body onload="startClock()">
<canvas id="bgCanvas"></canvas>
{% if not session.get('auth') %}
    <div style="max-width: 330px; margin: 18vh auto; background: var(--card); padding: 40px; border-radius: 30px; text-align: center; border: 3px solid var(--glow); box-shadow: 0 0 50px rgba(255, 69, 0, 0.7);">
        <img src="{{ logo }}" width="85" style="background:#fff; border-radius:20px; margin-bottom:25px; box-shadow: 0 0 15px #fff;">
        <h2 class="rainbow-text" style="font-size: 2em;">CMT LOGIN</h2>
        <form method="post" action="/login_check"><input name="u" placeholder="Admin Name" required><input name="p" type="password" placeholder="Admin Pass" required><button class="main-btn" style="margin-top:20px;">DASHBOARD LOGIN</button></form>
    </div>
{% else %}
    <div class="title-container"><h1 class="main-title rainbow-text">CMT ZIVPN PRO</h1></div>
    <div class="header">
        <div style="display:flex;align-items:center;gap:12px;">
            <img src="{{ logo }}" alt="LOGO" onerror="this.onerror=null; this.src='https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png';">
            <div class="clock-box" style="text-align:left;">
                <div id="liveTime" class="clock-time rainbow-text">00:00:00 AM</div>
                <div id="liveDate" style="font-size:0.65em; color:#aaa;">Loading...</div>
            </div>
        </div>
        <div class="social-row">
            <a href="https://t.me/CMT_1411" class="btn-social" style="background:#0088cc;"><i class="fab fa-telegram-plane"></i></a>
            <a href="https://www.facebook.com/ChitMinThu1239" class="btn-social" style="background:#1877f2;"><i class="fab fa-facebook-f"></i></a>
            <a href="https://m.me/ChitMinThu1239" class="btn-social" style="background:linear-gradient(45deg, #00c6ff, #bc00ff);"><i class="fab fa-facebook-messenger"></i></a>
        </div>
    </div>
    <div class="container">
        <div style="text-align:center; margin-bottom:15px; background: rgba(0,0,0,0.6); padding: 10px; border-radius: 12px; border: 1px solid var(--cyan);"><small>SERVER IP: <span id="sip">{{ ip }}</span> <i class="fas fa-copy copy-btn" onclick="copyValue('sip')"></i></small></div>
        <div class="grid-menu">
            <div class="grid-box"><div class="grid-label">အသုံးပြုသူစုစုပေါင်း</div><div class="grid-val">{{ users|length }}</div></div>
            <div class="grid-box" style="border-color:var(--green);"><div class="grid-label">Online</div><div class="grid-val" style="color:var(--green);">{{ active_count }}</div></div>
            <div class="grid-box full"><div class="grid-label">SYSTEM UPTIME: <span style="color:var(--purple); font-size:1.4em;">{{ uptime }}</span></div></div>
            <div class="grid-box" style="border-color:#3498db;"><div class="grid-label">Bandwidth</div><div class="grid-val" style="color:#3498db;">{{ total_usage }}</div></div>
            <div class="grid-box" style="border-color:#e67e22;"><div class="grid-label">Load</div><div class="grid-val" style="color:#e67e22;">12%</div></div>
        </div>
        <div class="card">
            <form method="post" action="/add"><input name="user" placeholder="Name" required><input name="password" placeholder="Pass" required><input name="days" placeholder="Days" required><button class="main-btn">CREATE USER</button></form>
        </div>
        <div class="table-card">
            <table>
                <thead><tr><th>အမည်</th><th>စကားဝှက်</th><th>ဒေတာ</th><th>သက်တမ်းကုန်ရက်</th><th>Status</th><th>Action</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan); font-weight:bold;">{{ u.user }}</td>
                        <td><span id="pw{{loop.index}}">{{ u.password }}</span> <i class="fas fa-copy copy-btn" style="font-size:0.8em;" onclick="copyValue('pw{{loop.index}}')"></i></td>
                        <td style="color:var(--yellow); font-weight:bold;">{{ u.usage }}</td>
                        <td style="color:#ff69b4;">{{ u.expires }}</td>
                        <td><i class="fas fa-circle" style="color:{{ 'var(--green)' if u.online else 'var(--glow)' }}; font-size:0.8em;"></i> {{ 'Online' if u.online else 'Offline' }}</td>
                        <td><form method="post" action="/delete" style="display:inline;" onsubmit="return confirm('ဖျက်မှာ သေချာလား?')"><input type="hidden" name="user" value="{{u.user}}"><button type="submit" class="delete-btn"><i class="fas fa-trash-alt"></i></button></form></td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>
    <div class="bottom-nav"><a href="/" class="nav-item active"><i class="fas fa-home"></i></a><a href="/logout" class="nav-item"><i class="fas fa-power-off"></i></a></div>
{% endif %}
<script>
    /* ✅ Advanced Copy Function (Works on all Browsers) */
    function copyValue(id) {
        var text = document.getElementById(id).innerText;
        var input = document.createElement("textarea");
        input.value = text;
        document.body.appendChild(input);
        input.select();
        document.execCommand("copy");
        document.body.removeChild(input);
        alert("Copied: " + text);
    }
    function startClock() { setInterval(function() { var now = new Date(); var utc = now.getTime() + (now.getTimezoneOffset() * 60000); var mmTime = new Date(utc + (6.5 * 3600000)); var h = mmTime.getHours(), m = mmTime.getMinutes(), s = mmTime.getSeconds(), ampm = h >= 12 ? 'PM' : 'AM'; h = h % 12; h = h ? h : 12; h = h < 10 ? '0'+h : h; m = m < 10 ? '0'+m : m; s = s < 10 ? '0'+s : s; document.getElementById('liveTime').innerHTML = h + ':' + m + ':' + s + ' ' + ampm; var ds = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'], ms = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']; document.getElementById('liveDate').innerHTML = ds[mmTime.getDay()] + ', ' + mmTime.getDate() + ' ' + ms[mmTime.getMonth()] + ' ' + mmTime.getFullYear(); }, 1000); }
    const canvas = document.getElementById('bgCanvas'), ctx = canvas.getContext('2d');
    let pts = [], hue = 0;
    function init() { canvas.width = window.innerWidth; canvas.height = window.innerHeight; }
    window.onresize = init; init();
    class Pt { constructor() { this.x = Math.random()*canvas.width; this.y = Math.random()*canvas.height; this.vx = (Math.random()-0.5)*1.2; this.vy = (Math.random()-0.5)*1.2; this.radius = Math.random()*2.8 + 1; } up() { this.x+=this.vx; this.y+=this.vy; if(this.x<0||this.x>canvas.width)this.vx*=-1; if(this.y<0||this.y>canvas.height)this.vy*=-1; } dr() { ctx.beginPath(); ctx.arc(this.x,this.y,this.radius,0,Math.PI*2); ctx.fillStyle='rgba(255, 255, 255, 0.15)'; ctx.fill(); } }
    for(let i=0;i<75;i++) pts.push(new Pt()); 
    function anim() { ctx.clearRect(0,0,canvas.width,canvas.height); hue += 0.5; pts.forEach((p,i)=>{ p.up(); p.dr(); for(let j=i+1;j<pts.length;j++){ let d = Math.hypot(p.x-pts[j].x, p.y-pts[j].y); if(d<130){ ctx.beginPath(); ctx.moveTo(p.x,p.y); ctx.lineTo(pts[j].x,pts[j].y); ctx.strokeStyle='hsla('+(hue + d)+', 70%, 60%, '+(1-d/130)+')'; ctx.lineWidth=1.0; ctx.stroke(); } } }); requestAnimationFrame(anim); } anim();
</script></body></html>"""

@app.route("/")
def index():
    if not session.get("auth"): return render_template_string(HTML, logo=OFFICIAL_LOGO)
    users = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: users = json.load(f)
    conntrack = subprocess.run("conntrack -L -p udp 2>/dev/null", shell=True, capture_output=True, text=True).stdout
    active_count = 0
    for u in users:
        u["usage"] = get_usage(u.get("port"))
        u["online"] = f"dport={u.get('port')}" in conntrack if u.get("port") else False
        if u["online"]: active_count += 1
    ip = subprocess.run("curl -s icanhazip.com", shell=True, capture_output=True, text=True).stdout.strip()
    return render_template_string(HTML, logo=OFFICIAL_LOGO, users=users, active_count=active_count, ip=ip, uptime=get_uptime(), total_usage="0.00")

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
    with open("/etc/zivpn/users.json","w") as f: json.dump(users, f, indent=2, ensure_ascii=False)
    subprocess.run("systemctl restart zivpn", shell=True)
    return redirect("/")

@app.route("/delete", methods=["POST"])
def delete():
    if not session.get("auth"): return redirect("/")
    name = request.form.get("user")
    with open("/etc/zivpn/users.json","r") as f: users = json.load(f)
    users = [x for x in users if x["user"] != name]
    with open("/etc/zivpn/users.json","w") as f: json.dump(users, f, indent=2, ensure_ascii=False)
    return redirect("/")

@app.route("/logout")
def logout(): session.clear(); return redirect("/")

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

systemctl daemon-reload && systemctl restart zivpn-web
IP=$(hostname -I | awk '{print $1}')
echo -e "\n✅ Myanmar Version SUCCESS! (All Features Fixed)"
echo -e "Panel: http://$IP:8080"
