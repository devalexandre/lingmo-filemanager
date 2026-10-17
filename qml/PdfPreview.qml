import QtQuick
import QtQuick.Pdf

// First page of a PDF. Loaded through a Loader so the file manager still
// starts when the QtPdf QML module isn't installed.
Item {
    id: control

    property url source

    PdfDocument {
        id: _document
        source: control.source
    }

    PdfPageImage {
        anchors.fill: parent
        document: _document
        currentFrame: 0
        fillMode: Image.PreserveAspectFit
        sourceSize.width: width * 2
        asynchronous: true
    }
}
