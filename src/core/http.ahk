#Requires AutoHotkey v2.0

/**
 * HttpClient - HTTP request wrapper using WinHttp
 *
 * Uses WinHttp.WinHttpRequest.5.1 which is faster than MSXML2
 * and doesn't have caching or redirect issues.
 */
class HttpClient {
    static DefaultTimeout := 30000  ; 30 seconds

    /**
     * Make an HTTP request
     * @param method HTTP method (GET, POST, PUT, DELETE)
     * @param url Full URL to request
     * @param body Request body (string or will be JSON.Dump'd if object)
     * @param headers Map of header name => value
     * @param timeout Timeout in milliseconds
     * @returns {status, body, headers, error}
     */
    static Request(method, url, body := "", headers := Map(), timeout := 0) {
        if timeout = 0
            timeout := this.DefaultTimeout

        result := {
            status: 0,
            body: "",
            headers: "",
            error: ""
        }

        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")

            ; Set timeouts BEFORE Open for reliability
            whr.SetTimeouts(timeout, timeout, timeout, timeout)

            ; Use synchronous mode for reliability
            whr.Open(method, url, false)

            ; Set custom headers
            for name, value in headers
                whr.SetRequestHeader(name, value)

            ; Serialize body if it's an object (not string)
            sendBody := ""
            if body != "" {
                if IsObject(body) {
                    sendBody := JSON.Dump(body)
                    if !headers.Has("Content-Type")
                        whr.SetRequestHeader("Content-Type", "application/json")
                } else {
                    sendBody := body
                }
            }

            ; Send request
            whr.Send(sendBody)

            result.status := whr.Status
            result.body := whr.ResponseText
            result.headers := whr.GetAllResponseHeaders()
        } catch as e {
            result.error := e.Message
            result.status := 0
        }

