import QtQuick
import QtTest
import "../.."

// PresetCarousel imports only QtQuick, so it loads without Quickshell. These
// cases cover keyboard behavior and the signals the panel wires up.
TestCase {
  id: tc
  name: "Carousel"
  width: 1100
  height: 400
  when: windowShown
  visible: true   // TestCase hides its children by default; clicks need a hit target

  readonly property var presets: [
    { id: "a", name: "A", description: "one", overrides: {} },
    { id: "b", name: "B", description: "two", overrides: { "general:gaps_in": 0 } },
    { id: "c", name: "C", description: "three", overrides: { "general:layout": "scrolling" } },
    { id: "d", name: "D", description: "four", overrides: { "decoration:rounding": 4 } },
    { id: "e", name: "E", description: "five", overrides: { "decoration:rounding": 5 } },
    { id: "f", name: "F", description: "six", overrides: { "decoration:rounding": 6 } }
  ]

  Component {
    id: factory
    PresetCarousel {
      width: 1100
      height: 360
      presets: tc.presets
      focus: true
    }
  }

  function make(matchingIndex) {
    var c = createTemporaryObject(factory, tc, { matchingIndex: matchingIndex === undefined ? -1 : matchingIndex })
    verify(c)
    c.forceActiveFocus()
    return c
  }

  function spy(target, signalName) {
    return createTemporaryObject(spyFactory, tc, { target: target, signalName: signalName })
  }
  Component { id: spyFactory; SignalSpy {} }

  function test_initial_focus_is_matching() {
    compare(make(3).focusedIndex, 3)
  }

  function test_initial_focus_falls_back_to_zero() {
    compare(make(-1).focusedIndex, 0)
  }

  function test_arrows_and_hl_step_and_clamp() {
    var c = make(0)
    keyClick(Qt.Key_Right); compare(c.focusedIndex, 1)
    keyClick(Qt.Key_L);     compare(c.focusedIndex, 2)
    keyClick(Qt.Key_Left);  compare(c.focusedIndex, 1)
    keyClick(Qt.Key_H);     compare(c.focusedIndex, 0)
    keyClick(Qt.Key_Left);  compare(c.focusedIndex, 0)
    for (var i = 0; i < 10; i++) keyClick(Qt.Key_Right)
    compare(c.focusedIndex, 5)
  }

  function test_number_keys_jump() {
    var c = make(0)
    keyClick(Qt.Key_4); compare(c.focusedIndex, 3)
    keyClick(Qt.Key_1); compare(c.focusedIndex, 0)
    keyClick(Qt.Key_6); compare(c.focusedIndex, 5)
    keyClick(Qt.Key_7); compare(c.focusedIndex, 5)
    keyClick(Qt.Key_0); compare(c.focusedIndex, 5)
  }

  function test_focus_change_emits_previewed_only() {
    var c = make(0)
    var previewed = spy(c, "previewed")
    var applied = spy(c, "applied")
    var cancelled = spy(c, "cancelled")
    var customize = spy(c, "customizeRequested")
    keyClick(Qt.Key_Right)
    keyClick(Qt.Key_3)
    compare(previewed.count, 2)
    compare(previewed.signalArguments[0][0], 1)
    compare(previewed.signalArguments[1][0], 2)
    compare(applied.count, 0)
    compare(cancelled.count, 0)
    compare(customize.count, 0)
  }

  function test_enter_space_apply_focused() {
    var c = make(2)
    var applied = spy(c, "applied")
    keyClick(Qt.Key_Return); compare(applied.count, 1); compare(applied.signalArguments[0][0], 2)
    keyClick(Qt.Key_Enter);  compare(applied.count, 2)
    keyClick(Qt.Key_Space);  compare(applied.count, 3); compare(applied.signalArguments[2][0], 2)
  }

  function test_click_focused_card_applies_and_other_card_focuses() {
    var c = make(1)
    var applied = spy(c, "applied")
    var previewed = spy(c, "previewed")
    var focused = c.cardAt(1)
    var other = c.cardAt(4)
    verify(focused); verify(other)
    mouseClick(other)
    compare(c.focusedIndex, 4)
    compare(previewed.count, 1)
    compare(applied.count, 0)
    tryCompare(other, "width", c.focusedWidth)   // let the enlarge animation land
    mouseClick(other)
    compare(applied.count, 1)
    compare(applied.signalArguments[0][0], 4)
  }

  function test_escape_cancels_and_tab_customizes() {
    var c = make(0)
    var cancelled = spy(c, "cancelled")
    var customize = spy(c, "customizeRequested")
    keyClick(Qt.Key_Escape); compare(cancelled.count, 1)
    keyClick(Qt.Key_Tab);    compare(customize.count, 1)
  }

  function test_custom_note_only_when_nothing_matches() {
    verify(make(-1).customNoteVisible)
    verify(!make(2).customNoteVisible)
  }

  function test_focused_card_is_enlarged() {
    var c = make(2)
    tryCompare(c.cardAt(2), "width", c.focusedWidth)
    verify(c.cardAt(2).width > c.cardAt(1).width)
    verify(c.cardAt(2).width > c.cardAt(3).width)
    verify(c.cardAt(2).z > c.cardAt(1).z)
  }

  function test_reset_refocuses_matching() {
    var c = make(1)
    keyClick(Qt.Key_5)
    compare(c.focusedIndex, 4)
    c.matchingIndex = 3
    c.reset()
    compare(c.focusedIndex, 3)
  }
}
