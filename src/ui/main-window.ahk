#Requires AutoHotkey v2.0

/**
 * MainWindow - Primary application window for Simple Transcriber
 *
 * Features: drag-and-drop file zone, browse button, editable transcript area,
 * progress bar, save/copy buttons, settings access.
 */
class MainWindow {
    static MyGui := ""
    static DropZoneText := ""
    static FileInfoText := ""
    static TranscriptEdit := ""
    static ProgressBar := ""
    static StatusText := ""
    static BtnBrowse := ""
    static BtnSave := ""
    static BtnCopy := ""
    static BtnCancel := ""
    static BtnSettings := ""
    static CurrentFile := ""
    static Config := ""
    static IsVisible := false

    ; Supported file extensions
    static SupportedFormats := "*.mp3;*.wav;*.mp4;*.m4a;*.ogg;*.flac;*.webm;*.mov;*.mkv;*.avi;*.wmv;*.mpeg;*.mpga"
    static SupportedExts := ["mp3", "wav", "mp4", "m4a", "ogg", "flac", "webm", "mov", "mkv", "avi", "wmv", "mpeg", "mpga"]

    /**
     * Initialize the main window
     * @param config ConfigManager instance
     */
    static Initialize(config) {
        this.Config := config
        this._CreateGui()
    }

    /**
     * Show the main window
     */
    static Show() {
        if this.MyGui = ""
            return

        this.MyGui.Show("w600 h650")
        this.IsVisible := true

        ; Warm up the Whisper server so the model is loaded when the user needs it
        this._WarmUpServer()
    }

    /**
     * Hide the main window
     */
    static Hide() {
        if this.MyGui = ""
            return

        this.MyGui.Hide()
        this.IsVisible := false
    }

    /**
     * Toggle window visibility
     */
    static Toggle() {
        if this.IsVisible
            this.Hide()
        else
            this.Show()
    }

    /**
     * Create the GUI layout
     */
    static _CreateGui() {
        myGui := Gui("+Resize +MinSize500x500", "Simple Transcriber")
        myGui.OnEvent("Close", (*) => this.Hide())
        myGui.OnEvent("DropFiles", (guiObj, ctrl, fileArray, *) => this._OnDropFiles(fileArray))
        myGui.OnEvent("Size", (guiObj, minMax, width, height) => this._OnResize(width, height))

        ; Apply theme
        ThemeManager.Apply(myGui)
        colors := ThemeManager.GetColors()

        ; Title bar area with settings button
        myGui.SetFont("s11 bold")
        myGui.Add("Text", "x20 y15 w500", "Simple Transcriber")

        myGui.SetFont("s9 norm")
        this.BtnSettings := myGui.Add("Button", "x540 y10 w40 h30", Chr(0x2699))
        this.BtnSettings.ToolTip := "Settings"
        this.BtnSettings.OnEvent("Click", (*) => SettingsWindow.Show())

        ; Drop zone
        myGui.SetFont("s10")
        myGui.Add("GroupBox", "x20 y50 w560 h120 vDropZoneBox", "Drop File Here")
        myGui.SetFont("s9")
        this.DropZoneText := myGui.Add("Text", "x40 y80 w520 h70 Center",
            "Drop an audio or video file here, or click Browse`n`nSupported: mp3, wav, mp4, m4a, ogg, flac, webm, mov, mkv, avi")

        ; Browse button and file info
        this.BtnBrowse := myGui.Add("Button", "x20 y180 w120 h30", "&Browse File...")
        this.BtnBrowse.OnEvent("Click", (*) => this._OnBrowse())

        this.FileInfoText := myGui.Add("Text", "x150 y185 w430 h20", "No file selected")

        ; Transcript section
        myGui.SetFont("s9")
        myGui.Add("Text", "x20 y220 w560 h20", "Transcription:")

        this.TranscriptEdit := myGui.Add("Edit", "x20 y240 w560 h310 Multi VScroll WantReturn")

        ; Progress bar and status
        this.ProgressBar := myGui.Add("Progress", "x20 y560 w560 h20 Range0-100", 0)
        this.StatusText := myGui.Add("Text", "x20 y585 w560 h20", "Ready")

        ; Action buttons
        this.BtnSave := myGui.Add("Button", "x20 y610 w130 h30", "&Save as .txt")
        this.BtnSave.OnEvent("Click", (*) => this._OnSave())

        this.BtnCopy := myGui.Add("Button", "x160 y610 w150 h30", "&Copy to Clipboard")
        this.BtnCopy.OnEvent("Click", (*) => this._OnCopy())

        this.BtnCancel := myGui.Add("Button", "x450 y610 w130 h30", "Ca&ncel")
        this.BtnCancel.OnEvent("Click", (*) => this._OnCancel())
        this.BtnCancel.Enabled := false

        this.MyGui := myGui
    }

