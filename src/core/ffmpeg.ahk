#Requires AutoHotkey v2.0

/**
 * FFmpegManager - Detect, download, and run FFmpeg for audio/video processing
 *
 * Handles: video-to-audio extraction, audio splitting for large files,
 * duration/size detection, and auto-download of FFmpeg binaries.
 */
class FFmpegManager {
    static AppDataDir := A_AppData "\Simple Transcriber"
    static DownloadUrl := "https://github.com/GyanD/codexffmpeg/releases/download/7.1/ffmpeg-7.1-essentials_build.zip"

    ; Audio formats that Whisper accepts directly (no FFmpeg needed for format conversion)
    static WhisperFormats := ["flac", "mp3", "mp4", "mpeg", "mpga", "m4a", "ogg", "wav", "webm"]

    ; Video formats that need audio extraction
    static VideoFormats := ["mp4", "mkv", "avi", "mov", "wmv", "flv", "webm"]

    ; Max file size for Whisper API (25MB)
    static MaxFileSize := 25 * 1024 * 1024

    /**
     * Check if FFmpeg is available (app folder, config path, or PATH)
     * @param config ConfigManager instance (optional)
     * @returns {Boolean}
     */
    static IsAvailable(config := "") {
        return this.GetPath(config) != ""
    }

    /**
     * Get path to ffmpeg.exe, checking multiple locations
     * @param config ConfigManager instance (optional)
     * @returns {String} Full path to ffmpeg.exe, or empty if not found
     */
    static GetPath(config := "") {
        ; 1. Check config-specified path
        if config != "" {
            configPath := config.Get("FFmpeg", "Path", "")
            if configPath != "" && FileExist(configPath)
                return configPath
        }

        ; 2. Check app folder (next to script) - preferred location
        scriptPath := A_ScriptDir "\ffmpeg.exe"
        if FileExist(scriptPath)
            return scriptPath

        ; 3. Check AppData folder (legacy location)
        appDataPath := this.AppDataDir "\ffmpeg.exe"
        if FileExist(appDataPath)
            return appDataPath

        ; 4. Check if compiled - check parent folder
        if A_IsCompiled {
            parentPath := A_ScriptDir "\..\ffmpeg.exe"
            if FileExist(parentPath)
                return parentPath
        }

        ; 5. Check PATH by trying to run it
        try {
            shell := ComObject("WScript.Shell")
            exec := shell.Exec('cmd.exe /c where ffmpeg.exe 2>nul')
            output := Trim(exec.StdOut.ReadAll(), "`r`n `t")
            if output != "" {
                ; where may return multiple lines; use only the first
                firstLine := StrSplit(output, "`n")[1]
                firstLine := Trim(firstLine, "`r`n `t")
                if firstLine != "" && FileExist(firstLine)
                    return firstLine
            }
        }

        return ""
    }

