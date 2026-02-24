#Requires AutoHotkey v2.0
#SingleInstance Force

;@Ahk2Exe-SetName Simple Transcriber Uninstaller
;@Ahk2Exe-SetDescription Simple Transcriber Uninstaller
;@Ahk2Exe-SetVersion 1.0.1
;@Ahk2Exe-SetCopyright Copyright (c) 2026 Jamie Bykov-Brett

if !A_IsAdmin {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
        ExitApp
    } catch {
        MsgBox("This uninstaller requires administrator privileges.", "Administrator Required", "IconX")
        ExitApp
    }
}

global MainGui := ""
global CurrentStep := 1
global RemoveSettings := true
global RemoveShortcuts := true
global UninstallComplete := false

global Step1Controls := []
global Step2Controls := []
global Step3Controls := []
global ProgressBar := ""
global ProgressText := ""

global InstallPath := DetectInstallPath()

SetupUninstaller()

DetectInstallPath() {
    try {
        path := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SimpleTranscriber", "InstallLocation")
        if path && DirExist(path)
            return path
    }
    return A_ScriptDir
}

SetupUninstaller() {
    global MainGui

    MainGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", "Uninstall Simple Transcriber")
    MainGui.SetFont("s10", "Segoe UI")
    MainGui.BackColor := "FFFFFF"

    MainGui.Add("Text", "x0 y0 w180 h350 BackgroundDC2626")

    MainGui.SetFont("Bold s14 cFFFFFF")
    MainGui.Add("Text", "x15 y20 w150 BackgroundTrans", "Simple")
    MainGui.SetFont("Bold s14 cFFFFFF")
    MainGui.Add("Text", "x15 y38 w150 BackgroundTrans", "Transcriber")
    MainGui.SetFont("Norm s9 cFFFFFF")
    MainGui.Add("Text", "x15 y58 w150 BackgroundTrans", "Uninstall Wizard")

    MainGui.SetFont("s10 cFFFFFF")
    MainGui.Add("Text", "x15 y100 w150 BackgroundTrans vSideStep1", "1. Confirm")
    MainGui.Add("Text", "x15 y130 w150 BackgroundTrans vSideStep2", "2. Options")
    MainGui.Add("Text", "x15 y160 w150 BackgroundTrans vSideStep3", "3. Uninstall")

    MainGui.SetFont("Norm s10 c000000", "Segoe UI")

    BuildStep1()
    BuildStep2()
    BuildStep3()
    ShowStep1()
    HideStep2()
    HideStep3()

    MainGui.Add("Button", "x200 y310 w80 h30 vBackBtn", "< Back").OnEvent("Click", OnBackBtn)
    MainGui.Add("Button", "x290 y310 w80 h30 vNextBtn", "Next >").OnEvent("Click", OnNextBtn)
    MainGui.Add("Button", "x420 y310 w80 h30 vCancelBtn", "Cancel").OnEvent("Click", OnCancelBtn)

    MainGui["BackBtn"].Enabled := false

    MainGui.OnEvent("Close", OnGuiClose)
    MainGui.OnEvent("Escape", OnGuiClose)
    MainGui.Show("w520 h350")
}

BuildStep1() {
    global MainGui, Step1Controls, InstallPath
    MainGui.SetFont("Bold s14")
    ctrl := MainGui.Add("Text", "x200 y30 w300 vStep1Title", "Uninstall Simple Transcriber?")
    Step1Controls.Push(ctrl)
    MainGui.SetFont("Norm s10")
    ctrl := MainGui.Add("Text", "x200 y70 w300 vStep1Desc", "This will remove Simple Transcriber from your computer.`n`nInstall location:`n" InstallPath)
    Step1Controls.Push(ctrl)
    ctrl := MainGui.Add("Text", "x200 y180 w300 c666666 vStep1Note", "Click Next to choose uninstall options.")
    Step1Controls.Push(ctrl)
}

BuildStep2() {
    global MainGui, Step2Controls
    MainGui.SetFont("Bold s14")
    ctrl := MainGui.Add("Text", "x200 y30 w300 vStep2Title Hidden", "Uninstall Options")
    Step2Controls.Push(ctrl)
    MainGui.SetFont("Norm s10")
    ctrl := MainGui.Add("Text", "x200 y70 w300 vStep2Desc Hidden", "Choose what to remove:")
    Step2Controls.Push(ctrl)
    ctrl := MainGui.Add("Checkbox", "x200 y110 w300 vRemoveSettingsCheck Checked Hidden", "Remove settings (stored in AppData)")
    Step2Controls.Push(ctrl)
    ctrl := MainGui.Add("Checkbox", "x200 y140 w300 vRemoveShortcutsCheck Checked Hidden", "Remove desktop and Start Menu shortcuts")
    Step2Controls.Push(ctrl)
}

