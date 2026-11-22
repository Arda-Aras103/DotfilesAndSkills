import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080

    function cfgStr(key, fallback) {
        if (typeof config !== "undefined" && config !== null && config[key] !== undefined && String(config[key]).length > 0) {
            return String(config[key]);
        }
        return fallback;
    }

    function cfgBool(key, fallback) {
        if (typeof config !== "undefined" && config !== null && config[key] !== undefined) {
            var v = String(config[key]).toLowerCase();
            if (v === "true" || v === "1" || v === "yes") return true;
            if (v === "false" || v === "0" || v === "no") return false;
        }
        return fallback;
    }

    function resolveFrameImage() {
        var raw = cfgStr("CustomImage", "login-photo.jpg");
        if (raw.indexOf("://") !== -1) {
            return raw;
        }
        if (raw.charAt(0) === "/") {
            return "file://" + raw;
        }
        return Qt.resolvedUrl(raw);
    }

    function resolveImageHAlign() {
        var align = cfgStr("ImageAlign", "right").toLowerCase();
        if (align === "right") return Image.AlignRight;
        if (align === "left") return Image.AlignLeft;
        return Image.AlignHCenter;
    }

    readonly property color bgColor: cfgStr("BackgroundColor", "#f5eccd")
    readonly property color fgColor: cfgStr("ForegroundColor", "#282726")
    readonly property color pillColor: cfgStr("PillColor", "#cfc7ab")
    readonly property color shadeColor: cfgStr("AccentShade", "#eadbb6")
    readonly property color wireColor: cfgStr("WireframeColor", "#282726")
    readonly property color errColor: cfgStr("ErrorColor", "#8c2f27")
    readonly property string uiFont: cfgStr("FontFamily", "JetBrainsMono Nerd Font")
    readonly property bool use24Hour: cfgBool("Clock24Hour", true)
    readonly property bool showDayHeader: cfgBool("ShowDayHeader", true)

    color: bgColor

    property date currentTime: new Date()
    property int userIndex: 0
    property int sessionIndex: 0
    property bool showPassword: false
    property bool virtualKeyboardOn: false
    property bool loggingIn: false
    property string statusMessage: ""
    property bool statusIsError: false

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    // Hidden model indexers avoid hardcoded QAbstractItemModel role numbers across Qt5/Qt6 SDDM.
    Item {
        visible: false
        Repeater {
            id: userBridge
            model: typeof userModel !== "undefined" ? userModel : null
            delegate: Item {
                property string uName: name || ""
                property string uReal: realName || ""
            }
        }
        Repeater {
            id: sessionBridge
            model: typeof sessionModel !== "undefined" ? sessionModel : null
            delegate: Item {
                property string sName: name || "Default"
                property string sFile: file || ""
            }
        }
    }

    function currentSessionName() {
        if (sessionBridge.count > 0) {
            var idx = Math.max(0, Math.min(sessionIndex, sessionBridge.count - 1));
            var item = sessionBridge.itemAt(idx);
            if (item && item.sName) {
                return item.sName;
            }
        }
        return "Session";
    }

    function cycleUser() {
        if (userBridge.count > 0) {
            userIndex = (userIndex + 1) % userBridge.count;
            var item = userBridge.itemAt(userIndex);
            if (item && item.uName) {
                usernameInput.text = item.uName;
            }
        }
    }

    function cycleSession() {
        if (sessionBridge.count > 0) {
            sessionIndex = (sessionIndex + 1) % sessionBridge.count;
        }
    }

    function attemptLogin() {
        var user = usernameInput.text.trim();
        if (user.length === 0) {
            statusIsError = true;
            statusMessage = "ENTER USERNAME";
            usernameInput.forceActiveFocus();
            return;
        }
        loggingIn = true;
        statusIsError = false;
        statusMessage = "AUTHENTICATING...";
        if (typeof sddm !== "undefined" && sddm !== null) {
            sddm.login(user, passwordInput.text, sessionIndex);
        }
    }

    Component.onCompleted: {
        if (typeof userModel !== "undefined" && userModel !== null) {
            if (userModel.lastIndex >= 0 && userModel.lastIndex < userBridge.count) {
                userIndex = userModel.lastIndex;
            }
            if (userModel.lastUser && String(userModel.lastUser).length > 0) {
                usernameInput.text = String(userModel.lastUser);
            } else if (userBridge.count > 0 && userBridge.itemAt(userIndex)) {
                usernameInput.text = userBridge.itemAt(userIndex).uName;
            }
        }
        if (typeof sessionModel !== "undefined" && sessionModel !== null) {
            if (sessionModel.lastIndex >= 0 && sessionModel.lastIndex < sessionBridge.count) {
                sessionIndex = sessionModel.lastIndex;
            }
        }
        if (usernameInput.text.length > 0) {
            passwordInput.forceActiveFocus();
        } else {
            usernameInput.forceActiveFocus();
        }
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            root.loggingIn = false;
            root.statusIsError = true;
            root.statusMessage = "AUTHENTICATION FAILED";
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }
        function onLoginSucceeded() {
            root.loggingIn = false;
            root.statusIsError = false;
            root.statusMessage = "ACCESS GRANTED";
        }
    }

    // Subtle paper grain / corner telemetry strip
    Text {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 28
        text: cfgStr("FrameTitle", "SYSTEM // ACCESS")
        font.family: root.uiFont
        font.pixelSize: 11
        font.letterSpacing: 2.5
        color: root.fgColor
        opacity: 0.45
    }

    // Left column: cyber clock, day header, pills, power actions, session & virtual keyboard
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

            // Large stylized cyber clock
            Text {
                id: clockText
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(root.currentTime, root.use24Hour ? "HH:mm" : "hh:mm")
                font.family: root.uiFont
                font.pixelSize: Math.max(64, Math.min(104, root.width * 0.056))
                font.weight: Font.Black
                font.letterSpacing: 4
                color: root.fgColor
            }

            // Stylized day header
            Text {
                visible: root.showDayHeader
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(root.currentTime, "dddd  //  dd MMM").toUpperCase()
                font.family: root.uiFont
                font.pixelSize: 18
                font.weight: Font.Bold
                font.letterSpacing: 3
                color: root.fgColor
                opacity: 0.88
            }

            Item { width: 1; height: 42 }

            // Username pill
            Rectangle {
                id: userPill
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(310, parent.width)
                height: 42
                radius: 21
                color: root.pillColor
                border.width: usernameInput.activeFocus ? 1.8 : 1.0
                border.color: usernameInput.activeFocus ? root.fgColor : root.wireColor

                Canvas {
                    id: userIcon
                    width: 18
                    height: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 15
                    anchors.verticalCenter: parent.verticalCenter
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.fillStyle = root.fgColor;
                        ctx.beginPath();
                        ctx.arc(9, 6, 3.3, 0, Math.PI * 2);
                        ctx.fill();
                        ctx.beginPath();
                        ctx.moveTo(3, 15.5);
                        ctx.quadraticCurveTo(9, 10.5, 15, 15.5);
                        ctx.closePath();
                        ctx.fill();
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cycleUser()
                    }
                }

                TextInput {
                    id: usernameInput
                    anchors.left: userIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    color: root.fgColor
                    selectionColor: root.fgColor
                    selectedTextColor: root.bgColor
                    font.family: root.uiFont
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                    clip: true
                    KeyNavigation.tab: passwordInput
                    Keys.onReturnPressed: passwordInput.forceActiveFocus()
                    Keys.onEnterPressed: passwordInput.forceActiveFocus()

                    Text {
                        anchors.centerIn: parent
                        text: "USERNAME"
                        color: root.fgColor
                        opacity: 0.42
                        font.family: root.uiFont
                        font.pixelSize: 12
                        font.letterSpacing: 1.5
                        visible: usernameInput.text.length === 0 && !usernameInput.activeFocus
                    }
                }
            }

            Item { width: 1; height: 12 }

            // Password pill
            Rectangle {
                id: passPill
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(310, parent.width)
                height: 42
                radius: 21
                color: root.pillColor
                border.width: passwordInput.activeFocus ? 1.8 : 1.0
                border.color: passwordInput.activeFocus ? root.fgColor : root.wireColor

                Canvas {
                    id: eyeIcon
                    width: 18
                    height: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 15
                    anchors.verticalCenter: parent.verticalCenter
                    property bool revealed: root.showPassword
                    onRevealedChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = root.fgColor;
                        ctx.fillStyle = root.fgColor;
                        ctx.lineWidth = 1.6;
                        ctx.beginPath();
                        ctx.moveTo(2, 9);
                        ctx.quadraticCurveTo(9, 3.5, 16, 9);
                        ctx.quadraticCurveTo(9, 14.5, 2, 9);
                        ctx.stroke();
                        ctx.beginPath();
                        ctx.arc(9, 9, 2.3, 0, Math.PI * 2);
                        ctx.fill();
                        if (!revealed) {
                            ctx.beginPath();
                            ctx.moveTo(3, 14.5);
                            ctx.lineTo(15, 3.5);
                            ctx.stroke();
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showPassword = !root.showPassword
                    }
                }

                TextInput {
                    id: passwordInput
                    anchors.left: eyeIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    color: root.fgColor
                    selectionColor: root.fgColor
                    selectedTextColor: root.bgColor
                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    font.family: root.uiFont
                    font.pixelSize: 13
                    font.letterSpacing: root.showPassword ? 1 : 2.5
                    clip: true
                    KeyNavigation.backtab: usernameInput
                    Keys.onReturnPressed: root.attemptLogin()
                    Keys.onEnterPressed: root.attemptLogin()

                    Text {
                        anchors.centerIn: parent
                        text: "PASSWORD"
                        color: root.fgColor
                        opacity: 0.42
                        font.family: root.uiFont
                        font.pixelSize: 12
                        font.letterSpacing: 1.5
                        visible: passwordInput.text.length === 0 && !passwordInput.activeFocus
                    }
                }
            }

            Item { width: 1; height: 14 }

            // Dark LOGIN button
            Rectangle {
                id: loginBtn
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(310, parent.width)
                height: 42
                radius: 21
                color: root.fgColor
                opacity: root.loggingIn ? 0.65 : (loginMouse.pressed ? 0.78 : (loginMouse.containsMouse ? 0.88 : 1.0))

                Text {
                    anchors.centerIn: parent
                    text: root.loggingIn ? "LOGGING IN..." : "LOGIN"
                    color: root.bgColor
                    font.family: root.uiFont
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 2.5
                }

                MouseArea {
                    id: loginMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.loggingIn
                    onClicked: root.attemptLogin()
                }
            }

            // Status / CapsLock message
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 24
                verticalAlignment: Text.AlignVCenter
                text: {
                    if (root.statusMessage.length > 0) return root.statusMessage;
                    if (typeof keyboard !== "undefined" && keyboard !== null && keyboard.capsLock) return "CAPS LOCK ACTIVE";
                    return "";
                }
                color: root.statusIsError ? root.errColor : root.fgColor
                font.family: root.uiFont
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1.5
            }

            Item { width: 1; height: 18 }

            // 4 circular power action buttons
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 22

                Repeater {
                    model: [
                        { label: "SHUTDOWN", kind: "power" },
                        { label: "REBOOT", kind: "reboot" },
                        { label: "SUSPEND", kind: "suspend" },
                        { label: "HIBERNATE", kind: "hibernate" }
                    ]

                    delegate: Column {
                        spacing: 6
                        width: 58

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 38
                            height: 38
                            radius: 19
                            color: actionMouse.containsMouse ? root.shadeColor : "transparent"
                            border.color: root.fgColor
                            border.width: 1.5

                            Canvas {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                property string iconKind: modelData.kind
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.strokeStyle = root.fgColor;
                                    ctx.fillStyle = root.fgColor;
                                    ctx.lineWidth = 1.6;
                                    ctx.lineCap = "round";
                                    if (iconKind === "power") {
                                        ctx.beginPath();
                                        ctx.arc(10, 10.5, 6, -Math.PI * 0.25, Math.PI * 1.25);
                                        ctx.stroke();
                                        ctx.beginPath();
                                        ctx.moveTo(10, 3);
                                        ctx.lineTo(10, 9.5);
                                        ctx.stroke();
                                    } else if (iconKind === "reboot") {
                                        ctx.beginPath();
                                        ctx.arc(10, 10, 6, 0.4, Math.PI * 1.85);
                                        ctx.stroke();
                                        ctx.beginPath();
                                        ctx.moveTo(15.2, 5.2);
                                        ctx.lineTo(16.2, 8.8);
                                        ctx.lineTo(12.6, 8.2);
                                        ctx.stroke();
                                    } else if (iconKind === "suspend") {
                                        ctx.beginPath();
                                        ctx.arc(10, 10, 6.5, 0, Math.PI * 2);
                                        ctx.stroke();
                                        ctx.beginPath();
                                        ctx.moveTo(8, 7);
                                        ctx.lineTo(8, 13);
                                        ctx.moveTo(12, 7);
                                        ctx.lineTo(12, 13);
                                        ctx.stroke();
                                    } else {
                                        ctx.beginPath();
                                        ctx.arc(10, 10, 6.5, 0, Math.PI * 2);
                                        ctx.stroke();
                                        ctx.beginPath();
                                        ctx.arc(10, 10, 2.4, 0, Math.PI * 2);
                                        ctx.fill();
                                    }
                                }
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof sddm === "undefined" || sddm === null) return;
                                    if (modelData.kind === "power") sddm.powerOff();
                                    else if (modelData.kind === "reboot") sddm.reboot();
                                    else if (modelData.kind === "suspend") sddm.suspend();
                                    else if (modelData.kind === "hibernate") sddm.hibernate();
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: root.fgColor
                            font.family: root.uiFont
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                        }
                    }
                }
            }

            Item { width: 1; height: 22 }

            // Session cycle button
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: sessionLabel.implicitWidth + 24
                height: 24
                radius: 12
                color: sessionMouse.containsMouse ? root.shadeColor : "transparent"

                Text {
                    id: sessionLabel
                    anchors.centerIn: parent
                    text: "SESSION (" + root.currentSessionName().toUpperCase() + ")"
                    color: root.fgColor
                    font.family: root.uiFont
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1.3
                }

                MouseArea {
                    id: sessionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cycleSession()
                }
            }

            Item { width: 1; height: 4 }

            // Virtual keyboard toggle (hidden by default unless ShowVirtualKeyboard=true)
            Rectangle {
                visible: root.cfgBool("ShowVirtualKeyboard", false)
                anchors.horizontalCenter: parent.horizontalCenter
                width: vkbdLabel.implicitWidth + 24
                height: 24
                radius: 12
                color: vkbdMouse.containsMouse ? root.shadeColor : "transparent"

                Text {
                    id: vkbdLabel
                    anchors.centerIn: parent
                    text: "VIRTUAL KEYBOARD (" + (root.virtualKeyboardOn ? "ON" : "OFF") + ")"
                    color: root.fgColor
                    font.family: root.uiFont
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1.3
                }

                MouseArea {
                    id: vkbdMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.virtualKeyboardOn = !root.virtualKeyboardOn
                }
            }
        }
    }

    // Right column: Editorial Portrait Showcase (clean corner brackets + layered accent shadow)
    Item {
        id: rightCol
        width: Math.min(parent.width * 0.46, 660)
        height: Math.min(parent.height * 0.78, 640)
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: parent.width * 0.05

        // Offset layered shadow / accent card behind the portrait
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
                source: root.resolveFrameImage()
                fillMode: Image.PreserveAspectCrop
                horizontalAlignment: root.resolveImageHAlign()
                asynchronous: true
                smooth: true
            }

            // Minimal bottom editorial caption strip
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
                    text: Qt.formatTime(root.currentTime, "HH:mm:ss")
                    color: root.wireColor
                    font.family: root.uiFont
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }
            }

            // Minimalist viewfinder L-brackets + subtle partial orbital ring arc (no grids)
            Canvas {
                anchors.fill: parent
                z: 4
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    var w = width;
                    var h = height;
                    if (w <= 0 || h <= 0) return;
                    ctx.reset();

                    ctx.strokeStyle = root.wireColor;
                    ctx.lineWidth = 1.8;
                    ctx.globalAlpha = 0.85;
                    var m = 10;
                    var b = 24;

                    // Four clean L-corner brackets
                    ctx.beginPath();
                    ctx.moveTo(m, m + b); ctx.lineTo(m, m); ctx.lineTo(m + b, m);
                    ctx.moveTo(w - m - b, m); ctx.lineTo(w - m, m); ctx.lineTo(w - m, m + b);
                    ctx.moveTo(m, h - m - b); ctx.lineTo(m, h - m); ctx.lineTo(m + b, h - m);
                    ctx.moveTo(w - m - b, h - m); ctx.lineTo(w - m, h - m); ctx.lineTo(w - m, h - m - b);
                    ctx.stroke();

                    // Subtle partial orbital arc around upper-right quadrant
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

    // Built-in compact on-screen keyboard overlay (zero external QtQuick.VirtualKeyboard dependency)
    Rectangle {
        id: vkbdOverlay
        visible: root.virtualKeyboardOn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: Math.min(parent.width * 0.72, 720)
        height: 164
        radius: 14
        color: root.bgColor
        border.color: root.fgColor
        border.width: 2
        z: 50

        property bool shifted: false

        function targetInput() {
            return usernameInput.activeFocus ? usernameInput : passwordInput;
        }

        function pressKey(label) {
            var target = targetInput();
            if (label === "BS") {
                target.text = target.text.slice(0, -1);
            } else if (label === "CLR") {
                target.text = "";
            } else if (label === "SHIFT") {
                shifted = !shifted;
            } else if (label === "SPACE") {
                target.text += " ";
            } else if (label === "ENTER") {
                root.attemptLogin();
            } else {
                target.text += (shifted ? label.toUpperCase() : label.toLowerCase());
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: [
                    ["1","2","3","4","5","6","7","8","9","0","BS"],
                    ["q","w","e","r","t","y","u","i","o","p","CLR"],
                    ["a","s","d","f","g","h","j","k","l","-","_"],
                    ["SHIFT","z","x","c","v","b","n","m","SPACE","ENTER"]
                ]

                delegate: Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 5
                    Repeater {
                        model: modelData
                        delegate: Rectangle {
                            property string kLabel: modelData
                            width: (kLabel === "SPACE" || kLabel === "ENTER" || kLabel === "SHIFT") ? 72 : (kLabel === "CLR" || kLabel === "BS" ? 48 : 38)
                            height: 30
                            radius: 6
                            color: kMouse.pressed ? root.fgColor : ((kLabel === "SHIFT" && vkbdOverlay.shifted) ? root.shadeColor : root.pillColor)
                            border.color: root.fgColor
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: (vkbdOverlay.shifted && kLabel.length === 1) ? kLabel.toUpperCase() : kLabel
                                color: kMouse.pressed ? root.bgColor : root.fgColor
                                font.family: root.uiFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: kMouse
                                anchors.fill: parent
                                onClicked: vkbdOverlay.pressKey(kLabel)
                            }
                        }
                    }
                }
            }
        }
    }
}
