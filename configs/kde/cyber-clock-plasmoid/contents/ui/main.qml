import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    property date now: new Date()
    property bool showSeconds: false

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    fullRepresentation: Item {
        implicitWidth: 680
        implicitHeight: 220

        readonly property string timeStr: Qt.formatTime(root.now, root.showSeconds ? "HH:mm:ss" : "HH:mm")
        readonly property string dateStr: Qt.formatDate(root.now, "dddd  //  dd MMM yyyy").toUpperCase()
        readonly property int clockPx: Math.max(76, Math.min(128, width * 0.19))

        // Soft ambient drop shadow behind clock & date
        Column {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 3
            anchors.verticalCenterOffset: 5
            spacing: 8
            opacity: 0.68

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: timeStr
                color: "#1a0504"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: clockPx
                font.weight: Font.Black
                font.letterSpacing: 5
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(360, parent.parent.width * 0.58)
                height: 2
                color: "#1a0504"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dateStr
                color: "#1a0504"
                opacity: 0.55
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                font.weight: Font.Bold
                font.letterSpacing: 3
            }
        }

        // Crisp foreground typography (Makima crimson / amber-gold / warm ivory)
        Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: timeStr
                color: "#fff3e0"
                style: Text.Outline
                styleColor: "#b31a0504"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: clockPx
                font.weight: Font.Black
                font.letterSpacing: 5
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(360, parent.parent.width * 0.58)
                height: 2
                color: "#f59e0b"
                opacity: 0.92
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dateStr
                color: "#ffd6c2"
                style: Text.Outline
                styleColor: "#cc1a0504"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                font.weight: Font.Bold
                font.letterSpacing: 3
                opacity: 0.96
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showSeconds = !root.showSeconds
        }
    }
}
