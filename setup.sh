#!/bin/bash
# CMT ZIVPN PRO - TELEGRAM BOT SYNC & NEON UI
set -euo pipefail
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl python3-pip >/dev/null
pip3 install psutil requests python-telegram-bot==13.15 >/dev/null

mkdir -p /etc/zivpn
ENVF="/etc/zivpn/web.env"
USERS="/etc/zivpn/users.json"

# Permanent Support Links & Initial Env
if [ ! -f "$ENVF" ]; then
    echo "WEB_ADMIN_USER=admin" > "$ENVF"
    echo "WEB_ADMIN_PASSWORD=admin" >> "$ENVF"
    echo "WEB_SECRET=$(openssl rand -hex 16)" >> "$ENVF"
    echo "TG_TOKEN=" >> "$ENVF"
    echo "TG_CHAT_ID=" >> "$ENVF"
    echo "SUPPORT_TG=https://t.me/CMT_1411" >> "$ENVF"
    echo "SUPPORT_FB=https://www.facebook.com/ChitMinThu1239" >> "$ENVF"
    echo "SUPPORT_MSG=https://m.me/ChitMinThu1239" >> "$ENVF"
fi

cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, hmac, datetime, requests, psutil, threading
from flask import Flask, render_template_string, request, redirect, session, url_for
from telegram import Bot, Update
from telegram.ext import Updater, CommandHandler, CallbackContext

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

# --- Telegram Bot Logic ---
def bot_adduser(update: Update, context: CallbackContext):
    chat_id = str(update.effective_chat.id)
    if chat_id != get_env("TG_CHAT_ID"): return
    try:
        u, d = context.args[0], context.args[1]
        p = context.args[2] if len(context.args) > 2 else "1234"
        exp = (datetime.datetime.now() + datetime.timedelta(days=int(d))).strftime("%Y-%m-%d")
        
        with open("/etc/zivpn/users.json","r") as f: u_list = json.load(f)
        port = str(max([int(x.get("port", 6000)) for x in u_list] + [6000]) + 1)
        u_list.insert(0, {"user":u, "password":p, "expires":exp, "port":port})
        with open("/etc/zivpn/users.json","w") as f: json.dump(u_list, f, indent=2, ensure_ascii=False)
        
        ip = requests.get("https://icanhazip.com").text.strip()
        msg = f"✅ **User Added Successfully!**\n\n🌐 Server: `{ip}`\n👤 Username: `{u}`\n🔑 Password: `{p}`\n📅 Expires: `{exp}`\n\nUser can connect now!"
        update.message.reply_markdown(msg)
        subprocess.run("systemctl restart zivpn", shell=True)
    except:
        update.message.reply_text("❌ Usage: /adduser [name] [days] [pass]")

def start_bot():
    token = get_env("TG_TOKEN")
    if token:
        updater = Updater(token)
        updater.dispatcher.add_handler(CommandHandler("adduser", bot_adduser))
        updater.start_polling()

# Start bot in separate thread
threading.Thread(target=start_bot, daemon=True).start()

