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
import LingmoUI.CompatibleModule 3.0 as LingmoUI
import Lingmo.FileManager 1.0 as FM

// Column view (Miller columns, like Finder's): the folders from rootPath down
// to the open one side by side. The open folder (dirModel) is the active
// column: selection, drag and drop, rename and the context menu work there as
// in the list view. A selected folder is shown in the column after it, a
// selected file is previewed there.
//
// Keys: Up/Down move in the column, Right (or Return) enters the selected
// folder, Left goes back to the parent keeping the folder selected.
FocusScope {
    id: control

    // ------------------------------------------------ what FolderPage expects
    property alias currentIndex: _active.currentIndex
    readonly property alias count: _active.count
    readonly property var positioner: null
    readonly property alias contentX: _active.contentX
    readonly property alias contentY: _active.contentY
    readonly property alias contentWidth: _active.contentWidth
    readonly property alias contentHeight: _active.contentHeight
    // The list showing the open folder: drags start there, shortcuts go there
    readonly property alias activeView: _active
    // An empty open folder is shown inside its column, not over the whole view
    readonly property bool handlesEmptyState: true

    signal openInNewTabRequested(string url)

    function reset() {
        _active.reset()
    }

    function rename() {
        _active.rename()
    }

    // Return / double click: folders open in the next column, files in their app
    function openSelected() {
        if (dirModel.selectionCount === 1 && selectedInfo.valid && selectedInfo.isDir)
            navigateTo(selectedInfo.path || selectedInfo.url, "")
        else
            dirModel.openSelected()
    }

    // ------------------------------------------------------------ the columns
    readonly property int columnWidth: 240
    readonly property int previewWidth: 300
    readonly property int itemHeight: Math.round(LingmoUI.Units.fontMetrics.height + LingmoUI.Units.largeSpacing * 1.1)
    readonly property int listIconSize: LingmoUI.Units.iconSizes.smallMedium

    // First column. It stays while moving inside it; going above it, or
    // anywhere else, starts the columns again there.
    property string rootPath: ""
    // The folders before the open one (rootPath first)
    property var ancestorPaths: []

    // The single selected item of the open folder, for the next column
    property var selectedInfo: ({})

    function isLocal(path) {
        return path.length > 0 && path.charAt(0) === "/"
    }

    function parentOf(path) {
        if (!isLocal(path) || path === "/")
            return ""
        var i = path.lastIndexOf("/")
        return i <= 0 ? "/" : path.substring(0, i)
    }

    function isUnder(path, root) {
        if (!isLocal(path) || !isLocal(root))
            return path === root
        return root === "/" || path === root || path.indexOf(root + "/") === 0
    }

    function syncColumns() {
        var url = dirModel.url
        if (rootPath === "" || !isUnder(url, rootPath))
            rootPath = url

        var chain = []
        var p = url
        while (p !== rootPath) {
            p = parentOf(p)
            if (p === "")
                break
            chain.unshift(p)
        }

        // Keep the columns that didn't change: their folders stay listed
        var keep = 0
        while (keep < chain.length && keep < _ancestors.count && _ancestors.get(keep).path === chain[keep])
            ++keep
        if (_ancestors.count > keep)
            _ancestors.remove(keep, _ancestors.count - keep)
        for (var i = keep; i < chain.length; ++i)
            _ancestors.append({ "path": chain[i] })
        ancestorPaths = chain

        selectedInfo = ({})
        Qt.callLater(scrollToEnd)
    }

    // Opens a folder as the active column and selects one of its items
    // (a path; "" for the first item; undefined for none)
    function navigateTo(path, select) {
        if (!path)
            return
        if (dirModel.url !== path)
            dirModel.url = path
        if (select !== undefined && select !== null)
            dirModel.selectWhenListed(select)
        _active.forceActiveFocus()
    }

    function goToParent() {
        var parent = parentOf(dirModel.url)
        if (parent !== "")
            navigateTo(parent, dirModel.url)
    }

    function enterSelected() {
        if (dirModel.selectionCount === 1 && selectedInfo.valid && selectedInfo.isDir)
            navigateTo(selectedInfo.path || selectedInfo.url, "")
    }

    // A click in a column other than the open folder's: that column becomes
    // the active one, with the clicked item selected
    function columnItemClicked(columnPath, itemPath) {
        navigateTo(columnPath, itemPath)
    }

    function columnItemActivated(columnPath, itemPath, isDir) {
        if (isDir) {
            navigateTo(itemPath, "")
        } else {
            navigateTo(columnPath, itemPath)
            dirModel.openPath(itemPath)
        }
    }

    function scrollToEnd() {
        _flick.contentX = Math.max(0, _row.width - _flick.width)
    }

    function updateSelectedInfo() {
        selectedInfo = dirModel.selectionCount === 1 ? dirModel.selectedItemInfo() : ({})
    }

    ListModel {
        id: _ancestors
    }

    Connections {
        target: dirModel
        function onUrlChanged() { control.syncColumns() }
        function onSelectionCountChanged() { _selectionTimer.restart() }
        function onStatusChanged() { _selectionTimer.restart() }
    }

    Connections {
        target: _active
        function onCurrentIndexChanged() { _selectionTimer.restart() }
    }

    // Wait for the selection to settle (click = clear + select)
    Timer {
        id: _selectionTimer
        interval: 60
        onTriggered: control.updateSelectedInfo()
    }

    Component.onCompleted: syncColumns()

    Flickable {
        id: _flick
        anchors.fill: parent
        contentWidth: _row.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        // Dragging in a column selects or drags files, it doesn't pan
        interactive: false
        clip: true

        Behavior on contentX {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        ScrollBar.horizontal: ScrollBar {
            policy: _row.width > _flick.width ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        onWidthChanged: Qt.callLater(control.scrollToEnd)

        Row {
            id: _row
            height: _flick.height

            onWidthChanged: Qt.callLater(control.scrollToEnd)

            // Folders before the open one
            Repeater {
                model: _ancestors

                delegate: FolderColumnList {
                    columns: control
                    path: model.path
                    markedPath: index + 1 < control.ancestorPaths.length ? control.ancestorPaths[index + 1]
                                                                          : dirModel.url
                }
            }

            // The open folder
            Item {
                width: control.columnWidth
                height: _row.height

                FolderListView {
                    id: _active
                    anchors.fill: parent
                    anchors.rightMargin: 1
                    focus: true
                    model: dirModel
                    delegate: FolderColumnItem {}
                    showHeader: false
                    customOpen: true
                    itemHeight: control.itemHeight
                    listIconSize: control.listIconSize
                    topMargin: LingmoUI.Units.smallSpacing
                    bottomMargin: LingmoUI.Units.smallSpacing
                    leftMargin: LingmoUI.Units.smallSpacing
                    rightMargin: LingmoUI.Units.smallSpacing
                    spacing: 0

                    onOpenRequested: control.openSelected()
                    onOpenInNewTabRequested: function(url) { control.openInNewTabRequested(url) }

                    Keys.onRightPressed: function(event) {
                        if (!editor || !editor.targetItem)
                            control.enterSelected()
                    }
                    Keys.onLeftPressed: function(event) {
                        if (!editor || !editor.targetItem)
                            control.goToParent()
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: _active.count === 0
                             && (dirModel.status === FM.FolderModel.Ready || dirModel.status === FM.FolderModel.Canceled)
                    text: qsTr("Empty folder")
                    color: LingmoUI.Theme.disabledTextColor
                }

                FolderColumnSeparator {}
            }

            // The selected folder's contents, or the selected file's preview
            Loader {
                height: _row.height
                sourceComponent: !control.selectedInfo.valid ? null
                               : control.selectedInfo.isDir ? _nextFolder : _preview
            }
        }
    }

    Component {
        id: _nextFolder

        FolderColumnList {
            columns: control
            height: _row.height
            path: control.selectedInfo.path || control.selectedInfo.url || ""
            markedPath: ""
        }
    }

    Component {
        id: _preview

        PreviewPane {
            width: control.previewWidth
            height: _row.height
            info: control.selectedInfo
            selectionCount: 1
            selectionSize: dirModel.selectedItemSize
        }
    }
}
