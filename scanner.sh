#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# FREE FIRE ANTI-CHEAT SCANNER
# Creado por: TIZI.XIT
# Versión: 1.1.0
# ============================================

# Colores
R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
B='\033[1;34m'
M='\033[1;35m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

# Variables globales
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
    for i in $(seq 1 $inner); do
        top+="═"
        bottom+="═"
    done
    top+="╗"
    bottom+="╝"

    _center() {
        local text="$1"
        local len=${#text}
        local left=$(( (inner - len) / 2 ))
        local right=$(( inner - len - left ))
        printf "%${left}s%s%${right}s" "" "$text" ""
    }

    printf "%b\n" "${C}${top}${N}"
    printf "%b\n" "${C}║${M}$( _center "CODE BY TIZI.XIT - ANTI-CHEAT SYSTEM" )${C}║${N}"
    printf "%b\n" "${C}║${M}$( _center "VERSIÓN 1.1.0" )${C}║${N}"
    printf "%b\n" "${C}║${M}$( _center "discord gg/lskcheats" )${C}║${N}"
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
    echo -e "${M}[4]${W} Actualizar scanner${N}"
    echo -e "${R}[S]${W} Salir${N}"
    echo ""
    echo -ne "${Y}Selecciona una opción: ${N}"
    read -r opcao

    case $opcao in
        0) conectar_adb ;;
        1) scan_ff_normal ;;
        2) scan_ff_max ;;
        3) ver_ultimo_log ;;
        4) actualizar_scanner ;;
        s|S) echo -e "\n${W}Gracias por usar el scanner${N}\n"; exit 0 ;;
        *) echo -e "${R}Opción inválida${N}"; sleep 2; main_menu ;;
    esac
}

actualizar_scanner() {
    clear
    banner
    echo -e "${B}[*] Actualizando scanner...${N}\n"
    cd "$(dirname "$0")"
    git fetch origin
    git reset --hard origin/main
    git clean -f -d
    echo -e "\n${G}[✓] Scanner actualizado correctamente${N}"
    echo -e "${Y}[*] Reiniciando...${N}\n"
    sleep 2
    exec bash scanner.sh
}

