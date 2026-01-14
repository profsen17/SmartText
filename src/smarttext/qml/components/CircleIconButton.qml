import QtQuick 2.15
import QtQuick.Controls 2.15

ToolButton {
    id: btn

    property int size: 38
    required property string tooltipText
    required property url iconSource

    width: size
    height: size
    hoverEnabled: true

    // -------- Custom tooltip --------
    Timer {
        id: tipDelay
        interval: 350
        repeat: false
        onTriggered: tooltipBubble.visible = btn.hovered
    }

    onHoveredChanged: {
        if (hovered) tipDelay.restart()
        else {
            tipDelay.stop()
            tooltipBubble.visible = false
        }
    }

    Rectangle {
        id: tooltipBubble
        visible: false
        opacity: visible ? 1 : 0
        z: 999

        radius: 8
        color: "#CC1e1e1e"
        border.color: "#333333"
        border.width: 1

        implicitWidth: tipLabel.implicitWidth + 16
        implicitHeight: tipLabel.implicitHeight + 10

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 10

        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        Label {
            id: tipLabel
            text: btn.tooltipText
            color: "#eeeeee"
            font.pixelSize: 12
            anchors.centerIn: parent
        }
    }

    // -------- Button background --------
    background: Rectangle {
        radius: btn.width / 2
        border.width: 1
        border.color: "#3a3a3a"

        color: !btn.enabled ? "#2a2a2a"
            : btn.down ? "#3a3a3a"
            : btn.hovered ? "#333333"
            : "#2a2a2a"
    }

    // -------- SVG icon --------
    contentItem: Item {
        anchors.fill: parent

        Image {
            anchors.centerIn: parent
            source: btn.iconSource
            width: 18
            height: 18
            smooth: true
            mipmap: true
            opacity: btn.enabled ? 1.0 : 0.45
        }
    }
}
