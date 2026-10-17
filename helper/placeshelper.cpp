/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

#include "placeshelper.h"
#include "datehelper.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QLocale>
#include <QMimeDatabase>
#include <QQmlEngine>
#include <QSettings>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QStringDecoder>
#include <QTimer>
#include <QUrl>
#include <QXmlStreamReader>

#include <KFileItem>
#include <KIO/Global>

#ifdef HAVE_KFILEMETADATA
#include <KFileMetaData/ExtractorCollection>
#include <KFileMetaData/Extractor>
#include <KFileMetaData/PropertyInfo>
#include <KFileMetaData/SimpleExtractionResult>
#endif

static const int MaxRecentFiles = 6;

PlacesHelper *PlacesHelper::self()
{
    static PlacesHelper *instance = new PlacesHelper;
    return instance;
}

QObject *PlacesHelper::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(scriptEngine);
    // Shared by every window's engine: never let one of them delete it
    QQmlEngine::setObjectOwnership(self(), QQmlEngine::CppOwnership);
    Q_UNUSED(engine);
    return self();
}

PlacesHelper::PlacesHelper(QObject *parent)
    : QObject(parent)
    , m_watcher(new QFileSystemWatcher(this))
{
    const QString dataHome = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    m_recentFile = dataHome + QStringLiteral("/recently-used.xbel");
    m_trashFilesDir = dataHome + QStringLiteral("/Trash/files");

    loadFavorites();
    reloadRecent();
    reloadTrashCount();

    if (QDir(m_trashFilesDir).exists())
        m_watcher->addPath(m_trashFilesDir);
    watchRecentFile();

    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, [this](const QString &path) {
        if (path == m_trashFilesDir)
            reloadTrashCount();
    });
    // Apps replace the xbel file atomically: the watch is dropped, so re-add it
    connect(m_watcher, &QFileSystemWatcher::fileChanged, this, [this] {
        QTimer::singleShot(300, this, [this] {
            reloadRecent();
            watchRecentFile();
        });
    });

    auto *timer = new QTimer(this);
    timer->setInterval(30 * 1000);
    connect(timer, &QTimer::timeout, this, [this] {
        ++m_revision;
        // The trash folder may only appear after the first deletion
        if (!m_watcher->directories().contains(m_trashFilesDir) && QDir(m_trashFilesDir).exists()) {
            m_watcher->addPath(m_trashFilesDir);
            reloadTrashCount();
        }
        watchRecentFile();
        emit revisionChanged();
    });
    timer->start();
}

void PlacesHelper::watchRecentFile()
{
    if (QFile::exists(m_recentFile) && !m_watcher->files().contains(m_recentFile))
        m_watcher->addPath(m_recentFile);
}

// ---------------------------------------------------------------- favorites

static QSettings &favoritesStore()
{
    static QSettings settings(QStringLiteral("lingmoos"), QStringLiteral("lingmo-filemanager-places"));
    return settings;
}

QString PlacesHelper::localPathFor(const QString &pathOrUrl)
{
    if (pathOrUrl.isEmpty())
        return QString();
    if (pathOrUrl.startsWith(QLatin1Char('/')))
        return QDir::cleanPath(pathOrUrl);
    const QUrl url(pathOrUrl);
    if (url.isLocalFile())
        return QDir::cleanPath(url.toLocalFile());
    return QString();
}

void PlacesHelper::loadFavorites()
{
    m_favoritePaths = favoritesStore().value(QStringLiteral("favorites")).toStringList();
}

void PlacesHelper::saveFavorites()
{
    favoritesStore().setValue(QStringLiteral("favorites"), m_favoritePaths);
    favoritesStore().sync();
    emit favoritesChanged();
}

QVariantList PlacesHelper::favorites() const
{
    QVariantList list;
    for (const QString &path : m_favoritePaths) {
        QVariantMap map;
        map[QStringLiteral("path")] = path;
        map[QStringLiteral("name")] = displayNameForPath(path);
        map[QStringLiteral("exists")] = QFileInfo::exists(path);
        list.append(map);
    }
    return list;
}

bool PlacesHelper::isFavorite(const QString &pathOrUrl) const
{
    return m_favoritePaths.contains(localPathFor(pathOrUrl));
}

void PlacesHelper::addFavorite(const QString &pathOrUrl)
{
    const QString path = localPathFor(pathOrUrl);
    if (path.isEmpty() || m_favoritePaths.contains(path) || !QFileInfo(path).isDir())
        return;
    m_favoritePaths.append(path);
    saveFavorites();
}

void PlacesHelper::removeFavorite(const QString &pathOrUrl)
{
    if (m_favoritePaths.removeAll(localPathFor(pathOrUrl)) > 0)
        saveFavorites();
}

