#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

; Tray icon göster
A_IconHidden := false

; ─── Global Değişkenler ────────────────────────────────────────────────────
global activeAmmo  := "5.56"
global macroOn     := false
global shooting    := false
global toggleMacro := ""
global recoilNum   := ""
global recoilLabel := ""
global progressBar := ""
global statusDot   := ""
global saveStatus  := ""
global a556 := "", a762 := "", a9mm := ""
global rgbLabel := "", rgbHue := 0
global recoilValues := Map("5.56", 0, "7.62", 0, "9MM", 0)
global glowState := 0
global sysBadge := ""
global sysPulseState := 0
global sysBarStrip := ""
global hudAmmo := "", hudRecoil := "", hudStatus := ""
global hudVisible := true
global hudPosLabel := ""

; İstatistik değişkenleri
global statTotal := 0
global stat556 := 0, stat762 := 0, stat9mm := 0
global statLabel := ""
global verLabel  := ""
global uptimeLabel := ""
global uptimeSeconds := 0
global motoLabel := ""
global ramLabel  := ""

; ─── Otomatik Güncelleme ───────────────────────────────────────────────────
global updateApiUrl := "https://api.github.com/repos/berkaycimh/macro/releases/latest"
global updateExeUrl := "https://github.com/berkaycimh/macro/releases/latest/download/PSP.exe"

; Versiyon — bu değer her zaman derlenen exe ile eşleşmeli
global currentVersion := "1.6"

; Şifre ekranı kaldırıldı

