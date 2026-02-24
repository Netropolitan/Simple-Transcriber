/**
 * SettingsWindow - Settings GUI for Simple Transcriber
 *
 * Sections: Whisper Provider (OpenAI / Local), Output, About
 */
class SettingsWindow {
    static Gui := ""
    static CurrentVersion := "1.0.1"
    static GitHubRepo := "https://github.com/Netropolitan/Simple-Transcriber"

    ; Control references
    static OpenAIRadio := ""
    static LocalRadio := ""
    static BaseUrlEdit := ""
    static ApiKeyLabel := ""
    static ApiKeyEdit := ""
    static ShowKeyBtn := ""
    static ModelEdit := ""
    static TestBtn := ""
    static OutputFolderEdit := ""
    static FFmpegStatusText := ""
    static UpdateStatusText := ""
    static UpdateBtn := ""

    ; Y positions for dynamic layout
    static ApiKeyY := 0
    static ModelY := 0

    /**
     * Show settings window
     */
    static Show() {
        if this.Gui {
            WinActivate(this.Gui)
            return
        }

        DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

        this.Gui := Gui("+OwnDialogs", "Simple Transcriber - Settings")
        this.Gui.SetFont("s10", "Segoe UI")
        ThemeManager.Apply(this.Gui)

        y := 15
        x := 20
        w := 510

        ; === Whisper Provider Section ===
        this.Gui.SetFont("Bold s11")
        this.Gui.Add("Text", "x" x " y" y " w" w, "Whisper Provider")
        this.Gui.SetFont("Norm s10")
        y += 28

        ; Radio buttons
        currentProvider := AppConfig.Get("General", "Provider", "openai")
        this.OpenAIRadio := this.Gui.Add("Radio", "x" x " y" y " w200 vProvider Group", "OpenAI")
        this.LocalRadio := this.Gui.Add("Radio", "x" (x+250) " y" y " w200", "Local Whisper Server")
        if currentProvider = "local"
            this.LocalRadio.Value := 1
        else
            this.OpenAIRadio.Value := 1
        this.OpenAIRadio.OnEvent("Click", (*) => this._OnProviderChange())
        this.LocalRadio.OnEvent("Click", (*) => this._OnProviderChange())
        y += 32

        ; Server URL
        this.Gui.Add("Text", "x" x " y" y, "Server URL:")
        this.BaseUrlEdit := this.Gui.Add("Edit", "x" (x+100) " y" (y-3) " w" (w-100) " vBaseUrl")
        y += 32

        ; API Key (only visible for OpenAI)
        this.ApiKeyY := y
        this.ApiKeyLabel := this.Gui.Add("Text", "x" x " y" y, "API Key:")
        this.ApiKeyEdit := this.Gui.Add("Edit", "x" (x+100) " y" (y-3) " w" (w-180) " Password vApiKey")
        this.ShowKeyBtn := this.Gui.Add("Button", "x" (x+w-70) " y" (y-4) " w70 h26", "S&how")
        this.ShowKeyBtn.OnEvent("Click", (*) => this._ToggleApiKeyVisibility(this.ShowKeyBtn))
        y += 32

        ; Model
        this.ModelY := y
        this.Gui.Add("Text", "x" x " y" y, "Model:")
        this.ModelEdit := this.Gui.Add("Edit", "x" (x+100) " y" (y-3) " w" (w-180) " vModel")
        this.TestBtn := this.Gui.Add("Button", "x" (x+w-70) " y" (y-4) " w70 h26", "&Test")
        this.TestBtn.OnEvent("Click", (*) => this._TestConnection())
        y += 40

        ; Load the active provider's values into the fields
        this._LoadProviderFields()

        ; === Output Section ===
        this.Gui.SetFont("Bold s11")
        this.Gui.Add("Text", "x" x " y" y " w" w, "Output")
        this.Gui.SetFont("Norm s10")
        y += 28

        this.Gui.Add("Text", "x" x " y" y, "Output folder:")
        this.OutputFolderEdit := this.Gui.Add("Edit", "x" (x+100) " y" (y-3) " w" (w-170) " vOutputFolder")
        this.OutputFolderEdit.Value := AppConfig.Get("Output", "OutputFolder", "")
        browseBtn := this.Gui.Add("Button", "x" (x+w-60) " y" (y-4) " w60 h26", "...")
        browseBtn.OnEvent("Click", (*) => this._BrowseOutputFolder())
        y += 32

        y += 8

        ; === FFmpeg Section ===
        this.Gui.SetFont("Bold s11")
        this.Gui.Add("Text", "x" x " y" y " w" w, "FFmpeg")
        this.Gui.SetFont("Norm s10")
        y += 28

        ffmpegAvailable := FFmpegManager.IsAvailable(AppConfig)
        statusStr := ffmpegAvailable ? "Installed" : "Not found"
        this.FFmpegStatusText := this.Gui.Add("Text", "x" x " y" y " w300", "Status: " statusStr)
        if !ffmpegAvailable {
            downloadBtn := this.Gui.Add("Button", "x" (x+320) " y" (y-4) " w120 h26", "Download FFmpeg")
            downloadBtn.OnEvent("Click", (*) => this._DownloadFFmpeg())
        }
        y += 40

        ; === About Section ===
        this.Gui.SetFont("Bold s11")
        this.Gui.Add("Text", "x" x " y" y " w" w, "About")
        this.Gui.SetFont("Norm s10")
        y += 28

        this.Gui.Add("Text", "x" x " y" y, "Simple Transcriber v" this.CurrentVersion)
        y += 22
        this.Gui.Add("Text", "x" x " y" y, "(c) 2026 Jamie Bykov-Brett")
        y += 22
        this.Gui.Add("Text", "x" x " y" y " c666666", "Audio/Video to Text Transcription Tool")
        y += 22

        repoLink := this.Gui.Add("Link", "x" x " y" y, '<a href="' this.GitHubRepo '">GitHub Repository</a>')
        y += 22

        this.Gui.Add("Text", "x" x " y" y " c666666 w" w, "Licensed under CC BY-NC-ND 4.0")
        y += 30

        ; Check for Updates button and status
        this.UpdateBtn := this.Gui.Add("Button", "x" x " y" y " w150 h28", "Check for &Updates")
        this.UpdateBtn.OnEvent("Click", (*) => this._OnCheckForUpdates())
        this.UpdateStatusText := this.Gui.Add("Text", "x" (x+160) " y" (y+5) " w" (w-160) " c666666", "")
        y += 32

        ; Disclaimer button
        disclaimerBtn := this.Gui.Add("Button", "x" x " y" y " w100 h28", "&Disclaimer")
        disclaimerBtn.OnEvent("Click", (*) => this._ShowDisclaimer())
        y += 40

        ; Save / Close buttons
        saveBtn := this.Gui.Add("Button", "x" (x + w - 230) " y" y " w110 h30", "&Save Settings")
        saveBtn.OnEvent("Click", (*) => this._OnSave())

        closeBtn := this.Gui.Add("Button", "x" (x + w - 110) " y" y " w110 h30", "C&lose")
        closeBtn.OnEvent("Click", (*) => this.Close())

        y += 45
        this.Gui.OnEvent("Close", (*) => this.Close())
        this.Gui.OnEvent("Escape", (*) => this.Close())
        this.Gui.Show("w" (x * 2 + w) " h" y)
    }

