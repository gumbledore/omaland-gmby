<div align="center">

<img src="icon.png" alt="" width="120">

# Omaland Themepark

**Pick a look for your Hyprland windows.**

An Omarchy shell plugin. Six curated presets in a carousel, each drawn over
your own wallpaper in your theme's colors. Arrow to preview on the real
desktop, Enter to apply. The full option editor is one Tab away.

<img src="https://img.shields.io/badge/Omarchy-4.x-a855f7?style=flat-square" alt="Omarchy 4.x">
<img src="https://img.shields.io/badge/Hyprland-%E2%89%A5%200.56-22d3ee?style=flat-square" alt="Hyprland 0.56+">
<img src="https://img.shields.io/badge/license-MIT-64748b?style=flat-square" alt="MIT">

<br><br>

<img src="preview.png" alt="The Omaland Themepark picker, a row of six preset cards with the focused one enlarged" width="820">

</div>

## Install

```bash
omarchy plugin add https://github.com/gumbledore/omaland-gmby.git --enable --yes
```

Open it from **SUPER+SPACE › Omaland Themepark**. No network access, no sudo.

To remove it, `omarchy plugin remove gumbledore.omaland-themepark --yes`. Your
settings stay — they are plain Lua in the files Hyprland already reads. Apply
the **Omarchy** preset first to undo them too.

## The presets

| | Layout | Character |
|---|---|---|
| **Omarchy** | stock | Nothing overridden. Always a way back. |
| **Tight** | scrolling | No gaps, no rounding, thin border, no blur or shadow. |
| **Airy** | dwindle | Big gaps, soft corners, a gentle shadow, light dim on inactive. |
| **Glass** | dwindle | Strong blur under translucent windows, glow on focus. |
| **Focus** | dwindle | Thick border and full opacity on the active window; the rest dim and fade. |
| **Snappy** | scrolling | Near stock, animations twice as fast, no dimming. |

Applying a preset clears every override in both managed files and writes the
preset's own, so a preset is a complete known state. A preset that names a
layout also removes the per-workspace pins left by Omarchy's workspace layout
toggle (`~/.local/state/omarchy/workspace-layouts/`), which load after
`looknfeel.lua` and would otherwise win over the preset's layout. The card matching what is
on disk carries a dot; hand-tuned settings match no card, and the footer says
so. Browsing never touches your files: Escape puts the desktop back exactly.

Colors are never set. Omarchy themes own `general:col:*` from a file that
loads before `looknfeel.lua`, so writing them here would pin your borders and
break `omarchy theme set`.

## Keys

**Picker**

| | |
|---|---|
| `←` `→` / `h` `l` | move between cards, previewing live |
| `1` – `6` | jump to a card |
| `Enter` `Space` | apply the focused card and close |
| `Tab` | open the option editor |
| `Esc` | put everything back and close |

The tiling layout is not previewed while you browse, so your windows stay put.
It changes on apply.

**Editor**

| | |
|---|---|
| `↑` `↓` / `k` `j` | move between rows |
| `←` `→` / `h` `l` | adjust the current row |
| `Tab` / `Shift+Tab` | next / previous section; `Shift+Tab` from the first section returns to the picker |
| `Space` `Enter` | toggle |
| `Backspace` | reset the row to the Omarchy default |
| `Esc` | close |

The editor opens on what is on disk, never on the card you were previewing.

## What the editor edits

| Section | Options |
|---|---|
| **Windows** | gaps in/out/workspaces/floating, border width, border inside window, snapping |
| **Layout** | tiling engine, plus the active engine's own knobs (`dwindle:*`, `master:*`, `scrolling:*`) |
| **Corners** | rounding, roundness curve |
| **Opacity** | full opacity, focused, unfocused, fullscreen |
| **Dimming** | dim unfocused, strength, special workspace, dim around, dim behind modals |
| **Blur** | enabled, size, passes, noise, contrast, brightness, vibrancy, x-ray, special, popups |
| **Shadow** | enabled, range, falloff, scale, sharp |
| **Glow** | enabled, range, falloff |
| **Animations** | enabled, wrap workspaces, speed multiplier |
| **Groups** | group bar height, font size, titles, indicator, rounding, gradients, stacked |

