import QtQuick
import QtTest
import "../.."

// PresetCard is pure QtQuick: a preset in, a mock desktop out. These cases
// check the item tree it builds rather than pixels.
TestCase {
  id: tc
  name: "Card"
  width: 400
  height: 300
  when: windowShown
  visible: true   // TestCase hides its children by default; clicks need a hit target

  Component {
    id: factory
    PresetCard { width: 320 }
  }

  function make(overrides, extra) {
    var props = { preset: { id: "x", name: "X", description: "desc", overrides: overrides || {} } }
    for (var k in extra) props[k] = extra[k]
    var c = createTemporaryObject(factory, tc, props)
    verify(c)
    return c
  }

  function windows(card) {
    var out = []
    function walk(item) {
      if (item.objectName === "window") out.push(item)
      for (var i = 0; i < item.children.length; i++) walk(item.children[i])
    }
    walk(card)
    return out
  }

  function focusedOf(card) {
    return windows(card).filter(function(w) { return w.focused })[0]
  }
  function unfocusedOf(card) {
    return windows(card).filter(function(w) { return !w.focused })[0]
  }

  function test_dwindle_draws_three_windows() {
    compare(windows(make({})).length, 3)
    compare(windows(make({ "general:layout": "dwindle" })).length, 3)
  }

  function test_scrolling_draws_two_columns_second_off_edge() {
    var card = make({ "general:layout": "scrolling" })
    var ws = windows(card)
    compare(ws.length, 2)
    var desk = card.desktop
    var second = ws.filter(function(w) { return !w.focused })[0]
    verify(second.x + second.width > desk.width, "second column should run off the right edge")
  }

  function test_gaps_move_windows_inward() {
    var tightCard = make({ "general:gaps_out": 0, "general:gaps_in": 0 })
    var airyCard = make({ "general:gaps_out": 40, "general:gaps_in": 20 })
    var tight = focusedOf(tightCard).mapToItem(tightCard.desktop, 0, 0)
    var airy = focusedOf(airyCard).mapToItem(airyCard.desktop, 0, 0)
    verify(tight.x < airy.x)
    verify(tight.y < airy.y)
    verify(focusedOf(tightCard).width > focusedOf(airyCard).width)
  }

  function test_border_and_rounding_flow_through() {
    var a = focusedOf(make({ "general:border_size": 1, "decoration:rounding": 0 }))
    var b = focusedOf(make({ "general:border_size": 6, "decoration:rounding": 20 }))
    compare(a.frame.radius, 0)
    verify(b.frame.radius > 0)
    verify(b.frame.border.width > a.frame.border.width)
  }

  function test_opacity_flows_through() {
    var card = make({ "decoration:active_opacity": 0.5, "decoration:inactive_opacity": 0.25 })
    fuzzyCompare(focusedOf(card).paneOpacity, 0.5, 0.001)
    fuzzyCompare(unfocusedOf(card).paneOpacity, 0.25, 0.001)
    var stock = make({})
    fuzzyCompare(focusedOf(stock).paneOpacity, 1, 0.001)
  }

  function test_dim_only_on_unfocused_when_enabled() {
    var card = make({ "decoration:dim_inactive": true, "decoration:dim_strength": 0.6 })
    fuzzyCompare(unfocusedOf(card).dimAmount, 0.6, 0.001)
    fuzzyCompare(focusedOf(card).dimAmount, 0, 0.001)
    fuzzyCompare(unfocusedOf(make({ "decoration:dim_strength": 0.6 })).dimAmount, 0, 0.001)
  }

  function test_shadow_blur_glow_layers() {
    var plain = focusedOf(make({}))
    verify(!plain.shadowVisible); verify(!plain.blurVisible); verify(!plain.glowVisible)
    var fancy = focusedOf(make({
      "decoration:shadow:enabled": true,
      "decoration:blur:enabled": true, "decoration:active_opacity": 0.8,
      "decoration:glow:enabled": true
    }))
    verify(fancy.shadowVisible); verify(fancy.blurVisible); verify(fancy.glowVisible)
    // Blur only shows behind a translucent window; opaque glass is just glass.
    verify(!focusedOf(make({ "decoration:blur:enabled": true })).blurVisible)
    // Glow belongs to the focused window only.
    verify(!unfocusedOf(make({ "decoration:glow:enabled": true })).glowVisible)
  }

  function test_empty_wallpaper_falls_back() {
    var card = make({}, { wallpaper: "" })
    verify(!card.wallpaperShown)
    compare(windows(card).length, 3)
  }

  function test_missing_wallpaper_falls_back() {
    var card = make({}, { wallpaper: "/nonexistent/omaland-test.png" })
    tryVerify(function() { return card.wallpaperStatus === Image.Error })
    verify(!card.wallpaperShown)
  }

  function test_name_and_description_shown() {
    var card = make({})
    compare(card.nameText, "X")
    compare(card.descriptionText, "desc")
  }
}
