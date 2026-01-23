
#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# FREE FIRE ANTI-CHEAT SCANNER
# Creado por: TIZI.XIT
# Versión: 1.0.0 Beta
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

# Banner inicial
banner() {
    clear
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║${M}          CODE BY TIZI.XIT - ANTI-CHEAT SYSTEM          ${C}║${N}"
    echo -e "${C}║${M}                   VERSIÓN BETA 1.0                     ${C}║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    echo -e "${Y}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${Y}║  ⚠️  ESTE SCANNER ESTÁ EN PROCESO DE DESARROLLO  ⚠️    ║${N}"
    echo -e "${Y}║   SE RECOMIENDA HACER REVISIÓN MANUAL ADICIONAL       ║${N}"
    echo -e "${Y}║         PARA MAYOR SEGURIDAD Y PRECISIÓN              ║${N}"
    echo -e "${Y}╚════════════════════════════════════════════════════════╝${N}"
    echo ""
    sleep 3
}

# Función de logging
log_output() {
    echo -e "${1}" | tee -a "$LOGFILE"
}

# Verificar permisos
check_storage() {
    if [ ! -d "$HOME/storage" ]; then
        echo -e "${Y}[*] Configurando permisos de almacenamiento...${N}"
        termux-setup-storage
        sleep 2
    fi
}

# Menú principal
main_menu() {
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

# Actualizar scanner
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

# Conectar ADB
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
        sleep 2
        conectar_adb
        return
    fi
    
    echo -ne "${Y}Puerto de pareamiento (solo números): ${N}"
    read -r pair_port_input
    pair_port=$(echo "$pair_port_input" | grep -oE '[0-9]+$' | tail -1)
    
    if [ -z "$pair_port" ] || [ "$pair_port" -lt 1 ] || [ "$pair_port" -gt 65535 ]; then
        echo -e "${R}[!] Error: Puerto inválido${N}"
        sleep 2
        conectar_adb
        return
    fi
    
    echo ""
    echo -e "${B}[*] Pareando con localhost:$pair_port...${N}"
    PAIR_RESULT=$(adb pair localhost:$pair_port $pair_code 2>&1)
    
    if echo "$PAIR_RESULT" | grep -qi "successfully\|success"; then
        echo -e "${G}[✓] Pareamiento exitoso${N}"
    else
        echo -e "${R}[!] Error en pareamiento${N}"
        echo -e "\n${W}Presiona Enter para volver al menú...${N}"
        read
        main_menu
        return
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
        sleep 2
        conectar_adb
        return
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
    
    echo -e "\n${W}Presiona Enter para volver al menú...${N}"
    read
    main_menu
}

# Escanear Free Fire Normal
scan_ff_normal() {
    GAME_PKG="com.dts.freefireth"
    GAME_SELECTED="Free Fire"
    ejecutar_scan
}

# Escanear Free Fire MAX
scan_ff_max() {
    GAME_PKG="com.dts.freefiremax"
    GAME_SELECTED="Free Fire MAX"
    ejecutar_scan
}

# Ver último log
ver_ultimo_log() {
    clear
    banner
    
    ULTIMO_LOG=$(ls -t $HOME/anticheat_log_*.txt 2>/dev/null | head -1)
    
    if [ -z "$ULTIMO_LOG" ]; then
        echo -e "${R}[!] No se encontraron logs guardados${N}"
        echo -e "\n${W}Presiona Enter para volver al menú...${N}"
        read
        main_menu
        return
    fi
    
    echo -e "${B}[*] Log: $(basename "$ULTIMO_LOG")${N}"
    echo -e "${C}════════════════════════════════════════════════════════${N}\n"
    
    cat "$ULTIMO_LOG"
    
    echo -e "\n${C}════════════════════════════════════════════════════════${N}"
    echo -e "${W}Presiona Enter para volver al menú...${N}"
    read
    main_menu
}

