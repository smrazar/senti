import AppKit
import SwiftUI

/// The single source of truth for colour, spacing, radius, type and motion.
/// Every visual value in senti comes from here — no magic numbers in views.
///
/// Ported from Stow so the two apps read as one family. Colours are authored in OKLCH for the
/// accent family and as hex for the grey ramp. `NSColor(Color)` is never used: it resolves
/// against the "current" SwiftUI environment and renders solid black from plain AppKit code.
enum Theme {

    // MARK: - OKLCH → sRGB

    struct OKLCH {
        let l: Double
        let c: Double
        let h: Double
        let alpha: Double

        init(_ l: Double, _ c: Double, _ h: Double, alpha: Double = 1) {
            self.l = l
            self.c = c
            self.h = h
            self.alpha = alpha
        }

        /// Gamma-correct sRGB components in 0...1.
        var srgb: (r: Double, g: Double, b: Double) {
            let hRad = h * .pi / 180
            let a = c * cos(hRad)
            let bb = c * sin(hRad)

            let lp = l + 0.3963377774 * a + 0.2158037573 * bb
            let mp = l - 0.1055613458 * a - 0.0638541728 * bb
            let sp = l - 0.0894841775 * a - 1.2914855480 * bb

            let lc = lp * lp * lp
            let mc = mp * mp * mp
            let sc = sp * sp * sp

            let rLin = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
            let gLin = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
            let bLin = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc

            return (encode(rLin), encode(gLin), encode(bLin))
        }

        private func encode(_ v: Double) -> Double {
            let c = max(0, min(1, v))
            let out = c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
            return max(0, min(1, out))
        }

        /// Direct NSColor path — never bridged from SwiftUI.
        var nsColor: NSColor {
            let (r, g, b) = srgb
            return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
        }
    }

    /// sRGB from a `#RRGGBB` literal. The grey ramp is authored this way.
    static func hex(_ value: UInt32, alpha: Double = 1) -> NSColor {
        NSColor(srgbRed: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255,
                alpha: alpha)
    }

    /// A colour that follows the system appearance. Resolved by AppKit, so it is correct
    /// in both SwiftUI views and raw AppKit drawing.
    static func dynamic(_ light: OKLCH, _ dark: OKLCH) -> NSColor {
        dynamic(light.nsColor, dark.nsColor)
    }

