cat > /etc/zivpn/web.py <<'PY'
import os, json, subprocess, hmac, datetime
from flask import Flask, render_template_string, request, redirect, session, url_for

app = Flask(__name__)
app.secret_key = "CMT_BIG_PANEL_KEY_2026"

# Default Admin (နောက်မှ Settings ထဲမှာ ပြောင်းလို့ရပါတယ်)
ADMIN_USER = "admin"
ADMIN_PASS = "admin"

def get_uptime():
    try:
        with open('/proc/uptime', 'r') as f:
            up_sec = float(f.readline().split()[0])
            hrs, rem = divmod(int(up_sec), 3600)
            mins, _ = divmod(rem, 60)
            return f"{hrs}h {mins}m"
    except: return "0h 0m"

HTML = """<!doctype html>
<html lang="my" translate="no">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>CMT ZIVPN PRO PANEL</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root { --bg: #050810; --card: rgba(16, 22, 42, 0.95); --cyan: #00d4ff; --glow: #ff4500; --yellow: #ffaa00; --purple: #9b59b6; --green: #2ecc71; }
        body { background: var(--bg); color: #fff; font-family: sans-serif; margin: 0; padding-bottom: 50px; }
        
        .header { background: rgba(0,0,0,0.7); padding: 15px; border-bottom: 2px solid var(--cyan); display: flex; justify-content: space-between; align-items: center; position: sticky; top: 0; z-index: 100; }
        .header img { border-radius: 50%; width: 45px; height: 45px; border: 2px solid #fff; }
        
        /* ✅ Panel အကြီးကြီး ဖြစ်အောင် Container ကို ချဲ့ထားပါတယ် */
        .container { padding: 15px; max-width: 800px; margin: auto; }
        
        /* Dashboard Grids */
        .grid-menu { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 20px; }
        .grid-box { background: var(--card); border: 1.5px solid var(--cyan); border-radius: 12px; padding: 15px; text-align: center; }
        .grid-val { font-size: 1.2em; font-weight: bold; color: var(--cyan); }
        .grid-label { font-size: 0.7em; color: #888; text-transform: uppercase; margin-top: 5px; }

        /* Action Buttons Grid */
        .action-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 25px; }
        .action-box { background: var(--card); border: 2px solid var(--purple); border-radius: 15px; padding: 20px; text-align: center; cursor: pointer; transition: 0.3s; }
        .action-box:active { transform: scale(0.95); background: rgba(155, 89, 182, 0.2); }
        .action-box i { font-size: 1.8em; color: var(--yellow); display: block; margin-bottom: 8px; }
        .action-label { font-size: 0.8em; font-weight: bold; }

        /* Table Design */
        .table-card { background: var(--card); border-radius: 15px; border: 1.5px solid var(--cyan); padding: 10px; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; min-width: 500px; }
        th { text-align: left; padding: 12px; color: var(--cyan); border-bottom: 2px solid #1e293b; font-size: 0.85em; }
        td { padding: 15px 12px; border-bottom: 1px solid #1e293b; font-size: 0.95em; }

        /* Modal (Popup) System */
        .modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.85); backdrop-filter: blur(5px); }
        .modal-content { background: var(--card); margin: 15% auto; padding: 25px; border-radius: 20px; border: 2px solid var(--cyan); width: 85%; max-width: 400px; text-align: center; box-shadow: 0 0 30px var(--cyan); }
        input { width: 100%; padding: 14px; margin: 10px 0; background: #000; border: 1.5px solid #333; color: #fff; border-radius: 10px; box-sizing: border-box; outline: none; }
        input:focus { border-color: var(--cyan); }
        .btn { background: linear-gradient(45deg, #00c6ff, #0072ff); color: #fff; border: none; padding: 15px; border-radius: 10px; font-weight: bold; width: 100%; cursor: pointer; margin-top: 10px; }
        .social-link { display: flex; align-items: center; justify-content: center; gap: 15px; text-decoration: none; padding: 12px; border-radius: 10px; margin-bottom: 10px; color: white; font-weight: bold; }
    </style>
</head>
<body>
{% if not session.get('auth') %}
    <div style="max-width: 320px; margin: 20vh auto; background: var(--card); padding: 40px; border-radius: 25px; text-align: center; border: 2px solid var(--glow);">
        <h3 style="color:var(--cyan); margin-bottom:20px;">CMT LOGIN</h3>
        <form method="post" action="/login_check">
            <input name="u" placeholder="Admin" required>
            <input name="p" type="password" placeholder="Pass" required>
            <button class="btn">LOGIN</button>
        </form>
    </div>
{% else %}
    <div class="header">
        <div style="display:flex; align-items:center; gap:12px;">
            <img src="https://raw.githubusercontent.com/hninpo01/CMT/main/logo.png">
            <b style="color:var(--cyan); letter-spacing:1px;">CMT ZIVPN PRO PANEL</b>
        </div>
        <a href="/logout" style="color:var(--cyan); font-size:1.5em;"><i class="fas fa-power-off"></i></a>
    </div>

    <div class="container">
        <div class="grid-menu">
            <div class="grid-box"><div class="grid-val">0.3%</div><div class="grid-label">CPU</div></div>
            <div class="grid-box"><div class="grid-val">12.0%</div><div class="grid-label">RAM</div></div>
            <div class="grid-box"><div class="grid-val">9.0%</div><div class="grid-label">DISK</div></div>
            <div class="grid-box" style="border-color:var(--purple);"><div class="grid-val">{{ users|length }}</div><div class="grid-label">အသုံးပြုသူ</div></div>
            <div class="grid-box" style="border-color:var(--green);"><div class="grid-val">0</div><div class="grid-label">အွန်လိုင်း</div></div>
            <div class="grid-box" style="border-color:var(--yellow);"><div class="grid-val">12%</div><div class="grid-label">ဝန်ဆောင်မှု</div></div>
        </div>

        <div class="action-grid">
            <div class="action-box" onclick="openModal('addModal')"><i class="fas fa-user-plus"></i><div class="action-label">အကောင့်သစ်</div></div>
            <div class="action-box" onclick="openModal('supportModal')"><i class="fas fa-headset"></i><div class="action-label">ဆက်သွယ်ရန်</div></div>
            <div class="action-box" onclick="openModal('settingsModal')"><i class="fas fa-tools"></i><div class="action-label">ကိတ်တင်များ</div></div>
        </div>

        <div class="table-card">
            <table>
                <thead><tr><th>အမည်</th><th>ကောက်ပက်</th><th>သက်တမ်း</th><th>Status</th></tr></thead>
                <tbody>
                    {% for u in users %}
                    <tr>
                        <td style="color:var(--cyan); font-weight:bold;">{{ u.user }}</td>
                        <td>{{ u.port }}</td>
                        <td style="color:#ff69b4;">{{ u.expires }}</td>
                        <td><i class="fas fa-circle" style="color:var(--glow);"></i> Offline</td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>

    <div id="addModal" class="modal"><div class="modal-content">
        <h3 style="color:var(--cyan);">အကောင့်သစ်ဖွင့်ရန်</h3>
        <form method="post" action="/add">
            <input name="user" placeholder="နာမည် (Username)" required>
            <input name="password" placeholder="စကားဝှက် (Password)" required>
            <input name="days" placeholder="ရက်ပေါင်း (ဥပမာ ၃၀)" required>
            <button class="btn">CREATE USER</button>
        </form>
        <button onclick="closeModal('addModal')" style="background:none; border:none; color:#888; margin-top:15px; cursor:pointer;">မလုပ်တော့ပါ</button>
    </div></div>

    <div id="supportModal" class="modal"><div class="modal-content">
        <h3 style="color:var(--cyan); margin-bottom:20px;">ဆက်သွယ်ရန်</h3>
        <a href="https://t.me/CMT_1411" class="social-link" style="background:#0088cc;"><i class="fab fa-telegram-plane"></i> Telegram</a>
        <a href="https://www.facebook.com/ChitMinThu1239" class="social-link" style="background:#1877f2;"><i class="fab fa-facebook-f"></i> Facebook</a>
        <a href="https://m.me/ChitMinThu1239" class="social-link" style="background:linear-gradient(45deg, #00c6ff, #bc00ff);"><i class="fab fa-facebook-messenger"></i> Messenger</a>
        <button onclick="closeModal('supportModal')" style="background:none; border:none; color:#888; margin-top:15px; cursor:pointer;">ပိတ်မည်</button>
    </div></div>

    <div id="settingsModal" class="modal"><div class="modal-content">
        <h3 style="color:var(--cyan);">စက်တင်များ (Admin)</h3>
        <form method="post" action="/change_admin">
            <input name="new_pass" type="password" placeholder="စကားဝှက်အသစ်" required>
            <button class="btn" style="background:var(--green); color:#000;">UPDATE ADMIN PASS</button>
        </form>
        <button onclick="closeModal('settingsModal')" style="background:none; border:none; color:#888; margin-top:15px; cursor:pointer;">ပိတ်မည်</button>
    </div></div>

    <script>
        function openModal(id) { document.getElementById(id).style.display = "block"; }
        function closeModal(id) { document.getElementById(id).style.display = "none"; }
        window.onclick = function(event) { if (event.target.className === 'modal') { event.target.style.display = "none"; } }
    </script>
{% endif %}
</body></html>"""

@app.route("/")
def index():
    users = []
    if os.path.exists("/etc/zivpn/users.json"):
        try:
            with open("/etc/zivpn/users.json","r") as f: users = json.load(f)
        except: users = []
    return render_template_string(HTML, users=users, uptime=get_uptime())

@app.route("/login_check", methods=["POST"])
def login_check():
    if request.form.get("u") == ADMIN_USER and request.form.get("p") == ADMIN_PASS:
        session["auth"] = True
    return redirect("/")

@app.route("/logout")
def logout():
    session.clear()
    return redirect("/")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
PY

# Service Restart
systemctl restart zivpn-web
