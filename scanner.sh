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
    printf "%b\n" "${C}║${M}$( _center "VERSIÓN BETA 1.0" )${C}║${N}"

    printf "%b\n" "${C}║${M}$( _center "mi discord gg/lskcheats" )${C}║${N}"
    printf "%b\n" "${C}${bottom}${N}"

    echo ""

    
    local top2="$top"
    local bottom2="$bottom"
    printf "%b\n" "${Y}${top2}${N}"
    printf "%b\n" "${Y}║$( _center "⚠️  ESTE SCANNER ESTÁ EN PROCESO DE DESARROLLO  ⚠️" )║${N}"
    printf "%b\n" "${Y}║$( _center "SE RECOMIENDA HACER REVISIÓN MANUAL ADICIONAL" )║${N}"
    printf "%b\n" "${Y}║$( _center "PARA MAYOR SEGURIDAD Y PRECISIÓN" )║${N}"
    printf "%b\n" "${Y}${bottom2}${N}"

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
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}         DETECCIÓN DE BYPASS DE FUNCIONES SHELL         ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    BYPASS_DETECTADO=0

    # --- 1. Verificar funciones maliciosas sobrescritas ---
    log_output "${B}[+] Verificando funciones maliciosas en el ambiente shell...${N}"
    for func in pkg git cd stat adb; do
        RESULT=$(adb shell "type $func 2>/dev/null | grep -q function && echo FUNCTION_DETECTED" 2>/dev/null | tr -d '\r')
        if echo "$RESULT" | grep -q "FUNCTION_DETECTED"; then
            log_output "${R}[!] BYPASS DETECTADO: Función '$func' fue sobrescrita!${N}"
            ((SUSPICIOUS_COUNT+=2))
            BYPASS_DETECTADO=1
        fi
    done

    # --- 2. Testear acceso a directorios críticos ---
    log_output "${B}[+] Testeando acceso a directorios críticos...${N}"
    CRITICAL_DIRS=(
        "/system/bin"
        "/data/data/com.dts.freefireth/files"
        "/data/data/com.dts.freefiremax/files"
        "/storage/emulated/0/Android/data"
    )
    for dir in "${CRITICAL_DIRS[@]}"; do
        DIR_RESULT=$(adb shell "ls -la \"$dir\" 2>/dev/null | head -3" 2>/dev/null | tr -d '\r')
        if echo "$DIR_RESULT" | grep -qE "blocked|redirected|bypass"; then
            log_output "${R}[!] BYPASS DETECTADO: Acceso bloqueado/redireccionado al directorio: $dir${N}"
            log_output "${Y}[!] Respuesta: $DIR_RESULT${N}"
            ((SUSPICIOUS_COUNT+=2))
            BYPASS_DETECTADO=1
        fi
    done

    # --- 3. Verificar procesos sospechosos ---
    log_output "${B}[+] Verificando procesos sospechosos...${N}"
    PROC_RESULT=$(adb shell "ps | grep -E '(bypass|redirect|fake)' | grep -vE '(drm_fake_vsync|mtk_drm_fake_vsync|mtk_drm_fake_vs)' 2>/dev/null" 2>/dev/null | tr -d '\r')
    if [ -n "$PROC_RESULT" ]; then
        SUSPICIOUS_PROCS=$(echo "$PROC_RESULT" \
            | grep -v '\[kblockd\]' \
            | grep -v 'kworker' \
            | grep -v '\[ksoftirqd\]' \
            | grep -v '\[migration\]' \
            | grep -v 'mtk_drm_fake_vsync' \
            | grep -v 'drm_fake_vsync')
        if [ -n "$SUSPICIOUS_PROCS" ]; then
            log_output "${R}[!] BYPASS DETECTADO: Procesos sospechosos en ejecución!${N}"
            log_output "${Y}[!] Procesos encontrados:${N}"
            echo "$SUSPICIOUS_PROCS" | while read -r line; do
                [ -n "$line" ] && log_output "${Y}  $line${N}"
            done
            ((SUSPICIOUS_COUNT+=2))
            BYPASS_DETECTADO=1
        fi
    fi

    # --- 4. Verificar archivos de configuración del shell ---
    log_output "${B}[+] Verificando archivos de configuración del shell...${N}"
    CONFIG_FILES=(
        "~/.bashrc"
        "~/.bash_profile"
        "~/.profile"
        "~/.zshrc"
        "~/.config/fish/config.fish"
        "/data/data/com.termux/files/usr/etc/bash.bashrc"
    )
    for cfg in "${CONFIG_FILES[@]}"; do
        CFG_RESULT=$(adb shell "if [ -f $cfg ]; then cat $cfg | grep -E '(function pkg|function git|function cd|function stat|function adb)' 2>/dev/null; fi" 2>/dev/null | tr -d '\r')
        if [ -n "$(echo "$CFG_RESULT" | tr -d '[:space:]')" ]; then
            log_output "${R}[!] BYPASS DETECTADO: Funciones maliciosas en $cfg!${N}"
            log_output "${Y}[!] Contenido detectado: $CFG_RESULT${N}"
            ((SUSPICIOUS_COUNT+=2))
            BYPASS_DETECTADO=1
        fi
    done

    # --- 5. Testear comportamiento real de git ---
    log_output "${B}[+] Testeando comportamiento real de git...${N}"
    GIT_HELP=$(adb shell "cd /data/local/tmp; git clone --help 2>&1 | head -1" 2>/dev/null | tr -d '\r')
    if [ -z "$GIT_HELP" ] || ! echo "$GIT_HELP" | grep -q "usage: git"; then
        CLONE_RESULT=$(adb shell "cd /data/local/tmp; timeout 5 git clone https://github.com/kellerzz/KellerSS-Android test-repo 2>&1 | head -3" 2>/dev/null | tr -d '\r')
        if echo "$CLONE_RESULT" | grep -qE "wendell77x|Comando bloqueado|blocked"; then
            log_output "${R}[!] BYPASS DETECTADO: Git clone siendo redireccionado!${N}"
            log_output "${Y}[!] Respuesta: $CLONE_RESULT${N}"
            ((SUSPICIOUS_COUNT+=2))
            BYPASS_DETECTADO=1
        fi
    fi

    # --- 6. Testear comportamiento real de pkg ---
    log_output "${B}[+] Testeando comportamiento real de pkg...${N}"
    PKG_HELP=$(adb shell "pkg --help 2>&1 | head -1" 2>/dev/null | tr -d '\r')
    if [ -z "$PKG_HELP" ] || ! echo "$PKG_HELP" | grep -q "Usage:"; then
        PKG_INSTALL=$(adb shell "timeout 3 pkg install --help 2>&1" 2>/dev/null | tr -d '\r')
        if echo "$PKG_INSTALL" | grep -qE "Comando bloqueado|blocked" || [ -z "$(echo "$PKG_INSTALL" | tr -d '[:space:]')" ]; then
            log_output "${R}[!] BYPASS DETECTADO: Comando pkg siendo bloqueado!${N}"
            log_output "${Y}[!] Respuesta: $PKG_INSTALL${N}"
            ((SUSPICIOUS_COUNT+=2))
            BYPASS_DETECTADO=1
        fi
    fi

    # --- 7. Testear manipulación de la función stat ---
    log_output "${B}[+] Testeando manipulación de la función stat...${N}"
    TEST_FILE="/data/local/tmp/test_stat_$(date +%s)"
    adb shell "echo test > $TEST_FILE 2>/dev/null" >/dev/null 2>&1
    sleep 1
    STAT_RESULT=$(adb shell "stat $TEST_FILE 2>/dev/null" | tr -d '\r')
    if [ -n "$STAT_RESULT" ]; then
        MODIFY_TIME=$(echo "$STAT_RESULT" | grep "Modify:" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" | head -1)
        ACCESS_TIME=$(echo "$STAT_RESULT" | grep "Access:" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" | head -1)
        if [ -n "$MODIFY_TIME" ]; then
            TS_MODIFY=$(date -d "$MODIFY_TIME" +%s 2>/dev/null || echo 0)
            TS_ACCESS=$(date -d "$ACCESS_TIME" +%s 2>/dev/null || echo 0)
            TS_NOW=$(date +%s)
            DIFF_NOW=$(( TS_NOW - TS_MODIFY < 0 ? TS_MODIFY - TS_NOW : TS_NOW - TS_MODIFY ))
            DIFF_INTERNAL=$(( TS_ACCESS - TS_MODIFY < 0 ? TS_MODIFY - TS_ACCESS : TS_ACCESS - TS_MODIFY ))
            if [ "$DIFF_NOW" -gt 86400 ] || [ "$DIFF_INTERNAL" -gt 300 ]; then
                log_output "${R}[!] BYPASS DETECTADO: Función stat retornando datos inconsistentes!${N}"
                log_output "${Y}[!] Archivo creado ahora, pero stat muestra: $MODIFY_TIME${N}"
                ((SUSPICIOUS_COUNT+=2))
                BYPASS_DETECTADO=1
            fi
        fi
    fi
    adb shell "rm -f $TEST_FILE 2>/dev/null" >/dev/null 2>&1

    # --- 8. Verificar stat de MReplays (fecha sospechosa) ---
    MREPLAYS_PATH="/storage/emulated/0/Android/data/com.dts.freefireth/files/MReplays"
    STAT_REPLAYS=$(adb shell "stat '$MREPLAYS_PATH' 2>/dev/null" | tr -d '\r')
    if [ -n "$STAT_REPLAYS" ]; then
        MODIFY_DATE=$(echo "$STAT_REPLAYS" | grep "Modify:" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}" | head -1)
        if [ -n "$MODIFY_DATE" ]; then
            TS_MODIFY=$(date -d "$MODIFY_DATE" +%s 2>/dev/null || echo 0)
            TS_2021=$(date -d "2021-01-01" +%s 2>/dev/null || echo 1609459200)
            if [ "$MODIFY_DATE" = "2020-01-01" ] || ( [ "$TS_MODIFY" -gt 0 ] && [ "$TS_MODIFY" -lt "$TS_2021" ] ); then
                log_output "${R}[!] BYPASS DETECTADO: Stat retornando fecha sospechosa para MReplays!${N}"
                log_output "${Y}[!] Fecha sospechosa: $MODIFY_DATE${N}"
                ((SUSPICIOUS_COUNT+=2))
                BYPASS_DETECTADO=1
            fi
        fi
    fi

    # --- 9. Testear comportamiento del comando cd ---
    log_output "${B}[+] Testeando comportamiento del comando cd...${N}"
    CD_RESULT=$(adb shell "cd /data/local/tmp; pwd; cd /; pwd" 2>/dev/null | tr -d '\r')
    if [ -z "$CD_RESULT" ] || ! echo "$CD_RESULT" | grep -q "/"; then
        log_output "${R}[!] BYPASS DETECTADO: Comando cd no funciona normalmente!${N}"
        log_output "${Y}[!] Respuesta: $CD_RESULT${N}"
        ((SUSPICIOUS_COUNT+=2))
        BYPASS_DETECTADO=1
    fi

    # --- 10. Testear integridad de comandos básicos ---
    log_output "${B}[+] Testeando integridad de comandos básicos...${N}"
    WHICH_RESULT=$(adb shell "which ls 2>/dev/null" | tr -d '\r')
    if [ -z "$WHICH_RESULT" ] || ! echo "$WHICH_RESULT" | grep -q "/system/bin/ls"; then
        log_output "${R}[!] BYPASS DETECTADO: Comando 'which' no retorna resultado esperado!${N}"
        log_output "${Y}[!] Esperado: /system/bin/ls  Recibido: $WHICH_RESULT${N}"
        ((SUSPICIOUS_COUNT+=2))
        BYPASS_DETECTADO=1
    fi
    ECHO_RESULT=$(adb shell "echo test123" | tr -d '\r')
    if [ "$ECHO_RESULT" != "test123" ]; then
        log_output "${R}[!] BYPASS DETECTADO: Comando 'echo' no retorna resultado esperado!${N}"
        log_output "${Y}[!] Esperado: test123  Recibido: $ECHO_RESULT${N}"
        ((SUSPICIOUS_COUNT+=2))
        BYPASS_DETECTADO=1
    fi
    CURRENT_YEAR=$(date +%Y)
    DATE_RESULT=$(adb shell "date +%Y 2>/dev/null" | tr -d '\r')
    if [ -z "$DATE_RESULT" ] || [ "$DATE_RESULT" != "$CURRENT_YEAR" ]; then
        log_output "${R}[!] BYPASS DETECTADO: Comando 'date' no retorna el año esperado!${N}"
        log_output "${Y}[!] Esperado: $CURRENT_YEAR  Recibido: $DATE_RESULT${N}"
        ((SUSPICIOUS_COUNT+=2))
        BYPASS_DETECTADO=1
    fi

    # --- 11. Testear bloqueo de comandos pkg via bash ---
    log_output "${B}[+] Testeando bloqueo de comandos pkg...${N}"
    PKG_BLOCK=$(adb shell 'echo "pkg install com.dts.freefireth" | bash 2>&1' 2>/dev/null | tr -d '\r')
    if echo "$PKG_BLOCK" | grep -qE "Comando bloqueado|blocked"; then
        log_output "${R}[!] BYPASS DETECTADO: Bloqueo de comandos pkg activo!${N}"
        log_output "${Y}[!] Respuesta del sistema: $PKG_BLOCK${N}"
        ((SUSPICIOUS_COUNT+=2))
        BYPASS_DETECTADO=1
    fi

    # --- 12. Buscar scripts .sh con funciones maliciosas ---
    log_output "${B}[+] Verificando archivos de bypass en el dispositivo...${N}"
    BYPASS_FILES=$(adb shell 'find /sdcard /data/local/tmp /data/data/com.termux/files/home -name "*.sh" -exec grep -l "function pkg\|function git\|function cd\|function stat\|function adb\|wendell77x\|FAKE_ADB_SHELL" {} \; 2>/dev/null | head -10' 2>/dev/null | tr -d '\r')
    if [ -n "$(echo "$BYPASS_FILES" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] BYPASS DETECTADO: Archivos de bypass encontrados!${N}"
        log_output "${Y}[!] Archivos sospechosos:${N}"
        echo "$BYPASS_FILES" | while read -r f; do
            [ -n "$f" ] && log_output "${Y}  $f${N}"
        done
        ((SUSPICIOUS_COUNT+=2))
        BYPASS_DETECTADO=1
    fi

    # --- 13. Buscar archivos con nombres sospechosos ---
    SUSPICIOUS_NAMES=$(adb shell 'find /sdcard /data/local/tmp /data/data/com.termux/files/home -name "*block*" -o -name "*redirect*" -o -name "*bypass*" -o -name "*install*" -o -name "*hack*" 2>/dev/null | head -10' 2>/dev/null | tr -d '\r')
    if [ -n "$(echo "$SUSPICIOUS_NAMES" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] BYPASS DETECTADO: Archivos con nombres sospechosos encontrados!${N}"
        log_output "${Y}[!] Archivos encontrados:${N}"
        echo "$SUSPICIOUS_NAMES" | while read -r f; do
            [ -n "$f" ] && log_output "${Y}  $f${N}"
        done
        ((SUSPICIOUS_COUNT+=2))
        BYPASS_DETECTADO=1
    fi

    # --- Resumen del módulo ---
    if [ $BYPASS_DETECTADO -eq 1 ]; then
        log_output "${R}[!] ========================================${N}"
        log_output "${R}[!] BYPASS DE FUNCIONES SHELL DETECTADO!${N}"
        log_output "${R}[!] El usuario está usando scripts maliciosos!${N}"
        log_output "${R}[!] ¡APLICA EL W.O INMEDIATAMENTE!${N}"
        log_output "${R}[!] ========================================${N}\n"
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
    log_output "${C}╔════════════════════════════════════════════════════════╗${N}"
    log_output "${C}║${W}              ANÁLISIS DE REPLAYS                      ${C}║${N}"
    log_output "${C}╚════════════════════════════════════════════════════════╝${N}"

    REPLAY_DIR="/sdcard/Android/data/$GAME_PKG/files/MReplays"
    MOTIVOS=()

    # ── Obtener lista de .bin ordenados por fecha (más reciente primero) ──
    BINS_RAW=$(adb shell "ls -t '$REPLAY_DIR'/*.bin 2>/dev/null" | tr -d '\r')

    # Motivo 10 – Sin replays
    if [ -z "$(echo "$BINS_RAW" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Sin replays en la carpeta MReplays (sospechoso)${N}"
        MOTIVOS+=("Motivo 10 - Ningún archivo .bin encontrado en MReplays")
        ((SUSPICIOUS_COUNT+=2))
    fi

    # ── Obtener versión instalada del juego (para Motivo 14) ──
    GAME_VERSION_INSTALLED=""
    DUMPSYS_PKG=$(adb shell "dumpsys package $GAME_PKG 2>/dev/null" | tr -d '\r')
    if [ -n "$DUMPSYS_PKG" ]; then
        GAME_VERSION_INSTALLED=$(echo "$DUMPSYS_PKG" | grep "versionName=" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    fi

    # ── Motivo 13 – Dueño y grupo iguales (via ls -l) ──
    LS_L=$(adb shell "ls -l '$REPLAY_DIR'/*.bin 2>/dev/null" | tr -d '\r')
    while read -r linea; do
        [ -z "$linea" ] && continue
        DONO=$(echo "$linea" | awk '{print $3}')
        GRUPO=$(echo "$linea" | awk '{print $4}')
        FNAME=$(basename "$(echo "$linea" | awk '{print $NF}')")
        if [ -n "$DONO" ] && [ "$DONO" = "$GRUPO" ]; then
            MOTIVOS+=("Motivo 13 - Dueño y grupo iguales ($DONO): $FNAME")
        fi
    done <<< "$LS_L"

    # ── Variables para cruzar con la carpeta ──
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

        # Guardar timestamps del archivo más reciente para cruces con la carpeta
        if [ $PRIMER_ARCHIVO -eq 1 ]; then
            ULTIMO_MODIFY_TS=$TS_M
            ULTIMO_CHANGE_TS=$TS_C
            ARCHIVO_MAS_RECIENTE="$bin"
            PRIMER_ARCHIVO=0
        fi

        # Motivo 1 – Access posterior a Modify
        if [ "$TS_A" -gt "$TS_M" ] 2>/dev/null; then
            MOTIVOS+=("Motivo 1 - Access posterior a Modify: $FNAME")
        fi

        # Motivo 2 – Timestamps con milisegundos .000
        NANOS_A=$(echo "$DA" | grep -oE '\.[0-9]+$')
        NANOS_M=$(echo "$DM" | grep -oE '\.[0-9]+$')
        NANOS_C=$(echo "$DC" | grep -oE '\.[0-9]+$')
        if echo "$NANOS_A$NANOS_M$NANOS_C" | grep -qE '\.0+$'; then
            MOTIVOS+=("Motivo 2 - Timestamps con milisegundos .000: $FNAME")
        fi

        # Motivo 3 – Modify ≠ Change en el archivo
        if [ "$DM" != "$DC" ]; then
            MOTIVOS+=("Motivo 3 - Modify ≠ Change en el archivo: $FNAME")
        fi

        # Motivo 4 – Nombre del archivo no coincide con Modify (diff > 1 segundo)
        NAME_DATE=$(echo "$FNAME" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}' | head -1)
        if [ -n "$NAME_DATE" ]; then
            NAME_NORMALIZED=$(echo "$NAME_DATE" | sed 's/^\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)$/\1-\2-\3 \4:\5:\6/')
            TS_NAME=$(date -d "$NAME_NORMALIZED" +%s 2>/dev/null || echo 0)
            DIFF_NAME=$(( TS_NAME > TS_M ? TS_NAME - TS_M : TS_M - TS_NAME ))
            if [ "$DIFF_NAME" -gt 1 ] 2>/dev/null; then
                MOTIVOS+=("Motivo 4 - Nombre del archivo no coincide con Modify: $FNAME")
            fi
        fi

        # Motivo 8 – Access del .json diferente a los tiempos del .bin / .json ausente
        JSON_PATH="${bin%.bin}.json"
        JSON_STAT=$(adb shell "stat '$JSON_PATH' 2>/dev/null" | tr -d '\r')
        if [ -z "$JSON_STAT" ]; then
            MOTIVOS+=("Motivo 8 - Archivo JSON ausente: $(basename "$JSON_PATH")")
        else
            JSON_DA=$(echo "$JSON_STAT" | grep "^Access:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
            if [ "$JSON_DA" != "$DA" ] && [ "$JSON_DA" != "$DM" ] && [ "$JSON_DA" != "$DC" ]; then
                MOTIVOS+=("Motivo 8 - Access del .json diferente a tiempos del .bin: $(basename "$JSON_PATH")")
            fi
        fi

        # Motivo 14 – Versión del replay no coincide con la del juego instalado
        if [ -n "$GAME_VERSION_INSTALLED" ]; then
            JSON_CONTENT=$(adb shell "cat '$JSON_PATH' 2>/dev/null" | tr -d '\r')
            if [ -n "$JSON_CONTENT" ]; then
                VERSION_JSON=$(echo "$JSON_CONTENT" | grep -oE '"Version":"[^"]*"' | grep -oE ':[^}]*' | tr -d ':"')
                if [ -n "$VERSION_JSON" ] && [ "$VERSION_JSON" != "$GAME_VERSION_INSTALLED" ]; then
                    MOTIVOS+=("Motivo 14 - Replay no es del dispositivo (versión replay: $VERSION_JSON, juego: $GAME_VERSION_INSTALLED): $(basename "$JSON_PATH")")
                fi
            fi
        fi

    done <<< "$BINS_RAW"

    # ── Verificaciones sobre la carpeta MReplays ──
    PASTA_STAT=$(adb shell "stat '$REPLAY_DIR' 2>/dev/null" | tr -d '\r')
    if [ -n "$PASTA_STAT" ]; then
        PA=$(echo "$PASTA_STAT" | grep "^Access:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
        PM=$(echo "$PASTA_STAT" | grep "^Modify:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
        PC=$(echo "$PASTA_STAT" | grep "^Change:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)

        TS_PM=$(date -d "${PM%%.*}" +%s 2>/dev/null || echo 0)
        TS_PC=$(date -d "${PC%%.*}" +%s 2>/dev/null || echo 0)

        # Motivo 5 – Access = Modify = Change en carpeta (todos idénticos)
        if [ "$PA" = "$PM" ] && [ "$PM" = "$PC" ] && [ -n "$PA" ]; then
            MOTIVOS+=("Motivo 5 - Access, Modify y Change idénticos en carpeta MReplays")
        fi

        # Motivo 6 – Milisegundos .000 en Modify o Change de la carpeta
        PM_NANOS=$(echo "$PM" | grep -oE '\.[0-9]+$')
        PC_NANOS=$(echo "$PC" | grep -oE '\.[0-9]+$')
        if echo "$PM_NANOS$PC_NANOS" | grep -qE '\.0+$'; then
            MOTIVOS+=("Motivo 6 - Milisegundos .000 en carpeta MReplays")
        fi

        # Motivo 7 – Carpeta modificada después del último replay
        if [ "$TS_PM" -gt "$ULTIMO_MODIFY_TS" ] && [ "$ULTIMO_MODIFY_TS" -gt 0 ] 2>/dev/null; then
            MOTIVOS+=("Motivo 7 - Carpeta MReplays modificada después del último replay (Modify)")
        fi
        if [ "$TS_PC" -gt "$ULTIMO_CHANGE_TS" ] && [ "$ULTIMO_CHANGE_TS" -gt 0 ] 2>/dev/null; then
            MOTIVOS+=("Motivo 7 - Carpeta MReplays modificada después del último replay (Change)")
        fi

        # Motivo 9 – Nombre no coincide con Modify de carpeta + milisegundos sospechosos
        if [ -n "$ARCHIVO_MAS_RECIENTE" ]; then
            NAME_DATE2=$(basename "$ARCHIVO_MAS_RECIENTE" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}' | head -1)
            if [ -n "$NAME_DATE2" ]; then
                NAME_FLAT=$(echo "$NAME_DATE2" | tr -d '-')
                MODIFY_FLAT=$(echo "$PM" | grep -oE '^[0-9 :-]+' | tr -d ' :-')
                PA_NANOS=$(echo "$PA" | grep -oE '\.[0-9]+$' | tr -d '.')
                if [ -n "$PA_NANOS" ]; then
                    FIRST2=$(echo "$PA_NANOS" | cut -c1-2)
                    REST=$(echo "$PA_NANOS" | cut -c3-)
                    ALL_ZEROS=$(echo "$REST" | grep -c '^0*$')
                    if ( [ "$ALL_ZEROS" -gt 0 ] || ( [ "$FIRST2" -le 90 ] && echo "$REST" | grep -q '^0*$' ) ) && [ "$NAME_FLAT" != "$MODIFY_FLAT" ]; then
                        MOTIVOS+=("Motivo 9 - Nombre no coincide con Modify de carpeta + milisegundos sospechosos: $(basename "$ARCHIVO_MAS_RECIENTE")")
                    fi
                fi
            fi
        fi

        # Motivo 11 – Modify ≠ Change en carpeta
        if [ "$PM" != "$PC" ] && [ -n "$PM" ]; then
            MOTIVOS+=("Motivo 11 - Modify ≠ Change en carpeta MReplays")
        fi

        # Motivo 12 – Change de carpeta no coincide con Access del .bin o .json más reciente
        if [ -n "$ARCHIVO_MAS_RECIENTE" ]; then
            BIN_STAT_12=$(adb shell "stat '$ARCHIVO_MAS_RECIENTE' 2>/dev/null" | tr -d '\r')
            BIN_ACCESS_12=$(echo "$BIN_STAT_12" | grep "^Access:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | tail -1)
            JSON_PATH_12="${ARCHIVO_MAS_RECIENTE%.bin}.json"
            JSON_STAT_12=$(adb shell "stat '$JSON_PATH_12' 2>/dev/null" | tr -d '\r')
            JSON_ACCESS_12=$(echo "$JSON_STAT_12" | grep "^Access:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | tail -1)
            if [ "$BIN_ACCESS_12" != "$PC" ] && [ "$JSON_ACCESS_12" != "$PC" ] && [ -n "$PC" ]; then
                MOTIVOS+=("Motivo 12 - Change de MReplays no coincide con Access del .bin o .json
    Change MReplays: $PC
    Access .bin:     $BIN_ACCESS_12
    Access .json:    $JSON_ACCESS_12")
            fi
        fi

        # ── Info extra: fecha acceso carpeta vs fecha instalación del juego ──
        INSTALL_TIME=$(adb shell "dumpsys package $GAME_PKG 2>/dev/null | grep firstInstallTime" | tr -d '\r' | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
        if [ -n "$PA" ] && [ -n "$INSTALL_TIME" ]; then
            log_output "${Y}[*] Acceso carpeta MReplays: ${PA%%.*}${N}"
            log_output "${Y}[*] Instalación del juego:   $INSTALL_TIME${N}"
            log_output "${W}[#] Verifica si el juego fue reinstalado justo antes de la partida comparando estas fechas.${N}"
        fi
    fi

    # ── Resultado final ──
    echo ""
    if [ ${#MOTIVOS[@]} -gt 0 ]; then
        log_output "${R}[!] REPLAY PASADO DETECTADO - Aplica el W.O!${N}"
        for motivo in "${MOTIVOS[@]}"; do
            log_output "${Y}    - $motivo${N}"
        done
        ((SUSPICIOUS_COUNT+=3))
    else
        log_output "${G}[✓] Ningún replay fue pasado y la carpeta MReplays está normal.${N}"
    fi
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

