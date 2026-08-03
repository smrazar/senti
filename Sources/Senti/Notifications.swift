import AppKit
@preconcurrency import UserNotifications

/// Connect banners: "Pixel 8 connected" with a Mirror button on it, so a session can start
/// without opening the panel.
///
/// Permission is asked the first time a banner is actually posted, not at launch — a permission
/// dialog before the user has plugged anything in reads as an app asking for something it has
/// not yet earned.
@MainActor
final class Notifications: NSObject, UNUserNotificationCenterDelegate {

    /// Called when the user taps Mirror on a banner.
    var onMirrorRequested: ((String) -> Void)?

    private var hasAskedPermission = false
    private var isAuthorized = false

    private let categoryID = "senti.deviceConnected"
    private let mirrorActionID = "senti.mirror"

    /// Only true inside a real app bundle. `UNUserNotificationCenter.current()` traps when the
    /// process has no bundle identifier, which is what a `swift run` from the terminal is.
    private var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    override init() {
        super.init()
        guard isAvailable else { return }
        UNUserNotificationCenter.current().delegate = self
        let mirror = UNNotificationAction(identifier: mirrorActionID, title: "Mirror", options: [.foreground])
        let category = UNNotificationCategory(identifier: categoryID,
                                              actions: [mirror],
                                              intentIdentifiers: [],
                                              options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func deviceConnected(serial: String, name: String) {
        guard isAvailable else { return }
        Task {
            guard await ensureAuthorized() else { return }
            let content = UNMutableNotificationContent()
            content.title = name
            content.body = "Connected over USB."
            content.categoryIdentifier = categoryID
            content.userInfo = ["serial": serial]
            content.sound = nil

            let request = UNNotificationRequest(identifier: "senti.connect.\(serial)",
                                                content: content,
                                                trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func ensureAuthorized() async -> Bool {
        if isAuthorized { return true }
        if hasAskedPermission { return isAuthorized }
        hasAskedPermission = true
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert])) ?? false
        isAuthorized = granted
        return granted
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let serial = info["serial"] as? String
        let action = response.actionIdentifier
        let wanted = mirrorActionID
        Task { @MainActor in
            if action == wanted, let serial {
                self.onMirrorRequested?(serial)
            }
            completionHandler()
        }
    }

    /// Without this, macOS suppresses a banner while the app is frontmost — which for a menu-bar
    /// app means any moment its settings window happens to be open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
}
