#!/bin/bash
# CMT ZIVPN PRO - PERMANENT LINKS & FULL MYANMAR
set -euo pipefail
apt-get update -y && apt-get install -y curl jq python3 python3-flask conntrack iptables openssl python3-pip >/dev/null
pip3 install psutil requests >/dev/null

mkdir -p /etc/zivpn
ENVF="/etc/zivpn/web.env"

# ✅ အစ်ကို့ရဲ့ Link တွေကို ဒီမှာ အသေထည့်ပေးထားပါတယ်
cat > "$ENVF" <<EOF
WEB_ADMIN_USER=admin
WEB_ADMIN_PASSWORD=admin
WEB_SECRET=$(openssl rand -hex 16)
TG_TOKEN=
TG_CHAT_ID=
SUPPORT_TG=https://t.me/CMT_1411
SUPPORT_FB=https://www.facebook.com/ChitMinThu1239
SUPPORT_MSG=https://m.me/ChitMinThu1239
EOF

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
    :root { --bg: #050810; --card: rgba(16, 22, 42, 0.95); --glow: #ff4500; --cyan: #00d4ff; --yellow: #ffaa00; --green: #2ecc71; }
    body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; overflow-x: hidden; }
    #bgCanvas { position: fixed; top:0; left:0; width:100%; height:100%; z-index:-1; }
    @keyframes rb { 0%{background-position:0% 50%} 50%{background-position:100% 50%} 100%{background-position:0% 50%} }
    .rainbow-text { font-weight: bold; background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #ff0000); background-size: 300% 300%; -webkit-background-clip: text; -webkit-text-fill-color: transparent; animation: rb 5s linear infinite; }
    .header { background: rgba(0,0,0,0.7); padding: 10px 15px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); }
    .logo-img { border-radius: 50%; width: 50px; height: 50px; background: #fff; box-shadow: 0 0 10px #fff; }
    .clock-center { flex-grow: 1; text-align: center; }
    .container { padding: 15px; }
    .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 20px; }
    .grid-box { background: var(--card); border: 2px solid var(--glow); border-radius: 12px; padding: 10px; text-align: center; }
    .modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); }
    .modal-content { background: var(--card); margin: 15% auto; padding: 25px; width: 85%; max-width: 350px; border-radius: 20px; border: 2px solid var(--cyan); }
    input { width: 100%; padding: 12px; margin: 10px 0; background: #000; color: #fff; border: 1.5px solid var(--cyan); border-radius: 10px; box-sizing: border-box; outline: none; }
    .main-btn { background: linear-gradient(90deg, #ff0000, #ffaa00, #00d4ff); padding: 15px; border: none; border-radius: 12px; color: #fff; width: 100%; font-weight: bold; cursor: pointer; }
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
        <h2 class="rainbow-text">စီအမ်တီ လော့ဂ်အင်</h2>
        <form method="post" action="/login_check"><input name="u" placeholder="Admin"><input name="p" type="password" placeholder="Pass"><button class="main-btn">ဝင်မည်</button></form>
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

        <div style="text-align:center; margin-bottom:20px;">
            <button class="main-btn" onclick="toggleModal('addModal')" style="width:220px; background:var(--green);">
                <i class="fas fa-user-plus"></i> အကောင့်သစ်ဖွင့်ရန်
            </button>
        </div>

        <div id="addModal" class="modal">
            <div class="modal-content">
                <h3 class="rainbow-text">အကောင့်အသစ်ဆောက်ပါ</h3>
                <form method="post" action="/add">
                    <input name="user" placeholder="အမည် (မြန်မာလိုရသည်)" required>
                    <input name="password" placeholder="စကားဝှက်" required>
                    <input name="days" placeholder="ရက်ပေါင်း" required>
                    <button class="main-btn">ဆောက်မည်</button>
                </form>
                <button onclick="toggleModal('addModal')" style="background:none;border:none;color:#ff4444;width:100%;margin-top:10px;cursor:pointer;">ပိတ်မည်</button>
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

        <div style="text-align:center; padding:20px;">
            <button class="main-btn" onclick="toggleModal('supportModal')" style="width:200px; background:var(--cyan); color:#000;"><i class="fas fa-headset"></i> ဆက်သွယ်ရန်</button>
        </div>
    </div>

    <div id="supportModal" class="modal">
        <div class="modal-content" style="text-align:center;">
            <h3 class="rainbow-text">ဆက်သွယ်ရန် ရွေးချယ်ပါ</h3>
            <a href="{{tg}}" target="_blank" style="display:block;padding:12px;margin:10px 0;background:#0088cc;color:#fff;border-radius:10px;text-decoration:none;font-weight:bold;"><i class="fab fa-telegram-plane"></i> Telegram</a>
            <a href="{{fb}}" target="_blank" style="display:block;padding:12px;margin:10px 0;background:#1877f2;color:#fff;border-radius:10px;text-decoration:none;font-weight:bold;"><i class="fab fa-facebook-f"></i> Facebook</a>
            <a href="{{msg}}" target="_blank" style="display:block;padding:12px;margin:10px 0;background:linear-gradient(45deg,#00c6ff,#bc00ff);color:#fff;border-radius:10px;text-decoration:none;font-weight:bold;"><i class="fab fa-facebook-messenger"></i> Messenger</a>
            <button onclick="toggleModal('supportModal')" style="background:none;border:none;color:#aaa;margin-top:15px;cursor:pointer;">ပိတ်မည်</button>
        </div>
    </div>

    <div class="bottom-nav">
        <a href="/" style="color:var(--cyan);font-size:1.8em;"><i class="fas fa-home"></i></a>
        <a href="/logout" style="color:#ff4444;font-size:1.8em;"><i class="fas fa-power-off"></i></a>
    </div>
{% endif %}
<script>
    function toggleModal(id) { var m = document.getElementById(id); m.style.display = m.style.display == 'block' ? 'none' : 'block'; }
    function copyVal(v){ var t=document.createElement("textarea");document.body.appendChild(t);t.value=v;t.select();document.execCommand("copy");document.body.removeChild(t);alert("Copied!"); }
    function startClock(){ setInterval(function(){ var n=new Date(); var mm=new Date(n.getTime()+(n.getTimezoneOffset()*60000)+23
