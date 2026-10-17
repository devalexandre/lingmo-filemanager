import QtQuick
import QtQuick.Controls
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// Icon-only toolbar button with an animated hover background.
// Same API as the shared LingmoUI IconButton (iconName, tipText, iconSize).
AbstractButton {
    id: control

    property string iconName: ""
    property string tipText: ""
    property int iconSize: LingmoUI.Units.iconSizes.small

    implicitWidth: 32
    implicitHeight: 32
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    opacity: enabled ? 1.0 : 0.4

    Accessible.name: tipText

    background: Rectangle {
        radius: LingmoUI.Theme.smallRadius
        color: control.checked ? Qt.rgba(LingmoUI.Theme.highlightColor.r, LingmoUI.Theme.highlightColor.g,
                                          LingmoUI.Theme.highlightColor.b, LingmoUI.Theme.darkMode ? 0.3 : 0.15)
             : control.pressed ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                          LingmoUI.Theme.textColor.b, 0.15)
             : control.hovered ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                          LingmoUI.Theme.textColor.b, 0.08)
             : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    contentItem: Item {
        SymbolicIcon {
            anchors.centerIn: parent
            size: control.iconSize
            name: control.iconName
            color: control.checked ? LingmoUI.Theme.highlightColor : LingmoUI.Theme.textColor
        }
    }

    ToolTip.visible: hovered && tipText.length > 0
    ToolTip.text: tipText
    ToolTip.delay: 500
}