; ─── Ayarları Yükle ────────────────────────────────────────────────────────
iniFile := A_ScriptDir "\settings.ini"
if FileExist(iniFile) {
    recoilValues["5.56"] := IniRead(iniFile, "Recoil", "556", 0)
    recoilValues["7.62"] := IniRead(iniFile, "Recoil", "762", 0)
    recoilValues["9MM"]  := IniRead(iniFile, "Recoil", "9mm", 0)
    activeAmmo           := IniRead(iniFile, "Settings", "LastAmmo", "5.56")
    statTotal := IniRead(iniFile, "Stats", "Total", 0)
    stat556   := IniRead(iniFile, "Stats", "556",   0)
    stat762   := IniRead(iniFile, "Stats", "762",   0)
    stat9mm   := IniRead(iniFile, "Stats", "9mm",   0)
}
global hudX := IniRead(iniFile, "HUD", "X", -1)
global hudY := IniRead(iniFile, "HUD", "Y", 10)
global hudOpacity := IniRead(iniFile, "HUD", "Opacity", 210)
; ── Güncelleme Splash Ekranı ──
splashGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
splashGui.BackColor := "0e0e0e"
splashGui.MarginX := 0
splashGui.MarginY := 0
splashGui.Add("Text", "x0 y0 w300 h2 Background00ff88")
splashGui.SetFont("s10 w800 cFFFFFF", "Consolas")
splashGui.Add("Text", "x0 y12 w300 Background0e0e0e Center", "405-B / 406-X")
splashGui.SetFont("s8 w600 c00ff88", "Consolas")
splashGui.Add("Text", "x0 y32 w300 Background0e0e0e Center", "Güncelleme kontrol ediliyor...")
splashGui.SetFont("s7 c555555", "Consolas")
global splashStatus := splashGui.Add("Text", "x0 y50 w300 Background0e0e0e Center", "GitHub bağlantısı kuruluyor...")
splashGui.Add("Text", "x0 y68 w300 h1 Background1a1a1a")
splashGui.SetFont("s7 c333333", "Consolas")
splashGui.Add("Text", "x0 y72 w300 h18 Background0a0a0a Center", "berkaycimh  •  v" currentVersion)
screenW := SysGet(0)
screenH := SysGet(1)
splashGui.Show("w300 h92 x" (screenW-300)//2 " y" (screenH-92)//2)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", splashGui.Hwnd, "uint", 33, "int*", 2, "uint", 4)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", splashGui.Hwnd, "uint", 34, "int*", 0x0e0e0e, "uint", 4)

; 5 saniye bekle ve güncelleme kontrol et
Sleep(1000)
splashStatus.Value := "Sunucuya bağlanılıyor..."
Sleep(500)

try {
    ; GitHub Releases API'den latest tag_name çek
    whr := ComObject("MSXML2.ServerXMLHTTP.6.0")
    whr.Open("GET", updateApiUrl, false)
    whr.SetRequestHeader("User-Agent", "AutoHotkey")
    whr.Send()
    apiResponse := whr.ResponseText

    ; tag_name alanını parse et — örn: "tag_name":"v1.4" veya "tag_name":"1.4"
    latestVer := ""
    if RegExMatch(apiResponse, '"tag_name"\s*:\s*"v?([^"]+)"', &vm)
        latestVer := vm[1]

    if (latestVer != "" && latestVer != currentVersion) {
        splashStatus.SetFont("cffcc00")
        splashStatus.Value := "↓ v" latestVer " indiriliyor..."
        Sleep(800)

        ; API yanıtından browser_download_url'yi parse et — redirect yok, direkt link
        dlUrl := ""
        if RegExMatch(apiResponse, '"browser_download_url"\s*:\s*"([^"]+)"', &dm)
            dlUrl := dm[1]
        if (dlUrl = "")
            dlUrl := updateExeUrl

        ; EXE modunda: PowerShell ile indir — HTTPS + redirect tam destek
        tmpExe := A_ScriptDir "\macro_new.exe"
        try FileDelete(tmpExe)

        psCmd := 'powershell -NoProfile -NonInteractive -Command "Invoke-WebRequest -Uri ' "'" dlUrl "'" ' -OutFile ' "'" tmpExe "'" ' -UseBasicParsing"'
        RunWait(psCmd,, "Hide")

        ; Boyut kontrolü — 1MB altıysa geçersiz say
        if (!FileExist(tmpExe) || FileGetSize(tmpExe) < 1000000) {
            try FileDelete(tmpExe)
            splashStatus.SetFont("cff3355")
            splashStatus.Value := "İndirme başarısız, devam ediliyor..."
            Sleep(2000)
        } else {
            splashStatus.Value := "Yükleniyor, yeniden başlatılıyor..."
            Sleep(500)
            oldExe := A_ScriptFullPath
            cmd := 'cmd /c ping -n 2 127.0.0.1 >nul & move /y "' tmpExe '" "' oldExe '" & start "" "' oldExe '"'
            Run(cmd,, "Hide")
            splashGui.Destroy()
            ExitApp()
        }
    } else {
        splashStatus.SetFont("c00ff88")
        splashStatus.Value := "✔ Güncel — v" currentVersion
        Sleep(1500)
    }
} catch as e {
    splashStatus.SetFont("cff3355")
    splashStatus.Value := "Bağlantı yok, devam ediliyor..."
    Sleep(2000)
}
splashGui.Destroy()
; ─── GUI ───────────────────────────────────────────────────────────────────
G := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
G.BackColor := "0e0e0e"
G.MarginX := 0
G.MarginY := 0

; ── Titlebar (h=44) ──
global sysBarStrip := G.Add("Text", "x0 y0 w4 h44 Background00ff88")
G.Add("Text", "x4 y0 w396 h44 Background0a0a0a")
G.SetFont("s7 w700 c00ff88", "Consolas")
global sysBadge := G.Add("Text", "x14 y4 w50 h36 Background003322 Center +0x200", "SYS v" currentVersion)
G.SetFont("s10 w800 cFFFFFF", "Consolas")
G.Add("Text", "x70 y8 w185 Background0a0a0a", "405-B / 406-X")
G.Add("Text", "x70 y24 w185 Background0a0a0a", "Kullanımı riskli değildir")
G.Add("Text", "x260 y0 w1 h44 Background222222")
G.SetFont("s6 ccccccc", "Consolas")
G.Add("Text", "x262 y6 w76 h14 Background0a0a0a Center", "UPTIME")
G.SetFont("s11 w700 c00ff88", "Consolas")
global uptimeLabel := G.Add("Text", "x262 y20 w76 h20 Background0a0a0a Center", "00:00")
G.Add("Text", "x334 y0 w1 h44 Background222222")
G.SetFont("s12 w700 c555555", "Consolas")
minBtn   := G.Add("Text", "x335 y0 w36 h44 Background0a0a0a Center +0x200", "─")
closeBtn := G.Add("Text", "x373 y0 w27 h44 Background0a0a0a Center +0x200", "×")
minBtn.OnEvent("Click",    (*) => G.Hide())
closeBtn.OnEvent("Click",  (*) => ExitApp())

; Çizgiyi WM_PAINT ile her zaman yeniden çiz — hiçbir kontrol silemez
OnMessage(0x000F, DrawTitleLines)
DrawTitleLines(wParam, lParam, msg, hwnd) {
    global G
    if (hwnd != G.Hwnd)
        return
    hdc := DllCall("GetDC", "ptr", hwnd, "ptr")
    hPen := DllCall("CreatePen", "int", 0, "int", 1, "uint", 0x222222, "ptr")
    DllCall("SelectObject", "ptr", hdc, "ptr", hPen)
    DllCall("MoveToEx", "ptr", hdc, "int", 372, "int", 0, "ptr", 0)
    DllCall("LineTo",   "ptr", hdc, "int", 372, "int", 44)
    DllCall("MoveToEx", "ptr", hdc, "int", 334, "int", 0, "ptr", 0)
    DllCall("LineTo",   "ptr", hdc, "int", 334, "int", 44)
    DllCall("MoveToEx", "ptr", hdc, "int", 260, "int", 0, "ptr", 0)
    DllCall("LineTo",   "ptr", hdc, "int", 260, "int", 44)
    DllCall("DeleteObject", "ptr", hPen)
    DllCall("ReleaseDC", "ptr", hwnd, "ptr", hdc)
}

; X hover efekti — WM_MOUSEMOVE ile
global closeBtnHover := false
OnMessage(0x200, WM_MOUSEMOVE_Handler)
WM_MOUSEMOVE_Handler(wParam, lParam, msg, hwnd) {
    global closeBtn, closeBtnHover
    if (hwnd = closeBtn.Hwnd) {
        if (!closeBtnHover) {
            closeBtnHover := true
            closeBtn.SetFont("cff3355")
        }
    } else {
        if (closeBtnHover) {
            closeBtnHover := false
            closeBtn.SetFont("c555555")
        }
    }
}
G.Add("Text", "x4 y0 w256 h44 BackgroundTrans").OnEvent("Click", DragWin)

; ── Status Strip (h=28) ──
G.Add("Text", "x0 y44 w400 h1 Background222222")
G.Add("Text", "x0 y45 w400 h28 Background0a0a0a")
G.SetFont("s8 w700 cff3355", "Consolas")
statusDot := G.Add("Text", "x10 y53 w90 Background0a0a0a", "● OFFLINE")
G.Add("Text", "x104 y52 w1 h14 Background222222")
G.SetFont("s10 w800 cffb300", "Consolas")
G.Add("Text", "x110 y49 w60 Background0a0a0a", "PUBG")
G.SetFont("s7 c4488ff", "Consolas")
global motoLabel := G.Add("Text", "x160 y53 w230 Background0a0a0a Right", "")

; ── Silah Seçimi (y=73) ──
G.Add("Text", "x0 y73 w400 h1 Background222222")
G.Add("Text", "x0 y74 w400 h22 Background0e0e0e")
G.Add("Text", "x10 y79 w60 h1 Background222222")
G.SetFont("s7 ccccccc", "Consolas")
G.Add("Text", "x74 y78 w80 Background0e0e0e Center", "SİLAH SEÇİMİ")
G.Add("Text", "x158 y79 w232 h1 Background222222")
G.Add("Text", "x0 y96 w400 h52 Background0e0e0e")
; 5.56
G.Add("Text", "x10 y96 w88 h52 Background141414")
G.SetFont("s6 ccccccc", "Consolas")
G.Add("Text", "x10 y99 w88 Background141414 Center", "F1")
G.SetFont("s11 w800 c00ff88", "Consolas")
a556 := G.Add("Text", "x10 y108 w88 h24 Background141414 Center", "5.56")
G.SetFont("s7 ccccccc", "Consolas")
G.Add("Text", "x10 y132 w88 Background141414 Center", "Rifle")
; 7.62
G.Add("Text", "x104 y96 w88 h52 Background141414")
G.SetFont("s6 ccccccc", "Consolas")
G.Add("Text", "x104 y99 w88 Background141414 Center", "F2")
G.SetFont("s11 w800 cffcc00", "Consolas")
a762 := G.Add("Text", "x104 y108 w88 h24 Background141414 Center", "7.62")
G.SetFont("s7 ccccccc", "Consolas")
G.Add("Text", "x104 y132 w88 Background141414 Center", "DMR/SR")
; 9MM
G.Add("Text", "x198 y96 w88 h52 Background141414")
G.SetFont("s6 ccccccc", "Consolas")
G.Add("Text", "x198 y99 w88 Background141414 Center", "F3")
G.SetFont("s11 w800 cff8800", "Consolas")
a9mm := G.Add("Text", "x198 y108 w88 h24 Background141414 Center", "9MM")
G.SetFont("s7 ccccccc", "Consolas")
G.Add("Text", "x198 y132 w88 Background141414 Center", "SMG")
; BOMBA
G.Add("Text", "x292 y96 w98 h52 Background141414")
G.SetFont("s6 ccccccc", "Consolas")
G.Add("Text", "x292 y99 w98 Background141414 Center", "F4")
G.SetFont("s11 w800 c4488ff", "Consolas")
aBomba := G.Add("Text", "x292 y108 w98 h24 Background141414 Center", "BOMBA")
G.SetFont("s7 ccccccc", "Consolas")
G.Add("Text", "x292 y132 w98 Background141414 Center", "Grenade")
a556.OnEvent("Click",   (*) => SetAmmo("5.56"))
a762.OnEvent("Click",   (*) => SetAmmo("7.62"))
a9mm.OnEvent("Click",   (*) => SetAmmo("9MM"))
aBomba.OnEvent("Click", (*) => SetAmmoKey("BOMBA"))

; ── Recoil (y=148) ──
G.Add("Text", "x0 y148 w400 h1 Background222222")
G.Add("Text", "x0 y149 w400 h22 Background0e0e0e")
G.Add("Text", "x10 y154 w60 h1 Background222222")
G.SetFont("s7 ccccccc", "Consolas")
G.Add("Text", "x74 y153 w90 Background0e0e0e Center", "RECOİL KONTROLÜ")
G.Add("Text", "x168 y154 w222 h1 Background222222")
G.Add("Text", "x10 y171 w380 h60 Background141414")
G.SetFont("s9 w700 c00ff88", "Consolas")
recoilLabel := G.Add("Text", "x20 y180 w50 Background141414", "5.56")
G.SetFont("s9 ccccccc", "Consolas")
G.Add("Text", "x72 y180 w160 Background141414", "— Aşağı Çekme")
G.SetFont("s22 w800 c00ff88", "Consolas")
recoilNum := G.Add("Text", "x280 y172 w60 Background141414 Right", "0")
G.SetFont("s8 c555555", "Consolas")
G.Add("Text", "x342 y192 w28 Background141414", "/100")
G.Add("Text", "x20 y208 w370 h4 Background1a1a1a")
global progressBar := G.Add("Text", "x20 y208 w0 h4 Background00ff88")
G.SetFont("s7 c333333", "Consolas")
G.Add("Text", "x20 y215 w50 Background141414", "0")
G.Add("Text", "x185 y215 w30 Background141414 Center", "50")
G.Add("Text", "x340 y215 w50 Background141414 Right", "100")

; ── Macro Toggle (y=231) ──
G.Add("Text", "x0 y231 w400 h1 Background222222")
G.Add("Text", "x0 y232 w400 h42 Background0e0e0e")
G.SetFont("s10 w600 ccccccc", "Consolas")
G.Add("Text", "x14 y240 w200 Background0e0e0e", "Macro")
G.SetFont("s7 ccccccc", "Consolas")
G.Add("Text", "x14 y254 w200 Background0e0e0e", "DELETE — aç/kapat")
G.Add("Text", "x290 y232 w1 h42 Background222222")
G.SetFont("s9 w700 cff3355", "Consolas")
toggleMacro := G.Add("Text", "x291 y232 w109 h42 Background1a0008 Center +0x200", "✘ PASİF")
toggleMacro.OnEvent("Click", (*) => DoToggleMacro())

; ── Mini HUD (y=274) ──
G.Add("Text", "x0 y274 w400 h1 Background222222")
G.Add("Text", "x0 y275 w400 h42 Background0e0e0e")
G.SetFont("s10 w600 ccccccc", "Consolas")
G.Add("Text", "x14 y283 w80 Background0e0e0e", "Mini HUD")
G.Add("Text", "x100 y275 w1 h42 Background222222")
G.SetFont("s9 w700 cffffff", "Consolas")
btnUp    := G.Add("Text", "x106 y282 w24 h28 Background1a1a1a Center +0x200", "▲")
btnLeft  := G.Add("Text", "x132 y282 w24 h28 Background1a1a1a Center +0x200", "◄")
btnDown  := G.Add("Text", "x158 y282 w24 h28 Background1a1a1a Center +0x200", "▼")
btnRight := G.Add("Text", "x184 y282 w24 h28 Background1a1a1a Center +0x200", "►")
btnUp.SetFont("s9 w700 cffffff", "Consolas")
btnLeft.SetFont("s9 w700 cffffff", "Consolas")
btnDown.SetFont("s9 w700 cffffff", "Consolas")
btnRight.SetFont("s9 w700 cffffff", "Consolas")
G.SetFont("s7 c333333", "Consolas")
global hudPosLabel := G.Add("Text", "x212 y287 w70 Background0e0e0e", "")
btnUp.OnEvent("Click",    (*) => MoveHUD(0, -10))
btnLeft.OnEvent("Click",  (*) => MoveHUD(-10, 0))
btnDown.OnEvent("Click",  (*) => MoveHUD(0, 10))
btnRight.OnEvent("Click", (*) => MoveHUD(10, 0))
G.Add("Text", "x290 y275 w1 h42 Background222222")
G.SetFont("s9 w700 c00ff88", "Consolas")
global hudToggleBtn := G.Add("Text", "x291 y275 w109 h42 Background001a0a Center +0x200", "AÇIK")
hudToggleBtn.OnEvent("Click", (*) => ToggleHUD())

; ── Kaydet (y=317) ──
G.Add("Text", "x0 y317 w400 h1 Background222222")
G.Add("Text", "x0 y318 w400 h42 Background0e0e0e")
G.SetFont("s10 w600 ccccccc", "Consolas")
G.Add("Text", "x14 y326 w200 Background0e0e0e", "Ayarları Kaydet")
G.SetFont("s7 c555555", "Consolas")
global saveStatus := G.Add("Text", "x14 y340 w200 Background0e0e0e", "✔ otomatik kaydediliyor")
G.Add("Text", "x290 y318 w1 h42 Background222222")
G.SetFont("s9 w700 c4488ff", "Consolas")
saveBtn := G.Add("Text", "x291 y318 w109 h42 Background001020 Center +0x200", "KAYDET")
saveBtn.OnEvent("Click", (*) => DoSave())

; ── Önerilen Ayarlar (y=360) ──
G.Add("Text", "x0 y360 w400 h1 Background222222")
G.Add("Text", "x0 y361 w400 h42 Background0e0e0e")
G.SetFont("s10 w600 cffb300", "Consolas")
G.Add("Text", "x14 y369 w200 Background0e0e0e", "Önerilen Ayarlar")
G.SetFont("s7 c555555", "Consolas")
G.Add("Text", "x14 y383 w200 Background0e0e0e", "Hazır recoil profilleri")
G.Add("Text", "x290 y361 w1 h42 Background222222")
G.SetFont("s9 w700 cffb300", "Consolas")
presetBtn := G.Add("Text", "x291 y361 w109 h42 Background1a1000 Center +0x200", "⚙ ÖNERİ")
presetBtn.OnEvent("Click", (*) => OpenPresetGui())

; ── Footer (y=403) ──
G.Add("Text", "x0 y403 w400 h1 Background222222")
G.Add("Text", "x0 y404 w400 h28 Background0a0a0a")
G.SetFont("s8 w800 cFFFFFF", "Consolas")
global rgbLabel := G.Add("Text", "x14 y413 w100 Background0a0a0a", "berkaycimh")
G.SetFont("s7 c333333", "Consolas")
global verLabel := G.Add("Text", "x160 y414 w80 Background0a0a0a Center", "v" currentVersion)
G.SetFont("s7 c00ff88", "Consolas")
global ramLabel := G.Add("Text", "x280 y414 w100 Background0a0a0a Right", "RAM: --")
G.Show("w400 h432")

; Başlangıç animasyonu — yukarıdan aşağı kayarak gel
screenW := SysGet(0)
screenH := SysGet(1)
startX := (screenW - 400) // 2
startY := -432
targetY := (screenH - 432) // 2
G.Move(startX, startY)
G.Show("NoActivate")
loop {
    WinGetPos(&cx, &cy,,, G)
    if (cy >= targetY)
        break
    newY := cy + Round((targetY - cy) * 0.18 + 3)
    G.Move(startX, newY)
    Sleep(10)
}
G.Move(startX, targetY)

; Başlangıç
SetAmmo(activeAmmo)
toggleMacro.Value := "✘ PASİF"
toggleMacro.SetFont("cff3355")
toggleMacro.Opt("Background1a0008")
UpdateStatLabel()



; Sürüm kontrolü (GitHub'dan)
; SetTimer(CheckVersion, -2000) -- artık GUI'den önce çalışıyor

OnExit(SaveSettings)
SetTimer(GlowActive, 400)
SetTimer(UptimeTick, 1000)
SetTimer(UpdateRAM, 3000)
SetTimer(SysPulse, 50)

; Rastgele motivasyon yazısı
mottos := [
    "Chicken dinner yakın! 🍗",
    "Nişan al, tereddüt etme.",
    "Son halka, son kurşun.",
    "Recoil kontrol altında.",
    "Düşman görünce soğukkanlı ol.",
    "Her mermi sayılır.",
    "Hareket et, hayatta kal.",
    "Kafan soğuk, ellerin sabit.",
    "Bugün winner sensin.",
    "Spray'i kontrol et, maçı kazan."
]
if IsObject(motoLabel)
    motoLabel.Value := mottos[Random(1, mottos.Length)]

; ── Mini HUD Overlay ──
HUD := Gui("+AlwaysOnTop -Caption +ToolWindow -Border -DPIScale +E0x80000 +E0x20", "HUD")
HUD.BackColor := "0d0d14"
HUD.MarginX := 0
HUD.MarginY := 0
HUD.SetFont("s8 w700 cE2E2F0", "Segoe UI")
hudMacroTxt := HUD.Add("Text", "x6 y4 w80 Background0d0d14", "MACRO")
HUD.SetFont("s8 w700 cef4444", "Segoe UI")
hudStatus := HUD.Add("Text", "x52 y4 w50 Background0d0d14 Right", "OFF")
HUD.Add("Text", "x0 y18 w110 h1 Background1a1a28")
HUD.SetFont("s8 w600 c22c55e", "Segoe UI")
hudAmmo := HUD.Add("Text", "x6 y22 w50 Background0d0d14", "5.56")
HUD.SetFont("s8 c3a3a5a", "Segoe UI")
HUD.Add("Text", "x46 y22 w20 Background0d0d14", "►")
HUD.SetFont("s8 w700 cE2E2F0", "Segoe UI")
hudRecoil := HUD.Add("Text", "x60 y22 w44 Background0d0d14 Right", "0")

screenW := SysGet(0)
hudStartX := (hudX = -1) ? (screenW - 120) : hudX
HUD.Show("w110 h36 x" hudStartX " y" hudY " NoActivate")
WinSetTransparent(hudOpacity, HUD)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", HUD.Hwnd, "uint", 33, "int*", 2, "uint", 4)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", HUD.Hwnd, "uint", 34, "int*", 0x0d0d14, "uint", 4)

; Click-through: mouse olaylarını oyuna geçir
exStyle := DllCall("GetWindowLong", "ptr", HUD.Hwnd, "int", -20)
DllCall("SetWindowLong", "ptr", HUD.Hwnd, "int", -20, "int", exStyle | 0x80000 | 0x20)

; Sürükleme için sadece Ctrl basılıyken çalışsın
hudDrag := HUD.Add("Text", "x0 y0 w110 h36 BackgroundTrans")
hudDrag.OnEvent("Click", DragHUD)

; Boyut değişince içeriği yeniden yerleştir
HUD.OnEvent("Size", ResizeHUD)

HWND := G.Hwnd
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", HWND, "uint", 2,  "int*", 1,          "uint", 4)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", HWND, "uint", 33, "int*", 2,          "uint", 4)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", HWND, "uint", 34, "int*", 0x181111,   "uint", 4)

