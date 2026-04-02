#!/bin/bash
# CMT ZIVPN PRO - FINAL MASTER FIX (ALL FEATURES INCLUDED)
set -euo pipefail
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl python3-pip >/dev/null
pip3 install psutil requests >/dev/null

mkdir -p /etc/zivpn
ENVF="/etc/zivpn/web.env"
USERS="/etc/zivpn/users.json"

# Initialize env file with default support links
if [ ! -f "$ENVF" ]; then
    echo "WEB_ADMIN_USER=admin" > "$ENVF"
    echo "WEB_ADMIN_PASSWORD=admin" >> "$ENVF"
    echo "WEB_SECRET=$(openssl rand -hex 16)" >> "$ENVF"
    echo "SUPPORT_TG=https://t.me/CMT_1411" >> "$ENVF"
    echo "SUPPORT_FB=https://www.facebook.com/ChitMinThu1239" >> "$ENVF"
    echo "SUPPORT_MSG=https://m.me/ChitMinThu1239" >> "$ENVF"
fi

cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, hmac, datetime, requests, psutil
from flask import Flask, render_template_string, request, redirect, session, url_for

app = Flask(__name__)
app.secret_key = os.environ.get("WEB_SECRET")
OFFICIAL_LOGO = "https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png"

def get_env(key):
    try:
        with open("/etc/zivpn/web.env", "r") as f:
            for line in f:
                if line.startswith(key): return line.split("=")[1].strip()
    except: pass
    return ""

def set_env(key, value):
    lines = []
    if os.path.exists("/etc/zivpn/web.env"):
        with open("/etc/zivpn/web.env", "r") as f: lines = f.readlines()
    with open("/etc/zivpn/web.env", "w") as f:
        found = False
        for line in lines:
            if line.startswith(key): f.write(f"{key}={value}\n"); found = True
            else: f.write(line)
        if not found: f.write(f"{key}={value}\n")

def get_sys_info():
    return {"cpu": psutil.cpu_percent(), "ram": psutil.virtual_memory().percent, "disk": psutil.disk_usage('/').percent}