    /**
     * Get the currently selected provider
     */
    static _GetSelectedProvider() {
        return this.LocalRadio.Value ? "local" : "openai"
    }

    /**
     * Get the config section name for a provider
     */
    static _GetSection(provider) {
        return provider = "local" ? "LocalWhisper" : "OpenAI"
    }

    /**
     * Get the credential key for a provider
     */
    static _GetCredentialKey(provider) {
        return "openai"  ; Only OpenAI uses credentials
    }

    /**
     * Load field values for the currently selected provider
     */
    static _LoadProviderFields() {
        provider := this._GetSelectedProvider()
        section := this._GetSection(provider)

        defaultUrl := provider = "local" ? "http://localhost:8080" : "https://api.openai.com"
        this.BaseUrlEdit.Value := AppConfig.Get(section, "BaseUrl", defaultUrl)
        this.ModelEdit.Value := AppConfig.Get(section, "Model", "whisper-1")

        if provider = "openai" {
            ; Show API key row
            this.ApiKeyLabel.Visible := true
            this.ApiKeyEdit.Visible := true
            this.ShowKeyBtn.Visible := true
            maskedKey := CredentialManager.GetMasked("openai")
            ; Fall back to legacy "whisper" credential if "openai" has nothing
            if maskedKey = ""
                maskedKey := CredentialManager.GetMasked("whisper")
            this.ApiKeyEdit.Opt("+Password")
            this.ApiKeyEdit.Value := maskedKey
            this.ShowKeyBtn.Text := "Show"
        } else {
            ; Hide API key row
            this.ApiKeyLabel.Visible := false
            this.ApiKeyEdit.Visible := false
            this.ShowKeyBtn.Visible := false
        }
    }

