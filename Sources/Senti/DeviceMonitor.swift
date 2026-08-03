import Combine
import Foundation

/// Polls adb for connected devices.
///
/// adb has no push notification for attach and detach — the only way to know a phone arrived is
/// to ask. Polling is therefore the design, not a shortcut; what matters is asking off the main
/// thread and asking less often when nobody is looking.
@MainActor
final class DeviceMonitor: ObservableObject {

    @Published private(set) var devices: [Device] = []
    @Published private(set) var isRefreshing = false
    /// Nil until the first poll completes, so the panel can tell "no phones" from "not asked yet".
    @Published private(set) var hasPolled = false

    /// While the panel is open a plugged-in phone should appear almost at once.
    private static let fastInterval: TimeInterval = 1.5
    /// In the background this only has to be fast enough for the connect banner to feel prompt.
    private static let slowInterval: TimeInterval = 5

    private let toolchain: Toolchain
    private var timer: Timer?
    private var isPollingFast = false
    /// Guards against a slow `adb devices` overlapping the next tick.
    private var pollInFlight = false

    /// Called with devices that appeared since the previous poll. Drives connect banners and
    /// auto-mirror.
    var onDevicesAppeared: (([Device]) -> Void)?

    init(toolchain: Toolchain) {
        self.toolchain = toolchain
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Polling

    func start() {
        setPolling(fast: false)
        Task { await refresh() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Switches cadence. Cheap to call repeatedly — a no-op when already at that speed.
    func setPolling(fast: Bool) {
        guard timer == nil || fast != isPollingFast else { return }
        isPollingFast = fast
        timer?.invalidate()
        let interval = fast ? Self.fastInterval : Self.slowInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        if fast { Task { await refresh() } }
    }

    /// One poll. Safe to call at any time; overlapping calls collapse into one.
    func refresh() async {
        guard toolchain.isReady, !pollInFlight else { return }
        pollInFlight = true
        isRefreshing = true
        defer {
            pollInFlight = false
            isRefreshing = false
        }

        let adbPath = toolchain.adbPath
        let polled = await Task.detached(priority: .utility) {
            AdbService.listDevices(adbPath: adbPath)
        }.value

        // Stable order so rows do not jump around between polls: ready devices first, then by
        // name. adb's own order follows its internal transport table and does shuffle.
        let sorted = polled.sorted {
            if $0.isReady != $1.isReady { return $0.isReady }
            return $0.defaultName.localizedCaseInsensitiveCompare($1.defaultName) == .orderedAscending
        }

        let previous = Set(devices.filter(\.isReady).map(\.serial))
        let appeared = sorted.filter { $0.isReady && !previous.contains($0.serial) }

        // Assigning an identical array still fires objectWillChange and redraws the panel every
        // 1.5 seconds, which visibly interrupts a rename in progress.
        if sorted != devices { devices = sorted }
        hasPolled = true

        if !appeared.isEmpty { onDevicesAppeared?(appeared) }
    }
}
