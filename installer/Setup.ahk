#Requires AutoHotkey v2.0
#SingleInstance Force

;@Ahk2Exe-SetName Simple Transcriber Setup
;@Ahk2Exe-SetDescription Simple Transcriber Installer
;@Ahk2Exe-SetVersion 1.0.1
;@Ahk2Exe-SetCopyright Copyright (c) 2026 Jamie Bykov-Brett

global GitHubRepo := "Netropolitan/Simple-Transcriber"
global CurrentInstallerVersion := "1.0.1"

DownloadWithRedirect(url, savePath) {
    whr := ComObject("WinHttp.WinHttpRequest.5.1")
    whr.Open("GET", url, true)
    whr.SetRequestHeader("User-Agent", "Simple-Transcriber-Updater/" . CurrentInstallerVersion)
    whr.SetTimeouts(30000, 30000, 30000, 60000)
    whr.Send()
    whr.WaitForResponse(60)

    if whr.Status = 302 || whr.Status = 301 {
        redirectUrl := whr.GetResponseHeader("Location")
        if redirectUrl {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("GET", redirectUrl, true)
            whr.SetRequestHeader("User-Agent", "Simple-Transcriber-Updater/" . CurrentInstallerVersion)
            whr.SetTimeouts(30000, 30000, 30000, 60000)
            whr.Send()
            whr.WaitForResponse(60)
        }
    }

    if whr.Status != 200
        throw Error("HTTP " . whr.Status)

    stream := ComObject("ADODB.Stream")
    stream.Type := 1
    stream.Open()
    stream.Write(whr.ResponseBody)
    stream.SaveToFile(savePath, 2)
    stream.Close()
}

global UpgradeMode := false
global UpgradePath := ""

for arg in A_Args {
    if arg = "/upgrade" || arg = "-upgrade" || arg = "--upgrade"
        UpgradeMode := true
    else if UpgradeMode && UpgradePath = "" && DirExist(arg)
        UpgradePath := arg
}

if !A_IsAdmin {
    try {
        cmdLine := '"' A_ScriptFullPath '"'
        if UpgradeMode {
            cmdLine .= ' /upgrade'
            if UpgradePath != ""
                cmdLine .= ' "' UpgradePath '"'
        }
        Run('*RunAs ' cmdLine)
        ExitApp
    } catch {
        MsgBox("This installer requires administrator privileges.", "Administrator Required", "IconX")
        ExitApp
    }
}

global MainGui := ""
global CurrentStep := 1
global InstallPath := "C:\Program Files\Simple Transcriber"
global CreateDesktopShortcut := true
global CreateStartMenuShortcut := true
global LaunchAfterInstall := true
global RunOnStartup := false
global StartMinimized := false
global DownloadFFmpeg := true
global InstallComplete := false

if UpgradeMode && UpgradePath != ""
    InstallPath := UpgradePath
else if UpgradeMode {
    try InstallPath := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SimpleTranscriber", "InstallLocation")
}

global Step1Controls := []
global Step2Controls := []
global Step3Controls := []
global Step4Controls := []
global ProgressBar := ""
global ProgressText := ""

global SourceDir := A_IsCompiled ? A_ScriptDir : A_ScriptDir "\.."

if UpgradeMode
    RunUpgrade()
else
    SetupInstaller()

