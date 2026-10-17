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
import LingmoUI.CompatibleModule 3.0 as LingmoUI
import Lingmo.FileManager 1.0 as FM

// A column of the column view that isn't the open folder: it lists its own
// folder, marks the item open to its right, and a click makes it the open
// folder (FolderColumnsView.columnItemClicked)
Item {
    id: _column

    // The FolderColumnsView
    property Item columns
    property string path
    // The item open to the right (highlighted)
    property string markedPath

    width: columns.columnWidth
    height: parent ? parent.height : 0

    FM.FolderModel {
        id: _model
        url: _column.path
        sortMode: settings.sortMode
        sortDesc: settings.sortDesc
        sortDirsFirst: settings.sortDirsFirst
        showHiddenFiles: dirModel.showHiddenFiles

        onListingCompleted: _list.showMarked()
    }

    ListView {
        id: _list
        anchors.fill: parent
        anchors.rightMargin: 1
        topMargin: LingmoUI.Units.smallSpacing
        bottomMargin: LingmoUI.Units.smallSpacing
        leftMargin: LingmoUI.Units.smallSpacing
        rightMargin: LingmoUI.Units.smallSpacing
        model: _model
        clip: true
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        // FolderColumnItem's passive mode
        readonly property bool passive: true
        readonly property string markedPath: _column.markedPath
        readonly property int itemHeight: _column.columns.itemHeight
        readonly property int listIconSize: _column.columns.listIconSize

        signal itemClicked(int index, string path, bool isDir)
        signal itemActivated(int index, string path, bool isDir)
        signal openInNewTabRequested(string url)

        delegate: FolderColumnItem {}

        onItemClicked: function(index, path, isDir) { _column.columns.columnItemClicked(_column.path, path) }
        onItemActivated: function(index, path, isDir) { _column.columns.columnItemActivated(_column.path, path, isDir) }
        onOpenInNewTabRequested: function(url) { _column.columns.openInNewTabRequested(url) }

        function showMarked() {
            var row = _model.rowForPath(_column.markedPath)
            if (row >= 0)
                positionViewAtIndex(row, ListView.Contain)
        }
    }

    onMarkedPathChanged: _list.showMarked()

    Label {
        anchors.centerIn: parent
        visible: _list.count === 0 && _model.status === FM.FolderModel.Ready
        text: qsTr("Empty folder")
        color: LingmoUI.Theme.disabledTextColor
    }

    FolderColumnSeparator {}
}
