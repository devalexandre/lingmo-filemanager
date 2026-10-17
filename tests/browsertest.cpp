#include "../model/searchmodel.h"
#include "../model/pathbarmodel.h"
#include <QtTest>
#include <QTemporaryDir>
#include <QDir>

class BrowserTest : public QObject {
    Q_OBJECT

    static void touch(const QString &path) {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
    }

private slots:
    void matcher() {
        // every term, any order, case and accent insensitive
        QVERIFY(SearchModel::matches("Relatório Anual 2026.pdf", SearchModel::terms("relatorio 2026")));
        QVERIFY(SearchModel::matches("Notas da reunião.txt", SearchModel::terms("REUNIAO notas")));
        QVERIFY(!SearchModel::matches("Notas.txt", SearchModel::terms("notas reunião")));
        QVERIFY(!SearchModel::matches("anything", SearchModel::terms("   ")));
    }

    void recursiveSearch() {
        QTemporaryDir dir;
        QVERIFY(QDir(dir.path()).mkpath("Documentos/Projetos/2026"));
        QVERIFY(QDir(dir.path()).mkpath(".oculta"));
        touch(dir.filePath("Documentos/Projetos/2026/orçamento final.ods"));
        touch(dir.filePath("Documentos/Orcamento antigo.txt"));
        touch(dir.filePath(".oculta/orcamento secreto.txt"));
        touch(dir.filePath("foto.jpg"));

        SearchModel model;
        model.setRootPath(dir.path());
        QSignalSpy done(&model, &SearchModel::searchingChanged);
        model.setQuery("orcamento");
        QVERIFY(model.searching());
        QTRY_VERIFY(!model.searching());
        QCOMPARE(model.rowCount(), 2);   // hidden folder skipped

        QStringList names;
        for (int i = 0; i < model.rowCount(); ++i)
            names << model.data(model.index(i), SearchModel::NameRole).toString();
        names.sort();
        QCOMPARE(names, QStringList({"Orcamento antigo.txt", "orçamento final.ods"}));

        for (int i = 0; i < model.rowCount(); ++i) {
            if (model.data(model.index(i), SearchModel::NameRole).toString() == "orçamento final.ods")
                QCOMPARE(model.data(model.index(i), SearchModel::LocationRole).toString(), QString("Documentos/Projetos/2026"));
        }

        model.setShowHidden(true);
        QTRY_VERIFY(!model.searching());
        QCOMPARE(model.rowCount(), 3);

        model.setQuery("");
        QCOMPARE(model.rowCount(), 0);
        QVERIFY(!model.searching());
    }

    void pathBarStartsAtHome() {
        PathBarModel model;
        model.setUrl(QDir::homePath() + "/Documentos/Projetos");
        QCOMPARE(model.rowCount(), 3);
        QCOMPARE(model.data(model.index(0, 0), PathBarModel::PathRole).toString(), QDir::homePath());
        QCOMPARE(model.data(model.index(0, 0), PathBarModel::IconNameRole).toString(), QString("user-home"));
        QCOMPARE(model.data(model.index(2, 0), PathBarModel::NameRole).toString(), QString("Projetos"));

        model.setUrl("/usr/share");
        QCOMPARE(model.rowCount(), 3);
        QCOMPARE(model.data(model.index(0, 0), PathBarModel::PathRole).toString(), QString("/"));

        model.setUrl("trash:///");
        QCOMPARE(model.rowCount(), 1);
        QCOMPARE(model.data(model.index(0, 0), PathBarModel::PathRole).toString(), QString("trash:///"));
    }
};

QTEST_GUILESS_MAIN(BrowserTest)
#include "browsertest.moc"
