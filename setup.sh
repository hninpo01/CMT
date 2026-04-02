#!/bin/bash
# CMT ZIVPN PRO - ULTIMATE BUSINESS EDITION (AUTO-RENEW & SECURITY)
set -euo pipefail
apt-get update -y && apt-get install -y curl ufw jq python3 python3-flask conntrack iptables openssl >/dev/null

mkdir -p /etc/zivpn
USERS="/etc/zivpn/users.json"
ENVF="/etc/zivpn/web.env"

# Initial Env if not exist
if [ ! -f "$ENVF" ]; then
    echo "WEB_ADMIN_USER=admin" > "$ENVF"
    echo "WEB_ADMIN_PASSWORD=admin" >> "$ENVF"
    echo "WEB_SECRET=$(openssl rand -hex 16)" >> "$ENVF"
    echo "TG_TOKEN=" >> "$ENVF"
    echo "TG_CHAT_ID=" >> "$ENVF"
fi

cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, hmac, datetime, requests
from flask import Flask, render_template_string, request, redirect, session, url_for

app = Flask(__name__)
app.secret_key = os.environ.get("WEB_SECRET")
OFFICIAL_LOGO = "https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png"

def get_env(key):
    with open("/etc/zivpn/web.env", "r") as f:
        for line in f:
            if line.startswith(key): return line.split("=")[1].strip()
    return ""

def set_env(key, value):
    lines = []
    found = False
    with open("/etc/zivpn/web.env", "r") as f:
        lines = f.readlines()
    with open("/etc/zivpn/web.env", "w") as f:
        for line in lines:
            if line.startswith(key):
                f.write(f"{key}={value}\n")
                found = True
            else: f.write(line)
        if not found: f.write(f"{key}={value}\n")

def send_tg(msg):
    token = get_env("TG_TOKEN")
    chat_id = get_env("TG_CHAT_ID")
    if token and chat_id:
        try: requests.get(f"https://api.telegram.org/bot{token}/sendMessage?chat_id={chat_id}&text={msg}")
        except: pass

def get_usage(port):
    if not port: return "0.0 MB"
    try:
        out = subprocess.run(f"iptables -L ZIVPN_TRAFFIC -n -v -x | grep 'dpt:{port}'", shell=True, capture_output=True, text=True).stdout
        total = sum(int(l.split()[1]) for l in out.strip().split('\n') if l)
        return f"{round(total/1024**2, 2)} MB" if total < 1024**3 else f"{round(total/1024**3, 2)} GB"
    except: return "0.0 MB"

def check_expiry():
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json", "r") as f: users = json.load(f)
        today = datetime.datetime.now().date()
        new_users = [u for u in users if datetime.datetime.strptime(u['expires'], '%Y-%m-%d').date() >= today]
        if len(new_users) != len(users):
            with open("/etc/zivpn/users.json", "w") as f: json.dump(new_users, f, indent=2, ensure_ascii=False)
            subprocess.run("systemctl restart zivpn", shell=True)