# Ejecutar escaneo completo
ejecutar_scan() {
    clear
    banner
    
    log_output "${B}[*] Escaneando: $GAME_SELECTED${N}\n"
    
    if ! adb devices | grep -q "device$"; then
        log_output "${R}[!] ERROR: No hay dispositivos conectados por ADB${N}"
        log_output "${Y}[*] SOLUCIÓN:${N}"
        log_output "${W}   1. Vuelve al menú principal${N}"
        log_output "${W}   2. Selecciona opción [0] Conectar ADB${N}"
        log_output "${W}   3. Sigue las instrucciones${N}"
        echo ""
        echo -e "${W}Presiona Enter para volver al menú...${N}"
        read
        main_menu
        return
    fi
    
    if ! adb shell pm list packages | grep -q "$GAME_PKG"; then
        log_output "${R}[!] $GAME_SELECTED no está instalado${N}"
        sleep 3
        main_menu
        return
    fi
    
    # Ejecutar análisis
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
    show_summary
    
    echo -e "\n${W}Presiona Enter para volver al menú...${N}"
    read
    main_menu
}

# [AQUÍ VAN TODAS LAS FUNCIONES DE DETECCIÓN]
# (Las copio del artifact anterior pero resumidas)

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
    log_output "${B}[+] Detectando bypass de funciones...${N}"
    for func in pkg git cd stat adb; do
        if adb shell "type $func 2>/dev/null | grep -q function"; then
            log_output "${R}[!] BYPASS: función '$func' sobrescrita${N}"
            ((SUSPICIOUS_COUNT+=2))
        fi
    done
    log_output "${G}[✓] Verificación completada${N}\n"
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
    echo "$APKS" | while read -r apk; do
        [ -z "$apk" ] && continue
        NAME=$(basename "$apk" | tr '[:upper:]' '[:lower:]')
        if echo "$NAME" | grep -qiE "hack|cheat|mod|panel|lucky|gg|magisk"; then
            log_output "${R}[!] APK SOSPECHOSO: $NAME${N}"
            FOUND=1
        fi
    done
    if [ $FOUND -eq 0 ]; then
        log_output "${G}[✓] Sin APKs sospechosos${N}\n"
    else
        ((SUSPICIOUS_COUNT+=2))
        echo ""
    fi
}

