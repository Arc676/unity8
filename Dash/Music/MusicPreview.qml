/*
 * Copyright (C) 2013 Canonical, Ltd.
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

import QtQuick 2.0
import QtMultimedia 5.0
import Ubuntu.Components 0.1
import Ubuntu.Components.ListItems 0.1
import ".."
import "../Generic"
import "../../Components"
import "../Previews"

GenericPreview {
    id: root

    previewImages: previewImageComponent
    header: headerComponent
    description: descriptionComponent

    Component {
        id: previewImageComponent
        LazyImage {
            height: units.gu(22)
            scaleTo: "height"
            source: previewData ? previewData.image : ""
            initialHeight: height
            initialWidth: height
        }
    }

    Component {
        id: headerComponent
        Header {
            title: previewData.title
            subtitle: previewData.subtitle
        }
    }

    Component {
        id: descriptionComponent

        Column {
            height: childrenRect.height

            ThinDivider {
                objectName: "topDivider"
                anchors {
                    left: parent.left
                    right: parent.right
                }
                visible: trackRepeater.count > 0
            }

            Repeater {
                id: trackRepeater
                objectName: "trackRepeater"

                model: previewData.tracks

                signal stopPlayback()

                delegate: Item {
                    objectName: "trackItem" + index
                    width: parent.width
                    height: units.gu(5)
                    Row {
                        id: trackRow
                        width: parent.width
                        spacing: units.gu(1)
                        property int column1Width: units.gu(3)
                        property int column2Width: width - (2 * spacing) - column1Width - column3Width
                        property int column3Width: units.gu(4)
                        anchors.verticalCenter: parent.verticalCenter

                        UbuntuShape {
                            id: playButtonShape
                            objectName: "playButton"
                            width: trackRow.column1Width
                            height: width
                            Icon {
                                width: units.gu(2)
                                height: width
                                anchors.centerIn: playButtonShape
                                name: audioPlayer.playbackState == Audio.PlayingState ? "media-playback-pause" : "media-playback-start"
                                color: "white"
                                opacity: .9
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (audioPlayer.playbackState == Audio.PlayingState) {
                                        audioPlayer.pause();
                                    } else if (audioPlayer.playbackState == Audio.PausedState){
                                        audioPlayer.play();
                                    } else {
                                        trackRepeater.stopPlayback();
                                        audioPlayer.play();
                                    }
                                }
                            }
                        }

                        Label {
                            objectName: "trackTitleLabel"
                            fontSize: "small"
                            opacity: 0.9
                            color: "white"
                            horizontalAlignment: Text.AlignLeft
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.column2Width
                            text: title
                            style: Text.Raised
                            styleColor: "black"
                            elide: Text.ElideRight

                            UbuntuShape {
                                id: progressBarFill
                                objectName: "progressBarFill"
                                color: UbuntuColors.orange
                                anchors.left: progressBarImage.left
                                anchors.right: progressBarImage.right
                                anchors.verticalCenter: progressBarImage.verticalCenter
                                height: units.dp(2)
                                anchors.margins: units.dp(2)
                                anchors.rightMargin: maxWidth - (maxWidth * audioPlayer.percent / 100) + units.dp(2)
                                visible: progressBarImage.visible
                                property int maxWidth: progressBarImage.width - units.dp(4)
                            }
                            Image {
                                id: progressBarImage
                                anchors {
                                    left: parent.left
                                    top: parent.bottom
                                    right: parent.right
                                }
                                height: units.dp(6)
                                visible: audioPlayer.playbackState != Audio.StoppedState
                                source: "graphics/music_progress_bg.png"

                            }
                        }
                        Label {
                            id: valueLabel
                            objectName: "timeLabel"
                            fontSize: "small"
                            opacity: 0.9
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            width: parent.column3Width
                            text: length
                            style: Text.Raised
                            styleColor: "black"
                        }
                    }

                    ThinDivider {
                        anchors {
                            left: parent.left
                            bottom: parent.bottom
                            right: parent.right
                        }
                    }

                    Audio {
                        id: audioPlayer
                        objectName: "audioPlayer"
                        source: uri
                        property real percent: audioPlayer.position * 100 / audioPlayer.duration

                        Component.onDestruction: {
                            audioPlayer.stop();
                        }

                        onErrorStringChanged: print("Audio player error:", errorString)

                    }
                    Connections {
                        target: root
                        onIsCurrentChanged: {
                            if (!root.isCurrent) {
                                audioPlayer.stop();
                            }
                        }
                    }
                    Connections {
                        target: trackRepeater
                        onStopPlayback: audioPlayer.stop();
                    }
                }
            }
        }
    }
}
