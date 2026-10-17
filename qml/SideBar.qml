/*
 * Copyright (C) 2021 - 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import LingmoUI.CompatibleModule 3.0 as LingmoUI
import Lingmo.FileManager 1.0
import Lingmo.DragDrop 1.0 as DragDrop

import "./Controls"

// Settings-style sidebar: Favorites (drop folders in), Recent files, Places
// (home folders, Trash, Boxes) and Drives with a usage bar.
Rectangle {
    id: sideBar

    property string currentUrl: ""
    property int topInset: 0

    signal clicked(string path)
    signal openInNewWindow(string path)
    signal openInNewTab(string path)
    signal openFile(string path)

    implicitWidth: 230
    color: LingmoUI.Theme.darkMode ? Qt.rgba(0.11, 0.11, 0.15, 0.55) : "#EDEEF2"
    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.Linear } }

    Fm {
        id: _fm
    }

    PlacesModel {
        id: placesModel
        onDeviceSetupDone: sideBar.clicked(filePath)    // open a device once it is mounted
    }

    // Symbolic glyph and tile colour for each standard place
    function placeStyle(iconPath) {
        switch (iconPath) {
        case "folder-home.svg": return { icon: "user-home", color: LingmoUI.Theme.blueColor }
        case "folder-desktop.svg": return { icon: "user-desktop", color: LingmoUI.Theme.purpleColor }
        case "folder-document.svg": return { icon: "folder-documents", color: LingmoUI.Theme.orangeColor }
        case "folder-download.svg": return { icon: "folder-download", color: LingmoUI.Theme.greenColor }
        case "folder-apps.svg": return { icon: "view-app-grid", color: LingmoUI.Theme.blueColor }
        case "folder-music.svg": return { icon: "folder-music", color: LingmoUI.Theme.redColor }
        case "folder-picture.svg": return { icon: "folder-pictures", color: LingmoUI.Theme.pinkColor }
        case "folder-video.svg": return { icon: "folder-videos", color: LingmoUI.Theme.purpleColor }
        case "user-trash.svg": return { icon: Places.trashCount > 0 ? "user-trash-full" : "user-trash", color: LingmoUI.Theme.greyColor }
        case "drive-optical.svg": return { icon: "media-optical", color: LingmoUI.Theme.greyColor }
        case "drive-removable-media-usb.svg": return { icon: "drive-removable-media", color: LingmoUI.Theme.orangeColor }
        default: return { icon: "drive-harddisk", color: LingmoUI.Theme.greyColor }
        }
    }

    function samePath(a, b) {
        return Places.urlToPath(a) === Places.urlToPath(b)
    }

    Flickable {
        id: _flickable
        anchors.fill: parent
        anchors.topMargin: sideBar.topInset
        contentHeight: _column.height + LingmoUI.Units.largeSpacing
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ScrollBar.vertical: ScrollBar {}

        LingmoUI.WheelHandler {
            target: _flickable
        }

        Column {
            id: _column
            x: LingmoUI.Units.largeSpacing * 0.75
            width: _flickable.width - LingmoUI.Units.largeSpacing * 1.5
            spacing: 2

            // ------------------------------------------------------ Favorites
            Item {
                width: parent.width
                height: _favColumn.height

                Column {
                    id: _favColumn
                    width: parent.width
                    spacing: 2

                    SideBarSection {
                        id: _favSection
                        title: qsTr("Favorites")
                    }

                    Repeater {
                        model: _favSection.expanded ? Places.favorites : []

                        SideBarItem {
                            width: _favColumn.width
                            title: modelData.name
                            iconName: modelData.path === Places.homePath ? "user-home" : "folder"
                            tileColor: LingmoUI.Theme.blueColor
                            dimmed: !modelData.exists
                            toolTipText: modelData.path
                            isCurrent: sideBar.samePath(sideBar.currentUrl, modelData.path)
                            onClicked: sideBar.clicked(modelData.path)
                            onMiddleClicked: sideBar.openInNewTab(modelData.path)
                            onRightClicked: _favMenu.popupFor(modelData.path, index)
                        }
                    }

                    // Shown while there are no favorites, or while dragging over
                    Rectangle {
                        visible: _favSection.expanded && (Places.favorites.length === 0 || _favDrop.containsDrag)
                        width: parent.width
                        height: _hint.implicitHeight + LingmoUI.Units.largeSpacing
                        radius: LingmoUI.Theme.mediumRadius
                        color: _favDrop.containsDrag ? Qt.rgba(LingmoUI.Theme.highlightColor.r, LingmoUI.Theme.highlightColor.g,
                                                                LingmoUI.Theme.highlightColor.b, 0.15)
                                                     : "transparent"
                        border.width: 1
                        border.color: _favDrop.containsDrag ? LingmoUI.Theme.highlightColor
                                                            : Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                                                      LingmoUI.Theme.textColor.b, 0.15)

                        Label {
                            id: _hint
                            anchors.fill: parent
                            anchors.margins: LingmoUI.Units.smallSpacing
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.Wrap
                            text: qsTr("Drag folders here")
                            font.pointSize: LingmoUI.Theme.fontSize * 0.9
                            color: LingmoUI.Theme.disabledTextColor
                        }
                    }
                }

                DragDrop.DropArea {
                    id: _favDrop
                    anchors.fill: parent
                    onDrop: function(event) {
                        var urls = event.mimeData.urls
                        for (var i = 0; i < urls.length; ++i)
                            Places.addFavorite(urls[i])
                        event.accept(Qt.LinkAction)
                    }
                }
            }

            // -------------------------------------------------------- Recents
            SideBarSection {
                id: _recentSection
                title: qsTr("Recent")
                visible: Places.recentFiles.length > 0
            }

            Repeater {
                model: _recentSection.expanded ? Places.recentFiles : []

                SideBarItem {
                    width: _column.width
                    title: modelData.name
                    iconSource: "image://icontheme/" + modelData.iconName
                    toolTipText: modelData.path
                    onClicked: sideBar.openFile(modelData.path)
                    onRightClicked: _recentMenu.popupFor(modelData.path)
                }
            }

            // --------------------------------------------------------- Places
            SideBarSection {
                id: _placesSection
                title: qsTr("Places")
            }

            Repeater {
                model: placesModel

                SideBarItem {
                    readonly property var style: sideBar.placeStyle(model.iconPath)
                    readonly property string target: model.path ? model.path : model.url
                    visible: _placesSection.expanded && !model.isDevice
                    width: _column.width
                    title: model.name
                    iconName: style.icon
                    tileColor: style.color
                    badge: model.iconPath === "user-trash.svg" ? Places.trashCount : ""
                    isCurrent: sideBar.samePath(sideBar.currentUrl, target)
                               || (String(model.url).indexOf("trash:") === 0 && String(sideBar.currentUrl).indexOf("trash:") === 0)
                    onClicked: sideBar.clicked(target)
                    onMiddleClicked: sideBar.openInNewTab(target)
                    onRightClicked: _placeMenu.popupFor(index, target, false)
                }
            }

            SideBarItem {
                visible: _placesSection.expanded && Places.boxesExists
                width: _column.width
                title: qsTr("Boxes")
                iconName: "package-x-generic"
                tileColor: LingmoUI.Theme.greenColor
                toolTipText: qsTr("Isolated app boxes")
                isCurrent: sideBar.samePath(sideBar.currentUrl, Places.boxesPath)
                onClicked: sideBar.clicked(Places.boxesPath)
                onMiddleClicked: sideBar.openInNewTab(Places.boxesPath)
            }

            // --------------------------------------------------------- Drives
            SideBarSection {
                id: _drivesSection
                title: qsTr("Drives")
            }

            Repeater {
                model: placesModel

                SideBarItem {
                    readonly property var style: sideBar.placeStyle(model.iconPath)
                    readonly property string target: model.path ? model.path : model.url
                    readonly property var storage: (Places.revision, model.setupNeeded ? ({ valid: false })
                                                                                          : Places.storageInfo(target))
                    visible: _drivesSection.expanded && model.isDevice
                    width: _column.width
                    title: model.name
                    iconName: style.icon
                    tileColor: style.color
                    usage: storage.valid ? storage.fraction : -1
                    toolTipText: storage.valid ? storage.usageText : ""
                    isCurrent: !model.setupNeeded && sideBar.samePath(sideBar.currentUrl, target)
                    onClicked: {
                        if (model.setupNeeded)
                            placesModel.requestSetup(index)
                        else
                            sideBar.clicked(target)
                    }
                    onMiddleClicked: if (!model.setupNeeded) sideBar.openInNewTab(target)
                    onRightClicked: _placeMenu.popupFor(index, target, true)
                }
            }
        }
    }

    // ---------------------------------------------------------------- menus
    LingmoUI.DesktopMenu {
        id: _placeMenu

        property int row: -1
        property string target: ""
        property bool device: false
        readonly property var item: row >= 0 ? placesModel.get(row) : ({})

        function popupFor(r, t, d) {
            row = r
            target = t
            device = d
            popup()
        }

        MenuItem {
            text: qsTr("Open")
            onTriggered: {
                if (_placeMenu.item.isDevice && _placeMenu.item.setupNeeded)
                    placesModel.requestSetup(_placeMenu.row)
                else
                    sideBar.clicked(_placeMenu.target)
            }
        }

        MenuItem {
            text: qsTr("Open in New Tab")
            enabled: !_placeMenu.item.setupNeeded
            onTriggered: sideBar.openInNewTab(_placeMenu.target)
        }

        MenuItem {
            text: qsTr("Open in new window")
            enabled: !_placeMenu.item.setupNeeded
            onTriggered: sideBar.openInNewWindow(_placeMenu.target)
        }

        MenuItem {
            text: (Places.favorites, Places.isFavorite(_placeMenu.target)) ? qsTr("Remove from Favorites") : qsTr("Add to Favorites")
            visible: !_placeMenu.device && _placeMenu.target.indexOf("trash:") !== 0
            height: visible ? implicitHeight : 0
            onTriggered: {
                if (Places.isFavorite(_placeMenu.target))
                    Places.removeFavorite(_placeMenu.target)
                else
                    Places.addFavorite(_placeMenu.target)
            }
        }

        MenuItem {
            text: qsTr("Eject")
            visible: _placeMenu.device && !_placeMenu.item.setupNeeded && _placeMenu.item.isOpticalDisc
                     && _placeMenu.target !== _fm.rootPath()
            height: visible ? implicitHeight : 0
            onTriggered: placesModel.requestEject(_placeMenu.row)
        }

        MenuItem {
            text: qsTr("Unmount")
            visible: _placeMenu.device && !_placeMenu.item.setupNeeded && !_placeMenu.item.isOpticalDisc
                     && _placeMenu.target !== _fm.rootPath()
            height: visible ? implicitHeight : 0
            onTriggered: placesModel.requestTeardown(_placeMenu.row)
        }
    }

    LingmoUI.DesktopMenu {
        id: _favMenu

        property string path: ""
        property int row: -1

        function popupFor(p, r) {
            path = p
            row = r
            popup()
        }

        MenuItem {
            text: qsTr("Open")
            onTriggered: sideBar.clicked(_favMenu.path)
        }

        MenuItem {
            text: qsTr("Open in New Tab")
            onTriggered: sideBar.openInNewTab(_favMenu.path)
        }

        MenuItem {
            text: qsTr("Open in new window")
            onTriggered: sideBar.openInNewWindow(_favMenu.path)
        }

        MenuSeparator {}

        MenuItem {
            text: qsTr("Move Up")
            enabled: _favMenu.row > 0
            onTriggered: Places.moveFavorite(_favMenu.row, _favMenu.row - 1)
        }

        MenuItem {
            text: qsTr("Move Down")
            enabled: _favMenu.row < Places.favorites.length - 1
            onTriggered: Places.moveFavorite(_favMenu.row, _favMenu.row + 1)
        }

        MenuItem {
            text: qsTr("Remove from Favorites")
            onTriggered: Places.removeFavorite(_favMenu.path)
        }
    }

    LingmoUI.DesktopMenu {
        id: _recentMenu

        property string path: ""

        function popupFor(p) {
            path = p
            popup()
        }

        MenuItem {
            text: qsTr("Open")
            onTriggered: sideBar.openFile(_recentMenu.path)
        }

        MenuItem {
            text: qsTr("Show in Folder")
            onTriggered: sideBar.clicked(_recentMenu.path)
        }
    }
}