    static func dynamic(_ light: NSColor, _ dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    // MARK: - Palette
    //
    // Greyscale everywhere plus one pastel-cyan accent. The accent is rationed: primary
    // buttons, toggle-on, focus rings, selected rows and the live-mirror indicator. Nothing
    // else in the app carries a hue.
    //
    // To re-point the app's accent later, change the four OKLCH triples below and nothing
    // else — every surface reads them through `Theme.accent*`.

    enum NS {
        static let bg = dynamic(hex(0xFDFDFD), hex(0x1E1F21))
        static let surface = dynamic(hex(0xFFFFFF), hex(0x28292C))
        static let surfaceSecondary = dynamic(hex(0xF3F4F5), hex(0x333438))
        static let surfaceHover = dynamic(hex(0xEDEEF0), hex(0x3B3C40))
        static let border = dynamic(hex(0x000000, alpha: 0.10), hex(0xFFFFFF, alpha: 0.12))
        static let borderStrong = dynamic(hex(0x000000, alpha: 0.16), hex(0xFFFFFF, alpha: 0.20))
        static let textPrimary = dynamic(hex(0x28292B), hex(0xF0F1F2))
        static let textSecondary = dynamic(hex(0x5F6164), hex(0xA7A9AD))
        static let textTertiary = dynamic(hex(0x8A8C8F), hex(0x7E8085))

        static let accent = dynamic(OKLCH(0.740, 0.100, 205), OKLCH(0.800, 0.100, 205))
        static let accentHover = dynamic(OKLCH(0.700, 0.105, 205), OKLCH(0.840, 0.100, 205))
        static let accentSoft = dynamic(OKLCH(0.740, 0.100, 205, alpha: 0.14),
                                        OKLCH(0.800, 0.100, 205, alpha: 0.18))
        static let onAccent = dynamic(OKLCH(0.230, 0.030, 220), OKLCH(0.200, 0.030, 220))

        /// Red is the one non-accent hue in the app, and only for destructive confirmation —
        /// "Forget this device", "Reset all settings". Never for ordinary error text, which
        /// uses the grey ramp plus an icon.
        static let danger = dynamic(hex(0xC0392B), hex(0xE06C5E))

        #if DEBUG
        /// Fixed sample used by `Theme.selfCheck()` to verify `hex()` decoding.
        static let hexProbe = hex(0x28292B)
        #endif
    }

    static var bg: Color { Color(nsColor: NS.bg) }
    static var surface: Color { Color(nsColor: NS.surface) }
    static var surfaceSecondary: Color { Color(nsColor: NS.surfaceSecondary) }
    static var surfaceHover: Color { Color(nsColor: NS.surfaceHover) }
    static var border: Color { Color(nsColor: NS.border) }
    static var borderStrong: Color { Color(nsColor: NS.borderStrong) }
    static var textPrimary: Color { Color(nsColor: NS.textPrimary) }
    static var textSecondary: Color { Color(nsColor: NS.textSecondary) }
    static var textTertiary: Color { Color(nsColor: NS.textTertiary) }
    static var accent: Color { Color(nsColor: NS.accent) }
    static var accentHover: Color { Color(nsColor: NS.accentHover) }
    static var accentSoft: Color { Color(nsColor: NS.accentSoft) }
    static var onAccent: Color { Color(nsColor: NS.onAccent) }
    static var danger: Color { Color(nsColor: NS.danger) }

    // MARK: - Spacing (roomy)

    enum Space {
        static let s4: CGFloat = 4
        static let s8: CGFloat = 8
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s20: CGFloat = 20
        static let s24: CGFloat = 24
        static let s28: CGFloat = 28
        static let s32: CGFloat = 32
        static let s40: CGFloat = 40
        static let s48: CGFloat = 48

        static let panel: CGFloat = 28
        static let card: CGFloat = 20
        static let rowV: CGFloat = 14
        static let rowH: CGFloat = 16
        static let control: CGFloat = 16
        static let section: CGFloat = 32
        static let item: CGFloat = 12
    }

    enum Radius {
        static let control: CGFloat = 6
        static let card: CGFloat = 8
        static let panel: CGFloat = 10
        static let pill: CGFloat = 999
    }

    // MARK: - Type

    enum Font {
        static let display = SwiftUI.Font.system(size: 24, weight: .semibold, design: .default)
        static let title = SwiftUI.Font.system(size: 16, weight: .semibold)
        static let headline = SwiftUI.Font.system(size: 14, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 13, weight: .regular)
        static let bodyEmph = SwiftUI.Font.system(size: 13, weight: .medium)
        static let caption = SwiftUI.Font.system(size: 11, weight: .regular)
        static let mono = SwiftUI.Font.system(size: 13, weight: .regular, design: .monospaced)
        static let monoSmall = SwiftUI.Font.system(size: 11, weight: .regular, design: .monospaced)
    }

    enum IconSize {
        static let inline: CGFloat = 13
        static let row: CGFloat = 15
        static let toolbar: CGFloat = 16
        static let tab: CGFloat = 14
        static let empty: CGFloat = 28
        static let menuBar: CGFloat = 16
    }

    // MARK: - Motion (subtle & quick, ease-out; never springy)

    enum Motion {
        static let fast = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.12)
        static let standard = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.16)
        static let swap = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.14)
    }

    enum Elevation {
        static let panelRadius: CGFloat = 20
        static let panelY: CGFloat = 6
        static var panelColor: Color { Color.black.opacity(0.14) }
    }
}

// MARK: - Self-check

#if DEBUG
extension Theme {
    /// Verifies the OKLCH→sRGB path against the hex values the design language documents.
    static func selfCheck() {
        func hexString(_ c: OKLCH) -> String {
            let (r, g, b) = c.srgb
            return String(format: "#%02X%02X%02X",
                          Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
        }
        func close(_ a: String, _ b: String) -> Bool {
            guard a.count == 7, b.count == 7 else { return false }
            for i in stride(from: 1, to: 7, by: 2) {
                let sa = a.index(a.startIndex, offsetBy: i)
                let sb = b.index(b.startIndex, offsetBy: i)
                let va = Int(a[sa...a.index(sa, offsetBy: 1)], radix: 16) ?? -1
                let vb = Int(b[sb...b.index(sb, offsetBy: 1)], radix: 16) ?? -2
                if abs(va - vb) > 3 { return false }
            }
            return true
        }
        assert(close(hexString(OKLCH(0.740, 0.100, 205)), "#50BDC9"),
               "light accent drifted: \(hexString(OKLCH(0.740, 0.100, 205)))")
        assert(close(hexString(OKLCH(0.800, 0.100, 205)), "#65D0DC"),
               "dark accent drifted: \(hexString(OKLCH(0.800, 0.100, 205)))")
        assert(close(hexString(OKLCH(1.0, 0.0, 0)), "#FFFFFF"), "pure white must round-trip")
        assert(close(hexString(OKLCH(0.0, 0.0, 0)), "#000000"), "pure black must round-trip")

        let grey = NS.hexProbe
        assert(abs(grey.redComponent - 0x28 / 255.0) < 0.005
                && abs(grey.greenComponent - 0x29 / 255.0) < 0.005
                && abs(grey.blueComponent - 0x2B / 255.0) < 0.005,
               "hex() decoded #28292B wrongly")
    }
}
#endif