    /**
     * Handle window resize
     */
    static _OnResize(width, height) {
        if width < 100 || height < 100
            return

        pad := 20
        innerW := width - (pad * 2)

        try {
            ; Settings button - top right
            this.BtnSettings.Move(width - pad - 40, 10)

            ; Drop zone group box
            this.MyGui["DropZoneBox"].Move(pad, 50, innerW, 120)
            this.DropZoneText.Move(pad + 20, 80, innerW - 40, 70)

            ; File info
            this.FileInfoText.Move(150, 185, innerW - 130, 20)

            ; Transcript edit - fill available space
            editHeight := height - 410
            if editHeight < 100
                editHeight := 100
            this.TranscriptEdit.Move(pad, 240, innerW, editHeight)

            ; Progress bar and status
            progressY := 240 + editHeight + 10
            this.ProgressBar.Move(pad, progressY, innerW, 20)
            this.StatusText.Move(pad, progressY + 25, innerW, 20)

            ; Buttons
            btnY := progressY + 50
            this.BtnSave.Move(pad, btnY)
            this.BtnCopy.Move(pad + 140, btnY)
            this.BtnCancel.Move(width - pad - 130, btnY)
        }
    }

    /**
     * Handle files dropped onto the window
     */
    static _OnDropFiles(fileArray) {
        if fileArray.Length = 0
            return

        ; Use the first file
        this._LoadFile(fileArray[1])
    }

    /**
     * Handle Browse button click
     */
    static _OnBrowse() {
        filePath := FileSelect(1, , "Select Audio or Video File",
            "Audio/Video Files (" this.SupportedFormats ")")

        if filePath = ""
            return

        this._LoadFile(filePath)
    }

    /**
     * Load a file and start transcription
     */
    static _LoadFile(filePath) {
        ; Validate extension
        SplitPath(filePath, &fileName, , &ext)
        ext := StrLower(ext)

        isSupported := false
        for fmt in this.SupportedExts {
            if ext = fmt {
                isSupported := true
                break
            }
        }

        if !isSupported {
            MsgBox("Unsupported file format: ." ext "`n`nSupported formats: mp3, wav, mp4, m4a, ogg, flac, webm, mov, mkv, avi", "Simple Transcriber", "Icon!")
            return
        }

        this.CurrentFile := filePath

        ; Show file info
        fileSize := FileGetSize(filePath)
        sizeMB := Round(fileSize / (1024 * 1024), 1)
        this.FileInfoText.Value := fileName " (" sizeMB " MB)"

        ; Check if FFmpeg is needed
        if FFmpegManager.NeedsFFmpeg(filePath) && !FFmpegManager.IsAvailable(this.Config) {
            result := MsgBox("This file requires FFmpeg for processing.`n`nFFmpeg is needed to extract audio from video files or split large audio files.`n`nWould you like to download FFmpeg now? (~80MB)", "FFmpeg Required", "YesNo Icon!")
            if result = "Yes" {
                this._DownloadFFmpeg()
            } else {
                this.StatusText.Value := "FFmpeg required - please install via Settings"
                return
            }
        }

        ; Start transcription
        this._StartTranscription(filePath)
    }

