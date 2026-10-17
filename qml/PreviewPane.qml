import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import LingmoUI.CompatibleModule 3.0 as LingmoUI
import Lingmo.FileManager 1.0 as FM

import "./Controls"

// Right-hand preview: picture, first PDF page, start of a text file or the
// icon, followed by the file's details (and media details when available).
Item {
    id: control

    // Map from Places.describe(): name, url, path, kind, sizeText, modified...
    property var info: ({})
    // > 1 shows a selection summary instead
    property int selectionCount: 0
    property string selectionSize: ""

    readonly property bool valid: info && info.valid === true
    readonly property var mediaRows: valid && info.isMedia ? FM.Places.mediaInfo(info.path, info.mimeType) : []
    readonly property string textHead: valid && info.isText && info.isLocal ? FM.Places.textHead(info.path, 1500) : ""

    implicitWidth: 280

    Flickable {
        id: _flickable
        anchors.fill: parent
        contentHeight: _layout.implicitHeight + LingmoUI.Units.largeSpacing * 2
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: _layout
            x: LingmoUI.Units.largeSpacing * 1.25
            y: LingmoUI.Units.largeSpacing
            width: _flickable.width - LingmoUI.Units.largeSpacing * 2.5
            spacing: LingmoUI.Units.smallSpacing
            visible: control.valid

            // ---------------------------------------------------- preview
            Item {
                id: _previewBox
                Layout.fillWidth: true
                Layout.preferredHeight: control.selectionCount > 1 ? 120 : Math.min(width, 220)

                // Several items selected: a stack of icons
                Item {
                    anchors.centerIn: parent
                    width: 96
                    height: 96
                    visible: control.selectionCount > 1

                    Repeater {
                        model: 3
                        Image {
                            x: index * 10 - 10
                            y: -index * 6 + 6
                            z: -index
                            width: 80
                            height: 80
                            sourceSize: Qt.size(80, 80)
                            opacity: 1 - index * 0.25
                            source: "image://icontheme/" + (control.info.iconName || "text-x-generic")
                        }
                    }
                }

                Image {
                    id: _picture
                    anchors.fill: parent
                    visible: control.selectionCount <= 1 && control.info.isImage === true && status === Image.Ready
                    source: control.selectionCount <= 1 && control.info.isImage ? control.info.url : ""
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false

                    layer.enabled: visible
                    layer.effect: OpacityMask {
                        maskSource: Item {
                            width: _picture.width
                            height: _picture.height
                            Rectangle {
                                anchors.centerIn: parent
                                width: _picture.paintedWidth
                                height: _picture.paintedHeight
                                radius: LingmoUI.Theme.smallRadius
                            }
                        }
                    }
                }

                Loader {
                    id: _pdfLoader
                    anchors.fill: parent
                    active: control.selectionCount <= 1 && control.info.isPdf === true
                    source: "PdfPreview.qml"
                    onLoaded: item.source = Qt.binding(function() { return control.info.url })
                }

                Rectangle {
                    anchors.fill: parent
                    visible: control.selectionCount <= 1 && control.textHead.length > 0
                    radius: LingmoUI.Theme.smallRadius
                    color: LingmoUI.Theme.alternateBackgroundColor
                    clip: true

                    Label {
                        anchors.fill: parent
                        anchors.margins: LingmoUI.Units.smallSpacing * 1.5
                        text: control.textHead
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAnywhere
                        font.family: "Monospace"
                        font.pointSize: LingmoUI.Theme.fontSize * 0.85
                        color: LingmoUI.Theme.textColor
                    }
                }

                Image {
                    anchors.centerIn: parent
                    width: LingmoUI.Units.iconSizes.enormous
                    height: width
                    sourceSize: Qt.size(width, height)
                    source: "image://icontheme/" + (control.info.iconName || "text-x-generic")
                    visible: control.selectionCount <= 1 && !_picture.visible
                             && !(_pdfLoader.status === Loader.Ready && _pdfLoader.active)
                             && control.textHead.length === 0
                }
            }

            // ------------------------------------------------------- title
            Label {
                Layout.fillWidth: true
                Layout.topMargin: LingmoUI.Units.smallSpacing
                horizontalAlignment: Text.AlignHCenter
                text: control.selectionCount > 1 ? qsTr("%1 items selected").arg(control.selectionCount)
                                                 : (control.info.name || "")
                font.pointSize: LingmoUI.Theme.fontSize * 1.2
                font.bold: true
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: control.selectionCount > 1 ? control.selectionSize
                                                 : [control.info.kind, control.info.sizeText].filter(function(v) { return v }).join(" · ")
                color: LingmoUI.Theme.disabledTextColor
                wrapMode: Text.Wrap
                visible: text.length > 0
            }

            // ----------------------------------------------------- details
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: LingmoUI.Units.largeSpacing
                visible: control.selectionCount <= 1
                implicitHeight: _details.implicitHeight + LingmoUI.Units.largeSpacing * 1.5
                radius: LingmoUI.Theme.mediumRadius
                color: LingmoUI.Theme.alternateBackgroundColor

                ColumnLayout {
                    id: _details
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: LingmoUI.Units.largeSpacing
                    anchors.topMargin: LingmoUI.Units.largeSpacing * 0.75
                    spacing: LingmoUI.Units.smallSpacing

                    Label {
                        text: qsTr("Information")
                        font.bold: true
                        Layout.bottomMargin: 2
                    }

                    Repeater {
                        model: {
                            var i = control.info
                            var rows = []
                            function add(label, value) { if (value) rows.push({ label: label, value: value }) }
                            for (var m = 0; m < control.mediaRows.length; ++m)
                                rows.push(control.mediaRows[m])
                            add(qsTr("Size"), i.sizeText)
                            add(qsTr("Modified"), i.modified)
                            add(qsTr("Created"), i.created)
                            add(qsTr("Last opened"), i.accessed)
                            add(qsTr("Permissions"), i.access ? i.access + "\n" + i.permissions : "")
                            add(qsTr("Owner"), i.owner)
                            add(qsTr("Where"), i.location)
                            return rows
                        }

                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Label {
                                text: modelData.label
                                font.pointSize: LingmoUI.Theme.fontSize * 0.85
                                color: LingmoUI.Theme.disabledTextColor
                            }

                            Label {
                                Layout.fillWidth: true
                                text: modelData.value
                                wrapMode: Text.WrapAnywhere
                                textFormat: Text.PlainText
                            }
                        }
                    }
                }
            }
        }
    }
}
