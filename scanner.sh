#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# FREE FIRE ANTI-CHEAT SCANNER
# Creado por: TIZI.XIT
# Versión: 1.2.0
# ============================================

R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
B='\033[1;34m'
M='\033[1;35m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

LOGFILE="$HOME/anticheat_log_$(date +%Y%m%d_%H%M%S).txt"
SUSPICIOUS_COUNT=0
GAME_SELECTED=""
GAME_PKG=""

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
    printf "%b\n" "${C}║${M}$( _center "CODE BY TIZI.XIT - ANTI-CHEAT SYSTEM" )${C}║${N}"
    printf "%b\n" "${C}║${M}$( _center "VERSIÓN 1.2.0" )${C}║${N}"
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
        s|S) echo -e "\n${W}Gracias por usar el scanner${N}\n"; exit 0 ;;
        *) echo -e "${R}Opción inválida${N}"; sleep 2; main_menu ;;
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
    echo -e "${B}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${B}║         GUARDAR DIAGNÓSTICO COMPLETO                  ║${N}"
    echo -e "${B}╚════════════════════════════════════════════════════════╝${N}"

    if ! adb devices | grep -q "device$"; then
        echo -e "${R}[!] No hay dispositivos conectados. Usá la opción [0]${N}"
        echo -e "${W}Enter...${N}"; read; main_menu; return
    fi

    DUMP_DIR="$HOME/dump_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$DUMP_DIR"
    echo -e "${B}[*] Guardando en: ${W}$DUMP_DIR${N}\n"

    _dump_step() {
        echo -ne "${B}  → $1...${N}"
        eval "$2" > "$DUMP_DIR/$3" 2>&1
        echo -e " ${G}OK${N}"
    }

    # Propiedades del sistema
    _dump_step "Propiedades del sistema" \
        "adb shell 'getprop 2>/dev/null'" \
        "getprop.txt"

    # Kernel y hardware
    _dump_step "Info del kernel" \
        "adb shell 'uname -a 2>/dev/null; echo; cat /proc/version 2>/dev/null; echo; cat /proc/cmdline 2>/dev/null | tr \"\\0\" \" \"; echo'" \
        "kernel_info.txt"

    # Logcat — todos los buffers
    for buf in main system events kernel crash; do
        _dump_step "Logcat [$buf]" \
            "adb shell 'logcat -d -b $buf 2>/dev/null'" \
            "logcat_${buf}.txt"
    done

    # Logcat completo con threadtime (últimas 8000 líneas)
    _dump_step "Logcat completo (tail 8000)" \
        "adb shell 'logcat -d -v threadtime -b all 2>/dev/null | tail -n 8000'" \
        "logcat_all_tail.txt"

    # dumpsys — servicios clave
    for svc in package activity procstats batterystats appops usb media_projection; do
        _dump_step "dumpsys $svc" \
            "adb shell 'dumpsys $svc 2>/dev/null'" \
            "dumpsys_${svc}.txt"
    done

    # dumpsys overlay (wallhack overlay check)
    _dump_step "dumpsys overlay" \
        "adb shell 'dumpsys overlay 2>/dev/null'" \
        "dumpsys_overlay.txt"

    # dumpsys usagestats (historial de apps)
    _dump_step "dumpsys usagestats (tail 8000)" \
        "adb shell 'dumpsys usagestats 2>/dev/null | tail -n 8000'" \
        "dumpsys_usagestats_tail.txt"

    # ps + mounts + tcp
    _dump_step "Procesos activos" \
        "adb shell 'ps -A -Z 2>/dev/null'" \
        "ps_full.txt"
    _dump_step "Puntos de montaje" \
        "adb shell 'cat /proc/mounts 2>/dev/null'" \
        "mounts.txt"
    _dump_step "Conexiones TCP" \
        "adb shell 'cat /proc/net/tcp /proc/net/tcp6 2>/dev/null'" \
        "tcp_connections.txt"
    _dump_step "Sockets Unix" \
        "adb shell 'cat /proc/net/unix 2>/dev/null'" \
        "unix_sockets.txt"
    _dump_step "appops completo" \
        "adb shell 'dumpsys appops 2>/dev/null'" \
        "dumpsys_appops.txt"

    # Dropbox
    _dump_step "Dropbox (crashes)" \
        "adb shell 'dumpsys dropbox 2>/dev/null'" \
        "dumpsys_dropbox.txt"

    # Packages Free Fire (ambos)
    for pkg in com.dts.freefireth com.dts.freefiremax; do
        _dump_step "Package info $pkg" \
            "adb shell 'dumpsys package $pkg 2>/dev/null'" \
            "dumpsys_pkg_${pkg}.txt"
    done

    echo ""
    DUMP_SIZE=$(du -sh "$DUMP_DIR" 2>/dev/null | cut -f1)
    echo -e "${G}[✓] Diagnóstico guardado: ${W}$DUMP_DIR${G} ($DUMP_SIZE)${N}"
    echo -e "${Y}[*] Podés comprimir con: tar czf dump.tar.gz -C \$HOME $(basename $DUMP_DIR)${N}"
    echo ""
    echo -e "${W}Enter para volver...${N}"; read; main_menu
}