; ─── Hotkeys ───────────────────────────────────────────────────────────────

F1:: SetAmmoKey("5.56")
F2:: SetAmmoKey("7.62")
F3:: SetAmmoKey("9MM")
F4:: SetAmmoKey("BOMBA")
Delete:: DoToggleMacro()



Up::
+Up:: {
    global activeAmmo, recoilValues, macroOn
    if (!macroOn) {
        ShowLockedNotify()
        return
    }
    if (activeAmmo = "BOMBA")
        return
    cur := recoilValues[activeAmmo]
    if (cur < 100) {
        recoilValues[activeAmmo] := cur + 1
        UpdateRecoilDisplay()
        ShowRecoilNotify()
    }
}

Down::
+Down:: {
    global activeAmmo, recoilValues, macroOn
    if (!macroOn) {
        ShowLockedNotify()
        return
    }
    if (activeAmmo = "BOMBA")
        return
    cur := recoilValues[activeAmmo]
    if (cur > 0) {
        recoilValues[activeAmmo] := cur - 1
        UpdateRecoilDisplay()
        ShowRecoilNotify()
    }
}

~LButton:: {
    global macroOn, shooting
    if (!macroOn)
        return
    ; Sağ tık basılıysa (nişan almadan atma = bomba/sis) çalışma
    if GetKeyState("RButton")
        return
    ; Kısa gecikme — fırlatma animasyonunu atla
    Sleep(50)
    ; Hala sol tık basılıysa silah ateşi, devam et
    if !GetKeyState("LButton")
        return
    shooting := true
    SetTimer(ApplyRecoil, 10)
}

