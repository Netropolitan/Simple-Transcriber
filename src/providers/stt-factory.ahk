#Requires AutoHotkey v2.0

/**
 * STTFactory - Creates STT provider instances based on configuration
 *
 * Reads General.Provider to determine which config section to use:
 * - "openai" -> [OpenAI] section, credential key "openai"
 * - "local"  -> [LocalWhisper] section, no API key
 *
 * Includes migration from legacy [Whisper] section and "whisper" credential key.
 */
class STTFactory {
    /**
     * Create a Whisper STT provider from config
     * @param config ConfigManager instance
     * @returns {STTWhisper} Provider instance
     */
    static Create(config) {
        this._MigrateLegacyConfig(config)

        provider := config.Get("General", "Provider", "openai")

        if provider = "local" {
            baseUrl := config.Get("LocalWhisper", "BaseUrl", "http://localhost:8080")
            model := config.Get("LocalWhisper", "Model", "whisper-1")
            responseFormat := config.Get("LocalWhisper", "ResponseFormat", "verbose_json")
            endpointPath := config.Get("LocalWhisper", "EndpointPath", "")
            return STTWhisper(baseUrl, model, "", responseFormat, endpointPath)
        }

        ; Default: openai
        baseUrl := config.Get("OpenAI", "BaseUrl", "https://api.openai.com")
        model := config.Get("OpenAI", "Model", "whisper-1")
        responseFormat := config.Get("OpenAI", "ResponseFormat", "verbose_json")
        apiKey := CredentialManager.Retrieve("openai")
        ; Fall back to legacy "whisper" credential key
        if apiKey = ""
            apiKey := CredentialManager.Retrieve("whisper")
        return STTWhisper(baseUrl, model, apiKey, responseFormat)
    }

    /**
     * Migrate legacy [Whisper] config to new [OpenAI] section
     * Only runs once - checks if [OpenAI] section exists yet
     */
    static _MigrateLegacyConfig(config) {
        ; Skip if already migrated (OpenAI section has a BaseUrl)
        existingUrl := config.Get("OpenAI", "BaseUrl", "")
        if existingUrl != ""
            return

        ; Check for legacy [Whisper] section
        legacyUrl := config.Get("Whisper", "BaseUrl", "")
        if legacyUrl = ""
            return

        ; Copy legacy values to [OpenAI] section
        config.Set("OpenAI", "BaseUrl", legacyUrl)
        config.Set("OpenAI", "Model", config.Get("Whisper", "Model", "whisper-1"))
        config.Set("OpenAI", "ResponseFormat", config.Get("Whisper", "ResponseFormat", "verbose_json"))

        ; Set provider if not already set
        if config.Get("General", "Provider", "") = ""
            config.Set("General", "Provider", "openai")

        ; Migrate credential from "whisper" to "openai"
        legacyKey := CredentialManager.Retrieve("whisper")
        if legacyKey != "" && CredentialManager.Retrieve("openai") = ""
            CredentialManager.Store("openai", legacyKey)
    }
}