HTML = """<!doctype html>
<html lang="my"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CMT ZIVPN PRO</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
<style>
    :root { --bg: #050810; --card: rgba(16, 22, 42, 0.9); --glow: #ff4500; --cyan: #00d4ff; --yellow: #ffaa00; --green: #2ecc71; --purple: #9b59b6; }
    body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; overflow-x: hidden; }
    #bgCanvas { position: fixed; top:0; left:0; width:100%; height:100%; z-index:-1; background: #050810; }
    @keyframes rb { 0%{background-position:0% 50%} 50%{background-position:100% 50%} 100%{background-position:0% 50%} }
    .rainbow-text { font-weight: bold; background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #9b59b6, #ff0000); background-size: 300% 300%; -webkit-background-clip: text; -webkit-text-fill-color: transparent; animation: rb 5s linear infinite; }
    .header { background: rgba(0,0,0,0.6); padding: 10px 15px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); backdrop-filter: blur(10px); }
    .logo-img { border-radius: 50%; width: 55px; height: 55px; background: #fff; border: 2px solid #fff; box-shadow: 0 0 10px #fff; }
    .clock-center { flex-grow: 1; text-align: center; }
    .container { padding: 15px; }
    .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 15px; }
    .grid-box { background: var(--card); border: 2px solid var(--glow); border-radius: 12px; padding: 10px; text-align: center; }
    .card { background: var(--card); padding: 20px; border-radius: 15px; border: 1.5px solid var(--glow); margin-bottom: 15px; }
    input { width: 100%; padding: 12px; margin: 8px 0; background: #000; color: #fff; border: 1.5px solid var(--cyan); border-radius: 10px; box-sizing: border-box; outline: none; }
    .main-btn { background: linear-gradient(90deg, #ff0000, #ffaa00, #00d4ff); padding: 12px; border: none; border-radius: 10px; color: #fff; width: 100%; font-weight: bold; cursor: pointer; }
    .table-card { background: var(--card); border-radius: 12px; border: 1.5px solid var(--cyan); overflow-x: auto; padding: 10px; }
    table { width: 100%; border-collapse: collapse; min-width: 600px; }
    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #333; font-size: 0.9em; }
    .support-row { display: flex; justify-content: center; gap: 10px; margin-top: 20px; padding: 10px; }
    .btn-support { padding: 10px 15px; border-radius: 10px; text-decoration: none; color: white; font-weight: bold; font-size: 0.9em; display: flex; align-items: center; gap: 5px; }
    .bottom-nav { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(10,14,26,0.95); display: flex; justify-content: space-around; padding: 15px 0; border-top: 2px solid var(--cyan); }
</style>
</head><body onload="startClock()">
<canvas id="bgCanvas"></canvas>
{% if not session.get('auth') %}
    <div style="max-width:320px; margin:20vh auto; background:var(--card); padding:35px; border-radius:20px; text-align:center; border:3px solid var(--glow);">
        <img src="{{logo}}" width="80" style="background:#fff; border-radius:15px; margin-bottom:20px;">
        <h2 class="rainbow-text">CMT LOGIN</h2>
        <form method="post" action="/login_check"><input name="u" placeholder="Admin"><input name="p" type="password" placeholder="Pass"><button class="main-btn">LOGIN</button></form>
    </div>
{% else %}
    <div class="header">
        <img src="{{logo}}" class="logo-img">
        <div class="clock-center"><div id="liveTime" class="rainbow-text" style="font-size:1.3em;"></div><div id="liveDate" style="font-size:0.7em;color:#aaa;"></div></div>
        <a href="/settings" style="color:var(--cyan);font-size:1.5em;"><i class="fas fa-cog"></i></a>
    </div>
    <div class="container">
        <div class="grid-menu">
            <div class="grid-box" style="border-color:var(--cyan);"><small>CPU</small><div style="color:var(--cyan)">{{sys.cpu}}%</div></div>
            <div class="grid-box" style="border-color:var(--yellow);"><small>RAM</small><div style="color:var(--yellow)">{{sys.ram}}%</div></div>
            <div class="grid-box" style="border-color:var(--green);"><small>DISK</small><div style="color:var(--green)">{{sys.disk}}%</div></div>
        </div>
        <div class="card">
            <form method="post" action="/add"><input name="user" placeholder="အမည်"><input name="password" placeholder="စကားဝှက်"><input name="days" placeholder="ရက်ပေါင်း"><button class="main-btn">အကောင့်ဆောက်မည်</button></form>
        </div>
        <div class="table-card">
            <table>
                <thead><tr><th>အမည်</th><th>စကားဝှက်</th><th>သက်တမ်းကုန်</th><th>Status</th><th>Action</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan); font-weight:bold;">{{u.user}}</td>
                        <td>{{u.password}} <i class="fas fa-copy" style="cursor:pointer;color:var(--cyan)" onclick="copyVal('{{u.password}}')"></i></td>
                        <td style="color:#ff69b4">{{u.expires}}</td>
                        <td><span style="color:{{ 'var(--green)' if u.online else '#ff4444' }}">● {{ 'Online' if u.online else 'Offline' }}</span></td>
                        <td>
                            <div style="display:flex;gap:12px;">
                                <form method="post" action="/renew"><input type="hidden" name="user" value="{{u.user}}"><button style="background:none;border:none;color:var(--yellow);cursor:pointer;"><i class="fas fa-history"></i></button></form>
                                <i class="fas fa-share-alt" style="color:var(--cyan);cursor:pointer;" onclick="copyVal('v2ray://{{u.user}}:{{u.password}}@{{ip}}:443#CMT-{{u.user}}')"></i>
                                <form method="post" action="/delete" onsubmit="return confirm('ဖျက်မှာလား?')"><input type="hidden" name="user" value="{{u.user}}"><button style="background:none;border:none;color:#ff4444;cursor:pointer;"><i class="fas fa-trash"></i></button></form>
                            </div>
                        </td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>

        <div class="support-row">
            <a href="{{tg}}" target="_blank" class="btn-support" style="background:#0088cc;"><i class="fab fa-telegram-plane"></i> Telegram</a>
            <a href="{{fb}}" target="_blank" class="btn-support" style="background:#1877f2;"><i class="fab fa-facebook-f"></i> Facebook</a>
            <a href="{{msg}}" target="_blank" class="btn-support" style="background:linear-gradient(45deg,#00c6ff,#bc00ff);"><i class="fab fa-facebook-messenger"></i> Messenger</a>
        </div>
    </div>
    <div class="bottom-nav">
        <a href="/" style="color:var(--cyan);font-size:1.8em;"><i class="fas fa-home"></i></a>
        <a href="/logout" style="color:#ff4444;font-size:1.8em;"><i class="fas fa-power-off"></i></a>
    </div>
{% endif %}
<script>
    function copyVal(v){ var t=document.createElement("textarea");document.body.appendChild(t);t.value=v;t.select();document.execCommand("copy");document.body.removeChild(t);alert("Copied!"); }
    function startClock(){ setInterval(function(){ var n=new Date(); var mm=new Date(n.getTime()+(n.getTimezoneOffset()*60000)+23400000); var h=mm.getHours(),m=mm.getMinutes(),s=mm.getSeconds(),ap=h>=12?'PM':'AM'; h=h%12||12; h=h<10?'0'+h:h; m=m<10?'0'+m:m; s=s<10?'0'+s:s; document.getElementById('liveTime').innerHTML=h+':'+m+':'+s+' '+ap; document.getElementById('liveDate').innerHTML=mm.toDateString(); }, 1000); }
    const cvs=document.getElementById('bgCanvas'),ctx=cvs.getContext('2d');
    let pts=[],hue=0; function init(){cvs.width=window.innerWidth;cvs.height=window.innerHeight;} window.onresize=init; init();
    class Pt{constructor(){this.x=Math.random()*cvs.width;this.y=Math.random()*cvs.height;this.vx=(Math.random()-0.5);this.vy=(Math.random()-0.5);this.r=Math.random()*2+1;} up(){this.x+=this.vx;this.y+=this.vy;if(this.x<0||this.x>cvs.width)this.vx*=-1;if(this.y<0||this.y>cvs.height)this.vy*=-1;} dr(){ctx.beginPath();ctx.arc(this.x,this.y,this.r,0,Math.PI*2);ctx.fill();}}
    for(let i=0;i<60;i++)pts.push(new Pt());
    function anim(){ctx.clearRect(0,0,cvs.width,cvs.height);hue+=0.5;pts.forEach((p,i)=>{p.up();p.dr();for(let j=i+1;j<pts.length;j++){let d=Math.hypot(p.x-pts[j].x,p.y-pts[j].y);if(d<110){ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.lineTo(pts[j].x,pts[j].y);ctx.strokeStyle='hsla('+(hue+d)+',70%,60%,'+(1-d/110)*0.8+')';ctx.lineWidth=0.8;ctx.stroke();}}});requestAnimationFrame(anim);} anim();
</script></body></html>"""

