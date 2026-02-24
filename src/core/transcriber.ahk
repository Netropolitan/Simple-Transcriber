#Requires AutoHotkey v2.0

/**
 * TranscriptionEngine - Orchestrates the file transcription workflow
 *
 * Handles: file type detection, audio extraction, chunking, Whisper API calls,
 * result merging, paragraph formatting, and file export.
 */
class TranscriptionEngine {
    static AppDataDir := A_AppData "\Simple Transcriber"
    static IsTranscribing := false
    static CancelRequested := false

    /**
     * Transcribe an audio or video file
     * @param filePath Path to the input file
     * @param config ConfigManager instance
     * @param progressCallback Function(status, percent) for progress updates
     * @returns {Object} {success: bool, text: string, segments: Array, error: string}
     */
    static TranscribeFile(filePath, config, progressCallback := "") {
        this.IsTranscribing := true
        this.CancelRequested := false

        try {
            if !FileExist(filePath)
                return this._Result(false, "", [], "File not found: " filePath)

            ; Create STT provider
            provider := STTFactory.Create(config)

            ; Check if API key is configured (only required for OpenAI provider)
            if provider.ApiKey = "" && config.Get("General", "Provider", "openai") = "openai"
                return this._Result(false, "", [], "No API key configured. Please add your OpenAI API key in Settings.")

            if progressCallback
                progressCallback("Analysing file...", 5)

            SplitPath(filePath, , , &ext)
            ext := StrLower(ext)
            audioPath := filePath
            needsCleanup := false
            chunkDir := ""

            ; Step 1: Extract audio if video
            if FFmpegManager.IsVideoFormat(ext) {
                if !FFmpegManager.IsAvailable(config)
                    return this._Result(false, "", [], "FFmpeg is required to process video files. Please install FFmpeg via Settings or download it manually.")

                if progressCallback
                    progressCallback("Extracting audio from video...", 10)

                audioPath := this.AppDataDir "\extracted_audio_" A_TickCount ".mp3"
                needsCleanup := true

                ; Extract as MP3 (smaller than WAV for upload)
                extractResult := this._ExtractAudioAsMP3(filePath, audioPath, config)
                if !extractResult.success {
                    this._Cleanup(audioPath, needsCleanup, chunkDir)
                    return this._Result(false, "", [], "Audio extraction failed: " extractResult.error)
                }

                if this.CancelRequested {
                    this._Cleanup(audioPath, needsCleanup, chunkDir)
                    return this._Result(false, "", [], "Transcription cancelled")
                }
            }

            ; Step 2: Check file size and split if needed
            fileSize := FFmpegManager.GetFileSize(audioPath)

            if fileSize > FFmpegManager.MaxFileSize {
                ; File too large - need to split into chunks
                if !FFmpegManager.IsAvailable(config)
                    return this._Result(false, "", [], "FFmpeg is required to process files larger than 25MB. Please install FFmpeg via Settings.")

                if progressCallback
                    progressCallback("Splitting audio into chunks...", 15)

                chunkDir := this.AppDataDir "\chunks_" A_TickCount
                splitResult := FFmpegManager.SplitAudio(audioPath, 600, chunkDir, config)

                if !splitResult.success {
                    this._Cleanup(audioPath, needsCleanup, chunkDir)
                    return this._Result(false, "", [], "Failed to split audio: " splitResult.error)
                }

                ; Transcribe each chunk
                result := this._TranscribeChunks(splitResult.chunks, provider, config, progressCallback)

                ; Clean up
                this._Cleanup(audioPath, needsCleanup, chunkDir)
                return result
            } else {
                ; File is small enough - transcribe directly
                if progressCallback
                    progressCallback("Transcribing...", 20)

                ; Retry logic for transient errors (server cold start, model loading)
                result := ""
                maxRetries := 3
                loop maxRetries {
                    attempt := A_Index
                    result := provider.TranscribeWithTimestamps(audioPath, config.Get("General", "Language", "en"))

                    if result.success
                        break

                    isTransient := InStr(result.error, "500") || InStr(result.error, "503") || InStr(result.error, "timeout") || InStr(result.error, "Timeout")
                    if !isTransient
                        break

                    if attempt < maxRetries {
                        retryDelay := attempt = 1 ? 5 : (attempt = 2 ? 15 : 30)
                        if progressCallback
                            progressCallback("Request failed (attempt " attempt "/" maxRetries "), retrying in " retryDelay "s...", 20)
                        Sleep(retryDelay * 1000)
                    }
                }

                ; Clean up extracted audio if needed
                this._Cleanup(audioPath, needsCleanup, chunkDir)

                if this.CancelRequested
                    return this._Result(false, "", [], "Transcription cancelled")

                if !result.success
                    return this._Result(false, "", [], result.error)

                if progressCallback
                    progressCallback("Formatting text...", 90)

                ; Format with paragraph breaks
                threshold := Number(config.Get("Output", "ParagraphBreakThreshold", "2.0"))
                addTimestamps := config.Get("Output", "AddTimestamps", "0") = "1"
                formattedText := this.FormatTranscript(result.segments, threshold, addTimestamps)

                if formattedText = ""
                    formattedText := result.text  ; Fallback to raw text

                if progressCallback
                    progressCallback("Done", 100)

                return this._Result(true, formattedText, result.segments, "")
            }
        } catch as e {
            this.IsTranscribing := false
            return this._Result(false, "", [], "Transcription error: " e.Message)
        } finally {
            this.IsTranscribing := false
        }
    }

