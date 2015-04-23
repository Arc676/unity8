/*
 * Copyright (C) 2015 Canonical, Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <QtTestGui>
#include <QQuickItem>
#include <QQuickView>
#include <QSignalSpy>

#include "sessionscreenshoter.h"

class SessionScreenshoterTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:

    void init()
    {
        view = new QQuickView();
        view->setSource(QUrl::fromLocalFile(CURRENT_SOURCE_DIR "/sessionscreenshotertest.qml"));
        view->show();
        QTest::qWaitForWindowExposed(view);
    }

    void testSessionScreenshoter()
    {
        SessionScreenshoter s;
        s.setAppdId("test-app-id");
        s.setTarget(view->rootObject());
        QSignalSpy spy(&s, &SessionScreenshoter::screenshotTaken);

        QVERIFY(!QFile::exists(s.path()));

        view->rootObject()->setProperty("color", "red");
        s.take();
        spy.wait();

        QVERIFY(QFile::exists(s.path()));
        QImage image(s.path());
        QCOMPARE(image.pixel(0, 0), qRgb(255, 0, 0));

        view->rootObject()->setProperty("color", "blue");
        s.take();
        spy.wait();

        QVERIFY(QFile::exists(s.path()));
        image = QImage(s.path());
        QCOMPARE(image.pixel(0, 0), qRgb(0, 0, 255));

        s.removeScreenshot();

        QVERIFY(!QFile::exists(s.path()));
    }

    void cleanup()
    {
        delete view;
    }

private:
    QQuickView *view;
};

QTEST_MAIN(SessionScreenshoterTest)

#include "sessionscreenshotertest.moc"
