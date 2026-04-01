    #!/bin/bash
# CMT ZIVPN PRO - FINAL STABLE FIX (PASS + IP COPY + USAGE)
set -euo pipefail
apt-get update -y && apt-get install -y curl ufw jq python3 python3-flask conntrack iptables openssl >/dev/null

mkdir -p /etc/zivpn
BIN="/usr/local/bin/zivpn"; CFG="/etc/zivpn/config.json"; USERS="/etc/zivpn/users.json"; ENVF="/etc/zivpn/web.env"

# Admin Credentials
echo "WEB_ADMIN_USER=admin" > "$ENVF"
echo "WEB_ADMIN_PASSWORD=admin" >> "$ENVF"
echo "WEB_SECRET=$(openssl rand -hex 16)" >> "$ENVF"

# Networking & Usage Tracking Setup
sysctl -w net.ipv4.ip_forward=1 >/dev/null
iptables -N ZIVPN_TRAFFIC 2>/dev/null || true
iptables -C FORWARD -j ZIVPN_TRAFFIC 2>/dev/null || iptables -I FORWARD -j ZIVPN_TRAFFIC
iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || true
iptables -t nat -A POSTROUTING -j MASQUERADE 2>/dev/null || true

# Python Script
cat > /etc/zivpn/web.py <<PY
import os, json, subprocess, hmac, datetime
from flask import Flask, render_template_string, request, redirect, session, url_for

app = Flask(__name__)
app.secret_key = os.environ.get("WEB_SECRET")
ADMIN_USER = os.environ.get("WEB_ADMIN_USER")
ADMIN_PASS = os.environ.get("WEB_ADMIN_PASSWORD")

OFFICIAL_LOGO = "https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png"

def get_usage(port):
    if not port: return "0 MB"
    try:
        subprocess.run(f"iptables -L ZIVPN_TRAFFIC -n | grep -q 'dpt:{port}' || iptables -A ZIVPN_TRAFFIC -p udp --dport {port} -j RETURN", shell=True)
        out = subprocess.run(f"iptables -L ZIVPN_TRAFFIC -n -v -x | grep 'dpt:{port}'", shell=True, capture_output=True, text=True).stdout
        bytes_total = sum(int(line.split()[1]) for line in out.strip().split('\\n') if line)
        if bytes_total > 1024**3: return f"{round(bytes_total/1024**3, 2)} GB"
        return f"{round(bytes_total/1024**2, 2)} MB"
    except: return "0 MB"

def get_uptime():
    try:
        with open('/proc/uptime', 'r') as f:
            up_sec = float(f.readline().split()[0])
            return str(datetime.timedelta(seconds=int(up_sec)))
    except: return "0:00:00"