    /**
     * Download FFmpeg to AppData folder
     * Downloads the gyan.dev essentials build from GitHub
     * @param progressCallback Function(status, percent) for progress updates
     * @returns {Object} {success: bool, path: string, error: string}
     */
    static Download(progressCallback := "") {
        try {
            ; Install FFmpeg next to the app exe (survives "Remove settings" uninstall option)
            installDir := A_ScriptDir
            zipPath := installDir "\ffmpeg-download.zip"
            extractDir := installDir "\ffmpeg-extract"
            targetPath := installDir "\ffmpeg.exe"

            if progressCallback
                progressCallback("Downloading FFmpeg...", 10)

            ; Download using URLDownloadToFile
            try {
                Download(this.DownloadUrl, zipPath)
            } catch as e {
                return {success: false, path: "", error: "Download failed: " e.Message}
            }

            if !FileExist(zipPath)
                return {success: false, path: "", error: "Download failed - file not saved"}

            if progressCallback
                progressCallback("Extracting FFmpeg...", 60)

            ; Extract using PowerShell
            if DirExist(extractDir)
                DirDelete(extractDir, true)
            DirCreate(extractDir)

            psCmd := "powershell.exe -NoProfile -Command `"Expand-Archive -Path '" zipPath "' -DestinationPath '" extractDir "' -Force`""
            RunWait(psCmd, , "Hide")

            ; Find ffmpeg.exe in extracted folder (it's in a subfolder)
            found := ""
            loop files extractDir "\*\bin\ffmpeg.exe", "R" {
                found := A_LoopFileFullPath
                break
            }

            if found = "" {
                ; Try flat search
                loop files extractDir "\ffmpeg.exe", "R" {
                    found := A_LoopFileFullPath
                    break
                }
            }

            if found = "" {
                ; Clean up
                try FileDelete(zipPath)
                try DirDelete(extractDir, true)
                return {success: false, path: "", error: "Could not find ffmpeg.exe in downloaded archive"}
            }

            if progressCallback
                progressCallback("Installing FFmpeg...", 90)

            ; Copy to target location
            FileCopy(found, targetPath, true)

            ; Clean up
            try FileDelete(zipPath)
            try DirDelete(extractDir, true)

            if !FileExist(targetPath)
                return {success: false, path: "", error: "Failed to install ffmpeg.exe"}

            if progressCallback
                progressCallback("FFmpeg installed", 100)

            return {success: true, path: targetPath, error: ""}
        } catch as e {
            return {success: false, path: "", error: "FFmpeg download error: " e.Message}
        }
    }

    /**
     * Extract audio from video file to WAV format
     * @param videoPath Path to video file
     * @param outputPath Path for output WAV file
     * @param config ConfigManager instance (optional)
     * @returns {Object} {success: bool, error: string}
     */
    static ExtractAudio(videoPath, outputPath, config := "") {
        ffmpeg := this.GetPath(config)
        if ffmpeg = ""
            return {success: false, error: "FFmpeg not found"}

        try {
            ; Extract audio as 16kHz mono WAV (optimal for Whisper)
            cmd := '"' ffmpeg '" -i "' videoPath '" -vn -ar 16000 -ac 1 -c:a pcm_s16le "' outputPath '" -y'
            RunWait('cmd.exe /c "' cmd '"', , "Hide")

            if FileExist(outputPath)
                return {success: true, error: ""}
            return {success: false, error: "FFmpeg produced no output file"}
        } catch as e {
            return {success: false, error: "FFmpeg error: " e.Message}
        }
    }

    /**
     * Get media file duration in seconds
     * @param filePath Path to media file
     * @param config ConfigManager instance (optional)
     * @returns {Number} Duration in seconds, or 0 on failure
     */
    static GetDuration(filePath, config := "") {
        ffmpeg := this.GetPath(config)
        if ffmpeg = ""
            return 0

        ; Use ffprobe if available (same directory as ffmpeg)
        SplitPath(ffmpeg, , &ffmpegDir)
        ffprobe := ffmpegDir "\ffprobe.exe"
        if !FileExist(ffprobe)
            ffprobe := ffmpeg  ; Fall back to ffmpeg -i

        try {
            if FileExist(ffmpegDir "\ffprobe.exe") {
                ; Use ffprobe for accurate duration
                tempFile := this.AppDataDir "\duration_output.txt"
                cmd := '"' ffprobe '" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "' filePath '"'
                RunWait('cmd.exe /c "' cmd ' > "' tempFile '" 2>&1"', , "Hide")

                if FileExist(tempFile) {
                    content := Trim(FileRead(tempFile), "`r`n `t")
                    try FileDelete(tempFile)
                    if content != "" && RegExMatch(content, "^\d+\.?\d*$")
                        return Number(content)
                }
            }

            ; Fallback: parse ffmpeg -i output for duration
            tempFile := this.AppDataDir "\duration_output.txt"
            cmd := '"' ffmpeg '" -i "' filePath '"'
            RunWait('cmd.exe /c "' cmd ' > "' tempFile '" 2>&1"', , "Hide")