# --- Web Panel Pages (HTML) ---
HTML = """<!doctype html>
<html lang="my"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CMT ZIVPN PRO</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
<style>
    :root { --bg: #050810; --card: rgba(16, 22, 42, 0.95); --cyan: #00d4ff; --green: #2ecc71; --purple: #9b59b6; --yellow: #ffaa00; }
    body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; }
    #bgCanvas { position: fixed; top:0; left:0; width:100%; height:100%; z-index:-1; background: #050810; }
    @keyframes rb { 0%{background-position:0% 50%} 50%{background-position:100% 50%} 100%{background-position:0% 50%} }
    .rainbow-text { font-weight: bold; background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #ff0000); background-size: 300% 300%; -webkit-background-clip: text; -webkit-text-fill-color: transparent; animation: rb 5s linear infinite; }
    .header { background: rgba(0,0,0,0.7); padding: 10px 15px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); }
    .logo-img { border-radius: 50%; width: 50px; height: 50px; background: #fff; box-shadow: 0 0 10px #fff; border: 2px solid #fff; }
    .container { padding: 15px; }
    .grid-info { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 15px; }
    .info-box { background: var(--card); padding: 12px 5px; text-align: center; border: 2px solid var(--cyan); border-radius: 12px; box-shadow: 0 0 15px var(--cyan); }
    .action-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 20px; }
    .action-box { background: var(--card); padding: 15px 5px; border-radius: 12px; border: 2px solid rgba(0, 212, 255, 0.4); text-align: center; cursor: pointer; }
    .table-card { background: var(--card); border-radius: 12px; border: 2.5px solid var(--cyan); overflow-x: auto; padding: 10px; }
    table { width: 100%; border-collapse: collapse; min-width: 600px; }
    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #333; font-size: 0.85em; }
    .modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); }
    .modal-content { background: var(--card); margin: 15% auto; padding: 25px; width: 85%; max-width: 350px; border-radius: 20px; border: 2px solid var(--cyan); text-align: center; }
    input { width: 100%; padding: 12px; margin: 10px 0; background: #000; color: #fff; border: 1.5px solid var(--cyan); border-radius: 10px; outline: none; box-sizing: border-box; }
    .main-btn { background: linear-gradient(90deg, #ff0000, #ffaa00, #00d4ff); padding: 12px; border: none; border-radius: 12px; color: #fff; width: 100%; font-weight: bold; cursor: pointer; }
    .bottom-nav { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(10,14,26,0.95); display: flex; justify-content: space-around; padding: 15px 0; border-top: 2px solid var(--cyan); }
</style>
</head><body onload="startClock()">
<canvas id="bgCanvas"></canvas>
{% if not session.get('auth') %}
    <div style="max-width:320px; margin:20vh auto; background:var(--card); padding:35px; border-radius:20px; text-align:center; border:3px solid #ff4500;">
        <h2 class="rainbow-text">CMT LOGIN</h2>
        <form method="post" action="/login_check"><input name="u" placeholder="Admin"><input name="p" type="password" placeholder="Pass"><button class="main-btn">LOGIN</button></form>
    </div>
{% else %}
    <div class="header">
        <img src="{{logo}}" class="logo-img">
        <div style="text-align:center;"><div id="liveTime" class="rainbow-text" style="font-size:1.3em;"></div><div id="liveDate" style="font-size:0.7em;color:#aaa;"></div></div>
        <div style="width:40px;"></div>
    </div>
    <div class="container">
        <h2 class="rainbow-text" style="text-align:center; margin-bottom:15px; font-size:1.5em;">CMT PRO PANEL</h2>
        <div class="grid-info">
            <div class="info-box"><small>CPU</small><div style="color:var(--cyan)">{{sys.cpu}}%</div></div>
            <div class="info-box" style="border-color:var(--yellow); box-shadow: 0 0 15px var(--yellow);"><small>RAM</small><div style="color:var(--yellow)">{{sys.ram}}%</div></div>
            <div class="info-box" style="border-color:var(--green); box-shadow: 0 0 15px var(--green);"><small>DISK</small><div style="color:var(--green)">{{sys.disk}}%</div></div>
        </div>
        <div class="grid-info">
            <div class="info-box" style="border-color:var(--purple); box-shadow: 0 0 15px var(--purple);"><small>အသုံးပြုသူ</small><div style="color:var(--purple)">{{users|length}}</div></div>
            <div class="info-box" style="border-color:var(--green);"><small>အွန်လိုင်း</small><div style="color:var(--green)">{{active_count}}</div></div>
            <div class="info-box" style="border-color:var(--yellow);"><small>ဝန်အား</small><div style="color:var(--yellow)">12%</div></div>
        </div>
        <div class="action-grid">
            <div class="action-box" onclick="toggleModal('addModal')"><i class="fas fa-user-plus" style="color:var(--green);"></i><span>အကောင့်သစ်</span></div>
            <div class="action-box" onclick="toggleModal('supportModal')"><i class="fas fa-headset" style="color:var(--cyan);"></i><span>ဆက်သွယ်ရန်</span></div>
            <div class="action-box" onclick="location.href='/settings'"><i class="fas fa-cog" style="color:var(--purple);"></i><span>စက်တင်များ</span></div>
        </div>
        <div class="table-card">
            <table>
                <thead><tr><th>အမည်</th><th>စကားဝှက်</th><th>ကျန်ရက်</th><th>Status</th><th>Action</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan); font-weight:bold;">{{u.user}}</td>
                        <td>{{u.password}} <i class="fas fa-copy" style="cursor:pointer;color:var(--cyan);font-size:0.8em;" onclick="copyVal('{{u.password}}')"></i></td>
                        <td style="color:#ff69b4;">{{u.expires}}<br><small>{{u.days_left}} ရက်ကျန်</small></td>
                        <td><span style="color:{{ 'var(--green)' if u.online else '#ff4444' }}">● {{ 'Online' if u.online else 'Offline' }}</span></td>
                        <td>
                            <div style="display:flex;gap:12px;">
                                <i class="fas fa-pencil-alt" style="color:var(--yellow);cursor:pointer;" onclick="openRenew('{{u.user}}')"></i>
                                <form method="post" action="/delete" onsubmit="return confirm('ဖျက်မှာလား?')"><input type="hidden" name="user" value="{{u.user}}"><button style="background:none;border:none;color:#ff4444;cursor:pointer;"><i class="fas fa-trash"></i></button></form>
                            </div>
                        </td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>

    <div id="addModal" class="modal"><div class="modal-content">
        <h3 class="rainbow-text">အကောင့်သစ်ဖွင့်ရန်</h3>
        <form method="post" action="/add"><input name="user" placeholder="အမည်" required><input name="password" placeholder="စကားဝှက်" required><input name="days" placeholder="ရက်ပေါင်း" required><button class="main-btn">ဆောက်မည်</button></form>
        <button onclick="toggleModal('addModal')" style="background:none;border:none;color:#aaa;margin-top:15px;">ပိတ်မည်</button>
    </div></div>

    <div id="renewModal" class="modal"><div class="modal-content">
        <h3 class="rainbow-text">သက်တမ်းပြင်ရန်</h3>
        <form method="post" action="/renew"><input type="hidden" name="user" id="renewUser"><input name="days" placeholder="ရက်ပေါင်း (တိုးရန် ၃၀ / လျော့ရန် -၅)" required><button class="main-btn">အတည်ပြုသည်</button></form>
        <button onclick="toggleModal('renewModal')" style="background:none;border:none;color:#aaa;margin-top:15px;">ပိတ်မည်</button>
    </div></div>

    <div id="supportModal" class="modal"><div class="modal-content">
        <h3 class="rainbow-text">ဆက်သွယ်ရန်</h3>
        <a href="{{tg}}" target="_blank" style="display:block;padding:12px;margin:10px 0;background:#0088cc;color:#fff;border-radius:10px;text-decoration:none;">Telegram</a>
        <a href="{{fb}}" target="_blank" style="display:block;padding:12px;margin:10px 0;background:#1877f2;color:#fff;border-radius:10px;text-decoration:none;">Facebook</a>
        <a href="{{msg}}" target="_blank" style="display:block;padding:12px;margin:10px 0;background:linear-gradient(45deg,#00c6ff,#bc00ff);color:#fff;border-radius:10px;text-decoration:none;">Messenger</a>
        <button onclick="toggleModal('supportModal')" style="background:none;border:none;color:#aaa;margin-top:15px;">ပိတ်မည်</button>
    </div></div>

    <div class="bottom-nav"><a href="/" style="color:var(--cyan);font-size:1.8em;"><i class="fas fa-home"></i></a><a href="/logout" style="color:#ff4444;font-size:1.8em;"><i class="fas fa-power-off"></i></a></div>
{% endif %}
<script>
    function toggleModal(id) { var m = document.getElementById(id); m.style.display = m.style.display == 'block' ? 'none' : 'block'; }
    function openRenew(u) { document.getElementById('renewUser').value = u; toggleModal('renewModal'); }
    function copyVal(v){ var t=document.createElement("textarea");document.body.appendChild(t);t.value=v;t.select();document.execCommand("copy");document.body.removeChild(t);alert("Copied!"); }
    function startClock(){ setInterval(function(){ var n=new Date(); var utc = n.getTime()+(n.getTimezoneOffset()*60000); var th=new Date(utc+25200000); var h=th.getHours(),m=th.getMinutes(),s=th.getSeconds(),ap=h>=12?'PM':'AM'; h=h%12||12; h=h<10?'0'+h:h; m=m<10?'0'+m:m; s=s<10?'0'+s:s; document.getElementById('liveTime').innerHTML=h+':'+m+':'+s+' '+ap; document.getElementById('liveDate').innerHTML=th.toDateString(); }, 1000); }
    const cvs=document.getElementById('bgCanvas'),ctx=cvs.getContext('2d');
    let pts=[],hue=0; function init(){cvs.width=window.innerWidth;cvs.height=window.innerHeight;} window.onresize=init; init();
    class Pt{constructor(){this.x=Math.random()*cvs.width;this.y=Math.random()*cvs.height;this.vx=(Math.random()-0.5)*0.8;this.vy=(Math.random()-0.5)*0.8;this.r=Math.random()*2+1;} up(){this.x+=this.vx;this.y+=this.vy;if(this.x<0||this.x>cvs.width)this.vx*=-1;if(this.y<0||this.y>cvs.height)this.vy*=-1;} dr(){ctx.beginPath();ctx.arc(this.x,this.y,this.r,0,Math.PI*2);ctx.fillStyle='rgba(255,255,255,0.1)';ctx.fill();}}
    for(let i=0;i<70;i++)pts.push(new Pt());
    function anim(){ctx.clearRect(0,0,cvs.width,cvs.height);hue+=0.5;pts.forEach((p,i)=>{p.up();p.dr();for(let j=i+1;j<pts.length;j++){let d=Math.hypot(p.x-pts[j].x,p.y-pts[j].y);if(d<110){ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.lineTo(pts[j].x,pts[j].y);ctx.strokeStyle='hsla('+(hue+d)+',70%,60%,'+(1-d/110)*0.8+')';ctx.lineWidth=0.8;ctx.stroke();}}});requestAnimationFrame(anim);} anim();
</script></body></html>"""

