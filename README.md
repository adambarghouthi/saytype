# SayType

Voice-to-text for macOS. Speak and it types into any focused app.

SayType runs as a menu bar app — click to start listening, speak naturally, and your words appear wherever your cursor is. Built for hands-free use on Apple Silicon Macs.

## Features

- **Always-on dictation** — continuous listening with smart silence detection
- **Menu bar app** — unobtrusive, lives in your toolbar
- **Works everywhere** — types into any focused app (editors, terminals, browsers)
- **Voice commands** — say "send", "cancel", "yes", "no" for keyboard actions
- **Fast** — uses WhisperKit with Core ML, optimized for Apple Silicon
- **Privacy** — all processing happens locally, nothing leaves your machine
- **Lightweight** — single binary, no Python, no dependencies to install

## Requirements

- macOS 14+ (Sonoma or later)
- Apple Silicon Mac (M1, M2, M3, M4)

## Install

Download the latest `.dmg` from [Releases](https://github.com/adambarghouthi/saytype/releases), open it, and drag SayType to Applications.

On first launch, SayType will:
1. Let you choose a transcription model
2. Download it (~40 MB for tiny.en)
3. Guide you through permissions setup

## Voice Commands

| Say | Action |
|-----|--------|
| "send" / "enter" / "go" / "submit" / "done" | Press Enter |
| "cancel" / "stop" | Press Ctrl+C |
| "yes" / "accept" / "approve" | Type `y` + Enter |
| "no" / "reject" / "deny" | Type `n` + Enter |

Anything else is typed as dictated text.

## Models

| Model | Size | Speed | Quality |
|-------|------|-------|---------|
| `tiny.en` | ~40 MB | Fastest | Good (default) |
| `base.en` | ~140 MB | Fast | Better |
| `small.en` | ~500 MB | Moderate | Best |

## Permissions

SayType needs two macOS permissions:

1. **Microphone** — prompted automatically on first launch
2. **Accessibility** — required for typing into other apps
   - System Settings > Privacy & Security > Accessibility > Enable SayType

## Build from Source

```bash
git clone https://github.com/adambarghouthi/saytype.git
cd saytype
swift build -c release
bash Scripts/build-app.sh
```

## How It Works

1. Microphone audio captured via AVAudioEngine
2. Voice activity detected with RMS energy thresholding
3. Speech transcribed by WhisperKit (on-device, Core ML)
4. Text injected via clipboard + CGEventPost

## License

MIT