HTML = """<!doctype html>
<html lang="my" translate="no">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>CMT ZIVPN PRO</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root { --bg: #050810; --card: #10162a; --glow: #ff4500; --cyan: #00d4ff; --yellow: #ffaa00; --green: #2ecc71; --purple: #9b59b6; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; }
        #fireCanvas { position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: -1; }
        .header { background: linear-gradient(135deg, #6610f2, #6f42c1); padding: 18px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid #fff; box-shadow: 0 0 20px rgba(110,66,193,0.8); }
        .header img { border-radius: 50%; border: 2px solid #fff; width: 45px; height: 45px; background: #fff; box-shadow: 0 0 10px #fff; }
        .container { padding: 15px; }
        .grid-menu { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin-bottom: 20px; }
        .grid-box { background: var(--card); border: 2.5px solid var(--glow); border-radius: 15px; padding: 12px; text-align: center; box-shadow: 0 0 15px rgba(255, 69, 0, 0.4); }
        .grid-box.full { grid-column: span 2; border-color: var(--purple); box-shadow: 0 0 15px rgba(155, 89, 182, 0.4); }
        .grid-val { font-size: 1.3em; font-weight: bold; color: var(--yellow); text-shadow: 0 0 10px var(--yellow); }
        .grid-label { font-size: 0.7em; color: #aaa; text-transform: uppercase; letter-spacing: 1px; }
        .card { background: var(--card); padding: 25px; border-radius: 20px; border: 2px solid var(--glow); margin-bottom: 20px; box-shadow: 0 0 25px rgba(255, 69, 0, 0.5); }
        input { width: 100%; padding: 14px; margin: 8px 0; background: #000; border: 1.5px solid #444; color: #fff !important; border-radius: 12px; box-sizing: border-box; }
        input:focus { border-color: var(--yellow); box-shadow: 0 0 15px var(--yellow); outline: none; }
        .btn { background: linear-gradient(45deg, #ff4500, #ffaa00); color: #fff; border: none; padding: 15px; border-radius: 12px; font-weight: bold; width: 100%; cursor: pointer; box-shadow: 0 0 20px rgba(255, 69, 0, 0.5); }
        .table-card { background: var(--card); border-radius: 15px; border: 2.5px solid var(--cyan); padding: 15px; overflow-x: auto; box-shadow: 0 0 20px rgba(0, 212, 255, 0.4); }
        table { width: 100%; border-collapse: collapse; min-width: 550px; }
        th { text-align: left; padding: 12px; color: var(--cyan); font-size: 0.8em; border-bottom: 2px solid #1e293b; }
        td { padding: 15px 12px; border-bottom: 1px solid #1e293b; font-size: 0.95em; }
        .usage { color: var(--yellow); font-weight: bold; text-shadow: 0 0 5px var(--yellow); }
        .copy-btn { background: rgba(78, 115, 223, 0.2); color: #4e73df; border: 1px solid #4e73df; padding: 3px 6px; border-radius: 5px; font-size: 0.7em; cursor: pointer; margin-left: 5px; }
        .bottom-nav { position: fixed; bottom: 0; left: 0; width: 100%; background: #0a0e1a; display: flex; justify-content: space-around; padding: 15px 0; border-top: 2px solid #4e73df; }
        .nav-item { color: #555; text-decoration: none; text-align: center; font-size: 0.75em; }
        .nav-item i { font-size: 1.8em; display: block; margin-bottom: 5px; }
        .nav-item.active { color: var(--cyan); text-shadow: 0 0 15px var(--cyan); }
    </style>
</head>
<body>
<canvas id="fireCanvas"></canvas>
{% if not session.get('auth') %}
    <div style="max-width: 330px; margin: 18vh auto; background: var(--card); padding: 40px; border-radius: 25px; text-align: center; border: 3.5px solid var(--glow); box-shadow: 0 0 50px rgba(255, 69, 0, 0.7);">
        <img src="{{ logo }}" width="90" style="background:#fff; border-radius:20px; margin-bottom:25px; box-shadow: 0 0 20px #fff;">
        <h2 style="color:var(--yellow); text-shadow: 0 0 15px var(--yellow);">CMT LOGIN</h2>
        <form method="post" action="/login_check">
            <input name="u" placeholder="Admin Name" required>
            <input name="p" type="password" placeholder="Password" required>
            <button class="btn" style="margin-top:20px;">DASHBOARD LOGIN</button>
        </form>
    </div>
{% else %}
    <div class="header">
        <div style="display:flex;align-items:center;gap:12px;"><img src="{{ logo }}"><b>CMT ZIVPN PRO PANEL</b></div>
        <div style="text-align:right;">
            <small>IP: <span id="srvIp">{{ ip }}</span></small>
            <button class="copy-btn" style="background:#ff4500;color:white;border:none;" onclick="copyText('srvIp')"><i class="fas fa-copy"></i></button>
        </div>
    </div>
    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><div class="grid-label">Total Users</div><div class="grid-val">{{ users|length }}</div></div>
            <div class="grid-box" style="border-color:var(--green);"><div class="grid-label">Online</div><div class="grid-val" style="color:var(--green); text-shadow: 0 0 10px var(--green);">{{ active_count }}</div></div>
            <div class="grid-box full"><div class="grid-label">System Uptime</div><div class="grid-val" style="color:var(--purple); text-shadow: 0 0 10px var(--purple);">{{ uptime }}</div></div>
            <div class="grid-box" style="border-color:#3498db;"><div class="grid-label">Bandwidth</div><div class="grid-val" style="color:#3498db; text-shadow: 0 0 10px #3498db;">0.00</div></div>
            <div class="grid-box" style="border-color:#e67e22;"><div class="grid-label">Server Load</div><div class="grid-val" style="color:#e67e22; text-shadow: 0 0 10px #e67e22;">12%</div></div>
        </div>
        <div class="card">
            <h4 style="color:var(--green); margin:0 0 10px 0;"><i class="fas fa-plus-circle"></i> Add New User</h4>
            <form method="post" action="/add"><input name="user" placeholder="အမည်" required><input name="password" placeholder="စကားဝှက်" required><input name="days" placeholder="ရက်ပေါင်း" required><button class="btn">CREATE & SYNC</button></form>
        </div>
        <div class="table-card">
            <table>
                <thead><tr><th>USER</th><th>PASS</th><th>USAGE</th><th>EXPIRY</th><th>STATUS</th><th>ACTION</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan); font-weight:bold;">{{ u.user }}</td>
                        <td><span id="pw_{{u.user}}">{{ u.password }}</span> <button class="copy-btn" onclick="copyText('pw_{{u.user}}')"><i class="fas fa-copy"></i></button></td>
                        <td class="usage">{{ u.usage }}</td>
                        <td style="color:#ff69b4;">{{ u.expires }}</td>
                        <td><span style="color:{{ '#2ecc71' if u.online else '#e74c3c' }}; font-weight:bold;">● {{ 'Online' if u.online else 'Offline' }}</span></td>
                        <td><form method="post" action="/delete" style="display:inline;"><input type="hidden" name="user" value="{{u.user}}"><button style="background:none;border:none;color:#ff4444;cursor:pointer;"><i class="fas fa-trash-alt"></i></button></form></td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>
    <div class="bottom-nav">
        <a href="/" class="nav-item active"><i class="fas fa-home"></i>ပင်မ</a>
        <a href="#" class="nav-item"><i class="fas fa-users-cog"></i>စီမံမှု</a>
        <a href="#" class="nav-item"><i class="fas fa-user-plus"></i>အသစ်</a>
        <a href="/logout" class="nav-item"><i class="fas fa-power-off"></i>ထွက်ရန်</a>
    </div>
{% endif %}
<script>
    function copyText(id) {
        var text = document.getElementById(id).innerText;
        var elem = document.createElement("textarea"); document.body.appendChild(elem);
        elem.value = text; elem.select(); document.execCommand("copy");
        document.body.removeChild(elem); alert("Copy Success: " + text);
    }
    const c=document.getElementById('fireCanvas'),ctx=c.getContext('2d');
    let ps=[]; function rs(){c.width=window.innerWidth;c.height=window.innerHeight;} window.onresize=rs;rs();
    class P { constructor(){this.i();} i(){this.x=Math.random()*c.width;this.y=c.height+10;this.v=Math.random()*1.2+0.5;this.o=Math.random()*0.5;} u(){this.y-=this.v;if(this.y<-10)this.i();} d(){ctx.fillStyle="rgba(255, 75, 0, "+this.o+")";ctx.beginPath();ctx.arc(this.x,this.y,2.5,0,Math.PI*2);ctx.fill();}}
    for(let i=0;i<65;i++)ps.push(new P()); function anim(){ctx.clearRect(0,0,c.width,c.height);ps.forEach(p=>{p.u();p.d();});requestAnimationFrame(anim);} anim();
</script></body></html>"""

