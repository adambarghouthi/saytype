import AppKit
import SwiftUI

@MainActor
class OnboardingWindow {
    static let shared = OnboardingWindow()

    private var window: NSWindow?

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = OnboardingView()
        let hostingView = NSHostingView(rootView: view)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "SayType Setup"
        w.contentView = hostingView
        w.center()
        w.isReleasedWhenClosed = false
        w.level = .floating

        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }
}
