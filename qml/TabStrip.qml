import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LingmoUI.CompatibleModule 3.0 as LingmoUI

import "./Controls"

// Tabs of the window; only shown when there is more than one
Item {
    id: control

    property alias model: _repeater.model     // ListModel with a "title" role
    property int currentIndex: 0

    signal activated(int index)
    signal closeRequested(int index)
    signal newTabRequested()

    implicitHeight: 34

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: LingmoUI.Units.smallSpacing
        anchors.rightMargin: LingmoUI.Units.smallSpacing
        spacing: 2

        Repeater {
            id: _repeater

            delegate: AbstractButton {
                id: _tab
                readonly property bool current: index === control.currentIndex
                Layout.fillWidth: true
                Layout.maximumWidth: 240
                Layout.preferredHeight: control.height - 4
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                Accessible.name: model.title

                background: Rectangle {
                    radius: LingmoUI.Theme.smallRadius
                    color: _tab.current ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                                  LingmoUI.Theme.textColor.b, LingmoUI.Theme.darkMode ? 0.12 : 0.07)
                         : _tab.hovered ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                                  LingmoUI.Theme.textColor.b, 0.04)
                         : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                contentItem: RowLayout {
                    spacing: LingmoUI.Units.smallSpacing

                    Item { Layout.preferredWidth: 20 }

                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: model.title
                        elide: Text.ElideMiddle
                        font.bold: _tab.current
                        color: _tab.current ? LingmoUI.Theme.textColor : LingmoUI.Theme.disabledTextColor
                    }

                    IconButton {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        iconName: "window-close"
                        iconSize: 10
                        tipText: qsTr("Close Tab")
                        opacity: _tab.hovered || _tab.current ? 1 : 0
                        onClicked: control.closeRequested(index)
                    }
                }

                onClicked: control.activated(index)

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.MiddleButton
                    onClicked: control.closeRequested(index)
                }
            }
        }

        IconButton {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            iconName: "list-add"
            tipText: qsTr("New Tab (Ctrl+T)")
            onClicked: control.newTabRequested()
        }
    }
}
