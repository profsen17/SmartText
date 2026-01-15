import QtQuick 2.15
import QtQuick.Controls 2.15

ToolButton {
    id: btn

    property int size: 38
    required property string tooltipText
    required property url iconSource

    // Optional theme palette (pass win.palette)
    property var palette: null

    // Fallbacks (if palette is not passed)
    property color _border:      palette ? palette.editorBorder : "#3a3a3a"
    property color _btnBg:       palette ? palette.btnBg        : "#2a2a2a"
    property color _btnHover:    palette ? palette.btnHover     : "#333333"
    property color _btnDown:     palette ? palette.btnHover     : "#3a3a3a"
    property color _tooltipBg:   palette ? palette.chromeBg     : "#1e1e1e"
    property color _tooltipText: palette ? palette.text         : "#eeeeee"
    property color _tooltipBorder: palette ? palette.borderStrong : "#333333"

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
        color: Qt.rgba(btn._tooltipBg.r, btn._tooltipBg.g, btn._tooltipBg.b, 0.80)
        border.color: btn._tooltipBorder
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
            color: btn._tooltipText
            font.pixelSize: 12
            anchors.centerIn: parent
        }
    }

    // -------- Button background --------
    background: Rectangle {
        radius: btn.width / 2
        border.width: 1
        border.color: btn._border

        color: !btn.enabled ? btn._btnBg
            : btn.down ? btn._btnDown
            : btn.hovered ? btn._btnHover
            : btn._btnBg
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
