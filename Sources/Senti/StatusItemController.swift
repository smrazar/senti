import AppKit
import SwiftUI

/// Owns the one menu-bar item: its glyph, its click routing, and the panel it drops.
///
/// The glyph is a template image so macOS inverts it for a light or dark bar. It changes with
/// state — plain phone when idle, radio-waves phone while a session is live — never by colour.
@MainActor
final class StatusItemController {

    private let item: NSStatusItem
    private var panel: MenuBarPanel?
    private var cancellable: Any?

    private let state: AppState

    init(state: AppState) {
        self.state = state
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Set before any button configuration — position persistence depends on it, and on
        // never recreating the item.
        item.autosaveName = "senti.statusItem"
        item.behavior = []

        if let button = item.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        applySymbol(mirroring: false)
    }

    deinit {
        let statusItem = item
        Task { @MainActor in NSStatusBar.system.removeStatusItem(statusItem) }
    }

    var button: NSStatusBarButton? { item.button }

    // MARK: - Glyph

    /// Swaps the glyph for the live-session variant. Called by `AppState` whenever the session
    /// count crosses zero.
    func applySymbol(mirroring: Bool) {
        let name = mirroring ? Sym.menuBarActive : Sym.menuBarIdle
        let label = mirroring ? "senti — mirroring" : "senti"
        let config = NSImage.SymbolConfiguration(pointSize: Theme.IconSize.menuBar, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: label)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button?.image = image
        button?.contentTintColor = nil
        button?.toolTip = label
    }

    // MARK: - Click routing

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if isRight {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: #selector(AppState.openSettingsAction), keyEquivalent: ",")
        settings.target = state
        menu.addItem(settings)
        if state.scrcpy.hasAnySession {
            let stop = NSMenuItem(title: "Stop All Mirroring", action: #selector(AppState.stopAllAction), keyEquivalent: "")
            stop.target = state
            menu.addItem(stop)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit senti", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        item.menu = menu
        button?.performClick(nil)
        item.menu = nil
    }

    // MARK: - Panel

    func togglePanel() {
        if let panel, panel.isShowing {
            panel.dismiss()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard let button else { return }
        // A failure from a previous session should not still be sitting there the next time the
        // panel is opened — by then it is history, not news.
        state.scrcpy.lastError = nil

        // Rebuilt each time rather than kept alive: the panel's height follows the device list,
        // and a stale hosting view measured against an empty list opens at the wrong size.
        let content = DevicePanel(state: state)
        let panel = MenuBarPanel.hosting(content, width: 340)
        self.panel = panel

        state.deviceMonitor.setPolling(fast: true)
        panel.present(below: button) { [weak self] in
            MainActor.assumeIsolated { self?.state.deviceMonitor.setPolling(fast: false) }
        }
    }

    func dismissPanel() {
        panel?.dismiss()
    }

    /// Called when the device list changes while the panel is open, so it grows or shrinks with
    /// the content instead of clipping new rows.
    ///
    /// Deferred a pass: this runs from the Combine sink that publishes the change, and the
    /// hosting view has not laid the new row out yet. Measuring now returns the old height, and
    /// a phone plugged in with the panel open would slide in behind a clipped edge.
    func resizePanel() {
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.panel?.resizeToFit() }
        }
    }
}
