import Foundation

/// Starts and stops scrcpy. One process per device; scrcpy owns its own window.
///
/// There is no engine abstraction here on purpose. scrcpy is the only way senti mirrors, so a
/// protocol with one implementation would be a layer that hides `Process` without replacing it.
@MainActor
final class ScrcpyService: ObservableObject {

    /// One live scrcpy process, and where it is writing if the session is being recorded.
    struct Session {
        let process: Process
        let recordingURL: URL?
    }

    /// Serials with a live session. The panel reads this to pick Mirror or Stop.
    @Published private(set) var sessions: [String: Session] = [:]
    /// Last failure, shown in the panel until it is cleared.
    @Published var lastError: String?

    private let toolchain: Toolchain
    private let preferences: Preferences

    init(toolchain: Toolchain, preferences: Preferences) {
        self.toolchain = toolchain
        self.preferences = preferences
    }

    func isMirroring(_ serial: String) -> Bool { sessions[serial] != nil }
    func isRecording(_ serial: String) -> Bool { sessions[serial]?.recordingURL != nil }
    var hasAnySession: Bool { !sessions.isEmpty }

    // MARK: - Start

    /// Launches scrcpy for one device. Does nothing if that device is already mirroring.
    @discardableResult
    func start(_ device: Device, displayName: String) -> Bool {
        guard sessions[device.serial] == nil else { return true }
        guard toolchain.isReady else {
            lastError = "The scrcpy toolchain is not ready yet."
            return false
        }
        guard device.isReady else {
            lastError = device.statusText
            return false
        }

        let destination = recordingURL(for: displayName)
        let arguments = Self.arguments(for: device,
                                       displayName: displayName,
                                       preferences: preferences,
                                       recordingURL: destination)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolchain.scrcpyPath)
        process.arguments = arguments

        // scrcpy finds adb and its server jar through the environment. Without these it falls
        // back to whatever `adb` is on PATH — which for a Finder-launched app is usually none,
        // and if Android Studio is installed is a *different* adb fighting us for port 5037.
        var environment = ProcessInfo.processInfo.environment
        environment["ADB"] = toolchain.adbPath
        environment["SCRCPY_SERVER_PATH"] = URL(fileURLWithPath: toolchain.scrcpyPath)
            .deletingLastPathComponent()
            .appendingPathComponent("scrcpy-server").path
        process.environment = environment

        // scrcpy is chatty on stderr even when healthy; we only want to know it died.
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let serial = device.serial
        process.terminationHandler = { [weak self] finished in
            Task { @MainActor in
                self?.handleTermination(serial: serial, status: finished.terminationStatus)
            }
        }

        do {
            if destination != nil {
                try FileManager.default.createDirectory(at: preferences.recordingFolder,
                                                        withIntermediateDirectories: true)
            }
            try process.run()
        } catch {
            lastError = "scrcpy would not start: \(error.localizedDescription)"
            return false
        }

