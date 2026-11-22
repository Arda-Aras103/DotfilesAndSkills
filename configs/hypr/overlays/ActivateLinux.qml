import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                right: true
                bottom: true
            }

            margins {
                right: 36
                bottom: 30
            }

            implicitWidth: Math.max(watermarkCol.implicitWidth + 16, 280)
            implicitHeight: watermarkCol.implicitHeight + 12
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            focusable: false
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "activate-linux"
            mask: Region {}

            Column {
                id: watermarkCol
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 2

                Text {
                    text: "Activate Linux"
                    color: "#c8d0dc"
                    opacity: 0.42
                    font.family: "sans-serif"
                    font.pixelSize: 24
                    font.weight: Font.Normal
                }

                Text {
                    text: "Go to Settings to activate Linux."
                    color: "#c8d0dc"
                    opacity: 0.36
                    font.family: "sans-serif"
                    font.pixelSize: 14
                    font.weight: Font.Normal
                }
            }
        }
    }
}
