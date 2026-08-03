# Changelog

Version rule: `+0.1` for a normal round, `+1.0` for a major one. Single source: `VERSION=` in
`package-app.sh`.

## [1.5] — 2026-07-27

### Changed — the background setting is one switch

Solid / Translucent / Clear is now just **Frosted**, on or off. This is the shared house standard
shared across these apps: senti, Stow and MarkPad all frost the same way, so the
setting stops being three answers to a question each app answered differently. Picking a vibrancy
material is a decision nobody wants to make twice.

- **The materials are pinned to the two the standard names** — `.popover` for the menu-bar panel,
  `.sidebar` for the main window. These are exactly what Translucent already used, so an install
  on that stage looks identical; only Clear changes appearance.
- **Frosted is what a fresh install lands on**, where 1.1–1.4 started Solid.
- **An existing setting is carried forward.** Both old blurred stages mean frosted; only an
  explicit Solid stays off. The stored preference no longer takes a default at read time, so
  "never set" is distinguishable from "set to Solid" — otherwise a fresh install and a
  deliberately-flat one were the same value.
- `FrostStyle.selfCheck()` covers the two states, both materials and every migration case.

`Frost.swift`, `Preferences.swift`, `GeneralSettingsView.swift`, `MainWindow.swift`,
`SelfChecks.swift`.

## [1.4] — 2026-07-26

### Fixed — translucency, properly this time

1.3 blurred the whole window and left an opaque bar across the top. Both were the same mistake:
blurring *inside* a transparent window instead of at the window level. The window is now built
the way Stow builds its own, so the two apps look like one family.

- **One `NSVisualEffectView` is the window's content view**, with the SwiftUI tree layered on top.
  AppKit expects the blur there, so the titlebar, corner rounding and shadow all stay correct.
- **`.fullSizeContentView`, transparent titlebar, hidden title.** Content runs under the titlebar
  instead of stopping at a solid strip; the traffic lights float over the sidebar, which pads its
  first row down to clear them.
- **Only the sidebar is frosted.** The content pane is always opaque — settings text has to stay
  readable over any wallpaper, and a window frosted edge to edge reads as several differently
  tinted slabs rather than one surface. Cards are solid again, since they now sit on an opaque
  pane rather than over a blur.
- **The search field is slightly see-through over frost**, so it reads as part of the sidebar
  rather than a solid chip floating on it.
- **Switching the setting restyles the open window**, rather than doing nothing visible until it
  is closed and reopened.

## [1.3] — 2026-07-26

### Fixed

- **Translucency was wrong on the main window.** Both surfaces used `.popover`, and the same
  material reads as far more opaque across an 820pt window than a 340pt panel — the result was a
  flat milky sheet with the frost only visible in the sidebar. The window now uses `.sidebar` and
  `.underWindowBackground`, the lighter ramp macOS itself uses at that size.
- **Cards punched solid white holes through the frost.** Every card, group and list now uses a
  scrim over frost instead of an opaque fill, so the wallpaper carries through the whole window.

### Changed

- **The sidebar has the app icon and name at the top**, and its four items are split into two
  groups — what senti does, then how senti behaves — with a divider between them.
- **About is a proper card.** It was a settings group whose rows had an empty control column,
  which read as switches nobody wired up. Now: icon, name, version, licence, and the two credits
  with their own licence chips.
- **Advanced flags are grouped into eight categories** — Video, Audio, Camera, Window and display,
  Keyboard mouse and control, Recording and capture, Device and connection, Other — with a count
  on each. 78 options in one alphabetical run were findable by search but not by browsing, which
  is how you learn what is there. Two land in Other, both genuinely miscellaneous.
- **Quick settings gained bitrate, resolution and borderless**, alongside audio, recording and
  always-on-top.
- **Defaults are now a real working configuration:** h265 at 4 Mbps, 720px, 120 fps, always on
  top, keep the phone unlocked, turn the phone's screen off, open at login, and no connect
  banners. Open-at-login registers with macOS on first launch rather than only claiming to.

## [1.2] — 2026-07-26

### Virtual display

Mirror can now open a **second Android display** instead of a copy of the phone's screen. The
phone stays usable while an app runs over here.

- **The choice lives in the panel**, as a Phone screen / New display switch above the quick
  settings. It changes session to session, and the Mirror button gives no other hint which of the
  two it is about to do.
- **Size and density** — width by height in pixels and a DPI, both optional. Left alone, the new
  display matches the phone's own. A half-typed size is marked in red and dropped rather than
  passed on, because scrcpy exits with a usage error on a malformed one.
- **Open an app on it** by package name, with a `?` prefix to match by app name instead, and an
  optional force-stop so it starts fresh rather than resuming.
- **Resize with the window**, **keep apps when it closes** (they move back to the phone's screen
  rather than being destroyed with the display), and **hide system decorations**.

The five scrcpy flags behind this are now managed by senti, so the Advanced pane no longer offers
them — it lists 78 options rather than 83. Offering both would let the same flag be sent twice.

Verified: the full generated command line — codec, bitrate, audio, window title, new display with
size and density, all three display flags and a force-stopped start-app — is accepted by scrcpy
4.0, which gets as far as looking for a device rather than rejecting an argument.

