import SwiftUI

/// The panel that drops from the menu-bar icon: what is plugged in, and one button to mirror it.
///
/// Everything configurable lives in the main window. The panel answers one question — which
/// phone, mirror it — and nothing else earns a place here.
struct DevicePanel: View {

    @ObservedObject var state: AppState
    @ObservedObject private var monitor: DeviceMonitor
    @ObservedObject private var scrcpy: ScrcpyService
    @ObservedObject private var store: DeviceStore
    @ObservedObject private var toolchain: Toolchain
    @ObservedObject private var preferences: Preferences

    init(state: AppState) {
        self.state = state
        monitor = state.deviceMonitor
        scrcpy = state.scrcpy
        store = state.deviceStore
        toolchain = state.toolchain
        preferences = state.preferences
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            RowDivider().padding(.leading, 0)

            Group {
                if case .failed(let message) = toolchain.status {
                    toolchainFailure(message)
                } else if case .provisioning = toolchain.status {
                    EmptyState(symbol: Sym.paneToolchain,
                               title: "Setting up",
                               message: "Unpacking the mirroring tools. This happens once.")
                } else if monitor.devices.isEmpty {
                    emptyState
                } else {
                    deviceList
                }
            }
            .animation(Theme.Motion.standard, value: monitor.devices)

            RowDivider().padding(.leading, 0)
            quickSettings

            if let error = scrcpy.lastError {
                errorStrip(error)
            }

            if !absent.isEmpty {
                RowDivider().padding(.leading, 0)
                recentSection
            }
        }
        .frame(width: 340)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.Space.s8) {
            Text("senti")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.textPrimary)

            if scrcpy.hasAnySession {
                LiveDot()
            }

            Spacer(minLength: Theme.Space.s8)

            IconButton(symbol: Sym.refresh, help: "Check for devices") {
                Task { await monitor.refresh() }
            }
            IconButton(symbol: Sym.settings, help: "Settings") {
                state.openMainWindow()
            }
            IconButton(symbol: Sym.quit, help: "Quit senti") {
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, Theme.Space.rowH)
        .padding(.vertical, Theme.Space.s12)
    }

    // MARK: - Devices

    private var deviceList: some View {
        VStack(spacing: 0) {
            ForEach(monitor.devices) { device in
                DeviceRow(device: device,
                          name: store.displayName(for: device.serial, live: device),
                          isMirroring: scrcpy.isMirroring(device.serial),
                          isRecording: scrcpy.isRecording(device.serial),
                          isAutoMirror: state.preferences.autoMirrorSerials.contains(device.serial),
                          onToggleMirror: { state.toggleMirror(device) },
                          onRename: { store.setCustomName($0, for: device.serial) },
                          onToggleAutoMirror: { toggleAutoMirror(device.serial) },
                          onForget: { store.forget(device.serial) })
            }
        }
        .padding(.horizontal, Theme.Space.s8)
        .padding(.vertical, Theme.Space.s8)
    }

    private var emptyState: some View {
        EmptyState(symbol: Sym.usb,
                   title: monitor.hasPolled ? "No phone connected" : "Looking for phones",
                   message: monitor.hasPolled
                        ? "Plug an Android phone in over USB with USB debugging turned on."
                        : nil)
            .padding(.horizontal, Theme.Space.s12)
    }

    private func toolchainFailure(_ message: String) -> some View {
        VStack(spacing: Theme.Space.s12) {
            Image(systemName: Sym.warning)
                .font(.system(size: Theme.IconSize.empty, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text(message)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton(title: "Open Help", symbol: Sym.paneHelp) {
                state.openMainWindow(selecting: .help)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Space.s20)
    }

    private func errorStrip(_ message: String) -> some View {
        HStack(spacing: Theme.Space.s8) {
            Image(systemName: Sym.warning)
                .font(.system(size: Theme.IconSize.inline))
                .foregroundStyle(Theme.textTertiary)
            Text(message)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Space.rowH)
        .padding(.vertical, Theme.Space.s12)
        .background(Theme.surfaceSecondary)
    }

    // MARK: - Quick settings
    //
    // The three that get changed session to session. Everything else is a decision made once,
    // and lives in the main window.

    private var quickSettings: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s4) {
            HStack(spacing: Theme.Space.s8) {
                Text("NEXT SESSION")
                    .font(Theme.Font.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 0)
                Text("Applies when you press Mirror")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, Theme.Space.rowH)
            .padding(.bottom, Theme.Space.s4)

            // What Mirror actually does is the one choice worth making from here rather than
            // from a settings pane — it changes session to session, and the button gives no
            // other hint which of the two it is about to do.
            HStack(spacing: Theme.Space.s12) {
                Image(systemName: preferences.useNewDisplay ? Sym.newDisplay : Sym.phoneScreen)
                    .font(.system(size: Theme.IconSize.row))
                    .foregroundStyle(preferences.useNewDisplay ? Theme.accent : Theme.textSecondary)
                    .frame(width: 20)
                    .contentTransition(.symbolEffect(.replace))
                Picker("", selection: $preferences.useNewDisplay) {
                    Text("Phone screen").tag(false)
                    Text("New display").tag(true)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
            }
            .padding(.vertical, Theme.Space.s8)
            .padding(.horizontal, Theme.Space.rowH)
            .animation(Theme.Motion.fast, value: preferences.useNewDisplay)

            quickStepper("Bitrate", symbol: "gauge.with.dots.needle.50percent",
                         value: $preferences.videoBitrateMbps, range: 1...50, step: 1, unit: "Mbps")
            quickStepper("Resolution", symbol: "arrow.up.left.and.arrow.down.right",
                         value: $preferences.maxSize, range: 360...2160, step: 120, unit: "px")

            quickToggle("Play the phone’s audio", symbol: "speaker.wave.2", isOn: $preferences.audioEnabled)
            quickToggle("Record the session", symbol: Sym.recording, isOn: $preferences.recordingEnabled)
            quickToggle("Keep the window on top", symbol: "macwindow.on.rectangle", isOn: $preferences.alwaysOnTop)
            quickToggle("Borderless window", symbol: "rectangle.dashed", isOn: $preferences.borderless)
        }
        .padding(.vertical, Theme.Space.s12)
    }

    private func quickStepper(_ label: String,
                              symbol: String,
                              value: Binding<Int>,
                              range: ClosedRange<Int>,
                              step: Int,
                              unit: String) -> some View {
        HStack(spacing: Theme.Space.s12) {
            Image(systemName: symbol)
                .font(.system(size: Theme.IconSize.row))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 20)
            Text(label)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: Theme.Space.s8)
            InlineStepper(value: value, range: range, step: step, unit: unit)
        }
        .padding(.vertical, Theme.Space.s8)
        .padding(.horizontal, Theme.Space.rowH)
    }

    private func quickToggle(_ label: String, symbol: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Theme.Space.s12) {
            Image(systemName: symbol)
                .font(.system(size: Theme.IconSize.row))
                .foregroundStyle(isOn.wrappedValue ? Theme.accent : Theme.textSecondary)
                .frame(width: 20)
            Text(label)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: Theme.Space.s8)
            SentiToggle(isOn: isOn)
        }
        .padding(.vertical, Theme.Space.s8)
        .padding(.horizontal, Theme.Space.rowH)
        .animation(Theme.Motion.fast, value: isOn.wrappedValue)
    }

    // MARK: - Remembered devices

    private var absent: [DeviceStore.Entry] {
        Array(store.absentEntries(connected: monitor.devices).prefix(3))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s8) {
            Text("RECENT")
                .font(Theme.Font.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, Theme.Space.rowH)

            ForEach(absent, id: \.serial) { entry in
                HStack(spacing: Theme.Space.s12) {
                    Image(systemName: Sym.deviceAbsent)
                        .font(.system(size: Theme.IconSize.row))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 20)
                    Text(store.displayName(for: entry.serial))
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: Theme.Space.s8)
                    Text(Self.relative.localizedString(for: entry.lastSeen, relativeTo: Date()))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.vertical, Theme.Space.s8)
                .padding(.horizontal, Theme.Space.rowH)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Forget This Device") { store.forget(entry.serial) }
                }
            }
        }
        .padding(.vertical, Theme.Space.s12)
    }

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    // MARK: - Actions

    private func toggleAutoMirror(_ serial: String) {
        var serials = state.preferences.autoMirrorSerials
        if let index = serials.firstIndex(of: serial) {
            serials.remove(at: index)
        } else {
            serials.append(serial)
        }
        state.preferences.autoMirrorSerials = serials
    }
}

/// The one live-session indicator: an accent dot that breathes. The only place in the panel
/// where the accent appears without the user having selected something.
struct LiveDot: View {
    @State private var isBright = false

    var body: some View {
        Circle()
            .fill(Theme.accent)
            .frame(width: 7, height: 7)
            .opacity(isBright ? 1 : 0.45)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isBright)
            .onAppear { isBright = true }
            .help("Mirroring")
    }
}
