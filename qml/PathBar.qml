/*
 * Copyright (C) 2021 - 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Lingmo.FileManager 1.0
import LingmoUI.CompatibleModule 3.0 as LingmoUI

import "./Controls"

// Breadcrumb path bar. Folders below home start at "Home"; middle crumbs
// that don't fit fold into a "…" menu. Clicking the empty part of the bar
// (or Ctrl+L) turns it into an editable path.
Item {
    id: control

    property string url: ""
    readonly property bool editing: _pathEditor.visible

    signal itemClicked(string path)
    signal editorAccepted(string path)
    signal middleClicked(string path)

    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        radius: LingmoUI.Theme.smallRadius
        color: Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                       LingmoUI.Theme.textColor.b, LingmoUI.Theme.darkMode ? 0.1 : 0.06)
        border.width: _pathEditor.visible ? 1 : 0
        border.color: LingmoUI.Theme.highlightColor
    }

    PathBarModel {
        id: _pathBarModel
        onUrlChanged: Qt.callLater(control.relayout)
    }

    // Empty space opens the editor
    MouseArea {
        anchors.fill: parent
        visible: !_pathEditor.visible
        onClicked: control.openEditor()
    }

    // Number of crumbs after the first one folded into "…"
    property int collapsed: 0

    function relayout() {
        var n = _repeater.count
        if (n === 0)
            return
        var spacing = _crumbRow.spacing
        var widths = []
        var total = 0
        for (var i = 0; i < n; ++i) {
            var it = _repeater.itemAt(i)
            var w = it ? it.fullWidth : 0
            widths.push(w)
            total += w + spacing
        }
        var available = _crumbArea.width
        var k = 0
        if (total > available && n > 2) {
            var ellipsis = _ellipsis.implicitWidth + _crumbRow.spacing
            var used = total + ellipsis
            for (k = 1; k < n - 1; ++k) {
                used -= widths[k] + spacing
                if (used <= available)
                    break
            }
            k = Math.min(k, n - 2)
        }
        collapsed = k
    }

    Item {
        id: _crumbArea
        anchors.fill: parent
        anchors.leftMargin: 3
        anchors.rightMargin: 3
        visible: !_pathEditor.visible
        clip: true
        onWidthChanged: Qt.callLater(control.relayout)

        Row {
            id: _crumbRow
            height: parent.height
            spacing: 0

            Repeater {
                id: _repeater
                model: _pathBarModel
                onCountChanged: Qt.callLater(control.relayout)

                delegate: Row {
                    id: _crumb
                    readonly property bool hidden: index >= 1 && index <= control.collapsed
                    readonly property bool last: index === _repeater.count - 1
                    readonly property real fullWidth: (index > 0 ? _sep.width : 0) + _button.implicitWidth
                    visible: !hidden
                    height: _crumbRow.height

                    SymbolicIcon {
                        id: _sep
                        visible: index > 0
                        width: visible ? 14 : 0
                        anchors.verticalCenter: parent.verticalCenter
                        name: Qt.application.layoutDirection === Qt.RightToLeft ? "pan-start" : "pan-end"
                        size: 12
                        color: LingmoUI.Theme.disabledTextColor
                    }

                    AbstractButton {
                        id: _button
                        height: parent.height - 6
                        anchors.verticalCenter: parent.verticalCenter
                        hoverEnabled: true
                        focusPolicy: Qt.NoFocus
                        implicitWidth: Math.min(_content.implicitWidth + LingmoUI.Units.largeSpacing, 220)
                        Accessible.name: model.name

                        background: Rectangle {
                            radius: LingmoUI.Theme.smallRadius - 2
                            color: _button.pressed ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                                             LingmoUI.Theme.textColor.b, 0.15)
                                 : _button.hovered ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                                             LingmoUI.Theme.textColor.b, 0.08)
                                 : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        contentItem: Item {
                            RowLayout {
                                id: _content
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, parent.width)
                                spacing: LingmoUI.Units.smallSpacing

                                SymbolicIcon {
                                    visible: model.iconName.length > 0
                                    name: model.iconName
                                    color: _crumb.last ? LingmoUI.Theme.highlightColor : LingmoUI.Theme.textColor
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: model.name
                                    elide: Text.ElideMiddle
                                    font.bold: _crumb.last
                                    color: _crumb.last ? LingmoUI.Theme.highlightColor : LingmoUI.Theme.textColor
                                }
                            }
                        }

                        onClicked: control.itemClicked(model.path)

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.MiddleButton
                            onClicked: control.middleClicked(model.path)
                        }
                    }

                    // "…" lives right after the first crumb
                    Item {
                        visible: index === 0 && control.collapsed > 0
                        width: visible ? _ellipsis.implicitWidth : 0
                        height: parent.height
                    }
                }
            }
        }

        // Folded crumbs
        AbstractButton {
            id: _ellipsis
            visible: control.collapsed > 0 && _repeater.count > 0
            x: _repeater.count > 0 && _repeater.itemAt(0) ? _repeater.itemAt(0).width - implicitWidth : 0
            height: parent.height - 6
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 44
            hoverEnabled: true
            focusPolicy: Qt.NoFocus
            Accessible.name: qsTr("Show hidden path parts")

            background: Rectangle {
                radius: LingmoUI.Theme.smallRadius - 2
                color: _ellipsis.hovered ? Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                                   LingmoUI.Theme.textColor.b, 0.08) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            contentItem: Item {
                SymbolicIcon {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    name: Qt.application.layoutDirection === Qt.RightToLeft ? "pan-start" : "pan-end"
                    size: 12
                    color: LingmoUI.Theme.disabledTextColor
                }

                Label {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    text: "…"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                }
            }

            onClicked: _hiddenMenu.popup(_ellipsis, 0, _ellipsis.height)
        }
    }

    Menu {
        id: _hiddenMenu

        Instantiator {
            model: control.collapsed > 0 ? control.collapsed : 0
            delegate: MenuItem {
                readonly property int row: control.collapsed - index    // nearest folder first
                text: _repeater.itemAt(row) ? _pathBarModel.data(_pathBarModel.index(row, 0), 257) : ""
                onTriggered: control.itemClicked(_pathBarModel.data(_pathBarModel.index(row, 0), 259))
            }
            onObjectAdded: function(index, object) { _hiddenMenu.insertItem(index, object) }
            onObjectRemoved: function(index, object) { _hiddenMenu.removeItem(object) }
        }
    }

    TextField {
        id: _pathEditor
        anchors.fill: parent
        visible: false
        selectByMouse: true
        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
        text: _pathBarModel.url

        onAccepted: {
            control.editorAccepted(text)
            closeEditor()
        }

        Keys.onEscapePressed: closeEditor()

        onActiveFocusChanged: {
            if (!activeFocus)
                closeEditor()
        }
    }

    function updateUrl(url) {
        control.url = url
        _pathBarModel.url = url
    }

    function openEditor() {
        _pathEditor.text = _pathBarModel.url
        _pathEditor.visible = true
        _pathEditor.forceActiveFocus()
        _pathEditor.selectAll()
    }

    function closeEditor() {
        _pathEditor.visible = false
    }
}