    /**
     * Handle provider radio button change
     */
    static _OnProviderChange() {
        this._LoadProviderFields()
    }

    /**
     * Toggle API key visibility
     */
    static _ToggleApiKeyVisibility(btn) {
        if InStr(btn.Text, "how") {
            key := CredentialManager.Retrieve("openai")
            ; Fall back to legacy "whisper" credential
            if key = ""
                key := CredentialManager.Retrieve("whisper")
            if key != "" {
                this.ApiKeyEdit.Opt("-Password")
                this.ApiKeyEdit.Value := key
                btn.Text := "&Hide"
            }
        } else {
            maskedKey := CredentialManager.GetMasked("openai")
            if maskedKey = ""
                maskedKey := CredentialManager.GetMasked("whisper")
            this.ApiKeyEdit.Opt("+Password")
            this.ApiKeyEdit.Value := maskedKey
            btn.Text := "S&how"
        }
    }

    /**
     * Test connection to Whisper server
     */
    static _TestConnection() {
        provider := this._GetSelectedProvider()
        baseUrl := this.BaseUrlEdit.Value
        model := this.ModelEdit.Value

        if provider = "openai" {
            apiKey := CredentialManager.Retrieve("openai")
            if apiKey = ""
                apiKey := CredentialManager.Retrieve("whisper")
            stt := STTWhisper(baseUrl, model, apiKey)
            result := stt.TestConnection()
            if result.available
                MsgBox("Connection successful!", "Test Connection", "Iconi")
            else
                MsgBox("Connection failed:`n" result.error, "Test Connection", "Icon!")
            return
        }

        ; Local provider: run endpoint discovery
        stt := STTWhisper(baseUrl, model, "")
        result := stt.TestConnection(true)

        if !result.available {
            if result.checked.Length > 0 {
                ; Server reachable but no endpoint found
                msg := result.error "`n`nChecked:`n"
                for entry in result.checked
                    msg .= "  " entry "`n"
                MsgBox(msg, "Test Connection", "Icon!")
            } else {
                ; Server unreachable
                MsgBox(result.error, "Test Connection", "Icon!")
            }
            return
        }

        ; Success — build result message
        msg := "Connection successful!`n"

        if result.serverType != ""
            msg .= "`nServer type: " result.serverType

        msg .= "`nEndpoint: " result.endpointPath

        if result.models.Length > 0 {
            modelList := ""
            for m in result.models {
                if modelList != ""
                    modelList .= ", "
                modelList .= m
            }
            msg .= "`nAvailable models: " modelList
        }

        if result.docsUrl != ""
            msg .= "`nAPI docs: " result.docsUrl

        ; Auto-save the discovered endpoint path
        AppConfig.Set("LocalWhisper", "EndpointPath", result.endpointPath)
        msg .= "`n`nThe endpoint path has been saved."

        ; Auto-update model if current model isn't available on the server
        if result.models.Length > 0 {
            currentModel := this.ModelEdit.Value
            modelFound := false
            for m in result.models {
                if m = currentModel {
                    modelFound := true
                    break
                }
            }
            if !modelFound {
                this.ModelEdit.Value := result.models[1]
                AppConfig.Set("LocalWhisper", "Model", result.models[1])
                msg .= "`nModel updated to: " result.models[1]
            }
        }

        MsgBox(msg, "Test Connection", "Iconi")
    }

    /**
     * Browse for output folder
     */
    static _BrowseOutputFolder() {
        folder := DirSelect(, 0, "Select Default Output Folder")
        if folder != ""
            this.OutputFolderEdit.Value := folder
    }

    /**
     * Download FFmpeg
     */
    static _DownloadFFmpeg() {
        this.FFmpegStatusText.Value := "Status: Downloading..."

        result := FFmpegManager.Download()

        if result.success {
            AppConfig.Set("FFmpeg", "Path", result.path)
            this.FFmpegStatusText.Value := "Status: Installed"
            MsgBox("FFmpeg downloaded and installed successfully.", "FFmpeg", "Iconi")
        } else {
            this.FFmpegStatusText.Value := "Status: Download failed"
            MsgBox("Failed to download FFmpeg:`n" result.error, "FFmpeg", "Icon!")
        }
    }

