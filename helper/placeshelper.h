/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

#ifndef PLACESHELPER_H
#define PLACESHELPER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class KFileItem;
class QFileSystemWatcher;
class QQmlEngine;
class QJSEngine;

// Data behind the sidebar sections that are not plain places (favorites,
// recent files, trash count, disk usage, Boxes) and the preview pane.
// One instance per process, shared by every window (QML singleton "Places").
class PlacesHelper : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList favorites READ favorites NOTIFY favoritesChanged)
    Q_PROPERTY(QVariantList recentFiles READ recentFiles NOTIFY recentFilesChanged)
    Q_PROPERTY(int trashCount READ trashCount NOTIFY trashCountChanged)
    Q_PROPERTY(QString homePath READ homePath CONSTANT)
    Q_PROPERTY(QString boxesPath READ boxesPath CONSTANT)
    Q_PROPERTY(bool boxesExists READ boxesExists NOTIFY revisionChanged)
    // Bumped every 30 s and when files change: bindings that read disk
    // usage depend on it to stay current
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)

public:
    static PlacesHelper *self();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    QVariantList favorites() const;
    QVariantList recentFiles() const;
    int trashCount() const;
    QString homePath() const;
    QString boxesPath() const;
    bool boxesExists() const;
    int revision() const;

    Q_INVOKABLE bool isFavorite(const QString &pathOrUrl) const;
    Q_INVOKABLE void addFavorite(const QString &pathOrUrl);
    Q_INVOKABLE void removeFavorite(const QString &pathOrUrl);
    Q_INVOKABLE void moveFavorite(int from, int to);

    // {valid, fraction, freeText, totalText, usageText} for the volume holding path
    Q_INVOKABLE QVariantMap storageInfo(const QString &path) const;

    // Preview pane
    Q_INVOKABLE QVariantMap fileInfo(const QString &pathOrUrl) const;
    Q_INVOKABLE QString textHead(const QString &pathOrUrl, int maxChars = 4000) const;
    Q_INVOKABLE QVariantList mediaInfo(const QString &pathOrUrl, const QString &mimeType) const;
    Q_INVOKABLE QString urlToPath(const QString &url) const;
    Q_INVOKABLE QString displayNameForPath(const QString &pathOrUrl) const;

    static QVariantMap describe(const KFileItem &item);
    static QString localPathFor(const QString &pathOrUrl);

signals:
    void favoritesChanged();
    void recentFilesChanged();
    void trashCountChanged();
    void revisionChanged();

private:
    explicit PlacesHelper(QObject *parent = nullptr);
    void loadFavorites();
    void saveFavorites();
    void reloadRecent();
    void reloadTrashCount();
    void watchRecentFile();

    QStringList m_favoritePaths;
    QVariantList m_recent;
    int m_trashCount = 0;
    int m_revision = 0;
    QString m_recentFile;
    QString m_trashFilesDir;
    QFileSystemWatcher *m_watcher;
};

#endif // PLACESHELPER_H