HTML = """<!doctype html>
<html lang="my"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CMT ZIVPN PRO</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
<style>
    :root { --bg: #050810; --card: rgba(16, 22, 42, 0.9); --glow: #ff4500; --cyan: #00d4ff; --yellow: #ffaa00; --green: #2ecc71; }
    body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 80px; }
    #bgCanvas { position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: -1; }
    .rainbow-text { font-weight: bold; background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #9b59b6, #ff0000); background-size: 300%; -webkit-background-clip: text; -webkit-text-fill-color: transparent; animation: rb 5s linear infinite; }
    @keyframes rb { 0%{background-position:0% 50%} 50%{background-position:100% 50%} 100%{background-position:0% 50%} }
    .header { background: rgba(0,0,0,0.5); padding: 10px 15px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); }
    .logo-img { border-radius: 50%; width: 50px; height: 50px; background: #fff; border: 2px solid #fff; }
    .container { padding: 15px; }
    .grid-menu { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin-bottom: 15px; }
    .grid-box { background: var(--card); border: 2px solid var(--glow); border-radius: 12px; padding: 10px; text-align: center; }
    .card { background: var(--card); padding: 20px; border-radius: 15px; border: 1.5px solid var(--glow); margin-bottom: 15px; }
    input { width: 100%; padding: 12px; margin: 8px 0; background: #000; color: #fff; border: 1.5px solid var(--cyan); border-radius: 10px; box-sizing: border-box; }
    .main-btn { background: linear-gradient(90deg, #ff0000, #ffaa00, #00d4ff); padding: 12px; border: none; border-radius: 10px; color: #fff; width: 100%; font-weight: bold; cursor: pointer; }
    .table-card { background: var(--card); border-radius: 12px; border: 1.5px solid var(--cyan); overflow-x: auto; padding: 10px; }
    table { width: 100%; border-collapse: collapse; min-width: 600px; }
    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #333; font-size: 0.9em; }
    .badge { padding: 3px 8px; border-radius: 5px; font-size: 0.8em; }
    .bottom-nav { position: fixed; bottom: 0; left: 0; width: 100%; background: #0a0e1a; display: flex; justify-content: space-around; padding: 15px 0; border-top: 2px solid var(--cyan); }
</style>
</head><body onload="startClock()">
<canvas id="bgCanvas"></canvas>
{% if not session.get('auth') %}
    <div style="max-width:320px; margin:20vh auto; background:var(--card); padding:35px; border-radius:20px; text-align:center; border:3px solid var(--glow);">
        <img src="{{logo}}" width="80" style="background:#fff; border-radius:15px; margin-bottom:20px;">
        <h2 class="rainbow-text">စီအမ်တီ လော့ဂ်အင်</h2>
        <form method="post" action="/login_check"><input name="u" placeholder="အမည်"><input name="p" type="password" placeholder="စကားဝှက်"><button class="main-btn">ဝင်မည်</button></form>
    </div>
{% else %}
    <div class="header">
        <img src="{{logo}}" class="logo-img">
        <div style="text-align:center;"><div id="liveTime" class="rainbow-text" style="font-size:1.2em;"></div><div id="liveDate" style="font-size:0.6em;color:#aaa;"></div></div>
        <div class="social-row"><a href="/settings" style="color:var(--cyan);font-size:1.4em;"><i class="fas fa-cog"></i></a></div>
    </div>
    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><div>အသုံးပြုသူ</div><div style="color:var(--yellow);font-weight:bold;">{{users|length}}</div></div>
            <div class="grid-box" style="border-color:var(--green);"><div>အွန်လိုင်း</div><div style="color:var(--green);font-weight:bold;">{{active_count}}</div></div>
        </div>
        <div class="card">
            <h3 style="margin:0 0 10px 0;font-size:1em;" class="rainbow-text">အကောင့်အသစ်ဆောက်ရန်</h3>
            <form method="post" action="/add"><input name="user" placeholder="အမည် (မြန်မာလိုရသည်)"><input name="password" placeholder="စကားဝှက်"><input name="days" placeholder="ရက်ပေါင်း"><button class="main-btn">အကောင့်ဆောက်မည်</button></form>
        </div>
        <div class="table-card">
            <table>
                <thead><tr><th>အမည်</th><th>စကားဝှက်</th><th>သက်တမ်းကုန်</th><th>အခြေအနေ</th><th>လုပ်ဆောင်ချက်</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan)">{{u.user}}</td>
                        <td>{{u.password}} <i class="fas fa-copy" style="cursor:pointer;color:var(--cyan)" onclick="copyVal('{{u.password}}')"></i></td>
                        <td style="color:#ff69b4">{{u.expires}}</td>
                        <td><span class="badge" style="background:{{ 'var(--green)' if u.online else '#e74c3c' }}">{{ 'Online' if u.online else 'Offline' }}</span></td>
                        <td>
                            <div style="display:flex;gap:10px;">
                                <form method="post" action="/renew"><input type="hidden" name="user" value="{{u.user}}"><button style="background:none;border:none;color:var(--yellow);cursor:pointer;"><i class="fas fa-history"></i></button></form>
                                <i class="fas fa-share-alt" style="color:var(--cyan);cursor:pointer;" onclick="copyVal('v2ray://{{u.user}}:{{u.password}}@{{ip}}:443#CMT-{{u.user}}')"></i>
                                <form method="post" action="/delete"><input type="hidden" name="user" value="{{u.user}}"><button style="background:none;border:none;color:#ff4444;cursor:pointer;"><i class="fas fa-trash"></i></button></form>
                            </div>
                        </td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>
    <div class="bottom-nav"><a href="/" style="color:var(--cyan);font-size:1.5em;"><i class="fas fa-home"></i></a><a href="/logout" style="color:#555;font-size:1.5em;"><i class="fas fa-power-off"></i></a></div>
{% endif %}
<script>
    function copyVal(v){ var t=document.createElement("textarea");document.body.appendChild(t);t.value=v;t.select();document.execCommand("copy");document.body.removeChild(t);alert("ကူးယူပြီးပါပြီ"); }
    function startClock(){ setInterval(function(){ var n=new Date(); var mm=new Date(n.getTime()+(n.getTimezoneOffset()*60000)+23400000); var h=mm.getHours(),m=mm.getMinutes(),s=mm.getSeconds(),ap=h>=12?'PM':'AM'; h=h%12||12; h=h<10?'0'+h:h; m=m<10?'0'+m:m; s=s<10?'0'+s:s; document.getElementById('liveTime').innerHTML=h+':'+m+':'+s+' '+ap; document.getElementById('liveDate').innerHTML=mm.toDateString(); }, 1000); }
</script></body></html>"""

