#!/data/data/com.termux/files/usr/bin/bash
R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
B='\033[1;34m'
M='\033[1;35m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

COLS=$(tput cols 2>/dev/null); [[ ! "$COLS" =~ ^[0-9]+$ ]] && COLS=60
[ "$COLS" -gt 66 ] && COLS=66; [ "$COLS" -lt 44 ] && COLS=44

_hl() { local n=$1 c="${2:-─}" s="" i; for((i=0;i<n;i++)); do s+="$c"; done; printf '%s' "$s"; }
_sp() { printf "%${1}s" ""; }
_bc() { local t="$1" inner="$2" tl=${#1} lp rp
    lp=$(( (inner-tl)/2 )); rp=$(( inner-tl-lp ))
    [ $lp -lt 0 ] && lp=0; [ $rp -lt 0 ] && rp=0
    printf '%s%s%s' "$(_sp $lp)" "$t" "$(_sp $rp)"; }

sec_hdr() {
    local t="$1" inner=$(( COLS-2 ))
    local pad=$(( inner-2-${#t} )); [ $pad -lt 0 ] && pad=0
    log_output "${C}┌$(_hl $inner)┐${N}"
    log_output "${C}│ ${W}${t}$(_sp $pad) ${C}│${N}"
    log_output "${C}└$(_hl $inner)┘${N}"
}

echo_hdr() {
    local t="$1" col="${2:-$B}" inner=$(( COLS-2 ))
    local pad=$(( inner-2-${#t} )); [ $pad -lt 0 ] && pad=0
    echo -e "${col}┌$(_hl $inner)┐${N}"
    echo -e "${col}│ ${W}${t}$(_sp $pad) ${col}│${N}"
    echo -e "${col}└$(_hl $inner)┘${N}"
}

verdict_box() {
    local col="$1" t="$2" inner=$(( COLS-2 ))
    local lp=$(( (inner-${#t})/2 )) rp
    rp=$(( inner-${#t}-lp ))
    [ $lp -lt 0 ] && lp=0; [ $rp -lt 0 ] && rp=0
    log_output "${col}╔$(_hl $inner ═)╗${N}"
    log_output "${col}║$(_sp $lp)${t}$(_sp $rp)║${N}"
    log_output "${col}╚$(_hl $inner ═)╝${N}"
}

BACKEND_URL="https://unknown-scanner-backend-v1-0.onrender.com"
STATS_FILE="$HOME/.unknown_scanner_uses"
KEY_FILE="$HOME/.unknown_premium_key"     # cache local de la key premium

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
        -d '{"version":"1.5.0"}' &>/dev/null &
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
        echo -e "${R}$(_hl $COLS ═)${N}"
        echo -e "${R}$(_bc "DISPOSITIVO BLOQUEADO DEL SCANNER" $COLS)${N}"
        echo -e "${R}$(_hl $COLS ═)${N}"
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
    local inner=$(( COLS - 2 ))
    local _l _g

    _l=$(cat "$STATS_FILE" 2>/dev/null || echo "0")
    _g=$(curl -sf --max-time 3 "${BACKEND_URL}/api/stats/scan" 2>/dev/null \
         | grep -o '"total":[0-9]*' | grep -o '[0-9]*' || echo "?")

    printf "%b\n" "${C}╔$(_hl $inner ═)╗${N}"
    printf "%b\n" "${C}║${M}$(_bc "CODE BY TIZI.XIT  ·  ANTI-CHEAT SYSTEM" $inner)${C}║${N}"
    printf "%b\n" "${C}║${W}$(_bc "UNKNOWN SCANNER  —  v1.5.0" $inner)${C}║${N}"
    printf "%b\n" "${C}║${G}$(_bc "Globales: ${_g}   Dispositivo: ${_l}" $inner)${C}║${N}"
    printf "%b\n" "${C}╚$(_hl $inner ═)╝${N}"
    echo ""
    printf "%b\n" "${Y}┌$(_hl $inner)┐${N}"
    printf "%b\n" "${Y}│${N}$(_bc "[!] EN DESARROLLO — SIEMPRE REVISAR MANUALMENTE" $inner)${Y}│${N}"
    printf "%b\n" "${Y}└$(_hl $inner)┘${N}"
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
    echo_hdr "MENÚ PRINCIPAL" "$B"
    echo ""
    echo -e "${Y}[0]${W} Conectar ADB (Pareamiento inalámbrico)${N}"
    echo -e "${G}[1]${W} Escanear Free Fire Normal${N}"
    echo -e "${G}[2]${W} Escanear Free Fire MAX${N}"
    echo -e "${C}[3]${W} Ver último log guardado${N}"
    echo -e "${B}[4]${W} Guardar diagnóstico completo (Dumpsys)${N}"
    echo -e "${M}[5]${W} Actualizar scanner${N}"
    echo -e "${M}[6]${W} Análisis Premium — BugReport ${M}(KERNEL LEVEL)${N}"
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
        6) bugreport_menu ;;
        s|S) echo -e "\n${W}Gracias por usar el scanner${N}\n"; exit 0 ;;
        *) echo -e "${R}Opción inválida${N}"; sleep 2; main_menu ;;
    esac
}

_validate_key() {
    local key="$1"
    [ -z "$key" ] && return 1

    if ! echo "$key" | grep -qE '^UNKN-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$'; then
        return 1
    fi

    local RESP
    RESP=$(curl -sf --max-time 8 \
        -X POST "${BACKEND_URL}/api/premium/validate" \
        -H "Content-Type: application/json" \
        -d "{\"key\":\"$key\",\"hwid\":\"${DEVICE_HWID:-unknown}\"}" 2>/dev/null)

    if [ -z "$RESP" ]; then return 2; fi             # sin respuesta = sin internet
    if echo "$RESP" | grep -q '"valid":true'; then return 0; fi
    return 1
}

_key_cached_ok() {
    [ ! -f "$KEY_FILE" ] && return 1

    local STORED_KEY STORED_HWID STORED_TS NOW
    STORED_KEY=$(sed -n '1p' "$KEY_FILE" | tr -d '\r\n')
    STORED_HWID=$(sed -n '2p' "$KEY_FILE" | tr -d '\r\n')
    STORED_TS=$(sed -n '3p'  "$KEY_FILE" | tr -d '\r\n')
    NOW=$(date +%s)

    [ "$STORED_HWID" != "${DEVICE_HWID:-unknown}" ] && { rm -f "$KEY_FILE"; return 1; }

    if [ $(( NOW - STORED_TS )) -gt 604800 ]; then
        _validate_key "$STORED_KEY"
        local RES=$?
        if [ $RES -eq 0 ]; then
            printf '%s\n%s\n%s\n' "$STORED_KEY" "${DEVICE_HWID:-unknown}" "$NOW" > "$KEY_FILE"
            return 0
        elif [ $RES -eq 2 ]; then
            log_output "${Y}[!] Sin conexión para re-validar key — acceso temporal por cache.${N}"
            return 0
        else
            rm -f "$KEY_FILE"; return 1
        fi
    fi

    return 0   # cache vigente
}

_save_key() {
    local key="$1"
    printf '%s\n%s\n%s\n' "$key" "${DEVICE_HWID:-unknown}" "$(date +%s)" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
}

check_premium_key() {
    _key_cached_ok && return 0

    clear; banner
    echo_hdr "UNKNOWN PREMIUM — ACCESO REQUERIDO" "$M"
    echo ""
    echo -e "${M}  Esta función es exclusiva para usuarios con licencia Premium.${N}"
    echo ""
    echo -e "${W}  Formato de key:  ${C}UNKN-XXXX-XXXX-XXXX${N}"
    echo ""
    echo -ne "${Y}  Ingresá tu key: ${N}"
    read -r INPUT_KEY
    INPUT_KEY=$(echo "$INPUT_KEY" | tr -d ' \t\r' | tr '[:lower:]' '[:upper:]')

    echo ""
    echo -e "${B}[*] Validando key...${N}"

    _validate_key "$INPUT_KEY"
    local RES=$?

    case $RES in
        0)
            _save_key "$INPUT_KEY"
            echo -e "${G}[✓] Key válida. Bienvenido a UNKNOWN Premium.${N}"
            sleep 1; return 0
            ;;
        2)
            echo -e "${R}[!] Sin conexión a internet. Verificá tu red e intentá de nuevo.${N}"
            sleep 2; return 1
            ;;
        *)
            echo -e "${R}[!] Key inválida o expirada.${N}"
            echo -e "${W}    Contactá al equipo UNKNOWN para obtener tu licencia.${N}"
            sleep 2; return 1
            ;;
    esac
}

BR_DIR=""
BR_TXT=""

_br_sec() {
    local pattern="$1"
    # Intenta el separador estándar (------ NOMBRE ------) con variantes de Android
    local result
    result=$(awk "
        /^-{2,} ${pattern}/{ found=1; next }
        found && /^-{6,}[[:space:]]/ && !/^-{2,} ${pattern}/{ exit }
        found{ print }
    " "$BR_TXT" 2>/dev/null)
    # Fallback: búsqueda más laxa ignorando mayúsculas
    if [ -z "$result" ]; then
        result=$(awk -v pat="${pattern}" '
            BEGIN{ IGNORECASE=1 }
            $0 ~ ("^------.*" pat){ found=1; next }
            found && /^------[^-]/ && $0 !~ ("^------.*" pat){ exit }
            found{ print }
        ' "$BR_TXT" 2>/dev/null)
    fi
    printf '%s' "$result"
}

br_check_props() {
    sec_hdr "PROPIEDADES DEL SISTEMA (NIVEL KERNEL)"
    local FOUND=0

    local PROPS
    PROPS=$(_br_sec "SYSTEM PROPERTIES")
    [ -z "$PROPS" ] && { log_output "${Y}[*] Sección SYSTEM PROPERTIES no encontrada${N}"; echo ""; return; }

    local BOOT
    BOOT=$(echo "$PROPS" | grep "ro.boot.verifiedbootstate" | grep -o '=.*' | tr -d '=')
    log_output "${B}[*] Boot state: ${W}${BOOT:-desconocido}${N}"
    [ "$BOOT" != "green" ] && { log_output "${Y}[!] Boot state no es GREEN${N}"; ((SUSPICIOUS_COUNT++)); FOUND=1; }

    local FLASH
    FLASH=$(echo "$PROPS" | grep "ro.boot.flash.locked" | grep -o '=.*' | tr -d '=')
    if [ "$FLASH" = "0" ]; then
        log_output "${R}[!] BOOTLOADER DESBLOQUEADO${N}"
        ((SUSPICIOUS_COUNT+=2)); FOUND=1
    fi

    local KVER SPL
    KVER=$(echo "$PROPS" | grep "^ro.kernel.version" | head -1)
    SPL=$(echo "$PROPS"  | grep "ro.build.version.security_patch" | head -1)
    [ -n "$KVER" ] && log_output "${B}[*] ${W}$KVER${N}"
    [ -n "$SPL"  ] && log_output "${B}[*] ${W}$SPL${N}"

    local ROOT_PROPS
    ROOT_PROPS=$(echo "$PROPS" | grep -iE "magisk|kernelsu|apatch|shamiko|zygisk|susfs")
    if [ -n "$ROOT_PROPS" ]; then
        log_output "${R}[!] Propiedades de root detectadas:${N}"
        echo "$ROOT_PROPS" | head -6 | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND=1
    fi

    local SPOOF
    SPOOF=$(echo "$PROPS" | grep -iE "^persist\.pif\.|^ro\..*spoof")
    if [ -n "$SPOOF" ]; then
        log_output "${R}[!] Play Integrity Fix / spoofing detectado:${N}"
        echo "$SPOOF" | head -4 | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=2)); FOUND=1
    fi

    [ $FOUND -eq 0 ] && log_output "${G}[✓] Propiedades sin anomalías${N}"
    echo ""
}

br_check_kernel() {
    sec_hdr "KERNEL — DMESG / MENSAJES DE KERNEL"
    local FOUND=0

    local DMESG
    DMESG=$(_br_sec "KERNEL LOG")
    if [ -z "$DMESG" ]; then
        log_output "${Y}[*] Sección KERNEL LOG no encontrada${N}"; echo ""; return
    fi

    local SUSFS_LOG
    SUSFS_LOG=$(echo "$DMESG" | grep -i "susfs")
    if [ -n "$SUSFS_LOG" ]; then
        log_output "${R}[!] SUSFS detectado en dmesg (bypass de kernel):${N}"
        echo "$SUSFS_LOG" | head -5 | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=4)); FOUND=1
    fi

    local KSU_LOG
    KSU_LOG=$(echo "$DMESG" | grep -iE "\[ksu\]|kernelsu:")
    if [ -n "$KSU_LOG" ]; then
        log_output "${R}[!] KernelSU en dmesg:${N}"
        echo "$KSU_LOG" | head -5 | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=4)); FOUND=1
    fi

    local APATCH_LOG
    APATCH_LOG=$(echo "$DMESG" | grep -i "apatch")
    if [ -n "$APATCH_LOG" ]; then
        log_output "${R}[!] APatch en dmesg:${N}"
        echo "$APATCH_LOG" | head -3 | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=4)); FOUND=1
    fi

    local MAGISK_LOG
    MAGISK_LOG=$(echo "$DMESG" | grep -i "magisk")
    if [ -n "$MAGISK_LOG" ]; then
        log_output "${R}[!] Magisk en dmesg:${N}"
        echo "$MAGISK_LOG" | head -3 | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND=1
    fi

    local INSMOD
    INSMOD=$(echo "$DMESG" | grep -iE "insmod|module.*loaded|loading.*module" | grep -viE "wlan|wifi|bluetooth|nfc")
    if [ -n "$INSMOD" ]; then
        log_output "${Y}[!] Carga de módulos de kernel detectada:${N}"
        echo "$INSMOD" | head -5 | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=2)); FOUND=1
    fi

    [ $FOUND -eq 0 ] && log_output "${G}[✓] Sin anomalías en dmesg${N}"
    echo ""
}

