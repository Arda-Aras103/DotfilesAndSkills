import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    property bool locked: false
    property bool lampOn: true
    property bool drawerOpen: true
    property bool mailboxFlagUp: true
    property bool mailboxPopupOpen: false
    property int activeWorkspace: 1
    property int trashedCount: 0
    property int nextNoteSeq: 1

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
        launchProc.command = ["hyprctl", "dispatch", "workspace", String(ws)];
        launchProc.running = true;
    }

    function launchCmd(cmdStr) {
        launchProc.command = ["sh", "-c", cmdStr + " >/dev/null 2>&1 &"];
        launchProc.running = true;
    }

    Process { id: launchProc }

    ListModel {
        id: sheetModel
        ListElement {
            title: "DESK // NOTES"
            body: "Drag sheets around.\nClick dog-ear to fold.\nCrumple & toss in bin."
            xPos: 260
            yPos: 290
            rotDeg: -3
            folded: false
            crumpled: false
        }
        ListElement {
            title: "HYPRLAND KEYS"
            body: "Super+T : Switch Theme\nSuper+Enter : Terminal\nSuper+R : Launcher"
            xPos: 520
            yPos: 340
            rotDeg: 2.5
            folded: true
            crumpled: false
        }
        ListElement {
            title: "STUDY PLAN"
            body: "- Terraform & K8s lab\n- xv6 syscall review\n- Algorithms DP set"
            xPos: 770
            yPos: 280
            rotDeg: -1.8
            folded: false
            crumpled: false
        }
    }

    property var trashedStack: []

    function addNewSheet() {
        var titles = ["SCRATCHPAD", "LAB NOTES", "DEVOPS CHECK", "QUICK SKETCH"];
        var bodies = [
            "Fresh crisp paper sheet.\nFold corner or crumple!",
            "kubectl get pods -A\nterraform plan -out=tf",
            "git status && pytest\nCheck telemetry logs",
            "Crumple into a ball and\ndrop into trash bin."
        ];
        var idx = (nextNoteSeq - 1) % titles.length;
        sheetModel.append({
            title: titles[idx] + " #" + nextNoteSeq,
            body: bodies[idx],
            xPos: 320 + ((nextNoteSeq * 47) % 380),
            yPos: 270 + ((nextNoteSeq * 33) % 180),
            rotDeg: ((nextNoteSeq % 5) - 2) * 1.6,
            folded: false,
            crumpled: false
        });
        nextNoteSeq += 1;
    }

    function tossSheet(index) {
        if (index < 0 || index >= sheetModel.count) return;
        var item = sheetModel.get(index);
        var copy = trashedStack.slice();
        copy.push({
            title: item.title,
            body: item.body,
            xPos: item.xPos,
            yPos: item.yPos,
            rotDeg: item.rotDeg
        });
        trashedStack = copy;
        sheetModel.remove(index);
        trashedCount += 1;
    }

    function restoreLastSheet() {
        if (trashedStack.length === 0) return;
        var copy = trashedStack.slice();
        var item = copy.pop();
        trashedStack = copy;
        sheetModel.append({
            title: item.title,
            body: item.body,
            xPos: item.xPos,
            yPos: item.yPos,
            rotDeg: item.rotDeg,
            folded: false,
            crumpled: false
        });
        trashedCount = Math.max(0, trashedCount - 1);
    }

    // 1. 3D Perspective Study Room & Wooden Desk Surface (WlrLayer.Background)
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
            WlrLayershell.namespace: "desk-background"

            Canvas {
                id: deskCanvas
                anchors.fill: parent
                property bool lightOn: root.lampOn
                onLightOnChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    var w = width, h = height;
                    if (w <= 0 || h <= 0) return;
                    ctx.reset();

                    var horizonY = h * 0.27;

                    // Upper study wall + bookshelf alcove
                    var wallGrad = ctx.createLinearGradient(0, 0, 0, horizonY);
                    if (lightOn) {
                        wallGrad.addColorStop(0.0, "#1c1714");
                        wallGrad.addColorStop(1.0, "#2d231c");
                    } else {
                        wallGrad.addColorStop(0.0, "#0c0b0e");
                        wallGrad.addColorStop(1.0, "#151319");
                    }
                    ctx.fillStyle = wallGrad;
                    ctx.fillRect(0, 0, w, horizonY);

                    // Wooden wall baseboard / bookshelf ledge
                    ctx.fillStyle = lightOn ? "#4e3422" : "#261b14";
                    ctx.fillRect(0, horizonY - 14, w, 14);
                    ctx.fillStyle = lightOn ? "#6e4b32" : "#35261c";
                    ctx.fillRect(0, horizonY - 14, w, 3);

                    // Perspective oak desk surface
                    var deskGrad = ctx.createLinearGradient(0, horizonY, 0, h);
                    if (lightOn) {
                        deskGrad.addColorStop(0.0, "#5c3b24");
                        deskGrad.addColorStop(0.45, "#784d2e");
                        deskGrad.addColorStop(1.0, "#462b19");
                    } else {
                        deskGrad.addColorStop(0.0, "#281b13");
                        deskGrad.addColorStop(0.45, "#362419");
                        deskGrad.addColorStop(1.0, "#1b120d");
                    }
                    ctx.fillStyle = deskGrad;
                    ctx.fillRect(0, horizonY, w, h - horizonY);

                    // 3D receding wood plank perspective lines toward vanishing point
                    var vx = w * 0.5;
                    var vy = horizonY - h * 0.38;
                    ctx.strokeStyle = lightOn ? "rgba(32, 18, 9, 0.36)" : "rgba(8, 5, 4, 0.55)";
                    ctx.lineWidth = 1.6;
                    var plankCount = 12;
                    for (var i = 0; i <= plankCount; i++) {
                        var bx = (i / plankCount) * w * 1.35 - w * 0.175;
                        var tTop = (horizonY - vy) / (h - vy);
                        var tx = vx + (bx - vx) * tTop;
                        ctx.beginPath();
                        ctx.moveTo(tx, horizonY);
                        ctx.lineTo(bx, h);
                        ctx.stroke();
                    }

                    // Horizontal perspective grain depth seams
                    var seams = [0.38, 0.54, 0.74];
                    ctx.lineWidth = 1.1;
                    for (var s = 0; s < seams.length; s++) {
                        var sy = h * seams[s];
                        ctx.beginPath();
                        ctx.moveTo(0, sy);
                        ctx.lineTo(w, sy);
                        ctx.stroke();
                    }

                    // Perspective dark-green / espresso stitched leather desk blotter pad
                    var padTopY = horizonY + (h - horizonY) * 0.11;
                    var padBotY = h - 78;
                    var padTopW = w * 0.52;
                    var padBotW = w * 0.64;
                    ctx.fillStyle = lightOn ? "#1d3228" : "#111b16";
                    ctx.beginPath();
                    ctx.moveTo(vx - padTopW * 0.5, padTopY);
                    ctx.lineTo(vx + padTopW * 0.5, padTopY);
                    ctx.lineTo(vx + padBotW * 0.5, padBotY);
                    ctx.lineTo(vx - padBotW * 0.5, padBotY);
                    ctx.closePath();
                    ctx.fill();

                    ctx.strokeStyle = lightOn ? "#9b8356" : "#443b2a";
                    ctx.lineWidth = 2;
                    ctx.setLineDash([7, 5]);
                    ctx.stroke();
                    ctx.setLineDash([]);

                    // Warm architect desk lamp light cone
                    if (lightOn) {
                        var lx = w * 0.17;
                        var ly = horizonY + 18;
                        var cone = ctx.createRadialGradient(lx + 160, ly + 170, 24, lx + 230, ly + 240, w * 0.48);
                        cone.addColorStop(0.0, "rgba(255, 214, 130, 0.34)");
                        cone.addColorStop(0.45, "rgba(255, 186, 92, 0.14)");
                        cone.addColorStop(1.0, "rgba(255, 165, 70, 0.0)");
                        ctx.fillStyle = cone;
                        ctx.fillRect(0, horizonY - 40, w, h - horizonY + 40);
                    } else {
                        ctx.fillStyle = "rgba(8, 10, 20, 0.32)";
                        ctx.fillRect(0, 0, w, h);
                    }
                }
            }
        }
    }

    // 2. Interactive Study Desk Surface (Lamp, Bookshelf Folders, Mailbox, Trash Bin, Paper Sheets)
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
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "desk-props"

            readonly property real horizonY: height * 0.27

            // Clickable Brass / Matte Architect Desk Lamp (Left of Bookshelf)
            Item {
                id: lampWidget
                x: Math.max(32, parent.width * 0.06)
                y: Math.max(24, parent.horizonY - 168)
                width: 170
                height: 185

                Canvas {
                    anchors.fill: parent
                    property bool on: root.lampOn
                    onOnChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        // Base
                        ctx.fillStyle = "#2b2a29";
                        ctx.strokeStyle = "#c89d54";
                        ctx.lineWidth = 2;
                        ctx.beginPath();
                        ctx.ellipse(24, 152, 68, 22);
                        ctx.fill();
                        ctx.stroke();

                        // Articulated arm
                        ctx.strokeStyle = "#b58d47";
                        ctx.lineWidth = 6;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.moveTo(56, 156);
                        ctx.lineTo(36, 90);
                        ctx.lineTo(106, 46);
                        ctx.stroke();

                        // Lamp shade cone
                        ctx.fillStyle = on ? "#2f4f3c" : "#1d2621";
                        ctx.strokeStyle = "#c89d54";
                        ctx.lineWidth = 2;
                        ctx.beginPath();
                        ctx.moveTo(92, 34);
                        ctx.lineTo(128, 30);
                        ctx.lineTo(156, 76);
                        ctx.lineTo(84, 72);
                        ctx.closePath();
                        ctx.fill();
                        ctx.stroke();

                        // Glowing bulb inside shade
                        ctx.fillStyle = on ? "#ffdf85" : "#555046";
                        ctx.beginPath();
                        ctx.arc(122, 68, 12, 0, Math.PI);
                        ctx.fill();
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: lampTxt.implicitWidth + 16
                    height: 20
                    radius: 4
                    color: root.lampOn ? "#c89d54" : "#2e2b27"
                    border.color: "#1a1510"
                    border.width: 1

                    Text {
                        id: lampTxt
                        anchors.centerIn: parent
                        text: root.lampOn ? "LAMP: ON" : "LAMP: OFF"
                        color: root.lampOn ? "#1a140b" : "#d8ccb8"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.lampOn = !root.lampOn
                }
            }

            // Center Upper Bookshelf App Folders (Terminal, Files, Browser, Code)
            Row {
                id: bookshelfRow
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(36, parent.horizonY - 122)
                spacing: 14

                Repeater {
                    model: [
                        { label: "Terminal", icon: ">_", cmd: "kitty", spine: "#295e73", trim: "#7ec8e3" },
                        { label: "Files", icon: "DIR", cmd: "dolphin", spine: "#8c5424", trim: "#f0b775" },
                        { label: "Browser", icon: "WEB", cmd: "xdg-open https://github.com", spine: "#2d6a4f", trim: "#95d5b2" },
                        { label: "Code", icon: "{ }", cmd: "zed || kitty", spine: "#5f3b6e", trim: "#d8b4e2" }
                    ]

                    delegate: Rectangle {
                        id: bookCard
                        width: 74
                        height: 112
                        radius: 4
                        y: bookMouse.containsMouse ? -10 : 0
                        color: modelData.spine
                        border.color: modelData.trim
                        border.width: 2

                        Behavior on y { NumberAnimation { duration: 120 } }

                        // Book spine horizontal bands
                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: 12
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 14
                            height: 4
                            color: modelData.trim
                            opacity: 0.75
                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -6
                            text: modelData.icon
                            color: "#fff8eb"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            font.weight: Font.Black
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 10
                            height: 22
                            radius: 2
                            color: "#f2e7cf"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: "#221a12"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }

                        MouseArea {
                            id: bookMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launchCmd(modelData.cmd)
                        }
                    }
                }
            }

            // Right Desk Corner: Mailbox Notification Flag + Popup Card
            Item {
                id: mailboxWidget
                x: parent.width - 210
                y: Math.max(36, parent.horizonY - 120)
                width: 168
                height: 128

                Canvas {
                    anchors.fill: parent
                    property bool flagUp: root.mailboxFlagUp
                    onFlagUpChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        // Wooden post
                        ctx.fillStyle = "#523522";
                        ctx.fillRect(72, 78, 18, 42);
                        // Mailbox body
                        ctx.fillStyle = "#34495e";
                        ctx.strokeStyle = "#d5cbb8";
                        ctx.lineWidth = 2;
                        ctx.beginPath();
                        ctx.roundRect(34, 34, 94, 48, 12);
                        ctx.fill();
                        ctx.stroke();
                        // Front arched door
                        ctx.fillStyle = "#22303e";
                        ctx.beginPath();
                        ctx.roundRect(42, 42, 34, 34, 8);
                        ctx.fill();
                        // Red notification flag
                        ctx.fillStyle = "#d94136";
                        if (flagUp) {
                            ctx.fillRect(108, 8, 5, 36);
                            ctx.fillRect(113, 8, 22, 13);
                        } else {
                            ctx.fillRect(96, 52, 34, 5);
                            ctx.fillRect(118, 57, 12, 14);
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: mbLabel.implicitWidth + 16
                    height: 20
                    radius: 4
                    color: root.mailboxFlagUp ? "#b83b32" : "#2f3e4e"
                    border.color: "#efe6d4"
                    border.width: 1

                    Text {
                        id: mbLabel
                        anchors.centerIn: parent
                        text: root.mailboxFlagUp ? "MAILBOX: NEW" : "MAILBOX: READ"
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.mailboxPopupOpen = !root.mailboxPopupOpen;
                        if (root.mailboxPopupOpen) root.mailboxFlagUp = false;
                    }
                }
            }

            // Mailbox Popup Card (Notifications / Time / Active Track)
            Rectangle {
                visible: root.mailboxPopupOpen
                x: parent.width - 330
                y: parent.horizonY + 18
                width: 288
                height: mbCol.implicitHeight + 24
                radius: 8
                color: "#f6eedc"
                border.color: "#523522"
                border.width: 2
                z: 40

                Column {
                    id: mbCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Row {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "DESK POST // " + Qt.formatTime(clock.date, "HH:mm")
                            color: "#2c2218"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.weight: Font.Black
                        }

                        Item { width: 1; height: 1 }

                        Text {
                            text: "[Toggle Flag]"
                            color: "#8c342b"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            font.weight: Font.Bold

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.mailboxFlagUp = !root.mailboxFlagUp
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Workspace " + root.activeWorkspace + " • " + Qt.formatDate(clock.date, "dddd, dd MMM")
                        color: "#5c4a38"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: root.activePlayer
                            ? ("Now Playing: " + (root.activePlayer.trackTitle || "Track"))
                            : "No active audio stream. Desk quiet."
                        color: "#362b21"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                    }
                }
            }

            // Desk Left Tool Button: [+ NEW SHEET]
            Rectangle {
                id: newSheetBtn
                x: 42
                y: parent.horizonY + 34
                width: 132
                height: 36
                radius: 6
                color: newSheetMouse.containsMouse ? "#efe1c4" : "#e3d1ad"
                border.color: "#4a321f"
                border.width: 2
                z: 5

                Text {
                    anchors.centerIn: parent
                    text: "+ NEW SHEET"
                    color: "#291c12"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.weight: Font.Black
                }

                MouseArea {
                    id: newSheetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addNewSheet()
                }
            }

            // Bottom-Right Wire-Mesh Trash Bin Dropzone
            Item {
                id: trashBin
                x: parent.width - 178
                y: parent.height - 224
                width: 132
                height: 146
                z: 8

                property bool dropHighlight: false

                Canvas {
                    anchors.fill: parent
                    property bool lit: trashBin.dropHighlight
                    property int count: root.trashedCount
                    onLitChanged: requestPaint()
                    onCountChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        // Bin shadow
                        ctx.fillStyle = "rgba(0, 0, 0, 0.35)";
                        ctx.beginPath();
                        ctx.ellipse(66, 128, 48, 12);
                        ctx.fill();

                        // Tapered steel mesh body
                        ctx.fillStyle = lit ? "rgba(217, 74, 61, 0.28)" : "rgba(38, 44, 52, 0.72)";
                        ctx.strokeStyle = lit ? "#ff7a6e" : "#9aa4b0";
                        ctx.lineWidth = lit ? 3 : 2;
                        ctx.beginPath();
                        ctx.moveTo(22, 26);
                        ctx.lineTo(110, 26);
                        ctx.lineTo(96, 122);
                        ctx.lineTo(36, 122);
                        ctx.closePath();
                        ctx.fill();
                        ctx.stroke();

                        // Wire mesh ribs
                        ctx.strokeStyle = lit ? "#ff9b92" : "rgba(190, 200, 212, 0.45)";
                        ctx.lineWidth = 1.2;
                        for (var gx = 36; gx <= 96; gx += 15) {
                            ctx.beginPath();
                            ctx.moveTo(gx, 28);
                            ctx.lineTo(66 + (gx - 66) * 0.72, 120);
                            ctx.stroke();
                        }

                        // Paper balls sitting inside bin
                        var shown = Math.min(4, count);
                        for (var b = 0; b < shown; b++) {
                            ctx.fillStyle = "#e6dcc5";
                            ctx.strokeStyle = "#8a7f6b";
                            ctx.beginPath();
                            ctx.arc(46 + b * 12, 108 - (b % 2) * 8, 9, 0, Math.PI * 2);
                            ctx.fill();
                            ctx.stroke();
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: binLbl.implicitWidth + 14
                    height: 20
                    radius: 4
                    color: trashBin.dropHighlight ? "#b83b32" : "#22272e"
                    border.color: "#9aa4b0"
                    border.width: 1

                    Text {
                        id: binLbl
                        anchors.centerIn: parent
                        text: root.trashedCount > 0 ? ("TRASH (" + root.trashedCount + ") • RESTORE") : "TRASH BIN"
                        color: "#f2f4f8"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.restoreLastSheet()
                }
            }

            // Draggable, Foldable & Crumplable Paper Sheets on the Desk
            Repeater {
                model: sheetModel

                delegate: Item {
                    id: sheetRoot
                    x: xPos
                    y: yPos
                    width: crumpled ? 72 : 210
                    height: crumpled ? 72 : 168
                    rotation: crumpled ? rotDeg * 4 : rotDeg
                    z: sheetDrag.drag.active ? 35 : 15 + index

                    Behavior on width { NumberAnimation { duration: 150 } }
                    Behavior on height { NumberAnimation { duration: 150 } }

                    function checkOverTrash() {
                        var cx = sheetRoot.x + sheetRoot.width * 0.5;
                        var cy = sheetRoot.y + sheetRoot.height * 0.5;
                        return (cx >= trashBin.x - 18 && cx <= trashBin.x + trashBin.width + 18 &&
                                cy >= trashBin.y - 18 && cy <= trashBin.y + trashBin.height + 18);
                    }

                    // Flat / Dog-Ear Folded Paper View
                    Item {
                        visible: !crumpled
                        anchors.fill: parent

                        // Drop shadow on blotter/wood
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 5
                            anchors.topMargin: 6
                            color: "#55000000"
                            radius: 2
                        }

                        // Paper body + optional dog-ear folded corner canvas
                        Canvas {
                            anchors.fill: parent
                            property bool isFolded: folded
                            property bool isLit: root.lampOn
                            onIsFoldedChanged: requestPaint()
                            onIsLitChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                var w = width, h = height;
                                var fold = isFolded ? 32 : 0;
                                ctx.reset();

                                // Main paper polygon (dog-ear notch if folded)
                                ctx.fillStyle = isLit ? "#faf2dc" : "#c8bfa8";
                                ctx.strokeStyle = "#8a7b63";
                                ctx.lineWidth = 1.4;
                                ctx.beginPath();
                                ctx.moveTo(0, 0);
                                ctx.lineTo(w - fold, 0);
                                if (isFolded) {
                                    ctx.lineTo(w, fold);
                                }
                                ctx.lineTo(w, h);
                                ctx.lineTo(0, h);
                                ctx.closePath();
                                ctx.fill();
                                ctx.stroke();

                                // Subtle ruled notebook lines
                                ctx.strokeStyle = "rgba(110, 145, 185, 0.25)";
                                ctx.lineWidth = 1;
                                for (var ly = 42; ly < h - 30; ly += 20) {
                                    ctx.beginPath();
                                    ctx.moveTo(12, ly);
                                    ctx.lineTo(w - 12, ly);
                                    ctx.stroke();
                                }

                                // Folded dog-ear flap triangle + shadow
                                if (isFolded) {
                                    ctx.fillStyle = isLit ? "#dfd2b4" : "#9c937e";
                                    ctx.beginPath();
                                    ctx.moveTo(w - fold, 0);
                                    ctx.lineTo(w - fold, fold);
                                    ctx.lineTo(w, fold);
                                    ctx.closePath();
                                    ctx.fill();
                                    ctx.strokeStyle = "#7a6b54";
                                    ctx.stroke();
                                }
                            }
                        }

                        // Dog-ear corner click hotspot
                        MouseArea {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            width: 38
                            height: 38
                            cursorShape: Qt.PointingHandCursor
                            z: 5
                            onClicked: sheetModel.setProperty(index, "folded", !folded)
                        }

                        // Sheet title + handwritten/mono text
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            Text {
                                width: parent.width - 28
                                elide: Text.ElideRight
                                text: title
                                color: "#2b2116"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.weight: Font.Black
                            }

                            Text {
                                width: parent.width
                                height: 76
                                wrapMode: Text.WordWrap
                                text: body
                                color: "#443728"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                            }
                        }

                        // Sheet Action Buttons (Fold / Crumple / Toss)
                        Row {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.margins: 8
                            spacing: 5
                            z: 6

                            Rectangle {
                                width: 48
                                height: 20
                                radius: 3
                                color: "#e5d7b8"
                                border.color: "#7a6b54"

                                Text {
                                    anchors.centerIn: parent
                                    text: folded ? "UNFOLD" : "FOLD"
                                    color: "#2b2116"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 8
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: sheetModel.setProperty(index, "folded", !folded)
                                }
                            }

                            Rectangle {
                                width: 56
                                height: 20
                                radius: 3
                                color: "#ded0b0"
                                border.color: "#7a6b54"

                                Text {
                                    anchors.centerIn: parent
                                    text: "CRUMPLE"
                                    color: "#2b2116"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 8
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: sheetModel.setProperty(index, "crumpled", true)
                                }
                            }

                            Rectangle {
                                width: 40
                                height: 20
                                radius: 3
                                color: "#d9b2a9"
                                border.color: "#7c3228"

                                Text {
                                    anchors.centerIn: parent
                                    text: "TOSS"
                                    color: "#4a1711"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 8
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.tossSheet(index)
                                }
                            }
                        }
                    }

                    // Faceted Crumpled Paper-Ball View
                    Item {
                        visible: crumpled
                        anchors.fill: parent

                        Canvas {
                            anchors.fill: parent
                            onPaint: {
                                var ctx = getContext("2d");
                                var w = width, h = height;
                                ctx.reset();
                                ctx.fillStyle = "rgba(0,0,0,0.35)";
                                ctx.beginPath();
                                ctx.ellipse(w * 0.52, h * 0.78, w * 0.34, h * 0.14);
                                ctx.fill();

                                var pts = [
                                    [0.50, 0.12], [0.80, 0.24], [0.90, 0.56], [0.72, 0.84],
                                    [0.36, 0.86], [0.14, 0.62], [0.18, 0.28]
                                ];
                                ctx.fillStyle = "#efe5cd";
                                ctx.strokeStyle = "#7a6b54";
                                ctx.lineWidth = 1.6;
                                ctx.beginPath();
                                ctx.moveTo(pts[0][0] * w, pts[0][1] * h);
                                for (var i = 1; i < pts.length; i++) {
                                    ctx.lineTo(pts[i][0] * w, pts[i][1] * h);
                                }
                                ctx.closePath();
                                ctx.fill();
                                ctx.stroke();

                                // Crumple crease lines inside ball
                                ctx.beginPath();
                                ctx.moveTo(0.20 * w, 0.32 * h); ctx.lineTo(0.54 * w, 0.50 * h); ctx.lineTo(0.86 * w, 0.52 * h);
                                ctx.moveTo(0.54 * w, 0.50 * h); ctx.lineTo(0.42 * w, 0.82 * h);
                                ctx.moveTo(0.50 * w, 0.14 * h); ctx.lineTo(0.54 * w, 0.50 * h);
                                ctx.strokeStyle = "#9c8f78";
                                ctx.lineWidth = 1.2;
                                ctx.stroke();
                            }
                        }

                        // Click small pill below ball to flatten back or drag to trash
                        MouseArea {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 60
                            height: 18
                            z: 8
                            cursorShape: Qt.PointingHandCursor
                            onDoubleClicked: sheetModel.setProperty(index, "crumpled", false)
                        }
                    }

                    // Sheet Drag Controller (works in both flat and crumpled states)
                    MouseArea {
                        id: sheetDrag
                        anchors.fill: parent
                        anchors.bottomMargin: crumpled ? 0 : 30
                        anchors.rightMargin: crumpled ? 0 : 34
                        cursorShape: Qt.OpenHandCursor
                        drag.target: sheetRoot
                        drag.axis: Drag.XAndYAxis
                        onPositionChanged: {
                            if (drag.active) {
                                trashBin.dropHighlight = sheetRoot.checkOverTrash();
                            }
                        }
                        onReleased: {
                            trashBin.dropHighlight = false;
                            if (sheetRoot.checkOverTrash()) {
                                root.tossSheet(index);
                            } else {
                                sheetModel.setProperty(index, "xPos", Math.round(sheetRoot.x));
                                sheetModel.setProperty(index, "yPos", Math.round(sheetRoot.y));
                            }
                        }
                        onDoubleClicked: {
                            if (crumpled) sheetModel.setProperty(index, "crumpled", false);
                        }
                    }
                }
            }
        }
    }

    // 3. Bottom Pull-Out Desk Drawer Dock (WlrLayer.Top so accessible over apps)
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                bottom: true
                left: true
                right: true
            }

            implicitHeight: root.drawerOpen ? 56 : 20
            exclusiveZone: root.drawerOpen ? 56 : 20
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "desk-drawer"

            Behavior on implicitHeight { NumberAnimation { duration: 150 } }

            Item {
                anchors.fill: parent

                // Brass Drawer Pull Handle Tab
                Rectangle {
                    id: drawerTab
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 150
                    height: 16
                    radius: 4
                    color: tabMouse.containsMouse ? "#7a5133" : "#5c3b24"
                    border.color: "#c89d54"
                    border.width: 1
                    z: 4

                    Text {
                        anchors.centerIn: parent
                        text: root.drawerOpen ? "▼ DESK DRAWER ▼" : "▲ PULL DRAWER ▲"
                        color: "#f5e6c8"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.drawerOpen = !root.drawerOpen
                    }
                }

                // Wooden Drawer Body
                Rectangle {
                    visible: root.drawerOpen
                    anchors.top: drawerTab.bottom
                    anchors.topMargin: -2
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width - 28, 920)
                    radius: 6
                    color: "#3f2718"
                    border.color: "#c89d54"
                    border.width: 2

                    // Left: Workspaces 1..4
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Repeater {
                            model: [1, 2, 3, 4]
                            delegate: Rectangle {
                                readonly property bool current: root.activeWorkspace === modelData
                                width: 26
                                height: 26
                                radius: 4
                                color: current ? "#c89d54" : "#281910"
                                border.color: "#8f6a34"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: String(modelData)
                                    color: current ? "#1c120b" : "#e8d9bc"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.weight: Font.Black
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.switchWorkspace(modelData)
                                }
                            }
                        }
                    }

                    // Center: Drawer Quick Tools
                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Repeater {
                            model: [
                                { lbl: "KITTY", cmd: "kitty" },
                                { lbl: "DOLPHIN", cmd: "dolphin" },
                                { lbl: "BROWSER", cmd: "xdg-open https://github.com" },
                                { lbl: "ZED", cmd: "zed || kitty" }
                            ]
                            delegate: Rectangle {
                                width: dLbl.implicitWidth + 18
                                height: 26
                                radius: 4
                                color: dMouse.containsMouse ? "#6b4429" : "#2e1c11"
                                border.color: "#9b7843"
                                border.width: 1

                                Text {
                                    id: dLbl
                                    anchors.centerIn: parent
                                    text: modelData.lbl
                                    color: "#f5e8cc"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    id: dMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.launchCmd(modelData.cmd)
                                }
                            }
                        }
                    }

                    // Right: Clock + Lock
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatTime(clock.date, "HH:mm:ss")
                            color: "#f2dfbc"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        Rectangle {
                            width: 56
                            height: 26
                            radius: 4
                            color: "#6e2e24"
                            border.color: "#d9927c"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "LOCK"
                                color: "#fff2eb"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                font.weight: Font.Black
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
    }

    // 4. Super+L Desk Lock Overlay
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
            WlrLayershell.namespace: "desk-lock"

            Rectangle {
                anchors.fill: parent
                color: "#d916100c"
                focus: root.locked
                Keys.onEscapePressed: root.locked = false
                Keys.onReturnPressed: root.locked = false

                Rectangle {
                    anchors.centerIn: parent
                    width: 340
                    height: 210
                    radius: 8
                    color: "#2b1c12"
                    border.color: "#c89d54"
                    border.width: 2

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "STUDY DESK LOCKED"
                            color: "#c89d54"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.weight: Font.Black
                            font.letterSpacing: 2
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatTime(clock.date, "HH:mm")
                            color: "#f7ecd5"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 52
                            font.weight: Font.Black
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 180
                            height: 36
                            radius: 6
                            color: unlockMouse.containsMouse ? "#d9b066" : "#c89d54"

                            Text {
                                anchors.centerIn: parent
                                text: "RETURN TO DESK"
                                color: "#1c120b"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.weight: Font.Black
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
