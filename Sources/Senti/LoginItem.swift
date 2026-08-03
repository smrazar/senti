import Foundation
import ServiceManagement

/// Launch-at-login, via `SMAppService`. No helper target and no login-items plist — the modern
/// API registers the main bundle itself.
@MainActor
enum LoginItem {

    /// False outside a real app bundle: `SMAppService` has nothing to register when the process
    /// is a bare binary from `swift run`.
    static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    static var isEnabled: Bool {
        guard isAvailable else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    /// Returns the state actually achieved, which is not always the one asked for — macOS can
    /// refuse when the user has disabled the item in System Settings.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard isAvailable else { return false }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("senti: could not \(enabled ? "register" : "unregister") the login item — \(error.localizedDescription)")
        }
        return isEnabled
    }
}
