#include "archivemanager.h"
#include <QCoreApplication>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QProcess>
#include <QStandardPaths>
#include <QTimer>
#include <algorithm>

ArchiveManager::ArchiveManager(QObject *parent) : QObject(parent)
{
    m_program = QStandardPaths::findExecutable("ark");
    if (m_program.isEmpty())
        return;
    // Ask the installed plugins instead of maintaining an extension whitelist.
    auto *probe = new QProcess(this);
    connect(probe, &QProcess::finished, this, [this, probe](int code, QProcess::ExitStatus status) {
        if (code == 0 && status == QProcess::NormalExit) {
            const auto lines = QString::fromUtf8(probe->readAllStandardOutput()).split('\n');
            for (const auto &line : lines) {
                const QString mime = line.trimmed();
                if (mime.contains('/'))
                    m_mimeTypes.insert(mime);
            }
            emit supportedFormatsChanged();
        }
        probe->deleteLater();
    });
    connect(probe, &QProcess::errorOccurred, probe, [probe](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            probe->deleteLater();
    });
    QTimer::singleShot(10000, probe, [probe] {
        if (probe->state() != QProcess::NotRunning)
            probe->kill();
    });
    probe->start(m_program, {"--mimetypes"});
}

ArchiveManager *ArchiveManager::instance()
{
    static auto *manager = new ArchiveManager(QCoreApplication::instance());
    return manager;
}

bool ArchiveManager::available() const { return !m_program.isEmpty(); }

bool ArchiveManager::canExtract(const QList<QUrl> &urls) const
{
    if (!available() || urls.isEmpty())
        return false;
    QMimeDatabase database;
    return std::all_of(urls.begin(), urls.end(), [&](const QUrl &url) {
        if (!url.isLocalFile() || !QFileInfo(url.toLocalFile()).isFile())
            return false;
        const auto mime = database.mimeTypeForFile(url.toLocalFile());
        for (const auto &supported : m_mimeTypes)
            if (mime.inherits(supported))
                return true;
        return false;
    });
}

QStringList ArchiveManager::arguments(Operation operation, const QList<QUrl> &urls)
{
    if (urls.isEmpty())
        return {};
    QStringList args;
    if (operation == Compress)
        args = {"--add", "--dialog", "--changetofirstpath"};
    else {
        args = {"--batch", "--autodestination", "--autosubfolder"};
        if (operation == ExtractTo)
            args << "--dialog";
    }
    args << "--";
    for (const auto &url : urls) {
        if (!url.isLocalFile() || !QFileInfo::exists(url.toLocalFile()))
            return {};
        args << url.toLocalFile();
    }
    return args;
}

bool ArchiveManager::launch(Operation operation, const QList<QUrl> &urls) const
{
    const auto args = arguments(operation, urls);
    if (!available() || args.isEmpty())
        return false;
    // Ark owns the progress, password, conflict and format-selection dialogs.
    return QProcess::startDetached(m_program, args);
}
