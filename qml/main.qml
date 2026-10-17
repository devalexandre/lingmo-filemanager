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
import QtQuick.Window 2.12
import Qt.labs.platform 1.0 as Platform
import LingmoUI.CompatibleModule 3.0 as LingmoUI
import Lingmo.FileManager 1.0 as FM

import "./Controls"

LingmoUI.Window {
    id: root
    width: settings.width
    height: settings.height
    minimumWidth: 900
    minimumHeight: 580
    visible: true
    title: qsTr("File Manager")

    background.opacity: LingmoUI.Theme.darkMode ? 0.88 : 0.97
    header.height: 48
    contentTopMargin: 0

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property QtObject settings: GlobalSettings { }

    // ------------------------------------------------------------------ tabs
    property int currentTab: 0
    property Item currentPage: null

    function updateCurrentPage() {
        currentPage = _pages.itemAt(currentTab)
        if (currentPage) {
            _pathBar.updateUrl(currentPage.currentUrl)
            _searchField.text = currentPage.searchQuery
            currentPage.focusView()
        }
    }

    onCurrentTabChanged: updateCurrentPage()

    function newTab(url) {
        _tabsModel.append({ "url": url ? url : (currentPage ? currentPage.currentUrl : ""), "title": "" })
        currentTab = _tabsModel.count - 1
    }

    function closeTab(index) {
        if (_tabsModel.count <= 1) {
            root.close()
            return
        }
        var next = currentTab
        if (index < currentTab || (index === currentTab && currentTab === _tabsModel.count - 1))
            next = currentTab - 1
        _tabsModel.remove(index)
        currentTab = Math.max(0, next)
        updateCurrentPage()
    }

    ListModel {
        id: _tabsModel
        ListElement { url: ""; title: "" }
    }

    // ---------------------------------------------------------------- search
    function startSearch() {
        if (!currentPage)
            return
        currentPage.searchActive = true
        _searchField.text = currentPage.searchQuery
        _searchField.forceActiveFocus()
        _searchField.selectAll()
    }

    function stopSearch() {
        if (!currentPage)
            return
        currentPage.searchActive = false
        currentPage.searchQuery = ""
        _searchField.text = ""
        currentPage.focusView()
    }

    // Typing restarts the search only once it pauses
    Timer {
        id: _searchDelay
        interval: 180
        onTriggered: if (root.currentPage) root.currentPage.searchQuery = _searchField.text
    }

    onClosing: {
        if (root.visibility !== Window.Maximized &&
                root.visibility !== Window.FullScreen) {
            settings.width = root.width
            settings.height = root.height
        }
    }

    LingmoUI.WindowBlur {
        view: root
        geometry: Qt.rect(root.x, root.y, root.width, root.height)
        windowRadius: root.windowRadius
        enabled: true
    }

    OptionsMenu {
        id: _sortMenu
    }

    LingmoUI.AboutDialog {
        id: _aboutDialog
        name: qsTr("File Manager")
        description: qsTr("A file manager designed for LingmoOS.")
        iconSource: "image://icontheme/file-system-manager"
    }

    // ------------------------------------------------------------- shortcuts
    Shortcut { sequence: "Ctrl+T"; onActivated: root.newTab() }
    Shortcut { sequence: "Ctrl+W"; onActivated: root.closeTab(root.currentTab) }
    Shortcut { sequences: [StandardKey.Find]; onActivated: root.startSearch() }
    Shortcut {
        sequence: "Ctrl+L"
        onActivated: {
            if (currentPage && currentPage.searchActive)
                root.stopSearch()
            _pathBar.openEditor()
        }
    }
    Shortcut { sequence: "Escape"; enabled: currentPage !== null && currentPage.searchActive; onActivated: root.stopSearch() }
    Shortcut { sequence: "Alt+Left"; onActivated: if (currentPage) currentPage.goBack() }
    Shortcut { sequence: "Alt+Right"; onActivated: if (currentPage) currentPage.goForward() }
    Shortcut { sequence: "Alt+Up"; onActivated: if (currentPage) currentPage.model.up() }
    Shortcut { sequences: ["Ctrl+Tab", "Ctrl+PgDown"]; onActivated: root.currentTab = (root.currentTab + 1) % _tabsModel.count }
    Shortcut { sequences: ["Ctrl+Shift+Tab", "Ctrl+PgUp"]; onActivated: root.currentTab = (root.currentTab + _tabsModel.count - 1) % _tabsModel.count }
    Shortcut { sequence: "Ctrl+1"; onActivated: settings.viewMethod = 1 }
    Shortcut { sequence: "Ctrl+2"; onActivated: settings.viewMethod = 0 }
    Shortcut { sequence: "Ctrl+3"; onActivated: settings.viewMethod = 2 }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: if (currentPage) currentPage.model.newFolder() }
    Shortcut { sequence: "Alt+P"; onActivated: settings.showPreview = !settings.showPreview }

    // ----------------------------------------------------------- global menu
    Platform.MenuBar {
        Platform.Menu {
            title: qsTr("File")

            Platform.MenuItem {
                text: qsTr("New Tab")
                onTriggered: root.newTab()
            }

            Platform.MenuItem {
                text: qsTr("New Folder")
                onTriggered: if (currentPage) currentPage.model.newFolder()
            }

            Platform.MenuSeparator {}

            Platform.MenuItem {
                text: qsTr("Properties")
                onTriggered: if (currentPage) currentPage.model.openPropertiesDialog()
            }

            Platform.MenuSeparator {}

            Platform.MenuItem {
                text: qsTr("Close Tab")
                onTriggered: root.closeTab(root.currentTab)
            }

            Platform.MenuItem {
                text: qsTr("Quit")
                onTriggered: root.close()
            }
        }

        Platform.Menu {
            title: qsTr("Edit")

            Platform.MenuItem {
                text: qsTr("Select All")
                onTriggered: if (currentPage) currentPage.model.selectAll()
            }

            Platform.MenuSeparator {}

            Platform.MenuItem {
                text: qsTr("Cut")
                onTriggered: if (currentPage) currentPage.model.cut()
            }

            Platform.MenuItem {
                text: qsTr("Copy")
                onTriggered: if (currentPage) currentPage.model.copy()
            }

            Platform.MenuItem {
                text: qsTr("Paste")
                onTriggered: if (currentPage) currentPage.model.paste()
            }

            Platform.MenuSeparator {}

            Platform.MenuItem {
                text: qsTr("Search")
                onTriggered: root.startSearch()
            }
        }

        Platform.Menu {
            title: qsTr("View")

            Platform.MenuItem {
                text: qsTr("Icons")
                checkable: true
                checked: settings.viewMethod === 1
                onTriggered: settings.viewMethod = 1
            }

            Platform.MenuItem {
                text: qsTr("List")
                checkable: true
                checked: settings.viewMethod === 0
                onTriggered: settings.viewMethod = 0
            }

            Platform.MenuItem {
                text: qsTr("Columns")
                checkable: true
                checked: settings.viewMethod === 2
                onTriggered: settings.viewMethod = 2
            }

            Platform.MenuSeparator {}

            Platform.MenuItem {
                text: qsTr("Preview Pane")
                checkable: true
                checked: settings.showPreview
                onTriggered: settings.showPreview = !settings.showPreview
            }
        }

        Platform.Menu {
            title: qsTr("Help")

            Platform.MenuItem {
                text: qsTr("About")
                onTriggered: _aboutDialog.show()
            }
        }
    }

    // --------------------------------------------------------------- toolbar
    headerItem: Item {
        id: _toolbar

        RowLayout {
            anchors.fill: parent
            anchors.rightMargin: LingmoUI.Units.largeSpacing
            anchors.topMargin: LingmoUI.Units.smallSpacing
            anchors.bottomMargin: LingmoUI.Units.smallSpacing
            spacing: LingmoUI.Units.smallSpacing

            // Start the toolbar where the content starts (the window
            // buttons sit over the sidebar)
            Item {
                Layout.preferredWidth: Math.max(0, _sideBar.width - (_toolbar.parent ? _toolbar.parent.x : 0))
                                       + LingmoUI.Units.smallSpacing
            }

            IconButton {
                iconName: Qt.application.layoutDirection === Qt.RightToLeft ? "go-next" : "go-previous"
                tipText: qsTr("Back (Alt+Left)")
                onClicked: if (currentPage) currentPage.goBack()
            }

            IconButton {
                iconName: Qt.application.layoutDirection === Qt.RightToLeft ? "go-previous" : "go-next"
                tipText: qsTr("Forward (Alt+Right)")
                onClicked: if (currentPage) currentPage.goForward()
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                Layout.leftMargin: LingmoUI.Units.smallSpacing

                PathBar {
                    id: _pathBar
                    anchors.fill: parent
                    visible: !(currentPage && currentPage.searchActive)
                    onItemClicked: function(path) { if (currentPage) currentPage.openUrl(path) }
                    onEditorAccepted: function(path) { if (currentPage) currentPage.openUrl(path) }
                    onMiddleClicked: function(path) { root.newTab(path) }
                }

                TextField {
                    id: _searchField
                    anchors.fill: parent
                    visible: currentPage !== null && currentPage.searchActive
                    leftPadding: LingmoUI.Units.largeSpacing * 2.5
                    rightPadding: LingmoUI.Units.largeSpacing * 2.5
                    selectByMouse: true
                    placeholderText: currentPage ? qsTr("Search in “%1”").arg(currentPage.title) : ""
                    onTextEdited: _searchDelay.restart()
                    onAccepted: {
                        _searchDelay.stop()
                        if (currentPage) {
                            currentPage.searchQuery = text
                            currentPage.focusView()
                        }
                    }
                    Keys.onEscapePressed: root.stopSearch()
                    Keys.onDownPressed: if (currentPage) currentPage.focusView()

                    SymbolicIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: LingmoUI.Units.largeSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        name: "edit-find"
                        color: LingmoUI.Theme.disabledTextColor
                    }

                    IconButton {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        iconSize: 12
                        iconName: "window-close"
                        tipText: qsTr("Close search (Esc)")
                        onClicked: root.stopSearch()
                    }
                }
            }

            IconButton {
                iconName: "edit-find"
                tipText: qsTr("Search (Ctrl+F)")
                checkable: true
                checked: currentPage !== null && currentPage.searchActive
                onClicked: {
                    if (currentPage && currentPage.searchActive)
                        root.stopSearch()
                    else
                        root.startSearch()
                }
            }

            SegmentedControl {
                Layout.leftMargin: LingmoUI.Units.smallSpacing
                // Segment order: icons, list, columns; settings.viewMethod: 1, 0, 2
                readonly property var methods: [1, 0, 2]
                model: [
                    { icon: "view-grid", text: qsTr("Icons (Ctrl+1)") },
                    { icon: "view-list", text: qsTr("List (Ctrl+2)") },
                    { icon: "view-column", text: qsTr("Columns (Ctrl+3)") }
                ]
                currentIndex: Math.max(0, methods.indexOf(settings.viewMethod))
                onActivated: function(index) { settings.viewMethod = methods[index] }
            }

            IconButton {
                id: _sortButton
                iconName: settings.sortDesc ? "view-sort-descending" : "view-sort-ascending"
                tipText: qsTr("Sort")
                onClicked: _sortMenu.popup(_sortButton, 0, _sortButton.height + 4)
            }

            IconButton {
                iconName: "folder-new"
                tipText: qsTr("New Folder (Ctrl+Shift+N)")
                enabled: currentPage !== null && !currentPage.isTrash
                onClicked: if (currentPage) currentPage.model.newFolder()
            }

            IconButton {
                iconName: "view-dual"
                tipText: qsTr("Preview Pane (Alt+P)")
                checkable: true
                checked: settings.showPreview
                onClicked: settings.showPreview = !settings.showPreview
            }
        }
    }

    // --------------------------------------------------------------- content
    RowLayout {
        anchors.fill: parent
        spacing: 0

        SideBar {
            id: _sideBar
            Layout.fillHeight: true
            Layout.preferredWidth: 230
            topInset: root.header.height
            currentUrl: currentPage ? currentPage.currentUrl : ""
            onClicked: function(path) { if (currentPage) currentPage.openUrl(path) }
            onOpenInNewWindow: function(path) { if (currentPage) currentPage.model.openInNewWindow(path) }
            onOpenInNewTab: function(path) { root.newTab(path) }
            onOpenFile: function(path) { if (currentPage) currentPage.model.openPath(path) }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: root.header.height
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: _tabStrip.implicitHeight + LingmoUI.Units.smallSpacing
                visible: _tabsModel.count > 1
                color: LingmoUI.Theme.secondBackgroundColor

                TabStrip {
                    id: _tabStrip
                    anchors.fill: parent
                    anchors.topMargin: LingmoUI.Units.smallSpacing / 2
                    anchors.bottomMargin: LingmoUI.Units.smallSpacing / 2
                    model: _tabsModel
                    currentIndex: root.currentTab
                    onActivated: function(index) { root.currentTab = index }
                    onCloseRequested: function(index) { root.closeTab(index) }
                    onNewTabRequested: root.newTab()
                }
            }

            StackLayout {
                id: _stack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentTab

                Repeater {
                    id: _pages
                    model: _tabsModel

                    onItemAdded: function(index, item) {
                        if (index === root.currentTab)
                            Qt.callLater(root.updateCurrentPage)
                    }

                    FolderPage {
                        id: _folderPage
                        // (FolderPage has its own "model" property: read the tab's url from the ListModel)
                        initialUrl: _tabsModel.get(index).url

                        onTitleChanged: _tabsModel.setProperty(index, "title", title)
                        Component.onCompleted: _tabsModel.setProperty(index, "title", title)

                        onCurrentUrlChanged: {
                            if (_folderPage === root.currentPage)
                                _pathBar.updateUrl(currentUrl)
                        }
                        onRequestPathEditor: _pathBar.openEditor()
                        onOpenInNewTab: function(url) { root.newTab(url) }
                        onCloseTabRequested: root.closeTab(index)
                        onSearchActiveChanged: {
                            if (!searchActive && _folderPage === root.currentPage)
                                _searchField.text = ""
                        }
                    }
                }
            }
        }
    }
}
