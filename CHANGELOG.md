# Changelog

## [Unreleased]

## [1.0.1] - 2026-02-24

### Added
- Update checking via GitHub Releases API with auto-download installer flow
- Analytics reporting (anonymous usage stats to brew endpoint)
- Install ID generation (UUID v4) for anonymous telemetry
- Monthly auto-update check with configurable opt-out
- "Check for Updates" button in Settings > About section
- "Disclaimer" button in Settings > About section with full legal text
- `/startup` command-line flag for Windows startup launch
- `StartMinimized` setting for system tray-only startup
- Installer wizard (4-step: Welcome/License > Location > Options > Install)
- Uninstaller wizard (3-step: Confirm > Options > Uninstall)
- FFmpeg download option in installer with description
- Windows registry entries for Add/Remove Programs
- Desktop and Start Menu shortcut creation
- Run on Windows startup option (via registry)
- New multi-size app icon (16, 32, 48, 256px) from SVG logo
- Build scripts for compiling installer and uninstaller
- Server warmup ping on window show to pre-load local Whisper models
- Retry logic (3 attempts with backoff) for transient server errors
- Contextual error messages for HTTP 500/401/413/429/503 errors

### Changed
- `build-all.bat` now produces SimpleTranscriber-Setup.exe and Uninstall.exe
- `compile.bat` now copies icon.ico to build folder
- `settings.default.ini` includes [Updates] section and StartMinimized key
- FFmpeg now downloads to app folder instead of AppData (survives settings reset)
- Local Whisper servers no longer receive OpenAI-only `timestamp_granularities` field

### Fixed
- Keyboard accessibility: added Alt+key accelerators to all buttons (A11Y-002, A11Y-003)
- Screen reader accessibility: added tooltip to settings gear icon button (A11Y-001)
- Keyboard accessibility: GitHub link in settings now uses Link control instead of Text (A11Y-009)
- Transcription failing on local Whisper servers due to unsupported API fields

## [1.0.0] - 2026-02-24

### Added
- Drag-and-drop file transcription with editable output
- OpenAI Whisper API integration with verbose_json response format
- Automatic paragraph breaks based on configurable pause threshold
- Optional timestamp insertion in transcription output
- FFmpeg integration for video audio extraction and large file splitting
- Auto-download of FFmpeg from GitHub (gyan.dev essentials build)
- File chunking for audio files exceeding Whisper's 25MB limit
- Save transcription as UTF-8 .txt file
- Copy transcription to clipboard
- Settings window with Whisper API, output, and FFmpeg configuration
- System tray integration (left-click to open, menu for settings/exit)
- Dark/light theme support
- DPAPI-encrypted API key storage
- Progress bar and status updates during transcription
- Support for mp3, wav, mp4, m4a, ogg, flac, webm, mov, mkv, avi, wmv formats
