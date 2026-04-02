#!/bin/bash
# CMT ZIVPN PRO - FINAL STABLE BOT FIX
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
    echo "SUPPORT_TG=https://t.me/CMT_1411" >> "$ENVF"
    echo "SUPPORT_FB=https://www.facebook.com/ChitMinThu1239" >> "$ENVF"
    echo "SUPPORT_MSG=https://m.me/ChitMinThu1239" >> "$ENVF"
fi

cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, hmac, datetime, requests, psutil, threading, time
from flask import Flask, render_template_string, request, redirect, session, url_for

app = Flask(__name__)
app.secret_key = os.environ.get("WEB_SECRET")

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

# --- Telegram Bot Engine (No Library needed, more stable) ---
def bot_polling():
    token = get_env("TG_TOKEN")
    last_update_id = 0
    if not token or ":" not in token: return

    while True:
        try:
            url = f"https://api.telegram.org/bot{token}/getUpdates?offset={last_update_id + 1}&timeout=30"
            resp = requests.get(url, timeout=40).json()
            if "result" in resp:
                for update in resp["result"]:
                    last_update_id = update["update_id"]
                    if "message" in update:
                        msg = update["message"]
                        text = msg.get("text", "")
                        chat_id = str(msg["chat"]["id"])
                        
                        if chat_id != get_env("TG_CHAT_ID"): continue

                        if text.startswith("/start"):
                            requests.get(f"https://api.telegram.org/bot{token}/sendMessage?chat_id={chat_id}&text=👋 Mingalarpar Admin! Bot connected to Panel.")
                        
                        elif text.startswith("/adduser"):
                            try:
                                args = text.split()
                                u, d = args[1], args[2]
                                exp = (datetime.datetime.now() + datetime.timedelta(days=int(d))).strftime("%Y-%m-%d")
                                u_list = []
                                if os.path.exists("/etc/zivpn/users.json"):
                                    with open("/etc/zivpn/users.json","r") as f: u_list = json.load(f)
                                u_list.insert(0, {"user":u, "password":"455", "expires":exp, "port":str(6000+len(u_list))})
                                with open("/etc/zivpn/users.json","w") as f: json.dump(u_list, f, indent=2, ensure_ascii=False)
                                requests.get(f"https://api.telegram.org/bot{token}/sendMessage?chat_id={chat_id}&text=✅ User {u} added for {d} days!")
                                subprocess.run("systemctl restart zivpn", shell=True)
                            except:
                                requests.get(f"https://api.telegram.org/bot{token}/sendMessage?chat_id={chat_id}&text=❌ Usage: /adduser [name] [days]")
        except: time.sleep(10)
        time.sleep(1)

threading.Thread(target=bot_polling, daemon=True).start()

