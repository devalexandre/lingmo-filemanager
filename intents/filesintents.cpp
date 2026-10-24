#include "filesintents.h"

#include <LingmoIntents/intentgate.h>
#include <LingmoIntents/intentservice.h>

#include <QCoreApplication>
#include <QDeadlineTimer>
#include <QDirIterator>
#include <QFileInfo>
#include <QLocale>
#include <QMimeDatabase>
#include <QTranslator>

using LingmoIntents::IntentCall;
using LingmoIntents::IntentResult;

namespace {

// Never "open" something that runs code
bool runsCode(const QFileInfo &fi)
{
    if (fi.isDir())
        return false;
    static const QStringList types{
        QStringLiteral("application/x-executable"), QStringLiteral("application/x-sharedlib"),
        QStringLiteral("application/x-pie-executable"), QStringLiteral("application/x-desktop"),
        QStringLiteral("application/x-shellscript"), QStringLiteral("application/x-ms-dos-executable"),
        QStringLiteral("application/x-msdownload"), QStringLiteral("application/vnd.microsoft.portable-executable"),
        QStringLiteral("application/x-perl"), QStringLiteral("text/x-python"), QStringLiteral("text/x-python3"),
        QStringLiteral("application/x-appimage"), QStringLiteral("application/vnd.appimage"),
        QStringLiteral("application/x-java-archive"), QStringLiteral("application/x-msi")};
    const QMimeType mime = QMimeDatabase().mimeTypeForFile(fi);
    for (const QString &t : types)
        if (mime.inherits(t))
            return true;
    return fi.isExecutable();
}

IntentResult reveal(const IntentCall &call)
{
    const QFileInfo fi(call.params().value(QStringLiteral("path")).toString());
    if (!fi.exists())
        return IntentResult::failed(QObject::tr("File not found: %1").arg(fi.filePath()));
    const QString folder = fi.isDir() ? fi.absoluteFilePath() : fi.absolutePath();
    QString error;
    if (!LingmoIntents::spawnDetached(QStringLiteral("lingmo-filemanager"), {folder}, &error))
        return IntentResult::failed(error);
    return IntentResult::ok({{QStringLiteral("folder"), folder}});
}

IntentResult open(const IntentCall &call)
{
    const QFileInfo fi(call.params().value(QStringLiteral("path")).toString());
    if (!fi.exists())
        return IntentResult::failed(QObject::tr("File not found: %1").arg(fi.filePath()));
    if (runsCode(fi))
        return IntentResult::failed(QObject::tr("Programs, scripts and app launchers are never opened by actions."),
                                    LingmoIntents::Errors::Denied);
    QString error;
    if (!LingmoIntents::spawnDetached(QStringLiteral("xdg-open"), {fi.absoluteFilePath()}, &error))
        return IntentResult::failed(error);
    return IntentResult::ok({{QStringLiteral("path"), fi.absoluteFilePath()},
                             {QStringLiteral("type"), QMimeDatabase().mimeTypeForFile(fi).name()}});
}

IntentResult search(const IntentCall &call)
{
    const QVariantMap p = call.params();
    const QString root = p.value(QStringLiteral("folder")).toString();
    if (!QFileInfo(root).isDir())
        return IntentResult::failed(QObject::tr("Not a folder: %1").arg(root));
    const QStringList words = p.value(QStringLiteral("query")).toString().toLower().split(QLatin1Char(' '), Qt::SkipEmptyParts);
    const int limit = p.value(QStringLiteral("limit")).toInt();
    QStringList found;
    bool truncated = false;
    int visited = 0;
    QDeadlineTimer deadline(8000);
    // Hidden entries are skipped (QDir::Hidden is not set); protected places too
    QDirIterator it(root, QDir::AllEntries | QDir::NoDotAndDotDot | QDir::NoSymLinks, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString path = it.next();
        if (++visited > 20000 || deadline.hasExpired()) {
            truncated = true;
            break;
        }
        if (LingmoIntents::IntentGate::isBlockedPath(path))
            continue;
        const QString name = it.fileName().toLower();
        bool all = true;
        for (const QString &w : words)
            all = all && name.contains(w);
        if (!all)
            continue;
        found << path;
        if (found.size() >= limit) {
            truncated = true;
            break;
        }
    }
    return IntentResult::ok({{QStringLiteral("files"), found}, {QStringLiteral("count"), found.size()},
                             {QStringLiteral("truncated"), truncated}});
}

}

namespace FilesIntents {

bool requested(int argc, char *argv[])
{
    return argc == 2 && qstrcmp(argv[1], "--intents") == 0;
}

int run(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    app.setOrganizationName(QStringLiteral("lingmoos"));
    app.setApplicationName(QStringLiteral("lingmo-filemanager"));
    QTranslator translator;
    if (translator.load(QStringLiteral("/usr/share/lingmo-filemanager/translations/%1.qm").arg(QLocale::system().name())))
        app.installTranslator(&translator);
    LingmoIntents::IntentService intents(QStringLiteral("lingmo-filemanager"));
    intents.handle(QStringLiteral("files.reveal"), reveal);
    intents.handle(QStringLiteral("files.open"), open);
    intents.handle(QStringLiteral("files.search"), search);
    if (!intents.publish(LingmoIntents::IntentService::Headless))
        return 1;
    intents.setIdleQuit(30000);
    return app.exec();
}

}
