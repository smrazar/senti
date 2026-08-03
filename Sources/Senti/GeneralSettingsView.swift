import AppKit
import SwiftUI

/// Startup, notifications, and the two ways to start over.
struct GeneralSettingsView: View {

    @ObservedObject var state: AppState
    @ObservedObject private var preferences: Preferences
    @ObservedObject private var store: DeviceStore

    @State private var confirmingReset = false
    @State private var confirmingForget = false

    init(state: AppState) {
        self.state = state
        preferences = state.preferences
        store = state.deviceStore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.section) {
            appearance

            // The shortcut had a pane of its own until the sidebar was cut to four.
            ShortcutsSettingsView(state: state)

            SettingsGroup(title: "General", symbol: Sym.paneGeneral) {
                SettingsRow(label: "Open senti at login",
                            description: "The icon appears in the menu bar when you log in.") {
                    SentiToggle(isOn: Binding(
                        get: { preferences.launchAtLogin },
                        set: { wanted in
                            // Store what macOS actually did, not what was asked for — it can
                            // refuse when the user has switched the item off in System Settings.
                            preferences.launchAtLogin = LoginItem.setEnabled(wanted)
                        }
                    ))
                }
                RowDivider()
                SettingsRow(label: "Notify when a phone connects",
                            description: "A banner with a Mirror button, so a session can start without opening the panel.") {
                    SentiToggle(isOn: $preferences.notifyOnConnect)
                }
                RowDivider()
                SettingsRow(label: "Welcome tour",
                            description: "The three pages senti shows on a first launch.") {
                    SecondaryButton(title: "Show Again") { OnboardingWindow.shared.present() }
                }
            }

            SettingsGroup(title: "Devices", symbol: Sym.device) {
                SettingsRow(label: "Remembered devices",
                            description: store.entries.isEmpty
                                ? "None yet."
                                : "\(store.entries.count) device\(store.entries.count == 1 ? "" : "s"), with any names you have given them.") {
                    SecondaryButton(title: confirmingForget ? "Really forget?" : "Forget All",
                                    destructive: true) {
                        if confirmingForget {
                            store.forgetAll()
                            confirmingForget = false
                        } else {
                            confirmingForget = true
                        }
                    }
                }
            }

            SettingsGroup(title: "Start over", symbol: "arrow.counterclockwise") {
                SettingsRow(label: "Reset all settings",
                            description: "Puts every setting back the way it shipped. Recordings and remembered devices are left alone.") {
                    SecondaryButton(title: confirmingReset ? "Really reset?" : "Reset",
                                    destructive: true) {
                        if confirmingReset {
                            preferences.resetAll()
                            state.applyHotKey()
                            confirmingReset = false
                        } else {
                            confirmingReset = true
                        }
                    }
                }
            }
        }
        .animation(Theme.Motion.fast, value: confirmingReset)
        .animation(Theme.Motion.fast, value: confirmingForget)
        .onAppear {
            // System Settings can change this behind the app's back.
            if LoginItem.isAvailable { preferences.launchAtLogin = LoginItem.isEnabled }
        }
    }

    // MARK: Appearance

    private var appearance: some View {
        SettingsGroup(title: "Appearance", symbol: Sym.appearance) {
            SettingsRow(label: "Frosted background",
                        description: FrostStyle.current(preferences).blurb) {
                SentiToggle(isOn: Binding(
                    get: { FrostStyle.current(preferences).isFrosted },
                    set: { preferences.frostStyle = ($0 ? FrostStyle.frosted : .solid).rawValue }
                ))
            }
        }
        .animation(Theme.Motion.standard, value: preferences.frostStyle)
    }
}
