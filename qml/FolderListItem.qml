/*
 * Copyright (C) 2021 LingmoOS Team.
 *
 * Author:     revenmartin <revenmartin@gmail.com>
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
import Lingmo.FileManager 1.0

// One row of the list view: icon + name | size | modified | kind
Item {
    id: _listItem
    width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
    height: ListView.view.itemHeight

    Accessible.name: model.fileName
    Accessible.role: Accessible.Canvas

    property Item iconArea: _image.visible ? _image : _icon
    property Item labelArea: _label
    property Item labelArea2: _sizeLabel

    property int index: model.index
    property bool hovered: ListView.view.hoveredItem === _listItem
    property bool selected: model.selected
    property bool blank: model.blank
    property bool isDir: model.isDir
    property var url: model.url
    readonly property ListView view: ListView.view
    readonly property color secondaryColor: selected ? LingmoUI.Theme.highlightedTextColor
                                                     : LingmoUI.Theme.disabledTextColor

    // Zebra striping, hover and selection
    Rectangle {
        id: _background
        anchors.fill: parent
        radius: LingmoUI.Theme.smallRadius
        color: _listItem.selected ? LingmoUI.Theme.highlightColor
             : _listItem.hovered ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                           LingmoUI.Theme.textColor.b, 0.07)
             : _listItem.index % 2 === 1 ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                                   LingmoUI.Theme.textColor.b, LingmoUI.Theme.darkMode ? 0.035 : 0.025)
             : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
        id: _mainLayout
        anchors.fill: parent
        anchors.leftMargin: LingmoUI.Units.smallSpacing
        anchors.rightMargin: LingmoUI.Units.smallSpacing
        spacing: LingmoUI.Units.smallSpacing

        Item {
            id: iconItem
            Layout.fillHeight: true
            Layout.preferredWidth: _listItem.view.listIconSize
            opacity: model.isHidden ? 0.5 : 1.0

            Image {
                id: _icon
                anchors.centerIn: iconItem
                width: _listItem.view.listIconSize
                height: width
                sourceSize.width: width
                sourceSize.height: height
                source: "image://icontheme/" + model.iconName
                visible: !_image.visible
                asynchronous: true
            }

            Image {
                id: _image
                width: _listItem.view.listIconSize
                height: width
                anchors.centerIn: iconItem
                sourceSize: Qt.size(width, height)
                source: model.thumbnail ? model.thumbnail : ""
                visible: _image.status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: _image.width
                        height: _image.height
                        radius: 4
                    }
                }
            }

            Image {
                anchors.right: _icon.visible ? _icon.right : _image.right
                anchors.bottom: _icon.visible ? _icon.bottom : _image.bottom
                source: "image://icontheme/emblem-symbolic-link"
                width: 12
                height: 12
                visible: model.isLink
                sourceSize: Qt.size(width, height)
            }
        }

        Label {
            id: _label
            text: model.fileName
            Layout.fillWidth: true
            color: _listItem.selected ? LingmoUI.Theme.highlightedTextColor : LingmoUI.Theme.textColor
            textFormat: Text.PlainText
            elide: Qt.ElideMiddle
            opacity: model.isHidden ? 0.8 : 1.0
        }

        Label {
            id: _sizeLabel
            Layout.preferredWidth: _listItem.view.sizeColumnWidth
            text: model.fileSize
            horizontalAlignment: Text.AlignRight
            color: _listItem.secondaryColor
            textFormat: Text.PlainText
            elide: Text.ElideRight
        }

        Label {
            Layout.preferredWidth: _listItem.view.modifiedColumnWidth
            Layout.leftMargin: LingmoUI.Units.largeSpacing
            text: model.modified
            textFormat: Text.PlainText
            color: _listItem.secondaryColor
            elide: Text.ElideRight
        }

        Label {
            visible: _listItem.view.showKindColumn
            Layout.preferredWidth: _listItem.view.kindColumnWidth
            text: model.kind
            textFormat: Text.PlainText
            color: _listItem.secondaryColor
            elide: Text.ElideRight
        }
    }
}
