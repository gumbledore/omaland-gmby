.pragma library

// The six curated looks the picker offers. A preset is a partial override map
// in the editor's own key space, so applying one is exactly "clear everything,
// then set these". Omarchy is the empty map, the same thing as Reset all.
//
// Colors are never set: Omarchy themes own general:col:*. Values must already
// be quantized for their schema item; test/run.js checks that.

var LAYOUT_KEY = "general:layout"

var PRESETS = [
  {
    id: "omarchy",
    name: "Omarchy",
    description: "Stock defaults. Nothing overridden.",
    overrides: {}
  },
  {
    id: "tight",
    name: "Tight",
    description: "No gaps, no rounding, scrolling columns. Every pixel works.",
    overrides: {
      "general:layout": "scrolling",
      "general:gaps_in": 0,
      "general:gaps_out": 0,
      "general:border_size": 1,
      "decoration:rounding": 0,
      "decoration:blur:enabled": false,
      "decoration:shadow:enabled": false
    }
  },
  {
    id: "airy",
    name: "Airy",
    description: "Big gaps, soft corners and a gentle shadow. Room to breathe.",
    overrides: {
      "general:layout": "dwindle",
      "general:gaps_in": 12,
      "general:gaps_out": 28,
      "general:border_size": 2,
      "decoration:rounding": 16,
      "decoration:shadow:enabled": true,
      "decoration:shadow:range": 30,
      "decoration:shadow:render_power": 3,
      "decoration:dim_inactive": true,
      "decoration:dim_strength": 0.1
    }
  },
  {
    id: "glass",
    name: "Glass",
    description: "Strong blur under translucent windows, with a soft glow on focus.",
    overrides: {
      "general:layout": "dwindle",
      "general:gaps_in": 0,
      "general:gaps_out": 0,
      "general:border_size": 1,
      "decoration:rounding": 10,
      "decoration:active_opacity": 0.92,
      "decoration:inactive_opacity": 0.78,
      "decoration:blur:enabled": true,
      "decoration:blur:size": 10,
      "decoration:blur:passes": 3,
      "decoration:blur:vibrancy": 0.3,
      "decoration:glow:enabled": true,
      "decoration:glow:range": 10,
      "decoration:glow:render_power": 3
    }
  },
  {
    id: "focus",
    name: "Focus",
    description: "The active window stands out. Everything else dims and fades.",
    overrides: {
      "general:layout": "dwindle",
      "general:border_size": 4,
      "omaland:opaque_windows": true,
      "decoration:active_opacity": 1,
      "decoration:inactive_opacity": 0.7,
      "decoration:dim_inactive": true,
      "decoration:dim_strength": 0.4
    }
  },
  {
    id: "snappy",
    name: "Snappy",
    description: "Stock look on scrolling columns, animations twice as fast, no dimming.",
    overrides: {
      "general:layout": "scrolling",
      "general:gaps_in": 4,
      "general:gaps_out": 12,
      "decoration:dim_inactive": false,
      "omaland:animation_speed": 2
    }
  }
]

function sameMap(a, b) {
  var ka = Object.keys(a), kb = Object.keys(b)
  if (ka.length !== kb.length) return false
  for (var i = 0; i < ka.length; i++)
    if (b[ka[i]] === undefined || b[ka[i]] !== a[ka[i]]) return false
  return true
}

// The preset whose overrides equal the given map exactly, or null. Highlighting
// derives from this; nothing on disk records which preset was applied.
function matching(overrides) {
  if (!overrides || typeof overrides !== "object") return null
  for (var i = 0; i < PRESETS.length; i++)
    if (sameMap(PRESETS[i].overrides, overrides)) return PRESETS[i]
  return null
}

// What a card previews while it is merely focused: everything but the layout,
// which would rearrange the windows on every keypress.
function previewOverrides(overrides) {
  var out = {}
  for (var k in overrides)
    if (k !== LAYOUT_KEY) out[k] = overrides[k]
  return out
}