        sessions[serial] = Session(process: process, recordingURL: destination)
        lastError = nil
        return true
    }

    // MARK: - Stop

    func stop(_ serial: String) {
        guard let session = sessions[serial] else { return }
        // SIGTERM, not SIGKILL: scrcpy needs to close the video stream and tear down its
        // server on the phone. Killed outright it leaves the phone's screen off after a
        // `--turn-screen-off` session, and truncates a recording mid-file.
        session.process.terminate()
        sessions[serial] = nil
    }

    func stopAll() {
        for serial in sessions.keys { stop(serial) }
    }

    private func handleTermination(serial: String, status: Int32) {
        guard sessions[serial] != nil else { return }
        sessions[serial] = nil
        // 0 is a clean quit; 1 is what scrcpy returns when the user closes its window mid-stream.
        if status != 0 && status != 1 {
            lastError = "Mirroring stopped unexpectedly (code \(status))."
        }
    }

    // MARK: - Recording destination

    private func recordingURL(for displayName: String) -> URL? {
        guard preferences.recordingEnabled else { return nil }
        let stamp = Self.timestampFormatter.string(from: Date())
        let safeName = displayName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return preferences.recordingFolder
            .appendingPathComponent("\(safeName) \(stamp).\(preferences.recordingFormat)")
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter
    }()

    // MARK: - Command line

    /// Builds the scrcpy argument list. Static and pure so the self-check can assert on it
    /// without launching anything.
    static func arguments(for device: Device,
                          displayName: String,
                          preferences: Preferences,
                          recordingURL: URL?) -> [String] {
        var args = ["--serial=\(device.serial)"]

        args.append("--video-codec=\(preferences.videoCodec)")
        args.append("--video-bit-rate=\(preferences.videoBitrateMbps)M")
        args.append("--max-fps=\(preferences.maxFPS)")
        args.append("--max-size=\(preferences.maxSize)")

        if preferences.audioEnabled {
            args.append("--audio-codec=\(preferences.audioCodec)")
            args.append("--audio-bit-rate=\(preferences.audioBitrateKbps)K")
        } else {
            args.append("--no-audio")
        }

        if preferences.alwaysOnTop { args.append("--always-on-top") }
        if preferences.borderless { args.append("--window-borderless") }
        if preferences.stayAwake { args.append("--stay-awake") }
        if preferences.keepActive { args.append("--keep-active") }
        if preferences.turnScreenOff { args.append("--turn-screen-off") }
        if preferences.timeLimitMinutes > 0 {
            args.append("--time-limit=\(preferences.timeLimitMinutes * 60)")
        }

        if let recordingURL {
            args.append("--record=\(recordingURL.path)")
        }

        args.append("--window-title=\(displayName)")

        if preferences.useNewDisplay {
            args.append(contentsOf: VirtualDisplaySpec.from(preferences).arguments)
        }

        // Last, so anything the user set by hand in Advanced is visible at the end of the
        // command line rather than buried among the managed options. `ScrcpyFlags` refuses to
        // emit anything senti already set above, so nothing here can contradict a setting.
        args.append(contentsOf: ScrcpyFlags.arguments(from: preferences.advancedFlagValues))
        return args
    }
}

#if DEBUG
extension ScrcpyService {
    @MainActor
    static func selfCheck(preferences: Preferences) {
        let device = Device(serial: "R5CT30ABCDE", state: .ready, model: "SM F956B", product: nil)

        let audioOn = arguments(for: device, displayName: "Fold", preferences: preferences, recordingURL: nil)
        assert(audioOn.contains("--serial=R5CT30ABCDE"), "serial must be pinned or scrcpy grabs the wrong phone")
        assert(audioOn.contains("--max-fps=\(preferences.maxFPS)"), "fps cap missing from the command line")
        assert(!audioOn.contains { $0.hasPrefix("--record=") }, "recording off must emit no --record")

        let wasEnabled = preferences.audioEnabled
        preferences.audioEnabled = false
        let audioOff = arguments(for: device, displayName: "Fold", preferences: preferences, recordingURL: nil)
        assert(audioOff.contains("--no-audio"), "audio off must emit --no-audio")
        assert(!audioOff.contains { $0.hasPrefix("--audio-codec=") },
               "--no-audio and --audio-codec together makes scrcpy exit with a usage error")
        preferences.audioEnabled = wasEnabled

        let recorded = arguments(for: device,
                                 displayName: "Fold",
                                 preferences: preferences,
                                 recordingURL: URL(fileURLWithPath: "/tmp/a b.mp4"))
        assert(recorded.contains("--record=/tmp/a b.mp4"),
               "the record path goes in unquoted — Process passes argv directly, so shell quoting would become part of the filename")

        // The virtual display is a mode, not an extra: off, none of its flags may appear.
        assert(!audioOn.contains { $0.hasPrefix("--new-display") },
               "virtual display is off but --new-display was emitted")

        let wasNewDisplay = preferences.useNewDisplay
        preferences.useNewDisplay = true
        let virtual = arguments(for: device, displayName: "Fold", preferences: preferences, recordingURL: nil)
        assert(virtual.contains { $0.hasPrefix("--new-display") },
               "virtual display is on but --new-display is missing")
        preferences.useNewDisplay = wasNewDisplay
    }
}
#endif
