#Requires AutoHotkey v2.0

/**
 * UpdateManager - Handles version checking, auto-updates, and usage analytics
 */
class UpdateManager {
    static GitHubRepo := "Netropolitan/Simple-Transcriber"
    static GitHubAPI := "https://api.github.com/repos/" . UpdateManager.GitHubRepo . "/releases/latest"
    static CurrentVersion := "1.0.1"

    static AnalyticsEndpoint := "https://brew.taila07ff3.ts.net/api/simpletranscriber/event"
    static AppName := "Simple-Transcriber"

    static LatestVersion := ""
    static DownloadUrl := ""
    static ReleaseNotes := ""
    static LastCheckTime := 0

    static InitializeAutoCheck(config, isFirstLaunch := false) {
        autoUpdateEnabled := config.Get("Updates", "AutoCheck", "1") = "1"
        if !autoUpdateEnabled
            return

        lastCheckStr := config.Get("Updates", "LastAutoCheck", "")
        currentYear := A_Year
        currentMonth := A_Mon
        currentDay := A_MDay
        currentHour := A_Hour

        shouldCheck := false
        currentMonthKey := currentYear . "-" . Format("{:02}", currentMonth)

        if lastCheckStr = "" {
            shouldCheck := true
        } else {
            if lastCheckStr != currentMonthKey {
                if currentDay >= 1 {
                    if currentDay = 1 {
                        if currentHour >= 14
                            shouldCheck := true
                    } else {
                        shouldCheck := true
                    }
                }
            }
        }

        if shouldCheck {
            SetTimer(() => this.DoAutoCheck(config), -5000)
        }

        analyticsEnabled := config.Get("Updates", "Analytics", "1") = "1"
        if analyticsEnabled && this.AnalyticsEndpoint != "" {
            eventType := isFirstLaunch ? "install" : "startup"
            SetTimer(() => this.SendAnalyticsPing(config, eventType), -10000)
        }
    }

    static DoAutoCheck(config) {
        result := this.CheckForUpdates()
        currentMonthKey := A_Year . "-" . Format("{:02}", A_Mon)
        config.Set("Updates", "LastAutoCheck", currentMonthKey)

        if result.available {
            TrayTip("Update Available", "Simple Transcriber v" . result.version . " is available. Open Settings to update.", 1)
        }
    }

    static SendAnalyticsPing(config, eventType := "active") {
        if this.AnalyticsEndpoint = ""
            return

        try {
            installId := config.Get("Updates", "InstallId", "")
            if installId = "" {
                installId := this.GenerateInstallId()
                config.Set("Updates", "InstallId", installId)
            }

            if eventType = "install"
                eventType := "download"
            else if eventType = "startup"
                eventType := "active"

            osVersion := "Windows " . A_OSVersion

            payload := '{'
            payload .= '"event_type":"' . eventType . '",'
            payload .= '"version":"' . this.CurrentVersion . '",'
            payload .= '"machine_id":"' . installId . '",'
            payload .= '"os_version":"' . osVersion . '"'
            payload .= '}'

            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("POST", this.AnalyticsEndpoint, true)
            whr.SetRequestHeader("Content-Type", "application/json")
            whr.SetRequestHeader("User-Agent", "Simple-Transcriber/" . this.CurrentVersion)
            whr.SetTimeouts(5000, 5000, 5000, 5000)
            whr.Send(payload)
            whr.WaitForResponse(5)
        } catch {
        }
    }

    static GenerateInstallId() {
        chars := "0123456789abcdef"
        id := ""
        Loop 36 {
            if A_Index = 9 || A_Index = 14 || A_Index = 19 || A_Index = 24
                id .= "-"
            else if A_Index = 15
                id .= "4"
            else if A_Index = 20
                id .= SubStr("89ab", Random(1, 4), 1)
            else
                id .= SubStr(chars, Random(1, 16), 1)
        }
        return id
    }

    static GetInstallId(config) {
        return config.Get("Updates", "InstallId", "Not generated")
    }

