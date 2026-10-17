/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

// The thumbnail cache follows the freedesktop.org Thumbnail Managing Standard,
// like Lingmo Photos: md5 of the file URI, flavor folders, Thumb::URI,
// Thumb::MTime and Thumb::Size, private permissions, regeneration when the file
// changes, failure markers in fail/lingmo-filemanager.

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QTemporaryDir>
#include <QTest>

#include "thumbnailer/thumbnailcache.h"

class ThumbnailTest : public QObject
{
    Q_OBJECT

private:
    static bool writeImage(const QString &path, int w, int h, const QDateTime &mtime = QDateTime())
    {
        QDir().mkpath(QFileInfo(path).absolutePath());
        QImage image(w, h, QImage::Format_RGB32);
        for (int y = 0; y < h; ++y)
            for (int x = 0; x < w; ++x)
                image.setPixel(x, y, qRgb(x % 256, y % 256, 120));
        if (!image.save(path, "PNG"))
            return false;
        if (mtime.isValid()) {
            QFile f(path);
            if (!f.open(QIODevice::ReadWrite))
                return false;
            return f.setFileTime(mtime, QFileDevice::FileModificationTime);
        }
        return true;
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        const QString home = m_dir.filePath(QStringLiteral("home"));
        QDir().mkpath(home);
        qputenv("HOME", home.toLocal8Bit());
        qputenv("XDG_CACHE_HOME", (home + QStringLiteral("/.cache")).toLocal8Bit());
        m_cache = home + QStringLiteral("/.cache/thumbnails");
    }

    void namesFollowTheSpec()
    {
        // The spec's own example
        QCOMPARE(Thumbnails::fileNameFor(QStringLiteral("/home/jens/photos/me.png")),
                 QStringLiteral("c6ee772d9e49320e97ec29a7eb5b1697.png"));
        QCOMPARE(Thumbnails::uriFor(QStringLiteral("/home/ana/Imagens/Praia 2024/foto #1.jpg")),
                 QStringLiteral("file:///home/ana/Imagens/Praia%202024/foto%20%231.jpg"));
        const QByteArray md5 = QCryptographicHash::hash("file:///tmp/x.jpg", QCryptographicHash::Md5).toHex();
        QCOMPARE(Thumbnails::fileNameFor(QStringLiteral("/tmp/x.jpg")), QString::fromLatin1(md5) + QStringLiteral(".png"));

        QCOMPARE(Thumbnails::cacheRoot(), m_cache);
        QCOMPARE(Thumbnails::flavorFor(64), QStringLiteral("normal"));
        QCOMPARE(Thumbnails::flavorFor(256), QStringLiteral("large"));
        QCOMPARE(Thumbnails::flavorFor(300), QStringLiteral("x-large"));
        QCOMPARE(Thumbnails::flavorFor(2000), QStringLiteral("xx-large"));
        QCOMPARE(Thumbnails::pathFor(QStringLiteral("/tmp/x.jpg"), 100),
                 m_cache + QStringLiteral("/normal/") + QString::fromLatin1(md5) + QStringLiteral(".png"));
        QVERIFY(Thumbnails::failPathFor(QStringLiteral("/tmp/x.jpg"))
                    .startsWith(m_cache + QStringLiteral("/fail/lingmo-filemanager/")));
    }

    void imageUrlsKeepOddNames()
    {
        const QStringList names = {QStringLiteral("/tmp/a b/foto #1?.png"), QStringLiteral("/tmp/100%25 done.jpg"),
                                   QStringLiteral("/tmp/ação/é.webp")};
        for (const QString &name : names) {
            const QString url = Thumbnails::imageUrlFor(name, 1700000000);
            QVERIFY(url.startsWith(QStringLiteral("image://thumbnailer/")));
            const QString id = url.mid(QStringLiteral("image://thumbnailer/").size());
            QCOMPARE(Thumbnails::pathFromImageId(id), name);
        }
        QCOMPARE(Thumbnails::pathFromImageId(QStringLiteral("file:///tmp/a%20b.png")), QStringLiteral("/tmp/a b.png"));
        QVERIFY(Thumbnails::canThumbnail(QStringLiteral("image/png")));
        QVERIFY(Thumbnails::canThumbnail(QStringLiteral("image/jpeg")));
        QVERIFY(!Thumbnails::canThumbnail(QStringLiteral("image/svg+xml")));
        QVERIFY(!Thumbnails::canThumbnail(QStringLiteral("text/plain")));
    }