@app.route("/")
def index():
    if not session.get("auth"): return render_template_string(HTML, logo=OFFICIAL_LOGO)
    users = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: users = json.load(f)
    conntrack = subprocess.run("conntrack -L -p udp 2>/dev/null", shell=True, capture_output=True, text=True).stdout
    active_count = 0
    for u in users:
        u["usage"] = get_usage(u.get("port"))
        u["online"] = f"dport={u.get('port')}" in conntrack if u.get("port") else False
        if u["online"]: active_count += 1
    ip = subprocess.run("curl -s icanhazip.com", shell=True, capture_output=True, text=True).stdout.strip()
    return render_template_string(HTML, logo=OFFICIAL_LOGO, users=users, active_count=active_count, ip=ip, uptime=get_uptime())

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
    users = []
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: users = json.load(f)
    port = str(max([int(x.get("port", 6000)) for x in users] + [6000]) + 1)
    users.insert(0, {"user":u, "password":p, "expires":exp, "port":port})
    with open("/etc/zivpn/users.json","w") as f: json.dump(users, f, indent=2)
    if os.path.exists("/etc/zivpn/config.json"):
        with open("/etc/zivpn/config.json","r") as f: cfg = json.load(f)
        cfg["auth"]["config"] = [x["password"] for x in users]
        with open("/etc/zivpn/config.json","w") as f: json.dump(cfg, f, indent=2)
        subprocess.run("systemctl restart zivpn", shell=True)
    return redirect("/")

@app.route("/delete", methods=["POST"])
def delete():
    if not session.get("auth"): return redirect("/")
    name = request.form.get("user")
    if os.path.exists("/etc/zivpn/users.json"):
        with open("/etc/zivpn/users.json","r") as f: users = json.load(f)
        users = [x for x in users if x["user"] != name]
        with open("/etc/zivpn/users.json","w") as f: json.dump(users, f, indent=2)
        with open("/etc/zivpn/config.json","r") as f: cfg = json.load(f)
        cfg["auth"]["config"] = [x["password"] for x in users]
        with open("/etc/zivpn/config.json","w") as f: json.dump(cfg, f, indent=2)
        subprocess.run("systemctl restart zivpn", shell=True)
    return redirect("/")

@app.route("/logout")
def logout(): session.clear(); return redirect("/")

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

systemctl daemon-reload && systemctl restart zivpn-web
echo -e "\n✅ Full Fix Completed! (Pass + IP Copy Added) http://$(hostname -I | awk '{print $1}'):8080"
