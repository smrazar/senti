import Combine
import Foundation

/// UserDefaults-backed settings — the single source of truth. Every view reads this; nothing
/// else keeps a copy.
///
/// Keys are namespaced `senti.*` and this app writes no others. Nothing secret lives here:
/// `defaults read com.local.senti` is a plain-text dump readable by anything running as the user.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let store = UserDefaults.standard

    // MARK: Video
    //
    // 60 fps and 1080 px are the *defaults*, not limits. Both can go higher — up to 120 fps and
    // 2160 px — for a phone and a Mac that can keep up. They are where they are because that
    // combination is smooth on every device tested and cheap on battery, not because anything
    // above it is unsafe.

    /// `h264` · `h265` · `av1`. h264 is the safe default — every device encodes it in hardware.
    @Published var videoCodec: String { didSet { store.set(videoCodec, forKey: K.videoCodec) } }
    @Published var videoBitrateMbps: Int { didSet { store.set(videoBitrateMbps, forKey: K.videoBitrate) } }
    @Published var maxFPS: Int { didSet { store.set(maxFPS, forKey: K.maxFPS) } }
    @Published var maxSize: Int { didSet { store.set(maxSize, forKey: K.maxSize) } }

    // MARK: Audio

    @Published var audioEnabled: Bool { didSet { store.set(audioEnabled, forKey: K.audioEnabled) } }
    /// `opus` · `aac` · `flac` · `raw`.
    @Published var audioCodec: String { didSet { store.set(audioCodec, forKey: K.audioCodec) } }
    @Published var audioBitrateKbps: Int { didSet { store.set(audioBitrateKbps, forKey: K.audioBitrate) } }

    // MARK: Window

    @Published var alwaysOnTop: Bool { didSet { store.set(alwaysOnTop, forKey: K.alwaysOnTop) } }
    @Published var borderless: Bool { didSet { store.set(borderless, forKey: K.borderless) } }
    /// Keeps the phone's screen on while mirroring.
    @Published var stayAwake: Bool { didSet { store.set(stayAwake, forKey: K.stayAwake) } }
    /// Stops the phone dimming and locking mid-session.
    @Published var keepActive: Bool { didSet { store.set(keepActive, forKey: K.keepActive) } }
    /// Turns the phone's own screen off while mirroring — the display stays live on the Mac.
    @Published var turnScreenOff: Bool { didSet { store.set(turnScreenOff, forKey: K.turnScreenOff) } }
    /// Minutes before a session stops on its own. 0 means run until stopped.
    @Published var timeLimitMinutes: Int { didSet { store.set(timeLimitMinutes, forKey: K.timeLimit) } }

    // MARK: Recording

    @Published var recordingEnabled: Bool { didSet { store.set(recordingEnabled, forKey: K.recordingEnabled) } }
    /// `mp4` · `mkv`.
    @Published var recordingFormat: String { didSet { store.set(recordingFormat, forKey: K.recordingFormat) } }
    @Published var recordingFolderPath: String { didSet { store.set(recordingFolderPath, forKey: K.recordingFolder) } }

    var recordingFolder: URL { URL(fileURLWithPath: recordingFolderPath) }

    // MARK: General

    @Published var launchAtLogin: Bool { didSet { store.set(launchAtLogin, forKey: K.launchAtLogin) } }
    /// A banner when a phone is plugged in, with a Mirror button on it.
    @Published var notifyOnConnect: Bool { didSet { store.set(notifyOnConnect, forKey: K.notifyOnConnect) } }
    /// Serials that start mirroring the moment they are plugged in.
    @Published var autoMirrorSerials: [String] { didSet { store.set(autoMirrorSerials, forKey: K.autoMirror) } }

    // MARK: Shortcut
    //
    // 0 key code with 0 modifiers means "no shortcut set" — `HotKey` refuses to register that
    // rather than binding the A key with no modifier.

    @Published var hotKeyCode: Int { didSet { store.set(hotKeyCode, forKey: K.hotKeyCode) } }
    @Published var hotKeyModifiers: Int { didSet { store.set(hotKeyModifiers, forKey: K.hotKeyModifiers) } }

    // MARK: Virtual display
    //
    // On: Mirror opens a *second* Android display rather than a copy of the phone's screen. The
    // phone stays usable while an app runs over here.

    @Published var useNewDisplay: Bool { didSet { store.set(useNewDisplay, forKey: K.useNewDisplay) } }
    /// `1920x1080`, or empty for the phone's own display size.
    @Published var newDisplaySize: String { didSet { store.set(newDisplaySize, forKey: K.newDisplaySize) } }
    /// 0 means the phone's default density.
    @Published var newDisplayDPI: Int { didSet { store.set(newDisplayDPI, forKey: K.newDisplayDPI) } }
    @Published var newDisplayStartApp: String { didSet { store.set(newDisplayStartApp, forKey: K.newDisplayStartApp) } }
    @Published var newDisplayForceStop: Bool { didSet { store.set(newDisplayForceStop, forKey: K.newDisplayForceStop) } }
    @Published var newDisplayKeepContent: Bool { didSet { store.set(newDisplayKeepContent, forKey: K.newDisplayKeepContent) } }
    @Published var newDisplayHideDecorations: Bool { didSet { store.set(newDisplayHideDecorations, forKey: K.newDisplayHideDecorations) } }
    @Published var newDisplayResizeWithWindow: Bool { didSet { store.set(newDisplayResizeWithWindow, forKey: K.newDisplayResize) } }

    // MARK: Appearance

    /// `FrostStyle.rawValue` — whether the desktop shows through senti's surfaces. One switch,
    /// no amount to choose; see `FrostStyle`.
    @Published var frostStyle: String { didSet { store.set(frostStyle, forKey: K.frostStyle) } }

    // MARK: Advanced flags

    /// Raw scrcpy options the user turned on in the Advanced pane, as `flag: value`. An empty
    /// value means a switch that takes no value. Flags senti manages itself are never stored
    /// here — see `ScrcpyFlags.managed`.
    @Published var advancedFlagValues: [String: String] {
        didSet { store.set(advancedFlagValues, forKey: K.advancedFlags) }
    }

    // MARK: Onboarding

    @Published var hasSeenTour: Bool { didSet { store.set(hasSeenTour, forKey: K.hasSeenTour) } }

    // MARK: - Init

    private init() {
        // A local reference, not `self.store`: reading a property before every stored property
        // is initialised is not allowed, and these helpers run during that window.
        let defaults = UserDefaults.standard
        func string(_ key: String, _ fallback: String) -> String {
            defaults.string(forKey: key) ?? fallback
        }
        func int(_ key: String, _ fallback: Int) -> Int {
            defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
        }
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
        }

        videoCodec = string(K.videoCodec, Default.videoCodec)
        videoBitrateMbps = int(K.videoBitrate, Default.videoBitrateMbps)
        maxFPS = int(K.maxFPS, Default.maxFPS)
        maxSize = int(K.maxSize, Default.maxSize)

        audioEnabled = bool(K.audioEnabled, true)
        audioCodec = string(K.audioCodec, "opus")
        audioBitrateKbps = int(K.audioBitrate, 128)

        alwaysOnTop = bool(K.alwaysOnTop, Default.alwaysOnTop)
        borderless = bool(K.borderless, false)
        stayAwake = bool(K.stayAwake, true)
        keepActive = bool(K.keepActive, Default.keepActive)
        turnScreenOff = bool(K.turnScreenOff, Default.turnScreenOff)
        timeLimitMinutes = int(K.timeLimit, 0)

        recordingEnabled = bool(K.recordingEnabled, false)
        recordingFormat = string(K.recordingFormat, "mp4")
        recordingFolderPath = string(
            K.recordingFolder,
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Movies/senti", isDirectory: true).path
        )

        launchAtLogin = bool(K.launchAtLogin, Default.launchAtLogin)
        notifyOnConnect = bool(K.notifyOnConnect, Default.notifyOnConnect)
        autoMirrorSerials = store.stringArray(forKey: K.autoMirror) ?? []

        hotKeyCode = int(K.hotKeyCode, 0)
        hotKeyModifiers = int(K.hotKeyModifiers, 0)

        useNewDisplay = bool(K.useNewDisplay, false)
        newDisplaySize = string(K.newDisplaySize, "")
        newDisplayDPI = int(K.newDisplayDPI, 0)
        newDisplayStartApp = string(K.newDisplayStartApp, "")
        newDisplayForceStop = bool(K.newDisplayForceStop, false)
        newDisplayKeepContent = bool(K.newDisplayKeepContent, false)
        newDisplayHideDecorations = bool(K.newDisplayHideDecorations, false)
        newDisplayResizeWithWindow = bool(K.newDisplayResize, false)

        // Nil rather than a default, so `migrating` can tell "never set" from "set to Solid" and
        // carry a v1.1–v1.4 three-stage value forward instead of silently resetting it.
        frostStyle = FrostStyle.migrating(stored: defaults.string(forKey: K.frostStyle)).rawValue
        advancedFlagValues = defaults.dictionary(forKey: K.advancedFlags) as? [String: String] ?? [:]

        hasSeenTour = bool(K.hasSeenTour, false)
    }

    /// What a fresh install starts with.
    ///
    /// These are a real working configuration, measured off a live setup rather than picked
    /// from scrcpy's documentation: h265 at 4 Mbps and 720px is sharp enough on a phone-shaped
    /// window and much lighter than 8 Mbps at 1080, and 120 fps is what makes it feel immediate.
    /// The three window options are on because a phone being mirrored is a phone you are not
    /// holding: it should stay awake, stay unlocked, and keep its own screen dark.
    enum Default {
        static let videoCodec = "h265"
        static let videoBitrateMbps = 4
        static let maxFPS = 120
        static let maxSize = 720
        static let alwaysOnTop = true
        static let keepActive = true
        static let turnScreenOff = true
        static let launchAtLogin = true
        /// Off: the banner interrupts, and the panel is one click away.
        static let notifyOnConnect = false
    }

    /// Wipes every `senti.*` key and reloads the defaults. Used by Settings → General → Reset.
    func resetAll() {
        for key in K.all { store.removeObject(forKey: key) }
        store.synchronize()

        videoCodec = Default.videoCodec
        videoBitrateMbps = Default.videoBitrateMbps
        maxFPS = Default.maxFPS
        maxSize = Default.maxSize
        audioEnabled = true
        audioCodec = "opus"
        audioBitrateKbps = 128
        alwaysOnTop = Default.alwaysOnTop
        borderless = false
        stayAwake = true
        keepActive = Default.keepActive
        turnScreenOff = Default.turnScreenOff
        timeLimitMinutes = 0
        recordingEnabled = false
        recordingFormat = "mp4"
        recordingFolderPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/senti", isDirectory: true).path
        launchAtLogin = Default.launchAtLogin
        notifyOnConnect = Default.notifyOnConnect
        autoMirrorSerials = []
        hotKeyCode = 0
        hotKeyModifiers = 0
        useNewDisplay = false
        newDisplaySize = ""
        newDisplayDPI = 0
        newDisplayStartApp = ""
        newDisplayForceStop = false
        newDisplayKeepContent = false
        newDisplayHideDecorations = false
        newDisplayResizeWithWindow = false
        frostStyle = FrostStyle.frosted.rawValue
        advancedFlagValues = [:]
        hasSeenTour = false
    }

    private enum K {
        static let videoCodec = "senti.videoCodec"
        static let videoBitrate = "senti.videoBitrateMbps"
        static let maxFPS = "senti.maxFPS"
        static let maxSize = "senti.maxSize"
        static let audioEnabled = "senti.audioEnabled"
        static let audioCodec = "senti.audioCodec"
        static let audioBitrate = "senti.audioBitrateKbps"
        static let alwaysOnTop = "senti.alwaysOnTop"
        static let borderless = "senti.borderless"
        static let stayAwake = "senti.stayAwake"
        static let keepActive = "senti.keepActive"
        static let turnScreenOff = "senti.turnScreenOff"
        static let timeLimit = "senti.timeLimitMinutes"
        static let recordingEnabled = "senti.recordingEnabled"
        static let recordingFormat = "senti.recordingFormat"
        static let recordingFolder = "senti.recordingFolder"
        static let launchAtLogin = "senti.launchAtLogin"
        static let notifyOnConnect = "senti.notifyOnConnect"
        static let autoMirror = "senti.autoMirrorSerials"
        static let hotKeyCode = "senti.hotKeyCode"
        static let hotKeyModifiers = "senti.hotKeyModifiers"
        static let useNewDisplay = "senti.useNewDisplay"
        static let newDisplaySize = "senti.newDisplaySize"
        static let newDisplayDPI = "senti.newDisplayDPI"
        static let newDisplayStartApp = "senti.newDisplayStartApp"
        static let newDisplayForceStop = "senti.newDisplayForceStop"
        static let newDisplayKeepContent = "senti.newDisplayKeepContent"
        static let newDisplayHideDecorations = "senti.newDisplayHideDecorations"
        static let newDisplayResize = "senti.newDisplayResizeWithWindow"
        static let frostStyle = "senti.frostStyle"
        static let advancedFlags = "senti.advancedFlagValues"
        static let hasSeenTour = "senti.hasSeenTour"

        /// Device history is deliberately absent: it belongs to `DeviceStore`, which holds the
        /// entries in memory and would write them straight back after the key was removed. It is
        /// cleared through General → Forget All instead.
        static let all = [
            videoCodec, videoBitrate, maxFPS, maxSize,
            audioEnabled, audioCodec, audioBitrate,
            alwaysOnTop, borderless, stayAwake, keepActive, turnScreenOff, timeLimit,
            recordingEnabled, recordingFormat, recordingFolder,
            launchAtLogin, notifyOnConnect, autoMirror,
            useNewDisplay, newDisplaySize, newDisplayDPI, newDisplayStartApp,
            newDisplayForceStop, newDisplayKeepContent, newDisplayHideDecorations, newDisplayResize,
            hotKeyCode, hotKeyModifiers, frostStyle, advancedFlags, hasSeenTour,
        ]
    }
}
