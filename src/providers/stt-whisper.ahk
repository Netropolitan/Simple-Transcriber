#Requires AutoHotkey v2.0

/**
 * STTWhisper - OpenAI Whisper-compatible STT via API
 *
 * Supports: OpenAI API, local faster-whisper-server, any Whisper-compatible endpoint.
 * API: POST /v1/audio/transcriptions (multipart/form-data)
 */
class STTWhisper extends STTBase {
    Name := "Whisper"
    BaseUrl := ""
    Model := "whisper-1"
    ApiKey := ""
    ResponseFormat := "verbose_json"
    EndpointPath := ""

    __New(baseUrl := "", model := "", apiKey := "", responseFormat := "", endpointPath := "") {
        this.BaseUrl := baseUrl
        this.Model := model != "" ? model : "whisper-1"
        this.ApiKey := apiKey
        this.ResponseFormat := responseFormat != "" ? responseFormat : "verbose_json"
        this.EndpointPath := endpointPath
    }

    /**
     * Build the full transcription URL from BaseUrl and EndpointPath
     */
    _GetTranscriptionUrl() {
        path := this.EndpointPath != "" ? this.EndpointPath : "/v1/audio/transcriptions"
        return RTrim(this.BaseUrl, "/") . path
    }

    /**
     * Transcribe audio file using Whisper API (simple text output)
     * @param filePath Path to audio file
     * @param language Language code (e.g., "en")
     * @returns {Object} {success: bool, text: string, error: string}
     */
    Transcribe(filePath, language := "en") {
        if !FileExist(filePath)
            return {success: false, text: "", error: "Audio file not found"}

        if this.BaseUrl = ""
            return {success: false, text: "", error: "Whisper server URL not configured"}

        try {
            url := this._GetTranscriptionUrl()

            ; Build fields
            fields := Map()
            fields["model"] := this.Model
            fields["response_format"] := "text"
            if language != ""
                fields["language"] := SubStr(language, 1, 2)  ; Use 2-letter code

            ; Build headers
            headers := Map()
            if this.ApiKey != ""
                headers["Authorization"] := "Bearer " this.ApiKey

            ; Send multipart request with extended timeout for large files
            response := HttpClient.PostMultipart(url, fields, filePath, "file", headers, 300000)

            if response.error != ""
                return {success: false, text: "", error: response.error}

            if response.status >= 200 && response.status < 300 {
                text := Trim(response.body)
                if text = ""
                    return {success: false, text: "", error: "No speech detected"}
                return {success: true, text: text, error: ""}
            } else {
                errMsg := "HTTP " response.status
                try {
                    errData := JSON.Load(response.body)
                    if errData is Map {
                        if errData.Has("error")
                            errMsg := String(errData["error"])
                        else if errData.Has("detail")
                            errMsg := IsObject(errData["detail"]) ? JSON.Dump(errData["detail"]) : String(errData["detail"])
                    }
                }
                return {success: false, text: "", error: errMsg}
            }
        } catch as e {
            return {success: false, text: "", error: "Whisper error: " e.Message}
        }
    }

