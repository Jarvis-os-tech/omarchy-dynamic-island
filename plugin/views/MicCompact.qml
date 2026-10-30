import QtQuick

// Dynamic voice agent & microphone listening view:
// - Leading edge: glowing microphone glyph (or camera glyph)
// - Center: dynamic multi-color liquid acoustic waveform (Apple Intelligence / Siri style)
// - Trailing edge: pulsing acoustic aura indicator
Item {
    id: view

    property var island: null
    readonly property string voiceState: island && island.activeVoiceState ? island.activeVoiceState : "listening"
    readonly property bool isCamera: island && island.cameraActive
    readonly property color toneColor: isCamera ? island.greenColor : (island ? island.accentColor : "#38bdf8")

    // --- Leading Icon (Mic / Camera) -------------------------------------------
    Item {
        id: lead

        anchors.left: parent.left
        anchors.leftMargin: island ? island.s(12) : 12
        anchors.verticalCenter: parent.verticalCenter
        width: island ? island.s(18) : 18
        height: width

        // Subtle breathing ambient halo behind the mic glyph
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.35
            height: width
            radius: width / 2
            color: view.toneColor
            opacity: 0.15
            visible: !view.isCamera

            SequentialAnimation on opacity {
                running: view.visible && !view.isCamera
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.30
                    duration: 900
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0.10
                    duration: 900
                    easing.type: Easing.InOutSine
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: view.isCamera ? "󰄀" : "󰍬"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.fontFamily : "sans-serif"
            font.pixelSize: island ? island.f(15) : 15
            color: view.toneColor
        }
    }

    // --- Center: Dynamic Multi-Color Liquid Waveform --------------------------
    VoiceWaveform {
        id: waveform

        anchors.centerIn: parent
        island: view.island
        voiceState: view.voiceState
        active: true
        barCount: 7
        barWidth: island ? island.s(3.5) : 3.5
        maxHeight: island ? island.s(16) : 16
        minHeight: island ? island.s(3.5) : 3.5
    }

    // --- Trailing Edge: Acoustic Pulsing Glow Dot -----------------------------
    Item {
        id: trail

        anchors.right: parent.right
        anchors.rightMargin: island ? island.s(13) : 13
        anchors.verticalCenter: parent.verticalCenter
        width: island ? island.s(16) : 16
        height: width

        // Outer acoustic aura ring
        Rectangle {
            id: aura

            anchors.centerIn: parent
            width: parent.width
            height: width
            radius: width / 2
            color: "transparent"
            border.width: island ? island.s(1.5) : 1.5
            border.color: view.toneColor
            opacity: 0.6

            SequentialAnimation on scale {
                running: view.visible
                loops: Animation.Infinite
                NumberAnimation {
                    from: 0.6
                    to: 1.25
                    duration: 1100
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    from: 1.25
                    to: 0.6
                    duration: 1100
                    easing.type: Easing.InOutSine
                }
            }

            SequentialAnimation on opacity {
                running: view.visible
                loops: Animation.Infinite
                NumberAnimation {
                    from: 0.8
                    to: 0.15
                    duration: 1100
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    from: 0.15
                    to: 0.8
                    duration: 1100
                    easing.type: Easing.InOutSine
                }
            }
        }

        // Inner glowing core dot
        Rectangle {
            anchors.centerIn: parent
            width: island ? island.s(7) : 7
            height: width
            radius: width / 2
            color: view.toneColor

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.lighter(view.toneColor, 1.4)
                }
                GradientStop {
                    position: 1.0
                    color: view.toneColor
                }
            }
        }
    }
}