    /**
     * Cancel an in-progress transcription
     */
    static Cancel() {
        this.CancelRequested := true
    }

    /**
     * Transcribe multiple chunks and merge results
     */
    static _TranscribeChunks(chunks, provider, config, progressCallback := "") {
        allSegments := []
        allText := ""
        language := config.Get("General", "Language", "en")
        chunkDuration := 600  ; 10 minutes per chunk
        totalChunks := chunks.Length

        for i, chunkPath in chunks {
            if this.CancelRequested
                return this._Result(false, allText, allSegments, "Transcription cancelled")

            ; Calculate progress (20-90% range for transcription)
            percent := 20 + Floor((i - 1) / totalChunks * 70)
            if progressCallback
                progressCallback("Transcribing chunk " i "/" totalChunks "...", percent)

            ; Retry logic for transient errors (server cold start, model loading, etc.)
            result := ""
            maxRetries := 3
            loop maxRetries {
                attempt := A_Index
                result := provider.TranscribeWithTimestamps(chunkPath, language)

                if result.success
                    break

                ; Don't retry on non-transient errors
                isTransient := InStr(result.error, "500") || InStr(result.error, "503") || InStr(result.error, "timeout") || InStr(result.error, "Timeout")
                if !isTransient
                    break

                ; Wait before retry (increasing delay: 5s, 15s, 30s)
                if attempt < maxRetries {
                    retryDelay := attempt = 1 ? 5 : (attempt = 2 ? 15 : 30)
                    if progressCallback
                        progressCallback("Chunk " i " failed (attempt " attempt "/" maxRetries "), retrying in " retryDelay "s...", percent)
                    Sleep(retryDelay * 1000)
                }
            }

            if !result.success {
                ; If we already have text and this looks like end-of-audio
                ; (decode/audio errors on later chunks), treat as complete
                if allText != "" && i > 1 && (InStr(result.error, "decode") || InStr(result.error, "audio") || InStr(result.error, "No speech")) {
                    break
                }
                ; Otherwise report the error with any partial results
                if allText != ""
                    return this._Result(false, allText, allSegments, "Failed on chunk " i "/" totalChunks ": " result.error)
                return this._Result(false, "", [], "Transcription failed on chunk " i ": " result.error)
            }

            ; Adjust timestamps for chunk offset
            timeOffset := (i - 1) * chunkDuration
            for seg in result.segments {
                seg.start += timeOffset
                seg.end += timeOffset
                allSegments.Push(seg)
            }

            if allText != ""
                allText .= " "
            allText .= result.text
        }

        if progressCallback
            progressCallback("Formatting text...", 92)

        ; Format merged results
        threshold := Number(config.Get("Output", "ParagraphBreakThreshold", "2.0"))
        addTimestamps := config.Get("Output", "AddTimestamps", "0") = "1"
        formattedText := this.FormatTranscript(allSegments, threshold, addTimestamps)

        if formattedText = ""
            formattedText := allText

        if progressCallback
            progressCallback("Done", 100)

        return this._Result(true, formattedText, allSegments, "")
    }