# Detección de VPN/DNS/Proxy
check_vpn_dns() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}       DETECCIÓN DE VPN/DNS/PROXY                      ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    
    # 1. Detectar VPN activas
    log_output "${B}[+] Verificando VPN activas...${N}"
    
    # Apps VPN conocidas
    VPN_PACKAGES=(
        "com.nordvpn.android"
        "net.openvpn.openvpn"
        "com.expressvpn.vpn"
        "com.surfshark.vpnclient.android"
        "com.privacyvpn.pvpn"
        "com.cloudflare.onedotonedotonedotone"
        "com.protonvpn.android"
        "com.vyprvpn.vyprvpn"
        "com.tunnelbear.android"
        "de.blinkt.openvpn"
        "com.hotspotshield.vpn.ui"
        "com.psiphon3"
        "org.torproject.android"
        "com.anchorfree.hss"
        "com.ultrasurf.ultrasurf"
        "com.vpn.proxy.master"
        "free.vpn.unblock.proxy"
        "com.freevpn.vpn"
        "com.shadowsocks.vpn"
        "com.v2ray.ang"
    )
    
    VPN_DETECTED=0
    for pkg in "${VPN_PACKAGES[@]}"; do
        if adb shell pm list packages 2>/dev/null | grep -q "$pkg"; then
            APP_NAME=$(echo "$pkg" | rev | cut -d'.' -f1 | rev)
            log_output "${R}[!] VPN INSTALADA: $APP_NAME${N}"
            VPN_DETECTED=1
            ((SUSPICIOUS_COUNT++))
        fi
    done
    
    # Verificar interfaces de red VPN
    VPN_INTERFACE=$(adb shell "ip link show" 2>/dev/null | grep -iE "tun|tap|ppp|ipsec" | grep -v "LOOPBACK")
    if [ -n "$VPN_INTERFACE" ]; then
        log_output "${R}[!] INTERFAZ VPN ACTIVA DETECTADA${N}"
        log_output "${Y}$(echo "$VPN_INTERFACE" | head -3)${N}"
        VPN_DETECTED=1
        ((SUSPICIOUS_COUNT+=2))
    fi
    
    # Verificar procesos VPN activos
    VPN_PROCESS=$(adb shell "ps -A" 2>/dev/null | grep -iE "vpn|openvpn|wireguard|shadowsocks|v2ray|clash|tunnel" | grep -v "grep")
    if [ -n "$VPN_PROCESS" ]; then
        log_output "${R}[!] PROCESO VPN ACTIVO${N}"
        echo "$VPN_PROCESS" | head -3 | while read -r line; do
            log_output "${Y}  $line${N}"
        done
        VPN_DETECTED=1
        ((SUSPICIOUS_COUNT+=2))
    fi
    
    if [ $VPN_DETECTED -eq 0 ]; then
        log_output "${G}[✓] No se detectaron VPNs${N}"
    fi
    
    echo ""
    
    # 2. Detectar DNS modificados
    log_output "${B}[+] Verificando DNS modificados...${N}"
    
    # Obtener DNS actual
    DNS_SERVERS=$(adb shell "getprop | grep dns" 2>/dev/null | tr -d '\r')
    
    if [ -n "$DNS_SERVERS" ]; then
        log_output "${W}DNS actuales:${N}"
        echo "$DNS_SERVERS" | while read -r dns; do
            log_output "${Y}  $dns${N}"
        done
        
        # DNS públicos conocidos (sospechosos para evadir detección)
        CUSTOM_DNS=$(echo "$DNS_SERVERS" | grep -E "1\.1\.1\.1|8\.8\.8\.8|8\.8\.4\.4|9\.9\.9\.9|208\.67\.222\.222|1\.0\.0\.1|quad9|cloudflare|google")
        
        if [ -n "$CUSTOM_DNS" ]; then
            log_output "${Y}[!] DNS PERSONALIZADO DETECTADO (Cloudflare/Google/Quad9)${N}"
            log_output "${W}Esto puede usarse para evadir bloqueos${N}"
            ((SUSPICIOUS_COUNT++))
        fi
    fi
    
    # Verificar Private DNS (DNS sobre TLS/HTTPS)
    PRIVATE_DNS=$(adb shell "settings get global private_dns_mode" 2>/dev/null | tr -d '\r')
    
    if [ "$PRIVATE_DNS" = "hostname" ] || [ "$PRIVATE_DNS" = "opportunistic" ]; then
        PRIVATE_DNS_HOST=$(adb shell "settings get global private_dns_specifier" 2>/dev/null | tr -d '\r')
        log_output "${Y}[!] DNS PRIVADO ACTIVO: $PRIVATE_DNS${N}"
        if [ -n "$PRIVATE_DNS_HOST" ]; then
            log_output "${Y}    Servidor: $PRIVATE_DNS_HOST${N}"
        fi
        ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] DNS privado no configurado${N}"
    fi
    
    echo ""
    
    # 3. Detectar Proxy
    log_output "${B}[+] Verificando Proxy configurado...${N}"
    
    # Proxy HTTP
    HTTP_PROXY=$(adb shell "settings get global http_proxy" 2>/dev/null | tr -d '\r')
    if [ -n "$HTTP_PROXY" ] && [ "$HTTP_PROXY" != "null" ] && [ "$HTTP_PROXY" != ":0" ]; then
        log_output "${R}[!] PROXY HTTP CONFIGURADO: $HTTP_PROXY${N}"
        ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Sin proxy HTTP${N}"
    fi
    
    # Verificar variables de entorno proxy
    PROXY_ENV=$(adb shell "printenv | grep -i proxy" 2>/dev/null)
    if [ -n "$PROXY_ENV" ]; then
        log_output "${Y}[!] Variables de proxy en entorno:${N}"
        echo "$PROXY_ENV" | while read -r line; do
            log_output "${Y}  $line${N}"
        done
        ((SUSPICIOUS_COUNT++))
    fi
    
    echo ""
}

