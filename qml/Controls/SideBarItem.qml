import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// Settings-style sidebar row: white symbolic icon on a coloured tile (or a
// full-colour icon), title, optional count badge and optional usage bar.
// Same core API as the shared LingmoUI SideBarItem (title, iconName,
// iconSource, tileColor, badge, isCurrent, clicked, rightClicked).
Item {
    id: control

    property string title: ""
    property string iconName: ""
    property url iconSource: ""
    property color tileColor: LingmoUI.Theme.blueColor
    property var badge: ""
    property bool isCurrent: false
    property bool dropHighlight: false
    property bool dimmed: false
    // 0..1 draws a usage bar under the title (disks); < 0 hides it
    property real usage: -1
    property string toolTipText: ""
    readonly property alias hovered: _mouseArea.containsMouse

    signal clicked()
    signal rightClicked()
    signal middleClicked()

    implicitWidth: 200
    implicitHeight: LingmoUI.Units.fontMetrics.height + LingmoUI.Units.largeSpacing * (usage >= 0 ? 1.9 : 1.2)

    Accessible.role: Accessible.ListItem
    Accessible.name: title

    Rectangle {
        anchors.fill: parent
        radius: LingmoUI.Theme.mediumRadius
        color: control.isCurrent ? LingmoUI.Theme.highlightColor
             : control.dropHighlight ? Qt.rgba(LingmoUI.Theme.highlightColor.r, LingmoUI.Theme.highlightColor.g,
                                                LingmoUI.Theme.highlightColor.b, 0.25)
             : _mouseArea.pressed ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                             LingmoUI.Theme.textColor.b, 0.15)
             : _mouseArea.containsMouse ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                                   LingmoUI.Theme.textColor.b, 0.08)
             : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: LingmoUI.Units.smallSpacing
        anchors.rightMargin: LingmoUI.Units.smallSpacing
        spacing: LingmoUI.Units.smallSpacing * 1.5
        opacity: control.dimmed ? 0.5 : 1

        // Coloured tile with a white glyph
        Rectangle {
            visible: control.iconName.length > 0
            Layout.alignment: Qt.AlignVCenter
            width: 24
            height: 24
            radius: 7
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(control.tileColor, 1.18) }
                GradientStop { position: 1.0; color: control.tileColor }
            }

            SymbolicIcon {
                anchors.centerIn: parent
                size: 14
                name: control.iconName
                color: LingmoUI.Theme.highlightedTextColor
            }
        }

        Image {
            visible: control.iconName.length === 0 && control.iconSource.toString().length > 0
            Layout.alignment: Qt.AlignVCenter
            width: 24
            height: 24
            sourceSize: Qt.size(24, 24)
            source: control.iconSource
            asynchronous: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            Label {
                Layout.fillWidth: true
                text: control.title
                elide: Text.ElideRight
                color: control.isCurrent ? LingmoUI.Theme.highlightedTextColor : LingmoUI.Theme.textColor
            }

            // Disk usage
            Rectangle {
                visible: control.usage >= 0
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: control.isCurrent ? Qt.rgba(LingmoUI.Theme.highlightedTextColor.r, LingmoUI.Theme.highlightedTextColor.g,
                                                   LingmoUI.Theme.highlightedTextColor.b, 0.3)
                                         : Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                                   LingmoUI.Theme.textColor.b, 0.12)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, control.usage))
                    height: parent.height
                    radius: parent.radius
                    color: control.isCurrent ? LingmoUI.Theme.highlightedTextColor
                         : control.usage > 0.9 ? LingmoUI.Theme.redColor
                         : control.usage > 0.75 ? LingmoUI.Theme.orangeColor
                         : LingmoUI.Theme.highlightColor
                }
            }
        }

        // Count badge
        Rectangle {
            readonly property string badgeText: control.badge === undefined || control.badge === null ? "" : String(control.badge)
            visible: badgeText.length > 0 && badgeText !== "0"
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Math.max(height, _badgeLabel.implicitWidth + LingmoUI.Units.smallSpacing * 2)
            implicitHeight: _badgeLabel.implicitHeight + 2
            radius: height / 2
            color: control.isCurrent ? Qt.rgba(LingmoUI.Theme.highlightedTextColor.r, LingmoUI.Theme.highlightedTextColor.g,
                                               LingmoUI.Theme.highlightedTextColor.b, 0.25)
                                     : Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                               LingmoUI.Theme.textColor.b, 0.1)

            Label {
                id: _badgeLabel
                anchors.centerIn: parent
                text: parent.badgeText
                font.pointSize: LingmoUI.Theme.fontSize * 0.8
                color: control.isCurrent ? LingmoUI.Theme.highlightedTextColor : LingmoUI.Theme.disabledTextColor
            }
        }
    }

    MouseArea {
        id: _mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton)
                control.rightClicked()
            else if (mouse.button === Qt.MiddleButton)
                control.middleClicked()
            else
                control.clicked()
        }
    }

    ToolTip.visible: _mouseArea.containsMouse && toolTipText.length > 0
    ToolTip.text: toolTipText
    ToolTip.delay: 600
}
