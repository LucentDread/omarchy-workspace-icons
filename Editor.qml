import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "IconStore.js" as IconStore

// Icon picker for the workspace widget. Right click a workspace (or run
// `omarchy-shell shell toggle lucentdread.workspace-icons '{"workspace":3}'`),
// search Nerd Font glyphs by name and pick one. Saved to the plugin's own
// file, ~/.config/omarchy/workspace-icons.json.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginId: "lucentdread.workspace-icons"
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
  readonly property string settingsPath: configHome + "/omarchy/workspace-icons.json"
  readonly property string glyphPath: decodeURIComponent(String(Qt.resolvedUrl("glyphs.tsv")).replace(/^file:\/\//, ""))

  property bool opened: false
  property int workspace: 1
  property var settings: ({ version: 1, icons: {} })
  property var glyphs: []
  property var results: []
  property int selectedIndex: 0

  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Commons.Color.menu.scrim
  property color selectedBackground: Commons.Color.menu.selectedBackground
  property color selectedText: Commons.Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int cellSize: Math.max(Style.space(44), Style.font.display + Style.spacing.md)
  property int cardWidth: Math.min(Style.space(560), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(600), panel.height - Style.gapsOut * 2)
  readonly property int columns: Math.max(1, Math.floor(resultGrid.width / cellSize))

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) { payload = {} }
    var requested = Number(payload.workspace)
    if (requested >= 1 && requested <= 10) workspace = Math.floor(requested)
    else if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id >= 1 && Hyprland.focusedWorkspace.id <= 10)
      workspace = Hyprland.focusedWorkspace.id
    opened = true
    search.text = ""
    rebuild()
    Qt.callLater(function() { search.forceActiveFocus() })
  }

  function close() {
    opened = false
  }

  function dismiss() {
    if (shell && typeof shell.hide === "function" && shell.hide((manifest && manifest.id) || pluginId)) return
    close()
  }

  function rebuild() {
    results = IconStore.searchGlyphs(glyphs, search.text, 600)
    selectedIndex = 0
    resultGrid.positionViewAtBeginning()
  }

  function currentIcon() {
    return settings.icons[String(workspace)] || ""
  }

  function setIcon(icon) {
    settings = IconStore.withIcon(settings, workspace, icon)
    settingsFile.setText(IconStore.serialize(settings))
  }

  function move(delta) {
    if (results.length === 0) return
    selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta))
    resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
  }

  function cycleWorkspace(delta) {
    workspace = ((workspace - 1 + delta + 10) % 10) + 1
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.settings = IconStore.parseSettings(text())
    onLoadFailed: function(error) { root.settings = IconStore.parseSettings("") }
    onFileChanged: reload()
  }

  FileView {
    path: root.glyphPath
    printErrors: false
    onLoaded: {
      root.glyphs = IconStore.parseGlyphs(text())
      if (root.opened) root.rebuild()
    }
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "lucentdread-workspace-icons"

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: search.forceActiveFocus() }

      // Navigation keys; everything else is typed into the search line.
      Item {
        id: keyHandler
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (search.text !== "") search.text = ""
            else root.dismiss()
          } else if (event.key === Qt.Key_Tab) {
            root.cycleWorkspace(1)
          } else if (event.key === Qt.Key_Backtab) {
            root.cycleWorkspace(-1)
          } else if (event.key === Qt.Key_Left) {
            root.move(-1)
          } else if (event.key === Qt.Key_Right) {
            root.move(1)
          } else if (event.key === Qt.Key_Up) {
            root.move(-root.columns)
          } else if (event.key === Qt.Key_Down) {
            root.move(root.columns)
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.results.length > 0) root.setIcon(root.results[root.selectedIndex].glyph)
          } else if (event.key === Qt.Key_Delete) {
            root.setIcon("")
          } else {
            return
          }
          event.accepted = true
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.spacing.md

        // ---------------------------------------------------- workspaces 1-10
        Row {
          id: workspaceRow
          width: parent.width
          spacing: Style.space(4)
          readonly property real chip: (width - spacing * 9) / 10

          Repeater {
            model: 10

            Rectangle {
              id: chip
              required property int index
              readonly property int workspaceId: index + 1
              readonly property string icon: {
                var dummy = root.settings
                return root.settings.icons[String(workspaceId)] || ""
              }
              readonly property bool current: root.workspace === workspaceId

              width: workspaceRow.chip
              height: Style.space(48)
              radius: root.cornerRadius
              color: current ? root.selectedBackground : (chipMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent")
              border.width: 1
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, current ? 0.5 : 0.15)

              Column {
                anchors.centerIn: parent
                spacing: 0
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: chip.icon || "·"
                  textFormat: Text.PlainText
                  color: chip.current ? root.selectedText : root.foreground
                  opacity: chip.icon ? 1 : 0.4
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.iconLarge
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: chip.workspaceId === 10 ? "0" : String(chip.workspaceId)
                  color: chip.current ? root.selectedText : root.foreground
                  opacity: 0.6
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }

              MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.workspace = chip.workspaceId
                  search.forceActiveFocus()
                }
              }
            }
          }
        }

        // ----------------------------------------------------------- search
        Item {
          id: searchRow
          width: parent.width
          height: Math.max(Style.space(34), Style.font.heading + Style.spacing.controlPaddingY * 2)

          FilterInput {
            id: search
            anchors.left: parent.left
            anchors.right: clearButton.left
            anchors.rightMargin: Style.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            keyHandler: keyHandler
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            onTextChanged: root.rebuild()

            Text {
              anchors.fill: parent
              visible: search.text === ""
              text: "Search icons for workspace " + (root.workspace === 10 ? 0 : root.workspace) + "…"
              color: root.foreground
              opacity: 0.5
              font: search.font
              elide: Text.ElideRight
            }
          }

          Button {
            id: clearButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Clear icon"
            bordered: true
            enabled: root.currentIcon() !== ""
            onClicked: {
              root.setIcon("")
              search.forceActiveFocus()
            }
          }
        }

        // ---------------------------------------------------------- results
        Item {
          width: parent.width
          height: parent.height - workspaceRow.height - searchRow.height - footer.height - Style.spacing.md * 3

          GridView {
            id: resultGrid
            anchors.fill: parent
            clip: true
            model: root.results
            cellWidth: Math.floor(width / root.columns)
            cellHeight: root.cellSize
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
              id: cell
              required property int index
              required property var modelData
              readonly property bool hasCursor: index === root.selectedIndex
              readonly property bool chosen: modelData.glyph === root.currentIcon()

              width: resultGrid.cellWidth
              height: resultGrid.cellHeight
              radius: root.cornerRadius
              color: hasCursor ? root.selectedBackground : "transparent"
              border.width: chosen ? 2 : 0
              border.color: Commons.Color.accent

              Text {
                anchors.centerIn: parent
                text: cell.modelData.glyph
                textFormat: Text.PlainText
                color: cell.hasCursor ? root.selectedText : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) root.selectedIndex = cell.index
                onClicked: {
                  root.setIcon(cell.modelData.glyph)
                  search.forceActiveFocus()
                }
              }
            }
          }

          Text {
            anchors.centerIn: parent
            visible: root.results.length === 0
            text: root.glyphs.length === 0 ? "Loading icons…" : "No icon matches “" + search.text + "”"
            color: root.foreground
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }
        }

        // ----------------------------------------------------------- footer
        Text {
          id: footer
          width: parent.width
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: (root.results.length > 0 ? root.results[root.selectedIndex].name + "   ·   " : "")
            + "Enter apply · Del clear · Tab next workspace · Esc close"
          color: root.foreground
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }
}
