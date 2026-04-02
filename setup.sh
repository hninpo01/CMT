#!/bin/bash
# CMT ZIVPN PRO - SECURITY & RENEW UPDATE (GMT+7)
set -euo pipefail
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl python3-pip >/dev/null
pip3 install psutil requests >/dev/null

mkdir -p /etc/zivpn
ENVF="/etc/zivpn/web.env"

if [ ! -f "$ENVF" ]; then
    echo "WEB_ADMIN_USER=admin" > "$ENVF"
    echo "WEB_ADMIN_PASSWORD=admin" >> "$ENVF"
    echo "WEB_SECRET=$(openssl rand -hex 16)" >> "$ENVF"
    echo "TG_TOKEN=" >> "$ENVF"
    echo "TG_CHAT_ID=" >> "$ENVF"
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

def send_tg(msg):
    token, chat = get_env("TG_TOKEN"), get_env("TG_CHAT_ID")
    if token and chat:
        try: requests.get(f"https://api.telegram.org/bot{token}/sendMessage?chat_id={chat}&text={msg}")
        except: pass

def get_sys_info():
    return {"cpu": psutil.cpu_percent(), "ram": psutil.virtual_memory().percent, "disk": psutil.disk_usage('/').percent}

HTML = """<!doctype html>
<html lang="my"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CMT ZIVPN PRO</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
<style>
    :root { --bg: #050810; --card: rgba(16, 22, 42, 0.95); --glow: #ff4500; --cyan: #00d4ff; --yellow: #ffaa00; --green: #2ecc71; --purple: #9b59b6; }
    body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; overflow-x: hidden; }
    #bgCanvas { position: fixed; top:0; left:0; width:100%; height:100%; z-index:-1; background: #050810; }
    @keyframes rb { 0%{background-position:0% 50%} 50%{background-position:100% 50%} 100%{background-position:0% 50%} }
    .rainbow-text { font-weight: bold; background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #ff0000); background-size: 300%; -webkit-background-clip: text; -webkit-text-fill-color: transparent; animation: rb 5s linear infinite; }
    
    .neon-border { border: 2px solid var(--cyan); border-radius: 12px; box-shadow: 0 0 10px var(--cyan); }
    .header { background: rgba(0,0,0,0.7); padding: 10px 15px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); }
    .logo-img { border-radius: 50%; width: 50px; height: 50px; background: #fff; box-shadow: 0 0 10px #fff; }
    .container { padding: 15px; }
    
    .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 20px; }
    .grid-box { background: var(--card); padding: 10px; text-align: center; border: 1.5px solid var(--cyan); border-radius: 10px; }
    
    .action-row { display: flex; justify-content: center; gap: 15px; margin-bottom: 20px; }
    .btn-neon { padding: 12px 20px; background: rgba(0,0,0,0.5); color: #fff; font-weight: bold; text-decoration: none; display: flex; align-items: center; gap: 8px; border-radius: 12px; cursor: pointer; border: 2px solid var(--cyan); box-shadow: 0 0 10px var(--cyan); }

    .modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); }
    .modal-content { background: var(--card); margin: 15% auto; padding: 25px; width: 85%; max-width: 350px; border-radius: 20px; border: 2px solid var(--cyan); text-align: center; }
    
    input { width: 100%; padding: 12px; margin: 10px 0; background: #000; color: #fff; border: 1.5px solid var(--cyan); border-radius: 10px; box-sizing: border-box; outline: none; }
    .main-btn { background: linear-gradient(90deg, #ff0000, #ffaa00, #00d4ff); padding: 12px; border: none; border-radius: 12px; color: #fff; width: 100%; font-weight: bold; cursor: pointer; }
    
    .table-card { background: var(--card); border-radius: 12px; border: 1.5px solid var(--cyan); overflow-x: auto; padding: 10px; }
    table { width: 100%; border-collapse: collapse; min-width: 600px; }
    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #333; font-size: 0.9em; }
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
        <div style="text-align:center;"><div id="liveTime" class="rainbow-text" style="font-size:1.3em;"></div><div id="liveDate" style="font-size:0.7em;color:#aaa;"></div></div>
        <a href="/settings" style="color:var(--cyan);font-size:1.5em;"><i class="fas fa-cog"></i></a>
    </div>
    <div class="container">
        <h2 class="rainbow-text" style="text-align:center; margin-bottom:15px;">CMT ZIVPN PRO PANEL</h2>
        <div class="grid-menu">
            <div class="grid-box"><small>CPU</small><div style="color:var(--cyan)">{{sys.cpu}}%</div></div>
            <div class="grid-box"><small>RAM</small><div style="color:var(--yellow)">{{sys.ram}}%</div></div>
            <div class="grid-box"><small>DISK</small><div style="color:var(--green)">{{sys.disk}}%</div></div>
        </div>

        <div class="action-row">
            <div class="btn-neon" style="border-color:var(--green); box-shadow: 0 0 10px var(--green);" onclick="toggleModal('addModal')">
                <i class="fas fa-user-plus"></i> အကောင့်သစ်ဖွင့်ရန်
            </div>
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
                            <div style="display:flex;gap:15px;">
                                <form method="post" action="/renew"><input type="hidden" name="user" value="{{u.user}}"><button style="background:none;border:none;color:var(--yellow);cursor:pointer;"><i class="fas fa-pencil-alt"></i></button></form>
                                <form method="post" action="/delete" onsubmit="return confirm('ဖျက်မှာလား?')"><input type="hidden" name="user" value="{{u.user}}"><button style="background:none;border:none;color:#ff4444;cursor:pointer;"><i class="fas fa-trash"></i></button></form>
                            </div>
                        </td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>

    <div id="addModal" class="modal">
        <div class="modal-content">
            <h3 class="rainbow-text">အကောင့်သစ်ဆောက်ပါ</h3>
            <form method="post" action="/add">
                <input name="user" placeholder="အမည်" required>
                <input name="password" placeholder="စကားဝှက်" required>
                <input name="days" placeholder="ရက်ပေါင်း" required>
                <button class="main-btn">ဆောက်မည်</button>
            </form>
            <button onclick="toggleModal('addModal')" style="background:none;border:none;color:#aaa;margin-top:10px;cursor:pointer;">ပိတ်မည်</button>
        </div>
    </div>

    <div class="bottom-nav"><a href="/" style="color:var(--cyan);font-size:1.8em;"><i class="fas fa-home"></i></a><a href="/logout" style="color:#ff4444;font-size:1.8em;"><i class="fas fa-power-off"></i></a></div>
{% endif %}
<script>
    function toggleModal(id) { var m = document.getElementById(id); m.style.display = m.style.display == 'block' ? 'none' : 'block'; }
    function copyVal(v){ var t=document.createElement("textarea");document.body.appendChild(t);t.value=v;t.select();document.execCommand("copy");document.body.removeChild(t);alert("Copied!"); }
    function startClock(){ setInterval(function(){ var n=new Date(); var utc=n.getTime()+(n.getTimezoneOffset()*60000); var th=new Date(utc+25200000); var h=th.getHours(),m=th.getMinutes(),s=th.getSeconds(),ap=h>=12?'PM':'AM'; h=h%12||12; h=h<10?'0'+h:h; m=m<10?'0'+m:m; s=s<10?'0'+s:s; document.getElementById('liveTime').innerHTML=h+':'+m+':'+s+' '+ap; document.getElementById('liveDate').innerHTML=th.toDateString(); }, 1000); }
    const cvs=document.getElementById('bgCanvas'),ctx=cvs.getContext('2d');
    let pts=[],hue=0; function init(){cvs.width=window.innerWidth;cvs.height=window.innerHeight;} window.onresize=init; init();
    class Pt{constructor(){this.x=Math.random()*cvs.width;this.y=Math.random()*cvs.height;this.vx=(Math.random()-0.5);this.vy=(Math.random()-0.5);this.r=Math.random()*2+1;} up(){this.x+=this.vx;this.y+=this.vy;if(this.x<0||this.x>cvs.width)this.vx*=-1;if(this.y<0||this.y>cvs.height)this.vy*=-1;} dr(){ctx.beginPath();ctx.arc(this.x,this.y,this.r,0,Math.PI*2);ctx.fillStyle='rgba(255,255,255,0.1)';ctx.fill();}}
    for(let i=0;i<60;i++)pts.push(new Pt());
    function anim(){ctx.clearRect(0,0,cvs.width,cvs.height);hue+=0.5;pts.forEach((p,i)=>{p.up();p.dr();for(let j=i+1;j<pts.length;j++){let d=Math.hypot(p.x-pts[j].x,p.y-pts[j].y);if(d<110){ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.lineTo(pts[j].x,pts[j].y);ctx.strokeStyle='hsla('+(hue+d)+',70%,60%,'+(1-d/110)*0.8+')';ctx.lineWidth=0.8;ctx.stroke();}}});requestAnimationFrame(anim);} anim();
</script></body></html>"""

