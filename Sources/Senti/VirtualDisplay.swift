import Foundation

/// A virtual display: a second Android screen that exists only while senti is mirroring it,
/// rather than a copy of what is on the phone.
///
/// The phone keeps its own screen and can be used normally while an app runs over here. Building
/// the argument list is fiddly enough — an optional value with two optional halves — to be worth
/// its own type with its own assertions.
struct VirtualDisplaySpec: Equatable, Sendable {

    /// `1920x1080`, or empty for the Mac's own display size.
    var size: String = ""
    /// Dots per inch. 0 means the phone's default, which is what scrcpy uses when omitted.
    var dpi: Int = 0
    /// Exact Android package name. A `?` prefix matches by app name instead, which scrcpy
    /// resolves on the device.
    var startApp: String = ""
    /// Force-stop the app before starting it — scrcpy's `+` prefix.
    var forceStopApp: Bool = false
    /// Move running apps to the phone's own screen when the display closes, rather than killing
    /// them with it.
    var keepContentOnClose: Bool = false
    var hideSystemDecorations: Bool = false
    /// Resize the virtual display as the window is resized.
    var resizeWithWindow: Bool = false

    /// `1920x1080` and nothing else. An empty string is valid — it means "use the default".
    static func isValidSize(_ text: String) -> Bool {
        guard !text.isEmpty else { return true }
        let parts = text.lowercased().split(separator: "x", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        guard let width = Int(parts[0]), let height = Int(parts[1]) else { return false }
        return width >= 100 && height >= 100 && width <= 8192 && height <= 8192
    }

    /// The scrcpy arguments for this display. A malformed size is dropped rather than passed on:
    /// scrcpy would exit with a usage error, and the settings row already says the size is wrong.
    var arguments: [String] {
        var args: [String] = []

        let usableSize = Self.isValidSize(size) ? size : ""
        switch (usableSize.isEmpty, dpi > 0) {
        case (true, false): args.append("--new-display")
        case (false, false): args.append("--new-display=\(usableSize)")
        case (true, true): args.append("--new-display=/\(dpi)")
        case (false, true): args.append("--new-display=\(usableSize)/\(dpi)")
        }

        if keepContentOnClose { args.append("--no-vd-destroy-content") }
        if hideSystemDecorations { args.append("--no-vd-system-decorations") }
        if resizeWithWindow { args.append("--flex-display") }

        let app = startApp.trimmingCharacters(in: .whitespaces)
        if !app.isEmpty {
            // scrcpy's own prefix order is `+` then `?`. If the user already typed a `+`, do not
            // add a second one.
            let prefix = forceStopApp && !app.hasPrefix("+") ? "+" : ""
            args.append("--start-app=\(prefix)\(app)")
        }

        return args
    }

    @MainActor
    static func from(_ preferences: Preferences) -> VirtualDisplaySpec {
        VirtualDisplaySpec(size: preferences.newDisplaySize,
                           dpi: preferences.newDisplayDPI,
                           startApp: preferences.newDisplayStartApp,
                           forceStopApp: preferences.newDisplayForceStop,
                           keepContentOnClose: preferences.newDisplayKeepContent,
                           hideSystemDecorations: preferences.newDisplayHideDecorations,
                           resizeWithWindow: preferences.newDisplayResizeWithWindow)
    }
}

#if DEBUG
extension VirtualDisplaySpec {
    static func selfCheck() {
        assert(VirtualDisplaySpec().arguments == ["--new-display"],
               "an empty spec must be the bare flag, not `--new-display=`")

        assert(VirtualDisplaySpec(size: "1920x1080").arguments == ["--new-display=1920x1080"],
               "size-only form wrong")

        assert(VirtualDisplaySpec(dpi: 240).arguments == ["--new-display=/240"],
               "dpi-only form must keep the leading slash")

        assert(VirtualDisplaySpec(size: "1920x1080", dpi: 420).arguments == ["--new-display=1920x1080/420"],
               "size and dpi form wrong")

        // A size the user is halfway through typing must not reach scrcpy.
        assert(VirtualDisplaySpec(size: "1920x").arguments == ["--new-display"],
               "a malformed size must be dropped, not passed through")
        assert(!isValidSize("1920"), "a size needs both halves")
        assert(!isValidSize("axb"), "a size must be numeric")
        assert(!isValidSize("10x10"), "a size that small is a typo, not a display")
        assert(isValidSize(""), "empty means default and is valid")
        assert(isValidSize("1920x1080"), "a plain size must validate")

        let full = VirtualDisplaySpec(size: "1080x2400",
                                      dpi: 400,
                                      startApp: "org.mozilla.firefox",
                                      forceStopApp: true,
                                      keepContentOnClose: true,
                                      hideSystemDecorations: true,
                                      resizeWithWindow: true).arguments
        assert(full == ["--new-display=1080x2400/400",
                        "--no-vd-destroy-content",
                        "--no-vd-system-decorations",
                        "--flex-display",
                        "--start-app=+org.mozilla.firefox"],
               "full spec built wrong: \(full)")

        // A `+` the user typed themselves must not become `++`.
        let typed = VirtualDisplaySpec(startApp: "+com.example", forceStopApp: true).arguments
        assert(typed.last == "--start-app=+com.example", "force-stop prefix doubled: \(typed.last ?? "nil")")
    }
}
#endif