## [1.1] — 2026-07-26

Mirroring and input confirmed working on a real phone. This round is the polish pass plus four
things asked for after it.

### New

- **Advanced pane.** Every option the bundled scrcpy understands that senti does not already
  surface — 83 of them — read from its own `--help` at runtime rather than hard-coded, so the
  list cannot drift out of date with the binary. Search across names and descriptions, a Reset
  that clears the lot, and a count of what is switched on. Flags senti sets itself are excluded:
  sending one twice would silently override a setting from a pane the user cannot see.
- **Background: Solid, Translucent, Clear.** Three named stages rather than a slider, in
  General → Appearance. Applies to the panel and the main window together.
- **Quick settings in the panel.** Audio, recording and always-on-top, the three that change
  session to session, with a line saying they apply to the next Mirror.
- **Welcome tour can be shown again**, from General.

### Changed

- **Four panes, down from seven.** Recording joined Mirroring; the shortcut and appearance joined
  General; the toolchain repair buttons and About joined Help. Panes holding two rows each made
  the sidebar look busier than the app is.
- **The frame rate is no longer capped at 60.** It goes to 120, and resolution to 2160. Those
  numbers are the defaults, not limits — the row says plainly what higher costs.

### Fixed

- **Device history was written to disk on every poll** — twice a second while the panel was open,
  because `lastSeen` changed each time. A plain timestamp refresh is now held in memory and
  flushed at most once a minute; anything that actually changes is written immediately.
- **Reset all settings could not clear device history.** It removed the key while `DeviceStore`
  still held the entries in memory and wrote them straight back. History belongs to Forget All,
  which was already there, and Reset no longer claims to touch it.
- **A banner for every phone already plugged in at launch.** The first poll no longer notifies —
  the user did not connect anything, they opened the app. Auto-mirror still fires.
- **The panel did not grow when a phone appeared while it was open.** It measured itself from the
  Combine sink that published the change, before the new row had been laid out.
- **A failed session's error sat in the panel forever.** It clears when the panel is reopened.
- **Closing the tour hid the Dock icon while the settings window was still open.** Both windows
  now ask one shared check whether any window is left.
- **A recording session did not say so.** The row reads "Mirroring · recording".
- **`--new-display[=[<width>x<height>]]` parsed its name as `--new-display[`.** An optional-value
  flag would have built an argument scrcpy refuses. A flag that needs a value is also no longer
  stored until one is typed, so a half-finished row cannot reach the command line.

### Also

- `senti --list-flags` prints what the Advanced pane will show, so the parser's real output can be
  inspected rather than only the fixed sample the self-check uses.

## [1.0] — 2026-07-26

First release. senti rebuilt from scratch as a Swift package in Stow's design language.

### The app

- **Menu-bar panel.** One row per connected phone: glyph, name, plain-English status, and a
  Mirror button. Right-click the icon for Settings, Stop All and Quit.
- **Main window** with sidebar navigation and settings search: Mirroring, Recording, Toolchain,
  Shortcut, General, Help, About.
- **Mirroring settings.** Video codec, bitrate, frame rate, resolution; audio on/off with codec
  and bitrate; always-on-top, borderless, keep-awake, keep-unlocked, turn-the-phone's-screen-off,
  and a time limit.
- **Recording** to mp4 or mkv in a folder you choose, with the five most recent files listed and
  Show / Open buttons on each.
- **Device memory.** Phones are remembered with the name you give them, and recently-seen phones
  stay listed in the panel when unplugged.
- **Connect banners** with a Mirror button, so a session starts without opening the panel.
- **Auto-mirror**, per phone, off by default.
- **Global shortcut** to open the panel, recorded in Settings.
- **Three-page first-run tour**, shown once.
- **Self-checks** — `senti --self-check` runs them without launching the app.

### Deliberately not here

- **iOS.** The AVFoundation capture path is gone.
- **The in-app viewer.** scrcpy renders in its own window; senti does not decode video. That
  removes the H.264 decoder, the MKV parser, the frame tap, the audio player and the input
  forwarder along with it.
- **The engine abstraction.** With one engine, a protocol with one implementation is a layer that
  hides `Process` without replacing it.
- **Deferred, not refused:** the advanced scrcpy-flag panel, virtual displays, file transfer to
  and from the phone, and an in-app updater.

### Under the hood

- Swift package, not an Xcode project. `package-app.sh` assembles the bundle; `install.sh`
  installs it, with `--fresh` to wipe all state first.
- `Theme.swift` is the single source of visual truth, ported from Stow: OKLCH accent, hex grey
  ramp, roomy spacing, 6/8/10 radii, 120–160ms motion.
- Bundled scrcpy 4.0 + adb, unpacked to `~/Library/Application Support/senti/` on first launch
  and quarantine-cleared so macOS does not block a binary the user has never heard of.
- All 16 scrcpy flags senti emits were checked against the bundled binary's `--help`.
- Bundle ID `com.local.senti`, preferences prefixed `senti.`, ad-hoc signed, `LSUIElement`.
