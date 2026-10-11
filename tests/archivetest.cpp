#include "../helper/archivemanager.h"
#include <QtTest>
#include <QTemporaryDir>
#include <QProcess>
#include <QStandardPaths>
#include <QDir>

class ArchiveTest : public QObject {
    Q_OBJECT
private slots:
    void arguments() {
        QTemporaryDir dir;
        const auto path = dir.filePath("-relatório $(echo oi).txt");
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.close();
        const QList<QUrl> urls{QUrl::fromLocalFile(path)};
        QCOMPARE(ArchiveManager::arguments(ArchiveManager::Compress, urls),
                 QStringList({"--add", "--dialog", "--changetofirstpath", "--", path}));
        QCOMPARE(ArchiveManager::arguments(ArchiveManager::ExtractTo, urls),
                 QStringList({"--batch", "--autodestination", "--autosubfolder", "--dialog", "--", path}));
        QVERIFY(ArchiveManager::arguments(ArchiveManager::Compress, {QUrl("https://example.com/a.zip")}).isEmpty());
        QVERIFY(ArchiveManager::arguments(ArchiveManager::ExtractHere, {}).isEmpty());
    }
    void installedBackendRoundTrip() {
        const auto ark = QStandardPaths::findExecutable("ark");
        if (ark.isEmpty())
            QSKIP("Ark is not installed; set PATH to an Ark installation for the integration test.");
        ArchiveManager manager;
        QSignalSpy formats(&manager, &ArchiveManager::supportedFormatsChanged);
        QVERIFY(formats.wait(10000));
        QTemporaryDir dir;
        const auto input = dir.filePath("nota com espaços.txt");
        const QByteArray content("Archive round trip\n");
        QFile file(input);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(content);
        file.close();
        for (const auto &suffix : {"zip", "tar.gz", "7z"}) {
            const auto archive = dir.filePath(QString("bundle.") + suffix);
            QProcess create;
            create.start(ark, {"--add-to", archive, "--changetofirstpath", "--", input});
            QVERIFY(create.waitForFinished(15000));
            QCOMPARE(create.exitCode(), 0);
            QVERIFY(QFile::exists(archive));
            const QList<QUrl> urls{QUrl::fromLocalFile(archive)};
            QVERIFY(manager.canExtract(urls));
            QVERIFY(!manager.canExtract({QUrl::fromLocalFile(input)}));
            const auto destination = dir.filePath(QString("out-") + suffix);
            QVERIFY(QDir().mkpath(destination));
            auto args = ArchiveManager::arguments(ArchiveManager::ExtractHere, urls);
            const int endOptions = args.indexOf("--");
            args.insert(endOptions, "--destination");
            args.insert(endOptions + 1, destination);
            QProcess extract;
            extract.start(ark, args);
            QVERIFY(extract.waitForFinished(15000));
            QCOMPARE(extract.exitCode(), 0);
            QFile restored(destination + "/nota com espaços.txt");
            QVERIFY(restored.open(QIODevice::ReadOnly));
            QCOMPARE(restored.readAll(), content);
        }
    }
};
QTEST_GUILESS_MAIN(ArchiveTest)
#include "archivetest.moc"