# --- Website Pages ---
HTML = """<!doctype html>
<html lang="my"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CMT ZIVPN PRO</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
<style>
    :root { --bg: #050810; --card: rgba(16, 22, 42, 0.95); --cyan: #00d4ff; --green: #2ecc71; --purple: #9b59b6; --yellow: #ffaa00; }
    body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; }
    .header { background: rgba(0,0,0,0.7); padding: 10px 15px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); }
    .logo-img { border-radius: 50%; width: 50px; height: 50px; background: #fff; box-shadow: 0 0 10px #fff; border: 2px solid #fff; }
    .action-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin: 20px 15px; }
    .action-box { background: var(--card); padding: 15px 5px; border-radius: 12px; border: 2px solid rgba(0, 212, 255, 0.4); text-align: center; cursor: pointer; }
    .main-btn { background: linear-gradient(90deg, #ff0000, #ffaa00, #00d4ff); padding: 12px; border: none; border-radius: 12px; color: #fff; width: 100%; font-weight: bold; cursor: pointer; }
</style>
</head><body>
{% if not session.get('auth') %}
    <div style="max-width:320px; margin:20vh auto; background:var(--card); padding:35px; border-radius:20px; text-align:center; border:3px solid #ff4500;">
        <h2>CMT LOGIN</h2>
        <form method="post" action="/login_check"><input style="width:100%;padding:10px;margin:10px 0;background:#000;color:#fff;border:1px solid var(--cyan);border-radius:8px;" name="u" placeholder="Admin"><input style="width:100%;padding:10px;margin:10px 0;background:#000;color:#fff;border:1px solid var(--cyan);border-radius:8px;" name="p" type="password" placeholder="Pass"><button class="main-btn">ဝင်မည်</button></form>
    </div>
{% else %}
    <div class="header">
        <img src="https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png" class="logo-img">
        <h3 class="rainbow-text" style="font-weight:bold; background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #ff0000); background-size: 300% 300%; -webkit-background-clip: text; -webkit-text-fill-color: transparent; animation: rb 5s linear infinite;">CMT PRO</h3>
        <a href="/settings" style="color:var(--cyan);font-size:1.5em;"><i class="fas fa-cog"></i></a>
    </div>
    <div class="action-grid">
        <div class="action-box" onclick="location.href='/'"><i class="fas fa-users" style="color:var(--green);"></i><span>Users</span></div>
        <div class="action-box" onclick="location.href='/settings'"><i class="fas fa-robot" style="color:var(--purple);"></i><span>Bot Set</span></div>
        <div class="action-box" onclick="location.href='/logout'"><i class="fas fa-power-off" style="color:#ff4444;"></i><span>Exit</span></div>
    </div>
    <div style="padding:15px; text-align:center;">
        <h4 style="color:var(--cyan)">Bot တကယ်အလုပ်လုပ်၊ မလုပ် Telegram မှာ /start ပို့စမ်းကြည့်ပါ။</h4>
    </div>
{% endif %}
<script>
    function copyVal(v){ var t=document.createElement("textarea");document.body.appendChild(t);t.value=v;t.select();document.execCommand("copy");document.body.removeChild(t);alert("Copied!"); }
</script></body></html>"""

@app.route("/")
def index():
    if not session.get("auth"): return render_template_string(HTML)
    return render_template_string(HTML)

@app.route("/login_check", methods=["POST"])
def login_check():
    if hmac.compare_digest(request.form.get("u"), get_env("WEB_ADMIN_USER")) and hmac.compare_digest(request.form.get("p"), get_env("WEB_ADMIN_PASSWORD")):
        session["auth"] = True
    return redirect("/")

@app.route("/settings")
def settings():
    if not session.get("auth"): return redirect("/")
    return render_template_string("<!doctype html><html><head><style>body{background:#050810;color:#fff;font-family:sans-serif;padding:20px;}.card{background:rgba(16,22,42,0.9);padding:15px;border-radius:12px;border:1px solid #00d4ff;margin-bottom:20px;}input{width:100%;padding:10px;margin:8px 0;background:#000;color:#fff;border:1px solid #ff4500;border-radius:10px;width:100%;box-sizing:border-box;}.btn{background:#00d4ff;padding:12px;border:none;border-radius:10px;width:100%;font-weight:bold;cursor:pointer;color:#000;}</style></head><body><h2>Bot Settings</h2><div class='card'><h4>Telegram Bot Connect</h4><form method='post' action='/update_tg'><p>Bot Token:</p><input name='token' value='{{token}}'><p>Your Chat ID:</p><input name='chat_id' value='{{chat_id}}'><button class='btn'>Save Token & Start Bot</button></form></div><a href='/' style='color:#aaa;text-decoration:none;'>Back Home</a></body></html>", token=get_env("TG_TOKEN"), chat_id=get_env("TG_CHAT_ID"))

@app.route("/update_tg", methods=["POST"])
def update_tg():
    if session.get("auth"):
        set_env("TG_TOKEN", request.form.get("token"))
        set_env("TG_CHAT_ID", request.form.get("chat_id"))
        subprocess.run("systemctl restart zivpn-web", shell=True)
    return redirect("/settings")

@app.route("/logout")
def logout(): session.clear(); return redirect("/")

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

systemctl daemon-reload && systemctl restart zivpn-web
IP=$(hostname -I | awk '{print $1}')
echo -e "\n✅ Final Bot Fix! Website: http://$IP:8080"
