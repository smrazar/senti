import AppKit
import SwiftUI

/// The first-run tour: three pages, shown once.
///
/// It exists because senti's whole UI is one menu-bar icon. Without it, a new user's first
/// sight of the app is a phone glyph in the bar and no sign of what to do with it.
@MainActor
final class OnboardingWindow: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindow()

    private var window: NSWindow?

    func present() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let root = OnboardingView { [weak self] in self?.finish() }
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Welcome to senti"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 520, height: 460))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        Preferences.shared.hasSeenTour = true
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        // Closing with the red button counts as seen — otherwise the tour reappears every launch
        // for anyone who dismissed it on purpose.
        Preferences.shared.hasSeenTour = true
        ActivationPolicy.refresh()
    }
}

struct OnboardingView: View {

    let onFinish: () -> Void

    @State private var page = 0

    private struct Page {
        let symbol: String
        let title: String
        let body: String
        let bullets: [String]
    }

    private let pages: [Page] = [
        Page(symbol: "iphone.gen3.radiowaves.left.and.right",
             title: "senti",
             body: "Mirror an Android phone on the Mac, over USB. No Terminal, no Homebrew, nothing to install — the tools ship inside the app.",
             bullets: []),
        Page(symbol: Sym.usb,
             title: "Get the phone ready",
             body: "One-time setup on the phone itself.",
             bullets: [
                "Settings → About phone → tap Build number seven times.",
                "Settings → System → Developer options → turn on USB debugging.",
                "Plug the phone in and tap Allow on the prompt it shows.",
             ]),
        Page(symbol: Sym.menuBarIdle,
             title: "That’s it",
             body: "senti lives in the menu bar. Click the phone icon to see what is connected and press Mirror.",
             bullets: [
                "The icon gains radio waves while a session is running.",
                "Everything else — picture quality, recording, a keyboard shortcut — is in Settings.",
             ]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: Theme.Space.s20) {
                Image(systemName: pages[page].symbol)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.symbolEffect(.replace))

                Text(pages[page].title)
                    .font(Theme.Font.display)
                    .foregroundStyle(Theme.textPrimary)

                Text(pages[page].body)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 360)

                if !pages[page].bullets.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.s12) {
                        ForEach(pages[page].bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: Theme.Space.s12) {
                                Circle().fill(Theme.accent).frame(width: 5, height: 5)
                                    .padding(.top, 6)
                                Text(bullet)
                                    .font(Theme.Font.body)
                                    .foregroundStyle(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: 360, alignment: .leading)
                }
            }
            .padding(.horizontal, Theme.Space.s40)
            .id(page)
            .transition(.opacity)

            Spacer(minLength: 0)

            HStack(spacing: Theme.Space.s8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Theme.accent : Theme.borderStrong)
                        .frame(width: 6, height: 6)
                }
                Spacer()
                if page > 0 {
                    SecondaryButton(title: "Back") { page -= 1 }
                }
                if page < pages.count - 1 {
                    PrimaryButton(title: "Next") { page += 1 }
                } else {
                    PrimaryButton(title: "Done", action: onFinish)
                }
            }
            .padding(Theme.Space.panel)
        }
        .frame(width: 520, height: 460)
        .background(Theme.bg)
        .animation(Theme.Motion.standard, value: page)
    }
}
