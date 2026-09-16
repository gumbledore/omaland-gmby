// Tests for the library files and the pure-QtQuick components. QML's
// `.pragma library` header is stripped so node can evaluate the JS; the QML
// cases in test/qml run under qmltestrunner (shipped with Qt 6 on Omarchy)
// and are skipped with a message when that binary is absent.
//
//   node test/run.js

const fs = require("fs")
const path = require("path")
const { execFileSync, spawnSync } = require("child_process")

const root = path.join(__dirname, "..")

function load(file, exports) {
  const src = fs.readFileSync(path.join(root, file), "utf8").replace(".pragma library", "")
  const module = {}
  new Function("__exports", src + "\n;Object.assign(__exports, {" + exports.join(",") + "});")(module)
  return module
}

const Schema = load("Schema.js", [
  "SECTIONS", "ANIMATION_SPEED_KEY", "OPAQUE_WINDOWS_KEY", "allItems", "itemFor", "queryKeys", "quantize"
])
const Lua = load("LuaConfig.js", [
  "renderBlock", "renderConfigBody", "renderWindowsBody", "renderPreview",
  "parseHarness", "animationSpeedFrom", "applyBlock", "splitBlock"
])
const Presets = load("Presets.js", ["PRESETS", "matching", "previewOverrides"])

let failures = 0
function check(name, condition, detail) {
  if (condition) {
    console.log("  ok   " + name)
  } else {
    failures++
    console.log("  FAIL " + name + (detail === undefined ? "" : "  → " + detail))
  }
}
// Key order is not part of the contract — the managed block groups keys the way
// a person would write them, not the order they were set — so compare plain
// objects by sorted key.
function stable(value) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return JSON.stringify(value)
  return JSON.stringify(Object.keys(value).sort().map(function(k) { return [k, value[k]] }))
}
function eq(name, actual, expected) {
  check(name, stable(actual) === stable(expected),
        "got " + JSON.stringify(actual) + ", want " + JSON.stringify(expected))
}

// Exercises read.lua for real rather than mocking it — it is the parser now.
function readSource(source) {
  return Lua.parseHarness(
    execFileSync("lua", [path.join(root, "read.lua"), "-e", source],
                 { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }))
}
function readFile(file) {
  return Lua.parseHarness(
    execFileSync("lua", [path.join(root, "read.lua"), file],
                 { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }))
}
function readBlock(text) {
  return readSource(Lua.splitBlock(text).body)
}

const OMARCHY = process.env.OMARCHY_PATH || "/usr/share/omarchy"
const defaultsPath = OMARCHY + "/default/hypr/looknfeel.lua"
const baseline = fs.existsSync(defaultsPath) ? readFile(defaultsPath).animations : []

console.log("\nSchema")

// Regression: the numeric guard used to run before the type dispatch, so
// Number("dwindle") → NaN → 0. Hyprland then accepted a layout literally named
// "0" without reporting a config error, silently breaking tiling.
const layout = Schema.itemFor("general:layout")
eq("enum keeps its name", Schema.quantize(layout, "dwindle"), "dwindle")
eq("enum never degrades to a number", Schema.quantize(layout, "scrolling"), "scrolling")

const rounding = Schema.itemFor("decoration:rounding")
eq("int rounds", Schema.quantize(rounding, 11.6), 12)

const noise = Schema.itemFor("decoration:blur:noise")
eq("float honours decimals", Schema.quantize(noise, 0.0123456), 0.012)
eq("float drops binary dust", Schema.quantize(Schema.itemFor("decoration:blur:vibrancy"), 0.7300000000000001), 0.73)

const dim = Schema.itemFor("decoration:dim_inactive")
eq("bool stays strict", Schema.quantize(dim, "yes"), false)
eq("bool true", Schema.quantize(dim, true), true)

check("every item has a unique key", (function() {
  const seen = {}
  return Schema.allItems().every(function(i) {
    if (seen[i.key]) return false
    seen[i.key] = true
    return true
  })
})())

// A plain `needs` dims the row and must name a bool; `needs` + `needsValue`
// hides it and must name an enum that actually offers that value.
check("every plain `needs` points at a real bool", Schema.allItems().every(function(i) {
  if (!i.needs || i.needsValue !== undefined) return true
  const dep = Schema.itemFor(i.needs)
  return dep && dep.type === "bool"
}))
check("every `needsValue` names a real option of a real enum", Schema.allItems().every(function(i) {
  if (i.needsValue === undefined) return true
  const dep = Schema.itemFor(i.needs)
  if (!dep || dep.type !== "enum") return false
  return (dep.options || []).some(function(o) { return String(o.value) === String(i.needsValue) })
}))

