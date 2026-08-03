import AppKit
import SwiftUI

/// Whether what is behind senti shows through it.
///
/// **One switch, on or off, with no amount to choose.** This is the design language shared
/// across these apps, and the whole point of it is that senti, Stow and
/// MarkPad stop each having their own answer to the same question. It replaces the three named
/// stages of v1.1–v1.4; picking a vibrancy material is a decision nobody wants to make twice.
///
/// Kept as an enum rather than a `Bool` so the stored preference stays a string and
/// `migrating(stored:)` below has something to land on.
enum FrostStyle: String, CaseIterable, Identifiable, Sendable {
    case solid, frosted

    var id: String { rawValue }

    var label: String {
        switch self {
        case .solid: return "Solid"
        case .frosted: return "Frosted"
        }
    }

    var blurb: String {
        switch self {
        case .solid: return "Flat surfaces. Nothing shows through."
        case .frosted:
            return "The sidebar and the menu-bar panel pick up a frosted blur of what is behind them. Settings text stays on an opaque surface, and macOS’s own vibrancy materials keep it legible over any wallpaper."
        }
    }

    /// The material for a small floating surface — the menu-bar panel.
    ///
    /// Nil for `.solid`: there is no effect view, the surface just paints its colour.
    var panelMaterial: NSVisualEffectView.Material? {
        switch self {
        case .solid: return nil
        case .frosted: return .popover
        }
    }

    /// The material for the main window, which needs a *lighter* one than the panel.
    ///
    /// The same material reads as far more opaque across a large surface than a small one:
    /// `.popover` over an 820pt window is the flat milky sheet the panel does not suffer from.
    /// `.sidebar` is what macOS itself uses at that size, and what the house standard names.
    var windowMaterial: NSVisualEffectView.Material? {
        switch self {
        case .solid: return nil
        case .frosted: return .sidebar
        }
    }

    var isFrosted: Bool { panelMaterial != nil }

    /// Carries a v1.1–v1.4 setting forward onto the two states that are left.
    ///
    /// Both blurred stages meant the same look with a different amount of it, so both land on
    /// frosted; only an explicit "solid" stays off. Nil — a fresh install — lands frosted,
    /// because that is the house standard.
    static func migrating(stored: String?) -> FrostStyle {
        switch stored {
        case "solid": return .solid
        case .some(let raw): return FrostStyle(rawValue: raw) ?? .frosted
        case nil: return .frosted
        }
    }

    /// Reads the stored preference, falling back to frosted on anything unrecognised.
    @MainActor
    static func current(_ preferences: Preferences) -> FrostStyle {
        FrostStyle(rawValue: preferences.frostStyle) ?? .frosted
    }

    #if DEBUG
    static func selfCheck() {
        assert(allCases.count == 2, "one switch — on or off, with no amount to choose")

        // Solid is the state that paints its own colour instead of an effect view. A nil
        // material is what every surface reads to decide that, so getting it backwards makes
        // "off" still show the desktop.
        assert(FrostStyle.solid.panelMaterial == nil && FrostStyle.solid.windowMaterial == nil)
        assert(!FrostStyle.solid.isFrosted && FrostStyle.frosted.isFrosted)

        // The two the house standard names, and the window needs the lighter one — `.popover`
        // stretched across 820pt is a flat milky sheet the small panel never shows.
        assert(FrostStyle.frosted.panelMaterial == .popover)
        assert(FrostStyle.frosted.windowMaterial == .sidebar)

        // **Carrying a v1.1–v1.4 install forward.** Both old blurred stages were the same look
        // with a different amount of it, so both land on frosted; only an explicit Solid is off.
        assert(FrostStyle.migrating(stored: "translucent") == .frosted)
        assert(FrostStyle.migrating(stored: "clear") == .frosted)
        assert(FrostStyle.migrating(stored: "solid") == .solid)
        // Never set — a fresh install — lands on the house standard rather than flat.
        assert(FrostStyle.migrating(stored: nil) == .frosted)

        for style in allCases {
            assert(!style.label.isEmpty && !style.blurb.isEmpty)
            assert(FrostStyle(rawValue: style.rawValue) == style, "raw value must round trip")
        }
    }
    #endif
}

/// A live blur of whatever is behind the window.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

/// The fill for every senti surface: frosted when the setting asks for it, flat when it does not.
///
/// Nothing inside a frosted surface may paint its own opaque background, or it shows as a hole
/// punched through the blur.
/// The fill for the menu-bar panel.
///
/// The main window does not use this: it blurs at the window level with an `NSVisualEffectView`
/// as its content view, which is what keeps its titlebar, corner rounding and shadow correct.
/// See `MainWindowController`.
struct SurfaceFill: View {
    @ObservedObject private var preferences = Preferences.shared
    /// The colour used when frost is off.
    var opaque: Color = Theme.surface

    var body: some View {
        if let material = FrostStyle.current(preferences).panelMaterial {
            VisualEffectBackground(material: material)
        } else {
            opaque
        }
    }
}