BuildStep3() {
    global MainGui, Step3Controls, ProgressBar, ProgressText
    MainGui.SetFont("Bold s14")
    ctrl := MainGui.Add("Text", "x200 y30 w300 vStep3Title Hidden", "Uninstalling")
    Step3Controls.Push(ctrl)
    MainGui.SetFont("Norm s10")
    ctrl := MainGui.Add("Text", "x200 y70 w300 vStep3Desc Hidden", "Please wait while Simple Transcriber is being removed...")
    Step3Controls.Push(ctrl)
    ProgressBar := MainGui.Add("Progress", "x200 y120 w300 h25 vProgressBar Hidden cDC2626", 0)
    Step3Controls.Push(ProgressBar)
    ProgressText := MainGui.Add("Text", "x200 y155 w300 vProgressText Hidden", "Preparing...")
    Step3Controls.Push(ProgressText)
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

OnBackBtn(ctrl, info) {
    global CurrentStep
    if CurrentStep > 1 {
        CurrentStep--
        UpdateStep()
    }
}

OnNextBtn(ctrl, info) {
    global CurrentStep, MainGui, RemoveSettings, RemoveShortcuts
    if CurrentStep = 2 {
        RemoveSettings := MainGui["RemoveSettingsCheck"].Value
        RemoveShortcuts := MainGui["RemoveShortcutsCheck"].Value
        CurrentStep++
        UpdateStep()
        StartUninstall()
        return
    }
    if CurrentStep < 3 {
        CurrentStep++
        UpdateStep()
    }
}

OnCancelBtn(ctrl, info) {
    CancelUninstall()
}

OnGuiClose(gui) {
    CancelUninstall()
}

CancelUninstall() {
    global MainGui, UninstallComplete
    if UninstallComplete {
        batchPath := A_Temp "\uninstall_cleanup.bat"
        if FileExist(batchPath)
            try Run(batchPath, , "Hide")
        ExitApp
    }
    result := MsgBox("Are you sure you want to cancel?", "Uninstall Simple Transcriber", "YesNo Icon?")
    if result = "Yes"
        ExitApp
}

UpdateStep() {
    global CurrentStep, MainGui
    HideStep1()
    HideStep2()
    HideStep3()
    switch CurrentStep {
        case 1: ShowStep1()
        case 2: ShowStep2()
        case 3: ShowStep3()
    }
    MainGui["SideStep1"].SetFont(CurrentStep = 1 ? "Bold" : "Norm")
    MainGui["SideStep2"].SetFont(CurrentStep = 2 ? "Bold" : "Norm")
    MainGui["SideStep3"].SetFont(CurrentStep = 3 ? "Bold" : "Norm")
    MainGui["BackBtn"].Enabled := (CurrentStep > 1 && CurrentStep < 3)
    MainGui["NextBtn"].Enabled := (CurrentStep < 3)
    if CurrentStep = 2
        MainGui["NextBtn"].Text := "Uninstall"
    else
        MainGui["NextBtn"].Text := "Next >"
}

StartUninstall() {
    global MainGui, ProgressBar, ProgressText, InstallPath, RemoveSettings, RemoveShortcuts
    global UninstallComplete

    MainGui["BackBtn"].Enabled := false
    MainGui["NextBtn"].Enabled := false
    MainGui["CancelBtn"].Enabled := false

    try {
        ProgressText.Value := "Closing Simple Transcriber..."
        ProgressBar.Value := 10
        Sleep(200)
        DetectHiddenWindows(true)
        try WinClose("Simple Transcriber Settings")
        try RunWait('taskkill /F /IM "SimpleTranscriber.exe"',, "Hide")

        ProgressText.Value := "Removing startup entry..."
        ProgressBar.Value := 20
        try RegDelete("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run", "SimpleTranscriber")

        if RemoveShortcuts {
            ProgressText.Value := "Removing shortcuts..."
            ProgressBar.Value := 35
            try FileDelete(A_Desktop "\Simple Transcriber.lnk")
            startMenuFolder := A_Programs "\Simple Transcriber"
            if DirExist(startMenuFolder)
                try DirDelete(startMenuFolder, true)
        }

        if RemoveSettings {
            ProgressText.Value := "Removing settings..."
            ProgressBar.Value := 50
            appDataDir := A_AppData "\Simple Transcriber"
            if DirExist(appDataDir)
                try DirDelete(appDataDir, true)
        }

        ProgressText.Value := "Removing registry entries..."
        ProgressBar.Value := 65
        try RunWait('reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SimpleTranscriber" /f', , "Hide")

        ProgressText.Value := "Removing program files..."
        ProgressBar.Value := 80
        if InstallPath && DirExist(InstallPath) {
            batchPath := A_Temp "\uninstall_cleanup.bat"
            batchContent := "@echo off`r`ntimeout /t 2 /nobreak >nul`r`n"
            batchContent .= 'rd /s /q "' InstallPath '"`r`ndel "%~f0"`r`n'
            try FileDelete(batchPath)
            FileAppend(batchContent, batchPath)
        }

        ProgressText.Value := "Uninstall complete!"
        ProgressBar.Value := 100
        Sleep(500)

        UninstallComplete := true
        MainGui["Step3Title"].Value := "Uninstall Complete"
        MainGui["Step3Desc"].Value := "Simple Transcriber has been removed.`nThe program folder will be deleted when you close this window."
        MainGui["CancelBtn"].Text := "Finish"
        MainGui["CancelBtn"].Enabled := true
    } catch as e {
        MsgBox("Uninstall error: " e.Message, "Uninstall Simple Transcriber", "IconX")
        MainGui["CancelBtn"].Enabled := true
    }
}