RunUpgrade() {
    global InstallPath, SourceDir, LaunchAfterInstall
    LaunchAfterInstall := true

    upgradeGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox -SysMenu", "Simple Transcriber Update")
    upgradeGui.SetFont("s10", "Segoe UI")
    upgradeGui.BackColor := "FFFFFF"
    upgradeGui.Add("Text", "x20 y20 w360", "Updating Simple Transcriber...")
    progressBar := upgradeGui.Add("Progress", "x20 y50 w360 h25", 0)
    statusText := upgradeGui.Add("Text", "x20 y85 w360", "Preparing...")
    upgradeGui.Show("w400 h120")

    try {
        statusText.Value := "Closing running instances..."
        progressBar.Value := 20
        try RunWait('taskkill /F /IM SimpleTranscriber.exe', , "Hide")
        Sleep(1000)

        statusText.Value := "Updating application files..."
        progressBar.Value := 40

        if !DirExist(InstallPath)
            DirCreate(InstallPath)

        needsDownload := !FileExist(SourceDir "\SimpleTranscriber.exe")

        if needsDownload {
            statusText.Value := "Downloading application files..."
            downloadPath := InstallPath "\SimpleTranscriber.exe"
            downloaded := false
            lastError := ""

            for tag in ["v" . CurrentInstallerVersion, CurrentInstallerVersion] {
                baseUrl := "https://github.com/" . GitHubRepo . "/releases/download/" . tag . "/"
                try {
                    DownloadWithRedirect(baseUrl . "SimpleTranscriber.exe", downloadPath)
                    if FileExist(downloadPath) && FileGetSize(downloadPath) > 500000 {
                        downloaded := true
                        break
                    }
                } catch as e {
                    lastError := e.Message
                }
            }

            if !downloaded
                throw Error("Download failed: " . lastError)

            try DownloadWithRedirect(baseUrl . "Uninstall.exe", InstallPath "\Uninstall.exe")
        } else {
            if FileExist(SourceDir "\SimpleTranscriber.exe")
                FileCopy(SourceDir "\SimpleTranscriber.exe", InstallPath "\SimpleTranscriber.exe", true)
            if FileExist(SourceDir "\Uninstall.exe")
                FileCopy(SourceDir "\Uninstall.exe", InstallPath "\Uninstall.exe", true)
        }

        progressBar.Value := 70

        if FileExist(SourceDir "\assets\icon.ico")
            FileCopy(SourceDir "\assets\icon.ico", InstallPath "\icon.ico", true)
        else if FileExist(SourceDir "\icon.ico")
            FileCopy(SourceDir "\icon.ico", InstallPath "\icon.ico", true)

        progressBar.Value := 80

        statusText.Value := "Updating registry..."
        regKey := "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SimpleTranscriber"
        try RegWrite(CurrentInstallerVersion, "REG_SZ", regKey, "DisplayVersion")

        progressBar.Value := 100
        statusText.Value := "Update complete!"
        Sleep(500)
        upgradeGui.Destroy()

        MsgBox("Simple Transcriber has been updated to v" . CurrentInstallerVersion . "!", "Update Complete", "Iconi")

        exePath := InstallPath "\SimpleTranscriber.exe"
        if FileExist(exePath)
            try Run('explorer.exe "' exePath '"')

        ExitApp
    } catch as e {
        upgradeGui.Destroy()
        MsgBox("Update failed: " . e.Message, "Update Error", "IconX")
        ExitApp
    }
}

SetupInstaller() {
    global MainGui, InstallPath

    MainGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", "Simple Transcriber Setup")
    MainGui.SetFont("s10", "Segoe UI")
    MainGui.BackColor := "FFFFFF"

    MainGui.Add("Text", "x0 y0 w180 h400 Background2563EB")

    MainGui.SetFont("Bold s14 cFFFFFF")
    MainGui.Add("Text", "x15 y20 w150 BackgroundTrans", "Simple")
    MainGui.SetFont("Bold s14 cFFFFFF")
    MainGui.Add("Text", "x15 y38 w150 BackgroundTrans", "Transcriber")
    MainGui.SetFont("Bold s9 cFFFFFF")
    MainGui.Add("Text", "x15 y58 w150 BackgroundTrans", "Bykov-Brett Enterprises")
    MainGui.SetFont("Norm s9 cFFFFFF")
    MainGui.Add("Text", "x15 y74 w150 BackgroundTrans", "Setup Wizard")

    MainGui.SetFont("s10 cFFFFFF")
    MainGui.Add("Text", "x15 y110 w150 BackgroundTrans vSideStep1", "1. Welcome")
    MainGui.Add("Text", "x15 y140 w150 BackgroundTrans vSideStep2", "2. Location")
    MainGui.Add("Text", "x15 y170 w150 BackgroundTrans vSideStep3", "3. Options")
    MainGui.Add("Text", "x15 y200 w150 BackgroundTrans vSideStep4", "4. Install")

    MainGui.SetFont("Norm s10 c000000", "Segoe UI")

    BuildStep1()
    BuildStep2()
    BuildStep3()
    BuildStep4()

    ShowStep1()
    HideStep2()
    HideStep3()
    HideStep4()

    MainGui.Add("Button", "x200 y360 w80 h30 vBackBtn", "< Back").OnEvent("Click", OnBackBtn)
    MainGui.Add("Button", "x290 y360 w80 h30 vNextBtn", "Next >").OnEvent("Click", OnNextBtn)
    MainGui.Add("Button", "x450 y360 w80 h30 vCancelBtn", "Cancel").OnEvent("Click", OnCancelBtn)

    MainGui["BackBtn"].Enabled := false
    MainGui["NextBtn"].Enabled := false

    MainGui.OnEvent("Close", OnGuiClose)
    MainGui.OnEvent("Escape", OnGuiClose)
    MainGui.Show("w550 h400")
}

