import AppKit

@MainActor
class StatusBarController {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let statusMenuItem: NSMenuItem
    private let toggleItem: NSMenuItem
    private var greenDot: NSImage?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()

        // Status line
        statusMenuItem = NSMenuItem(title: "Idle", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        // Version
        let versionItem = NSMenuItem(title: "SayType v1.0.0", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(.separator())

        // Toggle listening
        toggleItem = NSMenuItem(title: "Start Listening", action: #selector(toggleListening), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit SayType", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Setup status item
        if let button = statusItem.button {
            button.title = "ST"
        }
        statusItem.menu = menu

        // Create green dot image
        greenDot = makeCircleImage(size: 7.5, color: NSColor(red: 0.18, green: 0.80, blue: 0.34, alpha: 1.0))

        // Observe state changes
        setupObservers()
    }

    private func makeCircleImage(size: CGFloat, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size, height: size)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func setupObservers() {
        let state = AppState.shared
        // Poll state every 0.2s to update UI
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateUI(state: state)
            }
        }
    }

    private func updateUI(state: AppState) {
        statusMenuItem.title = state.statusText

        if state.isListening {
            toggleItem.title = "Stop Listening"
            if let button = statusItem.button {
                button.image = greenDot
                button.imagePosition = .imageTrailing
            }
            statusItem.button?.title = "ST "
        } else {
            toggleItem.title = "Start Listening"
            statusItem.button?.image = nil
            statusItem.button?.title = "ST"
        }

        // Disable start if model not ready
        toggleItem.isEnabled = state.modelReady || state.isListening
    }

    @objc private func toggleListening() {
        let state = AppState.shared
        if state.isListening {
            TranscriptionEngine.shared.stop()
        } else {
            TranscriptionEngine.shared.start()
        }
    }

    @objc private func showSettings() {
        OnboardingWindow.shared.show()
    }

    @objc private func quit() {
        TranscriptionEngine.shared.stop()
        NSApp.terminate(nil)
    }
}