        return result
    }

    /**
     * Make a GET request
     */
    static Get(url, headers := Map()) {
        return this.Request("GET", url, "", headers)
    }

    /**
     * Make a POST request
     */
    static Post(url, body, headers := Map()) {
        return this.Request("POST", url, body, headers)
    }

    /**
     * Make a POST request with JSON body and parse JSON response
     */
    static PostJSON(url, body, headers := Map()) {
        response := this.Post(url, body, headers)

        result := {
            success: false,
            data: "",
            error: "",
            status: response.status
        }

        if response.error {
            result.error := response.error
            return result
        }

        if response.status >= 200 && response.status < 300 {
            try {
                result.data := JSON.Load(response.body)
                result.success := true
            } catch as e {
                result.error := "JSON parse error: " e.Message
            }
        } else {
            try {
                errData := JSON.Load(response.body)
                hasError := (errData is Map) ? errData.Has("error") : errData.HasProp("error")
                if hasError {
                    errVal := errData["error"]
                    if IsObject(errVal) {
                        hasMsg := (errVal is Map) ? errVal.Has("message") : errVal.HasProp("message")
                        if hasMsg
                            result.error := errVal["message"]
                        else
                            result.error := String(errVal)
                    } else {
                        result.error := String(errVal)
                    }
                } else {
                    result.error := "HTTP " response.status
                }
            } catch {
                result.error := "HTTP " response.status ": " SubStr(response.body, 1, 200)
            }
        }

        return result
    }

    /**
     * POST multipart/form-data request (for file uploads like Whisper API)
     * @param url URL to request
     * @param fields Map of field name => value (strings)
     * @param filePath Path to file to upload
     * @param fileFieldName Field name for the file (default: "file")
     * @param headers Additional headers Map
     * @returns {status, body, headers, error}
     */
    static PostMultipart(url, fields := Map(), filePath := "", fileFieldName := "file", headers := Map(), timeout := 0) {
        if timeout = 0
            timeout := this.DefaultTimeout

        result := {
            status: 0,
            body: "",
            headers: "",
            error: ""
        }

        try {
            ; Generate boundary
            boundary := "----SimpleTranscriber" . A_TickCount . Random(10000, 99999)

            ; Build multipart body as binary buffer
            bodyParts := Buffer(0)
            CRLF := "`r`n"

            ; Add string fields
            textParts := ""
            for name, value in fields {
                textParts .= "--" boundary CRLF
                textParts .= 'Content-Disposition: form-data; name="' name '"' CRLF
                textParts .= CRLF
                textParts .= value CRLF
            }

            ; Read file if specified
            fileData := Buffer(0)
            fileHeader := ""
            if filePath != "" && FileExist(filePath) {
                SplitPath(filePath, &fileName)
                fileHeader := "--" boundary CRLF
                fileHeader .= 'Content-Disposition: form-data; name="' fileFieldName '"; filename="' fileName '"' CRLF
                fileHeader .= "Content-Type: application/octet-stream" CRLF
                fileHeader .= CRLF

                ; Read file as binary
                f := FileOpen(filePath, "r")
                fileData := Buffer(f.Length)
                f.RawRead(fileData, f.Length)
                f.Close()
            }

            ; Closing boundary
            closingBoundary := CRLF "--" boundary "--" CRLF

            ; Calculate total size
            textBytes := Buffer(StrPut(textParts, "UTF-8") - 1)
            StrPut(textParts, textBytes, "UTF-8")

            fileHeaderBytes := Buffer(StrPut(fileHeader, "UTF-8") - 1)
            StrPut(fileHeader, fileHeaderBytes, "UTF-8")

            closingBytes := Buffer(StrPut(closingBoundary, "UTF-8") - 1)
            StrPut(closingBoundary, closingBytes, "UTF-8")

            totalSize := textBytes.Size + fileHeaderBytes.Size + fileData.Size + closingBytes.Size
            fullBody := Buffer(totalSize)

            ; Assemble body
            offset := 0
            if textBytes.Size > 0 {
                DllCall("RtlMoveMemory", "Ptr", fullBody.Ptr + offset, "Ptr", textBytes.Ptr, "UInt", textBytes.Size)
                offset += textBytes.Size
            }
            if fileHeaderBytes.Size > 0 {
                DllCall("RtlMoveMemory", "Ptr", fullBody.Ptr + offset, "Ptr", fileHeaderBytes.Ptr, "UInt", fileHeaderBytes.Size)
                offset += fileHeaderBytes.Size
            }
            if fileData.Size > 0 {
                DllCall("RtlMoveMemory", "Ptr", fullBody.Ptr + offset, "Ptr", fileData.Ptr, "UInt", fileData.Size)
                offset += fileData.Size
            }
            if closingBytes.Size > 0 {
                DllCall("RtlMoveMemory", "Ptr", fullBody.Ptr + offset, "Ptr", closingBytes.Ptr, "UInt", closingBytes.Size)
            }

            ; Create ADODB.Stream to hold binary data for WinHttp
            stream := ComObject("ADODB.Stream")
            stream.Type := 1  ; adTypeBinary
            stream.Open()
            ; Write binary data via SafeArray
            pSA := DllCall("oleaut32\SafeArrayCreateVector", "UShort", 0x11, "UInt", 0, "UInt", totalSize, "Ptr")
            pvData := 0
            DllCall("oleaut32\SafeArrayAccessData", "Ptr", pSA, "Ptr*", &pvData)
            DllCall("RtlMoveMemory", "Ptr", pvData, "Ptr", fullBody.Ptr, "UInt", totalSize)
            DllCall("oleaut32\SafeArrayUnaccessData", "Ptr", pSA)

            bodyVariant := Buffer(16 + A_PtrSize, 0)
            NumPut("UShort", 0x2011, bodyVariant, 0)  ; VT_ARRAY | VT_UI1
            NumPut("Ptr", pSA, bodyVariant, 8)

            stream.Write(ComValue(0x2011, pSA))
            stream.Position := 0

            ; Send request
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.SetTimeouts(timeout, timeout, timeout, timeout)
            whr.Open("POST", url, false)

            ; Set content type with boundary
            whr.SetRequestHeader("Content-Type", "multipart/form-data; boundary=" boundary)

            ; Set additional headers
            for name, value in headers
                whr.SetRequestHeader(name, value)

            ; Send binary body
            whr.Send(stream.Read())
            stream.Close()

            ; Clean up SafeArray
            DllCall("oleaut32\SafeArrayDestroy", "Ptr", pSA)

            result.status := whr.Status
            result.body := whr.ResponseText
            result.headers := whr.GetAllResponseHeaders()
        } catch as e {
            result.error := e.Message
            result.status := 0
        }

        return result
    }

    /**
     * POST multipart with JSON response parsing (for Whisper API)
     */
    static PostMultipartJSON(url, fields := Map(), filePath := "", fileFieldName := "file", headers := Map()) {
        response := this.PostMultipart(url, fields, filePath, fileFieldName, headers)

        result := {
            success: false,
            data: "",
            error: "",
            status: response.status
        }

        if response.error {
            result.error := response.error
            return result
        }

        if response.status >= 200 && response.status < 300 {
            try {
                result.data := JSON.Load(response.body)
                result.success := true
            } catch as e {
                result.error := "JSON parse error: " e.Message
            }
        } else {
            try {
                errData := JSON.Load(response.body)
                hasError := (errData is Map) ? errData.Has("error") : errData.HasProp("error")
                if hasError {
                    errVal := errData["error"]
                    if IsObject(errVal) {
                        hasMsg := (errVal is Map) ? errVal.Has("message") : errVal.HasProp("message")
                        if hasMsg
                            result.error := errVal["message"]
                        else
                            result.error := String(errVal)
                    } else {
                        result.error := String(errVal)
                    }
                } else {
                    result.error := "HTTP " response.status
                }
            } catch {
                result.error := "HTTP " response.status ": " SubStr(response.body, 1, 200)
            }
        }

        return result
    }
}
