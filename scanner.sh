#!/data/data/com.termux/files/usr/bin/bash
R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
B='\033[1;34m'
M='\033[1;35m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

BACKEND_URL="https://unknown-scanner-backend-v1-0.onrender.com"
STATS_FILE="$HOME/.unknown_scanner_uses"

LOGFILE="$HOME/anticheat_log_$(date +%Y%m%d_%H%M%S).txt"
SUSPICIOUS_COUNT=0
GAME_SELECTED=""
GAME_PKG=""
DEVICE_HWID=""

_xd() { local b="$1" o="" c d i; while [ ${#b} -ge 8 ]; do c="${b:0:8}"; b="${b:8}"; d=0; for (( i=0; i<8; i++ )); do d=$(( d*2 + ${c:$i:1} )); done; o+=$(printf "\\$(printf '%03o' $d)"); done; printf '%s' "$o"; }
REPLAY_HWID_WHITELIST=(
"$(_xd 0011100000110010001100100011001000110101001100010011100001100011001101100011100001100010001101010110010101100001011000100011001100110011001110010110011000111000011001000011000100110001001100110110000100110011011001010011010001100010001100110110001100110101)"
)

registrar_uso() {
    local count=1
    [ -f "$STATS_FILE" ] && count=$(( $(cat "$STATS_FILE" 2>/dev/null || echo 0) + 1 ))
    echo "$count" > "$STATS_FILE"
    curl -sf --max-time 4 -X POST "${BACKEND_URL}/api/stats/scan" \
        -H "Content-Type: application/json" \
        -d '{"version":"1.4.0"}' &>/dev/null &
}

obtener_stats_global() {
    local resp total
    resp=$(curl -sf --max-time 5 "${BACKEND_URL}/api/stats/scan" 2>/dev/null)
    total=$(echo "$resp" | grep -o '"total":[0-9]*' | grep -o '[0-9]*')
    [ -n "$total" ] && echo "$total" || echo "?"
}

obter_hwid_real() {
    local android_id serial boot_serial
    android_id=$(adb shell "settings get secure android_id 2>/dev/null" | tr -d '\r\n')
    serial=$(adb shell "getprop ro.serialno 2>/dev/null" | tr -d '\r\n')
    boot_serial=$(adb shell "getprop ro.boot.serialno 2>/dev/null" | tr -d '\r\n')
    printf '%s:%s:%s' "$android_id" "$serial" "$boot_serial" \
        | md5sum | cut -d' ' -f1
}

verificar_hwid_ban() {
    echo -e "${B}[*] Verificando dispositivo...${N}"

    DEVICE_HWID=$(obter_hwid_real)

    if [ -z "$DEVICE_HWID" ] || [ ${#DEVICE_HWID} -lt 8 ]; then
        echo -e "${Y}[*] No se pudo calcular HWID — continuando${N}"
        sleep 1; return 0
    fi

    local respuesta
    respuesta=$(curl -sf --max-time 6 \
        "${BACKEND_URL}/api/ban/check?hwid=${DEVICE_HWID}" 2>/dev/null)

    if [ -z "$respuesta" ]; then
        return 0
    fi

    local baneado motivo fecha
    baneado=$(echo "$respuesta" | grep -o '"banned":[^,}]*' | cut -d: -f2 | tr -d '" ')
    motivo=$(echo "$respuesta"  | grep -o '"motivo":"[^"]*"' | cut -d'"' -f4)
    fecha=$(echo "$respuesta"   | grep -o '"fecha":"[^"]*"'  | cut -d'"' -f4)

    if [ "$baneado" = "true" ]; then
        clear
        echo ""
        echo -e "${R}  ██████╗  █████╗ ███╗   ██╗${N}"
        echo -e "${R}  ██╔══██╗██╔══██╗████╗  ██║${N}"
        echo -e "${R}  ██████╔╝███████║██╔██╗ ██║${N}"
        echo -e "${R}  ██╔══██╗██╔══██║██║╚██╗██║${N}"
        echo -e "${R}  ██████╔╝██║  ██║██║ ╚████║${N}"
        echo -e "${R}  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝${N}"
        echo ""
        echo -e "${R}╔════════════════════════════════════════════════════════╗${N}"
        echo -e "${R}║         DISPOSITIVO BLOQUEADO DEL SCANNER               ║${N}"
        echo -e "${R}╚════════════════════════════════════════════════════════╝${N}"
        echo ""
        echo -e "${W}  Motivo : ${R}${motivo}${N}"
        echo -e "${W}  Data   : ${Y}${fecha}${N}"
        echo -e "${W}  HWID   : ${Y}${DEVICE_HWID}${N}"
        echo ""
        echo -e "${Y}  Este dispositivo no puede usar el scanner.${N}"
        echo ""
        echo -e "${W}Presione Enter para salir...${N}"; read
        return 1
    fi

    return 0
}

banner() {
    clear
    local width=58
    local inner=$((width-2))
    local top="╔"
    local bottom="╚"
    for i in $(seq 1 $inner); do top+="═"; bottom+="═"; done
    top+="╗"; bottom+="╝"

    _center() {
        local text="$1"
        local len=${#text}
        local left=$(( (inner - len) / 2 ))
        local right=$(( inner - len - left ))
        printf "%${left}s%s%${right}s" "" "$text" ""
    }

    printf "%b\n" "${C}${top}${N}"
    local _l; _l=$(cat "$STATS_FILE" 2>/dev/null || echo "0")
    local _g; _g=$(curl -sf --max-time 3 "${BACKEND_URL}/api/stats/scan" 2>/dev/null | grep -o '"total":[0-9]*' | grep -o '[0-9]*' || echo "?")
    printf "%b\n" "${C}║${M}$( _center "CODE BY TIZI.XIT - ANTI-CHEAT SYSTEM" )${C}║${N}"
    printf "%b\n" "${C}║${M}$( _center "VERSIÓN 1.4.0" )${C}║${N}"
    printf "%b\n" "${C}║${G}$( _center "Scans globales: ${_g}  |  Este dispositivo: ${_l}" )${C}║${N}"
    printf "%b\n" "${C}${bottom}${N}"
    echo ""
    printf "%b\n" "${Y}${top}${N}"
    printf "%b\n" "${Y}║$( _center "⚠️  ESTE SCANNER ESTÁ EN PROCESO DE DESARROLLO  ⚠️" )║${N}"
    printf "%b\n" "${Y}║$( _center "SE RECOMIENDA HACER REVISIÓN MANUAL ADICIONAL" )║${N}"
    printf "%b\n" "${Y}║$( _center "PARA MAYOR SEGURIDAD Y PRECISIÓN" )║${N}"
    printf "%b\n" "${Y}${bottom}${N}"
    echo ""
    sleep 1
}

log_output() {
    echo -e "${1}" | tee -a "$LOGFILE"
}

check_storage() {
    if [ ! -d "$HOME/storage" ]; then
        echo -e "${Y}[*] Configurando permisos de almacenamiento...${N}"
        termux-setup-storage
        sleep 2
    fi
}

main_menu() {
    SUSPICIOUS_COUNT=0
    banner
    echo -e "${B}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${B}║                    MENÚ PRINCIPAL                      ║${N}"
    echo -e "${B}╚════════════════════════════════════════════════════════╝${N}"
    echo ""
    echo -e "${Y}[0]${W} Conectar ADB (Pareamiento inalámbrico)${N}"
    echo -e "${G}[1]${W} Escanear Free Fire Normal${N}"
    echo -e "${G}[2]${W} Escanear Free Fire MAX${N}"
    echo -e "${C}[3]${W} Ver último log guardado${N}"
    echo -e "${B}[4]${W} Guardar diagnóstico completo (Dumpsys)${N}"
    echo -e "${M}[5]${W} Actualizar scanner${N}"
    echo -e "${C}[6]${W} Revisión remota de pantalla ${Y}(beta)${N}"
    echo -e "${R}[S]${W} Salir${N}"
    echo ""
    echo -ne "${Y}Selecciona una opción: ${N}"
    read -r opcao

    case $opcao in
        0) conectar_adb ;;
        1) scan_ff_normal ;;
        2) scan_ff_max ;;
        3) ver_ultimo_log ;;
        4) guardar_dumpsys ;;
        5) actualizar_scanner ;;
        6) remote_review_menu ;;
        s|S) echo -e "\n${W}Gracias por usar el scanner${N}\n"; exit 0 ;;
        *) echo -e "${R}Opción inválida${N}"; sleep 2; main_menu ;;
    esac
}


remote_review_menu() {
    clear; banner

    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║${M}      REVISIÓN REMOTA DE PANTALLA  ${Y}(BETA)${C}            ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    echo ""
    echo -e "${Y}+========================================================+${N}"
    echo -e "${Y}|${R}  ⚠  AVISO — LEER ANTES DE CONTINUAR              ⚠  ${Y}|${N}"
    echo -e "${Y}+--------------------------------------------------------+${N}"
    echo -e "${Y}|${N}"
    echo -e "${Y}|${W}  El SS va a ver y controlar la pantalla del          ${N}"
    echo -e "${Y}|${W}  dispositivo en tiempo real — igual que AnyDesk.     ${N}"
    echo -e "${Y}|${N}"
    echo -e "${Y}|${W}  El usuario ve TODO lo que el SS hace en su pantalla.${N}"
    echo -e "${Y}|${N}"
    echo -e "${Y}|${C}  Para cortar el acceso en cualquier momento:         ${N}"
    echo -e "${Y}|${W}    Ajustes → Depuración Inalámbrica → Desactivar     ${N}"
    echo -e "${Y}|${N}"
    echo -e "${Y}+========================================================+${N}"
    echo ""

    if ! adb devices | grep -q "device$"; then
        echo -e "${R}[!] No hay dispositivos conectados. Usá la opción [0] primero.${N}"
        echo -e "${W}Enter para volver...${N}"; read; main_menu; return
    fi

    echo -ne "${Y}  ¿El usuario acepta la revisión? [s/N]: ${N}"
    read -r _consent
    if [[ "${_consent,,}" != "s" ]]; then
        echo -e "${Y}[*] Revisión cancelada.${N}"; sleep 2; main_menu; return
    fi

    pip install flask pillow --break-system-packages -q 2>/dev/null || \
        pip install flask pillow -q 2>/dev/null

    mkdir -p "$HOME/unknown_remote"
    _generar_remote_viewer
    echo -e "${G}[✓] Servidor listo${N}"

    local MY_IP
    MY_IP=$(ip route get 1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}' | head -1)
    [ -z "$MY_IP" ] && MY_IP="127.0.0.1"

    local CODE=$(printf '%04d' $((RANDOM % 9000 + 1000)))
    echo ""
    echo -e "${G}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${G}║          REVISIÓN REMOTA — SESIÓN INICIADA             ║${N}"
    echo -e "${G}╠════════════════════════════════════════════════════════╣${N}"
    echo -e "${G}║${N}                                                        ${G}║${N}"
    echo -e "${G}║${W}  Abrí el navegador de tu teléfono y entrá a:         ${G}║${N}"
    echo -e "${G}║${C}  http://${MY_IP}:8888                                 ${G}║${N}"
    echo -e "${G}║${N}                                                        ${G}║${N}"
    echo -e "${G}║${W}  Código de acceso (decíselo al SS verbalmente):      ${G}║${N}"
    echo -e "${G}║${Y}                   ${CODE}                              ${G}║${N}"
    echo -e "${G}║${N}                                                        ${G}║${N}"
    echo -e "${G}║${W}  El usuario puede cortar desactivando Depuración     ${G}║${N}"
    echo -e "${G}║${W}  Inalámbrica desde Ajustes.                           ${G}║${N}"
    echo -e "${G}║${N}                                                        ${G}║${N}"
    echo -e "${G}╚════════════════════════════════════════════════════════╝${N}"
    echo ""
    echo -e "${Y}[*] Presioná [ENTER] para terminar la sesión y volver al menú.${N}"
    echo ""

    REMOTE_SESSION_CODE="$CODE" python3 "$HOME/unknown_remote/remote_viewer.py" &
    local RPID=$!
    sleep 2
    read -r
    kill $RPID 2>/dev/null
    wait $RPID 2>/dev/null
    echo -e "${G}[✓] Sesión remota terminada.${N}"
    sleep 1; main_menu
}

