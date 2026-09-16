import QtQuick

// A row of preset cards with one foregrounded and enlarged, the rest
// compressed to either side, in the spirit of Omarchy's image picker. Pure
// QtQuick, so it loads under qmltestrunner; the panel wires the signals to
// preview, write, revert and view switching.
//
// Keys: ← → h l step, 1–6 jump, Enter/Space apply, Esc cancel, Tab customize.
// Clicking the focused card applies it; clicking another card focuses it.
Item {
  id: root

  property var presets: []
  property int matchingIndex: -1
  property string wallpaper: ""
  property color background: "#1e1e2e"
  property color foreground: "#cdd6f4"
  property color accent: "#89b4fa"
  property string fontFamily: ""
  property real nameSize: 15
  property real descriptionSize: 11

  property real focusedWidth: 320
  property real sideWidth: 132
  property real spacing: 8

  property int focusedIndex: 0
  readonly property bool customNoteVisible: matchingIndex < 0

  signal previewed(int index)
  signal applied(int index)
  signal cancelled()
  signal customizeRequested()

  function reset() {
    focusedIndex = matchingIndex >= 0 && matchingIndex < presets.length ? matchingIndex : 0
  }

  function step(delta) {
    focusedIndex = Math.max(0, Math.min(presets.length - 1, focusedIndex + delta))
  }

  function jump(index) {
    if (index >= 0 && index < presets.length) focusedIndex = index
  }

  function cardAt(index) {
    return cards.itemAt(index)
  }

  onFocusedIndexChanged: previewed(focusedIndex)
  Component.onCompleted: reset()

  Keys.onPressed: function(event) {
    var vim = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
    if (event.key === Qt.Key_Escape) { cancelled(); event.accepted = true }
    else if (event.key === Qt.Key_Tab) { customizeRequested(); event.accepted = true }
    else if (event.key === Qt.Key_Right || (vim && event.key === Qt.Key_L)) { step(1); event.accepted = true }
    else if (event.key === Qt.Key_Left || (vim && event.key === Qt.Key_H)) { step(-1); event.accepted = true }
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      applied(focusedIndex); event.accepted = true
    }
    else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
      jump(event.key - Qt.Key_1); event.accepted = true
    }
  }

  readonly property real rowWidth: focusedWidth + (presets.length - 1) * (sideWidth + spacing)
  readonly property real rowLeft: (width - rowWidth) / 2

  Item {
    id: row
    anchors.fill: parent

    Repeater {
      id: cards
      model: root.presets.length

      PresetCard {
        id: card
        required property int index
        readonly property bool isFocused: index === root.focusedIndex

        preset: root.presets[index]
        wallpaper: root.wallpaper
        background: root.background
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        nameSize: root.nameSize
        descriptionSize: root.descriptionSize
        focused: isFocused
        matched: index === root.matchingIndex

        width: isFocused ? root.focusedWidth : root.sideWidth
        x: root.rowLeft + index * (root.sideWidth + root.spacing)
           + (index > root.focusedIndex ? root.focusedWidth - root.sideWidth : 0)
        y: (row.height - height) / 2
        z: isFocused ? 10 : 1
        opacity: isFocused ? 1 : 0.7

        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 140 } }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: card.isFocused ? root.applied(card.index) : root.jump(card.index)
        }
      }
    }
  }
}
