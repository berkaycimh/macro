#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn VarUnset, Off
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
global statusText  := ""
global saveStatus  := ""
global a556 := "", a762 := "", a9mm := "", aBomba := ""
global a556Top := "", a762Top := "", a9mmTop := "", aBombaTop := ""
global recoilValues := Map("5.56", 0, "7.62", 0, "9MM", 0)
global sysBadge := ""
global sysPulseState := 0
global sysBarStrip := ""
global hudAmmo := "", hudRecoil := "", hudStatus := "", hudAmmoSub := "", hudAccentBar := "", hudAccentFade := "", hudAmmoIcon := "", hudRecoilBar := "", hudDotLbl := "", hudLeanStatus := ""
global hudVisible := true
global hudPosLabel := ""
global leanState := 0  ; 0=sol, 1=sağ
global leanOn := false  ; her açılışta kapalı
global leanKeyLeft := "q"    ; sol eğilme tuşu
global leanKeyRight := "e"   ; sağ eğilme tuşu
global bombaModeKey := "LShift"  ; bomba modu aktif tuşu — basılıyken F4 çalışır
global leanSpeed := 450       ; ms — eğilme aralığı
global leanDelay := 0         ; ms — ateş başlayınca kaç ms sonra devreye girsin
global leanToggleKey := ""    ; açma/kapama hotkey

; İstatistik değişkenleri
global statTotal := 0
global stat556 := 0, stat762 := 0, stat9mm := 0
global uptimeLabel := ""
global uptimeSeconds := 0
global ramLabel  := ""

; ─── Otomatik Güncelleme ───────────────────────────────────────────────────
global updateApiUrl := "https://api.github.com/repos/berkaycimh/macro/releases/latest"
global updateExeUrl := "https://github.com/berkaycimh/macro/releases/latest/download/PSP.exe"

; Versiyon — bu değer her zaman derlenen exe ile eşleşmeli
global currentVersion := "3.1"

; ─── Lisans Kontrolü ────────────────────────────────────────────────────────
global licenseUnlimited := "TR-7363-0B28-B721"
global license30Day := "TR-8357-73X2-0009"
global licenseAdmin := "TR-4BV4832-32BV04"
iniFile := A_ScriptDir "\settings.ini"
savedLicense := IniRead(iniFile, "License", "Key", "")
licenseType := IniRead(iniFile, "License", "Type", "")
licenseDate := IniRead(iniFile, "License", "Date", "")

; 30 günlük süre kontrolü
licenseValid := false
if (savedLicense = licenseUnlimited) {
    licenseValid := true
} else if (savedLicense = licenseAdmin) {
    licenseValid := true
} else if (savedLicense = license30Day && licenseDate != "") {
    ; Tarih farkı hesapla
    startDate := licenseDate
    now := A_Now
    daysDiff := DateDiff(now, startDate, "Days")
    if (daysDiff <= 30)
        licenseValid := true
}

if (!licenseValid) {
    ; Animasyonlu lisans ekranı — modern tasarım
    LicGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    LicGui.BackColor := "0a0a0a"
    LicGui.MarginX := 0
    LicGui.MarginY := 0

    ; Üst accent çizgisi
    LicGui.Add("Text", "x0 y0 w380 h3 Background00ff88")

    ; Header — online dot + başlık + badge + kapatma
    LicGui.Add("Text", "x0 y3 w380 h40 Background0a0a0a")
    LicGui.SetFont("s8 c00ff88", "Consolas")
    global licDot := LicGui.Add("Text", "x16 y15 w10 Background0a0a0a", "●")
    LicGui.SetFont("s11 w800 cFFFFFF", "Consolas")
    LicGui.Add("Text", "x30 y12 w160 Background0a0a0a", "LastCircle")
    LicGui.SetFont("s7 w700 c00ff88", "Consolas")
    LicGui.Add("Text", "x120 y14 w60 h18 Background001a0a Center +0x200", "SECURE")
    ; X kapatma butonu — kırmızı
    LicGui.SetFont("s12 w700 cff3355", "Consolas")
    global licCloseBtn := LicGui.Add("Text", "x350 y3 w27 h40 Background0a0a0a Center +0x200", "×")
    licCloseBtn.OnEvent("Click", (*) => ExitApp())

    ; Ayırıcı
    LicGui.Add("Text", "x0 y43 w380 h1 Background1a1a1a")
    ; Sürükleme alanı — header üzerinde
    licDragArea := LicGui.Add("Text", "x0 y3 w340 h40 BackgroundTrans")
    licDragArea.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0,, LicGui))

    ; Subtitle
    LicGui.SetFont("s8 w600 c00ff88", "Consolas")
    LicGui.Add("Text", "x0 y54 w380 Background0a0a0a Center", "LİSANS AKTİVASYONU")

    ; Açıklama
    LicGui.SetFont("s8 c555555", "Consolas")
    LicGui.Add("Text", "x0 y74 w380 Background0a0a0a Center", "Devam etmek için lisans anahtarınızı girin")

    ; Input kutusu — koyu tema, kenarlıksız
    LicGui.SetFont("s11 w700 cFFFFFF", "Consolas")
    global licInput := LicGui.Add("Edit", "x30 y100 w320 h32 Background0e0e0e Center -E0x200", "")

    ; Hata mesajı
    LicGui.SetFont("s8 w600 cff3355", "Consolas")
    global licError := LicGui.Add("Text", "x0 y140 w380 Background0a0a0a Center", "")

    ; Aktive et butonu
    LicGui.SetFont("s10 w700 c00ff88", "Consolas")
    licActivateBtn := LicGui.Add("Text", "x30 y164 w320 h38 Background001a0a Center +0x200", "AKTİVE ET")
    licActivateBtn.OnEvent("Click", (*) => CheckLicense())

    ; Footer
    LicGui.Add("Text", "x0 y214 w380 h1 Background1a1a1a")
    LicGui.SetFont("s7 cFFFFFF", "Consolas")
    LicGui.Add("Text", "x16 y220 w120 Background0a0a0a", "berkaycimh")
    LicGui.Add("Text", "x220 y220 w140 Background0a0a0a Right", "Lisans gereklidir")

    ; Ekranı ortala ve animasyonlu göster
    screenW := SysGet(0)
    screenH := SysGet(1)
    startY := -240
    targetY := (screenH - 240) // 2
    startX := (screenW - 380) // 2
    LicGui.Show("w380 h240 x" startX " y" startY)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", LicGui.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", LicGui.Hwnd, "uint", 34, "int*", 0x0a0a0a, "uint", 4)

    ; Kayma animasyonu
    loop {
        WinGetPos(, &cy,,, LicGui)
        if (cy >= targetY)
            break
        newY := cy + Round((targetY - cy) * 0.18 + 2)
        LicGui.Move(startX, newY)
        Sleep(10)
    }
    LicGui.Move(startX, targetY)

    ; Online dot yanıp sönme
    global licDotState := 0
    SetTimer(LicDotBlink, 750)
    LicDotBlink() {
        global licDot, licDotState
        if !IsObject(licDot)
            return
        licDotState := !licDotState
        licDot.SetFont(licDotState ? "s8 c00ff88" : "s8 c004422")
    }

    ; Lisans kontrol fonksiyonu
    CheckLicense() {
        global licInput, licError, licenseUnlimited, license30Day, LicGui
        local adminKey := "TR-ADM28-34583FB"
        entered := Trim(licInput.Value)
        if (entered = licenseUnlimited) {
            licError.SetFont("c00ff88")
            licError.Value := "✔ Lisans doğrulandı!"
            Sleep(600)
            iniFile := A_ScriptDir "\settings.ini"
            IniWrite(entered, iniFile, "License", "Key")
            IniWrite("unlimited", iniFile, "License", "Type")
            SetTimer(LicDotBlink, 0)
            global licSuccessMsg := "🎉 Sınırsız key aktif edildi!"
            LicGui.Destroy()
        } else if (entered = adminKey) {
            licError.SetFont("c00ff88")
            licError.Value := "✔ Kurucu lisansı doğrulandı!"
            Sleep(600)
            iniFile := A_ScriptDir "\settings.ini"
            IniWrite(entered, iniFile, "License", "Key")
            IniWrite("admin", iniFile, "License", "Type")
            SetTimer(LicDotBlink, 0)
            global licSuccessMsg := "👑 Kurucu lisansı aktif edildi!"
            LicGui.Destroy()
        } else if (entered = license30Day) {
            ; 30 günlük key
            licError.SetFont("c00ff88")
            licError.Value := "✔ Lisans doğrulandı!"
            Sleep(600)
            iniFile := A_ScriptDir "\settings.ini"
            IniWrite(entered, iniFile, "License", "Key")
            IniWrite("30day", iniFile, "License", "Type")
            IniWrite(A_Now, iniFile, "License", "Date")
            SetTimer(LicDotBlink, 0)
            global licSuccessMsg := "🎉 30 günlük key aktif edildi!"
            LicGui.Destroy()
        } else {
            ; Hata + titreme animasyonu
            licError.Value := "✘ Geçersiz lisans anahtarı!"
            WinGetPos(&gx, &gy,,, LicGui)
            loop 6 {
                offset := Mod(A_Index, 2) = 0 ? 5 : -5
                LicGui.Move(gx + offset, gy)
                Sleep(40)
            }
            LicGui.Move(gx, gy)
        }
    }

    ; Input değişince hatayı temizle
    licInput.OnEvent("Change", (*) => licError.Value := "")
    licInput.OnEvent("Focus", (*) => "")

    ; Placeholder — Windows EM_SETCUEBANNER
    DllCall("SendMessage", "ptr", licInput.Hwnd, "uint", 0x1501, "int", 1, "str", "XX-XXXX-XXXX-XXXX")

    ; Pencere kapanırsa çık
    LicGui.OnEvent("Close", (*) => ExitApp())

    ; Lisans girilene kadar bekle
    global licSuccessMsg := ""
    licHwnd := LicGui.Hwnd
    while WinExist("ahk_id " licHwnd) {
        Sleep(100)
    }
    SetTimer(LicDotBlink, 0)

    ; Başarı ekranını göster
    if (licSuccessMsg != "")
        ShowLicenseSuccess(licSuccessMsg)

    ; Başarı ekranı — konfetili
    ShowLicenseSuccess(msg) {
        SG := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
        SG.BackColor := "0a0a0a"
        SG.MarginX := 0
        SG.MarginY := 0

        ; Üst accent
        SG.Add("Text", "x0 y0 w380 h3 Background00ff88")
        SG.Add("Text", "x0 y3 w380 h30 Background0a0a0a")

        ; Konfeti emojileri
        SG.SetFont("s16", "Segoe UI Emoji")
        SG.Add("Text", "x20 y40 w40 Background0a0a0a", "🎊")
        SG.Add("Text", "x320 y40 w40 Background0a0a0a", "🎊")
        SG.Add("Text", "x60 y20 w40 Background0a0a0a", "🎉")
        SG.Add("Text", "x280 y20 w40 Background0a0a0a", "🎉")

        ; Başarı mesajı
        SG.SetFont("s11 w800 c00ff88", "Consolas")
        SG.Add("Text", "x0 y70 w380 Background0a0a0a Center", msg)

        ; Alt açıklama
        SG.SetFont("s8 c888888", "Consolas")
        SG.Add("Text", "x0 y96 w380 Background0a0a0a Center", "Macro kullanıma hazır")

        ; Devam et butonu
        SG.SetFont("s10 w700 c00ff88", "Consolas")
        sgBtn := SG.Add("Text", "x30 y124 w320 h38 Background001a0a Center +0x200", "Devam Et!")
        sgBtn.OnEvent("Click", (*) => SG.Destroy())

        ; Alt çizgi
        SG.Add("Text", "x0 y174 w380 h1 Background1a1a1a")
        SG.SetFont("s7 cFFFFFF", "Consolas")
        SG.Add("Text", "x0 y180 w380 Background0a0a0a Center", "LastCircle — Başarıyla aktif")

        screenW := SysGet(0)
        screenH := SysGet(1)
        SG.Show("w380 h200 x" (screenW-380)//2 " y" (screenH-200)//2)
        DllCall("dwmapi\DwmSetWindowAttribute", "ptr", SG.Hwnd, "uint", 33, "int*", 2, "uint", 4)
        DllCall("dwmapi\DwmSetWindowAttribute", "ptr", SG.Hwnd, "uint", 34, "int*", 0x0a0a0a, "uint", 4)

        ; Devam et butonuna basılana kadar bekle
        sgHwnd := SG.Hwnd
        while WinExist("ahk_id " sgHwnd) {
            Sleep(100)
        }
    }
}