    /**
     * Format transcript with paragraph breaks based on pause gaps
     * @param segments Array of {start, end, text} objects
     * @param threshold Seconds of silence to trigger paragraph break (default 2.0)
     * @param addTimestamps Whether to prepend timestamps to paragraphs
     * @returns {String} Formatted text
     */
    static FormatTranscript(segments, threshold := 2.0, addTimestamps := false) {
        if segments.Length = 0
            return ""

        text := ""
        paragraphStart := 0

        for i, seg in segments {
            if i = 1 {
                ; First segment
                if addTimestamps
                    text .= this._FormatTimestamp(seg.start) " "
                text .= seg.text
                paragraphStart := seg.start
            } else {
                ; Check gap between this segment and previous
                prevSeg := segments[i - 1]
                gap := seg.start - prevSeg.end

                if gap >= threshold {
                    ; Insert paragraph break
                    text .= "`r`n`r`n"
                    if addTimestamps
                        text .= this._FormatTimestamp(seg.start) " "
                    text .= seg.text
                    paragraphStart := seg.start
                } else {
                    ; Continue same paragraph
                    text .= " " seg.text
                }
            }
        }

        return Trim(text)
    }

    /**
     * Format seconds as [HH:MM:SS] timestamp
     */
    static _FormatTimestamp(seconds) {
        hours := Floor(seconds / 3600)
        mins := Floor(Mod(seconds, 3600) / 60)
        secs := Floor(Mod(seconds, 60))
        return Format("[{:02d}:{:02d}:{:02d}]", hours, mins, secs)
    }

    /**
     * Export text to a file with UTF-8 BOM encoding
     * @param text Text content to save
     * @param outputPath File path to save to
     * @returns {Object} {success: bool, error: string}
     */
    static ExportToFile(text, outputPath) {
        try {
            ; "UTF-8" encoding in FileOpen automatically writes BOM
            f := FileOpen(outputPath, "w", "UTF-8")
            f.Write(text)
            f.Close()
            return {success: true, error: ""}
        } catch as e {
            return {success: false, error: "Failed to save file: " e.Message}
        }
    }

    /**
     * Generate a suggested output file path based on input file name
     * @param inputPath Path to the input audio/video file
     * @param outputFolder Optional output folder (uses input file's folder if empty)
     * @returns {String} Suggested output path
     */
    static GetSuggestedOutputPath(inputPath, outputFolder := "") {
        SplitPath(inputPath, , &dir, , &nameNoExt)

        if outputFolder != "" && DirExist(outputFolder)
            dir := outputFolder

        return dir "\" nameNoExt "_transcription.txt"
    }

    /**
     * Extract audio from video as MP3 (smaller than WAV for API upload)
     */
    static _ExtractAudioAsMP3(videoPath, outputPath, config := "") {
        ffmpeg := FFmpegManager.GetPath(config)
        if ffmpeg = ""
            return {success: false, error: "FFmpeg not found"}

        try {
            cmd := '"' ffmpeg '" -i "' videoPath '" -vn -ar 16000 -ac 1 -b:a 128k "' outputPath '" -y'
            RunWait('cmd.exe /c "' cmd '"', , "Hide")

            if FileExist(outputPath)
                return {success: true, error: ""}
            return {success: false, error: "FFmpeg produced no output file"}
        } catch as e {
            return {success: false, error: "FFmpeg error: " e.Message}
        }
    }

    /**
     * Build a standard result object
     */
    static _Result(success, text, segments, error) {
        return {success: success, text: text, segments: segments, error: error}
    }

    /**
     * Clean up temporary files
     */
    static _Cleanup(audioPath, needsCleanup, chunkDir) {
        if needsCleanup {
            try FileDelete(audioPath)
        }
        if chunkDir != "" {
            try DirDelete(chunkDir, true)
        }
    }
}
