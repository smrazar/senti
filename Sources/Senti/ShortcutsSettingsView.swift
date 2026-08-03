import AppKit
import Carbon.HIToolbox
import SwiftUI

/// One global shortcut: open the panel from anywhere.
struct ShortcutsSettingsView: View {

    @ObservedObject var state: AppState
    @ObservedObject private var preferences: Preferences

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var failedToRegister = false

    init(state: AppState) {
        self.state = state
        preferences = state.preferences
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.section) {
            SettingsGroup(title: "Shortcut", symbol: Sym.paneShortcuts) {
                SettingsRow(label: "Open the panel",
                            description: isRecording
                                ? "Press the keys you want. Escape cancels."
                                : "Works from any app.") {
                    HStack(spacing: Theme.Space.s8) {
                        if isRecording {
                            KeycapChip(text: "Listening…")
                        } else if currentLabel.isEmpty {
                            Text("Not set").font(Theme.Font.caption).foregroundStyle(Theme.textTertiary)
                        } else {
                            KeycapChip(text: currentLabel)
                        }
                        SecondaryButton(title: isRecording ? "Cancel" : "Record") {
                            isRecording ? stopRecording() : startRecording()
                        }
                        if !currentLabel.isEmpty && !isRecording {
                            SecondaryButton(title: "Clear") { clear() }
                        }
                    }
                }
            }

            if failedToRegister {
                HStack(alignment: .top, spacing: Theme.Space.s8) {
                    Image(systemName: Sym.warning)
                        .font(.system(size: Theme.IconSize.inline))
                        .foregroundStyle(Theme.textTertiary)
                    Text("Another app already owns that combination, so senti will never see it. Pick a different one, or free it up in the other app.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .animation(Theme.Motion.standard, value: isRecording)
        .animation(Theme.Motion.standard, value: failedToRegister)
        .onDisappear { stopRecording() }
    }

    private var currentLabel: String {
        HotKey.label(keyCode: preferences.hotKeyCode, modifiers: preferences.hotKeyModifiers)
    }

    // MARK: Recording

    /// A local monitor is enough: the settings window is key while recording, so the key-down
    /// arrives here before anything else in the app sees it. Capturing chords another app has
    /// globally claimed would need an event tap and the Accessibility grant that comes with it —
    /// not worth asking for one shortcut.
    private func startRecording() {
        stopRecording()
        isRecording = true
        failedToRegister = false
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                handle(event)
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        // A bare letter would fire in the middle of typing anywhere on the Mac.
        guard !flags.isEmpty else { return }

        preferences.hotKeyCode = Int(event.keyCode)
        preferences.hotKeyModifiers = Int(HotKey.carbonModifiers(from: flags))
        stopRecording()

        failedToRegister = !state.applyHotKey()
    }

    private func clear() {
        preferences.hotKeyCode = 0
        preferences.hotKeyModifiers = 0
        failedToRegister = false
        state.applyHotKey()
    }
}