br_check_modules() {
    sec_hdr "MÓDULOS DEL KERNEL (/proc/modules)"
    local FOUND=0

    local MODULES_FILE="$BR_DIR/FS/proc/modules"
    local MODULES=""
    if [ -f "$MODULES_FILE" ]; then
        MODULES=$(cat "$MODULES_FILE")
    else
        MODULES=$(_br_sec "LSMOD")
    fi

    if [ -z "$MODULES" ]; then
        log_output "${Y}[*] /proc/modules no disponible en este bugreport${N}"; echo ""; return
    fi

    local SUSP_MOD
    SUSP_MOD=$(echo "$MODULES" | grep -iE "susfs|frida|xposed|zygisk|magisk|ksu_mod|apatch")
    if [ -n "$SUSP_MOD" ]; then
        log_output "${R}[!] MÓDULOS SOSPECHOSOS CARGADOS EN KERNEL:${N}"
        echo "$SUSP_MOD" | while read -r l; do log_output "${R}  ► $l${N}"; done
        ((SUSPICIOUS_COUNT+=5)); FOUND=1
    fi

    local TOTAL_MODS
    TOTAL_MODS=$(echo "$MODULES" | grep -c "^" 2>/dev/null || echo "0")
    log_output "${B}[*] Total de módulos cargados: ${W}$TOTAL_MODS${N}"

    [ $FOUND -eq 0 ] && log_output "${G}[✓] Sin módulos sospechosos${N}"
    echo ""
}

