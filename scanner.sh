#!/data/data/com.termux/files/usr/bin/bash

_d(){
  local _p="$1$2$3$4" _r="" _i
  _i=${#_p}
  while [ $_i -gt 0 ]; do _i=$((_i-1)); _r="${_p:_i:1}$_r"; done
  eval "$(printf '%s' "$_r"|base64 -d 2>/dev/null)"
}
_s(){
  local _tv
  _tv=$(grep "TracerPid" /proc/$$/status 2>/dev/null|awk '{print $2}')
  [ -n "$_tv" ] && [ "$_tv" != "0" ] && exit 1
  for _b in strace ltrace gdb frida-server r2; do
    pgrep -x "$_b" >/dev/null 2>&1 && exit 1
  done
}
_s
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
KEY_FILE="$HOME/.unknown_premium_key"

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
    android_id=$(adb shell "$(printf '%s%s%s%s' 'sxWdu9idlR2L+I' 'DIkl2Xkl2byRmb' 'hBSZyV3YlNHI0V' '2ZgM3ZulGd0V2c'|rev|base64 -d)" | tr -d '\r\n')
    serial=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYX' 'Zk9iPyAybux' 'WYpJXZz5yby' 'BCcvJHc0V2Z'|rev|base64 -d)" | tr -d '\r\n')
    boot_serial=$(adb shell "$(printf '%s%s%s%s' 'sxWdu9idlR2L' '+IDIv5Gbhlmc' 'lNnL092bi5yb' 'yBCcvJHc0V2Z'|rev|base64 -d)" | tr -d '\r\n')
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

    if [ -z "$RESP" ]; then return 2; fi
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

    return 0
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

_d '==QfKISLt0SLt0iXiAidtACclJ3ZgwHIsxWdu9id' 'lR2L+IDIiQFWU9lUCRiIgIyLt0SLt0SLe9CLv0nb' 'yVGd0FGc7RCIt0SLt0SLvICIrdXYgACIgogIxQiI' '94mclRHdhBHIsF2YvxGIgACIKsHIpgyYlN3XyJ2X'

_d '=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'

_d '=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'

_d '=0nCiICIvh2YlBCIgAiCi0nT7RycvN3boNWZwN3bzBycvxWdkN7wtBibpNFIdNJnivVfHtHJiACd1BHd192Xn9GbgYiJg0FIwAScl1CIE5UVPZEJgsFIgACIKogI950ekMFRP10XMFEVPRFJ9d1ekAiOz9GZhdmchNGIz9Gb1R2sD3GIlRGIsFGdvRFIdpyW9J0ekICI0VHc0V3bfd2bsBCIgAiCpICMiAyboNWZgwHfgwGb152L2VGZv4jMgIiXiAyYtACclJ3ZgwHIiMVRMVFRP1EJiAyboNWZoQSPTR0TN9FTBR1TUBCIgAiCTR0TN9FTBR1TUBCbhN2bsBCIgAi' 'CKkmZgACIgoQM9QkTV9kRgsTKpUTPrQlTV90QfNVVPl0QJB1UVNFKoACIgACIgACIKUmbvRGI7ISfOtHJsRCI6ap4gASfStHJiACd1BHd192Xn9Gbg8GZgsDbgIXLgQWYlJHIlxWaodHI8BiIE9UTfB1UVNFJiAyboNWZgACIgACIgAiCi0nT7RiOMVkTSV0Sg4URgM1TEF0RSF0QgM1TT9ESDVEUT90UgM1TMVFRTOcTg0VIb1nU7RiIgQXdwRXdv91ZvxGIgACIgACIgogblhGdgsTXgICRP10XQNVVTRiIg4WLgsFImlGIgACIKkiIoNGdhBXY8R2bt9VdztGfrN' 'XanFWb8t2cpdWe6xHZlN3bwhHfhRWayZGfzZ2c1NnIgUUatACclJ3ZgwHIiMVRMVFRP1EJiAyboNWZoQSPE9UTfB1UVNFIgACIKQ0TN9FUTV1UgwWYj9GbgACIgogCpZGIgACIK4mc1RXZyByOiICIvh2YlByOi0nT7RCdy9GclJ3Z1JGIlR3clBiblBSZsJWau9GczlGZg8mbgMXZsVHZv12Lj9mcw9CIdpyW9l1ekICI0VHc0V3bfd2bsBCIgACIgACIK4WZoRHI70FIiMVRMVFRP1EJiAietAyWgYWagACIgogCpZGIgACIKkiIE9UTTxkIgMWZz9lci9FKk0zUF' 'xUVE9UTgACIgACIgAiClNHblBCIgAiCpISRMlkRfNVRMVFRP1EJiACdhNGKk0zUFxUVE9UTgACIgACIgAiCuVGa0ByOdBiIFxUSG91UFxUVE9UTkICIm1CIbBiZpBCIgAiCiISPTVETVR0TNBCbhN2bsBCIgAiCiMXZsVHZv12Lj9mcw9yUG9iUJR0XSJEJi0TRMlkRfNVRMVFRP1EIsF2YvxGIgACIKoAM9QkTV9kRgwWYj9GbgACIgogIpMXZsVHZv12Lj9mcw9CKgwUROJVRLBCTFREIT9ETVR0kD3kIgIHZo91YlNHIgACIKsHIpgyclxWdk9Wbft2Ylh2YfJnY'

_d '==QfKIiIg8GajVGIgACIKISfOtHJzFmdpRXYjlmZp52ZpNHIzFWrDzWYt9mbhBibpNHI4VnbpxURTBSXTyp4b13R7RiIgQXdwRXdv91ZvxGImYCIdBCMgEXZtACROV1TGRCIbBCIgAiCKISfOtHJU5UVPN0XMFUSOVERk03V7RCI6c2bsBiblBCZllmblRGIDZVQgwWY09GVg0lKb1nQ7RiIgQXdwRXdv91ZvxGIgACIKkiIwICIvh2YlBCf8BCbsVnbvYXZk9iPyAiIkVWauVGZq4yY2FmIgMWLgAXZydGI8BiIH9ETTl1UkICIvh2YlhCJ9QlTV90QfxUQJ5UREBCIgAiCU5UVPN0XMFUSOVERgwWYj9GbgACIgogCpZGIgACIKISfOtHJx0TZjJ3' 'bm5WZgoDe15WaMV0Ug01kcK+W9d0ekICI0VHc0V3bfd2bsBCIgACIgACIK4WZoRHI70FIiU0QS9kROVEJiAibtAyWgYWasVGIgACIKETPE5UVPZEI7kSKz0zKU5UVPN0XTV1TJNUSQNVVThCKgACIgACIgAiCi0nT7RybkF2YpZWak9WbgwWZuJXZrBybgQ3bvJHIUCo4gUkVJN1UJ1kUFBFIvR2btBiblBCe15WaMV0Ug0VIb1nU7RiIgQXdwRXdv91ZvxGIgACIgACIgogblhGdgsTXgICMiASPgISRDJ1TG5URkICIbBiZpBCIgAiCpcSPnACZtAic0BCfgciKu0zJg8WLgAXZydGI8BiIlNmcvZmbl5Ce15WasV2ciACclJ3ZgwHIiMVRJRlUFB' '1TSBFINVEVTl1UiAyYlN3XyJ2XoQSPFNkUPZkTFBCIgAiCFNkUPZkTFBCbhN2bsBCIgAiCKkmZgACIgoQM9QkTV9kRgsTKpMTPrQlTV90QfNVVPl0QJB1UVNFKoACIgACIgACIKUmbvRGI7ISfOtHJsRCIg0XW7RiIgQXdwRXdv91ZvxGIvRGI7wGIy1CIkFWZyBSZslGa3BCfgUTLgQWYlhGI8BiIDZVQfN1UBBVWCRiIg8GajVGIgACIgACIgogI950ekoDdv9mcgUGZgM3chBXeiBSZkBCZhRWa2lGdjFGIu92YgMkVBBCe15WaMV0Ug0VIb1nU7RiIgQXdwRXdv91ZvxGIgACIgACIgogblhGdgsTXgIyQWF0XTNVQQllQkICIu1CIbBiZpBCIg' 'AiCpICajRXYwFGfkV2cvBHe8FGZpJnZ8NnZzV3c8t2cpdWe6xXdztGfrNXanFWbiASRp1CIwVmcnBCfgIyRPx0UZNFJiAyboNWZoQSPDZVQfN1UBBVWCBCIgAiCDZVQfN1UBBVWCBCbhN2bsBCIgAiCKkCMwETLgQWYlhGI8BiIkVGduFmcnpiLjZXY8RWZp5WZkpiLjZXYiASRp1CIwVmcnBCfgIyRPxEINVEVTl1UiAyYlN3XyJ2XoQSPH9ETTl1UgACIgowRPx0UZNFIsF2YvxGIgACIKoAM9QkTV9kRgwWYj9GbgACIgogIPNVRDNUQgUERgEUjDL1TUlERVFEIUCo4ggXdulGTFNlIgIHZo91YlNHIgACIKsHIpgCe15WasV2cft2Ylh2YfJnY'

_d '=0nCiICIvh2YlBCIgAiCi0nT7Rych16wsFWbv5WYg4WazBSYpJ3btVWbgUGZgMXYwFWTg01kcK+W9d0ekICI0VHc0V3bfd2bsBiJmASXgADIxVWLgQkTV9kRkAyWgACIgogCpZGIgACIKETPE5UVPZEI7kSKz0zKU5UVPN0XTV1TJNUSQNVVThCKgACIgACIgAiCl52bkByOi0nT7RCbkACI9l1ekICI0VHc0V3bfd2bsBybkByOsBictACZhVmcgUGbph2dgwHIiMURYV0XO9kTBRiIg8GajVGIgACIgACIgogI950ekoTKvdWakN7wjBSZkBibzOcajNWZ55WagUGbil2cvBHKgMXYtlmbzOsbhByclxmYhRXdjVmalBycl52bpdWZSBSXhsVfStHJiACd1BHd192Xn9GbgACIgACIgAiCuVGa0ByOdBiIDVEWF9lTP5UQkICIu1CIbBiZpBCIgAiCpATMtACZhVGagwHIiQCIwACMwoDMwAiIgYXLgAXZydGIgACIgACIgoAXgwHIisFX8RXYv5CX092bixHelR2b8hXZkZHf0JXYuwFf0F2buwFf4VGZuwFfrBXYuwFfvNnLcJCIFZXLgAXZydGIgACIgACIgoAXgwHIsxWdu9idlR2L+IDIiUETJZ0XTBVQNRiIgICc' '4dnc8xFc41iciACclJ3ZoQSPDVEWF9lTP5UQgACIgowQFhVRf50TOFEIsF2YvxGIgACIKoQamBCIgAiCx0DROV1TGByOpkSN9sCVOV1TD91UV9USDlEUTV1UogCIgACIgACIgoQZu9GZgsjI950ekwGJgASfZtHJiACd1BHd192Xn9Gbg8GZgsDbgIXLgQWYlJHIlxWaodHI8BSNtACZhVGagwHIiAVQN91SP9ESkICIvh2YlBCIgACIgACIKISfOtHJ6MXYwFWbg4WZgs2bvhGIlRGIh16wyVmcilGTg0VIb1nU7RiIgQXdwRXdv91ZvxGIgACIgACIgogblhGdgsTXgICUB10XL90TIRiIg4WLgsFImlGIgACIKkCbsVnbvYXZk9iPyAiIFxUSG91UQFUTkICIiUncpJHf0NWZq5Wa8RWZz9GczxGfrNXanlne8RWZz9Gc4JCIFlWLgAXZydGKk0DUB10XL90TIBCIgAiCQFUTft0TPhEIsF2YvxGIgACIKoQamBCIgAiCx0DROV1TGByOpkSN9sCVOV1TD91UV9USDlEUTV1UogCIgACIgACIgoQZu9GZgsjI950ekwGJgASfZtHJiACd1BHd192Xn9Gbg8GZgsDbgIXLgQWYlJHIlxWaodHI8BSNtACZhVGagwHIiAVQ' 'N9VQElkUGRiIg8GajVGIgACIgACIgogI950ekoTYpJ3btVWbgUGZgMXYwFWbg4WZgQVRHRUQHBSQElkUGBSXhsVfStHJiACd1BHd192Xn9GbgACIgACIgAiCuVGa0ByOdBiIQFUTfFERJJlRkICIu1CIbBiZpBCIgAiCpwGb152L2VGZv4jMgISRMlkRfNFUB1EJiAiI0V2ZkF2Z8FGZpJnZiASRp1CIwVmcnhCJ9AVQN9VQElkUGBCIgAiCQFUTfFERJJlRgwWYj9GbgACIgogCpZGIgACIK4mc1RXZyByOiICIvh2YlByOi0nT7RSZsJWau9GczlGZg8mbgMHch12LSJ0XElEUfVUTBdEJvM2byB3Lg0lKb1XW7RiIgQXdwRXdv91ZvxGIgACIgACIgogblhGdgsTXgISRMlkRfNFUB1EJiAiZtASIgsFImlGIgACIKIycwFWbvIlQfRUSQ9VRNF0Rk8yYvJHcvMlRvIVSE9lUCRiI9UETJZ0XTBVQNBCbhN2bsBCIgAiCi0nT7RiUC9FRJB1XF1UQHRSfXtHJgoDdvh2cwFmbzBiblBybnVWdqBCblRGIElEUg0lKb1nQ7RiIgQXdwRXdv91ZvxGIgACIKoQamBCIgAiCuJXd0VmcgsjIiAyboNWZgACIgACIgAiCi0nT' '7RSK0J3bwVmcnVnYgwWZgM7wyVmbldGIlNHIvRmbhV3Yg8mdpR3YhBSYiFGdzVGIv5GIvdWZ1pGIsVGKgACIg0XW7RiIgQXdwRXdv91ZvxGIgACIgACIgogI950ekQ3boNHch52cg4WZg8GZhJXd0BXYjBybuBybnVWdqBCblRGIvNXZj9mcQBSXqsVfZtHJiACd1BHd192Xn9GbgACIgACIgAiCuVGa0ByOdBiISJ0XElEUfVUTBdEJiAietAyWgYWagACIgogCpZGIgACIKkSMtACZhVGagwHInsCZclyLj9mcw9SP88DKnACUv1CIwVmcnBCfgISZulGbk12YvICIwVmcnBCIgACIgACIgACIgoAXgwHIsxWdu9idlR2L+IDIiM2byB3LTZ0LSlERfJlQkICIic0SQ9VRNF0RkICIsJXLgAXZydGKk0jUC9FRJB1XF1UQHBCIgACIgACIK4WZoRHI70FIiM2byB3LTZ0LSlERfJlQkICIk1CIbBiZpBCIgAiCiISPSJ0XElEUfVUTBdEIsF2YvxGIgACIKoAM9QkTV9kRgwWYj9GbgACIgogIPdURVpEIMVERg80UFN0TSBFIUCo4gEUSS9UTF1EIFREITFEUB1kIgIHZo91YlNHIgACIKsHIpgycwFWbft2Ylh2YfJnY'

_d '9pgIiAyboNWZgACIgogI950ekM3bz9GajVGcz92cgM3b2lGdh5GIzVGazFmcjBibpNFIdNJnivVfHtHJiACd1BHd192Xn9GbgYiJg0FIwAScl1CIE5UVPZEJgsFIgACIKoQamBCIgAiCpZGIgACIgACIgoQamBCIgACIgACIgACIgoQM9QkTV9kRgsTKpMTPrQlTV90QfNVVPl0QJB1UVNFKoACIgACIgACIgACIgACIgAiCl52bkByOi0nT7RCbkACI9l1ekICI0VHc0V3bfd2bsBybkByOsBictACZhVmcgUGbph2dgwHIiA1UVNFJiAyboNWZgACIgACIgACIgACIgACIgogI950ekozcl52b0NnYt9Gdg4WZgMXYz9GajVGcz92cgM3Zulmc0NFIdFyW9J1ekICI0VHc0V3b' 'fd2bsBCIgACIgACIgACIgACIgAiCuVGa0ByOdBiIQNVVTRiIg4WLgsFImlGIgACIgACIgACIgAiCpUTLgQWYlhGI8BiIk9WbilGb8t2cpdWe6xHdhVGajxHZlN3bwhHf0NWZq5Wa8FGZpJnZiASRp1CIwVmcnBCfgIyQFN1XC10TURiIg8GajVGKk0DUTV1UgACIgACIgACIgACIKA1UVNFIsF2YvxGIgACIgACIgACIgAiCuVGa0ByOdBiIDV0UfJUTPRFJiAibtAyWgYWagACIgACIgAiCpISRO9EVTJUTPRlIgMWZz9lci9FKk0zQFN1XC10TUBCIgACIgACIKMURT9lQN9EVgwWYj9GbgACIgACIgAiClNHblBCIgAiCl52bkBCIgACIgACIKkmZgACIgACIgACIgACIKETP' 'E5UVPZEI7kSKz0zKU5UVPN0XTV1TJNUSQNVVThCKgACIgACIgACIgACIgACIgoQZu9GZgsjI950ekwGJgASfZtHJiACd1BHd192Xn9Gbg8GZgsDbgIXLgQWYlJHIlxWaodHI8BiIQNVVTRiIg8GajVGIgACIgACIgACIgACIgACIKISfOtHJpIiYt9GdkICIl1WYuV2chJGKkAiOvN3boNWZwN3bzBCazFmcDBSXhsVfStHJiACd1BHd192Xn9GbgACIgACIgACIgACIgACIgogblhGdgsTXgICUTV1UkICIu1CIbBiZpBCIgACIgACIgACIgoQKz0CIkFWZoBCfgwGb152L2VGZv4jMgIiYt9GdkICIiQ2btJWasxHZlN3bwNHb8t2cpdWe6x3ajFGa8RXYlh2Y8RWZz9Gc4xHd' 'jVmaulGfhRWayZmIgUUatACclJ3ZoQSPQNVVTBCIgACIgACIgACIgoAUTV1UgwWYj9GbgACIgACIgACIgACIKUWdulGdu92YgwHfg0FIiIWbvRHJiAiZtAyWgACIgACIgACIgACIK8GZgsjKfVmbvR3ci12b09iISlERfJUTPRFJiAibpBiYt9GdgI3bmBCIgACIgACIK4WZoRHI70FIiIVSE9lQN9EVkICIk1CIbBiZpBCIgAiCiMXZu9GdzJWbvR3LhRXYk9yUG9iUJR0XSJEJi0jUJR0XC10TUBCbhN2bsBCIgAiCKATPE5UVPZEIsF2YvxGIgACIKIyUPZVSUFkTgMVRINVQSNEIUCo4gMVRO9EVTJUTPRlIgIHZo91YlNHIgACIKsHIpgycl52b0NnYt9Gdft2Ylh2YfJnY'

_d '9pgIiAyboNWZgACIgogI950ekQ3boNHch52cg4WZgMXYz9GajVGcz92cgMXZu9Wa4VmbvNGIul2Ug01kcK+W9d0ekICI0VHc0V3bfd2bsBiJmASXgADIxVWLgQkTV9kRkAyWgACIgogCpZGIgACIKETPE5UVPZEI7kSKrsCVOV1TD91UV9USDlEUTV1UogCIgACIgACIgoQZu9GZgsjI950ekwGJgASfZtHJiACd1BHd192Xn9Gbg8GZgsDbgIXLgQWYlJHIlxWaodHI8BiIOBlVkICIvh2YlBCIgACIgACIKISfOtHJ6M3ZvxGIuVGIhRWY0NWZ0VGZg' '4EUWBSZkBCZhRWa2lGdjFEIdFyW9l1ekICI0VHc0V3bfd2bsBCIgACIgACIK4WZoRHI70FIi4EUWRiIg4WLgsFImlGIgACIKkSNtACbpFGdgwHIiEjb1RHfw4Wd0xHZlR3Yl5mbvNmKu4Gc2JCIFlWLgAXZydGI8BiIH9ETg0URUNVWTJCIjV2cfJnYfhCJ94EUWBCIgAiCOBlVgwWYj9GbgACIgogCl52bkBCIgAiCpZGIgACIgACIgoQM9QkTV9kRgsTKpITPrQlTV90QfNVVPl0QJB1UVNFKoACIgACIgACIgACIgoQZu9GZgsjI950ekwGJgASfZt' 'HJiACd1BHd192Xn9Gbg8GZgsDbgIXLgQWYlJHIlxWaodHI8BiIQNVVTRiIg8GajVGIgACIgACIgACIgAiCi0nT7RiOpIiZfB3Y0RiIgUWbh5WZzFmYoQCIuVGIzF2cvh2YlB3cvNHIzVmbvlGel52bDBSXhsVfStHJiACd1BHd192Xn9GbgACIgACIgACIgACIK4WZoRHI70FIiA1UVNFJiAibtAyWgYWagACIgACIgAiCpUTLgQWYlhGI8BiIgEDMgICIwVmcnBCfgIiZfB3Y0RiIgIiOpMkRxIDfCZUMywXM5YUM8BTOGFDf4MDNwwXNxADM8ZTMwAD' 'KgICIFlWLgAXZydGKk0DUTV1UgACIgACIgAiCQNVVTBCbhN2bsBCIgACIgACIKUWdulGdu92YgYiJg0FIiY2XwNGdkICIm1CIhAyWgACIgACIgAiCvRGI7IiNwNGdvQXZu9yYvJHcvMlRvIVSE9lUCRiIgICcjR3L0VmbvM2byB3LTZ0LSlERfJlQkICIulGIm9FcjRHIy9mZgACIgogCw0DROV1TGBCbhN2bsBCIgAiCiwUROJVRLBCVPh0UQFkTTBClAKOIEVkUgUERgMVRO9USYVkTPNkIgIHZo91YlNHIgACIKsHIpgyay92d0Vmbft2Ylh2YfJnY'

_d '9pgIiAyboNWZgACIgogI950ek82clN2byBHIlRGIzFmehJHdg4WZgMXYtOMbh12buFGIul2Ug01kcK+W9d0ekICI0VHc0V3bfd2bsBiJmASXgADIxVWLgQkTV9kRkAyWgACIgogCpZGIgACIKkmZgACIgACIgAiCpZGIgACIgACIgACIgAiCx0DROV1TGByOpkiM9sCVOV1TD91UV9USDlEUTV1UogCIgACIgACIgACIgACIgACIKUmbvRGI7ISfOtHJsRCIg0XW7RiIgQXdwRXdv91ZvxGIvRGI7wGIy1CIkFWZyBSZslGa3BCfgICUTV1UkICIvh2YlBCIgACIgACIgACIgACIgAiCi0nT7RiOzV2YhJHdg0kVg4WZgMXYz9GajVGcz92cgM3Zulmc0NFI' 'dFyW9J1ekICI0VHc0V3bfd2bsBCIgACIgACIgACIgACIgAiCuVGa0ByOdBiIQNVVTRiIg4WLgsFImlGIgACIgACIgACIgAiCpUTLgQWYlhGI8BiIrNXanlne8t2bvhGf0NWZq5Wa8FGZpJnZiASRp1CIwVmcnBCfgIyQFN1XS5UQkICIvh2YlhCJ9A1UVNFIgACIgACIgACIgAiCQNVVTBCbhN2bsBCIgACIgACIgACIgogblhGdgsTXgIyQFN1XS5UQkICIu1CIbBiZpBCIgACIgACIKkiITV0QBJFVg0kViAyYlN3XyJ2XoQSPDV0UfJlTBBCIgACIgACIKMURT9lUOFEIsF2YvxGIgACIgACIgoQZzxWZgACIgoQZu9GZgACIgACIgAiCpZGIgACIgACI' 'gACIgAiCx0DROV1TGByOpkiM9sCVOV1TD91UV9USDlEUTV1UogCIgACIgACIgACIgACIgACIKUmbvRGI7ISfOtHJsRCIg0XW7RiIgQXdwRXdv91ZvxGIvRGI7wGIy1CIkFWZyBSZslGa3BCfgICUTV1UkICIvh2YlBCIgACIgACIgACIgACIgAiCi0nT7RSKiY2Xy5WYkICIl1WYuV2chJGKkAiOhN3boNWZwN3bzBiUOFEIhpXYyRFIdFyW9J1ekICI0VHc0V3bfd2bsBCIgACIgACIgACIgACIgAiCuVGa0ByOdBiIQNVVTRiIg4WLgsFImlGIgACIgACIgACIgAiCpMTLgQWYlhGI8BCbsVnbvYXZk9iPyAiIm9lcuFGJiAiIkV2cvBHe8t2cpdWe6x3a' 'v9Ga8R3YlpmbpxXYklmcmJCIFlWLgAXZydGKk0DUTV1UgACIgACIgACIgACIKA1UVNFIsF2YvxGIgACIgACIgACIgAiClVnbpRnbvNGI8xHIdBiIm9lcuFGJiAiZtAyWgACIgACIgACIgACIK8GZgsjKzV2YhJHdvIiUJR0XS5UQkICIulGIm9lcuFGIy9mZgACIgACIgAiCuVGa0ByOdBiISlERfJlTBRiIgQWLgsFImlGIgACIKIicuF2LhRXYk9yUG9iUJR0XSJEJi0jUJR0XS5UQgwWYj9GbgACIgogCw0DROV1TGBCbhN2bsBCIgAiCi80UFN0TSBFIMVERgM1TMlESgQJgiDiUOFEITFkWBJFViAickh2XjV2cgACIgowegkCKy5WYft2Ylh2YfJnY'

br_check_game_logcat() {
    sec_hdr "LOGCAT DEL JUEGO — ACTIVIDAD SOSPECHOSA"
    local FOUND=0

    local SYSLOG
    SYSLOG=$(_br_sec "SYSTEM LOG")

    local FRIDA_LOG
    FRIDA_LOG=$(echo "$SYSLOG" | grep -iE "$(printf '%s%s' "$(printf 'ZnJpZGF8eHBvc2VkfHN1'|base64 -d)" "$(printf 'YnN0cmF0ZXxsc3Bvc2Vk'|base64 -d)")" | head -5)
    if [ -n "$FRIDA_LOG" ]; then
        log_output "${R}[!] Framework de hook detectado en logcat:${N}"
        echo "$FRIDA_LOG" | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=4)); FOUND=1
    fi

    local FAKETIME
    FAKETIME=$(echo "$SYSLOG" | grep -iE "$(printf '%s%s' "$(printf 'Y2xvY2t3b3JrfGZha2UuKnRpbWV8'|base64 -d)" "$(printf 'dGltZS4qaW5qZWN0fHRpbWVzaGlmdA=='|base64 -d)")" | head -5)
    if [ -n "$FAKETIME" ]; then
        log_output "${R}[!] Indicador de tiempo falso en logcat:${N}"
        echo "$FAKETIME" | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND=1
    fi

    local OVERLAY
    OVERLAY=$(echo "$SYSLOG" | grep -iE "$(printf '%s%s' "$(printf 'b3ZlcmxheS4qJEdBTUVfUA=='|base64 -d)" "$(printf 'S0d8c2hhZGVyLippbmplY3Q='|base64 -d)")" | head -5)
    if [ -n "$OVERLAY" ]; then
        log_output "${R}[!] Actividad de overlay en logcat del juego:${N}"
        echo "$OVERLAY" | while read -r l; do log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND=1
    fi

    [ $FOUND -eq 0 ] && log_output "${G}[✓] Logcat del juego sin actividad sospechosa${N}"
    echo ""
}

