import QtQuick

// A small procedurally drawn desktop showing what a preset does, painted over
// the user's wallpaper in their theme colors. Pure QtQuick: theme inputs come
// in as plain properties so it loads under qmltestrunner without Quickshell.
//
// Drawn from the overrides: layout (three dwindle windows, or two scrolling
// columns with the second running off the edge), gaps, border width, rounding,
// focused and unfocused opacity, dim on inactive, a soft offset rectangle for
// shadow, a frosted layer behind translucent windows when blur is on, and a
// halo around the focused window for glow. Animation speed is not drawn.
Item {
  id: root

  required property var preset
  property string wallpaper: ""
  property color background: "#1e1e2e"
  property color foreground: "#cdd6f4"
  property color accent: "#89b4fa"
  property string fontFamily: ""
  property bool focused: false
  property bool matched: false
  property real nameSize: 15
  property real descriptionSize: 11

  // Test seams.
  readonly property alias desktop: desktop
  readonly property alias wallpaperStatus: wallpaperImage.status
  readonly property bool wallpaperShown: wallpaper !== "" && wallpaperImage.status === Image.Ready
  readonly property alias nameText: nameLabel.text
  readonly property alias descriptionText: descriptionLabel.text

  readonly property var overrides: (preset && preset.overrides) || ({})

  // Omarchy's stock values, for whatever the preset leaves alone.
  function v(key, fallback) {
    var value = overrides[key]
    return value === undefined ? fallback : value
  }

  readonly property string layout: v("general:layout", "dwindle")
  readonly property real gapsIn: v("general:gaps_in", 5)
  readonly property real gapsOut: v("general:gaps_out", 10)
  readonly property real borderSize: v("general:border_size", 2)
  readonly property real rounding: v("decoration:rounding", 0)
  readonly property real activeOpacity: v("decoration:active_opacity", 1)
  readonly property real inactiveOpacity: v("decoration:inactive_opacity", 1)
  readonly property bool dimInactive: v("decoration:dim_inactive", false) === true
  readonly property real dimStrength: v("decoration:dim_strength", 0.5)
  readonly property bool blurEnabled: v("decoration:blur:enabled", false) === true
  readonly property bool shadowEnabled: v("decoration:shadow:enabled", false) === true
  readonly property real shadowRange: v("decoration:shadow:range", 4)
  readonly property bool glowEnabled: v("decoration:glow:enabled", false) === true
  readonly property real glowRange: v("decoration:glow:range", 8)

  // The mock stands in for a 1280-wide screen, so gaps read at card size.
  readonly property real px: desktop.width / 1280 * 2.2

  // Fractions of the tiling area. The first window is the focused one.
  readonly property var windows: layout === "scrolling"
    ? [ { x: 0,   y: 0, w: 0.62, h: 1 },
        { x: 0.62, y: 0, w: 0.62, h: 1 } ]
    : [ { x: 0,   y: 0,   w: 0.55, h: 1 },
        { x: 0.55, y: 0,   w: 0.45, h: 0.5 },
        { x: 0.55, y: 0.5, w: 0.45, h: 0.5 } ]

  implicitHeight: desktop.height + labels.height + 8

  Rectangle {
    id: desktop
    width: root.width
    height: Math.round(width * 0.625)
    radius: 6
    color: root.background
    clip: true

    Image {
      id: wallpaperImage
      anchors.fill: parent
      source: root.wallpaper === "" ? "" : (root.wallpaper.indexOf("file://") === 0 ? root.wallpaper : "file://" + root.wallpaper)
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false   // the symlink target changes with the theme
      visible: root.wallpaperShown
      sourceSize.width: 640
    }

    Item {
      id: tiles
      anchors.fill: parent
      anchors.margins: root.gapsOut * root.px

      Repeater {
        model: root.windows

        Item {
          id: win
          objectName: "window"
          required property var modelData
          required property int index

          readonly property bool focused: index === 0
          readonly property real paneOpacity: focused ? root.activeOpacity : root.inactiveOpacity
          readonly property real dimAmount: (!focused && root.dimInactive) ? root.dimStrength : 0
          readonly property bool shadowVisible: root.shadowEnabled
          readonly property bool blurVisible: root.blurEnabled && paneOpacity < 0.999
          readonly property bool glowVisible: focused && root.glowEnabled
          readonly property alias frame: frame

          readonly property real half: root.gapsIn * root.px / 2
          x: modelData.x * tiles.width + (modelData.x > 0 ? half : 0)
          y: modelData.y * tiles.height + (modelData.y > 0 ? half : 0)
          width: modelData.w * tiles.width - (modelData.x > 0 ? half : 0) - (modelData.x + modelData.w < 0.999 ? half : 0)
          height: modelData.h * tiles.height - (modelData.y > 0 ? half : 0) - (modelData.y + modelData.h < 0.999 ? half : 0)
          z: focused ? 2 : 1

          Rectangle {
            objectName: "glow"
            visible: win.glowVisible
            anchors.fill: frame
            anchors.margins: -root.glowRange * root.px * 0.6
            radius: frame.radius + root.glowRange * root.px * 0.6
            color: "transparent"
            border.width: root.glowRange * root.px * 0.6
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
          }

          Rectangle {
            objectName: "shadow"
            visible: win.shadowVisible
            anchors.fill: frame
            anchors.leftMargin: root.shadowRange * root.px * 0.35
            anchors.topMargin: root.shadowRange * root.px * 0.35
            anchors.rightMargin: -root.shadowRange * root.px * 0.35
            anchors.bottomMargin: -root.shadowRange * root.px * 0.35
            radius: frame.radius + 2
            color: Qt.rgba(0, 0, 0, 0.45)
          }

          // A frosted pane stands in for the compositor's blur: the wallpaper
          // still shows through, but flattened toward the window color.
          Rectangle {
            objectName: "blur"
            visible: win.blurVisible
            anchors.fill: frame
            radius: frame.radius
            color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.55)
          }

          Rectangle {
            id: frame
            anchors.fill: parent
            radius: root.rounding * root.px
            color: Qt.rgba(root.background.r, root.background.g, root.background.b, win.paneOpacity)
            border.width: Math.max(root.borderSize > 0 ? 1 : 0, root.borderSize * root.px)
            border.color: win.focused
              ? root.accent
              : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)

            // A few lines of "content", so opacity and dim have something to act on.
            Column {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.margins: Math.max(4, parent.width * 0.06)
              spacing: Math.max(2, parent.height * 0.06)
              opacity: win.paneOpacity
              Repeater {
                model: 3
                Rectangle {
                  required property int index
                  width: Math.max(6, frame.width * (0.5 - index * 0.12))
                  height: Math.max(1.5, frame.height * 0.05)
                  radius: height / 2
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, index === 0 ? 0.8 : 0.45)
                }
              }
            }

            Rectangle {
              objectName: "dim"
              anchors.fill: parent
              radius: parent.radius
              color: "black"
              opacity: win.dimAmount * win.paneOpacity
            }
          }
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: "transparent"
      border.width: root.focused ? 2 : 1
      border.color: root.focused
        ? root.accent
        : (root.matched ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6)
                        : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2))
    }
  }

  Column {
    id: labels
    anchors.top: desktop.bottom
    anchors.topMargin: 8
    width: root.width
    spacing: 2

    Row {
      spacing: 6
      Text {
        id: nameLabel
        text: root.preset ? root.preset.name : ""
        color: root.focused ? root.accent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: root.nameSize
        font.bold: true
      }
      Rectangle {
        visible: root.matched
        width: 6; height: 6; radius: 3
        color: root.accent
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Text {
      id: descriptionLabel
      text: root.preset ? root.preset.description : ""
      visible: root.focused
      width: parent.width
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.7)
      font.family: root.fontFamily
      font.pixelSize: root.descriptionSize
      wrapMode: Text.WordWrap
    }
  }
}