conectar_adb() {
    clear; banner
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

scan_ff_normal() { GAME_PKG="com.dts.freefireth";  GAME_SELECTED="Free Fire";     ejecutar_scan; }
scan_ff_max()    { GAME_PKG="com.dts.freefiremax"; GAME_SELECTED="Free Fire MAX";  ejecutar_scan; }

ver_ultimo_log() {
    clear; banner
    ULTIMO_LOG=$(ls -t $HOME/anticheat_log_*.txt 2>/dev/null | head -1)
    if [ -z "$ULTIMO_LOG" ]; then
        echo -e "${R}[!] No hay logs guardados${N}"; echo -e "${W}Enter...${N}"; read; main_menu; return
    fi
    cat "$ULTIMO_LOG"
    echo -e "${W}Enter para volver...${N}"; read; main_menu
}

# ─────────────────────────────────────────────────────────────
#  EJECUTAR SCAN
# ─────────────────────────────────────────────────────────────
ejecutar_scan() {
    clear; banner
    log_output "${B}[*] Escaneando: $GAME_SELECTED${N}\n"

    if ! adb devices | grep -q "device$"; then
        log_output "${R}[!] No hay dispositivos conectados. Usá la opción [0]${N}"
        echo -e "${W}Enter...${N}"; read; main_menu; return
    fi

    if ! adb shell pm list packages | grep -q "$GAME_PKG"; then
        log_output "${R}[!] $GAME_SELECTED no está instalado${N}"
        sleep 3; main_menu; return
    fi

    check_hwid_ban
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
    check_suspicious_packages
    check_network_ports
    check_adb_connections
    check_uninstalled_apps
    check_media_projection
    check_data_local_tmp
    check_dropbox_crashes
    check_auto_time
    show_summary

    echo -e "\n${W}Presiona Enter para volver al menú...${N}"; read
    main_menu
}

# ─────────────────────────────────────────────────────────────
#  MÓDULOS
# ─────────────────────────────────────────────────────────────

check_hwid_ban() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}         DETECCIÓN DE BAN POR HWID                     ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    BAN_FOUND=0

    # ── Serial del hardware (SoC) vs getprop ──────────────────
    log_output "${B}[+] Verificando serial de hardware...${N}"
    HW_SERIAL=$(adb shell 'cat /sys/devices/soc0/serial_num 2>/dev/null || cat /sys/bus/soc/devices/soc0/serial_num 2>/dev/null || cat /sys/devices/system/soc/soc0/serial_num 2>/dev/null' | tr -d '\r\n')
    PROP_SERIAL=$(adb shell "getprop ro.serialno 2>/dev/null" | tr -d '\r\n')
    BOOT_SERIAL=$(adb shell "getprop ro.boot.serialno 2>/dev/null" | tr -d '\r\n')

    log_output "${B}[*] Serial SoC:    ${W}${HW_SERIAL:-no disponible}${N}"
    log_output "${B}[*] ro.serialno:   ${W}${PROP_SERIAL:-vacío}${N}"
    log_output "${B}[*] boot.serialno: ${W}${BOOT_SERIAL:-vacío}${N}"

    # Serial todo 9s o 0s = banido/spoofed
    if echo "$PROP_SERIAL" | grep -qE '^9{4,}|^0{4,}'; then
        log_output "${R}[!] SERIAL BANIDO/SPOOFED: $PROP_SERIAL${N}"
        ((SUSPICIOUS_COUNT+=3)); BAN_FOUND=1
    fi

    # Serial del SoC difiere del prop (spoofer activo)
    if [ -n "$HW_SERIAL" ] && [ -n "$PROP_SERIAL" ] && [ "$HW_SERIAL" != "$PROP_SERIAL" ]; then
        log_output "${R}[!] Serial adulterado — SoC: $HW_SERIAL ≠ prop: $PROP_SERIAL${N}"
        ((SUSPICIOUS_COUNT+=2)); BAN_FOUND=1
    fi

    # ── UID del juego en logcat (patrón de ban) ───────────────
    log_output "${B}[+] Verificando UID del juego en logcat...${N}"
    GAME_UID=$(adb shell "logcat -d -b uid 2>/dev/null | grep -oE '\"uid\"\\s*:\\s*\"?([0-9]{4,})\"?' | grep -oE '[0-9]{4,}' | tail -1" | tr -d '\r')
    if [ -z "$GAME_UID" ]; then
        # Fallback: pm dump para obtener el UID del paquete
        GAME_UID=$(adb shell "dumpsys package $GAME_PKG 2>/dev/null | grep 'userId=' | head -1 | grep -oE '[0-9]+'" | tr -d '\r')
    fi

    if [ -n "$GAME_UID" ]; then
        log_output "${B}[*] UID detectado: ${W}$GAME_UID${N}"
        if echo "$GAME_UID" | grep -qE '^9{4,}|^0{4,}'; then
            log_output "${R}[!] UID con patrón de BAN: $GAME_UID${N}"
            ((SUSPICIOUS_COUNT+=3)); BAN_FOUND=1
        fi
    else
        log_output "${Y}[*] No se pudo obtener UID del juego${N}"
    fi

    # ── androidboot.ulcnt (unlock counter) ───────────────────
    log_output "${B}[+] Verificando unlock counter...${N}"
    ULCNT_RAW=$(adb shell "cat /proc/cmdline 2>/dev/null" | tr '\0' ' ' | tr -d '\r')
    ULCNT=$(echo "$ULCNT_RAW" | grep -oE 'androidboot\.ulcnt=[0-9]+' | grep -oE '[0-9]+$')
    if [ -n "$ULCNT" ] && [ "$ULCNT" -gt 0 ] 2>/dev/null; then
        log_output "${Y}[!] androidboot.ulcnt=$ULCNT — bootloader desbloqueado al menos $ULCNT vez/veces${N}"
        ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] ulcnt=0 o no disponible${N}"
    fi

    # Mensajes de ban en logcat — regex ajustado para evitar falsos positivos
    # como "WIFI_BAND_5_GHZ" que contiene "ban" como substring
    log_output "${B}[+] Buscando mensajes de ban en logcat...${N}"
    BAN_LOG=$(adb shell "logcat -d 2>/dev/null | grep -iE 'hwid.*ban[^d]|ban[^d].*hwid|account.*banned|device.*banned|banned.*account' | grep -viE 'knox|samsung|wifi_band|NearbyMediums|Bluetooth' | tail -5" | tr -d '\r')
    if [ -n "$(echo "$BAN_LOG" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Mensajes de ban detectados en logcat:${N}"
        echo "$BAN_LOG" | while read -r line; do [ -n "$line" ] && log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=2)); BAN_FOUND=1
    fi

    # ── SSH keys / authorized_keys (bypass de ban via SSH tunnel) ──
    log_output "${B}[+] Verificando claves SSH sospechosas...${N}"
    SSH_KEYS=$(adb shell "find /data/adb /data/local /sdcard 2>/dev/null -maxdepth 4 \( -name 'authorized_keys' -o -name 'id_rsa' -o -name 'id_ed25519' -o -name 'known_hosts' \) | head -5" | tr -d '\r')
    if [ -n "$(echo "$SSH_KEYS" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Claves SSH encontradas (posible tunnel para evadir ban):${N}"
        echo "$SSH_KEYS" | while read -r f; do [ -n "$f" ] && log_output "${Y}  $f${N}"; done
        ((SUSPICIOUS_COUNT+=2)); BAN_FOUND=1
    fi

    if [ $BAN_FOUND -eq 0 ]; then
        log_output "${G}[✓] Sin indicadores de ban por HWID${N}"
    else
        log_output "${R}[!] INDICADORES DE BAN DETECTADOS${N}"
    fi
    echo ""
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
    log_output "${B}[+] Verificando ROOT...${N}"
    if adb shell "command -v su" 2>&1 | grep -q "/su"; then
        log_output "${R}[!] ROOT DETECTADO${N}\n"; ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] Sin ROOT${N}\n"
    fi
}

