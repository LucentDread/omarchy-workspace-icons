import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "IconStore.js" as IconStore

// Based on Workspace Dots (voyagen/oma-dots, MIT): the focused workspace grows
// into a pill while the previous one shrinks. A workspace with an icon shows
// it in place of its dot, and inside the pill when focused.
//
// Icons live in the plugin's own file, ~/.config/omarchy/workspace-icons.json.
// Nothing is written to the Hyprland config or to shell.json.
BarWidget {
  id: root
  moduleName: "lucentdread.workspace-icons"

  readonly property string pluginId: "lucentdread.workspace-icons"
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
  property var icons: ({})

  function workspaceCount() {
    var focused = Hyprland.focusedWorkspace
    var lastId = focused && focused.id > 0 && focused.id <= 10 ? focused.id : 1
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > lastId && id <= 10 && values[i].toplevels.values.length > 0) lastId = id
    }
    return lastId
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    // Lua-config Hyprland first, then the classic dispatcher.
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })")
      + " >/dev/null 2>&1 || hyprctl dispatch workspace " + id)
  }

  function openEditor(id) {
    var payload = JSON.stringify({ workspace: id })
    if (root.bar && root.bar.shell && typeof root.bar.shell.toggle === "function"
        && root.bar.shell.toggle(root.pluginId, payload)) return
    if (root.bar) root.bar.run("omarchy-shell shell toggle " + root.pluginId + " " + Util.shellQuote(payload))
  }

  function iconFor(id) {
    var icon = root.icons[String(id)]
    return icon ? String(icon) : ""
  }

  readonly property real dotSize: Style.spaceReal(8)
  readonly property real pillSize: Style.spaceReal(16)
  readonly property real gapSize: Style.spaceReal(6)
  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  readonly property real iconSize: Style.font.iconLarge
  readonly property real iconPad: Style.spaceReal(6)
  readonly property real iconGap: Style.spaceReal(10)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  FileView {
    path: root.configHome + "/omarchy/workspace-icons.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.icons = IconStore.parseSettings(text()).icons
    onLoadFailed: function(error) { root.icons = ({}) }
    // text() is stale inside the change signal; reload routes through onLoaded.
    onFileChanged: reload()
  }

  Grid {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceCount()
    spacing: 0

    Repeater {
      model: root.workspaceCount()

      WidgetButton {
        id: button
        required property int index
        readonly property int workspaceId: index + 1
        readonly property string icon: root.iconFor(workspaceId)
        readonly property bool hasIcon: icon !== ""
        property bool ready: false
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === workspaceId
        readonly property bool expanded: focused && ready
        // Length of the indicator along the bar: a dot or icon, growing into
        // a pill when focused.
        // Size and center on the glyph's ink, not its advance: Nerd Font
        // glyphs often sit off-center in a box wider than they are.
        readonly property rect ink: glyphMetrics.tightBoundingRect
        readonly property real glyphWidth: Math.max(root.iconSize * 0.75, Math.ceil(ink.width))
        readonly property real restLength: hasIcon ? (root.vertical ? root.iconSize : glyphWidth) : root.dotSize
        readonly property real pillLength: hasIcon ? restLength + root.iconPad * 2 : root.pillSize
        readonly property real length: expanded ? pillLength : restLength
        readonly property real thickness: hasIcon ? root.iconSize + Style.spaceReal(4) : root.dotSize
        Component.onCompleted: ready = true

        TextMetrics {
          id: glyphMetrics
          text: button.icon
          font.family: iconText.font.family
          font.pixelSize: root.iconSize
        }

        bar: root.bar
        labelVisible: false
        hasVisualContent: true
        fixedWidth: root.vertical ? root.barSize : button.length + (button.hasIcon ? root.iconGap : root.gapSize)
        fixedHeight: root.vertical ? button.length + (button.hasIcon ? root.iconGap : root.gapSize) : root.barSize
        tooltipText: "Workspace " + workspaceId + "  ·  right click to choose an icon"
        onPressed: function(which) {
          if (which === Qt.LeftButton) root.focusWorkspace(workspaceId)
          else if (which === Qt.RightButton) root.openEditor(workspaceId)
        }

        Behavior on fixedWidth { NumberAnimation { duration: 90; easing.type: Easing.InOutSine } }
        Behavior on fixedHeight { NumberAnimation { duration: 90; easing.type: Easing.InOutSine } }

        Rectangle {
          id: pill
          anchors.centerIn: parent
          width: root.vertical ? button.thickness : button.length
          height: root.vertical ? button.length : button.thickness
          radius: Math.min(width, height) / 2
          // An icon at rest has no dot behind it; the pill fills in on focus.
          color: button.focused ? Commons.Color.accent : (root.bar ? root.bar.barForeground : Commons.Color.foreground)
          opacity: button.hasIcon && !button.focused ? 0 : (button.focused ? 1 : 0.7)

          Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.InOutSine } }
          Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.InOutSine } }
          Behavior on color { ColorAnimation { duration: 90 } }
          Behavior on opacity { NumberAnimation { duration: 90 } }
        }

        Text {
          id: iconText
          anchors.centerIn: parent
          // Shift the box so the ink's center lands on the pill's center.
          anchors.horizontalCenterOffset: width / 2 - (button.ink.x + button.ink.width / 2)
          anchors.verticalCenterOffset: height / 2 - (baselineOffset + button.ink.y + button.ink.height / 2)
          visible: button.hasIcon
          text: button.icon
          textFormat: Text.PlainText
          font.family: root.bar && root.bar.fontFamily ? root.bar.fontFamily : Style.font.family
          font.pixelSize: root.iconSize
          // Left-aligned on purpose: Nerd Font glyphs are wider than their
          // advance, and centered alignment would center the advance, pushing
          // the drawing right. The offsets above center the ink instead.
          color: button.focused ? Commons.Color.background : (root.bar ? root.bar.barForeground : Commons.Color.foreground)
          opacity: button.focused ? 1 : 0.7

          Behavior on color { ColorAnimation { duration: 90 } }
          Behavior on opacity { NumberAnimation { duration: 90 } }
        }
      }
    }
  }
}
