# senti — bugs and platform constraints

Bugs by root cause, plus the platform behaviours that look like bugs and are not. Read this
before assuming something is broken.

## Platform constraints — not bugs

**B1 — `iconutil` rejects iconsets on this machine.** It began refusing every iconset, including
ones it had itself produced. `Tools/make-icns.swift` writes the `.icns` directly through ImageIO
instead, and the build no longer depends on `iconutil`.

**B2 — Ad-hoc signing invalidates permissions on every build.** The signature changes each time,
so macOS treats each build as a different app and any granted permission silently stops matching.
`install.sh --fresh` makes that fail obviously rather than quietly.

**B3 — A second adb owns port 5037.** Android Studio or a Homebrew adb will hold the port, and
senti's phone list comes back empty while the phone is plainly plugged in. Settings → Toolchain →
Restart adb fixes it. `ScrcpyService` sets `ADB` and `SCRCPY_SERVER_PATH` in the child
environment so scrcpy always uses senti's copy, never whatever is on `PATH`.

**B4 — A Finder-launched app has no shell `PATH`.** Every tool is invoked by absolute path.
`Shell.run` refuses a path that is not an executable file rather than inheriting one.

**B5 — adb has no attach notification.** Polling is the design, not a shortcut. The poll runs at
1.5s while the panel is open and 5s when it is not, always off the main thread.

**B6 — A borderless `NSPanel` cannot become key by default.** Without the `canBecomeKey`
override, the panel receives no keyboard events and no control inside it can take focus — the
rename field would be silently dead. `MenuBarPanel.selfCheck` asserts it.

**B7 — `NSHostingView` refuses the first mouse.** The click that makes the panel key is otherwise
swallowed instead of reaching the control under the pointer, so every button needs clicking
twice. `FirstMouseHostingView` overrides it.

**B8 — `NSColor(Color)` renders black from AppKit code.** It resolves against the current SwiftUI
environment, which plain AppKit does not have. `Theme` builds every `NSColor` directly and never
bridges one.

**B9 — `behindWindow` blur needs a non-opaque window.** A frosted `NSVisualEffectView` reaches the
desktop only through a window with `isOpaque = false` and a clear background colour. The main
window sets both unconditionally; with frost off, `SurfaceFill` paints the opaque colour instead.

**B10 — An accessory app has to manage its own Dock icon.** Each window controller dropping the
policy back to `.accessory` in its own `windowWillClose` took the icon away from a window that was
still open. `ActivationPolicy.refresh` asks once, a run loop pass later, whether any titled window
is left.

**B11 — One vibrancy material does not fit two sizes.** `.popover` across an 820pt window is a
flat milky sheet; across a 340pt panel it is correct. `FrostStyle` carries a separate ramp for
each — panel `.popover`/`.underWindowBackground`, window `.sidebar`/`.underWindowBackground`.

**B12 — Blur at the window level, not inside a transparent window.** Setting `isOpaque = false`
with a clear background and painting an effect view inside the SwiftUI tree produced two visible
faults at once: an opaque bar across the titlebar, because the titlebar is not part of the
content view, and a window frosted edge to edge. The fix is what AppKit expects — an
`NSVisualEffectView` *as* the window's content view, `.fullSizeContentView` in the style mask, a
transparent titlebar, and only the sidebar left unpainted so the backdrop shows through there.
Everything else paints an opaque fill over it.

**B13 — A full-size content view puts the traffic lights on top of your first row.** The sidebar
pads its top by 30pt so its wordmark starts below them.

## Rules learned

- **A `ViewThatFits` settings row needs a minimum width on its text column.** Without the floor
  the horizontal layout always "fits" — SwiftUI crushes the label to a few points and wraps it one
  character per line rather than reporting that it did not fit, so the stacked fallback is never
  chosen. `SettingsRow` sets 190pt.
- **`--no-audio` and `--audio-codec` together make scrcpy exit with a usage error.** The argument
  builder emits one or the other, never both. `ScrcpyService.selfCheck` asserts it.
- **Pass paths to `Process` unquoted.** argv goes straight through; shell quoting would become
  part of the filename.
- **Terminate scrcpy with SIGTERM, not SIGKILL.** Killed outright it cannot restore the phone's
  screen after a `--turn-screen-off` session.
- **Assigning an identical array still fires `objectWillChange`.** The device poll compares before
  assigning, or the panel redraws every 1.5 seconds and interrupts a rename in progress.
- **Nested helpers in an `init` capture `self`.** Reading a property before every stored property
  is initialised does not compile; take a local reference instead.
- **`--time-limit` is in seconds.** The setting is in minutes and multiplies by 60.
- **`UNUserNotificationCenter.current()` traps without a bundle identifier.** Every call site
  checks, so `swift run` from a terminal does not crash on launch.
- **A self-check whose subject is filtered out passes for the wrong reason.** The parser test
  used `--new-display` as its optional-value example; adding that flag to `managed` made `parse`
  drop it, and the assertion failed on nil rather than on a bad name. It uses an invented name now.
- **`scrcpy <args>` with no device tells you whether the arguments are valid.** A usage error is
  rejected before device discovery, so reaching "Could not find any ADB device" means the whole
  command line parsed. That is how the virtual-display arguments were checked without a phone.
- **Parse a help text against the real help text.** The fixed sample in `ScrcpyFlags.selfCheck`
  passed while `--new-display[=[<w>x<h>]]` was parsing its name as `--new-display[`, because the
  sample had no optional-value flag in it. `senti --list-flags` exists so the real output can be
  looked at.
- **A flag that needs a value must not be stored until it has one.** `--angle` alone makes scrcpy
  exit with a usage error, so the Advanced pane keeps an unfinished row in view state and only
  persists it once something is typed.
- **A setting that changes on every poll must not be persisted on every poll.** Device history
  refreshes `lastSeen` twice a second while the panel is open; writing that through meant a
  UserDefaults write at the same rate.
- **Clearing a UserDefaults key does not clear the object holding it.** `Preferences.resetAll`
  removed the device-history key while `DeviceStore` still had the entries in memory and rewrote
  them on the next poll. Whoever owns the data owns clearing it.
- **Measure a SwiftUI hosting view a pass after the change, not during it.** Resizing the panel
  from the Combine sink that published a new device measured the layout before the row existed.

## Open

Nothing verified broken yet. v1.0 has not had a phone plugged into it — the mirroring path is
built and its command line is asserted, but no live session has been observed.
