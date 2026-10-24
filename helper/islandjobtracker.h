/*
 * SPDX-FileCopyrightText: 2026 LingmoOS Team
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#ifndef ISLANDJOBTRACKER_H
#define ISLANDJOBTRACKER_H

#include <QObject>
#include <QPointer>
#include <QTimer>

class KJob;

// Shows a copy or move in the status bar's Island (com.lingmo.Island, see
// docs/island-api.md): progress, "Copying 3 of 12 items", a Cancel button,
// then "Copy complete". Jobs that end within a moment never show up.
class IslandJobTracker : public QObject
{
    Q_OBJECT

public:
    enum Operation { Copy, Move };

    // Follows job until it ends (deletes itself)
    static void track(KJob *job, Operation operation);

private:
    IslandJobTracker(KJob *job, Operation operation);

    void start();
    void sendUpdate();
    void onResult();
    QString title() const;
    QString subtitle() const;
    QString detail() const;
    double progress() const;

private slots:
    void onActionInvoked(uint id, const QString &actionId);
    void onClosed(uint id);

private:
    QPointer<KJob> m_job;
    Operation m_operation;
    uint m_id = 0;
    bool m_starting = false;
    bool m_done = false;
    qulonglong m_totalFiles = 0;
    qulonglong m_processedFiles = 0;
    qulonglong m_totalBytes = 0;
    qulonglong m_processedBytes = 0;
    unsigned long m_percent = 0;
    QTimer m_showTimer;
    QTimer m_updateTimer;
};

#endif