const forceSplit = Schema.itemFor("dwindle:force_split")
eq("numeric enum stays a number", Schema.quantize(forceSplit, "2"), 2)
check("numeric enum renders unquoted",
      Lua.renderConfigBody({ "dwindle:force_split": 2 }, baseline).indexOf("force_split = 2,") !== -1)
eq("numeric enum round trips",
   readBlock(Lua.applyBlock("", Lua.renderConfigBody({ "dwindle:force_split": 0 }, baseline))).overrides["dwindle:force_split"], 0)
check("string enums still quote",
      Lua.renderConfigBody({ "master:orientation": "top" }, baseline).indexOf('orientation = "top"') !== -1)

// hyprctl is asked only about real options; synthetics are backed by emitted
// Lua and must stay out of the getoption batch.
eq("synthetic keys are excluded from the hyprctl batch",
   Schema.allItems().filter(function(i) { return i.synthetic }).map(function(i) { return i.key }).sort(),
   ["omaland:animation_speed", "omaland:opaque_windows"])
check("every non-synthetic key is queried",
      Schema.queryKeys().every(function(k) { return k.indexOf("omaland:") !== 0 }))
eq("queryKeys covers exactly the real options",
   Schema.queryKeys().length, Schema.allItems().length - 2)

// Hyprland spells colors as a `col` path segment (general:col:active_border,
// group:groupbar:col:active) or a segment containing "color"
// (decoration:shadow:color, group:groupbar:text_color). Matched per segment so
// scrolling:column_width isn't a false positive.
check("no color options are exposed", Schema.allItems().every(function(i) {
  return i.key.split(":").every(function(seg) {
    return seg !== "col" && seg.indexOf("color") === -1
  })
}))

console.log("\nLua rendering")

const overrides = {
  "general:gaps_in": 8,
  "general:border_size": 3,
  "general:layout": "scrolling",
  "decoration:rounding": 12,
  "decoration:blur:enabled": true,
  "decoration:blur:size": 6,
  "decoration:blur:noise": 0.015,
  "decoration:shadow:sharp": false
}

