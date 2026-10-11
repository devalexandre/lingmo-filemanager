/*
 * Copyright (C) 2021 LingmoOS Team.
 *
 * Author:     revenmartin <revenmartin@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "desktopview.h"
#include "dockdbusinterface.h"
#include "thumbnailer/thumbnailprovider.h"

#include <QQmlEngine>
#include <QQmlContext>

#include <QDebug>
#include <QDBusConnection>
#include <QGuiApplication>
#include <QScreen>

#include <KWindowSystem>
#include <KX11Extras>

DesktopView::DesktopView(QScreen *screen, QQuickView *parent)
    : QQuickView(parent)
    , m_screen(screen)
{
    m_screenRect = m_screen->geometry();
    this->setFlag(Qt::FramelessWindowHint);
    this->setColor(QColor(Qt::transparent));
    KX11Extras::setType(winId(), NET::Desktop);
    KX11Extras::setState(winId(), NET::KeepBelow);

    engine()->rootContext()->setContextProperty("desktopView", this);
    engine()->rootContext()->setContextProperty("Dock", DockDBusInterface::self());
    QWindow::fromWinId(winId())->setOpacity(0.99);
    engine()->addImageProvider("thumbnailer", new ThumbnailProvider());

    setTitle(tr("Desktop"));
    setScreen(m_screen);
    setResizeMode(QQuickView::SizeRootObjectToView);

    onGeometryChanged();
    onPrimaryScreenChanged(QGuiApplication::primaryScreen());

    // 主屏改变
    connect(qGuiApp, &QGuiApplication::primaryScreenChanged, this, &DesktopView::onPrimaryScreenChanged);

    connect(m_screen, &QScreen::virtualGeometryChanged, this, &DesktopView::onGeometryChanged);
    connect(m_screen, &QScreen::geometryChanged, this, &DesktopView::onGeometryChanged);

    // Recreate only the wallpaper when returning from a lock/suspend or when
    // Qt recreates GPU resources. Deliver render-thread signals on the GUI thread.
    connect(this, &QQuickWindow::sceneGraphInitialized,
            this, &DesktopView::wallpaperRefreshRequested, Qt::QueuedConnection);
    QDBusConnection::sessionBus().connect("org.freedesktop.ScreenSaver", "/ScreenSaver",
        "org.freedesktop.ScreenSaver", "ActiveChanged", this, SLOT(onSessionInactive(bool)));
    QDBusConnection::systemBus().connect("org.freedesktop.login1", "/org/freedesktop/login1",
        "org.freedesktop.login1.Manager", "PrepareForSleep", this, SLOT(onSessionInactive(bool)));

}

QRect DesktopView::screenRect()
{
    return m_screenRect;
}

void DesktopView::onPrimaryScreenChanged(QScreen *screen)
{
    bool isPrimaryScreen = m_screen->name() == screen->name();

    onGeometryChanged();

    setSource(isPrimaryScreen ? QStringLiteral("qrc:/qml/Desktop/Main.qml")
                              : QStringLiteral("qrc:/qml/Desktop/Wallpaper.qml"));
}

void DesktopView::onGeometryChanged()
{
    m_screenRect = m_screen->geometry().adjusted(0, 0, 1, 1);
    setGeometry(m_screenRect);
    emit screenRectChanged();
}

void DesktopView::onSessionInactive(bool active)
{
    if (!active) {
        emit wallpaperRefreshRequested();
        update();
    }
}