BuildStep1() {
    global MainGui, Step1Controls

    MainGui.SetFont("Bold s14")
    ctrl := MainGui.Add("Text", "x200 y30 w330 vStep1Title", "Welcome to Simple Transcriber")
    Step1Controls.Push(ctrl)
    MainGui.SetFont("Norm s10")

    ctrl := MainGui.Add("Text", "x200 y60 w330 vStep1Desc", "This wizard will install Simple Transcriber on your computer.`n`nPlease read and accept the license agreement:")
    Step1Controls.Push(ctrl)

    licenseText := "
    (
LICENSE AGREEMENT

By installing and using Simple Transcriber, you agree to the following terms:

1. SOFTWARE PROVIDED "AS IS"
This software is provided without warranty of any kind.

2. AUDIO/VIDEO PROCESSING
This software processes audio and video files for speech-to-text transcription. Files are sent to your configured Whisper API endpoint for processing.

3. DATA & PRIVACY
- Temporary audio files are auto-deleted after processing
- OpenAI mode sends audio to OpenAI's API servers
- Local Whisper mode sends audio to your configured server
- Transcription results are saved locally

4. ACCEPTABLE USE
You agree not to use this software for unlawful purposes or to transcribe content without proper authorization.

5. NO LIABILITY
The developers shall not be held liable for any consequences from use of this software.

(c) 2026 Bykov-Brett Enterprises. All rights reserved.
    )"
    ctrl := MainGui.Add("Edit", "x200 y115 w330 h175 vStep1License Hidden ReadOnly Multi", licenseText)
    Step1Controls.Push(ctrl)

    ctrl := MainGui.Add("Checkbox", "x200 y300 w330 vAcceptLicense Hidden", "I accept the license agreement")
    ctrl.OnEvent("Click", OnAcceptLicense)
    Step1Controls.Push(ctrl)

    ctrl := MainGui.Add("Text", "x200 y325 w330 vStep1Footer Hidden c666666", "You must accept the license agreement to continue.")
    Step1Controls.Push(ctrl)
}

OnAcceptLicense(*) {
    global MainGui
    MainGui["NextBtn"].Enabled := MainGui["AcceptLicense"].Value
}

BuildStep2() {
    global MainGui, Step2Controls, InstallPath

    MainGui.SetFont("Bold s14")
    ctrl := MainGui.Add("Text", "x200 y30 w330 vStep2Title Hidden", "Choose Install Location")
    Step2Controls.Push(ctrl)
    MainGui.SetFont("Norm s10")

    ctrl := MainGui.Add("Text", "x200 y70 w330 vStep2Desc Hidden", "Select where Simple Transcriber should be installed:")
    Step2Controls.Push(ctrl)

    ctrl := MainGui.Add("Edit", "x200 y110 w250 vInstallPathEdit Hidden", InstallPath)
    Step2Controls.Push(ctrl)

    ctrl := MainGui.Add("Button", "x460 y109 w70 h24 vBrowseBtn Hidden", "Browse...")
    ctrl.OnEvent("Click", OnBrowse)
    Step2Controls.Push(ctrl)

    ctrl := MainGui.Add("Text", "x200 y150 w330 c666666 vStep2Note Hidden", "Note: Settings are stored in AppData.")
    Step2Controls.Push(ctrl)
}