conectar_adb() {
    clear
    banner
    echo -e "${B}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${B}║           INSTRUCCIONES PARA CONECTAR ADB              ║${N}"
    echo -e "${B}╚════════════════════════════════════════════════════════╝${N}"
    echo -e "${W}1. Ve a: Ajustes > Opciones de Desarrollador${N}"
    echo -e "${W}2. Activa: 'Depuración inalámbrica'${N}"
    echo -e "${W}3. Toca: 'Vincular dispositivo mediante código'${N}"
    echo -e "${W}4. Verás un CÓDIGO de 6 dígitos y una IP:Puerto${N}"
    echo ""
    echo -e "${Y}IMPORTANTE:${N}"
    echo -e "${C}Si dice: 192.168.1.5:${G}41429${C}, solo anota: ${G}41429${N}"
    echo -e "${C}Si dice: Código: ${G}123456${C}, anota: ${G}123456${N}"
    echo ""
    echo -ne "${Y}Código de 6 dígitos: ${N}"
    read -r pair_code

    if [ ${#pair_code} -ne 6 ]; then
        echo -e "${R}[!] Error: El código debe tener 6 dígitos${N}"
        sleep 2; conectar_adb; return
    fi

    echo -ne "${Y}Puerto de pareamiento (solo números): ${N}"
    read -r pair_port_input
    pair_port=$(echo "$pair_port_input" | grep -oE '[0-9]+$' | tail -1)

    if [ -z "$pair_port" ] || [ "$pair_port" -lt 1 ] || [ "$pair_port" -gt 65535 ]; then
        echo -e "${R}[!] Error: Puerto inválido${N}"
        sleep 2; conectar_adb; return
    fi

    echo ""
    echo -e "${B}[*] Pareando con localhost:$pair_port...${N}"
    PAIR_RESULT=$(adb pair localhost:$pair_port $pair_code 2>&1)

    if echo "$PAIR_RESULT" | grep -qi "successfully\|success"; then
        echo -e "${G}[✓] Pareamiento exitoso${N}"
    else
        echo -e "${R}[!] Error en pareamiento${N}"
        echo -e "\n${W}Presiona Enter para volver al menú...${N}"; read
        main_menu; return
    fi

    echo ""
    echo -e "${Y}Ahora CIERRA la ventana del código y mira ARRIBA${N}"
    echo -e "${Y}Verás algo como: 192.168.1.5:${G}37853${N}"
    echo ""
    echo -ne "${Y}Puerto de conexión (solo números): ${N}"
    read -r connect_port_input
    connect_port=$(echo "$connect_port_input" | grep -oE '[0-9]+$' | tail -1)

    if [ -z "$connect_port" ] || [ "$connect_port" -lt 1 ] || [ "$connect_port" -gt 65535 ]; then
        echo -e "${R}[!] Error: Puerto inválido${N}"
        sleep 2; conectar_adb; return
    fi

    echo ""
    echo -e "${B}[*] Conectando a localhost:$connect_port...${N}"
    CONNECT_RESULT=$(adb connect localhost:$connect_port 2>&1)

    if echo "$CONNECT_RESULT" | grep -qi "connected"; then
        echo -e "${G}[✓] Conexión exitosa${N}"
    else
        echo -e "${R}[!] Error en conexión${N}"
    fi

    sleep 1
    if adb devices | grep -q "device$"; then
        echo -e "${G}[✓] Dispositivo conectado correctamente${N}"
    else
        echo -e "${R}[!] El dispositivo no está conectado${N}"
    fi

    echo -e "\n${W}Presiona Enter para volver al menú...${N}"; read
    main_menu
}

scan_ff_normal() {
    GAME_PKG="com.dts.freefireth"
    GAME_SELECTED="Free Fire"
    ejecutar_scan
}

scan_ff_max() {
    GAME_PKG="com.dts.freefiremax"
    GAME_SELECTED="Free Fire MAX"
    ejecutar_scan
}

ver_ultimo_log() {
    clear
    banner
    ULTIMO_LOG=$(ls -t $HOME/anticheat_log_*.txt 2>/dev/null | head -1)
    if [ -z "$ULTIMO_LOG" ]; then
        echo -e "${R}[!] No se encontraron logs guardados${N}"
        echo -e "\n${W}Presiona Enter para volver al menú...${N}"; read
        main_menu; return
    fi
    echo -e "${B}[*] Log: $(basename "$ULTIMO_LOG")${N}"
    echo -e "${C}════════════════════════════════════════════════════════${N}\n"
    cat "$ULTIMO_LOG"
    echo -e "\n${C}════════════════════════════════════════════════════════${N}"
    echo -e "${W}Presiona Enter para volver al menú...${N}"; read
    main_menu
}

# ─────────────────────────────────────────────────────────────
#  EJECUTAR SCAN — llama a todos los módulos en orden
# ─────────────────────────────────────────────────────────────
ejecutar_scan() {
    clear
    banner
    log_output "${B}[*] Escaneando: $GAME_SELECTED${N}\n"

    if ! adb devices | grep -q "device$"; then
        log_output "${R}[!] ERROR: No hay dispositivos conectados por ADB${N}"
        log_output "${Y}[*] Volvé al menú y usá la opción [0] Conectar ADB${N}"
        echo -e "\n${W}Presiona Enter para volver al menú...${N}"; read
        main_menu; return
    fi

    if ! adb shell pm list packages | grep -q "$GAME_PKG"; then
        log_output "${R}[!] $GAME_SELECTED no está instalado${N}"
        sleep 3; main_menu; return
    fi

    # Módulos originales
    check_device_info
    check_root
    check_uptime
    check_background_scripts
    detect_shell_bypass
    check_system_logs
    check_time_changes
    check_playstore_access
    check_clipboard
    check_downloads
    check_vpn_dns
    check_deleted_files
    check_replays
    check_wallhack_bypass
    check_obb

    # ── Módulos nuevos integrados correctamente ──
    check_hooks
    check_root_bypass
    check_fake_time
    check_tooling

    show_summary

    echo -e "\n${W}Presiona Enter para volver al menú...${N}"; read
    main_menu
}

# ─────────────────────────────────────────────────────────────
#  MÓDULOS DE DETECCIÓN
# ─────────────────────────────────────────────────────────────

check_device_info() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}         INFORMACIÓN DEL DISPOSITIVO                   ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    ANDROID_VER=$(adb shell getprop ro.build.version.release | tr -d '\r\n')
    DEVICE_MODEL=$(adb shell getprop ro.product.model | tr -d '\r\n')
    DEVICE_BRAND=$(adb shell getprop ro.product.brand | tr -d '\r\n')
    log_output "${B}[*] Versión de Android: ${W}$ANDROID_VER${N}"
    log_output "${B}[*] Modelo: ${W}$DEVICE_MODEL${N}"
    log_output "${B}[*] Marca: ${W}$DEVICE_BRAND${N}\n"
}

