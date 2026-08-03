import AppKit
import Combine
import SwiftUI

/// The four panes of the main window, in sidebar order.
///
/// It was seven. Recording, the toolchain and the shortcut each had a pane to themselves holding
/// two or three rows, which made the sidebar look like the app had far more settings than it
/// does. They are groups inside a pane now, and About is the last section of Help.
enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case mirroring, advanced, general, help

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mirroring: return "Mirroring"
        case .advanced: return "Advanced"
        case .general: return "General"
        case .help: return "Help"
        }
    }

    var symbol: String {
        switch self {
        case .mirroring: return Sym.paneMirroring
        case .advanced: return Sym.paneAdvanced
        case .general: return Sym.paneGeneral
        case .help: return Sym.paneHelp
        }
    }

    /// One line under the pane title, so a pane explains itself before the user reads its rows.
    var blurb: String {
        switch self {
        case .mirroring: return "Picture, sound, the mirror window, and recording."
        case .advanced: return "Every option the bundled scrcpy understands, straight from its own help."
        case .general: return "Appearance, startup, the keyboard shortcut, and starting over."
        case .help: return "Getting a phone ready, fixing a connection, and what senti is built on."
        }
    }
}

// MARK: - Window

/// Hosts the main window and flips the activation policy while it is open, so an accessory app
/// still gets a focusable, minimisable window.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    private var window: NSWindow?
    private let selection = PaneSelection()
    private weak var backdrop: NSVisualEffectView?
    private var frostObserver: AnyCancellable?

    func present(state: AppState, pane: SettingsPane? = nil) {
        if let pane { selection.current = pane }

        if let window {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        // One `NSVisualEffectView` is the window's base surface, with the SwiftUI tree layered on
        // top of it. Blurring at the window level is what AppKit expects, so the titlebar, corner
        // rounding and shadow all stay correct. Blurring inside a transparent window instead
        // detaches the titlebar from the content, which is what the solid white strip across the
        // top was.
        //
        // Only the sidebar lets this backdrop show. The content pane paints an opaque fill over
        // it — settings text has to stay readable over any wallpaper, and a window frosted edge
        // to edge reads as three differently-tinted slabs rather than one surface.
        let style = FrostStyle.current(state.preferences)
        let backdrop = NSVisualEffectView()
        backdrop.material = style.windowMaterial ?? .sidebar
        backdrop.blendingMode = .behindWindow
        backdrop.state = style.isFrosted ? .active : .inactive
        self.backdrop = backdrop

        // The switch lives in this window, so it has to restyle the window it is sitting in —
        // otherwise the control does nothing visible until the window is closed and reopened.
        frostObserver = state.preferences.$frostStyle
            .receive(on: RunLoop.main)
            .sink { [weak backdrop] raw in
                let style = FrostStyle(rawValue: raw) ?? .frosted
                backdrop?.material = style.windowMaterial ?? .sidebar
                backdrop?.state = style.isFrosted ? .active : .inactive
            }

        let hosting = NSHostingView(rootView: MainWindow(state: state, selection: selection))
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = backdrop.bounds
        backdrop.addSubview(hosting)

        // `.fullSizeContentView` lets the backdrop run under the titlebar, so the window frosts
        // as one surface rather than growing an opaque bar across the top. The traffic lights
        // then float over the sidebar, which pads its content down to clear them.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 600),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered,
                              defer: false)
        window.contentView = backdrop
        window.title = "senti"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 820, height: 600))
        window.contentMinSize = NSSize(width: 680, height: 480)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName("SentiMainWindow")
        window.center()
        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        ActivationPolicy.refresh()
    }
}

/// Shared so `openMainWindow(selecting:)` can jump straight to a pane.
@MainActor
final class PaneSelection: ObservableObject {
    @Published var current: SettingsPane = .mirroring
}

// MARK: - View

struct MainWindow: View {

    @ObservedObject var state: AppState
    @ObservedObject var selection: PaneSelection
    /// Watched so switching the frost style redraws the window immediately.
    @ObservedObject private var preferences = Preferences.shared

