# Simple Transcriber

Audio/Video to Text transcription tool for Windows.

Drop any audio or video file into Simple Transcriber and get a clean, formatted text transcript powered by OpenAI Whisper (or any compatible API).

## Features

- **Drag-and-Drop**: Drop audio/video files directly onto the window
- **File Browser**: Browse and select files with supported format filtering
- **Smart Paragraphs**: Automatically inserts paragraph breaks at natural pauses
- **Optional Timestamps**: Include `[HH:MM:SS]` timestamps in output
- **Large File Support**: Automatically splits files >25MB into chunks
- **Video Support**: Extracts audio from video files via FFmpeg
- **Editable Output**: Review and edit transcription before saving
- **Export**: Save as UTF-8 .txt file or copy to clipboard
- **System Tray**: Runs in the background, always accessible

## Supported Formats

| Type | Formats |
|------|---------|
| **Audio** | mp3, wav, m4a, ogg, flac, mpga, mpeg |
| **Video** | mp4, webm, mov, mkv, avi, wmv, flv |

## Getting Started

### From Release
1. Download `SimpleTranscriber.exe` from [Releases](https://github.com/Netropolitan/Simple-Transcriber/releases)
2. Run the application
3. On first launch, open Settings and enter your OpenAI API key
4. Drop an audio or video file onto the window

### From Source
1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Clone this repository
3. Run `src/main.ahk`

## Configuration

Open Settings via the gear icon or system tray:

| Section | Options |
|---------|---------|
| **Whisper API** | Server URL, API key, model name |
| **Output** | Default output folder, paragraph break threshold, timestamps |
| **FFmpeg** | Status and download option |
| **About** | Version, developer info, links |

### Whisper API

Simple Transcriber works with:
- **OpenAI API** (default): Set server URL to `https://api.openai.com` and provide your API key
- **Local Whisper Server**: Point to any OpenAI-compatible Whisper endpoint (e.g., faster-whisper-server)

### FFmpeg

FFmpeg is required for:
- Processing video files (audio extraction)
- Splitting audio files larger than 25MB

On first use requiring FFmpeg, the app will offer to download it automatically.

## Building

See [BUILDING.md](BUILDING.md) for compilation instructions.

## Privacy

- Audio/video files are processed via the configured Whisper API endpoint
- Temporary files (extracted audio, chunks) are cleaned up automatically
- API keys are encrypted using Windows DPAPI (per-user, per-machine)
- No data is stored permanently beyond the exported text files you save

## Requirements

- Windows 10 or 11
- OpenAI API key (or compatible Whisper server)
- FFmpeg (for video files and large audio files - auto-download available)
- AutoHotkey v2 (only if running from source)

## License

CC BY-NC-ND 4.0 (Creative Commons Attribution-NonCommercial-NoDerivatives) - See [LICENSE](LICENSE)

## Developer

(c) 2026 Jamie Bykov-Brett - [Bykov-Brett Enterprises](https://bykovbrett.net/)

Built for [Netropolitan Academy](https://netropolitan.xyz/)