BuildStep3() {
    global MainGui, Step3Controls

    MainGui.SetFont("Bold s14")
    ctrl := MainGui.Add("Text", "x200 y30 w330 vStep3Title Hidden", "Installation Options")
    Step3Controls.Push(ctrl)
    MainGui.SetFont("Norm s10")

    ctrl := MainGui.Add("Text", "x200 y70 w330 vStep3Desc Hidden", "Choose additional options:")
    Step3Controls.Push(ctrl)

    ctrl := MainGui.Add("Checkbox", "x200 y100 w330 vDesktopShortcut Checked Hidden", "Create desktop shortcut")
    Step3Controls.Push(ctrl)

    ctrl := MainGui.Add("Checkbox", "x200 y125 w330 vStartMenuShortcut Checked Hidden", "Create Start Menu shortcut")
    Step3Controls.Push(ctrl)

    ctrl := MainGui.Add("Checkbox", "x200 y150 w330 vRunOnStartup Checked Hidden", "Run on Windows startup")
    Step3Controls.Push(ctrl)

    ctrl := MainGui.Add("Checkbox", "x200 y175 w330 vStartMinimized Checked Hidden", "Start minimized to system tray")
    Step3Controls.Push(ctrl)

    ctrl := MainGui.Add("Checkbox", "x200 y205 w330 vDownloadFFmpegCheck Checked Hidden", "Download FFmpeg (~80 MB)")
    Step3Controls.Push(ctrl)

    MainGui.SetFont("s8 c666666")
    ctrl := MainGui.Add("Text", "x218 y228 w310 vFFmpegDesc Hidden", "Required for transcribing video files (mp4, mkv, avi, etc.)`nand audio files larger than 25 MB.")
    Step3Controls.Push(ctrl)
    MainGui.SetFont("Norm s10 c000000", "Segoe UI")

    ctrl := MainGui.Add("Checkbox", "x200 y260 w330 vLaunchAfter Checked Hidden", "Launch Simple Transcriber after installation")
    Step3Controls.Push(ctrl)
}

BuildStep4() {
    global MainGui, Step4Controls, ProgressBar, ProgressText

    MainGui.SetFont("Bold s14")
    ctrl := MainGui.Add("Text", "x200 y30 w330 vStep4Title Hidden", "Installing")
    Step4Controls.Push(ctrl)
    MainGui.SetFont("Norm s10")

    ctrl := MainGui.Add("Text", "x200 y70 w330 vStep4Desc Hidden", "Please wait while Simple Transcriber is being installed...")
    Step4Controls.Push(ctrl)

    ProgressBar := MainGui.Add("Progress", "x200 y120 w330 h25 vProgressBar Hidden", 0)
    Step4Controls.Push(ProgressBar)

    ProgressText := MainGui.Add("Text", "x200 y155 w330 vProgressText Hidden", "Preparing...")
    Step4Controls.Push(ProgressText)
}

ShowStep1() {
    global Step1Controls
    for ctrl in Step1Controls
        ctrl.Visible := true
}
HideStep1() {
    global Step1Controls
    for ctrl in Step1Controls
        ctrl.Visible := false
}
ShowStep2() {
    global Step2Controls
    for ctrl in Step2Controls
        ctrl.Visible := true
}
HideStep2() {
    global Step2Controls
    for ctrl in Step2Controls
        ctrl.Visible := false
}
ShowStep3() {
    global Step3Controls
    for ctrl in Step3Controls
        ctrl.Visible := true
}
HideStep3() {
    global Step3Controls
    for ctrl in Step3Controls
        ctrl.Visible := false
}
ShowStep4() {
    global Step4Controls
    for ctrl in Step4Controls
        ctrl.Visible := true
}
HideStep4() {
    global Step4Controls
    for ctrl in Step4Controls
        ctrl.Visible := false
}

OnBackBtn(ctrl, info) {
    global CurrentStep
    if CurrentStep > 1 {
        CurrentStep--
        UpdateStep()
    }
}

OnNextBtn(ctrl, info) {
    global CurrentStep, MainGui, InstallPath

    if CurrentStep = 2 {
        InstallPath := MainGui["InstallPathEdit"].Value
        if InstallPath = "" {
            MsgBox("Please enter an installation path.", "Simple Transcriber Setup", "Icon!")
            return
        }
    }

    if CurrentStep = 3 {
        SaveOptions()
        CurrentStep++
        UpdateStep()
        StartInstallation()
        return
    }

    if CurrentStep < 4 {
        CurrentStep++
        UpdateStep()
    }
}

OnCancelBtn(ctrl, info) {
    CancelInstall()
}

OnGuiClose(gui) {
    CancelInstall()
}

CancelInstall() {
    global MainGui, InstallComplete
    if InstallComplete {
        ExitApp
    }
    result := MsgBox("Are you sure you want to cancel?", "Simple Transcriber Setup", "YesNo Icon?")
    if result = "Yes"
        ExitApp
}

