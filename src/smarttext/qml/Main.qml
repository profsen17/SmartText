import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 6.5
import "components"
import "components/themes.js" as Themes

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

    readonly property var palette: Themes.get(settingsSafe ? settingsSafe.theme : null)

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

    title: "SmartText"

    Rectangle {
        id: rootBg
        anchors.fill: parent
        radius: cornerRadius
        color: palette.windowBg
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            TitleBar {
                Layout.fillWidth: true
                window: win
                cornerRadius: win.cornerRadius
                titleText: ""
                palette: palette
            }

            // ---- Tabs strip ----
            Item {
                id: tabsBar
                Layout.fillWidth: true
                height: 44

                Rectangle {
                    anchors.fill: parent
                    radius: win.cornerRadius
                    color: palette.railBg
                    border.color: palette.border
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
                            color: tabItem.active ? palette.tabActiveBg : palette.tabInactiveBg
                            border.color: tabItem.active ? palette.editorBorder : palette.border
                            border.width: 1
                            anchors.bottomMargin: tabItem.active ? -8 : 0
                        }

                        Rectangle {
                            visible: tabItem.active
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 10
                            y: parent.height - 2
                            color: palette.editorBg
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
                                color: tabItem.active ? palette.text : palette.textMuted
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                width: tabItem.width - 44
                            }

                            // Close / Unsaved indicator
                            Rectangle {
                                width: 18
                                height: 18
                                radius: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color: closeArea.containsMouse ? palette.btnHover : "transparent"

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
                                    color: palette.textSoft
                                    font.pixelSize: 14
                                    visible: !model.modified
                                }
                            }
                        }
                    }
                }
            }

            // ---- Editor + overlay ----
            Item {
                id: editorShell
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // Feel knobs
                property int overlayHeight: 140
                property int overlaySlide: 40
                property int buttonSlide: 10
                property real buttonBaseOpacity: 0.85
                property int idleDelayMs: 5000
                property int hoverDelayMs: 120

                property bool hovering: false
                property bool idleHidden: false
                property bool showOverlay: hovering && !idleHidden

                function resetIdleTimer() {
                    if (!hovering) return
                    idleHidden = false
                    idleTimer.restart()
                }

                TextArea {
                    id: editor
                    anchors.fill: parent
                    wrapMode: TextArea.Wrap
                    padding: 12
                    color: palette.text
                    font.pixelSize: settingsSafe ? settingsSafe.fontSize : 11

                    background: Rectangle {
                        radius: cornerRadius
                        color: palette.editorBg
                        border.color: palette.editorBorder
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

                Timer {
                    id: hoverDelayTimer
                    interval: editorShell.hoverDelayMs
                    repeat: false
                    onTriggered: {
                        editorShell.hovering = true
                        editorShell.idleHidden = false
                        editorShell.resetIdleTimer()
                    }
                }

                HoverHandler {
                    target: editorShell
                    onHoveredChanged: {
                        if (hovered) {
                            hoverDelayTimer.restart()
                        } else {
                            hoverDelayTimer.stop()
                            editorShell.hovering = false
                            idleTimer.stop()
                            editorShell.idleHidden = false
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onPositionChanged: if (editorShell.hovering) editorShell.resetIdleTimer()
                }

                Timer {
                    id: idleTimer
                    interval: editorShell.idleDelayMs
                    repeat: false
                    onTriggered: editorShell.idleHidden = true
                }

                // ---- Overlay ----
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

                    // LEFT: Settings
                    Row {
                        spacing: 10
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 14
                        anchors.bottomMargin: 14

                        CircleIconButton {
                            tooltipText: "Settings"
                            iconSource: "../icons/settings.svg"
                            onClicked: settingsWindow.show()
                            palette: win.palette
                        }
                    }

                    // RIGHT: Actions
                    Row {
                        id: rightActions
                        spacing: 10
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 14
                        anchors.bottomMargin: 14

                        transform: Translate { id: actionsTranslate; y: 28 }

                        states: [
                            State { name: "shown";  when: editorShell.showOverlay; PropertyChanges { target: actionsTranslate; y: 0 } },
                            State { name: "hidden"; when: !editorShell.showOverlay; PropertyChanges { target: actionsTranslate; y: 28 } }
                        ]

                        transitions: [
                            Transition {
                                from: "hidden"; to: "shown"
                                SequentialAnimation {
                                    PauseAnimation { duration: 100 }
                                    NumberAnimation { target: actionsTranslate; property: "y"; duration: 280; easing.type: Easing.OutCubic }
                                }
                            },
                            Transition {
                                from: "shown"; to: "hidden"
                                NumberAnimation { target: actionsTranslate; property: "y"; duration: 200; easing.type: Easing.OutCubic }
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
                            palette: win.palette
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
                            palette: win.palette
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
                            palette: win.palette

                            property bool canSave: (appSafe !== null) && appSafe.modified
                            enabled: canSave
                            property real baseOpacity: canSave ? editorShell.buttonBaseOpacity : 0.45

                            onClicked: if (appSafe) appSafe.save()

                            opacity: 0
                            transform: Translate { id: trSave; y: editorShell.buttonSlide }

                            onHoveredChanged: {
                                if (!editorShell.showOverlay) return
                                if (!btnSave.canSave) return
                                btnSave.opacity = hovered ? 1.0 : btnSave.baseOpacity
                            }

                            states: [
                                State { name: "shown"; when: editorShell.showOverlay
                                    PropertyChanges { target: btnSave; opacity: btnSave.baseOpacity }
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
                            palette: win.palette
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