~LButton Up:: {
    global shooting
    shooting := false
    SetTimer(ApplyRecoil, 0)
}

; ─── Fonksiyonlar ──────────────────────────────────────────────────────────

ApplyRecoil() {
    global shooting, macroOn, activeAmmo, recoilValues
    global statTotal, stat556, stat762, stat9mm, statLabel
    try {
        if (!shooting || !macroOn)
            return
        ; Bomba/sis modunda recoil uygulama
        if (activeAmmo = "BOMBA")
            return
        val := recoilValues[activeAmmo]
        if (val > 0)
            DllCall("mouse_event", "uint", 0x0001, "int", 0, "int", val, "uint", 0, "uptr", 0)
        ; İstatistik say
        statTotal++
        if (activeAmmo = "5.56")
            stat556++
        if (activeAmmo = "7.62")
            stat762++
        if (activeAmmo = "9MM")
            stat9mm++
        ; Her 50 ateşte bir güncelle
        if (Mod(statTotal, 50) = 0)
            UpdateStatLabel()
    } catch {
    }
}

; ─── Otomatik Güncelleme ─── (splash kodu dosya başında çalışıyor)

CheckVersion() {
    global verLabel, currentVersion
    if IsObject(verLabel) {
        verLabel.SetFont("c00ff88")
        verLabel.Value := "✔ v" currentVersion
    }
}

