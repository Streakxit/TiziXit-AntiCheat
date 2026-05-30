#!/data/data/com.termux/files/usr/bin/bash
# ─────────────────────────────────────────────────────────────
# UNKNOWN Security Team — scanner_report_snippet.sh
# Agregar al scanner.sh para reportar scans al panel admin.
#
# INSTRUCCIONES:
#   1. Definir las variables globales del scanner antes de llamar
#      a _send_scan_report (la mayoría ya existen en scanner.sh).
#   2. Llamar a _send_scan_report al final del scan, luego de
#      calcular $VERDICT y $SIGNALS.
# ─────────────────────────────────────────────────────────────

# ── Variables que deben existir en el scanner ────────────────
# BACKEND_URL   → URL base del backend (ya usada en premium_validate)
# PREMIUM_KEY   → key validada al inicio (UNKN-XXXX-XXXX-XXXX)
# SCANNER_VERSION → ej: "1.4.0"
# HWID          → hardware ID del dispositivo escaneado
# PLAYER_NAME   → nombre ingresado por el operador
# VERDICT       → "clean" | "suspicious" | "cheat"
# SIGNALS       → entero (contador de señales)
#
# Variables de detecciones (las que ya genera el scanner):
# DETECT_ROOT, DETECT_SU_PATHS, DETECT_MAGISK,
# DETECT_KSU, DETECT_SUSFS, DETECT_LSPATCH,
# DETECT_LSPACED_CRACKED, DETECT_SHIZUKU,
# DETECT_TERMUX, DETECT_REPLAY, DETECT_FAKE_TIME,
# DETECT_FAKE_TIME_DIFF, DETECT_VPN, DETECT_DNS_SUS,
# DETECT_SUS_PORTS (space-separated), DETECT_LOGCAT_INJECT,
# DETECT_SHADERS, DETECT_PROCESS_SUS,
# DEVICE_BRAND, DEVICE_MODEL, DEVICE_ANDROID, DEVICE_SDK

# ── Función principal ────────────────────────────────────────
_send_scan_report() {
  # Construir el JSON de detecciones
  # Arrays: su_paths y sus_ports → convertir a JSON array
  local _su_json="[]"
  if [ -n "$DETECT_SU_PATHS" ]; then
    _su_json="["
    local _first=1
    for _p in $DETECT_SU_PATHS; do
      [ $_first -eq 0 ] && _su_json+=","
      _su_json+="\"$(printf '%s' "$_p" | sed 's/"/\\"/g')\""
      _first=0
    done
    _su_json+="]"
  fi

  local _ports_json="[]"
  if [ -n "$DETECT_SUS_PORTS" ]; then
    _ports_json="["
    local _first=1
    for _port in $DETECT_SUS_PORTS; do
      [ $_first -eq 0 ] && _ports_json+=","
      _ports_json+="\"$_port\""
      _first=0
    done
    _ports_json+="]"
  fi

  # Booleanos
  local _bool() { [ "$1" = "1" ] || [ "$1" = "true" ] && echo "true" || echo "false"; }

  local _detections
  _detections=$(printf '{
    "root":%s,
    "magisk":%s,
    "ksu":%s,
    "susfs":%s,
    "su_paths":%s,
    "lspatch":%s,
    "lspaced_cracked":%s,
    "shizuku":%s,
    "termux":%s,
    "replay":%s,
    "fake_time":%s,
    "fake_time_diff":"%s",
    "vpn":%s,
    "dns_sus":%s,
    "sus_ports":%s,
    "logcat_inject":%s,
    "shader_modified":%s
  }' \
    "$(_bool "$DETECT_ROOT")" \
    "$(_bool "$DETECT_MAGISK")" \
    "$(_bool "$DETECT_KSU")" \
    "$(_bool "$DETECT_SUSFS")" \
    "$_su_json" \
    "$(_bool "$DETECT_LSPATCH")" \
    "$(_bool "$DETECT_LSPACED_CRACKED")" \
    "$(_bool "$DETECT_SHIZUKU")" \
    "$(_bool "$DETECT_TERMUX")" \
    "$(_bool "$DETECT_REPLAY")" \
    "$(_bool "$DETECT_FAKE_TIME")" \
    "${DETECT_FAKE_TIME_DIFF:-}" \
    "$(_bool "$DETECT_VPN")" \
    "$(_bool "$DETECT_DNS_SUS")" \
    "$_ports_json" \
    "$(_bool "$DETECT_LOGCAT_INJECT")" \
    "$(_bool "$DETECT_SHADERS")")

  local _device_info
  _device_info=$(printf '{"brand":"%s","model":"%s","android":"%s","sdk":"%s"}' \
    "${DEVICE_BRAND:-}" "${DEVICE_MODEL:-}" "${DEVICE_ANDROID:-}" "${DEVICE_SDK:-}")

  # Escapar player name por si tiene comillas
  local _player_escaped
  _player_escaped=$(printf '%s' "${PLAYER_NAME:-}" | sed 's/"/\\"/g')
  local _hwid_escaped
  _hwid_escaped=$(printf '%s' "${HWID:-}" | sed 's/"/\\"/g')

  local _payload
  _payload=$(printf '{"hwid":"%s","player_name":"%s","version":"%s","premium_key":"%s","verdict":"%s","signals":%d,"detections":%s,"device_info":%s}' \
    "$_hwid_escaped" \
    "$_player_escaped" \
    "${SCANNER_VERSION:-unknown}" \
    "${PREMIUM_KEY:-}" \
    "${VERDICT:-unknown}" \
    "${SIGNALS:-0}" \
    "$_detections" \
    "$_device_info")

  # Enviar al backend — silencioso, no bloquea si falla
  curl -s -X POST "${BACKEND_URL}/api/android/scan/report" \
    -H "Content-Type: application/json" \
    -d "$_payload" \
    --max-time 12 \
    --connect-timeout 6 \
    >/dev/null 2>&1 || true
}


# ─────────────────────────────────────────────────────────────
# INTEGRACIÓN EN scanner.sh
# ─────────────────────────────────────────────────────────────
# Agregar al final del scan, justo DESPUÉS de calcular
# $VERDICT y $SIGNALS, por ejemplo:
#
#   # ... lógica del scan ...
#   _calcular_veredicto   # función interna que fija $VERDICT / $SIGNALS
#   _mostrar_resumen      # función interna que imprime el resultado
#
#   # Reportar al panel admin (no bloquea el flujo)
#   _send_scan_report &
#
# Usar & para que el reporte sea en background y no demore
# la salida del scanner al operador.
# ─────────────────────────────────────────────────────────────