br_check_selinux() {
    sec_hdr "SELinux — AUDITORÍA DE ACCESO"
    local FOUND=0

    local SYSLOG
    SYSLOG=$(_br_sec "SYSTEM LOG" | grep -iE "avc.*denied|avc.*granted" | head -100)

    local BYPASS_AVC
    BYPASS_AVC=$(echo "$SYSLOG" | grep -iE "magisk|ksu|zygisk|susfs|frida|xposed|apatch")
    if [ -n "$BYPASS_AVC" ]; then
        log_output "${R}[!] SELinux AVC con actividad de bypass de root:${N}"
        echo "$BYPASS_AVC" | head -5 | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND=1
    fi

    local ENFORCE
    ENFORCE=$(_br_sec "SYSTEM PROPERTIES" | grep "selinux.enforce" | grep -o '=.*' | tr -d '=')
    if [ "$ENFORCE" = "0" ]; then
        log_output "${R}[!] SELinux en modo PERMISSIVE — root o kernel modificado${N}"
        ((SUSPICIOUS_COUNT+=3)); FOUND=1
    elif [ -n "$ENFORCE" ]; then
        log_output "${G}[✓] SELinux: enforce=1${N}"
    fi

    local DENIAL_COUNT
    DENIAL_COUNT=$(echo "$SYSLOG" | grep -c "avc.*denied" 2>/dev/null || echo "0")
    log_output "${B}[*] Total AVC denied en log: ${W}$DENIAL_COUNT${N}"

    [ $FOUND -eq 0 ] && log_output "${G}[✓] SELinux sin anomalías significativas${N}"
    echo ""
}

br_check_maps() {
    sec_hdr "MAPAS DE MEMORIA — PROCESO DEL JUEGO"
    local FOUND=0

    local GAME_PID_BR=""
    if [ -d "$BR_DIR/FS/proc" ]; then
        GAME_PID_BR=$(grep -rl "$GAME_PKG" "$BR_DIR/FS/proc" 2>/dev/null | \
            grep "/cmdline" | grep -oP '(?<=/proc/)\d+' | head -1)
    fi

    if [ -z "$GAME_PID_BR" ]; then
        log_output "${Y}[*] Proceso del juego no capturado en snapshot${N}"
        log_output "${Y}    (el juego no estaba activo cuando se generó el bugreport)${N}"
        echo ""; return
    fi

    log_output "${B}[*] PID del juego en snapshot: ${W}$GAME_PID_BR${N}"
    local MAPS_FILE="$BR_DIR/FS/proc/$GAME_PID_BR/maps"
    if [ ! -f "$MAPS_FILE" ]; then
        log_output "${Y}[*] /proc/$GAME_PID_BR/maps no disponible${N}"; echo ""; return
    fi

    local FRIDA_MAP
    FRIDA_MAP=$(grep -iE "frida|gadget" "$MAPS_FILE" 2>/dev/null)
    if [ -n "$FRIDA_MAP" ]; then
        log_output "${R}[!] FRIDA GADGET en mapas de memoria:${N}"
        echo "$FRIDA_MAP" | head -5 | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=5)); FOUND=1
    fi

    local HOOK_MAP
    HOOK_MAP=$(grep -iE "xposed|zygisk|lsposed|inject|riru" "$MAPS_FILE" 2>/dev/null)
    if [ -n "$HOOK_MAP" ]; then
        log_output "${R}[!] Librería de hook en mapas:${N}"
        echo "$HOOK_MAP" | head -5 | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=5)); FOUND=1
    fi

    local ANON_EXEC
    ANON_EXEC=$(grep "r-xp\|rwxp" "$MAPS_FILE" 2>/dev/null | \
        grep -vE "\.so|\.apk|\.dex|\.oat|\.art|vdex|odex|boot\.oat|\[" | \
        grep -v " 00:00 0 $" | head -10)
    if [ -n "$ANON_EXEC" ]; then
        log_output "${R}[!] Regiones ejecutables anónimas (posible inyección de código):${N}"
        echo "$ANON_EXEC" | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND=1
    fi

    [ $FOUND -eq 0 ] && log_output "${G}[✓] Mapas de memoria sin anomalías${N}"
    echo ""
}

