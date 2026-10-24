/*
 * SPDX-FileCopyrightText: 2026 LingmoOS Team
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#ifndef NEARBYSHARE_H
#define NEARBYSHARE_H

#include <QList>
#include <QObject>
#include <QUrl>

class QAction;

// "Send to nearby device": hands local files to Lingmo Share (lingmo-share),
// which asks where to send them (Android phone, iPhone, Mac, PC...)
class NearbyShare : public QObject
{
    Q_OBJECT
public:
    static bool available();
    static QAction *createAction(QObject *parent);
    static void send(const QList<QUrl> &urls);
};

#endif
