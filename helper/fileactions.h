/*
 * SPDX-FileCopyrightText: 2026 LingmoOS Team
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#ifndef FILEACTIONS_H
#define FILEACTIONS_H

#include <QList>
#include <QObject>
#include <QUrl>

class QAction;

// "Converter…" / "Ações de arquivo…": hands the selected local files to the
// File actions wheel (lingmo-fileaction), which converts, compresses, rotates,
// trims... and saves the result next to the original
class FileActions : public QObject
{
    Q_OBJECT
public:
    static bool available();
    // wheel: "convert" (Converter…) or "tools" (Ações de arquivo…)
    static QAction *createAction(const QString &wheel, QObject *parent);
    static void open(const QString &wheel, const QList<QUrl> &urls);
};

#endif