br_check_tombstones() {
    sec_hdr "TOMBSTONES — CRASHES NATIVOS"
    local FOUND=0

    local TOMB_DIR="$BR_DIR/FS/data/tombstones"
    if [ -d "$TOMB_DIR" ]; then
        for tomb in "$TOMB_DIR"/tombstone_*; do
            [ -f "$tomb" ] || continue
            local SUSP
            # Patrones con límites de palabra para evitar falsos positivos:
            # - "xposed" con  para no matchear "exposed"
            # - "inject" solo como librería/path de cheat, no JS engines
            # - "cheat" solo si no viene precedido de "anti"
            # Whitelist: TikTok (spark_js_inject), ByteDance AB (__ab_local_exposed),
            #            Termux/AntiCheat (propio scanner), apps lemon/lv
            SUSP=$(grep -iE                 "frida.gadget|frida.agent|/frida[^a-z]|frida|libgadget\.so|xposed|lsposed|zygisk|magisk|/data/adb/|libhook\.so|libinject\.so|substrate|de\.robv\.android"                 "$tomb" 2>/dev/null                 | grep -viE "AntiCheat|anti.cheat|spark_js_inject|__ab_local|com\.termux|com\.lemon\.lv|zhiliaoapp\.musically|lvoverseas"                 | head -3)
            if [ -n "$SUSP" ]; then
                log_output "${R}[!] Crash sospechoso: $(basename "$tomb")${N}"
                echo "$SUSP" | while read -r l; do log_output "${Y}  $l${N}"; done
                ((SUSPICIOUS_COUNT+=3)); FOUND=1
            fi
        done
    else
        local TOMB_SEC
        TOMB_SEC=$(_br_sec "TOMBSTONE")
        if [ -n "$TOMB_SEC" ]; then
            local SUSP
            SUSP=$(echo "$TOMB_SEC" | grep -iE                 "frida.gadget|frida.agent|/frida[^a-z]|frida|libgadget\.so|xposed|lsposed|zygisk|magisk|/data/adb/|libhook\.so|libinject\.so|substrate|de\.robv\.android"                 | grep -viE "AntiCheat|anti.cheat|spark_js_inject|__ab_local|com\.termux|com\.lemon\.lv|zhiliaoapp\.musically|lvoverseas"                 | head -5)
            if [ -n "$SUSP" ]; then
                log_output "${R}[!] Strings sospechosas en tombstones:${N}"
                echo "$SUSP" | while read -r l; do log_output "${Y}  $l${N}"; done
                ((SUSPICIOUS_COUNT+=3)); FOUND=1
            fi
        fi
    fi

    [ $FOUND -eq 0 ] && log_output "${G}[✓] Sin crashes nativos sospechosos${N}"
    echo ""
}

br_check_network() {
    sec_hdr "CONEXIONES DE RED — SNAPSHOT KERNEL"
    local FOUND=0

    for tcp_f in "$BR_DIR/FS/proc/net/tcp" "$BR_DIR/FS/proc/net/tcp6"; do
        [ ! -f "$tcp_f" ] && continue
        local SUSP
        SUSP=$(grep -iE " (0016|0015|0438|1F90|1F91|21FB|21FC):" "$tcp_f" | grep " 01 " | head -5)
        if [ -n "$SUSP" ]; then
            log_output "${R}[!] Conexiones sospechosas en $(basename "$tcp_f"):${N}"
            echo "$SUSP" | while read -r l; do log_output "${Y}  $l${N}"; done
            ((SUSPICIOUS_COUNT+=2)); FOUND=1
        fi
    done

    local VPN
    VPN=$(_br_sec "SYSTEM LOG" | grep -iE "vpn.*connected|tun0|tun1" | tail -5)
    if [ -n "$VPN" ]; then
        log_output "${Y}[!] Actividad de VPN detectada en logs:${N}"
        echo "$VPN" | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT++)); FOUND=1
    fi

    [ $FOUND -eq 0 ] && log_output "${G}[✓] Sin conexiones sospechosas en snapshot${N}"
    echo ""
}

br_check_anr() {
    sec_hdr "TRAZAS ANR — HILOS DEL PROCESO"
    local FOUND=0

    local ANR_DIR="$BR_DIR/FS/data/anr"
    if [ -d "$ANR_DIR" ]; then
        for anr_f in "$ANR_DIR"/traces*; do
            [ -f "$anr_f" ] || continue
            local SUSP
            SUSP=$(grep -iE "frida|inject|hook|zygisk|xposed" "$anr_f" 2>/dev/null | head -3)
            if [ -n "$SUSP" ]; then
                log_output "${R}[!] Traza ANR sospechosa: $(basename "$anr_f")${N}"
                echo "$SUSP" | while read -r l; do log_output "${Y}  $l${N}"; done
                ((SUSPICIOUS_COUNT+=2)); FOUND=1
            fi
        done
    else
        local ANR_SEC
        ANR_SEC=$(_br_sec "VM TRACES")
        if [ -n "$ANR_SEC" ]; then
            local SUSP
            SUSP=$(echo "$ANR_SEC" | grep -iE "frida|inject|hook|zygisk" | head -5)
            if [ -n "$SUSP" ]; then
                log_output "${R}[!] Strings sospechosas en VM traces:${N}"
                echo "$SUSP" | while read -r l; do log_output "${Y}  $l${N}"; done
                ((SUSPICIOUS_COUNT+=2)); FOUND=1
            fi
        fi
    fi

    [ $FOUND -eq 0 ] && log_output "${G}[✓] Sin anomalías en trazas de proceso${N}"
    echo ""
}

br_check_game_logcat() {
    sec_hdr "LOGCAT DEL JUEGO — ACTIVIDAD SOSPECHOSA"
    local FOUND=0

    local SYSLOG
    SYSLOG=$(_br_sec "SYSTEM LOG")

    local FRIDA_LOG
    FRIDA_LOG=$(echo "$SYSLOG" | grep -iE "frida|xposed|substrate|lsposed" | head -5)
    if [ -n "$FRIDA_LOG" ]; then
        log_output "${R}[!] Framework de hook detectado en logcat:${N}"
        echo "$FRIDA_LOG" | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=4)); FOUND=1
    fi

    local FAKETIME
    FAKETIME=$(echo "$SYSLOG" | grep -iE "clockwork|fake.*time|time.*inject|timeshift" | head -5)
    if [ -n "$FAKETIME" ]; then
        log_output "${R}[!] Indicador de tiempo falso en logcat:${N}"
        echo "$FAKETIME" | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND=1
    fi

    local OVERLAY
    OVERLAY=$(echo "$SYSLOG" | grep -iE "overlay.*$GAME_PKG|shader.*inject" | head -5)
    if [ -n "$OVERLAY" ]; then
        log_output "${R}[!] Actividad de overlay en logcat del juego:${N}"
        echo "$OVERLAY" | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND=1
    fi

    [ $FOUND -eq 0 ] && log_output "${G}[✓] Logcat del juego sin actividad sospechosa${N}"
    echo ""
}

