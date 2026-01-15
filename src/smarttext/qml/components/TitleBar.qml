import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: bar

    required property var window
    required property int cornerRadius
    property string titleText: "SmartText"

    // Optional theme palette: pass it from parent windows
    // Example: TitleBar { palette: win.palette }
    property var palette: null

    height: 42
    radius: cornerRadius
    clip: true

    // Theme-resolved colors
    readonly property color _barBg:            palette ? palette.chromeBg     : barColor
    readonly property color _text:             palette ? palette.textSoft     : textColor
    readonly property color _icon:             palette ? palette.text         : textColor
    readonly property color _btnBg:            palette ? palette.btnBg        : barColor
    readonly property color _btnHover:         palette ? palette.btnHover     : hoverColor
    readonly property color _dangerHover:      palette ? palette.dangerHover  : dangerHoverColor

    color: _barBg

    // Drag region behind the buttons
    MouseArea {
        anchors.fill: parent
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
            color: bar._text
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
                hoverEnabled: true
                onClicked: if (bar.window) bar.window.showMinimized()

                background: Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: minBtn.hovered ? bar._btnHover : bar._btnBg
                }

                contentItem: Item {
                    width: 12; height: 12
                    anchors.centerIn: parent
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12; height: 2; radius: 1
                        color: bar._icon
                    }
                }
            }

            // Maximize
            ToolButton {
                id: maxBtn
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                hoverEnabled: true
                onClicked: {
                    if (!bar.window) return
                    if (bar.window.visibility === Window.Maximized) bar.window.showNormal()
                    else bar.window.showMaximized()
                }

                background: Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: maxBtn.hovered ? bar._btnHover : bar._btnBg
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
                        border.color: bar._icon
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
                            border.color: bar._icon
                            border.width: 2
                        }

                        Rectangle {
                            x: 0
                            y: 3
                            width: 8
                            height: 8
                            radius: 2
                            color: "transparent"
                            border.color: bar._icon
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
                hoverEnabled: true
                onClicked: if (bar.window) bar.window.close()

                background: Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: closeBtn.hovered ? bar._dangerHover : bar._btnBg
                }

                contentItem: Item {
                    width: 12; height: 12
                    anchors.centerIn: parent
                    Rectangle { anchors.centerIn: parent; width: 12; height: 2; radius: 1; color: bar._icon; rotation: 45 }
                    Rectangle { anchors.centerIn: parent; width: 12; height: 2; radius: 1; color: bar._icon; rotation: -45 }
                }
            }
        }
    }
}
