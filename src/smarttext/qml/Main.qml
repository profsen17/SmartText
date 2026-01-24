import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 6.5
import "components"

ApplicationWindow {
    id: win
    width: 900
    height: 600
    visible: true

    flags: Qt.FramelessWindowHint
    color: "transparent"

    property int cornerRadius: 10
    property var appSafe: (typeof app !== "undefined" && app !== null) ? app : null
    property var settingsSafe: (typeof settingsStore !== "undefined" && settingsStore !== null) ? settingsStore : null
    property bool uiLocked: openDialog.visible || saveAsDialog.visible || settingsWindow.visible

    // ---- Shortcuts ----
    Shortcut {
        enabled: settingsSafe !== null
        sequence: settingsSafe ? settingsSafe.shortcutNew : ""
        onActivated: if (appSafe) appSafe.new_file()
    }

    Shortcut {
        enabled: settingsSafe !== null
        sequence: settingsSafe ? settingsSafe.shortcutOpen : ""
        onActivated: openDialog.open()
    }

    Shortcut {
        enabled: settingsSafe !== null
        sequence: settingsSafe ? settingsSafe.shortcutSave : ""
        onActivated: if (appSafe) appSafe.save()
    }

    Shortcut {
        enabled: settingsSafe !== null
        sequence: settingsSafe ? settingsSafe.shortcutSaveAs : ""
        onActivated: saveAsDialog.open()
    }

    Connections {
        target: appSafe
        function onRequestSaveAs() { saveAsDialog.open() }
    }

    title: appSafe
        ? (appSafe.documentTitle + (appSafe.modified ? " •" : ""))
        : "SmartText"

    onActiveChanged: {
        if (!active) {
            editorShell.sidebarOpen = false
            editorShell.arrowHovering = false
            editorShell.sidebarHovering = false
            editorShell.hovering = false
            sidebarCloseTimer.stop()
            hoverDelayTimer.stop()
            idleTimer.stop()
            editorShell.idleHidden = false
        }
    }

    Rectangle {
        id: rootBg
        anchors.fill: parent
        radius: cornerRadius
        color: "#1e1e1e"
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            TitleBar {
                Layout.fillWidth: true
                window: win
                cornerRadius: win.cornerRadius
                titleText: appSafe
                    ? (appSafe.documentTitle + (appSafe.modified ? " •" : ""))
                    : "SmartText"
            }

            // ---- Tabs strip ----
            Item {
                id: tabsBar
                Layout.fillWidth: true
                height: 44

                Rectangle {
                    anchors.fill: parent
                    radius: win.cornerRadius
                    color: "#1b1b1b"
                    border.color: "#2a2a2a"
                    border.width: 1
                }

                ListView {
                    id: tabsView
                    anchors.fill: parent
                    anchors.margins: 6
                    orientation: ListView.Horizontal
                    spacing: 8
                    clip: true

                    model: appSafe ? appSafe.tabsModel : null
                    currentIndex: appSafe ? appSafe.currentIndex : 0

                    delegate: Item {
                        id: tabItem
                        width: Math.max(140, tabText.implicitWidth + 46)
                        height: 32

                        property bool active: (index === tabsView.currentIndex)

                        Rectangle {
                            id: tabBg
                            anchors.fill: parent
                            radius: 10
                            color: tabItem.active ? "#111111" : "#232323"
                            border.color: tabItem.active ? "#333333" : "#2a2a2a"
                            border.width: 1
                            anchors.bottomMargin: tabItem.active ? -8 : 0
                        }

                        Rectangle {
                            visible: tabItem.active
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 10
                            y: parent.height - 2
                            color: "#111111"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (appSafe) appSafe.set_current_index(index)
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 10

                            Text {
                                id: tabText
                                anchors.verticalCenter: parent.verticalCenter
                                text: model.title
                                color: tabItem.active ? "#eaeaea" : "#bdbdbd"
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                width: tabItem.width - 44
                            }

                            Rectangle {
                                width: 18
                                height: 18
                                radius: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color: closeArea.containsMouse ? "#333333" : "transparent"

                                MouseArea {
                                    id: closeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: if (appSafe) appSafe.close_tab(index)
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 9
                                    height: 9
                                    radius: 4.5
                                    color: "#ffffff"
                                    visible: !!model.modified
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: "#cfcfcf"
                                    font.pixelSize: 14
                                    visible: !model.modified
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: editorShell
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // ---- Feel knobs ----
                property int overlayHeight: 140
                property int overlaySlide: 40
                property int buttonSlide: 10
                property real buttonBaseOpacity: 0.85
                property int idleDelayMs: 5000
                property int hoverDelayMs: 120

                property bool hovering: false
                property bool idleHidden: false
                property bool showOverlay: hovering && !idleHidden && !win.uiLocked && !hoverFrozen && !sidebarHovering

                // ---- Left sidebar ----
                property bool sidebarOpen: false
                property bool sidebarHovering: false
                property bool arrowHovering: false

                property int sidebarWidth: 64
                property int sidebarPad: 8
                property int sidebarPeek: 10

                property bool showLeftArrow: hovering && !idleHidden && !sidebarOpen && !win.uiLocked && !hoverFrozen
                property bool hoverFrozen: false

                function resetIdleTimer() {
                    if (!hovering) return
                    idleHidden = false
                    idleTimer.restart()
                }

                // --- Sidebar close delay ---
                Timer {
                    id: sidebarCloseTimer
                    interval: 250
                    repeat: false
                    onTriggered: editorShell.sidebarOpen = false
                }

                function cancelSidebarClose() { sidebarCloseTimer.stop() }

                function scheduleSidebarClose() {
                    if (!editorShell.arrowHovering && !editorShell.sidebarHovering)
                        sidebarCloseTimer.restart()
                }

                TextArea {
                    id: editor
                    anchors.fill: parent
                    wrapMode: TextArea.Wrap
                    padding: 12
                    color: "#eeeeee"
                    font.pixelSize: settingsSafe ? settingsSafe.fontSize : 11

                    background: Rectangle {
                        radius: cornerRadius
                        color: "#111111"
                        border.color: "#333333"
                        border.width: 1
                    }

                    text: appSafe ? appSafe.text : ""
                    onTextChanged: if (appSafe) appSafe.text = text

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Tab) {
                            event.accepted = true
                            const cursor = editor.cursorPosition
                            editor.insert(cursor, "    ")
                            editor.cursorPosition = cursor + 4
                        }
                    }
                }

                // IMPORTANT: tracking mouse area must NOT cover arrow/sidebar.
                // Put it BEFORE them (so they draw above), and keep it non-clickable.
                MouseArea {
                    id: activityTracker
                    z: 0
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onPositionChanged: {
                        if (win.uiLocked) return
                        if (editorShell.hovering) editorShell.resetIdleTimer()
                    }
                }

                // ---- Left arrow hint (hover to open) ----
                Item {
                    id: leftArrow
                    z: 20
                    width: 26
                    height: 52
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 6
                    visible: editorShell.showLeftArrow
                    opacity: visible ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: leftArrowArea.containsMouse ? "#2e2e2e" : "#252525"
                        border.color: "#3a3a3a"
                        border.width: 1
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: "#eaeaea"
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: leftArrowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton

                        onEntered: {
                            if (win.uiLocked || editorShell.hoverFrozen) return
                            editorShell.arrowHovering = true
                            editorShell.cancelSidebarClose()
                            editorShell.sidebarOpen = true
                        }
                        onExited: {
                            if (win.uiLocked) return
                            editorShell.arrowHovering = false
                            editorShell.scheduleSidebarClose()
                        }
                    }
                }

                // ---- Left pill sidebar ----
                Item {
                    id: leftSidebar
                    z: 20
                    width: editorShell.sidebarWidth
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.leftMargin: 6

                    transform: Translate { id: sidebarTx; x: -leftSidebar.width - 6 }
                    opacity: 0
                    property bool sidebarVisible: false
                    visible: sidebarVisible
                    enabled: opacity > 0.05   // don't steal hover/clicks while "invisible"

                    states: [
                        State {
                            name: "open"
                            when: editorShell.sidebarOpen && editorShell.hovering && !editorShell.idleHidden
                            PropertyChanges { target: sidebarTx; x: 0 }
                            PropertyChanges { target: leftSidebar; opacity: 1 }
                        },
                        State {
                            name: "closed"
                            when: !(editorShell.sidebarOpen && editorShell.hovering && !editorShell.idleHidden)
                            PropertyChanges { target: sidebarTx; x: -leftSidebar.width - 6 }
                            PropertyChanges { target: leftSidebar; opacity: 0 }
                        }
                    ]

                    transitions: [
                        Transition {
                            from: "closed"; to: "open"
                            SequentialAnimation {
                                ScriptAction { script: leftSidebar.sidebarVisible = true }
                                ParallelAnimation {
                                    NumberAnimation { target: sidebarTx; property: "x"; duration: 240; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: leftSidebar; property: "opacity"; duration: 160; easing.type: Easing.OutCubic }
                                }
                            }
                        },
                        Transition {
                            from: "open"; to: "closed"
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation { target: sidebarTx; property: "x"; duration: 200; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: leftSidebar; property: "opacity"; duration: 120; easing.type: Easing.OutCubic }
                                }
                                ScriptAction { script: leftSidebar.sidebarVisible = false }
                            }
                        }
                    ]

                    Rectangle {
                        id: pill
                        anchors.fill: parent
                        radius: width / 2
                        color: "#1b1b1b"
                        border.color: "#2a2a2a"
                        border.width: 1
                        clip: true
                    }

                    HoverHandler {
                        target: leftSidebar
                        onHoveredChanged: {
                            if (win.uiLocked) return
                            if (hovered) {
                                if (editorShell.hoverFrozen) return
                                editorShell.sidebarHovering = true
                                editorShell.sidebarOpen = true
                                editorShell.cancelSidebarClose()
                            } else {
                                editorShell.sidebarHovering = false
                                editorShell.scheduleSidebarClose()
                            }
                        }
                    }

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: editorShell.sidebarPad
                        clip: true

                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        Column {
                            width: parent.width
                            spacing: 10

                            CircleIconButton {
                                size: 38
                                tooltipText: "New"
                                iconSource: "../icons/new.svg"
                                onClicked: if (appSafe) appSafe.new_file()
                            }

                            CircleIconButton {
                                size: 38
                                tooltipText: "Open"
                                iconSource: "../icons/open.svg"
                                onClicked: openDialog.open()
                            }

                            CircleIconButton {
                                size: 38
                                tooltipText: "Save"
                                iconSource: "../icons/save.svg"
                                enabled: appSafe ? appSafe.modified : false
                                onClicked: if (appSafe) appSafe.save()
                            }

                            CircleIconButton {
                                size: 38
                                tooltipText: "Save As"
                                iconSource: "../icons/save_as.svg"
                                onClicked: saveAsDialog.open()
                            }

                            CircleIconButton {
                                size: 38
                                tooltipText: "Settings"
                                iconSource: "../icons/settings.svg"
                                onClicked: settingsWindow.visible = true
                            }
                        }
                    }
                }

                Timer {
                    id: hoverDelayTimer
                    interval: editorShell.hoverDelayMs
                    repeat: false
                    onTriggered: {
                        if (win.uiLocked || editorShell.hoverFrozen) return
                        editorShell.hovering = true
                        editorShell.idleHidden = false
                        editorShell.resetIdleTimer()
                    }
                }

                Connections {
                    target: win
                    function onUiLockedChanged() {
                        // Freeze hover interactions immediately when any menu/dialog is up,
                        // and keep them frozen until the mouse re-enters the editor area.
                        editorShell.hoverFrozen = true

                        // Hard-close hover UI so it can't fight animations.
                        editorShell.hovering = false
                        editorShell.idleHidden = false

                        editorShell.sidebarOpen = false
                        editorShell.arrowHovering = false
                        editorShell.sidebarHovering = false

                        editorShell.cancelSidebarClose()
                        hoverDelayTimer.stop()
                        idleTimer.stop()
                    }
                }

                HoverHandler {
                    target: editorShell
                    onHoveredChanged: {
                        if (win.uiLocked) return

                        if (hovered) {
                            // first re-entry after closing a dialog: unfreeze and start clean
                            if (editorShell.hoverFrozen) {
                                editorShell.hoverFrozen = false
                                hoverDelayTimer.restart()
                                return
                            }
                            hoverDelayTimer.restart()
                        } else {
                            hoverDelayTimer.stop()
                            editorShell.hovering = false
                            idleTimer.stop()
                            editorShell.idleHidden = false

                            editorShell.sidebarOpen = false
                            editorShell.arrowHovering = false
                            editorShell.sidebarHovering = false
                            sidebarCloseTimer.stop()
                        }
                    }
                }

                Timer {
                    id: idleTimer
                    interval: editorShell.idleDelayMs
                    repeat: false
                    onTriggered: editorShell.idleHidden = true
                }

                Item {
                    id: overlay
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 2
                    anchors.rightMargin: 2
                    anchors.bottomMargin: 2

                    height: editorShell.overlayHeight
                    enabled: editorShell.showOverlay
                    opacity: editorShell.showOverlay ? 1 : 0

                    transform: Translate {
                        id: overlayTranslate
                        y: editorShell.showOverlay ? 0 : editorShell.overlaySlide
                        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    }

                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Row {
                        id: leftActions
                        spacing: 10
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 14
                        anchors.bottomMargin: 14

                        CircleIconButton {
                            id: btnSettings
                            tooltipText: "Settings"
                            iconSource: "../icons/settings.svg"
                            onClicked: settingsWindow.show()
                        }
                    }

                    Row {
                        id: rightActions
                        spacing: 10
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 14
                        anchors.bottomMargin: 14

                        transform: Translate { id: actionsTranslate; y: 28 }

                        states: [
                            State {
                                name: "shown"
                                when: editorShell.showOverlay
                                PropertyChanges { target: actionsTranslate; y: 0 }
                            },
                            State {
                                name: "hidden"
                                when: !editorShell.showOverlay
                                PropertyChanges { target: actionsTranslate; y: 28 }
                            }
                        ]

                        transitions: [
                            Transition {
                                from: "hidden"; to: "shown"
                                SequentialAnimation {
                                    PauseAnimation { duration: 100 }
                                    ParallelAnimation {
                                        NumberAnimation { target: actionsTranslate; property: "y"; duration: 280; easing.type: Easing.OutCubic }
                                    }
                                }
                            },
                            Transition {
                                from: "shown"; to: "hidden"
                                ParallelAnimation {
                                    NumberAnimation { target: actionsTranslate; property: "y"; duration: 200; easing.type: Easing.OutCubic }
                                }
                            }
                        ]

                        function boostOpacity(btn, hovered) {
                            if (!editorShell.showOverlay) return
                            btn.opacity = hovered ? 1.0 : editorShell.buttonBaseOpacity
                        }

                        CircleIconButton {
                            id: btnNew
                            size: 38
                            tooltipText: "New"
                            iconSource: "../icons/new.svg"
                            onClicked: if (appSafe) appSafe.new_file()

                            opacity: 0
                            transform: Translate { id: trNew; y: editorShell.buttonSlide }
                            onHoveredChanged: rightActions.boostOpacity(btnNew, hovered)

                            states: [
                                State { name: "shown"; when: editorShell.showOverlay
                                    PropertyChanges { target: btnNew; opacity: editorShell.buttonBaseOpacity }
                                    PropertyChanges { target: trNew; y: 0 }
                                },
                                State { name: "hidden"; when: !editorShell.showOverlay
                                    PropertyChanges { target: btnNew; opacity: 0 }
                                    PropertyChanges { target: trNew; y: editorShell.buttonSlide }
                                }
                            ]

                            transitions: [
                                Transition {
                                    from: "hidden"; to: "shown"
                                    SequentialAnimation {
                                        PauseAnimation { duration: 0 }
                                        ParallelAnimation {
                                            NumberAnimation { target: btnNew; property: "opacity"; duration: 160; easing.type: Easing.OutCubic }
                                            NumberAnimation { target: trNew; property: "y"; duration: 220; easing.type: Easing.OutCubic }
                                        }
                                    }
                                },
                                Transition {
                                    from: "shown"; to: "hidden"
                                    ParallelAnimation {
                                        NumberAnimation { target: btnNew; property: "opacity"; duration: 120; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: trNew; property: "y"; duration: 160; easing.type: Easing.OutCubic }
                                    }
                                }
                            ]
                        }

                        CircleIconButton {
                            id: btnOpen
                            size: 38
                            tooltipText: "Open"
                            iconSource: "../icons/open.svg"
                            onClicked: openDialog.open()

                            opacity: 0
                            transform: Translate { id: trOpen; y: editorShell.buttonSlide }
                            onHoveredChanged: rightActions.boostOpacity(btnOpen, hovered)

                            states: [
                                State { name: "shown"; when: editorShell.showOverlay
                                    PropertyChanges { target: btnOpen; opacity: editorShell.buttonBaseOpacity }
                                    PropertyChanges { target: trOpen; y: 0 }
                                },
                                State { name: "hidden"; when: !editorShell.showOverlay
                                    PropertyChanges { target: btnOpen; opacity: 0 }
                                    PropertyChanges { target: trOpen; y: editorShell.buttonSlide }
                                }
                            ]

                            transitions: [
                                Transition {
                                    from: "hidden"; to: "shown"
                                    SequentialAnimation {
                                        PauseAnimation { duration: 50 }
                                        ParallelAnimation {
                                            NumberAnimation { target: btnOpen; property: "opacity"; duration: 160; easing.type: Easing.OutCubic }
                                            NumberAnimation { target: trOpen; property: "y"; duration: 220; easing.type: Easing.OutCubic }
                                        }
                                    }
                                },
                                Transition {
                                    from: "shown"; to: "hidden"
                                    ParallelAnimation {
                                        NumberAnimation { target: btnOpen; property: "opacity"; duration: 120; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: trOpen; property: "y"; duration: 160; easing.type: Easing.OutCubic }
                                    }
                                }
                            ]
                        }

                        CircleIconButton {
                            id: btnSave
                            size: 38
                            tooltipText: "Save"
                            iconSource: "../icons/save.svg"
                            enabled: appSafe ? appSafe.modified : false
                            onClicked: if (appSafe) appSafe.save()

                            property real shownOpacity: (enabled ? editorShell.buttonBaseOpacity : 0.45)

                            opacity: 0
                            transform: Translate { id: trSave; y: editorShell.buttonSlide }
                            onHoveredChanged: {
                                if (!editorShell.showOverlay) return
                                if (!btnSave.enabled) return
                                btnSave.opacity = hovered ? 1.0 : btnSave.shownOpacity
                            }

                            states: [
                                State { name: "shown"; when: editorShell.showOverlay
                                    PropertyChanges { target: btnSave; opacity: btnSave.shownOpacity }
                                    PropertyChanges { target: trSave; y: 0 }
                                },
                                State { name: "hidden"; when: !editorShell.showOverlay
                                    PropertyChanges { target: btnSave; opacity: 0 }
                                    PropertyChanges { target: trSave; y: editorShell.buttonSlide }
                                }
                            ]

                            transitions: [
                                Transition {
                                    from: "hidden"; to: "shown"
                                    SequentialAnimation {
                                        PauseAnimation { duration: 150 }
                                        ParallelAnimation {
                                            NumberAnimation { target: btnSave; property: "opacity"; duration: 160; easing.type: Easing.OutCubic }
                                            NumberAnimation { target: trSave; property: "y"; duration: 220; easing.type: Easing.OutCubic }
                                        }
                                    }
                                },
                                Transition {
                                    from: "shown"; to: "hidden"
                                    ParallelAnimation {
                                        NumberAnimation { target: btnSave; property: "opacity"; duration: 120; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: trSave; property: "y"; duration: 160; easing.type: Easing.OutCubic }
                                    }
                                }
                            ]
                        }

                        CircleIconButton {
                            id: btnSaveAs
                            size: 38
                            tooltipText: "Save As"
                            iconSource: "../icons/save_as.svg"
                            onClicked: saveAsDialog.open()

                            opacity: 0
                            transform: Translate { id: trSaveAs; y: editorShell.buttonSlide }
                            onHoveredChanged: rightActions.boostOpacity(btnSaveAs, hovered)

                            states: [
                                State { name: "shown"; when: editorShell.showOverlay
                                    PropertyChanges { target: btnSaveAs; opacity: editorShell.buttonBaseOpacity }
                                    PropertyChanges { target: trSaveAs; y: 0 }
                                },
                                State { name: "hidden"; when: !editorShell.showOverlay
                                    PropertyChanges { target: btnSaveAs; opacity: 0 }
                                    PropertyChanges { target: trSaveAs; y: editorShell.buttonSlide }
                                }
                            ]

                            transitions: [
                                Transition {
                                    from: "hidden"; to: "shown"
                                    SequentialAnimation {
                                        PauseAnimation { duration: 200 }
                                        ParallelAnimation {
                                            NumberAnimation { target: btnSaveAs; property: "opacity"; duration: 160; easing.type: Easing.OutCubic }
                                            NumberAnimation { target: trSaveAs; property: "y"; duration: 220; easing.type: Easing.OutCubic }
                                        }
                                    }
                                },
                                Transition {
                                    from: "shown"; to: "hidden"
                                    ParallelAnimation {
                                        NumberAnimation { target: btnSaveAs; property: "opacity"; duration: 120; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: trSaveAs; property: "y"; duration: 160; easing.type: Easing.OutCubic }
                                    }
                                }
                            ]
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: openDialog
        title: "Open file"
        fileMode: FileDialog.OpenFile
        options: FileDialog.DontUseNativeDialog
        onAccepted: if (appSafe) appSafe.open_file(selectedFile.toString())
    }

    FileDialog {
        id: saveAsDialog
        title: "Save file as"
        fileMode: FileDialog.SaveFile
        options: FileDialog.DontUseNativeDialog
        onAccepted: if (appSafe) appSafe.save_as(selectedFile.toString())
    }

    SettingsWindow { id: settingsWindow }
}