    void createsReusesAndRefreshes()
    {
        const QString photo = m_dir.filePath(QStringLiteral("pics/wide shot.png"));
        const QDateTime t1(QDate(2024, 1, 2), QTime(3, 4, 5));
        QVERIFY(writeImage(photo, 1000, 500, t1));

        const QImage thumb = Thumbnails::load(photo, 200);
        QCOMPARE(thumb.size(), QSize(256, 128));   // large flavor, aspect kept

        const QString stored = Thumbnails::pathFor(photo, 256);
        QVERIFY(QFileInfo::exists(stored));
        const QImage onDisk(stored, "png");
        QCOMPARE(onDisk.text(QStringLiteral("Thumb::URI")), Thumbnails::uriFor(photo));
        QCOMPARE(onDisk.text(QStringLiteral("Thumb::MTime")), QString::number(t1.toSecsSinceEpoch()));
        QCOMPARE(onDisk.text(QStringLiteral("Thumb::Size")), QString::number(QFileInfo(photo).size()));
        QVERIFY(Thumbnails::isValid(stored, photo));
        QCOMPARE(QFileInfo(stored).permissions() & (QFile::ReadGroup | QFile::ReadOther), QFile::Permissions());
        QCOMPARE(QFileInfo(m_cache + QStringLiteral("/large")).permissions() & QFile::ReadOther, QFile::Permissions());

        // Read from the cache: put a red marker with the right keys and see it come back
        QImage marker(256, 128, QImage::Format_RGB32);
        marker.fill(Qt::red);
        marker.setText(QStringLiteral("Thumb::URI"), Thumbnails::uriFor(photo));
        marker.setText(QStringLiteral("Thumb::MTime"), QString::number(t1.toSecsSinceEpoch()));
        QVERIFY(marker.save(stored, "PNG"));
        QCOMPARE(Thumbnails::load(photo, 256).pixel(5, 5), qRgb(255, 0, 0));

        // Newer file: the MTime no longer matches, the thumbnail is made again
        QFile f(photo);
        QVERIFY(f.open(QIODevice::ReadWrite));
        QVERIFY(f.setFileTime(QDateTime(QDate(2025, 6, 7), QTime(8, 9, 10)), QFileDevice::FileModificationTime));
        f.close();
        QVERIFY(!Thumbnails::isValid(stored, photo));
        QVERIFY(Thumbnails::load(photo, 256).pixel(5, 5) != qRgb(255, 0, 0));
        QVERIFY(Thumbnails::isValid(stored, photo));

        // Small sizes use the normal flavor; small images aren't enlarged
        QCOMPARE(Thumbnails::load(photo, 96).size(), QSize(128, 64));
        QVERIFY(QFileInfo::exists(Thumbnails::pathFor(photo, 96)));
        const QString tiny = m_dir.filePath(QStringLiteral("pics/tiny.png"));
        QVERIFY(writeImage(tiny, 40, 30));
        QCOMPARE(Thumbnails::load(tiny, 256).size(), QSize(40, 30));
    }

    void failureMarker()
    {
        const QString broken = m_dir.filePath(QStringLiteral("pics/broken.jpg"));
        QFile f(broken);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("not a jpeg");
        f.close();

        QVERIFY(Thumbnails::load(broken, 128).isNull());
        const QString fail = Thumbnails::failPathFor(broken);
        QVERIFY(QFileInfo::exists(fail));
        QVERIFY(Thumbnails::isValid(fail, broken));
        QVERIFY(!QFileInfo::exists(Thumbnails::pathFor(broken, 128)));
        QVERIFY(Thumbnails::load(m_dir.filePath(QStringLiteral("pics/missing.png")), 128).isNull());
    }

    void noThumbnailsOfThumbnails()
    {
        const QString stored = Thumbnails::pathFor(m_dir.filePath(QStringLiteral("pics/wide shot.png")), 256);
        QVERIFY(QFileInfo::exists(stored));
        QVERIFY(!Thumbnails::load(stored, 128).isNull());
        QVERIFY(!QFileInfo::exists(Thumbnails::pathFor(stored, 128)));
    }

private:
    QTemporaryDir m_dir;
    QString m_cache;
};

QTEST_GUILESS_MAIN(ThumbnailTest)
#include "thumbnailtest.moc"