UpdateStatLabel() {
    ; İstatistik label kaldırıldı
}

SetAmmoKey(ammo) {
    SetAmmo(ammo)
    colorMap := Map("5.56", "c22c55e", "7.62", "cf5c518", "9MM", "cff8c00", "BOMBA", "c6366f1")
    bgMap    := Map("5.56", "0d2b1a",  "7.62", "2b2200",  "9MM", "2b1800",  "BOMBA", "0d0d2b")
    recoilTxt := (ammo != "BOMBA") ? " — Recoil: " recoilValues[ammo] : ""
    labelMap := Map("5.56", "⬤ 5.56 Silahlar" recoilTxt, "7.62", "⬤ 7.62 Silahlar" recoilTxt, "9MM", "⬤ 9MM Pistol/SMG" recoilTxt, "BOMBA", "💣 BOMBA MODU")
    static ammoGui := ""
    if IsObject(ammoGui)
        ammoGui.Destroy()
    ammoGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "")
    ammoGui.BackColor := bgMap[ammo]
    ammoGui.SetFont("s8 w700 " . colorMap[ammo], "Segoe UI")
    ammoGui.Add("Text", "x8 y6 w180 Center", labelMap[ammo])
    screenW := SysGet(0)
    screenH := SysGet(1)
    ammoGui.Show("w196 h28 x" (screenW-196)//2 " y" Round(screenH*0.82) " NoActivate")
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", ammoGui.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    SetTimer(() => (IsObject(ammoGui) ? ammoGui.Destroy() : ""), -2500)
}

SetAmmo(ammo) {
    global activeAmmo, a556, a762, a9mm
    activeAmmo := ammo
    if !IsObject(a556)
        return
    a556.SetFont(ammo = "5.56" ? "c00ff88" : "c1a5c2e")
    a762.SetFont(ammo = "7.62" ? "cffcc00" : "c555500")
    a9mm.SetFont(ammo = "9MM"  ? "cff8800" : "c553300")
    a556.Opt("Background" . (ammo = "5.56" ? "0d1a12" : "141414"))
    a762.Opt("Background" . (ammo = "7.62" ? "1a1200" : "141414"))
    a9mm.Opt("Background" . (ammo = "9MM"  ? "1a0e00" : "141414"))
    if (ammo = "BOMBA") {
        a556.SetFont("c1a5c2e")
        a762.SetFont("c555500")
        a9mm.SetFont("c553300")
        a556.Opt("Background141414")
        a762.Opt("Background141414")
        a9mm.Opt("Background141414")
    }
    UpdateRecoilDisplay()
}

UpdateRecoilDisplay() {
    global activeAmmo, recoilValues, recoilNum, recoilLabel, progressBar
    global hudAmmo, hudRecoil
    if !IsObject(recoilLabel)
        return
    ; Bomba modunda display güncelleme
    if (activeAmmo = "BOMBA") {
        recoilLabel.SetFont("c6366f1")
        recoilLabel.Value := "BOMBA"
        recoilNum.SetFont("c6366f1")
        recoilNum.Value := 0
        progressBar.Opt("w0")
        if IsObject(hudAmmo) {
            hudAmmo.SetFont("c6366f1")
            hudAmmo.Value := "BOMBA"
            hudRecoil.Value := 0
        }
        return
    }
    colorMap := Map("5.56", "c22c55e", "7.62", "cf5c518", "9MM", "cff8c00")
    barColor := Map("5.56", "22c55e",  "7.62", "f5c518",  "9MM", "ff8c00")
    recoilLabel.SetFont(colorMap[activeAmmo])
    recoilLabel.Value := activeAmmo
    val := recoilValues[activeAmmo]
    recoilNum.SetFont("s22 w800 " . colorMap[activeAmmo])
    recoilNum.Value := val
    barW := Round(val * 370 / 100)
    progressBar.Opt("w" . barW . " Background" . barColor[activeAmmo])
    if IsObject(hudAmmo) {
        hudAmmo.SetFont(colorMap[activeAmmo])
        hudAmmo.Value := activeAmmo
        hudRecoil.Value := val
    }
    ; Otomatik kayıt
    AutoSave()
}

