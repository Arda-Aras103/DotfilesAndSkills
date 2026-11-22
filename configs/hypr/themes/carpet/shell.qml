import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    property bool locked: false
    property int activeWorkspace: 1
    property int monthOffset: 0
    property string calendarTab: "Days"

    readonly property var activePlayer: (Mpris.players && Mpris.players.values && Mpris.players.values.length > 0)
        ? Mpris.players.values[0] : null

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Timer {
        running: root.activePlayer !== null && root.activePlayer.isPlaying
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.activePlayer) root.activePlayer.positionChanged();
        }
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

    function formatDuration(sec) {
        var total = Math.max(0, Math.floor(sec || 0));
        var m = Math.floor(total / 60);
        var s = total % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function buildCalendarCells(nowDate, offsetMonths) {
        var target = new Date(nowDate.getFullYear(), nowDate.getMonth() + offsetMonths, 1);
        var year = target.getFullYear();
        var month = target.getMonth();
        // Monday=0 .. Sunday=6
        var firstWeekday = (target.getDay() + 6) % 7;
        var daysInMonth = new Date(year, month + 1, 0).getDate();
        var daysInPrev = new Date(year, month, 0).getDate();
        var todayY = nowDate.getFullYear();
        var todayM = nowDate.getMonth();
        var todayD = nowDate.getDate();

        var cells = [];
        for (var i = 0; i < 42; i++) {
            var dayNum = i - firstWeekday + 1;
            var inMonth = true;
            var isToday = false;
            if (dayNum <= 0) {
                dayNum = daysInPrev + dayNum;
                inMonth = false;
            } else if (dayNum > daysInMonth) {
                dayNum = dayNum - daysInMonth;
                inMonth = false;
            } else {
                isToday = (year === todayY && month === todayM && dayNum === todayD);
            }
            cells.push({ day: dayNum, inMonth: inMonth, isToday: isToday });
        }
        return {
            monthName: Qt.formatDate(target, "MMMM yyyy"),
            cells: cells
        };
    }

    // Ornamental Carpet Wallpaper Layer
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
            WlrLayershell.namespace: "carpet-wallpaper"

            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("carpet.svg")
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                smooth: true
            }
        }
    }

    // Top-center compact date/time status strip + analog clock + left media widget + right calendar
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
            WlrLayershell.namespace: "carpet-desktop-widgets"

            // Click-through everywhere except actual interactive widget cards
            mask: Region {
                Region { item: topBarCard }
                Region { item: mediaWidget }
                Region { item: calendarWidget }
                Region { item: dockBar }
            }

            // 1. Top-center thin bronze & emerald status pill
            Rectangle {
                id: topBarCard
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 4
                width: 310
                height: 34
                radius: 4
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#a34a0c" }
                    GradientStop { position: 1.0; color: "#682908" }
                }
                border.color: "#1a6e2b"
                border.width: 2

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatTime(clock.date, "HH:mm:ss")
                        color: "#fff5d6"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDate(clock.date, "dddd, dd MMMM yyyy")
                        color: "#f2d699"
                        font.family: "serif"
                        font.pixelSize: 10
                    }
                }
            }

            // 2. Top-center Analog Clock (cerulean bezel + mint/ivory face)
            Item {
                id: analogClock
                anchors.top: topBarCard.bottom
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                width: 152
                height: 152

                Canvas {
                    id: clockFace
                    anchors.fill: parent
                    property int sec: clock.seconds
                    property int min: clock.minutes
                    property int hr: clock.hours
                    onSecChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        var w = width;
                        var h = height;
                        var cx = w / 2;
                        var cy = h / 2;
                        var r = Math.min(w, h) / 2 - 4;
                        ctx.reset();

                        // Outer blue bezel
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, Math.PI * 2);
                        ctx.fillStyle = "#3f8fe8";
                        ctx.fill();
                        ctx.lineWidth = 2.5;
                        ctx.strokeStyle = "#162738";
                        ctx.stroke();

                        // Inner pale mint/ivory dial
                        ctx.beginPath();
                        ctx.arc(cx, cy, r - 9, 0, Math.PI * 2);
                        ctx.fillStyle = "#d5e4da";
                        ctx.fill();
                        ctx.lineWidth = 1.5;
                        ctx.strokeStyle = "#22466e";
                        ctx.stroke();

                        // 12 hour tick marks
                        for (var i = 0; i < 12; i++) {
                            var ang = (i * Math.PI) / 6 - Math.PI / 2;
                            var r1 = r - 14;
                            var r2 = r - 21;
                            ctx.beginPath();
                            ctx.moveTo(cx + Math.cos(ang) * r1, cy + Math.sin(ang) * r1);
                            ctx.lineTo(cx + Math.cos(ang) * r2, cy + Math.sin(ang) * r2);
                            ctx.lineWidth = (i % 3 === 0) ? 2.4 : 1.4;
                            ctx.strokeStyle = "#1e1f22";
                            ctx.stroke();
                        }

                        // Hour hand
                        var hAng = (((hr % 12) + min / 60.0) * Math.PI) / 6 - Math.PI / 2;
                        ctx.beginPath();
                        ctx.moveTo(cx, cy);
                        ctx.lineTo(cx + Math.cos(hAng) * (r * 0.44), cy + Math.sin(hAng) * (r * 0.44));
                        ctx.lineWidth = 4.2;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = "#1b1c1f";
                        ctx.stroke();

                        // Minute hand
                        var mAng = ((min + sec / 60.0) * Math.PI) / 30 - Math.PI / 2;
                        ctx.beginPath();
                        ctx.moveTo(cx, cy);
                        ctx.lineTo(cx + Math.cos(mAng) * (r * 0.64), cy + Math.sin(mAng) * (r * 0.64));
                        ctx.lineWidth = 2.8;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = "#1b1c1f";
                        ctx.stroke();

                        // Second hand
                        var sAng = (sec * Math.PI) / 30 - Math.PI / 2;
                        ctx.beginPath();
                        ctx.moveTo(cx - Math.cos(sAng) * 10, cy - Math.sin(sAng) * 10);
                        ctx.lineTo(cx + Math.cos(sAng) * (r * 0.70), cy + Math.sin(sAng) * (r * 0.70));
                        ctx.lineWidth = 1.4;
                        ctx.strokeStyle = "#8e1616";
                        ctx.stroke();

                        // Center pin
                        ctx.beginPath();
                        ctx.arc(cx, cy, 3.8, 0, Math.PI * 2);
                        ctx.fillStyle = "#1b1c1f";
                        ctx.fill();
                    }
                }
            }

            // 3. Top-left Mahogany & Gold Media Player Widget
            Rectangle {
                id: mediaWidget
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: 18
                anchors.leftMargin: 18
                width: 248
                height: 238
                radius: 4
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#e64a1c08" }
                    GradientStop { position: 0.65; color: "#e66e2c0e" }
                    GradientStop { position: 1.0; color: "#e63b1405" }
                }
                border.color: "#c98e2c"
                border.width: 2

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Row {
                        width: parent.width
                        spacing: 10

                        Rectangle {
                            width: 70
                            height: 70
                            radius: 4
                            color: "#240d04"
                            border.color: "#c98e2c"
                            border.width: 1.5
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                visible: root.activePlayer !== null && root.activePlayer.trackArtUrl.length > 0
                                source: root.activePlayer ? root.activePlayer.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !(root.activePlayer !== null && root.activePlayer.trackArtUrl.length > 0)
                                text: "♫"
                                color: "#e0a83a"
                                font.pixelSize: 28
                            }
                        }

                        Column {
                            width: parent.width - 80
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown Track") : "No Media Active"
                                color: "#fff5dc"
                                font.family: "serif"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: root.activePlayer ? (root.activePlayer.trackArtist || "MPRIS Ready") : "Start a player"
                                color: "#e5c58e"
                                font.family: "serif"
                                font.pixelSize: 11
                            }

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: root.activePlayer ? (root.activePlayer.identity || "MPRIS2") : "carpet-audio"
                                color: "#c98e2c"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                            }
                        }
                    }

                    // Progress bar & timecodes
                    Column {
                        width: parent.width
                        spacing: 4

                        Rectangle {
                            width: parent.width
                            height: 8
                            radius: 4
                            color: "#1e0902"
                            border.color: "#9c4e0f"
                            border.width: 1

                            Rectangle {
                                height: parent.height - 2
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 1
                                radius: 3
                                color: "#2bb866"
                                width: {
                                    if (!root.activePlayer || root.activePlayer.length <= 0) return 0;
                                    var ratio = Math.max(0, Math.min(1, root.activePlayer.position / root.activePlayer.length));
                                    return Math.max(4, (parent.width - 2) * ratio);
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 14

                            Text {
                                anchors.left: parent.left
                                text: root.activePlayer ? root.formatDuration(root.activePlayer.position) : "00:00"
                                color: "#e5c58e"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                            }

                            Text {
                                anchors.right: parent.right
                                text: root.activePlayer ? root.formatDuration(root.activePlayer.length) : "00:00"
                                color: "#e5c58e"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                            }
                        }
                    }

                    // Transport buttons
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        Repeater {
                            model: [
                                { sym: "⏮", act: "prev" },
                                { sym: root.activePlayer && root.activePlayer.isPlaying ? "⏸" : "▶", act: "play" },
                                { sym: "⏭", act: "next" }
                            ]
                            delegate: Rectangle {
                                width: 48
                                height: 36
                                radius: 4
                                color: mediaBtnMouse.containsMouse ? "#9c4e0f" : "#5c250c"
                                border.color: "#c98e2c"
                                border.width: 1.5

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.sym
                                    color: "#fff5dc"
                                    font.pixelSize: 16
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    id: mediaBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!root.activePlayer) return;
                                        if (modelData.act === "prev" && root.activePlayer.canGoPrevious) root.activePlayer.previous();
                                        else if (modelData.act === "play" && root.activePlayer.canTogglePlaying) root.activePlayer.togglePlaying();
                                        else if (modelData.act === "next" && root.activePlayer.canGoNext) root.activePlayer.next();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 4. Top-right Monthly Calendar Grid Widget
            Rectangle {
                id: calendarWidget
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 18
                anchors.rightMargin: 18
                width: 286
                height: 236
                radius: 4
                color: "#e64a1b08"
                border.color: "#c98e2c"
                border.width: 2

                readonly property var calData: root.buildCalendarCells(clock.date, root.monthOffset)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Header: Month + Prev / Today / Next
                    Item {
                        width: parent.width
                        height: 24

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: calendarWidget.calData.monthName
                            color: "#fff5dc"
                            font.family: "serif"
                            font.pixelSize: 15
                            font.weight: Font.Bold
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                text: "◀"
                                color: "#22c55e"
                                font.pixelSize: 13
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.monthOffset -= 1
                                }
                            }

                            Text {
                                text: "Today"
                                color: "#f2e5c6"
                                font.family: "serif"
                                font.pixelSize: 12
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.monthOffset = 0
                                }
                            }

                            Text {
                                text: "▶"
                                color: "#22c55e"
                                font.pixelSize: 13
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.monthOffset += 1
                                }
                            }
                        }
                    }

                    // Tabs: Days | Months | Years
                    Row {
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: ["Days", "Months", "Years"]
                            delegate: Rectangle {
                                width: (parent.width - 12) / 3
                                height: 22
                                radius: 4
                                color: root.calendarTab === modelData ? "#240d04" : "transparent"
                                border.color: root.calendarTab === modelData ? "#1db982" : "#7c3f16"
                                border.width: 1.5

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: "#fff5dc"
                                    font.family: "serif"
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.calendarTab = modelData
                                }
                            }
                        }
                    }

                    // Weekday header
                    Row {
                        width: parent.width
                        Repeater {
                            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                            delegate: Text {
                                width: parent.width / 7
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: "#b78d63"
                                font.family: "serif"
                                font.pixelSize: 10
                            }
                        }
                    }

                    // 6x7 day grid
                    Grid {
                        width: parent.width
                        columns: 7
                        rowSpacing: 3

                        Repeater {
                            model: calendarWidget.calData.cells
                            delegate: Rectangle {
                                width: parent.width / 7
                                height: 20
                                radius: 3
                                color: modelData.isToday ? "#143d2c" : "transparent"
                                border.color: modelData.isToday ? "#1db982" : "transparent"
                                border.width: modelData.isToday ? 1.5 : 0

                                Text {
                                    anchors.centerIn: parent
                                    text: String(modelData.day)
                                    color: modelData.isToday ? "#ffffff" : (modelData.inMonth ? "#fff2d1" : "#8b6645")
                                    font.family: "serif"
                                    font.pixelSize: 11
                                    font.weight: modelData.isToday ? Font.Bold : Font.Normal
                                }
                            }
                        }
                    }
                }
            }

            // 5. Bottom-center compact workspace & app dock
            Rectangle {
                id: dockBar
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                height: 38
                width: dockRow.implicitWidth + 24
                radius: 5
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#a34a0c" }
                    GradientStop { position: 1.0; color: "#5e2206" }
                }
                border.color: "#1a6e2b"
                border.width: 2

                Row {
                    id: dockRow
                    anchors.centerIn: parent
                    spacing: 8

                    Repeater {
                        model: [1, 2, 3, 4]
                        delegate: Rectangle {
                            readonly property bool isCurrent: root.activeWorkspace === modelData
                            width: 26
                            height: 24
                            radius: 3
                            color: isCurrent ? "#165e3a" : "#3a1506"
                            border.color: isCurrent ? "#22c55e" : "#c98e2c"
                            border.width: 1.5

                            Text {
                                anchors.centerIn: parent
                                text: String(modelData)
                                color: "#fff5dc"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchWorkspace(modelData)
                            }
                        }
                    }

                    Rectangle { width: 1; height: 22; color: "#c98e2c" }

                    Rectangle {
                        height: 24
                        width: lockLabel.implicitWidth + 14
                        radius: 3
                        color: "#3a1506"
                        border.color: "#c98e2c"
                        border.width: 1.5

                        Text {
                            id: lockLabel
                            anchors.centerIn: parent
                            text: "LOCK"
                            color: "#fff5dc"
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
            WlrLayershell.namespace: "carpet-lock"

            Rectangle {
                anchors.fill: parent
                color: "#cc1b0b04"
                focus: root.locked
                Keys.onEscapePressed: root.locked = false
                Keys.onReturnPressed: root.locked = false

                Rectangle {
                    anchors.centerIn: parent
                    width: 340
                    height: 220
                    radius: 8
                    color: "#4a1b08"
                    border.color: "#c98e2c"
                    border.width: 3

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatTime(clock.date, "HH:mm")
                            color: "#fff5dc"
                            font.family: "serif"
                            font.pixelSize: 54
                            font.weight: Font.Bold
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDate(clock.date, "dddd, dd MMMM yyyy")
                            color: "#e5c58e"
                            font.family: "serif"
                            font.pixelSize: 13
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 140
                            height: 32
                            radius: 4
                            color: "#165e3a"
                            border.color: "#22c55e"
                            border.width: 1.5

                            Text {
                                anchors.centerIn: parent
                                text: "UNLOCK"
                                color: "#fff5dc"
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