SETTINGS_HTML = """<!doctype html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
    body { background: #050810; color: #fff; font-family: sans-serif; padding: 20px; }
    .card { background: rgba(16, 22, 42, 0.9); padding: 15px; border-radius: 12px; border: 2px solid #00d4ff; margin-bottom: 20px; }
    input { width: 100%; padding: 12px; margin: 8px 0; background: #000; color: #fff; border: 1.5px solid #ff4500; border-radius: 10px; box-sizing: border-box; }
    .btn { background: #00d4ff; padding: 12px; border: none; border-radius: 10px; width: 100%; font-weight: bold; cursor: pointer; color: #000; }
</style>
</head><body>
    <h2>စက်တင်များ</h2>
    <div class="card">
        <h4>Admin Security</h4>
        <form method="post" action="/update_pass">
            <input name="old_u" placeholder="အက်ဒမင်အမည်ဟောင်း">
            <input name="old_p" type="password" placeholder="စကားဝှက်အဟောင်း">
            <input name="new_p" type="password" placeholder="စကားဝှက်အသစ်">
            <button class="btn">Update Admin</button>
        </form>
    </div>
    <div class="card">
        <h4>Telegram Bot Connect</h4>
        <form method="post" action="/update_tg">
            <input name="token" placeholder="Bot Token" value="{{token}}">
            <input name="chat_id" placeholder="Chat ID" value="{{chat_id}}">
            <button class="btn">Save Token</button>
        </form>
    </div>
    <a href="/" style="color:#aaa; text-decoration:none;"><i class="fas fa-arrow-left"></i> ရှေ့သို့ပြန်သွားမည်</a>
</body></html>"""