            if FileExist(tempFile) {
                content := FileRead(tempFile)
                try FileDelete(tempFile)
                if RegExMatch(content, "Duration:\s*(\d+):(\d+):(\d+)\.(\d+)", &match) {
                    hours := Number(match[1])
                    mins := Number(match[2])
                    secs := Number(match[3])
                    frac := Number(match[4]) / 100
                    return hours * 3600 + mins * 60 + secs + frac
                }
            }
        }

        return 0
    }

    /**
     * Get file size in bytes
     * @param filePath Path to file
     * @returns {Number} File size in bytes
     */
    static GetFileSize(filePath) {
        if !FileExist(filePath)
            return 0
        return FileGetSize(filePath)
    }

    /**
     * Split audio file into chunks of specified duration
     * @param filePath Path to audio file
     * @param chunkDurationSec Duration per chunk in seconds (default: 600 = 10 minutes)
     * @param outputDir Directory for chunk files (default: AppData temp)
     * @param config ConfigManager instance (optional)
     * @returns {Object} {success: bool, chunks: Array of file paths, error: string}
     */
    static SplitAudio(filePath, chunkDurationSec := 600, outputDir := "", config := "") {
        ffmpeg := this.GetPath(config)
        if ffmpeg = ""
            return {success: false, chunks: [], error: "FFmpeg not found"}

        if outputDir = "" {
            outputDir := this.AppDataDir "\chunks"
        }

        try {
            if !DirExist(outputDir)
                DirCreate(outputDir)

            ; Get total duration
            totalDuration := this.GetDuration(filePath, config)
            if totalDuration = 0
                totalDuration := 36000  ; Assume up to 10 hours if we can't detect

            ; Calculate number of chunks
            numChunks := Ceil(totalDuration / chunkDurationSec)
            if numChunks < 1
                numChunks := 1

            SplitPath(filePath, , , &ext)
            chunks := []

            loop numChunks {
                startTime := (A_Index - 1) * chunkDurationSec
                chunkPath := outputDir "\chunk_" Format("{:03d}", A_Index) "." ext

                ; Use -c copy for compressed formats, re-encode for raw PCM formats (wav)
                if ext = "wav"
                    cmd := '"' ffmpeg '" -i "' filePath '" -ss ' startTime ' -t ' chunkDurationSec ' -ar 16000 -ac 1 -c:a pcm_s16le "' chunkPath '" -y'
                else
                    cmd := '"' ffmpeg '" -i "' filePath '" -ss ' startTime ' -t ' chunkDurationSec ' -c copy "' chunkPath '" -y'
                RunWait('cmd.exe /c "' cmd '"', , "Hide")

                ; Skip chunks smaller than 4KB (header-only files from seeking past end of audio)
                if FileExist(chunkPath) && FileGetSize(chunkPath) > 4096
                    chunks.Push(chunkPath)
            }

            if chunks.Length = 0
                return {success: false, chunks: [], error: "FFmpeg produced no chunk files"}

            return {success: true, chunks: chunks, error: ""}
        } catch as e {
            return {success: false, chunks: [], error: "Split error: " e.Message}
        }
    }

    /**
     * Check if a file needs FFmpeg processing
     * Returns true if file is a video format or exceeds Whisper's 25MB limit
     * @param filePath Path to file
     * @returns {Boolean}
     */
    static NeedsFFmpeg(filePath) {
        SplitPath(filePath, , , &ext)
        ext := StrLower(ext)

        ; Video files always need FFmpeg for audio extraction
        if this.IsVideoFormat(ext)
            return true

        ; Large audio files need FFmpeg for splitting
        if this.GetFileSize(filePath) > this.MaxFileSize
            return true

        return false
    }

    /**
     * Check if file extension is a video format
     * @param ext File extension (without dot)
     * @returns {Boolean}
     */
    static IsVideoFormat(ext) {
        ext := StrLower(ext)
        for fmt in this.VideoFormats {
            if ext = fmt {
                ; mp4 and webm can be audio-only, check more carefully
                if ext = "mp4" || ext = "webm"
                    return true  ; Treat as video by default, FFmpeg handles audio-only gracefully
                return true
            }
        }
        return false
    }

    /**
     * Clean up temporary chunk files
     * @param chunkDir Directory containing chunks (default: AppData chunks folder)
     */
    static CleanupChunks(chunkDir := "") {
        if chunkDir = ""
            chunkDir := this.AppDataDir "\chunks"

        try {
            if DirExist(chunkDir)
                DirDelete(chunkDir, true)
        }
    }

    /**
     * Clean up temporary extracted audio files
     * @param tempDir Directory containing temp files
     */
    static CleanupTempAudio(tempDir := "") {
        if tempDir = ""
            tempDir := this.AppDataDir

        try {
            loop files tempDir "\extracted_audio_*.*" {
                FileDelete(A_LoopFileFullPath)
            }
        }
    }
}