check_uptime() {
    UPTIME=$(adb shell uptime | tr -d '\r')
    log_output "${B}[*] Uptime: ${W}$UPTIME${N}"
    # Solo marcar si lleva menos de 10 minutos encendido (reinicio muy reciente)
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
    FIRST_LOG=$(adb logcat -d -v time 2>/dev/null | grep -oE "[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" | head -1)
    log_output "${Y}[*] Primer registro de log: $FIRST_LOG${N}\n"
}

check_time_changes() {
    log_output "${B}[+] Verificando cambios de hora...${N}"
    TIME_CHANGES=$(adb logcat -d 2>/dev/null | grep "Time changed" | grep -v "HCALL" | tail -3)
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
    # hcallSetClipboardTextRpc = log interno de FF cuando el juego copia texto al portapapeles
    # Los cheats suelen copiar UIDs, coordenadas o tokens usando esto
    log_output "${B}[+] Verificando uso de clipboard por Free Fire...${N}"
    CLIP=$(adb logcat -d 2>/dev/null | grep 'hcallSetClipboardTextRpc' | tail -5)
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
        if adb shell pm list packages 2>/dev/null | grep -q "$pkg"; then
            log_output "${R}[!] VPN INSTALADA: $pkg${N}"
            VPN_DETECTED=1; ((SUSPICIOUS_COUNT++))
        fi
    done

    # Interfaz VPN activa en la red
    VPN_IF=$(adb shell "ip link show 2>/dev/null | grep -iE 'tun[0-9]|tap[0-9]|ppp[0-9]'" | tr -d '\r')
    if [ -n "$VPN_IF" ]; then
        log_output "${R}[!] INTERFAZ VPN ACTIVA: $VPN_IF${N}"
        VPN_DETECTED=1; ((SUSPICIOUS_COUNT+=2))
    fi

    [ $VPN_DETECTED -eq 0 ] && log_output "${G}[✓] Sin VPN detectada${N}"
    echo ""

    # DNS — solo flagear si el servidor DNS es claramente un proxy cheat
    # No flagear Cloudflare/Google porque son legítimos en la mayoría de casos
    log_output "${B}[+] Verificando DNS privado...${N}"
    PRIVATE_DNS_MODE=$(adb shell "settings get global private_dns_mode" 2>/dev/null | tr -d '\r')
    PRIVATE_DNS_HOST=$(adb shell "settings get global private_dns_specifier" 2>/dev/null | tr -d '\r')

    if [ "$PRIVATE_DNS_MODE" = "hostname" ] && [ -n "$PRIVATE_DNS_HOST" ] && [ "$PRIVATE_DNS_HOST" != "null" ]; then
        # Solo sospechoso si el hostname del DNS privado parece un servidor de cheat
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

    echo ""
    if [ ${#MOTIVOS[@]} -gt 0 ]; then
        log_output "${R}[!] REPLAY PASADO DETECTADO - ¡APLICA EL W.O!${N}"
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
    log_output "${C}║${W}     DETECCIÓN DE HOOKING (Frida / Xposed / LSPosed)    ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Verificando procesos de hooking...${N}"
    HOOK_PROC=$(adb shell "ps -A 2>/dev/null | grep -iE 'frida|xposed|lsposed|zygisk|riru'" | tr -d '\r')
    if [ -n "$HOOK_PROC" ]; then
        log_output "${R}[!] FRAMEWORK DE HOOKING DETECTADO (proceso)${N}"
        echo "$HOOK_PROC" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=3))
    else
        log_output "${G}[✓] Sin procesos de hooking${N}"
    fi

    log_output "${B}[+] Verificando archivos de hooking...${N}"
    HOOK_FILES=$(adb shell "find /data /system 2>/dev/null | grep -iE '/frida|/xposed|/lsposed' | grep -v 'knox' | head -10" | tr -d '\r')
    if [ -n "$(echo "$HOOK_FILES" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] ARCHIVOS DE HOOKING DETECTADOS${N}"
        echo "$HOOK_FILES" | while read -r f; do [ -n "$f" ] && log_output "${Y}  $f${N}"; done
        ((SUSPICIOUS_COUNT+=3))
    else
        log_output "${G}[✓] Sin archivos de hooking${N}"
    fi
    echo ""
}

check_root_bypass() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     ROOT AVANZADO / MAGISK / SHAMIKO / ZYGISK          ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Verificando Magisk, Shamiko, Zygisk...${N}"
    BYPASS_FOUND=0

    # Verificar procesos — excluir knox que es Samsung legítimo
    BYPASS_PS=$(adb shell "ps -A 2>/dev/null | grep -iE 'magisk|shamiko|zygisk|busybox'" | grep -viE 'knox' | tr -d '\r')
    if [ -n "$BYPASS_PS" ]; then
        log_output "${R}[!] ROOT BYPASS DETECTADO (proceso)${N}"
        echo "$BYPASS_PS" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=3)); BYPASS_FOUND=1
    fi

    # Verificar archivos de Magisk
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

    log_output "${B}[+] Verificando que el tiempo avance normalmente...${N}"
    T1=$(adb shell "date +%s 2>/dev/null" | tr -d '\r')
    sleep 1
    T2=$(adb shell "date +%s 2>/dev/null" | tr -d '\r')
    if [ -n "$T1" ] && [ -n "$T2" ]; then
        DIFF=$((T2 - T1))
        if [ "$DIFF" -lt 1 ]; then
            log_output "${R}[!] TIEMPO CONGELADO O FALSO (T1=$T1 T2=$T2)${N}"
            ((SUSPICIOUS_COUNT+=3))
        else
            log_output "${G}[✓] Tiempo avanza normalmente${N}"
        fi
    fi

    log_output "${B}[+] Verificando inconsistencia via stat...${N}"
    TEST_FILE="/data/local/tmp/.tc_$$"
    adb shell "echo test > $TEST_FILE 2>/dev/null" >/dev/null 2>&1
    sleep 1
    STAT_R=$(adb shell "stat $TEST_FILE 2>/dev/null" | tr -d '\r')
    adb shell "rm -f $TEST_FILE 2>/dev/null" >/dev/null 2>&1
    if echo "$STAT_R" | grep -q "1970"; then
        log_output "${R}[!] INCONSISTENCIA: stat muestra año 1970${N}"
        ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Timestamps consistentes${N}"
    fi
    echo ""
}

