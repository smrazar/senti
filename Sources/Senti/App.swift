import AppKit

@main
@MainActor
enum SentiMain {
    static func main() {
        // `senti --self-check` runs the checks and exits without starting the app, so they can
        // run on a build box or in an agent session with no WindowServer — `NSApplication.run()`
        // aborts before `applicationDidFinishLaunching` in that environment, which reads exactly
        // like a failing assertion and is not one.
        if CommandLine.arguments.contains("--self-check") {
            exit(SelfChecks.runAll() ? 0 : 1)
        }

        // `senti --list-flags` prints what the Advanced pane will show. The parser reads a
        // 700-line help text whose shape is scrcpy's to change, so there has to be a way to look
        // at its actual output rather than only the fixed sample the self-check uses.
        if CommandLine.arguments.contains("--list-flags") {
            let flags = ScrcpyFlags.load(scrcpyPath: Toolchain().scrcpyPath)
            for flag in flags {
                let value = flag.valueLabel.map { "=\($0)" } ?? ""
                print("\(flag.category.rawValue)\t\(flag.name)\(value)\t\(flag.summary.prefix(60))")
            }
            print("— \(flags.count) options")
            exit(flags.isEmpty ? 1 : 0)
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        _ = SelfChecks.runAll(includingWindowServer: true)
        #endif

        // Accessory: no Dock icon. `MainWindowController` flips to `.regular` while its window
        // is open, so the window can be focused and ⌘W works.
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = AppMenu.build()

        AppState.shared.start()

        if !Preferences.shared.hasSeenTour {
            // The delay lets the status item settle, so the tour does not appear over a
            // half-drawn menu bar.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                MainActor.assumeIsolated { OnboardingWindow.shared.present() }
            }
        }
    }

    /// scrcpy is a child process; left alone it survives the app and keeps the phone's screen
    /// off after a `--turn-screen-off` session.
    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.scrcpy.stopAll()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        AppState.shared.openMainWindow()
        return true
    }
}

/// Keeps the Dock icon in step with whether any real window is open.
///
/// Each window controller used to drop the policy back to `.accessory` in its own
/// `windowWillClose`, which meant closing the tour while the settings window was open took the
/// Dock icon away from a window that was still on screen.
@MainActor
enum ActivationPolicy {
    /// Deferred a pass: the window that triggered this still reports itself visible during
    /// `windowWillClose`.
    static func refresh() {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                let hasWindow = NSApp.windows.contains { window in
                    window.isVisible
                        && window.styleMask.contains(.titled)
                        && !(window is MenuBarPanel)
                }
                NSApp.setActivationPolicy(hasWindow ? .regular : .accessory)
            }
        }
    }
}

/// An accessory app has no main menu, and without one no text field anywhere gets ⌘C/⌘V/⌘X/⌘Z —
/// there is no menu item carrying those key equivalents. This menu never appears on screen; it
/// only has to exist.
@MainActor
enum AppMenu {
    static func build() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "senti")
        appMenu.addItem(withTitle: "About senti",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…",
                                  action: #selector(AppState.openSettingsAction),
                                  keyEquivalent: ",")
        settings.target = AppState.shared
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide senti", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit senti", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = window
        main.addItem(windowItem)

        return main
    }
}