    /**
     * Transcribe audio file with timestamp data (verbose_json format)
     * Returns segments with start/end times for paragraph formatting
     * @param filePath Path to audio file
     * @param language Language code (e.g., "en")
     * @returns {Object} {success: bool, segments: Array, text: string, duration: number, error: string}
     */
    TranscribeWithTimestamps(filePath, language := "en") {
        if !FileExist(filePath)
            return {success: false, segments: [], text: "", duration: 0, error: "Audio file not found"}

        if this.BaseUrl = ""
            return {success: false, segments: [], text: "", duration: 0, error: "Whisper server URL not configured"}

        try {
            url := this._GetTranscriptionUrl()

            ; Build fields
            fields := Map()
            fields["model"] := this.Model
            fields["response_format"] := "verbose_json"
            ; timestamp_granularities is OpenAI-only; local servers reject unknown fields
            if this.ApiKey != ""
                fields["timestamp_granularities[]"] := "segment"
            if language != ""
                fields["language"] := SubStr(language, 1, 2)

            ; Build headers
            headers := Map()
            if this.ApiKey != ""
                headers["Authorization"] := "Bearer " this.ApiKey

            ; Send multipart request with extended timeout
            response := HttpClient.PostMultipart(url, fields, filePath, "file", headers, 300000)

            if response.error != ""
                return {success: false, segments: [], text: "", duration: 0, error: response.error}

            if response.status >= 200 && response.status < 300 {
                try {
                    data := JSON.Load(response.body)

                    ; Extract text
                    text := ""
                    if data is Map {
                        text := data.Has("text") ? data["text"] : ""
                    }

                    if text = "" || Trim(text) = ""
                        return {success: false, segments: [], text: "", duration: 0, error: "No speech detected"}

                    ; Extract duration
                    duration := 0
                    if data is Map && data.Has("duration")
                        duration := data["duration"]

                    ; Extract segments
                    segments := []
                    if data is Map && data.Has("segments") {
                        rawSegments := data["segments"]
                        for seg in rawSegments {
                            segObj := {}
                            if seg is Map {
                                segObj.start := seg.Has("start") ? seg["start"] : 0
                                segObj.end := seg.Has("end") ? seg["end"] : 0
                                segObj.text := seg.Has("text") ? Trim(seg["text"]) : ""
                            } else {
                                segObj.start := seg.HasProp("start") ? seg.start : 0
                                segObj.end := seg.HasProp("end") ? seg.end : 0
                                segObj.text := seg.HasProp("text") ? Trim(seg.text) : ""
                            }
                            if segObj.text != ""
                                segments.Push(segObj)
                        }
                    }

                    return {success: true, segments: segments, text: Trim(text), duration: duration, error: ""}
                } catch as e {
                    return {success: false, segments: [], text: "", duration: 0, error: "Failed to parse response: " e.Message}
                }
            } else {
                errMsg := "HTTP " response.status
                try {
                    errData := JSON.Load(response.body)
                    if errData is Map {
                        if errData.Has("error") {
                            errVal := errData["error"]
                            if IsObject(errVal) {
                                if errVal is Map && errVal.Has("message")
                                    errMsg := errVal["message"]
                                else
                                    errMsg := String(errVal)
                            } else {
                                errMsg := String(errVal)
                            }
                        } else if errData.Has("detail") {
                            errMsg := IsObject(errData["detail"]) ? JSON.Dump(errData["detail"]) : String(errData["detail"])
                        }
                    }
                } catch {
                    ; Include raw body if JSON parsing failed
                    if response.body != ""
                        errMsg .= " - " SubStr(response.body, 1, 200)
                }

                ; Add user-friendly context for common error codes
                isLocal := (this.ApiKey = "")
                if response.status = 500 {
                    if isLocal
                        errMsg .= "`n`nThe local Whisper server returned an internal error. Common causes:`n- Insufficient GPU memory (VRAM) - close other GPU applications`n- Model failed to load - restart the server`n- Server ran out of memory processing the file"
                    else
                        errMsg .= "`n`nOpenAI's servers returned an internal error. Try again in a moment."
                } else if response.status = 413 {
                    errMsg .= "`n`nFile too large for the server. Try a shorter audio file."
                } else if response.status = 401 {
                    errMsg .= "`n`nAuthentication failed. Check your API key in Settings."
                } else if response.status = 429 {
                    errMsg .= "`n`nRate limit exceeded. Wait a moment and try again."
                } else if response.status = 503 {
                    if isLocal
                        errMsg .= "`n`nThe local Whisper server is unavailable. Check that it is running and the model is loaded."
                    else
                        errMsg .= "`n`nOpenAI's service is temporarily unavailable. Try again shortly."
                }

                return {success: false, segments: [], text: "", duration: 0, error: errMsg}
            }
        } catch as e {
            return {success: false, segments: [], text: "", duration: 0, error: "Whisper error: " e.Message}
        }
    }

    /**
     * Send a lightweight warmup request to prompt the server to load its model.
     * Fires and forgets - runs asynchronously via SetTimer so it doesn't block the UI.
     */
    WarmUp() {
        if this.BaseUrl = ""
            return

        ; Fire-and-forget: hit /v1/models to wake the server and trigger model loading
        SetTimer(() => this._DoWarmUp(), -100)
    }

    _DoWarmUp() {
        try {
            url := RTrim(this.BaseUrl, "/") "/v1/models"
            headers := Map()
            if this.ApiKey != ""
                headers["Authorization"] := "Bearer " this.ApiKey
            HttpClient.Request("GET", url, "", headers, 5000)
        }
    }

    /**
     * Test connection to Whisper server
     * @param discover If true, run full endpoint discovery (for local servers)
     * @returns {Object} {available: bool, error: string} or discovery result object
     */
    TestConnection(discover := false) {
        if this.BaseUrl = ""
            return {available: false, error: "Server URL not configured"}

        if discover
            return this.DiscoverEndpoints()

        try {
            url := RTrim(this.BaseUrl, "/")
            headers := Map()
            if this.ApiKey != ""
                headers["Authorization"] := "Bearer " this.ApiKey

            response := HttpClient.Get(url "/v1/models", headers)

            if response.error != ""
                return {available: false, error: "Cannot reach server: " response.error}

            if response.status >= 200 && response.status < 500
                return {available: true, error: ""}

            return {available: false, error: "Server returned HTTP " response.status}
        } catch as e {
            return {available: false, error: e.Message}
        }
    }

