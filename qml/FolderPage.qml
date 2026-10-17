/*
 * Copyright (C) 2021 - 2026 LingmoOS Team.
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

import Lingmo.FileManager 1.0 as FM
import LingmoUI.CompatibleModule 3.0 as LingmoUI

import "./Dialogs"
import "./Controls"

// One tab: the folder (grid or list), the search results, the status bar
// and the optional preview pane
Item {
    id: folderPage

    property alias currentUrl: dirModel.url
    property alias model: dirModel
    property Item currentView: _viewLoader.item
    property string initialUrl: ""

    // Search (driven by the toolbar)
    property bool searchActive: false
    property string searchQuery: ""
    readonly property alias searchModel: _searchModel

    readonly property bool isTrash: dirModel.url.indexOf("trash:") === 0
    readonly property string title: isTrash ? qsTr("Trash") : FM.Places.displayNameForPath(dirModel.url)

    // What the preview pane shows (refreshed on selection changes)
    property var previewInfo: ({})

    signal requestPathEditor()
    signal openInNewTab(string url)
    signal closeTabRequested()

    onCurrentUrlChanged: {
        searchActive = false
        searchQuery = ""

        if (!_viewLoader.item)
            return

        _viewLoader.item.reset()
        _viewLoader.item.forceActiveFocus()
        _previewTimer.restart()
    }

    Rectangle {
        anchors.fill: parent
        color: LingmoUI.Theme.secondBackgroundColor
        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.Linear } }
    }

    FM.FolderModel {
        id: dirModel
        viewAdapter: viewAdapter
        sortMode: settings.sortMode
        sortDesc: settings.sortDesc
        sortDirsFirst: settings.sortDirsFirst
        // The right-click "Sort By" menu changes the model: keep the choice
        onSortModeChanged: settings.sortMode = sortMode
        onSortDescChanged: settings.sortDesc = sortDesc
        onSortDirsFirstChanged: settings.sortDirsFirst = sortDirsFirst
        // showHiddenFiles: settings.showHiddenFiles

        Component.onCompleted: {
            if (folderPage.initialUrl)
                dirModel.url = folderPage.initialUrl
            else if (arg)
                dirModel.url = arg
            else
                dirModel.url = dirModel.homePath()
        }

        // For new folder rename.
        onCurrentIndexChanged: {
            _viewLoader.item.currentIndex = dirModel.currentIndex
        }

        onSelectionCountChanged: _previewTimer.restart()
        onStatusChanged: _previewTimer.restart()
        onOpenInNewTabRequested: function(url) { folderPage.openInNewTab(url) }
    }

    FM.SearchModel {
        id: _searchModel
        rootPath: dirModel.url
        showHidden: dirModel.showHiddenFiles
        query: folderPage.searchActive ? folderPage.searchQuery : ""
    }

    Connections {
        target: dirModel

        function onNotification(text) {
            root.showPassiveNotification(text, 3000)
        }

        // Scroll to item.
        function onScrollToItem(index) {
            _viewLoader.item.currentIndex = index
        }
    }

    // Preview info is read from disk: wait for selection changes to settle
    Timer {
        id: _previewTimer
        interval: 120
        onTriggered: folderPage.updatePreview()
    }

    function updatePreview() {
        if (!settings.showPreview)
            return
        if (searchActive) {
            var path = _searchModel.pathAt(_searchView.currentIndex)
            previewInfo = path ? FM.Places.fileInfo(path) : ({})
        } else {
            previewInfo = dirModel.selectedItemInfo()
        }
    }

    Connections {
        target: settings
        function onShowPreviewChanged() { folderPage.updatePreview() }
    }

    FM.ItemViewAdapter {
        id: viewAdapter
        adapterView: _viewLoader.item
        adapterModel: _viewLoader.item && _viewLoader.item.positioner ? _viewLoader.item.positioner : dirModel
        adapterIconSize: 40
        adapterVisibleArea: _viewLoader.item ? Qt.rect(_viewLoader.item.contentX, _viewLoader.item.contentY,
                                                       _viewLoader.item.contentWidth, _viewLoader.item.contentHeight)
                                             : Qt.rect(0, 0, 0, 0)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                id: _viewArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                Loader {
                    id: _viewLoader
                    anchors.fill: parent
                    visible: !folderPage.searchActive
                    asynchronous: true
                    sourceComponent: switch (settings.viewMethod) {
                                     case 0: return _listViewComponent
                                     case 1: return _gridViewComponent
                                     }

                    onSourceComponentChanged: {
                        if (!_viewLoader.item)
                            return
                        // Focus
                        _viewLoader.item.forceActiveFocus()

                        // ShortCut
                        shortCut.install(_viewLoader.item)
                    }

                    onLoaded: {
                        _viewLoader.item.forceActiveFocus()
                        shortCut.install(_viewLoader.item)
                    }
                }

                SearchResultsView {
                    id: _searchView
                    anchors.fill: parent
                    topMargin: LingmoUI.Units.smallSpacing
                    leftMargin: LingmoUI.Units.largeSpacing
                    rightMargin: LingmoUI.Units.largeSpacing
                    bottomMargin: LingmoUI.Units.smallSpacing
                    visible: folderPage.searchActive && count > 0
                    model: _searchModel

                    onCurrentIndexChanged: _previewTimer.restart()
                    onOpenRequested: function(row) { folderPage.openSearchResult(row) }
                    onContextMenuRequested: function(row) { _searchMenu.popupFor(row) }
                    onOpenInNewTabRequested: function(url) { folderPage.openInNewTab(url) }
                }

                // ------------------------------------------------ empty states
                EmptyState {
                    anchors.fill: parent
                    visible: !folderPage.searchActive && !folderPage.isTrash
                             && (dirModel.status === FM.FolderModel.Ready || dirModel.status === FM.FolderModel.Canceled)
                             && _viewLoader.status === Loader.Ready
                             && _viewLoader.item.count === 0
                    iconName: "folder-open"
                    title: qsTr("Empty folder")
                    text: qsTr("Drag files here or create a new folder.")
                }

                EmptyState {
                    anchors.fill: parent
                    visible: !folderPage.searchActive && folderPage.isTrash && FM.Places.trashCount === 0
                             && (dirModel.status === FM.FolderModel.Ready || dirModel.status === FM.FolderModel.Canceled)
                             && _viewLoader.status === Loader.Ready
                             && _viewLoader.item.count === 0
                    iconName: "user-trash"
                    title: qsTr("Trash is empty")
                    text: qsTr("Items you delete stay here until you empty the trash.")
                }

                EmptyState {
                    anchors.fill: parent
                    visible: folderPage.searchActive && folderPage.searchQuery.trim().length === 0
                    iconName: "system-search"
                    title: qsTr("Search in “%1”").arg(folderPage.title)
                    text: qsTr("Type part of a file name. Subfolders are searched too.")
                }

                EmptyState {
                    anchors.fill: parent
                    visible: folderPage.searchActive && folderPage.searchQuery.trim().length > 0
                             && !_searchModel.searching && _searchModel.count === 0
                    iconName: "edit-find"
                    title: qsTr("No results")
                    text: qsTr("Nothing named “%1” in “%2”.").arg(folderPage.searchQuery.trim()).arg(folderPage.title)
                }
            }

            // -------------------------------------------------- status bar
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                               LingmoUI.Theme.textColor.b, 0.08)
            }

            Item {
                id: _statusBar
                Layout.fillWidth: true
                Layout.preferredHeight: 30

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: LingmoUI.Units.largeSpacing
                    anchors.rightMargin: LingmoUI.Units.largeSpacing
                    spacing: LingmoUI.Units.largeSpacing

                    LingmoUI.BusyIndicator {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: 16
                        Layout.preferredWidth: 16
                        running: visible
                        visible: dirModel.status === FM.FolderModel.Listing
                                 || (folderPage.searchActive && _searchModel.searching)
                    }

                    Label {
                        font.pointSize: LingmoUI.Theme.fontSize * 0.9
                        color: LingmoUI.Theme.disabledTextColor
                        text: {
                            if (folderPage.searchActive) {
                                var n = _searchModel.count
                                var t = n === 1 ? qsTr("%1 result").arg(n) : qsTr("%1 results").arg(n)
                                return _searchModel.truncated ? t + " · " + qsTr("showing the first ones") : t
                            }
                            var c = dirModel.count
                            var s = c === 1 ? qsTr("%1 item").arg(c) : qsTr("%1 items").arg(c)
                            if (dirModel.selectionCount >= 1) {
                                s += " · " + qsTr("%1 selected").arg(dirModel.selectionCount)
                                if (dirModel.selectedItemSize && !folderPage.isTrash)
                                    s += " (" + dirModel.selectedItemSize + ")"
                            }
                            return s
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        id: _emptyTrashBtn
                        Layout.preferredHeight: 24
                        text: qsTr("Empty Trash")
                        font.pointSize: LingmoUI.Theme.fontSize * 0.9
                        onClicked: dirModel.emptyTrash()
                        visible: folderPage.isTrash && !folderPage.searchActive
                                 && _viewLoader.item && _viewLoader.item.count > 0
                        focusPolicy: Qt.NoFocus
                    }

                    // Zoom (icon view)
                    RowLayout {
                        visible: settings.viewMethod === 1 && !folderPage.searchActive
                        spacing: LingmoUI.Units.smallSpacing

                        SymbolicIcon {
                            name: "zoom-out"
                            size: 12
                            color: LingmoUI.Theme.disabledTextColor
                        }

                        Slider {
                            id: _zoomSlider
                            Layout.preferredWidth: 110
                            from: 48
                            to: settings.maximumIconSize
                            stepSize: 8
                            value: settings.gridIconSize
                            focusPolicy: Qt.NoFocus
                            onMoved: settings.gridIconSize = Math.round(value)

                            ToolTip.visible: hovered || pressed
                            ToolTip.text: qsTr("Zoom (Ctrl+wheel)")
                            ToolTip.delay: 600
                        }

                        SymbolicIcon {
                            name: "zoom-in"
                            size: 12
                            color: LingmoUI.Theme.disabledTextColor
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: settings.showPreview
            Layout.fillHeight: true
            width: 1
            color: Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                           LingmoUI.Theme.textColor.b, 0.08)
        }

        PreviewPane {
            visible: settings.showPreview
            Layout.fillHeight: true
            Layout.preferredWidth: 280
            info: folderPage.previewInfo
            selectionCount: folderPage.searchActive ? (_searchView.currentIndex >= 0 ? 1 : 0) : dirModel.selectionCount
            selectionSize: dirModel.selectedItemSize
        }
    }

    // Menu for a search result
    LingmoUI.DesktopMenu {
        id: _searchMenu

        property int row: -1

        function popupFor(r) {
            row = r
            popup()
        }

        MenuItem {
            text: qsTr("Open")
            onTriggered: folderPage.openSearchResult(_searchMenu.row)
        }

        MenuItem {
            text: qsTr("Open in New Tab")
            visible: _searchModel.isDirAt(_searchMenu.row)
            height: visible ? implicitHeight : 0
            onTriggered: folderPage.openInNewTab(_searchModel.pathAt(_searchMenu.row))
        }

        MenuItem {
            text: qsTr("Show in Folder")
            onTriggered: {
                var path = _searchModel.pathAt(_searchMenu.row)
                dirModel.url = path.substring(0, path.lastIndexOf("/")) || "/"
            }
        }
    }

    function openSearchResult(row) {
        var path = _searchModel.pathAt(row)
        if (!path)
            return
        if (_searchModel.isDirAt(row))
            dirModel.url = path
        else
            dirModel.openPath(path)
    }

    function rename() {
        _viewLoader.item.rename()
    }

    Component.onCompleted: {
        dirModel.requestRename.connect(rename)
    }

    Component {
        id: _gridViewComponent

        FolderGridView {
            id: _gridView
            model: dirModel
            delegate: FolderGridItem {}

            leftMargin: LingmoUI.Units.largeSpacing
            rightMargin: LingmoUI.Units.largeSpacing
            topMargin: LingmoUI.Units.smallSpacing
            bottomMargin: LingmoUI.Units.smallSpacing
            minimumIconSize: 48

            onIconSizeChanged: {
                // Save
                settings.gridIconSize = Math.round(_gridView.iconSize)
            }

            // The zoom slider writes the setting: follow it
            Connections {
                target: settings
                function onGridIconSizeChanged() {
                    if (Math.round(_gridView.iconSize) !== settings.gridIconSize)
                        _gridView.iconSize = settings.gridIconSize
                }
            }

            onOpenInNewTabRequested: function(url) { folderPage.openInNewTab(url) }
        }
    }

    Component {
        id: _listViewComponent

        FolderListView {
            id: _folderListView
            model: dirModel

            topMargin: LingmoUI.Units.smallSpacing
            leftMargin: LingmoUI.Units.largeSpacing
            rightMargin: LingmoUI.Units.largeSpacing
            bottomMargin: LingmoUI.Units.smallSpacing
            spacing: 0

            delegate: FolderListItem {}

            onSortRequested: function(mode) {
                if (settings.sortMode === mode) {
                    settings.sortDesc = !settings.sortDesc
                } else {
                    settings.sortMode = mode
                    settings.sortDesc = false
                }
            }

            onOpenInNewTabRequested: function(url) { folderPage.openInNewTab(url) }
        }
    }

    Component {
        id: rubberBandObject

        FM.RubberBand {
            id: rubberBand

            width: 0
            height: 0
            z: 99999
            color: LingmoUI.Theme.highlightColor

            function close() {
                opacityAnimation.restart()
            }

            OpacityAnimator {
                id: opacityAnimation
                target: rubberBand
                to: 0
                from: 1
                duration: 150

                easing {
                    bezierCurve: [0.4, 0.0, 1, 1]
                    type: Easing.Bezier
                }

                onFinished: {
                    rubberBand.visible = false
                    rubberBand.enabled = false
                    rubberBand.destroy()
                }
            }
        }
    }

    FM.ShortCut {
        id: shortCut

        onOpen: {
            dirModel.openSelected()
        }
        onCopy: {
            dirModel.copy()
        }
        onCut: {
            dirModel.cut()
        }
        onPaste: {
            dirModel.paste()
        }
        onRename: {
            dirModel.requestRename()
        }
        onOpenPathEditor: {
            folderPage.requestPathEditor()
        }
        onSelectAll: {
            dirModel.selectAll()
        }
        onBackspace: {
            dirModel.up()
        }
        onDeleteFile: {
            dirModel.keyDeletePress()
        }
        onRefresh: {
            dirModel.refresh()
        }
        onKeyPressed: {
            dirModel.keyboardSearch(text)
        }
        onShowHidden: {
            dirModel.showHiddenFiles = !dirModel.showHiddenFiles
        }
        onClose: {
            folderPage.closeTabRequested()
        }
        onUndo: {
            dirModel.undo()
        }
    }

    function openUrl(url) {
        dirModel.url = url
        if (_viewLoader.item)
            _viewLoader.item.forceActiveFocus()
    }

    function goBack() {
        dirModel.goBack()
    }

    function goForward() {
        dirModel.goForward()
    }

    function focusView() {
        if (searchActive && _searchView.count > 0)
            _searchView.forceActiveFocus()
        else if (_viewLoader.item)
            _viewLoader.item.forceActiveFocus()
    }
}
