#!/bin/bash
# CMT ZIVPN PRO - ULTIMATE FINAL FIX (ERROR FREE)
set -euo pipefail
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl python3-pip >/dev/null
pip3 install psutil requests >/dev/null

mkdir -p /etc/zivpn
ENVF="/etc/zivpn/web.env"
USERS="/etc/zivpn/users.json"

# Initialize env file if missing
if [ ! -f "$ENVF" ]; then
    echo "WEB_ADMIN_USER=admin" > "$ENVF"
    echo "WEB_ADMIN_PASSWORD=admin" >> "$ENVF"
    echo "WEB_SECRET=$(openssl rand -hex 16)" >> "$ENVF"
    echo "SUPPORT_TG=https://t.me/CMT_1411" >> "$ENVF"
    echo "SUPPORT_FB=https://www.facebook.com/ChitMinThu1239" >> "$ENVF"
fi

cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, hmac, datetime, requests, psutil
from flask import Flask, render_template_string, request, redirect, session

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

def get_usage(port):
    if not port: return "0.0 MB"
    try:
        out = subprocess.run(f"iptables -L ZIVPN_TRAFFIC -n -v -x | grep 'dpt:{port}'", shell=True, capture_output=True, text=True).stdout
        total = sum(int(l.split()[1]) for l in out.strip().split('\n') if l)
        return f"{round(total/1024**2, 2)} MB" if total < 1024**3 else f"{round(total/1024**3, 2)} GB"
    except: return "0.0 MB"

HTML = """<!doctype html>
<html lang="my"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CMT ZIVPN PRO</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
<style>
    :root { --bg: #050810; --card: rgba(16, 22, 42, 0.92); --glow: #ff4500; --cyan: #00d4ff; --yellow: #ffaa00; --green: #2ecc71; }
    body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 80px; overflow-x: hidden; }
    #bgCanvas { position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: -1; }
    @keyframes rb { 0%{background-position:0% 50%} 50%{background-position:100% 50%} 100%{background-position:0% 50%} }
    .rainbow-text { font-weight: bold; background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #ff0000); background-size: 300%; -webkit-background-clip: text; -webkit-text-fill-color: transparent; animation: rb 5s linear infinite; }
    .header { background: rgba(0,0,0,0.6); padding: 10px 15px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); }
    .logo-img { border-radius: 50%; width: 55px; height: 55px; background: #fff; border: 2px solid #fff; box-shadow: 0 0 10px #fff; }
    .container { padding: 15px; }
    .grid-menu { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin-bottom: 15px; }
    .grid-box { background: var(--card); border: 2px solid var(--glow); border-radius: 12px; padding: 10px; text-align: center; }
    .card { background: var(--card); padding: 20px; border-radius: 15px; border: 1.5px solid var(--glow); margin-bottom: 15px; }
    input { width: 100%; padding: 12px; margin: 8px 0; background: #000; color: #fff; border: 1.5px solid var(--cyan); border-radius: 10px; box-sizing: border-box; outline: none; }
    .main-btn { background: linear-gradient(90deg, #ff0000, #ffaa00, #00d4ff); padding: 12px; border: none; border-radius: 10px; color: #fff; width: 100%; font-weight: bold; cursor: pointer; }
    .table-card { background: var(--card); border-radius: 12px; border: 1.5px solid var(--cyan); overflow-x: auto; padding: 10px; }
    table { width: 100%; border-collapse: collapse; min-width: 600px; }
    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #333; font-size: 0.9em; }
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
        <div class="grid-menu" style="grid-template-columns: repeat(3, 1fr);">
            <div class="grid-box" style="border-color:var(--cyan);"><small>CPU</small><div style="color:var(--cyan)">{{sys.cpu}}%</div></div>
            <div class="grid-box" style="border-color:var(--yellow);"><small>RAM</small><div style="color:var(--yellow)">{{sys.ram}}%</div></div>
            <div class="grid-box" style="border-color:var(--green);"><small>DISK</small><div style="color:var(--green)">{{sys.disk}}%</div></div>
        </div>
        <div class="card">
            <form method="post" action="/add"><input name="user" placeholder="အမည် (မြန်မာလိုရသည်)"><input name="password" placeholder="စကားဝှက်"><input name="days" placeholder="ရက်ပေါင်း"><button class="main-btn">အကောင့်ဆောက်မည်</button></form>
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
    </div>
    <div style="padding: 15px; display: flex; justify-content: center; gap: 15px;">
        <a href="{{support_tg}}" target="_blank" style="background:#0088cc; color:white; padding:10px 15px; border-radius:10px; text-decoration:none;"><i class="fab fa-telegram-plane"></i> Support</a>
    </div>
{% endif %}
<script>
    function copyVal(v){ var t=document.createElement("textarea");document.body.appendChild(t);t.value=v;t.select();document.execCommand("copy");document.body.removeChild(t);alert("Copied!"); }
    function startClock(){ setInterval(function(){ var n=new Date(); var mm=new Date(n.getTime()+(n.getTimezoneOffset()*60000)+23400000); var h=mm.getHours(),m=mm.getMinutes(),s=mm.getSeconds(),ap=h>=12?'PM':'AM'; h=h%12||12; h=h<10?'0'+h:h; m=m<10?'0'+m:m; s=s<10?'0'+s:s; document.getElementById('liveTime').innerHTML=h+':'+m+':'+s+' '+ap; document.getElementById('liveDate').innerHTML=mm.toDateString(); }, 1000); }
</script></body></html>"""

@app.route("/")
def index():
    u_list = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: u_list = json.load(f)
    conntrack = subprocess.run("conntrack -L -p udp 2>/dev/null", shell=True, capture_output=True, text=True).stdout
    active_count = sum(1 for u in u_list if f"dport={u.get('port')}" in conntrack)
    for u in u_list: u["online"] = f"dport={u.get('port')}" in conntrack
    ip = subprocess.run("curl -s icanhazip.com", shell=True, capture_output=True, text=True).stdout.strip()
    return render_template_string(HTML, users=u_list, active_count=active_count, ip=ip, logo=OFFICIAL_LOGO, sys=get_sys_info(), support_tg=get_env("SUPPORT_TG"))

@app.route("/login_check", methods=["POST"])
def login_check():
    if hmac.compare_digest(request.form.get("u"), get_env("WEB_ADMIN_USER")) and hmac.compare_digest(request.form.get("p"), get_env("WEB_ADMIN_PASSWORD")):
        session["auth"] = True
    return redirect("/")

@app.route("/add", methods=["POST"])
def add():
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

@app.route("/delete", methods=["POST"])
def delete():
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
echo -e "\n✅🤍 Fixed Success! http://$(hostname -I | awk '{print $1}'):8080"