    /**
     * Discover server type, available models, and transcription endpoint
     * Probes well-known endpoints to find a compatible transcription route.
     * @returns {Object} {available, serverType, endpointPath, models, docsUrl, checked, error}
     */
    DiscoverEndpoints() {
        base := RTrim(this.BaseUrl, "/")
        headers := Map()
        if this.ApiKey != ""
            headers["Authorization"] := "Bearer " this.ApiKey
        timeout := 5000

        result := {
            available: false,
            serverType: "",
            endpointPath: "",
            models: [],
            docsUrl: "",
            checked: [],
            error: ""
        }

        ; --- Phase 1: Server identification ---

        ; Check if server is reachable at all via GET /v1/models
        modelsResp := HttpClient.Request("GET", base "/v1/models", "", headers, timeout)

        if modelsResp.error != "" {
            result.error := "Cannot reach server at " this.BaseUrl "`n`n"
                . "- Check the server URL is correct`n"
                . "- Check the server is running`n"
                . "- Check no firewall is blocking the connection"
            return result
        }

        ; If /v1/models returned a non-connection error, server is reachable
        ; Extract model names if we got a good response
        if modelsResp.status >= 200 && modelsResp.status < 300 {
            try {
                modelsData := JSON.Load(modelsResp.body)
                if modelsData is Map && modelsData.Has("data") {
                    for item in modelsData["data"] {
                        modelId := ""
                        if item is Map && item.Has("id")
                            modelId := item["id"]
                        else if item.HasProp("id")
                            modelId := item.id
                        if modelId != ""
                            result.models.Push(modelId)
                    }
                }
            }
        }

        ; Try GET /openapi.json to detect server type
        openApiResp := HttpClient.Request("GET", base "/openapi.json", "", headers, timeout)
        if openApiResp.status >= 200 && openApiResp.status < 300 {
            try {
                apiDoc := JSON.Load(openApiResp.body)
                if apiDoc is Map && apiDoc.Has("info") {
                    info := apiDoc["info"]
                    if info is Map && info.Has("title")
                        result.serverType := info["title"]
                }
            }
        }

        ; --- Phase 2: Endpoint probing (stop on first hit) ---
        endpoints := [
            {path: "/v1/audio/transcriptions", label: "OpenAI-compatible"},
            {path: "/inference", label: "whisper.cpp"},
            {path: "/asr", label: "whisper-asr-webservice"}
        ]

        for ep in endpoints {
            result.checked.Push(ep.path " (" ep.label ")")

            ; POST with empty body — 400/422 means endpoint exists, 404 means it doesn't
            probeResp := HttpClient.Request("POST", base ep.path, "", headers, timeout)

            if probeResp.error != ""
                continue

            ; Endpoint exists if we get anything other than 404/405
            if probeResp.status != 404 && probeResp.status != 405 {
                result.available := true
                result.endpointPath := ep.path
                result.docsUrl := base "/docs"
                return result
            }
        }

        ; Server reachable but no endpoint found
        result.error := "Server is reachable but no compatible transcription endpoint was found."
        return result
    }

    /**
     * Fetch available models from Whisper server
     * @returns {Object} {success: bool, models: Array, error: string}
     */
    GetModels() {
        if this.BaseUrl = ""
            return {success: false, models: [], error: "Server URL not configured"}

        try {
            url := RTrim(this.BaseUrl, "/") "/v1/models"
            headers := Map()
            if this.ApiKey != ""
                headers["Authorization"] := "Bearer " this.ApiKey

            response := HttpClient.Get(url, headers)

            if response.error != ""
                return {success: false, models: [], error: response.error}

            if response.status < 200 || response.status >= 300
                return {success: false, models: [], error: "HTTP " response.status}

            data := JSON.Load(response.body)
            models := []

            ; OpenAI format: {data: [{id: "model-name"}, ...]}
            if data is Map && data.Has("data") {
                for item in data["data"] {
                    if item is Map && item.Has("id")
                        models.Push(item["id"])
                    else if item.HasProp("id")
                        models.Push(item.id)
                }
            }

            return {success: true, models: models, error: ""}
        } catch as e {
            return {success: false, models: [], error: e.Message}
        }
    }
}
