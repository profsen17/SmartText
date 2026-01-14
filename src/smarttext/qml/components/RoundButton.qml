import QtQuick 2.15
import QtQuick.Controls 2.15

ToolButton {
    id: btn
    required property int cornerRadius

    background: Rectangle {
        radius: btn.cornerRadius
        border.color: "#3a3a3a"
        border.width: 1
        color: btn.down ? "#3a3a3a"
            : btn.hovered ? "#333333"
            : "#2a2a2a"
    }


    contentItem: Label {
        text: btn.text
        color: "#dddddd"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Label.ElideRight
    }
}