SETTINGS_HTML = """<!doctype html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Settings - CMT</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
<style>
    body { background: #050810; color: #fff; font-family: sans-serif; padding: 20px; }
    .card { background: rgba(16, 22, 42, 0.9); padding: 20px; border-radius: 15px; border: 1.5px solid #ff4500; margin-bottom: 20px; }
    input { width: 100%; padding: 12px; margin: 10px 0; background: #000; color: #fff; border: 1.5px solid #00d4ff; border-radius: 10px; box-sizing: border-box; }
    .btn { background: #00d4ff; padding: 12px; border: none; border-radius: 10px; width: 100%; font-weight: bold; cursor: pointer; }
</style>
</head><body>
    <h2><i class="fas fa-cog"></i> ဆက်တင်များ</h2>
    <div class="card">
        <h3>Admin Password ပြောင်းရန်</h3>
        <form method="post" action="/update_pass"><input name="old" type="password" placeholder="စကားဝှက်အဟောင်း"><input name="new" type="password" placeholder="စကားဝှက်အသစ်"><button class="btn">Update Password</button></form>
    </div>
    <div class="card">
        <h3>Telegram Notification (Bot)</h3>
        <form method="post" action="/update_tg"><input name="token" placeholder="Bot Token" value="{{token}}"><input name="chat_id" placeholder="Chat ID" value="{{chat_id}}"><button class="btn">Save TG Settings</button></form>
    </div>
    <a href="/" style="color:#aaa;text-decoration:none;"><i class="fas fa-arrow-left"></i> ရှေ့သို့ပြန်သွားမည်</a>
</body></html>"""

@app.route("/")
def index():
    check_expiry()
    if not session.get("auth"): return render_template_string(HTML, logo=OFFICIAL_LOGO)
    u_list = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: u_list = json.load(f)
    conntrack = subprocess.run("conntrack -L -p udp 2>/dev/null", shell=True, capture_output=True, text=True).stdout
    active_count = sum(1 for u in u_list if f"dport={u.get('port')}" in conntrack)
    for u in u_list: u["online"] = f"dport={u.get('port')}" in conntrack
    ip = subprocess.run("curl -s icanhazip.com", shell=True, capture_output=True, text=True).stdout.strip()
    return render_template_string(HTML, users=u_list, active_count=active_count, ip=ip, logo=OFFICIAL_LOGO)

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
    if session.get("auth") and hmac.compare_digest(request.form.get("old"), get_env("WEB_ADMIN_PASSWORD")):
        set_env("WEB_ADMIN_PASSWORD", request.form.get("new"))
    return redirect("/settings")

@app.route("/update_tg", methods=["POST"])
def update_tg():
    if session.get("auth"):
        set_env("TG_TOKEN", request.form.get("token"))
        set_env("TG_CHAT_ID", request.form.get("chat_id"))
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
    send_tg(f"✅ User Created: {u}\nDays: {d}\nExpires: {exp}")
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
            u['expires'] = (cur_exp + datetime.timedelta(days=30)).strftime('%Y-%m-%d')
            send_tg(f"🔄 Account Renewed: {name}\nNew Expiry: {u['expires']}")
            break
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

# Systemd Fix
cat > /etc/systemd/system/zivpn-web.service <<EOF
[Unit]
Description=ZIVPN Web
After=network.target

[Service]
EnvironmentFile=/etc/zivpn/web.env
ExecStart=/usr/bin/python3 /etc/zivpn/web.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl restart zivpn-web
echo -e "\n✅ Ultimate Panel Updated! http://$(hostname -I | awk '{print $1}'):8080"