SETTINGS_HTML = """<!doctype html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
<style>
    body { background: #050810; color: #fff; font-family: sans-serif; padding: 20px; }
    .card { background: rgba(16, 22, 42, 0.9); padding: 15px; border-radius: 12px; border: 1.5px solid #ff4500; margin-bottom: 15px; }
    input { width: 100%; padding: 10px; margin: 8px 0; background: #000; color: #fff; border: 1px solid #00d4ff; border-radius: 8px; box-sizing: border-box; }
    .btn { background: #00d4ff; padding: 10px; border: none; border-radius: 8px; width: 100%; font-weight: bold; cursor: pointer; color: #000; }
</style>
</head><body>
    <h2><i class="fas fa-cog"></i> Settings</h2>
    <div class="card">
        <h4>Support Links</h4>
        <form method="post" action="/update_links">
            <input name="tg" placeholder="Telegram Link" value="{{tg}}">
            <input name="fb" placeholder="Facebook Link" value="{{fb}}">
            <input name="msg" placeholder="Messenger Link" value="{{msg}}">
            <button class="btn">Save Links</button>
        </form>
    </div>
    <a href="/" style="color:#aaa; text-decoration:none;"><i class="fas fa-arrow-left"></i> Back to Home</a>
</body></html>"""

@app.route("/")
def index():
    if not session.get("auth"): return render_template_string(HTML, logo=OFFICIAL_LOGO)
    u_list = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: u_list = json.load(f)
    conntrack = subprocess.run("conntrack -L -p udp 2>/dev/null", shell=True, capture_output=True, text=True).stdout
    for u in u_list: u["online"] = f"dport={u.get('port')}" in conntrack
    active_count = sum(1 for u in u_list if u["online"])
    ip = subprocess.run("curl -s icanhazip.com", shell=True, capture_output=True, text=True).stdout.strip()
    return render_template_string(HTML, users=u_list, active_count=active_count, ip=ip, logo=OFFICIAL_LOGO, sys=get_sys_info(), tg=get_env("SUPPORT_TG"), fb=get_env("SUPPORT_FB"), msg=get_env("SUPPORT_MSG"))

