import Foundation

/// The settings index behind the sidebar's search field.
///
/// A hand-written list rather than something derived from the views: the point of searching is
/// to find a setting by a word the UI does not use ("lag" for bitrate, "sound" for audio), and
/// only a hand-written list can carry those.
enum SettingsSearch {

    struct Hit: Identifiable, Hashable {
        let title: String
        let pane: SettingsPane
        let keywords: [String]

        var id: String { "\(pane.rawValue).\(title)" }
    }

    static let index: [Hit] = [
        .init(title: "Video codec", pane: .mirroring, keywords: ["h264", "h265", "hevc", "av1", "encoder", "quality"]),
        .init(title: "Bitrate", pane: .mirroring, keywords: ["mbps", "quality", "sharpness", "bandwidth", "lag", "blocky"]),
        .init(title: "Frame rate", pane: .mirroring, keywords: ["fps", "smooth", "60", "stutter", "lag"]),
        .init(title: "Resolution", pane: .mirroring, keywords: ["size", "1080", "720", "scale", "sharp", "big", "small"]),
        .init(title: "Audio", pane: .mirroring, keywords: ["sound", "mute", "volume", "opus", "aac", "speaker"]),
        .init(title: "Always on top", pane: .mirroring, keywords: ["float", "front", "above", "window"]),
        .init(title: "Borderless window", pane: .mirroring, keywords: ["chrome", "title bar", "frame", "window"]),
        .init(title: "Keep the phone awake", pane: .mirroring, keywords: ["sleep", "screen off", "lock", "dim", "timeout"]),
        .init(title: "Turn the phone screen off", pane: .mirroring, keywords: ["blank", "privacy", "black", "battery"]),
        .init(title: "Stop after", pane: .mirroring, keywords: ["time limit", "timer", "minutes", "auto stop"]),

        .init(title: "Virtual display", pane: .mirroring, keywords: ["new display", "second screen", "separate", "desktop mode", "extra display", "app window"]),
        .init(title: "Open an app on the new display", pane: .mirroring, keywords: ["start app", "package", "launch", "firefox", "launcher"]),
        .init(title: "Display size and density", pane: .mirroring, keywords: ["dpi", "resolution", "1920x1080", "scale", "density"]),

        .init(title: "Record sessions", pane: .mirroring, keywords: ["video", "capture", "save", "mp4", "mkv", "film"]),
        .init(title: "Recording format", pane: .mirroring, keywords: ["mp4", "mkv", "container", "file type"]),
        .init(title: "Where recordings go", pane: .mirroring, keywords: ["folder", "movies", "location", "path", "save"]),

        .init(title: "Advanced scrcpy options", pane: .advanced, keywords: ["flags", "arguments", "command line", "expert", "raw", "everything else"]),
        .init(title: "Reset advanced options", pane: .advanced, keywords: ["clear flags", "undo", "start over", "broken", "will not start"]),

        .init(title: "scrcpy version", pane: .help, keywords: ["adb", "tools", "engine", "binary", "version"]),
        .init(title: "Re-install the tools", pane: .help, keywords: ["repair", "fix", "unpack", "broken", "reprovision"]),
        .init(title: "Restart adb", pane: .help, keywords: ["daemon", "server", "5037", "not found", "device missing"]),

        .init(title: "Keyboard shortcut", pane: .general, keywords: ["hotkey", "shortcut", "key", "global", "open panel"]),
        .init(title: "Background", pane: .general, keywords: ["appearance", "translucent", "transparency", "frost", "blur", "clear", "solid", "theme"]),
        .init(title: "Open at login", pane: .general, keywords: ["startup", "launch", "boot", "start"]),
        .init(title: "Notify when a phone connects", pane: .general, keywords: ["banner", "notification", "alert", "connect"]),
        .init(title: "Welcome tour", pane: .general, keywords: ["onboarding", "intro", "tutorial", "walkthrough", "first launch"]),
        .init(title: "Reset all settings", pane: .general, keywords: ["default", "wipe", "start over", "erase", "factory"]),
        .init(title: "Forget all devices", pane: .general, keywords: ["history", "names", "clear", "erase"]),

        .init(title: "Turning on USB debugging", pane: .help, keywords: ["developer options", "setup", "allow", "authorize", "adb"]),
        .init(title: "Phone not showing up", pane: .help, keywords: ["missing", "trouble", "cable", "not detected", "problem"]),
    ]

    /// Case- and diacritic-insensitive substring match over the title and the keyword list.
    static func matches(for query: String) -> [Hit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return index.filter { hit in
            if hit.title.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                return true
            }
            return hit.keywords.contains {
                $0.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }
}

#if DEBUG
extension SettingsSearch {
    static func selfCheck() {
        assert(matches(for: "").isEmpty, "an empty query must match nothing, not everything")
        assert(matches(for: "   ").isEmpty, "whitespace is an empty query")
        assert(!matches(for: "fps").isEmpty, "a keyword-only term must still find its setting")
        assert(matches(for: "fps").first?.pane == .mirroring, "fps should land in Mirroring")
        assert(!matches(for: "SOUND").isEmpty, "search must be case-insensitive")
        assert(matches(for: "zzzz").isEmpty, "a term matching nothing must return nothing")

        // Every pane in the sidebar should be reachable by search, or the field quietly hides
        // half the app.
        let covered = Set(index.map(\.pane))
        for pane in SettingsPane.allCases {
            assert(covered.contains(pane), "\(pane.title) has no entry in the settings index")
        }
    }
}
#endif