_br_run_analysis() {
    local ZIP_PATH="$1"

    BR_DIR=$(mktemp -d "${TMPDIR}/unknown_br_XXXXXX")

    # ── Archivo suelto (.txt) — no necesita extracción ───────────────────────
    if [[ "$ZIP_PATH" == *.txt ]]; then
        log_output "${B}[*] Analizando archivo suelto...${N}"
        if [ ! -s "$ZIP_PATH" ]; then
            log_output "${R}[!] Archivo vacio o inaccesible.${N}"
            rm -rf "$BR_DIR"; sleep 2; bugreport_menu; return
        fi
        BR_TXT="$ZIP_PATH"

    # ── ZIP — extraer primero ─────────────────────────────────────────────────
    else
        log_output "${B}[*] Extrayendo bugreport...${N}"
        if ! unzip -q "$ZIP_PATH" -d "$BR_DIR" 2>/dev/null; then
            log_output "${R}[!] Error al extraer el zip. ¿Es un bugreport válido?${N}"
            rm -rf "$BR_DIR"; sleep 2; bugreport_menu; return
        fi
        BR_TXT=$(find "$BR_DIR" -maxdepth 4 -name "bugreport*.txt" ! -path "*/FS/*" 2>/dev/null | head -1)
        if [ -z "$BR_TXT" ]; then
            BR_TXT=$(find "$BR_DIR" -maxdepth 4 -name "*.txt" ! -path "*/FS/*" 2>/dev/null \
                -exec du -b {} + | sort -rn | head -1 | cut -f2-)
        fi
        if [ -z "$BR_TXT" ]; then
            log_output "${R}[!] No se encontro el archivo de reporte en el zip.${N}"
            log_output "${Y}[*] Contenido del zip:${N}"
            unzip -l "$ZIP_PATH" 2>/dev/null | head -20 | while read -r l; do log_output "${W}    $l${N}"; done
            rm -rf "$BR_DIR"; sleep 4; bugreport_menu; return
        fi
    fi

    clear; banner
    LOGFILE="$HOME/br_analysis_$(date +%Y%m%d_%H%M%S).txt"
    SUSPICIOUS_COUNT=0

    log_output "${M}════ UNKNOWN PREMIUM — BUGREPORT ANALYZER ════${N}"
    log_output "${W}[*] Archivo:  $(basename "$ZIP_PATH")${N}"
    log_output "${W}[*] Análisis: $(date)${N}"

    if grep -q "com.dts.freefireth" "$BR_TXT" 2>/dev/null; then
        GAME_PKG="com.dts.freefireth"; GAME_SELECTED="Free Fire"
    elif grep -q "com.dts.freefiremax" "$BR_TXT" 2>/dev/null; then
        GAME_PKG="com.dts.freefiremax"; GAME_SELECTED="Free Fire MAX"
    else
        GAME_PKG="com.dts.freefireth"; GAME_SELECTED="Free Fire (no confirmado)"
    fi
    log_output "${B}[*] Juego: ${W}$GAME_SELECTED${N}\n"

    br_check_props
    br_check_kernel
    br_check_modules
    br_check_selinux
    br_check_network
    br_check_maps
    br_check_tombstones
    br_check_anr
    br_check_game_logcat

    show_summary

    rm -rf "$BR_DIR"; BR_DIR=""; BR_TXT=""

    log_output "${W}[*] Log guardado en: ${C}$LOGFILE${N}"
    echo ""
    echo -e "${W}  Presioná [ENTER] para volver al menú.${N}"
    read -r
    main_menu
}

# Variable global — evita el subshell que silencia el menú
BR_SELECTED_FILE=""

# Recolecta bugreports de Descargas (deduplica por nombre de archivo)
_br_scan_downloads() {
    local -A seen=()
    local -a result=()
    while IFS= read -r f; do
        local name
        name=$(basename "$f")
        if [ -z "${seen[$name]}" ]; then
            seen[$name]=1
            result+=("$f")
        fi
    done < <(find \
        /sdcard/Download \
        /sdcard/Downloads \
        /storage/emulated/0/Download \
        /storage/emulated/0/Downloads \
        -maxdepth 1 \
        \( -name "bugreport*.zip" -o -name "bug_report*.zip" \
           -o -name "dumpstate*.txt" -o -name "bugreport*.txt" \) \
        2>/dev/null | sort -r | head -15)
    printf '%s\n' "${result[@]}"
}

# Lista bugreports desde la carpeta interna de Android via ADB
_br_scan_adb() {
    local ADB_BR_DIR="/data/user_de/0/com.android.shell/files/bugreports"
    adb shell "ls -1 ${ADB_BR_DIR}/ 2>/dev/null" 2>/dev/null \
        | tr -d '\r' | grep -E '\.(zip|txt)$' | sort -r | head -10
}