void PlacesHelper::moveFavorite(int from, int to)
{
    if (from < 0 || from >= m_favoritePaths.size() || to < 0 || to >= m_favoritePaths.size() || from == to)
        return;
    m_favoritePaths.move(from, to);
    saveFavorites();
}

QString PlacesHelper::displayNameForPath(const QString &pathOrUrl) const
{
    const QString path = localPathFor(pathOrUrl);
    if (path.isEmpty())
        return pathOrUrl;
    if (path == QDir::homePath())
        return tr("Home");
    if (path == QLatin1String("/"))
        return tr("Computer");
    return QFileInfo(path).fileName();
}

// ------------------------------------------------------------------ recents

void PlacesHelper::reloadRecent()
{
    struct Entry {
        QString path;
        QString visited;
    };
    QList<Entry> entries;

    QFile file(m_recentFile);
    if (file.open(QIODevice::ReadOnly)) {
        QXmlStreamReader xml(&file);
        while (!xml.atEnd()) {
            xml.readNext();
            if (xml.isStartElement() && xml.name() == QLatin1String("bookmark")) {
                const QUrl url(xml.attributes().value(QLatin1String("href")).toString());
                if (!url.isLocalFile())
                    continue;
                QString visited = xml.attributes().value(QLatin1String("visited")).toString();
                const QString modified = xml.attributes().value(QLatin1String("modified")).toString();
                if (modified > visited)
                    visited = modified;
                entries.append({url.toLocalFile(), visited});
            }
        }
    }

    // ISO 8601 timestamps sort as strings
    std::stable_sort(entries.begin(), entries.end(), [](const Entry &a, const Entry &b) {
        return a.visited > b.visited;
    });

    QMimeDatabase db;
    QVariantList list;
    QStringList seen;
    for (const Entry &e : entries) {
        if (list.size() >= MaxRecentFiles)
            break;
        const QFileInfo info(e.path);
        if (seen.contains(e.path) || !info.exists() || info.isDir())
            continue;
        seen.append(e.path);
        QVariantMap map;
        map[QStringLiteral("path")] = e.path;
        map[QStringLiteral("name")] = info.fileName();
        map[QStringLiteral("iconName")] = db.mimeTypeForFile(info).iconName();
        list.append(map);
    }

    if (list != m_recent) {
        m_recent = list;
        emit recentFilesChanged();
    }
}

QVariantList PlacesHelper::recentFiles() const
{
    return m_recent;
}

// -------------------------------------------------------------------- trash

void PlacesHelper::reloadTrashCount()
{
    const int count = QDir(m_trashFilesDir).entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System).count();
    if (count != m_trashCount) {
        m_trashCount = count;
        emit trashCountChanged();
    }
}

int PlacesHelper::trashCount() const
{
    return m_trashCount;
}

// --------------------------------------------------------------- misc paths

QString PlacesHelper::homePath() const
{
    return QDir::homePath();
}

QString PlacesHelper::boxesPath() const
{
    return QDir::homePath() + QStringLiteral("/Boxes");
}

bool PlacesHelper::boxesExists() const
{
    return QFileInfo(boxesPath()).isDir();
}

int PlacesHelper::revision() const
{
    return m_revision;
}

bool PlacesHelper::pdfPreviewAvailable() const
{
#ifdef HAVE_POPPLER
    return true;
#else
    return false;
#endif
}

QString PlacesHelper::urlToPath(const QString &url) const
{
    const QString path = localPathFor(url);
    return path.isEmpty() ? url : path;
}

QVariantMap PlacesHelper::storageInfo(const QString &path) const
{
    QVariantMap map;
    const QString local = localPathFor(path);
    QStorageInfo storage(local);
    if (local.isEmpty() || !storage.isValid() || !storage.isReady() || storage.bytesTotal() <= 0) {
        map[QStringLiteral("valid")] = false;
        return map;
    }

    const qint64 total = storage.bytesTotal();
    const qint64 free = storage.bytesAvailable();
    map[QStringLiteral("valid")] = true;
    map[QStringLiteral("fraction")] = double(total - free) / double(total);
    map[QStringLiteral("freeText")] = KIO::convertSize(free);
    map[QStringLiteral("totalText")] = KIO::convertSize(total);
    map[QStringLiteral("usageText")] = tr("%1 free of %2").arg(KIO::convertSize(free), KIO::convertSize(total));
    return map;
}

// ------------------------------------------------------------------ preview

static QString formatDate(const QDateTime &dt)
{
    if (!dt.isValid())
        return QString();
    return QLocale().toString(dt.toLocalTime(), QStringLiteral("d MMM yyyy, HH:mm"));
}

