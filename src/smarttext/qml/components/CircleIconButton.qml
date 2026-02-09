import QtQuick 2.15
import QtQuick.Controls 2.15

ToolButton {
    id: btn

    property int size: 38
    required property string tooltipText
    required property url iconSource

    width: size
    height: size
    hoverEnabled: enabled

    // ---- tooltip tuning ----
    property int tooltipDelayMs: 350
    property int tooltipGap: 10

    Timer {
        id: tipDelay
        interval: btn.tooltipDelayMs
        repeat: false
        onTriggered: {
            if (btn.hovered && btn.enabled && btn.tooltipText.length > 0)
                tip.openTip()
        }
    }

    onHoveredChanged: {
        if (hovered) tipDelay.restart()
        else {
            tipDelay.stop()
            tip.closeTip()
        }
    }

    // Also close if disabled while hovered
    onEnabledChanged: if (!enabled) tip.closeTip()

    // ====== Custom styled ToolTip control instance ======
    ToolTip {
        id: tip
        // Overlay overlay is the right place so it draws above everything
        parent: Overlay.overlay
        visible: false
        text: ""

        // nice pill look
        background: Rectangle {
            radius: height / 2
            color: "#1e1e1e"
            border.color: "#3a3a3a"
            border.width: 1
        }

        contentItem: Item {
            implicitWidth: tipText.implicitWidth
            implicitHeight: tipText.implicitHeight

            Text {
                id: tipText
                anchors.centerIn: parent
                text: tip.text
                color: "#eaeaea"
                font.pixelSize: 11
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        // padding (ToolTip doesn't always have padding in older versions)
        implicitHeight: contentItem.implicitHeight + 10
        implicitWidth: contentItem.implicitWidth + 18

        function openTip() {
            if (!Overlay.overlay) return
            if (!btn.tooltipText || btn.tooltipText.length === 0) return

            tip.text = btn.tooltipText
            tip.positionTip()
            tip.visible = true
        }

        function closeTip() {
            tip.visible = false
        }

        function positionTip() {
            if (!Overlay.overlay) return

            // map button top-center to overlay coords
            var p = btn.mapToItem(Overlay.overlay, btn.width / 2, 0)

            var nx = p.x - tip.width / 2
            var ny = p.y - tip.height - btn.tooltipGap

            // clamp within overlay
            var margin = 6
            nx = Math.max(margin, Math.min(nx, Overlay.overlay.width - margin - tip.width))

            // if too close to top, show below
            if (ny < margin)
                ny = p.y + btn.height + btn.tooltipGap

            tip.x = nx
            tip.y = ny
        }

        // keep it attached if layout moves while visible (wheel animation etc.)
        Timer {
            interval: 16
            repeat: true
            running: tip.visible
            onTriggered: tip.positionTip()
        }
    }

    // ====== Button visuals ======
    background: Rectangle {
        radius: btn.width / 2
        border.width: 1
        border.color: "#3a3a3a"

        color: !btn.enabled ? "#2a2a2a"
              : btn.down    ? "#3a3a3a"
              : btn.hovered ? "#333333"
              : "#2a2a2a"
    }

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
