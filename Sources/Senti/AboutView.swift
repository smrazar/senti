import AppKit
import SwiftUI

/// What this is, what version, and the credits the licences require.
///
/// One card rather than a settings group: nothing here is a setting, and rows with an empty
/// control column read as switches someone forgot to wire up.
struct AboutView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s12) {
            Text("ABOUT")
                .font(Theme.Font.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.textTertiary)

            VStack(alignment: .leading, spacing: 0) {
                identity
                RowDivider()
                credits
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
        }
    }

    // MARK: Identity

    private var identity: some View {
        HStack(alignment: .center, spacing: Theme.Space.s20) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 56, height: 56)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("senti")
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.textPrimary)
                Text("Mirror an Android phone on the Mac, over USB.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.textSecondary)
                Text("GPL-3.0")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: Theme.Space.s16)
            VStack(alignment: .trailing, spacing: 3) {
                Text("Version")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)
                Text(AppInfo.version)
                    .font(Theme.Font.mono)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(Theme.Space.card)
    }

    // MARK: Credits

    private var credits: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s16) {
            Text("Built on")
                .font(Theme.Font.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)

            creditRow(name: "scrcpy",
                      detail: "The mirroring engine, by Genymobile. Bundled unmodified.",
                      trailing: Toolchain.version,
                      licence: "Apache 2.0")
            creditRow(name: "Android platform tools",
                      detail: "adb, which finds the phone and talks to it.",
                      trailing: nil,
                      licence: "Apache 2.0")

            Text("senti is a wrapper. Everything that makes mirroring fast is scrcpy’s work; senti hands it the right settings and stays out of the way.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Space.card)
    }

    private func creditRow(name: String, detail: String, trailing: String?, licence: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.s12) {
            Image(systemName: Sym.paneToolchain)
                .font(.system(size: Theme.IconSize.row))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Space.s8) {
                    Text(name).font(Theme.Font.bodyEmph).foregroundStyle(Theme.textPrimary)
                    if let trailing {
                        Text(trailing).font(Theme.Font.monoSmall).foregroundStyle(Theme.textSecondary)
                    }
                }
                Text(detail)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Space.s12)
            KeycapChip(text: licence)
        }
    }
}

enum AppInfo {
    /// Reads the bundle so the version is stated in exactly one place — `package-app.sh`.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
