/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

#include "searchmodel.h"
#include "../thumbnailer/thumbnailcache.h"
#include "../helper/datehelper.h"

#include <QDirIterator>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QPointer>
#include <QThread>
#include <QTimer>
#include <QUrl>

#include <KIO/Global>

static const int MaxResults = 2000;

static QString fold(const QString &text)
{
    const QString decomposed = text.normalized(QString::NormalizationForm_D);
    QString out;
    out.reserve(decomposed.size());
    for (const QChar c : decomposed) {
        if (c.category() != QChar::Mark_NonSpacing)
            out.append(c.toCaseFolded());
    }
    return out;
}

SearchModel::SearchModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

SearchModel::~SearchModel()
{
    cancel();
}

QStringList SearchModel::terms(const QString &query)
{
    return fold(query).split(QLatin1Char(' '), Qt::SkipEmptyParts);
}

bool SearchModel::matches(const QString &name, const QStringList &terms)
{
    if (terms.isEmpty())
        return false;
    const QString folded = fold(name);
    for (const QString &term : terms) {
        if (!folded.contains(term))
            return false;
    }
    return true;
}

void SearchModel::setRootPath(const QString &path)
{
    QString local = path;
    const QUrl url(path);
    if (url.isLocalFile())
        local = url.toLocalFile();
    else if (!path.startsWith(QLatin1Char('/')))
        local.clear();

    if (local == m_rootPath)
        return;
    m_rootPath = local;
    emit rootPathChanged();
    restart();
}

void SearchModel::setQuery(const QString &query)
{
    if (query == m_query)
        return;
    m_query = query;
    emit queryChanged();
    restart();
}

void SearchModel::setShowHidden(bool show)
{
    if (show == m_showHidden)
        return;
    m_showHidden = show;
    emit showHiddenChanged();
    restart();
}

void SearchModel::cancel()
{
    if (m_cancel)
        m_cancel->storeRelaxed(1);
    m_cancel.reset();
    ++m_generation;
    if (m_searching) {
        m_searching = false;
        emit searchingChanged();
    }
}

void SearchModel::restart()
{
    cancel();

    beginResetModel();
    m_results.clear();
    endResetModel();
    emit countChanged();
    m_truncated = false;

    const QStringList queryTerms = terms(m_query);
    if (queryTerms.isEmpty() || m_rootPath.isEmpty()) {
        emit searchingChanged();
        return;
    }

    m_searching = true;
    emit searchingChanged();

    const int generation = m_generation;
    auto cancelFlag = QSharedPointer<QAtomicInt>::create(0);
    m_cancel = cancelFlag;
    const QString root = m_rootPath;
    const bool hidden = m_showHidden;
    QPointer<SearchModel> self(this);

    QThread *thread = QThread::create([=] {
        QDir::Filters filters = QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System;
        if (hidden)
            filters |= QDir::Hidden;
        QDirIterator it(root, filters, QDirIterator::Subdirectories);
        QMimeDatabase db;
        QList<Result> batch;
        QElapsedTimer flushTimer;
        flushTimer.start();
        int total = 0;
        bool truncated = false;

        auto flush = [&] {
            if (batch.isEmpty())
                return;
            const QList<Result> copy = batch;
            batch.clear();
            QMetaObject::invokeMethod(self.data(), [self, generation, copy] {
                if (self)
                    self->appendBatch(generation, copy);
            }, Qt::QueuedConnection);
        };

        while (it.hasNext()) {
            if (cancelFlag->loadRelaxed())
                return;
            it.next();
            const QFileInfo info = it.fileInfo();
            if (!matches(info.fileName(), queryTerms))
                continue;

            Result r;
            r.name = info.fileName();
            r.path = info.absoluteFilePath();
            r.isDir = info.isDir();
            const QMimeType mime = r.isDir ? db.mimeTypeForName(QStringLiteral("inode/directory"))
                                           : db.mimeTypeForFile(info, QMimeDatabase::MatchExtension);
            r.mimeType = mime.name();
            r.iconName = mime.iconName();
            r.size = r.isDir ? 0 : info.size();
            r.modified = info.lastModified();
            batch.append(r);

            if (++total >= MaxResults) {
                truncated = true;
                break;
            }
            if (batch.size() >= 200 || flushTimer.elapsed() > 120) {
                flush();
                flushTimer.restart();
            }
        }
        flush();
        if (!cancelFlag->loadRelaxed()) {
            QMetaObject::invokeMethod(self.data(), [self, generation, truncated] {
                if (self)
                    self->finished(generation, truncated);
            }, Qt::QueuedConnection);
        }
    });
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start(QThread::LowPriority);
}

void SearchModel::appendBatch(int generation, const QList<Result> &batch)
{
    if (generation != m_generation || batch.isEmpty())
        return;
    beginInsertRows(QModelIndex(), m_results.size(), m_results.size() + batch.size() - 1);
    m_results.append(batch);
    endInsertRows();
    emit countChanged();
}

void SearchModel::finished(int generation, bool truncated)
{
    if (generation != m_generation)
        return;
    m_cancel.reset();
    m_truncated = truncated;
    m_searching = false;
    emit searchingChanged();
}

int SearchModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_results.size();
}

QHash<int, QByteArray> SearchModel::roleNames() const
{
    return {
        {NameRole, "fileName"},
        {PathRole, "path"},
        {UrlRole, "url"},
        {LocationRole, "location"},
        {IconNameRole, "iconName"},
        {IsDirRole, "isDir"},
        {FileSizeRole, "fileSize"},
        {ModifiedRole, "modified"},
        {KindRole, "kind"},
        {ThumbnailRole, "thumbnail"},
    };
}

QVariant SearchModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_results.size())
        return QVariant();

    const Result &r = m_results.at(index.row());
    switch (role) {
    case NameRole:
        return r.name;
    case PathRole:
        return r.path;
    case UrlRole:
        return QUrl::fromLocalFile(r.path).toString();
    case LocationRole: {
        // Folder relative to the search root ("" when directly inside it)
        QString parent = QFileInfo(r.path).absolutePath();
        if (parent.startsWith(m_rootPath))
            parent = parent.mid(m_rootPath.size());
        if (parent.startsWith(QLatin1Char('/')))
            parent.remove(0, 1);
        return parent;
    }
    case IconNameRole:
        return r.iconName;
    case IsDirRole:
        return r.isDir;
    case FileSizeRole:
        return r.isDir ? QString() : KIO::convertSize(r.size);
    case ModifiedRole:
        return DateHelper::friendlyTime(r.modified);
    case KindRole:
        return QMimeDatabase().mimeTypeForName(r.mimeType).comment();
    case ThumbnailRole: {
        if (r.mimeType == QLatin1String("image/svg+xml"))
            return QUrl::fromLocalFile(r.path);
        if (!r.isDir && Thumbnails::canThumbnail(r.mimeType))
            return Thumbnails::imageUrlFor(r.path, r.modified.toSecsSinceEpoch());
        return QVariant();
    }
    default:
        return QVariant();
    }
}

QString SearchModel::pathAt(int row) const
{
    return row >= 0 && row < m_results.size() ? m_results.at(row).path : QString();
}

bool SearchModel::isDirAt(int row) const
{
    return row >= 0 && row < m_results.size() && m_results.at(row).isDir;
}