    static CheckForUpdates() {
        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("GET", this.GitHubAPI, true)
            whr.SetRequestHeader("User-Agent", "Simple-Transcriber/" . this.CurrentVersion)
            whr.SetTimeouts(10000, 10000, 10000, 10000)
            whr.Send()
            whr.WaitForResponse(10)

            if whr.Status = 404
                return {available: false, version: "", error: "No releases found."}
            if whr.Status != 200
                return {available: false, version: "", error: "GitHub API returned status " . whr.Status}

            response := whr.ResponseText
            data := JSON.Load(response)

            if !data || !data.Has("tag_name")
                return {available: false, version: "", error: "Invalid response from GitHub"}

            latestVersion := data["tag_name"]
            if SubStr(latestVersion, 1, 1) = "v"
                latestVersion := SubStr(latestVersion, 2)

            this.LatestVersion := latestVersion
            this.LastCheckTime := A_TickCount

            if data.Has("body")
                this.ReleaseNotes := data["body"]

            if data.Has("assets") {
                for asset in data["assets"] {
                    if asset.Has("name") && InStr(asset["name"], "Setup.exe") {
                        this.DownloadUrl := asset["browser_download_url"]
                        break
                    }
                }
                if this.DownloadUrl = "" {
                    for asset in data["assets"] {
                        if asset.Has("name") && InStr(asset["name"], ".exe") {
                            this.DownloadUrl := asset["browser_download_url"]
                            break
                        }
                    }
                }
            }

            if this.DownloadUrl = "" {
                tag := data.Has("tag_name") ? data["tag_name"] : "v" . latestVersion
                this.DownloadUrl := "https://github.com/" . this.GitHubRepo . "/releases/download/" . tag . "/SimpleTranscriber-Setup.exe"
            }

            if this.CompareVersions(latestVersion, this.CurrentVersion) > 0
                return {available: true, version: latestVersion, error: ""}
            else
                return {available: false, version: latestVersion, error: ""}
        } catch as e {
            return {available: false, version: "", error: "Check failed: " . e.Message}
        }
    }

    static CompareVersions(v1, v2) {
        v1 := RegExReplace(v1, "-.*$", "")
        v2 := RegExReplace(v2, "-.*$", "")
        parts1 := StrSplit(v1, ".")
        parts2 := StrSplit(v2, ".")
        while parts1.Length < 3
            parts1.Push("0")
        while parts2.Length < 3
            parts2.Push("0")
        Loop 3 {
            n1 := this.ParseVersionPart(parts1[A_Index])
            n2 := this.ParseVersionPart(parts2[A_Index])
            if n1 > n2
                return 1
            if n1 < n2
                return -1
        }
        return 0
    }

    static ParseVersionPart(part) {
        if RegExMatch(part, "^(\d+)", &match)
            return Integer(match[1])
        return 0
    }

    static DownloadWithRedirect(url, savePath) {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", url, true)
        whr.SetRequestHeader("User-Agent", "Simple-Transcriber/" . this.CurrentVersion)
        whr.SetTimeouts(30000, 30000, 30000, 60000)
        whr.Send()
        whr.WaitForResponse(60)

        if whr.Status = 302 || whr.Status = 301 {
            redirectUrl := whr.GetResponseHeader("Location")
            if redirectUrl {
                whr := ComObject("WinHttp.WinHttpRequest.5.1")
                whr.Open("GET", redirectUrl, true)
                whr.SetRequestHeader("User-Agent", "Simple-Transcriber/" . this.CurrentVersion)
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

    static DownloadUpdate(progressCallback := "") {
        if this.DownloadUrl = "" {
            result := MsgBox("The update doesn't have an installer file attached yet.`n`nWould you like to open the GitHub releases page?", "Download Not Available", "YesNo Icon!")
            if result = "Yes"
                this.OpenReleasesPage()
            return {success: false, path: "", error: "No installer attached"}
        }

        try {
            tempPath := A_Temp . "\SimpleTranscriber-Setup-" . this.LatestVersion . ".exe"
            if FileExist(tempPath)
                FileDelete(tempPath)

            if progressCallback
                progressCallback(0, "Connecting...")

            this.DownloadWithRedirect(this.DownloadUrl, tempPath)

            if progressCallback
                progressCallback(100, "Download complete")

            if FileExist(tempPath) {
                if FileGetSize(tempPath) > 10000
                    return {success: true, path: tempPath, error: ""}
                else {
                    FileDelete(tempPath)
                    return this.OfferManualDownload("Downloaded file appears invalid")
                }
            } else {
                return this.OfferManualDownload("Download failed")
            }
        } catch as e {
            return this.OfferManualDownload("Download failed: " . e.Message)
        }
    }

    static OfferManualDownload(reason) {
        result := MsgBox(reason . "`n`nWould you like to open the GitHub releases page?", "Download Failed", "YesNo Icon!")
        if result = "Yes"
            this.OpenReleasesPage()
        return {success: false, path: "", error: reason}
    }

    static InstallUpdate(installerPath) {
        if !FileExist(installerPath) {
            MsgBox("Installer not found.", "Update Error", "IconX")
            return
        }

        installDir := ""
        if A_IsCompiled
            installDir := A_ScriptDir

        try {
            if installDir != ""
                Run('"' . installerPath . '" /upgrade "' . installDir . '"')
            else
                Run('"' . installerPath . '" /upgrade')
            ExitApp
        } catch as e {
            MsgBox("Failed to launch installer: " . e.Message, "Update Error", "IconX")
        }
    }

    static OpenReleasesPage() {
        Run("https://github.com/" . this.GitHubRepo . "/releases")
    }
}
