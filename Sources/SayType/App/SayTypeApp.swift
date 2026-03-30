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

        if !state.hasCompletedOnboarding {
            OnboardingWindow.shared.show()
        } else {
            Task {
                do {
                    try await TranscriptionEngine.shared.loadModel()
                } catch {
                    print("[saytype] Failed to load model: \(error)")
                    OnboardingWindow.shared.show()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        TranscriptionEngine.shared.stop()
    }
}