DoToggleMacro() {
    global macroOn, shooting, toggleMacro
    macroOn := !macroOn
    if (!macroOn) {
        shooting := false
        SetTimer(ApplyRecoil, 0)
    }
    toggleMacro.Value := macroOn ? "✔ AKTİF" : "✘ PASİF"
    toggleMacro.SetFont(macroOn ? "c00ff88" : "cff3355")
    toggleMacro.Opt("Background" . (macroOn ? "001a0a" : "1a0008"))
    UpdateStatus()
    static notifyGui := ""
    if IsObject(notifyGui)
        notifyGui.Destroy()
    notifyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "")
    notifyGui.BackColor := macroOn ? "0d2b1a" : "2b0d0d"
    notifyGui.SetFont("s8 w700 " . (macroOn ? "c22c55e" : "cef4444"), "Segoe UI")
    notifyGui.Add("Text", "x8 y6 w110 Center", macroOn ? "✔ MACRO AÇIK" : "✘ MACRO KAPALI")
    screenW := SysGet(0)
    screenH := SysGet(1)
    notifyGui.Show("w126 h28 x" (screenW-126)//2 " y" Round(screenH*0.82) " NoActivate")
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", notifyGui.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    SetTimer(() => (IsObject(notifyGui) ? notifyGui.Destroy() : ""), -2500)
}

UpdateStatus() {
    global macroOn, statusDot, hudStatus
    statusDot.SetFont(macroOn ? "c00ff88" : "cff3355")
    statusDot.Value := macroOn ? "● ONLINE" : "● OFFLINE"
    if IsObject(hudStatus) {
        hudStatus.SetFont(macroOn ? "c00ff88" : "cff3355")
        hudStatus.Value := macroOn ? "ON" : "OFF"
    }
}

ShowLockedNotify() {
    static lockGui := ""
    try {
        if IsObject(lockGui)
            lockGui.Destroy()
    }
    try {
        lockGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "")
        lockGui.BackColor := "2b0d0d"
        lockGui.SetFont("s8 w700 cef4444", "Segoe UI")
        lockGui.Add("Text", "x8 y6 w150 Center", "✘ MACRO KAPALI")
        screenW := SysGet(0)
        screenH := SysGet(1)
        lockGui.Show("w166 h28 x" (screenW-166)//2 " y" Round(screenH*0.82) " NoActivate")
        DllCall("dwmapi\DwmSetWindowAttribute", "ptr", lockGui.Hwnd, "uint", 33, "int*", 2, "uint", 4)
        SetTimer(() => (IsObject(lockGui) ? lockGui.Destroy() : ""), -1500)
    }
}

ShowRecoilNotify() {
    global activeAmmo, recoilValues
    colorMap := Map("5.56", "c22c55e", "7.62", "cf5c518", "9MM", "cff8c00")
    bgMap    := Map("5.56", "0d2b1a",  "7.62", "2b2200",  "9MM", "2b1800")
    val := recoilValues[activeAmmo]
    static recoilGui := ""
    try {
        if IsObject(recoilGui)
            recoilGui.Destroy()
    }
    try {
        recoilGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "")
        recoilGui.BackColor := bgMap[activeAmmo]
        recoilGui.SetFont("s8 w700 " . colorMap[activeAmmo], "Segoe UI")
        recoilGui.Add("Text", "x8 y6 w150 Center", activeAmmo " — Recoil: " val)
        screenW := SysGet(0)
        screenH := SysGet(1)
        recoilGui.Show("w166 h28 x" (screenW-166)//2 " y" Round(screenH*0.82) " NoActivate")
        DllCall("dwmapi\DwmSetWindowAttribute", "ptr", recoilGui.Hwnd, "uint", 33, "int*", 2, "uint", 4)
        SetTimer(() => (IsObject(recoilGui) ? recoilGui.Destroy() : ""), -1500)
    }
}

ToggleHUD() {
    global HUD, hudVisible, hudToggleBtn
    hudVisible := !hudVisible
    if (hudVisible) {
        HUD.Show("NoActivate")
        hudToggleBtn.Value := "AÇIK"
        hudToggleBtn.SetFont("c00ff88")
        hudToggleBtn.Opt("Background001a0a")
    } else {
        HUD.Hide()
        hudToggleBtn.Value := "KAPALI"
        hudToggleBtn.SetFont("cff3355")
        hudToggleBtn.Opt("Background1a0008")
    }
}

AutoSave() {
    ; 500ms debounce — çok sık disk yazımını önle
    SetTimer(DoAutoSave, -500)
}

DoAutoSave() {
    global recoilValues, activeAmmo, statTotal, stat556, stat762, stat9mm, HUD, saveStatus
    iniFile := A_ScriptDir "\settings.ini"
    IniWrite(recoilValues["5.56"], iniFile, "Recoil",   "556")
    IniWrite(recoilValues["7.62"], iniFile, "Recoil",   "762")
    IniWrite(recoilValues["9MM"],  iniFile, "Recoil",   "9mm")
    IniWrite(activeAmmo,           iniFile, "Settings", "LastAmmo")
    IniWrite(statTotal,            iniFile, "Stats",    "Total")
    IniWrite(stat556,              iniFile, "Stats",    "556")
    IniWrite(stat762,              iniFile, "Stats",    "762")
    IniWrite(stat9mm,              iniFile, "Stats",    "9mm")
    try {
        WinGetPos(&hx, &hy,,, HUD)
        IniWrite(hx, iniFile, "HUD", "X")
        IniWrite(hy, iniFile, "HUD", "Y")
        IniWrite(hudOpacity, iniFile, "HUD", "Opacity")
    }
    if IsObject(saveStatus) {
        saveStatus.SetFont("c3a3a5a")
        saveStatus.Value := "✔ otomatik"
        SetTimer(() => (IsObject(saveStatus) ? saveStatus.Value := "" : ""), -1500)
    }
}

DoSave() {
    global recoilValues, activeAmmo, saveStatus, HUD
    global statTotal, stat556, stat762, stat9mm
    iniFile := A_ScriptDir "\settings.ini"
    IniWrite(recoilValues["5.56"], iniFile, "Recoil",   "556")
    IniWrite(recoilValues["7.62"], iniFile, "Recoil",   "762")
    IniWrite(recoilValues["9MM"],  iniFile, "Recoil",   "9mm")
    IniWrite(activeAmmo,           iniFile, "Settings", "LastAmmo")
    IniWrite(statTotal,            iniFile, "Stats",    "Total")
    IniWrite(stat556,              iniFile, "Stats",    "556")
    IniWrite(stat762,              iniFile, "Stats",    "762")
    IniWrite(stat9mm,              iniFile, "Stats",    "9mm")
    WinGetPos(&hx, &hy,,, HUD)
    IniWrite(hx, iniFile, "HUD", "X")
    IniWrite(hy, iniFile, "HUD", "Y")
    IniWrite(hudOpacity, iniFile, "HUD", "Opacity")
    saveStatus.SetFont("c22c55e")
    saveStatus.Value := "✔ Kaydedildi"
    SetTimer(() => (saveStatus.Value := ""), -2000)
}

