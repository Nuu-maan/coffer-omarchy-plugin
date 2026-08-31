import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.nuu-maan.coffer"
  manageIpc: false

  readonly property string manifestPluginId: "io.github.nuu-maan.coffer"

  readonly property var svc: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor(manifestPluginId)
    : null

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string glyphQueue: "\u{F0BA7}"
  readonly property string glyphStash: "\u{F0523}"
  readonly property string glyphClip: "\u{F0198}"
  readonly property string glyphImage: "\u{F02E9}"

  readonly property bool hideWhenEmpty: setting("hideWhenEmpty", false)
  readonly property int maxItems: setting("maxItems", 20)

  readonly property int openCount: svc ? svc.openCount : 0
  readonly property var result: svc ? svc.grouped(maxItems) : Model.groupItems([], [], 0)
  readonly property bool storeMissing: svc ? svc.storeMissing : false
  readonly property string engineError: svc
    ? (svc.storeError || svc.lastError)
    : "The Coffer service is not loaded."

  readonly property bool iconVisible: !hideWhenEmpty || openCount > 0 || opened

  implicitWidth: iconVisible ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight
  visible: iconVisible

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyphQueue
    active: root.openCount > 0
    opacity: root.openCount > 0 ? 1.0 : 0.55
    tooltipText: Model.tooltipFor(root.openCount)
    onPressed: root.toggle()

    Text {
      visible: root.openCount > 0
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.rightMargin: Style.space(1)
      anchors.topMargin: Style.space(1)
      text: Model.badgeText(root.openCount)
      color: root.bar ? root.bar.urgent : root.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      renderType: Text.NativeRendering
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (t) {
        var key = String(t).toLowerCase()
        if (key === "s" && root.svc) root.svc.stash()
        else if (key === "c" && root.svc) root.svc.clip()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Coffer"
            meta: root.storeMissing ? "No store yet" : Model.heroMeta(root.result)
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: root.glyphQueue
                color: root.openCount > 0 ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Text {
            visible: root.engineError !== ""
            width: parent.width
            text: root.engineError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Text {
            visible: root.result.total === 0
            width: parent.width
            text: root.storeMissing
              ? "Nothing captured yet. Stash a selection to start."
              : "The queue is clear."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          Column {
            width: parent.width
            spacing: Style.space(10)

            Repeater {
              model: root.result.groups

              Column {
                required property var modelData
                width: parent.width
                spacing: Style.space(6)

                PanelSectionHeader {
                  text: modelData.name ? modelData.name.toUpperCase() : "UNFILED"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }

                Repeater {
                  model: modelData.items
                  QueueRow {
                    required property var modelData
                    width: parent.width
                    item: modelData
                  }
                }
              }
            }
          }

          Text {
            visible: root.result.hidden > 0
            width: parent.width
            text: "+" + root.result.hidden + " more in Coffer"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }

          PanelSeparator { foreground: root.foreground }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: (parent.width - Style.space(8)) / 2
              text: "Stash"
              iconText: root.glyphStash
              leftAlign: true
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              tooltipText: "Stash the current selection  (s)"
              onClicked: if (root.svc) root.svc.stash()
            }

            Button {
              width: (parent.width - Style.space(8)) / 2
              text: "Clip"
              iconText: root.glyphClip
              leftAlign: true
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              tooltipText: "Clip a region of the screen  (c)"
              onClicked: if (root.svc) root.svc.clip()
            }
          }
        }
      }
    }
  }

  component QueueRow: Item {
    id: row
    required property var item

    readonly property bool isImage: row.item && row.item.kind === "image"
    readonly property string thumbPath: root.svc ? root.svc.imagePathFor(row.item) : ""

    implicitHeight: Math.max(textCol.implicitHeight, thumb.height) + Style.space(4)

    Rectangle {
      id: thumb
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: row.isImage ? Style.space(34) : 0
      height: row.isImage ? Style.space(34) : 0
      visible: row.isImage
      radius: Style.cornerRadius
      clip: true
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

      Image {
        anchors.fill: parent
        source: row.thumbPath ? "file://" + row.thumbPath : ""
        sourceSize.width: 96
        sourceSize.height: 96
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
      }

      Text {
        anchors.centerIn: parent
        visible: !row.thumbPath
        text: root.glyphImage
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
      }
    }

    Column {
      id: textCol
      anchors.left: thumb.right
      anchors.leftMargin: row.isImage ? Style.space(8) : 0
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.hairline

      Text {
        width: parent.width
        text: Model.previewText(row.item, 160)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: row.isImage
        text: row.item.width + " × " + row.item.height
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }
}