check_root() {
    log_output "${B}[+] Verificando ROOT...${N}"
    if adb shell "command -v su" 2>&1 | grep -q "/su"; then
        log_output "${R}[!] ROOT DETECTADO${N}\n"
        ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] No se detectó ROOT${N}\n"
    fi
}

check_uptime() {
    UPTIME=$(adb shell uptime | tr -d '\r')
    log_output "${B}[*] Uptime: ${W}$UPTIME${N}"
    if echo "$UPTIME" | grep -q "min"; then
        log_output "${R}[!] Reinicio reciente${N}\n"
        ((SUSPICIOUS_COUNT++))
    else
        echo ""
    fi
}

check_background_scripts() {
    log_output "${B}[+] Verificando scripts en segundo plano...${N}"
    SCRIPTS=$(adb shell "pgrep -a bash | grep -v '/usr/bin/bash -l'" 2>/dev/null)
    if [ -n "$SCRIPTS" ]; then
        log_output "${R}[!] SCRIPTS DETECTADOS${N}\n"
        ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Sin scripts sospechosos${N}\n"
    fi
}

detect_shell_bypass() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}         DETECCIÓN DE BYPASS DE FUNCIONES SHELL         ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    BYPASS_DETECTADO=0

    log_output "${B}[+] Verificando funciones maliciosas en el ambiente shell...${N}"
    for func in pkg git cd stat adb; do
        RESULT=$(adb shell "type $func 2>/dev/null | grep -q function && echo FUNCTION_DETECTED" 2>/dev/null | tr -d '\r')
        if echo "$RESULT" | grep -q "FUNCTION_DETECTED"; then
            log_output "${R}[!] BYPASS DETECTADO: Función '$func' fue sobrescrita!${N}"
            ((SUSPICIOUS_COUNT+=2)); BYPASS_DETECTADO=1
        fi
    done

    log_output "${B}[+] Testeando acceso a directorios críticos...${N}"
    CRITICAL_DIRS=("/system/bin" "/data/data/com.dts.freefireth/files" "/data/data/com.dts.freefiremax/files" "/storage/emulated/0/Android/data")
    for dir in "${CRITICAL_DIRS[@]}"; do
        DIR_RESULT=$(adb shell "ls -la \"$dir\" 2>/dev/null | head -3" 2>/dev/null | tr -d '\r')
        if echo "$DIR_RESULT" | grep -qE "blocked|redirected|bypass"; then
            log_output "${R}[!] BYPASS DETECTADO: Acceso bloqueado: $dir${N}"
            ((SUSPICIOUS_COUNT+=2)); BYPASS_DETECTADO=1
        fi
    done

    log_output "${B}[+] Verificando procesos sospechosos...${N}"
    PROC_RESULT=$(adb shell "ps | grep -E '(bypass|redirect|fake)' | grep -vE '(drm_fake_vsync|mtk_drm_fake_vsync)'" 2>/dev/null | tr -d '\r')
    if [ -n "$PROC_RESULT" ]; then
        SUSPICIOUS_PROCS=$(echo "$PROC_RESULT" | grep -v '\[kblockd\]' | grep -v 'kworker' | grep -v 'mtk_drm_fake_vsync')
        if [ -n "$SUSPICIOUS_PROCS" ]; then
            log_output "${R}[!] BYPASS DETECTADO: Procesos sospechosos!${N}"
            ((SUSPICIOUS_COUNT+=2)); BYPASS_DETECTADO=1
        fi
    fi

    log_output "${B}[+] Verificando archivos de configuración del shell...${N}"
    CONFIG_FILES=("~/.bashrc" "~/.bash_profile" "~/.profile" "~/.zshrc" "/data/data/com.termux/files/usr/etc/bash.bashrc")
    for cfg in "${CONFIG_FILES[@]}"; do
        CFG_RESULT=$(adb shell "if [ -f $cfg ]; then cat $cfg | grep -E '(function pkg|function git|function cd|function stat|function adb)' 2>/dev/null; fi" 2>/dev/null | tr -d '\r')
        if [ -n "$(echo "$CFG_RESULT" | tr -d '[:space:]')" ]; then
            log_output "${R}[!] BYPASS DETECTADO: Funciones maliciosas en $cfg!${N}"
            ((SUSPICIOUS_COUNT+=2)); BYPASS_DETECTADO=1
        fi
    done

    log_output "${B}[+] Testeando comportamiento de git...${N}"
    GIT_HELP=$(adb shell "git clone --help 2>&1 | head -1" 2>/dev/null | tr -d '\r')
    if [ -z "$GIT_HELP" ] || ! echo "$GIT_HELP" | grep -q "usage: git"; then
        CLONE_RESULT=$(adb shell "cd /data/local/tmp; timeout 5 git clone https://github.com/kellerzz/KellerSS-Android test-repo 2>&1 | head -3" 2>/dev/null | tr -d '\r')
        if echo "$CLONE_RESULT" | grep -qE "wendell77x|Comando bloqueado|blocked"; then
            log_output "${R}[!] BYPASS DETECTADO: Git clone redireccionado!${N}"
            ((SUSPICIOUS_COUNT+=2)); BYPASS_DETECTADO=1
        fi
    fi

    log_output "${B}[+] Testeando integridad de comandos básicos...${N}"
    ECHO_RESULT=$(adb shell "echo test123" | tr -d '\r')
    if [ "$ECHO_RESULT" != "test123" ]; then
        log_output "${R}[!] BYPASS DETECTADO: Comando 'echo' manipulado!${N}"
        ((SUSPICIOUS_COUNT+=2)); BYPASS_DETECTADO=1
    fi
    CURRENT_YEAR=$(date +%Y)
    DATE_RESULT=$(adb shell "date +%Y 2>/dev/null" | tr -d '\r')
    if [ -z "$DATE_RESULT" ] || [ "$DATE_RESULT" != "$CURRENT_YEAR" ]; then
        log_output "${R}[!] BYPASS DETECTADO: Comando 'date' manipulado!${N}"
        ((SUSPICIOUS_COUNT+=2)); BYPASS_DETECTADO=1
    fi

    log_output "${B}[+] Verificando archivos de bypass en el dispositivo...${N}"
    BYPASS_FILES=$(adb shell 'find /sdcard /data/local/tmp /data/data/com.termux/files/home -name "*.sh" -exec grep -l "function pkg\|function git\|function adb\|wendell77x" {} \; 2>/dev/null | head -10' 2>/dev/null | tr -d '\r')
    if [ -n "$(echo "$BYPASS_FILES" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] BYPASS DETECTADO: Archivos de bypass encontrados!${N}"
        ((SUSPICIOUS_COUNT+=2)); BYPASS_DETECTADO=1
    fi

    if [ $BYPASS_DETECTADO -eq 1 ]; then
        log_output "${R}[!] ¡BYPASS DE FUNCIONES SHELL DETECTADO! ¡APLICA EL W.O!${N}\n"
    else
        log_output "${G}[✓] Ningún bypass de funciones shell detectado.${N}\n"
    fi
}

