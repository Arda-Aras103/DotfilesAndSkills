import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    ThemeConfig { id: themeCfg }

    property bool locked: false
    property real shaderTime: 0.0
    property int activeWorkspace: 1

    readonly property var activePlayer: (Mpris.players && Mpris.players.values && Mpris.players.values.length > 0)
        ? Mpris.players.values[0] : null

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    FrameAnimation {
        running: true
        onTriggered: root.shaderTime += frameTime
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

    Process {
        id: wsSwitchProc
    }

    // Background Balatro Swirl Layer (ShaderEffect when .qsb compiled, animated Canvas fallback otherwise)
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
            WlrLayershell.namespace: "balatro-wallpaper"

            Rectangle {
                anchors.fill: parent
                color: "#162325"

                Loader {
                    anchors.fill: parent
                    active: themeCfg.hasQsbShader
                    sourceComponent: ShaderEffect {
                        property real iTime: root.shaderTime
                        property vector2d iResolution: Qt.vector2d(width, height)
                        property real spinAmount: 0.72
                        property real contrast: 3.2
                        fragmentShader: themeCfg.qsbUrl
                    }
                }

                Canvas {
                    id: fallbackSwirl
                    anchors.fill: parent
                    visible: !themeCfg.hasQsbShader
                    property real t: root.shaderTime
                    onTChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        var w = width;
                        var h = height;
                        if (w <= 0 || h <= 0) return;

                        ctx.fillStyle = "#162325";
                        ctx.fillRect(0, 0, w, h);

                        var cx = w * 0.5;
                        var cy = h * 0.5;
                        var maxR = Math.sqrt(cx * cx + cy * cy);
                        var rings = 14;

                        for (var r = rings; r >= 1; r--) {
                            var frac = r / rings;
                            var radius = maxR * frac;
                            var angle = t * 0.45 + r * 0.42;
                            var ox = cx + Math.cos(angle) * 44 * (1 - frac);
                            var oy = cy + Math.sin(angle * 1.1) * 38 * (1 - frac);

                            var grad = ctx.createRadialGradient(ox, oy, radius * 0.08, cx, cy, radius);
                            if (r % 2 === 0) {
                                grad.addColorStop(0, "rgba(222, 68, 59, 0.55)");
                                grad.addColorStop(0.55, "rgba(22, 35, 37, 0.35)");
                                grad.addColorStop(1, "rgba(0, 107, 180, 0.45)");
                            } else {
                                grad.addColorStop(0, "rgba(0, 107, 180, 0.50)");
                                grad.addColorStop(0.55, "rgba(22, 35, 37, 0.30)");
                                grad.addColorStop(1, "rgba(222, 68, 59, 0.42)");
                            }
                            ctx.fillStyle = grad;
                            ctx.beginPath();
                            ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                            ctx.fill();
                        }

                        // Subtle CRT scanlines
                        ctx.fillStyle = "rgba(8, 12, 16, 0.16)";
                        for (var y = 0; y < h; y += 4) {
                            ctx.fillRect(0, y, w, 1);
                        }
                    }
                }
            }
        }
    }

    // Top Balatro Joker/Blind HUD Bar
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
                top: 8
                left: 14
                right: 14
            }

            implicitHeight: 42
            exclusiveZone: 50
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "balatro-hud"

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: "#e61b222a"
                border.color: "#de443b"
                border.width: 2

                // Inner gold trim
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: 5
                    color: "transparent"
                    border.color: "#f5b841"
                    border.width: 1
                    opacity: 0.55
                }

                // Left: Blind Badge + Workspaces
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        height: 26
                        width: blindTxt.implicitWidth + 18
                        radius: 5
                        color: "#de443b"
                        border.color: "#f5b841"
                        border.width: 1

                        Text {
                            id: blindTxt
                            anchors.centerIn: parent
                            text: "BALATRO // ANTE"
                            color: "#fff8e7"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.weight: Font.Black
                            font.letterSpacing: 1
                        }
                    }

                    Repeater {
                        model: [1, 2, 3, 4]
                        delegate: Rectangle {
                            readonly property bool isCurrent: root.activeWorkspace === modelData
                            width: 28
                            height: 26
                            radius: 5
                            color: isCurrent ? "#006bb4" : "#26313d"
                            border.color: isCurrent ? "#f5b841" : "#445466"
                            border.width: isCurrent ? 2 : 1

                            Text {
                                anchors.centerIn: parent
                                text: String(modelData)
                                color: isCurrent ? "#fff8e7" : "#b8c6d6"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
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

                // Center: Clock & Date Chip
                Rectangle {
                    anchors.centerIn: parent
                    height: 28
                    width: clockRow.implicitWidth + 24
                    radius: 6
                    color: "#12181f"
                    border.color: "#f5b841"
                    border.width: 1.5

                    Row {
                        id: clockRow
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            text: Qt.formatTime(clock.date, "HH:mm:ss")
                            color: "#f5b841"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.weight: Font.Black
                        }

                        Text {
                            text: Qt.formatDate(clock.date, "ddd dd MMM").toUpperCase()
                            color: "#d4dce6"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }
                }

                // Right: MPRIS Media Chip + Lock Button
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        visible: root.activePlayer !== null
                        height: 26
                        width: Math.min(220, mediaTxt.implicitWidth + 20)
                        radius: 5
                        color: "#222d38"
                        border.color: "#006bb4"
                        border.width: 1
                        clip: true

                        Text {
                            id: mediaTxt
                            anchors.centerIn: parent
                            width: parent.width - 14
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            text: root.activePlayer ? ((root.activePlayer.isPlaying ? "▶ " : "⏸ ") + (root.activePlayer.trackTitle || "Playing")) : ""
                            color: "#d8e6f5"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activePlayer && root.activePlayer.canTogglePlaying) {
                                    root.activePlayer.togglePlaying();
                                }
                            }
                        }
                    }

                    Rectangle {
                        height: 26
                        width: lockBtnTxt.implicitWidth + 18
                        radius: 5
                        color: lockBtnMouse.containsMouse ? "#de443b" : "#2b1c22"
                        border.color: "#de443b"
                        border.width: 1.5

                        Text {
                            id: lockBtnTxt
                            anchors.centerIn: parent
                            text: "LOCK"
                            color: "#fff8e7"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: lockBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.locked = true
                        }
                    }
                }
            }
        }
    }

    // Super+L Balatro Lockscreen Overlay
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
            WlrLayershell.namespace: "balatro-lock"

            Rectangle {
                anchors.fill: parent
                color: "#cc0e151a"
                focus: root.locked
                Keys.onEscapePressed: root.locked = false
                Keys.onReturnPressed: root.locked = false

                Rectangle {
                    anchors.centerIn: parent
                    width: 360
                    height: 260
                    radius: 14
                    color: "#1b222a"
                    border.color: "#f5b841"
                    border.width: 3

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: 10
                        color: "transparent"
                        border.color: "#de443b"
                        border.width: 2
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 14

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "BOSS BLIND // LOCKED"
                            color: "#de443b"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.weight: Font.Black
                            font.letterSpacing: 2
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatTime(clock.date, "HH:mm")
                            color: "#fff8e7"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 54
                            font.weight: Font.Black
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDate(clock.date, "dddd, dd MMMM").toUpperCase()
                            color: "#9db0c4"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.letterSpacing: 1.5
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 180
                            height: 36
                            radius: 8
                            color: unlockMouse.containsMouse ? "#0082d9" : "#006bb4"
                            border.color: "#f5b841"
                            border.width: 1.5

                            Text {
                                anchors.centerIn: parent
                                text: "PLAY HAND (UNLOCK)"
                                color: "#ffffff"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: unlockMouse
                                anchors.fill: parent
                                hoverEnabled: true
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