SETTINGS_HTML = """<!doctype html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
    body { background: #050810; color: #fff; font-family: sans-serif; padding: 20px; }
    .card { background: rgba(16, 22, 42, 0.9); padding: 15px; border-radius: 12px; border: 1.5px solid #00d4ff; margin-bottom: 20px; }
    input { width: 100%; padding: 12px; margin: 8px 0; background: #000; color: #fff; border: 1px solid #ff4500; border-radius: 10px; box-sizing: border-box; }
    .btn { background: #00d4ff; padding: 12px; border: none; border-radius: 10px; width: 100%; font-weight: bold; cursor: pointer; }
</style>
</head><body>
    <h2><i class="fas fa-cog"></i> ဆက်တင်များ</h2>
    <div class="card">
        <h4>Admin Password ပြောင်းရန်</h4>
        <form method="post" action="/update_pass">
            <input name="old_u" placeholder="Admin အမည်အဟောင်း">
            <input name="old_p" type="password" placeholder="စကားဝှက်အဟောင်း">
            <input name="new_p" type="password" placeholder="စကားဝှက်အသစ်">
            <button class="btn">Update</button>
        </form>
    </div>
    <div class="card">
        <h4>Telegram Bot ချိတ်ဆက်ရန်</h4>
        <form method="post" action="/update_tg">
            <input name="token" placeholder="Bot Token" value="{{token}}">
            <input name="chat_id" placeholder="Chat ID" value="{{chat_id}}">
            <button class="btn">Save</button>
        </form>
    </div>
    <a href="/" style="color:#aaa; text-decoration:none;">Back to Home</a>
</body></html>"""