_generar_remote_viewer() {
cat > "$HOME/unknown_remote/remote_viewer.py" << 'RVEOF'
import os, subprocess, io, base64, secrets, threading, time
from flask import Flask, Response, request, jsonify

app = Flask(__name__)
SESSION_CODE = os.environ.get("REMOTE_SESSION_CODE", "0000")
TOKENS = set()
FPS = 4

# ── HTML como bytes literales para evitar que Flask lo interprete ──
HTML = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<title>UNKNOWN Remote</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#0d0d0d;color:#e0e0e0;font-family:monospace;min-height:100vh}
#auth{display:flex;flex-direction:column;align-items:center;justify-content:center;height:100vh;gap:16px;padding:24px}
#auth h2{color:#1e90ff;font-size:16px;letter-spacing:2px;text-align:center}
#auth p{color:#888;font-size:12px;text-align:center;max-width:280px;line-height:1.6}
#code-inp{background:#111;border:1px solid #1e90ff;color:#fff;padding:12px;font-size:32px;text-align:center;border-radius:8px;width:170px;letter-spacing:12px;font-family:monospace}
#auth-btn{background:#1e90ff;color:#000;border:none;padding:12px 40px;border-radius:8px;font-family:monospace;font-size:15px;font-weight:bold;cursor:pointer;width:170px}
#auth-btn:active{opacity:.8}
#auth-err{color:#ff4444;font-size:12px;min-height:16px}
#app{display:none;flex-direction:column;height:100vh}
#topbar{background:#111;border-bottom:1px solid #1e90ff33;padding:7px 12px;display:flex;align-items:center;gap:8px}
#topbar h1{color:#1e90ff;font-size:11px;letter-spacing:2px;flex:1}
#badge{background:#0a2a0a;border:1px solid #44ff44;color:#44ff44;padding:2px 8px;border-radius:3px;font-size:10px}
#main{flex:1;display:flex;overflow:hidden}
#screen-col{flex:1;display:flex;flex-direction:column;background:#000}
#screen-wrap{flex:1;position:relative;overflow:hidden}
#screen{width:100%;height:100%;object-fit:contain;display:block}
#overlay{position:absolute;top:0;left:0;width:100%;height:100%}
#navbar{background:#0f0f0f;border-top:1px solid #222;padding:6px;display:flex;gap:6px;justify-content:center;flex-wrap:wrap}
.nb{background:#1a1a2e;border:1px solid #333;color:#ccc;padding:8px 12px;border-radius:5px;font-size:12px;cursor:pointer;font-family:monospace}
.nb:active{background:#1e90ff;color:#000;border-color:#1e90ff}
.rb{border-color:#ff4444;color:#ff4444}
.rb:active{background:#ff4444;color:#000}
#sidebar{width:260px;display:flex;flex-direction:column;border-left:1px solid #1a1a1a;background:#080808}
#path{padding:7px 10px;font-size:10px;color:#1e90ff;background:#111;border-bottom:1px solid #1a1a1a;cursor:pointer;word-break:break-all}
#files{flex:1;overflow-y:auto}
.fi{display:flex;align-items:center;gap:6px;padding:8px 10px;cursor:pointer;border-bottom:1px solid #0f0f0f;font-size:11px;color:#bbb}
.fi:active,.fi:hover{background:#151515;color:#fff}
.fi .ic{width:18px;text-align:center;font-size:13px;flex-shrink:0}
.fi .nm{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.fi .sz{font-size:10px;color:#444;flex-shrink:0}
@media(max-width:500px){#sidebar{display:none}}
</style>
</head>
<body>

<div id="auth">
  <h2>UNKNOWN<br>REVISIÓN REMOTA</h2>
  <p>Ingresá el código de 4 dígitos que el usuario te dijo verbalmente.</p>
  <input id="code-inp" type="tel" inputmode="numeric" maxlength="4" placeholder="0000">
  <button id="auth-btn" onclick="doAuth()">CONECTAR</button>
  <div id="auth-err"></div>
</div>

<div id="app">
  <div id="topbar">
    <h1>UNKNOWN · REVISIÓN REMOTA</h1>
    <span id="badge">● EN VIVO</span>
    <button class="nb rb" style="padding:4px 10px;font-size:11px" onclick="endSession()">TERMINAR</button>
  </div>
  <div id="main">
    <div id="screen-col">
      <div id="screen-wrap">
        <img id="screen" src="" alt="Pantalla">
        <div id="overlay"></div>
      </div>
      <div id="navbar">
        <button class="nb" onclick="nav('back')">◀ Atrás</button>
        <button class="nb" onclick="nav('home')">⬤ Inicio</button>
        <button class="nb" onclick="nav('recents')">▦ Recientes</button>
        <button class="nb" onclick="nav('notifications')">🔔 Notif</button>
        <button class="nb" onclick="saveScreen()">📷 Captura</button>
      </div>
    </div>
    <div id="sidebar">
      <div id="path" onclick="goUp()">/sdcard</div>
      <div id="files"></div>
    </div>
  </div>
</div>

<script>
let token = "", W = 1080, H = 1920, running = false, swipeStart = null;
let curPath = "/sdcard";

const overlay = document.getElementById("overlay");
const screenImg = document.getElementById("screen");

document.getElementById("code-inp").addEventListener("keydown", e => {
  if (e.key === "Enter") doAuth();
});

function doAuth() {
  const code = document.getElementById("code-inp").value.trim();
  fetch("/auth", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({code})
  }).then(r => r.json()).then(d => {
    if (d.ok) {
      token = d.token;
      document.getElementById("auth").style.display = "none";
      document.getElementById("app").style.display = "flex";
      running = true;
      streamLoop();
      browse("/sdcard");
    } else {
      document.getElementById("auth-err").textContent = "Código incorrecto.";
    }
  }).catch(() => {
    document.getElementById("auth-err").textContent = "Error de conexión.";
  });
}

function streamLoop() {
  if (!running) return;
  fetch("/frame?_=" + Date.now(), {headers: {"X-Token": token}})
    .then(r => r.json())
    .then(d => {
      if (d.img) { screenImg.src = "data:image/jpeg;base64," + d.img; W = d.w; H = d.h; }
      setTimeout(streamLoop, 1000 / """ + str(FPS) + """);
    })
    .catch(() => setTimeout(streamLoop, 3000));
}

overlay.addEventListener("click", e => {
  const r = screenImg.getBoundingClientRect();
  const x = Math.round((e.clientX - r.left) * W / r.width);
  const y = Math.round((e.clientY - r.top) * H / r.height);
  api("/tap", {x, y});
});

overlay.addEventListener("touchstart", e => {
  const t = e.touches[0], r = screenImg.getBoundingClientRect();
  swipeStart = {
    x: (t.clientX - r.left) * W / r.width,
    y: (t.clientY - r.top)  * H / r.height,
    ts: Date.now()
  };
}, {passive: true});

overlay.addEventListener("touchend", e => {
  if (!swipeStart) return;
  const t = e.changedTouches[0], r = screenImg.getBoundingClientRect();
  const ex = (t.clientX - r.left) * W / r.width;
  const ey = (t.clientY - r.top)  * H / r.height;
  const dx = ex - swipeStart.x, dy = ey - swipeStart.y;
  const dur = Date.now() - swipeStart.ts;
  if (Math.abs(dx) < 15 && Math.abs(dy) < 15) {
    api("/tap", {x: Math.round(ex), y: Math.round(ey)});
  } else {
    api("/swipe", {
      x1: Math.round(swipeStart.x), y1: Math.round(swipeStart.y),
      x2: Math.round(ex),           y2: Math.round(ey),
      dur: Math.min(dur, 2000)
    });
  }
  swipeStart = null;
}, {passive: true});

function nav(action) { api("/nav", {action}); }

function browse(path) {
  curPath = path;
  document.getElementById("path").textContent = path;
  fetch("/ls?path=" + encodeURIComponent(path), {headers: {"X-Token": token}})
    .then(r => r.json())
    .then(d => {
      const el = document.getElementById("files");
      el.innerHTML = "";
      (d.entries || []).forEach(e => {
        const div = document.createElement("div");
        div.className = "fi";
        div.innerHTML = `<span class="ic">${e.t === "d" ? "📁" : "📄"}</span>
                         <span class="nm">${e.n}</span>
                         <span class="sz">${e.s || ""}</span>`;
        div.onclick = () => {
          if (e.t === "d") browse(path + "/" + e.n);
          else if (confirm("¿Abrir " + e.n + " en el dispositivo?")) {
            api("/open", {path: path + "/" + e.n});
          }
        };
        el.appendChild(div);
      });
    });
}

function goUp() {
  const parts = curPath.split("/").filter(Boolean);
  if (parts.length > 1) { parts.pop(); browse("/" + parts.join("/")); }
  else browse("/sdcard");
}

function saveScreen() {
  fetch("/screenshot", {headers: {"X-Token": token}})
    .then(r => r.json())
    .then(d => {
      if (d.img) {
        const a = document.createElement("a");
        a.href = "data:image/jpeg;base64," + d.img;
        a.download = "remote_" + Date.now() + ".jpg";
        a.click();
      }
    });
}

function endSession() {
  if (!confirm("¿Terminar la sesión remota?")) return;
  running = false;
  api("/disconnect", {}).finally(() => location.reload());
}

function api(url, body) {
  return fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json", "X-Token": token},
    body: JSON.stringify(body)
  }).then(r => r.json()).catch(() => ({}));
}
</script>
</body>
</html>"""

def chk(req):
    return req.headers.get("X-Token", "") in TOKENS

def adb(cmd):
    try:
        return subprocess.run(["adb","shell"] + cmd.split(),
                              capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        return ""

def grab():
    try:
        r = subprocess.run(["adb","exec-out","screencap","-p"],
                           capture_output=True, timeout=10)
        if r.returncode == 0 and r.stdout:
            from PIL import Image
            img = Image.open(io.BytesIO(r.stdout)).convert("RGB")
            w, h = img.size
            nw = min(w, 800)
            img = img.resize((nw, int(h * nw / w)), Image.LANCZOS)
            buf = io.BytesIO()
            img.save(buf, "JPEG", quality=60)
            return base64.b64encode(buf.getvalue()).decode(), w, h
    except Exception:
        pass
    return None, 0, 0

@app.route("/")
def index():
    return Response(HTML, mimetype="text/html")

@app.route("/auth", methods=["POST"])
def auth():
    code = str((request.json or {}).get("code", ""))
    if code == SESSION_CODE:
        tok = secrets.token_hex(16)
        TOKENS.add(tok)
        return jsonify({"ok": True, "token": tok})
    return jsonify({"ok": False})

@app.route("/frame")
def frame():
    if not chk(request): return jsonify({}), 401
    img, w, h = grab()
    return jsonify({"img": img, "w": w, "h": h})

@app.route("/screenshot")
def screenshot():
    if not chk(request): return jsonify({}), 401
    img, w, h = grab()
    return jsonify({"img": img})

@app.route("/tap", methods=["POST"])
def tap():
    if not chk(request): return jsonify({}), 401
    d = request.json or {}
    adb(f"input tap {int(d.get('x',0))} {int(d.get('y',0))}")
    return jsonify({"ok": True})

@app.route("/swipe", methods=["POST"])
def swipe():
    if not chk(request): return jsonify({}), 401
    d = request.json or {}
    dur = max(50, min(int(d.get("dur", 300)), 2000))
    adb(f"input swipe {int(d.get('x1',0))} {int(d.get('y1',0))} {int(d.get('x2',0))} {int(d.get('y2',0))} {dur}")
    return jsonify({"ok": True})

@app.route("/nav", methods=["POST"])
def nav():
    if not chk(request): return jsonify({}), 401
    action = (request.json or {}).get("action", "")
    keys = {"back":"4","home":"3","recents":"187","notifications":"83 && adb shell input keyevent 83"}
    if action in keys:
        adb(f"input keyevent {keys[action]}")
    return jsonify({"ok": True})

@app.route("/ls")
def ls():
    if not chk(request): return jsonify({}), 401
    path = request.args.get("path", "/sdcard").replace("'","").replace(";","")
    raw = adb(f"ls -la '{path}'")
    entries = []
    for line in raw.splitlines():
        p = line.split(None, 8)
        if len(p) < 2: continue
        name = p[-1].strip()
        if name in (".", ".."): continue
        size = p[4] if len(p) >= 6 and p[4].isdigit() else ""
        ftype = "d" if p[0].startswith("d") else "f"
        entries.append({"n": name, "t": ftype, "s": size})
    entries.sort(key=lambda x: (0 if x["t"]=="d" else 1, x["n"].lower()))
    return jsonify({"ok": True, "entries": entries})

@app.route("/open", methods=["POST"])
def open_file():
    if not chk(request): return jsonify({}), 401
    path = (request.json or {}).get("path", "").replace("'","").replace(";","")
    adb(f"am start -a android.intent.action.VIEW -d 'file://{path}'")
    return jsonify({"ok": True})

@app.route("/disconnect", methods=["POST"])
def disconnect():
    if not chk(request): return jsonify({}), 401
    threading.Thread(target=lambda: (time.sleep(0.5), os._exit(0))).start()
    return jsonify({"ok": True})

if __name__ == "__main__":
    print(f"[UNKNOWN Remote] http://0.0.0.0:8888  codigo={SESSION_CODE}")
    app.run(host="0.0.0.0", port=8888, debug=False, threaded=True)
RVEOF
}


actualizar_scanner() {
    clear; banner
    echo -e "${B}[*] Actualizando scanner...${N}\n"
    cd "$(dirname "$0")"
    git fetch origin
    git reset --hard origin/main
    git clean -f -d
    echo -e "\n${G}[✓] Scanner actualizado correctamente${N}"
    sleep 2
    exec bash scanner.sh
}

guardar_dumpsys() {
    clear; banner
    echo -e "${B}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${B}║         GUARDAR DIAGNÓSTICO COMPLETO                  ║${N}"
    echo -e "${B}╚════════════════════════════════════════════════════════╝${N}"

    if ! adb devices | grep -q "device$"; then
        echo -e "${R}[!] No hay dispositivos conectados. Usá la opción [0]${N}"
        echo -e "${W}Enter...${N}"; read; main_menu; return
    fi

    DUMP_DIR="/sdcard/Download/unknown_dump_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$DUMP_DIR"
    echo -e "${B}[*] Guardando en: ${W}$DUMP_DIR${N}\n"

    _dump() {
        echo -ne "${B}  → $1...${N}"
        eval "$2" > "$DUMP_DIR/$3" 2>&1
        echo -e " ${G}OK${N}"
    }

    _dump "Propiedades"         "adb shell 'getprop 2>/dev/null'"                          "getprop.txt"
    _dump "Kernel info"         "adb shell 'uname -a; echo; cat /proc/version; echo; cat /proc/cmdline | tr \"\\0\" \" \"'" "kernel_info.txt"
    for buf in main system events kernel crash; do
        _dump "Logcat [$buf]"   "adb shell 'logcat -d -b $buf 2>/dev/null'"                "logcat_${buf}.txt"
    done
    _dump "Logcat completo"     "adb shell 'logcat -d -v threadtime -b all 2>/dev/null | tail -n 8000'" "logcat_all.txt"
    for svc in package activity procstats batterystats appops usb media_projection overlay; do
        _dump "dumpsys $svc"    "adb shell 'dumpsys $svc 2>/dev/null'"                     "dumpsys_${svc}.txt"
    done
    _dump "usagestats"          "adb shell 'dumpsys usagestats 2>/dev/null | tail -n 8000'" "dumpsys_usagestats.txt"
    _dump "Procesos"            "adb shell 'ps -A -Z 2>/dev/null'"                         "ps_full.txt"
    _dump "Montajes"            "adb shell 'cat /proc/mounts 2>/dev/null'"                 "mounts.txt"
    _dump "TCP"                 "adb shell 'cat /proc/net/tcp /proc/net/tcp6 2>/dev/null'" "tcp.txt"
    _dump "Unix sockets"        "adb shell 'cat /proc/net/unix 2>/dev/null'"               "unix_sockets.txt"
    _dump "Dropbox"             "adb shell 'dumpsys dropbox 2>/dev/null'"                  "dumpsys_dropbox.txt"
    _dump "Package FF Normal"   "adb shell 'dumpsys package com.dts.freefireth 2>/dev/null'"  "pkg_ff.txt"
    _dump "Package FF MAX"      "adb shell 'dumpsys package com.dts.freefiremax 2>/dev/null'" "pkg_ffmax.txt"

    echo ""
    DUMP_SIZE=$(du -sh "$DUMP_DIR" 2>/dev/null | cut -f1)
    echo -e "${G}[✓] Guardado: ${W}$DUMP_DIR ${G}($DUMP_SIZE)${N}"
    echo -e "${Y}[*] Guardado en Descargas: $(basename $DUMP_DIR)${N}"
    echo ""
    echo -e "${W}Enter para volver...${N}"; read; main_menu
}

conectar_adb() {
    clear; banner
    echo -e "${B}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${B}║           INSTRUCCIONES PARA CONECTAR ADB              ║${N}"
    echo -e "${B}╚════════════════════════════════════════════════════════╝${N}"
    echo -e "${W}1. Ajustes > Opciones de Desarrollador${N}"
    echo -e "${W}2. Activar 'Depuración inalámbrica'${N}"
    echo -e "${W}3. Tocar 'Vincular dispositivo mediante código'${N}"
    echo -e "${W}4. Anotar el código de 6 dígitos y el puerto${N}"
    echo ""
    echo -ne "${Y}Código de 6 dígitos: ${N}"; read -r pair_code
    if [ ${#pair_code} -ne 6 ]; then
        echo -e "${R}[!] Código debe tener 6 dígitos${N}"; sleep 2; conectar_adb; return
    fi
    echo -ne "${Y}Puerto de pareamiento: ${N}"; read -r pair_port_input
    pair_port=$(echo "$pair_port_input" | grep -oE '[0-9]+$' | tail -1)
    if [ -z "$pair_port" ] || [ "$pair_port" -lt 1 ] || [ "$pair_port" -gt 65535 ]; then
        echo -e "${R}[!] Puerto inválido${N}"; sleep 2; conectar_adb; return
    fi
    echo -e "${B}[*] Pareando...${N}"
    PAIR_RESULT=$(adb pair localhost:$pair_port $pair_code 2>&1)
    if ! echo "$PAIR_RESULT" | grep -qi "successfully\|success"; then
        echo -e "${R}[!] Error en pareamiento${N}"; echo -e "${W}Enter para volver...${N}"; read; main_menu; return
    fi
    echo -e "${G}[✓] Pareamiento exitoso${N}"
    echo ""
    echo -e "${Y}Cerrá la ventana del código y anotá el puerto que aparece arriba${N}"
    echo -ne "${Y}Puerto de conexión: ${N}"; read -r connect_port_input
    connect_port=$(echo "$connect_port_input" | grep -oE '[0-9]+$' | tail -1)
    if [ -z "$connect_port" ] || [ "$connect_port" -lt 1 ] || [ "$connect_port" -gt 65535 ]; then
        echo -e "${R}[!] Puerto inválido${N}"; sleep 2; conectar_adb; return
    fi
    echo -e "${B}[*] Conectando...${N}"
    CONNECT_RESULT=$(adb connect localhost:$connect_port 2>&1)
    if echo "$CONNECT_RESULT" | grep -qi "connected"; then
        echo -e "${G}[✓] Conexión exitosa${N}"
    else
        echo -e "${R}[!] Error en conexión${N}"
    fi
    sleep 1
    adb devices | grep -q "device$" && echo -e "${G}[✓] Dispositivo listo${N}" || echo -e "${R}[!] Dispositivo no conectado${N}"
    echo -e "${W}Enter para volver...${N}"; read; main_menu
}

scan_ff_normal() { GAME_PKG="com.dts.freefireth";  GAME_SELECTED="Free Fire";    verificar_hwid_ban && ejecutar_scan; }
scan_ff_max()    { GAME_PKG="com.dts.freefiremax"; GAME_SELECTED="Free Fire MAX"; verificar_hwid_ban && ejecutar_scan; }

ver_ultimo_log() {
    clear; banner
    ULTIMO_LOG=$(ls -t $HOME/anticheat_log_*.txt 2>/dev/null | head -1)
    if [ -z "$ULTIMO_LOG" ]; then
        echo -e "${R}[!] No hay logs guardados${N}"; echo -e "${W}Enter...${N}"; read; main_menu; return
    fi
    cat "$ULTIMO_LOG"
    echo -e "${W}Enter para volver...${N}"; read; main_menu
}

ejecutar_scan() {
    clear; banner
    IG_URL="https://www.instagram.com/tizi_7zz?igsh=MTdndzJyb2hzeDJmZQ=="
    SEP="${Y}+========================================================+${N}"
    DIV="${Y}+--------------------------------------------------------+${N}"
    echo -e "$SEP"
    echo -e "${Y}|${R}     !   ATENCION  --  LEER ANTES DE CONTINUAR   !     ${Y}|${N}"
    echo -e "$SEP"
    echo -e "${Y}|${N}"
    echo -e "${Y}|${W}  Garena hizo una actualizacion que rompio el sistema${N}"
    echo -e "${Y}|${W}  de deteccion de replays. El scanner puede generar${N}"
    echo -e "${Y}|${W}  FALSOS POSITIVOS en el modulo de replays.${N}"
    echo -e "${Y}|${N}"
    echo -e "${Y}|${W}  Ya se incorporo un sistema de aviso para estos casos.${N}"
    echo -e "${Y}|${N}"
    echo -e "$DIV"
    echo -e "${Y}|${C}  Para los SS:${N}"
    echo -e "${Y}|${W}    * Usen herramientas como Logcat, Brevent, etc.${N}"
    echo -e "${Y}|${W}    * NO apliquen W.O unicamente por el scanner.${N}"
    echo -e "${Y}|${W}    * El scanner puede cometer falsos positivos.${N}"
    echo -e "${Y}|${W}    * Ante la duda, analicen SIEMPRE manualmente.${N}"
    echo -e "${Y}|${N}"
    echo -e "$DIV"
    echo -e "${Y}|${C}  No sabes como revisar? Sin problema:${N}"
    echo -e "${Y}|${W}  Mandame captura a Instagram y te ayudo gratis.${N}"
    echo -e "${Y}|${W}  Mantengamos un ambiente limpio juntos.${N}"
    echo -e "${Y}|${N}"
    echo -e "${Y}|${M}  Instagram: @tizi_7zz${N}"
    echo -e "${Y}|${N}"
    echo -e "$SEP"
    echo -e "${Y}|${M}       Gracias por leer -- TIZI  *  UNKNOWN TEAM${N}"
    echo -e "$SEP"
    echo ""
    echo -ne "${W}  [ENTER] iniciar scan / [I] abrir Instagram: ${N}"
    read -r _opc
    if [[ "${_opc,,}" == "i" ]]; then
        if command -v termux-open-url &>/dev/null; then
            termux-open-url "$IG_URL"
        else
            am start -a android.intent.action.VIEW -d "$IG_URL" &>/dev/null
        fi
        echo -ne "${W}  Presiona [ENTER] para continuar... ${N}"; read
    fi

    clear; banner
    registrar_uso
    log_output "${B}[*] Escaneando: $GAME_SELECTED${N}\n"

    if ! adb devices | grep -q "device$"; then
        log_output "${R}[!] No hay dispositivos conectados. Usá la opción [0]${N}"
        echo -e "${W}Enter...${N}"; read; main_menu; return
    fi

    prefetch_device_data

    if ! echo "$PKG_CACHE" | grep -q "$GAME_PKG"; then
        log_output "${R}[!] $GAME_SELECTED no está instalado${N}"
        sleep 3; main_menu; return
    fi
    check_device_info
    check_root
    check_uptime
    detect_shell_bypass
    check_system_logs
    check_time_changes
    check_clipboard
    check_downloads
    check_vpn_dns
    check_deleted_files
    check_replays
    check_wallhack_bypass
    check_obb
    check_hooks
    check_root_bypass
    check_fake_time
    check_tooling
    check_selinux
    check_boot_state
    check_kernel
    check_pif
    check_device_spoof
    check_ca_certs
    check_mantis_keymap
    check_recording
    check_scenes
    check_suspicious_packages
    check_network_ports
    check_adb_connections
    check_uninstalled_apps
    check_media_projection
    check_data_local_tmp
    check_dropbox_crashes
    check_auto_time
    check_termux_on_device
    check_xiaomi_paths
    check_active_dns
    check_active_protocols
    check_logcat_delta
    check_process_delta
    REPLAY_DIR="/sdcard/Android/data/$GAME_PKG/files/MReplays"
    monitor_activo 8
    show_summary

    echo -e "\n${W}Presiona Enter para volver al menú...${N}"; read
    main_menu
}

prefetch_device_data() {
    echo -e "${B}[*] Recopilando datos del dispositivo...${N}"
    local T="$HOME/.usk_cache_$$"
    mkdir -p "$T"

    adb shell "pm list packages 2>/dev/null"                              > "$T/pkg.txt" &
    adb shell "ps -A 2>/dev/null"                                         > "$T/ps.txt"  &
    adb shell "getprop 2>/dev/null"                                       > "$T/prop.txt" &
    adb shell "logcat -d -b all 2>/dev/null | tail -n 4000"              > "$T/log.txt"  &
    adb shell "cat /proc/net/tcp /proc/net/tcp6 2>/dev/null"             > "$T/tcp.txt"  &
    adb shell "cat /proc/mounts 2>/dev/null"                             > "$T/mnt.txt"  &
    wait

    PKG_CACHE=$(cat "$T/pkg.txt" 2>/dev/null | tr -d '\r')
    PS_CACHE=$(cat "$T/ps.txt"  2>/dev/null | tr -d '\r')
    PS_SNAPSHOT_INICIO="$PS_CACHE"
    PROP_CACHE=$(cat "$T/prop.txt" 2>/dev/null | tr -d '\r')
    LOG_CACHE=$(cat "$T/log.txt"  2>/dev/null | tr -d '\r')
    LOG_LAST_LINE=$(echo "$LOG_CACHE" | tail -1)
    TCP_CACHE=$(cat "$T/tcp.txt"  2>/dev/null | tr -d '\r')
    MNT_CACHE=$(cat "$T/mnt.txt"  2>/dev/null | tr -d '\r')
    rm -rf "$T"
    echo -e "${G}[✓] Datos recopilados${N}
"
}

check_device_info() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}         INFORMACIÓN DEL DISPOSITIVO                   ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    ANDROID_VER=$(adb shell getprop ro.build.version.release | tr -d '\r\n')
    DEVICE_MODEL=$(adb shell getprop ro.product.model | tr -d '\r\n')
    DEVICE_BRAND=$(adb shell getprop ro.product.brand | tr -d '\r\n')
    log_output "${B}[*] Android: ${W}$ANDROID_VER${N}"
    log_output "${B}[*] Modelo:  ${W}$DEVICE_MODEL${N}"
    log_output "${B}[*] Marca:   ${W}$DEVICE_BRAND${N}\n"
}

check_root() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}         DETECCIÓN DE ROOT / BINARIOS SU                ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    FOUND_ROOT=0

    log_output "${B}[+] Verificando binario su y variantes...${N}"
    SU_PATHS=$(adb shell "find /system /sbin /su /data/adb /data/local/tmp /vendor 2>/dev/null \
        \( -name 'su' -o -name 'su64' -o -name 'su32' -o -name 'su-back' \
           -o -name '__su' -o -name 'off.su' -o -name 'Bksu' -o -name 'susu' \
           -o -name 'su.sh' -o -name 'supersu' \) 2>/dev/null | head -10" | tr -d '\r')
    if [ -n "$(echo "$SU_PATHS" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] BINARIO SU DETECTADO:${N}"
        echo "$SU_PATHS" | while read -r f; do [ -n "$f" ] && log_output "${Y}  $f${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_ROOT=1
    fi

    SU_CMD=$(adb shell "command -v su 2>/dev/null; which su 2>/dev/null" | tr -d '\r' | head -1)
    if [ -n "$(echo "$SU_CMD" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] ROOT: su accesible en PATH: $SU_CMD${N}"
        ((SUSPICIOUS_COUNT+=2)); FOUND_ROOT=1
    fi

    [ $FOUND_ROOT -eq 0 ] && log_output "${G}[✓] Sin ROOT${N}"
    echo ""
}

check_uptime() {
    UPTIME=$(adb shell uptime | tr -d '\r')
    log_output "${B}[*] Uptime: ${W}$UPTIME${N}"
    if echo "$UPTIME" | grep -qE "up [0-9]+ min" && ! echo "$UPTIME" | grep -qE "up [1-9][0-9]+ min"; then
        log_output "${R}[!] Reinicio muy reciente (menos de 10 min) — sospechoso${N}\n"
        ((SUSPICIOUS_COUNT++))
    else
        echo ""
    fi
}

detect_shell_bypass() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}         DETECCIÓN DE BYPASS DE FUNCIONES SHELL         ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    BYPASS_DETECTADO=0

    log_output "${B}[+] Verificando funciones shell maliciosas...${N}"
    for func in pkg git stat adb; do
        RESULT=$(adb shell "type $func 2>/dev/null | grep -q function && echo FUNCTION_DETECTED" 2>/dev/null | tr -d '\r')
        if echo "$RESULT" | grep -q "FUNCTION_DETECTED"; then
            log_output "${R}[!] BYPASS: Función '$func' sobrescrita${N}"
            ((SUSPICIOUS_COUNT+=2)); BYPASS_DETECTADO=1
        fi
    done

    log_output "${B}[+] Verificando archivos de configuración del shell...${N}"
    CONFIG_FILES=("~/.bashrc" "~/.bash_profile" "~/.zshrc" "/data/data/com.termux/files/usr/etc/bash.bashrc")
    for cfg in "${CONFIG_FILES[@]}"; do
        CFG_RESULT=$(adb shell "if [ -f $cfg ]; then grep -E '(function pkg|function git|function stat|function adb|wendell77x)' $cfg 2>/dev/null; fi" 2>/dev/null | tr -d '\r')
        if [ -n "$(echo "$CFG_RESULT" | tr -d '[:space:]')" ]; then
            log_output "${R}[!] BYPASS: Funciones maliciosas en $cfg${N}"
            ((SUSPICIOUS_COUNT+=2)); BYPASS_DETECTADO=1
        fi
    done

    log_output "${B}[+] Verificando integridad de comandos básicos...${N}"
    ECHO_RESULT=$(adb shell "echo test123" | tr -d '\r')
    if [ "$ECHO_RESULT" != "test123" ]; then
        log_output "${R}[!] BYPASS: Comando echo manipulado${N}"
        ((SUSPICIOUS_COUNT+=2)); BYPASS_DETECTADO=1
    fi
    CURRENT_YEAR=$(date +%Y)
    DATE_RESULT=$(adb shell "date +%Y 2>/dev/null" | tr -d '\r')
    if [ -z "$DATE_RESULT" ] || [ "$DATE_RESULT" != "$CURRENT_YEAR" ]; then
        log_output "${R}[!] BYPASS: Comando date manipulado${N}"
        ((SUSPICIOUS_COUNT+=2)); BYPASS_DETECTADO=1
    fi

    log_output "${B}[+] Buscando archivos de bypass en el dispositivo...${N}"
    BYPASS_FILES=$(adb shell 'find /sdcard /data/local/tmp -name "*.sh" -exec grep -l "function pkg\|function git\|function adb\|wendell77x" {} \; 2>/dev/null | head -5' 2>/dev/null | tr -d '\r')
    if [ -n "$(echo "$BYPASS_FILES" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] BYPASS: Archivos de bypass encontrados${N}"
        echo "$BYPASS_FILES" | while read -r f; do [ -n "$f" ] && log_output "${Y}  $f${N}"; done
        ((SUSPICIOUS_COUNT+=2)); BYPASS_DETECTADO=1
    fi

    if [ $BYPASS_DETECTADO -eq 1 ]; then
        log_output "${R}[!] ¡BYPASS DE SHELL DETECTADO! ¡APLICA EL W.O!${N}\n"
    else
        log_output "${G}[✓] Sin bypass de shell${N}\n"
    fi
}

check_system_logs() {
    log_output "${B}[+] Verificando logs del sistema...${N}"
    FIRST_LOG=$(echo "$LOG_CACHE" | grep -oE "[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" | head -1)
    log_output "${Y}[*] Primer registro de log: $FIRST_LOG${N}\n"
}

check_time_changes() {
    log_output "${B}[+] Verificando cambios de hora...${N}"
    TIME_CHANGES=$(echo "$LOG_CACHE" | grep "Time changed" | grep -v "HCALL" | tail -3)
    if [ -n "$TIME_CHANGES" ]; then
        log_output "${R}[!] CAMBIOS DE HORA DETECTADOS${N}"
        echo "$TIME_CHANGES" | while read -r line; do log_output "${Y}  $line${N}"; done
        echo ""
        ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] Sin cambios de hora${N}\n"
    fi
}

check_clipboard() {
    log_output "${B}[+] Verificando uso de clipboard por Free Fire...${N}"
    CLIP=$(echo "$LOG_CACHE" | grep 'hcallSetClipboardTextRpc' | tail -5)
    if [ -n "$CLIP" ]; then
        log_output "${Y}[!] Free Fire copió texto al portapapeles (posible cheat que copia datos del juego)${N}"
        echo "$CLIP" | while read -r line; do log_output "${W}  $line${N}"; done
        echo ""
        ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] Sin uso sospechoso del portapapeles${N}\n"
    fi
}

check_downloads() {
    log_output "${B}[+] Escaneando Downloads por APKs sospechosos...${N}"
    APKS=$(adb shell "find /sdcard/Download /sdcard/Downloads -name '*.apk' 2>/dev/null" | tr -d '\r')
    FOUND=0
    while read -r apk; do
        [ -z "$apk" ] && continue
        NAME=$(basename "$apk" | tr '[:upper:]' '[:lower:]')
        if echo "$NAME" | grep -qiE "hack|cheat|mod|panel|lucky|gg|magisk"; then
            log_output "${R}[!] APK SOSPECHOSO: $(basename "$apk")${N}"
            FOUND=1
        fi
    done <<< "$APKS"
    if [ $FOUND -eq 0 ]; then
        log_output "${G}[✓] Sin APKs sospechosos${N}\n"
    else
        ((SUSPICIOUS_COUNT+=2)); echo ""
    fi
}

check_vpn_dns() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}       DETECCIÓN DE VPN/DNS/PROXY                      ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Verificando VPN activas...${N}"
    VPN_PACKAGES=(
        "com.nordvpn.android"
        "net.openvpn.openvpn"
        "com.expressvpn.vpn"
        "com.surfshark.vpnclient.android"
        "com.cloudflare.onedotonedotonedotone"
        "com.protonvpn.android"
        "de.blinkt.openvpn"
        "com.psiphon3"
        "com.v2ray.ang"
        "com.shadowsocks.vpn"
        "com.github.shadowsocks"
        "com.hiddify.app"
    )
    VPN_DETECTED=0
    for pkg in "${VPN_PACKAGES[@]}"; do
        if echo "$PKG_CACHE" | grep -q "package:$pkg"; then
            log_output "${R}[!] VPN INSTALADA: $pkg${N}"
            VPN_DETECTED=1; ((SUSPICIOUS_COUNT++))
        fi
    done

    VPN_IF=$(adb shell "ip link show 2>/dev/null | grep -iE 'tun[0-9]|tap[0-9]|ppp[0-9]'" | tr -d '\r')
    if [ -n "$VPN_IF" ]; then
        log_output "${R}[!] INTERFAZ VPN ACTIVA: $VPN_IF${N}"
        VPN_DETECTED=1; ((SUSPICIOUS_COUNT+=2))
    fi

    [ $VPN_DETECTED -eq 0 ] && log_output "${G}[✓] Sin VPN detectada${N}"
    echo ""

    log_output "${B}[+] Verificando DNS privado...${N}"
    PRIVATE_DNS_MODE=$(adb shell "settings get global private_dns_mode" 2>/dev/null | tr -d '\r')
    PRIVATE_DNS_HOST=$(adb shell "settings get global private_dns_specifier" 2>/dev/null | tr -d '\r')

    if [ "$PRIVATE_DNS_MODE" = "hostname" ] && [ -n "$PRIVATE_DNS_HOST" ] && [ "$PRIVATE_DNS_HOST" != "null" ]; then
        if echo "$PRIVATE_DNS_HOST" | grep -qiE "proxy|cheat|hack|vpn\."; then
            log_output "${R}[!] DNS PRIVADO SOSPECHOSO: $PRIVATE_DNS_HOST${N}"
            ((SUSPICIOUS_COUNT++))
        else
            log_output "${Y}[*] DNS privado configurado: $PRIVATE_DNS_HOST (verificar manualmente)${N}"
        fi
    else
        log_output "${G}[✓] DNS privado no configurado o default${N}"
    fi
    echo ""

    log_output "${B}[+] Verificando proxy HTTP...${N}"
    HTTP_PROXY=$(adb shell "settings get global http_proxy" 2>/dev/null | tr -d '\r')
    if [ -n "$HTTP_PROXY" ] && [ "$HTTP_PROXY" != "null" ] && [ "$HTTP_PROXY" != ":0" ]; then
        log_output "${R}[!] PROXY HTTP CONFIGURADO: $HTTP_PROXY${N}"
        ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Sin proxy HTTP${N}"
    fi
    echo ""
}

check_deleted_files() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}    ARCHIVOS ELIMINADOS RECIENTEMENTE (GAME DATA)      ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    GAME_DATA_DIR="/sdcard/Android/data/$GAME_PKG"
    GAME_OBB_DIR="/sdcard/Android/obb/$GAME_PKG"
    CRITICAL_FOLDERS=("$GAME_DATA_DIR/files/contentcache" "$GAME_DATA_DIR/files/MReplays" "$GAME_DATA_DIR/cache" "$GAME_OBB_DIR")

    log_output "${B}[+] Verificando carpetas vacías sospechosas...${N}"
    EMPTY_DETECTED=0
    for folder in "${CRITICAL_FOLDERS[@]}"; do
        if adb shell "[ -d '$folder' ]" 2>/dev/null; then
            FILE_COUNT=$(adb shell "find '$folder' -type f 2>/dev/null | wc -l" | tr -d '\r')
            if [ "$FILE_COUNT" -eq 0 ]; then
                log_output "${R}[!] CARPETA VACÍA: $(basename "$folder")${N}"
                EMPTY_DETECTED=1; ((SUSPICIOUS_COUNT+=2))
            fi
        fi
    done
    [ $EMPTY_DETECTED -eq 0 ] && log_output "${G}[✓] Todas las carpetas tienen archivos${N}"
    echo ""

    log_output "${B}[+] Verificando modificaciones recientes en carpetas críticas...${N}"
    MOD_FOUND=0
    for folder in "${CRITICAL_FOLDERS[@]}"; do
        if adb shell "[ -d '$folder' ]" 2>/dev/null; then
            CHANGE_TIME=$(adb shell "stat '$folder' 2>/dev/null | grep 'Change:' | awk '{print \$2\" \"\$3}' | cut -d'.' -f1" | tr -d '\r')
            if [ -n "$CHANGE_TIME" ]; then
                CHANGE_EPOCH=$(date -d "$CHANGE_TIME" +%s 2>/dev/null || echo 0)
                CURRENT_EPOCH=$(date +%s)
                TIME_DIFF=$((CURRENT_EPOCH - CHANGE_EPOCH))
                if [ $TIME_DIFF -lt 10800 ] && [ $TIME_DIFF -gt 0 ]; then
                    HOURS_AGO=$((TIME_DIFF / 3600))
                    MINS_AGO=$(((TIME_DIFF % 3600) / 60))
                    log_output "${Y}[!] Modificada hace ${HOURS_AGO}h ${MINS_AGO}m: $(basename "$folder")${N}"
                    MOD_FOUND=1; ((SUSPICIOUS_COUNT++))
                fi
            fi
        fi
    done
    [ $MOD_FOUND -eq 0 ] && log_output "${G}[✓] Sin modificaciones recientes sospechosas${N}"
    echo ""
}

check_replays() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}              ANÁLISIS DE REPLAYS                      ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    for _wl in "${REPLAY_HWID_WHITELIST[@]}"; do
        if [ "$DEVICE_HWID" = "$_wl" ]; then
            log_output "${B}[*] Dispositivo exento — analisis de replays omitido${N}"
            echo ""; return 0
        fi
    done

    REPLAY_DIR="/sdcard/Android/data/$GAME_PKG/files/MReplays"
    MOTIVOS=()
    BINS_RAW=$(adb shell "ls -t '$REPLAY_DIR'/*.bin 2>/dev/null" | tr -d '\r')

    if [ -z "$(echo "$BINS_RAW" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Sin replays en MReplays${N}"
        MOTIVOS+=("Motivo 10 - Sin archivos .bin en MReplays")
        ((SUSPICIOUS_COUNT+=2))
    fi

    GAME_VERSION_INSTALLED=""
    DUMPSYS_PKG=$(adb shell "dumpsys package $GAME_PKG 2>/dev/null" | tr -d '\r')
    [ -n "$DUMPSYS_PKG" ] && GAME_VERSION_INSTALLED=$(echo "$DUMPSYS_PKG" | grep "versionName=" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    ULTIMO_MODIFY_TS=0; ULTIMO_CHANGE_TS=0; ARCHIVO_MAS_RECIENTE=""; PRIMER_ARCHIVO=1

    while read -r bin; do
        [ -z "$bin" ] && continue
        FNAME=$(basename "$bin")
        log_output "${W}[*] Replay: $FNAME${N}"

        STAT=$(adb shell "stat '$bin' 2>/dev/null" | tr -d '\r')
        [ -z "$STAT" ] && continue

        DA=$(echo "$STAT" | grep "^Access:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
        DM=$(echo "$STAT" | grep "^Modify:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
        DC=$(echo "$STAT" | grep "^Change:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)

        TS_A=$(date -d "${DA%%.*}" +%s 2>/dev/null || echo 0)
        TS_M=$(date -d "${DM%%.*}" +%s 2>/dev/null || echo 0)

        if [ $PRIMER_ARCHIVO -eq 1 ]; then
            ULTIMO_MODIFY_TS=$TS_M
            ULTIMO_CHANGE_TS=$(date -d "${DC%%.*}" +%s 2>/dev/null || echo 0)
            ARCHIVO_MAS_RECIENTE="$bin"; PRIMER_ARCHIVO=0
        fi

        [ "$TS_A" -gt "$TS_M" ] 2>/dev/null && MOTIVOS+=("Motivo 1 - Access posterior a Modify: $FNAME")

        NANOS_A=$(echo "$DA" | grep -oE '\.[0-9]+$')
        NANOS_M=$(echo "$DM" | grep -oE '\.[0-9]+$')
        NANOS_C=$(echo "$DC" | grep -oE '\.[0-9]+$')
        echo "$NANOS_A$NANOS_M$NANOS_C" | grep -qE '\.0+$' && MOTIVOS+=("Motivo 2 - Timestamps .000: $FNAME")

        [ "$DM" != "$DC" ] && MOTIVOS+=("Motivo 3 - Modify ≠ Change: $FNAME")

        NAME_DATE=$(echo "$FNAME" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}' | head -1)
        if [ -n "$NAME_DATE" ]; then
            NAME_NORM=$(echo "$NAME_DATE" | sed 's/^\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)$/\1-\2-\3 \4:\5:\6/')
            TS_NAME=$(date -d "$NAME_NORM" +%s 2>/dev/null || echo 0)
            DIFF_NAME=$(( TS_NAME > TS_M ? TS_NAME - TS_M : TS_M - TS_NAME ))
            [ "$DIFF_NAME" -gt 1 ] 2>/dev/null && MOTIVOS+=("Motivo 4 - Nombre no coincide con Modify: $FNAME")
        fi

        JSON_PATH="${bin%.bin}.json"
        JSON_STAT=$(adb shell "stat '$JSON_PATH' 2>/dev/null" | tr -d '\r')
        if [ -z "$JSON_STAT" ]; then
            MOTIVOS+=("Motivo 8 - JSON ausente: $(basename "$JSON_PATH")")
        else
            JSON_DA=$(echo "$JSON_STAT" | grep "^Access:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
            [ "$JSON_DA" != "$DA" ] && [ "$JSON_DA" != "$DM" ] && [ "$JSON_DA" != "$DC" ] && \
                MOTIVOS+=("Motivo 8 - Access JSON diferente: $(basename "$JSON_PATH")")
        fi

        if [ -n "$GAME_VERSION_INSTALLED" ]; then
            JSON_CONTENT=$(adb shell "cat '$JSON_PATH' 2>/dev/null" | tr -d '\r')
            if [ -n "$JSON_CONTENT" ]; then
                VERSION_JSON=$(echo "$JSON_CONTENT" | grep -oE '"Version":"[^"]*"' | grep -oE ':[^}]*' | tr -d ':"')
                [ -n "$VERSION_JSON" ] && [ "$VERSION_JSON" != "$GAME_VERSION_INSTALLED" ] && \
                    MOTIVOS+=("Motivo 14 - Replay versión $VERSION_JSON vs juego $GAME_VERSION_INSTALLED: $(basename "$JSON_PATH")")
            fi
        fi

    done <<< "$BINS_RAW"

    OUTRO_JSON="$REPLAY_DIR/outro.json"
    OUTRO_STAT=$(adb shell "stat '$OUTRO_JSON' 2>/dev/null" | tr -d '\r')
    if [ -n "$OUTRO_STAT" ]; then
        OUTRO_M=$(echo "$OUTRO_STAT" | grep "^Modify:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
        OUTRO_C=$(echo "$OUTRO_STAT" | grep "^Change:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
        [ "$OUTRO_M" != "$OUTRO_C" ] && [ -n "$OUTRO_M" ] && MOTIVOS+=("Motivo 15 - outro.json Modify != Change: manipulacion de metadata")
        OUTRO_NANOS=$(echo "$OUTRO_M" | grep -oE '\.[0-9]+$')
        echo "$OUTRO_NANOS" | grep -qE '\.0+$' && MOTIVOS+=("Motivo 16 - outro.json timestamps .000: copia/manipulacion")
    fi

    PASTA_STAT=$(adb shell "stat '$REPLAY_DIR' 2>/dev/null" | tr -d '\r')
    if [ -n "$PASTA_STAT" ]; then
        PA=$(echo "$PASTA_STAT" | grep "^Access:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
        PM=$(echo "$PASTA_STAT" | grep "^Modify:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
        PC=$(echo "$PASTA_STAT" | grep "^Change:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
        TS_PM=$(date -d "${PM%%.*}" +%s 2>/dev/null || echo 0)
        TS_PC=$(date -d "${PC%%.*}" +%s 2>/dev/null || echo 0)

        [ "$PA" = "$PM" ] && [ "$PM" = "$PC" ] && [ -n "$PA" ] && MOTIVOS+=("Motivo 5 - A/M/C idénticos en carpeta MReplays")
        PM_N=$(echo "$PM" | grep -oE '\.[0-9]+$'); PC_N=$(echo "$PC" | grep -oE '\.[0-9]+$')
        echo "$PM_N$PC_N" | grep -qE '\.0+$' && MOTIVOS+=("Motivo 6 - Milisegundos .000 en carpeta")
        [ "$TS_PM" -gt "$ULTIMO_MODIFY_TS" ] && [ "$ULTIMO_MODIFY_TS" -gt 0 ] 2>/dev/null && MOTIVOS+=("Motivo 7 - Carpeta modificada después del último replay (Modify)")
        [ "$TS_PC" -gt "$ULTIMO_CHANGE_TS" ] && [ "$ULTIMO_CHANGE_TS" -gt 0 ] 2>/dev/null && MOTIVOS+=("Motivo 7 - Carpeta modificada después del último replay (Change)")
        [ "$PM" != "$PC" ] && [ -n "$PM" ] && MOTIVOS+=("Motivo 11 - Modify ≠ Change en carpeta MReplays")
    fi


    if [ -n "$ARCHIVO_MAS_RECIENTE" ]; then
        log_output "${B}[+] Segunda pasada — verificando estabilidad de timestamps...${N}"
        STAT_PASADA1=$(adb shell "stat '$ARCHIVO_MAS_RECIENTE' 2>/dev/null" | tr -d '\r')
        sleep 3
        STAT_PASADA2=$(adb shell "stat '$ARCHIVO_MAS_RECIENTE' 2>/dev/null" | tr -d '\r')

        DM_P1=$(echo "$STAT_PASADA1" | grep "^Modify:" | head -1)
        DM_P2=$(echo "$STAT_PASADA2" | grep "^Modify:" | head -1)
        DC_P1=$(echo "$STAT_PASADA1" | grep "^Change:" | head -1)
        DC_P2=$(echo "$STAT_PASADA2" | grep "^Change:" | head -1)

        if [ "$DM_P1" != "$DM_P2" ] || [ "$DC_P1" != "$DC_P2" ]; then
            log_output "${R}[!] MANIPULACION EN TIEMPO REAL: timestamps del replay cambiaron entre pasadas${N}"
            log_output "${Y}    Pasada 1 Modify: $DM_P1${N}"
            log_output "${Y}    Pasada 2 Modify: $DM_P2${N}"
            MOTIVOS+=("Motivo 17 - Timestamps mutando durante el scan: manipulacion activa detectada")
            ((SUSPICIOUS_COUNT+=5))
        else
            log_output "${G}[✓] Timestamps estables entre pasadas${N}"
        fi
    fi

    echo ""
    if [ ${#MOTIVOS[@]} -gt 0 ]; then
        log_output "${Y}[!] ANOMALIAS EN REPLAYS - REVISAR MANUALMENTE - POSIBLE FALSO POSITIVO${N}"
        for m in "${MOTIVOS[@]}"; do log_output "${Y}    - $m${N}"; done
        ((SUSPICIOUS_COUNT+=3))
    else
        log_output "${G}[✓] Replays normales${N}"
    fi
    echo ""
}

check_wallhack_bypass() {
    log_output "${B}[+] Verificando shaders...${N}"
    SHADER_DIR="/sdcard/Android/data/$GAME_PKG/files/contentcache/Optional/android/gameassetbundles"
    SHADERS=$(adb shell "find '$SHADER_DIR' -name 'shader*' 2>/dev/null" | tr -d '\r' | head -3)
    if [ -z "$SHADERS" ]; then
        log_output "${G}[✓] Sin shaders modificados${N}\n"; return
    fi
    SHADER_OK=1
    echo "$SHADERS" | while read -r shader; do
        UNITY=$(adb shell "head -c 7 '$shader' 2>/dev/null")
        if [ "$UNITY" != "UnityFS" ]; then
            log_output "${R}[!] SHADER INVÁLIDO: $(basename "$shader")${N}"
            ((SUSPICIOUS_COUNT+=3)); SHADER_OK=0
        fi
    done
    [ $SHADER_OK -eq 1 ] && log_output "${G}[✓] Shaders OK${N}"
    echo ""
}

check_obb() {
    log_output "${B}[+] Verificando OBB...${N}"
    OBB=$(adb shell "ls '/sdcard/Android/obb/$GAME_PKG' 2>/dev/null" | tr -d '\r')
    if [ -z "$OBB" ]; then
        log_output "${R}[!] OBB no encontrado${N}\n"; ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] OBB presente${N}\n"
    fi
}

check_hooks() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}  HOOKING: Frida / Xposed / LSPosed / Shizuku / Inject  ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    FOUND_HOOK=0

    log_output "${B}[+] Verificando procesos de hooking...${N}"
    HOOK_PROC=$(echo "$PS_CACHE" | grep -iE 'frida|xposed|lsposed|lspatch|zygisk|riru|shizuku')
    if [ -n "$HOOK_PROC" ]; then
        log_output "${R}[!] PROCESO DE HOOKING ACTIVO:${N}"
        echo "$HOOK_PROC" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_HOOK=1
    fi

    log_output "${B}[+] Verificando archivos de hooking...${N}"
    HOOK_FILES=$(adb shell "find /data /system 2>/dev/null | grep -iE '/frida|/xposed|/lsposed|/lspatch|/riru' | grep -v 'knox' | head -10" | tr -d '\r')
    if [ -n "$(echo "$HOOK_FILES" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] ARCHIVOS DE HOOKING:${N}"
        echo "$HOOK_FILES" | while read -r f; do [ -n "$f" ] && log_output "${Y}  $f${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_HOOK=1
    fi

    log_output "${B}[+] Verificando LSPatch / LSPosed crackeado / wrapper...${N}"
    PKG_HOOK=$(echo "$PKG_CACHE" | grep -iE 'lspatch|lsposed|crackedlsposed|lsposedwrapper')
    if [ -n "$PKG_HOOK" ]; then
        log_output "${R}[!] PAQUETE DE HOOKING INSTALADO:${N}"
        echo "$PKG_HOOK" | while read -r p; do [ -n "$p" ] && log_output "${Y}  $p${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_HOOK=1
    fi

    log_output "${B}[+] Verificando Shizuku (escalada de privilegios)...${N}"
    SHIZUKU=$(echo "$PKG_CACHE" | grep -i 'shizuku')
    SHIZUKU_SVC=$(echo "$PS_CACHE" | grep -i 'shizuku')
    if [ -n "$SHIZUKU" ] || [ -n "$SHIZUKU_SVC" ]; then
        log_output "${R}[!] SHIZUKU DETECTADO (escalada de privilegios sin root):${N}"
        [ -n "$SHIZUKU" ] && log_output "${Y}  Package: $SHIZUKU${N}"
        [ -n "$SHIZUKU_SVC" ] && log_output "${Y}  Proceso: $SHIZUKU_SVC${N}"
        ((SUSPICIOUS_COUNT+=3)); FOUND_HOOK=1
    fi

    [ $FOUND_HOOK -eq 0 ] && log_output "${G}[✓] Sin hooking detectado${N}"
    echo ""
}

check_root_bypass() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     ROOT AVANZADO / MAGISK / SHAMIKO / ZYGISK          ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Verificando Magisk, Shamiko, Zygisk...${N}"
    BYPASS_FOUND=0

    BYPASS_PS=$(echo "$PS_CACHE" | grep -iE 'magisk|shamiko|zygisk|busybox' | grep -viE 'knox')
    if [ -n "$BYPASS_PS" ]; then
        log_output "${R}[!] ROOT BYPASS DETECTADO (proceso)${N}"
        echo "$BYPASS_PS" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=3)); BYPASS_FOUND=1
    fi

    MAGISK_FILES=$(adb shell "ls /data/adb/magisk 2>/dev/null" | tr -d '\r')
    if [ -n "$MAGISK_FILES" ]; then
        log_output "${R}[!] MAGISK DETECTADO (/data/adb/magisk existe)${N}"
        ((SUSPICIOUS_COUNT+=3)); BYPASS_FOUND=1
    fi

    [ $BYPASS_FOUND -eq 0 ] && log_output "${G}[✓] Sin root bypass avanzado${N}"
    echo ""
}

check_fake_time() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}          DETECCIÓN DE TIEMPO FALSO / CONGELADO         ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Midiendo progresión del tiempo (3 muestras)...${N}"
    T1=$(adb shell "date +%s 2>/dev/null" | tr -d '\r')
    sleep 2
    T2=$(adb shell "date +%s 2>/dev/null" | tr -d '\r')
    sleep 2
    T3=$(adb shell "date +%s 2>/dev/null" | tr -d '\r')

    if [ -n "$T1" ] && [ -n "$T2" ] && [ -n "$T3" ]; then
        D1=$((T2 - T1))
        D2=$((T3 - T2))
        log_output "${B}[*] Intervalo 1: ${W}${D1}s${N}  |  Intervalo 2: ${W}${D2}s${N}"
        TIEMPO_OK=1
        [ "$D1" -lt 1 ] && { log_output "${R}[!] TIEMPO CONGELADO — no avanzó entre muestra 1 y 2${N}"; ((SUSPICIOUS_COUNT+=3)); TIEMPO_OK=0; }
        [ "$D2" -lt 1 ] && { log_output "${R}[!] TIEMPO CONGELADO — no avanzó entre muestra 2 y 3${N}"; ((SUSPICIOUS_COUNT+=3)); TIEMPO_OK=0; }
        SALTO=$(( D1 > D2 ? D1 - D2 : D2 - D1 ))
        if [ "$SALTO" -gt 3 ] && [ $TIEMPO_OK -eq 1 ] 2>/dev/null; then
            log_output "${R}[!] SALTO DE TIEMPO IRREGULAR: diferencia de ${SALTO}s entre intervalos${N}"
            ((SUSPICIOUS_COUNT+=2))
        elif [ $TIEMPO_OK -eq 1 ]; then
            log_output "${G}[✓] Tiempo avanza normalmente y de forma consistente${N}"
        fi
    fi

    log_output "${B}[+] Verificando coherencia de timestamps via stat...${N}"
    TEST_FILE="/data/local/tmp/.tc_$$"
    adb shell "echo test > $TEST_FILE 2>/dev/null" >/dev/null 2>&1
    sleep 1
    STAT_R1=$(adb shell "stat $TEST_FILE 2>/dev/null" | tr -d '\r')
    sleep 2
    STAT_R2=$(adb shell "stat $TEST_FILE 2>/dev/null" | tr -d '\r')
    adb shell "rm -f $TEST_FILE 2>/dev/null" >/dev/null 2>&1

    ATIME1=$(echo "$STAT_R1" | grep "^Access:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
    ATIME2=$(echo "$STAT_R2" | grep "^Access:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
    if echo "$STAT_R1" | grep -q "1970"; then
        log_output "${R}[!] INCONSISTENCIA CRÍTICA: stat muestra año 1970${N}"; ((SUSPICIOUS_COUNT+=2))
    elif [ -n "$ATIME1" ] && [ "$ATIME1" = "$ATIME2" ]; then
        log_output "${R}[!] ATIME no cambia entre lecturas — posible tiempo congelado${N}"; ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Timestamps coherentes entre lecturas${N}"
    fi
    echo ""
}

check_tooling() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     HERRAMIENTAS SOSPECHOSAS / EMULADOR                ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Verificando emuladores y herramientas sospechosas...${N}"
    TOOL_FOUND=0

    EMULATOR_PROPS=$(echo "$PROP_CACHE" | grep -iE 'qemu|goldfish|vbox|genymotion|nox|memu|bluestacks|andy|droid4x' | grep -viE 'knox|samsung|\]: \[0\]|\]: \[\]')
    if [ -n "$EMULATOR_PROPS" ]; then
        log_output "${R}[!] EMULADOR DETECTADO${N}"
        echo "$EMULATOR_PROPS" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=2)); TOOL_FOUND=1
    fi

    QEMU_PROC=$(echo "$PS_CACHE" | grep -iE 'qemu|genymotion|bluestacks' | grep -viE 'knox')
    if [ -n "$QEMU_PROC" ]; then
        log_output "${R}[!] PROCESO DE EMULADOR DETECTADO${N}"
        echo "$QEMU_PROC" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=2)); TOOL_FOUND=1
    fi

    QEMU_FLAG=$(echo "$PROP_CACHE" | grep "ro.kernel.qemu" | grep -oE "\[.*\]$" | tr -d "[]")
    if [ "$QEMU_FLAG" = "1" ]; then
        log_output "${R}[!] EMULADOR CONFIRMADO (ro.kernel.qemu=1)${N}"
        ((SUSPICIOUS_COUNT+=3)); TOOL_FOUND=1
    fi

    [ $TOOL_FOUND -eq 0 ] && log_output "${G}[✓] Dispositivo físico, sin emulador${N}"
    echo ""
}

check_selinux() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}         ESTADO DE SELINUX                             ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    SE=$(adb shell "getenforce 2>/dev/null" | tr -d '\r')
    case "$SE" in
        Enforcing)  log_output "${G}[✓] SELinux: Enforcing${N}" ;;
        Permissive) log_output "${R}[!] SELinux PERMISSIVO — común en rooteados${N}"; ((SUSPICIOUS_COUNT+=2)) ;;
        Disabled)   log_output "${R}[!] SELinux DESACTIVADO${N}"; ((SUSPICIOUS_COUNT+=3)) ;;
        *)          log_output "${Y}[*] SELinux: estado desconocido ($SE)${N}" ;;
    esac
    echo ""
}

check_boot_state() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}         ESTADO DE BOOT VERIFICADO                     ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    BOOT_STATE=$(echo "$PROP_CACHE" | grep '"ro.boot.verifiedbootstate"' | grep -oE '\[.*\]$' | tr -d '[]')
    FLASH_LOCKED=$(echo "$PROP_CACHE" | grep '"ro.boot.flash.locked"' | grep -oE '\[.*\]$' | tr -d '[]')
    VBMETA=$(echo "$PROP_CACHE" | grep '"ro.boot.vbmeta.device_state"' | grep -oE '\[.*\]$' | tr -d '[]')
    WARRANTY=$(echo "$PROP_CACHE" | grep '"ro.boot.warranty_bit"' | grep -oE '\[.*\]$' | tr -d '[]')
    log_output "${B}[*] verifiedbootstate:  ${W}${BOOT_STATE:-desconocido}${N}"
    log_output "${B}[*] flash.locked:       ${W}${FLASH_LOCKED:-desconocido}${N}"
    log_output "${B}[*] vbmeta.device_state:${W}${VBMETA:-desconocido}${N}"
    log_output "${B}[*] warranty_bit:       ${W}${WARRANTY:-desconocido}${N}"
    if [ "$BOOT_STATE" = "orange" ] || [ "$BOOT_STATE" = "red" ]; then
        log_output "${R}[!] BOOTLOADER DESBLOQUEADO: $BOOT_STATE${N}"; ((SUSPICIOUS_COUNT+=3))
    fi
    if [ "$FLASH_LOCKED" = "0" ]; then
        log_output "${R}[!] flash.locked=0${N}"; ((SUSPICIOUS_COUNT+=2))
    fi
    if [ "$VBMETA" = "unlocked" ]; then
        log_output "${R}[!] vbmeta.device_state=unlocked${N}"; ((SUSPICIOUS_COUNT+=2))
    fi
    if [ "$WARRANTY" = "1" ]; then
        log_output "${Y}[!] warranty_bit=1 — bootloader desbloqueado anteriormente${N}"; ((SUSPICIOUS_COUNT++))
    fi
    BUILD_TAGS=$(echo "$PROP_CACHE" | grep '"ro.build.tags"' | grep -oE '\[.*\]$' | tr -d '[]')
    if echo "$BUILD_TAGS" | grep -qiE "test-keys|dev-keys"; then
        log_output "${R}[!] Build tags sospechosas: $BUILD_TAGS${N}"; ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Build tags: ${BUILD_TAGS}${N}"
    fi
    echo ""
}

check_kernel() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}         ANÁLISIS DE KERNEL                            ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    KERNEL=$(adb shell 'uname -r 2>/dev/null' | tr -d '\r')
    log_output "${B}[*] Kernel: ${W}$KERNEL${N}"
    KSU_LOG=$(echo "$LOG_CACHE" | grep -iE "kernelsu|magisk|apatch" | head -1)
    if [ -n "$KSU_LOG" ]; then
        log_output "${R}[!] KernelSU/Magisk/APatch en kernel log:${N}"
        log_output "${Y}  $KSU_LOG${N}"; ((SUSPICIOUS_COUNT+=3))
    fi
    PROC_VER=$(adb shell "cat /proc/version 2>/dev/null" | tr -d '\r')
    if echo "$PROC_VER" | grep -qiE "kernelsu|magisk|apatch|dirty|unofficial"; then
        log_output "${R}[!] Kernel modificado en /proc/version${N}"
        log_output "${Y}  $PROC_VER${N}"; ((SUSPICIOUS_COUNT+=2))
    fi
    SUSFS=$(adb shell '{ test -d /proc/sys/fs/susfs && echo FOUND; } || { test -d /sys/kernel/security/susfs && echo FOUND; } || echo NOTFOUND' | tr -d '\r')
    PAGE_SIZE=$(adb shell "getprop ro.product.cpu.pagesize.max 2>/dev/null || cat /proc/sys/vm/mmap_min_addr 2>/dev/null" | tr -d '\r')
    if echo "$SUSFS" | grep -q "FOUND"; then
        if echo "$KERNEL" | grep -qE "\-16k|16k" || [ "$PAGE_SIZE" = "16384" ]; then
            log_output "${B}[*] SuSFS-16k presente (kernel con páginas 16K — informativo)${N}"
        else
            log_output "${B}[*] SuSFS-4k presente (informativo — presente en kernels stock recientes)${N}"
        fi
    else
        log_output "${G}[✓] SuSFS no detectado${N}"
    fi
    CUSTOM_KERNELS=$(echo "$KERNEL" | grep -iE "alucard|chronos|sultan|lychee|eureka|ethereal|elitekernel|wild|buddy|panda|redmi-oc|apatch")
    if [ -n "$CUSTOM_KERNELS" ]; then
        log_output "${R}[!] Kernel custom con soporte root: $CUSTOM_KERNELS${N}"; ((SUSPICIOUS_COUNT+=2))
    fi

    KSUNEXT_PROP=$(echo "$PROP_CACHE" | grep -im1 'ksunext\|com\.rifsxd')
    if [ -n "$KSUNEXT_PROP" ]; then
        log_output "${R}[!] KernelSU Next detectado en props: $KSUNEXT_PROP${N}"; ((SUSPICIOUS_COUNT+=3))
    fi
    if [ -n "$KSU_MOUNT" ]; then
        log_output "${R}[!] Módulos KernelSU montados:${N}"
        echo "$KSU_MOUNT" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=2))
    fi
    echo ""
}

check_suspicious_packages() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     APLICACIONES SOSPECHOSAS / ROOT / CHEAT           ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    declare -A SUSP_APPS
    SUSP_APPS=(
        ["com.topjohnwu.magisk"]="Magisk"
        ["io.github.magisk"]="Magisk"
        ["com.rifsxd.ksunext"]="KernelSU Next"
        ["me.weishu.kernelsu"]="KernelSU"
        ["me.bmax.apatch"]="APatch"
        ["io.github.huskydg.magisk"]="Magisk Delta"
        ["org.lsposed.manager"]="LSPosed Manager"
        ["com.dergoogler.mmrl"]="MMRL"
        ["com.googleplay.ndkvs"]="FF Modificado (.ndkvs)"
        ["eu.sisik.hackendebug"]="Hack&Debug"
        ["me.piebridge.brevent"]="Brevent"
        ["io.github.mhmrdd.libxposed.ps.passit"]="Passador de Replay (Xposed)"
        ["com.lexa.fakegps"]="Fake GPS"
        ["io.github.vvb2060.mahoshojo"]="TrickyStore (Bypass)"
        ["com.opa334.TrollStore"]="TrollStore"
        ["com.reveny.nativecheck"]="NativeCheck"
        ["com.studio.duckdetector"]="Duck Detector"
        ["io.github.huskydg.memorydetector"]="MemoryDetector"
        ["com.zhenxi.hunter"]="Shizuku Hunter"
        ["com.system.update.service"]="Servicio falso del sistema"
    )
    PKG_LIST="$PKG_CACHE"
    FOUND_SUSP=0
    for pkg in "${!SUSP_APPS[@]}"; do
        if echo "$PKG_LIST" | grep -q "package:$pkg"; then
            log_output "${R}[!] App sospechosa: ${SUSP_APPS[$pkg]} ($pkg)${N}"
            FOUND_SUSP=1; ((SUSPICIOUS_COUNT+=2))
        fi
    done
    log_output "${B}[+] Verificando instalador de $GAME_PKG...${N}"
    INSTALLER=$(adb shell "dumpsys package $GAME_PKG 2>/dev/null | grep 'installerPackageName'" | tr -d '\r' | head -1)
    if [ -n "$INSTALLER" ]; then
        log_output "${B}[*] $INSTALLER${N}"
        if echo "$INSTALLER" | grep -qiE "null|adb|sideload|bin.mt.plus"; then
            log_output "${R}[!] Instalador sospechoso: $INSTALLER${N}"; ((SUSPICIOUS_COUNT+=2)); FOUND_SUSP=1
        fi
    fi
    [ $FOUND_SUSP -eq 0 ] && log_output "${G}[✓] Sin apps sospechosas${N}"
    echo ""
}

check_network_ports() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     PUERTOS Y CONEXIONES SOSPECHOSAS                  ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    log_output "${B}[+] Verificando puertos Frida (27042/27043)...${N}"
    FRIDA_PORT=$(echo "$TCP_CACHE" | grep -iE ':(69B2|69B3) ' | grep -E ' 0A ' | head -3)
    if [ -n "$(echo "$FRIDA_PORT" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] PUERTOS FRIDA EN LISTEN:${N}"
        echo "$FRIDA_PORT" | while read -r line; do [ -n "$line" ] && log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=3))
    else
        log_output "${G}[✓] Sin puertos Frida${N}"
    fi
    log_output "${B}[+] Verificando proxy HTTP...${N}"
    HTTP_PROXY=$(adb shell "settings get global http_proxy 2>/dev/null" | tr -d '\r')
    if [ -n "$HTTP_PROXY" ] && [ "$HTTP_PROXY" != "null" ] && [ "$HTTP_PROXY" != ":0" ]; then
        log_output "${R}[!] PROXY HTTP: $HTTP_PROXY${N}"; ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Sin proxy HTTP${N}"
    fi
    log_output "${B}[+] Verificando proxy Wi-Fi...${N}"
    WIFI_PROXY=$(adb shell "content query --uri content://settings/global/wifi_proxy_host 2>/dev/null" | tr -d '\r')
    if echo "$WIFI_PROXY" | grep -qE "value=.+[^null]"; then
        log_output "${R}[!] Proxy Wi-Fi configurado: $WIFI_PROXY${N}"; ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Sin proxy Wi-Fi${N}"
    fi
    echo ""
}

check_adb_connections() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     CONEXIONES ADB / CONTROL REMOTO                   ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    USB_STATE=$(adb shell "getprop sys.usb.state 2>/dev/null" | tr -d '\r')
    log_output "${B}[*] USB state: ${W}${USB_STATE:-desconocido}${N}"
    ADB_READ_FAIL=$(echo "$LOG_CACHE" | grep -c "AdbDebuggingManager.*Read failed" 2>/dev/null || echo 0)
    if [ "${ADB_READ_FAIL:-0}" -gt 2 ] 2>/dev/null; then
        log_output "${R}[!] AdbDebuggingManager: $ADB_READ_FAIL fallos — PC desconectado rápidamente${N}"; ((SUSPICIOUS_COUNT++))
    fi
    DATA_ADB_PROCS=$(adb shell 'for f in /proc/[0-9]*/exe; do l=$(readlink "$f" 2>/dev/null); case "$l" in /data/adb/*ksud*|/data/adb/*magiskd*|/data/adb/*apd*) continue;; /data/adb/*) echo "${f%%/exe}: $l";; esac; done 2>/dev/null | head -5' | tr -d '\r')
    if [ -n "$(echo "$DATA_ADB_PROCS" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Procesos desde /data/adb/:${N}"
        echo "$DATA_ADB_PROCS" | while read -r line; do [ -n "$line" ] && log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Sin procesos inesperados en /data/adb/${N}"
    fi
    echo ""
}

check_uninstalled_apps() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     APPS SOSPECHOSAS DESINSTALADAS                    ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    UNINST=$(adb shell "dumpsys batterystats 2>/dev/null | grep -oE 'pkgunin=[0-9]+:\"[^\"]+\"' | grep -oE '\"[^\"]+\"' | tr -d '\"' | sort -u" | tr -d '\r')
    FOUND_U=0
    if [ -n "$UNINST" ]; then
        while read -r pkg; do
            [ -z "$pkg" ] && continue
            if echo "$pkg" | grep -qiE "magisk|xposed|kernelsu|apatch|frida|hook|cheat|hack|bypass|inject|passit"; then
                log_output "${Y}[!] App sospechosa desinstalada: $pkg${N}"; ((SUSPICIOUS_COUNT++)); FOUND_U=1
            fi
        done <<< "$UNINST"
    fi
    [ $FOUND_U -eq 0 ] && log_output "${G}[✓] Sin apps sospechosas en historial${N}"
    echo ""
}

check_media_projection() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     CAPTURA DE PANTALLA / MEDIA PROJECTION             ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    MEDIA_PROJ=$(adb shell "dumpsys media_projection 2>/dev/null | grep -iE 'isRecording=true|state.*record|projection.*active' | head -5" | tr -d '\r')
    if [ -n "$(echo "$MEDIA_PROJ" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] CAPTURA DE PANTALLA ACTIVA:${N}"
        echo "$MEDIA_PROJ" | while read -r line; do [ -n "$line" ] && log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Sin captura de pantalla activa${N}"
    fi
    echo ""
}

check_data_local_tmp() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     ARCHIVOS EN /DATA/LOCAL/TMP                       ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    TMP_FILES=$(adb shell 'for f in /data/local/tmp/* /data/local/tmp/.*; do n="${f##*/}"; case "$n" in "." | "..") ;; *) [ -e "$f" ] && echo "$n";; esac; done' | tr -d '\r')
    if [ -n "$(echo "$TMP_FILES" | tr -d '[:space:]')" ]; then
        log_output "${Y}[!] Archivos en /data/local/tmp:${N}"
        echo "$TMP_FILES" | while read -r f; do
            [ -z "$f" ] && continue
            log_output "${Y}  $f${N}"
            if echo "$f" | grep -qiE "frida|hook|inject|cheat|hack|bypass|shizuku|brevent"; then
                log_output "${R}    ^ SOSPECHOSO${N}"; ((SUSPICIOUS_COUNT++))
            fi
        done
        ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] /data/local/tmp vacío${N}"
    fi
    echo ""
}

check_dropbox_crashes() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     CRASHES SOSPECHOSOS (DROPBOX)                     ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    CRASHES=$(adb shell 'dumpsys dropbox 2>/dev/null | grep -E "native_crash|TOMBSTONE|system_server" | sed "s/.*[0-9][0-9]:[0-9][0-9]:[0-9][0-9] //" | sed "s/ ([0-9]* bytes)//" | sort | uniq -c | sort -rn | awk '"'"'$1>=3{print $1" x "$2}'"'"' | head -5' | tr -d '\r')
    if [ -n "$(echo "$CRASHES" | tr -d '[:space:]')" ]; then
        log_output "${Y}[!] Crashes repetidos:${N}"
        echo "$CRASHES" | while read -r line; do [ -n "$line" ] && log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] Sin crashes repetidos${N}"
    fi
    PHANTOM=$(echo "$LOG_CACHE" | grep "PhantomProcessRecord" | tail -3)
    if [ -n "$PHANTOM" ]; then
        log_output "${Y}[!] PhantomProcessRecord (procesos matados):${N}"
        echo "$PHANTOM" | while read -r line; do log_output "${Y}  $line${N}"; done
    fi
    echo ""
}

check_auto_time() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     CONFIGURACIÓN DE FECHA/HORA                       ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    AUTO_TIME=$(adb shell "settings get global auto_time 2>/dev/null" | tr -d '\r')
    AUTO_TZ=$(adb shell "settings get global auto_time_zone 2>/dev/null" | tr -d '\r')
    TIMEZONE=$(adb shell "getprop persist.sys.timezone 2>/dev/null" | tr -d '\r')
    log_output "${B}[*] auto_time:     ${W}${AUTO_TIME:-desconocido}${N}"
    log_output "${B}[*] auto_time_zone:${W}${AUTO_TZ:-desconocido}${N}"
    log_output "${B}[*] Zona horaria:  ${W}${TIMEZONE:-desconocida}${N}"
    if [ "$AUTO_TIME" = "0" ]; then
        log_output "${R}[!] Hora automática DESACTIVADA — facilita manipulación de timestamps${N}"; ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Hora automática activa${N}"
    fi
    echo ""
}

check_pif() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     PLAY INTEGRITY FIX / SPOOF DE INTEGRIDAD          ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    FOUND_PIF=0

    PKG_LIST_PIF="$PKG_CACHE"
    for pkg in "es.chiteroman.playintegrityfix" "com.chiteroman.playintegrityfix" "io.github.vvb2060.playintegrityfix"; do
        if echo "$PKG_LIST_PIF" | grep -q "$pkg"; then
            log_output "${R}[!] Play Integrity Fix instalado: $pkg${N}"; ((SUSPICIOUS_COUNT+=3)); FOUND_PIF=1
        fi
    done

    PIF_MOD=$(adb shell "ls /data/adb/modules 2>/dev/null | grep -iE 'playintegrity|pif|integrit'" | tr -d '\r')
    if [ -n "$PIF_MOD" ]; then
        log_output "${R}[!] Módulo PIF en Magisk: $PIF_MOD${N}"; ((SUSPICIOUS_COUNT+=3)); FOUND_PIF=1
    fi

    TRICK=$(adb shell "ls /data/adb/modules 2>/dev/null | grep -i trick" | tr -d '\r')
    if [ -n "$TRICK" ]; then
        log_output "${R}[!] TrickyStore (bypass de integridad): $TRICK${N}"; ((SUSPICIOUS_COUNT+=3)); FOUND_PIF=1
    fi

    BUILD_ID=$(adb shell "getprop ro.build.id 2>/dev/null" | tr -d '\r')
    SYS_BUILD_ID=$(adb shell "getprop ro.system.build.id 2>/dev/null" | tr -d '\r')
    if [ -n "$BUILD_ID" ] && [ -n "$SYS_BUILD_ID" ] && [ "$BUILD_ID" != "$SYS_BUILD_ID" ]; then
        log_output "${R}[!] Fingerprint adulterado: ro.build.id=$BUILD_ID ≠ ro.system.build.id=$SYS_BUILD_ID${N}"
        ((SUSPICIOUS_COUNT+=2)); FOUND_PIF=1
    fi

    DEBUGGABLE=$(adb shell "getprop ro.debuggable 2>/dev/null" | tr -d '\r')
    if [ "$DEBUGGABLE" = "1" ]; then
        log_output "${Y}[!] ro.debuggable=1 — dispositivo en modo debug${N}"; ((SUSPICIOUS_COUNT++))
    fi

    [ $FOUND_PIF -eq 0 ] && log_output "${G}[✓] Sin Play Integrity Fix${N}"
    echo ""
}

check_device_spoof() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     DEVICE SPOOFING / EVASIÓN DE BAN                  ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    FOUND_SPOOF=0

    ANDROID_ID=$(adb shell "settings get secure android_id 2>/dev/null" | tr -d '\r\n')
    log_output "${B}[*] Android ID: ${W}${ANDROID_ID:-no disponible}${N}"
    if [ -n "$ANDROID_ID" ] && [ "$ANDROID_ID" != "null" ]; then
        UNIQ=$(echo "$ANDROID_ID" | grep -oE '.' | sort -u | wc -l)
        ID_LEN=${#ANDROID_ID}
        if [ "$UNIQ" -le 2 ] || [ "$ID_LEN" -lt 15 ] 2>/dev/null; then
            log_output "${R}[!] Android ID con patrón de spoof${N}"; ((SUSPICIOUS_COUNT+=2)); FOUND_SPOOF=1
        fi
    fi

    HW_SERIAL=$(adb shell 'cat /sys/devices/soc0/serial_num 2>/dev/null || cat /sys/bus/soc/devices/soc0/serial_num 2>/dev/null' | tr -d '\r\n')
    PROP_SERIAL=$(adb shell "getprop ro.serialno 2>/dev/null" | tr -d '\r\n')
    if [ -n "$HW_SERIAL" ] && [ -n "$PROP_SERIAL" ] && [ "$HW_SERIAL" != "$PROP_SERIAL" ]; then
        log_output "${R}[!] Serial adulterado — SoC: $HW_SERIAL ≠ prop: $PROP_SERIAL${N}"
        ((SUSPICIOUS_COUNT+=3)); FOUND_SPOOF=1
    fi

    PKG_LIST_SP="$PKG_CACHE"
    for pkg in "com.metatech.deviceidfaker" "com.deviceid.changer" "com.xposed.imei" "com.imei.generator" "com.devicechanger.free"; do
        if echo "$PKG_LIST_SP" | grep -q "$pkg"; then
            log_output "${R}[!] App de spoof de ID: $pkg${N}"; ((SUSPICIOUS_COUNT+=3)); FOUND_SPOOF=1
        fi
    done
    SPOOF_NAME=$(echo "$PKG_LIST_SP" | grep -iE "deviceid|imei.changer|fakeid|androidid" | head -3)
    if [ -n "$SPOOF_NAME" ]; then
        log_output "${R}[!] App de spoof por nombre:${N}"
        echo "$SPOOF_NAME" | while read -r l; do [ -n "$l" ] && log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_SPOOF=1
    fi

    FIRST_INSTALL_MS=$(adb shell "dumpsys package $GAME_PKG 2>/dev/null | grep firstInstallTime | head -1 | grep -oE '[0-9]{10,}'" | tr -d '\r')
    UPTIME_SECS=$(adb shell "cut -d. -f1 /proc/uptime 2>/dev/null" | tr -d '\r')
    NOW_SECS=$(adb shell "date +%s 2>/dev/null" | tr -d '\r')
    if [ -n "$FIRST_INSTALL_MS" ] && [ -n "$NOW_SECS" ] && [ -n "$UPTIME_SECS" ]; then
        FIRST_S=$((FIRST_INSTALL_MS / 1000))
        BOOT_EPOCH=$((NOW_SECS - UPTIME_SECS))
        INSTALL_DAYS=$(( (NOW_SECS - FIRST_S) / 86400 ))
        UPTIME_DAYS=$((UPTIME_SECS / 86400))
        log_output "${B}[*] Juego instalado hace: ${W}${INSTALL_DAYS}d${N}  |  Uptime: ${W}${UPTIME_DAYS}d${N}"
        if [ "$FIRST_S" -gt "$BOOT_EPOCH" ] && [ "$UPTIME_SECS" -gt 86400 ] 2>/dev/null; then
            log_output "${Y}[!] Juego instalado después del último boot (reinstalación post-ban)${N}"
            ((SUSPICIOUS_COUNT+=2)); FOUND_SPOOF=1
        fi
        if [ "$INSTALL_DAYS" -le 3 ] && [ "$UPTIME_DAYS" -ge 7 ] 2>/dev/null; then
            log_output "${Y}[!] Reinstalación reciente: juego ${INSTALL_DAYS}d vs dispositivo activo ${UPTIME_DAYS}d${N}"
            ((SUSPICIOUS_COUNT++)); FOUND_SPOOF=1
        fi
    fi

    [ $FOUND_SPOOF -eq 0 ] && log_output "${G}[✓] Sin indicadores de spoof${N}"
    echo ""
}

check_ca_certs() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     CERTIFICADOS CA / MITM                            ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    USER_CERTS=$(adb shell "ls /data/misc/user/0/cacerts-added/ 2>/dev/null | wc -l" | tr -d '\r')
    if [ "${USER_CERTS:-0}" -gt 0 ] 2>/dev/null; then
        log_output "${R}[!] $USER_CERTS certificado(s) CA de usuario instalado(s) — posible MITM${N}"; ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Sin CA certs de usuario${N}"
    fi

    KC_CERTS=$(adb shell "ls /data/misc/keychain/certs-added/ 2>/dev/null | wc -l" | tr -d '\r')
    if [ "${KC_CERTS:-0}" -gt 0 ] 2>/dev/null; then
        log_output "${Y}[!] $KC_CERTS cert(s) en keychain del sistema${N}"; ((SUSPICIOUS_COUNT++))
    fi

    SSH_KEYS=$(adb shell "find /data/adb /data/local /sdcard 2>/dev/null -maxdepth 4 \( -name 'authorized_keys' -o -name 'id_rsa' -o -name 'id_ed25519' \) | head -3" | tr -d '\r')
    if [ -n "$(echo "$SSH_KEYS" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Claves SSH encontradas (tunnel de evasión):${N}"
        echo "$SSH_KEYS" | while read -r f; do [ -n "$f" ] && log_output "${Y}  $f${N}"; done
        ((SUSPICIOUS_COUNT+=2))
    fi
    echo ""
}

check_mantis_keymap() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     KEYMAPPERS / CONTROLES EXTERNOS                   ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    FOUND_KM=0

    PKG_LIST_KM="$PKG_CACHE"
    declare -A KM_APPS
    KM_APPS=(
        ["com.mantis.gamepad"]="Mantis Gamepad"
        ["com.panda.gamepad"]="Panda Gamepad"
        ["com.gamesir.global"]="GameSir"
        ["com.flydigi.center"]="Flydigi"
        ["com.tincore.gsp.gpad"]="Octopus Keymapper"
        ["io.github.ggmouse"]="GG Mouse"
        ["com.regula.mantisactivator"]="Mantis Activator"
    )
    for pkg in "${!KM_APPS[@]}"; do
        if echo "$PKG_LIST_KM" | grep -q "$pkg"; then
            log_output "${Y}[!] Keymapper: ${KM_APPS[$pkg]} ($pkg)${N}"; ((SUSPICIOUS_COUNT+=2)); FOUND_KM=1
        fi
    done
    KM_NAME=$(echo "$PKG_LIST_KM" | grep -iE "mantis|keymap|gamepad.*activat" | head -3)
    if [ -n "$KM_NAME" ] && [ $FOUND_KM -eq 0 ]; then
        log_output "${Y}[!] Keymapper por nombre:${N}"
        echo "$KM_NAME" | while read -r l; do [ -n "$l" ] && log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=2)); FOUND_KM=1
    fi

    [ $FOUND_KM -eq 0 ] && log_output "${G}[✓] Sin keymappers${N}"
    echo ""
}

check_recording() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     GRABACIÓN / ESPEJAMIENTO / SCRCPY                 ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    FOUND_REC=0

    PKG_LIST_REC="$PKG_CACHE"
    declare -A MIRROR_APPS
    MIRROR_APPS=(
        ["com.koushikdutta.vysor"]="Vysor"
        ["com.genymobile.scrcpy"]="scrcpy"
        ["com.github.xianfeng92.scrcpy"]="QtScrcpy"
        ["top.samir.guiscrcpy"]="guiScrcpy"
    )
    for pkg in "${!MIRROR_APPS[@]}"; do
        if echo "$PKG_LIST_REC" | grep -q "$pkg"; then
            log_output "${Y}[!] App de espejamiento: ${MIRROR_APPS[$pkg]}${N}"; ((SUSPICIOUS_COUNT++)); FOUND_REC=1
        fi
    done

    MEDIA_PROJ=$(adb shell "dumpsys media_projection 2>/dev/null | grep -iE 'isRecording=true|state=STARTED' | head -2" | tr -d '\r')
    if [ -n "$(echo "$MEDIA_PROJ" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] CAPTURA DE PANTALLA ACTIVA${N}"; ((SUSPICIOUS_COUNT+=2)); FOUND_REC=1
    fi

    SCRCPY_PROC=$(echo "$PS_CACHE" | grep -i scrcpy)
    if [ -n "$SCRCPY_PROC" ]; then
        log_output "${R}[!] Proceso scrcpy activo${N}"; ((SUSPICIOUS_COUNT+=2)); FOUND_REC=1
    fi

    REC_LOCK=$(adb shell "cat /proc/net/unix 2>/dev/null | grep -iE 'recordLock|recordUnlock' | head -2" | tr -d '\r')
    if [ -n "$(echo "$REC_LOCK" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Record lock en sockets Unix${N}"; ((SUSPICIOUS_COUNT+=2)); FOUND_REC=1
    fi

    [ $FOUND_REC -eq 0 ] && log_output "${G}[✓] Sin grabación activa${N}"
    echo ""
}

check_scenes() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     MODIFICACIÓN DE ESCENAS / ASSETS / PAYLOAD        ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    FOUND_SC=0

    NDKVS=$(adb shell "find /sdcard/Android/data/$GAME_PKG -name '*.ndkvs' 2>/dev/null | head -3" | tr -d '\r')
    if [ -n "$(echo "$NDKVS" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Archivo .ndkvs detectado (Free Fire modificado):${N}"
        echo "$NDKVS" | while read -r f; do [ -n "$f" ] && log_output "${Y}  $f${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_SC=1
    fi

    SCENE_DIR="/sdcard/Android/data/$GAME_PKG/files/contentcache/Optional/android/gameassetbundles"
    NON_UNITY=$(adb shell "find '$SCENE_DIR' -type f 2>/dev/null | while read f; do
        case \"\$f\" in *\~*) continue ;; esac
        h=\$(head -c 7 \"\$f\" 2>/dev/null)
        [ \"\$h\" != 'UnityFS' ] && echo \"\$f\"
    done | head -5" | tr -d '\r')
    if [ -n "$(echo "$NON_UNITY" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Assets no-UnityFS (posible wallhack/scene mod):${N}"
        echo "$NON_UNITY" | while read -r f; do [ -n "$f" ] && log_output "${Y}  $f${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_SC=1
    fi

    EXPLOITS=$(adb shell "find /data/local/tmp 2>/dev/null \( -name '*.so' -o -name 'payload*' -o -name 'exploit*' -o -name '*.bin' \) | head -5" | tr -d '\r')
    if [ -n "$(echo "$EXPLOITS" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Exploit/payload en /data/local/tmp:${N}"
        echo "$EXPLOITS" | while read -r f; do [ -n "$f" ] && log_output "${Y}  $f${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_SC=1
    fi

    [ $FOUND_SC -eq 0 ] && log_output "${G}[✓] Sin modificación de escenas/assets${N}"
    echo ""
}

check_termux_on_device() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     TERMUX / HERRAMIENTAS DE EVASION EN DISPOSITIVO    ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    FOUND_TX=0

    TERMUX_PKG=$(echo "$PKG_CACHE" | grep -iE "com.termux|termux")
    if [ -n "$TERMUX_PKG" ]; then
        log_output "${Y}[!] Termux instalado en dispositivo escaneado (informativo):${N}"
        echo "$TERMUX_PKG" | while read -r p; do [ -n "$p" ] && log_output "${Y}  $p${N}"; done
        log_output "${B}[*] Nota: puede usarse para scripts de bypass${N}"
        ((SUSPICIOUS_COUNT+=1)); FOUND_TX=1
    fi

    [ $FOUND_TX -eq 0 ] && log_output "${G}[✓] Sin Termux ni shells externos${N}"
    echo ""
}

check_xiaomi_paths() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     BYPASS XIAOMI / MIUI / HYPEROS                    ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    FOUND_MI=0

    BRAND=$(adb shell "getprop ro.product.brand 2>/dev/null" | tr -d '\r' | tr '[:upper:]' '[:lower:]')
    if echo "$BRAND" | grep -qiE "xiaomi|redmi|poco"; then
        log_output "${B}[*] Dispositivo Xiaomi/Redmi/POCO — verificando paths especificos...${N}"

        MI_ROOT_PATHS=$(adb shell "ls /data/miui 2>/dev/null; ls /data/system/miui* 2>/dev/null;             getprop ro.miui.ui.version.name 2>/dev/null; getprop ro.build.hyperos.version 2>/dev/null" | tr -d '\r')

        MI_SU=$(adb shell "find /system/xbin /system/bin 2>/dev/null -name 'su*' | head -5" | tr -d '\r')
        if [ -n "$(echo "$MI_SU" | tr -d '[:space:]')" ]; then
            log_output "${R}[!] Binario su en paths MIUI:${N}"
            echo "$MI_SU" | while read -r f; do [ -n "$f" ] && log_output "${Y}  $f${N}"; done
            ((SUSPICIOUS_COUNT+=2)); FOUND_MI=1
        fi

        MI_BYPASS=$(adb shell "getprop ro.miui.disable_dm_verity 2>/dev/null;             getprop persist.miui.disable_dm_verity 2>/dev/null" | tr -d '\r' | grep -v '^$')
        if [ -n "$MI_BYPASS" ]; then
            log_output "${Y}[!] DM-Verity modificado en MIUI: $MI_BYPASS${N}"
            ((SUSPICIOUS_COUNT++)); FOUND_MI=1
        fi

        [ $FOUND_MI -eq 0 ] && log_output "${G}[✓] Sin indicadores de bypass Xiaomi${N}"
    else
        log_output "${G}[✓] No es dispositivo Xiaomi — omitido${N}"
    fi
    echo ""
}

check_active_dns() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     ANÁLISIS DNS / INTERCEPCIÓN DE RED                 ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    FOUND_DNS=0

    DNS1=$(echo "$PROP_CACHE" | grep '"net.dns1"' | grep -oE '\[.*\]$' | tr -d '[]' | head -1)
    DNS2=$(echo "$PROP_CACHE" | grep '"net.dns2"' | grep -oE '\[.*\]$' | tr -d '[]' | head -1)
    [ -z "$DNS1" ] && DNS1=$(adb shell "getprop net.dns1 2>/dev/null" | tr -d '\r')
    [ -z "$DNS2" ] && DNS2=$(adb shell "getprop net.dns2 2>/dev/null" | tr -d '\r')
    log_output "${B}[*] DNS primario:   ${W}${DNS1:-no configurado}${N}"
    log_output "${B}[*] DNS secundario: ${W}${DNS2:-no configurado}${N}"

    KNOWN_DNS="^(8\.8\.|8\.4\.|1\.1\.|1\.0\.|9\.9\.9|149\.112|208\.67|185\.228|94\.140|192\.168|10\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[01]\.|127\.|$)"
    for DNS_VAL in "$DNS1" "$DNS2"; do
        [ -z "$DNS_VAL" ] && continue
        if ! echo "$DNS_VAL" | grep -qE "$KNOWN_DNS"; then
            log_output "${R}[!] DNS sospechoso (posible intercepción): $DNS_VAL${N}"
            ((SUSPICIOUS_COUNT+=2)); FOUND_DNS=1
        fi
    done

    for SERVER in "1.1.1.1" "8.8.8.8"; do
        PING_R=$(adb shell "ping -c 1 -W 3 $SERVER 2>/dev/null | grep -E 'time=|unreachable|100%'" | tr -d '\r')
        if echo "$PING_R" | grep -qE "unreachable|100%"; then
            log_output "${Y}[!] Sin conectividad a $SERVER — posible bloqueo${N}"
            ((SUSPICIOUS_COUNT++)); FOUND_DNS=1
        elif [ -n "$PING_R" ]; then
            log_output "${G}[✓] Conectividad a $SERVER OK${N}"
        fi
    done

    [ $FOUND_DNS -eq 0 ] && log_output "${G}[✓] DNS y conectividad normales${N}"
    echo ""
}

check_active_protocols() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     PUERTOS SOSPECHOSOS (SSH/FTP/IMAP/SOCKS)           ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    FOUND_PROTO=0

    TCP_CONNS=$(echo "$TCP_CACHE" | awk '{print $3}' | grep -v "rem_address" | sort -u)

    declare -A PROTO_PORTS
    PROTO_PORTS=(
        ["SSH"]="0016"
        ["FTP"]="0015"
        ["SMTP"]="0019"
        ["IMAP"]="008F"
        ["IMAP-SSL"]="03E1"
        ["POP3"]="006E"
        ["POP3-SSL"]="03E3"
        ["SOCKS"]="0438"
        ["PROXY-8080"]="1F90"
        ["PROXY-8888"]="22B8"
    )

    for proto in "${!PROTO_PORTS[@]}"; do
        PORT_HEX="${PROTO_PORTS[$proto]}"
        if echo "$TCP_CONNS" | grep -iq ":${PORT_HEX}"; then
            log_output "${R}[!] Conexion $proto activa (puerto sospechoso)${N}"
            ((SUSPICIOUS_COUNT+=2)); FOUND_PROTO=1
        fi
    done

    SOCKS5=$(echo "$TCP_CACHE" | awk '{print $3}' | grep -i ":0438")
    if [ -n "$(echo "$SOCKS5" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] SOCKS5 proxy activo en puerto 1080${N}"
        ((SUSPICIOUS_COUNT+=2)); FOUND_PROTO=1
    fi

    [ $FOUND_PROTO -eq 0 ] && log_output "${G}[✓] Sin puertos de protocolo sospechoso${N}"
    echo ""
}

check_logcat_delta() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     EVENTOS NUEVOS EN LOGCAT DURANTE EL SCAN           ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Capturando eventos nuevos desde inicio del scan...${N}"
    LOG_ACTUAL=$(adb shell "logcat -d -b all 2>/dev/null | tail -n 6000" | tr -d '\r')

    LOG_NUEVO=$(echo "$LOG_ACTUAL" | grep -A 999999 "$LOG_LAST_LINE" 2>/dev/null | tail -n +2)
    [ -z "$LOG_NUEVO" ] && LOG_NUEVO=$(echo "$LOG_ACTUAL" | tail -n 500)

    FOUND_LOG=0

    INJECT_LOG=$(echo "$LOG_NUEVO" | grep -iE 'inject|hook|frida|xposed|lsposed|bypass|cheat' | grep -viE 'knox|google|InputDispatcher|injectInputEvent|KeyButtonView|dalvik-internals|hooked signal|hooked sigaction|LogPrintln|Inject motion|Inject key' | head -5)
    if [ -n "$INJECT_LOG" ]; then
        log_output "${R}[!] ACTIVIDAD SOSPECHOSA EN LOG DURANTE EL SCAN:${N}"
        echo "$INJECT_LOG" | while read -r l; do [ -n "$l" ] && log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_LOG=1
    fi

    ROOT_LOG=$(echo "$LOG_NUEVO" | grep -iE 'su: |granted root|superuser|magisk.*allow|access granted' | grep -viE 'knox' | head -3)
    if [ -n "$ROOT_LOG" ]; then
        log_output "${R}[!] ACTIVIDAD DE ROOT DURANTE EL SCAN:${N}"
        echo "$ROOT_LOG" | while read -r l; do [ -n "$l" ] && log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_LOG=1
    fi

    CRASH_LOG=$(echo "$LOG_NUEVO" | grep -iE "FATAL|force.clos|native crash" | grep -i "${GAME_PKG}" | head -3)
    if [ -n "$CRASH_LOG" ]; then
        log_output "${Y}[!] Crash del juego durante el scan (posible cheat inestable):${N}"
        echo "$CRASH_LOG" | while read -r l; do [ -n "$l" ] && log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT++)); FOUND_LOG=1
    fi

    [ $FOUND_LOG -eq 0 ] && log_output "${G}[✓] Sin eventos sospechosos nuevos en logcat${N}"
    echo ""
}

check_process_delta() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     PROCESOS NUEVOS DURANTE EL SCAN (DELTA)            ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Comparando procesos inicio vs fin del scan...${N}"
    PS_SNAPSHOT_FIN=$(adb shell "ps -A 2>/dev/null" | tr -d '\r')

    PIDS_INICIO=$(echo "$PS_SNAPSHOT_INICIO" | awk '{print $2}' | sort)
    PIDS_FIN=$(echo "$PS_SNAPSHOT_FIN"    | awk '{print $2}' | sort)

    NUEVOS_PIDS=$(comm -13 <(echo "$PIDS_INICIO") <(echo "$PIDS_FIN") 2>/dev/null)
    FOUND_DELTA=0

    if [ -n "$NUEVOS_PIDS" ]; then
        while read -r pid; do
            [ -z "$pid" ] && continue
            PROC_LINE=$(echo "$PS_SNAPSHOT_FIN" | awk -v p="$pid" '$2==p {print}' | head -1)
            PROC_NAME=$(echo "$PROC_LINE" | awk '{print $NF}')
            if echo "$PROC_NAME" | grep -qiE 'frida|hook|cheat|bypass|magisk|xposed|lsposed|shizuku|su$'; then
                log_output "${R}[!] PROCESO SOSPECHOSO APARECIO DURANTE EL SCAN: $PROC_NAME (PID $pid)${N}"
                ((SUSPICIOUS_COUNT+=3)); FOUND_DELTA=1
            fi
        done <<< "$NUEVOS_PIDS"
    fi

    [ $FOUND_DELTA -eq 0 ] && log_output "${G}[✓] Sin procesos sospechosos nuevos durante el scan${N}"
    echo ""
}

monitor_activo() {
    local DURACION_MIN=${1:-8}
    local INTERVALO_SEG=30
    local TOTAL_SEG=$((DURACION_MIN * 60))
    local TRANSCURRIDO=0
    local ALERTAS=0

    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     MONITOREO ACTIVO DEL DISPOSITIVO                  ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    log_output "${B}[*] Observando el dispositivo durante ${DURACION_MIN} minutos...${N}"
    log_output "${B}[*] Intervalo de muestra: ${INTERVALO_SEG} segundos${N}"
    echo ""

    local LOG_MARCA=$(adb shell "logcat -d -b all 2>/dev/null | wc -l" | tr -d '\r')
    local PS_BASE=$(adb shell "ps -A 2>/dev/null" | tr -d '\r')
    local REPLAY_STAT_BASE=$(adb shell "stat '${REPLAY_DIR}' 2>/dev/null" | tr -d '\r')

    local CICLO=0
    while [ $TRANSCURRIDO -lt $TOTAL_SEG ]; do
        sleep $INTERVALO_SEG
        TRANSCURRIDO=$((TRANSCURRIDO + INTERVALO_SEG))
        CICLO=$((CICLO + 1))
        local MIN_REST=$(( (TOTAL_SEG - TRANSCURRIDO) / 60 ))
        local SEG_REST=$(( (TOTAL_SEG - TRANSCURRIDO) % 60 ))
        echo -ne "
${B}[*] Muestra $CICLO — Tiempo restante: ${W}${MIN_REST}m ${SEG_REST}s${N}   "

        local LOG_ACTUAL=$(adb shell "logcat -d -b all 2>/dev/null | wc -l" | tr -d '\r')
        local LOG_NUEVAS=$(( LOG_ACTUAL - LOG_MARCA ))
        if [ "$LOG_NUEVAS" -gt 0 ] 2>/dev/null; then
            local LOG_NUEVAS_CONT=$(adb shell "logcat -d -b all 2>/dev/null | tail -n $LOG_NUEVAS" | tr -d '\r')
            local SUSP_LOG=$(echo "$LOG_NUEVAS_CONT" | grep -iE 'inject|frida|hook|bypass|cheat|su: |access granted|magisk.*allow' | grep -viE 'knox|google|InputDispatcher|injectInputEvent|KeyButtonView|dalvik-internals|hooked signal|hooked sigaction|LogPrintln|Inject motion|Inject key' | head -3)
            if [ -n "$SUSP_LOG" ]; then
                echo ""
                log_output "${R}[!] CICLO $CICLO — ACTIVIDAD SOSPECHOSA EN LOG:${N}"
                echo "$SUSP_LOG" | while read -r l; do [ -n "$l" ] && log_output "${Y}  $l${N}"; done
                ((SUSPICIOUS_COUNT+=3)); ((ALERTAS++))
            fi
            LOG_MARCA=$LOG_ACTUAL
        fi

        local PS_ACTUAL=$(adb shell "ps -A 2>/dev/null" | tr -d '\r')
        local PS_DIFF=$(comm -13             <(echo "$PS_BASE" | awk '{print $NF}' | sort)             <(echo "$PS_ACTUAL" | awk '{print $NF}' | sort) 2>/dev/null)
        local SUSP_PROC=$(echo "$PS_DIFF" | grep -iE 'frida|hook|cheat|bypass|su$|xposed|lsposed|shizuku' | head -3)
        if [ -n "$SUSP_PROC" ]; then
            echo ""
            log_output "${R}[!] CICLO $CICLO — PROCESO SOSPECHOSO APARECIÓ:${N}"
            echo "$SUSP_PROC" | while read -r p; do [ -n "$p" ] && log_output "${Y}  $p${N}"; done
            ((SUSPICIOUS_COUNT+=3)); ((ALERTAS++))
        fi
        PS_BASE="$PS_ACTUAL"

        local REPLAY_STAT_ACT=$(adb shell "stat '${REPLAY_DIR}' 2>/dev/null" | tr -d '\r')
        local RM_ANTES=$(echo "$REPLAY_STAT_BASE" | grep "^Modify:" | head -1)
        local RM_AHORA=$(echo "$REPLAY_STAT_ACT"  | grep "^Modify:" | head -1)
        if [ -n "$RM_ANTES" ] && [ "$RM_ANTES" != "$RM_AHORA" ]; then
            echo ""
            log_output "${R}[!] CICLO $CICLO — CARPETA MREPLAYS MODIFICADA DURANTE MONITOREO:${N}"
            log_output "${Y}    Antes: $RM_ANTES${N}"
            log_output "${Y}    Ahora: $RM_AHORA${N}"
            ((SUSPICIOUS_COUNT+=5)); ((ALERTAS++))
        fi
        REPLAY_STAT_BASE="$REPLAY_STAT_ACT"

        local NET_SUSP=$(adb shell "cat /proc/net/tcp /proc/net/tcp6 2>/dev/null" | awk '{print $3}' |             grep -iE ':0438|:69B2|:69B3|:1F90' | head -3 | tr -d '\r')
        if [ -n "$NET_SUSP" ]; then
            echo ""
            log_output "${R}[!] CICLO $CICLO — CONEXION SOSPECHOSA ACTIVA:${N}"
            echo "$NET_SUSP" | while read -r n; do [ -n "$n" ] && log_output "${Y}  $n${N}"; done
            ((SUSPICIOUS_COUNT+=2)); ((ALERTAS++))
        fi
    done

    echo ""
    echo ""
    if [ $ALERTAS -eq 0 ]; then
        log_output "${G}[✓] Monitoreo completado — sin actividad sospechosa detectada${N}"
    else
        log_output "${R}[!] Monitoreo completado — $ALERTAS alerta(s) detectada(s) durante la observacion${N}"
    fi
    echo ""
}

show_summary() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}              RESUMEN DEL ANÁLISIS                     ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    log_output "${B}[*] Juego: ${W}$GAME_SELECTED${N}"
    log_output "${B}[*] Señales sospechosas: ${W}$SUSPICIOUS_COUNT${N}"
    [ -n "$DEVICE_HWID" ] && log_output "${B}[*] HWID: ${Y}$DEVICE_HWID${N}"
    echo ""

    if [ $SUSPICIOUS_COUNT -eq 0 ]; then
        log_output "${G}╔════════════════════════════════════════════════════════╗${N}"
        log_output "${G}║              ✓ DISPOSITIVO LIMPIO ✓                   ║${N}"
        log_output "${G}╚════════════════════════════════════════════════════════╝${N}"
    elif [ $SUSPICIOUS_COUNT -lt 10 ]; then
        log_output "${Y}╔════════════════════════════════════════════════════════╗${N}"
        log_output "${Y}║       ⚠  REVISAR MANUALMENTE — NO DAR W.O  ⚠          ║${N}"
        log_output "${Y}╚════════════════════════════════════════════════════════╝${N}"
    else
        log_output "${R}╔════════════════════════════════════════════════════════╗${N}"
        log_output "${R}║          ✗ ALTO RIESGO DE CHEATS ✗                    ║${N}"
        log_output "${R}╚════════════════════════════════════════════════════════╝${N}"
    fi

    log_output "\n${M}[*] Log: ${W}$LOGFILE${N}"
}

check_storage
main_menu
