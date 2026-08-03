import SwiftUI

/// Picture, sound, and how the mirror window behaves.
struct MirroringSettingsView: View {

    @ObservedObject var preferences: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.section) {
            picture
            sound
            window
            virtualDisplay
            // Recording had a pane of its own until the sidebar was cut to four. It is the same
            // view, rendered as the last two groups here.
            RecordingSettingsView(preferences: preferences)
        }
    }

    // MARK: Picture

    private var picture: some View {
        SettingsGroup(title: "Picture", symbol: Sym.paneMirroring) {
            SettingsRow(label: "Video codec",
                        description: "h264 works on every phone. h265 and AV1 look better at the same bitrate, if the phone can encode them.") {
                InlinePicker(selection: $preferences.videoCodec,
                             options: [("h264", "h264"), ("h265", "h265"), ("av1", "AV1")])
            }
            RowDivider()
            SettingsRow(label: "Bitrate",
                        description: "Higher is sharper and heavier. 8 Mbps is a good starting point.") {
                InlineStepper(value: $preferences.videoBitrateMbps, range: 1...50, unit: "Mbps")
            }
            RowDivider()
            SettingsRow(label: "Frame rate",
                        description: preferences.maxFPS > 60
                            ? "Above 60 needs a phone that can encode it and a Mac that can keep up. If the picture stutters, come back down."
                            : "60 is smooth on every phone tested. Higher is available if yours has a faster screen.") {
                InlineStepper(value: $preferences.maxFPS, range: 10...120, step: 5, unit: "fps")
            }
            RowDivider()
            SettingsRow(label: "Resolution",
                        description: "The long edge of the mirrored picture, in pixels. Raise the bitrate along with it or it will just look softer.") {
                InlineStepper(value: $preferences.maxSize, range: 360...2160, step: 120, unit: "px")
            }
        }
    }

    // MARK: Sound

    private var sound: some View {
        SettingsGroup(title: "Sound", symbol: "speaker.wave.2") {
            SettingsRow(label: "Play the phone’s audio",
                        description: "Sound comes through the Mac while mirroring.") {
                SentiToggle(isOn: $preferences.audioEnabled)
            }
            if preferences.audioEnabled {
                RowDivider()
                SettingsRow(label: "Audio codec") {
                    InlinePicker(selection: $preferences.audioCodec,
                                 options: [("opus", "Opus"), ("aac", "AAC"), ("flac", "FLAC"), ("raw", "Raw")])
                }
                RowDivider()
                SettingsRow(label: "Audio bitrate") {
                    InlineStepper(value: $preferences.audioBitrateKbps, range: 32...320, step: 32, unit: "kbps")
                }
            }
        }
        .animation(Theme.Motion.standard, value: preferences.audioEnabled)
    }

    // MARK: Virtual display

    private var virtualDisplay: some View {
        SettingsGroup(title: "Virtual display", symbol: Sym.newDisplay) {
            SettingsRow(label: "Mirror a new display instead",
                        description: "Opens a second Android screen rather than a copy of the phone's. The phone stays usable while an app runs here.") {
                SentiToggle(isOn: $preferences.useNewDisplay)
            }

            if preferences.useNewDisplay {
                RowDivider()
                SettingsRow(label: "Size",
                            description: sizeIsValid
                                ? "Width by height in pixels, like 1920x1080. Leave empty for the phone's own size."
                                : "That is not a size. Use width by height, like 1920x1080 — it will be ignored until it is.") {
                    TextField("1920x1080", text: $preferences.newDisplaySize)
                        .textFieldStyle(.plain)
                        .font(Theme.Font.mono)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, Theme.Space.s12)
                        .frame(width: 140, height: 30)
                        .background(Theme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                .strokeBorder(sizeIsValid ? Theme.border : Theme.danger, lineWidth: 1)
                        )
                }
                RowDivider()
                SettingsRow(label: "Density",
                            description: preferences.newDisplayDPI == 0
                                ? "The phone's own density."
                                : "Higher makes everything on the new display smaller.") {
                    InlineStepper(value: $preferences.newDisplayDPI, range: 0...640, step: 20, unit: "dpi")
                }
                RowDivider()
                SettingsRow(label: "Open an app",
                            description: "Exact package name, like org.mozilla.firefox. Start with ? to match by app name instead.") {
                    TextField("Package name", text: $preferences.newDisplayStartApp)
                        .textFieldStyle(.plain)
                        .font(Theme.Font.mono)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, Theme.Space.s12)
                        .frame(width: 200, height: 30)
                        .background(Theme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                .strokeBorder(Theme.border, lineWidth: 1)
                        )
                }
                if !preferences.newDisplayStartApp.trimmingCharacters(in: .whitespaces).isEmpty {
                    RowDivider()
                    SettingsRow(label: "Restart the app first",
                                description: "Force-stops it before opening, so it starts fresh rather than resuming.") {
                        SentiToggle(isOn: $preferences.newDisplayForceStop)
                    }
                }
                RowDivider()
                SettingsRow(label: "Resize with the window",
                            description: "The display follows the window as you drag its edge.") {
                    SentiToggle(isOn: $preferences.newDisplayResizeWithWindow)
                }
                RowDivider()
                SettingsRow(label: "Keep apps when it closes",
                            description: "Moves whatever is running back to the phone's own screen instead of closing it with the display.") {
                    SentiToggle(isOn: $preferences.newDisplayKeepContent)
                }
                RowDivider()
                SettingsRow(label: "Hide system decorations",
                            description: "No status bar or navigation bar on the new display.") {
                    SentiToggle(isOn: $preferences.newDisplayHideDecorations)
                }
            }
        }
        .animation(Theme.Motion.standard, value: preferences.useNewDisplay)
        .animation(Theme.Motion.fast, value: preferences.newDisplayStartApp.isEmpty)
    }

    private var sizeIsValid: Bool {
        VirtualDisplaySpec.isValidSize(preferences.newDisplaySize)
    }

    // MARK: Window

    private var window: some View {
        SettingsGroup(title: "Window and phone", symbol: "macwindow") {
            SettingsRow(label: "Always on top",
                        description: "The mirror window floats above other windows.") {
                SentiToggle(isOn: $preferences.alwaysOnTop)
            }
            RowDivider()
            SettingsRow(label: "Borderless",
                        description: "No title bar on the mirror window.") {
                SentiToggle(isOn: $preferences.borderless)
            }
            RowDivider()
            SettingsRow(label: "Keep the phone awake",
                        description: "Stops the phone sleeping while it is plugged in and mirroring.") {
                SentiToggle(isOn: $preferences.stayAwake)
            }
            RowDivider()
            SettingsRow(label: "Keep the phone unlocked",
                        description: "Stops the screen dimming and locking mid-session.") {
                SentiToggle(isOn: $preferences.keepActive)
            }
            RowDivider()
            SettingsRow(label: "Turn the phone’s screen off",
                        description: "The picture stays live on the Mac while the phone itself goes dark.") {
                SentiToggle(isOn: $preferences.turnScreenOff)
            }
            RowDivider()
            SettingsRow(label: "Stop after",
                        description: preferences.timeLimitMinutes == 0
                            ? "Sessions run until you stop them."
                            : "Sessions stop on their own after this long.") {
                InlineStepper(value: $preferences.timeLimitMinutes, range: 0...240, step: 5, unit: "min")
            }
        }
    }
}