check_tooling() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     HERRAMIENTAS SOSPECHOSAS / EMULADOR                ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Verificando emuladores y herramientas sospechosas...${N}"
    TOOL_FOUND=0

    # Detectar emuladores reales — solo flagear propiedades con valor sospechoso,
    # excluir ro.kernel.qemu con valor 0 (presente en todos los Android reales)
    EMULATOR_PROPS=$(adb shell "getprop 2>/dev/null | grep -iE 'qemu|goldfish|vbox|genymotion|nox|memu|bluestacks|andy|droid4x'" \
        | grep -viE 'knox|samsung|\]: \[0\]|\]: \[\]' | tr -d '\r')
    if [ -n "$EMULATOR_PROPS" ]; then
        log_output "${R}[!] EMULADOR DETECTADO${N}"
        echo "$EMULATOR_PROPS" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=2)); TOOL_FOUND=1
    fi

    # Proceso qemu (emulador Android Studio / Genymotion)
    QEMU_PROC=$(adb shell "ps -A 2>/dev/null | grep -iE 'qemu|genymotion|bluestacks'" | grep -viE 'knox' | tr -d '\r')
    if [ -n "$QEMU_PROC" ]; then
        log_output "${R}[!] PROCESO DE EMULADOR DETECTADO${N}"
        echo "$QEMU_PROC" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=2)); TOOL_FOUND=1
    fi

    # Verificar si ro.kernel.qemu = 1 (emulador real)
    QEMU_FLAG=$(adb shell "getprop ro.kernel.qemu 2>/dev/null" | tr -d '\r')
    if [ "$QEMU_FLAG" = "1" ]; then
        log_output "${R}[!] EMULADOR CONFIRMADO (ro.kernel.qemu=1)${N}"
        ((SUSPICIOUS_COUNT+=3)); TOOL_FOUND=1
    fi

    [ $TOOL_FOUND -eq 0 ] && log_output "${G}[✓] Dispositivo físico, sin emulador${N}"
    echo ""
}

# ─────────────────────────────────────────────────────────────
#  MÓDULOS NUEVOS (portados de KellerSS)
# ─────────────────────────────────────────────────────────────

check_selinux() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}         ESTADO DE SELINUX                             ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    SE=$(adb shell "getenforce 2>/dev/null" | tr -d '\r')
    case "$SE" in
        Enforcing)
            log_output "${G}[✓] SELinux: Enforcing${N}" ;;
        Permissive)
            log_output "${R}[!] SELinux PERMISSIVO — común en dispositivos rooteados${N}"
            ((SUSPICIOUS_COUNT+=2)) ;;
        Disabled)
            log_output "${R}[!] SELinux DESACTIVADO${N}"
            ((SUSPICIOUS_COUNT+=3)) ;;
        *)
            log_output "${Y}[*] SELinux: estado desconocido ($SE)${N}" ;;
    esac
    echo ""
}

check_boot_state() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}         ESTADO DE BOOT VERIFICADO                     ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    BOOT_STATE=$(adb shell "getprop ro.boot.verifiedbootstate 2>/dev/null" | tr -d '\r')
    FLASH_LOCKED=$(adb shell "getprop ro.boot.flash.locked 2>/dev/null" | tr -d '\r')
    VBMETA=$(adb shell "getprop ro.boot.vbmeta.device_state 2>/dev/null" | tr -d '\r')
    WARRANTY=$(adb shell "getprop ro.boot.warranty_bit 2>/dev/null" | tr -d '\r')
    BL_STATE=$(adb shell "getprop ro.boot.bl_state 2>/dev/null" | tr -d '\r')

    log_output "${B}[*] verifiedbootstate: ${W}${BOOT_STATE:-desconocido}${N}"
    log_output "${B}[*] flash.locked:       ${W}${FLASH_LOCKED:-desconocido}${N}"
    log_output "${B}[*] vbmeta.device_state:${W}${VBMETA:-desconocido}${N}"
    log_output "${B}[*] warranty_bit:       ${W}${WARRANTY:-desconocido}${N}"

    if [ "$BOOT_STATE" = "orange" ] || [ "$BOOT_STATE" = "red" ]; then
        log_output "${R}[!] BOOTLOADER DESBLOQUEADO — boot state: $BOOT_STATE${N}"
        ((SUSPICIOUS_COUNT+=3))
    fi
    if [ "$FLASH_LOCKED" = "0" ]; then
        log_output "${R}[!] Flash desbloqueado (ro.boot.flash.locked=0)${N}"
        ((SUSPICIOUS_COUNT+=2))
    fi
    if [ "$VBMETA" = "unlocked" ]; then
        log_output "${R}[!] vbmeta.device_state=unlocked${N}"
        ((SUSPICIOUS_COUNT+=2))
    fi
    if [ "$WARRANTY" = "1" ]; then
        log_output "${Y}[!] warranty_bit=1 — bootloader fue desbloqueado anteriormente${N}"
        ((SUSPICIOUS_COUNT++))
    fi
    if [ -n "$BL_STATE" ] && [ "$BL_STATE" != "0" ]; then
        log_output "${Y}[!] bl_state=$BL_STATE (valor fuera del estándar)${N}"
        ((SUSPICIOUS_COUNT++))
    fi

    # Fingerprint vs system build
    FP_BUILD=$(adb shell "getprop ro.build.fingerprint 2>/dev/null" | tr -d '\r')
    FP_SYSTEM=$(adb shell "getprop ro.system.build.fingerprint 2>/dev/null" | tr -d '\r')
    BUILD_ID=$(adb shell "getprop ro.build.id 2>/dev/null" | tr -d '\r')
    SYS_BUILD_ID=$(adb shell "getprop ro.system.build.id 2>/dev/null" | tr -d '\r')
    if [ -n "$BUILD_ID" ] && [ -n "$SYS_BUILD_ID" ] && [ "$BUILD_ID" != "$SYS_BUILD_ID" ]; then
        log_output "${R}[!] Fingerprint adulterado: ro.build.id=$BUILD_ID vs ro.system.build.id=$SYS_BUILD_ID${N}"
        ((SUSPICIOUS_COUNT+=2))
    fi

    BUILD_TAGS=$(adb shell "getprop ro.build.tags 2>/dev/null" | tr -d '\r')
    if echo "$BUILD_TAGS" | grep -qiE "test-keys|dev-keys"; then
        log_output "${R}[!] Build tags sospechosas: $BUILD_TAGS${N}"
        ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Build tags normales: ${BUILD_TAGS}${N}"
    fi
    echo ""
}

