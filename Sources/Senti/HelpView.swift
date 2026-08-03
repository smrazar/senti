import SwiftUI

/// Getting a phone ready, and what to try when it will not connect.
///
/// Written as plain steps rather than a link out: the two things that go wrong — USB debugging
/// off, and a second adb holding the port — account for nearly every "it does not see my phone".
struct HelpView: View {

    let state: AppState

    @State private var expanded: Set<String> = ["Get the phone ready"]

    private struct Topic {
        let title: String
        let symbol: String
        let steps: [String]
    }

    private let topics: [Topic] = [
        Topic(title: "Get the phone ready",
              symbol: Sym.usb,
              steps: [
                "On the phone, open Settings → About phone and tap Build number seven times. That turns on Developer options.",
                "Go back to Settings → System → Developer options and switch on USB debugging.",
                "Plug the phone into the Mac with a cable that carries data — some charge-only cables will not work.",
                "The phone asks whether to allow USB debugging from this computer. Tap Allow, and tick Always allow so it stops asking.",
                "The phone appears in senti's panel with a Mirror button next to it.",
              ]),
        Topic(title: "The phone does not show up",
              symbol: Sym.warning,
              steps: [
                "Check the cable first. A cable that only charges will never carry adb.",
                "Unlock the phone. A locked phone will not show the authorisation prompt.",
                "If the row says the phone is not authorised, unplug it, plug it back in, and tap Allow on the phone.",
                "If you have Android Studio or a Homebrew adb installed, its copy may be holding the port senti needs. Settings → Toolchain → Restart adb sorts that out.",
                "Still nothing: Settings → Toolchain → Re-install the tools unpacks a fresh copy from the app bundle.",
              ]),
        Topic(title: "The picture stutters or looks soft",
              symbol: Sym.paneMirroring,
              steps: [
                "Raise the bitrate in Mirroring. 8 Mbps is the default; 12–16 is noticeably sharper on a big screen.",
                "Lower the resolution instead if the Mac is working hard — fewer pixels at a steady frame rate looks better than more pixels that stutter.",
                "Try h265 rather than h264 if the phone supports it. It carries more detail for the same bitrate.",
                "The frame rate and resolution caps are deliberate. Higher values pushed the pipeline hard enough to hang the Mac in testing.",
              ]),
        Topic(title: "Nothing controls the phone",
              symbol: Sym.device,
              steps: [
                "Click the mirror window first — it takes keyboard and mouse only while it is focused.",
                "Typing goes to the phone as if from a hardware keyboard, so the phone's own on-screen keyboard may stay hidden.",
            ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.section) {
            VStack(alignment: .leading, spacing: Theme.Space.s16) {
                ForEach(topics, id: \.title) { topic in
                    topicCard(topic)
                }
            }

            // The toolchain had a pane of its own until the sidebar was cut to four. Its two
            // buttons are repair steps, which is what this pane is for.
            ToolchainSettingsView(state: state)

            AboutView()
        }
    }

    private func topicCard(_ topic: Topic) -> some View {
        let isOpen = expanded.contains(topic.title)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                if isOpen { expanded.remove(topic.title) } else { expanded.insert(topic.title) }
            } label: {
                HStack(spacing: Theme.Space.s12) {
                    Image(systemName: topic.symbol)
                        .font(.system(size: Theme.IconSize.row))
                        .foregroundStyle(isOpen ? Theme.accent : Theme.textSecondary)
                        .frame(width: 20)
                    Text(topic.title)
                        .font(Theme.Font.bodyEmph)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: Theme.Space.s8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: Theme.IconSize.inline, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .padding(.vertical, Theme.Space.rowV)
                .padding(.horizontal, Theme.Space.rowH)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(alignment: .leading, spacing: Theme.Space.s12) {
                    ForEach(Array(topic.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: Theme.Space.s12) {
                            Text("\(index + 1)")
                                .font(Theme.Font.monoSmall)
                                .foregroundStyle(Theme.textTertiary)
                                .frame(width: 20, alignment: .trailing)
                            Text(step)
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.rowH)
                .padding(.bottom, Theme.Space.card)
                .transition(.opacity)
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .animation(Theme.Motion.standard, value: isOpen)
    }
}
