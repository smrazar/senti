import AppKit
import Combine

/// Wires the pieces together and owns the objects that must outlive any window: the toolchain,
/// the device poll, the running sessions and the menu-bar item.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let preferences = Preferences.shared
    let toolchain = Toolchain()
    let deviceStore = DeviceStore()
    let scrcpy: ScrcpyService
    let deviceMonitor: DeviceMonitor
    let notifications = Notifications()

    private var statusItem: StatusItemController?
    private var hotKey: HotKey?
    private var cancellables = Set<AnyCancellable>()
    private var hasCompletedFirstPoll = false

    private init() {
        scrcpy = ScrcpyService(toolchain: toolchain, preferences: preferences)
        deviceMonitor = DeviceMonitor(toolchain: toolchain)
    }

    // MARK: - Lifecycle

    func start() {
        statusItem = StatusItemController(state: self)

        // The glyph follows the session count, and the panel has to re-measure when the device
        // list changes underneath it.
        scrcpy.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions in
                self?.statusItem?.applySymbol(mirroring: !sessions.isEmpty)
                self?.statusItem?.resizePanel()
            }
            .store(in: &cancellables)

        deviceMonitor.$devices
            .receive(on: RunLoop.main)
            .sink { [weak self] devices in
                self?.deviceStore.remember(devices)
                self?.statusItem?.resizePanel()
            }
            .store(in: &cancellables)

        deviceMonitor.onDevicesAppeared = { [weak self] appeared in
            self?.handleAppeared(appeared)
        }

        notifications.onMirrorRequested = { [weak self] serial in
            self?.mirrorBySerial(serial)
        }

        applyHotKey()

        // "Open at login" ships on, and a stored preference alone does not register anything —
        // without this the setting would read as on while macOS knew nothing about it.
        if preferences.launchAtLogin && LoginItem.isAvailable && !LoginItem.isEnabled {
            preferences.launchAtLogin = LoginItem.setEnabled(true)
        }

        Task {
            await toolchain.provision()
            guard toolchain.isReady else { return }
            // Start the daemon up front so the first poll is not the thing that pays for it.
            let adbPath = toolchain.adbPath
            await Task.detached(priority: .utility) { AdbService.startServer(adbPath: adbPath) }.value
            deviceMonitor.start()
        }
    }

    // MARK: - Actions

    func mirror(_ device: Device) {
        scrcpy.start(device, displayName: deviceStore.displayName(for: device.serial, live: device))
    }

    func toggleMirror(_ device: Device) {
        if scrcpy.isMirroring(device.serial) {
            scrcpy.stop(device.serial)
        } else {
            mirror(device)
        }
    }

    private func mirrorBySerial(_ serial: String) {
        guard let device = deviceMonitor.devices.first(where: { $0.serial == serial }) else { return }
        mirror(device)
    }

    private func handleAppeared(_ devices: [Device]) {
        // Everything already plugged in "appears" on the first poll. Banners for those are
        // noise — the user did not just connect anything, they launched the app. Auto-mirror
        // still fires: a phone marked for it should be mirroring whenever senti is running.
        let isFirstPoll = !hasCompletedFirstPoll
        hasCompletedFirstPoll = true

        for device in devices {
            if preferences.autoMirrorSerials.contains(device.serial) {
                mirror(device)
            } else if preferences.notifyOnConnect && !isFirstPoll {
                notifications.deviceConnected(serial: device.serial,
                                              name: deviceStore.displayName(for: device.serial, live: device))
            }
        }
    }

    @objc func openSettingsAction() {
        openMainWindow()
    }

    @objc func stopAllAction() {
        scrcpy.stopAll()
    }

    func openMainWindow() {
        statusItem?.dismissPanel()
        MainWindowController.shared.present(state: self)
    }

    func openMainWindow(selecting pane: SettingsPane) {
        statusItem?.dismissPanel()
        MainWindowController.shared.present(state: self, pane: pane)
    }

    func togglePanel() {
        statusItem?.togglePanel()
    }

    // MARK: - Shortcut

    /// Registers the global shortcut, or tears it down when the user has cleared it. Returns
    /// false when the chord is already owned by another process — Settings shows that, because
    /// the alternative is a shortcut that silently never fires.
    @discardableResult
    func applyHotKey() -> Bool {
        hotKey?.unregister()
        hotKey = nil
        guard preferences.hotKeyCode != 0 || preferences.hotKeyModifiers != 0 else { return true }
        let key = HotKey(keyCode: UInt32(preferences.hotKeyCode),
                         modifiers: UInt32(preferences.hotKeyModifiers)) { [weak self] in
            self?.togglePanel()
        }
        guard key.register() else { return false }
        hotKey = key
        return true
    }
}
