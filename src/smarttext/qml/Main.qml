import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
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

    property bool restoring: false
    property bool pendingRestore: false
    property int restoreToken: 0

    function restoreEditorState() {
        if (!appSafe) return
        restoring = true
        restoreToken++
        const tok = restoreToken

        Qt.callLater(() => Qt.callLater(() => {
            if (tok !== restoreToken) return
            if (!appSafe || !editorScroll.contentItem) { restoring = false; return }

            // IMPORTANT: load doc text first (no binding!)
            editor.text = appSafe.text

            const pos = Math.max(0, Math.min(appSafe.cursorPosition, editor.length))
            editor.cursorPosition = pos
            editorScroll.contentItem.contentY = Math.max(0, appSafe.scrollY)

            win.pendingRestore = false

            Qt.callLater(() => {
                if (tok !== restoreToken) return
                editor.cursorPosition = pos
                restoring = false
            })
        }))
    }

    // ---- Shortcuts ----
    Shortcut {
        enabled: settingsSafe !== null
                && !win.uiLocked
                && !(settingsWindow && settingsWindow.capturingShortcut)
        sequence: settingsSafe ? settingsSafe.shortcutNew : ""
        onActivated: if (appSafe) appSafe.new_file()
    }

    Shortcut {
        enabled: settingsSafe !== null
                && !win.uiLocked
                && !(settingsWindow && settingsWindow.capturingShortcut)
        sequence: settingsSafe ? settingsSafe.shortcutOpen : ""
        onActivated: openDialog.open()
    }

    Shortcut {
        enabled: settingsSafe !== null
                && !win.uiLocked
                && !(settingsWindow && settingsWindow.capturingShortcut)
        sequence: settingsSafe ? settingsSafe.shortcutSave : ""
        onActivated: if (appSafe) appSafe.save()
    }

    Shortcut {
        enabled: settingsSafe !== null
                && !win.uiLocked
                && !(settingsWindow && settingsWindow.capturingShortcut)
        sequence: settingsSafe ? settingsSafe.shortcutSaveAs : ""
        onActivated: saveAsDialog.open()
    }

    Connections {
        target: appSafe
        function onRequestSaveAs() { saveAsDialog.open() }
    }

    Connections {
        target: appSafe
        function onCurrentIndexChanged() {
            win.pendingRestore = true
        }
    }

    Connections {
        target: appSafe
        function onTextChanged() {
            // Only restore when the text changed because we switched docs,
            // NOT when the user is typing.
            if (!win.pendingRestore) return
            win.pendingRestore = false
            win.restoreEditorState()
        }
    }

    Component.onCompleted: restoreEditorState()

    title: appSafe
        ? (appSafe.documentTitle + (appSafe.modified ? " •" : ""))
        : "SmartText"

    onActiveChanged: {
        if (active) {
            // make cursor blink immediately on startup / when window becomes active
            Qt.callLater(() => editor.forceActiveFocus())
            return
        }

        // your existing "lost focus" cleanup
        editorShell.sidebarOpen = false
        editorShell.arrowHovering = false
        editorShell.sidebarHovering = false
        editorShell.hovering = false
        sidebarCloseTimer.stop()
        hoverDelayTimer.stop()
        idleTimer.stop()
        editorShell.idleHidden = false
    }

    Item {
        id: topHandleLayer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 32
        z: 999999

        property int handleW: 160
        property int handleH: 10
        property real targetCenterX: width / 2

        // "latch" that survives Wayland/system-move weirdness
        property bool forceVisible: false

        // becomes true once we see mouse movement again (meaning system move ended)
        property bool postDragArmed: false

        function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

        property bool hoveringTop: hotZone.containsMouse || handleArea.containsMouse
        property bool showing: (hoveringTop || forceVisible) && !win.uiLocked

        MouseArea {
            id: hotZone
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            onEntered: {
                topHandleLayer.targetCenterX =
                    topHandleLayer.clamp(mouseX,
                                        topHandleLayer.handleW / 2,
                                        topHandleLayer.width - topHandleLayer.handleW / 2)

                // If we were in "post-drag armed" state, entering means the move ended
                // and the user is back interacting with us.
                if (topHandleLayer.forceVisible)
                    topHandleLayer.postDragArmed = true
            }

            onPositionChanged: {
                topHandleLayer.targetCenterX =
                    topHandleLayer.clamp(mouseX,
                                        topHandleLayer.handleW / 2,
                                        topHandleLayer.width - topHandleLayer.handleW / 2)

                // Seeing position changes again is the reliable "we're back" signal.
                if (topHandleLayer.forceVisible)
                    topHandleLayer.postDragArmed = true
            }

            onExited: {
                // Only allow hiding AFTER we have seen mouse movement again post-drag.
                if (topHandleLayer.forceVisible && topHandleLayer.postDragArmed) {
                    topHandleLayer.forceVisible = false
                    topHandleLayer.postDragArmed = false
                }
            }
        }

        Item {
            id: dragHandle
            width: topHandleLayer.handleW
            height: topHandleLayer.handleH + 6
            x: topHandleLayer.targetCenterX - width / 2

            y: topHandleLayer.showing ? 0 : -height
            opacity: topHandleLayer.showing ? (handleVisual.over ? 1.0 : 0.9) : 0

            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            // Shadow lives behind
            MultiEffect {
                anchors.fill: handleVisual
                source: handleVisual
                shadowEnabled: true
                shadowOpacity: 0.35
                shadowBlur: 0.6
                shadowVerticalOffset: 2
                visible: topHandleLayer.showing
            }

            Rectangle {
                id: handleVisual
                anchors.fill: parent
                radius: height / 2

                // optional but helps edge quality
                antialiasing: true

                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#343434" }
                    GradientStop { position: 1.0; color: "#242424" }
                }
                border.color: "#4a4a4a"
                border.width: 1

                // states for visuals
                property bool down: handleArea.pressed
                property bool over: handleArea.containsMouse || hotZone.containsMouse

                scale: down ? 0.98 : (over ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: parent.width * 0.45
                    height: 2
                    radius: 1
                    color: "#5a5a5a"
                    opacity: 0.6
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    opacity: handleVisual.down ? 0.95 : (handleVisual.over ? 0.85 : 0.70)
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    Repeater {
                        model: 7
                        delegate: Rectangle {
                            width: 3; height: 3
                            radius: 1.5
                            color: "#d0d0d0"
                            opacity: index % 2 === 0 ? 1.0 : 0.75
                            antialiasing: true
                        }
                    }
                }

                MouseArea {
                    id: handleArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    onPressed: {
                        topHandleLayer.forceVisible = true
                        topHandleLayer.postDragArmed = false
                        if (win && win.startSystemMove) win.startSystemMove()
                    }

                    onDoubleClicked: {
                        if (win.visibility === Window.Maximized) win.showNormal()
                        else win.showMaximized()
                    }
                }
            }
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

            // ---- Tabs strip ----
            Item {
                id: tabsBar
                Layout.fillWidth: true
                height: 44
                property real windowControlsWidth: windowControls.implicitWidth + 12
                property bool tabsOverflowing: tabsView.contentWidth > tabsView.width

                Rectangle {
                    anchors.fill: parent
                    radius: win.cornerRadius
                    color: "#1b1b1b"
                    border.color: "#2a2a2a"
                    border.width: 1
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onPressed: {
                        if (win && win.startSystemMove) win.startSystemMove()
                    }
                    onDoubleClicked: {
                        if (!win) return
                        if (win.visibility === Window.Maximized) win.showNormal()
                        else win.showMaximized()
                    }
                    z: 0
                }

                ListView {
                    id: tabsView
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6 + tabsBar.windowControlsWidth
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    orientation: ListView.Horizontal
                    spacing: 8
                    clip: true
                    z: 1

                    model: appSafe ? appSafe.tabsModel : null
                    currentIndex: appSafe ? appSafe.currentIndex : 0

                    move: Transition {
                        NumberAnimation { properties: "x"; duration: 220; easing.type: Easing.OutCubic }
                    }

                    // Smoothly slide remaining tabs into place when one is removed
                    displaced: Transition {
                        NumberAnimation {
                            properties: "x"
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Animate the tab being closed: slide up + fade out
                    remove: Transition {
                        ParallelAnimation {
                            NumberAnimation {
                                properties: "y"
                                to: -18
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                properties: "opacity"
                                to: 0
                                duration: 140
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // Animate a newly created tab: drop in from above + fade in
                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation {
                                properties: "y"
                                from: -18
                                to: 0
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                properties: "opacity"
                                from: 0
                                to: 1
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // Optional: animate initial load too (when the model is first shown)
                    populate: Transition {
                        ParallelAnimation {
                            NumberAnimation {
                                properties: "y"
                                from: -10
                                to: 0
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                properties: "opacity"
                                from: 0
                                to: 1
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

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

                Item {
                    id: windowControlsWrap
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 6
                    width: windowControls.implicitWidth
                    height: windowControls.implicitHeight
                    z: 3

                    RowLayout {
                        id: windowControls
                        anchors.fill: parent
                        spacing: 6
                        z: 3

                        ToolButton {
                            id: minBtn
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            hoverEnabled: true
                            onClicked: if (win) win.showMinimized()

                            background: Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: minBtn.hovered ? "#3a3a3a" : "#2a2a2a"
                            }

                            contentItem: Item {
                                width: 12
                                height: 12
                                anchors.centerIn: parent
                                Rectangle { anchors.centerIn: parent; width: 12; height: 2; radius: 1; color: "#dddddd" }
                            }
                        }

                        ToolButton {
                            id: maxBtn
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            hoverEnabled: true
                            onClicked: {
                                if (!win) return
                                if (win.visibility === Window.Maximized) win.showNormal()
                                else win.showMaximized()
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

                                Rectangle {
                                    visible: win && win.visibility !== Window.Maximized
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 10
                                    radius: 2
                                    color: "transparent"
                                    border.color: "#dddddd"
                                    border.width: 2
                                }

                                Item {
                                    visible: win && win.visibility === Window.Maximized
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

                        ToolButton {
                            id: closeBtn
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            hoverEnabled: true
                            onClicked: if (win) win.close()

                            background: Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: closeBtn.hovered ? "#c0392b" : "#2a2a2a"
                            }

                            contentItem: Item {
                                width: 12
                                height: 12
                                anchors.centerIn: parent
                                Rectangle { anchors.centerIn: parent; width: 12; height: 2; radius: 1; color: "#dddddd"; rotation: 45 }
                                Rectangle { anchors.centerIn: parent; width: 12; height: 2; radius: 1; color: "#dddddd"; rotation: -45 }
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

                ScrollView {
                    id: editorScroll
                    anchors.fill: parent
                    clip: true

                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ScrollBar.vertical {
                        id: vbar
                        width: 10

                        contentItem: Rectangle {
                            radius: width / 2
                            color: "#6b6b6b"
                            opacity: vbar.pressed ? 0.9 : 0.6
                        }
                        background: Rectangle {
                            radius: width / 2
                            color: "transparent"
                        }
                    }

                    Connections {
                        target: editorScroll.contentItem
                        function onContentYChanged() {
                            if (!appSafe) return
                            if (!editorScroll.contentItem) return
                            if (win.restoring) return              // <- key: ignore while restoring
                            appSafe.set_scroll_y(editorScroll.contentItem.contentY)
                        }
                    }

                    TextArea {
                        id: editor
                        width: editorScroll.availableWidth
                        wrapMode: TextArea.Wrap
                        padding: 12
                        color: "#eeeeee"
                        font.pixelSize: settingsSafe ? settingsSafe.fontSize : 11

                        cursorVisible: false
                        focus: true
                        activeFocusOnTab: true

                        Component.onCompleted: {
                            // wait one tick so the window is visible and can accept focus
                            Qt.callLater(() => editor.forceActiveFocus())
                        }

                        onTextEdited: {
                            if (!appSafe) return
                            appSafe.text = text
                            appSafe.set_cursor_position(editor.cursorPosition)
                            customCaret.solidNow()
                        }

                        onCursorPositionChanged: {
                            if (!appSafe) return
                            if (win.restoring) return
                            appSafe.set_cursor_position(cursorPosition)
                        }

                        Keys.onPressed: (e) => {
                            // keep caret solid for most keys
                            if (e.key !== Qt.Key_Shift && e.key !== Qt.Key_Control && e.key !== Qt.Key_Alt && e.key !== Qt.Key_Meta)
                                customCaret.solidNow()

                            if (e.key === Qt.Key_Tab && e.modifiers === Qt.NoModifier) {
                                e.accepted = true
                                editor.insert(editor.cursorPosition, "    ")
                            }
                        }

                        background: Rectangle {
                            radius: cornerRadius
                            color: "#111111"
                            border.color: "#333333"
                            border.width: 1
                        }
                        text: ""

                        Connections {
                            target: appSafe
                            function onTextChanged() {
                                // Only pull backend text into the editor when we're switching docs
                                // or when the editor isn't being actively edited.
                                if (!appSafe) return
                                if (win.pendingRestore || !editor.activeFocus) {
                                    editor.text = appSafe.text
                                }
                            }
                        }

                        // ---- Custom caret (Qt cursor disabled) ----
                        Rectangle {
                            id: customCaret
                            z: 9999
                            width: 1
                            color: "#eaeaea"
                            visible: editor.activeFocus

                            // Track caret geometry from TextArea
                            x: editor.cursorRectangle.x
                            y: editor.cursorRectangle.y
                            height: editor.cursorRectangle.height

                            // typing state
                            property bool typing: false

                            function solidNow() {
                                typing = true
                                opacity = 1
                                resumeBlink.restart()
                            }

                            Timer {
                                id: resumeBlink
                                interval: 400   // how long after last input before blinking again
                                repeat: false
                                onTriggered: customCaret.typing = false
                            }

                            SequentialAnimation {
                                id: caretBlink
                                loops: Animation.Infinite
                                running: editor.activeFocus && !customCaret.typing
                                NumberAnimation { target: customCaret; property: "opacity"; to: 0; duration: 450 }
                                NumberAnimation { target: customCaret; property: "opacity"; to: 1; duration: 450 }
                            }

                            Connections {
                                target: editor
                                function onActiveFocusChanged() {
                                    customCaret.typing = false
                                    customCaret.opacity = 1
                                    resumeBlink.stop()
                                }
                            }
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
                    cursorShape: Qt.IBeamCursor
                    propagateComposedEvents: true

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
                            onClicked: settingsWindow.visible = true
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

    SettingsWindow { id: settingsWindow; visible: false }
}