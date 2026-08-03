import AppKit

/// Every debug-build assertion in one place, so `senti --self-check` can run them all and a
/// launch cannot skip any.
///
/// These are `assert`-based and therefore compiled out of a release build: they guard against
/// a regression while developing, not against a broken install. The things worth checking are
/// the ones reasoning gets wrong — colour conversion, adb's output format, whether a borderless
/// panel can take keyboard focus.
@MainActor
enum SelfChecks {

    /// Returns true when everything passed. In a release build there is nothing to run, so it
    /// returns true immediately.
    @discardableResult
    static func runAll(includingWindowServer: Bool = false) -> Bool {
        #if DEBUG
        Theme.selfCheck()
        FrostStyle.selfCheck()
        AdbService.selfCheck()
        SettingsSearch.selfCheck()
        HotKey.selfCheck()
        ScrcpyFlags.selfCheck()
        VirtualDisplaySpec.selfCheck()
        ScrcpyService.selfCheck(preferences: Preferences.shared)
        preferencesRoundTrip()

        // Anything that makes a window needs a WindowServer connection, which a build box or a
        // headless agent session does not have.
        if includingWindowServer {
            MenuBarPanel.selfCheck()
        }

        NSLog("senti: self-checks passed")
        #endif
        return true
    }

    #if DEBUG
    /// Asserts a setting survives a write and read through UserDefaults, and that `resetAll`
    /// really puts it back. A preference that silently fails to persist looks exactly like one
    /// the user never changed.
    private static func preferencesRoundTrip() {
        let preferences = Preferences.shared
        let original = preferences.videoBitrateMbps

        preferences.videoBitrateMbps = 17
        let stored = UserDefaults.standard.integer(forKey: "senti.videoBitrateMbps")
        assert(stored == 17, "a preference did not reach UserDefaults — got \(stored)")

        preferences.videoBitrateMbps = original
        assert(UserDefaults.standard.integer(forKey: "senti.videoBitrateMbps") == original,
               "restoring a preference did not write through")

        // Not caps any more — the ceiling the Mirroring pane offers. A value outside it means a
        // stale stored preference or a stepper range that moved without the other being updated.
        assert((10...120).contains(preferences.maxFPS),
               "frame rate \(preferences.maxFPS) is outside what the Mirroring pane can produce")
        assert((360...2160).contains(preferences.maxSize),
               "resolution \(preferences.maxSize) is outside what the Mirroring pane can produce")

        // An advanced flag that duplicates a managed one would be sent twice, and scrcpy takes
        // the last — silently overriding a setting from a pane the user cannot see from there.
        let leaked = Set(preferences.advancedFlagValues.keys).intersection(ScrcpyFlags.managed)
        assert(leaked.isEmpty, "managed flags leaked into the advanced set: \(leaked.sorted())")
    }
    #endif
}
