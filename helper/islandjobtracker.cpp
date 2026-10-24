/*
 * SPDX-FileCopyrightText: 2026 LingmoOS Team
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "islandjobtracker.h"

#include <KJob>
#include <KIO/Global>

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QLocale>

static const QString s_service = QStringLiteral("com.lingmo.Island");
static const QString s_path = QStringLiteral("/Island");
static const QString s_interface = QStringLiteral("com.lingmo.Island");

void IslandJobTracker::track(KJob *job, Operation operation)
{
    if (job)
        new IslandJobTracker(job, operation);
}

IslandJobTracker::IslandJobTracker(KJob *job, Operation operation)
    : QObject(nullptr)
    , m_job(job)
    , m_operation(operation)
{
    // Short copies never reach the Island
    m_showTimer.setSingleShot(true);
    m_showTimer.setInterval(700);
    connect(&m_showTimer, &QTimer::timeout, this, &IslandJobTracker::start);
    m_showTimer.start();

    // At most a few updates per second
    m_updateTimer.setSingleShot(true);
    m_updateTimer.setInterval(300);
    connect(&m_updateTimer, &QTimer::timeout, this, &IslandJobTracker::sendUpdate);

    connect(job, &KJob::totalAmountChanged, this, [this](KJob *, KJob::Unit unit, qulonglong amount) {
        if (unit == KJob::Files)
            m_totalFiles = amount;
        else if (unit == KJob::Bytes)
            m_totalBytes = amount;
        if (m_id && !m_updateTimer.isActive())
            m_updateTimer.start();
    });
    connect(job, &KJob::processedAmountChanged, this, [this](KJob *, KJob::Unit unit, qulonglong amount) {
        if (unit == KJob::Files)
            m_processedFiles = amount;
        else if (unit == KJob::Bytes)
            m_processedBytes = amount;
        if (m_id && !m_updateTimer.isActive())
            m_updateTimer.start();
    });
    connect(job, &KJob::percentChanged, this, [this](KJob *, unsigned long percent) {
        m_percent = percent;
        if (m_id && !m_updateTimer.isActive())
            m_updateTimer.start();
    });
    connect(job, &KJob::result, this, &IslandJobTracker::onResult);
    connect(job, &QObject::destroyed, this, [this] {
        if (!m_done)
            onResult();
    });

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(s_service, s_path, s_interface, QStringLiteral("ActionInvoked"),
                this, SLOT(onActionInvoked(uint,QString)));
    bus.connect(s_service, s_path, s_interface, QStringLiteral("Closed"),
                this, SLOT(onClosed(uint)));
}

QString IslandJobTracker::title() const
{
    return m_operation == Move ? tr("Moving files") : tr("Copying files");
}

QString IslandJobTracker::subtitle() const
{
    if (m_totalFiles > 1) {
        const qulonglong current = qMin(m_totalFiles, m_processedFiles + 1);
        return m_operation == Move ? tr("Moving %1 of %2 items").arg(current).arg(m_totalFiles)
                                   : tr("Copying %1 of %2 items").arg(current).arg(m_totalFiles);
    }
    return m_operation == Move ? tr("Moving 1 item") : tr("Copying 1 item");
}

QString IslandJobTracker::detail() const
{
    if (m_totalBytes == 0)
        return QString();
    return tr("%1 of %2").arg(KIO::convertSize(m_processedBytes), KIO::convertSize(m_totalBytes));
}

double IslandJobTracker::progress() const
{
    if (m_totalBytes > 0)
        return qBound(0.0, double(m_processedBytes) / double(m_totalBytes), 1.0);
    return qBound(0.0, m_percent / 100.0, 1.0);
}

void IslandJobTracker::start()
{
    if (m_done || m_id || m_starting || !m_job)
        return;
    m_starting = true;

    QVariantMap hints;
    hints.insert(QStringLiteral("detail"), detail());

    QDBusMessage msg = QDBusMessage::createMethodCall(s_service, s_path, s_interface, QStringLiteral("StartWithHints"));
    msg << QStringLiteral("lingmo-filemanager") << QStringLiteral("transfer") << title() << subtitle()
        << QStringLiteral("folder-copy") << progress()
        << QStringList { QStringLiteral("cancel"), tr("Cancel") } << hints;

    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        m_starting = false;
        QDBusPendingReply<uint> reply = *w;
        if (reply.isError()) {
            // No status bar: nothing to show
            if (m_done)
                deleteLater();
            return;
        }
        m_id = reply.value();
        if (m_done) {
            // Ended while the Island was being asked
            onResult();
            return;
        }
        sendUpdate();
    });
}

void IslandJobTracker::sendUpdate()
{
    if (!m_id || m_done)
        return;
    QVariantMap fields;
    fields.insert(QStringLiteral("subtitle"), subtitle());
    fields.insert(QStringLiteral("progress"), progress());
    fields.insert(QStringLiteral("detail"), detail());
    QDBusMessage msg = QDBusMessage::createMethodCall(s_service, s_path, s_interface, QStringLiteral("UpdateFields"));
    msg << m_id << fields;
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
}

void IslandJobTracker::onResult()
{
    m_done = true;
    m_showTimer.stop();
    m_updateTimer.stop();

    if (m_starting)
        return; // start()'s reply finishes it

    if (m_id) {
        QString message;
        const int error = m_job ? m_job->error() : 0;
        if (error == KIO::ERR_USER_CANCELED)
            message = QString();
        else if (error)
            message = m_operation == Move ? tr("Move failed") : tr("Copy failed");
        else
            message = m_operation == Move ? tr("Move complete") : tr("Copy complete");

        QDBusMessage msg = QDBusMessage::createMethodCall(s_service, s_path, s_interface, QStringLiteral("Finish"));
        msg << m_id << message;
        QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
        m_id = 0;
    }
    deleteLater();
}

void IslandJobTracker::onActionInvoked(uint id, const QString &actionId)
{
    if (id && id == m_id && actionId == QLatin1String("cancel") && m_job)
        m_job->kill(KJob::EmitResult);
}

void IslandJobTracker::onClosed(uint id)
{
    if (id && id == m_id)
        m_id = 0;
}
