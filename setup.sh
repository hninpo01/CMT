#!/bin/bash
# CMT ZIVPN PRO - FINAL FIX MYANMAR EDITION
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
        total = sum(int(l.split()[1]) for l in out.strip().split('\n') if l)
        return f"{round(total/1024**2, 2)} MB" if total < 1024**3 else f"{round(total/1024**3, 2)} GB"
    except: return "0.0 MB"

def get_uptime():
    try:
        with open('/proc/uptime', 'r') as f:
            up = float(f.readline().split()[0])
            h, r = divmod(int(up), 3600); m, s = divmod(r, 60)
            return f"{h}နာရီ {m}မိနစ်"
    except: return "0နာရီ"

HTML = """<!doctype html>
<html lang="my" translate="no">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>CMT ZIVPN PRO</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.88); --glow: #ff4500; --cyan: #00d4ff; --yellow: #ffaa00; --green: #2ecc71; --purple: #9b59b6; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; overflow-x: hidden; }
        #bgCanvas { position: fixed; top:0; left:0; width:100%; height:100%; z-index:-1; }
        @keyframes rainbowBG { 0% { background-position: 0% 50%; } 50% { background-position: 100% 50%; } 100% { background-position: 0% 50%; } }
        .rainbow-text { font-weight: bold; background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #9b59b6, #ff0000); background-size: 300% 300%; -webkit-background-clip: text; -webkit-text-fill-color: transparent; animation: rainbowBG 5s linear infinite; }
        .title-container { text-align: center; padding: 15px 0; border-bottom: 2px solid var(--cyan); background: rgba(0,0,0,0.6); backdrop-filter: blur(10px); }
        .header { background: rgba(0,0,0,0.5); padding: 10px 15px; display: flex; align-items: center; justify-content: space-between; }
        .header img { border-radius: 50%; width: 42px; height: 42px; background: #fff; box-shadow: 0 0 10px #fff; }
        .clock-center { flex-grow: 1; text-align: center; }
        .clock-time { font-size: 1.1em; font-weight: bold; }
        .social-row { display: flex; gap: 8px; }
        .btn-social { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border-radius: 50%; color: white; text-decoration: none; font-size: 1.1em; }
        .container { padding: 15px; }
        .grid-menu { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin-bottom: 15px; }
        .grid-box { background: var(--card); border: 2px solid var(--glow); border-radius: 12px; padding: 10px; text-align: center; }
        .grid-box.full { grid-column: span 2; border-color: var(--purple); }
        .grid-val { font-size: 1.2em; font-weight: bold; color: var(--yellow); }
        .card { background: var(--card); padding: 20px; border-radius: 20px; border: 2.5px solid var(--glow); margin-bottom: 15px; }
        input { width: 100%; padding: 15px 20px; margin: 12px 0; background: linear-gradient(90deg, #ff000022, #00d4ff22); background-size: 400%; animation: rainbowBG 8s infinite; color: #fff; border: 2px solid var(--cyan); border-radius: 12px; outline: none; font-weight: bold; }
        .main-btn { background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #ff0000); background-size: 300%; animation: rainbowBG 4s linear infinite; color: #fff; border: none; padding: 15px; border-radius: 12px; font-weight: bold; width: 100%; cursor: pointer; }
        .table-card { background: var(--card); border-radius: 15px; border: 2.5px solid var(--cyan); padding: 12px; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; min-width: 550px; }
        th { text-align: left; padding: 12px; color: var(--cyan); border-bottom: 2px solid #1e293b; font-size: 0.8em; }
        td { padding: 15px 12px; border-bottom: 1px solid #1e293b; font-size: 0.9em; }
        .copy-btn { color: var(--cyan); cursor: pointer; margin-left: 8px; transition: 0.2s; }
        .copy-btn:active { transform: scale(1.3); }
        .delete-btn { color: #ff4444; background: none; border: none; font-size: 1.2em; cursor: pointer; }
        .bottom-nav { position: fixed; bottom: 0; left: 0; width: 100%; background: #0a0e1a; display: flex; justify-content: space-around; padding: 15px 0; border-top: 2px solid var(--cyan); }
    </style>
</head>
<body onload="startClock()">
<canvas id="bgCanvas"></canvas>
{% if not session.get('auth') %}
    <div style="max-width:320px; margin:20vh auto; background:var(--card); padding:35px; border-radius:20px; text-align:center; border:3px solid var(--glow);">
        <img src="{{logo}}" width="80" style="background:#fff; border-radius:15px; margin-bottom:20px;">
        <h2 class="rainbow-text">စီအမ်တီ လော့ဂ်အင်</h2>
        <form method="post" action="/login_check"><input name="u" placeholder="အမည်" required><input name="p" type="password" placeholder="စကားဝှက်" required><button class="main-btn" style="margin-top:15px;">အကောင့်ဝင်ရန်</button></form>
    </div>
{% else %}
    <div class="title-container"><h1 class="main-title rainbow-text">CMT ZIVPN PRO</h1></div>
    <div class="header">
        <img src="{{ logo }}">
        <div class="clock-center">
            <div id="liveTime" class="clock-time rainbow-text">00:00:00 AM</div>
            <div id="liveDate" style="font-size:0.6em; color:#aaa;">Loading...</div>
        </div>
        <div class="social-row">
            <a href="https://t.me/CMT_1411" class="btn-social" style="background:#0088cc;"><i class="fab fa-telegram-plane"></i></a>
            <a href="https://www.facebook.com/ChitMinThu1239" class="btn-social" style="background:#1877f2;"><i class="fab fa-facebook-f"></i></a>
            <a href="https://m.me/ChitMinThu1239" class="btn-social" style="background:linear-gradient(45deg, #00c6ff, #bc00ff);"><i class="fab fa-facebook-messenger"></i></a>
        </div>
    </div>
    <div class="container">
        <div style="text-align:center; margin-bottom:12px; background:rgba(0,0,0,0.6); padding:8px; border-radius:10px; border:1px solid var(--cyan); font-size:0.8em;">
            ဆာဗာ IP: <span id="sip">{{ ip }}</span> <i class="fas fa-copy copy-btn" onclick="copyValue('sip')"></i>
        </div>
        <div class="grid-menu">
            <div class="grid-box"><div style="font-size:0.7em; color:#aaa;">အသုံးပြုသူစုစုပေါင်း</div><div class="grid-val">{{ users|length }}</div></div>
            <div class="grid-box" style="border-color:var(--green);"><div style="font-size:0.7em; color:#aaa;">အွန်လိုင်း</div><div class="grid-val" style="color:var(--green);">{{ active_count }}</div></div>
            <div class="grid-box full"><div style="font-size:0.7em; color:#aaa;">ဆာဗာသက်တမ်း: <span style="color:var(--purple); font-size:1.4em;">{{ uptime }}</span></div></div>
        </div>
        <div class="card">
            <form method="post" action="/add"><input name="user" placeholder="အမည် (မြန်မာလိုပေးနိုင်သည်)" required><input name="password" placeholder="စကားဝှက် (အင်္ဂလိပ်/ဂဏန်း)" required><input name="days" placeholder="ရက်အရေအတွက်" required><button class="main-btn">အကောင့်အသစ်ဆောက်မည်</button></form>
        </div>
        <div class="table-card">
            <table>
                <thead><tr><th>အမည်</th><th>စကားဝှက်</th><th>ဒေတာ</th><th>သက်တမ်းကုန်ရက်</th><th>အခြေအနေ</th><th>ဖျက်ရန်</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan); font-weight:bold;">{{ u.user }}</td>
                        <td><span id="pw{{loop.index}}">{{ u.password }}</span> <i class="fas fa-copy copy-btn" onclick="copyValue('pw{{loop.index}}')"></i></td>
                        <td style="color:var(--yellow); font-weight:bold;">{{ u.usage }}</td>
                        <td style="color:#ff69b4;">{{ u.expires }}</td>
                        <td>
                            {% if u.online %}
                                <span style="color:var(--green); font-size:0.8em;"><i class="fas fa-circle"></i> Online</span>
                            {% else %}
                                <span style="color:#e74c3c; font-size:0.8em;"><i class="fas fa-circle"></i> Offline</span>
                            {% endif %}
                        </td>
                        <td><form method="post" action="/delete" style="display:inline;" onsubmit="return confirm('ဖျက်မှာ သေချာလား?')"><input type="hidden" name="user" value="{{u.user}}"><button type="submit" class="delete-btn"><i class="fas fa-trash-alt"></i></button></form></td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>
    <div class="bottom-nav"><a href="/" style="color:var(--cyan); font-size:1.6em;"><i class="fas fa-home"></i></a><a href="/logout" style="color:#555; font-size:1.6em;"><i class="fas fa-power-off"></i></a></div>
{% endif %}
<script>
    function copyValue(id) {
        var val = document.getElementById(id).innerText;
        var t = document.createElement("textarea"); document.body.appendChild(t); t.value = val; t.select(); document.execCommand("copy"); document.body.removeChild(t);
        alert("ကူးယူပြီးပါပြီ: " + val);
    }
    function startClock() { 
        setInterval(function() { 
            var n = new Date(); var utc = n.getTime() + (n.getTimezoneOffset() * 60000); var mm = new Date(utc + 23400000);
            var h = mm.getHours(), m = mm.getMinutes(), s = mm.getSeconds(), ap = h >= 12 ? 'PM' : 'AM'; 
            h = h % 12; h = h ? h : 12; h = h < 10 ? '0'+h : h; m = m < 10 ? '0'+m : m; s = s < 10 ? '0'+s : s; 
            document.getElementById('liveTime').innerHTML = h + ':' + m + ':' + s + ' ' + ap; 
            var ds = ['တနင်္ဂနွေ', 'တနင်္လာ', 'အင်္ဂါ', 'ဗုဒ္ဓဟူး', 'ကြာသပတေး', 'သောကြာ', 'စနေ'], ms = ['ဇန်နဝါရီ', 'ဖေဖော်ဝါရီ', 'မတ်', 'ဧပြီ', 'မေ', 'ဇွန်', 'ဇူလိုင်', 'သြဂုတ်', 'စက်တင်ဘာ', 'အောက်တိုဘာ', 'နိုဝင်ဘာ', 'ဒီဇင်ဘာ']; 
            document.getElementById('liveDate').innerHTML = ds[mm.getDay()] + '၊ ' + mm.getDate() + ' ' + ms[mm.getMonth()] + ' ' + mm.getFullYear(); 
        }, 1000); 
    }
    const cvs = document.getElementById('bgCanvas'), ctx = cvs.getContext('2d');
    let pts = [], hue = 0;
    function init() { cvs.width = window.innerWidth; cvs.height = window.innerHeight; }
    window.onresize = init; init();
    class Pt { constructor() { this.x = Math.random()*cvs.width; this.y = Math.random