    @State private var query = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.border).frame(width: 1)
            content
        }
        .frame(minWidth: 680, minHeight: 480)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s12) {
            wordmark
                .padding(.horizontal, Theme.Space.s16)
                // Clears the traffic lights: with a full-size content view the sidebar runs to
                // the very top of the window, but its text has to start below the buttons.
                .padding(.top, 30)

            searchField
                .padding(.horizontal, Theme.Space.s12)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if query.isEmpty {
                        // Two groups, not one flat list: what senti does, then how senti itself
                        // behaves. Four items in a row read as an undifferentiated pile.
                        ForEach([SettingsPane.mirroring, .advanced]) { sidebarRow($0) }
                        Rectangle()
                            .fill(Theme.border)
                            .frame(height: 1)
                            .padding(.horizontal, Theme.Space.s12)
                            .padding(.vertical, Theme.Space.s12)
                        ForEach([SettingsPane.general, .help]) { sidebarRow($0) }
                    } else {
                        searchResults
                    }
                }
                .padding(.horizontal, Theme.Space.s8)
                .padding(.bottom, Theme.Space.s16)
            }
        }
        .frame(width: 210)
        // Frosted: paint nothing and let the window's backdrop through. Off: an opaque fill that
        // hides it. Never a second `NSVisualEffectView` — stacking blurs costs frames and muddies
        // the result.
        .background(FrostStyle.current(preferences).isFrosted ? Color.clear : Theme.surfaceSecondary)
    }

    /// The app's own icon and name at the top of the sidebar, so the window says what it is
    /// before it says what it can do.
    private var wordmark: some View {
        HStack(spacing: Theme.Space.s8) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: Sym.menuBarIdle)
                    .font(.system(size: Theme.IconSize.row, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 20)
            }
            Text("senti")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private var searchField: some View {
        HStack(spacing: Theme.Space.s8) {
            Image(systemName: Sym.search)
                .font(.system(size: Theme.IconSize.inline))
                .foregroundStyle(Theme.textTertiary)
            TextField("Search settings", text: $query)
                .textFieldStyle(.plain)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.textPrimary)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Theme.IconSize.inline))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Space.s12)
        .frame(height: 30)
        // Slightly see-through over frost so the field reads as part of the sidebar rather than
        // a solid chip floating on it.
        .background(Theme.surfaceHover.opacity(FrostStyle.current(preferences).isFrosted ? 0.6 : 1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    private func sidebarRow(_ pane: SettingsPane) -> some View {
        let isSelected = selection.current == pane
        return Button {
            selection.current = pane
        } label: {
            HStack(spacing: Theme.Space.s12) {
                Image(systemName: pane.symbol)
                    .font(.system(size: Theme.IconSize.row, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                    .frame(width: 20)
                Text(pane.title)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, Theme.Space.s12)
            .background(isSelected ? Theme.accentSoft : .clear)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .animation(Theme.Motion.fast, value: isSelected)
    }

    @ViewBuilder
    private var searchResults: some View {
        let hits = SettingsSearch.matches(for: query)
        if hits.isEmpty {
            Text("Nothing matches “\(query)”.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textTertiary)
                .padding(Theme.Space.s12)
        } else {
            ForEach(hits) { hit in
                Button {
                    selection.current = hit.pane
                    query = ""
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hit.title).font(Theme.Font.body).foregroundStyle(Theme.textPrimary)
                        Text(hit.pane.title).font(Theme.Font.caption).foregroundStyle(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 9)
                    .padding(.horizontal, Theme.Space.s12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverHighlight()
            }
        }
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.section) {
                VStack(alignment: .leading, spacing: Theme.Space.s4) {
                    Text(selection.current.title)
                        .font(Theme.Font.display)
                        .foregroundStyle(Theme.textPrimary)
                    Text(selection.current.blurb)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.textSecondary)
                }

                pane
            }
            .padding(Theme.Space.panel)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Always opaque. Settings text sits on this, and it is the half of the window that has
        // to stay readable over any wallpaper.
        .background(Theme.bg)
        // Panes cross-fade rather than cutting, matching the panel's open recipe.
        .animation(Theme.Motion.swap, value: selection.current)
    }

    @ViewBuilder
    private var pane: some View {
        switch selection.current {
        case .mirroring: MirroringSettingsView(preferences: state.preferences)
        case .advanced: AdvancedSettingsView(state: state)
        case .general: GeneralSettingsView(state: state)
        case .help: HelpView(state: state)
        }
    }
}