QVariantMap PlacesHelper::describe(const KFileItem &item)
{
    QVariantMap map;
    if (item.isNull())
        return map;

    const QString mime = item.mimetype();
    const QString local = item.localPath();

    map[QStringLiteral("valid")] = true;
    map[QStringLiteral("name")] = item.text();
    map[QStringLiteral("url")] = item.url().toString();
    map[QStringLiteral("path")] = local;
    map[QStringLiteral("location")] = local.isEmpty() ? item.url().adjusted(QUrl::RemoveFilename).toDisplayString(QUrl::PreferLocalFile)
                                                      : QFileInfo(local).absolutePath();
    map[QStringLiteral("isDir")] = item.isDir();
    map[QStringLiteral("mimeType")] = mime;
    map[QStringLiteral("kind")] = item.mimeComment();
    map[QStringLiteral("iconName")] = item.iconName();

    if (item.isDir()) {
        const int count = local.isEmpty() ? -1 : QDir(local).entryList(QDir::AllEntries | QDir::NoDotAndDotDot).count();
        map[QStringLiteral("sizeText")] = count < 0 ? QString() : (count == 1 ? tr("%1 item").arg(count) : tr("%1 items").arg(count));
    } else {
        map[QStringLiteral("sizeText")] = KIO::convertSize(item.size());
    }

    map[QStringLiteral("modified")] = formatDate(item.time(KFileItem::ModificationTime));
    map[QStringLiteral("created")] = formatDate(item.time(KFileItem::CreationTime));
    map[QStringLiteral("accessed")] = formatDate(item.time(KFileItem::AccessTime));

    QString access;
    if (item.isReadable() && item.isWritable())
        access = tr("Read and write");
    else if (item.isReadable())
        access = tr("Read only");
    else
        access = tr("No access");
    map[QStringLiteral("access")] = access;
    map[QStringLiteral("permissions")] = item.permissionsString();
    map[QStringLiteral("owner")] = item.user();

    map[QStringLiteral("isImage")] = mime.startsWith(QLatin1String("image/"));
    map[QStringLiteral("isPdf")] = mime == QLatin1String("application/pdf");
    map[QStringLiteral("isMedia")] = mime.startsWith(QLatin1String("audio/")) || mime.startsWith(QLatin1String("video/"));
    map[QStringLiteral("isText")] = !item.isDir() && item.currentMimeType().inherits(QStringLiteral("text/plain"));
    map[QStringLiteral("isLocal")] = !local.isEmpty();
    return map;
}

QVariantMap PlacesHelper::fileInfo(const QString &pathOrUrl) const
{
    const QString local = localPathFor(pathOrUrl);
    if (local.isEmpty())
        return QVariantMap();
    KFileItem item(QUrl::fromLocalFile(local));
    return describe(item);
}

QString PlacesHelper::textHead(const QString &pathOrUrl, int maxChars) const
{
    QFile file(localPathFor(pathOrUrl));
    if (!file.open(QIODevice::ReadOnly))
        return QString();

    const QByteArray data = file.read(qMax(256, maxChars) * 2);
    if (data.contains('\0'))
        return QString();
    QStringDecoder decoder(QStringDecoder::Utf8);
    QString text = decoder(data);
    if (decoder.hasError())
        text = QString::fromLatin1(data);
    if (text.size() > maxChars)
        text = text.left(maxChars) + QStringLiteral("…");
    return text;
}

QVariantList PlacesHelper::mediaInfo(const QString &pathOrUrl, const QString &mimeType) const
{
    QVariantList rows;
#ifdef HAVE_KFILEMETADATA
    const QString local = localPathFor(pathOrUrl);
    if (local.isEmpty())
        return rows;

    static KFileMetaData::ExtractorCollection collection;
    KFileMetaData::SimpleExtractionResult result(local, mimeType, KFileMetaData::ExtractionResult::ExtractMetaData);
    const auto extractors = collection.fetchExtractors(mimeType);
    for (KFileMetaData::Extractor *extractor : extractors) {
        extractor->extract(&result);
        if (!result.properties().isEmpty())
            break;
    }

    const auto props = result.properties();
    auto add = [&rows](const QString &label, const QString &value) {
        if (value.isEmpty())
            return;
        QVariantMap row;
        row[QStringLiteral("label")] = label;
        row[QStringLiteral("value")] = value;
        rows.append(row);
    };
    auto show = [&](KFileMetaData::Property::Property p) {
        if (!props.contains(p))
            return;
        KFileMetaData::PropertyInfo info(p);
        add(info.displayName(), info.formatAsDisplayString(props.value(p)));
    };

    using namespace KFileMetaData::Property;
    if (props.contains(Width) && props.contains(Height))
        add(tr("Dimensions"), QStringLiteral("%1 × %2").arg(props.value(Width).toInt()).arg(props.value(Height).toInt()));
    for (auto p : {Duration, Title, Artist, Album, FrameRate, SampleRate, BitRate, Channels, PageCount, Author})
        show(p);
#else
    Q_UNUSED(pathOrUrl);
    Q_UNUSED(mimeType);
#endif
    return rows;
}
