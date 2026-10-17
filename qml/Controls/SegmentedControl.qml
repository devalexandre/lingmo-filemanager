import QtQuick
import QtQuick.Controls
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// Row of mutually exclusive icon segments (view switcher).
// model: [{ icon: "view-grid", text: qsTr("Icons") }, ...]
// Same API as the shared LingmoUI SegmentedControl (model, currentIndex, activated).
Rectangle {
    id: control

    property var model: []
    property int currentIndex: 0
    readonly property int count: _repeater.count

    signal activated(int index)

    implicitHeight: 32
    implicitWidth: _row.implicitWidth + 4
    radius: LingmoUI.Theme.smallRadius
    color: Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                   LingmoUI.Theme.textColor.b, LingmoUI.Theme.darkMode ? 0.1 : 0.06)

    // Sliding "raised" segment
    Rectangle {
        readonly property Item target: _repeater.count > 0 && control.currentIndex >= 0
                                       ? _repeater.itemAt(control.currentIndex) : null
        visible: target !== null
        x: target ? _row.x + target.x : 0
        y: 2
        width: target ? target.width : 0
        height: control.height - 4
        radius: LingmoUI.Theme.smallRadius - 2
        color: LingmoUI.Theme.secondBackgroundColor
        border.width: 1
        border.color: Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                              LingmoUI.Theme.textColor.b, 0.08)

        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    Row {
        id: _row
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            id: _repeater
            model: control.model

            delegate: AbstractButton {
                id: _segment
                width: 34
                height: control.height - 4
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                Accessible.name: modelData.text

                background: Item {}
                contentItem: Item {
                    SymbolicIcon {
                        anchors.centerIn: parent
                        name: modelData.icon
                        color: index === control.currentIndex ? LingmoUI.Theme.highlightColor
                                                              : LingmoUI.Theme.textColor
                        opacity: _segment.hovered || index === control.currentIndex ? 1 : 0.75
                    }
                }

                onClicked: {
                    control.currentIndex = index
                    control.activated(index)
                }

                ToolTip.visible: hovered && modelData.text
                ToolTip.text: modelData.text || ""
                ToolTip.delay: 500
            }
        }
    }
}
