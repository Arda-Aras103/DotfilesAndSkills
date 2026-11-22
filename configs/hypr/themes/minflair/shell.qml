import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    ThemeColors { id: theme }

    property bool locked: false
    property int activeWorkspace: 1

    readonly property var activePlayer: (Mpris.players && Mpris.players.values && Mpris.players.values.length > 0)
        ? Mpris.players.values[0] : null

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    IpcHandler {
        target: "lock"
        function toggle(): void { root.locked = !root.locked; }
        function lock(): void { root.locked = true; }
        function unlock(): void { root.locked = false; }
    }

    Process {
        id: wsProc
        command: ["sh", "-c", "command -v hyprctl >/dev/null 2>&1 && hyprctl activeworkspace -j | python3 -c 'import json,sys; print(json.load(sys.stdin).get(\"id\",1))' 2>/dev/null || echo 1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parsed = parseInt(this.text.trim());
                if (!isNaN(parsed) && parsed > 0) root.activeWorkspace = parsed;
            }
        }
    }

    Timer {
        interval: 800
        running: true
        repeat: true
        onTriggered: {
            if (!wsProc.running) wsProc.running = true;
        }
    }

    function switchWorkspace(ws) {
        root.activeWorkspace = ws;
        wsSwitchProc.command = ["hyprctl", "dispatch", "workspace", String(ws)];
        wsSwitchProc.running = true;
    }

    Process { id: wsSwitchProc }

    // Wallpaper layer driven by extracted ThemeColors
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            focusable: false
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "minflair-wallpaper"

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: theme.bg }
                    GradientStop { position: 1.0; color: theme.surface }
                }

                Image {
                    anchors.fill: parent
                    visible: theme.wallpaperPath.length > 0
                    source: theme.wallpaperPath.length > 0
                        ? (theme.wallpaperPath.indexOf("://") !== -1 ? theme.wallpaperPath : "file://" + theme.wallpaperPath)
                        : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                // Subtle vignette for bar contrast
                Rectangle {
                    anchors.fill: parent
                    color: theme.bg
                    opacity: theme.wallpaperPath.length > 0 ? 0.16 : 0.0
                }
            }
        }
    }

    // Minimalist Floating Bar styled from extracted image palette
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            margins {
                top: 10
                left: 18
                right: 18
            }

            implicitHeight: 38
            exclusiveZone: 48
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "minflair-bar"

            Rectangle {
                anchors.fill: parent
                radius: 19
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.88)
                border.color: theme.primary
                border.width: 1.5

                // Left: Workspaces & Minflair Palette Swatches
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                            model: [theme.primary, theme.secondary, theme.fg]
                            delegate: Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: modelData
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "MINFLAIR"
                        color: theme.fg
                        opacity: 0.72
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.4
                    }

                    Repeater {
                        model: [1, 2, 3, 4]
                        delegate: Rectangle {
                            readonly property bool isCurrent: root.activeWorkspace === modelData
                            width: isCurrent ? 26 : 20
                            height: 20
                            radius: 10
                            color: isCurrent ? theme.primary : Qt.rgba(theme.bg.r, theme.bg.g, theme.bg.b, 0.75)
                            border.color: isCurrent ? theme.primary : theme.borderInactive
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: String(modelData)
                                color: isCurrent ? theme.bg : theme.fg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchWorkspace(modelData)
                            }
                        }
                    }
                }

                // Center: Clean Minimal Clock
                Text {
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(clock.date, "ddd dd MMM  //  HH:mm")
                    color: theme.fg
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                }

                // Right: Media + Lock Pill
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        visible: root.activePlayer !== null
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(180, implicitWidth)
                        elide: Text.ElideRight
                        text: root.activePlayer ? ((root.activePlayer.isPlaying ? "♪ " : "⏸ ") + (root.activePlayer.trackTitle || "Media")) : ""
                        color: theme.secondary
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                    Rectangle {
                        height: 22
                        width: lockTxt.implicitWidth + 16
                        radius: 11
                        color: Qt.rgba(theme.secondary.r, theme.secondary.g, theme.secondary.b, 0.22)
                        border.color: theme.secondary
                        border.width: 1

                        Text {
                            id: lockTxt
                            anchors.centerIn: parent
                            text: "LOCK"
                            color: theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.locked = true
                        }
                    }
                }
            }
        }
    }

    // Super+L Lock Overlay
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.locked

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            focusable: root.locked
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "minflair-lock"

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(theme.bg.r, theme.bg.g, theme.bg.b, 0.88)
                focus: root.locked
                Keys.onEscapePressed: root.locked = false
                Keys.onReturnPressed: root.locked = false

                Rectangle {
                    anchors.centerIn: parent
                    width: 340
                    height: 220
                    radius: 22
                    color: theme.surface
                    border.color: theme.primary
                    border.width: 2

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatTime(clock.date, "HH:mm")
                            color: theme.primary
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 56
                            font.weight: Font.Black
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDate(clock.date, "dddd, dd MMMM").toUpperCase()
                            color: theme.fg
                            opacity: 0.82
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.letterSpacing: 1.5
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 140
                            height: 32
                            radius: 16
                            color: theme.primary

                            Text {
                                anchors.centerIn: parent
                                text: "UNLOCK"
                                color: theme.bg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.locked = false
                            }
                        }
                    }
                }
            }
        }
    }
}
