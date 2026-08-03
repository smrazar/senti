# senti — Design Language

The rules for how senti looks. `Sources/Senti/Theme.swift` holds the values and is the single
source of truth; this file holds the rules for composing them. Every visual choice maps to a
token — no magic numbers in views, no off-palette colours.

Shared with Stow, deliberately: the two apps should read as one family.

## The direction in one line

Crisp, flat, minimal. A quiet grey utility with a single pastel-cyan pop, roomy spacing, slightly
rounded corners, subtle and quick motion, system SF type, full light and dark.

## Colour

- **Monochrome plus one pop.** The entire UI is greyscale except the pastel-cyan accent. No other
  hue. If something needs emphasis, use the accent or type weight — never a new colour.
- **The accent is rationed.** Solid accent fill is reserved for primary buttons, the toggle "on"
  state, input focus, the selected sidebar row's icon, and the live-session dot. A selected row
  gets `accentSoft` (a 14–18% tint), never a solid fill.
- **On-accent text** is a dark cyan-tinted ink, not white — the pastel accent is too light for
  white text to stay legible.
- **Depth from hairlines first, shadow second.** Every panel and card gets a 1px border. Shadow
  is only for floating surfaces — the menu-bar panel — never inline cards. That holds whether the
  background is solid or frosted.
- **The background is the user's choice, in three named stages** — Solid, Translucent, Clear.
  Not a slider: a slider can be dragged to unreadable, and the two blurred stages differ only in
  how much passes through. One `NSVisualEffectView` material per stage, nothing in between.
- **Frost is a window-level surface, and only the sidebar shows it.** The blur is an
  `NSVisualEffectView` used *as* the window's content view, with `.fullSizeContentView` so it runs
  under a transparent titlebar. The sidebar paints nothing and lets it through; the content pane
  paints an opaque fill over it, because settings text has to stay readable over any wallpaper.
  Never stack a second effect view inside — blurs on blurs cost frames and muddy the result.
  This is Stow's arrangement, copied deliberately: the two apps should look like one family.
- **The one exception:** red, and only for a destructive confirmation ("Forget All", "Reset").
  Ordinary error text stays in the grey ramp with an icon.

To re-point the accent later, change the four OKLCH triples in `Theme.NS` and nothing else.

## Light and dark

Full support, following the system. Dark is a straight token swap — identical layout, spacing,
radii and structure. Never restructure a component between modes.

## Density — roomy

Panels pad 28, cards 20, rows 14 vertical / 16 horizontal, 16 between controls, 32 between
sections, 12 between items. When unsure, add air. The menu-bar panel runs a touch tighter than
the main window but still errs roomy.

## Iconography

SF Symbols throughout, used generously — every button, row, tab and empty state carries one.
Names live in `Symbols.swift`, because a typo'd symbol renders as nothing at all.

- Weight regular; medium only for an active or emphasised icon.
- Monochrome by default, inheriting the text colour. Accent tint only for the active state — an
  icon does not turn cyan just for existing.
- Sizes: inline 13, row 15, toolbar 16, empty state 28, menu bar 16. Never freehand.
- State changes swap with `.contentTransition(.symbolEffect(.replace))`.
- The menu-bar glyph stays a template image so macOS inverts it for a light or dark bar. It
  changes with state — plain phone idle, radio-waves phone live — never by colour.

## Shape

Radius 6 for controls, rows and inputs; 8 for cards; 10 for the floating panel; full pill for
toggles. No arbitrary radii, nothing soft or bubbly.

## Type

SF Pro for text, SF Mono for numbers, versions and keyboard shortcuts. Use the named styles —
display / title / headline / body / bodyEmph / caption / mono. Hierarchy comes from weight and
the grey text ramp, not colour.

## Motion

Fast, understated, ease-out, 120–160ms. Panel open: fade plus 6px rise over 160ms; close is the
inverse over 110ms. Pane switch and toggle: 140ms. Icon press: scale to 0.92, springs back.
No bouncy springs, no attention-grabbing animation. Every `.animation(_:value:)` is value-scoped,
so nothing animates on unrelated state changes.

## Components

- **Buttons.** Primary = accent fill + on-accent text. Secondary = transparent + hairline border.
  Destructive secondary is the same shape in red.
- **Toggles.** 38×22 track, 18px knob, accent when on, `borderStrong` when off.
- **List rows.** Hover = `surfaceHover`; selected = `accentSoft`. Never a full accent fill.
- **Settings rows.** Label + one-line grey description + trailing control, inside a titled
  hairline card. Wrapped in `ViewThatFits` with a stacked fallback **and a 190pt floor on the
  text column** — without that floor the horizontal layout always "fits" by crushing the label to
  one character per line, and the fallback is never chosen.
- **Keycap chips** for shortcuts: small `surfaceSecondary` rounded rect, hairline border, SF Mono.
- **Settings = left-sidebar nav** with a search field, grouped sections, selected row tinted
  `accentSoft` with an accent icon.
- **Four panes, not seven.** A pane holding two rows makes the app look like it has more settings
  than it does. A subject that small is a group inside a pane.

## Anti-patterns

No second accent colour. No gradients. No frosted panels. No shadows on inline cards. No
full-accent rows or tabs. No arbitrary radii or off-scale spacing. No bundled fonts. No springy
animation. No colour-as-hierarchy where weight and the grey ramp would do.