const body = Lua.renderConfigBody(overrides, baseline)
check("enum renders as a quoted Lua string", body.indexOf('layout = "scrolling"') !== -1, body)
check("booleans render bare", body.indexOf("enabled = true") !== -1)
check("nested tables nest", /blur = \{[\s\S]*size = 6/.test(body))

eq("empty override set renders nothing", Lua.renderConfigBody({}, baseline), "")

const opaque = Lua.renderWindowsBody({ "omaland:opaque_windows": true })
check("opaque toggle uses Omarchy's o.window helper",
      /o\.window\("\.\*", \{ opacity = "1 1" \}\)/.test(opaque), opaque)
check("opaque rule is detected by the harness", readSource(opaque).opaque === true)
check("a plain config block is not read as opaque", readSource("hl.config({ general = { gaps_in = 1 } })").opaque === false)
eq("opaque toggle off emits nothing", Lua.renderWindowsBody({ "omaland:opaque_windows": false }), "")
eq("window rules stay out of the looknfeel body",
   Lua.renderConfigBody({ "omaland:opaque_windows": true }, baseline), "")
eq("config settings stay out of the hyprland body",
   Lua.renderWindowsBody({ "decoration:rounding": 12 }), "")
check("preview carries both bodies", (function() {
  const both = Lua.renderPreview({ "decoration:rounding": 12, "omaland:opaque_windows": true }, baseline)
  return both.indexOf("rounding = 12") !== -1 && both.indexOf("o.window") !== -1
})())

console.log("\nManaged block round trip")

const userFile = [
  "-- my own config",
  "hl.config({ general = { resize_on_border = true } })",
  ""
].join("\n")

const configBody = Lua.renderConfigBody(overrides, baseline)
const withBlock = Lua.applyBlock(userFile, configBody)
check("user content is preserved verbatim", withBlock.indexOf(userFile.trim()) === 0)
eq("round trip is exact", readBlock(withBlock).overrides, overrides)
eq("re-rendering is idempotent",
   Lua.applyBlock(withBlock, Lua.renderConfigBody(readBlock(withBlock).overrides, baseline)), withBlock)
eq("clearing every override restores the original file", Lua.applyBlock(withBlock, ""), userFile)

// A block that was hand-edited between sessions has to survive being read back.
const handEdited = withBlock.replace("gaps_in = 8,", "gaps_in = 21, -- bumped by hand")
eq("hand edits are read back", readBlock(handEdited).overrides["general:gaps_in"], 21)

// The old regex reader silently accepted a table with a missing separator.
// Real Lua does not, which is the point of handing parsing to Lua.
check("a hand edit that breaks the table is reported, not guessed at", (function() {
  try { readBlock(withBlock.replace("gaps_in = 8,", "gaps_in = 21 -- ate the comma")); return false }
  catch (e) { return String(e.stderr || "").indexOf("expected") !== -1 }
})())

console.log("\nAnimation baseline")

if (baseline.length === 0) {
  console.log("  skip (no " + defaultsPath + " on this machine)")
} else {
  check("baseline parsed", baseline.length >= 10, baseline.length + " leaves")
  const windows = baseline.filter(function(l) { return l.leaf === "windows" })[0]
  check("a known leaf carries speed + curve", windows && windows.speed > 0 && windows.bezier !== "")

  const styled = baseline.filter(function(l) { return l.style })[0]
  check("styles survive parsing", !!styled, JSON.stringify(styled))

  const doubled = Lua.renderConfigBody({ "omaland:animation_speed": 2 }, baseline)
  const halved = new RegExp("leaf = \"windows\", enabled = true, speed = "
    + String(Math.round((windows.speed / 2) * 100) / 100).replace(".", "\\."))
  check("multiplier halves the duration", halved.test(doubled), doubled.split("\n")[2])
  eq("multiplier is measured back off the block, with no marker",
     Lua.animationSpeedFrom(readSource(doubled).animations, baseline), 2)
  eq("an unscaled block measures as 1.0",
     Lua.animationSpeedFrom(readSource(Lua.renderConfigBody({ "omaland:animation_speed": 1 }, baseline)).animations, baseline), 1)
  check("nothing but Lua is written — no omaland markers",
     doubled.indexOf("omaland:") === -1, doubled.split("\n")[0])

  // Scaling must always start from the shipped set, never from a previous
  // result, or repeated adjustments would compound.
  const once = Lua.renderConfigBody({ "omaland:animation_speed": 1.5 }, baseline)
  const twice = Lua.renderConfigBody({ "omaland:animation_speed": 1.5 }, baseline)
  eq("multiplier does not compound", once, twice)

  check("disabled leaves emit no speed",
        /leaf = "workspaces", enabled = false \}/.test(doubled))
  check("styles survive the render/read round trip", (function() {
    const back = readSource(doubled).animations.filter(function(a) { return a.leaf === "windowsIn" })[0]
    return back && back.style === "popin 87%" && back.bezier === "easeOutQuint"
  })())
  check("read.lua rejects broken Lua loudly", (function() {
    try { readSource("hl.config({ this is not lua"); return false } catch (e) { return true }
  })())
}

console.log("\nPresets")

const presets = Presets.PRESETS
eq("exactly six presets", presets.length, 6)
eq("ids are unique", new Set(presets.map(function(p) { return p.id })).size, presets.length)
eq("Omarchy comes first", presets[0].id, "omarchy")
eq("Omarchy is the empty map", presets[0].overrides, {})
check("every preset has a name and description", presets.every(function(p) {
  return typeof p.name === "string" && p.name !== "" && typeof p.description === "string" && p.description !== ""
}))

check("every override key names a schema item and is already quantized", presets.every(function(p) {
  return Object.keys(p.overrides).every(function(k) {
    const item = Schema.itemFor(k)
    return item && Schema.quantize(item, p.overrides[k]) === p.overrides[k]
  })
}), presets.map(function(p) {
  return p.id + ": " + Object.keys(p.overrides).filter(function(k) {
    const item = Schema.itemFor(k)
    return !item || Schema.quantize(item, p.overrides[k]) !== p.overrides[k]
  }).join(",")
}).join(" "))

check("no preset sets a color", presets.every(function(p) {
  return Object.keys(p.overrides).every(function(k) {
    return k.split(":").every(function(seg) { return seg !== "col" && seg.indexOf("color") === -1 })
  })
}))

check("presets are pairwise distinct", presets.every(function(a, i) {
  return presets.every(function(b, j) { return i === j || stable(a.overrides) !== stable(b.overrides) })
}))

