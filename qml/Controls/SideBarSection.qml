import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// Collapsible section title in the sidebar
Item {
    id: control

    property string title: ""
    property bool expanded: true

    width: parent ? parent.width : 0
    height: LingmoUI.Units.fontMetrics.height + LingmoUI.Units.largeSpacing * 1.2

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: LingmoUI.Units.smallSpacing
        anchors.rightMargin: LingmoUI.Units.smallSpacing
        anchors.topMargin: LingmoUI.Units.smallSpacing

        Label {
            Layout.fillWidth: true
            text: control.title
            font.pointSize: LingmoUI.Theme.fontSize * 0.85
            font.bold: true
            color: LingmoUI.Theme.disabledTextColor
            elide: Text.ElideRight
        }

        SymbolicIcon {
            name: "pan-down"
            size: 12
            color: LingmoUI.Theme.disabledTextColor
            rotation: control.expanded ? 0 : -90
            opacity: _mouseArea.containsMouse ? 1 : 0
            Behavior on rotation { NumberAnimation { duration: 150 } }
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    MouseArea {
        id: _mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: control.expanded = !control.expanded
    }
}
