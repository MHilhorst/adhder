import Foundation
import ServiceManagement

/// Registers the app as a login item via the modern ServiceManagement API.
/// Requires the app to run from a proper .app bundle (which build_app.sh produces).
enum LaunchAtLogin {
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            NSLog("Adhder: failed to \(enabled ? "register" : "unregister") login item: \(error)")
            return false
        }
    }

    static func toggle() {
        set(!isEnabled)
    }
}