check_system_logs() {
    log_output "${B}[+] Verificando logs del sistema...${N}"
    FIRST_LOG=$(adb logcat -d -v time 2>/dev/null | grep -oE "[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" | head -1)
    log_output "${Y}[*] Primera log: $FIRST_LOG${N}\n"
}

check_time_changes() {
    log_output "${B}[+] Verificando cambios de fecha/hora...${N}"
    TIME_CHANGES=$(adb logcat -d 2>/dev/null | grep "Time changed" | grep -v "HCALL" | tail -3)
    if [ -n "$TIME_CHANGES" ]; then
        log_output "${R}[!] CAMBIOS DE HORA DETECTADOS${N}\n"
        ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] Sin cambios${N}\n"
    fi
}

check_playstore_access() {
    log_output "${B}[+] Verificando accesos a Play Store...${N}"
    PLAY=$(adb shell dumpsys usagestats 2>/dev/null | grep "com.android.vending" | grep "MOVE_TO_FOREGROUND" | tail -3)
    if [ -n "$PLAY" ]; then
        log_output "${Y}[*] Accesos recientes detectados${N}\n"
    else
        log_output "${G}[✓] Sin accesos${N}\n"
    fi
}

check_clipboard() {
    log_output "${B}[+] Verificando clipboard...${N}"
    CLIP=$(adb logcat -d 2>/dev/null | grep 'hcallSetClipboardTextRpc' | tail -5)
    if [ -n "$CLIP" ]; then
        log_output "${Y}[*] Textos copiados detectados${N}\n"
    else
        log_output "${G}[✓] Sin datos${N}\n"
    fi
}

