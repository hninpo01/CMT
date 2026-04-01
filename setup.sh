#!/bin/bash
# CMT ZIVPN PRO - FINAL RE-FIX (NO ERROR)
set -euo pipefail

# Dependencies
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl >/dev/null

# Directory & Env
mkdir -p /etc/zivpn
USERS="/etc/zivpn/users.json"; ENVF="/etc/zivpn/web.env"
echo "WEB_ADMIN_USER=admin" > "$ENVF"
echo "WEB_ADMIN_PASSWORD=admin" >> "$ENVF"
echo "WEB_SECRET=$(openssl rand -hex 16)" >> "$ENVF"

# Python Web Script
cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, hmac, datetime
from flask import Flask, render_template_string, request, redirect, session

app = Flask(__name__)
app.secret_key = os.environ.get("WEB_SECRET")
ADMIN_USER = os.environ.get("WEB_ADMIN_USER")
ADMIN_PASS = os.environ.get("WEB_ADMIN_PASSWORD")
OFFICIAL_LOGO = "https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png"

def get_usage(port):
    if not port: return "0.0 MB"
    try:
        out = subprocess.run(f"iptables -L ZIVPN_TRAFFIC -n -v -x | grep 'dpt:{port}'", shell=True, capture_output=True, text=True).stdout
        total = sum(int(l.split()[1]) for l in out.strip().split('\n') if l)
        return f"{round(total/1024**2, 2)} MB" if total < 1024**3 else f"{round(total/1024**3, 2)} GB"
    except: return "0.0 MB"

def get_uptime():
    try:
        with open('/proc/uptime', 'r') as f:
            up = float(f.readline().split()[0])
            h, r = divmod(int(up), 3600); m, s = divmod(r, 60)
            return f"{h}:{m:02d}"
    except: return "0:00"