# Detección de archivos eliminados recientemente
check_deleted_files() {
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}    ARCHIVOS ELIMINADOS RECIENTEMENTE (GAME DATA)      ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"
    
    GAME_DATA_DIR="/sdcard/Android/data/$GAME_PKG"
    GAME_OBB_DIR="/sdcard/Android/obb/$GAME_PKG"
    
    log_output "${B}[+] Analizando logs del sistema para archivos eliminados...${N}"
    
    # Buscar logs de archivos eliminados (últimas 24 horas)
    DELETED_LOGS=$(adb logcat -d -v time 2>/dev/null | grep -iE "delete|remove|unlink" | grep -E "$GAME_PKG|freefir" | tail -20)
    
    if [ -n "$DELETED_LOGS" ]; then
        log_output "${Y}[*] Actividad de eliminación detectada en logs:${N}"
        echo "$DELETED_LOGS" | while read -r line; do
            log_output "${W}  $line${N}"
        done
        ((SUSPICIOUS_COUNT++))
    fi
    
    echo ""
    
    # Verificar carpetas vacías sospechosas
    log_output "${B}[+] Verificando carpetas vacías sospechosas...${N}"
    
    CRITICAL_FOLDERS=(
        "$GAME_DATA_DIR/files/contentcache"
        "$GAME_DATA_DIR/files/MReplays"
        "$GAME_DATA_DIR/cache"
        "$GAME_OBB_DIR"
    )
    
    EMPTY_DETECTED=0
    for folder in "${CRITICAL_FOLDERS[@]}"; do
        if adb shell "[ -d '$folder' ]" 2>/dev/null; then
            FILE_COUNT=$(adb shell "find '$folder' -type f 2>/dev/null | wc -l" | tr -d '\r')
            FOLDER_NAME=$(basename "$folder")
            
            if [ "$FILE_COUNT" -eq 0 ]; then
                log_output "${R}[!] CARPETA VACÍA SOSPECHOSA: $FOLDER_NAME${N}"
                log_output "${Y}    Ruta: $folder${N}"
                EMPTY_DETECTED=1
                ((SUSPICIOUS_COUNT+=2))
            fi
        fi
    done
    
    if [ $EMPTY_DETECTED -eq 0 ]; then
        log_output "${G}[✓] Todas las carpetas contienen archivos${N}"
    fi
    
    echo ""
    
    # Buscar archivos .tmp o temporales (indicativo de eliminación reciente)
    log_output "${B}[+] Buscando archivos temporales sospechosos...${N}"
    
    TMP_FILES=$(adb shell "find '$GAME_DATA_DIR' -name '*.tmp' -o -name '*.bak' -o -name '*~' 2>/dev/null" | tr -d '\r')
    
    if [ -n "$TMP_FILES" ]; then
        log_output "${Y}[*] Archivos temporales encontrados:${N}"
        echo "$TMP_FILES" | head -5 | while read -r tmp; do
            [ -z "$tmp" ] && continue
            log_output "${W}  $(basename "$tmp")${N}"
        done
        ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] Sin archivos temporales sospechosos${N}"
    fi
    
    echo ""
    
    # Verificar timestamp de carpetas (si fue modificada recientemente, pueden haber borrado algo)
    log_output "${B}[+] Verificando modificaciones recientes en carpetas críticas...${N}"
    
    for folder in "${CRITICAL_FOLDERS[@]}"; do
        if adb shell "[ -d '$folder' ]" 2>/dev/null; then
            FOLDER_STAT=$(adb shell "stat '$folder' 2>/dev/null")
            CHANGE_TIME=$(echo "$FOLDER_STAT" | grep "Change:" | awk '{print $2" "$3}' | cut -d'.' -f1)
            
            if [ -n "$CHANGE_TIME" ]; then
                CHANGE_EPOCH=$(date -d "$CHANGE_TIME" +%s 2>/dev/null || echo 0)
                CURRENT_EPOCH=$(date +%s)
                TIME_DIFF=$((CURRENT_EPOCH - CHANGE_EPOCH))
                
                # Si fue modificada en las últimas 3 horas (10800 segundos)
                if [ $TIME_DIFF -lt 10800 ] && [ $TIME_DIFF -gt 0 ]; then
                    HOURS_AGO=$((TIME_DIFF / 3600))
                    MINS_AGO=$(((TIME_DIFF % 3600) / 60))
                    FOLDER_NAME=$(basename "$folder")
                    
                    log_output "${Y}[!] Carpeta modificada recientemente: $FOLDER_NAME${N}"
                    log_output "${W}    Hace: ${HOURS_AGO}h ${MINS_AGO}m${N}"
                    log_output "${W}    Hora: $CHANGE_TIME${N}"
                    ((SUSPICIOUS_COUNT++))
                fi
            fi
        fi
    done
    
    echo ""
    
    # Verificar papelera/reciclaje (algunas ROMs tienen papelera)
    log_output "${B}[+] Verificando papelera de reciclaje...${N}"
    
    TRASH_PATHS=(
        "/sdcard/.Trash"
        "/sdcard/LOST.DIR"
        "/data/local/.trash"
    )
    
    TRASH_FOUND=0
    for trash in "${TRASH_PATHS[@]}"; do
        TRASH_CONTENT=$(adb shell "find '$trash' -type f 2>/dev/null | grep -i '$GAME_PKG'" | tr -d '\r')
        
        if [ -n "$TRASH_CONTENT" ]; then
            log_output "${R}[!] ARCHIVOS DEL JUEGO EN PAPELERA${N}"
            echo "$TRASH_CONTENT" | head -3 | while read -r file; do
                log_output "${Y}  $(basename "$file")${N}"
            done
            TRASH_FOUND=1
            ((SUSPICIOUS_COUNT+=2))
        fi
    done
    
    if [ $TRASH_FOUND -eq 0 ]; then
        log_output "${G}[✓] Sin archivos en papelera${N}"
    fi
    
    echo ""
}