check_downloads() {
    log_output "${B}[+] Escaneando Downloads...${N}"
    APKS=$(adb shell "find /sdcard/Download /sdcard/Downloads -name '*.apk' 2>/dev/null" | tr -d '\r')
    FOUND=0
    while read -r apk; do
        [ -z "$apk" ] && continue
        NAME=$(basename "$apk" | tr '[:upper:]' '[:lower:]')
        if echo "$NAME" | grep -qiE "hack|cheat|mod|panel|lucky|gg|magisk"; then
            log_output "${R}[!] APK SOSPECHOSO: $NAME${N}"
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
    VPN_PACKAGES=("com.nordvpn.android" "net.openvpn.openvpn" "com.expressvpn.vpn" "com.surfshark.vpnclient.android" "com.cloudflare.onedotonedotonedotone" "com.protonvpn.android" "de.blinkt.openvpn" "com.psiphon3" "com.v2ray.ang" "com.shadowsocks.vpn")
    VPN_DETECTED=0
    for pkg in "${VPN_PACKAGES[@]}"; do
        if adb shell pm list packages 2>/dev/null | grep -q "$pkg"; then
            APP_NAME=$(echo "$pkg" | rev | cut -d'.' -f1 | rev)
            log_output "${R}[!] VPN INSTALADA: $APP_NAME${N}"
            VPN_DETECTED=1; ((SUSPICIOUS_COUNT++))
        fi
    done

    VPN_INTERFACE=$(adb shell "ip link show" 2>/dev/null | grep -iE "tun|tap|ppp|ipsec" | grep -v "LOOPBACK")
    if [ -n "$VPN_INTERFACE" ]; then
        log_output "${R}[!] INTERFAZ VPN ACTIVA DETECTADA${N}"
        VPN_DETECTED=1; ((SUSPICIOUS_COUNT+=2))
    fi

    VPN_PROCESS=$(adb shell "ps -A" 2>/dev/null | grep -iE "vpn|openvpn|wireguard|shadowsocks|v2ray|clash" | grep -v "grep")
    if [ -n "$VPN_PROCESS" ]; then
        log_output "${R}[!] PROCESO VPN ACTIVO${N}"
        VPN_DETECTED=1; ((SUSPICIOUS_COUNT+=2))
    fi

    [ $VPN_DETECTED -eq 0 ] && log_output "${G}[✓] No se detectaron VPNs${N}"
    echo ""

    log_output "${B}[+] Verificando DNS modificados...${N}"
    DNS_SERVERS=$(adb shell "getprop | grep dns" 2>/dev/null | tr -d '\r')
    if [ -n "$DNS_SERVERS" ]; then
        CUSTOM_DNS=$(echo "$DNS_SERVERS" | grep -E "1\.1\.1\.1|8\.8\.8\.8|9\.9\.9\.9|cloudflare|google")
        [ -n "$CUSTOM_DNS" ] && { log_output "${Y}[!] DNS PERSONALIZADO DETECTADO${N}"; ((SUSPICIOUS_COUNT++)); }
    fi

    PRIVATE_DNS=$(adb shell "settings get global private_dns_mode" 2>/dev/null | tr -d '\r')
    if [ "$PRIVATE_DNS" = "hostname" ] || [ "$PRIVATE_DNS" = "opportunistic" ]; then
        log_output "${Y}[!] DNS PRIVADO ACTIVO${N}"
        ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] DNS privado no configurado${N}"
    fi
    echo ""

    log_output "${B}[+] Verificando Proxy configurado...${N}"
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

    log_output "${B}[+] Verificando carpetas vacías sospechosas...${N}"
    CRITICAL_FOLDERS=("$GAME_DATA_DIR/files/contentcache" "$GAME_DATA_DIR/files/MReplays" "$GAME_DATA_DIR/cache" "$GAME_OBB_DIR")
    EMPTY_DETECTED=0
    for folder in "${CRITICAL_FOLDERS[@]}"; do
        if adb shell "[ -d '$folder' ]" 2>/dev/null; then
            FILE_COUNT=$(adb shell "find '$folder' -type f 2>/dev/null | wc -l" | tr -d '\r')
            FOLDER_NAME=$(basename "$folder")
            if [ "$FILE_COUNT" -eq 0 ]; then
                log_output "${R}[!] CARPETA VACÍA SOSPECHOSA: $FOLDER_NAME${N}"
                EMPTY_DETECTED=1; ((SUSPICIOUS_COUNT+=2))
            fi
        fi
    done
    [ $EMPTY_DETECTED -eq 0 ] && log_output "${G}[✓] Todas las carpetas contienen archivos${N}"
    echo ""

    log_output "${B}[+] Verificando modificaciones recientes en carpetas críticas...${N}"
    for folder in "${CRITICAL_FOLDERS[@]}"; do
        if adb shell "[ -d '$folder' ]" 2>/dev/null; then
            FOLDER_STAT=$(adb shell "stat '$folder' 2>/dev/null")
            CHANGE_TIME=$(echo "$FOLDER_STAT" | grep "Change:" | awk '{print $2" "$3}' | cut -d'.' -f1)
            if [ -n "$CHANGE_TIME" ]; then
                CHANGE_EPOCH=$(date -d "$CHANGE_TIME" +%s 2>/dev/null || echo 0)
                CURRENT_EPOCH=$(date +%s)
                TIME_DIFF=$((CURRENT_EPOCH - CHANGE_EPOCH))
                if [ $TIME_DIFF -lt 10800 ] && [ $TIME_DIFF -gt 0 ]; then
                    HOURS_AGO=$((TIME_DIFF / 3600))
                    MINS_AGO=$(((TIME_DIFF % 3600) / 60))
                    FOLDER_NAME=$(basename "$folder")
                    log_output "${Y}[!] Carpeta modificada recientemente: $FOLDER_NAME (hace ${HOURS_AGO}h ${MINS_AGO}m)${N}"
                    ((SUSPICIOUS_COUNT++))
                fi
            fi
        fi
    done
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
        log_output "${R}[!] Sin replays en MReplays (sospechoso)${N}"
        MOTIVOS+=("Motivo 10 - Ningún archivo .bin en MReplays")
        ((SUSPICIOUS_COUNT+=2))
    fi

    GAME_VERSION_INSTALLED=""
    DUMPSYS_PKG=$(adb shell "dumpsys package $GAME_PKG 2>/dev/null" | tr -d '\r')
    if [ -n "$DUMPSYS_PKG" ]; then
        GAME_VERSION_INSTALLED=$(echo "$DUMPSYS_PKG" | grep "versionName=" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    fi

    ULTIMO_MODIFY_TS=0
    ULTIMO_CHANGE_TS=0
    ARCHIVO_MAS_RECIENTE=""
    PRIMER_ARCHIVO=1

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
        TS_C=$(date -d "${DC%%.*}" +%s 2>/dev/null || echo 0)

        if [ $PRIMER_ARCHIVO -eq 1 ]; then
            ULTIMO_MODIFY_TS=$TS_M
            ULTIMO_CHANGE_TS=$TS_C
            ARCHIVO_MAS_RECIENTE="$bin"
            PRIMER_ARCHIVO=0
        fi

        [ "$TS_A" -gt "$TS_M" ] 2>/dev/null && MOTIVOS+=("Motivo 1 - Access posterior a Modify: $FNAME")

        NANOS_A=$(echo "$DA" | grep -oE '\.[0-9]+$')
        NANOS_M=$(echo "$DM" | grep -oE '\.[0-9]+$')
        NANOS_C=$(echo "$DC" | grep -oE '\.[0-9]+$')
        echo "$NANOS_A$NANOS_M$NANOS_C" | grep -qE '\.0+$' && MOTIVOS+=("Motivo 2 - Timestamps .000: $FNAME")

        [ "$DM" != "$DC" ] && MOTIVOS+=("Motivo 3 - Modify ≠ Change: $FNAME")

        NAME_DATE=$(echo "$FNAME" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}' | head -1)
        if [ -n "$NAME_DATE" ]; then
            NAME_NORMALIZED=$(echo "$NAME_DATE" | sed 's/^\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)$/\1-\2-\3 \4:\5:\6/')
            TS_NAME=$(date -d "$NAME_NORMALIZED" +%s 2>/dev/null || echo 0)
            DIFF_NAME=$(( TS_NAME > TS_M ? TS_NAME - TS_M : TS_M - TS_NAME ))
            [ "$DIFF_NAME" -gt 1 ] 2>/dev/null && MOTIVOS+=("Motivo 4 - Nombre no coincide con Modify: $FNAME")
        fi

        JSON_PATH="${bin%.bin}.json"
        JSON_STAT=$(adb shell "stat '$JSON_PATH' 2>/dev/null" | tr -d '\r')
        if [ -z "$JSON_STAT" ]; then
            MOTIVOS+=("Motivo 8 - JSON ausente: $(basename "$JSON_PATH")")
        else
            JSON_DA=$(echo "$JSON_STAT" | grep "^Access:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
            [ "$JSON_DA" != "$DA" ] && [ "$JSON_DA" != "$DM" ] && [ "$JSON_DA" != "$DC" ] && MOTIVOS+=("Motivo 8 - Access JSON diferente: $(basename "$JSON_PATH")")
        fi

        if [ -n "$GAME_VERSION_INSTALLED" ]; then
            JSON_CONTENT=$(adb shell "cat '$JSON_PATH' 2>/dev/null" | tr -d '\r')
            if [ -n "$JSON_CONTENT" ]; then
                VERSION_JSON=$(echo "$JSON_CONTENT" | grep -oE '"Version":"[^"]*"' | grep -oE ':[^}]*' | tr -d ':"')
                [ -n "$VERSION_JSON" ] && [ "$VERSION_JSON" != "$GAME_VERSION_INSTALLED" ] && \
                    MOTIVOS+=("Motivo 14 - Replay de otra versión ($VERSION_JSON vs $GAME_VERSION_INSTALLED): $(basename "$JSON_PATH")")
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
        PM_NANOS=$(echo "$PM" | grep -oE '\.[0-9]+$')
        PC_NANOS=$(echo "$PC" | grep -oE '\.[0-9]+$')
        echo "$PM_NANOS$PC_NANOS" | grep -qE '\.0+$' && MOTIVOS+=("Motivo 6 - Milisegundos .000 en carpeta")
        [ "$TS_PM" -gt "$ULTIMO_MODIFY_TS" ] && [ "$ULTIMO_MODIFY_TS" -gt 0 ] 2>/dev/null && MOTIVOS+=("Motivo 7 - Carpeta modificada después del último replay (Modify)")
        [ "$TS_PC" -gt "$ULTIMO_CHANGE_TS" ] && [ "$ULTIMO_CHANGE_TS" -gt 0 ] 2>/dev/null && MOTIVOS+=("Motivo 7 - Carpeta modificada después del último replay (Change)")
        [ "$PM" != "$PC" ] && [ -n "$PM" ] && MOTIVOS+=("Motivo 11 - Modify ≠ Change en carpeta MReplays")
    fi

    echo ""
    if [ ${#MOTIVOS[@]} -gt 0 ]; then
        log_output "${R}[!] REPLAY PASADO DETECTADO - ¡APLICA EL W.O!${N}"
        for motivo in "${MOTIVOS[@]}"; do
            log_output "${Y}    - $motivo${N}"
        done
        ((SUSPICIOUS_COUNT+=3))
    else
        log_output "${G}[✓] Replays normales, carpeta MReplays sin anomalías.${N}"
    fi
    echo ""
}

check_wallhack_bypass() {
    log_output "${B}[+] Detectando shaders modificados...${N}"
    SHADER_DIR="/sdcard/Android/data/$GAME_PKG/files/contentcache/Optional/android/gameassetbundles"
    SHADERS=$(adb shell "find '$SHADER_DIR' -name 'shader*' 2>/dev/null" | tr -d '\r' | head -3)
    if [ -z "$SHADERS" ]; then
        log_output "${G}[✓] Sin shaders modificados${N}\n"; return
    fi
    echo "$SHADERS" | while read -r shader; do
        UNITY=$(adb shell "head -c 7 '$shader' 2>/dev/null")
        if [ "$UNITY" != "UnityFS" ]; then
            log_output "${R}[!] SHADER INVÁLIDO: $(basename "$shader")${N}"
            ((SUSPICIOUS_COUNT+=3))
        fi
    done
    log_output "${G}[✓] Verificación completada${N}\n"
}

check_obb() {
    log_output "${B}[+] Verificando OBB...${N}"
    OBB=$(adb shell "ls '/sdcard/Android/obb/$GAME_PKG' 2>/dev/null" | tr -d '\r')
    if [ -z "$OBB" ]; then
        log_output "${R}[!] OBB no encontrado${N}\n"
        ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] OBB presente${N}\n"
    fi
}

# ─────────────────────────────────────────────────────────────
#  MÓDULOS NUEVOS — correctamente integrados con ADB
# ─────────────────────────────────────────────────────────────

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
    HOOK_FILES=$(adb shell "find /data /system 2>/dev/null | grep -iE 'frida|xposed|lsposed' | head -10" | tr -d '\r')
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

    log_output "${B}[+] Verificando Magisk, Shamiko, Zygisk, Busybox...${N}"

    # Verificar via getprop
    BYPASS_PROP=$(adb shell "getprop 2>/dev/null | grep -iE 'magisk|shamiko|zygisk'" | tr -d '\r')
    if [ -n "$BYPASS_PROP" ]; then
        log_output "${R}[!] ROOT BYPASS DETECTADO (getprop)${N}"
        echo "$BYPASS_PROP" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=3))
    fi

    # Verificar via ps
    BYPASS_PS=$(adb shell "ps -A 2>/dev/null | grep -iE 'magisk|shamiko|zygisk|busybox|brevent'" | tr -d '\r')
    if [ -n "$BYPASS_PS" ]; then
        log_output "${R}[!] ROOT BYPASS DETECTADO (proceso)${N}"
        echo "$BYPASS_PS" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=3))
    fi

    # Verificar archivos conocidos de Magisk
    MAGISK_FILES=$(adb shell "ls /data/adb/magisk 2>/dev/null" | tr -d '\r')
    if [ -n "$MAGISK_FILES" ]; then
        log_output "${R}[!] MAGISK DETECTADO (/data/adb/magisk existe)${N}"
        ((SUSPICIOUS_COUNT+=3))
    fi

    if [ -z "$BYPASS_PROP" ] && [ -z "$BYPASS_PS" ] && [ -z "$MAGISK_FILES" ]; then
        log_output "${G}[✓] Sin root bypass avanzado detectado${N}"
    fi
    echo ""
}

