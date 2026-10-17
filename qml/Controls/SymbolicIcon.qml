import QtQuick
import Qt5Compat.GraphicalEffects
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// A theme icon (its -symbolic variant) tinted with one colour, so it follows
// light/dark mode and selection colours
Item {
    id: control

    property string name: ""
    property color color: LingmoUI.Theme.textColor
    property int size: LingmoUI.Units.iconSizes.small

    implicitWidth: size
    implicitHeight: size

    Image {
        id: _image
        anchors.fill: parent
        source: control.name ? "image://icontheme/" + control.name
                               + (control.name.endsWith("-symbolic") ? "" : "-symbolic") : ""
        sourceSize: Qt.size(width, height)
        smooth: true
        visible: false
    }

    ColorOverlay {
        anchors.fill: parent
        source: _image
        color: control.color

        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
