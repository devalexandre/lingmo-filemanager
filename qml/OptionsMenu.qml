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
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// Sort menu of the toolbar (the view itself is chosen with the segmented control)
LingmoUI.DesktopMenu {
    id: control

    // Checkable item whose check mark always mirrors "on" (a click would
    // otherwise replace the binding with a plain toggle)
    component CheckItem: MenuItem {
        id: _item
        property bool on: false
        signal chosen()
        checkable: true
        checked: on
        onTriggered: {
            chosen()
            _item.checked = Qt.binding(function() { return _item.on })
        }
    }

    CheckItem {
        text: qsTr("Name")
        on: settings.sortMode === 0
        onChosen: settings.sortMode = 0
    }

    CheckItem {
        text: qsTr("Date")
        on: settings.sortMode === 2
        onChosen: settings.sortMode = 2
    }

    CheckItem {
        text: qsTr("Type")
        on: settings.sortMode === 6
        onChosen: settings.sortMode = 6
    }

    CheckItem {
        text: qsTr("Size")
        on: settings.sortMode === 1
        onChosen: settings.sortMode = 1
    }

    MenuSeparator {}

    CheckItem {
        text: qsTr("Ascending")
        on: !settings.sortDesc
        onChosen: settings.sortDesc = false
    }

    CheckItem {
        text: qsTr("Descending")
        on: settings.sortDesc
        onChosen: settings.sortDesc = true
    }

    MenuSeparator {}

    CheckItem {
        text: qsTr("Folders First")
        on: settings.sortDirsFirst
        onChosen: settings.sortDirsFirst = !settings.sortDirsFirst
    }
}