; ─── Ayarları Yükle ────────────────────────────────────────────────────────
iniFile := A_ScriptDir "\settings.ini"
if FileExist(iniFile) {
    recoilValues["5.56"] := IniRead(iniFile, "Recoil", "556", 0)
    recoilValues["7.62"] := IniRead(iniFile, "Recoil", "762", 0)
    recoilValues["9MM"]  := IniRead(iniFile, "Recoil", "9mm", 0)
    activeAmmo           := IniRead(iniFile, "Settings", "LastAmmo", "5.56")
    bombaModeKey         := IniRead(iniFile, "Settings", "BombaModeKey", "LShift")
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
splashGui.Add("Text", "x0 y12 w300 Background0e0e0e Center", "LastCircle")
splashGui.SetFont("s8 w600 c00ff88", "Consolas")
splashGui.Add("Text", "x0 y32 w300 Background0e0e0e Center", "Güncelleme kontrol ediliyor...")
splashGui.SetFont("s7 c555555", "Consolas")
global splashStatus := splashGui.Add("Text", "x0 y50 w300 Background0e0e0e Center", "GitHub bağlantısı kuruluyor...")
; Loading bar
splashGui.Add("Text", "x20 y66 w260 h3 Background1a1a1a")
global splashBar := splashGui.Add("Text", "x20 y66 w0 h3 Background00ff88")
splashGui.Add("Text", "x0 y74 w300 h1 Background1a1a1a")
splashGui.SetFont("s7 c333333", "Consolas")
splashGui.Add("Text", "x0 y78 w300 h18 Background0a0a0a Center", "berkaycimh  •  v" currentVersion)
screenW := SysGet(0)
screenH := SysGet(1)
splashGui.Show("w300 h98 x" (screenW-300)//2 " y" (screenH-98)//2)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", splashGui.Hwnd, "uint", 33, "int*", 2, "uint", 4)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", splashGui.Hwnd, "uint", 34, "int*", 0x0e0e0e, "uint", 4)

; Loading bar animasyonu
loop 20 {
    splashBar.Opt("w" Round(A_Index * 13))
    Sleep(50)
}

splashStatus.Value := "Sunucuya bağlanılıyor..."
loop 20 {
    splashBar.Opt("w" Round(260 * (20 + A_Index) / 40))
    Sleep(30)
}

; Güncelleme flag kontrolü — döngüyü önle
if FileExist(A_ScriptDir "\updated.flag") {
    flagVer := FileRead(A_ScriptDir "\updated.flag")
    FileDelete(A_ScriptDir "\updated.flag")
    splashStatus.SetFont("c00ff88")
    splashStatus.Value := "✔ Güncellendi — v" flagVer
    Sleep(1500)
    splashGui.Destroy()
    goto SkipUpdate
}

; updateApiUrl boşsa güncelleme kontrolünü atla
if (updateApiUrl = "") {
    splashStatus.SetFont("c00ff88")
    splashStatus.Value := "✔ Güncel — v" currentVersion
    Sleep(800)
    splashGui.Destroy()
    goto SkipUpdate
}

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

        ; Changelog body'sini parse et
        changelogBody := ""
        if RegExMatch(apiResponse, '"body"\s*:\s*"([^"]*)"', &bm)
            changelogBody := StrReplace(bm[1], "\r\n", "`n")
        if RegExMatch(apiResponse, '"body"\s*:\s*null', )
            changelogBody := ""

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
            ; Flag dosyasına yeni versiyonu yaz — döngüyü önle
            FileAppend(latestVer, A_ScriptDir "\updated.flag")
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
SkipUpdate:
; ─── GUI ───────────────────────────────────────────────────────────────────
G := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
G.BackColor := "111114"
G.MarginX := 0
G.MarginY := 0

; ── Üst mor accent çizgisi (3px) ──
G.Add("Text", "x0 y0 w300 h3 Background6366f1")

; ── Header (y=3, h=42) ──
G.Add("Text", "x0 y3 w300 h42 Background111114")
G.SetFont("s11 w700 ce2e8f0", "Segoe UI")
G.Add("Text", "x14 y12 w46 Background111114", "Last")
G.SetFont("s11 w700 c6366f1", "Segoe UI")
G.Add("Text", "x58 y12 w60 Background111114", "Circle")
G.SetFont("s7 w600 c6366f1", "Segoe UI")
G.Add("Text", "x120 y16 w30 Background0d0d1a", "v" currentVersion)
G.SetFont("s7 w700 c22c55e", "Segoe UI")
global changelogBtn := G.Add("Text", "x154 y16 w66 h12 Background111114 Center +0x200", "Güncellemeler")
changelogBtn.OnEvent("Click", (*) => ShowChangelog())
G.SetFont("s9 c475569", "Segoe UI")
minBtn := G.Add("Text", "x232 y12 w28 h22 Background111114 Center +0x200", "─")
minBtn.OnEvent("Click", (*) => G.Hide())
G.SetFont("s9 cef4444", "Segoe UI")
closeBtn := G.Add("Text", "x262 y12 w28 h22 Background111114 Center +0x200", "✕")
closeBtn.OnEvent("Click", (*) => ExitApp())

; Tray menüsü
A_TrayMenu.Add("Göster", (*) => G.Show())
A_TrayMenu.Add("Lisans Bilgisi", (*) => ShowLicenseInfo())
A_TrayMenu.Add("Çıkış", (*) => ExitApp())
A_TrayMenu.Default := "Göster"

; X hover efekti
global closeBtnHover := false
OnMessage(0x200, WM_MOUSEMOVE_Handler)
WM_MOUSEMOVE_Handler(wParam, lParam, msg, hwnd) {
    global closeBtn, closeBtnHover
    if (hwnd = closeBtn.Hwnd) {
        if (!closeBtnHover) {
            closeBtnHover := true
            closeBtn.SetFont("cef4444")
        }
    } else {
        if (closeBtnHover) {
            closeBtnHover := false
            closeBtn.SetFont("c475569")
        }
    }
}

; Sürükleme alanı
G.Add("Text", "x0 y3 w220 h42 BackgroundTrans").OnEvent("Click", DragWin)

; ── Status strip (y=45, h=24) ──
G.Add("Text", "x0 y45 w300 h1 Background1a1a2e")
G.Add("Text", "x0 y46 w300 h24 Background0d0d14")
G.SetFont("s8 w700 cef4444", "Segoe UI")
statusDot := G.Add("Text", "x14 y54 w6 h6 Background0d0d14")
statusDot.Opt("+0x1000000")
global statusText := G.Add("Text", "x14 y52 w60 Background0d0d14", "● PASİF")
G.SetFont("s7 w700 c22c55e", "Segoe UI")
global uptimeLabel := G.Add("Text", "x240 y52 w46 Background0d0d14 Right", "00:00")
global ramLabel := G.Add("Text", "x0 y0 w1 h1 Background111114", "")

; ── Silah Seçimi (y=70) ──
G.Add("Text", "x0 y70 w300 h1 Background1a1a2e")
G.SetFont("s8 w700 c475569", "Segoe UI")
G.Add("Text", "x14 y78 w120 Background111114", "SİLAH SEÇİMİ")

; 5.56 — alt çizgi rengi
G.Add("Text", "x14 y94 w62 h52 Background161620")
global a556Top := G.Add("Text", "x14 y142 w62 h2 Background22c55e")
G.SetFont("s7 c334155", "Segoe UI")
G.Add("Text", "x14 y98 w62 Background161620 Center", "F1")
G.SetFont("s12 w800 c22c55e", "Segoe UI")
a556 := G.Add("Text", "x14 y110 w62 h22 Background161620 Center +0x200", "5.56")

; 7.62
G.Add("Text", "x80 y94 w62 h52 Background161620")
global a762Top := G.Add("Text", "x80 y142 w62 h2 Background161620")
G.SetFont("s7 c334155", "Segoe UI")
G.Add("Text", "x80 y98 w62 Background161620 Center", "F2")
G.SetFont("s12 w800 c334155", "Segoe UI")
a762 := G.Add("Text", "x80 y110 w62 h22 Background161620 Center +0x200", "7.62")

; 9MM
G.Add("Text", "x146 y94 w62 h52 Background161620")
global a9mmTop := G.Add("Text", "x146 y142 w62 h2 Background161620")
G.SetFont("s7 c334155", "Segoe UI")
G.Add("Text", "x146 y98 w62 Background161620 Center", "F3")
G.SetFont("s12 w800 c334155", "Segoe UI")
a9mm := G.Add("Text", "x146 y110 w62 h22 Background161620 Center +0x200", "9MM")

; BOMBA
G.Add("Text", "x212 y94 w74 h52 Background161620")
global aBombaTop := G.Add("Text", "x212 y142 w74 h2 Background161620")
G.SetFont("s7 c334155", "Segoe UI")
G.Add("Text", "x212 y98 w74 Background161620 Center", "F4")
G.SetFont("s12 w800 c334155", "Segoe UI")
aBomba := G.Add("Text", "x212 y110 w74 h22 Background161620 Center +0x200", "💣")

a556.OnEvent("Click",   (*) => SetAmmo("5.56"))
a762.OnEvent("Click",   (*) => SetAmmo("7.62"))
a9mm.OnEvent("Click",   (*) => SetAmmo("9MM"))
aBomba.OnEvent("Click", (*) => SetAmmoKey("BOMBA"))

; ── Recoil (y=150) ──
G.Add("Text", "x0 y150 w300 h1 Background1a1a2e")
G.SetFont("s8 w700 c475569", "Segoe UI")
G.Add("Text", "x14 y158 w120 Background111114", "RECOİL")

; Recoil card — sol kenar mor çizgi
G.Add("Text", "x14 y172 w3 h80 Background6366f1")
G.Add("Text", "x17 y172 w269 h80 Background161620")
G.SetFont("s9 w600 c94a3b8", "Segoe UI")
G.Add("Text", "x26 y180 w140 Background161620", "Aşağı kaydırma hızı")
recoilLabel := G.Add("Text", "x200 y180 w80 Background161620 Right", "")
G.SetFont("s22 w900 cf8fafc", "Segoe UI")
recoilNum := G.Add("Text", "x180 y192 w100 Background161620 Right", "0")
G.Add("Text", "x26 y228 w264 h6 Background0d0d14")
global progressBar := G.Add("Text", "x26 y228 w0 h6 Background6366f1")
G.SetFont("s7 cef4444", "Segoe UI")
G.Add("Text", "x26 y238 w264 Background161620 Center", "↑↓ yön tuşları ile ayarlayın")

; ── Kontroller (y=256) ──
G.Add("Text", "x0 y256 w300 h1 Background1a1a2e")
G.SetFont("s8 w700 c475569", "Segoe UI")
G.Add("Text", "x14 y264 w160 Background111114", "KONTROLLER")
G.SetFont("s7 w600 c334155", "Segoe UI")
G.Add("Text", "x180 y266 w106 Background111114 Right", "berkaycimh")

; Macro — sol kırmızı çizgi
G.Add("Text", "x14 y278 w3 h38 Backgroundef4444")
G.Add("Text", "x17 y278 w269 h38 Background161620")
G.SetFont("s10 w700 cef4444", "Segoe UI")
G.Add("Text", "x26 y289 w16 h16 Background161620 Center", "◉")
G.SetFont("s9 w600 ccbd5e1", "Segoe UI")
G.Add("Text", "x46 y287 w100 Background161620", "Macro")
G.SetFont("s7 c334155", "Segoe UI")
G.Add("Text", "x46 y302 w120 Background161620", "DELETE tuşu")
G.SetFont("s9 w700 cef4444", "Segoe UI")
toggleMacro := G.Add("Text", "x196 y284 w84 h26 Background1a0808 Center +0x200", "PASİF")
toggleMacro.OnEvent("Click", (*) => DoToggleMacro())

; Kaydet — sol yeşil çizgi
G.Add("Text", "x14 y320 w3 h38 Background22c55e")
G.Add("Text", "x17 y320 w269 h38 Background161620")
G.SetFont("s10 w700 c22c55e", "Segoe UI")
G.Add("Text", "x26 y331 w16 h16 Background161620 Center", "▣")
G.SetFont("s9 w600 ccbd5e1", "Segoe UI")
G.Add("Text", "x46 y329 w100 Background161620", "Kaydet")
G.SetFont("s7 c334155", "Segoe UI")
global saveStatus := G.Add("Text", "x46 y344 w120 Background161620", "Otomatik")
G.SetFont("s9 w700 c22c55e", "Segoe UI")
saveBtn := G.Add("Text", "x196 y326 w84 h26 Background081a08 Center +0x200", "KAYDET")
saveBtn.OnEvent("Click", (*) => DoSave())

; Diğer Ayarlar — sol mor çizgi
G.Add("Text", "x14 y362 w3 h38 Background6366f1")
G.Add("Text", "x17 y362 w269 h38 Background161620")
G.SetFont("s10 w700 c6366f1", "Segoe UI")
G.Add("Text", "x26 y373 w16 h16 Background161620 Center", "✦")
G.SetFont("s9 w600 ccbd5e1", "Segoe UI")
G.Add("Text", "x46 y371 w120 Background161620", "Diğer Ayarlar")
G.SetFont("s7 c334155", "Segoe UI")
G.Add("Text", "x46 y386 w120 Background161620", "")
G.SetFont("s9 w700 c6366f1", "Segoe UI")
settingsBtn := G.Add("Text", "x196 y368 w84 h26 Background08081a Center +0x200", "AYARLAR")
settingsBtn.OnEvent("Click", (*) => OpenHudSettingsGui())

; Lisans — sol mor çizgi
G.Add("Text", "x14 y404 w3 h38 Backgrounda855f7")
G.Add("Text", "x17 y404 w269 h38 Background161620")
G.SetFont("s10 w700 ca855f7", "Segoe UI")
G.Add("Text", "x26 y415 w16 h16 Background161620 Center", "◈")
G.SetFont("s9 w600 ccbd5e1", "Segoe UI")
G.Add("Text", "x46 y413 w100 Background161620", "Lisans")
licType := IniRead(A_ScriptDir "\settings.ini", "License", "Type", "")
if (licType = "admin") {
    G.SetFont("s7 cc4b5fd", "Segoe UI")
    global licInfoLabel := G.Add("Text", "x46 y428 w160 Background161620", "Kurucu lisansı")
} else if (licType = "unlimited") {
    G.SetFont("s7 c22c55e", "Segoe UI")
    global licInfoLabel := G.Add("Text", "x46 y428 w160 Background161620", "∞ Sınırsız aktif")
} else if (licType = "30day") {
    licDate := IniRead(A_ScriptDir "\settings.ini", "License", "Date", "")
    remainDays := 30 - DateDiff(A_Now, licDate, "Days")
    if (remainDays < 0)
        remainDays := 0
    if (remainDays <= 7) {
        G.SetFont("s7 cef4444", "Segoe UI")
        global licInfoLabel := G.Add("Text", "x46 y428 w160 Background161620", "⏱ " remainDays " gün kaldı")
    } else {
        G.SetFont("s7 c22c55e", "Segoe UI")
        global licInfoLabel := G.Add("Text", "x46 y428 w160 Background161620", "⏱ " remainDays " gün kaldı")
    }
} else {
    G.SetFont("s7 c64748b", "Segoe UI")
    global licInfoLabel := G.Add("Text", "x46 y428 w160 Background161620", "Lisans bilgisi yok")
}
G.SetFont("s9 w700 ca855f7", "Segoe UI")
licBtn := G.Add("Text", "x196 y410 w84 h26 Background150818 Center +0x200", "BİLGİ")
licBtn.OnEvent("Click", (*) => ShowLicenseInfo())

G.Show("w300 h452")

; Butonlara yuvarlak köşe — CreateRoundRectRgn
RoundBtn(ctrl, w, h) {
    hRgn := DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", w, "int", h, "int", 14, "int", 14, "ptr")
    DllCall("SetWindowRgn", "ptr", ctrl.Hwnd, "ptr", hRgn, "int", 1)
}
RoundBtn(toggleMacro, 84, 26)
RoundBtn(saveBtn, 84, 26)
RoundBtn(settingsBtn, 84, 26)
RoundBtn(licBtn, 84, 26)

; Köşe kesilen kısımları kart rengiyle kapat
FixCorners(ctrl, x, y) {
    global G
    ; Sol üst
    G.Add("Text", "x" x " y" y " w4 h4 Background161620")
    G.Add("Text", "x" (x+80) " y" y " w4 h4 Background161620")
    G.Add("Text", "x" x " y" (y+22) " w4 h4 Background161620")
    G.Add("Text", "x" (x+80) " y" (y+22) " w4 h4 Background161620")
}
FixCorners(toggleMacro, 196, 284)
FixCorners(saveBtn, 196, 326)
FixCorners(settingsBtn, 196, 368)
FixCorners(licBtn, 196, 410)

; Başlangıç animasyonu — yukarıdan aşağı kayarak gel
screenW := SysGet(0)
screenH := SysGet(1)
startX := (screenW - 300) // 2
startY := -452
targetY := (screenH - 452) // 2
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
toggleMacro.Value := "PASİF"
toggleMacro.SetFont("s9 w700 cef4444")
toggleMacro.Opt("Background1a0008")
UpdateStatLabel()



; Sürüm kontrolü (GitHub'dan)
; SetTimer(CheckVersion, -2000) -- artık GUI'den önce çalışıyor

OnExit(SaveSettings)
SetTimer(UptimeTick, 1000)
SetTimer(UpdateRAM, 3000)
SetTimer(HudDotBlink, 50)
SetTimer(StatusDotBlink, 600)
SetTimer(BackupSettings, 300000)  ; 5 dakikada bir yedek

; ── Mini HUD Overlay — v2 ──
HUD := Gui("+AlwaysOnTop -Caption +ToolWindow -Border -DPIScale +E0x80000 +E0x20", "HUD")
HUD.BackColor := "08080f"
HUD.MarginX := 0
HUD.MarginY := 0

; Accent çizgisi — tam genişlik, macro durumuna göre renk
HUD.Add("Text", "x0 y0 w148 h2 Background111122")
global hudAccentBar := HUD.Add("Text", "x0 y0 w148 h2 Backgroundff3355")

; Üst satır: MACRO (beyaz) | nokta + ON (yeşil/kırmızı)
HUD.SetFont("s6 w700 cFFFFFF", "Segoe UI")
HUD.Add("Text", "x7 y4 w46 h12 Background08080f", "MACRO")
HUD.SetFont("s6 w700 c00ff88", "Segoe UI")
global hudStatus := HUD.Add("Text", "x53 y4 w88 h12 Background08080f Right", "● ON")
global hudDotLbl := hudStatus

; Yatay ayırıcı 1
HUD.Add("Text", "x7 y17 w134 h1 Background111122")

; Orta satır: ammo ikonu + isim + recoil
HUD.Add("Text", "x7 y20 w14 h14 Background0d1a12")
HUD.SetFont("s6 w800 c00ff88", "Segoe UI")
global hudAmmoIcon := HUD.Add("Text", "x7 y20 w14 h14 Background0d1a12 Center +0x200", "R")
HUD.SetFont("s9 w700 c00ff88", "Segoe UI")
global hudAmmo := HUD.Add("Text", "x24 y20 w40 h14 Background08080f", "5.56")
HUD.SetFont("s10 w800 cFFFFFF", "Segoe UI")
global hudRecoil := HUD.Add("Text", "x72 y19 w69 h14 Background08080f Right", "0")

; Recoil bar
HUD.Add("Text", "x7 y35 w134 h2 Background111122")
global hudRecoilBar := HUD.Add("Text", "x7 y35 w0 h2 Background00ff88")

; Yatay ayırıcı 2
HUD.Add("Text", "x7 y38 w134 h1 Background111122")

; Lean satırı: EĞİLME (beyaz) | AÇIK/KAPALI
HUD.SetFont("s6 w700 cFFFFFF", "Segoe UI")
HUD.Add("Text", "x7 y41 w60 h12 Background08080f", "EĞİLME")
HUD.SetFont("s6 w700 cff3355", "Segoe UI")
global hudLeanStatus := HUD.Add("Text", "x67 y41 w74 h12 Background08080f Right", "KAPALI")

screenW := SysGet(0)
hudStartX := (hudX = -1) ? (screenW - 158) : hudX
HUD.Show("w148 h55 x" hudStartX " y" hudY " NoActivate")
WinSetTransparent(hudOpacity, HUD)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", HUD.Hwnd, "uint", 33, "int*", 2, "uint", 4)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", HUD.Hwnd, "uint", 34, "int*", 0x08080f, "uint", 4)

; Click-through
exStyle := DllCall("GetWindowLong", "ptr", HUD.Hwnd, "int", -20)
DllCall("SetWindowLong", "ptr", HUD.Hwnd, "int", -20, "int", exStyle | 0x80000 | 0x20)

; Sürükleme alanı
hudDrag := HUD.Add("Text", "x0 y0 w148 h55 BackgroundTrans")
hudDrag.OnEvent("Click", DragHUD)

; Boyut değişince içeriği yeniden yerleştir
HUD.OnEvent("Size", ResizeHUD)

HWND := G.Hwnd
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", HWND, "uint", 2,  "int*", 1,          "uint", 4)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", HWND, "uint", 33, "int*", 2,          "uint", 4)
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", HWND, "uint", 34, "int*", 0x111114,   "uint", 4)

; ─── Hotkeys ───────────────────────────────────────────────────────────────

F1:: SetAmmoKey("5.56")
F2:: SetAmmoKey("7.62")
F3:: SetAmmoKey("9MM")
F4:: SetAmmoKey("BOMBA")
Delete:: DoToggleMacro()

; Bomba modu — tuşa basılıyken BOMBA, bırakınca önceki silaha dön
~*LShift:: {
    global bombaModeKey, activeAmmo
    if (bombaModeKey = "" || bombaModeKey != "LShift")
        return
    prevAmmo := activeAmmo
    SetAmmoKey("BOMBA")
    KeyWait("LShift")
    SetAmmoKey(prevAmmo)
}



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
    global macroOn, shooting, leanState
    if (!macroOn)
        return
    if GetKeyState("RButton")
        return
    Sleep(50)
    if !GetKeyState("LButton")
        return
    shooting := true
    leanState := 0
    SetTimer(ApplyRecoil, 10)
    SetTimer(AutoLean, leanSpeed)
    if (leanOn) {
        if (leanDelay > 0)
            SetTimer(() => (shooting && leanOn ? AutoLean() : ""), -leanDelay)
        else
            AutoLean()
    }
}

