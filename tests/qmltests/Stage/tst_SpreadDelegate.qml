/*
 * Copyright 2014-2016 Canonical Ltd.
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

import QtQuick 2.4
import QtTest 1.0
import Unity.Test 0.1 as UT
import ".."
import "../../../qml/Components"
import "../../../qml/Stages"
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3 as ListItem
import Unity.Application 0.1

Rectangle {
    color: "red"
    id: root
    width: fakeShell.shortestDimension + controls.width
    height: fakeShell.longestDimension

    property QtObject fakeApplication: null

    Item {
        id: fakeShell

        readonly property real shortestDimension: units.gu(40)
        readonly property real longestDimension: units.gu(70)

        width: landscape ? longestDimension : shortestDimension
        height: landscape ? shortestDimension : longestDimension

        x: landscape ? (height - width) / 2 : 0
        y: landscape ? (width - height) / 2 : 0

        property bool landscape: orientationAngle == 90 || orientationAngle == 270
        property int orientationAngle: shellOrientationAngleSelector.value

        rotation: orientationAngle

        Loader {
            id: spreadDelegateLoader
            width: parent.width
            height: parent.height

            active: false
            property bool itemDestroyed: false
            sourceComponent: SpreadDelegate {
                anchors.fill: parent
                swipeToCloseEnabled: swipeToCloseCheckbox.checked
                closeable: closeableCheckbox.checked
                application: fakeApplication
                surface: fakeApplication && fakeApplication.surfaceList.count > 0 ? fakeApplication.surfaceList.get(0) : null
                shellOrientationAngle: shellOrientationAngleSelector.value
                shellOrientation: {
                    switch (shellOrientationAngleSelector.value) {
                    case 0:
                        return Qt.PortraitOrientation;
                    case 90:
                        return Qt.InvertedLandscapeOrientation;
                    case 180:
                        return Qt.InvertedPortraitOrientation;
                    default: // 270
                        return Qt.LandscapeOrientation;
                    }
                }

                orientations: Orientations {
                    // the default values will do
                }

                maximizedAppTopMargin: units.gu(3)
                Component.onDestruction: {
                    spreadDelegateLoader.itemDestroyed = true;
                }
                Component.onCompleted: {
                    spreadDelegateLoader.itemDestroyed = false;
                }
            }
        }
    }

    Rectangle {
        id: controls
        color: "white"
        x: fakeShell.shortestDimension
        width: units.gu(30)
        anchors {
            top: parent.top
            bottom: parent.bottom
        }

        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: units.gu(1) }
            spacing: units.gu(1)
            Button {
                id: loadWithWeatherApp
                text: "Load with ubuntu-weather-app"
                onClicked: { testCase.restartWithApp("ubuntu-weather-app"); }
            }
            Button {
                id: loadWithGalleryApp
                text: "Load with gallery-app"
                onClicked: { testCase.restartWithApp("gallery-app"); }
            }
            Row {
                anchors { left: parent.left; right: parent.right }
                CheckBox { id: swipeToCloseCheckbox; checked: false; }
                Label { text: "swipeToCloseEnabled" }
            }
            Row {
                anchors { left: parent.left; right: parent.right }
                CheckBox { id: closeableCheckbox; checked: false }
                Label { text: "closeable" }
            }
            ListItem.ItemSelector {
                id: shellOrientationAngleSelector
                anchors { left: parent.left; right: parent.right }
                text: "shellOrientationAngle"
                model: ["0", "90", "180", "270"]
                property int value: selectedIndex * 90
            }
            Button {
                id: matchShellButton
                text: "matchShellOrientation()"
                onClicked: { spreadDelegateLoader.item.matchShellOrientation(); }
            }
            Button {
                id: animateToShellButton
                text: "animateToShellOrientation()"
                onClicked: { spreadDelegateLoader.item.animateToShellOrientation(); }
            }
        }
    }

    UT.UnityTestCase {
        id: testCase
        name: "SpreadDelegate"
        when: windowShown

        SignalSpy {
            id: spyClosedSignal
            target: spreadDelegateLoader.item
            signalName: "closed"
        }

        property var dragArea
        property Item spreadDelegate: spreadDelegateLoader.item

        function init() {
        }

        function cleanup() {
            unloadSpreadDelegate();
            spyClosedSignal.clear();
            shellOrientationAngleSelector.selectedIndex = 0;
            root.fakeApplication = null;
            killApps();
        }

        function restartWithApp(appId) {
            if (spreadDelegateLoader.active) {
                unloadSpreadDelegate();
            }
            if (root.fakeApplication) {
                ApplicationManager.stopApplication(root.fakeApplication.appId);
            }

            root.fakeApplication = ApplicationManager.startApplication(appId);
            spreadDelegateLoader.active = true;
            tryCompare(spreadDelegateLoader, "status", Loader.Ready);

            dragArea = findInvisibleChild(spreadDelegate, "dragArea");
            dragArea.__dateTime = fakeDateTime;
        }

        function unloadSpreadDelegate() {
            spreadDelegateLoader.active = false;
            tryCompare(spreadDelegateLoader, "status", Loader.Null);
            tryCompare(spreadDelegateLoader, "item", null);
            // Loader.status might be Loader.Null and Loader.item might be null but the Loader
            // item might still be alive. So if we set Loader.active back to true
            // again right now we will get the very same Shell instance back. So no reload
            // actually took place. Likely because Loader waits until the next event loop
            // iteration to do its work. So to ensure the reload, we will wait until the
            // Shell instance gets destroyed.
            tryCompare(spreadDelegateLoader, "itemDestroyed", true);

        }

        function waitUntilAppWindowIsFullyLoaded() {
            var appWindowStateGroup = findInvisibleChild(spreadDelegate, "applicationWindowStateGroup");
            tryCompareFunction(function() { return appWindowStateGroup.state === "surface" }, true);
            waitUntilTransitionsEnd(appWindowStateGroup);

            var priv = findInvisibleChild(spreadDelegate, "spreadDelegatePriv");
            verify(priv);
            tryCompare(priv, "startingUp", false);
        }

        function rotateShellTo(angle) {
            shellOrientationAngleSelector.selectedIndex = angle / 90;
        }

        function waitUntilRotationAnimationStops() {
            var orientationChangeAnimation = findInvisibleChild(spreadDelegate, "orientationChangeAnimation");
            verify(orientationChangeAnimation);
            tryCompare(orientationChangeAnimation, "running", false);
        }

        function checkAppWindowTransformationMatchesRotation(appWindow, angle) {

            var topLeftX = 0;
            var topLeftY = 0;
            var bottomRightX = 0;
            var bottomRightY = 0;

            switch (angle) {
            case 0:
                topLeftX = 0;
                topLeftY = 0;
                bottomRightX = fakeShell.shortestDimension;
                bottomRightY = fakeShell.longestDimension;
                break;
            case 90:
                topLeftX = fakeShell.shortestDimension;
                topLeftY = 0;
                bottomRightX = 0;
                bottomRightY = fakeShell.longestDimension;
                break;
            default:
                // TODO implement 180 and 270 once we need them
                verify(false);
            }

            var appWindowTopLeftInRootCoords = appWindow.mapToItem(root, 0, 0);

            if (appWindowTopLeftInRootCoords.x !== topLeftX) {
                qtest_fail("appWindow topLeft.x ("+appWindowTopLeftInRootCoords.x+")"
                           +" doesn't match expectations ("+topLeftX+").", 1);
            }
            if (appWindowTopLeftInRootCoords.y !== topLeftY) {
                qtest_fail("appWindow topLeft.y ("+appWindowTopLeftInRootCoords.y+")"
                           +" doesn't match expectations ("+topLeftY+").", 1);
            }

            var appWindowBottomRightInRootCoords = appWindow.mapToItem(root, appWindow.width,
                                                                             appWindow.height);
            compare(appWindowBottomRightInRootCoords.x, bottomRightX);
            compare(appWindowBottomRightInRootCoords.y, bottomRightY);

            if (appWindowBottomRightInRootCoords.x !== bottomRightX) {
                qtest_fail("appWindow bottomRight.x ("+appWindowBottomRightInRootCoords.x+")"
                           +" doesn't match expectations ("+bottomRightX+").", 1);
            }
            if (appWindowBottomRightInRootCoords.y !== bottomRightY) {
                qtest_fail("appWindow bottomRight.y ("+appWindowBottomRightInRootCoords.y+")"
                           +" doesn't match expectations ("+bottomRightY+").", 1);
            }
        }

        function test_swipeToClose_data() {
            return [
                {tag: "swipeToClose=true closeable=true -> appWindow moves away",
                 swipeToClose: true, closeable: true },

                {tag: "swipeToClose=true closeable=false -> appWindow bounces back",
                 swipeToClose: true, closeable: false },

                {tag: "swipeToClose=false -> appWindow stays put",
                 swipeToClose: false, closeable: true },
            ]
        }

        function test_swipeToClose(data) {
            loadWithGalleryApp.clicked();
            var displacedAppWindowWithShadow = findChild(spreadDelegateLoader.item, "displacedAppWindowWithShadow");

            verify(displacedAppWindowWithShadow.y === 0);

            swipeToCloseCheckbox.checked = data.swipeToClose;
            closeableCheckbox.checked = data.closeable;

            var dragDistance = spreadDelegateLoader.item.height * 0.8;
            var touchX = spreadDelegateLoader.item.width / 2;
            var fromY = spreadDelegateLoader.item.height * 0.9;
            var toY = fromY - dragDistance;
            touchFlick(spreadDelegateLoader.item,
                touchX /* fromX */,  fromY, touchX /* toX */,  toY,
                true /* beginTouch */, false /* endTouch */, dragArea.minSpeedToClose * 1.1 /* speed */);

            if (data.swipeToClose) {
                verify(displacedAppWindowWithShadow.y < 0);
                var threshold = findChild(spreadDelegateLoader.item, "dragArea").threshold
                if (data.closeable) {
                    // Verify that the delegate started moving exactly "threshold" after the finger movement
                    // and did not jump up to the finger, but lags the threshold behind
                    compare(Math.abs(Math.abs(displacedAppWindowWithShadow.y) - dragDistance), threshold);
                } else {
                    verify(Math.abs(Math.abs(displacedAppWindowWithShadow.y) - dragDistance) > threshold);
                }

                touchRelease(spreadDelegateLoader.item, touchX, toY - units.gu(1));

                waitForCloseAnimationToFinish();

                if (data.closeable) {
                    verify(spyClosedSignal.count === 1);
                } else {
                    verify(spyClosedSignal.count === 0);
                    tryCompare(displacedAppWindowWithShadow, "y", 0);
                }

            } else {
                verify(displacedAppWindowWithShadow.y === 0);

                touchRelease(spreadDelegateLoader.item, touchX, toY);
            }
        }

        function test_loadingLandscapeOnlyAppWhenShellInPortrait() {
            loadWithWeatherApp.clicked();

            var appWindow = findChild(spreadDelegate, "appWindow");
            verify(appWindow);

            // It must have landscape dimensions as it does not support portrait
            tryCompare(appWindow, "width", fakeShell.height);
            tryCompare(appWindow, "height", fakeShell.width - spreadDelegate.maximizedAppTopMargin);
        }

        function test_keepsSceneTransformationWhenShellRotates_data() {
            return [
                {tag: "0", selectedIndex: 0},
                {tag: "90", selectedIndex: 1},
                {tag: "180", selectedIndex: 2},
                {tag: "270", selectedIndex: 3}
            ];
        }
        function test_keepsSceneTransformationWhenShellRotates(data) {
            loadWithGalleryApp.clicked();

            waitUntilAppWindowIsFullyLoaded();

            var appWindowWithShadow = findChild(spreadDelegate, "appWindowWithShadow");
            verify(appWindowWithShadow);

            compare(appWindowWithShadow.state, "keepSceneRotation");

            shellOrientationAngleSelector.selectedIndex = data.selectedIndex;

            // must keep same aspect ratio
            compare(appWindowWithShadow.width, fakeShell.shortestDimension);
            compare(appWindowWithShadow.height, fakeShell.longestDimension);


            // and scene transformation must be the identity (ie, no rotation or translation)
            checkAppWindowTransformationMatchesRotation(appWindowWithShadow, 0);
        }

        function waitForCloseAnimationToFinish() {
            var closeAnimation = findInvisibleChild(spreadDelegateLoader.item, "closeAnimation");
            wait(closeAnimation.duration * 1.5);
            tryCompare(closeAnimation, "running", false);
        }

        function test_showHighLight() {
            loadWithGalleryApp.clicked();
            var highlightRect = findChild(spreadDelegateLoader.item, "selectionHighlight")
            tryCompare(highlightRect, "visible", false)
            spreadDelegateLoader.item.highlightShown = true;
            tryCompare(highlightRect, "visible", true)
        }

        /*
            Checks that the ApplicationWindow position, size and rotation is correct after
            a sequence of shell rotations folowed by rotations (immediate or not) to match them
         */
        function test_animateToShellThenMatchShell() {
            loadWithGalleryApp.clicked();
            waitUntilAppWindowIsFullyLoaded();

            var appWindowWithShadow = findChild(spreadDelegate, "appWindowWithShadow");
            verify(appWindowWithShadow);

            // appWindow transformation is 0 relative to display
            checkAppWindowTransformationMatchesRotation(appWindowWithShadow, 0);

            rotateShellTo(90);

            // appWindow transformation remains 0 relative to display
            checkAppWindowTransformationMatchesRotation(appWindowWithShadow, 0);

            animateToShellButton.clicked();
            waitUntilRotationAnimationStops();

            // appWindow transformation is now 90 relative to display, just like shell
            checkAppWindowTransformationMatchesRotation(appWindowWithShadow, 90);

            rotateShellTo(0);

            // appWindow transformation is remains 90 relative to display.
            checkAppWindowTransformationMatchesRotation(appWindowWithShadow, 90);

            matchShellButton.clicked();

            // appWindow transformation is back to 0 relative to display, just like shell
            checkAppWindowTransformationMatchesRotation(appWindowWithShadow, 0);

        }
    }
}
