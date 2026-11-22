import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    property bool locked: false
    property int activeWorkspace: 1
    // Boot sequence stages: 1 = MineGRUB Boot Menu, 2 = Building terrain / chunk grid, 0 = Desktop HUD
    property int bootStage: 1
    property int bootProgress: 0
    property int bootEntryIndex: 0
    property int autoBootSeconds: 4
    property bool autoBootPaused: false

    function triggerBoot() {
        locked = false;
        bootEntryIndex = 0;
        bootProgress = 0;
        autoBootSeconds = 4;
        autoBootPaused = false;
        bootStage = 1;
    }

    function startWorldGen() {
        bootProgress = 0;
        bootStage = 2;
    }

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

    IpcHandler {
        target: "boot"
        function trigger(): void { root.triggerBoot(); }
        function skip(): void { root.bootStage = 0; }
    }

    Timer {
        interval: 1000
        running: root.bootStage === 1 && !root.autoBootPaused
        repeat: true
        onTriggered: {
            if (root.autoBootSeconds > 1) {
                root.autoBootSeconds -= 1;
            } else {
                root.startWorldGen();
            }
        }
    }

    Timer {
        interval: 36
        running: root.bootStage === 2
        repeat: true
        onTriggered: {
            if (root.bootProgress < 100) {
                root.bootProgress = Math.min(100, root.bootProgress + 2);
            } else {
                root.bootStage = 0;
            }
        }
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

    // Blocky Minecraft Sky & Voxel Terrain Wallpaper Layer
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
            WlrLayershell.namespace: "minecraft-wallpaper"

            Canvas {
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    var w = width;
                    var h = height;
                    if (w <= 0 || h <= 0) return;

                    // Crisp Minecraft sky gradient
                    var sky = ctx.createLinearGradient(0, 0, 0, h * 0.72);
                    sky.addColorStop(0.0, "#4c7fd9");
                    sky.addColorStop(0.6, "#7ab3f2");
                    sky.addColorStop(1.0, "#b4d9ff");
                    ctx.fillStyle = sky;
                    ctx.fillRect(0, 0, w, h);

                    // Square pixel clouds
                    var blk = 32;
                    ctx.fillStyle = "rgba(255, 255, 255, 0.88)";
                    var cloudBoxes = [
                        [0.08, 0.16, 5, 1], [0.10, 0.13, 3, 1],
                        [0.42, 0.11, 6, 1], [0.46, 0.08, 3, 1],
                        [0.74, 0.20, 5, 1], [0.76, 0.17, 2, 1]
                    ];
                    for (var c = 0; c < cloudBoxes.length; c++) {
                        ctx.fillRect(w * cloudBoxes[c][0], h * cloudBoxes[c][1], blk * cloudBoxes[c][2], blk * cloudBoxes[c][3]);
                    }

                    // Blocky grass & dirt horizon
                    var horizon = Math.floor((h * 0.78) / blk) * blk;
                    var cols = Math.ceil(w / blk);
                    for (var x = 0; x < cols; x++) {
                        var hillOffset = ((x % 7 === 0) || (x % 11 === 0)) ? -blk : 0;
                        var gy = horizon + hillOffset;

                        // Grass top
                        ctx.fillStyle = (x % 2 === 0) ? "#5ca032" : "#67b23a";
                        ctx.fillRect(x * blk, gy, blk, blk);
                        ctx.fillStyle = "#487f24";
                        ctx.fillRect(x * blk, gy + blk - 6, blk, 6);

                        // Dirt & stone layers
                        for (var y = gy + blk; y < h; y += blk) {
                            var depth = (y - gy) / blk;
                            if (depth >= 3) {
                                ctx.fillStyle = ((x + depth) % 3 === 0) ? "#6d6d6d" : "#7c7c7c";
                            } else {
                                ctx.fillStyle = ((x + depth) % 2 === 0) ? "#79553a" : "#6b4931";
                            }
                            ctx.fillRect(x * blk, y, blk, blk);
                        }
                    }
                }
            }
        }
    }

    // Blocky Minecraft Hotbar + XP Top HUD
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
                top: 6
                left: 12
                right: 12
            }

            implicitHeight: 42
            exclusiveZone: 48
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "minecraft-hud"

            Rectangle {
                anchors.fill: parent
                radius: 0
                color: "#d9212121"
                border.color: "#555555"
                border.width: 3

                // Inner classic GUI bevel highlight
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: 0
                    color: "transparent"
                    border.color: "#111111"
                    border.width: 2
                }

                // Left: Hotbar Workspace Slots 1..4
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Rectangle {
                        height: 26
                        width: packTxt.implicitWidth + 14
                        radius: 0
                        color: "#386820"
                        border.color: "#7efc20"
                        border.width: 2

                        Text {
                            id: packTxt
                            anchors.centerIn: parent
                            text: "MC // HUD"
                            color: "#ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.weight: Font.Black
                        }
                    }

                    Repeater {
                        model: [1, 2, 3, 4]
                        delegate: Rectangle {
                            readonly property bool isCurrent: root.activeWorkspace === modelData
                            width: 28
                            height: 28
                            radius: 0
                            color: isCurrent ? "#5c5c5c" : "#2b2b2b"
                            border.color: isCurrent ? "#ffffff" : "#151515"
                            border.width: isCurrent ? 3 : 2

                            Text {
                                anchors.centerIn: parent
                                text: String(modelData)
                                color: isCurrent ? "#7efc20" : "#cccccc"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
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

                // Center: XP Bar + Clock Readout
                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatTime(clock.date, "HH:mm:ss") + "  [" + Qt.formatDate(clock.date, "dd MMM").toUpperCase() + "]"
                        color: "#7efc20"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.Black
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 190
                        height: 6
                        radius: 0
                        color: "#111111"
                        border.color: "#3a3a3a"
                        border.width: 1

                        Rectangle {
                            height: parent.height - 2
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 1
                            color: "#7efc20"
                            width: Math.max(4, (parent.width - 2) * (clock.seconds / 59.0))
                        }
                    }
                }

                // Right: Media + Stone Pause/Lock Button
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        visible: root.activePlayer !== null
                        height: 26
                        width: Math.min(200, mcMediaTxt.implicitWidth + 16)
                        radius: 0
                        color: "#2b2b2b"
                        border.color: "#6b6b6b"
                        border.width: 2
                        clip: true

                        Text {
                            id: mcMediaTxt
                            anchors.centerIn: parent
                            width: parent.width - 10
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            text: root.activePlayer ? ((root.activePlayer.isPlaying ? "♪ " : "⏸ ") + (root.activePlayer.trackTitle || "Jukebox")) : ""
                            color: "#f8f8f8"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        height: 28
                        width: 78
                        radius: 0
                        color: mcBootBtnMouse.containsMouse ? "#4d7c2b" : "#386820"
                        border.color: "#7efc20"
                        border.width: 2

                        Text {
                            anchors.centerIn: parent
                            text: "MC BOOT"
                            color: "#ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            font.weight: Font.Black
                        }

                        MouseArea {
                            id: mcBootBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.triggerBoot()
                        }
                    }

                    Rectangle {
                        height: 28
                        width: 72
                        radius: 0
                        color: mcLockMouse.containsMouse ? "#7c7c7c" : "#616161"
                        border.color: "#ffffff"
                        border.width: 2

                        Text {
                            anchors.centerIn: parent
                            text: "LOCK"
                            color: "#ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.weight: Font.Black
                        }

                        MouseArea {
                            id: mcLockMouse
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

    // Super+L Minecraft Dirt Pause/Lock Menu
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
            WlrLayershell.namespace: "minecraft-lock"

            Rectangle {
                anchors.fill: parent
                color: "#d91a120b"
                focus: root.locked
                Keys.onEscapePressed: root.locked = false
                Keys.onReturnPressed: root.locked = false

                Column {
                    anchors.centerIn: parent
                    spacing: 16

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Game Paused"
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        font.weight: Font.Black
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatTime(clock.date, "HH:mm")
                        color: "#7efc20"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 56
                        font.weight: Font.Black
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 220
                        height: 38
                        radius: 0
                        color: mcResumeMouse.containsMouse ? "#7c88b8" : "#6f6f6f"
                        border.color: "#ffffff"
                        border.width: 2

                        Text {
                            anchors.centerIn: parent
                            text: "Back to Game"
                            color: "#ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: mcResumeMouse
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

    // Interactive Minecraft Boot Overlay (Stage 1: MineGRUB Boot Menu, Stage 2: World Gen Chunk Grid)
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.bootStage > 0

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            focusable: root.bootStage > 0
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "minecraft-boot"

            Item {
                anchors.fill: parent
                focus: root.bootStage > 0

                Keys.onUpPressed: {
                    if (root.bootStage === 1) {
                        root.autoBootPaused = true;
                        root.bootEntryIndex = (root.bootEntryIndex + 2) % 3;
                    }
                }
                Keys.onDownPressed: {
                    if (root.bootStage === 1) {
                        root.autoBootPaused = true;
                        root.bootEntryIndex = (root.bootEntryIndex + 1) % 3;
                    }
                }
                Keys.onReturnPressed: {
                    if (root.bootStage === 1) {
                        if (root.bootEntryIndex === 2) root.bootStage = 0;
                        else root.startWorldGen();
                    } else if (root.bootStage === 2) {
                        root.bootStage = 0;
                    }
                }
                Keys.onEscapePressed: root.bootStage = 0

                // Classic Tiled Dirt Background Canvas
                Canvas {
                    id: dirtBgCanvas
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        var w = width, h = height;
                        if (w <= 0 || h <= 0) return;
                        var tile = 48;
                        var tones = ["#261911", "#2e1f15", "#21160f", "#342419"];
                        var cols = Math.ceil(w / tile);
                        var rows = Math.ceil(h / tile);
                        for (var r = 0; r < rows; r++) {
                            for (var c = 0; c < cols; c++) {
                                ctx.fillStyle = tones[(r * 7 + c * 13) % tones.length];
                                ctx.fillRect(c * tile, r * tile, tile, tile);
                            }
                        }
                        ctx.fillStyle = "rgba(0, 0, 0, 0.35)";
                        ctx.fillRect(0, 0, w, h);
                    }
                }

                // Stage 1: MineGRUB Boot Menu
                Column {
                    visible: root.bootStage === 1
                    anchors.centerIn: parent
                    width: Math.min(620, parent.width * 0.86)
                    spacing: 18

                    Column {
                        width: parent.width
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "MINEGRUB // FEDORA LINUX"
                            color: "#dcdcdc"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Math.max(26, Math.min(38, root.width * 0.025))
                            font.weight: Font.Black
                            font.letterSpacing: 3
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Now with Hyprland & Quickshell Chunks!"
                            color: "#ffff55"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                    }

                    // GRUB Menu Box
                    Rectangle {
                        width: parent.width
                        height: bootListCol.implicitHeight + 28
                        radius: 0
                        color: "#cc141414"
                        border.color: "#7c7c7c"
                        border.width: 3

                        Column {
                            id: bootListCol
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            Repeater {
                                model: [
                                    { title: "* Fedora Linux (Hyprland Overworld — Peaceful)", sub: "Kernel 6.x Wayland • Quickshell HUD" },
                                    { title: "  Fedora Linux (Advanced / Rescue Chunk)", sub: "Fallback chunk loader + terrain regeneration" },
                                    { title: "  Exit to Desktop HUD Immediately", sub: "Skip world generation overlay [Esc]" }
                                ]

                                delegate: Rectangle {
                                    readonly property bool selected: root.bootEntryIndex === index
                                    width: bootListCol.width
                                    height: 52
                                    radius: 0
                                    color: selected ? "#4a6c28" : (rowMouse.containsMouse ? "#2b2b2b" : "#1c1c1c")
                                    border.color: selected ? "#7efc20" : "#444444"
                                    border.width: selected ? 2 : 1

                                    Column {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        Text {
                                            text: modelData.title
                                            color: selected ? "#ffffff" : "#cccccc"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                        }

                                        Text {
                                            text: modelData.sub
                                            color: selected ? "#d6f5c6" : "#888888"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                        }
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: {
                                            root.autoBootPaused = true;
                                            root.bootEntryIndex = index;
                                        }
                                        onClicked: {
                                            root.bootEntryIndex = index;
                                            if (index === 2) root.bootStage = 0;
                                            else root.startWorldGen();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 14

                        Rectangle {
                            width: 240
                            height: 40
                            radius: 0
                            color: bootPlayMouse.containsMouse ? "#5c8c32" : "#467024"
                            border.color: "#ffffff"
                            border.width: 2

                            Text {
                                anchors.centerIn: parent
                                text: "Play Selected World"
                                color: "#ffffff"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.Black
                            }

                            MouseArea {
                                id: bootPlayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.startWorldGen()
                            }
                        }

                        Rectangle {
                            width: 140
                            height: 40
                            radius: 0
                            color: bootSkipMouse.containsMouse ? "#7c7c7c" : "#5a5a5a"
                            border.color: "#ffffff"
                            border.width: 2

                            Text {
                                anchors.centerIn: parent
                                text: "Skip [Esc]"
                                color: "#ffffff"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: bootSkipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.bootStage = 0
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.autoBootPaused
                            ? "Use Up/Down + Enter or click an option"
                            : "Booting highlighted entry automatically in " + root.autoBootSeconds + "s..."
                        color: "#aaaaaa"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                }

                // Stage 2: Building Terrain / Animated Chunk Grid + Progress Bar
                Column {
                    visible: root.bootStage === 2
                    anchors.centerIn: parent
                    spacing: 18

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.bootProgress < 35
                            ? "Building terrain..."
                            : (root.bootProgress < 80 ? "Generating world chunks..." : "Preparing spawn area...")
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        font.weight: Font.Black
                    }

                    // 16x16 Animated Voxel Spawn Chunk Grid
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 228
                        height: 228
                        radius: 0
                        color: "#111111"
                        border.color: "#6b6b6b"
                        border.width: 2

                        Canvas {
                            id: chunkCanvas
                            anchors.fill: parent
                            anchors.margins: 6
                            property int progress: root.bootProgress
                            onProgressChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                var w = width, h = height;
                                ctx.clearRect(0, 0, w, h);
                                var n = 16;
                                var cell = w / n;
                                var maxDist = 10.6;
                                var activeRadius = (progress / 100.0) * maxDist;
                                var palette = ["#5ca032", "#4e8b29", "#67b23a", "#3d72c4", "#b8aa75", "#7a7a7a", "#3e7022"];

                                for (var r = 0; r < n; r++) {
                                    for (var c = 0; c < n; c++) {
                                        var dx = c - 7.5;
                                        var dy = r - 7.5;
                                        var dist = Math.sqrt(dx * dx + dy * dy);
                                        var jitter = ((r * 31 + c * 17) % 10) * 0.12;
                                        if (dist + jitter <= activeRadius) {
                                            if (dist < 1.8) {
                                                ctx.fillStyle = "#ffffff";
                                            } else {
                                                var hash = (r * 19 + c * 29) % palette.length;
                                                ctx.fillStyle = palette[hash];
                                            }
                                            ctx.fillRect(c * cell, r * cell, Math.ceil(cell), Math.ceil(cell));
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Progress readout + green pixel bar
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.bootProgress + "%"
                            color: "#7efc20"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            font.weight: Font.Black
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 320
                            height: 14
                            radius: 0
                            color: "#1a1a1a"
                            border.color: "#7c7c7c"
                            border.width: 2

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                height: parent.height - 4
                                width: Math.max(0, (parent.width - 4) * (root.bootProgress / 100.0))
                                color: "#7efc20"
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "[Click or Esc to finish immediately]"
                            color: "#888888"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.bootStage = 0
                            }
                        }
                    }
                }
            }
        }
    }
}
