#pragma once

#include <QObject>
#include <QSet>
#include <QUrl>

class ArchiveManager : public QObject
{
    Q_OBJECT
public:
    enum Operation { ExtractHere, ExtractTo, Compress };
    explicit ArchiveManager(QObject *parent = nullptr);
    static ArchiveManager *instance();
    bool available() const;
    bool canExtract(const QList<QUrl> &urls) const;
    bool launch(Operation operation, const QList<QUrl> &urls) const;
    static QStringList arguments(Operation operation, const QList<QUrl> &urls);
signals:
    void supportedFormatsChanged();
private:
    QString m_program;
    QSet<QString> m_mimeTypes;
};
