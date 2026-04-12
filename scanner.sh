// ╔══════════════════════════════════════════════════════════════╗
// ║     UNKNOWN ANTI-CHEAT SCANNER — Free Fire Android                      ║
// ║     by TIZI.XIT · UNKNOWN Security Team                                 ║
// ║     Versión 2.0.0 ·                                                     ║ 
// ╚══════════════════════════════════════════════════════════════╝

package main

import (
	"bufio"
	"crypto/md5"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// ──────────────────────────────────────────────
//  PALETA DE COLOR
// ──────────────────────────────────────────────

const (
	cReset  = "\033[0m"
	cRed    = "\033[38;5;196m"
	cOrange = "\033[38;5;208m"
	cYellow = "\033[38;5;226m"
	cGreen  = "\033[38;5;46m"
	cCyan   = "\033[38;5;51m"
	cBlue   = "\033[38;5;39m"
	cPurple = "\033[38;5;135m"
	cWhite  = "\033[38;5;255m"
	cGray   = "\033[38;5;242m"
	cDim    = "\033[2m"
	cBold   = "\033[1m"

	// iconos de estado
	iOK   = cGreen + "  ✔" + cReset
	iWarn = cYellow + "  ⚑" + cReset
	iBad  = cRed + "  ✘" + cReset
	iInfo = cBlue + "  ◈" + cReset
	iScan = cCyan + "  ⟳" + cReset
)

// ──────────────────────────────────────────────
//  CONFIG
// ──────────────────────────────────────────────

const (
	VERSION     = "2.0.0"
	BACKEND_URL = "https://unknown-scanner-backend-v1-0.onrender.com"
)

// ──────────────────────────────────────────────
//  ESTADO GLOBAL
// ──────────────────────────────────────────────

var (
	gamePkg      string
	gameSelected string
	deviceHWID   string
	suspCount    int
	findings     []Finding
	logFile      *os.File
	logPath      string
)

type Finding struct {
	Tag      string // ROOT / HOOK / WALL / REPLAY / PIF / KSU / SPOOF / APP / PROXY / CERT / KEYMAP / RECORD / OTHER
	Severity int    // 1=info 2=warn 3=crit
	Msg      string
}

func addFinding(tag string, sev int, msg string) {
	suspCount += sev
	findings = append(findings, Finding{tag, sev, msg})
}

// ──────────────────────────────────────────────
//  ADB
// ──────────────────────────────────────────────

func adb(cmd string) string {
	out, err := exec.Command("adb", "shell", cmd).Output()
	if err != nil {
		return ""
	}
	return strings.TrimRight(strings.ReplaceAll(string(out), "\r", ""), "\n")
}

func adbRaw(args ...string) string {
	out, err := exec.Command("adb", args...).Output()
	if err != nil {
		return ""
	}
	return strings.TrimRight(strings.ReplaceAll(string(out), "\r", ""), "\n")
}

func deviceConnected() bool {
	out := adbRaw("devices")
	for _, l := range strings.Split(out, "\n") {
		if strings.HasSuffix(strings.TrimSpace(l), "device") {
			return true
		}
	}
	return false
}

func pkgInstalled(pkg string) bool {
	return strings.Contains(adb("pm list packages 2>/dev/null"), pkg)
}

// ──────────────────────────────────────────────
//  LOG
// ──────────────────────────────────────────────

func logout(msg string) {
	fmt.Println(msg)
	if logFile != nil {
		clean := regexp.MustCompile(`\033\[[0-9;]*m`).ReplaceAllString(msg, "")
		fmt.Fprintln(logFile, clean)
	}
}

func initLog() {
	logPath = fmt.Sprintf("%s/unk_scan_%s.txt",
		os.Getenv("HOME"), time.Now().Format("20060102_150405"))
	f, err := os.Create(logPath)
	if err == nil {
		logFile = f
	}
}

// ──────────────────────────────────────────────
//  UTILIDADES
// ──────────────────────────────────────────────

func cls() { fmt.Print("\033[2J\033[H") }

func read() string {
	r := bufio.NewReader(os.Stdin)
	t, _ := r.ReadString('\n')
	return strings.TrimSpace(t)
}

func parseInt(s string) (int64, error) {
	return strconv.ParseInt(strings.TrimSpace(s), 10, 64)
}

func sectionHeader(tag, title string) {
	tagColor := map[string]string{
		"ROOT": cRed, "HOOK": cPurple, "WALL": cOrange,
		"REPLAY": cYellow, "PIF": cCyan, "KSU": cRed,
		"SPOOF": cOrange, "APP": cBlue, "PROXY": cYellow,
		"CERT": cPurple, "KEYMAP": cBlue, "RECORD": cCyan,
		"SYSTEM": cGray, "OTHER": cGray,
	}
	col := tagColor[tag]
	if col == "" {
		col = cGray
	}
	fmt.Println()
	logout(fmt.Sprintf("%s%s┌─[ %s%-8s%s%s ]%s%s──────────────────────────────────────────────%s",
		cDim, cGray, cBold, tag, cReset, cGray+cDim, cReset, cDim+cGray, cReset))
	logout(fmt.Sprintf("%s%s│%s  %s%s%s%s",
		cDim, cGray, cReset, col+cBold, title, cReset, ""))
	logout(fmt.Sprintf("%s%s└%s%s",
		cDim, cGray, strings.Repeat("─", 55), cReset))
}

func line(icon, msg string) {
	logout(fmt.Sprintf("%s %s%s%s", icon, cWhite, msg, cReset))
}

func detail(msg string) {
	logout(fmt.Sprintf("       %s%s%s", cGray, msg, cReset))
}

// ──────────────────────────────────────────────
//  HWID
// ──────────────────────────────────────────────

func calcHWID() string {
	id := adb("settings get secure android_id 2>/dev/null")
	sr := adb("getprop ro.serialno 2>/dev/null")
	bs := adb("getprop ro.boot.serialno 2>/dev/null")
	h := md5.Sum([]byte(id + ":" + sr + ":" + bs))
	return fmt.Sprintf("%x", h)
}

// ──────────────────────────────────────────────
//  BAN CHECK
// ──────────────────────────────────────────────

type BanResp struct {
	Ok     bool   `json:"ok"`
	Banned bool   `json:"banned"`
	Motivo string `json:"motivo"`
	Fecha  string `json:"fecha"`
}

func verificarBan() bool {
	fmt.Printf("\n%s%s  Verificando acceso...%s", cDim, cCyan, cReset)
	hwid := calcHWID()
	if len(hwid) < 8 {
		fmt.Println()
		return true
	}
	deviceHWID = hwid

	cli := &http.Client{Timeout: 6 * time.Second}
	resp, err := cli.Get(fmt.Sprintf("%s/api/ban/check?hwid=%s", BACKEND_URL, hwid))
	if err != nil {
		fmt.Printf(" %s[offline]%s\n", cGray, cReset)
		return true
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	var br BanResp
	if json.Unmarshal(body, &br) != nil {
		return true
	}

	if br.Banned {
		cls()
		fmt.Println()
		fmt.Printf("%s%s", cRed+cBold, `
  ██████╗  █████╗ ███╗   ██╗
  ██╔══██╗██╔══██╗████╗  ██║
  ██████╔╝███████║██╔██╗ ██║
  ██╔══██╗██╔══██║██║╚██╗██║
  ██████╔╝██║  ██║██║ ╚████║
  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝`+cReset)
		fmt.Println()
		fmt.Println()
		fmt.Printf("%s%s  ╔══════════════════════════════════════════════════════╗%s\n", cBold, cRed, cReset)
		fmt.Printf("%s%s  ║       DISPOSITIVO BLOQUEADO DEL SCANNER              ║%s\n", cBold, cRed, cReset)
		fmt.Printf("%s%s  ╚══════════════════════════════════════════════════════╝%s\n", cBold, cRed, cReset)
		fmt.Println()
		fmt.Printf("  %sMOTIVO%s  %s%s%s\n", cGray, cReset, cRed+cBold, br.Motivo, cReset)
		fmt.Printf("  %sFECHA %s  %s%s%s\n", cGray, cReset, cYellow, br.Fecha, cReset)
		fmt.Printf("  %sHWID  %s  %s%s%s\n", cGray, cReset, cDim+cWhite, hwid, cReset)
		fmt.Println()
		fmt.Printf("  %sEste dispositivo no puede usar el scanner.%s\n\n", cOrange, cReset)
		fmt.Printf("  %sEnter para salir...%s ", cGray, cReset)
		read()
		return false
	}
	fmt.Printf(" %s[OK]%s\n", cGreen, cReset)
	return true
}

// ──────────────────────────────────────────────
//  BANNER
// ──────────────────────────────────────────────

func banner() {
	cls()
	fmt.Printf(`%s%s
  ██╗   ██╗███╗   ██╗██╗  ██╗███╗   ██╗ ██████╗ ██╗    ██╗███╗   ██╗
  ██║   ██║████╗  ██║██║ ██╔╝████╗  ██║██╔═══██╗██║    ██║████╗  ██║
  ██║   ██║██╔██╗ ██║█████╔╝ ██╔██╗ ██║██║   ██║██║ █╗ ██║██╔██╗ ██║
  ██║   ██║██║╚██╗██║██╔═██╗ ██║╚██╗██║██║   ██║██║███╗██║██║╚██╗██║
  ╚██████╔╝██║ ╚████║██║  ██╗██║ ╚████║╚██████╔╝╚███╔███╔╝██║ ╚████║
   ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═══╝%s`,
		cCyan+cBold, cReset)
	fmt.Println()
	fmt.Printf("  %s%sANTI-CHEAT SCANNER%s  %sv%s%s  %sFree Fire Android%s\n",
		cBold, cWhite, cReset,
		cDim+cGray, VERSION, cReset,
		cDim+cGray, cReset)
	fmt.Printf("  %sby TIZI.XIT · UNKNOWN Security Team%s\n", cDim+cGray, cReset)
	fmt.Println()
	fmt.Printf("  %s%s⚠  Scanner en desarrollo — siempre hacer revisión manual adicional%s\n",
		cBold, cOrange, cReset)
	fmt.Println()
}

// ──────────────────────────────────────────────
//  MENÚ
// ──────────────────────────────────────────────

func menu() {
	for {
		banner()
		suspCount = 0
		findings = nil

		fmt.Printf("  %s%s[ MENÚ PRINCIPAL ]%s\n\n", cBold, cCyan, cReset)
		fmt.Printf("  %s[0]%s  Conectar ADB\n", cYellow+cBold, cReset)
		fmt.Printf("  %s[1]%s  Escanear Free Fire\n", cGreen+cBold, cReset)
		fmt.Printf("  %s[2]%s  Escanear Free Fire MAX\n", cGreen+cBold, cReset)
		fmt.Printf("  %s[3]%s  Ver último log\n", cCyan+cBold, cReset)
		fmt.Printf("  %s[4]%s  Guardar diagnóstico\n", cBlue+cBold, cReset)
		fmt.Printf("  %s[5]%s  Actualizar scanner\n", cPurple+cBold, cReset)
		fmt.Printf("  %s[S]%s  Salir\n\n", cRed+cBold, cReset)
		fmt.Printf("  %s▸ %s", cCyan, cReset)

		switch strings.ToLower(read()) {
		case "0":
			conectarADB()
		case "1":
			gamePkg = "com.dts.freefireth"
			gameSelected = "Free Fire"
			if verificarBan() {
				ejecutarScan()
			}
		case "2":
			gamePkg = "com.dts.freefiremax"
			gameSelected = "Free Fire MAX"
			if verificarBan() {
				ejecutarScan()
			}
		case "3":
			verUltimoLog()
		case "4":
			guardarDiagnostico()
		case "5":
			actualizarScanner()
		case "s":
			fmt.Printf("\n  %sSaliendo...%s\n\n", cGray, cReset)
			os.Exit(0)
		}
	}
}

// ──────────────────────────────────────────────
//  CONECTAR ADB
// ──────────────────────────────────────────────

func conectarADB() {
	cls()
	banner()
	fmt.Printf("  %s%s[ CONEXIÓN ADB INALÁMBRICA ]%s\n\n", cBold, cCyan, cReset)
	fmt.Printf("  %s1. Ajustes → Opciones de Desarrollador%s\n", cGray, cReset)
	fmt.Printf("  %s2. Activar Depuración inalámbrica%s\n", cGray, cReset)
	fmt.Printf("  %s3. Tocar Vincular mediante código%s\n", cGray, cReset)
	fmt.Println()

	fmt.Printf("  %sCódigo 6 dígitos:%s ", cYellow, cReset)
	code := read()
	if len(code) != 6 {
		fmt.Printf("  %sCódigo inválido%s\n", cRed, cReset)
		time.Sleep(2 * time.Second)
		return
	}

	fmt.Printf("  %sPuerto de pareamiento:%s ", cYellow, cReset)
	pairPort := read()
	fmt.Printf("\n  %sPareando...%s\n", cBlue, cReset)
	out := adbRaw("pair", "localhost:"+pairPort, code)
	if !strings.Contains(strings.ToLower(out), "success") {
		fmt.Printf("  %sError en pareamiento%s\n", cRed, cReset)
		fmt.Printf("  %sEnter...%s ", cGray, cReset)
		read()
		return
	}
	fmt.Printf("  %s✔ Pareamiento exitoso%s\n", cGreen, cReset)
	fmt.Println()
	fmt.Printf("  %sPuerto de conexión:%s ", cYellow, cReset)
	connPort := read()
	fmt.Printf("\n  %sConectando...%s\n", cBlue, cReset)
	out2 := adbRaw("connect", "localhost:"+connPort)
	if strings.Contains(strings.ToLower(out2), "connected") {
		fmt.Printf("  %s✔ Conectado%s\n", cGreen, cReset)
	} else {
		fmt.Printf("  %sError de conexión: %s%s\n", cRed, out2, cReset)
	}
	fmt.Printf("\n  %sEnter...%s ", cGray, cReset)
	read()
}

// ──────────────────────────────────────────────
//  EJECUTAR SCAN
// ──────────────────────────────────────────────

func ejecutarScan() {
	cls()
	banner()
	suspCount = 0
	findings = nil
	initLog()

	logout(fmt.Sprintf("  %s%s◈  ESCANEANDO: %s%s%s\n",
		cBold, cCyan, cWhite, gameSelected, cReset))

	if !deviceConnected() {
		line(iBad, "No hay dispositivo conectado — usá la opción [0]")
		fmt.Printf("\n  %sEnter...%s ", cGray, cReset)
		read()
		return
	}
	if !pkgInstalled(gamePkg) {
		line(iBad, gameSelected+" no está instalado")
		time.Sleep(3 * time.Second)
		return
	}

	checkDeviceInfo()
	checkRoot()
	checkUptime()
	checkShellBypass()
	checkSystemLogs()
	checkTimeChanges()
	checkClipboard()
	checkDownloads()
	checkVPNDNS()
	checkDeletedFiles()
	checkReplays()
	checkWallhack()
	checkOBB()
	checkHooks()
	checkRootBypass()
	checkFakeTime()
	checkTooling()
	checkSELinux()
	checkBootState()
	checkKernel()
	checkPIF()
	checkDeviceSpoof()
	checkCACerts()
	checkMantisKeymap()
	checkRecording()
	checkSuspiciousPackages()
	checkNetworkPorts()
	checkADBConnections()
	checkUninstalledApps()
	checkDataLocalTmp()
	checkDropboxCrashes()
	checkAutoTime()
	checkScenes()

	showSummary()

	if logFile != nil {
		logFile.Close()
		logFile = nil
	}
	fmt.Printf("\n  %sEnter para volver al menú...%s ", cGray, cReset)
	read()
}

// ──────────────────────────────────────────────
//  MÓDULOS
// ──────────────────────────────────────────────

func checkDeviceInfo() {
	sectionHeader("SYSTEM", "INFORMACIÓN DEL DISPOSITIVO")
	logout(fmt.Sprintf("%s  %-16s%s%s%s", iInfo+" "+cGray, "Android", cReset+cWhite,
		adb("getprop ro.build.version.release"), cReset))
	logout(fmt.Sprintf("%s  %-16s%s%s%s", iInfo+" "+cGray, "Modelo", cReset+cWhite,
		adb("getprop ro.product.model"), cReset))
	logout(fmt.Sprintf("%s  %-16s%s%s%s", iInfo+" "+cGray, "Marca", cReset+cWhite,
		adb("getprop ro.product.brand"), cReset))
	logout(fmt.Sprintf("%s  %-16s%s%s%s", iInfo+" "+cGray, "CPU ABI", cReset+cWhite,
		adb("getprop ro.product.cpu.abi"), cReset))
	logout(fmt.Sprintf("%s  %-16s%s%s%s", iInfo+" "+cGray, "Serial", cReset+cWhite,
		adb("getprop ro.serialno 2>/dev/null"), cReset))
}

func checkRoot() {
	sectionHeader("ROOT", "DETECCIÓN DE ROOT")
	suPaths := []string{
		"/system/bin/su", "/system/xbin/su", "/sbin/su",
		"/vendor/bin/su", "/data/local/bin/su", "/data/local/su",
		"/data/local/xbin/su", "/data/adb/ksu", "/data/adb/ksud",
		"/system/sbin/su", "/system/bin/.ext/.su",
	}
	found := false
	for _, p := range suPaths {
		if adb(fmt.Sprintf("test -f '%s' && echo Y", p)) == "Y" {
			line(iBad, "Binario SU: "+p)
			addFinding("ROOT", 2, "SU binary: "+p)
			found = true
		}
	}
	// proc cmdline root
	cmdRoot := adb(`ps -A -Z 2>/dev/null | grep -E "^u:r:su:s0" | grep -vE "(surfaceflinger|webview_zygote|com\.android\.)" | awk '{print $NF}' | sort -u | head -5`)
	if strings.TrimSpace(cmdRoot) != "" {
		for _, proc := range strings.Split(cmdRoot, "\n") {
			if proc != "" {
				line(iBad, "Proceso con contexto root SELinux: "+proc)
				addFinding("ROOT", 3, "SELinux root ctx: "+proc)
				found = true
			}
		}
	}
	// uid=0
	suCmd := adb(`su -c id 2>&1 | head -1`)
	if strings.Contains(suCmd, "uid=0") {
		line(iBad, "Acceso root confirmado (uid=0)")
		addFinding("ROOT", 3, "uid=0 confirmed")
		found = true
	}
	if !found {
		line(iOK, "Sin ROOT detectado")
	}
}

func checkUptime() {
	sectionHeader("SYSTEM", "UPTIME")
	up := adb("uptime 2>/dev/null")
	line(iInfo, up)
	if ok, _ := regexp.MatchString(`up [0-9] min`, up); ok {
		line(iWarn, "Reinicio muy reciente (<10 min)")
		addFinding("OTHER", 1, "Reinicio reciente")
	}
}

func checkShellBypass() {
	sectionHeader("OTHER", "BYPASS DE FUNCIONES SHELL")
	found := false
	for _, fn := range []string{"pkg", "git", "stat", "adb"} {
		r := adb(fmt.Sprintf(`type %s 2>/dev/null | grep -q function && echo DETECTED`, fn))
		if r == "DETECTED" {
			line(iBad, fmt.Sprintf("Función '%s' sobrescrita (bypass)", fn))
			addFinding("OTHER", 2, "shell bypass func: "+fn)
			found = true
		}
	}
	for _, cfg := range []string{"~/.bashrc", "~/.zshrc", "/data/data/com.termux/files/usr/etc/bash.bashrc"} {
		r := adb(fmt.Sprintf(`[ -f %s ] && grep -E "(function pkg|function adb|wendell77x)" %s 2>/dev/null | head -1`, cfg, cfg))
		if strings.TrimSpace(r) != "" {
			line(iBad, "Bypass en config shell: "+cfg)
			addFinding("OTHER", 2, "shell bypass cfg: "+cfg)
			found = true
		}
	}
	// Binarios de bypass en /data/local/tmp
	bpFiles := adb(`find /sdcard /data/local/tmp -name "*.sh" 2>/dev/null | xargs grep -l "function pkg\|wendell77x" 2>/dev/null | head -3`)
	if strings.TrimSpace(bpFiles) != "" {
		line(iBad, "Scripts de bypass encontrados")
		for _, f := range strings.Split(bpFiles, "\n") {
			if f != "" {
				detail(f)
			}
		}
		addFinding("OTHER", 2, "bypass scripts found")
		found = true
	}
	if !found {
		line(iOK, "Sin bypass de shell")
	}
}

func checkSystemLogs() {
	sectionHeader("SYSTEM", "INTEGRIDAD DE LOGS")
	firstLog := adb(`logcat -d -v time 2>/dev/null | grep -oE "[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" | head -1`)
	line(iInfo, "Primer registro de log: "+firstLog)

	// Buffer de logs limpiado (pgrep logd)
	logd := adb(`pgrep -x logd 2>/dev/null | head -1`)
	if strings.TrimSpace(logd) == "" {
		line(iWarn, "logd no está corriendo — logs pueden estar manipulados")
		addFinding("OTHER", 2, "logd not running")
	}
}

func checkTimeChanges() {
	sectionHeader("SYSTEM", "CAMBIOS DE HORA")
	tc := adb(`logcat -d 2>/dev/null | grep "Time changed" | grep -v "HCALL" | tail -3`)
	if strings.TrimSpace(tc) != "" {
		line(iWarn, "Cambios de hora detectados en logcat:")
		for _, l := range strings.Split(tc, "\n") {
			if l != "" {
				detail(l)
			}
		}
		addFinding("OTHER", 1, "time changes in logcat")
	} else {
		line(iOK, "Sin cambios de hora")
	}
}

func checkClipboard() {
	sectionHeader("SYSTEM", "CLIPBOARD")
	clip := adb(`logcat -d 2>/dev/null | grep "hcallSetClipboardTextRpc" | tail -5`)
	if strings.TrimSpace(clip) != "" {
		line(iWarn, "Free Fire copió datos al portapapeles")
		for _, l := range strings.Split(clip, "\n") {
			if l != "" {
				detail(l)
			}
		}
		addFinding("OTHER", 1, "clipboard usage by FF")
	} else {
		line(iOK, "Sin clipboard sospechoso")
	}
}

func checkDownloads() {
	sectionHeader("APP", "APKs SOSPECHOSOS EN DESCARGAS")
	apks := adb(`find /sdcard/Download /sdcard/Downloads -name "*.apk" 2>/dev/null`)
	found := false
	for _, apk := range strings.Split(apks, "\n") {
		if apk == "" {
			continue
		}
		low := strings.ToLower(apk)
		for _, kw := range []string{"hack", "cheat", "mod", "panel", "lucky", "magisk", "inject"} {
			if strings.Contains(low, kw) {
				name := apk[strings.LastIndex(apk, "/")+1:]
				line(iBad, "APK sospechoso: "+name)
				addFinding("APP", 2, "suspicious APK: "+name)
				found = true
				break
			}
		}
	}
	if !found {
		line(iOK, "Sin APKs sospechosos")
	}
}

func checkVPNDNS() {
	sectionHeader("PROXY", "VPN / DNS / PROXY")

	vpnPkgs := map[string]string{
		"com.nordvpn.android": "NordVPN", "net.openvpn.openvpn": "OpenVPN",
		"com.expressvpn.vpn": "ExpressVPN", "com.cloudflare.onedotonedotonedotone": "Cloudflare WARP",
		"com.protonvpn.android": "ProtonVPN", "com.v2ray.ang": "V2Ray",
		"com.github.shadowsocks": "Shadowsocks", "com.hiddify.app": "Hiddify",
	}
	pkgList := adb(`pm list packages 2>/dev/null`)
	vpnFound := false
	for pkg, name := range vpnPkgs {
		if strings.Contains(pkgList, pkg) {
			line(iWarn, "VPN instalada: "+name)
			addFinding("PROXY", 1, "VPN: "+name)
			vpnFound = true
		}
	}
	vpnIf := adb(`ip link show 2>/dev/null | grep -iE "tun[0-9]|tap[0-9]|ppp[0-9]|wg[0-9]"`)
	if strings.TrimSpace(vpnIf) != "" {
		line(iBad, "Interfaz VPN/tunel activa")
		addFinding("PROXY", 2, "VPN interface active")
		vpnFound = true
	}
	if !vpnFound {
		line(iOK, "Sin VPN activa")
	}

	// DNS privado
	dnsMode := adb(`settings get global private_dns_mode 2>/dev/null`)
	dnsHost := adb(`settings get global private_dns_specifier 2>/dev/null`)
	if dnsMode == "hostname" && dnsHost != "" && dnsHost != "null" {
		if ok, _ := regexp.MatchString(`(?i)proxy|cheat|hack|vpn\.`, dnsHost); ok {
			line(iBad, "DNS privado sospechoso: "+dnsHost)
			addFinding("PROXY", 1, "suspicious DNS: "+dnsHost)
		} else {
			line(iWarn, "DNS privado configurado: "+dnsHost)
		}
	} else {
		line(iOK, "DNS normal")
	}

	// Proxy HTTP
	proxy := adb(`settings get global http_proxy 2>/dev/null`)
	if proxy != "" && proxy != "null" && proxy != ":0" {
		line(iBad, "Proxy HTTP activo: "+proxy)
		addFinding("PROXY", 2, "HTTP proxy: "+proxy)
	} else {
		line(iOK, "Sin proxy HTTP")
	}

	// Proxy Wi-Fi
	wProxy := adb(`content query --uri content://settings/global/wifi_proxy_host 2>/dev/null`)
	if ok, _ := regexp.MatchString(`value=.+[^null]`, wProxy); ok {
		line(iBad, "Proxy Wi-Fi configurado")
		addFinding("PROXY", 2, "WiFi proxy active")
	}
}

func checkDeletedFiles() {
	sectionHeader("OTHER", "CARPETAS VACÍAS / GAME DATA")
	gameDataDir := "/sdcard/Android/data/" + gamePkg
	gameObbDir := "/sdcard/Android/obb/" + gamePkg
	folders := []string{
		gameDataDir + "/files/contentcache",
		gameDataDir + "/files/MReplays",
		gameDataDir + "/cache",
		gameObbDir,
	}
	empty := false
	for _, folder := range folders {
		if adb(fmt.Sprintf(`[ -d '%s' ] && echo Y`, folder)) == "Y" {
			count := adb(fmt.Sprintf(`find '%s' -type f 2>/dev/null | wc -l`, folder))
			if strings.TrimSpace(count) == "0" {
				name := folder[strings.LastIndex(folder, "/")+1:]
				line(iBad, "Carpeta vacía: "+name)
				addFinding("OTHER", 2, "empty folder: "+name)
				empty = true
			}
		}
	}
	if !empty {
		line(iOK, "Todas las carpetas tienen archivos")
	}
}

func checkReplays() {
	sectionHeader("REPLAY", "ANÁLISIS DE REPLAYS")
	replayDir := "/sdcard/Android/data/" + gamePkg + "/files/MReplays"
	var replayMotivos []string

	binsRaw := adb(fmt.Sprintf(`ls -t '%s'/*.bin 2>/dev/null`, replayDir))
	if strings.TrimSpace(binsRaw) == "" || strings.Contains(binsRaw, "No such") {
		line(iBad, "Sin replays en MReplays")
		addFinding("REPLAY", 2, "no .bin files")
		binsRaw = ""
	}

	// Versión del juego
	gameVersion := ""
	re := regexp.MustCompile(`versionName=(\S+)`)
	if m := re.FindStringSubmatch(adb(fmt.Sprintf(`dumpsys package %s 2>/dev/null`, gamePkg))); len(m) > 1 {
		gameVersion = m[1]
	}

	parseTS := func(stat, prefix string) (int64, string) {
		r := regexp.MustCompile(prefix + `:\s+(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\.(\d+)`)
		m := r.FindStringSubmatch(stat)
		if len(m) < 3 {
			return 0, ""
		}
		t, err := time.ParseInLocation("2006-01-02 15:04:05", m[1], time.Local)
		if err != nil {
			return 0, ""
		}
		return t.Unix(), m[2]
	}

	latestModify := int64(0)
	latestChange := int64(0)
	first := true

	for _, bin := range strings.Split(binsRaw, "\n") {
		bin = strings.TrimSpace(bin)
		if bin == "" || strings.Contains(bin, "No such") {
			continue
		}
		fname := bin[strings.LastIndex(bin, "/")+1:]
		line(iInfo, "Replay: "+fname)

		stat := adb(fmt.Sprintf(`stat '%s' 2>/dev/null`, bin))
		if stat == "" {
			continue
		}

		tsA, nsA := parseTS(stat, "Access")
		tsM, nsM := parseTS(stat, "Modify")
		tsC, nsC := parseTS(stat, "Change")

		if first {
			latestModify = tsM
			latestChange = tsC
			first = false
		}

		// Motivo 1 — access > modify
		if tsA > tsM && tsA > 0 && tsM > 0 {
			replayMotivos = append(replayMotivos, "Motivo 1 — Access posterior a Modify: "+fname)
		}
		// Motivo 2 — nanosegundos .000
		if nsA == "000000000" && nsM == "000000000" && nsC == "000000000" {
			replayMotivos = append(replayMotivos, "Motivo 2 — Timestamps .000: "+fname)
		}
		// Motivo 3 — Modify ≠ Change
		if tsM != tsC && tsM > 0 {
			replayMotivos = append(replayMotivos, "Motivo 3 — Modify ≠ Change: "+fname)
		}
		// Motivo 4 — nombre vs modify
		reName := regexp.MustCompile(`(\d{4})-(\d{2})-(\d{2})-(\d{2})-(\d{2})-(\d{2})`)
		if nm := reName.FindStringSubmatch(fname); len(nm) > 0 {
			tName, _ := time.ParseInLocation("2006-01-02 15:04:05",
				fmt.Sprintf("%s-%s-%s %s:%s:%s", nm[1], nm[2], nm[3], nm[4], nm[5], nm[6]), time.Local)
			diff := tName.Unix() - tsM
			if diff < 0 {
				diff = -diff
			}
			if diff > 1 {
				replayMotivos = append(replayMotivos, "Motivo 4 — Nombre no coincide con Modify: "+fname)
			}
		}
		// Motivo 8 — JSON ausente o access diferente
		jsonPath := strings.TrimSuffix(bin, ".bin") + ".json"
		jsonStat := adb(fmt.Sprintf(`stat '%s' 2>/dev/null`, jsonPath))
		if strings.TrimSpace(jsonStat) == "" {
			replayMotivos = append(replayMotivos, "Motivo 8 — JSON ausente: "+fname)
		} else {
			tsJA, _ := parseTS(jsonStat, "Access")
			if tsJA != tsA && tsJA != tsM {
				replayMotivos = append(replayMotivos, "Motivo 8 — Access JSON diferente: "+fname)
			}
		}
		// Motivo 14 — versión diferente
		if gameVersion != "" {
			jsonContent := adb(fmt.Sprintf(`cat '%s' 2>/dev/null`, jsonPath))
			if m := regexp.MustCompile(`"Version":"([^"]*)"`).FindStringSubmatch(jsonContent); len(m) > 1 {
				if m[1] != gameVersion {
					replayMotivos = append(replayMotivos,
						fmt.Sprintf("Motivo 14 — Replay v%s vs juego v%s: %s", m[1], gameVersion, fname))
				}
			}
		}
		_ = nsA
		_ = nsM
		_ = nsC
	}

	// Análisis de la carpeta MReplays
	pastaStat := adb(fmt.Sprintf(`stat '%s' 2>/dev/null`, replayDir))
	if pastaStat != "" {
		tsPA, nsPA := parseTS(pastaStat, "Access")
		tsPM, nsPM := parseTS(pastaStat, "Modify")
		tsPC, nsPC := parseTS(pastaStat, "Change")
		if tsPA == tsPM && tsPM == tsPC && tsPA > 0 {
			replayMotivos = append(replayMotivos, "Motivo 5 — A/M/C idénticos en carpeta MReplays")
		}
		if (nsPM == "000000000" || nsPC == "000000000") && nsPM != "" {
			replayMotivos = append(replayMotivos, "Motivo 6 — Milisegundos .000 en carpeta")
		}
		if tsPM > latestModify && latestModify > 0 {
			replayMotivos = append(replayMotivos, "Motivo 7 — Carpeta modificada después del último replay (Modify)")
		}
		if tsPC > latestChange && latestChange > 0 {
			replayMotivos = append(replayMotivos, "Motivo 7 — Carpeta modificada después del último replay (Change)")
		}
		if tsPM != tsPC && tsPM > 0 {
			replayMotivos = append(replayMotivos, "Motivo 11 — Modify ≠ Change en carpeta MReplays")
		}
		_ = nsPA
	}

	// Replays externos en Downloads (Motivo 14)
	extReplays := adb(`ls /sdcard/Download/ 2>/dev/null | grep -E "^[0-9]{4}(-[0-9]{2}){5}_rep\.(bin|json)$" | head -5`)
	if strings.TrimSpace(extReplays) != "" {
		replayMotivos = append(replayMotivos, "Motivo 14 — Replay externo en Downloads")
	}

	fmt.Println()
	if len(replayMotivos) > 0 {
		line(iBad, fmt.Sprintf("%sREPLAY PASADO DETECTADO — ¡APLICAR W.O!%s", cBold, cReset))
		for _, m := range replayMotivos {
			detail(m)
		}
		addFinding("REPLAY", 3, fmt.Sprintf("%d motivos de replay", len(replayMotivos)))
	} else {
		line(iOK, "Replays normales")
	}
}

func checkWallhack() {
	sectionHeader("WALL", "SHADERS / WALLHACK BYPASS")
	shaderDir := fmt.Sprintf("/sdcard/Android/data/%s/files/contentcache/Optional/android/gameassetbundles", gamePkg)
	shaders := adb(fmt.Sprintf(`find '%s' -name 'shader*' 2>/dev/null | head -5`, shaderDir))
	if strings.TrimSpace(shaders) == "" {
		line(iOK, "Sin shaders modificados")
		return
	}
	allOK := true
	for _, s := range strings.Split(shaders, "\n") {
		if s == "" {
			continue
		}
		magic := adb(fmt.Sprintf(`head -c 7 '%s' 2>/dev/null`, s))
		if magic != "UnityFS" {
			name := s[strings.LastIndex(s, "/")+1:]
			line(iBad, "Shader inválido: "+name)
			addFinding("WALL", 3, "invalid shader: "+name)
			allOK = false
		}
	}
	if allOK {
		line(iOK, "Shaders OK")
	}

	// Overlay activo
	overlayDump := adb(`dumpsys overlay 2>/dev/null | grep -iE "enabled.*true" | grep -iv "android\." | head -5`)
	if strings.TrimSpace(overlayDump) != "" {
		line(iWarn, "Overlay activo:")
		for _, l := range strings.Split(overlayDump, "\n") {
			if l != "" {
				detail(l)
			}
		}
		addFinding("WALL", 2, "overlay active")
	}
}

func checkOBB() {
	sectionHeader("OTHER", "OBB")
	obb := adb(fmt.Sprintf(`ls '/sdcard/Android/obb/%s' 2>/dev/null`, gamePkg))
	if strings.TrimSpace(obb) == "" {
		line(iBad, "OBB no encontrado")
		addFinding("OTHER", 1, "OBB missing")
	} else {
		line(iOK, "OBB presente")
	}
}

func checkHooks() {
	sectionHeader("HOOK", "DETECCIÓN DE HOOKING")

	// Procesos activos
	hookProcs := adb(`ps -A 2>/dev/null | grep -iE "frida|xposed|lsposed|zygisk|riru"`)
	if strings.TrimSpace(hookProcs) != "" {
		line(iBad, "Framework de hooking en proceso:")
		for _, l := range strings.Split(hookProcs, "\n") {
			if l != "" {
				detail(l)
			}
		}
		addFinding("HOOK", 3, "hooking process active")
	} else {
		line(iOK, "Sin procesos de hooking")
	}

	// Archivos
	hookFiles := adb(`find /data /system 2>/dev/null | grep -iE "/frida|/xposed|/lsposed" | grep -v knox | head -10`)
	if strings.TrimSpace(hookFiles) != "" {
		line(iBad, "Archivos de hooking:")
		for _, f := range strings.Split(hookFiles, "\n") {
			if f != "" {
				detail(f)
			}
		}
		addFinding("HOOK", 3, "hooking files found")
	} else {
		line(iOK, "Sin archivos de hooking")
	}

	// XposedBridge
	if adb(`test -f /system/framework/XposedBridge.jar && echo Y`) == "Y" {
		line(iBad, "XposedBridge.jar detectado")
		addFinding("HOOK", 3, "XposedBridge.jar")
	}

	// LSPosed via pm
	for _, p := range []string{"io.github.lsposed.manager", "org.lsposed.manager"} {
		if pkgInstalled(p) {
			line(iBad, "LSPosed instalado: "+p)
			addFinding("HOOK", 3, "LSPosed: "+p)
		}
	}
}

func checkRootBypass() {
	sectionHeader("ROOT", "MAGISK / ZYGISK / BYPASS")
	found := false

	// Procesos Magisk/Zygisk
	bypPS := adb(`ps -A 2>/dev/null | grep -iE "magisk|shamiko|zygisk|busybox"`)
	for _, l := range strings.Split(bypPS, "\n") {
		if l == "" || strings.Contains(strings.ToLower(l), "knox") {
			continue
		}
		line(iBad, "Proceso de bypass: "+strings.TrimSpace(l))
		addFinding("ROOT", 3, "bypass proc")
		found = true
	}

	// /data/adb/magisk
	if strings.TrimSpace(adb(`ls /data/adb/magisk 2>/dev/null`)) != "" {
		line(iBad, "Magisk detectado en /data/adb/magisk")
		addFinding("ROOT", 3, "Magisk dir found")
		found = true
	}

	// Módulos activos
	modules := adb(`ls /data/adb/modules 2>/dev/null | head -10`)
	if strings.TrimSpace(modules) != "" {
		line(iWarn, "Módulos en /data/adb/modules:")
		for _, m := range strings.Split(modules, "\n") {
			if m != "" {
				detail(m)
			}
		}
		addFinding("ROOT", 2, "Magisk modules active")
		found = true
	}

	// Shamiko
	if adb(`test -d /data/adb/modules/shamiko && echo Y`) == "Y" {
		line(iBad, "Shamiko (hide root) detectado")
		addFinding("ROOT", 3, "Shamiko")
		found = true
	}

	if !found {
		line(iOK, "Sin bypass avanzado")
	}
}

func checkFakeTime() {
	sectionHeader("OTHER", "TIEMPO FALSO / CONGELADO")

	t1, _ := parseInt(adb(`date +%s 2>/dev/null`))
	time.Sleep(time.Second)
	t2, _ := parseInt(adb(`date +%s 2>/dev/null`))

	if t2-t1 < 1 && t1 > 0 {
		line(iBad, "Tiempo congelado o falso")
		addFinding("OTHER", 3, "frozen time")
	} else {
		line(iOK, "Tiempo avanza normalmente")
	}

	// Stat 1970
	tf := fmt.Sprintf("/data/local/tmp/.unk_%d", time.Now().UnixNano())
	adb(fmt.Sprintf(`echo x > %s 2>/dev/null`, tf))
	time.Sleep(time.Second)
	statR := adb(fmt.Sprintf(`stat %s 2>/dev/null`, tf))
	adb(fmt.Sprintf(`rm -f %s`, tf))
	if strings.Contains(statR, "1970") {
		line(iBad, "stat muestra año 1970 — inconsistencia de timestamps")
		addFinding("OTHER", 2, "stat 1970")
	} else {
		line(iOK, "Timestamps consistentes")
	}
}

func checkTooling() {
	sectionHeader("OTHER", "EMULADORES")
	found := false
	props := adb(`getprop 2>/dev/null`)
	for _, l := range strings.Split(props, "\n") {
		low := strings.ToLower(l)
		for _, kw := range []string{"qemu", "goldfish", "vbox", "genymotion", "bluestacks", "nox", "memu"} {
			if strings.Contains(low, kw) &&
				!strings.Contains(low, "]: [0]") &&
				!strings.Contains(low, "]: []") &&
				!strings.Contains(low, "knox") {
				line(iBad, "Prop de emulador: "+strings.TrimSpace(l))
				addFinding("OTHER", 2, "emulator prop: "+kw)
				found = true
				break
			}
		}
	}
	if adb(`getprop ro.kernel.qemu 2>/dev/null`) == "1" {
		line(iBad, "Emulador confirmado (ro.kernel.qemu=1)")
		addFinding("OTHER", 3, "ro.kernel.qemu=1")
		found = true
	}
	if !found {
		line(iOK, "Dispositivo físico")
	}
}

func checkSELinux() {
	sectionHeader("SYSTEM", "SELINUX")
	se := adb(`getenforce 2>/dev/null`)
	switch se {
	case "Enforcing":
		line(iOK, "SELinux: Enforcing")
	case "Permissive":
		line(iBad, "SELinux PERMISSIVO — común en rooteados")
		addFinding("ROOT", 2, "SELinux permissive")
	case "Disabled":
		line(iBad, "SELinux DESACTIVADO")
		addFinding("ROOT", 3, "SELinux disabled")
	default:
		line(iWarn, "SELinux: "+se)
	}
}

func checkBootState() {
	sectionHeader("SYSTEM", "ESTADO DE BOOT")
	bootState := adb(`getprop ro.boot.verifiedbootstate 2>/dev/null`)
	flashLocked := adb(`getprop ro.boot.flash.locked 2>/dev/null`)
	vbmeta := adb(`getprop ro.boot.vbmeta.device_state 2>/dev/null`)
	warranty := adb(`getprop ro.boot.warranty_bit 2>/dev/null`)
	buildTags := adb(`getprop ro.build.tags 2>/dev/null`)

	logout(fmt.Sprintf("%s  verifiedbootstate:  %s%s%s", iInfo+" "+cGray, cWhite, bootState, cReset))
	logout(fmt.Sprintf("%s  flash.locked:       %s%s%s", iInfo+" "+cGray, cWhite, flashLocked, cReset))
	logout(fmt.Sprintf("%s  vbmeta.device_state:%s%s%s", iInfo+" "+cGray, cWhite, vbmeta, cReset))
	logout(fmt.Sprintf("%s  warranty_bit:       %s%s%s", iInfo+" "+cGray, cWhite, warranty, cReset))

	if bootState == "orange" || bootState == "red" {
		line(iBad, "Bootloader desbloqueado: "+bootState)
		addFinding("SYSTEM", 3, "bootloader unlocked: "+bootState)
	}
	if flashLocked == "0" {
		line(iWarn, "flash.locked=0")
		addFinding("SYSTEM", 2, "flash.locked=0")
	}
	if vbmeta == "unlocked" {
		line(iWarn, "vbmeta.device_state=unlocked")
		addFinding("SYSTEM", 2, "vbmeta unlocked")
	}
	if warranty == "1" {
		line(iWarn, "warranty_bit=1 — bootloader fue desbloqueado anteriormente")
		addFinding("SYSTEM", 1, "warranty_bit=1")
	}
	tagLow := strings.ToLower(buildTags)
	if strings.Contains(tagLow, "test-keys") || strings.Contains(tagLow, "dev-keys") {
		line(iBad, "Build tags sospechosas: "+buildTags)
		addFinding("SYSTEM", 2, "build tags: "+buildTags)
	} else {
		line(iOK, "Build tags: "+buildTags)
	}
}

func checkKernel() {
	sectionHeader("KSU", "ANÁLISIS DE KERNEL")
	kernel := adb(`uname -r 2>/dev/null`)
	line(iInfo, "Kernel: "+kernel)

	procVer := adb(`cat /proc/version 2>/dev/null`)
	// Módulos root en kernel log
	ksuLog := adb(`logcat -b kernel -d 2>/dev/null | grep -iE "kernelsu|magisk|apatch" | head -1`)
	if strings.TrimSpace(ksuLog) != "" {
		line(iBad, "Root detectado en kernel log")
		detail(ksuLog)
		addFinding("KSU", 3, "root in kernel log")
	}

	// /proc/version modificado
	for _, kw := range []string{"kernelsu", "magisk", "apatch", "dirty", "unofficial"} {
		if strings.Contains(strings.ToLower(procVer), kw) {
			line(iBad, "Kernel modificado en /proc/version")
			detail(procVer)
			addFinding("KSU", 2, "modified kernel")
			break
		}
	}

	// Kernels custom que soportan root nativamente
	customKernels := []string{"alucard", "chronos", "sultan", "lychee", "eureka",
		"ethereal", "elitekernel", "wild", "buddy", "panda", "redmi-oc"}
	kernelLow := strings.ToLower(kernel + " " + procVer)
	for _, kn := range customKernels {
		if strings.Contains(kernelLow, kn) {
			line(iBad, "Kernel custom con soporte root: "+kn)
			addFinding("KSU", 2, "custom kernel: "+kn)
		}
	}

	// KernelSU Next
	ksunext := adb(`getprop 2>/dev/null | grep -im1 apatch; getprop 2>/dev/null | grep -im1 ksunext`)
	if strings.TrimSpace(ksunext) != "" {
		line(iBad, "KernelSU Next / APatch en props")
		addFinding("KSU", 3, "ksunext in props")
	}

	// SuSFS
	susfs := adb(`{ test -d /proc/sys/fs/susfs && echo Y; } || { test -d /sys/kernel/security/susfs && echo Y; }`)
	if strings.TrimSpace(susfs) == "Y" {
		line(iBad, "SuSFS detectado — oculta montajes de root")
		addFinding("KSU", 3, "SuSFS detected")
	} else {
		line(iOK, "SuSFS no detectado")
	}

	// Módulos KSU montados
	ksuMount := adb(`grep -iE "KSU on /(system|vendor|product)" /proc/mounts 2>/dev/null | head -3`)
	if strings.TrimSpace(ksuMount) != "" {
		line(iBad, "Módulos KernelSU montados:")
		for _, l := range strings.Split(ksuMount, "\n") {
			if l != "" {
				detail(l)
			}
		}
		addFinding("KSU", 2, "KSU modules mounted")
	}

	// cmdline de /proc
	cmdlineKSU := adb(`tr '\000' ' ' < /proc/cmdline 2>/dev/null | grep -iE "ksu|kernelsu|apatch"`)
	if strings.TrimSpace(cmdlineKSU) != "" {
		line(iBad, "KernelSU/APatch en cmdline del kernel")
		addFinding("KSU", 3, "KSU in cmdline")
	}
}

func checkPIF() {
	sectionHeader("PIF", "PLAY INTEGRITY FIX / SPOOF")

	pifPkgs := []string{
		"es.chiteroman.playintegrityfix",
		"com.chiteroman.playintegrityfix",
		"io.github.vvb2060.playintegrityfix",
	}
	pkgList := adb(`pm list packages 2>/dev/null`)
	found := false
	for _, pkg := range pifPkgs {
		if strings.Contains(pkgList, pkg) {
			line(iBad, "Play Integrity Fix instalado: "+pkg)
			addFinding("PIF", 3, "PIF pkg: "+pkg)
			found = true
		}
	}

	// Módulo PIF en Magisk
	pifMod := adb(`ls /data/adb/modules 2>/dev/null | grep -iE "playintegrity|pif|integrit"`)
	if strings.TrimSpace(pifMod) != "" {
		line(iBad, "Módulo PIF en Magisk: "+pifMod)
		addFinding("PIF", 3, "PIF module: "+pifMod)
		found = true
	}

	// TrickyStore
	if adb(`ls /data/adb/modules 2>/dev/null | grep -i trick`) != "" {
		line(iBad, "TrickyStore (bypass de integridad) detectado")
		addFinding("PIF", 3, "TrickyStore")
		found = true
	}

	// Fingerprint spoofado
	buildID := adb(`getprop ro.build.id 2>/dev/null`)
	sysBuildID := adb(`getprop ro.system.build.id 2>/dev/null`)
	if buildID != "" && sysBuildID != "" && buildID != sysBuildID {
		line(iBad, fmt.Sprintf("Fingerprint adulterado: ro.build.id=%s vs ro.system.build.id=%s", buildID, sysBuildID))
		addFinding("PIF", 2, "fingerprint spoofed")
		found = true
	}

	// ro.debuggable = 1 (inusual en producción)
	if adb(`getprop ro.debuggable 2>/dev/null`) == "1" {
		line(iWarn, "ro.debuggable=1 — dispositivo en modo debug")
		addFinding("PIF", 1, "ro.debuggable=1")
	}

	if !found {
		line(iOK, "Sin Play Integrity Fix")
	}
}

func checkDeviceSpoof() {
	sectionHeader("SPOOF", "DEVICE SPOOFING")

	// Android ID
	androidID := adb(`settings get secure android_id 2>/dev/null`)
	logout(fmt.Sprintf("%s  Android ID: %s%s%s", iInfo+" "+cGray, cWhite, androidID, cReset))

	uniqueChars := make(map[rune]bool)
	for _, c := range androidID {
		uniqueChars[c] = true
	}
	if len(androidID) > 0 && androidID != "null" && (len(uniqueChars) <= 2 || len(androidID) < 15) {
		line(iBad, "Android ID con patrón de spoof")
		addFinding("SPOOF", 2, "Android ID spoofed")
	}

	// Serial SoC vs prop
	hwSerial := adb(`cat /sys/devices/soc0/serial_num 2>/dev/null || cat /sys/bus/soc/devices/soc0/serial_num 2>/dev/null`)
	propSerial := adb(`getprop ro.serialno 2>/dev/null`)
	if hwSerial != "" && propSerial != "" && hwSerial != propSerial {
		line(iBad, fmt.Sprintf("Serial adulterado — SoC: %s ≠ prop: %s", hwSerial, propSerial))
		addFinding("SPOOF", 3, "serial spoofed")
	}

	// Apps de spoof de ID
	spoofApps := []string{
		"com.metatech.deviceidfaker", "com.deviceid.changer",
		"com.xposed.imei", "com.imei.generator", "com.devicechanger.free",
	}
	pkgList := adb(`pm list packages 2>/dev/null`)
	found := false
	for _, pkg := range spoofApps {
		if strings.Contains(pkgList, pkg) {
			line(iBad, "App de spoof de ID: "+pkg)
			addFinding("SPOOF", 3, "ID spoofer: "+pkg)
			found = true
		}
	}
	byName := adb(`pm list packages 2>/dev/null | grep -iE "deviceid|imei.changer|fakeid|androidid"`)
	if strings.TrimSpace(byName) != "" {
		line(iBad, "App de spoof por nombre: "+byName)
		addFinding("SPOOF", 3, "ID spoofer by name")
		found = true
	}

	// Reinstalación post-ban
	firstInstallMS := adb(fmt.Sprintf(`dumpsys package %s 2>/dev/null | grep firstInstallTime | head -1 | grep -oE "[0-9]{10,}"`, gamePkg))
	uptimeSecs := adb(`cut -d. -f1 /proc/uptime 2>/dev/null`)
	nowSecs := adb(`date +%s 2>/dev/null`)
	if firstInstallMS != "" && uptimeSecs != "" && nowSecs != "" {
		fim, _ := parseInt(firstInstallMS)
		ups, _ := parseInt(uptimeSecs)
		now, _ := parseInt(nowSecs)
		if fim > 0 && ups > 0 && now > 0 {
			fim = fim / 1000
			boot := now - ups
			installDays := (now - fim) / 86400
			uptimeDays := ups / 86400
			logout(fmt.Sprintf("%s  Juego instalado hace: %s%dd%s  |  Uptime: %s%dd%s",
				iInfo+" "+cGray, cWhite, installDays, cReset, cWhite, uptimeDays, cReset))
			if fim > boot && ups > 86400 {
				line(iWarn, "Juego instalado después del último boot (reinstalación post-ban)")
				addFinding("SPOOF", 2, "reinstall after boot")
				found = true
			}
			if installDays <= 3 && uptimeDays >= 7 {
				line(iWarn, fmt.Sprintf("Reinstalación reciente: juego %dd vs dispositivo activo %dd", installDays, uptimeDays))
				addFinding("SPOOF", 1, "recent reinstall")
				found = true
			}
		}
	}

	if !found {
		line(iOK, "Sin indicadores de spoof")
	}
}

func checkCACerts() {
	sectionHeader("CERT", "CERTIFICADOS CA / MITM")

	// CA certs del usuario
	userCerts := adb(`ls /data/misc/user/0/cacerts-added/ 2>/dev/null | wc -l`)
	if v, err := parseInt(userCerts); err == nil && v > 0 {
		line(iBad, fmt.Sprintf("%d certificado(s) CA de usuario instalado(s) — posible MITM", v))
		addFinding("CERT", 2, fmt.Sprintf("user CA certs: %d", v))
	} else {
		line(iOK, "Sin CA certs de usuario")
	}

	// Keychain certs
	kcCerts := adb(`ls /data/misc/keychain/certs-added/ 2>/dev/null | wc -l`)
	if v, err := parseInt(kcCerts); err == nil && v > 0 {
		line(iWarn, fmt.Sprintf("%d cert(s) en keychain del sistema", v))
		addFinding("CERT", 1, fmt.Sprintf("keychain certs: %d", v))
	}

	// SSH keys (tunneling para evadir ban)
	sshKeys := adb(`find /data/adb /data/local /sdcard 2>/dev/null -maxdepth 4 \( -name "authorized_keys" -o -name "id_rsa" -o -name "id_ed25519" \) | head -3`)
	if strings.TrimSpace(sshKeys) != "" {
		line(iBad, "Claves SSH encontradas (posible tunnel de evasión):")
		for _, f := range strings.Split(sshKeys, "\n") {
			if f != "" {
				detail(f)
			}
		}
		addFinding("CERT", 2, "SSH keys found")
	}
}

func checkMantisKeymap() {
	sectionHeader("KEYMAP", "KEYMAPPERS / CONTROLES")

	keymapApps := map[string]string{
		"com.mantis.gamepad":               "Mantis Gamepad",
		"com.panda.gamepad":                "Panda Gamepad",
		"com.gamesir.global":               "GameSir",
		"com.flydigi.center":               "Flydigi",
		"com.tincore.gsp.gpad":             "Octopus Keymapper",
		"com.touchsim.gamecontroller":      "TouchSim Gamepad",
		"io.github.ggmouse":                "GG Mouse",
		"com.mobile.legends.gamer.keymapping": "Keymapper Genérico",
	}
	pkgList := adb(`pm list packages 2>/dev/null`)
	found := false
	for pkg, name := range keymapApps {
		if strings.Contains(pkgList, pkg) {
			line(iWarn, "Keymapper: "+name+" ("+pkg+")")
			addFinding("KEYMAP", 2, "keymapper: "+name)
			found = true
		}
	}
	// Buscar por nombre
	byName := adb(`pm list packages 2>/dev/null | grep -iE "mantis|keymap|gamepad.*activat|controller.*map"`)
	if strings.TrimSpace(byName) != "" && !found {
		line(iWarn, "Keymapper por nombre: "+byName)
		addFinding("KEYMAP", 2, "keymapper by name")
		found = true
	}
	if !found {
		line(iOK, "Sin keymappers")
	}
}

func checkRecording() {
	sectionHeader("RECORD", "GRABACIÓN / ESPEJAMIENTO")

	mirrorApps := map[string]string{
		"com.koushikdutta.vysor":        "Vysor",
		"com.genymobile.scrcpy":         "scrcpy",
		"com.github.xianfeng92.scrcpy":  "QtScrcpy",
		"top.samir.guiscrcpy":           "guiScrcpy",
	}
	pkgList := adb(`pm list packages 2>/dev/null`)
	found := false
	for pkg, name := range mirrorApps {
		if strings.Contains(pkgList, pkg) {
			line(iWarn, "App de espejamiento: "+name)
			addFinding("RECORD", 1, "mirroring: "+name)
			found = true
		}
	}

	// Media projection activa
	mediaProj := adb(`dumpsys media_projection 2>/dev/null | grep -iE "isRecording=true|state=STARTED" | head -2`)
	if strings.TrimSpace(mediaProj) != "" {
		line(iBad, "Captura de pantalla ACTIVA")
		addFinding("RECORD", 2, "screen capture active")
		found = true
	}

	// scrcpy proceso
	scrcpyProc := adb(`ps -A 2>/dev/null | grep -iE "scrcpy"`)
	if strings.TrimSpace(scrcpyProc) != "" {
		line(iBad, "Proceso scrcpy activo")
		addFinding("RECORD", 2, "scrcpy process")
		found = true
	}

	// record lock
	recLock := adb(`cat /proc/net/unix 2>/dev/null | grep -iE "recordLock|recordUnlock" | head -2`)
	if strings.TrimSpace(recLock) != "" {
		line(iBad, "Record lock detectado en sockets Unix")
		addFinding("RECORD", 2, "record lock")
		found = true
	}

	if !found {
		line(iOK, "Sin grabación activa")
	}
}

func checkSuspiciousPackages() {
	sectionHeader("APP", "APLICACIONES SOSPECHOSAS")

	suspApps := map[string]string{
		"com.topjohnwu.magisk":              "Magisk",
		"io.github.magisk":                  "Magisk (alt)",
		"io.github.huskydg.magisk":          "Magisk Delta",
		"com.rifsxd.ksunext":               "KernelSU Next",
		"me.weishu.kernelsu":               "KernelSU",
		"me.bmax.apatch":                   "APatch",
		"org.lsposed.manager":              "LSPosed",
		"com.dergoogler.mmrl":              "MMRL",
		"com.googleplay.ndkvs":             "FF Modificado (.ndkvs)",
		"eu.sisik.hackendebug":             "Hack&Debug",
		"me.piebridge.brevent":             "Brevent",
		"io.github.mhmrdd.libxposed.ps.passit": "Passador de Replay",
		"com.lexa.fakegps":                "Fake GPS",
		"io.github.vvb2060.mahoshojo":     "TrickyStore",
		"com.opa334.TrollStore":            "TrollStore",
		"com.reveny.nativecheck":           "NativeCheck",
		"io.github.huskydg.memorydetector": "MemoryDetector",
		"com.system.update.service":        "Servicio Falso",
		"com.zerotier.one":                "ZeroTier",
		"com.lbe.parallel":                "Parallel Space",
		"com.excelliance.multiaccounts":   "Multi Accounts",
	}
	pkgList := adb(`pm list packages 2>/dev/null`)
	found := false
	for pkg, name := range suspApps {
		if strings.Contains(pkgList, pkg) {
			line(iBad, name+" ("+pkg+")")
			addFinding("APP", 2, "suspicious app: "+name)
			found = true
		}
	}

	// Instalador del juego
	installer := adb(fmt.Sprintf(`dumpsys package %s 2>/dev/null | grep installerPackageName | head -1`, gamePkg))
	if installer != "" {
		logout(fmt.Sprintf("%s  %s%s%s", iInfo+" "+cGray, cWhite, installer, cReset))
		instLow := strings.ToLower(installer)
		if strings.Contains(instLow, "null") || strings.Contains(instLow, "bin.mt.plus") {
			line(iWarn, "Instalador sospechoso")
			addFinding("APP", 2, "suspicious installer")
			found = true
		}
	}

	// Historial batterystats
	batt := adb(`dumpsys batterystats 2>/dev/null | grep -oE 'pkgunin=[0-9]+:"[^"]+"' | grep -oE '"[^"]+"' | tr -d '"' | sort -u`)
	for _, pkg := range strings.Split(batt, "\n") {
		if pkg == "" {
			continue
		}
		pkgLow := strings.ToLower(pkg)
		for _, kw := range []string{"magisk", "xposed", "kernelsu", "apatch", "frida", "cheat", "hack", "bypass", "passit"} {
			if strings.Contains(pkgLow, kw) {
				line(iWarn, "App sospechosa desinstalada: "+pkg)
				addFinding("APP", 1, "uninstalled: "+pkg)
				found = true
				break
			}
		}
	}

	if !found {
		line(iOK, "Sin apps sospechosas")
	}
}

func checkNetworkPorts() {
	sectionHeader("PROXY", "PUERTOS Y CONEXIONES")

	// Frida ports 27042/27043
	fridaPort := adb(`for f in /proc/net/tcp /proc/net/tcp6; do [ -r "$f" ] || continue; grep -iE ":(69B2|69B3) " "$f" | grep -E " 0A "; done | head -3`)
	if strings.TrimSpace(fridaPort) != "" {
		line(iBad, "Puertos Frida detectados en LISTEN (27042/27043)")
		addFinding("HOOK", 3, "Frida ports")
	} else {
		line(iOK, "Sin puertos Frida")
	}

	// Sockets ZygoteNext / APatch
	unixSocks := adb(`cat /proc/net/unix 2>/dev/null | grep -oE "@zn_(init|global|zygote|log)_[A-Za-z0-9]+" | sort -u | head -5`)
	if strings.TrimSpace(unixSocks) != "" {
		line(iBad, "Sockets APatch/ZygoteNext:")
		for _, s := range strings.Split(unixSocks, "\n") {
			if s != "" {
				detail(s)
			}
		}
		addFinding("HOOK", 2, "ZygoteNext sockets")
	}

	// Puertos localhost inesperados
	unexpPorts := adb(`awk '$4=="0A"{print $2}' /proc/net/tcp /proc/net/tcp6 2>/dev/null | grep -E "^0100007F:|^\[::ffff:7f" | while read addr; do port=$((16#${addr##*:})); echo $port; done | sort -nu | grep -vE "^(80|443|53|8080|4444|5554|5555|8888|9229)$"`)
	if strings.TrimSpace(unexpPorts) != "" {
		line(iWarn, "Puertos localhost inesperados:")
		for _, p := range strings.Split(unexpPorts, "\n") {
			if p != "" {
				detail(":"+p)
			}
		}
		addFinding("PROXY", 1, "unexpected localhost ports")
	}
}

func checkADBConnections() {
	sectionHeader("SYSTEM", "CONEXIONES ADB")
	usbState := adb(`getprop sys.usb.state 2>/dev/null`)
	logout(fmt.Sprintf("%s  USB state: %s%s%s", iInfo+" "+cGray, cWhite, usbState, cReset))

	// AdbDebuggingManager fallos
	adbFails := adb(`logcat -d -b system 2>/dev/null | grep -c "AdbDebuggingManager.*Read failed"`)
	if v, err := parseInt(adbFails); err == nil && v > 2 {
		line(iWarn, fmt.Sprintf("AdbDebuggingManager: %d fallos — PC desconectado rápidamente", v))
		addFinding("SYSTEM", 1, "ADB disconnect fast")
	}

	// Procesos desde /data/adb/
	dataProcs := adb(`for f in /proc/[0-9]*/exe; do l=$(readlink "$f" 2>/dev/null); case "$l" in /data/adb/*ksud*|/data/adb/*magiskd*|/data/adb/*apd*) continue;; /data/adb/*) echo "${f%%/exe}: $l";; esac; done 2>/dev/null | head -5`)
	if strings.TrimSpace(dataProcs) != "" {
		line(iBad, "Procesos ejecutables desde /data/adb/:")
		for _, l := range strings.Split(dataProcs, "\n") {
			if l != "" {
				detail(l)
			}
		}
		addFinding("ROOT", 2, "proc in /data/adb/")
	} else {
		line(iOK, "Sin procesos inesperados en /data/adb/")
	}
}

func checkUninstalledApps() {
	sectionHeader("APP", "APPS DESINSTALADAS SOSPECHOSAS")
	uninstLog := adb(fmt.Sprintf(`logcat -d -v time -s ActivityManager:I PackageManager:I 2>/dev/null | grep -iE "deletePackageX.*%s|pkg removed.*%s" | tail -3`, gamePkg, gamePkg))
	if strings.TrimSpace(uninstLog) != "" {
		line(iWarn, "Desinstalación previa del juego registrada:")
		for _, l := range strings.Split(uninstLog, "\n") {
			if l != "" {
				detail(l)
			}
		}
		addFinding("SPOOF", 1, "game previously uninstalled")
	} else {
		line(iOK, "Sin desinstalaciones sospechosas")
	}
}

func checkDataLocalTmp() {
	sectionHeader("OTHER", "/DATA/LOCAL/TMP")
	files := adb(`for f in /data/local/tmp/* /data/local/tmp/.*; do n="${f##*/}"; case "$n" in "." | "..") ;; *) [ -e "$f" ] && echo "$n";; esac; done`)
	if strings.TrimSpace(files) == "" {
		line(iOK, "/data/local/tmp vacío")
		return
	}
	line(iWarn, "Archivos en /data/local/tmp:")
	for _, f := range strings.Split(files, "\n") {
		if f == "" {
			continue
		}
		detail(f)
		fLow := strings.ToLower(f)
		for _, kw := range []string{"frida", "hook", "inject", "cheat", "hack", "bypass", "shizuku", "brevent"} {
			if strings.Contains(fLow, kw) {
				logout(fmt.Sprintf("         %s^ sospechoso%s", cRed, cReset))
				addFinding("OTHER", 1, "suspicious file in tmp: "+f)
				break
			}
		}
	}
	addFinding("OTHER", 1, "files in /data/local/tmp")
}

func checkDropboxCrashes() {
	sectionHeader("SYSTEM", "CRASHES (DROPBOX)")
	crashes := adb(`dumpsys dropbox 2>/dev/null | grep -E "native_crash|TOMBSTONE|system_server" | sed "s/.*[0-9][0-9]:[0-9][0-9]:[0-9][0-9] //" | sed "s/ ([0-9]* bytes)//" | sort | uniq -c | sort -rn | awk '$1>=3{print $1" x "$2}' | head -5`)
	if strings.TrimSpace(crashes) != "" {
		line(iWarn, "Crashes repetidos:")
		for _, l := range strings.Split(crashes, "\n") {
			if l != "" {
				detail(l)
			}
		}
		addFinding("OTHER", 1, "repeated crashes")
	} else {
		line(iOK, "Sin crashes repetidos")
	}
}

func checkAutoTime() {
	sectionHeader("SYSTEM", "FECHA / HORA")
	autoTime := adb(`settings get global auto_time 2>/dev/null`)
	tz := adb(`getprop persist.sys.timezone 2>/dev/null`)
	logout(fmt.Sprintf("%s  auto_time: %s%s%s  |  Zona: %s%s%s",
		iInfo+" "+cGray, cWhite, autoTime, cReset, cWhite, tz, cReset))
	if autoTime == "0" {
		line(iBad, "Hora automática DESACTIVADA — facilita manipulación de timestamps")
		addFinding("OTHER", 2, "auto time disabled")
	} else {
		line(iOK, "Hora automática activa")
	}

	// auto_time_zone
	atz := adb(`settings get global auto_time_zone 2>/dev/null`)
	if atz == "0" {
		line(iWarn, "Zona horaria automática desactivada")
	}
}

// ─── NUEVA DETECCIÓN: SCENES ──────────────────
func checkScenes() {
	sectionHeader("APP", "MODIFICACIÓN DE ESCENAS / ASSETS")

	// .ndkvs (Free Fire modificado)
	ndkvs := adb(fmt.Sprintf(`find /sdcard/Android/data/%s -name "*.ndkvs" 2>/dev/null | head -3`, gamePkg))
	if strings.TrimSpace(ndkvs) != "" {
		line(iBad, "Archivo .ndkvs detectado (Free Fire modificado):")
		for _, f := range strings.Split(ndkvs, "\n") {
			if f != "" {
				detail(f)
			}
		}
		addFinding("APP", 3, ".ndkvs file found")
	}

	// contentcache/Optional — shaders con flags 0xC2
	optDir := fmt.Sprintf("/sdcard/Android/data/%s/files/contentcache/Optional", gamePkg)
	optFiles := adb(fmt.Sprintf(`find '%s' -type f -newer '/proc/uptime' 2>/dev/null | head -5`, optDir))
	if strings.TrimSpace(optFiles) != "" {
		line(iWarn, "Archivos Optional modificados recientemente:")
		for _, f := range strings.Split(optFiles, "\n") {
			if f != "" {
				detail(f)
			}
		}
		addFinding("WALL", 2, "Optional files modified")
	}

	// gameassetbundles — escenas custom
	sceneDir := fmt.Sprintf("/sdcard/Android/data/%s/files/contentcache/Optional/android/gameassetbundles", gamePkg)
	nonUnity := adb(fmt.Sprintf(`find '%s' -type f 2>/dev/null | while read f; do h=$(head -c 7 "$f" 2>/dev/null); [ "$h" != "UnityFS" ] && echo "$f"; done | head -5`, sceneDir))
	if strings.TrimSpace(nonUnity) != "" {
		line(iBad, "Assets no-UnityFS (posible wallhack/scene mod):")
		for _, f := range strings.Split(nonUnity, "\n") {
			if f != "" {
				detail(f)
			}
		}
		addFinding("WALL", 3, "non-UnityFS assets")
	} else {
		line(iOK, "Assets de escena OK")
	}

	// Exploit/payload en /data/local/tmp
	exploit := adb(`find /data/local/tmp 2>/dev/null -name "*.so" -o -name "*.bin" -o -name "payload*" -o -name "exploit*" | head -5`)
	if strings.TrimSpace(exploit) != "" {
		line(iBad, "Exploit/payload detectado en /data/local/tmp:")
		for _, f := range strings.Split(exploit, "\n") {
			if f != "" {
				detail(f)
			}
		}
		addFinding("HOOK", 3, "exploit/payload found")
	}
}

// ──────────────────────────────────────────────
//  RESUMEN
// ──────────────────────────────────────────────

func showSummary() {
	fmt.Println()
	fmt.Printf("%s%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n",
		cBold, cCyan, cReset)
	fmt.Printf("  %s%sFINDINGS%s\n\n", cBold, cWhite, cReset)

	tagColors := map[string]string{
		"ROOT": cRed, "HOOK": cPurple, "WALL": cOrange,
		"REPLAY": cYellow, "PIF": cCyan, "KSU": cRed,
		"SPOOF": cOrange, "APP": cBlue, "PROXY": cYellow,
		"CERT": cPurple, "KEYMAP": cBlue, "RECORD": cCyan,
		"SYSTEM": cGray, "OTHER": cGray,
	}
	sevIcon := map[int]string{1: iInfo, 2: iWarn, 3: iBad}

	if len(findings) == 0 {
		logout(fmt.Sprintf("  %s  Sin hallazgos%s", cGreen, cReset))
	} else {
		for _, f := range findings {
			col := tagColors[f.Tag]
			if col == "" {
				col = cGray
			}
			icon := sevIcon[f.Severity]
			logout(fmt.Sprintf("%s  %s[%s]%s %s",
				icon, col+cBold, f.Tag, cReset, f.Msg))
		}
	}

	fmt.Println()
	logout(fmt.Sprintf("  %sJuego:%s %s%s%s", cGray, cReset, cWhite, gameSelected, cReset))
	if deviceHWID != "" {
		logout(fmt.Sprintf("  %sHWID: %s%s%s", cGray, cYellow, deviceHWID, cReset))
	}
	logout(fmt.Sprintf("  %sScore:%s %s%d%s", cGray, cReset, cWhite, suspCount, cReset))
	fmt.Println()

	fmt.Printf("%s%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n",
		cBold, cCyan, cReset)
	fmt.Println()

	if suspCount == 0 {
		fmt.Printf("  %s%s✔  DISPOSITIVO LIMPIO%s\n", cBold, cGreen, cReset)
	} else if suspCount <= 4 {
		fmt.Printf("  %s%s⚑  ADVERTENCIA — REVISAR MANUALMENTE%s\n", cBold, cYellow, cReset)
	} else {
		fmt.Printf("  %s%s✘  ALTO RIESGO — CHEATS DETECTADOS%s\n", cBold, cRed, cReset)
	}
	fmt.Println()
	logout(fmt.Sprintf("  %sLog: %s%s%s", cGray, cDim+cWhite, logPath, cReset))
	fmt.Printf("%s%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n",
		cBold, cCyan, cReset)
}

// ──────────────────────────────────────────────
//  OPCIONES DEL MENÚ
// ──────────────────────────────────────────────

func verUltimoLog() {
	cls()
	banner()
	entries, _ := os.ReadDir(os.Getenv("HOME"))
	var logs []string
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), "unk_scan_") && strings.HasSuffix(e.Name(), ".txt") {
			logs = append(logs, e.Name())
		}
	}
	if len(logs) == 0 {
		fmt.Printf("  %sSin logs guardados%s\n", cRed, cReset)
		fmt.Printf("  %sEnter...%s ", cGray, cReset)
		read()
		return
	}
	// El más reciente es el último en orden alfabético
	last := logs[len(logs)-1]
	content, err := os.ReadFile(os.Getenv("HOME") + "/" + last)
	if err == nil {
		fmt.Println(string(content))
	}
	fmt.Printf("  %sEnter...%s ", cGray, cReset)
	read()
}

