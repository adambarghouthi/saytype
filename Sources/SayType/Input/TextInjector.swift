import AppKit
import CoreGraphics

struct TextInjector {

    static func inject(_ text: String) {
        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let savedContents = pasteboard.string(forType: .string)

        // Write text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay for clipboard to settle
        usleep(30_000) // 30ms

        // Post Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),  // V
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        // Restore clipboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let saved = savedContents {
                pasteboard.clearContents()
                pasteboard.setString(saved, forType: .string)
            }
        }
    }
}
