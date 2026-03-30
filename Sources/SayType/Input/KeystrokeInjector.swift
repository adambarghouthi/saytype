import CoreGraphics
import Foundation

struct KeystrokeInjector {

    static func pressEnter() {
        postKey(keyCode: 0x24) // Return
    }

    static func pressCtrlC() {
        postKey(keyCode: 0x08, flags: .maskControl) // C
    }

    static func typeCharAndEnter(_ char: Character) {
        // Type the character
        let source = CGEventSource(stateID: .hidSystemState)
        if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
            var chars = [UniChar](String(char).utf16)
            event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            event.post(tap: .cghidEventTap)
        }
        if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            var chars = [UniChar](String(char).utf16)
            event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            event.post(tap: .cghidEventTap)
        }
        usleep(20_000) // 20ms
        pressEnter()
    }

    private static func postKey(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        if !flags.isEmpty {
            keyDown.flags = flags
            keyUp.flags = flags
        }
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
