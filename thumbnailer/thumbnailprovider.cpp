/*
 * Copyright (C) 2021 LingmoOS Team.
 *
 * Author:     Reion Wong <reionwong@gmail.com>
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

#include "thumbnailprovider.h"
#include "thumbnailcache.h"

// id: the percent-encoded path (Thumbnails::imageUrlFor), as the models'
// "thumbnail" role gives it. Runs on QQuickPixmapCache's loader thread (the
// Images are asynchronous).
QImage ThumbnailProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    const QString path = Thumbnails::pathFromImageId(id);
    const int wanted = std::max(requestedSize.width(), requestedSize.height());

    // The flavor's size (128, 256, ...): the view scales it to the item
    const QImage image = Thumbnails::load(path, wanted > 0 ? wanted : 128);
    if (size)
        *size = image.size();
    return image;
}
