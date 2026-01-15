import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"
import "components/themes.js" as Themes

ApplicationWindow {
    id: settingsWin
    width: 720
    height: 440
    visible: false
    title: "Settings"
    color: "transparent"
    flags: Qt.FramelessWindowHint

    // UI-only state
    property int selectedIndex: 0
    property int cornerRadius: 10

    // Defaults (for the popup “Cancel/Apply” flow and future reset)
    readonly property string defaultShortcutNew: "Ctrl+N"
    readonly property string defaultShortcutOpen: "Ctrl+O"
    readonly property string defaultShortcutSave: "Ctrl+S"
    readonly property string defaultShortcutSaveAs: "Ctrl+Shift+S"

    readonly property var palette: Themes.get((settingsStore && settingsStore.theme) ? settingsStore.theme : "Dark") || Themes.get("Dark")

    function norm(seq) {
        if (!seq) return ""
        let s = ("" + seq).replace(/\s+/g, "")
        s = s.replace(/CTRL/ig, "Ctrl")
             .replace(/SHIFT/ig, "Shift")
             .replace(/ALT/ig, "Alt")
             .replace(/META/ig, "Meta")
        return s
    }

    // =================== ROOT ===================
    Rectangle {
        anchors.fill: parent
        radius: settingsWin.cornerRadius
        color: palette.windowBg
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // ---- Top navbar ----
            TitleBar {
                Layout.fillWidth: true
                window: settingsWin
                cornerRadius: settingsWin.cornerRadius
                titleText: "Settings"
                palette: palette
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // ---------- SIDEBAR ----------
                Rectangle {
                    Layout.preferredWidth: 210
                    Layout.fillHeight: true
                    radius: settingsWin.cornerRadius
                    color: palette.cardBg
                    border.color: palette.border
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Label {
                            text: "Menus"
                            color: palette.textSoft
                            font.pixelSize: 14
                        }

                        ListView {
                            id: menu
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 6
                            currentIndex: settingsWin.selectedIndex

                            model: [
                                { title: "TextArea" },
                                { title: "Shortcuts" },
                                { title: "Look" }
                            ]

                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 40
                                radius: 8
                                color: index === menu.currentIndex ? palette.btnBg : "transparent"

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: settingsWin.selectedIndex = index
                                }

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    text: modelData.title
                                    color: palette.textSoft
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }

                // ---------- MAIN CONTENT ----------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: settingsWin.cornerRadius
                    color: palette.cardBg
                    border.color: palette.border
                    border.width: 1

                    StackLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        currentIndex: settingsWin.selectedIndex

                        // ===== Page 0: TextArea =====
                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 16

                                Label {
                                    text: "TextArea"
                                    color: palette.text
                                    font.pixelSize: 18
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 60
                                    radius: 10
                                    color: palette.surface2
                                    border.color: palette.editorBorder
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Label { text: "Font size"; color: palette.textSoft; font.pixelSize: 13 }
                                        Item { Layout.fillWidth: true }

                                        SpinBox {
                                            from: 8
                                            to: 36
                                            value: settingsStore ? settingsStore.fontSize : 11
                                            editable: true
                                            stepSize: 1

                                            onValueModified: if (settingsStore) settingsStore.fontSize = value

                                            implicitWidth: 80
                                            implicitHeight: 28

                                            background: Rectangle {
                                                radius: settingsWin.cornerRadius
                                                color: palette.cardBg
                                                border.color: palette.borderStrong
                                                border.width: 1
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }

                        // ===== Page 1: Shortcuts =====
                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 16

                                Label {
                                    text: "Shortcuts"
                                    color: palette.text
                                    font.pixelSize: 18
                                }

                                // ---------- helper for shortcut rows ----------
                                function hoverIn(rect)  { rect.color = palette.btnHover }
                                function hoverOut(rect) { rect.color = palette.btnBg }

                                // ---------- New ----------
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 60
                                    radius: 10
                                    color: palette.surface2
                                    border.color: palette.editorBorder
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Label { text: "New"; color: palette.textSoft; font.pixelSize: 13 }
                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            id: scNew
                                            width: 180
                                            height: 34
                                            radius: settingsWin.cornerRadius
                                            color: palette.btnBg
                                            border.color: palette.borderStrong
                                            border.width: 1

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: capturePopup.openFor("new", settingsStore ? settingsStore.shortcutNew : settingsWin.defaultShortcutNew)
                                                onEntered: settingsWin.selectedIndex = settingsWin.selectedIndex, hoverIn(scNew)
                                                onExited: hoverOut(scNew)
                                            }

                                            Label {
                                                anchors.centerIn: parent
                                                text: settingsStore ? settingsStore.shortcutNew : settingsWin.defaultShortcutNew
                                                color: palette.text
                                                font.pixelSize: 13
                                            }
                                        }
                                    }
                                }

                                // ---------- Open ----------
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 60
                                    radius: 10
                                    color: palette.surface2
                                    border.color: palette.editorBorder
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Label { text: "Open"; color: palette.textSoft; font.pixelSize: 13 }
                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            id: scOpen
                                            width: 180
                                            height: 34
                                            radius: settingsWin.cornerRadius
                                            color: palette.btnBg
                                            border.color: palette.borderStrong
                                            border.width: 1

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: capturePopup.openFor("open", settingsStore ? settingsStore.shortcutOpen : settingsWin.defaultShortcutOpen)
                                                onEntered: hoverIn(scOpen)
                                                onExited: hoverOut(scOpen)
                                            }

                                            Label {
                                                anchors.centerIn: parent
                                                text: settingsStore ? settingsStore.shortcutOpen : settingsWin.defaultShortcutOpen
                                                color: palette.text
                                                font.pixelSize: 13
                                            }
                                        }
                                    }
                                }

                                // ---------- Save ----------
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 60
                                    radius: 10
                                    color: palette.surface2
                                    border.color: palette.editorBorder
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Label { text: "Save"; color: palette.textSoft; font.pixelSize: 13 }
                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            id: scSave
                                            width: 180
                                            height: 34
                                            radius: settingsWin.cornerRadius
                                            color: palette.btnBg
                                            border.color: palette.borderStrong
                                            border.width: 1

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: capturePopup.openFor("save", settingsStore ? settingsStore.shortcutSave : settingsWin.defaultShortcutSave)
                                                onEntered: hoverIn(scSave)
                                                onExited: hoverOut(scSave)
                                            }

                                            Label {
                                                anchors.centerIn: parent
                                                text: settingsStore ? settingsStore.shortcutSave : settingsWin.defaultShortcutSave
                                                color: palette.text
                                                font.pixelSize: 13
                                            }
                                        }
                                    }
                                }

                                // ---------- Save As ----------
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 60
                                    radius: 10
                                    color: palette.surface2
                                    border.color: palette.editorBorder
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Label { text: "Save As"; color: palette.textSoft; font.pixelSize: 13 }
                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            id: scSaveAs
                                            width: 180
                                            height: 34
                                            radius: settingsWin.cornerRadius
                                            color: palette.btnBg
                                            border.color: palette.borderStrong
                                            border.width: 1

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: capturePopup.openFor("saveAs", settingsStore ? settingsStore.shortcutSaveAs : settingsWin.defaultShortcutSaveAs)
                                                onEntered: hoverIn(scSaveAs)
                                                onExited: hoverOut(scSaveAs)
                                            }

                                            Label {
                                                anchors.centerIn: parent
                                                text: settingsStore ? settingsStore.shortcutSaveAs : settingsWin.defaultShortcutSaveAs
                                                color: palette.text
                                                font.pixelSize: 13
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }

                        // ===== Page 2: Look =====
                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 16

                                Label {
                                    text: "Look"
                                    color: palette.text
                                    font.pixelSize: 18
                                }

                                Rectangle {
                                    id: themePill
                                    Layout.fillWidth: true
                                    height: 54
                                    radius: settingsWin.cornerRadius
                                    color: palette.surface2
                                    border.color: palette.editorBorder
                                    border.width: 1

                                    property int segmentCount: 3
                                    property real pad: settingsWin.cornerRadius
                                    property real segW: (width - pad*2) / segmentCount
                                    property real thumbX: pad + selected * segW

                                    property int selected: (settingsStore && settingsStore.theme === "White") ? 1
                                                         : (settingsStore && settingsStore.theme === "Purple") ? 2
                                                         : 0

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: themePill.pad
                                        radius: (themePill.height - themePill.pad*2) / 2
                                        color: palette.chromeBg
                                    }

                                    Rectangle {
                                        id: thumb
                                        x: themePill.thumbX
                                        y: themePill.pad + 2
                                        width: themePill.segW
                                        height: themePill.height - (themePill.pad + 2) * 2
                                        radius: height / 2
                                        color: palette.cardBg
                                        border.color: palette.borderStrong
                                        border.width: 1

                                        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                                    }

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: themePill.pad
                                        spacing: 0

                                        function labelColor(i) {
                                            return (themePill.selected === i) ? palette.text : palette.textMuted
                                        }

                                        Item {
                                            width: themePill.segW
                                            height: parent.height
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    themePill.selected = 0
                                                    if (settingsStore) settingsStore.theme = "Dark"
                                                }
                                            }
                                            Text { anchors.centerIn: parent; text: "Dark"; color: parent.parent.labelColor(0); font.pixelSize: 13 }
                                        }

                                        Item {
                                            width: themePill.segW
                                            height: parent.height
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    themePill.selected = 1
                                                    if (settingsStore) settingsStore.theme = "White"
                                                }
                                            }
                                            Text { anchors.centerIn: parent; text: "White"; color: parent.parent.labelColor(1); font.pixelSize: 13 }
                                        }

                                        Item {
                                            width: themePill.segW
                                            height: parent.height
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    themePill.selected = 2
                                                    if (settingsStore) settingsStore.theme = "Purple"
                                                }
                                            }
                                            Text { anchors.centerIn: parent; text: "Purple"; color: parent.parent.labelColor(2); font.pixelSize: 13 }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }
                    }
                }
            }
        }
    }

    // =================== Capture Popup ===================
    Popup {
        id: capturePopup
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose

        width: 360
        height: 190
        anchors.centerIn: Overlay.overlay

        property string actionKey: ""
        property string captured: ""

        function isSingleTypeableKey(s) { return s && s.length === 1 }
        function partsCount(s) {
            if (!s) return 0
            return s.split("+").filter(p => p.length > 0).length
        }
        function hasModifier(s) {
            if (!s) return false
            return s.indexOf("Ctrl+") === 0
                || s.indexOf("Alt+") === 0
                || s.indexOf("Shift+") === 0
                || s.indexOf("Meta+") === 0
                || s.indexOf("+Ctrl+") !== -1
                || s.indexOf("+Alt+") !== -1
                || s.indexOf("+Shift+") !== -1
                || s.indexOf("+Meta+") !== -1
        }
        function isValidShortcut(s) {
            s = settingsWin.norm(s)
            if (partsCount(s) < 2) return false
            const tokens = s.split("+")
            const key = tokens[tokens.length - 1]
            if (!hasModifier(s) && isSingleTypeableKey(key)) return false
            return true
        }

        function openFor(action, currentValue) {
            actionKey = action
            captured = currentValue
            open()
            captureArea.forceActiveFocus()
        }

        function applyToStore(action, value) {
            if (!settingsStore) return
            const v = settingsWin.norm(value)
            if (action === "new") settingsStore.shortcutNew = v
            else if (action === "open") settingsStore.shortcutOpen = v
            else if (action === "save") settingsStore.shortcutSave = v
            else if (action === "saveAs") settingsStore.shortcutSaveAs = v
        }

        background: Rectangle {
            radius: settingsWin.cornerRadius
            color: palette.cardBg
            border.color: palette.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Label {
                text: "Press a shortcut"
                color: palette.text
                font.pixelSize: 16
            }

            Rectangle {
                Layout.fillWidth: true
                height: 54
                radius: settingsWin.cornerRadius
                color: palette.surface2
                border.color: palette.editorBorder
                border.width: 1

                Item {
                    id: captureArea
                    anchors.fill: parent
                    focus: true

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Control ||
                            event.key === Qt.Key_Shift ||
                            event.key === Qt.Key_Alt ||
                            event.key === Qt.Key_Meta) {
                            event.accepted = true
                            return
                        }

                        if (event.key === Qt.Key_Escape) {
                            event.accepted = true
                            capturePopup.close()
                            return
                        }

                        if (event.key === Qt.Key_Backspace) {
                            event.accepted = true
                            capturePopup.captured = ""
                            return
                        }

                        let parts = []
                        if (event.modifiers & Qt.ControlModifier) parts.push("Ctrl")
                        if (event.modifiers & Qt.ShiftModifier)   parts.push("Shift")
                        if (event.modifiers & Qt.AltModifier)     parts.push("Alt")
                        if (event.modifiers & Qt.MetaModifier)    parts.push("Meta")

                        let k = ""
                        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z) {
                            k = String.fromCharCode("A".charCodeAt(0) + (event.key - Qt.Key_A))
                        } else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                            k = String.fromCharCode("0".charCodeAt(0) + (event.key - Qt.Key_0))
                        } else if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35) {
                            k = "F" + (event.key - Qt.Key_F1 + 1)
                        } else if (event.key === Qt.Key_Tab)        k = "Tab"
                        else if (event.key === Qt.Key_Space)        k = "Space"
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) k = "Enter"
                        else if (event.key === Qt.Key_Delete)       k = "Del"
                        else if (event.key === Qt.Key_Escape)       k = "Esc"
                        else if (event.key === Qt.Key_Left)         k = "Left"
                        else if (event.key === Qt.Key_Right)        k = "Right"
                        else if (event.key === Qt.Key_Up)           k = "Up"
                        else if (event.key === Qt.Key_Down)         k = "Down"
                        else if (event.text && event.text.length === 1) k = event.text.toUpperCase()

                        if (k.length > 0) parts.push(k)
                        capturePopup.captured = parts.join("+")
                        event.accepted = true
                    }

                    Label {
                        anchors.centerIn: parent
                        text: capturePopup.captured.length ? capturePopup.captured : "Press keys…"
                        color: capturePopup.captured.length ? palette.text : palette.textMuted
                        font.pixelSize: 14
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: cancelBtn
                    width: 96
                    height: 34
                    radius: settingsWin.cornerRadius
                    color: palette.btnBg
                    border.color: palette.borderStrong
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: capturePopup.close()
                        onEntered: cancelBtn.color = palette.btnHover
                        onExited: cancelBtn.color = palette.btnBg
                    }

                    Label { anchors.centerIn: parent; text: "Cancel"; color: palette.textSoft; font.pixelSize: 13 }
                }

                Rectangle {
                    id: applyBtn
                    width: 96
                    height: 34
                    radius: settingsWin.cornerRadius
                    color: palette.btnBg
                    border.color: palette.borderStrong
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!capturePopup.isValidShortcut(capturePopup.captured))
                                return
                            capturePopup.applyToStore(capturePopup.actionKey, capturePopup.captured)
                            capturePopup.close()
                        }
                        onEntered: applyBtn.color = palette.btnHover
                        onExited: applyBtn.color = palette.btnBg
                    }

                    Label { anchors.centerIn: parent; text: "Apply"; color: palette.textSoft; font.pixelSize: 13 }
                }

                Label {
                    visible: capturePopup.captured.length > 0 && !capturePopup.isValidShortcut(capturePopup.captured)
                    text: "Shortcut must include a modifier (Ctrl/Alt/Shift/Meta) and at least 2 keys."
                    color: "#d67a7a"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
    }
}
