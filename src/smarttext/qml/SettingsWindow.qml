import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"

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

    // TRUE while the "Press a shortcut" popup is open
    property bool capturingShortcut: capturePopup.visible

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
        color: "#1e1e1e"
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
                    color: "#161616"
                    border.color: "#2a2a2a"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Label {
                            text: "Menus"
                            color: "#dddddd"
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
                                { title: "Placeholder" }
                            ]

                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 40
                                radius: 8
                                color: index === menu.currentIndex ? "#2a2a2a" : "transparent"

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: settingsWin.selectedIndex = index
                                }

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    text: modelData.title
                                    color: "#dddddd"
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
                    color: "#161616"
                    border.color: "#2a2a2a"
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
                                    color: "#eeeeee"
                                    font.pixelSize: 18
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 60
                                    radius: 10
                                    color: "#111111"
                                    border.color: "#333333"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Label { text: "Font size"; color: "#dddddd"; font.pixelSize: 13 }
                                        Item { Layout.fillWidth: true }

                                        SpinBox {
                                            from: 8
                                            to: 36
                                            value: settingsStore ? settingsStore.fontSize : 11
                                            editable: true
                                            stepSize: 1

                                            // only write back on user change
                                            onValueModified: if (settingsStore) settingsStore.fontSize = value

                                            implicitWidth: 80
                                            implicitHeight: 28  // (you said you set this)

                                            background: Rectangle {
                                                radius: settingsWin.cornerRadius
                                                color: "#1e1e1e"
                                                border.color: "#333333"
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
                                    color: "#eeeeee"
                                    font.pixelSize: 18
                                }

                                // ---------- New ----------
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 60
                                    radius: 10
                                    color: "#111111"
                                    border.color: "#333333"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Label { text: "New"; color: "#dddddd"; font.pixelSize: 13 }
                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            width: 180
                                            height: 34
                                            radius: settingsWin.cornerRadius
                                            color: "#1e1e1e"
                                            border.color: "#333333"
                                            border.width: 1

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: capturePopup.openFor("new", settingsStore ? settingsStore.shortcutNew : settingsWin.defaultShortcutNew)
                                                onEntered: parent.color = "#222222"
                                                onExited: parent.color = "#1e1e1e"
                                            }

                                            Label {
                                                anchors.centerIn: parent
                                                text: settingsStore ? settingsStore.shortcutNew : settingsWin.defaultShortcutNew
                                                color: "#eeeeee"
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
                                    color: "#111111"
                                    border.color: "#333333"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Label { text: "Open"; color: "#dddddd"; font.pixelSize: 13 }
                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            width: 180
                                            height: 34
                                            radius: settingsWin.cornerRadius
                                            color: "#1e1e1e"
                                            border.color: "#333333"
                                            border.width: 1

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: capturePopup.openFor("open", settingsStore ? settingsStore.shortcutOpen : settingsWin.defaultShortcutOpen)
                                                onEntered: parent.color = "#222222"
                                                onExited: parent.color = "#1e1e1e"
                                            }

                                            Label {
                                                anchors.centerIn: parent
                                                text: settingsStore ? settingsStore.shortcutOpen : settingsWin.defaultShortcutOpen
                                                color: "#eeeeee"
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
                                    color: "#111111"
                                    border.color: "#333333"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Label { text: "Save"; color: "#dddddd"; font.pixelSize: 13 }
                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            width: 180
                                            height: 34
                                            radius: settingsWin.cornerRadius
                                            color: "#1e1e1e"
                                            border.color: "#333333"
                                            border.width: 1

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: capturePopup.openFor("save", settingsStore ? settingsStore.shortcutSave : settingsWin.defaultShortcutSave)
                                                onEntered: parent.color = "#222222"
                                                onExited: parent.color = "#1e1e1e"
                                            }

                                            Label {
                                                anchors.centerIn: parent
                                                text: settingsStore ? settingsStore.shortcutSave : settingsWin.defaultShortcutSave
                                                color: "#eeeeee"
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
                                    color: "#111111"
                                    border.color: "#333333"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        Label { text: "Save As"; color: "#dddddd"; font.pixelSize: 13 }
                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            width: 180
                                            height: 34
                                            radius: settingsWin.cornerRadius
                                            color: "#1e1e1e"
                                            border.color: "#333333"
                                            border.width: 1

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: capturePopup.openFor("saveAs", settingsStore ? settingsStore.shortcutSaveAs : settingsWin.defaultShortcutSaveAs)
                                                onEntered: parent.color = "#222222"
                                                onExited: parent.color = "#1e1e1e"
                                            }

                                            Label {
                                                anchors.centerIn: parent
                                                text: settingsStore ? settingsStore.shortcutSaveAs : settingsWin.defaultShortcutSaveAs
                                                color: "#eeeeee"
                                                font.pixelSize: 13
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }

                        // ===== Page 2: Placeholder =====
                        Item {
                            Label {
                                anchors.centerIn: parent
                                text: "Placeholder"
                                color: "#777777"
                                font.pixelSize: 16
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

        // center in the window overlay
        anchors.centerIn: Overlay.overlay

        property string actionKey: ""
        property string captured: ""
        
        property string errorText: ""

        function storeOrDefault(action) {
            // Returns the currently active shortcut for an action (normalized)
            if (settingsStore) {
                if (action === "new")    return settingsWin.norm(settingsStore.shortcutNew)
                if (action === "open")   return settingsWin.norm(settingsStore.shortcutOpen)
                if (action === "save")   return settingsWin.norm(settingsStore.shortcutSave)
                if (action === "saveAs") return settingsWin.norm(settingsStore.shortcutSaveAs)
            }
            // fallback to defaults
            if (action === "new")    return settingsWin.norm(settingsWin.defaultShortcutNew)
            if (action === "open")   return settingsWin.norm(settingsWin.defaultShortcutOpen)
            if (action === "save")   return settingsWin.norm(settingsWin.defaultShortcutSave)
            if (action === "saveAs") return settingsWin.norm(settingsWin.defaultShortcutSaveAs)
            return ""
        }

        function actionLabel(action) {
            if (action === "new") return "New"
            if (action === "open") return "Open"
            if (action === "save") return "Save"
            if (action === "saveAs") return "Save As"
            return action
        }

        function findConflict(action, value) {
            // Returns "" if no conflict, otherwise returns the conflicting actionKey
            const v = settingsWin.norm(value)
            const actions = ["new", "open", "save", "saveAs"]
            for (let i = 0; i < actions.length; i++) {
                const a = actions[i]
                if (a === action) continue
                if (storeOrDefault(a) === v) return a
            }
            return ""
        }

        function openFor(action, currentValue) {
            actionKey = action
            captured = currentValue
            errorText = ""          // NEW
            open()
            captureArea.forceActiveFocus()
        }

        function keyName(key, text) {
            // Prefer text when it's a normal printable letter/number
            if (text && text.length === 1) return text.toUpperCase()

            // Letters
            if (key >= Qt.Key_A && key <= Qt.Key_Z)
                return String.fromCharCode("A".charCodeAt(0) + (key - Qt.Key_A))

            // Numbers (top row)
            if (key >= Qt.Key_0 && key <= Qt.Key_9)
                return String.fromCharCode("0".charCodeAt(0) + (key - Qt.Key_0))

            // Function keys
            if (key >= Qt.Key_F1 && key <= Qt.Key_F35)
                return "F" + (key - Qt.Key_F1 + 1)

            // Common named keys
            if (key === Qt.Key_Tab) return "Tab"
            if (key === Qt.Key_Space) return "Space"
            if (key === Qt.Key_Return || key === Qt.Key_Enter) return "Enter"
            if (key === Qt.Key_Backspace) return "Backspace"
            if (key === Qt.Key_Delete) return "Del"
            if (key === Qt.Key_Escape) return "Esc"
            if (key === Qt.Key_Left) return "Left"
            if (key === Qt.Key_Right) return "Right"
            if (key === Qt.Key_Up) return "Up"
            if (key === Qt.Key_Down) return "Down"
            if (key === Qt.Key_Home) return "Home"
            if (key === Qt.Key_End) return "End"
            if (key === Qt.Key_PageUp) return "PgUp"
            if (key === Qt.Key_PageDown) return "PgDn"
            if (key === Qt.Key_Insert) return "Ins"

            // If we don't know, don't show a garbage number
            return ""
        }

        function isSingleTypeableKey(s) {
            // single character like A, 1, ., / etc.
            return s && s.length === 1
        }

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

            // must be at least 2 parts: e.g. Ctrl+N, Ctrl+Shift+S
            if (partsCount(s) < 2) return false

            // last token is the “key”
            const tokens = s.split("+")
            const key = tokens[tokens.length - 1]

            // reject if it's just a single typeable character as the "key" with no modifier
            if (!hasModifier(s) && isSingleTypeableKey(key)) return false

            // also reject if key is a single letter/number even WITH no modifier (covered above)
            // (with modifier it's fine: Ctrl+S is okay)

            return true
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
            color: "#161616"
            border.color: "#2a2a2a"
            border.width: 1
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Label {
                text: "Press a shortcut"
                color: "#eeeeee"
                font.pixelSize: 16
            }

            Rectangle {
                Layout.fillWidth: true
                height: 54
                radius: settingsWin.cornerRadius
                color: "#111111"
                border.color: "#333333"
                border.width: 1

                Item {
                    id: captureArea
                    anchors.fill: parent
                    focus: true

                    Keys.onPressed: (event) => {
                        // ignore pure modifier taps
                        if (event.key === Qt.Key_Control ||
                            event.key === Qt.Key_Shift ||
                            event.key === Qt.Key_Alt ||
                            event.key === Qt.Key_Meta) {
                            event.accepted = true
                            return
                        }

                        // Escape closes without applying
                        if (event.key === Qt.Key_Escape) {
                            event.accepted = true
                            capturePopup.close()
                            return
                        }

                        // Backspace clears
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

                        // ----- KEY NAME RESOLUTION -----
                        let k = ""

                        // Letters A–Z
                        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z) {
                            k = String.fromCharCode(
                                "A".charCodeAt(0) + (event.key - Qt.Key_A)
                            )
                        }
                        // Numbers 0–9
                        else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                            k = String.fromCharCode(
                                "0".charCodeAt(0) + (event.key - Qt.Key_0)
                            )
                        }
                        // Function keys
                        else if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35) {
                            k = "F" + (event.key - Qt.Key_F1 + 1)
                        }
                        // Named keys
                        else if (event.key === Qt.Key_Tab)        k = "Tab"
                        else if (event.key === Qt.Key_Space)      k = "Space"
                        else if (event.key === Qt.Key_Return ||
                                event.key === Qt.Key_Enter)      k = "Enter"
                        else if (event.key === Qt.Key_Delete)     k = "Del"
                        else if (event.key === Qt.Key_Escape)     k = "Esc"
                        else if (event.key === Qt.Key_Left)       k = "Left"
                        else if (event.key === Qt.Key_Right)      k = "Right"
                        else if (event.key === Qt.Key_Up)         k = "Up"
                        else if (event.key === Qt.Key_Down)       k = "Down"
                        else if (event.text && event.text.length === 1) {
                            // fallback for printable characters
                            k = event.text.toUpperCase()
                        }

                        if (k.length > 0)
                            parts.push(k)

                        capturePopup.captured = parts.join("+")
                        capturePopup.errorText = "" 
                        event.accepted = true
                    }

                    Label {
                        anchors.centerIn: parent
                        text: capturePopup.captured.length ? capturePopup.captured : "Press keys…"
                        color: capturePopup.captured.length ? "#eeeeee" : "#777777"
                        font.pixelSize: 14
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                visible: capturePopup.errorText.length > 0
                text: capturePopup.errorText
                color: "#d67a7a"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item { Layout.fillWidth: true }

                // Cancel
                Rectangle {
                    width: 96
                    height: 34
                    radius: settingsWin.cornerRadius
                    color: "#2a2a2a"
                    border.color: "#333333"
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: capturePopup.close()
                        onEntered: parent.color = "#333333"
                        onExited: parent.color = "#2a2a2a"
                    }

                    Label { anchors.centerIn: parent; text: "Cancel"; color: "#dddddd"; font.pixelSize: 13 }
                }

                // Apply
                Rectangle {
                    width: 96
                    height: 34
                    radius: settingsWin.cornerRadius
                    color: "#2a2a2a"
                    border.color: "#333333"
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!capturePopup.isValidShortcut(capturePopup.captured))
                                return

                            const conflict = capturePopup.findConflict(capturePopup.actionKey, capturePopup.captured)
                            if (conflict !== "") {
                                capturePopup.errorText =
                                    "That shortcut is already used by “" + capturePopup.actionLabel(conflict) + "”. Choose another."
                                return
                            }

                            capturePopup.applyToStore(capturePopup.actionKey, capturePopup.captured)
                            capturePopup.close()
                        }
                        onEntered: parent.color = "#333333"
                        onExited: parent.color = "#2a2a2a"
                    }

                    Label { anchors.centerIn: parent; text: "Apply"; color: "#dddddd"; font.pixelSize: 13 }
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
