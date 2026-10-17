import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// Centered icon + title + explanation (+ optional action) for empty views.
// Same API as the shared LingmoUI EmptyState (iconName, title, text, actionText).
Item {
    id: control

    property string iconName: ""
    property string title: ""
    property string text: ""
    property string actionText: ""

    signal actionTriggered()

    implicitWidth: _layout.implicitWidth
    implicitHeight: _layout.implicitHeight

    ColumnLayout {
        id: _layout
        anchors.centerIn: parent
        width: Math.min(parent.width - LingmoUI.Units.largeSpacing * 4, 360)
        spacing: LingmoUI.Units.smallSpacing

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: LingmoUI.Units.smallSpacing
            width: LingmoUI.Units.iconSizes.large * 1.6
            height: width
            radius: width / 2
            color: Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                           LingmoUI.Theme.textColor.b, LingmoUI.Theme.darkMode ? 0.08 : 0.05)

            SymbolicIcon {
                anchors.centerIn: parent
                size: LingmoUI.Units.iconSizes.large * 0.8
                name: control.iconName
                color: LingmoUI.Theme.disabledTextColor
            }
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: control.title
            font.pointSize: LingmoUI.Theme.fontSize * 1.3
            font.bold: true
            wrapMode: Text.Wrap
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: control.text
            color: LingmoUI.Theme.disabledTextColor
            wrapMode: Text.Wrap
            visible: text.length > 0
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: LingmoUI.Units.smallSpacing
            text: control.actionText
            visible: control.actionText.length > 0
            focusPolicy: Qt.NoFocus
            onClicked: control.actionTriggered()
        }
    }
}
