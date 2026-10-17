import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import LingmoUI.CompatibleModule 3.0 as LingmoUI

import "./Controls"

// Results of the recursive name search: name | folder | size | modified
ListView {
    id: control

    property int itemHeight: Math.round(LingmoUI.Units.fontMetrics.height + LingmoUI.Units.largeSpacing * 1.1)
    readonly property bool showKindColumn: width > 760

    signal openRequested(int row)
    signal contextMenuRequested(int row)
    signal openInNewTabRequested(string url)

    clip: true
    currentIndex: -1
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: true
    highlightMoveDuration: 0

    ScrollBar.vertical: ScrollBar {}

    LingmoUI.WheelHandler {
        target: control
    }

    Keys.onReturnPressed: if (currentIndex >= 0) openRequested(currentIndex)
    Keys.onEnterPressed: if (currentIndex >= 0) openRequested(currentIndex)

    headerPositioning: ListView.OverlayHeader
    header: Rectangle {
        z: 3
        width: control.width - control.leftMargin - control.rightMargin
        height: LingmoUI.Units.fontMetrics.height + LingmoUI.Units.largeSpacing
        color: LingmoUI.Theme.secondBackgroundColor

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                           LingmoUI.Theme.textColor.b, 0.08)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: LingmoUI.Units.smallSpacing + LingmoUI.Units.iconSizes.smallMedium + LingmoUI.Units.smallSpacing
            anchors.rightMargin: LingmoUI.Units.smallSpacing
            spacing: LingmoUI.Units.smallSpacing

            HeaderLabel { text: qsTr("Name"); Layout.fillWidth: true; Layout.preferredWidth: 2 }
            HeaderLabel { text: qsTr("Folder"); Layout.fillWidth: true; Layout.preferredWidth: 1 }
            HeaderLabel { text: qsTr("Size"); Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
            HeaderLabel { text: qsTr("Modified"); Layout.preferredWidth: 130; Layout.leftMargin: LingmoUI.Units.largeSpacing }
        }
    }

    component HeaderLabel: Label {
        font.pointSize: LingmoUI.Theme.fontSize * 0.9
        color: LingmoUI.Theme.disabledTextColor
        elide: Text.ElideRight
    }

    delegate: Item {
        id: _row
        width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
        height: control.itemHeight

        readonly property bool selected: ListView.isCurrentItem
        readonly property color secondaryColor: selected ? LingmoUI.Theme.highlightedTextColor
                                                         : LingmoUI.Theme.disabledTextColor

        Rectangle {
            anchors.fill: parent
            radius: LingmoUI.Theme.smallRadius
            color: _row.selected ? LingmoUI.Theme.highlightColor
                 : _mouse.containsMouse ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                                  LingmoUI.Theme.textColor.b, 0.07)
                 : index % 2 === 1 ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                             LingmoUI.Theme.textColor.b, LingmoUI.Theme.darkMode ? 0.035 : 0.025)
                 : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: LingmoUI.Units.smallSpacing
            anchors.rightMargin: LingmoUI.Units.smallSpacing
            spacing: LingmoUI.Units.smallSpacing

            Item {
                Layout.preferredWidth: LingmoUI.Units.iconSizes.smallMedium
                Layout.preferredHeight: LingmoUI.Units.iconSizes.smallMedium

                Image {
                    anchors.fill: parent
                    sourceSize: Qt.size(width, height)
                    source: "image://icontheme/" + model.iconName
                    visible: !_thumb.visible
                    asynchronous: true
                }

                Image {
                    id: _thumb
                    anchors.fill: parent
                    sourceSize: Qt.size(width, height)
                    source: model.thumbnail ? model.thumbnail : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    asynchronous: true
                    layer.enabled: visible
                    layer.effect: OpacityMask {
                        maskSource: Rectangle { width: _thumb.width; height: _thumb.height; radius: 4 }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                text: model.fileName
                elide: Text.ElideMiddle
                textFormat: Text.PlainText
                color: _row.selected ? LingmoUI.Theme.highlightedTextColor : LingmoUI.Theme.textColor
            }

            Label {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: model.location.length > 0 ? model.location : "—"
                elide: Text.ElideLeft
                textFormat: Text.PlainText
                color: _row.secondaryColor
            }

            Label {
                Layout.preferredWidth: 80
                horizontalAlignment: Text.AlignRight
                text: model.fileSize
                color: _row.secondaryColor
            }

            Label {
                Layout.preferredWidth: 130
                Layout.leftMargin: LingmoUI.Units.largeSpacing
                text: model.modified
                elide: Text.ElideRight
                color: _row.secondaryColor
            }
        }

        MouseArea {
            id: _mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: function(mouse) {
                control.forceActiveFocus()
                control.currentIndex = index
                if (mouse.button === Qt.RightButton)
                    control.contextMenuRequested(index)
                else if (mouse.button === Qt.MiddleButton && model.isDir)
                    control.openInNewTabRequested(model.url)
            }
            onDoubleClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton)
                    control.openRequested(index)
            }
        }
    }
}
