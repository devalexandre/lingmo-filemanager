/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import Qt5Compat.GraphicalEffects
import LingmoUI.CompatibleModule 3.0 as LingmoUI

import "./Controls"

// One row of a column in the column view: icon, name and, for folders, a
// chevron. In the open folder's column (a FolderListView) the view does the
// mouse handling; in the other columns (passive) the row reports clicks.
Item {
    id: _item
    width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
    height: ListView.view.itemHeight

    Accessible.name: model.fileName
    Accessible.role: Accessible.ListItem

    // What FolderListView expects from its delegates
    property Item iconArea: _image.visible ? _image : _icon
    property Item labelArea: _label
    property Item labelArea2: _chevronBox

    property int index: model.index
    readonly property ListView view: ListView.view
    readonly property bool passive: view.passive === true
    property bool hovered: passive ? _mouse.containsMouse : view.hoveredItem === _item
    property bool selected: passive ? false : model.selected
    // Passive columns mark the folder that is open to their right
    readonly property bool marked: passive && view.markedPath !== "" && model.path === view.markedPath
    property bool blank: model.blank
    property bool isDir: model.isDir
    property var url: model.url

    readonly property color textColor: selected ? LingmoUI.Theme.highlightedTextColor : LingmoUI.Theme.textColor

    Rectangle {
        anchors.fill: parent
        radius: LingmoUI.Theme.smallRadius
        color: _item.selected ? LingmoUI.Theme.highlightColor
             : _item.marked ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                      LingmoUI.Theme.textColor.b, LingmoUI.Theme.darkMode ? 0.16 : 0.11)
             : _item.hovered ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                       LingmoUI.Theme.textColor.b, 0.06)
             : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: LingmoUI.Units.smallSpacing
        anchors.rightMargin: LingmoUI.Units.smallSpacing
        spacing: LingmoUI.Units.smallSpacing

        Item {
            id: _iconBox
            Layout.fillHeight: true
            Layout.preferredWidth: _item.view.listIconSize
            opacity: model.isHidden ? 0.5 : 1.0

            Image {
                id: _icon
                anchors.centerIn: parent
                width: _item.view.listIconSize
                height: width
                sourceSize: Qt.size(width, height)
                source: "image://icontheme/" + model.iconName
                visible: !_image.visible
                asynchronous: true
            }

            Image {
                id: _image
                anchors.centerIn: parent
                width: _item.view.listIconSize
                height: width
                sourceSize: Qt.size(width, height)
                source: model.thumbnail ? model.thumbnail : ""
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                asynchronous: true

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: _image.width
                        height: _image.height
                        radius: 3
                    }
                }
            }
        }

        Label {
            id: _label
            Layout.fillWidth: true
            text: model.fileName
            color: _item.textColor
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            opacity: model.isHidden ? 0.8 : 1.0
        }

        Item {
            id: _chevronBox
            Layout.preferredWidth: 12
            Layout.preferredHeight: 12

            SymbolicIcon {
                anchors.fill: parent
                visible: _item.isDir
                name: "pan-end"
                size: 12
                color: _item.textColor
                opacity: _item.selected ? 1 : 0.55
            }
        }
    }

    MouseArea {
        id: _mouse
        anchors.fill: parent
        enabled: _item.passive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton) {
                if (_item.isDir)
                    _item.view.openInNewTabRequested(_item.url.toString())
                return
            }
            _item.view.itemClicked(_item.index, model.path, _item.isDir)
        }
        onDoubleClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton)
                _item.view.itemActivated(_item.index, model.path, _item.isDir)
        }
    }
}
