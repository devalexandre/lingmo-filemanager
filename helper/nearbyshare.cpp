/*
 * SPDX-FileCopyrightText: 2026 LingmoOS Team
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "nearbyshare.h"

#include <QAction>
#include <QIcon>
#include <QProcess>
#include <QStandardPaths>

bool NearbyShare::available()
{
    return !QStandardPaths::findExecutable(QStringLiteral("lingmo-share")).isEmpty();
}

QAction *NearbyShare::createAction(QObject *parent)
{
    auto *action = new QAction(QIcon::fromTheme(QStringLiteral("document-send")), tr("Send to Nearby Device…"), parent);
    action->setVisible(false);
    return action;
}

void NearbyShare::send(const QList<QUrl> &urls)
{
    QStringList args{QStringLiteral("send"), QStringLiteral("--pick")};
    for (const QUrl &url : urls) {
        if (url.isLocalFile())
            args << url.toLocalFile();
    }
    if (args.size() > 2)
        QProcess::startDetached(QStringLiteral("lingmo-share"), args);
}
