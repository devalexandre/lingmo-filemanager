/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

#ifndef SEARCHMODEL_H
#define SEARCHMODEL_H

#include <QAbstractListModel>
#include <QAtomicInt>
#include <QDateTime>
#include <QSharedPointer>

// Recursive file name search below a local folder. Walks the tree in a worker
// thread (no indexer needed) and streams matches into the model in batches.
class SearchModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString rootPath READ rootPath WRITE setRootPath NOTIFY rootPathChanged)
    Q_PROPERTY(QString query READ query WRITE setQuery NOTIFY queryChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    Q_PROPERTY(bool searching READ searching NOTIFY searchingChanged)
    Q_PROPERTY(bool truncated READ truncated NOTIFY searchingChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    struct Result {
        QString name;
        QString path;
        QString iconName;
        QString mimeType;
        bool isDir = false;
        qint64 size = 0;
        QDateTime modified;
    };

    enum Roles {
        NameRole = Qt::UserRole + 1,
        PathRole,
        UrlRole,
        LocationRole,
        IconNameRole,
        IsDirRole,
        FileSizeRole,
        ModifiedRole,
        KindRole,
        ThumbnailRole,
    };

    explicit SearchModel(QObject *parent = nullptr);
    ~SearchModel() override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString rootPath() const { return m_rootPath; }
    void setRootPath(const QString &path);
    QString query() const { return m_query; }
    void setQuery(const QString &query);
    bool showHidden() const { return m_showHidden; }
    void setShowHidden(bool show);
    bool searching() const { return m_searching; }
    bool truncated() const { return m_truncated; }

    Q_INVOKABLE QString pathAt(int row) const;
    Q_INVOKABLE bool isDirAt(int row) const;
    Q_INVOKABLE void cancel();

    // Pure matcher, exposed for tests: every whitespace-separated term of
    // query must appear in name (case and accent insensitive)
    static bool matches(const QString &name, const QStringList &terms);
    static QStringList terms(const QString &query);

signals:
    void rootPathChanged();
    void queryChanged();
    void showHiddenChanged();
    void searchingChanged();
    void countChanged();

private:
    void restart();
    void appendBatch(int generation, const QList<Result> &batch);
    void finished(int generation, bool truncated);

    QString m_rootPath;
    QString m_query;
    bool m_showHidden = false;
    bool m_searching = false;
    bool m_truncated = false;
    QList<Result> m_results;
    int m_generation = 0;
    QSharedPointer<QAtomicInt> m_cancel;
};

#endif // SEARCHMODEL_H