    /**
     * Download FFmpeg with progress
     */
    static _DownloadFFmpeg() {
        this.StatusText.Value := "Downloading FFmpeg..."
        this.ProgressBar.Value := 0
        this.BtnBrowse.Enabled := false

        ; Run download (blocking for now - FFmpeg download is quick)
        result := FFmpegManager.Download(ObjBindMethod(this, "_OnProgress"))

        this.BtnBrowse.Enabled := true

        if !result.success {
            MsgBox("Failed to download FFmpeg:`n" result.error, "Download Error", "Icon!")
            this.StatusText.Value := "FFmpeg download failed"
            this.ProgressBar.Value := 0
            return
        }

        ; Save path to config
        this.Config.Set("FFmpeg", "Path", result.path)
        this.StatusText.Value := "FFmpeg installed successfully"
        this.ProgressBar.Value := 0
    }

    /**
     * Start the transcription process in a background thread
     */
    static _StartTranscription(filePath) {
        ; Disable controls during transcription
        this.BtnBrowse.Enabled := false
        this.BtnSave.Enabled := false
        this.BtnCopy.Enabled := false
        this.BtnCancel.Enabled := true
        this.TranscriptEdit.Value := ""
        this.ProgressBar.Value := 0
        this.StatusText.Value := "Starting transcription..."

        ; Use SetTimer to avoid blocking the GUI
        SetTimer(() => this._RunTranscription(filePath), -50)
    }

    /**
     * Run the transcription (called via SetTimer to keep GUI responsive)
     */
    static _RunTranscription(filePath) {
        result := TranscriptionEngine.TranscribeFile(
            filePath,
            this.Config,
            ObjBindMethod(this, "_OnProgress")
        )

        ; Re-enable controls
        this.BtnBrowse.Enabled := true
        this.BtnCancel.Enabled := false

        if result.success {
            this.TranscriptEdit.Value := result.text
            this.BtnSave.Enabled := true
            this.BtnCopy.Enabled := true
            this.StatusText.Value := "Transcription complete (" result.segments.Length " segments)"
            this.ProgressBar.Value := 100
        } else {
            this.StatusText.Value := "Error: " result.error
            this.ProgressBar.Value := 0
            this.BtnSave.Enabled := false
            this.BtnCopy.Enabled := false

            ; If we have partial text, show it
            if result.text != "" {
                this.TranscriptEdit.Value := result.text
                this.BtnSave.Enabled := true
                this.BtnCopy.Enabled := true
            }
        }
    }

    /**
     * Progress callback from transcription engine
     */
    static _OnProgress(status, percent) {
        try {
            this.StatusText.Value := status
            this.ProgressBar.Value := Min(percent, 100)
        }
    }

    /**
     * Handle Save button click
     */
    static _OnSave() {
        text := this.TranscriptEdit.Value
        if text = "" {
            MsgBox("No transcription to save.", "Simple Transcriber", "Icon!")
            return
        }

        ; Generate suggested filename
        suggestedPath := ""
        if this.CurrentFile != "" {
            outputFolder := this.Config.Get("Output", "OutputFolder", "")
            suggestedPath := TranscriptionEngine.GetSuggestedOutputPath(this.CurrentFile, outputFolder)
        }

        ; Open save dialog
        SplitPath(suggestedPath, &defaultName, &defaultDir)
        savePath := FileSelect("S16", suggestedPath, "Save Transcription", "Text Files (*.txt)")

        if savePath = ""
            return

        ; Ensure .txt extension
        if !RegExMatch(savePath, "i)\.txt$")
            savePath .= ".txt"

        result := TranscriptionEngine.ExportToFile(text, savePath)
        if result.success {
            this.StatusText.Value := "Saved to: " savePath
        } else {
            MsgBox("Failed to save file:`n" result.error, "Save Error", "Icon!")
        }
    }

    /**
     * Handle Copy button click
     */
    static _OnCopy() {
        text := this.TranscriptEdit.Value
        if text = "" {
            MsgBox("No transcription to copy.", "Simple Transcriber", "Icon!")
            return
        }

        A_Clipboard := text
        this.StatusText.Value := "Copied to clipboard"
    }

    /**
     * Send a warmup ping to the Whisper server to trigger model loading
     */
    static _WarmUpServer() {
        try {
            provider := STTFactory.Create(this.Config)
            if provider.HasMethod("WarmUp")
                provider.WarmUp()
        }
    }

    /**
     * Handle Cancel button click
     */
    static _OnCancel() {
        TranscriptionEngine.Cancel()
        this.StatusText.Value := "Cancelling..."
        this.BtnCancel.Enabled := false
    }
}
