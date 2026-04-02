#!/bin/bash
# CMT ZIVPN PRO - ORIGINAL DATA SYNC & BOT FIX
set -euo pipefail

# Install dependencies
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl python3-pip >/dev/null
pip3 install psutil requests >/dev/null

mkdir -p /etc/zivpn
ENVF="/etc/zivpn/web.env"

# Initialize Environment with correct ZIVPN settings
if [ ! -f "$ENVF" ]; then
    echo "WEB_ADMIN_USER=admin" > "$ENVF"
    echo "WEB_ADMIN_PASSWORD=admin" >> "$ENVF"
    echo "WEB_SECRET=$(openssl rand -hex 16)" >> "$ENVF"
    echo "TG_TOKEN=" >> "$ENVF"
    echo "TG_CHAT_ID=" >> "$ENVF"
fi

cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, hmac, datetime, requests, psutil, threading, time
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

# --- Original ZIVPN Data Sync ---
def get_users():
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json", "r") as f:
            try: return json.load(f)
            except: return []
    return []

def save_users(data):
    with open("/etc/zivpn/users.json", "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    subprocess.run("systemctl restart zivpn", shell=True)

# --- Telegram Bot Handler ---
def bot_polling():
    token = get_env("TG_TOKEN")
    last_id = 0
    if not token or ":" not in token: return
    while True:
        try:
            url = f"https://api.telegram.org/bot{token}/getUpdates?offset={last_id + 1}&timeout=30"
            r = requests.get(url, timeout=40).json()
            if "result" in r:
                for up in r["result"]:
                    last_id = up["update_id"]
                    if "message" in up and "text" in up["message"]:
                        msg = up["message"]
                        cid = str(msg["chat"]["id"])
                        text = msg["text"]
                        if cid != get_env("TG_CHAT_ID"): continue
                        
                        if text.startswith("/start"):
                            requests.get(f"https://api.telegram.org/bot{token}/sendMessage?chat_id={cid}&text=👋 Mingalarpar Admin!")
                        elif text.startswith("/adduser"):
                            try:
                                args = text.split()
                                u, d = args[1], args[2]
                                exp = (datetime.datetime.now() + datetime.timedelta(days=int(d))).strftime("%Y-%m-%d")
                                data = get_users()
                                p = args[3] if len(args) > 3 else "455"
                                data.insert(0, {"user":u, "password":p, "expires":exp, "port":str(6000+len(data))})
                                save_users(data)
                                requests.get(f"https://api.telegram.org/bot{token}/sendMessage?chat_id={cid}&text=✅ User {u} Added!")
                            except: requests.get(f"https://api.telegram.org/bot{token}/sendMessage?chat_id={cid}&text=❌ /adduser [name] [days]")
        except: time.sleep(5)
        time.sleep(1)

threading.Thread(target=bot_polling, daemon=True).start()

HTML = """<!doctype html>
<html lang="my"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CMT ZIVPN PRO</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
<style>
    :root { --bg: #050810; --card: rgba(16, 22, 42, 0.95); --cyan: #00d4ff; --green: #2ecc71; --yellow: #ffaa00; --red: #ff4444; }
    body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; overflow-x: hidden; }
    #bgCanvas { position: fixed; top:0; left:0; width:100%; height:100%; z-index:-1; }
    .header { background: rgba(0,0,0,0.7); padding: 12px 15px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); }
    .logo-img { border-radius: 50%; width: 50px; height: 50px; background: #fff; border: 2px solid #fff; }
    .container { padding: 15px; }
    .grid-info { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 20px; }
    .info-box { background: var(--card); padding: 10px; text-align: center; border: 1.5px solid var(--cyan); border-radius: 12px; box-shadow: 0 0 10px var(--cyan); }
    .action-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 20px; }
    .action-box { background: var(--card); padding: 15px 5px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.1); text-align: center; cursor: pointer; }
    .table-card { background: var(--card); border-radius: 12px; border: 1.5px solid var(--cyan); overflow-x: auto; padding: 10px; }
    table { width: 100%; border-collapse: collapse; min-width: 600px; }
    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #333; font-size: 0.85em; }
    .main-btn { background: linear-gradient(90deg, #ff0000, #ffaa00, #00d4ff); padding: 12px; border: none; border-radius: 12px; color: #fff; width: 100%; font-weight: bold; cursor: pointer; }
    .modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); }
    .modal-content { background: var(--card); margin: 15% auto; padding: 25px; width: 85%; max-width: 350px; border-radius: 20px; border: 2px solid var(--cyan); text-align: center; }
    input { width: 100%; padding: 12px; margin: 10px 0; background: #000; color: #fff; border: 1.5px solid var(--cyan); border-radius: 10px; outline: none; box-sizing: border-box; }
    .bottom-nav { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(10,14,26,0.95); display: flex; justify-content: space-around; padding: 15px 0; border-top: 2px solid var(--cyan); }
</style>
</head><body onload="startClock()">
<canvas id="bgCanvas"></canvas>
{% if not session.get('auth') %}
    <div style="max-width:320px; margin:20vh auto; background:var(--card); padding:35px; border-radius:20px; text-align:center; border:3px solid var(--cyan);">
        <img src="{{logo}}" width="80" style="background:#fff; border-radius:10px; margin-bottom:20px;">
        <h2>CMT LOGIN</h2>
        <form method="post" action="/login_check"><input name="u" placeholder="Admin"><input name="p" type="password" placeholder="Pass"><button class="main-btn">ဝင်မည်</button></form>
    </div>
{% else %}
    <div class="header">
        <img src="{{logo}}" class="logo-img">
        <div style="text-align:center;"><div id="liveTime" style="color:var(--green);font-weight:bold;font-size:1.3em;"></div><div id="liveDate" style="font-size:0.7em;color:#aaa;"></div></div>
        <a href="/settings" style="color:var(--cyan);font-size:1.5em;"><i class="fas fa-cog"></i></a>
    </div>
    <div class="container">
        <div class="grid-info">
            <div class="info-box"><small>CPU</small><div style="color:var(--cyan)">{{sys.cpu}}%</div></div>
            <div class="info-box"><small>RAM</small><div style="color:var(--yellow)">{{sys.ram}}%</div></div>
            <div class="info-box"><small>DISK</small><div style="color:var(--green)">{{sys.disk}}%</div></div>
        </div>
        <div class="grid-info">
            <div class="info-box" style="border-color:var(--green)"><small>USER</small><div>{{users|length}}</div></div>
            <div class="info-box" style="border-color:var(--green)"><small>ONLINE</small><div>{{active}}</div></div>
            <div class="info-box" style="border-color:var(--green)"><small>LOAD</small><div>12%</div></div>
        </div>
        <div class="action-grid">
            <div class="action-box" onclick="toggleModal('addModal')"><i class="fas fa-user-plus" style="color:var(--green)"></i><span>Add User</span></div>
            <div class="action-box" onclick="location.href='/settings'"><i class="fas fa-robot" style="color:var(--cyan)"></i><span>Bot Set</span></div>
            <div class="action-box" onclick="location.href='/logout'"><i class="fas fa-power-off" style="color:var(--red)"></i><span>Logout</span></div>
        </div>
        <div class="table-card">
            <table>
                <thead><tr><th>Name</th><th>Pass</th><th>Expiry</th><th>Status</th><th>Act</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan);font-weight:bold;">{{u.user}}</td>
                        <td>{{u.password}} <i class="fas fa-copy" style="cursor:pointer;color:var(--cyan)" onclick="copyVal('{{u.password}}')"></i></td>
                        <td style="color:#ff69b4;">{{u.expires}}</td>
                        <td><span style="color:{{ 'var(--green)' if u.online else 'var(--red)' }}">● {{ 'On' if u.online else 'Off' }}</span></td>
                        <td>
                            <div style="display:flex;gap:10px;">
                                <i class="fas fa-pencil-alt" style="color:var(--yellow);cursor:pointer;" onclick="openRenew('{{u.user}}')"></i>
                                <form method="post" action="/delete" onsubmit="return confirm('ဖျက်မှာလား?')"><input type="hidden" name="user" value="{{u.user}}"><button style="background:none;border:none;color:var(--red);cursor:pointer;"><i class="fas fa-trash"></i></button></form>
                            </div>
                        </td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>
    <div id="addModal" class="modal"><div class="modal-content">
        <h3>Add User</h3>
        <form method="post" action="/add"><input name="user" placeholder="Name" required><input name="password" placeholder="Pass" required><input name="days" placeholder="Days" required><button class="main-btn">Create</button></form>
        <button onclick="toggleModal('addModal')" style="background:none;border:none;color:#aaa;margin-top:10px;">Cancel</button>
    </div></div>
    <div id="renewModal" class="modal"><div class="modal-content">
        <h3>Renew User</h3>
        <form method="post" action="/renew"><input type="hidden" name="user" id="rUser"><input name="days" placeholder="Days (eg. 30)" required><button class="main-btn">Confirm</button></form>
        <button onclick="toggleModal('renewModal')" style="background:none;border:none;color:#aaa;margin-top:10px;">Cancel</button>
    </div></div>
{% endif %}
<script>
    function toggleModal(id) { var m = document.getElementById(id); m.style.display = m.style.display == 'block' ? 'none' : 'block'; }
    function openRenew(u) { document.getElementById('rUser').value = u; toggleModal('renewModal'); }
    function copyVal(v){ var t=document.createElement("textarea");document.body.appendChild(t);t.value=v;t.select();document.execCommand("copy");document.body.removeChild(t);alert("Copied!"); }
    function startClock(){ setInterval(function(){ var n=new Date(); var utc = n.getTime()+(n.getTimezoneOffset()*60000); var th=new Date(utc+25200000); var h=th.getHours(),m=th.getMinutes(),s=th.getSeconds(),ap=h>=12?'PM':'AM'; h=h%12||12; h=h<10?'0'+h:h; m=m<10?'0'+m:m; s=s<10?'0'+s:s; document.getElementById('liveTime').innerHTML=h+':'+m+':'+s+' '+ap; document.getElementById('liveDate').innerHTML=th.toDateString(); }, 1000); }
    const cvs=document.getElementById('bgCanvas'),ctx=cvs.getContext('2d');
    let pts=[]; function init(){cvs.width=window.innerWidth;cvs.height=window.innerHeight;} window.onresize=init; init();
    class Pt{constructor(){this.x=Math.random()*cvs.width;this.y=Math.random()*cvs.height;this.vx=(Math.random()-0.5)*0.8;this.vy=(Math.random()-0.5)*0.8;this.r=Math.random()*2+1;} up(){this.x+=this.vx;this.y+=this.vy;if(this.x<0||this.x>cvs.width)this.vx*=-1;if(this.y<0||this.y>cvs.height)this.vy*=-1;} dr(){ctx.beginPath();ctx.arc(this.x,this.y,this.r,0,Math.PI*2);ctx.fillStyle='rgba(255,255,255,0.1)';ctx.fill();}}
    for(let i=0;i<60;i++)pts.push(new Pt());
    function anim(){ctx.clearRect(0,0,cvs.width,cvs.height);pts.forEach((p,i)=>{p.up();p.dr();for(let j=i+1;j<pts.length;j++){let d=Math.hypot(p.x-pts[j].x,p.y-pts[j].y);if(d<110){ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.lineTo(pts[j].x,pts[j].y);ctx.strokeStyle='rgba(0,212,255,'+(1-d/110)*0.5+')';ctx.lineWidth=0.8;ctx.stroke();}}});requestAnimationFrame(anim);} anim();
</script></body></html>"""

@app.route("/")
def index():
    if not session.get("auth"): return render_template_string(HTML, logo=OFFICIAL_LOGO)
    u_list = get_users()
    conntrack = subprocess.run("conntrack -L -p udp 2>/dev/null", shell=True, capture_output=True, text=True).stdout
    for u in u_list: u["online"] = f"dport={u.get('port')}" in conntrack
    return render_template_string(HTML, users=u_list, active=sum(1 for u in u_list if u["online"]), logo=OFFICIAL_LOGO, sys={"cpu": psutil.cpu_percent(), "ram": psutil.virtual_memory().percent, "disk": psutil.disk_usage('/').percent})

@app.route("/login_check", methods=["POST"])
def login_check():
    if hmac.compare_digest(request.form.get("u"), get_env("WEB_ADMIN_USER")) and hmac.compare_digest(request.form.get("p"), get_env("WEB_ADMIN_PASSWORD")):
        session["auth"] = True
    return redirect("/")

@app.route("/settings")
def settings():
    if not session.get("auth"): return redirect("/")
    return render_template_string("<!doctype html><html><head><style>body{background:#050810;color:#fff;font-family:sans-serif;padding:20px;}.card{background:rgba(16,22,42,0.9);padding:15px;border-radius:12px;border:1px solid #00d4ff;margin-bottom:20px;}input{width:100%;padding:10px;margin:8px 0;background:#000;color:#fff;border:1px solid #ff4500;border-radius:10px;box-sizing:border-box;}.btn{background:#00d4ff;padding:12px;border:none;border-radius:10px;width:100%;font-weight:bold;cursor:pointer;color:#000;}</style></head><body><h2>Settings</h2><div class='card'><form method='post' action='/update_pass'><h4>Admin Password</h4><input name='old_u' placeholder='Old User'><input name='old_p' type='password' placeholder='Old Pass'><input name='new_p' type='password' placeholder='New Pass'><button class='btn'>Update Admin</button></form></div><div class='card'><form method='post' action='/update_tg'><h4>Bot Connect</h4><input name='token' value='{{token}}' placeholder='Bot Token'><input name='chat_id' value='{{chat_id}}' placeholder='Chat ID'><button class='btn'>Save Token</button></form></div><a href='/' style='color:#aaa;text-decoration:none;'>Back Home</a></body></html>", token=get_env("TG_TOKEN"), chat_id=get_env("TG_CHAT_ID"))

@app.route("/update_tg", methods=["POST"])
def update_tg():
    if session.get("auth"):
        set_env("TG_TOKEN", request.form.get("token")); set_env("TG_CHAT_ID", request.form.get("chat_id"))
        subprocess.run("systemctl restart zivpn-web", shell=True)
    return redirect("/settings")

@app.route("/update_pass", methods=["POST"])
def update_pass():
    if session.get("auth") and hmac.compare_digest(request.form.get("old_u"), get_env("WEB_ADMIN_USER")) and hmac.compare_digest(request.form.get("old_p"), get_env("WEB_ADMIN_PASSWORD")):
        set_env("WEB_ADMIN_PASSWORD", request.form.get("new_p"))
    return redirect("/settings")

@app.route("/add", methods=["POST"])
def add():
    if not session.get("auth"): return redirect("/")
    u, p, d = request.form.get("user"), request.form.get("password"), request.form.get("days")
    exp = (datetime.datetime.now() + datetime.timedelta(days=int(d))).strftime("%Y-%m-%d")
    data = get_users()
    data.insert(0, {"user":u, "password":p, "expires":exp, "port":str(6000+len(data))})
    save_users(data)
    return redirect("/")

@app.route("/renew", methods=["POST"])
def renew():
    if not session.get("auth"): return redirect("/")
    n, d = request.form.get("user"), request.form.get("days")
    data = get_users()
    for u in data:
        if u["user"] == n:
            cur = datetime.datetime.strptime(u['expires'], '%Y-%m-%d')
            u['expires'] = (cur + datetime.timedelta(days=int(d))).strftime('%Y-%m-%d'); break
    save_users(data)
    return redirect("/")

@app.route("/delete", methods=["POST"])
def delete():
    if not session.get("auth"): return redirect("/")
    n = request.form.get("user")
    data = [x for x in get_users() if x["user"] != n]
    save_users(data)
    return redirect("/")

@app.route("/logout")
def logout(): session.clear(); return redirect("/")

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

systemctl daemon-reload && systemctl restart zivpn-web
IP=$(hostname -I | awk '{print $1}')
echo -e "\n✅ Fixed Success! http://$IP:8080"
