import Foundation

/// One option scrcpy advertises in its own `--help`.
struct ScrcpyFlag: Identifiable, Hashable, Sendable {
    /// The long form, including the dashes: `--video-bit-rate`.
    let name: String
    /// The short alias, if it has one: `-b`.
    let short: String?
    /// What the value is called in the help text — `value`, `ms`, `name`. Nil means the flag is
    /// a switch that takes no value.
    let valueLabel: String?
    /// The description scrcpy prints, joined into one paragraph.
    let summary: String

    var takesValue: Bool { valueLabel != nil }
    var id: String { name }

    var category: ScrcpyFlagCategory { ScrcpyFlagCategory.of(name) }
}

/// Buckets for the Advanced pane. 78 options in one alphabetical run is a wall — the flag you
/// want is findable by search, but not by browsing, and browsing is how you learn what is there.
///
/// scrcpy's own help groups nothing, so the buckets are inferred from the flag names. A name
/// that matches nothing lands in "Other", which is honest: a wrong guess is worse than none.
enum ScrcpyFlagCategory: String, CaseIterable, Identifiable, Sendable {
    case video, audio, camera, window, input, capture, connection, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .video: return "Video"
        case .audio: return "Audio"
        case .camera: return "Camera"
        case .window: return "Window and display"
        case .input: return "Keyboard, mouse and control"
        case .capture: return "Recording and capture"
        case .connection: return "Device and connection"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .video: return "film"
        case .audio: return "speaker.wave.2"
        case .camera: return "camera"
        case .window: return "macwindow"
        case .input: return "keyboard"
        case .capture: return "record.circle"
        case .connection: return "cable.connector"
        case .other: return "ellipsis.circle"
        }
    }

    /// Ordered: the first rule that matches wins, so `--camera-fps` is a camera option rather
    /// than a video one, and `--audio-source` beats the generic `source` idea entirely.
    static func of(_ name: String) -> ScrcpyFlagCategory {
        let rules: [(ScrcpyFlagCategory, [String])] = [
            (.camera, ["camera"]),
            (.audio, ["audio"]),
            (.capture, ["record", "v4l2", "screenshot", "capture-orientation", "playback"]),
            (.video, ["video", "codec", "encoder", "bit-rate", "fps", "crop", "angle", "render",
                      "mipmap", "downsize", "min-size"]),
            (.window, ["window", "display", "fullscreen", "borderless", "always-on-top",
                       "orientation", "rotation", "screensaver", "background-color"]),
            (.input, ["keyboard", "mouse", "gamepad", "key", "hid", "otg", "shortcut",
                      "paste", "clipboard", "touch", "forward", "text", "input", "control"]),
            (.connection, ["serial", "tcpip", "port", "tunnel", "adb", "select-", "push",
                           "power", "screen-off", "stay-awake", "start-app", "vd-", "cleanup",
                           "list-", "device"]),
        ]
        for (category, needles) in rules where needles.contains(where: { name.contains($0) }) {
            return category
        }
        return .other
    }
}

/// Reads scrcpy's own `--help` and turns it into a list senti can render.
///
/// Parsed at runtime rather than hard-coded: scrcpy gains and renames options between releases,
/// and a hand-maintained list would quietly drift out of date. Whatever the bundled binary
/// supports is exactly what the Advanced pane offers.
enum ScrcpyFlags {

    /// Options senti sets itself from the Mirroring pane. Offering them here as well would send
    /// the same flag twice — scrcpy takes the last one, so a value typed here would silently
    /// override a setting the user cannot see from this pane, or contradict it outright.
    static let managed: Set<String> = [
        "--serial", "--video-codec", "--video-bit-rate", "--max-fps", "--max-size",
        "--no-audio", "--audio-codec", "--audio-bit-rate",
        "--always-on-top", "--window-borderless", "--stay-awake", "--keep-active",
        "--turn-screen-off", "--time-limit", "--record", "--window-title",
        // The virtual-display group, set from Mirroring when that mode is on.
        "--new-display", "--no-vd-destroy-content", "--no-vd-system-decorations",
        "--flex-display", "--start-app",
        // Not managed, but excluded on purpose: these terminate instead of mirroring, and a
        // switch in a settings pane that makes Mirror do nothing is a trap.
        "--help", "--version", "--list-encoders", "--list-displays", "--list-cameras",
        "--list-camera-sizes", "--list-apps",
    ]

    /// Runs the binary and parses what it prints. Blocking — call it off the main thread.
    static func load(scrcpyPath: String) -> [ScrcpyFlag] {
        guard let help = Shell.run(scrcpyPath, ["--help"], timeout: 20) else { return [] }
        return parse(help)
    }

    /// scrcpy's help lays each option out as a 4-space-indented flag line followed by
    /// 8-space-indented description lines:
    ///
    ///     -b, --video-bit-rate=value
    ///         Encode the video at the given bit rate, expressed in bits/s. Unit
    ///         suffixes are supported: 'K' (x1000) and 'M' (x1000000).
    ///
    /// Split out from `load` so it can be checked without a binary.
    static func parse(_ help: String) -> [ScrcpyFlag] {
        var flags: [ScrcpyFlag] = []
        var pending: (name: String, short: String?, valueLabel: String?)?
        var summaryLines: [String] = []

        func flush() {
            guard let pending else { return }
            let summary = summaryLines
                .joined(separator: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespaces)
            flags.append(ScrcpyFlag(name: pending.name,
                                    short: pending.short,
                                    valueLabel: pending.valueLabel,
                                    summary: summary))
            summaryLines = []
        }

        for rawLine in help.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)

