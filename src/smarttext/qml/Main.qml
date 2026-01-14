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

    title: appSafe
        ? (appSafe.documentTitle + (appSafe.modified ? " •" : ""))
        : "SmartText"

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

            Item {
                id: editorShell
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // ---- Feel knobs ----
                property int overlayHeight: 140        // fade height
                property int overlaySlide: 40          // fade slide distance
                property int buttonSlide: 10           // per-button slide distance
                property real buttonBaseOpacity: 0.85  // shown opacity (0..1)
                property int idleDelayMs: 5000         // hide after idle ms
                property int hoverDelayMs: 120         // show after hover ms

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
                            editor.insert(cursor, "    ")   // 4 spaces
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
                        Behavior on y {
                            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    // LEFT: Settings
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

                    // RIGHT: Existing actions
                    Row {
                        id: rightActions
                        spacing: 10
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 14
                        anchors.bottomMargin: 14

                        // Group motion (buttons handle opacity)
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

                        // ---- Helper: per-button hover boost ----
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

                            // dim when disabled, but still animate in/out
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
