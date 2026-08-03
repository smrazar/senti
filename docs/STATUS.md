# senti — Status

*Updated: 2026-07-26 · Phase: verify · Version: 1.4*

## TL;DR

Menu-bar app that mirrors an Android phone to the Mac over USB. **v1.4 is built, installed at
`/Applications/senti.app` and running.**

**Defaults are a real working configuration:** h265 · 4 Mbps · 720px · 120 fps, always on top,
phone kept unlocked with its own screen off, open at login, no connect banners.

Written from scratch as a Swift package in the same design language as Stow: greyscale plus one
pastel-cyan accent, roomy spacing, SF Symbols everywhere, 120–160ms motion.

**Deployment target is macOS 15.** Apple Silicon only — the bundled scrcpy is an aarch64 build.

Version rule: `+0.1` for a normal round, `+1.0` for a major one. Single source: `VERSION=` in
`package-app.sh`.

Where things are written down:
- **`CHANGELOG.md`** — what shipped and what was left out on purpose.
- **`BUGS.md`** — bugs by root cause, plus platform behaviours that look like bugs.
- **`DESIGN.md`** — the visual rules. `Sources/Senti/Theme.swift` holds the values.
- **`README.md`** — the front page.

## Verified this round

- Clean build, zero warnings.
- `senti --self-check` passes: colour conversion, adb output parsing, the settings search index,
  shortcut labelling, the scrcpy argument builder, and a preferences round-trip through
  UserDefaults.
- Fresh install unpacks scrcpy + adb to `~/Library/Application Support/senti/` on first launch;
  both binaries land executable. `adb version` runs from the unpacked copy.
- All 16 scrcpy flags senti emits exist in the bundled scrcpy 4.0 (`--help` checked one by one).
- App launches and stays up. No crash reports.
- **Live on a real phone: mirroring works and input works.** Confirmed on
  2026-07-26.
- 78 advanced flags parsed from the real 738-line `scrcpy --help` and checked flag by flag
  (`senti --list-flags`); every parsed name is punctuation-free and every category bucket sane.
- The full generated command line — including the virtual display, all three display flags and a
  force-stopped `--start-app` — is accepted by scrcpy 4.0, which reaches device discovery rather
  than rejecting an argument.
- Fresh install registers the login item with macOS.

**Never verified here: anything visual.** `screencapture` from an agent session returns black
without Screen Recording permission, so every UI judgement in this project came back through the
screenshots taken by hand. Two rounds of frost bugs were found that way — see BUGS B11–B13.

## New in 1.4

Translucency rebuilt the way Stow does it: one NSVisualEffectView as the window content view,
full-size content under a transparent titlebar, and only the sidebar frosted. Fixes both the
opaque bar across the top and the whole-window blur.

## New in 1.3

Translucency fixed on the main window (it used the panel's material), cards no longer punch
opaque holes through the frost, sidebar has the app icon and two nav groups, About redesigned,
Advanced flags grouped into eight categories, quick settings gained bitrate/resolution/borderless,
and the shipped defaults are now a real working configuration.

## New in 1.2

Virtual display: Mirror can open a second Android screen instead of copying the phone's, with
size, density, an app to open on it, resize-with-window, keep-apps-on-close and hidden system
decorations. The Phone screen / New display switch is in the panel; its settings are in Mirroring.

## New in 1.1

Advanced pane (83 scrcpy options parsed from the binary's own help, searchable, with Reset),
Solid/Translucent/Clear backgrounds, quick settings in the panel, four sidebar panes instead of
seven, and the frame-rate ceiling raised to 120. Eight fixes from the polish pass — see
`CHANGELOG.md`.

## Still to check by hand

1. Stop, then close the scrcpy window directly — both should clear the row back to Mirror.
2. Rename a phone from the row's context menu. Unplug it; it should stay listed under RECENT with
   the new name.
3. Turn recording on, mirror briefly, stop. The file should appear under Recording → Recent.
4. Walk every settings pane at the minimum window width (680pt) and check no row wraps one
   character per line.
5. Record a keyboard shortcut, then press it from another app.
6. Toggle the system between light and dark with the panel open.
7. Switch the background through Solid, Translucent and Clear with both the panel and the main
   window open. Nothing inside either should read as an opaque patch over the blur.
8. In Advanced, switch on a harmless option (`--no-cleanup`), mirror, and confirm the session
   still starts. Then Reset and confirm it goes back.
9. Right-click a device row while the panel is open — the context menu should appear without the
   panel dismissing behind it. Untested.
10. Switch the panel to New display and press Mirror. A second Android screen should open, and
    the phone's own screen should stay usable. Then set a package name and confirm the app opens
    on it rather than on the phone.
11. With New display on, turn on "Keep apps when it closes", open an app on it, then close the
    window — the app should reappear on the phone rather than being killed.

## Next round, unpicked

The advanced-flag pane and virtual displays both shipped. What is left, in rough order of
usefulness — the first is a gap this rewrite introduced rather than one it inherited:

- **Capture scrcpy's stderr.** It goes to `/dev/null`, so a failed session reports "stopped
  unexpectedly (code 1)" with no reason. The last twenty lines would make that an actual message.
- **Screenshot** to clipboard or a file, via `adb screencap` — works with no session running.
- **Device stats on the row** — "Android 14 · 87%", two `adb shell` probes.
- **An installed-app picker** for the virtual display, instead of typing a package name.
- **Command preview** — the exact scrcpy line before it launches.
- **File transfer** — drag onto a row to push, `.apk` auto-installs; pull Screenshots / DCIM /
  Downloads.
- **Diagnostics** — one copyable report for triage.
- **Orphan detection** — adopt or kill a scrcpy left behind by a crash.
- Smaller: stop on sleep, double-click a row to mirror, copy serial, session count on the glyph,
  `adb reconnect offline`, settings export/import.
