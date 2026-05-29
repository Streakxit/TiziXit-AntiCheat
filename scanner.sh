#!/data/data/com.termux/files/usr/bin/bash
clear
M='\033[1;35m'; Y='\033[1;33m'; G='\033[1;32m'; W='\033[1;37m'; C='\033[1;36m'; N='\033[0m'
echo ""
printf "${M}╔%s╗${N}\n" "$(printf '═%.0s' {1..64})"
printf "${M}║${N}  %-60s  ${M}║${N}\n" "UNKNOWN SECURITY TEAM  —  AVISO IMPORTANTE"
printf "${M}╚%s╝${N}\n" "$(printf '═%.0s' {1..64})"
echo ""
echo -e "${Y}  [!]${W} El scanner fue migrado a codigo cerrado por razones de proteccion.${N}"
echo ""
printf "${M}%s${N}\n" "$(printf '─%.0s' {1..66})"
echo -e "${C}  Nuevo comando de ejecucion:${N}"
printf "${M}%s${N}\n" "$(printf '─%.0s' {1..66})"
echo ""
echo -e "${G}  pkg install git android-tools -y && rm -rf TiziXit-AntiCheat &&${N}"
echo -e "${G}  git clone https://github.com/Streakxit/TiziXit-AntiCheat &&${N}"
echo -e "${G}  cd TiziXit-AntiCheat && chmod +x scanner && ./scanner${N}"
echo ""

