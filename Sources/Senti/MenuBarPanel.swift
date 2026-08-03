import AppKit
import SwiftUI

/// The floating panel that drops from the menu-bar icon.
///
/// A borderless window returns `false` from `canBecomeKey` by default, and a non-key panel
/// receives no keyboard events and cannot hand focus to a control. The override below is what
/// makes the rename field and the Escape key work at all.
final class MenuBarPanel: NSPanel {

    private(set) static weak var current: MenuBarPanel?

    private var onClose: (() -> Void)?

    /// True while the close animation is in flight. Re-opening clears it, which cancels the
    /// pending `orderOut` — otherwise a fast toggle would hide the panel it just reopened.
    private var isClosing = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(content: NSView, width: CGFloat) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: width, height: 100),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = content
    }

    // MARK: - Presentation

    /// Shows the panel under the status-item button, clamped to the screen.
    func present(below anchor: NSStatusBarButton, onClose: (() -> Void)? = nil) {
        self.onClose = onClose
        isClosing = false
        MenuBarPanel.current?.dismiss()

        guard let anchorWindow = anchor.window, let screen = anchorWindow.screen ?? NSScreen.main else { return }
        let anchorRect = anchorWindow.convertToScreen(anchor.convert(anchor.bounds, to: nil))

        let size = contentView?.fittingSize ?? frame.size
        let width = max(frame.width, size.width)
        let height = max(size.height, 1)

        let gap: CGFloat = 8
        var origin = NSPoint(x: anchorRect.midX - width / 2,
                             y: anchorRect.minY - height - gap)
        let visible = screen.visibleFrame
        origin.x = min(max(visible.minX + gap, origin.x), visible.maxX - width - gap)
        origin.y = max(visible.minY + gap, origin.y)

        setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: false)

        // Panel-open recipe: fade + 6px rise over 160ms, ease-out.
        alphaValue = 0
        setFrameOrigin(NSPoint(x: origin.x, y: origin.y - 6))
        MenuBarPanel.current = self
        orderFrontRegardless()
        makeKey()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0, 0, 1)
            animator().alphaValue = 1
            animator().setFrameOrigin(origin)
        }
    }

    /// Re-measures the hosting view and grows or shrinks the panel downward, keeping the top
    /// edge pinned under the menu bar. `present` only measures once, so anything that changes
    /// height later — a phone plugged in, a rename field opening — has to call this.
    func resizeToFit() {
        guard isVisible, let contentView else { return }
        let fitting = contentView.fittingSize
        let height = max(fitting.height, 1)
        let width = max(fitting.width, frame.width)
        guard abs(height - frame.height) > 0.5 || abs(width - frame.width) > 0.5 else { return }

        let top = frame.maxY
        var origin = NSPoint(x: frame.minX, y: top - height)
        if let visible = (screen ?? NSScreen.main)?.visibleFrame {
            let gap: CGFloat = 8
            origin.x = min(max(visible.minX + gap, origin.x), visible.maxX - width - gap)
            origin.y = max(visible.minY + gap, origin.y)
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0, 0, 1)
            animator().setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)),
                                display: true)
        }
    }

    /// The inverse of the open recipe: fade + 4px drop over 110ms.
    func dismiss() {
        guard isVisible, !isClosing else { return }
        isClosing = true
        if MenuBarPanel.current === self { MenuBarPanel.current = nil }
        let resting = frame.origin

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.11
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 1, 1)
            animator().alphaValue = 0
            animator().setFrameOrigin(NSPoint(x: resting.x, y: resting.y - 4))
        } completionHandler: { [weak self] in
            guard let self, self.isClosing else { return }
            self.orderOut(nil)
            self.setFrameOrigin(resting)
            self.alphaValue = 1
            self.isClosing = false
            self.onClose?()
        }
    }

    var isShowing: Bool { isVisible }

    // MARK: - Auto-close

    override func resignKey() {
        super.resignKey()
        dismiss()
    }

    /// Escape closes, even when a text field holds focus.
    override func cancelOperation(_ sender: Any?) {
        dismiss()
    }
}

/// Wraps a SwiftUI view in the standard panel surface: fill, hairline border, panel radius.
/// Depth comes from the hairline first and the window shadow second, frosted or not.
struct PanelSurface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(SurfaceFill())
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }
}

/// `NSHostingView` refuses the first mouse by default, so the click that makes the panel key is
/// swallowed instead of reaching the SwiftUI control under the pointer — every button in the
/// panel would need clicking twice.
final class FirstMouseHostingView<V: View>: NSHostingView<V> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @MainActor required init(rootView: V) { super.init(rootView: rootView) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("not used") }
}

extension MenuBarPanel {
    /// Builds a panel hosting `view` inside the standard surface.
    static func hosting<V: View>(_ view: V, width: CGFloat) -> MenuBarPanel {
        let root = PanelSurface { view }.frame(width: width)
        let host = FirstMouseHostingView(rootView: root)
        let fitting = host.fittingSize
        host.frame = NSRect(x: 0, y: 0, width: max(width, fitting.width), height: fitting.height)
        return MenuBarPanel(content: host, width: max(width, fitting.width))
    }
}

#if DEBUG
extension MenuBarPanel {
    /// Asserts the `canBecomeKey` override survives, and that a text field inside the panel can
    /// actually take focus. Reasoning about this instead of running it is how the rename field
    /// ends up silently dead.
    @MainActor
    static func selfCheck() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 40))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        field.isEditable = true
        container.addSubview(field)

        let panel = MenuBarPanel(content: container, width: 120)
        assert(panel.canBecomeKey, "canBecomeKey override missing — typing and clicks will both be dead")

        // Parked off-screen so the check never flashes anything at the user.
        panel.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        panel.orderFrontRegardless()
        assert(panel.makeFirstResponder(field),
               "the panel refused first responder to a text field — renaming would be dead")

        panel.orderOut(nil)
        MenuBarPanel.current = nil
    }
}
#endif