SaveSettings(reason, code) {
    global recoilValues, activeAmmo, HUD, hudOpacity
    global statTotal, stat556, stat762, stat9mm
    iniFile := A_ScriptDir "\settings.ini"
    IniWrite(recoilValues["5.56"], iniFile, "Recoil",   "556")
    IniWrite(recoilValues["7.62"], iniFile, "Recoil",   "762")
    IniWrite(recoilValues["9MM"],  iniFile, "Recoil",   "9mm")
    IniWrite(activeAmmo,           iniFile, "Settings", "LastAmmo")
    IniWrite(statTotal,            iniFile, "Stats",    "Total")
    IniWrite(stat556,              iniFile, "Stats",    "556")
    IniWrite(stat762,              iniFile, "Stats",    "762")
    IniWrite(stat9mm,              iniFile, "Stats",    "9mm")
    WinGetPos(&hx, &hy,,, HUD)
    IniWrite(hx, iniFile, "HUD", "X")
    IniWrite(hy, iniFile, "HUD", "Y")
    IniWrite(hudOpacity, iniFile, "HUD", "Opacity")
}

UpdateRAM() {
    global ramLabel
    if !IsObject(ramLabel)
        return
    try {
        pid := DllCall("GetCurrentProcessId")
        hProc := DllCall("OpenProcess", "uint", 0x0400, "int", 0, "uint", pid, "ptr")
        memInfo := Buffer(40, 0)
        DllCall("psapi\GetProcessMemoryInfo", "ptr", hProc, "ptr", memInfo, "uint", 40)
        DllCall("CloseHandle", "ptr", hProc)
        workingSet := NumGet(memInfo, 16, "uptr")
        mb := Round(workingSet / 1048576, 1)
        ramLabel.SetFont(mb > 50 ? "cff3355" : "c00ff88")
        ramLabel.Value := "RAM: " mb " MB"
    } catch {
        ramLabel.SetFont("c555555")
        ramLabel.Value := "RAM: --"
    }
}

UptimeTick() {
    global uptimeSeconds, uptimeLabel, G
    uptimeSeconds++
    mins := uptimeSeconds // 60
    secs := Mod(uptimeSeconds, 60)
    if IsObject(uptimeLabel)
        uptimeLabel.Value := Format("{:02d}:{:02d}", mins, secs)
    ; Çizgiyi yeniden çiz
    hdc := DllCall("GetDC", "ptr", G.Hwnd, "ptr")
    hPen := DllCall("CreatePen", "int", 0, "int", 1, "uint", 0x222222, "ptr")
    DllCall("SelectObject", "ptr", hdc, "ptr", hPen)
    DllCall("MoveToEx", "ptr", hdc, "int", 372, "int", 0, "ptr", 0)
    DllCall("LineTo",   "ptr", hdc, "int", 372, "int", 44)
    DllCall("MoveToEx", "ptr", hdc, "int", 334, "int", 0, "ptr", 0)
    DllCall("LineTo",   "ptr", hdc, "int", 334, "int", 44)
    DllCall("MoveToEx", "ptr", hdc, "int", 260, "int", 0, "ptr", 0)
    DllCall("LineTo",   "ptr", hdc, "int", 260, "int", 44)
    DllCall("DeleteObject", "ptr", hPen)
    DllCall("ReleaseDC", "ptr", G.Hwnd, "ptr", hdc)
}

RGBCycle() {
    global rgbHue, rgbLabel
    try {
        rgbHue := Mod(rgbHue + 2, 360)
    h := rgbHue / 60
    i := Floor(h)
    f := h - i
    q := Round(255 * (1 - f))
    t := Round(255 * f)
    v := 255
    r := 0
    g := 0
    b := 0
    if (i = 0) {
        r := v
        g := t
        b := 0
    }
    if (i = 1) {
        r := q
        g := v
        b := 0
    }
    if (i = 2) {
        r := 0
        g := v
        b := t
    }
    if (i = 3) {
        r := 0
        g := q
        b := v
    }
    if (i = 4) {
        r := t
        g := 0
        b := v
    }
    if (i = 5) {
        r := v
        g := 0
        b := q
    }
    rgbLabel.SetFont("c" . Format("{:02X}{:02X}{:02X}", r, g, b))
    } catch {
    }
}

GlowActive() {
    global activeAmmo, a556, a762, a9mm, glowState
    glowState := !glowState
    brightMap := Map("5.56", "0d2218", "7.62", "1a1800", "9MM", "1a0e00")
    dimMap    := Map("5.56", "141414", "7.62", "141414", "9MM", "141414")
    if (activeAmmo = "5.56")
        a556.Opt("Background" . (glowState ? brightMap["5.56"] : dimMap["5.56"]))
    if (activeAmmo = "7.62")
        a762.Opt("Background" . (glowState ? brightMap["7.62"] : dimMap["7.62"]))
    if (activeAmmo = "9MM")
        a9mm.Opt("Background" . (glowState ? brightMap["9MM"] : dimMap["9MM"]))
}

SysPulse() {
    global sysBarStrip, sysPulseState
    sysPulseState := Mod(sysPulseState + 1, 20)
    step := sysPulseState < 10 ? sysPulseState : 20 - sysPulseState
    g := Round(step * 25.5)
    r := 0
    b := Round(step * 13.6)
    hex := Format("{:02X}{:02X}{:02X}", r, g, b)
    sysBarStrip.Opt("Background" . hex)
}

ResizeHUD(thisGui, minMax, w, h) {
    global hudMacroTxt, hudStatus, hudAmmo, hudRecoil, hudDrag
    if (minMax = -1)
        return
    ; Font boyutunu pencere genişliğine göre ölçekle
    fs := Max(7, Round(w / 14))
    hudMacroTxt.SetFont("s" fs " w700 cE2E2F0")
    hudStatus.SetFont("s" fs " w700")
    hudAmmo.SetFont("s" fs " w600")
    hudRecoil.SetFont("s" fs " w700 cE2E2F0")
    ; Kontrolleri yeniden boyutlandır
    half := Round(w / 2)
    hudMacroTxt.Move(6, Round(h*0.1), half, Round(h*0.45))
    hudStatus.Move(half, Round(h*0.1), half-6, Round(h*0.45))
    hudAmmo.Move(6, Round(h*0.55), half, Round(h*0.4))
    hudRecoil.Move(half, Round(h*0.55), half-6, Round(h*0.4))
    hudDrag.Move(0, 0, w, h)
}