~LButton Up:: {
    global shooting
    shooting := false
    SetTimer(ApplyRecoil, 0)
    SetTimer(AutoLean, 0)
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
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", ammoGui.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    SetTimer(() => (IsObject(ammoGui) ? ammoGui.Destroy() : ""), -2500)
}

SetAmmo(ammo) {
    global activeAmmo, a556, a762, a9mm, aBomba
    global a556Top, a762Top, a9mmTop, aBombaTop
    activeAmmo := ammo
    if !IsObject(a556)
        return

    ; Reset all colors
    a556.SetFont("c334155")
    a762.SetFont("c334155")
    a9mm.SetFont("c334155")
    aBomba.SetFont("c334155")

    ; Reset all bottom bars
    a556Top.Opt("Background161620")
    a762Top.Opt("Background161620")
    a9mmTop.Opt("Background161620")
    aBombaTop.Opt("Background161620")
    a556Top.Redraw()
    a762Top.Redraw()
    a9mmTop.Redraw()
    aBombaTop.Redraw()

    ; Set active
    if (ammo = "5.56") {
        a556.SetFont("c22c55e")
        a556Top.Opt("Background22c55e")
        a556Top.Redraw()
    } else if (ammo = "7.62") {
        a762.SetFont("ceab308")
        a762Top.Opt("Backgroundeab308")
        a762Top.Redraw()
    } else if (ammo = "9MM") {
        a9mm.SetFont("cf97316")
        a9mmTop.Opt("Backgroundf97316")
        a9mmTop.Redraw()
    } else if (ammo = "BOMBA") {
        aBomba.SetFont("c818cf8")
        aBombaTop.Opt("Background818cf8")
        aBombaTop.Redraw()
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
        recoilLabel.SetFont("c818cf8")
        recoilLabel.Value := "BOMBA"
        recoilNum.SetFont("c818cf8")
        recoilNum.Value := 0
        progressBar.Opt("w0")
        if IsObject(hudAmmo) {
            hudAmmo.SetFont("s10 w700 c818cf8")
            hudAmmo.Value := "BOMBA"
            hudRecoil.Value := 0
        }
        if IsObject(hudAmmoIcon) {
            hudAmmoIcon.SetFont("s7 w800 c818cf8")
            hudAmmoIcon.Value := "B"
            hudAmmoIcon.Opt("Background0d0d2b")
        }
        if IsObject(hudRecoilBar)
            hudRecoilBar.Opt("w0")
        if IsObject(hudAccentBar)
            hudAccentBar.Opt("Background818cf8")
        return
    }
    colorMap := Map("5.56", "c22c55e", "7.62", "ceab308", "9MM", "cf97316")
    barColor := Map("5.56", "22c55e",  "7.62", "eab308",  "9MM", "f97316")
    subMap   := Map("5.56", "RIFLE",   "7.62", "DMR/SR",  "9MM", "SMG")
    val := recoilValues[activeAmmo]
    recoilLabel.SetFont(colorMap[activeAmmo])
    recoilLabel.Value := activeAmmo
    recoilNum.SetFont("s22 w900 " . colorMap[activeAmmo])
    recoilNum.Value := val
    barW := Round(val * 264 / 100)
    progressBar.Opt("w" . barW . " Background" . barColor[activeAmmo])
    if IsObject(hudAmmo) {
        hudAmmo.SetFont("s10 w700 " . colorMap[activeAmmo])
        hudAmmo.Value := activeAmmo
        hudRecoil.Value := val
    }
    if IsObject(hudAmmoIcon) {
        iconMap := Map("5.56","R","7.62","D","9MM","S","BOMBA","B")
        hudAmmoIcon.SetFont("s7 w800 " . colorMap[activeAmmo])
        hudAmmoIcon.Value := iconMap[activeAmmo]
        hudAmmoIcon.Opt("Background" . (activeAmmo = "5.56" ? "0d1a12" : activeAmmo = "7.62" ? "1a1200" : activeAmmo = "9MM" ? "1a0e00" : "0d0d2b"))
    }
    if IsObject(hudRecoilBar) {
        barW := Round(val * 62 / 100)
        hudRecoilBar.Opt("w" barW " Background" barColor[activeAmmo])
    }
    if IsObject(hudAmmoSub)
        hudAmmoSub.Value := subMap[activeAmmo]
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
    toggleMacro.Value := macroOn ? "AKTİF" : "PASİF"
    toggleMacro.SetFont(macroOn ? "s9 w700 c22c55e" : "s9 w700 cef4444")
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
    global macroOn, statusDot, statusText, hudStatus, hudAccentBar
    if IsObject(statusText) {
        statusText.SetFont(macroOn ? "s8 w700 c22c55e" : "s8 w700 cef4444")
        statusText.Value := macroOn ? "● AKTİF" : "● PASİF"
    }
    if IsObject(hudStatus) {
        hudStatus.SetFont(macroOn ? "s6 w700 c00ff88" : "s6 w700 cff3355")
        hudStatus.Value := macroOn ? "● ON" : "● OFF"
    }
    try {
        hudAccentBar.Opt("Background" . (macroOn ? "00ff88" : "ff3355"))
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
    global HUD, hudVisible
    hudVisible := !hudVisible
    if (hudVisible) {
        HUD.Show("NoActivate")
    } else {
        HUD.Hide()
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
    ; Kapanırken yedek al
    BackupSettings()
}

BackupSettings() {
    iniFile   := A_ScriptDir "\settings.ini"
    backupFile := A_ScriptDir "\settings_backup.ini"
    if FileExist(iniFile)
        FileCopy(iniFile, backupFile, 1)
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
        ramLabel.SetFont("s7 w700 c22c55e")
        ramLabel.Value := mb " MB"
    } catch {
        ramLabel.SetFont("s7 w700 c475569")
        ramLabel.Value := "--"
    }
}

UptimeTick() {
    global uptimeSeconds, uptimeLabel
    uptimeSeconds++
    mins := uptimeSeconds // 60
    secs := Mod(uptimeSeconds, 60)
    if IsObject(uptimeLabel)
        uptimeLabel.Value := Format("{:02d}:{:02d}", mins, secs)
}

StatusDotBlink() {
    global statusText, macroOn
    static blinkState := true
    if !IsObject(statusText)
        return
    blinkState := !blinkState
    if (macroOn) {
        statusText.SetFont("s8 w700 c" . (blinkState ? "22c55e" : "0a3a1a"))
    } else {
        statusText.SetFont("s8 w700 c" . (blinkState ? "ef4444" : "3a0a0a"))
    }
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
    global hudDrag
    if (minMax = -1)
        return
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

HudDotBlink() {
    global hudDotLbl, hudAccentBar, macroOn
    static phase := 0.0
    if !IsObject(hudDotLbl)
        return
    ; Accent çizgisi rengini sürekli güncelle
    try {
        hudAccentBar.Opt("Background" . (macroOn ? "00ff88" : "ff3355"))
        hudAccentBar.Redraw()
    }
    ; Nokta nefes animasyonu
    phase := Mod(phase + 0.08, 6.2832)
    brightness := (Sin(phase) + 1) / 2
    if (macroOn) {
        g := Round(50 + brightness * 205)
        r := 0
        b := Round(brightness * 136)
        hudDotLbl.SetFont("s6 w700 c" Format("{:02X}{:02X}{:02X}", r, g, b))
    } else {
        r := Round(50 + brightness * 205)
        g := 0
        b := 0
        hudDotLbl.SetFont("s6 w700 c" Format("{:02X}{:02X}{:02X}", r, g, b))
    }
}

AutoLean() {
    global shooting, macroOn, leanState, leanOn, leanKeyLeft, leanKeyRight, leanSpeed
    if (!shooting || !macroOn || !leanOn)
        return
    mouseKeys := ["LButton","RButton","MButton","XButton1","XButton2"]
    isMouseKey(k) {
        for mk in mouseKeys
            if (k = mk)
                return true
        return false
    }
    SendKey(k, down) {
        if isMouseKey(k) {
            if (down)
                Click(k " down")
            else
                Click(k " up")
        } else {
            if (down)
                SendInput("{" k " down}")
            else
                SendInput("{" k " up}")
        }
    }
    if (leanState = 0) {
        SendKey(leanKeyLeft, true)
        Sleep(400)
        SendKey(leanKeyLeft, false)
        leanState := 1
    } else {
        SendKey(leanKeyRight, true)
        Sleep(400)
        SendKey(leanKeyRight, false)
        leanState := 0
    }
}

OpenLeanSettings() {
    global leanKeyLeft, leanKeyRight, leanSpeed, leanDelay, leanToggleKey
    global leanLeftBtn, leanRightBtn, leanSpeedBtn, leanDelayBtn, leanHotkeyBtn, leanSettingsBtn

    LG := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" . A_ScriptHwnd, "")
    LG.BackColor := "0e0e0e"
    LG.MarginX := 0
    LG.MarginY := 0

    ; Titlebar
    LG.Add("Text", "x0 y0 w3 h36 Background4488ff")
    LG.Add("Text", "x3 y0 w281 h36 Background0a0a0a")
    LG.SetFont("s9 w700 c4488ff", "Consolas")
    LG.Add("Text", "x12 y0 w240 h36 Background0a0a0a +0x200", "⚙ EĞİLME MODU AYARLARI")
    LG.Add("Text", "x284 y0 w1 h36 Background222222")
    LG.SetFont("s12 w700 c555555", "Consolas")
    lgClose := LG.Add("Text", "x285 y0 w35 h36 Background0a0a0a Center +0x200", "×")
    lgClose.OnEvent("Click", (*) => LG.Destroy())
    LG.Add("Text", "x0 y36 w320 h1 Background222222")

    LG.SetFont("s8 w600 cFFFFFF", "Consolas")
    LG.Add("Text", "x10 y46 w140 Background0e0e0e", "Sol eğilme tuşu")
    LG.SetFont("s8 w700 c4488ff", "Consolas")
    lgLeft := LG.Add("Text", "x160 y44 w140 h22 Background141414 Center +0x200", StrUpper(leanKeyLeft))
    lgLeft.OnEvent("Click", (*) => (AssignLeanKey("left"), lgLeft.Value := StrUpper(leanKeyLeft), UpdateLeanInfo()))

    LG.SetFont("s8 w600 cFFFFFF", "Consolas")
    LG.Add("Text", "x10 y72 w140 Background0e0e0e", "Sağ eğilme tuşu")
    LG.SetFont("s8 w700 c4488ff", "Consolas")
    lgRight := LG.Add("Text", "x160 y70 w140 h22 Background141414 Center +0x200", StrUpper(leanKeyRight))
    lgRight.OnEvent("Click", (*) => (AssignLeanKey("right"), lgRight.Value := StrUpper(leanKeyRight), UpdateLeanInfo()))

    LG.SetFont("s8 w600 cFFFFFF", "Consolas")
    LG.Add("Text", "x10 y98 w140 Background0e0e0e", "Eğilme hızı")
    LG.SetFont("s8 w700 c4488ff", "Consolas")
    lgSpeed := LG.Add("Text", "x160 y96 w140 h22 Background141414 Center +0x200", leanSpeed "ms")
    lgSpeed.OnEvent("Click", (*) => (AdjustLeanSetting("speed"), lgSpeed.Value := leanSpeed "ms", UpdateLeanInfo()))

    LG.SetFont("s8 w600 cFFFFFF", "Consolas")
    LG.Add("Text", "x10 y124 w140 Background0e0e0e", "Başlama gecikmesi")
    LG.SetFont("s8 w700 c4488ff", "Consolas")
    lgDelay := LG.Add("Text", "x160 y122 w140 h22 Background141414 Center +0x200", DelayTxt())
    lgDelay.OnEvent("Click", (*) => (AdjustLeanSetting("delay"), lgDelay.Value := DelayTxt(), UpdateLeanInfo()))

    LG.SetFont("s8 w600 cFFFFFF", "Consolas")
    LG.Add("Text", "x10 y150 w140 Background0e0e0e", "Açma/kapama tuşu")
    LG.SetFont("s8 w700 c4488ff", "Consolas")
    lgHotkey := LG.Add("Text", "x160 y148 w140 h22 Background141414 Center +0x200", leanToggleKey = "" ? "YOK" : StrUpper(leanToggleKey))
    lgHotkey.OnEvent("Click", (*) => (AssignLeanHotkey(), lgHotkey.Value := leanToggleKey = "" ? "YOK" : StrUpper(leanToggleKey), UpdateLeanInfo()))

    LG.Add("Text", "x0 y178 w320 h1 Background222222")
    LG.SetFont("s6 c333333", "Consolas")
    LG.Add("Text", "x0 y182 w320 Background0e0e0e Center", "Hız ve gecikme butonlarına tıklayarak değer döngüsü yapılır.")

    screenW := SysGet(0)
    screenH := SysGet(1)
    LG.Show("w320 h196 x" (screenW-320)//2 " y" (screenH-196)//2)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", LG.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", LG.Hwnd, "uint", 34, "int*", 0x0e0e0e, "uint", 4)

    UpdateLeanInfo() {
        ; Ana GUI'deki özet satırı güncelle
        if IsObject(leanSettingsBtn) {
            delayTxt := (leanDelay = 0) ? "0" : (leanDelay < 1000 ? leanDelay "ms" : leanDelay//1000 "sn")
            hotkeyTxt := (leanToggleKey = "") ? "YOK" : StrUpper(leanToggleKey)
            leanSettingsBtn.Value := "SOL:" StrUpper(leanKeyLeft) " SAĞ:" StrUpper(leanKeyRight) " HIZ:" leanSpeed "ms"
        }
    }
}

AdjustLeanSetting(type) {
    global leanSpeed, leanDelay, leanSpeedBtn, leanDelayBtn

    if (type = "speed") {
        ; Hız seçenekleri: 200ms, 300ms, 450ms, 600ms, 800ms, 1000ms
        speeds := [200, 300, 450, 600, 800, 1000]
        cur := leanSpeed
        next := speeds[1]
        for i, s in speeds {
            if (s = cur && i < speeds.Length) {
                next := speeds[i+1]
                break
            }
        }
        leanSpeed := next
        SetTimer(AutoLean, leanSpeed)
        leanSpeedBtn.Value := next "ms"
    } else {
        ; Gecikme seçenekleri: 0, 500ms, 1sn, 2sn, 3sn
        delays := [0, 500, 1000, 2000, 3000]
        cur := leanDelay
        next := delays[1]
        for i, d in delays {
            if (d = cur && i < delays.Length) {
                next := delays[i+1]
                break
            }
        }
        leanDelay := next
        if (next = 0)
            leanDelayBtn.Value := "0sn"
        else if (next < 1000)
            leanDelayBtn.Value := next . "ms"
        else
            leanDelayBtn.Value := (next//1000) . "sn"
    }
}

DelayTxt() {
    global leanDelay
    if (leanDelay = 0)
        return "0sn"
    else if (leanDelay < 1000)
        return leanDelay . "ms"
    else
        return (leanDelay//1000) . "sn"
}

AssignLeanHotkey() {
    global leanToggleKey, leanHotkeyBtn

    aGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "")
    aGui.BackColor := "0e0e0e"
    aGui.SetFont("s8 w700 c4488ff", "Consolas")
    aGui.Add("Text", "x10 y10 w200 Center", "Eğilme açma/kapama tuşu")
    aGui.SetFont("s7 c555555", "Consolas")
    aGui.Add("Text", "x10 y26 w200 Center", "Bir tuşa bas — ESC iptal")
    screenW := SysGet(0)
    screenH := SysGet(1)
    aGui.Show("w220 h50 x" (screenW-220)//2 " y" (screenH-50)//2 " NoActivate")
    Sleep(200)

    ih := InputHook("L1 T5")
    ih.KeyOpt("{All}", "E")
    ih.Start()
    ih.Wait()
    pressedKey := ih.EndKey
    aGui.Destroy()

    if (pressedKey = "Escape" || pressedKey = "")
        return

    ; Eski hotkey'i kaldır
    if (leanToggleKey != "") {
        try Hotkey(leanToggleKey, "Off")
    }

    leanToggleKey := pressedKey
    ; Yeni hotkey ata
    Hotkey(pressedKey, (*) => ToggleLean(), "On")
}

AssignLeanKey(side) {
    global leanKeyLeft, leanKeyRight, leanLeftBtn, leanRightBtn

    ; Atama penceresi
    aGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "")
    aGui.BackColor := "0e0e0e"
    aGui.SetFont("s8 w700 c4488ff", "Consolas")
    aGui.Add("Text", "x10 y10 w200 Center", "Bir tuşa bas...")
    aGui.SetFont("s7 c555555", "Consolas")
    aGui.Add("Text", "x10 y26 w200 Center", "Klavye veya mouse tuşu — ESC iptal")
    screenW := SysGet(0)
    screenH := SysGet(1)
    aGui.Show("w220 h50 x" (screenW-220)//2 " y" (screenH-50)//2 " NoActivate")

    ; Mouse ve klavye tuşlarını birlikte bekle
    mouseKeys := ["LButton","RButton","MButton","XButton1","XButton2"]
    pressedKey := ""

    ; Önce mevcut basılı tuşların bitmesini bekle
    Sleep(200)

    loop {
        ; Mouse tuşlarını kontrol et
        for mk in mouseKeys {
            if GetKeyState(mk, "P") {
                pressedKey := mk
                break 2
            }
        }
        ; Klavye — InputHook ile tek tuş yakala
        ih := InputHook("L1 T0.05")
        ih.KeyOpt("{All}", "E")
        ih.Start()
        ih.Wait()
        if (ih.EndKey != "" && ih.EndKey != "Escape") {
            pressedKey := ih.EndKey
            break
        }
        if (ih.EndKey = "Escape")
            break
        Sleep(10)
    }

    aGui.Destroy()

    if (pressedKey = "" || pressedKey = "Escape")
        return

    ; Görünen isim
    displayMap := Map(
        "LButton","LMB", "RButton","RMB", "MButton","MMB",
        "XButton1","M4", "XButton2","M5"
    )
    displayName := displayMap.Has(pressedKey) ? displayMap[pressedKey] : StrUpper(pressedKey)

    if (side = "left") {
        leanKeyLeft := pressedKey
        leanLeftBtn.Value := displayName
    } else {
        leanKeyRight := pressedKey
        leanRightBtn.Value := displayName
    }
}

ToggleLean() {
    global leanOn, leanBtn, hudLeanStatus
    leanOn := !leanOn
    leanBtn.Value := leanOn ? "✔ AKTİF" : "✘ PASİF"
    leanBtn.SetFont(leanOn ? "c00ff88" : "cff3355")
    leanBtn.Opt("Background" . (leanOn ? "001a0a" : "1a0008"))
    if IsObject(hudLeanStatus) {
        hudLeanStatus.SetFont(leanOn ? "s6 w700 c00ff88" : "s6 w700 cff3355")
        hudLeanStatus.Value := leanOn ? "AÇIK" : "KAPALI"
    }
}

CycleHudMonitor() {
    global HUD, hudMonBtn, hudMonLabel
    ; Mevcut monitör sayısını al
    monCount := SysGet(80)  ; SM_CMONITORS
    if (monCount < 2) {
        hudMonLabel.Value := "Tek ekran"
        return
    }
    ; Mevcut HUD pozisyonunu al
    WinGetPos(&hx, &hy,,, HUD)
    ; Hangi monitörde olduğunu bul
    curMon := 1
    loop monCount {
        mLeft  := SysGet(76 + (A_Index-1)*4)   ; SM_XVIRTUALSCREEN benzeri
        ; MonitorGet ile daha güvenilir
    }
    ; MonitorGet ile tüm monitörleri tara
    loop monCount {
        MonitorGet(A_Index, &mL, &mT, &mR, &mB)
        if (hx >= mL && hx < mR && hy >= mT && hy < mB) {
            curMon := A_Index
            break
        }
    }
    ; Bir sonraki monitöre geç
    nextMon := Mod(curMon, monCount) + 1
    MonitorGet(nextMon, &nL, &nT, &nR, &nB)
    ; HUD'u yeni monitörün sağ üstüne taşı
    newX := nR - 158
    newY := nT + 10
    HUD.Move(newX, newY)
    hudMonBtn.Value := "MON " nextMon
    AutoSave()
}

ShowChangelogPopup(ver, body) {
    CL := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" . A_ScriptHwnd, "")
    CL.BackColor := "0e0e0e"
    CL.MarginX := 0
    CL.MarginY := 0
    ; Titlebar
    CL.Add("Text", "x0 y0 w3 h36 Backgroundffb300")
    CL.Add("Text", "x3 y0 w281 h36 Background0a0a0a")
    CL.SetFont("s9 w700 cffb300", "Consolas")
    CL.Add("Text", "x12 y0 w240 h36 Background0a0a0a +0x200", "🎉 v" ver " — YENİLİKLER")
    CL.Add("Text", "x284 y0 w1 h36 Background222222")
    CL.SetFont("s12 w700 c555555", "Consolas")
    clClose := CL.Add("Text", "x285 y0 w35 h36 Background0a0a0a Center +0x200", "×")
    clClose.OnEvent("Click", (*) => CL.Destroy())
    CL.Add("Text", "x0 y36 w320 h1 Background222222")
    ; İçerik
    CL.SetFont("s8 cFFFFFF", "Consolas")
    ; Body'yi satırlara böl ve göster
    lines := StrSplit(body, "`n")
    yPos := 46
    for line in lines {
        if (Trim(line) = "")
            continue
        CL.SetFont("s8 cFFFFFF", "Consolas")
        CL.Add("Text", "x10 y" yPos " w300 Background0e0e0e", Trim(line))
        yPos += 16
    }
    if (yPos < 80)
        yPos := 80
    CL.Add("Text", "x0 y" yPos " w320 h1 Background222222")
    CL.SetFont("s7 c333333", "Consolas")
    CL.Add("Text", "x0 y" (yPos+4) " w320 Background0e0e0e Center", "Kapat")
    totalH := yPos + 22
    screenW := SysGet(0)
    screenH := SysGet(1)
    CL.Show("w320 h" totalH " x" (screenW-320)//2 " y" (screenH-totalH)//2)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", CL.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", CL.Hwnd, "uint", 34, "int*", 0x0e0e0e, "uint", 4)
}

OpenThemeGui() {
    global G

    ; Tema tanımları: [isim, guiBg, titleBg, accent, textColor]
    themes := [
        ["⬛ Siyah (Default)", "0e0e0e", "0a0a0a", "00ff88", "FFFFFF"],
        ["🟦 Lacivert",        "0a0a18", "060612", "4488ff", "FFFFFF"],
        ["🟣 Koyu Mor",        "120a18", "0c0612", "aa44ff", "FFFFFF"],
        ["🟥 Koyu Kırmızı",   "180a0a", "120606", "ff3355", "FFFFFF"],
        ["🟩 Koyu Yeşil",     "0a1810", "06120a", "00ff88", "FFFFFF"],
        ["🌑 Tam Siyah",      "000000", "000000", "00ff88", "FFFFFF"],
        ["🌫 Gri",            "1a1a1a", "141414", "aaaaaa", "FFFFFF"],
    ]

    TG := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" . A_ScriptHwnd, "")
    TG.BackColor := "0e0e0e"
    TG.MarginX := 0
    TG.MarginY := 0

    ; Titlebar
    TG.Add("Text", "x0 y0 w3 h36 Background00ff88")
    TG.Add("Text", "x3 y0 w281 h36 Background0a0a0a")
    TG.SetFont("s9 w700 c00ff88", "Consolas")
    TG.Add("Text", "x12 y0 w240 h36 Background0a0a0a +0x200", "⚙ TEMA AYARLARI")
    TG.Add("Text", "x284 y0 w1 h36 Background222222")
    TG.SetFont("s12 w700 c555555", "Consolas")
    tgClose := TG.Add("Text", "x285 y0 w35 h36 Background0a0a0a Center +0x200", "×")
    tgClose.OnEvent("Click", (*) => TG.Destroy())
    TG.Add("Text", "x0 y36 w320 h1 Background222222")

    ; Tema butonları
    yPos := 46
    for i, t in themes {
        TG.SetFont("s9 w600 cFFFFFF", "Consolas")
        btn := TG.Add("Text", "x8 y" yPos " w304 h32 Background141414 +0x200 Center", t[1])
        btn.OnEvent("Click", ApplyTheme.Bind(t[2], t[3], t[4], t[5], TG))
        yPos += 36
    }

    TG.Add("Text", "x0 y" yPos " w320 h1 Background222222")
    screenW := SysGet(0)
    screenH := SysGet(1)
    TG.Show("w320 h" (yPos+2) " x" (screenW-320)//2 " y" (screenH-(yPos+2))//2)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", TG.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", TG.Hwnd, "uint", 34, "int*", 0x0e0e0e, "uint", 4)
}

ApplyTheme(guiBg, titleBg, accent, textColor, tgGui, *) {
    global G, sysBarStrip, sysBadge, uptimeLabel, hudAccentBar

    ; GUI arka plan
    G.BackColor := guiBg

    ; Tüm kontrolleri yeniden renklendir — WinRedraw
    ; Accent çizgisi
    if IsObject(sysBarStrip)
        sysBarStrip.Opt("Background" accent)
    if IsObject(sysBadge) {
        sysBadge.Opt("Background" . SubStr(accent, 1, 2) . "1a" . SubStr(accent, 3, 2) . "0a")
        sysBadge.SetFont("c" accent)
    }
    if IsObject(uptimeLabel)
        uptimeLabel.SetFont("c" accent)
    if IsObject(hudAccentBar)
        hudAccentBar.Opt("Background" accent)

    ; Ayarı kaydet
    iniFile := A_ScriptDir "\settings.ini"
    IniWrite(guiBg,    iniFile, "Theme", "GuiBg")
    IniWrite(titleBg,  iniFile, "Theme", "TitleBg")
    IniWrite(accent,   iniFile, "Theme", "Accent")
    IniWrite(textColor,iniFile, "Theme", "Text")

    ; Bildirim
    tgGui.Destroy()
    static tNotify := ""
    if IsObject(tNotify)
        tNotify.Destroy()
    tNotify := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "")
    tNotify.BackColor := "0e0e0e"
    tNotify.SetFont("s8 w700 c" accent, "Segoe UI")
    tNotify.Add("Text", "x8 y6 w180 Center", "✔ Tema uygulandı")
    screenW := SysGet(0)
    screenH := SysGet(1)
    tNotify.Show("w196 h28 x" (screenW-196)//2 " y" Round(screenH*0.82) " NoActivate")
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", tNotify.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    SetTimer(() => (IsObject(tNotify) ? tNotify.Destroy() : ""), -2000)
}

AssignBombaModeKey() {
    global bombaModeKey, bombaModeKeyBtn

    aGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "")
    aGui.BackColor := "0e0e0e"
    aGui.SetFont("s8 w700 c818cf8", "Consolas")
    aGui.Add("Text", "x10 y10 w200 Center", "Bomba modu aktif tuşu")
    aGui.SetFont("s7 c555555", "Consolas")
    aGui.Add("Text", "x10 y26 w200 Center", "Bir tuşa bas — ESC = YOK")
    screenW := SysGet(0)
    screenH := SysGet(1)
    aGui.Show("w220 h50 x" (screenW-220)//2 " y" (screenH-50)//2 " NoActivate")
    Sleep(200)

    ih := InputHook("L1 T5")
    ih.KeyOpt("{All}", "E")
    ih.Start()
    ih.Wait()
    pressedKey := ih.EndKey
    aGui.Destroy()

    if (pressedKey = "Escape" || pressedKey = "") {
        bombaModeKey := ""
    } else {
        bombaModeKey := pressedKey
    }
    ; settings.ini'ye kaydet
    IniWrite(bombaModeKey, A_ScriptDir "\settings.ini", "Settings", "BombaModeKey")
    try {
        if IsObject(bombaModeKeyBtn)
            bombaModeKeyBtn.Value := bombaModeKey = "" ? "YOK" : StrUpper(bombaModeKey)
    }
}

DragWin(*) {
    PostMessage(0xA1, 2, 0, G)
}

OpenHudSettingsGui() {
    global HUD, hudVisible, bombaModeKey

    HS := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" . A_ScriptHwnd, "")
    HS.BackColor := "111114"
    HS.MarginX := 0
    HS.MarginY := 0

    ; Üst mor accent
    HS.Add("Text", "x0 y0 w300 h3 Background6366f1")

    ; Header
    HS.Add("Text", "x0 y3 w300 h38 Background111114")
    HS.SetFont("s10 w700 ce2e8f0", "Segoe UI")
    HS.Add("Text", "x14 y10 w180 Background111114", "Diğer Ayarlar")
    HS.SetFont("s9 cef4444", "Segoe UI")
    hsClose := HS.Add("Text", "x268 y10 w24 h22 Background111114 Center +0x200", "✕")
    hsClose.OnEvent("Click", (*) => HS.Destroy())

    ; Sürükleme
    HS.Add("Text", "x0 y3 w260 h38 BackgroundTrans").OnEvent("Click", (*) => PostMessage(0xA1, 2, 0,, HS))

    ; Ayırıcı
    HS.Add("Text", "x0 y41 w300 h1 Background1a1a2e")

    ; ── Mini HUD bölümü ──
    HS.Add("Text", "x0 y42 w300 h28 Background0d0d14")
    HS.SetFont("s8 w700 c475569", "Segoe UI")
    HS.Add("Text", "x14 y50 w120 Background0d0d14", "MİNİ HUD")

    ; HUD Aç/Kapat
    HS.Add("Text", "x14 y74 w3 h32 Background22c55e")
    HS.Add("Text", "x17 y74 w269 h32 Background161620")
    HS.SetFont("s9 w600 ce2e8f0", "Segoe UI")
    HS.Add("Text", "x26 y79 w100 Background161620", "HUD Görünürlük")
    HS.SetFont("s8 w700 c22c55e", "Segoe UI")
    hsToggle := HS.Add("Text", "x196 y80 w84 h20 Background081a08 Center +0x200", hudVisible ? "AÇIK" : "KAPALI")
    hsToggle.SetFont(hudVisible ? "s8 w700 c22c55e" : "s8 w700 cef4444")
    hsToggle.Opt("Background" . (hudVisible ? "081a08" : "1a0808"))
    hsToggle.OnEvent("Click", (*) => (ToggleHUD(), hsToggle.Value := hudVisible ? "AÇIK" : "KAPALI", hsToggle.SetFont(hudVisible ? "s8 w700 c22c55e" : "s8 w700 cef4444"), hsToggle.Opt("Background" . (hudVisible ? "081a08" : "1a0808"))))

    ; Konum
    HS.Add("Text", "x14 y110 w3 h32 Background6366f1")
    HS.Add("Text", "x17 y110 w269 h32 Background161620")
    HS.SetFont("s9 w600 ce2e8f0", "Segoe UI")
    HS.Add("Text", "x26 y119 w80 Background161620", "Konum")
    HS.SetFont("s9 w700 ce2e8f0", "Segoe UI")
    hsBtnUp    := HS.Add("Text", "x160 y113 w24 h24 Background1a1a2e Center +0x200", "▲")
    hsBtnLeft  := HS.Add("Text", "x186 y113 w24 h24 Background1a1a2e Center +0x200", "◄")
    hsBtnDown  := HS.Add("Text", "x212 y113 w24 h24 Background1a1a2e Center +0x200", "▼")
    hsBtnRight := HS.Add("Text", "x238 y113 w24 h24 Background1a1a2e Center +0x200", "►")
    hsBtnUp.OnEvent("Click",    (*) => (MoveHUD(0,-10), UpdateHudPosLabel()))
    hsBtnLeft.OnEvent("Click",  (*) => (MoveHUD(-10,0), UpdateHudPosLabel()))
    hsBtnDown.OnEvent("Click",  (*) => (MoveHUD(0,10),  UpdateHudPosLabel()))
    hsBtnRight.OnEvent("Click", (*) => (MoveHUD(10,0),  UpdateHudPosLabel()))

    ; Monitör
    HS.Add("Text", "x14 y146 w3 h32 Background4488ff")
    HS.Add("Text", "x17 y146 w269 h32 Background161620")
    HS.SetFont("s9 w600 ce2e8f0", "Segoe UI")
    HS.Add("Text", "x26 y155 w80 Background161620", "Monitör")
    HS.SetFont("s8 w700 c4488ff", "Segoe UI")
    global hudMonBtn := HS.Add("Text", "x196 y152 w84 h20 Background08081a Center +0x200", "MON 1")
    hudMonBtn.OnEvent("Click", (*) => CycleHudMonitor())

    ; Ayırıcı
    HS.Add("Text", "x0 y182 w300 h1 Background1a1a2e")

    ; ── Bomba Modu bölümü ──
    HS.Add("Text", "x0 y183 w300 h28 Background0d0d14")
    HS.SetFont("s8 w700 c475569", "Segoe UI")
    HS.Add("Text", "x14 y191 w120 Background0d0d14", "BOMBA MODU")

    ; Aktif tuşu
    HS.Add("Text", "x14 y215 w3 h32 Backgrounda855f7")
    HS.Add("Text", "x17 y215 w269 h32 Background161620")
    HS.SetFont("s9 w600 ce2e8f0", "Segoe UI")
    HS.Add("Text", "x26 y220 w140 Background161620", "Aktif tuşu")
    HS.SetFont("s7 c475569", "Segoe UI")
    HS.Add("Text", "x26 y232 w140 Background161620", "Basılıyken BOMBA modu")
    HS.SetFont("s8 w700 ca855f7", "Segoe UI")
    global bombaModeKeyBtn := HS.Add("Text", "x196 y221 w84 h20 Background150818 Center +0x200", bombaModeKey = "" ? "YOK" : StrUpper(bombaModeKey))
    bombaModeKeyBtn.OnEvent("Click", (*) => (AssignBombaModeKey(), IsObject(bombaModeKeyBtn) ? bombaModeKeyBtn.Value := bombaModeKey = "" ? "YOK" : StrUpper(bombaModeKey) : ""))

    HS.Add("Text", "x0 y251 w300 h1 Background1a1a2e")

    screenW := SysGet(0)
    screenH := SysGet(1)
    ; GUI'nin sağ tarafında aç
    try {
        WinGetPos(&gx, &gy, &gw,,, "ahk_id " G.Hwnd)
    } catch {
        gx := (screenW - 300) // 2
        gy := (screenH - 252) // 2
        gw := 0
    }
    hsX := gx + gw + 8
    if (hsX + 300 > screenW)
        hsX := gx - 308
    if (hsX < 0)
        hsX := (screenW - 300) // 2
    HS.Show("w300 h252 x" hsX " y" gy)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", HS.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", HS.Hwnd, "uint", 34, "int*", 0x111114, "uint", 4)
}

UpdateHudPosLabel() {
    global HUD, hudPosLabel
    if !IsObject(hudPosLabel)
        return
    WinGetPos(&hx, &hy,,, HUD)
    hudPosLabel.Value := "X:" hx " Y:" hy
}

ShowChangelog() {
    CL := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" . A_ScriptHwnd, "")
    CL.BackColor := "0f1115"
    CL.MarginX := 0
    CL.MarginY := 0

    ; Header
    CL.Add("Text", "x0 y0 w300 h44 Background1a1d24")
    CL.SetFont("s11 w700 cf8fafc", "Segoe UI")
    CL.Add("Text", "x14 y8 w180 Background1a1d24", "Güncellemeler")
    CL.SetFont("s8 w600 cc4b5fd", "Segoe UI")
    CL.Add("Text", "x14 y28 w100 Background1a1d24", "v" currentVersion " — Güncel")
    CL.SetFont("s12 w700 c64748b", "Segoe UI")
    clClose := CL.Add("Text", "x270 y8 w24 h24 Background1a1d24 Center +0x200", "✕")
    clClose.OnEvent("Click", (*) => CL.Destroy())

    ; Ayırıcı
    CL.Add("Text", "x0 y44 w300 h1 Background222222")

    ; Sürükleme alanı — header üzerinde
    clDrag := CL.Add("Text", "x0 y0 w276 h44 BackgroundTrans")
    clDrag.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0,, CL))

    ; Değişiklik listesi
    changes := [
        ["c22c55e", "GUI tasarımı değişti"],
        ["c22c55e", "Lisans sistemi eklendi"],
    ]

    yPos := 56
    for item in changes {
        CL.SetFont("s9 w700 c" item[1], "Segoe UI")
        CL.Add("Text", "x14 y" yPos " w12 Background0f1115", "•")
        CL.SetFont("s9 w500 cf8fafc", "Segoe UI")
        CL.Add("Text", "x26 y" yPos " w260 Background0f1115", item[2])
        yPos += 22
    }

    ; Alt çizgi
    yPos += 4
    CL.Add("Text", "x0 y" yPos " w300 h1 Background222222")
    CL.SetFont("s7 w600 c334155", "Segoe UI")
    CL.Add("Text", "x0 y" (yPos+5) " w300 h14 Background0f1115 Center", "berkaycimh  •  LastCircle")

    totalH := yPos + 24
    screenW := SysGet(0)
    screenH := SysGet(1)
    CL.Show("w300 h" totalH " x" (screenW-300)//2 " y" (screenH-totalH)//2)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", CL.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", CL.Hwnd, "uint", 34, "int*", 0x0f1115, "uint", 4)
}

HudBtnMouseDown(wParam, lParam, msg, hwnd) {
    global hudMoveDir, btnUp, btnLeft, btnDown, btnRight
    if (hwnd = btnUp.Hwnd) {
        hudMoveDir := "up"
    } else if (hwnd = btnLeft.Hwnd) {
        hudMoveDir := "left"
    } else if (hwnd = btnDown.Hwnd) {
        hudMoveDir := "down"
    } else if (hwnd = btnRight.Hwnd) {
        hudMoveDir := "right"
    } else {
        return
    }
    SetTimer(HudMoveRepeat, 80)
}

HudBtnMouseUp(wParam, lParam, msg, hwnd) {
    global hudMoveDir
    hudMoveDir := ""
    SetTimer(HudMoveRepeat, 0)
}

HudMoveRepeat() {
    global hudMoveDir
    if (hudMoveDir = "up") {
        MoveHUD(0, -5)
    } else if (hudMoveDir = "left") {
        MoveHUD(-5, 0)
    } else if (hudMoveDir = "down") {
        MoveHUD(0, 5)
    } else if (hudMoveDir = "right") {
        MoveHUD(5, 0)
    }
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

; ─── Lisans Sıfırlama ──────────────────────────────────────────────────────
ResetLicense() {
    iniFile := A_ScriptDir "\settings.ini"
    IniDelete(iniFile, "License", "Key")
    IniDelete(iniFile, "License", "Type")
    IniDelete(iniFile, "License", "Date")

    static resetGui := ""
    if IsObject(resetGui)
        resetGui.Destroy()
    resetGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "")
    resetGui.BackColor := "1a0008"
    resetGui.SetFont("s8 w700 cff3355", "Segoe UI")
    resetGui.Add("Text", "x8 y6 w220 Center", "✘ Lisans sıfırlandı — yeniden başlatın")
    screenW := SysGet(0)
    screenH := SysGet(1)
    resetGui.Show("w236 h28 x" (screenW-236)//2 " y" Round(screenH*0.82) " NoActivate")
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", resetGui.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    SetTimer(() => ExitApp(), -2000)
}

; ─── Lisans Bilgisi Popup (Tray) ───────────────────────────────────────────
ShowLicenseInfo() {
    iniFile := A_ScriptDir "\settings.ini"
    licType := IniRead(iniFile, "License", "Type", "")
    licKey  := IniRead(iniFile, "License", "Key", "")

    LI := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
    LI.BackColor := "0a0a0a"
    LI.MarginX := 0
    LI.MarginY := 0

    LI.Add("Text", "x0 y0 w320 h3 Background00ff88")
    LI.Add("Text", "x0 y3 w320 h30 Background0a0a0a")
    LI.SetFont("s10 w800 cFFFFFF", "Consolas")
    LI.Add("Text", "x12 y8 w200 Background0a0a0a", "Lisans Bilgisi")
    LI.SetFont("s12 w700 cff3355", "Consolas")
    liClose := LI.Add("Text", "x288 y3 w30 h30 Background0a0a0a Center +0x200", "×")
    liClose.OnEvent("Click", (*) => LI.Destroy())

    LI.Add("Text", "x0 y33 w320 h1 Background1a1a1a")

    ; Tip
    LI.SetFont("s8 c888888", "Consolas")
    LI.Add("Text", "x12 y42 w80 Background0a0a0a", "Tür:")
    LI.SetFont("s8 w700 c00ff88", "Consolas")
    if (licType = "admin")
        LI.Add("Text", "x90 y42 w200 Background0a0a0a", "Kurucu Lisansı")
    else if (licType = "unlimited")
        LI.Add("Text", "x90 y42 w200 Background0a0a0a", "Sınırsız")
    else if (licType = "30day")
        LI.Add("Text", "x90 y42 w200 Background0a0a0a", "30 Günlük")
    else
        LI.Add("Text", "x90 y42 w200 Background0a0a0a", "Bilinmiyor")

    ; Key
    LI.SetFont("s8 c888888", "Consolas")
    LI.Add("Text", "x12 y60 w80 Background0a0a0a", "Key:")
    LI.SetFont("s8 w600 cFFFFFF", "Consolas")
    LI.Add("Text", "x90 y60 w220 Background0a0a0a", licKey != "" ? licKey : "—")

    ; Kalan gün
    LI.SetFont("s8 c888888", "Consolas")
    LI.Add("Text", "x12 y78 w80 Background0a0a0a", "Süre:")
    LI.SetFont("s8 w700 cffb300", "Consolas")
    if (licType = "admin") {
        LI.Add("Text", "x90 y78 w200 Background0a0a0a", "∞ Sınırsız (Kurucu)")
    } else if (licType = "unlimited") {
        LI.Add("Text", "x90 y78 w200 Background0a0a0a", "∞ Sınırsız")
    } else if (licType = "30day") {
        licDate := IniRead(iniFile, "License", "Date", "")
        remainDays := 30 - DateDiff(A_Now, licDate, "Days")
        if (remainDays < 0)
            remainDays := 0
        LI.Add("Text", "x90 y78 w200 Background0a0a0a", remainDays " gün kaldı")
    } else {
        LI.Add("Text", "x90 y78 w200 Background0a0a0a", "—")
    }

    LI.Add("Text", "x0 y98 w320 h1 Background1a1a1a")
    LI.SetFont("s7 c333333", "Consolas")
    LI.Add("Text", "x0 y102 w320 Background0a0a0a Center", "LastCircle License System")

    ; Lisans sıfırla butonu
    LI.SetFont("s8 w700 cff3355", "Consolas")
    licResetBtn := LI.Add("Text", "x20 y118 w280 h28 Background1a0008 Center +0x200", "🗑 LİSANSI SIFIRLA")
    licResetBtn.OnEvent("Click", (*) => (LI.Destroy(), ResetLicense()))

    screenW := SysGet(0)
    screenH := SysGet(1)
    LI.Show("w320 h154 x" (screenW-320)//2 " y" (screenH-154)//2)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", LI.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", LI.Hwnd, "uint", 34, "int*", 0x0a0a0a, "uint", 4)
}