@app.route("/login_check", methods=["POST"])
def login_check():
    if hmac.compare_digest(request.form.get("u"), get_env("WEB_ADMIN_USER")) and hmac.compare_digest(request.form.get("p"), get_env("WEB_ADMIN_PASSWORD")):
        session["auth"] = True
    return redirect("/")

@app.route("/settings")
def settings():
    if not session.get("auth"): return redirect("/")
    return render_template_string(SETTINGS_HTML, tg=get_env("SUPPORT_TG"), fb=get_env("SUPPORT_FB"), msg=get_env("SUPPORT_MSG"))

@app.route("/update_links", methods=["POST"])
def update_links():
    if session.get("auth"):
        set_env("SUPPORT_TG", request.form.get("tg"))
        set_env("SUPPORT_FB", request.form.get("fb"))
        set_env("SUPPORT_MSG", request.form.get("msg"))
    return redirect("/settings")

@app.route("/add", methods=["POST"])
def add():
    if not session.get("auth"): return redirect("/")
    u, p, d = request.form.get("user"), request.form.get("password"), request.form.get("days")
    exp = (datetime.datetime.now() + datetime.timedelta(days=int(d))).strftime("%Y-%m-%d")
    u_list = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: u_list = json.load(f)
    port = str(max([int(x.get("port", 6000)) for x in u_list] + [6000]) + 1)
    u_list.insert(0, {"user":u, "password":p, "expires":exp, "port":port})
    with open("/etc/zivpn/users.json","w") as f: json.dump(u_list, f, indent=2, ensure_ascii=False)
    subprocess.run("systemctl restart zivpn", shell=True)
    return redirect("/")

@app.route("/renew", methods=["POST"])
def renew():
    if not session.get("auth"): return redirect("/")
    name = request.form.get("user")
    with open("/etc/zivpn/users.json", "r") as f: users = json.load(f)
    for u in users:
        if u["user"] == name:
            cur_exp = datetime.datetime.strptime(u['expires'], '%Y-%m-%d')
            u['expires'] = (cur_exp + datetime.timedelta(days=30)).strftime('%Y-%m-%d'); break
    with open("/etc/zivpn/users.json", "w") as f: json.dump(users, f, indent=2, ensure_ascii=False)
    return redirect("/")

@app.route("/delete", methods=["POST"])
def delete():
    if not session.get("auth"): return redirect("/")
    n = request.form.get("user")
    with open("/etc/zivpn/users.json","r") as f: u_list = json.load(f)
    u_list = [x for x in u_list if x["user"] != n]
    with open("/etc/zivpn/users.json","w") as f: json.dump(u_list, f, indent=2, ensure_ascii=False)
    return redirect("/")

@app.route("/logout")
def logout(): session.clear(); return redirect("/")

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

systemctl daemon-reload && systemctl restart zivpn-web
IP=$(hostname -I | awk '{print $1}')
echo -e "\n✅ Installation Success! Web Panel: http://$IP:8080"