UpdateStep() {
    global CurrentStep, MainGui

    HideStep1()
    HideStep2()
    HideStep3()
    HideStep4()

    switch CurrentStep {
        case 1: ShowStep1()
        case 2: ShowStep2()
        case 3: ShowStep3()
        case 4: ShowStep4()
    }

    MainGui["SideStep1"].SetFont(CurrentStep = 1 ? "Bold" : "Norm")
    MainGui["SideStep2"].SetFont(CurrentStep = 2 ? "Bold" : "Norm")
    MainGui["SideStep3"].SetFont(CurrentStep = 3 ? "Bold" : "Norm")
    MainGui["SideStep4"].SetFont(CurrentStep = 4 ? "Bold" : "Norm")

    MainGui["BackBtn"].Enabled := (CurrentStep > 1 && CurrentStep < 4)

    if CurrentStep = 1
        MainGui["NextBtn"].Enabled := MainGui["AcceptLicense"].Value
    else
        MainGui["NextBtn"].Enabled := (CurrentStep < 4)

    if CurrentStep = 3
        MainGui["NextBtn"].Text := "Install"
    else
        MainGui["NextBtn"].Text := "Next >"
}

OnBrowse(ctrl, info) {
    global MainGui, InstallPath
    folder := DirSelect("*" InstallPath, 3, "Select installation folder")
    if folder
        MainGui["InstallPathEdit"].Value := folder
}

SaveOptions() {
    global MainGui, CreateDesktopShortcut, CreateStartMenuShortcut, LaunchAfterInstall
    global RunOnStartup, StartMinimized, DownloadFFmpeg
    CreateDesktopShortcut := MainGui["DesktopShortcut"].Value
    CreateStartMenuShortcut := MainGui["StartMenuShortcut"].Value
    RunOnStartup := MainGui["RunOnStartup"].Value
    StartMinimized := MainGui["StartMinimized"].Value
    DownloadFFmpeg := MainGui["DownloadFFmpegCheck"].Value
    LaunchAfterInstall := MainGui["LaunchAfter"].Value
}