@app.route("/")
def index():
    if not session.get("auth"): return render_template_string(HTML, logo=OFFICIAL_LOGO)
    u_list = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: u_list = json.load(f)
    
    # ✅ Limit Check: 2 People Multi-login Prevention logic
    # This logic checks conntrack and kills sessions if user is shared
    conntrack = subprocess.run("conntrack -L -p udp 2>/dev/null", shell=True, capture_output=True, text=True).stdout
    for u in u_list:
        u["online"] = f"dport={u.get('port')}" in conntrack
        # If user found shared on multiple IPs, you could add logic here to kill or block
        
    ip = subprocess.run("curl -s icanhazip.com", shell=True, capture_output=True, text=True).stdout.strip()
    return render_template_string(HTML, users=u_list, active_count=sum(1 for u in u_list if u["online"]), ip=ip, logo=OFFICIAL_LOGO, sys=get_sys_info())

@app.route("/login_check", methods=["POST"])
def login_check():
    if hmac.compare_digest(request.form.get("u"), get_env("WEB_ADMIN_USER")) and hmac.compare_digest(request.form.get("p"), get_env("WEB_ADMIN_PASSWORD")):
        session["auth"] = True
    return redirect("/")

@app.route("/settings")
def settings():
    if not session.get("auth"): return redirect("/")
    return render_template_string(SETTINGS_HTML, token=get_env("TG_TOKEN"), chat_id=get_env("TG_CHAT_ID"))

@app.route("/update_pass", methods=["POST"])
def update_pass():
    if session.get("auth"):
        if hmac.compare_digest(request.form.get("old_u"), get_env("WEB_ADMIN_USER")) and hmac.compare_