check_kernel() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}         ANÁLISIS DE KERNEL                            ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    KERNEL=$(adb shell "uname -r 2>/dev/null" | tr -d '\r')
    log_output "${B}[*] Kernel: ${W}$KERNEL${N}"

    # KernelSU en el kernel
    KSU_LOG=$(adb shell 'logcat -b kernel -d 2>/dev/null | grep -iE "kernelsu|magisk|apatch" | head -1' | tr -d '\r')
    if [ -n "$KSU_LOG" ]; then
        log_output "${R}[!] KernelSU/Magisk/APatch detectado en kernel log:${N}"
        log_output "${Y}  $KSU_LOG${N}"
        ((SUSPICIOUS_COUNT+=3))
    fi

    # Sufijo de page size (indica kernel custom)
    if echo "$KERNEL" | grep -qE "\-[0-9]+k$|\-[0-9]+K$"; then
        log_output "${Y}[!] uname con sufijo de page size: $KERNEL — indica kernel personalizado${N}"
        ((SUSPICIOUS_COUNT++))
    fi

    # /proc/version
    PROC_VER=$(adb shell "cat /proc/version 2>/dev/null" | tr -d '\r')
    if echo "$PROC_VER" | grep -qiE "kernelsu|magisk|apatch|dirty|unofficial"; then
        log_output "${R}[!] Kernel modificado detectado en /proc/version${N}"
        log_output "${Y}  $PROC_VER${N}"
        ((SUSPICIOUS_COUNT+=2))
    fi

    # SuSFS
    SUSFS=$(adb shell '{ test -d /proc/sys/fs/susfs && echo FOUND; } || { test -d /sys/kernel/security/susfs && echo FOUND; } || echo NOTFOUND' | tr -d '\r')
    if echo "$SUSFS" | grep -q "FOUND"; then
        log_output "${R}[!] SuSFS detectado (oculta montajes/sockets de KernelSU)${N}"
        ((SUSPICIOUS_COUNT+=3))
    else
        log_output "${G}[✓] SuSFS no detectado${N}"
    fi

    # Módulos de kernel sospechosos via /proc/mounts
    KSU_MOUNT=$(adb shell 'grep -iE "KSU on /(system|vendor|product)" /proc/mounts 2>/dev/null | head -3' | tr -d '\r')
    if [ -n "$KSU_MOUNT" ]; then
        log_output "${R}[!] Módulos KernelSU montados detectados:${N}"
        echo "$KSU_MOUNT" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=2))
    fi
    echo ""
}

