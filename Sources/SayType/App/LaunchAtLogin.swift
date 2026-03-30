import ServiceManagement
import os.log

struct LaunchAtLogin {
    private static let logger = Logger(subsystem: "com.saytype.app", category: "login")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
                logger.notice("[saytype] Unregistered login item")
            } else {
                if !Bundle.main.bundlePath.hasPrefix("/Applications") {
                    logger.warning("[saytype] App not in /Applications, login item may not persist")
                }
                try SMAppService.mainApp.register()
                logger.notice("[saytype] Registered login item")
            }
        } catch {
            logger.error("[saytype] Login item error: \(error)")
        }
    }
}
