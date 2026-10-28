/*
 * SPDX-FileCopyrightText: 2026 LingmoOS Team
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "fileactions.h"

#include <QAction>
#include <QIcon>
#include <QProcess>
#include <QStandardPaths>

bool FileActions::available()
{
    return !QStandardPaths::findExecutable(QStringLiteral("lingmo-fileaction")).isEmpty();
}

QAction *FileActions::createAction(const QString &wheel, QObject *parent)
{
    const bool convert = wheel == QLatin1String("convert");
    auto *action = new QAction(QIcon::fromTheme(convert ? QStringLiteral("document-export") : QStringLiteral("lingmo-fileaction")),
                               convert ? tr("Convert…") : tr("File Actions…"), parent);
    action->setVisible(false);
    return action;
}

void FileActions::open(const QString &wheel, const QList<QUrl> &urls)
{
    QStringList args{QStringLiteral("--wheel"), wheel};
    for (const QUrl &url : urls) {
        if (url.isLocalFile())
            args << url.toLocalFile();
    }
    if (args.size() > 2)
        QProcess::startDetached(QStringLiteral("lingmo-fileaction"), args);
}