HTML = """<!doctype html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CMT ZIVPN</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
<style>
    :root { --bg: #050810; --card: rgba(16, 22, 42, 0.9); --glow: #ff4500; --cyan: #00d4ff; --yellow: #ffaa00; --green: #2ecc71; --purple: #9b59b6; }
    body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 80px; overflow-x: hidden; }
    #bgCanvas { position: fixed; top:0; left:0; width:100%; height:100%; z-index:-1; }
    @keyframes rainbowBG { 0% { background-position: 0% 50%; } 50% { background-position: 100% 50%; } 100% { background-position: 0% 50%; } }
    .rainbow-text { font-weight: bold; background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #9b59b6, #ff0000); background-size: 300% 300%; -webkit-background-clip: text; -webkit-text-fill-color: transparent; animation: rainbowBG 5s linear infinite; }
    .title-container { text-align: center; padding: 15px 0; border-bottom: 2px solid var(--cyan); background: rgba(0,0,0,0.6); backdrop-filter: blur(10px); }
    .header { background: rgba(0,0,0,0.5); padding: 10px 15px; display: flex; align-items: center; justify-content: space-between; }
    .header img { border-radius: 50%; width: 40px; height: 40px; background: #fff; box-shadow: 0 0 10px #fff; }
    .clock-center { flex-grow: 1; text-align: center; }
    .social-row { display: flex; gap: 8px; }
    .btn-social { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border-radius: 50%; color: white; text-decoration: none; font-size: 1.1em; }
    .container { padding: 15px; }
    .grid-menu { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin-bottom: 15px; }
    .grid-box { background: var(--card); border: 2px solid var(--glow); border-radius: 12px; padding: 10px; text-align: center; }
    .grid-box.full { grid-column: span 2; border-color: var(--purple); }
    .card { background: var(--card); padding: 20px; border-radius: 20px; border: 2.5px solid var(--glow); margin-bottom: 15px; }
    input { width: 100%; padding: 15px; margin: 10px 0; background: linear-gradient(90deg, #ff000022, #00d4ff22); background-size: 400%; animation: rainbowBG 8s infinite; color: #fff; border: 2px solid var(--cyan); border-radius: 12px; outline: none; box-sizing: border-box; }
    .main-btn { background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #ff0000); background-size: 300%; animation: rainbowBG 4s linear infinite; color: #fff; border: none; padding: 15px; border-radius: 12px; font-weight: bold; width: 100%; cursor: pointer; }
    .table-card { background: var(--card); border-radius: 15px; border: 2.5px solid var(--cyan); padding: 10px; overflow-x: auto; }
    table { width: 100%; border-collapse: collapse; min-width: 500px; }
    th, td { padding: 10px; text-align: left; border-bottom: 1px solid #333; }
    .bottom-nav { position: fixed; bottom: 0; left: 0; width: 100%; background: #0a0e1a; display: flex; justify-content: space-around; padding: 15px 0; border-top: 2px solid var(--cyan); }
</style>
</head><body onload="startClock()">
<canvas id="bgCanvas"></canvas>
{% if not session.get('auth') %}
    <div style="max-width:320px; margin:20vh auto; background:var(--card); padding:35px; border-radius:20px; text-align:center; border:3px solid var(--glow);">
        <h2 class="rainbow-text">စီအမ်တီ လော့ဂ်အင်</h2>
        <form method="post" action="/login_check"><input name="u" placeholder="Admin"><input name="p" type="password" placeholder="Pass"><button class="main-btn">အကောင့်ဝင်ရန်</button></form>
    </div>
{% else %}
    <div class="title-container"><h1 class="main-title rainbow-text">CMT ZIVPN PRO</h1></div>
    <div class="header">
        <img src="{{logo}}">
        <div class="clock-center"><div id="liveTime" class="rainbow-text" style="font-size:1.1em;"></div><div id="liveDate" style="font-size:0.6em;color:#aaa;"></div></div>
        <div class="social-row">
            <a href="https://t.me/CMT_1411" class="btn-social" style="background:#0088cc;"><i class="fab fa-telegram-plane"></i></a>
            <a href="https://www.facebook.com/ChitMinThu1239" class="btn-social" style="background:#1877f2;"><i class="fab fa-facebook-f"></i></a>
            <a href="https://m.me/ChitMinThu1239" class="btn-social" style="background:linear-gradient(45deg,#00c6ff,#bc00ff);"><i class="fab fa-facebook-messenger"></i></a>
        </div>
    </div>
    <div class="container">
        <div style="text-align:center; margin-bottom:12px; background:rgba(0,0,0,0.6); padding:8px; border-radius:10px; border:1px solid var(--cyan); font-size:0.8em;">
            ဆာဗာ IP: <span id="sip">{{ip}}</span> <i class="fas fa-copy" style="cursor:pointer;" onclick="copyVal('sip')"></i>
        </div>
        <div class="grid-menu">
            <div class="grid-box"><div>အသုံးပြုသူ</div><div style="color:var(--yellow)">{{users|length}}</div></div>
            <div class="grid-box" style="border-color:var(--green);"><div>အွန်လိုင်း</div><div style="color:var(--green)">{{active_count}}</div></div>
            <div class="grid-box full"><div>ဆာဗာသက်တမ်း: <span style="color:var(--purple)">{{uptime}}</span></div></div>
            <div class="grid-box" style="border-color:#3498db;"><div>ဒေတာ</div><div style="color:#3498db">0.00</div></div>
            <div class="grid-box" style="border-color:#e67e22;"><div>ဝန်အား</div><div style="color:#e67e22">12%</div></div>
        </div>
        <div class="card">
            <form method="post" action="/add"><input name="user" placeholder="အမည် (မြန်မာလို)"><input name="password" placeholder="စကားဝှက်"><input name="days" placeholder="ရက်ပေါင်း"><button class="main-btn">အကောင့်ဆောက်မည်</button></form>
        </div>
        <div class="table-card">
            <table>
                <thead><tr><th>အမည်</th><th>စကားဝှက်</th><th>ဒေတာ</th><th>အခြေအနေ</th><th>ဖျက်</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan)">{{u.user}}</td>
                        <td><span id="pw{{loop.index}}">{{u.password}}</span> <i class="fas fa-copy" style="cursor:pointer;color:var(--cyan)" onclick="copyVal('pw{{loop.index}}')"></i></td>
                        <td style="color:var(--yellow)">{{u.usage}}</td>
                        <td><span style="color:{{ 'var(--green)' if u.online else '#e74c3c' }}">● {{ 'Online' if u.online else 'Offline' }}</span></td>
                        <td><form method="post" action="/delete" style="display:inline;"><input type="hidden" name="user" value="{{u.user}}"><button type="submit" style="color:#ff4444;background:none;border:none;cursor:pointer;"><i class="fas fa-trash-alt"></i></button></form></td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>
    <div class="bottom-nav"><a href="/" style="color:var(--cyan);font-size:1.5em;"><i class="fas fa-home"></i></a><a href="/logout" style="color:#555;font-size:1.5em;"><i class="fas fa-power-off"></i></a></div>
{% endif %}
<script>
    function copyVal(id){ var v=document.getElementById(id).innerText; var t=document.createElement("textarea"); document.body.appendChild(t); t.value=v; t.select(); document.execCommand("copy"); document.body.removeChild(t); alert("Copied: "+v); }
    function startClock(){ setInterval(function(){ var n=new Date(); var utc=n.getTime()+(n.getTimezoneOffset()*60000); var mm=new Date(utc+23400000); var h=mm.getHours(),m=mm.getMinutes(),s=mm.getSeconds(),ap=h>=12?'PM':'AM'; h=h%12||12; h=h<10?'0'+h:h; m=m<10?'0'+m:m; s=s<10?'0'+s:s; document.getElementById('liveTime').innerHTML=h+':'+m+':'+s+' '+ap; var ds=['တနင်္ဂနွေ','တနင်္လာ','အင်္ဂါ','ဗုဒ္ဓဟူး','ကြာသပတေး','သောကြာ','စနေ'], ms=['ဇန်နဝါရီ','ဖေဖော်ဝါရီ','မတ်','ဧပြီ','မေ','ဇွန်','ဇူလိုင်','သြဂုတ်','စက်တင်ဘာ','အောက်တိုဘာ','နိုဝင်ဘာ','ဒီဇင်ဘာ']; document.getElementById('liveDate').innerHTML=ds[mm.getDay()]+'၊ '+mm.getDate()+' '+ms[mm.getMonth()]+' '+mm.getFullYear(); }, 1000); }
    const cvs=document.getElementById('bgCanvas'),ctx=cvs.getContext('2d');
    let pts=[],hue=0; function init(){cvs.width=window.innerWidth;cvs.height=window.innerHeight;} window.onresize=init; init();
    class Pt{constructor(){this.x=Math.random()*cvs.width;this.y=Math.random()*cvs.height;this.vx=(Math.random()-0.5);this.vy=(Math.random()-0.5);this.r=Math.random()*2+1;} up(){this.x+=this.vx;this.y+=this.vy;if(this.x<0||this.x>cvs.width)this.vx*=-1;if(this.y<0||this.y>cvs.height)this.vy*=-1;} dr(){ctx.beginPath();ctx.arc(this.x,this.y,this.r,0,Math.PI*2);ctx.fillStyle='rgba(255,255,255,0.15)';ctx.fill();}}
    for(let i=0;i<60;i++)pts.push(new Pt());
    function anim(){ctx.clearRect(0,0,cvs.width,cvs.height);hue+=0.5;pts.forEach((p,i)=>{p.up();p.dr();for(let j=i+1;j<pts.length;j++){let d=Math.hypot(p.x-pts[j].x,p.y-pts[j].y);if(d<110){ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.lineTo(pts[j].x,pts[j].y);ctx.strokeStyle='hsla('+(hue+d)+',70%,60%,'+(1-d/110)*0.8+')';ctx.lineWidth=0.8;ctx.stroke();}}});requestAnimationFrame(anim);} anim();
</script></body></html>"""