presets.forEach(function(p) {
  const config = readBlock(Lua.applyBlock("", Lua.renderConfigBody(p.overrides, baseline)))
  const back = config.overrides
  if (baseline.length > 0) {
    const speed = Lua.animationSpeedFrom(config.animations, baseline)
    if (speed !== undefined) back[Schema.ANIMATION_SPEED_KEY] = speed
  }
  const windows = Lua.renderWindowsBody(p.overrides)
  if (windows && readSource(windows).opaque) back[Schema.OPAQUE_WINDOWS_KEY] = true
  const expected = {}
  for (const k in p.overrides) {
    if (k === Schema.ANIMATION_SPEED_KEY && baseline.length === 0) continue
    expected[k] = p.overrides[k]
  }
  eq(p.id + " round-trips through Lua", back, expected)
})

presets.forEach(function(p) {
  check("matching() finds " + p.id + " from its own overrides",
        Presets.matching(p.overrides) === p)
})
check("matching() finds a copy, not just the same object", Presets.matching(JSON.parse(JSON.stringify(presets[1].overrides))) === presets[1])
check("matching() rejects a tweaked copy", presets.slice(1).every(function(p) {
  const tweaked = JSON.parse(JSON.stringify(p.overrides))
  const k = Object.keys(tweaked)[0]
  tweaked[k] = typeof tweaked[k] === "boolean" ? !tweaked[k] : typeof tweaked[k] === "number" ? tweaked[k] + 1 : tweaked[k] + "x"
  return Presets.matching(tweaked) === null
}))
check("matching() rejects a superset", Presets.matching(Object.assign({ "decoration:glow:range": 9 }, presets[1].overrides)) === null)
check("matching() rejects a subset", presets.slice(1).every(function(p) {
  const sub = JSON.parse(JSON.stringify(p.overrides))
  delete sub[Object.keys(sub)[0]]
  return Presets.matching(sub) !== p
}))
check("the empty map matches only Omarchy", Presets.matching({}) === presets[0])
check("undefined matches nothing", Presets.matching(undefined) === null)

const byId = {}
presets.forEach(function(p) { byId[p.id] = p })
eq("Tight tiles as scrolling", byId.tight.overrides["general:layout"], "scrolling")
eq("Snappy tiles as scrolling", byId.snappy.overrides["general:layout"], "scrolling")
check("the others leave the layout alone or pick dwindle", ["omarchy", "airy", "glass", "focus"].every(function(id) {
  const l = byId[id].overrides["general:layout"]
  return l === undefined || l === "dwindle"
}))
check("previewOverrides drops the layout and nothing else", presets.every(function(p) {
  const pv = Presets.previewOverrides(p.overrides)
  if (pv["general:layout"] !== undefined) return false
  return Object.keys(p.overrides).every(function(k) { return k === "general:layout" || pv[k] === p.overrides[k] })
    && Object.keys(pv).every(function(k) { return p.overrides[k] !== undefined })
}))

console.log("\nQML components")

function findQmlTestRunner() {
  const candidates = ["/usr/lib/qt6/bin/qmltestrunner", "qmltestrunner", "qmltestrunner6"]
  for (const c of candidates) {
    const probe = spawnSync(c, ["--help"], { stdio: "ignore" })
    if (!probe.error) return c
  }
  return null
}

const runner = findQmlTestRunner()
if (!runner) {
  console.log("  skip (qmltestrunner not found; install qt6-declarative to run test/qml)")
} else {
  // Headless: no display, and no GTK platform theme trying to open one.
  const env = Object.assign({}, process.env, { QT_QPA_PLATFORM: "offscreen", QT_QPA_PLATFORMTHEME: "" })
  delete env.DISPLAY
  delete env.WAYLAND_DISPLAY
  const qml = spawnSync(runner, ["-input", path.join(__dirname, "qml")], { env: env, encoding: "utf8" })
  const lines = (qml.stdout || "").split("\n")
  lines.filter(function(l) { return /^(PASS|FAIL!|XFAIL|SKIP)/.test(l) }).forEach(function(l) {
    const m = l.match(/^(\S+)\s*:\s*qmltestrunner::(\S+)\(\)(.*)$/)
    if (!m) return
    if (/TestCase$/.test(m[2])) return
    if (m[1] === "PASS") console.log("  ok   " + m[2])
    else { failures++; console.log("  FAIL " + m[2] + m[3]) }
  })
  const totals = lines.filter(function(l) { return l.indexOf("Totals:") === 0 })[0]
  if (qml.status !== 0 && !totals) {
    failures++
    console.log("  FAIL qmltestrunner did not run\n" + (qml.stderr || qml.stdout || String(qml.error)))
  }
}

console.log("")
if (failures > 0) {
  console.log(failures + " failing\n")
  process.exit(1)
}
console.log("all passing\n")
