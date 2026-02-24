#Requires AutoHotkey v2.0

/**
 * STTBase - Abstract base class for Speech-to-Text providers
 */
class STTBase {
    Name := "Base"

    /**
     * Transcribe audio file to text
     * @param filePath Path to WAV file
     * @param language Language code (e.g., "en-US")
     * @returns {Object} {success: bool, text: string, error: string}
     */
    Transcribe(filePath, language := "en-US") {
        return {success: false, text: "", error: "Not implemented"}
    }

    /**
     * Test if the provider is available/configured
     * @returns {Object} {available: bool, error: string}
     */
    TestConnection() {
        return {available: false, error: "Not implemented"}
    }
}
