import Combine
import Foundation

/// Remembers phones between launches: what the user renamed them to, and when each was last
/// seen. The panel uses it to keep a known device visible with a "not connected" line rather
/// than having the list empty out the moment a cable is pulled.
@MainActor
final class DeviceStore: ObservableObject {

    struct Entry: Codable, Hashable, Sendable {
        let serial: String
        /// What adb last reported, so a remembered device still has a name when unplugged.
        var lastKnownName: String
        /// User-typed name. Wins over `lastKnownName` everywhere it is set.
        var customName: String?
        var lastSeen: Date
    }

    @Published private(set) var entries: [String: Entry] = [:]

    private let store = UserDefaults.standard
    private let key = "senti.deviceHistory"
    private var lastSaved = Date.distantPast

    init() {
        load()
    }

    // MARK: - Naming

    /// The name to show for a serial. Custom name, else what adb said, else the serial itself.
    func displayName(for serial: String, live: Device? = nil) -> String {
        if let custom = entries[serial]?.customName, !custom.isEmpty { return custom }
        if let live { return live.defaultName }
        if let remembered = entries[serial]?.lastKnownName, !remembered.isEmpty { return remembered }
        return serial
    }

    /// Passing nil or an empty string clears the custom name and falls back to the model.
    func setCustomName(_ name: String?, for serial: String) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var entry = entries[serial] else { return }
        entry.customName = (trimmed?.isEmpty ?? true) ? nil : trimmed
        entries[serial] = entry
        save()
    }

    // MARK: - Lifecycle

    /// Called after every poll. Records what was seen, leaving everything else untouched.
    ///
    /// The poll runs every 1.5 seconds while the panel is open, and `lastSeen` changes on every
    /// one of them. Writing that straight through would mean a UserDefaults write twice a second
    /// for as long as a phone is plugged in, so a plain timestamp refresh is held in memory and
    /// flushed at most once a minute. Anything that actually changes — a new phone, a new model
    /// name — is written immediately.
    func remember(_ devices: [Device]) {
        guard !devices.isEmpty else { return }
        let now = Date()
        var isMaterial = false

        for device in devices {
            if var entry = entries[device.serial] {
                if entry.lastKnownName != device.defaultName {
                    entry.lastKnownName = device.defaultName
                    isMaterial = true
                }
                entry.lastSeen = now
                entries[device.serial] = entry
            } else {
                entries[device.serial] = Entry(serial: device.serial,
                                               lastKnownName: device.defaultName,
                                               customName: nil,
                                               lastSeen: now)
                isMaterial = true
            }
        }

        if isMaterial || now.timeIntervalSince(lastSaved) > Self.timestampFlushInterval {
            save()
        }
    }

    /// How stale a persisted `lastSeen` is allowed to get while a phone stays connected. Only
    /// affects the "2 minutes ago" line after a relaunch.
    private static let timestampFlushInterval: TimeInterval = 60

    func forget(_ serial: String) {
        entries[serial] = nil
        save()
    }

    func forgetAll() {
        entries = [:]
        save()
    }

    /// Remembered devices that are not currently plugged in, newest first.
    func absentEntries(connected: [Device]) -> [Entry] {
        let live = Set(connected.map(\.serial))
        return entries.values
            .filter { !live.contains($0.serial) }
            .sorted { $0.lastSeen > $1.lastSeen }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = store.data(forKey: key) else { return }
        guard let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            // A store we cannot read is a store we replace. Keeping it would mean every
            // subsequent save silently fails to fix the file.
            NSLog("senti: device history could not be read; starting a fresh one")
            store.removeObject(forKey: key)
            return
        }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        store.set(data, forKey: key)
        lastSaved = Date()
    }
}
