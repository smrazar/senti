import AppKit
import SwiftUI

/// What senti mirrors with, and the two buttons that fix it when something on disk is wrong.
struct ToolchainSettingsView: View {

    @ObservedObject var state: AppState
    @ObservedObject private var toolchain: Toolchain

    @State private var isWorking = false
    @State private var note: String?

    init(state: AppState) {
        self.state = state
        toolchain = state.toolchain
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.section) {
            SettingsGroup(title: "Mirroring engine", symbol: Sym.paneToolchain) {
                SettingsRow(label: "scrcpy",
                            description: "Bundled with senti. Nothing to install and no network needed.") {
                    Text(Toolchain.version).font(Theme.Font.mono).foregroundStyle(Theme.textSecondary)
                }
                RowDivider()
                SettingsRow(label: "Status", description: statusDescription) {
                    HStack(spacing: Theme.Space.s8) {
                        Image(systemName: statusSymbol)
                            .font(.system(size: Theme.IconSize.inline))
                            .foregroundStyle(isReady ? Theme.accent : Theme.textTertiary)
                            .contentTransition(.symbolEffect(.replace))
                        Text(statusLabel).font(Theme.Font.bodyEmph).foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            SettingsGroup(title: "Repair", symbol: "wrench.and.screwdriver") {
                SettingsRow(label: "Restart adb",
                            description: "Try this first when a phone is plugged in but never appears. Another copy of adb — from Android Studio, say — fighting for the same port is the usual cause.") {
                    SecondaryButton(title: "Restart") { restartAdb() }
                }
                RowDivider()
                SettingsRow(label: "Re-install the tools",
                            description: "Deletes the unpacked copy and unpacks it again from the app bundle.") {
                    SecondaryButton(title: "Re-install") { reinstall() }
                }
            }

            if let note {
                HStack(spacing: Theme.Space.s8) {
                    Image(systemName: Sym.ready)
                        .font(.system(size: Theme.IconSize.inline))
                        .foregroundStyle(Theme.accent)
                    Text(note).font(Theme.Font.caption).foregroundStyle(Theme.textSecondary)
                }
                .transition(.opacity)
            }
        }
        .animation(Theme.Motion.standard, value: note)
        .animation(Theme.Motion.standard, value: toolchain.status)
        .disabled(isWorking)
    }

    // MARK: Status

    private var isReady: Bool {
        if case .ready = toolchain.status { return true }
        return false
    }

    private var statusLabel: String {
        switch toolchain.status {
        case .idle: return "Not set up"
        case .provisioning: return "Setting up…"
        case .ready: return "Ready"
        case .failed: return "Failed"
        }
    }

    private var statusSymbol: String {
        switch toolchain.status {
        case .ready: return Sym.ready
        case .failed: return Sym.warning
        default: return "hourglass"
        }
    }

    private var statusDescription: String? {
        if case .failed(let message) = toolchain.status { return message }
        return nil
    }

    // MARK: Actions

    private func restartAdb() {
        isWorking = true
        note = nil
        let adbPath = toolchain.adbPath
        Task {
            // Both calls block on a subprocess; neither belongs on the main thread.
            await Task.detached(priority: .userInitiated) {
                AdbService.killServer(adbPath: adbPath)
                AdbService.startServer(adbPath: adbPath)
            }.value
            await state.deviceMonitor.refresh()
            isWorking = false
            note = "adb restarted."
        }
    }

    private func reinstall() {
        isWorking = true
        note = nil
        Task {
            state.scrcpy.stopAll()
            await toolchain.reprovision()
            if case .ready = toolchain.status {
                await state.deviceMonitor.refresh()
                note = "Tools re-installed."
            }
            isWorking = false
        }
    }
}
