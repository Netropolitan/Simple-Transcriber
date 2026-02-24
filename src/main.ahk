#Requires AutoHotkey v2.0
#SingleInstance Force

; Set DPI awareness before any GUI operations
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

; Compiler directives for EXE
;@Ahk2Exe-SetName Simple Transcriber
;@Ahk2Exe-SetDescription Audio/Video to Text Transcription Tool
;@Ahk2Exe-SetVersion 1.0.1
;@Ahk2Exe-SetCopyright Copyright (c) 2026 Jamie Bykov-Brett
;@Ahk2Exe-SetCompanyName Bykov-Brett Enterprises

; Core libraries
#Include lib\cJson.ahk
#Include core\config.ahk
#Include core\http.ahk
#Include core\credentials.ahk
#Include core\ffmpeg.ahk
#Include core\transcriber.ahk
#Include core\updater.ahk

; Providers
#Include providers\stt-base.ahk
#Include providers\stt-whisper.ahk
#Include providers\stt-factory.ahk

; UI
#Include ui\tray.ahk
#Include ui\theme.ahk
#Include ui\settings.ahk
#Include ui\main-window.ahk

; Application initialization
global AppConfig := ConfigManager()

; Initialize theme manager
ThemeManager.Load(AppConfig)

; Initialize system tray
TrayManager.Initialize()

; Initialize main window
MainWindow.Initialize(AppConfig)

; Check if this is the first launch
isFirstLaunch := AppConfig.Get("General", "FirstLaunch", "1") = "1"

; Mark first launch as done
AppConfig.Set("General", "FirstLaunch", "0")

; Detect /startup flag from command line args
isStartupLaunch := false
for arg in A_Args {
    if arg = "/startup" || arg = "-startup" || arg = "--startup" {
        isStartupLaunch := true
        break
    }
}

; Check StartMinimized setting
startMinimized := AppConfig.Get("General", "StartMinimized", "0") = "1"

; Show main window (unless startup launch with minimize enabled)
if !(isStartupLaunch && startMinimized) {
    SetTimer(() => MainWindow.Show(), -200)
}

; Show settings on first launch so user can configure API key
if isFirstLaunch {
    SetTimer(() => SettingsWindow.Show(), -500)
}

; Initialize auto-update check and analytics
UpdateManager.InitializeAutoCheck(AppConfig, isFirstLaunch)

; Clean up old temp files on startup
FFmpegManager.CleanupTempAudio()

; Keep script running
Persistent