check_replays() {
    log_output "${B}[+] Analizando replays...${N}"
    REPLAY_DIR="/sdcard/Android/data/$GAME_PKG/files/MReplays"
    BINS=$(adb shell "ls -t '$REPLAY_DIR'/*.bin 2>/dev/null" | tr -d '\r' | head -1)
    
    if [ -z "$BINS" ]; then
        log_output "${R}[!] No hay replays (sospechoso)${N}\n"
        ((SUSPICIOUS_COUNT++))
        return
    fi
    
    echo "$BINS" | while read -r bin; do
        STAT=$(adb shell "stat '$bin' 2>/dev/null")
        MODIFY=$(echo "$STAT" | grep "Modify:" | awk '{print $2" "$3}')
        CHANGE=$(echo "$STAT" | grep "Change:" | awk '{print $2" "$3}')
        
        log_output "${W}Replay: $(basename "$bin")${N}"
        if [ "$MODIFY" != "$CHANGE" ]; then
            log_output "${R}[!] Modify ≠ Change${N}"
            ((SUSPICIOUS_COUNT++))
        fi
    done
    echo ""
}

check_wallhack_bypass() {
    log_output "${B}[+] Detectando wallhacks...${N}"
    SHADER_DIR="/sdcard/Android/data/$GAME_PKG/files/contentcache/Optional/android/gameassetbundles"
    SHADERS=$(adb shell "find '$SHADER_DIR' -name 'shader*' 2>/dev/null" | tr -d '\r' | head -3)
    
    if [ -z "$SHADERS" ]; then
        log_output "${G}[✓] Sin shaders modificados${N}\n"
        return
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

# Iniciar
check_storage
main_menu