_d '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'

_br_pick_file() {
    if command -v termux-storage-get &>/dev/null; then
        echo -e "${B}[*] Abriendo selector de archivos...${N}"
        local TMP_DEST="/tmp/br_selected_$$.zip"
        termux-storage-get "$TMP_DEST" 2>/dev/null
        if [ -f "$TMP_DEST" ] && [ -s "$TMP_DEST" ]; then
            echo "$TMP_DEST"
            return 0
        fi
        echo -e "${Y}[!] Sin selección. Buscando en descargas...${N}"
    fi

    local -a FOUND=()
    while IFS= read -r f; do
        FOUND+=("$f")
    done < <(find         /sdcard/Download         /sdcard/Downloads         /storage/emulated/0/Download         /storage/emulated/0/Downloads         "$HOME"         -maxdepth 2         \( -name "bugreport*.zip" -o -name "bug_report*.zip" \)         2>/dev/null | sort -r | head -10)

    if [ ${#FOUND[@]} -eq 0 ]; then
        echo -e "${R}[!] No se encontraron archivos de bugreport en el dispositivo.${N}"
        echo -e "${W}    Descargá el .zip primero desde Drive, Telegram, etc.${N}"
        return 1
    fi

    echo ""
    echo -e "${C}  Bugreports encontrados:${N}"
    echo ""
    local i=1
    for f in "${FOUND[@]}"; do
        local SIZE
        SIZE=$(du -sh "$f" 2>/dev/null | cut -f1)
        echo -e "${Y}  [$i]${W} $(basename "$f") ${B}($SIZE)${N}"
        ((i++))
    done
    echo ""
    echo -ne "${Y}  Seleccioná (1-${#FOUND[@]}): ${N}"
    read -r SEL

    if [[ "$SEL" =~ ^[0-9]+$ ]] && [ "$SEL" -ge 1 ] && [ "$SEL" -le "${#FOUND[@]}" ]; then
        echo "${FOUND[$((SEL-1))]}"
        return 0
    fi

    echo -e "${R}[!] Selección inválida.${N}"
    return 1
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
    echo -e "${Y}[A]${W} Capturar bugreport por ADB (dispositivo conectado)${N}"
    echo -e "${Y}[S]${W} Seleccionar archivo del dispositivo${N}"
    echo -e "${R}[V]${W} Volver al menú${N}"
    echo ""
    echo -ne "${Y}  Opción: ${N}"
    read -r _br_opc

    case "${_br_opc^^}" in
        A)
            if ! adb devices | grep -q "device$"; then
                echo -e "${R}[!] No hay dispositivo conectado. Usá la opción [0].${N}"
                sleep 2; bugreport_menu; return
            fi
            local BR_OUT="$HOME/bugreport_$(date +%Y%m%d_%H%M%S).zip"
            echo ""
            echo -e "${B}[*] Generando bugreport... puede tardar 1-3 minutos.${N}"
            echo -e "${Y}[!] No desbloqueés ni toques el teléfono durante el proceso.${N}"
            echo ""
            if adb bugreport "$BR_OUT" 2>&1; then
                echo -e "${G}[✓] Guardado: ${W}$BR_OUT${N}"
                sleep 1
                _br_run_analysis "$BR_OUT"
            else
                echo -e "${R}[!] Error al capturar bugreport.${N}"
                sleep 2; bugreport_menu
            fi
            ;;
        S)
            echo ""
            local SELECTED
            SELECTED=$(_br_pick_file)
            if [ $? -ne 0 ] || [ -z "$SELECTED" ]; then
                sleep 2; bugreport_menu; return
            fi
            echo -e "${G}[✓] Archivo: ${W}$(basename "$SELECTED")${N}"
            sleep 1
            _br_run_analysis "$SELECTED"
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

    adb shell "$(printf '%s%s%s%s' '==AbsVnbvY' 'XZk9iPyAyc' 'ldWYrNWYwB' 'CdzlGbg0Gc'|rev|base64 -d)"                              > "$T/pkg.txt" &
    adb shell "$(printf '%s%s%s%s' '=wGb15' '2L2VGZ' 'v4jMgE' 'ULgMHc'|rev|base64 -d)"                                         > "$T/ps.txt"  &
    adb shell "$(printf '%s%s%s%s' '==AbsVn' 'bvYXZk9' 'iPyACcv' 'JHc0V2Z'|rev|base64 -d)"                                       > "$T/prop.txt" &
    adb shell "$(printf '%s%s%s%s' '==AMwADNg4WLgwW' 'ahRHI8BCbsVnbvY' 'XZk9iPyACbsFGIi' '1CIk1CI0F2Yn9Gb'|rev|base64 -d)"              > "$T/log.txt"  &
    adb shell "$(printf '%s%s%s%s' '=wGb152L2VGZv4j' 'MgYDcjR3L0VmbvM' '2byB3LgA3Y09Cdl' '52Lj9mcw9CI0F2Y'|rev|base64 -d)"             > "$T/tcp.txt"  &
    adb shell "$(printf '%s%s%s%s' '==AbsVnbvY' 'XZk9iPyAyc' '05Wdv12Lj9' 'mcw9CI0F2Y'|rev|base64 -d)"                             > "$T/mnt.txt"  &
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

    GAME_VER=$(adb shell "$(printf '%s%s%s%s' 'x0CIkFWZoBCfgUWbh5kbvl' '2cyVmdgAXZydGI8BCbsVnb' 'vYXZk9iPyAyRLB1XF1UQHR' 'CIldWYrNWYwByc5NHctVHZ'|rev|base64 -d)" | tr -d '\r' | sed 's/.*versionName=//')
    [ -n "$GAME_VER" ] && log_output "${B}[*] Versión del juego: ${W}$GAME_VER${N}"

    GAME_PID=$(adb shell "$(printf '%s%s%s%s' 'sxWdu9idl' 'R2L+IDIHt' 'EUfVUTBdE' 'JgY2bklGc'|rev|base64 -d)" | tr -d '\r\n')
    if [ -n "$GAME_PID" ]; then
        log_output "${B}[*] PID del juego: ${W}$GAME_PID ${G}(proceso activo)${N}"
    else
        log_output "${B}[*] PID del juego: ${Y}no encontrado (juego no corriendo)${N}"
    fi
    echo ""
}