_br_pick_file() {
    BR_SELECTED_FILE=""
    clear; banner
    echo_hdr "SELECCIONAR BUGREPORT" "$M"

    local -a DL_FILES=()
    while IFS= read -r f; do [ -n "$f" ] && DL_FILES+=("$f"); done \
        < <(_br_scan_downloads)

    local -a ADB_FILES=()
    local ADB_BR_DIR="/data/user_de/0/com.android.shell/files/bugreports"
    if adb devices 2>/dev/null | grep -q "device$"; then
        while IFS= read -r f; do [ -n "$f" ] && ADB_FILES+=("$f"); done \
            < <(_br_scan_adb)
    fi

    local -a ALL_LABELS=()
    local -a ALL_TYPES=()
    local -a ALL_PATHS=()

    if [ ${#DL_FILES[@]} -gt 0 ]; then
        echo -e "${C}  Descargas:${N}"
        echo ""
        for f in "${DL_FILES[@]}"; do
            local SIZE DATE_STR idx
            SIZE=$(du -sh "$f" 2>/dev/null | cut -f1)
            DATE_STR=$(date -r "$f" "+%d/%m/%Y %H:%M" 2>/dev/null)
            idx=$(( ${#ALL_LABELS[@]} + 1 ))
            local FTYPE=""
            [[ "$f" == *.zip ]] && FTYPE="${G}[ZIP]${N}" || FTYPE="${Y}[TXT]${N}"
            echo -e "${Y}  [$idx] ${FTYPE}${W} $(basename "$f")${N}"
            echo -e "      ${B}${SIZE}   ${DATE_STR}${N}"
            echo ""
            ALL_LABELS+=("$(basename "$f")")
            ALL_TYPES+=("dl")
            ALL_PATHS+=("$f")
        done
    fi

    # Solo mostrar seccion ADB si tiene archivos nuevos (no duplicados)
    local adb_shown=0
    for name in "${ADB_FILES[@]}"; do
        local already=0
        for lbl in "${ALL_LABELS[@]}"; do
            [ "$lbl" = "$name" ] && { already=1; break; }
        done
        [ $already -eq 1 ] && continue
        if [ $adb_shown -eq 0 ]; then
            echo -e "${M}  Informes del sistema:${N}"
            echo ""
            adb_shown=1
        fi
        local idx=$(( ${#ALL_LABELS[@]} + 1 ))
        echo -e "${Y}  [$idx]${M} $name${N}"
        echo -e "      ${B}(se copiara a Descargas al analizarlo)${N}"
        echo ""
        ALL_LABELS+=("$name")
        ALL_TYPES+=("adb")
        ALL_PATHS+=("$name")
    done

    local total=${#ALL_LABELS[@]}

    if [ $total -eq 0 ]; then
        echo -e "${Y}  [!] No se encontraron bugreports.${N}"
        echo -e "${W}      Generalo desde Ajustes -> Opciones de desarrollador${N}"
        echo -e "${W}      -> Informe de errores -> Informe completo.${N}"
        echo ""
    fi

    echo -e "${C}  [B]${W} Buscar por nombre de archivo${N}"
    echo -e "${R}  [V]${W} Volver${N}"
    echo ""
    [ $total -gt 0 ] && echo -ne "${Y}  Opcion (1-${total} / B / V): ${N}" \
                      || echo -ne "${Y}  Opcion (B / V): ${N}"
    read -r SEL

    case "${SEL^^}" in
        V) return 1 ;;
        B)
            echo -ne "${Y}  Nombre del archivo (ej: bugreport-...-2026.zip): ${N}"
            read -r INPUT
            INPUT=$(echo "$INPUT" | tr -d "'\"\r")
            # Si es ruta absoluta, usarla directo
            if [[ "$INPUT" == /* ]] && [ -f "$INPUT" ] && [ -s "$INPUT" ]; then
                BR_SELECTED_FILE="$INPUT"
                return 0
            fi
            # Si es solo nombre, buscar en Descargas
            local FNAME
            FNAME=$(basename "$INPUT")
            for dir in /sdcard/Download /sdcard/Downloads /storage/emulated/0/Download /storage/emulated/0/Downloads; do
                local candidate="${dir}/${FNAME}"
                if [ -f "$candidate" ] && [ -s "$candidate" ]; then
                    BR_SELECTED_FILE="$candidate"
                    echo -e "${G}  [✓] Encontrado en $(dirname "$candidate")${N}"
                    sleep 1
                    return 0
                fi
            done
            echo -e "${R}  [!] No se encontro '${FNAME}' en Descargas.${N}"
            return 1
            ;;
        *)
            if [[ "$SEL" =~ ^[0-9]+$ ]] && [ "$SEL" -ge 1 ] && [ "$SEL" -le "$total" ]; then
                local idx=$(( SEL - 1 ))
                local tipo="${ALL_TYPES[$idx]}"
                local path="${ALL_PATHS[$idx]}"
                if [ "$tipo" = "dl" ]; then
                    BR_SELECTED_FILE="$path"
                    return 0
                else
                    local DEST="/sdcard/Download/${path}"
                    echo -e "${B}  [*] Copiando desde carpeta del sistema...${N}"
                    if adb pull "${ADB_BR_DIR}/${path}" "$DEST" 2>/dev/null; then
                        echo -e "${G}  [✓] Copiado a Descargas.${N}"
                        sleep 1
                        BR_SELECTED_FILE="$DEST"
                        return 0
                    else
                        echo -e "${R}  [!] Error al copiar. Compartilo manualmente a Descargas.${N}"
                        return 1
                    fi
                fi
            fi
            echo -e "${R}  [!] Opcion invalida.${N}"
            return 1
            ;;
    esac
}

bugreport_menu() {
    check_premium_key || { main_menu; return; }
    clear; banner
    echo_hdr "UNKNOWN PREMIUM — BUGREPORT ANALYZER" "$M"
    echo ""
    echo -e "${M}  Análisis a nivel de kernel — dmesg, /proc/modules, mapas de memoria.${N}"
    echo -e "${W}  Detecta root, hooks e inyecciones que los bypass tools no pueden ocultar.${N}"
    echo ""
    echo -e "${C}  Cómo obtener el bugreport del jugador:${N}"
    echo -e "${W}  1. Ajustes → Opciones de desarrollador → Informe de errores${N}"
    echo -e "${W}  2. Seleccionar 'Informe completo' y tocar 'Notificar'${N}"
    echo -e "${W}  3. Esperar la notificación (1-3 minutos)${N}"
    echo -e "${W}  4. Compartir el .zip al SS (Drive, Telegram, etc.) y descargarlo${N}"
    echo ""
    echo -e "${Y}$(_hl $COLS ─)${N}"
    echo ""
    echo -e "${Y}[S]${W} Seleccionar bugreport (.zip) de Descargas${N}"
    echo -e "${R}[V]${W} Volver al menú${N}"
    echo ""
    echo -ne "${Y}  Opción: ${N}"
    read -r _br_opc

    case "${_br_opc^^}" in
        S)
            echo ""
            _br_pick_file
            if [ $? -ne 0 ] || [ -z "$BR_SELECTED_FILE" ]; then
                sleep 2; bugreport_menu; return
            fi
            echo -e "${G}[✓] Archivo: ${W}$(basename "$BR_SELECTED_FILE")${N}"
            sleep 1
            _br_run_analysis "$BR_SELECTED_FILE"
            ;;
        V|*) main_menu ;;
    esac
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
    echo_hdr "GUARDAR DIAGNÓSTICO COMPLETO" "$B"

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
    echo_hdr "INSTRUCCIONES PARA CONECTAR ADB" "$B"
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
    SEP="${Y}$(_hl $COLS ═)${N}"
    DIV="${Y}$(_hl $COLS ─)${N}"
    echo -e "$SEP"
    echo -e "${R}  !  ATENCION — LEER ANTES DE CONTINUAR  !${N}"
    echo -e "$SEP"
    echo ""
    echo -e "${W}  Garena hizo una actualizacion que rompio el sistema${N}"
    echo -e "${W}  de deteccion de replays. El scanner puede generar${N}"
    echo -e "${W}  FALSOS POSITIVOS en el modulo de replays.${N}"
    echo ""
    echo -e "${W}  Ya se incorporo un sistema de aviso para estos casos.${N}"
    echo ""
    echo -e "$DIV"
    echo -e "${C}  Para los SS:${N}"
    echo -e "${W}  * Usen herramientas como Logcat, Brevent, etc.${N}"
    echo -e "${W}  * NO apliquen W.O unicamente por el scanner.${N}"
    echo -e "${W}  * El scanner puede cometer falsos positivos.${N}"
    echo -e "${W}  * Ante la duda, analicen SIEMPRE manualmente.${N}"
    echo ""
    echo -e "$DIV"
    echo -e "${C}  No sabes como revisar? Sin problema:${N}"
    echo -e "${W}  Mandame captura a Instagram y te ayudo gratis.${N}"
    echo -e "${W}  Mantengamos un ambiente limpio juntos.${N}"
    echo ""
    echo -e "${M}  Instagram: @tizi_7zz${N}"
    echo ""
    echo -e "$SEP"
    echo -e "${M}  Gracias por leer -- TIZI  *  UNKNOWN TEAM${N}"
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
    check_apk_integrity
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
    sec_hdr "INFORMACIÓN DEL DISPOSITIVO"
    ANDROID_VER=$(adb shell getprop ro.build.version.release | tr -d '\r\n')
    DEVICE_MODEL=$(adb shell getprop ro.product.model | tr -d '\r\n')
    DEVICE_BRAND=$(adb shell getprop ro.product.brand | tr -d '\r\n')
    log_output "${B}[*] Android: ${W}$ANDROID_VER${N}"
    log_output "${B}[*] Modelo:  ${W}$DEVICE_MODEL${N}"
    log_output "${B}[*] Marca:   ${W}$DEVICE_BRAND${N}"

    GAME_VER=$(adb shell "dumpsys package $GAME_PKG 2>/dev/null | grep versionName | head -1" | tr -d '\r' | sed 's/.*versionName=//')
    [ -n "$GAME_VER" ] && log_output "${B}[*] Versión del juego: ${W}$GAME_VER${N}"

    GAME_PID=$(adb shell "pidof $GAME_PKG 2>/dev/null" | tr -d '\r\n')
    if [ -n "$GAME_PID" ]; then
        log_output "${B}[*] PID del juego: ${W}$GAME_PID ${G}(proceso activo)${N}"
    else
        log_output "${B}[*] PID del juego: ${Y}no encontrado (juego no corriendo)${N}"
    fi
    echo ""
}

check_root() {
    sec_hdr "DETECCIÓN DE ROOT / BINARIOS SU"
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
    sec_hdr "DETECCIÓN DE BYPASS DE FUNCIONES SHELL"
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
    sec_hdr "DETECCIÓN DE VPN/DNS/PROXY"
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
    sec_hdr "ARCHIVOS ELIMINADOS RECIENTEMENTE (GAME DATA)"
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
    sec_hdr "ANÁLISIS DE REPLAYS"
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
    sec_hdr "WALLHACK / SHADERS / OVERLAYS"
    FOUND_WH=0

    log_output "${B}[+] Verificando shaders (firma UnityFS)...${N}"
    SHADER_DIR="/sdcard/Android/data/$GAME_PKG/files/contentcache/Optional/android/gameassetbundles"
    SHADERS=$(adb shell "find '$SHADER_DIR' -name 'shader*' 2>/dev/null" | tr -d '\r' | head -3)
    if [ -n "$(echo "$SHADERS" | tr -d '[:space:]')" ]; then
        echo "$SHADERS" | while read -r shader; do
            [ -z "$shader" ] && continue
            UNITY=$(adb shell "head -c 7 '$shader' 2>/dev/null")
            if [ "$UNITY" != "UnityFS" ]; then
                log_output "${R}[!] SHADER INVÁLIDO (firma incorrecta): $(basename "$shader")${N}"
                ((SUSPICIOUS_COUNT+=3)); FOUND_WH=1
            fi
        done
    fi

    log_output "${B}[+] Verificando overlays por nombre de color...${N}"
    for shader in branco verde ciano laranja amarelo marelomag agente; do
        NAMED=$(adb shell "find /sdcard/Android/data/$GAME_PKG -name '*${shader}*' 2>/dev/null | head -1" | tr -d '\r')
        if [ -n "$(echo "$NAMED" | tr -d '[:space:]')" ]; then
            log_output "${R}[!] OVERLAY/SHADER POR NOMBRE DETECTADO: $(basename "$NAMED") (patrón: $shader)${N}"
            ((SUSPICIOUS_COUNT+=3)); FOUND_WH=1
        fi
    done

    log_output "${B}[+] Verificando overlays en /sdcard raíz...${N}"
    SDCARD_OVL=$(adb shell "ls /sdcard/ 2>/dev/null | grep -iE 'overlay|shader|Overlay'" | tr -d '\r')
    if [ -n "$(echo "$SDCARD_OVL" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] ARCHIVOS DE OVERLAY EN /sdcard:${N}"
        echo "$SDCARD_OVL" | while read -r f; do [ -n "$f" ] && log_output "${Y}  /sdcard/$f${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_WH=1
    fi

    [ $FOUND_WH -eq 0 ] && log_output "${G}[✓] Sin shaders ni overlays sospechosos${N}"
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

check_apk_integrity() {
    sec_hdr "INTEGRIDAD DEL APK / HASH SHA256"
    APK_PATH=$(adb shell "pm path $GAME_PKG 2>/dev/null | head -1" | tr -d '\r' | sed 's/^package://')
    if [ -z "$(echo "$APK_PATH" | tr -d '[:space:]')" ]; then
        log_output "${Y}[*] No se pudo obtener el path del APK${N}"
        echo ""; return
    fi

    log_output "${B}[*] APK path: ${W}$APK_PATH${N}"
    log_output "${B}[+] Calculando SHA256 (puede tardar unos segundos)...${N}"
    APK_SHA=$(adb shell "sha256sum '$APK_PATH' 2>/dev/null | awk '{print \$1}'" | tr -d '\r\n')

    if [ -n "$APK_SHA" ] && [ ${#APK_SHA} -eq 64 ]; then
        log_output "${B}[*] SHA256: ${W}$APK_SHA${N}"
        if echo "$APK_SHA" | grep -qE '^0{64}$'; then
            log_output "${R}[!] SHA256 inválido (todo ceros) — posible error de lectura${N}"
            ((SUSPICIOUS_COUNT++))
        else
            log_output "${G}[✓] SHA256 calculado correctamente${N}"
        fi
    else
        log_output "${Y}[*] No se pudo calcular SHA256${N}"
    fi
    echo ""
}

check_hooks() {
    sec_hdr "HOOKING: Frida / Xposed / LSPosed / Shizuku / Inject"
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
    sec_hdr "ROOT AVANZADO / MAGISK / SHAMIKO / ZYGISK"
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

    APATCH_FILES=$(adb shell "ls /data/adb/apatch 2>/dev/null && echo found" | tr -d '\r')
    if echo "$APATCH_FILES" | grep -q "found"; then
        log_output "${R}[!] APATCH DETECTADO (/data/adb/apatch existe)${N}"
        ((SUSPICIOUS_COUNT+=3)); BYPASS_FOUND=1
    fi

    KSU_BIN=$(adb shell "ksud --version 2>/dev/null | head -1" | tr -d '\r')
    KSU_DIR=$(adb shell "ls /data/adb/ksu 2>/dev/null && echo found" | tr -d '\r')
    if [ -n "$KSU_BIN" ] || echo "$KSU_DIR" | grep -q "found"; then
        log_output "${R}[!] KERNELSU DETECTADO${N}"
        [ -n "$KSU_BIN" ] && log_output "${Y}  ksud: $KSU_BIN${N}"
        ((SUSPICIOUS_COUNT+=3)); BYPASS_FOUND=1
    fi

    KSUNEXT_DIR=$(adb shell "ls /data/adb/ksunext 2>/dev/null && echo found" | tr -d '\r')
    if echo "$KSUNEXT_DIR" | grep -q "found"; then
        log_output "${R}[!] KERNELSU NEXT DETECTADO (/data/adb/ksunext)${N}"
        ((SUSPICIOUS_COUNT+=3)); BYPASS_FOUND=1
    fi

    [ $BYPASS_FOUND -eq 0 ] && log_output "${G}[✓] Sin root bypass avanzado${N}"
    echo ""
}

check_fake_time() {
    sec_hdr "DETECCIÓN DE TIEMPO FALSO / CONGELADO"
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
    sec_hdr "HERRAMIENTAS SOSPECHOSAS / EMULADOR"
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
    sec_hdr "ESTADO DE SELINUX"
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
    sec_hdr "ESTADO DE BOOT VERIFICADO"
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
    sec_hdr "ANÁLISIS DE KERNEL"
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
    sec_hdr "APLICACIONES SOSPECHOSAS / ROOT / CHEAT"
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

    log_output "${B}[+] Verificando wrapper en el juego...${N}"
    WRAPPER=$(adb shell "pm dump $GAME_PKG 2>/dev/null | grep -i wrapper" | tr -d '\r')
    if [ -n "$(echo "$WRAPPER" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] WRAPPER DETECTADO — APK modificada mediante wrapper:${N}"
        echo "$WRAPPER" | head -3 | while read -r l; do [ -n "$l" ] && log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_SUSP=1
    fi

    log_output "${B}[+] Verificando indicadores de APK crackeado...${N}"
    CRACKED=$(adb shell "pm dump $GAME_PKG 2>/dev/null | grep -iE 'cracked|modded|lsposed'" | tr -d '\r')
    if [ -n "$(echo "$CRACKED" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] APK CRACKEADO/MODIFICADO DETECTADO:${N}"
        echo "$CRACKED" | head -3 | while read -r l; do [ -n "$l" ] && log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_SUSP=1
    fi

    [ $FOUND_SUSP -eq 0 ] && log_output "${G}[✓] Sin apps sospechosas${N}"
    echo ""
}

check_network_ports() {
    sec_hdr "PUERTOS Y CONEXIONES SOSPECHOSAS"
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
    sec_hdr "CONEXIONES ADB / CONTROL REMOTO"
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
    sec_hdr "APPS SOSPECHOSAS DESINSTALADAS"
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
    sec_hdr "CAPTURA DE PANTALLA / MEDIA PROJECTION"
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
    sec_hdr "ARCHIVOS EN /DATA/LOCAL/TMP"
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
    sec_hdr "CRASHES SOSPECHOSOS (DROPBOX)"
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
    sec_hdr "CONFIGURACIÓN DE FECHA/HORA"
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
    sec_hdr "PLAY INTEGRITY FIX / SPOOF DE INTEGRIDAD"
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
    sec_hdr "DEVICE SPOOFING / EVASIÓN DE BAN"
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
    sec_hdr "CERTIFICADOS CA / MITM"
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
    sec_hdr "KEYMAPPERS / CONTROLES EXTERNOS"
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
    sec_hdr "GRABACIÓN / ESPEJAMIENTO / SCRCPY"
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
    sec_hdr "MODIFICACIÓN DE ESCENAS / ASSETS / PAYLOAD"
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
    sec_hdr "TERMUX / HERRAMIENTAS DE EVASION EN DISPOSITIVO"
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
    sec_hdr "BYPASS XIAOMI / MIUI / HYPEROS"
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
    sec_hdr "ANÁLISIS DNS / INTERCEPCIÓN DE RED"
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
    sec_hdr "PUERTOS SOSPECHOSOS (SSH/FTP/IMAP/SOCKS)"
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
    sec_hdr "EVENTOS NUEVOS EN LOGCAT DURANTE EL SCAN"
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
    sec_hdr "PROCESOS NUEVOS DURANTE EL SCAN (DELTA)"
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

    sec_hdr "MONITOREO ACTIVO DEL DISPOSITIVO"
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
    sec_hdr "RESUMEN DEL ANÁLISIS"
    log_output "${B}[*] Juego: ${W}$GAME_SELECTED${N}"
    log_output "${B}[*] Señales sospechosas: ${W}$SUSPICIOUS_COUNT${N}"
    [ -n "$DEVICE_HWID" ] && log_output "${B}[*] HWID: ${Y}$DEVICE_HWID${N}"
    echo ""

    if [ $SUSPICIOUS_COUNT -eq 0 ]; then
        verdict_box "$G" "  ✓  DISPOSITIVO LIMPIO  ✓  "
    elif [ $SUSPICIOUS_COUNT -lt 10 ]; then
        verdict_box "$Y" "  !  REVISAR MANUALMENTE — NO DAR W.O  !  "
    else
        verdict_box "$R" "  ✗  ALTO RIESGO DE CHEATS  ✗  "
    fi

    log_output "\n${M}[*] Log: ${W}$LOGFILE${N}"
}

check_storage
main_menu
