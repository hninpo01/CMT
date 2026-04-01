    #!/bin/bash
# CMT ZIVPN PRO - RAINBOW & NETWORK LINES EDITION
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
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.8); --glow: #ff4500; --cyan: #00d4ff; --yellow: #ffaa00; --green: #2ecc71; --purple: #9b59b6; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 90px; overflow-x: hidden; }
        
        /* ✅ Network Lines Background */
        #bgCanvas { position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: -1; background: #050810; }

        /* ✅ Rainbow Animated Title */
        @keyframes rainbowText {
            0% { background-position: 0% 50%; }
            50% { background-position: 100% 50%; }
            100% { background-position: 0% 50%; }
        }
        .rainbow-text {
            font-weight: bold;
            background: linear-gradient(90deg, #ff0000, #ffaa00, #2ecc71, #00d4ff, #9b59b6, #ff0000);
            background-size: 300% 300%;
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            animation: rainbowText 5s linear infinite;
        }

        .header { background: rgba(0,0,0,0.5); backdrop-filter: blur(10px); padding: 18px; display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--cyan); box-shadow: 0 0 20px var(--cyan); }
        .header img { border-radius: 50%; border: 2px solid #fff; width: 45px; height: 45px; background: #fff; }
        
        .container { padding: 15px; }
        .grid-menu { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin-bottom: 20px; }
        .grid-box { background: var(--card); border: 2px solid var(--glow); border-radius: 15px; padding: 12px; text-align: center; box-shadow: 0 0 15px rgba(255, 69, 0, 0.4); backdrop-filter: blur(5px); }
        .grid-box.full { grid-column: span 2; border-color: var(--purple); }
        .grid-val { font-size: 1.3em; font-weight: bold; color: var(--yellow); text-shadow: 0 0 10px var(--yellow); }
        
        .card { background: var(--card); padding: 25px; border-radius: 20px; border: 2px solid var(--glow); margin-bottom: 20px; box-shadow: 0 0 25px rgba(255, 69, 0, 0.5); backdrop-filter: blur(5px); }
        input { width: 100%; padding: 14px; margin: 8px 0; background: rgba(0,0,0,0.7); border: 1.5px solid #444; color: #fff !important; border-radius: 12px; box-sizing: border-box; }
        .btn { background: linear-gradient(45deg, #ff4500, #ffaa00); color: #fff; border: none; padding: 15px; border-radius: 12px; font-weight: bold; width: 100%; cursor: pointer; box-shadow: 0 0 20px rgba(255, 69, 0, 0.5); }
        
        .table-card { background: var(--card); border-radius: 15px; border: 2.5px solid var(--cyan); padding: 15px; overflow-x: auto; box-shadow: 0 0 20px rgba(0, 212, 255, 0.4); backdrop-filter: blur(5px); }
        table { width: 100%; border-collapse: collapse; min-width: 550px; }
        th { text-align: left; padding: 12px; color: var(--cyan); border-bottom: 2px solid #1e293b; }
        td { padding: 15px 12px; border-bottom: 1px solid #1e293b; font-size: 0.95em; }

        .bottom-nav { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(10, 14, 26, 0.9); display: flex; justify-content: space-around; padding: 15px 0; border-top: 2px solid #4e73df; backdrop-filter: blur(10px); }
        .nav-item { color: #555; text-decoration: none; text-align: center; }
        .nav-item.active { color: var(--cyan); text-shadow: 0 0 15px var(--cyan); }
    </style>
</head>
<body>
<canvas id="bgCanvas"></canvas>
{% if not session.get('auth') %}
    <div style="max-width: 330px; margin: 18vh auto; background: var(--card); padding: 40px; border-radius: 25px; text-align: center; border: 3px solid var(--glow); box-shadow: 0 0 45px rgba(255, 69, 0, 0.7);">
        <img src="{{ logo }}" width="90" style="background:#fff; border-radius:20px; margin-bottom:25px;">
        <h2 class="rainbow-text" style="font-size: 1.8em;">CMT LOGIN</h2>
        <form method="post" action="/login_check"><input name="u" placeholder="Admin Name" required><input name="p" type="password" placeholder="Password" required><button class="btn" style="margin-top:20px;">DASHBOARD LOGIN</button></form>
    </div>
{% else %}
    <div class="header">
        <div style="display:flex;align-items:center;gap:12px;"><img src="{{ logo }}"><b class="rainbow-text" style="font-size: 1.2em;">CMT ZIVPN PRO PANEL</b></div>
        <div style="text-align:right;"><small>IP: {{ ip }}</small></div>
    </div>
    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><div style="font-size: 0.7em;">TOTAL USERS</div><div class="grid-val">{{ users|length }}</div></div>
            <div class="grid-box" style="border-color:var(--green);"><div style="font-size: 0.7em;">ONLINE</div><div class="grid-val" style="color:var(--green);">{{ active_count }}</div></div>
            <div class="grid-box full"><div style="font-size: 0.7em;">SYSTEM UPTIME</div><div class="grid-val" style="color:var(--purple);">{{ uptime }}</div></div>
            <div class="grid-box" style="border-color:#3498db;"><div style="font-size: 0.7em;">BANDWIDTH</div><div class="grid-val" style="color:#3498db;">0.00</div></div>
            <div class="grid-box" style="border-color:#e67e22;"><div style="font-size: 0.7em;">SERVER LOAD</div><div class="grid-val" style="color:#e67e22;">12%</div></div>
        </div>
        <div class="card">
            <h4 style="color:var(--green); margin:0 0 10px 0;"><i class="fas fa-plus-circle"></i> Add User</h4>
            <form method="post" action="/add"><input name="user" placeholder="User Name" required><input name="password" placeholder="Pass" required><input name="days" placeholder="Days" required><button class="btn">ACTIVATE</button></form>
        </div>
        <div class="table-card">
            <table>
                <thead><tr><th>USER</th><th>PASS</th><th>USAGE</th><th>EXPIRY</th><th>STATUS</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan); font-weight:bold;">{{ u.user }}</td>
                        <td>{{ u.password }}</td>
                        <td style="color:var(--yellow);">{{ u.usage }}</td>
                        <td style="color:#ff69b4;">{{ u.expires }}</td>
                        <td><span style="color:{{ '#2ecc71' if u.online else '#e74c3c' }};">● {{ 'Online' if u.online else 'Offline' }}</span></td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>
    <div class="bottom-nav">
        <a href="/" class="nav-item active"><i class="fas fa-home"></i></a>
        <a href="https://t.me/Zero_Free_Vpn" class="nav-item"><i class="fab fa-telegram-plane"></i></a>
        <a href="/logout" class="nav-item"><i class="fas fa-power-off"></i></a>
    </div>
{% endif %}

<script>
    /* ✅ Moving Network Lines Script */
    const canvas = document.getElementById('bgCanvas');
    const ctx = canvas.getContext('2d');
    let particles = [];
    function init() {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    }
    window.onresize = init; init();

    class Particle {
        constructor() {
            this.x = Math.random() * canvas.width;
            this.y = Math.random() * canvas.height;
            this.vx = (Math.random() - 0.5) * 0.5;
            this.vy = (Math.random() - 0.5) * 0.5;
            this.radius = Math.random() * 2;
        }
        update() {
            this.x += this.vx; this.y += this.vy;
            if (this.x < 0 || this.x > canvas.width) this.vx *= -1;
            if (this.y < 0 || this.y > canvas.height) this.vy *= -1;
        }
        draw() {
            ctx.beginPath();
            ctx.arc(this.x, this.y, this.radius, 0, Math.PI * 2);
            ctx.fillStyle = 'rgba(0, 212, 255, 0.5)';
            ctx.fill();
        }
    }

    function createParticles() {
        for (let i = 0; i < 80; i++) particles.push(new Particle());
    }
    createParticles();

    function animate() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        particles.forEach((p, index) => {
            p.update(); p.draw();
            for (let j = index + 1; j < particles.length; j++) {
                const p2 = particles[j];
                const dist = Math.hypot(p.x - p2.x, p.y - p2.y);
                if (dist < 100) {
                    ctx.beginPath();
                    ctx.moveTo(p.x, p.y);
                    ctx.lineTo(p2.x, p2.y);
                    ctx.strokeStyle = `rgba(255, 69, 0, ${1 - dist / 100})`;
                    ctx.lineWidth = 0.5;
                    ctx.stroke();
                }
            }
        });
        requestAnimationFrame(animate);
    }
    animate();
</script>
</body></html>"""

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
    with open("/etc/zivpn/users.json","r") as f: users = json.load(f)
    port = str(max([int(x.get("port", 6000)) for x in users] + [6000]) + 1)
    users.insert(0, {"user":u, "password":p, "expires":exp, "port":port})
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
echo -e "\n✅ Rainbow Title & Network Lines Ready! http://$(hostname -I | awk '{print $1}'):8080"