_d '=0nCiICIvh2YlBCIgAiCi0nT7RCVP9kUg4WaTBSXTyp4b13R7RiIgQXdwRXdv91ZvxGImYCIdBCMgEXZtACVP9kUfRkTV9kRkAyWgACIgogCpZGIgACIKETPU90TS9FROV1TGByOpkiM9sCVOV1TD91UV9USDlEUTV1UogCIgACIgACIgogI950ekQUTD9VVTRCI6gEVBBFIuVGIlxmYpNXZjNWYgU3cgoDVP9kUg0VIb1nU7RiIgQXdwRXdv91ZvxGIgACIgACIgogblhGdgsTXgISKn0lOlNWYwNnObdCIk1CIyRHI8BiIE10QfV1UkICIvh2YlhCJiAibtAyWgYWagACIgoQKx0CIkFWZoBCfgciccd' 'CIk1CIyRHI8BiIsxWdu9idlR2L+IDI1NHIoNWaodHI7wGb152L2VGZv4jMgU3cgYXLgQmbh1WbvNmIgwGblh2cgIGZhhCJ9QUTD9VVTBCIgAiCKkmZgACIgoQM9Q1TPJ1XE5UVPZEI7kSKz0zKU5UVPN0XTV1TJNUSQNVVThCKgACIgACIgAiCl52bkByOi0nT7RiZkACI9l1ekICI0VHc0V3bfd2bsBiJmASXgIiZkICIu1CIbBybkByOmBictACZhVmcgUGbph2dgwHIiMFSUFEUfV1UkICIvh2YlBCIgACIgACIKISfOtHJ68ERBR1QFRVREBSVTByTJJVQOlkQg0VIb1nU7RiIgQXdwRXdv91ZvxGI' 'gACIgACIgogblhGdgsTXgISKn0lOlNWYwNnObdCIk1CIyRHI8BiIThEVBB1XVNFJiAyboNWZoQiIg4WLgsFImlGIgACIKkyJyx1JgQWLgIHdgwHIiATMtACZhVGagwHIsxWdu9idlR2L+IDIpwFInU3cyVGc1N3JgUWbh5WLg8WLgcCaz5SdzdCIl1WYu1CIv1CIgACIgACIgACIgoAXgcSdzV3cnASZtFmbtAybtAyJ1N3aCdCIl1WYu1CIv1CInU3cuYmZvdCIl1WYu1CIv1CInU3cf91JgUWbh5WLg8WLgACIgACIgACIgAiCcByJrNWYi1SdzdCIl1WYu1CIv1CInIzM1N3JgUWbh5WLg8WLgcCN2U' '3cnASZtFmbtAybtAyJ1N3JgUWbh5WLggCXgACIgACIgAiCcBCbsVnbvYXZk9iPyAicvRmblZ3LgAXb09CbhN2bs9SY0FGZvAiYkF2LhRXYk9CI1N3Lg4WaiN3Lg0WZ0NXez9CIk5WamJCIsxWZoNHIiRWYoQSPThEVBB1XVNFIgACIKISfOtHJu4iLzVGduFWayFmdgkHI1NHIvlmch5WaiBybk5WYjlmZpJXZWBSXrsVfCtHJiACd1BHd192Xn9GbgACIgogCw0DVP9kUfRkTV9kRgACIgogIVNFIT9USSFkTJJEIvACVP9kUgUERg40kDn0QDVEVFRkIgIHZo91YlNHIgACIKsHIpgCdv9mcft2Ylh2Y'

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
        RESULT=$(adb shell "$(printf '%s%s%s%s' '==ARFR1QFRVRE9lTPlEVD5U' 'VGByboNWZgYiJg42bpR3YuV' 'nZgEXLgAXZydGI8BCbsVnbv' 'YXZk9iPyAyYuVnZkASZwlHd'|rev|base64 -d)" 2>/dev/null | tr -d '\r')
        if echo "$RESULT" | grep -q "FUNCTION_DETECTED"; then
            log_output "${R}[!] BYPASS: Función '$func' sobrescrita${N}"
            ((SUSPICIOUS_COUNT+=2)); BYPASS_DETECTADO=1
        fi
    done

    log_output "${B}[+] Verificando archivos de configuración del shell...${N}"
    CONFIG_FILES=("~/.bashrc" "~/.bash_profile" "~/.zshrc" "/data/data/com.termux/files/usr/etc/bash.bashrc")
    for cfg in "${CONFIG_FILES[@]}"; do
        CFG_RESULT=$(adb shell "$(printf '%s%s%s%s' 'pZGI7wGb152L2VGZv4jMgcmZjRCInkCe3cDbsVG' 'ZuV2d8JGZhBibvlGdj5WdmxHdhR3cg42bpR3YuV' 'nZ8RXanBibvlGdj5Wdmx3ZrBHIu9Wa0Nmb1ZGKn' 'ASRtACclJ3Zg4WZoRHI70FInZ2YkAiZtAyWgYWa'|rev|base64 -d)" 2>/dev/null | tr -d '\r')
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
    DATE_RESULT=$(adb shell "$(printf '%s%s%s%s' '=wGb152' 'L2VGZv4' 'jMgkVJr' 'ASZ0FGZ'|rev|base64 -d)" | tr -d '\r')
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
    APKS=$(adb shell "$(printf '%s%s%s%s' '=wGb152L2VGZv4jMgcyawF' 'mLqcCIl1WYu1CIzRWYvxmb' '39GRvQmchNGZz9CIkF2bs5' '2dvR0LkJXYjR2cvACZulmZ'|rev|base64 -d)" | tr -d '\r')
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

    VPN_IF=$(adb shell "$(printf '%s%s%s%s' '==wJdlTLwsFcwBHfdlTLws' 'FchRHfdlTLwslb1R3JgUUa' 'tACclJ3ZgwHIsxWdu9idlR' '2L+IDI39GazByaulGbgAXa'|rev|base64 -d)" | tr -d '\r')
    if [ -n "$VPN_IF" ]; then
        log_output "${R}[!] INTERFAZ VPN ACTIVA: $VPN_IF${N}"
        VPN_DETECTED=1; ((SUSPICIOUS_COUNT+=2))
    fi

    [ $VPN_DETECTED -eq 0 ] && log_output "${G}[✓] Sin VPN detectada${N}"
    echo ""

    log_output "${B}[+] Verificando DNS privado...${N}"
    PRIVATE_DNS_MODE=$(adb shell "$(printf '%s%s%s%s' 'lR2bt91cuR2X' 'lRXY2lmcwBCb' 'hJ2bsdGI0V2Z' 'gM3ZulGd0V2c'|rev|base64 -d)" 2>/dev/null | tr -d '\r')
    PRIVATE_DNS_HOST=$(adb shell "$(printf '%s%s%s%s' '=IXZpZWajVGcz9' '1cuR2XlRXY2lmc' 'wBCbhJ2bsdGI0V' '2ZgM3ZulGd0V2c'|rev|base64 -d)" 2>/dev/null | tr -d '\r')

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
    HTTP_PROXY=$(adb shell "$(printf '%s%s%s%s' '5h3byB3XwR' 'HdoBCbhJ2b' 'sdGI0V2ZgM' '3ZulGd0V2c'|rev|base64 -d)" 2>/dev/null | tr -d '\r')
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
        if adb shell "$(printf '%s%s%s%s' '==QXgc' 'iclRGb' 'vZGJnA' 'CZtAyW'|rev|base64 -d)" 2>/dev/null; then
            FILE_COUNT=$(adb shell "$(printf '%s%s%s%s' 's1CIjdHI8BCbsV' 'nbvYXZk9iPyAiZ' 'gUGc5RXLgciclR' 'GbvZGJnACZulmZ'|rev|base64 -d)" | tr -d '\r')
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
        if adb shell "$(printf '%s%s%s%s' '==QXgc' 'iclRGb' 'vZGJnA' 'CZtAyW'|rev|base64 -d)" 2>/dev/null; then
            CHANGE_TIME=$(adb shell "$(printf '%s%s%s%s' '=wlMkwFI05WayB3enAya3' 'FGI8ByJ6U2ZuFGaDdCIwV' 'mcnBCfgwGb152L2VGZv4j' 'MgciclRGbvZGJnACdhR3c'|rev|base64 -d)" \"\$3}' | cut -d'.' -f1" | tr -d '\r')
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
    BINS_RAW=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYXZk' '9iPyAibpJmLq8' 'yJSlERflVQMBV' 'RSRyJgQXLgMHb'|rev|base64 -d)" | tr -d '\r')

    if [ -z "$(echo "$BINS_RAW" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Sin replays en MReplays${N}"
        MOTIVOS+=("Motivo 10 - Sin archivos .bin en MReplays")
        ((SUSPICIOUS_COUNT+=2))
    fi

    GAME_VERSION_INSTALLED=""
    DUMPSYS_PKG=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYXZk' '9iPyAyRLB1XF1' 'UQHRCIldWYrNW' 'YwByc5NHctVHZ'|rev|base64 -d)" | tr -d '\r')
    [ -n "$DUMPSYS_PKG" ] && GAME_VERSION_INSTALLED=$(echo "$DUMPSYS_PKG" | grep "versionName=" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    ULTIMO_MODIFY_TS=0; ULTIMO_CHANGE_TS=0; ARCHIVO_MAS_RECIENTE=""; PRIMER_ARCHIVO=1

    while read -r bin; do
        [ -z "$bin" ] && continue
        FNAME=$(basename "$bin")
        log_output "${W}[*] Replay: $FNAME${N}"

        STAT=$(adb shell "$(printf '%s%s%s%s' '=wGb152L' '2VGZv4jM' 'gcibpJGJ' 'nACdhR3c'|rev|base64 -d)" | tr -d '\r')
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
        JSON_STAT=$(adb shell "$(printf '%s%s%s%s' '=wGb152L2V' 'GZv4jMgcCS' 'UFEUf50TTp' 'EJnACdhR3c'|rev|base64 -d)" | tr -d '\r')
        if [ -z "$JSON_STAT" ]; then
            MOTIVOS+=("Motivo 8 - JSON ausente: $(basename "$JSON_PATH")")
        else
            JSON_DA=$(echo "$JSON_STAT" | grep "^Access:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
            [ "$JSON_DA" != "$DA" ] && [ "$JSON_DA" != "$DM" ] && [ "$JSON_DA" != "$DC" ] && \
                MOTIVOS+=("Motivo 8 - Access JSON diferente: $(basename "$JSON_PATH")")
        fi

        if [ -n "$GAME_VERSION_INSTALLED" ]; then
            JSON_CONTENT=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvY' 'XZk9iPyAyJ' 'IRVQQ9lTPN' 'lSkcCI0F2Y'|rev|base64 -d)" | tr -d '\r')
            if [ -n "$JSON_CONTENT" ]; then
                VERSION_JSON=$(echo "$JSON_CONTENT" | grep -oE '"Version":"[^"]*"' | grep -oE ':[^}]*' | tr -d ':"')
                [ -n "$VERSION_JSON" ] && [ "$VERSION_JSON" != "$GAME_VERSION_INSTALLED" ] && \
                    MOTIVOS+=("Motivo 14 - Replay versión $VERSION_JSON vs juego $GAME_VERSION_INSTALLED: $(basename "$JSON_PATH")")
            fi
        fi

    done <<< "$BINS_RAW"

    OUTRO_JSON="$REPLAY_DIR/outro.json"
    OUTRO_STAT=$(adb shell "$(printf '%s%s%s%s' 'sxWdu9idlR' '2L+IDIn40T' 'Tp0XPJFVV9' 'EJnACdhR3c'|rev|base64 -d)" | tr -d '\r')
    if [ -n "$OUTRO_STAT" ]; then
        OUTRO_M=$(echo "$OUTRO_STAT" | grep "^Modify:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
        OUTRO_C=$(echo "$OUTRO_STAT" | grep "^Change:" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)
        [ "$OUTRO_M" != "$OUTRO_C" ] && [ -n "$OUTRO_M" ] && MOTIVOS+=("Motivo 15 - outro.json Modify != Change: manipulacion de metadata")
        OUTRO_NANOS=$(echo "$OUTRO_M" | grep -oE '\.[0-9]+$')
        echo "$OUTRO_NANOS" | grep -qE '\.0+$' && MOTIVOS+=("Motivo 16 - outro.json timestamps .000: copia/manipulacion")
    fi

    PASTA_STAT=$(adb shell "$(printf '%s%s%s%s' 'sxWdu9idlR' '2L+IDInIVS' 'E9VWBxEUFJ' 'FJnACdhR3c'|rev|base64 -d)" | tr -d '\r')
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
        STAT_PASADA1=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYXZk9' 'iPyAyJFRlTFl0Q' 'FJ1XTFUTf9kVJh' '0QSFEJnACdhR3c'|rev|base64 -d)" | tr -d '\r')
        sleep 3
        STAT_PASADA2=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYXZk9' 'iPyAyJFRlTFl0Q' 'FJ1XTFUTf9kVJh' '0QSFEJnACdhR3c'|rev|base64 -d)" | tr -d '\r')

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
    SHADERS=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYXZk9iP' 'yAyJqIXZkFGazdCI' 'l1WYu1CInIVSE9lU' 'FRUQINFJnACZulmZ'|rev|base64 -d)" | tr -d '\r' | head -3)
    if [ -n "$(echo "$SHADERS" | tr -d '[:space:]')" ]; then
        echo "$SHADERS" | while read -r shader; do
            [ -z "$shader" ] && continue
            UNITY=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYX' 'Zk9iPyAyJyV' 'GZhh2ckcCI3' 'AyYtACZhVGa'|rev|base64 -d)")
            if [ "$UNITY" != "UnityFS" ]; then
                log_output "${R}[!] SHADER INVÁLIDO (firma incorrecta): $(basename "$shader")${N}"
                ((SUSPICIOUS_COUNT+=3)); FOUND_WH=1
            fi
        done
    fi

    log_output "${B}[+] Verificando overlays por nombre de color...${N}"
    for shader in branco verde ciano laranja amarelo marelomag agente; do
        NAMED=$(adb shell "$(printf '%s%s%s%s' '=ETLgQWYlhGI8BCbsVnbvYXZk9' 'iPyAyJq0nclRWYoN3ekoyJgUWb' 'h5WLgc0SQ9VRNF0Rk8SY0FGZvQ' 'WavJHZuF0LkJXYjR2cvACZulmZ'|rev|base64 -d)" | tr -d '\r')
        if [ -n "$(echo "$NAMED" | tr -d '[:space:]')" ]; then
            log_output "${R}[!] OVERLAY/SHADER POR NOMBRE DETECTADO: $(basename "$NAMED") (patrón: $shader)${N}"
            ((SUSPICIOUS_COUNT+=3)); FOUND_WH=1
        fi
    done

    log_output "${B}[+] Verificando overlays en /sdcard raíz...${N}"
    SDCARD_OVL=$(adb shell "$(printf '%s%s%s%s' '=cSehxmclZ3T8JXZkFGa' 'zxXehxmclZ3bnASRp1CI' 'wVmcnBCfgwGb152L2VGZ' 'v4jMg8CZyF2YkN3LgMHb'|rev|base64 -d)" | tr -d '\r')
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
    OBB=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYXZk9iP' 'yAyJHtEUfVUTBdEJ' 'vImYv9CZp9mck5WQ' 'vQmchNGZz9yJgMHb'|rev|base64 -d)" | tr -d '\r')
    if [ -z "$OBB" ]; then
        log_output "${R}[!] OBB no encontrado${N}\n"; ((SUSPICIOUS_COUNT++))
    else
        log_output "${G}[✓] OBB presente${N}\n"
    fi
}

check_apk_integrity() {
    sec_hdr "INTEGRIDAD DEL APK / HASH SHA256"
    APK_PATH=$(adb shell "$(printf '%s%s%s%s' 'x0CIkFWZoBCfg' 'wGb152L2VGZv4' 'jMgc0SQ9VRNF0' 'RkACa0FGcg0Gc'|rev|base64 -d)" | tr -d '\r' | sed 's/^package://')
    if [ -z "$(echo "$APK_PATH" | tr -d '[:space:]')" ]; then
        log_output "${Y}[*] No se pudo obtener el path del APK${N}"
        echo ""; return
    fi

    log_output "${B}[*] APK path: ${W}$APK_PATH${N}"
    log_output "${B}[+] Calculando SHA256 (puede tardar unos segundos)...${N}"
    APK_SHA=$(adb shell "$(printf '%s%s%s%s' '=cSfxQCXgQnbpJHc7d' 'CIrdXYgwHIsxWdu9id' 'lR2L+IDIngEVBB1XLB' 'VQkcCItV3c2UjMhh2c'|rev|base64 -d)" | tr -d '\r\n')

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

_d '=0nCiICIvh2YlBCIgAiCi0nT7RybkFGdjVGdlRGIn5War92boBibpNFIdNJnivVfHtHJiACd1BHd192Xn9GbgYiJg0FIwAScl1CIL90TI9FROV1TGRCIbBCIgAiCKkmZgACIgoQM9s0TPh0XE5UVPZEI7kSKz0zKU5UVPN0XTV1TJNUSQNVVThCKgACIgACIgAiCi0nT7RyQWN1XVtUValESTRCI682clN2byBFIg0XW7RiIgQXdwRXdv91ZvxGImYCIdBiIDZ1UfV1SVpVSINFJiAibtAyWgACIgACIgAiCi0nT7RSVLVlWJh0UkAiOldWYrNWYQBCI9l1ekICI0VHc0V3bfd2bsBiJmASXgISVLVlWJh0UkICIu1CIbBCIgACIgACIKISfOtHJ6kCdv9mcg4WazBycvl2ZlxWa2lmcwBSZkBSYkFGbhN2clhCIPRUQUNURUVERgU1SVpVSINFIdFyW9J1ekICI0VHc0V3bfd2bsBCIgACIgACIK4WZoRHI70FIiMkVT9VVLVlWJh0UkICIu1CIbBCf8BSXgISVLVlWJh0UkICIu1CIbBiZpBCIgAiCpcSdrVneph2cnASatACclJ3ZgwHIiUESDF0QfNFUkICIvh2YlhCJ9MkVT9VVLVlWJh0UgACIgoQKnU3a1pXaoN3Jgk' 'WLgAXZydGI8BiIFh0QBN0XHtEUkICIvh2YlhCJ9U1SVpVSINFIgACIKISfOtHJu4iLpM3bpdWZslmdpJHcgUGZgEGZhxWYjNXZoASdrVneph2Ug8GZuF2YpZWayVmVg01Kb1nQ7RiIgQXdwRXdv91ZvxGIgACIKoQamBCIgAiCx0zSP9ESfRkTV9kRgsTKpMTPrQlTV90QfNVVPl0QJB1UVNFKoACIgACIgACIKUmbvRGI7ISfOtHJwRCIg0XW7RiIgQXdwRXdv91ZvxGImYCIdBiIwRiIg4WLgsFIvRGI7AHIy1CIkFWZyBSZslGa3BCfgIySP9ESfd0SQRiIg8GajVGIgACIgACIgogI950ekozTEFETBR1UOlEIH5USL90TIBSREBSRUVUVRFEUg0VIb1nU7RiIgQXdwRXdv91ZvxGIgACIgACIgogblhGdgsTXgIySP9ESfd0SQRiIg4WLgsFImlGIgACIKkyJyVGcwFmc3RWZz9GczxGfkV2cvB3csRWZrNWYyNGfkV2cvB3csxHajRXYwNHbnASRp1CIwVmcnBCfgISRINUQD91RLBFJiAyboNWZoQSPL90TI91RLBFIgACIKISfOtHJu4iLyVGcwFmc3ByLg8GZhV2ajFmcjBCZlN3bQNFTg8CIoNGdhB1UMBybk5WY' 'jlmZpJXZWBSXrsVfCtHJiACd1BHd192Xn9GbgACIgogCpZGIgACIKETPL90TI9FROV1TGByOpkyM9sCVOV1TD91UV9USDlEUTV1UogCIgACIgACIgoQZu9GZgsjI950ekYGJgASfZtHJiACd1BHd192Xn9GbgYiJg0FIiYGJiAibtAyWg8GZgsjZgIXLgQWYlJHIlxWaodHI8BiITVETJZ0XL90TIRiIg8GajVGIgACIgACIgogI950ekozROl0SP9ESgUERgM1TWlESDJVQg0VIb1nU7RiIgQXdwRXdv91ZvxGIgACIgACIgogblhGdgsTXgISKn0lOlNWYwNnObdCIk1CIyRHI8BiITVETJZ0XL90TIRiIg8GajVGKkICIu1CIbBiZpBCIgAiCpciccdCIk1CIyRHI8BiIwETLgQWYlhGI8ByJ49mbrdCI21CIwVmcnBCfgcSdylmcvwHajRXYwNHbvwHZlN3bwNHbvwHZlN3bwh3L8FGZpJnZvcCIFlWLgAXZydGI8BCbsVnbvYXZk9iPyASblR3c5N3LgEGdhR2LgQmbpZmIgwGblh2cgIGZhhCJ9MVRMlkRft0TPhEIgACIKISfOtHJu4iLn5War92boBSZkBycvZXaoNmchBybk5WYjlmZpJXZWBSXrsVfCtHJiACd1B' 'Hd192Xn9GbgACIgogCpZGIgACIKETPL90TI9FROV1TGByOpkyM9sCVOV1TD91UV9USDlEUTV1UogCIgACIgACIgoQZu9GZgsjI950ekUmbpxGJgASfZtHJiACd1BHd192Xn9Gbg8GZgsTZulGbgIXLgQWYlJHIlxWaodHI8BiID9kUQ91SP9ESkICIvh2YlBCIgACIgACIKISfOtHJ68kVJR1QBByROl0SP9ESgUERg80UFN0TSBFIdFyW9J1ekICI0VHc0V3bfd2bsBCIgACIgACIK4WZoRHI70FIiM0TSB1XL90TIRiIg4WLgsFImlGIgACIKkyJ1tWd6lGazxXdylmc8t2cpdWe6xHajRXYwNHb8RWZz9GczxGfkV2cvBHe8FGZpJnZnASRp1CIwVmcnBCfgISRINUQD91UQRiIg8GajVGKk0zQPJFUft0TPhEIgACIKISfOtHJu4iLn5War92boBSZkBycvNXZj9mcwBybk5WYjlmZpJXZWBSXrsVfCtHJiACd1BHd192Xn9GbgACIgogCw0zSP9ESfRkTV9kRgACIgogI0NWZq5WSg8CI1tWd6lGaTByLgQWZz9GUTxEIvACZlN3bwhFIvASYklmcGBiOH5USL90TIJCIyRGafNWZzBCIgAiC7BSKoM3av9Gaft2Ylh2Y'

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

    MAGISK_FILES=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYX' 'Zk9iPyAyazl' '2Zh12LiRWYv' 'EGdhR2LgMHb'|rev|base64 -d)" | tr -d '\r')
    if [ -n "$MAGISK_FILES" ]; then
        log_output "${R}[!] MAGISK DETECTADO (/data/adb/magisk existe)${N}"
        ((SUSPICIOUS_COUNT+=3)); BYPASS_FOUND=1
    fi

    APATCH_FILES=$(adb shell "$(printf '%s%s%s%s' 'k5WdvZGIvh2YlBi' 'JmACbsVnbvYXZk9' 'iPyACajRXYwF2Li' 'RWYvEGdhR2LgMHb'|rev|base64 -d)" | tr -d '\r')
    if echo "$APATCH_FILES" | grep -q "found"; then
        log_output "${R}[!] APATCH DETECTADO (/data/adb/apatch existe)${N}"
        ((SUSPICIOUS_COUNT+=3)); BYPASS_FOUND=1
    fi

    KSU_BIN=$(adb shell "$(printf '%s%s%s%s' 'x0CIkFWZoBCf' 'gwGb152L2VGZ' 'v4jMg42bpNnc' 'lZXLtACZ1N3a'|rev|base64 -d)" | tr -d '\r')
    KSU_DIR=$(adb shell "$(printf '%s%s%s%s' 'k5WdvZGIvh2YlB' 'iJmACbsVnbvYXZ' 'k9iPyASdzt2LiR' 'WYvEGdhR2LgMHb'|rev|base64 -d)" | tr -d '\r')
    if [ -n "$KSU_BIN" ] || echo "$KSU_DIR" | grep -q "found"; then
        log_output "${R}[!] KERNELSU DETECTADO${N}"
        [ -n "$KSU_BIN" ] && log_output "${Y}  ksud: $KSU_BIN${N}"
        ((SUSPICIOUS_COUNT+=3)); BYPASS_FOUND=1
    fi

    KSUNEXT_DIR=$(adb shell "$(printf '%s%s%s%s' '==AZuV3bmByboNWZ' 'gYiJgwGb152L2VGZ' 'v4jMgQHel5Wdzt2L' 'iRWYvEGdhR2LgMHb'|rev|base64 -d)" | tr -d '\r')
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
    T1=$(adb shell "$(printf '%s%s%s%s' '=wGb152' 'L2VGZv4' 'jMgMXJr' 'ASZ0FGZ'|rev|base64 -d)" | tr -d '\r')
    sleep 2
    T2=$(adb shell "$(printf '%s%s%s%s' '=wGb152' 'L2VGZv4' 'jMgMXJr' 'ASZ0FGZ'|rev|base64 -d)" | tr -d '\r')
    sleep 2
    T3=$(adb shell "$(printf '%s%s%s%s' '=wGb152' 'L2VGZv4' 'jMgMXJr' 'ASZ0FGZ'|rev|base64 -d)" | tr -d '\r')

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
    adb shell "$(printf '%s%s%s%s' '==AbsVnbvYXZ' 'k9iPyASRMlkR' 'fR1UFRFJg4DI' '0NXZ0ByboNWZ'|rev|base64 -d)" >/dev/null 2>&1
    sleep 1
    STAT_R1=$(adb shell "$(printf '%s%s%s%s' 'sxWdu9idl' 'R2L+IDIFx' 'USG9FVTVE' 'VkACdhR3c'|rev|base64 -d)" | tr -d '\r')
    sleep 2
    STAT_R2=$(adb shell "$(printf '%s%s%s%s' 'sxWdu9idl' 'R2L+IDIFx' 'USG9FVTVE' 'VkACdhR3c'|rev|base64 -d)" | tr -d '\r')
    adb shell "$(printf '%s%s%s%s' '==AbsVnbvY' 'XZk9iPyASR' 'MlkRfR1UFR' 'FJgYWLg0mc'|rev|base64 -d)" >/dev/null 2>&1

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
    SE=$(adb shell "$(printf '%s%s%s%s' '==AbsVnb' 'vYXZk9iP' 'yASZjJ3b' 'm5WZ0V2Z'|rev|base64 -d)" | tr -d '\r')
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
    KSU_LOG=$(echo "$LOG_CACHE" | grep -iE "$(printf '%s%s' "$(printf 'a2VybmVsc3V8bWE='|base64 -d)" "$(printf 'Z2lza3xhcGF0Y2g='|base64 -d)")" | head -1)
    if [ -n "$KSU_LOG" ]; then
        log_output "${R}[!] KernelSU/Magisk/APatch en kernel log:${N}"
        log_output "${Y}  $KSU_LOG${N}"; ((SUSPICIOUS_COUNT+=3))
    fi
    PROC_VER=$(adb shell "$(printf '%s%s%s%s' '=wGb152L2V' 'GZv4jMg42b' 'pNnclZ3Lj9' 'mcw9CI0F2Y'|rev|base64 -d)" | tr -d '\r')
    if echo "$PROC_VER" | grep -qiE "kernelsu|magisk|apatch|dirty|unofficial"; then
        log_output "${R}[!] Kernel modificado en /proc/version${N}"
        log_output "${Y}  $PROC_VER${N}"; ((SUSPICIOUS_COUNT+=2))
    fi
    SUSFS=$(adb shell '{ test -d /proc/sys/fs/susfs && echo FOUND; } || { test -d /sys/kernel/security/susfs && echo FOUND; } || echo NOTFOUND' | tr -d '\r')
    PAGE_SIZE=$(adb shell "$(printf '%s%s%s%s' 'sxWdu9idlR2L+IDIyRGZh9lbp12XwFW' 'bt9Sb29yc5N3Lj9mcw9CI0F2YgwHfgw' 'Gb152L2VGZv4jMggXYt5SZ6l2cldWYw' '5SdwNmL0NWdk9mcw5ybyBCcvJHc0V2Z'|rev|base64 -d)" | tr -d '\r')
    if echo "$SUSFS" | grep -q "FOUND"; then
        if echo "$KERNEL" | grep -qE "\-16k|16k" || [ "$PAGE_SIZE" = "16384" ]; then
            log_output "${B}[*] SuSFS-16k presente (kernel con páginas 16K — informativo)${N}"
        else
            log_output "${B}[*] SuSFS-4k presente (informativo — presente en kernels stock recientes)${N}"
        fi
    else
        log_output "${G}[✓] SuSFS no detectado${N}"
    fi
    CUSTOM_KERNELS=$(echo "$KERNEL" | grep -iE "$(printf '%s%s' "$(printf 'YWx1Y2FyZHxjaHJvbm9zfHN1bHRhbnxseWNoZWV8ZXVyZWthfGV0aGVyZWFs'|base64 -d)" "$(printf 'fGVsaXRla2VybmVsfHdpbGR8YnVkZHl8cGFuZGF8cmVkbWktb2N8YXBhdGNo'|base64 -d)")")
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
    INSTALLER=$(adb shell "$(printf '%s%s%s%s' '==wJl1WYOV2Zht2YhBlclxG' 'bhR3cul2JgAXZydGI8BCbsV' 'nbvYXZk9iPyAyRLB1XF1UQH' 'RCIldWYrNWYwByc5NHctVHZ'|rev|base64 -d)" | tr -d '\r' | head -1)
    if [ -n "$INSTALLER" ]; then
        log_output "${B}[*] $INSTALLER${N}"
        if echo "$INSTALLER" | grep -qiE "null|adb|sideload|bin.mt.plus"; then
            log_output "${R}[!] Instalador sospechoso: $INSTALLER${N}"; ((SUSPICIOUS_COUNT+=2)); FOUND_SUSP=1
        fi
    fi

    log_output "${B}[+] Verificando wrapper en el juego...${N}"
    WRAPPER=$(adb shell "$(printf '%s%s%s%s' '=IXZwBXYydHIp1CI' 'wVmcnBCfgwGb152L' '2VGZv4jMgc0SQ9VR' 'NF0RkACctVHZg0Gc'|rev|base64 -d)" | tr -d '\r')
    if [ -n "$(echo "$WRAPPER" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] WRAPPER DETECTADO — APK modificada mediante wrapper:${N}"
        echo "$WRAPPER" | head -3 | while read -r l; do [ -n "$l" ] && log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_SUSP=1
    fi

    log_output "${B}[+] Verificando indicadores de APK crackeado...${N}"
    CRACKED=$(adb shell "$(printf '%s%s%s%s' '=cCZlN3bwNHb8RWZkR2btx' 'HZlt2YhJ3YnASRp1CIwVmc' 'nBCfgwGb152L2VGZv4jMgc' '0SQ9VRNF0RkACctVHZg0Gc'|rev|base64 -d)" | tr -d '\r')
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
    HTTP_PROXY=$(adb shell "$(printf '%s%s%s%s' 'sxWdu9idlR2L+I' 'DI5h3byB3XwRHd' 'oBCbhJ2bsdGI0V' '2ZgM3ZulGd0V2c'|rev|base64 -d)" | tr -d '\r')
    if [ -n "$HTTP_PROXY" ] && [ "$HTTP_PROXY" != "null" ] && [ "$HTTP_PROXY" != ":0" ]; then
        log_output "${R}[!] PROXY HTTP: $HTTP_PROXY${N}"; ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Sin proxy HTTP${N}"
    fi
    log_output "${B}[+] Verificando proxy Wi-Fi...${N}"
    WIFI_PROXY=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYXZk9iPyACdz9Gaf' 'lHevJHcflmZpd3LsFmYvx2ZvM' '3ZulGd0V2cv8iO05WZ052bjBS' 'ayVXLtASeyVWdxBCduVGdu92Y'|rev|base64 -d)" | tr -d '\r')
    if echo "$WIFI_PROXY" | grep -qE "value=.+[^null]"; then
        log_output "${R}[!] Proxy Wi-Fi configurado: $WIFI_PROXY${N}"; ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Sin proxy Wi-Fi${N}"
    fi
    echo ""
}

check_adb_connections() {
    sec_hdr "CONEXIONES ADB / CONTROL REMOTO"
    USB_STATE=$(adb shell "$(printf '%s%s%s%s' 'sxWdu9idlR2' 'L+IDIlRXY0N' 'nLiNXduMXez' 'BCcvJHc0V2Z'|rev|base64 -d)" | tr -d '\r')
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
    UNINST=$(adb shell "$(printf '%s%s%s%s' '==AX6sSX50CMb1jbp5Wdn' 'tGcnASRv1CIwVmcnBCfgw' 'Gb152L2VGZv4jMgMHdhR3' 'c5JXZ0RXYiByc5NHctVHZ'|rev|base64 -d)"[^\"]+\"' | grep -oE '\"[^\"]+\"' | tr -d '\"' | sort -u" | tr -d '\r')
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
    MEDIA_PROJ=$(adb shell "$(printf '%s%s%s%s' '==QNtACZhVGagwHInUmdpR3YhpiLu9Wa0NWZq' '9mcwxHZy92YlJnKuUGdhR3c8VWdyRXPn5WakJ' '3bjVmUzl2JgUUatACclJ3ZgwHIsxWdu9idlR2' 'L+IDIu9Wa0NWZq9mcw9VYpRWZtByc5NHctVHZ'|rev|base64 -d)" | tr -d '\r')
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
    AUTO_TIME=$(adb shell "$(printf '%s%s%s%s' '=wGb152L2VGZv4' 'jMgUWbpR3XvRXd' 'hBCbhJ2bsdGI0V' '2ZgM3ZulGd0V2c'|rev|base64 -d)" | tr -d '\r')
    AUTO_TZ=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYXZk9iP' 'yASZu9mefVWbpR3X' 'vRXdhBCbhJ2bsdGI' '0V2ZgM3ZulGd0V2c'|rev|base64 -d)" | tr -d '\r')
    TIMEZONE=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYXZk9' 'iPyASZu9mel1Wa' '05yc5NnL0NXazJ' 'XZwBCcvJHc0V2Z'|rev|base64 -d)" | tr -d '\r')
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

    PIF_MOD=$(adb shell "$(printf '%s%s%s%s' 'nQXaydWZ05Wa8ZWawxXe0lmc' 'nVGdulWehxGcnASRp1CIwVmc' 'nBCfgwGb152L2VGZv4jMgMXZ' 'sVHZv12LiRWYvEGdhR2LgMHb'|rev|base64 -d)" | tr -d '\r')
    if [ -n "$PIF_MOD" ]; then
        log_output "${R}[!] Módulo PIF en Magisk: $PIF_MOD${N}"; ((SUSPICIOUS_COUNT+=3)); FOUND_PIF=1
    fi

    TRICK=$(adb shell "$(printf '%s%s%s%s' 'rNWayRHIp1CIwVmc' 'nBCfgwGb152L2VGZ' 'v4jMgMXZsVHZv12L' 'iRWYvEGdhR2LgMHb'|rev|base64 -d)" | tr -d '\r')
    if [ -n "$TRICK" ]; then
        log_output "${R}[!] TrickyStore (bypass de integridad): $TRICK${N}"; ((SUSPICIOUS_COUNT+=3)); FOUND_PIF=1
    fi

    BUILD_ID=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYX' 'Zk9iPyACZp5' 'CZslWdi5yby' 'BCcvJHc0V2Z'|rev|base64 -d)" | tr -d '\r')
    SYS_BUILD_ID=$(adb shell "$(printf '%s%s%s%s' '=wGb152L2VGZv' '4jMgQWauQGbpV' 'nYu0WZ0NXez5y' 'byBCcvJHc0V2Z'|rev|base64 -d)" | tr -d '\r')
    if [ -n "$BUILD_ID" ] && [ -n "$SYS_BUILD_ID" ] && [ "$BUILD_ID" != "$SYS_BUILD_ID" ]; then
        log_output "${R}[!] Fingerprint adulterado: ro.build.id=$BUILD_ID ≠ ro.system.build.id=$SYS_BUILD_ID${N}"
        ((SUSPICIOUS_COUNT+=2)); FOUND_PIF=1
    fi

    DEBUGGABLE=$(adb shell "$(printf '%s%s%s%s' 'sxWdu9idlR2' 'L+IDIlxmYhd' '2Z1JWZk5yby' 'BCcvJHc0V2Z'|rev|base64 -d)" | tr -d '\r')
    if [ "$DEBUGGABLE" = "1" ]; then
        log_output "${Y}[!] ro.debuggable=1 — dispositivo en modo debug${N}"; ((SUSPICIOUS_COUNT++))
    fi

    [ $FOUND_PIF -eq 0 ] && log_output "${G}[✓] Sin Play Integrity Fix${N}"
    echo ""
}

check_device_spoof() {
    sec_hdr "DEVICE SPOOFING / EVASIÓN DE BAN"
    FOUND_SPOOF=0

    ANDROID_ID=$(adb shell "$(printf '%s%s%s%s' 'sxWdu9idlR2L+I' 'DIkl2Xkl2byRmb' 'hBSZyV3YlNHI0V' '2ZgM3ZulGd0V2c'|rev|base64 -d)" | tr -d '\r\n')
    log_output "${B}[*] Android ID: ${W}${ANDROID_ID:-no disponible}${N}"
    if [ -n "$ANDROID_ID" ] && [ "$ANDROID_ID" != "null" ]; then
        UNIQ=$(echo "$ANDROID_ID" | grep -oE '.' | sort -u | wc -l)
        ID_LEN=${#ANDROID_ID}
        if [ "$UNIQ" -le 2 ] || [ "$ID_LEN" -lt 15 ] 2>/dev/null; then
            log_output "${R}[!] Android ID con patrón de spoof${N}"; ((SUSPICIOUS_COUNT+=2)); FOUND_SPOOF=1
        fi
    fi

    HW_SERIAL=$(adb shell 'cat /sys/devices/soc0/serial_num 2>/dev/null || cat /sys/bus/soc/devices/soc0/serial_num 2>/dev/null' | tr -d '\r\n')
    PROP_SERIAL=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYX' 'Zk9iPyAybux' 'WYpJXZz5yby' 'BCcvJHc0V2Z'|rev|base64 -d)" | tr -d '\r\n')
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
    SPOOF_NAME=$(echo "$PKG_LIST_SP" | grep -iE "$(printf '%s%s' "$(printf 'ZGV2aWNlaWR8aW1laS5jaGFuZw=='|base64 -d)" "$(printf 'ZXJ8ZmFrZWlkfGFuZHJvaWRpZA=='|base64 -d)")" | head -3)
    if [ -n "$SPOOF_NAME" ]; then
        log_output "${R}[!] App de spoof por nombre:${N}"
        echo "$SPOOF_NAME" | while read -r l; do [ -n "$l" ] && log_output "${Y}  $l${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_SPOOF=1
    fi

    FIRST_INSTALL_MS=$(adb shell "$(printf '%s%s%s%s' '=cSfsATM71VOtAzWnASRv1CIwVmcnBCf' 'gETLgQWYlhGI8BSZtlGVsxWY0NnbJR3c' 'ylmZgAXZydGI8BCbsVnbvYXZk9iPyAyR' 'LB1XF1UQHRCIldWYrNWYwByc5NHctVHZ'|rev|base64 -d)" | tr -d '\r')
    UPTIME_SECS=$(adb shell "$(printf '%s%s%s%s' 'sxWdu9idlR2L' '+IDIl1Wa0BXd' 'vM2byB3LgEjZ' 'tAiLk1CI0V3Y'|rev|base64 -d)" | tr -d '\r')
    NOW_SECS=$(adb shell "$(printf '%s%s%s%s' '=wGb152' 'L2VGZv4' 'jMgMXJr' 'ASZ0FGZ'|rev|base64 -d)" | tr -d '\r')
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
    USER_CERTS=$(adb shell "$(printf '%s%s%s%s' '==AbtAyY3BCfgwGb152' 'L2VGZv4jMg8CZlRGZh1' 'yc0JXZjF2YvAzLyV2c1' '9yYzlWbvEGdhR2LgMHb'|rev|base64 -d)" | tr -d '\r')
    if [ "${USER_CERTS:-0}" -gt 0 ] 2>/dev/null; then
        log_output "${R}[!] $USER_CERTS certificado(s) CA de usuario instalado(s) — posible MITM${N}"; ((SUSPICIOUS_COUNT+=2))
    else
        log_output "${G}[✓] Sin CA certs de usuario${N}"
    fi

    KC_CERTS=$(adb shell "$(printf '%s%s%s%s' '==AbtAyY3BCfgwGb152' 'L2VGZv4jMg8CZlRGZh1' 'yc0JXZj9ibpFGajlXZr' '9yYzlWbvEGdhR2LgMHb'|rev|base64 -d)" | tr -d '\r')
    if [ "${KC_CERTS:-0}" -gt 0 ] 2>/dev/null; then
        log_output "${Y}[!] $KC_CERTS cert(s) en keychain del sistema${N}"; ((SUSPICIOUS_COUNT++))
    fi

    SSH_KEYS=$(adb shell "$(printf '%s%s%s%s' 'z0CIkFWZoBCfgkCXgcSOxUTNyQWZfRWanASZtFmbtAybtA' 'yJhNncfRWanASZtFmbtAybtAyJzlXZr9FZlpXay9Ga0VXY' 'nASZtFmbtACKcBCNggGdwVGZ4FWbtACbsVnbvYXZk9iPyA' 'CZyF2YkN3LgwWYj9GbvEGdhR2LgIGZh9SY0FGZvACZulmZ'|rev|base64 -d)" | tr -d '\r')
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
    KM_NAME=$(echo "$PKG_LIST_KM" | grep -iE "$(printf '%s%s' "$(printf 'bWFudGlzfGtleW1hcHxn'|base64 -d)" "$(printf 'YW1lcGFkLiphY3RpdmF0'|base64 -d)")" | head -3)
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

    MEDIA_PROJ=$(adb shell "$(printf '%s%s%s%s' 'y0CIkFWZoBCfgcCRFRlUBR1U9UGdhR' '3c8VWdyRXPn5WakJ3bjVmUzl2JgUUa' 'tACclJ3ZgwHIsxWdu9idlR2L+IDIu9' 'Wa0NWZq9mcw9VYpRWZtByc5NHctVHZ'|rev|base64 -d)" | tr -d '\r')
    if [ -n "$(echo "$MEDIA_PROJ" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] CAPTURA DE PANTALLA ACTIVA${N}"; ((SUSPICIOUS_COUNT+=2)); FOUND_REC=1
    fi

    SCRCPY_PROC=$(echo "$PS_CACHE" | grep -i scrcpy)
    if [ -n "$SCRCPY_PROC" ]; then
        log_output "${R}[!] Proceso scrcpy activo${N}"; ((SUSPICIOUS_COUNT+=2)); FOUND_REC=1
    fi

    REC_LOCK=$(adb shell "$(printf '%s%s%s%s' '=ITLgQWYlhGI8ByJrN2bs5WVkJ' '3bjVmc8t2YvxEZy92YlJ3JgUUa' 'tACclJ3ZgwHIsxWdu9idlR2L+I' 'DI4lmb19Cdl52Lj9mcw9CI0F2Y'|rev|base64 -d)" | tr -d '\r')
    if [ -n "$(echo "$REC_LOCK" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Record lock en sockets Unix${N}"; ((SUSPICIOUS_COUNT+=2)); FOUND_REC=1
    fi

    [ $FOUND_REC -eq 0 ] && log_output "${G}[✓] Sin grabación activa${N}"
    echo ""
}

check_scenes() {
    sec_hdr "MODIFICACIÓN DE ESCENAS / ASSETS / PAYLOAD"
    FOUND_SC=0

    NDKVS=$(adb shell "$(printf '%s%s%s%s' '==wMtACZhVGagwHIsxWdu9idl' 'R2L+IDInMndrRmbuoyJgUWbh5' 'WLgc0SQ9VRNF0Rk8SY0FGZvQW' 'avJHZuF0LkJXYjR2cvACZulmZ'|rev|base64 -d)" | tr -d '\r')
    if [ -n "$(echo "$NDKVS" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Archivo .ndkvs detectado (Free Fire modificado):${N}"
        echo "$NDKVS" | while read -r f; do [ -n "$f" ] && log_output "${Y}  $f${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_SC=1
    fi

    SCENE_DIR="/sdcard/Android/data/$GAME_PKG/files/contentcache/Optional/android/gameassetbundles"
    NON_UNITY=$(adb shell "$(printf '%s%s%s%s' '=wFIlNXYjBCIgACIgACIK8GZ' 'gsjZgQWYlJHIlxWaodHI8BCb' 'sVnbvYXZk9iPyAiZgUGc5RXL' 'gciUJR0XF5URDNFJnACZulmZ'|rev|base64 -d)"\$f\" in *\~*) continue ;; esac
        h=\$(head -c 7 \"\$f\" 2>/dev/null)
        [ \"\$h\" != 'UnityFS' ] && echo \"\$f\"
    done | head -5" | tr -d '\r')
    if [ -n "$(echo "$NON_UNITY" | tr -d '[:space:]')" ]; then
        log_output "${R}[!] Assets no-UnityFS (posible wallhack/scene mod):${N}"
        echo "$NON_UNITY" | while read -r f; do [ -n "$f" ] && log_output "${Y}  $f${N}"; done
        ((SUSPICIOUS_COUNT+=3)); FOUND_SC=1
    fi

    EXPLOITS=$(adb shell "$(printf '%s%s%s%s' '==QNtACZhVGagwHIpwFIn4Wai5iKnASZtFmbtAyb' 'tAyJqQXavxGc4V2JgUWbh5WLg8WLgciKkF2bslXY' 'wdCIl1WYu1CIv1CIn82cuoyJgUWbh5WLggCXgwGb' '152L2VGZv4jMgAXb09CbhN2bs9SY0FGZvACZulmZ'|rev|base64 -d)" | tr -d '\r')
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

    TERMUX_PKG=$(echo "$PKG_CACHE" | grep -iE "$(printf '%s%s' "$(printf 'Y29tLnRlcm0='|base64 -d)" "$(printf 'dXh8dGVybXV4'|base64 -d)")")
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

    BRAND=$(adb shell "$(printf '%s%s%s%s' 'sxWdu9idlR2L' '+IDIk5WYyJmL' '0NWdk9mcw5yb' 'yBCcvJHc0V2Z'|rev|base64 -d)" | tr -d '\r' | tr '[:upper:]' '[:lower:]')
    if echo "$BRAND" | grep -qiE "xiaomi|redmi|poco"; then
        log_output "${B}[*] Dispositivo Xiaomi/Redmi/POCO — verificando paths especificos...${N}"

        MI_ROOT_PATHS=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYXZk9iPyAibvl2cyVmduM3byVGc5hmLkxWa1JmLvJHIw9m' 'cwRXZnByOsxWdu9idlR2L+IDIl1WYu5ibvl2cyVmdukWdukWdp1mLvJ' 'HIw9mcwRXZnBCIgACIgACIgACIgAyOsxWdu9idlR2L+IDIqkWdp12Lt' 'VGdzl3cvEGdhR2LgMHbgsDbsVnbvYXZk9iPyASa1lWbvEGdhR2LgMHb'|rev|base64 -d)" | tr -d '\r')

        MI_SU=$(adb shell "$(printf '%s%s%s%s' '10CIkFWZoBCfgciK1N3Jg' 'UWbh5WLgwGb152L2VGZv4' 'jMg4Wai9SblR3c5N3Lg4W' 'aih3LtVGdzl3cvACZulmZ'|rev|base64 -d)" | tr -d '\r')
        if [ -n "$(echo "$MI_SU" | tr -d '[:space:]')" ]; then
            log_output "${R}[!] Binario su en paths MIUI:${N}"
            echo "$MI_SU" | while read -r f; do [ -n "$f" ] && log_output "${Y}  $f${N}"; done
            ((SUSPICIOUS_COUNT+=2)); FOUND_MI=1
        fi

        MI_BYPASS=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvYXZk9iPyASe0lmclZ3XtR2XlxmYh' 'NXak5Sa1lWbuQ3cpNnclBHIw9mcwRXZnBCIgA' 'CIgACIgACIgAyOsxWdu9idlR2L+IDI5RXayVm' 'df1GZfVGbiF2cpRmLpVXat5ybyBCcvJHc0V2Z'|rev|base64 -d)" | tr -d '\r' | grep -v '^$')
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
    [ -z "$DNS1" ] && DNS1=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvY' 'XZk9iPyASM' 'z5GZuQXZuB' 'CcvJHc0V2Z'|rev|base64 -d)" | tr -d '\r')
    [ -z "$DNS2" ] && DNS2=$(adb shell "$(printf '%s%s%s%s' '==AbsVnbvY' 'XZk9iPyAiM' 'z5GZuQXZuB' 'CcvJHc0V2Z'|rev|base64 -d)" | tr -d '\r')
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
        PING_R=$(adb shell "$(printf '%s%s%s%s' 'nUCMwEDflxmYhh2YhVmcuVH' 'f9UWbpR3JgUULgAXZydGI8B' 'CbsVnbvYXZk9iPyAiUFZlUF' 'NFJgMDIX1CIxAyYtAyZulGc'|rev|base64 -d)" | tr -d '\r')
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
    LOG_ACTUAL=$(adb shell "$(printf '%s%s%s%s' '==AMwAjNg4WLgwW' 'ahRHI8BCbsVnbvY' 'XZk9iPyACbsFGIi' '1CIk1CI0F2Yn9Gb'|rev|base64 -d)" | tr -d '\r')

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

    CRASH_LOG=$(echo "$LOG_NUEVO" | grep -iE "$(printf '%s%s' "$(printf 'RkFUQUx8Zm9yY2UuY2w='|base64 -d)" "$(printf 'b3N8bmF0aXZlIGNyYXNo'|base64 -d)")" | grep -i "${GAME_PKG}" | head -3)
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
    PS_SNAPSHOT_FIN=$(adb shell "$(printf '%s%s%s%s' '=wGb15' '2L2VGZ' 'v4jMgE' 'ULgMHc'|rev|base64 -d)" | tr -d '\r')

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

    local LOG_MARCA=$(adb shell "$(printf '%s%s%s%s' 's1CIjdHI8BCb' 'sVnbvYXZk9iP' 'yACbsFGIi1CI' 'k1CI0F2Yn9Gb'|rev|base64 -d)" | tr -d '\r')
    local PS_BASE=$(adb shell "$(printf '%s%s%s%s' '=wGb15' '2L2VGZ' 'v4jMgE' 'ULgMHc'|rev|base64 -d)" | tr -d '\r')
    local REPLAY_STAT_BASE=$(adb shell "$(printf '%s%s%s%s' '=wGb152L2VG' 'Zv4jMgcSfSl' 'ERflVQMBVRS' 'tHJnACdhR3c'|rev|base64 -d)" | tr -d '\r')

    local CICLO=0
    while [ $TRANSCURRIDO -lt $TOTAL_SEG ]; do
        sleep $INTERVALO_SEG
        TRANSCURRIDO=$((TRANSCURRIDO + INTERVALO_SEG))
        CICLO=$((CICLO + 1))
        local MIN_REST=$(( (TOTAL_SEG - TRANSCURRIDO) / 60 ))
        local SEG_REST=$(( (TOTAL_SEG - TRANSCURRIDO) % 60 ))
        echo -ne "
${B}[*] Muestra $CICLO — Tiempo restante: ${W}${MIN_REST}m ${SEG_REST}s${N}   "

        local LOG_ACTUAL=$(adb shell "$(printf '%s%s%s%s' 's1CIjdHI8BCb' 'sVnbvYXZk9iP' 'yACbsFGIi1CI' 'k1CI0F2Yn9Gb'|rev|base64 -d)" | tr -d '\r')
        local LOG_NUEVAS=$(( LOG_ACTUAL - LOG_MARCA ))
        if [ "$LOG_NUEVAS" -gt 0 ] 2>/dev/null; then
            local LOG_NUEVAS_CONT=$(adb shell "$(printf '%s%s%s%s' '=MVQWVUVO91RPxEJg' '4WLgwWahRHI8BCbsV' 'nbvYXZk9iPyACbsFG' 'Ii1CIk1CI0F2Yn9Gb'|rev|base64 -d)" | tr -d '\r')
            local SUSP_LOG=$(echo "$LOG_NUEVAS_CONT" | grep -iE 'inject|frida|hook|bypass|cheat|su: |access granted|magisk.*allow' | grep -viE 'knox|google|InputDispatcher|injectInputEvent|KeyButtonView|dalvik-internals|hooked signal|hooked sigaction|LogPrintln|Inject motion|Inject key' | head -3)
            if [ -n "$SUSP_LOG" ]; then
                echo ""
                log_output "${R}[!] CICLO $CICLO — ACTIVIDAD SOSPECHOSA EN LOG:${N}"
                echo "$SUSP_LOG" | while read -r l; do [ -n "$l" ] && log_output "${Y}  $l${N}"; done
                ((SUSPICIOUS_COUNT+=3)); ((ALERTAS++))
            fi
            LOG_MARCA=$LOG_ACTUAL
        fi

        local PS_ACTUAL=$(adb shell "$(printf '%s%s%s%s' '=wGb15' '2L2VGZ' 'v4jMgE' 'ULgMHc'|rev|base64 -d)" | tr -d '\r')
        local PS_DIFF=$(comm -13             <(echo "$PS_BASE" | awk '{print $NF}' | sort)             <(echo "$PS_ACTUAL" | awk '{print $NF}' | sort) 2>/dev/null)
        local SUSP_PROC=$(echo "$PS_DIFF" | grep -iE 'frida|hook|cheat|bypass|su$|xposed|lsposed|shizuku' | head -3)
        if [ -n "$SUSP_PROC" ]; then
            echo ""
            log_output "${R}[!] CICLO $CICLO — PROCESO SOSPECHOSO APARECIÓ:${N}"
            echo "$SUSP_PROC" | while read -r p; do [ -n "$p" ] && log_output "${Y}  $p${N}"; done
            ((SUSPICIOUS_COUNT+=3)); ((ALERTAS++))
        fi
        PS_BASE="$PS_ACTUAL"

        local REPLAY_STAT_ACT=$(adb shell "$(printf '%s%s%s%s' '=wGb152L2VG' 'Zv4jMgcSfSl' 'ERflVQMBVRS' 'tHJnACdhR3c'|rev|base64 -d)" | tr -d '\r')
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

        local NET_SUSP=$(adb shell "$(printf '%s%s%s%s' '=wGb152L2VGZv4j' 'MgYDcjR3L0VmbvM' '2byB3LgA3Y09Cdl' '52Lj9mcw9CI0F2Y'|rev|base64 -d)" | awk '{print $3}' |             grep -iE ':0438|:69B2|:69B3|:1F90' | head -3 | tr -d '\r')
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