check_fake_time() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}          DETECCIÓN DE TIEMPO FALSO / CONGELADO         ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Verificando si el tiempo avanza normalmente...${N}"

    # Tomar dos timestamps con 1 segundo de diferencia
    T1=$(adb shell "date +%s 2>/dev/null" | tr -d '\r')
    sleep 1
    T2=$(adb shell "date +%s 2>/dev/null" | tr -d '\r')

    if [ -n "$T1" ] && [ -n "$T2" ]; then
        DIFF=$((T2 - T1))
        if [ "$DIFF" -lt 1 ]; then
            log_output "${R}[!] TIEMPO CONGELADO O FALSO DETECTADO${N}"
            log_output "${Y}    T1=$T1 T2=$T2 Diferencia=$DIFF${N}"
            ((SUSPICIOUS_COUNT+=3))
        else
            log_output "${G}[✓] El tiempo avanza normalmente${N}"
        fi
    fi

    # Verificar inconsistencia via stat
    log_output "${B}[+] Verificando inconsistencia de tiempo via stat...${N}"
    TEST_FILE="/data/local/tmp/.time_test_$$"
    adb shell "echo test > $TEST_FILE 2>/dev/null" >/dev/null 2>&1
    sleep 1
    STAT_RESULT=$(adb shell "stat $TEST_FILE 2>/dev/null" | tr -d '\r')
    adb shell "rm -f $TEST_FILE 2>/dev/null" >/dev/null 2>&1

    if echo "$STAT_RESULT" | grep -q "1970"; then
        log_output "${R}[!] INCONSISTENCIA DE TIEMPO DETECTADA (año 1970 en stat)${N}"
        ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Timestamps de stat consistentes${N}"
    fi
    echo ""
}

