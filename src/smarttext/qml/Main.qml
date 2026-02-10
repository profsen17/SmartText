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
    property bool uiLocked: openDialog.visible || saveAsDialog.visible || settingsWindow.visible || searchOpen
    property int _prevVisibility: Window.Windowed

    property bool restoring: false
    property bool pendingRestore: false
    property int restoreToken: 0

    property string actionHint: ""
    property var actionHintItem: null

    property bool searchOpen: false

    onSearchOpenChanged: {
        if (searchOpen) Qt.callLater(() => bgSource.scheduleUpdate())
    }

    function showHint(text, item) {
        actionHint = text || ""
        actionHintItem = item || null
    }

    function hideHint(item) {
        // Delay clearing so moving from one button to another doesn't flicker
        Qt.callLater(() => {
            if (actionHintItem === item) {
                actionHint = ""
                actionHintItem = null
            }
        })
    }

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
        enabled: settingsSafe !== null && !win.uiLocked
                && !win.uiLocked
                && !(settingsWindow && settingsWindow.capturingShortcut)
        sequence: settingsSafe ? settingsSafe.shortcutNew : ""
        onActivated: if (appSafe) appSafe.new_file()
    }

    Shortcut {
        enabled: settingsSafe !== null && !win.uiLocked
                && !win.uiLocked
                && !(settingsWindow && settingsWindow.capturingShortcut)
        sequence: settingsSafe ? settingsSafe.shortcutOpen : ""
        onActivated: openDialog.open()
    }

    Shortcut {
        enabled: settingsSafe !== null && !win.uiLocked
                && !win.uiLocked
                && !(settingsWindow && settingsWindow.capturingShortcut)
        sequence: settingsSafe ? settingsSafe.shortcutSave : ""
        onActivated: if (appSafe) appSafe.save()
    }

    Shortcut {
        enabled: settingsSafe !== null && !win.uiLocked
                && !win.uiLocked
                && !(settingsWindow && settingsWindow.capturingShortcut)
        sequence: settingsSafe ? settingsSafe.shortcutSaveAs : ""
        onActivated: saveAsDialog.open()
    }

    Shortcut {
        enabled: settingsSafe !== null && !win.uiLocked
                && !win.uiLocked
                && !(settingsWindow && settingsWindow.capturingShortcut)
        sequence: settingsSafe ? settingsSafe.shortcutClose : ""
        onActivated: if (appSafe) appSafe.close_current_tab()
    }

    Shortcut {
        enabled: settingsSafe !== null
                && !openDialog.visible && !saveAsDialog.visible && !settingsWindow.visible
                && !(settingsWindow && settingsWindow.capturingShortcut)

        sequence: settingsSafe ? settingsSafe.shortcutSearch : ""
        onActivated: win.searchOpen = !win.searchOpen
    }

    Shortcut {
        enabled: win.searchOpen
        sequence: "Escape"
        onActivated: win.searchOpen = false
    }

    Shortcut {
        enabled: !win.uiLocked
        sequence: "F11"
        onActivated: {
            if (win.visibility === Window.FullScreen) {
                // restore what we had before fullscreen
                if (win._prevVisibility === Window.Maximized) win.showMaximized()
                else win.showNormal()
            } else {
                // remember current state then go fullscreen
                win._prevVisibility = win.visibility
                win.showFullScreen()
            }
        }
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
        //Put this if you want drag handle in F11 Fulscreen mode
        //property bool showing: (hoveringTop || forceVisible) && !win.uiLocked
        property bool showing: (hoveringTop || forceVisible) && !win.uiLocked && win.visibility !== Window.FullScreen

        //Remove this if you want drag handle in F11 Fullscreen mode
        Connections {
            target: win
            function onVisibilityChanged() {
                if (win.visibility === Window.FullScreen) {
                    topHandleLayer.forceVisible = false
                    topHandleLayer.postDragArmed = false
                }
            }
        }

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

        Item {
            id: mainContent
            anchors.fill: parent

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
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#202020" }
                            GradientStop { position: 1.0; color: "#161616" }
                        }
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
                                        visible: win && win.visibility !== Window.Maximized && win.visibility !== Window.FullScreen
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10
                                        radius: 2
                                        color: "transparent"
                                        border.color: "#dddddd"
                                        border.width: 2
                                    }

                                    Item {
                                        visible: win && (win.visibility === Window.Maximized || win.visibility === Window.FullScreen)
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
                        if (!hovering && !sidebarHovering && !arrowHovering) return
                        idleHidden = false
                        idleTimer.restart()
                    }

                    // --- Sidebar close delay ---
                    Timer {
                        id: sidebarCloseTimer
                        interval: 250
                        repeat: false
                        onTriggered: {
                            if (editorShell.sidebarHovering || editorShell.arrowHovering) return
                            editorShell.sidebarOpen = false
                        }
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
                                // Block cursor writes during tab switching/restoring
                                if (win.restoring || win.pendingRestore) return
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
                                    if (!appSafe) return
                                    // Only update editor when user isn't actively editing.
                                    // Tab switching is handled by restoreEditorState().
                                    if (!editor.activeFocus && !win.pendingRestore) {
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
                                editorShell.idleHidden = false
                                editorShell.resetIdleTimer()
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
                        enabled: sidebarVisible   // don't steal hover/clicks while "invisible"

                        states: [
                            State {
                                name: "open"
                                when: editorShell.sidebarOpen && !editorShell.idleHidden
                                PropertyChanges { target: sidebarTx; x: 0 }
                                PropertyChanges { target: leftSidebar; opacity: 1 }
                            },
                            State {
                                name: "closed"
                                when: !(editorShell.sidebarOpen && !editorShell.idleHidden)
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

                        HoverHandler {
                            id: sidebarHoverHandler
                            target: leftSidebar

                            onHoveredChanged: {
                                if (win.uiLocked || editorShell.hoverFrozen) return

                                editorShell.sidebarHovering = hovered

                                if (hovered) {
                                    editorShell.sidebarOpen = true
                                    editorShell.idleHidden = false
                                    editorShell.cancelSidebarClose()
                                    editorShell.resetIdleTimer()
                                } else {
                                    editorShell.scheduleSidebarClose()
                                }
                            }

                            onPointChanged: {
                                if (hovered && !win.uiLocked)
                                    editorShell.resetIdleTimer()
                            }
                        }

                        Item {
                            id: wheelMenu
                            anchors.fill: parent
                            anchors.margins: editorShell.sidebarPad
                            clip: false

                            // --- wheel tuning ---
                            property int itemSize: 38
                            property real step: 54
                            property int range: 2
                            property int currentIndex: 0
                            property int spinDir: 0

                            function wrapIndex(i) {
                                const n = wheelModel.count
                                if (n <= 0) return 0
                                i = i % n
                                if (i < 0) i += n
                                return i
                            }

                            function signedDistance(idx) {
                                const n = wheelModel.count
                                if (n <= 0) return 0
                                let d = idx - currentIndex
                                d = ((d % n) + n) % n
                                if (d > n / 2) d -= n
                                return d
                            }

                            function stepWheel(delta) {
                                currentIndex = wrapIndex(currentIndex + delta)
                            }

                            function trigger(actionId) {
                                if (win.uiLocked) return
                                switch (actionId) {
                                case "new":      if (appSafe) appSafe.new_file(); break
                                case "open":     openDialog.open(); break
                                case "save":     if (appSafe) appSafe.save(); break
                                case "saveAs":   saveAsDialog.open(); break
                                case "settings": settingsWindow.visible = true; break
                                }
                            }

                            // --- Mouse wheel scroll rotates the sidebar wheel ---
                            WheelHandler {
                                id: sidebarWheel
                                target: wheelMenu
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                                onWheel: (event) => {
                                    if (win.uiLocked) return

                                    // Prefer angleDelta; fall back to pixelDelta for high-res devices
                                    const dy = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y
                                    if (dy === 0) return

                                    // wheel up => previous (-1), wheel down => next (+1)
                                    wheelMenu.stepWheel(dy > 0 ? -1 : +1)

                                    // prevent the editor ScrollView from also scrolling
                                    event.accepted = true
                                }
                            }

                            Timer {
                                id: spinTimer
                                interval: 220
                                repeat: true
                                running: false
                                onTriggered: wheelMenu.stepWheel(wheelMenu.spinDir)
                            }

                            // --- Invisible hover zones to "rotate" the wheel ---
                            Item {
                                id: hoverZones
                                anchors.fill: parent
                                z: -10   // keep it behind the buttons

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: parent.height * 0.35
                                    color: "transparent"

                                    HoverHandler {
                                        onHoveredChanged: {
                                            if (win.uiLocked) return
                                            if (hovered) { wheelMenu.spinDir = -1; spinTimer.start() }
                                            else { wheelMenu.spinDir = 0; spinTimer.stop() }
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: parent.height * 0.35
                                    color: "transparent"

                                    HoverHandler {
                                        onHoveredChanged: {
                                            if (win.uiLocked) return
                                            if (hovered) { wheelMenu.spinDir = +1; spinTimer.start() }
                                            else { wheelMenu.spinDir = 0; spinTimer.stop() }
                                        }
                                    }
                                }
                            }

                            // --- Wheel model (your actions) ---
                            ListModel {
                                id: wheelModel
                                ListElement { actionId: "new";      tooltip: "New";      icon: "../icons/new.svg" }
                                ListElement { actionId: "open";     tooltip: "Open";     icon: "../icons/open.svg" }
                                ListElement { actionId: "save";     tooltip: "Save";     icon: "../icons/save.svg" }
                                ListElement { actionId: "saveAs";   tooltip: "Save As";  icon: "../icons/save_as.svg" }
                                ListElement { actionId: "settings"; tooltip: "Settings"; icon: "../icons/settings.svg" }
                            }

                            // --- The wheel renderer ---
                            Repeater {
                                model: wheelModel

                                delegate: Item {
                                    id: slot
                                    width: wheelMenu.itemSize
                                    height: wheelMenu.itemSize

                                    property real d: wheelMenu.signedDistance(index)
                                    property bool isCenter: d === 0
                                    property real ad: Math.abs(d)

                                    // ✅ ring logic
                                    property bool isNeighbor: ad === 1
                                    property bool isDisabledRing: ad >= 2

                                    // ✅ visuals
                                    opacity: isDisabledRing ? 0.55 : 1.0
                                    scale: isCenter ? 1.15 : (isNeighbor ? 0.95 : 0.88)

                                    // ✅ ONLY center + neighbors can be interacted with
                                    enabled: !isDisabledRing

                                    // layout (keep your arc)
                                    property real arc: Math.min(1.0, ad / (wheelMenu.range + 1.0))
                                    x: (wheelMenu.width - width) / 2 - (arc * arc * 12)
                                    y: (wheelMenu.height - height) / 2 + d * wheelMenu.step

                                    z: 100 - ad

                                    Behavior on x       { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on y       { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on scale   { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                    // optional: stronger shadow for center (adds “brighter” feel)
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: wheelMenu.itemSize
                                        height: wheelMenu.itemSize
                                        radius: width / 2
                                        color: "transparent"
                                        visible: true

                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            shadowEnabled: true
                                            shadowOpacity: slot.isCenter ? 0.55 : (slot.isNeighbor ? 0.35 : 0.18)
                                            shadowBlur: 0.9
                                            shadowVerticalOffset: 3
                                        }
                                    }

                                    CircleIconButton {
                                        id: btn
                                        anchors.centerIn: parent
                                        size: wheelMenu.itemSize
                                        tooltipText: model.tooltip
                                        iconSource: model.icon

                                        // ✅ disabled ring grey + unclickable
                                        // ✅ keep your Save special-case
                                        enabled: slot.enabled && ((model.actionId !== "save") ? true : (appSafe ? appSafe.modified : false))

                                        opacity: slot.opacity
                                        scale: slot.scale

                                        onClicked: {
                                            if (win.uiLocked) return
                                            if (!slot.isCenter) {
                                                wheelMenu.currentIndex = index
                                                return
                                            }
                                            wheelMenu.trigger(model.actionId)
                                        }
                                    }
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
                        onTriggered: {
                            // If the user is interacting with the left edge UI, DO NOT auto-hide.
                            if (editorShell.sidebarOpen || editorShell.sidebarHovering || editorShell.arrowHovering) {
                                idleTimer.restart()
                                return
                            }
                            editorShell.idleHidden = true
                        }
                    }

                    Item {
                        id: fileTypePill
                        z: 30
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 12
                        anchors.rightMargin: 14

                        // ✅ give the container a real size
                        width: pillBg.implicitWidth
                        height: pillBg.implicitHeight

                        property bool canShow: editorShell.hovering
                                            && !editorShell.idleHidden
                                            && !win.uiLocked
                                            && appSafe
                                            && appSafe.fileTypeLabel !== ""

                        enabled: opacity > 0.05
                        opacity: 0
                        visible: opacity > 0.0

                        transform: Translate { id: pillTx; x: 180 }

                        states: [
                            State {
                                name: "shown"
                                when: fileTypePill.canShow
                                PropertyChanges { target: fileTypePill; opacity: 1 }
                                PropertyChanges { target: pillTx; x: 0 }
                            },
                            State {
                                name: "hidden"
                                when: !fileTypePill.canShow
                                PropertyChanges { target: fileTypePill; opacity: 0 }
                                PropertyChanges { target: pillTx; x: 180 }
                            }
                        ]

                        transitions: [
                            Transition {
                                from: "hidden"; to: "shown"
                                ParallelAnimation {
                                    NumberAnimation { target: pillTx; property: "x"; duration: 240; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: fileTypePill; property: "opacity"; duration: 160; easing.type: Easing.OutCubic }
                                }
                            },
                            Transition {
                                from: "shown"; to: "hidden"
                                ParallelAnimation {
                                    NumberAnimation { target: pillTx; property: "x"; duration: 200; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: fileTypePill; property: "opacity"; duration: 120; easing.type: Easing.OutCubic }
                                }
                            }
                        ]

                        Rectangle {
                            id: pillBg

                            implicitHeight: 22
                            implicitWidth: pillRow.implicitWidth + 16

                            anchors.fill: parent
                            radius: 7
                            antialiasing: true

                            // flatter, label-like
                            color: "#2a2a2a"
                            border.width: 0   // no button border

                            Row {
                                id: pillRow
                                anchors.centerIn: parent
                                spacing: 6

                                // extension: compact + mono-ish feel
                                Text {
                                    id: extText
                                    text: appSafe ? appSafe.fileExtension : ""
                                    color: "#eaeaea"
                                    font.pixelSize: 11
                                    font.family: "Monospace"
                                    font.bold: true
                                    opacity: 0.95
                                }

                                // small separator dot
                                Rectangle {
                                    width: 3
                                    height: 3
                                    radius: 1.5
                                    color: "#eaeaea"
                                    opacity: 0.55
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: appSafe && appSafe.fileTypeLabel !== ""
                                }

                                // type label: lighter
                                Text {
                                    id: typeText
                                    text: appSafe ? appSafe.fileTypeLabel : ""
                                    color: "#eaeaea"
                                    font.pixelSize: 11
                                    opacity: 0.70
                                }
                            }
                        }

                        MultiEffect {
                            anchors.fill: pillBg
                            source: pillBg
                            shadowEnabled: true
                            shadowOpacity: 0.28
                            shadowBlur: 0.6
                            shadowVerticalOffset: 2
                            visible: fileTypePill.opacity > 0.0
                        }
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
                                onHoveredChanged: {
                                    rightActions.boostOpacity(btnNew, hovered)
                                }

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
                                onHoveredChanged: {
                                    rightActions.boostOpacity(btnOpen, hovered)
                                }

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
                                    rightActions.boostOpacity(btnSave, hovered)
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
                                onHoveredChanged: {
                                    rightActions.boostOpacity(btnSaveAs, hovered)
                                }

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

            Item {
                id: actionHintPill
                z: 999999
                visible: win.actionHint !== "" && !win.uiLocked
                opacity: visible ? 1 : 0
                width: bg.implicitWidth
                height: bg.implicitHeight

                function reposition() {
                    if (!win.actionHintItem) return

                    // map hovered button center to rootBg
                    const p = win.actionHintItem.mapToItem(rootBg,
                                                        win.actionHintItem.width / 2,
                                                        0)

                    // place above the button (slightly to the right)
                    let x = p.x + 18 - width / 2
                    let y = p.y - height - 10

                    // clamp inside rootBg
                    x = Math.max(10, Math.min(rootBg.width - width - 10, x))
                    y = Math.max(10, Math.min(rootBg.height - height - 10, y))

                    actionHintPill.x = x
                    actionHintPill.y = y
                }

                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Connections {
                    target: win
                    function onActionHintChanged() { Qt.callLater(actionHintPill.reposition) }
                    function onActionHintItemChanged() { Qt.callLater(actionHintPill.reposition) }
                }
                Connections {
                    target: rootBg
                    function onWidthChanged() { actionHintPill.reposition() }
                    function onHeightChanged() { actionHintPill.reposition() }
                }

                Rectangle {
                    id: bg
                    implicitWidth: txt.implicitWidth + 18
                    implicitHeight: 34
                    radius: 8
                    color: "#2a2a2a"
                    border.color: "#3a3a3a"
                    border.width: 1

                    Text {
                        id: txt
                        anchors.centerIn: parent
                        text: win.actionHint
                        color: "#eaeaea"
                        font.pixelSize: 11
                    }
                }

                MultiEffect {
                    anchors.fill: bg
                    source: bg
                    shadowEnabled: true
                    shadowOpacity: 0.25
                    shadowBlur: 0.6
                    shadowVerticalOffset: 2
                    visible: actionHintPill.opacity > 0
                }
            }

            DropArea {
                id: fileDrop
                anchors.fill: parent
                z: 999999   // above editor content, below dialogs if needed

                // Only accept when not locked by dialogs/settings
                enabled: !win.uiLocked

                onEntered: (drag) => {
                    // Accept only if there are urls (files)
                    if (drag.hasUrls) drag.accepted = true
                }

                onDropped: (drop) => {
                    if (!appSafe || !drop.hasUrls)
                        return

                    // Open all files in the order they were dropped.
                    // The LAST opened one will become the current tab (focused),
                    // because appSafe.open_file() ends up switching currentIndex.
                    for (let i = 0; i < drop.urls.length; ++i) {
                        const u = drop.urls[i]
                        if (!u) continue

                        const p = u.toString()

                        // ignore folders
                        if (p.endsWith("/"))
                            continue

                        appSafe.open_file(p)
                    }
                }

                // --- Visual overlay while dragging ---
                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: fileDrop.containsDrag ? 0.22 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    // dashed border style
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 18
                        color: "transparent"
                        radius: win.cornerRadius
                        border.width: 2
                        border.color: "#5a5a5a"
                        opacity: 0.8
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Drop a file to open"
                        color: "#eaeaea"
                        font.pixelSize: 14
                        opacity: 0.9
                    }
                }
            }
        }

        // ---- Search bar (Ctrl+Space) ----
        Item {
            id: searchLayer
            anchors.fill: parent
            z: 900000

            // ✅ decouple visibility from open flag
            property bool shown: false

            visible: shown
            enabled: shown

            // play animations both ways (already handled by your Behaviors)
            onVisibleChanged: {
                if (visible) Qt.callLater(() => cmdSearchInput.forceActiveFocus())
                else cmdSearchInput.text = ""
            }

            // ✅ when opening: show immediately
            // ✅ when closing: wait for the reverse animation to finish, then hide
            Connections {
                target: win
                function onSearchOpenChanged() {
                    if (win.searchOpen) {
                        searchLayer.shown = true
                        Qt.callLater(() => searchLayer._updateCardRect())
                    } else {
                        closeHideTimer.restart()
                    }
                }
            }

            Timer {
                id: closeHideTimer
                interval: 280   // >= your longest close animation (y is 260ms)
                repeat: false
                onTriggered: searchLayer.shown = false
            }

            // --- scrim ---
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: win.searchOpen ? 0.45 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            // Blocks ALL interaction under the search UI.
            // Click outside the searchCard closes. Click inside does nothing.
            MouseArea {
                id: searchBlocker
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons
                preventStealing: true
                propagateComposedEvents: false

                function insideSearchCard(px, py) {
                    // px/py are in searchLayer coordinates (same as this MouseArea)
                    const p = searchCard.mapFromItem(searchLayer, px, py)
                    return p.x >= 0 && p.y >= 0 && p.x <= searchCard.width && p.y <= searchCard.height
                }

                onPressed: (mouse) => {
                    mouse.accepted = true
                    if (!insideSearchCard(mouse.x, mouse.y))
                        win.searchOpen = false
                }

                onReleased: (mouse) => mouse.accepted = true
                onClicked: (mouse) => mouse.accepted = true
                onDoubleClicked: (mouse) => mouse.accepted = true
                onPressAndHold: (mouse) => mouse.accepted = true
                onWheel: (wheel) => wheel.accepted = true
            }

            // Captures ONLY what's behind the searchCard (correct region)
            property rect _cardRect: Qt.rect(0, 0, 1, 1)

            function _updateCardRect() {
                if (!win.searchOpen) return
                // map searchCard's top-left into mainContent coordinates
                const p = searchCard.mapToItem(mainContent, 0, 0)
                _cardRect = Qt.rect(p.x, p.y, searchCard.width, searchCard.height)
            }

            Timer {
                // keeps the blur “tracking” perfectly during the slide animation
                interval: 16
                repeat: true
                running: win.searchOpen
                onTriggered: searchLayer._updateCardRect()
            }

            ShaderEffectSource {
                id: cardBgSource
                sourceItem: mainContent
                recursive: true
                live: win.searchOpen
                smooth: true
                visible: false
                hideSource: false
                sourceRect: searchLayer._cardRect
            }

            Item {
                id: searchOverlay
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 86

                opacity: win.searchOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                transform: Translate {
                    id: searchTx
                    y: win.searchOpen ? 76 : -searchOverlay.height - 20
                    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    id: searchCard
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(rootBg.width - 32, 640)
                    height: 54
                    radius: 14
                    antialiasing: true
                    color: "transparent"

                    // --- CLIP AREA (so blur is visible and rounded) ---
                    Item {
                        id: glassClip
                        anchors.fill: parent
                        clip: true

                        // 1) Blurred background behind the card (THIS is the glass)
                        MultiEffect {
                            anchors.fill: parent
                            source: cardBgSource
                            blurEnabled: true
                            blur: 1.0       // 0..1 (1 = strongest)
                            blurMax: 64
                            opacity: 1.0
                        }

                        // 2) Subtle glass tint (do NOT make it too opaque)
                        Rectangle {
                            anchors.fill: parent
                            color: "#18ffffff"   // tiny white tint
                        }

                        // 3) Slight dark wash to keep text readable
                        Rectangle {
                            anchors.fill: parent
                            color: "#14000000"   // tiny black tint
                        }
                    }

                    // Edge highlight (outside clip is fine)
                    Rectangle {
                        anchors.fill: parent
                        radius: searchCard.radius
                        color: "transparent"
                        border.width: 1
                        border.color: "#35ffffff"
                    }

                    // Your content ABOVE glass
                    Item {
                        anchors.fill: parent
                        anchors.margins: 10

                        RowLayout {
                            anchors.fill: parent
                            spacing: 10

                            Item {
                                Layout.fillWidth: true
                                height: 34

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    text: "Search…"
                                    color: "#ffffff"
                                    opacity: cmdSearchInput.text.length > 0 ? 0.0 : 0.75
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                TextInput {
                                    id: cmdSearchInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    color: "#ffffff"
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                    verticalAlignment: Text.AlignVCenter
                                    selectByMouse: true
                                    focus: true
                                }
                            }

                            Text {
                                text: "Esc"
                                color: "#eaeaea"
                                opacity: 0.45
                                font.pixelSize: 11
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Modal scrim when Settings is open ----
    Rectangle {
        id: settingsScrim
        anchors.fill: parent
        z: 1000000
        visible: settingsWindow.visible

        radius: win.cornerRadius      // ✅ match main window rounding
        clip: true                    // ✅ enforce rounding

        color: "#000000"
        opacity: settingsWindow.visible ? 0.55 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        // Block ALL interaction with the main window while visible
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            preventStealing: true
            propagateComposedEvents: false
            onPressed: e => e.accepted = true
            onReleased: e => e.accepted = true
            onWheel: e => e.accepted = true
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