check_suspicious_packages() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     APLICACIONES SOSPECHOSAS / ROOT / CHEAT           ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    declare -A SUSPICIOUS_APPS
    SUSPICIOUS_APPS=(
        ["com.topjohnwu.magisk"]="Magisk (Manager)"
        ["io.github.magisk"]="Magisk"
        ["com.rifsxd.ksunext"]="KernelSU Next"
        ["me.weishu.kernelsu"]="KernelSU"
        ["me.bmax.apatch"]="APatch"
        ["io.github.apatch"]="APatch"
        ["io.github.huskydg.magisk"]="Magisk Delta"
        ["org.lsposed.manager"]="LSPosed Manager"
        ["com.dergoogler.mmrl"]="MMRL (Magisk Module)"
        ["com.zhenxi.hunter"]="Shizuku Hunter"
        ["com.googleplay.ndkvs"]="Free Fire Modificado (.ndkvs)"
        ["eu.sisik.hackendebug"]="Hack&Debug"
        ["eu.sisik.hackendebug.full"]="Hack&Debug Pro"
        ["me.piebridge.brevent"]="Brevent"
        ["io.github.mhmrdd.libxposed"]="libXposed"
        ["io.github.mhmrdd.libxposed.ps.passit"]="Passador de Replay via Xposed"
        ["io.liankong.riskdetector"]="Risk Detector"
        ["com.tsng.applistdetector"]="AppList Detector"
        ["io.github.rabehx.securify"]="Securify"
        ["com.eltavine.duckdetector"]="Duck Detector"
        ["gr.nikolasspyr.integritycheck"]="Integrity Check"
        ["com.studio.duckdetector"]="Duck Detector (Studio)"
        ["com.reveny.nativecheck"]="NativeCheck"
        ["com.chunqiunativecheck"]="NativeCheck"
        ["com.lexa.fakegps"]="Fake GPS"
        ["com.incorporateapps.fakegps.fre"]="Fake GPS Free"
        ["com.zerotier.one"]="ZeroTier (tunel)"
        ["com.lbe.parallel"]="Parallel Space"
        ["io.github.vvb2060.mahoshojo"]="TrickyStore (Bypass)"
        ["io.github.huskydg.memorydetector"]="MemoryDetector"
        ["com.system.update.service"]="Servicio falso de sistema"
        ["id.my.pjm.qbcd_okr_dvii"]="QBCD (detector root)"
        ["com.rem01gaming.disclosure"]="Disclosure"
    )

    PKG_LIST=$(adb shell "pm list packages 2>/dev/null" | tr -d '\r')
    FOUND_SUSP=0
    for pkg in "${!SUSPICIOUS_APPS[@]}"; do
        if echo "$PKG_LIST" | grep -q "package:$pkg"; then
            log_output "${R}[!] App sospechosa: ${SUSPICIOUS_APPS[$pkg]} ($pkg)${N}"
            FOUND_SUSP=1; ((SUSPICIOUS_COUNT+=2))
        fi
    done

    # Buscar por instalador sospechoso (sideload/ADB)
    log_output "${B}[+] Verificando instalador de $GAME_PKG...${N}"
    INSTALLER=$(adb shell "dumpsys package $GAME_PKG 2>/dev/null | grep 'installerPackageName'" | tr -d '\r' | head -1)
    if [ -n "$INSTALLER" ]; then
        log_output "${B}[*] $INSTALLER${N}"
        if echo "$INSTALLER" | grep -qiE "null|adb|sideload|unknown|bin.mt.plus|me.kissfisher"; then
            log_output "${R}[!] Instalador sospechoso/modificado: $INSTALLER${N}"
            ((SUSPICIOUS_COUNT+=2)); FOUND_SUSP=1
        fi
    fi

    # batterystats — apps en historial que ya no están instaladas
    log_output "${B}[+] Verificando historial de apps sospechosas (batterystats)...${N}"
    BATT_HIST=$(adb shell "dumpsys batterystats 2>/dev/null | grep -oE 'pkgunin=[0-9]+:\"[^\"]+\"' | grep -oE '\"[^\"]+\"' | tr -d '\"' | sort -u" | tr -d '\r')
    if [ -n "$BATT_HIST" ]; then
        while read -r pkg; do
            [ -z "$pkg" ] && continue
            if echo "$pkg" | grep -qiE "magisk|xposed|lsposed|kernelsu|apatch|frida|hook|cheat|hack|bypass|cracked|modded|inject|passit|suspeito"; then
                log_output "${Y}[!] App sospechosa en historial (desinstalada): $pkg${N}"
                ((SUSPICIOUS_COUNT++)); FOUND_SUSP=1
            fi
        done <<< "$BATT_HIST"
    fi

    [ $FOUND_SUSP -eq 0 ] && log_output "${G}[✓] Sin apps sospechosas${N}"
    echo ""
}

check_network_ports() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     PUERTOS Y CONEXIONES SOSPECHOSAS                  ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    # Puertos Frida (27042/27043 = 0x699A/0x699B en hex little-endian = 69B2/69B3)
    log_output "${B}[+] Verificando puertos Frida (27042/27043)...${N}"
    FRIDA_PORT=$(adb shell "for f in /proc/net/tcp /proc/net/tcp6; do [ -r \"\$f\" ] || continue; grep -iE ':(69B2|69B3) ' \"\$f\" | grep -E ' 0A ' && echo \"\$f\"; done | head -3" | tr -d '\r')
    if [ -n "$(echo "$FRIDA_PORT" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] PUERTOS FRIDA DETECTADOS EN LISTEN:${N}"
        echo "$FRIDA_PORT" | while read -r line; do [ -n "$line" ] && log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=3))
    else
        log_output "${G}[✓] Sin puertos Frida${N}"
    fi

    # Sockets Unix de ZygoteNext / Shizuku
    log_output "${B}[+] Verificando sockets abstractos sospechosos...${N}"
    UNIX_SOCKETS=$(adb shell "cat /proc/net/unix 2>/dev/null | grep -oE '@zn_(init|global|zygote|log)_[A-Za-z0-9]+' | sort -u | head -5" | tr -d '\r')
    if [ -n "$UNIX_SOCKETS" ]; then
        log_output "${R}[!] Sockets ZygoteNext detectados (APatch Trick):${N}"
        echo "$UNIX_SOCKETS" | while read -r s; do log_output "${Y}  $s${N}"; done
        ((SUSPICIOUS_COUNT+=2))
    fi

    # Puertos locales inesperados (excluyendo los comunes)
    log_output "${B}[+] Verificando puertos localhost inesperados...${N}"
    UNEXPECTED_PORTS=$(adb shell "awk '\$4==\"0A\"{print \$2}' /proc/net/tcp /proc/net/tcp6 2>/dev/null | grep -E '^0100007F:|^\[::ffff:7f' | while read addr; do port=\$((16#\${addr##*:})); echo \$port; done | sort -nu | grep -vE '^(80|443|53|8080|4444|5554|5555|8888|9229)\$'" | tr -d '\r')
    if [ -n "$UNEXPECTED_PORTS" ]; then
        log_output "${Y}[!] Puertos localhost en LISTEN no estándar:${N}"
        echo "$UNEXPECTED_PORTS" | while read -r p; do [ -n "$p" ] && log_output "${Y}  :$p${N}"; done
        ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] Sin puertos localhost sospechosos${N}"
    fi

    # Wi-Fi Proxy
    log_output "${B}[+] Verificando proxy Wi-Fi...${N}"
    WIFI_PROXY_HOST=$(adb shell "content query --uri content://settings/global/wifi_proxy_host 2>/dev/null" | tr -d '\r')
    WIFI_PROXY_PORT=$(adb shell "content query --uri content://settings/global/wifi_proxy_port 2>/dev/null" | tr -d '\r')
    if echo "$WIFI_PROXY_HOST" | grep -qE "value=.+[^null]"; then
        log_output "${R}[!] Proxy Wi-Fi configurado: $WIFI_PROXY_HOST $WIFI_PROXY_PORT${N}"
        ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Sin proxy Wi-Fi${N}"
    fi
    echo ""
}