check_tooling() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}     HERRAMIENTAS SOSPECHOSAS / EMULADOR                ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    log_output "${B}[+] Verificando herramientas sospechosas y entorno virtual...${N}"

    TOOL_PS=$(adb shell "ps -A 2>/dev/null | grep -iE 'vysor|frida-server|genymotion|panda'" | tr -d '\r')
    TOOL_PROP=$(adb shell "getprop 2>/dev/null | grep -iE 'qemu|goldfish|vbox|genymotion|nox|memu|bluestacks'" | tr -d '\r')

    if [ -n "$TOOL_PS" ]; then
        log_output "${R}[!] HERRAMIENTA SOSPECHOSA DETECTADA (proceso)${N}"
        echo "$TOOL_PS" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=2))
    fi

    if [ -n "$TOOL_PROP" ]; then
        log_output "${R}[!] ENTORNO VIRTUAL/EMULADOR DETECTADO${N}"
        echo "$TOOL_PROP" | while read -r line; do log_output "${Y}  $line${N}"; done
        ((SUSPICIOUS_COUNT+=2))
    fi

    if [ -z "$TOOL_PS" ] && [ -z "$TOOL_PROP" ]; then
        log_output "${G}[✓] Sin herramientas sospechosas ni emulador detectado${N}"
    fi
    echo ""
}

show_summary() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}              RESUMEN DEL ANÁLISIS                     ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    log_output "${B}[*] Juego: ${W}$GAME_SELECTED${N}"
    log_output "${B}[*] Elementos sospechosos: ${W}$SUSPICIOUS_COUNT${N}\n"

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

    log_output "\n${M}[*] Log guardado: ${W}$LOGFILE${N}"
}

# ─────────────────────────────────────────────────────────────
#  INICIO
# ─────────────────────────────────────────────────────────────
check_storage
main_menu