@app.route("/")
def index():
    u_list = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: u_list = json.load(f)
    conntrack = subprocess.run("conntrack -L -p udp 2>/dev/null", shell=True, capture_output=True, text=True).stdout
    today = datetime.datetime.now().date()
    for u in u_list:
        u["online"] = f"dport={u.get('port')}" in conntrack
        exp_date = datetime.datetime.strptime(u['expires'], '%Y-%m-%d').date()
        u["days_left"] = (exp_date - today).days
    ip = subprocess.run("curl -s icanhazip.com", shell=True, capture_output=True, text=True).stdout.strip()
    return render_template_string(HTML, users=u_list, active_count=sum(1 for u in u_list if u["online"]), ip=ip, logo=OFFICIAL_LOGO, sys=get_sys_info(), tg=get_env("SUPPORT_TG"), fb=get_env("SUPPORT_FB"), msg=get_env("SUPPORT_MSG"))

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
    if session.get("auth") and hmac.compare_digest(request.form.get("old_u"), get_env("WEB_ADMIN_USER")) and hmac.compare_digest(request.form.get("old_p"), get_env("WEB_ADMIN_PASSWORD")):
        set_env("WEB_ADMIN_PASSWORD", request.form.get("new_p"))
    return redirect("/settings")

@app.route("/update_tg", methods=["POST"])
def update_tg():
    if session.get("auth"):
        set_env("TG_TOKEN", request.form.get("token")); set_env("TG_CHAT_ID", request.form.get("chat_id"))
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
    name, days = request.form.get("user"), request.form.get("days")
    with open("/etc/zivpn/users.json", "r") as f: users = json.load(f)
    for u in users:
        if u["user"] == name:
            cur_exp = datetime.datetime.strptime(u['expires'], '%Y-%m-%d')
            u['expires'] = (cur_exp + datetime.timedelta(days=int(days))).strftime('%Y-%m-%d'); break
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