## How it works

**Where it writes.** One fenced block per file — `hl.config` and `hl.animation`
in `looknfeel.lua`, `o.window` rules in `hyprland.lua`. Nothing outside the
fences is touched, and clearing every override removes the blocks and restores
both files exactly. The block format is unchanged from Omaland 1.x, so existing
blocks load as they are.

**Reading state back** is done by Lua, not by a parser. `read.lua` runs the
block against recording stubs for `hl` and `o` and reports what it set, so the
block stays pure Lua with no state comments, and a hand-edit that breaks the
syntax gets a real error instead of being silently misread. Needs `lua`, which
`hyprland` already depends on.

**Which preset is active** is derived, not recorded: the on-disk overrides are
compared to each preset's map, and only an exact match highlights a card.

**Live preview** uses `hyprctl eval` (Hyprland's Lua parser rejects `hyprctl
keyword`), handed the same Lua that gets written on apply, so preview and
saved state can't drift. Moving between cards previews the on-disk value for
anything the new card leaves alone, and Escape reloads the config so the
in-memory preview is dropped. `hyprctl configerrors` runs after every write
and surfaces in the footer.

**The cards** are drawn, not screenshotted. `PresetCard.qml` paints a mock
desktop from a preset's overrides over the current wallpaper, read from
`~/.local/state/omarchy/current/background`, in the shell's theme colors.

**The launcher entry** is installed by the plugin, because Omarchy has no
install hook. Enabling writes
`~/.local/share/applications/omaland-themepark.desktop`; disabling or removing
deletes it. Only a file carrying `X-Omaland-Themepark-Managed=true` is ever
touched, so your own entry at that path is left alone.

**Full opacity** clears the `opacity = "0.985 0.96"` rule Omarchy applies to
every window. That rule multiplies with the opacity sliders, so without the
switch 100% still renders at 0.985.

<details>
<summary>Reaching it from the Omarchy menu as well</summary>

Add this to `~/.config/omarchy/extensions/omarchy-menu.jsonc` to turn
**Style › Hyprland** into a submenu. Redeclaring the id with no `action` flips
it to a submenu, and the original editor action moves into a child:

```jsonc
"style.hyprland": {"icon":"","label":"Hyprland","aliases":["hyprland","looknfeel"]},
"style.hyprland.themepark": {"icon":"󰸌","label":"Themepark","aliases":["omaland","themepark"],"action":"omarchy-shell shell toggle gumbledore.omaland-themepark"},
"style.hyprland.edit": {"icon":"","label":"Edit Config","action":"omarchy-launch-config-editor \"$HOME/.config/hypr/looknfeel.lua\""},
```

</details>

## Development

```
manifest.json        plugin declaration (kinds: panel, service)
Panel.qml            state, hyprctl processes, file IO, the two views
PresetCarousel.qml   the row of cards: focus, keys, signals (pure QtQuick)
PresetCard.qml       one card: a mock desktop drawn from a preset (pure QtQuick)
Presets.js           the six presets and matching()
OptionRow.qml        one editor row
Schema.js            the option catalogue
LuaConfig.js         render the managed blocks, read read.lua's output
read.lua             runs a block against recording stubs to report what it set
Service.qml          installs and removes the launcher entry
test/run.js          node test/run.js  (JS suite, then test/qml under qmltestrunner)
```

Adding a preset is one entry in `Presets.js`; the suite checks it against the
schema and round-trips it through Lua. Adding an option is one entry in
`Schema.js`. Plugin QML is cached by URL, so edits need `omarchy restart shell`.

## License

MIT
