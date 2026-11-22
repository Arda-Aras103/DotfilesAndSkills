import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool locked: false
    property bool showPass: false

    readonly property color bgColor: "#0c0a08"
    readonly property color fgColor: "#eee5dd"
    readonly property color pillColor: "#221a14"
    readonly property color shadeColor: "#191410"
    readonly property color wireColor: "#c19c7b"
    readonly property string uiFont: "JetBrainsMono Nerd Font"

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
            WlrLayershell.namespace: "cyber-lock"

            Rectangle {
                anchors.fill: parent
                color: root.bgColor
                focus: root.locked
                Keys.onEscapePressed: root.locked = false
                Keys.onReturnPressed: root.locked = false

                // Top-left minimal telemetry strip
                Text {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 28
                    text: "SYSTEM // LOCKED"
                    font.family: root.uiFont
                    font.pixelSize: 11
                    font.letterSpacing: 2.5
                    color: root.fgColor
                    opacity: 0.45
                }

                // Left column: large cyber clock, day header, unlock pill, UNLOCK button
                Item {
                    id: leftCol
                    width: Math.min(parent.width * 0.40, 440)
                    height: leftStack.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: -parent.width * 0.25

                    Column {
                        id: leftStack
                        width: parent.width
                        spacing: 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatTime(clock.date, "HH:mm")
                            font.family: root.uiFont
                            font.pixelSize: Math.max(64, Math.min(104, parent.width * 0.24))
                            font.weight: Font.Black
                            font.letterSpacing: 4
                            color: root.fgColor
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDate(clock.date, "dddd  //  dd MMM").toUpperCase()
                            font.family: root.uiFont
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            font.letterSpacing: 3
                            color: root.fgColor
                            opacity: 0.88
                        }

                        Item { width: 1; height: 40 }

                        // Unlock passphrase pill
                        Rectangle {
                            id: passPill
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(310, parent.width)
                            height: 42
                            radius: 21
                            color: root.pillColor
                            border.width: passInput.activeFocus ? 1.8 : 1.0
                            border.color: passInput.activeFocus ? root.fgColor : root.wireColor

                            Text {
                                id: eyeToggle
                                anchors.left: parent.left
                                anchors.leftMargin: 15
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.showPass ? "◉" : "◎"
                                color: root.wireColor
                                font.family: root.uiFont
                                font.pixelSize: 14

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showPass = !root.showPass
                                }
                            }

                            TextInput {
                                id: passInput
                                anchors.left: eyeToggle.right
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: TextInput.AlignHCenter
                                color: root.fgColor
                                selectionColor: root.fgColor
                                selectedTextColor: root.bgColor
                                echoMode: root.showPass ? TextInput.Normal : TextInput.Password
                                passwordCharacter: "•"
                                font.family: root.uiFont
                                font.pixelSize: 13
                                font.letterSpacing: root.showPass ? 1 : 2.5
                                clip: true
                                Keys.onReturnPressed: {
                                    passInput.text = "";
                                    root.locked = false;
                                }
                                Keys.onEnterPressed: {
                                    passInput.text = "";
                                    root.locked = false;
                                }
                                Keys.onEscapePressed: root.locked = false

                                Text {
                                    anchors.centerIn: parent
                                    text: "PASSPHRASE"
                                    color: root.fgColor
                                    opacity: 0.42
                                    font.family: root.uiFont
                                    font.pixelSize: 12
                                    font.letterSpacing: 1.5
                                    visible: passInput.text.length === 0 && !passInput.activeFocus
                                }
                            }
                        }

                        Item { width: 1; height: 14 }

                        // UNLOCK button matching Main.qml pill style
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(310, parent.width)
                            height: 42
                            radius: 21
                            color: root.fgColor
                            opacity: unlockMouse.pressed ? 0.78 : (unlockMouse.containsMouse ? 0.88 : 1.0)

                            Text {
                                anchors.centerIn: parent
                                text: "UNLOCK"
                                color: root.bgColor
                                font.family: root.uiFont
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                font.letterSpacing: 2.5
                            }

                            MouseArea {
                                id: unlockMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    passInput.text = "";
                                    root.locked = false;
                                }
                            }
                        }

                        Item { width: 1; height: 18 }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Win+L / Esc / Enter to unlock"
                            color: root.wireColor
                            opacity: 0.65
                            font.family: root.uiFont
                            font.pixelSize: 10
                            font.letterSpacing: 1.2
                        }
                    }
                }

                // Right column: Editorial Portrait Showcase matching Main.qml
                Item {
                    id: rightCol
                    width: Math.min(parent.width * 0.46, 660)
                    height: Math.min(parent.height * 0.78, 640)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: parent.width * 0.05

                    Rectangle {
                        x: frameBox.x + 14
                        y: frameBox.y + 14
                        width: frameBox.width
                        height: frameBox.height
                        radius: 4
                        color: root.shadeColor
                        border.color: root.wireColor
                        border.width: 1
                        opacity: 0.65
                    }

                    Rectangle {
                        id: frameBox
                        x: 0
                        y: 0
                        width: parent.width - 14
                        height: parent.height - 14
                        radius: 4
                        color: root.bgColor
                        border.color: root.wireColor
                        border.width: 1.4
                        clip: true

                        Image {
                            id: frameImage
                            anchors.fill: parent
                            anchors.margins: 12
                            source: Qt.resolvedUrl("login-photo.jpg")
                            fillMode: Image.PreserveAspectCrop
                            horizontalAlignment: Image.AlignRight
                            asynchronous: true
                            smooth: true
                        }

                        Rectangle {
                            anchors.left: frameImage.left
                            anchors.right: frameImage.right
                            anchors.bottom: frameImage.bottom
                            height: 30
                            color: root.bgColor
                            opacity: 0.84

                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: root.wireColor
                                opacity: 0.45
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "CYBER // PORTRAIT"
                                color: root.fgColor
                                font.family: root.uiFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 2
                                opacity: 0.90
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatTime(clock.date, "HH:mm:ss")
                                color: root.wireColor
                                font.family: root.uiFont
                                font.pixelSize: 10
                                font.letterSpacing: 1.5
                            }
                        }

                        Canvas {
                            anchors.fill: parent
                            z: 4
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                var w = width, h = height;
                                if (w <= 0 || h <= 0) return;
                                ctx.reset();
                                ctx.strokeStyle = root.wireColor;
                                ctx.lineWidth = 1.8;
                                ctx.globalAlpha = 0.85;
                                var m = 10, b = 24;
                                ctx.beginPath();
                                ctx.moveTo(m, m + b); ctx.lineTo(m, m); ctx.lineTo(m + b, m);
                                ctx.moveTo(w - m - b, m); ctx.lineTo(w - m, m); ctx.lineTo(w - m, m + b);
                                ctx.moveTo(m, h - m - b); ctx.lineTo(m, h - m); ctx.lineTo(m + b, h - m);
                                ctx.moveTo(w - m - b, h - m); ctx.lineTo(w - m, h - m); ctx.lineTo(w - m, h - m - b);
                                ctx.stroke();

                                var radius = Math.min(w, h) * 0.30;
                                ctx.lineWidth = 1.2;
                                ctx.globalAlpha = 0.32;
                                ctx.beginPath();
                                ctx.arc(w * 0.76, h * 0.28, radius, -0.35, 1.30);
                                ctx.stroke();
                                ctx.beginPath();
                                ctx.arc(w * 0.76, h * 0.28, radius + 8, 2.55, 3.45);
                                ctx.stroke();
                            }
                        }
                    }
                }
            }
        }
    }
}
