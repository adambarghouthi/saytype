<p align="center">
  <img src="assets/icon.png" width="128" alt="SayType icon">
</p>

# SayType

Voice-to-text for macOS. Speak and it types into any focused app.

SayType runs as a menu bar app — click to start listening, speak naturally, and your words appear wherever your cursor is. Built for hands-free use.

## Features

- **Always-on dictation** — continuous listening with smart silence detection
- **Menu bar app** — unobtrusive, lives in your toolbar
- **Works everywhere** — types into any focused app (editors, terminals, browsers)
- **Voice commands** — say "send", "cancel", "yes", "no" for keyboard actions
- **Fast** — uses faster-whisper (tiny.en) for low-latency transcription on CPU
- **Privacy** — all processing happens locally, nothing leaves your machine

## Requirements

- macOS 13+ (Apple Silicon or Intel)
- Python 3.11+
- Microphone
- Accessibility permission (for keystroke injection)

## Install

### DMG (easiest)

Download the latest `.dmg` from [Releases](https://github.com/adambargh/saytype/releases), open it, and drag SayType to Applications.

### From source

```bash
git clone https://github.com/adambargh/saytype.git
cd saytype
pip install .
saytype setup
```

## Quick Start

```bash
# First time — downloads model and checks permissions
saytype setup

# Launch the menu bar app
saytype start

# Verify everything works
saytype check
```

Click **ST** in the menu bar, then click **Start Listening**. A green dot appears when active.

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
| `tiny.en` | ~75MB | Fast | Good for commands (default) |
| `small` | ~500MB | Moderate | Better accuracy |
| `medium` | ~1.5GB | Slower | Best accuracy |

```bash
saytype start --model small
```

## Permissions

SayType needs two macOS permissions:

1. **Microphone** — prompted automatically on first launch
2. **Accessibility** — required for typing into other apps
   - System Settings > Privacy & Security > Accessibility
   - Add SayType.app or your terminal

Run `saytype check` to verify permissions are working.

## How It Works

1. Microphone audio captured via `sounddevice`
2. Voice activity detected with `webrtcvad` (aggressiveness 3)
3. Speech transcribed by `faster-whisper` (local, on-device)
4. Text injected via clipboard + AppleScript (System Events)

## License

MIT
