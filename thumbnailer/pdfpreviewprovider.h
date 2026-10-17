/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

#ifndef PDFPREVIEWPROVIDER_H
#define PDFPREVIEWPROVIDER_H

#include <QQuickImageProvider>

// image://pdfpreview/<file url>: first page of a PDF rendered with Poppler.
// Requests run off the GUI thread (ForceAsynchronousImageLoading).
class PdfPreviewProvider : public QQuickImageProvider
{
public:
    PdfPreviewProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

    static QImage renderFirstPage(const QString &path, const QSize &bounds);
};

#endif // PDFPREVIEWPROVIDER_H