check_adb_connections() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     CONEXIONES ADB / CONTROL REMOTO                   ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    # USB conectado a computador
    log_output "${B}[+] Verificando conexión USB...${N}"
    USB_STATE=$(adb shell "getprop sys.usb.state 2>/dev/null" | tr -d '\r')
    log_output "${B}[*] USB state: ${W}${USB_STATE:-desconocido}${N}"

    USB_CONNECTED=$(adb shell "dumpsys usb 2>/dev/null | grep -c 'USB_STATE=CONNECTED'" | tr -d '\r')
    if [ "${USB_CONNECTED:-0}" -gt 0 ] 2>/dev/null; then
        log_output "${Y}[!] USB_STATE=CONNECTED detectado ($USB_CONNECTED)${N}"
        ((SUSPICIOUS_COUNT++))
    fi

    # Claves ADB autorizadas recientes
    log_output "${B}[+] Verificando autorizaciones ADB recientes...${N}"
    ADB_KEYS=$(adb shell "dumpsys adb 2>/dev/null | grep -c 'connected key\|public key'" | tr -d '\r')
    if [ "${ADB_KEYS:-0}" -gt 0 ] 2>/dev/null; then
        log_output "${Y}[!] $ADB_KEYS clave(s) ADB autorizadas en el sistema${N}"
    fi

    # AdbDebuggingManager leer fallos (PC desconectado rápido)
    ADB_READ_FAIL=$(adb shell "logcat -d -b system 2>/dev/null | grep -c 'AdbDebuggingManager.*Read failed'" | tr -d '\r')
    if [ "${ADB_READ_FAIL:-0}" -gt 2 ] 2>/dev/null; then
        log_output "${R}[!] AdbDebuggingManager: $ADB_READ_FAIL fallos de lectura — PC desconectado rápidamente${N}"
        ((SUSPICIOUS_COUNT++))
    fi

    # Procesos ejecutables corriendo desde /data/adb/
    log_output "${B}[+] Verificando procesos desde /data/adb/...${N}"
    DATA_ADB_PROCS=$(adb shell 'for f in /proc/[0-9]*/exe; do l=$(readlink "$f" 2>/dev/null); case "$l" in /data/adb/*ksud*|/data/adb/*magiskd*|/data/adb/*apd*) continue;; /data/adb/*) echo "${f%%/exe}: $l";; esac; done 2>/dev/null | head -5' | tr -d '\r')
    if [ -n "$(echo "$DATA_ADB_PROCS" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Procesos corriendo desde /data/adb/:${N}"
        echo "$DATA_ADB_PROCS" | while read -r line; do [ -n "$line" ] && log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Sin procesos ejecutables inesperados en /data/adb/${N}"
    fi

    # Apps de control remoto / espejamiento instaladas
    log_output "${B}[+] Verificando apps de control remoto...${N}"
    declare -A REMOTE_APPS
    REMOTE_APPS=(
        ["com.koushikdutta.vysor"]="Vysor"
        ["com.genymobile.scrcpy"]="scrcpy"
        ["com.github.xianfeng92.scrcpy"]="QtScrcpy"
        ["com.adbcontrol.free"]="ADB Control"
    )
    PKG_LIST2=$(adb shell "pm list packages 2>/dev/null" | tr -d '\r')
    FOUND_REMOTE=0
    for pkg in "${!REMOTE_APPS[@]}"; do
        if echo "$PKG_LIST2" | grep -q "package:$pkg"; then
            log_output "${Y}[!] App de control remoto: ${REMOTE_APPS[$pkg]} ($pkg)${N}"
            FOUND_REMOTE=1; ((SUSPICIOUS_COUNT++))
        fi
    done
    [ $FOUND_REMOTE -eq 0 ] && log_output "${G}[✓] Sin apps de control remoto${N}"
    echo ""
}

check_uninstalled_apps() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     APPS SOSPECHOSAS DESINSTALADAS                    ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Buscando apps desinstaladas sospechosas en batterystats...${N}"
    # pkgunin = packages que fueron desinstaladas pero aparecen en el historial
    UNINSTALLED=$(adb shell "dumpsys batterystats 2>/dev/null | grep -oE 'pkgunin=[0-9]+:\"[^\"]+\"' | grep -oE '\"[^\"]+\"' | tr -d '\"' | sort -u" | tr -d '\r')
    FOUND_UNINST=0
    if [ -n "$UNINSTALLED" ]; then
        while read -r pkg; do
            [ -z "$pkg" ] && continue
            if echo "$pkg" | grep -qiE "magisk|xposed|lsposed|kernelsu|apatch|frida|hook|cheat|hack|bypass|cracked|modded|inject|passit|panel|gg\.mod"; then
                log_output "${Y}[!] App sospechosa desinstalada en historial: $pkg${N}"
                FOUND_UNINST=1; ((SUSPICIOUS_COUNT++))
            fi
        done <<< "$UNINSTALLED"
    fi

    # Force-stop sospechoso en logcat (deletePackageX/pkg removed de apps de cheat)
    log_output "${B}[+] Verificando force-stop de apps sospechosas en logs...${N}"
    FORCE_STOP=$(adb shell "logcat -d -b system 2>/dev/null | grep -E 'Force stopping|deletePackageX|pkg removed' | grep -iE 'magisk|xposed|frida|cheat|hack|bypass|kernelsu|apatch' | tail -5" | tr -d '\r')
    if [ -n "$FORCE_STOP" ]; then
        log_output "${Y}[!] Force-stop de apps sospechosas detectado:${N}"
        echo "$FORCE_STOP" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT++))
    fi

    [ $FOUND_UNINST -eq 0 ] && [ -z "$FORCE_STOP" ] && log_output "${G}[✓] Sin apps sospechosas en historial${N}"
    echo ""
}

check_media_projection() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     CAPTURA DE PANTALLA / MEDIA PROJECTION             ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Verificando media_projection activa...${N}"
    MEDIA_PROJ=$(adb shell "dumpsys media_projection 2>/dev/null | grep -iE 'package|isRecording|state.*record|projection.*active' | head -10" | tr -d '\r')
    if echo "$MEDIA_PROJ" | grep -qiE "isRecording=true|state=STARTED|active=true"; then
        log_output "${R}[!] CAPTURA DE PANTALLA ACTIVA — posible espejamiento:${N}"
        echo "$MEDIA_PROJ" | while read -r line; do [ -n "$line" ] && log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Sin captura de pantalla activa${N}"
    fi

    # appops SYSTEM_ALERT_WINDOW
    log_output "${B}[+] Verificando permiso SYSTEM_ALERT_WINDOW...${N}"
    SAW=$(adb shell "adb shell appops get $GAME_PKG SYSTEM_ALERT_WINDOW 2>/dev/null" | tr -d '\r')
    if echo "$SAW" | grep -qi "allow"; then
        log_output "${Y}[!] $GAME_SELECTED tiene SYSTEM_ALERT_WINDOW permitido${N}"
        ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] SYSTEM_ALERT_WINDOW no activo${N}"
    fi
    echo ""
}