func guardarDiagnostico() {
	cls()
	banner()
	fmt.Printf("  %s%s[ DIAGNÓSTICO COMPLETO ]%s\n\n", cBold, cBlue, cReset)

	if !deviceConnected() {
		fmt.Printf("  %sSin dispositivo conectado%s\n", cRed, cReset)
		fmt.Printf("  %sEnter...%s ", cGray, cReset)
		read()
		return
	}

	dumpDir := fmt.Sprintf("%s/dump_%s", os.Getenv("HOME"), time.Now().Format("20060102_150405"))
	os.MkdirAll(dumpDir, 0755)
	fmt.Printf("  %s%s%s\n\n", cGray, dumpDir, cReset)

	type dumpJob struct {
		name string
		cmd  string
		file string
	}
	jobs := []dumpJob{
		{"getprop", "adb shell getprop 2>/dev/null", "getprop.txt"},
		{"kernel", "adb shell uname -a; adb shell cat /proc/version; adb shell tr '\\000' ' ' < /proc/cmdline", "kernel.txt"},
		{"logcat main", "adb shell logcat -d -b main 2>/dev/null", "logcat_main.txt"},
		{"logcat system", "adb shell logcat -d -b system 2>/dev/null", "logcat_system.txt"},
		{"logcat events", "adb shell logcat -d -b events 2>/dev/null", "logcat_events.txt"},
		{"logcat kernel", "adb shell logcat -b kernel -d 2>/dev/null", "logcat_kernel.txt"},
		{"logcat crash", "adb shell logcat -d -b crash 2>/dev/null", "logcat_crash.txt"},
		{"logcat all", "adb shell logcat -d -v threadtime -b all 2>/dev/null | tail -n 8000", "logcat_all.txt"},
		{"dumpsys package", "adb shell dumpsys package 2>/dev/null", "dumpsys_package.txt"},
		{"dumpsys activity", "adb shell dumpsys activity 2>/dev/null", "dumpsys_activity.txt"},
		{"dumpsys batterystats", "adb shell dumpsys batterystats 2>/dev/null", "dumpsys_batterystats.txt"},
		{"dumpsys appops", "adb shell dumpsys appops 2>/dev/null", "dumpsys_appops.txt"},
		{"dumpsys overlay", "adb shell dumpsys overlay 2>/dev/null", "dumpsys_overlay.txt"},
		{"dumpsys media_projection", "adb shell dumpsys media_projection 2>/dev/null", "dumpsys_media_projection.txt"},
		{"dumpsys usagestats", "adb shell dumpsys usagestats 2>/dev/null | tail -n 8000", "dumpsys_usagestats.txt"},
		{"dumpsys dropbox", "adb shell dumpsys dropbox 2>/dev/null", "dumpsys_dropbox.txt"},
		{"ps", "adb shell ps -A -Z 2>/dev/null", "ps_full.txt"},
		{"mounts", "adb shell cat /proc/mounts 2>/dev/null", "mounts.txt"},
		{"tcp", "adb shell cat /proc/net/tcp /proc/net/tcp6 2>/dev/null", "tcp.txt"},
		{"unix", "adb shell cat /proc/net/unix 2>/dev/null", "unix_sockets.txt"},
		{"ff package", fmt.Sprintf("adb shell dumpsys package %s 2>/dev/null", gamePkg), "pkg_ff.txt"},
	}

	for _, j := range jobs {
		fmt.Printf("  %s→ %-26s%s", cBlue, j.name, cReset)
		parts := strings.Fields(j.cmd)
		out, _ := exec.Command(parts[0], parts[1:]...).Output()
		os.WriteFile(dumpDir+"/"+j.file, out, 0644)
		fmt.Printf("%s ok%s\n", cGreen, cReset)
	}

	fmt.Println()
	fmt.Printf("  %s✔ Guardado: %s%s%s\n", cGreen, cWhite, dumpDir, cReset)
	fmt.Printf("  %sComprimir: tar czf dump.tar.gz -C $HOME %s%s\n",
		cGray, strings.TrimPrefix(dumpDir, os.Getenv("HOME")+"/"), cReset)
	fmt.Printf("\n  %sEnter...%s ", cGray, cReset)
	read()
}

func actualizarScanner() {
	cls()
	banner()
	fmt.Printf("  %sActualizando...%s\n", cBlue, cReset)
	cmd := exec.Command("git", "fetch", "origin")
	cmd.Run()
	cmd = exec.Command("git", "reset", "--hard", "origin/main")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()
	fmt.Printf("\n  %s✔ Actualizado%s\n", cGreen, cReset)
	fmt.Printf("  %sEnter...%s ", cGray, cReset)
	read()
}

// ──────────────────────────────────────────────
//  MAIN
// ──────────────────────────────────────────────

func main() {
	menu()
}
 
