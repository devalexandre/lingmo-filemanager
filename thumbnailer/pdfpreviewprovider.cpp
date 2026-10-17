/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

#include "pdfpreviewprovider.h"

#include <QUrl>
#include <poppler-qt6.h>

PdfPreviewProvider::PdfPreviewProvider()
    : QQuickImageProvider(QQuickImageProvider::Image, QQmlImageProviderBase::ForceAsynchronousImageLoading)
{
}

QImage PdfPreviewProvider::renderFirstPage(const QString &path, const QSize &bounds)
{
    std::unique_ptr<Poppler::Document> document = Poppler::Document::load(path);
    if (!document || document->isLocked() || document->numPages() < 1)
        return QImage();

    std::unique_ptr<Poppler::Page> page = document->page(0);
    if (!page)
        return QImage();

    document->setRenderHint(Poppler::Document::Antialiasing);
    document->setRenderHint(Poppler::Document::TextAntialiasing);

    // Page size is in points (1/72 inch): pick the DPI that fits the bounds
    const QSizeF points = page->pageSizeF();
    const QSize target = bounds.isValid() && !bounds.isEmpty() ? bounds : QSize(600, 600);
    if (points.isEmpty())
        return QImage();
    const double scale = qMin(target.width() / points.width(), target.height() / points.height());
    const double dpi = qBound(18.0, 72.0 * scale, 300.0);

    return page->renderToImage(dpi, dpi);
}

QImage PdfPreviewProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    const QUrl url(id);
    const QString path = url.isLocalFile() ? url.toLocalFile() : id;
    QImage image = renderFirstPage(path, requestedSize);
    if (size)
        *size = image.size();
    return image;
}
