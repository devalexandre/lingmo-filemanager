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
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.12
import Qt5Compat.GraphicalEffects

import Lingmo.FileManager 1.0
import LingmoUI.CompatibleModule 3.0 as LingmoUI

Item {
    id: control

    width: GridView.view.cellWidth
    height: GridView.view.cellHeight

    property Item iconArea: _image.visible ? _image : _icon
    property Item labelArea: _label
    property Item background: _background

    property int index: model.index
    property bool hovered: GridView.view.hoveredItem === control
    property bool selected: model.selected
    property bool blank: model.blank
    property var fileName: model.displayName
    property bool isDir: model.isDir
    property var url: model.url
    readonly property bool isDesktop: GridView.view.isDesktopView
    readonly property int iconSize: GridView.view.iconSize

    // For desktop
    visible: isDesktop ? !blank : true

    onSelectedChanged: {
        if (!isDesktop)
            return

        if (selected && !blank) {
            control.grabToImage(function(result) {
                dirModel.addItemDragImage(control.index,
                                          control.x,
                                          control.y,
                                          control.width,
                                          control.height,
                                          result.image)
            })
        }
    }

    // Hit area for hover/selection (FolderGridView maps the mouse into it)
    Item {
        id: _background
        width: Math.max(_iconItem.width, _label.paintedWidth)
        height: _iconItem.height + _label.paintedHeight + LingmoUI.Units.largeSpacing
        x: (parent.width - width) / 2
        y: _iconItem.y
    }

    // Window views: soft rounded tile behind the icon when hovered/selected
    Rectangle {
        visible: !control.isDesktop
        anchors.centerIn: _iconItem
        width: control.iconSize + LingmoUI.Units.largeSpacing
        height: width
        radius: LingmoUI.Theme.mediumRadius
        color: control.selected ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                          LingmoUI.Theme.textColor.b, LingmoUI.Theme.darkMode ? 0.14 : 0.09)
             : control.hovered ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                         LingmoUI.Theme.textColor.b, LingmoUI.Theme.darkMode ? 0.08 : 0.05)
             : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Item {
        id: _iconItem
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: control.isDesktop ? LingmoUI.Units.smallSpacing : LingmoUI.Units.smallSpacing * 1.5
        z: 2

        width: control.iconSize
        height: control.iconSize

        opacity: model.isHidden ? 0.5 : 1.0

        Image {
            id: _icon
            width: control.iconSize
            height: control.iconSize
            anchors.centerIn: parent
            sourceSize: Qt.size(width, height)
            source: "image://icontheme/" + model.iconName
            visible: !_image.visible
            smooth: true
            antialiasing: true
        }

        // Thumbnails: same square size for every picture, rounded corners
        Image {
            id: _image
            anchors.centerIn: parent
            width: control.isDesktop ? parent.width : Math.round(control.iconSize * 0.92)
            height: width
            fillMode: control.isDesktop ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            visible: status === Image.Ready
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            sourceSize: Qt.size(width, height)
            source: model.thumbnail ? model.thumbnail : ""
            asynchronous: true
            cache: false
            smooth: true
            antialiasing: true

            layer.enabled: _image.visible
            layer.effect: OpacityMask {
                maskSource: Item {
                    width: _image.width
                    height: _image.height

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, _image.paintedWidth)
                        height: Math.min(parent.height, _image.paintedHeight)
                        radius: control.isDesktop ? height * 0.1 : LingmoUI.Theme.smallRadius
                    }
                }
            }
        }

        // Hairline frame so light pictures don't melt into the background
        Rectangle {
            visible: _image.visible && !control.isDesktop
            anchors.fill: _image
            radius: LingmoUI.Theme.smallRadius
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                  LingmoUI.Theme.textColor.b, 0.12)
        }

        Image {
            anchors.right: _icon.visible ? _icon.right : _image.right
            anchors.bottom: _icon.visible ? _icon.bottom : _image.bottom
            source: "image://icontheme/emblem-symbolic-link"
            width: 16
            height: 16
            visible: model.isLink
            sourceSize: Qt.size(width, height)
        }

        // Desktop keeps its tinted-icon selection
        ColorOverlay {
            id: _selectedColorOverlay
            anchors.fill: _iconItem
            source: _iconItem
            color: LingmoUI.Theme.highlightColor
            opacity: 0.5
            visible: control.isDesktop && control.selected
        }

        ColorOverlay {
            id: _hoveredColorOverlay
            anchors.fill: _iconItem
            source: _iconItem
            color: "white"
            opacity: 0.3
            visible: control.isDesktop && control.hovered && !control.selected
        }
    }

    Label {
        id: _label
        z: 2
        anchors.top: _iconItem.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: control.isDesktop ? LingmoUI.Units.smallSpacing : LingmoUI.Units.smallSpacing * 1.5
        maximumLineCount: control.selected ? 3 : 2
        horizontalAlignment: Text.AlignHCenter
        width: parent.width - LingmoUI.Units.largeSpacing * 2 - LingmoUI.Units.smallSpacing
        textFormat: Text.PlainText
        elide: Qt.ElideRight
        wrapMode: Text.Wrap
        text: control.fileName
        color: control.isDesktop ? "white"
                                 : control.selected ? LingmoUI.Theme.highlightedTextColor
                                                    : LingmoUI.Theme.textColor
        opacity: model.isHidden ? 0.8 : 1.0
    }

    // Name pill: solid accent when selected (Finder-like)
    Rectangle {
        z: 1
        x: _label.x + (_label.width - _label.paintedWidth) / 2 - LingmoUI.Units.smallSpacing
        y: _label.y - 1
        width: _label.paintedWidth + LingmoUI.Units.smallSpacing * 2
        height: _label.paintedHeight + 2
        radius: control.isDesktop ? 4 : LingmoUI.Theme.smallRadius - 2
        color: LingmoUI.Theme.highlightColor

        opacity: {
            if (control.selected)
                return 1

            if (control.hovered && control.isDesktop)
                return 0.05

            return 0
        }

        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    DropShadow {
        anchors.fill: _label
        source: _label
        z: 1
        horizontalOffset: 1
        verticalOffset: 1
        radius: Math.round(4 * LingmoUI.Units.devicePixelRatio)
        samples: radius * 2 + 1
        spread: 0.35
        color: Qt.rgba(0, 0, 0, 0.3)
        opacity: model.isHidden ? 0.6 : 1
        visible: control.isDesktop && !control.selected
    }
}