StartInstallation() {
    global MainGui, ProgressBar, ProgressText, InstallPath, SourceDir
    global CreateDesktopShortcut, CreateStartMenuShortcut, LaunchAfterInstall
    global RunOnStartup, StartMinimized, DownloadFFmpeg, InstallComplete

    MainGui["BackBtn"].Enabled := false
    MainGui["NextBtn"].Enabled := false
    MainGui["CancelBtn"].Enabled := false

    try {
        ProgressText.Value := "Creating installation folder..."
        ProgressBar.Value := 10
        Sleep(200)

        if !DirExist(InstallPath)
            DirCreate(InstallPath)

        ProgressText.Value := "Copying application files..."
        ProgressBar.Value := 30
        Sleep(200)

        if FileExist(SourceDir "\SimpleTranscriber.exe")
            FileCopy(SourceDir "\SimpleTranscriber.exe", InstallPath "\SimpleTranscriber.exe", true)
        else
            throw Error("SimpleTranscriber.exe not found")

        ProgressText.Value := "Copying configuration files..."
        ProgressBar.Value := 50
        Sleep(200)

        if FileExist(SourceDir "\settings.default.ini")
            FileCopy(SourceDir "\settings.default.ini", InstallPath "\settings.default.ini", true)

        if FileExist(SourceDir "\icon.ico")
            FileCopy(SourceDir "\icon.ico", InstallPath "\icon.ico", true)
        else if FileExist(SourceDir "\assets\icon.ico")
            FileCopy(SourceDir "\assets\icon.ico", InstallPath "\icon.ico", true)

        if FileExist(SourceDir "\Uninstall.exe")
            FileCopy(SourceDir "\Uninstall.exe", InstallPath "\Uninstall.exe", true)

        if DownloadFFmpeg {
            ProgressText.Value := "Downloading FFmpeg..."
            ProgressBar.Value := 55
            Sleep(200)

            ffmpegZipUrl := "https://github.com/GyanD/codexffmpeg/releases/download/7.1/ffmpeg-7.1-essentials_build.zip"
            ffmpegZipPath := InstallPath "\ffmpeg-download.zip"
            ffmpegExtractDir := InstallPath "\ffmpeg-extract"
            ffmpegTarget := InstallPath "\ffmpeg.exe"

            try {
                Download(ffmpegZipUrl, ffmpegZipPath)

                if FileExist(ffmpegZipPath) {
                    ProgressText.Value := "Extracting FFmpeg..."
                    ProgressBar.Value := 60
                    Sleep(200)

                    if DirExist(ffmpegExtractDir)
                        DirDelete(ffmpegExtractDir, true)
                    DirCreate(ffmpegExtractDir)

                    psCmd := "powershell.exe -NoProfile -Command `"Expand-Archive -Path '" ffmpegZipPath "' -DestinationPath '" ffmpegExtractDir "' -Force`""
                    RunWait(psCmd, , "Hide")

                    ; Find ffmpeg.exe in extracted folder
                    found := ""
                    loop files ffmpegExtractDir "\*\bin\ffmpeg.exe", "R" {
                        found := A_LoopFileFullPath
                        break
                    }
                    if found = "" {
                        loop files ffmpegExtractDir "\ffmpeg.exe", "R" {
                            found := A_LoopFileFullPath
                            break
                        }
                    }

                    if found != "" {
                        FileCopy(found, ffmpegTarget, true)
                        ProgressText.Value := "FFmpeg installed successfully"
                    }

                    ; Clean up download artifacts
                    try FileDelete(ffmpegZipPath)
                    try DirDelete(ffmpegExtractDir, true)
                }
            } catch as e {
                ; FFmpeg download is optional - don't fail the whole install
                ProgressText.Value := "FFmpeg download skipped (can be installed later)"
                Sleep(1000)
            }
        }

        ProgressText.Value := "Creating shortcuts..."
        ProgressBar.Value := 70
        Sleep(200)

        exePath := InstallPath "\SimpleTranscriber.exe"
        iconPath := FileExist(InstallPath "\icon.ico") ? InstallPath "\icon.ico" : exePath

        if CreateDesktopShortcut
            CreateShortcut(A_Desktop "\Simple Transcriber.lnk", exePath, InstallPath, iconPath)

        if CreateStartMenuShortcut {
            startMenuFolder := A_Programs "\Simple Transcriber"
            if !DirExist(startMenuFolder)
                DirCreate(startMenuFolder)
            CreateShortcut(startMenuFolder "\Simple Transcriber.lnk", exePath, InstallPath, iconPath)
            if FileExist(InstallPath "\Uninstall.exe")
                CreateShortcut(startMenuFolder "\Uninstall Simple Transcriber.lnk", InstallPath "\Uninstall.exe", InstallPath, InstallPath "\Uninstall.exe")
        }

        ProgressText.Value := "Creating registry entries..."
        ProgressBar.Value := 85
        Sleep(200)

        regKey := "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SimpleTranscriber"
        RegWrite("Simple Transcriber", "REG_SZ", regKey, "DisplayName")
        RegWrite(InstallPath "\Uninstall.exe", "REG_SZ", regKey, "UninstallString")
        RegWrite(iconPath, "REG_SZ", regKey, "DisplayIcon")
        RegWrite("Jamie Bykov-Brett", "REG_SZ", regKey, "Publisher")
        RegWrite(CurrentInstallerVersion, "REG_SZ", regKey, "DisplayVersion")
        RegWrite(InstallPath, "REG_SZ", regKey, "InstallLocation")

        ProgressText.Value := "Applying settings..."
        ProgressBar.Value := 90
        Sleep(200)

        appDataDir := A_AppData "\Simple Transcriber"
        if !DirExist(appDataDir)
            DirCreate(appDataDir)
        settingsFile := appDataDir "\settings.ini"
        IniWrite(StartMinimized ? "1" : "0", settingsFile, "General", "StartMinimized")

        if RunOnStartup {
            startupKey := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
            RegWrite('"' exePath '" /startup', "REG_SZ", startupKey, "SimpleTranscriber")
        }

        ProgressText.Value := "Installation complete!"
        ProgressBar.Value := 100
        Sleep(500)

        InstallComplete := true

        MainGui["Step4Title"].Value := "Installation Complete"
        MainGui["Step4Desc"].Value := "Simple Transcriber has been successfully installed.`n`nDrag and drop audio or video files onto the window to transcribe them to text."

        MainGui["CancelBtn"].Text := "Finish"
        MainGui["CancelBtn"].Enabled := true

        if LaunchAfterInstall
            SetTimer () => LaunchApp(exePath), -2000

    } catch as e {
        MsgBox("Installation failed: " e.Message, "Simple Transcriber Setup", "IconX")
        MainGui["CancelBtn"].Enabled := true
    }
}

LaunchApp(exePath) {
    try Run('explorer.exe "' exePath '"')
}

CreateShortcut(shortcutPath, targetPath, workingDir, iconPath) {
    try {
        shell := ComObject("WScript.Shell")
        shortcut := shell.CreateShortcut(shortcutPath)
        shortcut.TargetPath := targetPath
        shortcut.WorkingDirectory := workingDir
        shortcut.IconLocation := iconPath
        shortcut.Description := "Audio/Video to Text Transcription Tool"
        shortcut.Save()
    }
}
