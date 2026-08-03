import SwiftUI

/// One phone in the panel: glyph, name, plain-English status, and the action button.
///
/// The row is the only place a mirror session starts, so the button is the primary affordance
/// and everything else on the row stays quiet.
struct DeviceRow: View {

    let device: Device
    let name: String
    let isMirroring: Bool
    let isRecording: Bool
    let isAutoMirror: Bool
    let onToggleMirror: () -> Void
    let onRename: (String?) -> Void
    let onToggleAutoMirror: () -> Void
    let onForget: () -> Void

    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var draftName = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        HStack(spacing: Theme.Space.s12) {
            Image(systemName: glyph)
                .font(.system(size: Theme.IconSize.row, weight: isMirroring ? .medium : .regular))
                .foregroundStyle(isMirroring ? Theme.accent : Theme.textSecondary)
                .frame(width: 20)
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 2) {
                if isRenaming {
                    TextField("Name", text: $draftName)
                        .textFieldStyle(.plain)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.textPrimary)
                        .focused($nameFieldFocused)
                        .onSubmit(commitRename)
                        .onExitCommand { isRenaming = false }
                } else {
                    Text(name)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                }
                Text(subtitle)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.Space.s8)

            if device.isReady {
                actionButton
            }
        }
        .padding(.vertical, Theme.Space.s12)
        .padding(.horizontal, Theme.Space.s12)
        .background(isHovering ? Theme.surfaceHover : .clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(Theme.Motion.fast, value: isHovering)
        .animation(Theme.Motion.swap, value: isMirroring)
        .contextMenu {
            Button("Rename…") { beginRename() }
            Button(isAutoMirror ? "Don’t Mirror Automatically" : "Mirror Automatically When Connected") {
                onToggleAutoMirror()
            }
            Divider()
            Button("Forget This Device", role: .destructive) { onForget() }
        }
    }

    // MARK: - Pieces

    private var glyph: String {
        switch device.state {
        case .ready: return isMirroring ? Sym.deviceMirroring : Sym.device
        case .unauthorized: return Sym.deviceLocked
        case .offline: return Sym.deviceOffline
        }
    }

    /// Auto-mirror is worth a word on the row: it is the one setting that makes the app act on
    /// its own, and a phone that starts mirroring unprompted should not be a mystery. So is
    /// recording — a session quietly writing a file to disk should say so.
    private var subtitle: String {
        if isMirroring { return isRecording ? "Mirroring · recording" : "Mirroring" }
        if device.isReady && isAutoMirror { return "Ready · mirrors automatically" }
        return device.statusText
    }

    @ViewBuilder
    private var actionButton: some View {
        if isMirroring {
            SecondaryButton(title: "Stop", symbol: Sym.stop, action: onToggleMirror)
        } else {
            PrimaryButton(title: "Mirror", symbol: Sym.mirror, action: onToggleMirror)
        }
    }

    // MARK: - Rename

    private func beginRename() {
        draftName = name
        isRenaming = true
        // The field only exists after this state change lands, so focus has to wait a pass.
        DispatchQueue.main.async { nameFieldFocused = true }
    }

    private func commitRename() {
        isRenaming = false
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Typing the model name back in should clear the override, not store a copy of it.
        onRename(trimmed == device.defaultName ? nil : trimmed)
    }
}
