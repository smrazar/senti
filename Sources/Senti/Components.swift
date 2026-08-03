import AppKit
import SwiftUI

/// The shared UI vocabulary. Every screen composes from these — no bespoke rows or buttons.

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var symbol: String?
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s8) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: Theme.IconSize.inline, weight: .medium))
                }
                Text(title).font(Theme.Font.bodyEmph.weight(.semibold))
            }
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(isHovering ? Theme.accentHover : Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .shadow(color: Theme.accent.opacity(isHovering ? 0.35 : 0), radius: 8, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { isHovering = $0 }
        .animation(Theme.Motion.standard, value: isHovering)
    }
}

struct SecondaryButton: View {
    let title: String
    var symbol: String?
    var destructive: Bool = false
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s8) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: Theme.IconSize.inline))
                }
                Text(title).font(Theme.Font.bodyEmph)
            }
            .foregroundStyle(destructive ? Theme.danger : Theme.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(isHovering ? Theme.surfaceHover : .clear)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(isHovering ? Theme.borderStrong : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { isHovering = $0 }
        .animation(Theme.Motion.fast, value: isHovering)
    }
}

/// Icon-only button. The tooltip carries the label.
struct IconButton: View {
    let symbol: String
    let help: String
    var active: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: Theme.IconSize.toolbar, weight: active ? .medium : .regular))
                .foregroundStyle(active ? Theme.accent : Theme.textSecondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressableButtonStyle())
        .hoverHighlight()
        .help(help)
        .animation(Theme.Motion.fast, value: active)
    }
}

/// Press-down is instant, release springs back. A symmetric curve feels mushy, because the
/// finger is already gone by the time the animation catches up.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(configuration.isPressed
                       ? .easeOut(duration: 0.06)
                       : .spring(response: 0.28, dampingFraction: 0.55),
                       value: configuration.isPressed)
    }
}

struct HoverHighlight: ViewModifier {
    var radius: CGFloat = Theme.Radius.control

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(isHovering ? Theme.surfaceHover : .clear)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .onHover { isHovering = $0 }
            .animation(Theme.Motion.fast, value: isHovering)
    }
}

extension View {
    func hoverHighlight(radius: CGFloat = Theme.Radius.control) -> some View {
        modifier(HoverHighlight(radius: radius))
    }
}

// MARK: - Settings scaffolding

/// A titled group of rows: small grey header above a hairline-bordered card.
struct SettingsGroup<Content: View>: View {
    let title: String
    var symbol: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s12) {
            HStack(spacing: Theme.Space.s8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: Theme.IconSize.inline, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
                Text(title.uppercased())
                    .font(Theme.Font.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.textTertiary)
            }
            VStack(spacing: 0) { content }
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )
        }
    }
}

/// A settings row: label + one-line grey description + a trailing control.
///
/// `ViewThatFits` with a stacked fallback, and a **minimum width on the text column**. Without
/// that floor the horizontal layout always "fits" — SwiftUI squeezes the text to a few points
/// wide and wraps it one character per line rather than reporting that it did not fit, and the
/// fallback is never chosen.
struct SettingsRow<Control: View>: View {
    let label: String
    var description: String?
    var symbol: String?
    @ViewBuilder var control: Control

    /// Narrower than this and the row stacks instead.
    private static var textFloor: CGFloat { 190 }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Theme.Space.s16) {
                icon
                text.frame(minWidth: Self.textFloor, alignment: .leading)
                Spacer(minLength: Theme.Space.s16)
                control
            }
            VStack(alignment: .leading, spacing: Theme.Space.s12) {
                HStack(alignment: .center, spacing: Theme.Space.s16) {
                    icon
                    text
                }
                HStack {
                    Spacer(minLength: 0)
                    control
                }
            }
        }
        .padding(.vertical, Theme.Space.rowV)
        .padding(.horizontal, Theme.Space.rowH)
    }

    @ViewBuilder
    private var icon: some View {
        if let symbol {
            Image(systemName: symbol)
                .font(.system(size: Theme.IconSize.row))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 20)
        }
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Theme.Font.body).foregroundStyle(Theme.textPrimary)
            if let description {
                Text(description)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Theme.border).frame(height: 1).padding(.leading, Theme.Space.rowH)
    }
}

/// The house toggle: 38×22 track, 18px knob, accent when on.
struct SentiToggle: View {
    @Binding var isOn: Bool

    @State private var isPressed = false

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Theme.accent : Theme.borderStrong)
                    .frame(width: 38, height: 22)
                Capsule().fill(.white)
                    .frame(width: isPressed ? 22 : 18, height: 18)
                    .shadow(color: .black.opacity(0.16), radius: 1, y: 0.5)
                    .padding(2)
            }
            .frame(width: 38, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, pressing: { isPressed = $0 }, perform: {})
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
        .animation(Theme.Motion.fast, value: isPressed)
    }
}

/// A keycap chip: ⌘⇧D in SF Mono on a hairline-bordered surface.
struct KeycapChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Font.monoSmall)
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, Theme.Space.s8)
            .padding(.vertical, Theme.Space.s4)
            .background(Theme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }
}

/// The house menu control. `Picker` is used with `.menu` style so it stays a native pop-up,
/// but wrapped so the label lives in the row and never inside the control.
struct InlinePicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [(value: T, label: String)]

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .frame(minWidth: 96)
    }
}

/// A numeric stepper reading as `12 Mbps` with the unit inside the row, not in the control.
struct InlineStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var unit: String = ""

    var body: some View {
        HStack(spacing: Theme.Space.s8) {
            Text("\(value)\(unit.isEmpty ? "" : " \(unit)")")
                .font(Theme.Font.mono)
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 64, alignment: .trailing)
                .contentTransition(.numericText())
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
                .controlSize(.small)
        }
        .animation(Theme.Motion.fast, value: value)
    }
}

/// Empty state: a large glyph, a line of explanation.
struct EmptyState: View {
    let symbol: String
    let title: String
    var message: String?

    var body: some View {
        VStack(spacing: Theme.Space.s12) {
            Image(systemName: symbol)
                .font(.system(size: Theme.IconSize.empty, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text(title).font(Theme.Font.bodyEmph).foregroundStyle(Theme.textSecondary)
            if let message {
                Text(message)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.s32)
    }
}