@app.route("/")
def index():
    if not session.get("auth"): return render_template_string(HTML)
    u_list = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: u_list = json.load(f)
    active_count = 0
    conntrack = subprocess.run("conntrack -L -p udp 2>/dev/null", shell=True, capture_output=True, text=True).stdout
    for u in u_list:
        u["online"] = f"dport={u.get('port')}" in conntrack if u.get("port") else False
        u["usage"] = get_usage(u.get("port"))
        if u["online"]: active_count += 1
    ip = subprocess.run("curl -s icanhazip.com", shell=True, capture_output=True, text=True).stdout.strip()
    return render_template_string(HTML, users=u_list, active_count=active_count, ip=ip, uptime=get_uptime())

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
    u_list = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: u_list = json.load(f)
    port = str(max([int(x.get("port", 6000)) for x in u_list] + [6000]) + 1)
    u_list.insert(0, {"user":u, "password":p, "expires":exp, "port":port})
    with open("/etc/zivpn/users.json","w") as f: json.dump(u_list, f, indent=2, ensure_ascii=False)
    subprocess.run("systemctl restart zivpn", shell=True)
    return redirect("/")

@app.route("/delete", methods=["POST"])
def delete():
    if not session.get("auth"): return redirect("/")
    n = request.form.get("user")
    u_list = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: u_list = json.load(f)
    u_list = [x for x in u_list if x["user"] != n]
    with open("/etc/zivpn/users.json","w") as f: json.dump(u_list, f, indent=2, ensure_ascii=False)
    return redirect("/")

@app.route("/logout")
def logout(): session.clear(); return redirect("/")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
PY

# Systemd Service Fix
cat > /etc/systemd/system/zivpn-web.service <<EOF
[Unit]
Description=ZIVPN Web Service
After=network.target

[Service]
EnvironmentFile=/etc/zivpn/web.env
ExecStart=/usr/bin/python3 /etc/zivpn/web.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl restart zivpn-web
IP=$(hostname -I | awk '{print $1}')
echo -e "\n✅ Installation Success!"
echo -e "Web Panel: http://$IP:8080"