            if let parsed = parseFlagLine(line) {
                flush()
                pending = parsed
                continue
            }

            // A description line: exactly the continuation indent, and we are inside an option.
            if pending != nil, line.hasPrefix("        ") {
                let text = line.trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { summaryLines.append(text) }
                continue
            }

            // A blank line inside an option's description is a paragraph break, not the end.
            if pending != nil, line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

            // Anything else — a section header, the usage line — ends the current option.
            flush()
            pending = nil
        }
        flush()

        return flags
            .filter { !managed.contains($0.name) }
            .sorted { $0.name < $1.name }
    }

    /// Matches `    --flag`, `    --flag=value`, `    -f, --flag` and `    -f, --flag=value`.
    /// Returns nil for anything else, including the deeper-indented description lines.
    private static func parseFlagLine(_ line: String) -> (name: String, short: String?, valueLabel: String?)? {
        guard line.hasPrefix("    "), !line.hasPrefix("        ") else { return nil }
        let body = line.dropFirst(4)
        guard body.hasPrefix("-") else { return nil }

        var short: String?
        var remainder = Substring(body)

        // A short alias always comes first and is followed by ", ".
        if let separator = body.range(of: ", --"), body.distance(from: body.startIndex, to: separator.lowerBound) <= 3 {
            short = String(body[body.startIndex..<separator.lowerBound])
            remainder = body[body.index(separator.lowerBound, offsetBy: 2)...]
        }

        guard remainder.hasPrefix("--") else { return nil }
        // Anything after whitespace on a flag line is not part of the flag.
        guard let token = remainder.split(separator: " ", maxSplits: 1).first else { return nil }

        let parts = token.split(separator: "=", maxSplits: 1)
        // A flag whose value is optional is printed as `--new-display[=[<w>x<h>][/<dpi>]]`, so
        // the name carries a trailing bracket that is punctuation, not part of the flag. Left
        // in, senti would emit `--new-display[=…` and scrcpy would refuse to start.
        let name = String(parts[0]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        guard name.count > 2, name.hasPrefix("--") else { return nil }

        // The label carries the same optional-value punctuation as the name — `mode]` for
        // `--pause-on-exit[=mode]`. It is only ever shown as a placeholder, so trim it.
        let valueLabel = parts.count > 1
            ? String(parts[1]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            : nil
        return (name, short, valueLabel)
    }

    /// Turns the stored `flag: value` map into argv entries. An empty value means a switch.
    static func arguments(from values: [String: String]) -> [String] {
        values
            .filter { !managed.contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { name, value in value.isEmpty ? name : "\(name)=\(value)" }
    }
}

#if DEBUG
extension ScrcpyFlags {
    static func selfCheck() {
        let sample = """
        scrcpy 4.0 <https://example.invalid>
        Usage: scrcpy [options]

        Options:

            --always-on-top
                Make scrcpy window always on top (above other windows).

            -b, --video-bit-rate=value
                Encode the video at the given bit rate.
                Default is 8M.

            --audio-output-buffer=ms
                Configure the size of the SDL audio output buffer (in milliseconds).

        """
        let flags = parse(sample)

        // --always-on-top and --video-bit-rate are both managed, so only one survives.
        assert(flags.count == 1, "expected 1 unmanaged flag, parsed \(flags.count)")
        let buffer = flags[0]
        assert(buffer.name == "--audio-output-buffer", "flag name mis-parsed: \(buffer.name)")
        assert(buffer.valueLabel == "ms", "value label mis-parsed: \(buffer.valueLabel ?? "nil")")
        assert(buffer.summary.hasPrefix("Configure the size"), "summary mis-parsed: \(buffer.summary)")

        // The short-alias form has to yield the long name, or the argument built from it is junk.
        let withShort = parse("""
        Options:

            -b, --some-option=value
                Text.

        """)
        assert(withShort.first?.name == "--some-option", "a short alias must not become the name")
        assert(withShort.first?.short == "-b", "short alias dropped")

        // Multi-line descriptions must join rather than truncate.
        assert(parse("""
        Options:

            --thing=x
                One.
                Two.

        """).first?.summary == "One. Two.", "description lines must join")

        let argv = arguments(from: ["--audio-output-buffer": "50", "--no-cleanup": "", "--max-fps": "9"])
        assert(argv == ["--audio-output-buffer=50", "--no-cleanup"],
               "argv build wrong, or a managed flag leaked through: \(argv)")

        // An optional-value flag prints its brackets as part of the token, and a name carrying a
        // bracket would build an argument scrcpy rejects. Checked with an invented name: the real
        // example (`--new-display`) is managed, so `parse` filters it out before it can be seen.
        let optional = parse("""
        Options:

            --sample-display[=[<width>x<height>][/<dpi>]]
                Create a new display.

        """)
        assert(optional.first?.name == "--sample-display",
               "optional-value flag name mis-parsed: \(optional.first?.name ?? "nil")")

        // Nothing may reach the command line with punctuation in its name.
        for flag in optional + flags {
            assert(flag.name.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" },
                   "flag name has punctuation in it: \(flag.name)")
        }
    }
}
#endif
