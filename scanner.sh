#!/data/data/com.termux/files/usr/bin/bash

clear

R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'
C='\033[1;36m'; M='\033[1;35m'; W='\033[1;37m'; N='\033[0m'

L=$(printf '═%.0s' {1..64})
D=$(printf '─%.0s' {1..64})

echo ""
echo -e "${M}╔${L}╗${N}"
printf "${M}║${N}%-64s${M}║${N}\n" "$(printf '%*s' $(( (64 + ${#"  UNKNOWN SECURITY TEAM  ·  AVISO IMPORTANTE  "}) / 2 )) "  UNKNOWN SECURITY TEAM  ·  AVISO IMPORTANTE  ")"
echo -e "${M}╚${L}╝${N}"
echo ""
echo -e "${Y}  [!]${W} El scanner fue migrado a codigo cerrado por razones de proteccion.${N}"
echo ""
echo -e "${M}${D}${N}"
echo -e "${C}  Nuevo comando de ejecucion:${N}"
echo -e "${M}${D}${N}"
echo ""
echo -e "${G}  pkg install git android-tools -y && rm -rf TiziXit-AntiCheat &&${N}"
echo -e "${G}  git clone https://github.com/Streakxit/TiziXit-AntiCheat &&${N}"
echo -e "${G}  cd TiziXit-AntiCheat && chmod +x scanner && ./scanner${N}"
echo ""
echo -e "${M}${D}${N}"
echo ""