check_data_local_tmp() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     ARCHIVOS EN /DATA/LOCAL/TMP                       ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Verificando /data/local/tmp...${N}"
    TMP_FILES=$(adb shell 'for f in /data/local/tmp/* /data/local/tmp/.*; do n="${f##*/}"; case "$n" in "." | "..") ;; *) [ -e "$f" ] && echo "$n";; esac; done' | tr -d '\r')
    if [ -n "$(echo "$TMP_FILES" | tr -d '[:space:]')" ]; then
        log_output "${Y}[!] Archivos encontrados en /data/local/tmp:${N}"
        echo "$TMP_FILES" | while read -r f; do
            [ -n "$f" ] && log_output "${Y}  $f${N}"
            if echo "$f" | grep -qiE "frida|hook|inject|cheat|hack|bypass|script"; then
                log_output "${R}    ^ SOSPECHOSO${N}"
                ((SUSPICIOUS_COUNT++))
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

    log_output "${B}[+] Verificando crashes repetidos en dropbox...${N}"
    CRASHES=$(adb shell 'dumpsys dropbox 2>/dev/null | grep -E "native_crash|TOMBSTONE|system_server" | sed "s/.*[0-9][0-9]:[0-9][0-9]:[0-9][0-9] //" | sed "s/ ([0-9]* bytes)//" | sort | uniq -c | sort -rn | awk '"'"'$1>=3{print $1" x "$2}'"'"' | head -5' | tr -d '\r')
    if [ -n "$(echo "$CRASHES" | tr -d '[:space:]')" ]; then
        log_output "${Y}[!] Crashes repetidos detectados:${N}"
        echo "$CRASHES" | while read -r line; do [ -n "$line" ] && log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] Sin crashes repetidos${N}"
    fi

    # AudioService crash (anti-cheat kill via audio crash)
    AUDIO_CRASH=$(adb shell "dumpsys dropbox 2>/dev/null | grep -iE 'audio.*crash|data_app_crash' | grep -i audio | head -3" | tr -d '\r')
    if [ -n "$AUDIO_CRASH" ]; then
        log_output "${Y}[!] Crash de AudioService — puede indicar kill de anti-cheat${N}"
        ((SUSPICIOUS_COUNT++))
    fi

    # PhantomProcess kills (Android 12+)
    PHANTOM=$(adb shell "logcat -d -b system 2>/dev/null | grep 'PhantomProcessRecord' | tail -5" | tr -d '\r')
    if [ -n "$PHANTOM" ]; then
        log_output "${Y}[!] PhantomProcessRecord en logs (procesos matados por el sistema):${N}"
        echo "$PHANTOM" | while read -r line; do log_output "${Y}  $line${N}"; done
    fi
    echo ""
}

check_auto_time() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     CONFIGURACIÓN DE FECHA/HORA                       ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Verificando auto_time y auto_time_zone...${N}"
    AUTO_TIME=$(adb shell "settings get global auto_time 2>/dev/null" | tr -d '\r')
    AUTO_TZ=$(adb shell "settings get global auto_time_zone 2>/dev/null" | tr -d '\r')
    TIMEZONE=$(adb shell "getprop persist.sys.timezone 2>/dev/null" | tr -d '\r')

    log_output "${B}[*] auto_time: ${W}${AUTO_TIME:-desconocido}${N}"
    log_output "${B}[*] auto_time_zone: ${W}${AUTO_TZ:-desconocido}${N}"
    log_output "${B}[*] Zona horaria: ${W}${TIMEZONE:-desconocida}${N}"

    if [ "$AUTO_TIME" = "0" ]; then
        log_output "${R}[!] Hora automática DESACTIVADA — facilita manipulación de timestamps${N}"
        ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Hora automática activa${N}"
    fi

    # Pantalla de configuración de fecha abierta via ADB (logcat)
    DATE_SCREEN=$(adb shell "logcat -d -b all -v time 2>/dev/null | grep -i 'com.android.settings' | grep -i 'date\|time\|clock' | tail -3" | tr -d '\r')
    if [ -n "$DATE_SCREEN" ]; then
        log_output "${Y}[!] Configuración de fecha/hora abierta recientemente (posible manipulación):${N}"
        echo "$DATE_SCREEN" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT++))
    fi
    echo ""
}

show_summary() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}              RESUMEN DEL ANÁLISIS                     ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    log_output "${B}[*] Juego: ${W}$GAME_SELECTED${N}"
    log_output "${B}[*] Señales sospechosas: ${W}$SUSPICIOUS_COUNT${N}\n"

    if [ $SUSPICIOUS_COUNT -eq 0 ]; then
        log_output "${G}╔════════════════════════════════════════════════════════╗${N}"
        log_output "${G}║              ✓ DISPOSITIVO LIMPIO ✓                   ║${N}"
        log_output "${G}╚════════════════════════════════════════════════════════╝${N}"
    elif [ $SUSPICIOUS_COUNT -le 3 ]; then
        log_output "${Y}╔════════════════════════════════════════════════════════╗${N}"
        log_output "${Y}║         ⚠ ADVERTENCIA: REVISAR MANUALMENTE ⚠          ║${N}"
        log_output "${Y}╚════════════════════════════════════════════════════════╝${N}"
    else
        log_output "${R}╔════════════════════════════════════════════════════════╗${N}"
        log_output "${R}║          ✗ ALTO RIESGO DE CHEATS ✗                    ║${N}"
        log_output "${R}╚════════════════════════════════════════════════════════╝${N}"
    fi

    log_output "\n${M}[*] Log: ${W}$LOGFILE${N}"
}

# ─────────────────────────────────────────────────────────────
#  INICIO
# ─────────────────────────────────────────────────────────────
check_storage
main_menu