    /**
     * Save settings
     */
    static _OnSave() {
        provider := this._GetSelectedProvider()
        section := this._GetSection(provider)

        ; Save provider selection
        AppConfig.Set("General", "Provider", provider)

        ; Clear EndpointPath if local BaseUrl changed (force re-discovery)
        if provider = "local" {
            previousUrl := AppConfig.Get("LocalWhisper", "BaseUrl", "")
            if this.BaseUrlEdit.Value != previousUrl
                AppConfig.Set("LocalWhisper", "EndpointPath", "")
        }

        ; Save current provider's settings
        AppConfig.Set(section, "BaseUrl", this.BaseUrlEdit.Value)
        AppConfig.Set(section, "Model", this.ModelEdit.Value)

        ; Save API key if OpenAI and changed
        if provider = "openai" {
            keyValue := this.ApiKeyEdit.Value
            maskedKey := CredentialManager.GetMasked("openai")
            if maskedKey = ""
                maskedKey := CredentialManager.GetMasked("whisper")
            if keyValue != maskedKey && keyValue != "" && !RegExMatch(keyValue, "^\*+.{0,4}$") {
                CredentialManager.Store("openai", keyValue)
            }
        }

        ; Save output settings
        AppConfig.Set("Output", "OutputFolder", this.OutputFolderEdit.Value)

        MsgBox("Settings saved.", "Simple Transcriber", "Iconi")
    }

    /**
     * Check for updates button handler
     */
    static _OnCheckForUpdates() {
        this.UpdateStatusText.Value := "Checking..."
        this.UpdateBtn.Enabled := false

        result := UpdateManager.CheckForUpdates()

        if result.error != "" && result.version = "" {
            this.UpdateStatusText.Value := result.error
            this.UpdateBtn.Enabled := true
            return
        }

        if result.available {
            this.UpdateStatusText.Opt("c009900")
            this.UpdateStatusText.Value := "v" . result.version . " available!"
            this.UpdateBtn.Text := "Download && Install"
            this.UpdateBtn.Enabled := true
            this.UpdateBtn.OnEvent("Click", (*) => this._OnDownloadUpdate(), -1)
            this.UpdateBtn.OnEvent("Click", (*) => this._OnDownloadUpdate())
        } else {
            if result.version != ""
                this.UpdateStatusText.Value := "Up to date (v" . result.version . ")"
            else
                this.UpdateStatusText.Value := "No releases found."
            this.UpdateBtn.Enabled := true
        }
    }

    /**
     * Download and install update
     */
    static _OnDownloadUpdate() {
        confirm := MsgBox("Download and install Simple Transcriber v" . UpdateManager.LatestVersion . "?`n`nThe application will close and the installer will launch.", "Update Available", "YesNo Iconi")
        if confirm != "Yes"
            return

        this.UpdateStatusText.Value := "Downloading..."
        this.UpdateBtn.Enabled := false

        result := UpdateManager.DownloadUpdate((pct, msg) => this.UpdateStatusText.Value := msg)

        if result.success {
            UpdateManager.InstallUpdate(result.path)
        } else {
            this.UpdateBtn.Enabled := true
        }
    }

    /**
     * Show disclaimer dialog
     */
    static _ShowDisclaimer() {
        disclaimer := "
        (
DISCLAIMER

Simple Transcriber is provided "as is" without warranty of any kind, express or implied.

AUDIO/VIDEO FILE PROCESSING:
This software processes audio and video files for speech-to-text transcription. Files are sent to your configured Whisper API endpoint (OpenAI or local server) for processing.

DATA HANDLING:
- Files are read from your local system and sent to the configured API endpoint
- Temporary audio files created during processing are automatically cleaned up
- Transcription results are saved locally to your chosen output folder
- No data is permanently stored by the application beyond your settings

USER RESPONSIBILITY:
- You are responsible for ensuring you have the right to transcribe any audio/video content
- You are responsible for the security of your API keys and server endpoints
- You acknowledge that content sent to third-party APIs (e.g., OpenAI) is subject to their terms of service

ANALYTICS:
When enabled, anonymous usage statistics (app version, OS version, anonymous install ID) are sent to help improve the software. No personal data or transcription content is included. This can be disabled in settings.

LIABILITY:
The developers shall not be held liable for any damages arising from the use of this software, including but not limited to data loss, inaccurate transcriptions, or unauthorized use of API services.

(c) 2026 Bykov-Brett Enterprises. All rights reserved.
        )"
        MsgBox(disclaimer, "Simple Transcriber - Disclaimer", "Iconi")
    }

    /**
     * Close settings window
     */
    static Close() {
        if this.Gui {
            this.Gui.Destroy()
            this.Gui := ""
        }
    }

    /**
     * Check if settings window is currently open
     */
    static IsOpen() {
        return this.Gui != ""
    }
}
