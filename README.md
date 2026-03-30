# SayType

Voice-to-text for macOS. Speak and it types into any focused app.

SayType runs as a menu bar app — click to start listening, speak naturally, and your words appear wherever your cursor is. Built for hands-free use on Apple Silicon Macs.

## Features

- **Always-on dictation** — continuous listening with smart silence detection
- **Menu bar app** — unobtrusive, lives in your toolbar
- **Works everywhere** — types into any focused app (editors, terminals, browsers)
- **Voice commands** — say "send", "cancel", "undo" and more for keyboard actions
- **Fast** — uses WhisperKit with Core ML, optimized for Apple Silicon
- **Privacy** — all processing happens locally, nothing leaves your machine
- **Launch at Login** — optional, toggle from the menu bar

## Requirements

- macOS 14+ (Sonoma or later)
- Apple Silicon Mac (M1, M2, M3, M4)

## Install

1. Download the latest `.dmg` from [Releases](https://github.com/adambarghouthi/saytype/releases)
2. Open the DMG and drag SayType to Applications
3. Open SayType from Applications

### First Launch — Gatekeeper

Since SayType is not notarized with Apple, macOS will show a warning:

> "Apple could not verify SayType is free of malware"

To open it:
- **Option A:** Right-click SayType.app > **Open** > click **Open** in the dialog
- **Option B:** Go to **System Settings > Privacy & Security**, scroll down, and click **Open Anyway**

You only need to do this once.

### Onboarding

On first launch, SayType will:
1. Download the speech recognition model (~40 MB)
2. Ask for **Microphone** and **Accessibility** permissions
3. You're ready — click **ST** in the menu bar to start

## Voice Commands

| Say | Action |
|-----|--------|
| "send" / "submit" / "enter" / "confirm" | Press Enter |
| "cancel" / "cancel that" | Ctrl+C |
| "yes" / "yeah" / "approve" | Type `y` + Enter |
| "nope" / "deny" / "reject" | Type `n` + Enter |
| "undo" / "oops" / "backspace" | Delete word |
| "clear all" / "erase all" / "delete all" | Select all + delete |

Anything else is typed as dictated text. Short phrases containing a command word (e.g., "please send") are also recognized.

## Permissions

SayType needs two macOS permissions:

1. **Microphone** — to hear your voice (prompted automatically)
2. **Accessibility** — to type into other apps (open System Settings > Privacy & Security > Accessibility > enable SayType)

Both must be granted before SayType can work. The onboarding screen will guide you through this.

## Build from Source

```bash
git clone https://github.com/adambarghouthi/saytype.git
cd saytype
swift build -c release
bash Scripts/build-app.sh
cp -R dist/SayType.app /Applications/
```

## Uninstall

1. Quit SayType from the menu bar
2. Delete `/Applications/SayType.app`
3. Optionally remove cached data:
```bash
defaults delete com.saytype.app
rm -rf ~/Library/Caches/com.saytype.app
```

## How It Works

1. Microphone audio captured via AVAudioEngine at 16kHz
2. Voice activity detected with RMS energy thresholding
3. Speech transcribed by WhisperKit (on-device, Core ML)
4. Commands parsed from short utterances, text injected via clipboard + Cmd+V

## License

MIT
