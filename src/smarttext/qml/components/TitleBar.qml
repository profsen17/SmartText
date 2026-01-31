import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: bar

    required property var window
    required property int cornerRadius
    property string titleText: "SmartText"
    property bool draggable: true
    property bool showMinimize: true
    property bool showMaximize: true
    property bool showClose: true

    height: 42
    color: "#1b1b1b"
    radius: cornerRadius
    clip: true

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#202020" }
        GradientStop { position: 1.0; color: "#161616" }
    }
    border.color: "#2a2a2a"
    border.width: 1

    MouseArea {
        anchors.fill: parent
        enabled: bar.draggable
        acceptedButtons: Qt.LeftButton
        onPressed: {
            if (bar.window && bar.window.startSystemMove) bar.window.startSystemMove()
        }
        onDoubleClicked: {
            if (!bar.window) return
            if (bar.window.visibility === Window.Maximized) bar.window.showNormal()
            else bar.window.showMaximized()
        }
        z: 0
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 8
        z: 1

        Label {
            text: bar.titleText
            color: "#dddddd"
            font.pixelSize: 13
            elide: Label.ElideRight
            Layout.fillWidth: true
        }

        RowLayout {
            spacing: 6

            // Minimize
            ToolButton {
                id: minBtn
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28

                visible: bar.showMinimize
                enabled: bar.showMinimize

                hoverEnabled: true
                onClicked: if (bar.window) bar.window.showMinimized()

                background: Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: minBtn.hovered ? "#3a3a3a" : "#2a2a2a"
                }

                contentItem: Item {
                    width: 12; height: 12
                    anchors.centerIn: parent
                    Rectangle { anchors.centerIn: parent; width: 12; height: 2; radius: 1; color: "#dddddd" }
                }
            }

            // Maximize
            ToolButton {
                id: maxBtn
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28

                visible: bar.showMaximize
                enabled: bar.showMaximize

                hoverEnabled: true
                onClicked: {
                    if (!bar.window) return
                    if (bar.window.visibility === Window.Maximized) bar.window.showNormal()
                    else bar.window.showMaximized()
                }

                background: Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: maxBtn.hovered ? "#3a3a3a" : "#2a2a2a"
                }

                contentItem: Item {
                    width: 12
                    height: 12
                    anchors.centerIn: parent

                    // NORMAL (single square)
                    Rectangle {
                        visible: bar.window && bar.window.visibility !== Window.Maximized
                        anchors.centerIn: parent
                        width: 10
                        height: 10
                        radius: 2
                        color: "transparent"
                        border.color: "#dddddd"
                        border.width: 2
                    }

                    // MAXIMIZED (two overlapping squares)
                    Item {
                        visible: bar.window && bar.window.visibility === Window.Maximized
                        anchors.centerIn: parent
                        width: 12
                        height: 12

                        Rectangle {
                            x: 3
                            y: 0
                            width: 8
                            height: 8
                            radius: 2
                            color: "transparent"
                            border.color: "#dddddd"
                            border.width: 2
                        }

                        Rectangle {
                            x: 0
                            y: 3
                            width: 8
                            height: 8
                            radius: 2
                            color: "transparent"
                            border.color: "#dddddd"
                            border.width: 2
                        }
                    }
                }
            }

            // Close
            ToolButton {
                id: closeBtn
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28

                visible: bar.showClose
                enabled: bar.showClose

                hoverEnabled: true
                onClicked: if (bar.window) bar.window.close()

                background: Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: closeBtn.hovered ? "#c0392b" : "#2a2a2a"
                }

                contentItem: Item {
                    width: 12; height: 12
                    anchors.centerIn: parent
                    Rectangle { anchors.centerIn: parent; width: 12; height: 2; radius: 1; color: "#dddddd"; rotation: 45 }
                    Rectangle { anchors.centerIn: parent; width: 12; height: 2; radius: 1; color: "#dddddd"; rotation: -45 }
                }
            }
        }
    }
}
