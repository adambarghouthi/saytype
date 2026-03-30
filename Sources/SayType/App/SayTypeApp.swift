import AppKit

@main
struct SayTypeMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private let state = AppState.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()

        // Check if first launch (no model downloaded)
        if !ModelManager.shared.hasAnyModel() {
            OnboardingWindow.shared.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        TranscriptionEngine.shared.stop()
    }
}