DragHUD(*) {
    ; Click-through modunda sürükleme devre dışı
    ; HUD konumu settings.ini'den ayarlanabilir
}

MoveHUD(dx, dy) {
    global HUD, hudPosLabel
    WinGetPos(&hx, &hy,,, HUD)
    newX := hx + dx
    newY := hy + dy
    HUD.Move(newX, newY)
    if IsObject(hudPosLabel)
        hudPosLabel.Value := "X:" newX " Y:" newY
    AutoSave()
}

DragWin(*) {
    PostMessage(0xA1, 2, 0, G)
}

; ─── Önerilen Ayarlar Popup ────────────────────────────────────────────────

OpenPresetGui() {
    PG := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" . A_ScriptHwnd, "")
    PG.BackColor := "0e0e0e"
    PG.MarginX := 0
    PG.MarginY := 0

    ; ── Popup Titlebar ──
    PG.Add("Text", "x0 y0 w3 h36 Backgroundffb300")
    PG.Add("Text", "x3 y0 w281 h36 Background0a0a0a")
    PG.SetFont("s9 w700 cffb300", "Consolas")
    PG.Add("Text", "x12 y0 w240 h36 Background0a0a0a +0x200", "⚙ ÖNERİLEN AYARLAR")
    PG.Add("Text", "x284 y0 w1 h36 Background222222")
    PG.SetFont("s12 w700 c555555", "Consolas")
    pgClose := PG.Add("Text", "x285 y0 w35 h36 Background0a0a0a Center +0x200", "×")
    pgClose.OnEvent("Click", (*) => PG.Destroy())
    PG.Add("Text", "x0 y36 w320 h1 Background222222")

    ; ── Açıklama ──
    PG.SetFont("s10 w600 cFFFFFF", "Consolas")
    PG.Add("Text", "x10 y44 w300 Background0e0e0e", "Oyun içerisinde bulunan hassasiyet ayarları")
    PG.SetFont("s10 w700 cff3355", "Consolas")
    PG.Add("Text", "x10 y62 w300 Background0e0e0e", "önerilir !")

    ; ── Bilgi Kartları ──

    ; Genel hassasiyet
    PG.Add("Text", "x8 y84 w304 h36 Background141414")
    PG.SetFont("s8 w600 cFFFFFF", "Consolas")
    PG.Add("Text", "x16 y88 w180 Background141414", "Genel hassasiyet")
    PG.SetFont("s11 w800 cFF0000", "Consolas")
    PG.Add("Text", "x240 y85 w64 Background141414 Right", "48")

    ; Dikey hassasiyet çarpanı
    PG.Add("Text", "x8 y122 w304 h36 Background141414")
    PG.SetFont("s8 w600 cFFFFFF", "Consolas")
    PG.Add("Text", "x16 y126 w180 Background141414", "Dikey hassasiyet çarpanı")
    PG.SetFont("s11 w800 cFF0000", "Consolas")
    PG.Add("Text", "x240 y123 w64 Background141414 Right", "1.45")

    PG.Add("Text", "x8 y160 w304 h1 Background222222")

    ; Nişan alma hassasiyeti
    PG.Add("Text", "x8 y163 w304 h36 Background141414")
    PG.SetFont("s8 w600 cFFFFFF", "Consolas")
    PG.Add("Text", "x16 y167 w180 Background141414", "Nişan alma hassasiyeti")
    PG.SetFont("s11 w800 cFF0000", "Consolas")
    PG.Add("Text", "x240 y164 w64 Background141414 Right", "57")

    ; Yakın bakış hassasiyeti
    PG.Add("Text", "x8 y201 w304 h36 Background141414")
    PG.SetFont("s8 w600 cFFFFFF", "Consolas")
    PG.Add("Text", "x16 y205 w180 Background141414", "Yakın bakış hassasiyeti")
    PG.SetFont("s11 w800 cFF0000", "Consolas")
    PG.Add("Text", "x240 y202 w64 Background141414 Right", "48")

    ; Dürbün başlığı
    PG.Add("Text", "x8 y239 w304 h1 Background333333")
    PG.Add("Text", "x8 y242 w304 h20 Background0a0a0a")
    PG.SetFont("s7 w700 cFFFFFF", "Consolas")
    PG.Add("Text", "x8 y245 w304 Background0a0a0a Center", "— DÜRBÜN —")

    ; Dürbün değerleri — 2 sütun grid
    scopes := [["2x","50"],["3x","48"],["4x","61"],["6x","52"],["8x","43"],["15x","42"]]
    rowY := 264
    col := 0
    for i, s in scopes {
        xPos := (col = 0) ? 8 : 160
        PG.Add("Text", "x" xPos " y" rowY " w148 h30 Background141414")
        PG.SetFont("s8 w600 cFFFFFF", "Consolas")
        PG.Add("Text", "x" (xPos+8) " y" (rowY+4) " w60 Background141414", s[1])
        PG.SetFont("s11 w800 cFF0000", "Consolas")
        PG.Add("Text", "x" (xPos+80) " y" (rowY+1) " w60 Background141414 Right", s[2])
        col++
        if (col = 2) {
            col := 0
            rowY += 32
        }
    }

    totalH := rowY + 12
    screenW := SysGet(0)
    screenH := SysGet(1)
    PG.Show("w320 h" totalH " x" (screenW-320)//2 " y" (screenH-totalH)//2)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", PG.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", PG.Hwnd, "uint", 34, "int*", 0x0e0e0e, "uint", 4)
}

DoApplyPreset() {
    global recoilValues
    recoilValues["5.56"] := Min(100, Round(recoilValues["5.56"] * 1.45))
    recoilValues["7.62"] := Min(100, Round(recoilValues["7.62"] * 1.45))
    recoilValues["9MM"]  := Min(100, Round(recoilValues["9MM"]  * 1.45))
    UpdateRecoilDisplay()
    AutoSave()

    static applyGui := ""
    if IsObject(applyGui)
        applyGui.Destroy()
    applyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "")
    applyGui.BackColor := "1a1200"
    applyGui.SetFont("s8 w700 cffb300", "Segoe UI")
    applyGui.Add("Text", "x8 y6 w220 Center", "✔ Çarpan uygulandı  ×1.45")
    screenW := SysGet(0)
    screenH := SysGet(1)
    applyGui.Show("w236 h28 x" (screenW-236)//2 " y" Round(screenH*0.82) " NoActivate")
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", applyGui.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    SetTimer(() => (IsObject(applyGui) ? applyGui.Destroy() : ""), -2500)
}
