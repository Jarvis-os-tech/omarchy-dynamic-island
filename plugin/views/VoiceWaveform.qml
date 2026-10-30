import QtQuick

// Dynamic multi-color liquid acoustic waveform for voice agents and
// microphone listening states, inspired by Apple Intelligence / Siri.
// Smooth rounded capsule bars oscillate with phase-shifted spring curves.
Row {
    id: wave

    property var island: null
    property string voiceState: "listening" // listening | thinking | speaking | idle
    property bool active: true
    property int barCount: 7
    property real barWidth: island ? island.s(3.5) : 3.5
    property real maxHeight: island ? island.s(16) : 16
    property real minHeight: island ? island.s(3.5) : 3.5
    property color overrideColor: "transparent"

    readonly property var siriPalette: ["#38bdf8" // 0: electric sky
        , "#60a5fa" // 1: vibrant blue
        , "#818cf8" // 2: soft indigo
        , "#a855f7" // 3: neon purple (center)
        , "#c084fc" // 4: bright violet
        , "#e879f9" // 5: electric fuchsia
        , "#f472b6"  // 6: luminous pink
    ]

    readonly property var cameraPalette: ["#34d399", "#10b981", "#059669", "#10b981", "#34d399", "#6ee7b7", "#a7f3d0"]

    function colorForBar(index) {
        if (overrideColor !== "transparent" && overrideColor.a > 0)
            return overrideColor;
        if (island && island.cameraActive)
            return cameraPalette[index % cameraPalette.length];
        return siriPalette[index % siriPalette.length];
    }

    spacing: island ? island.s(3) : 3
    height: maxHeight

    Repeater {
        id: barsRepeater
        model: wave.barCount

        Rectangle {
            id: bar
            property real level: 0.3
            property color baseColor: wave.colorForBar(index)

            anchors.verticalCenter: parent.verticalCenter
            width: wave.barWidth
            radius: width / 2
            height: {
                if (!wave.active || wave.voiceState === "idle")
                    return wave.minHeight;
                return Math.max(wave.minHeight, wave.maxHeight * level);
            }

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.lighter(bar.baseColor, 1.4)
                }
                GradientStop {
                    position: 0.6
                    color: bar.baseColor
                }
                GradientStop {
                    position: 1.0
                    color: Qt.darker(bar.baseColor, 1.2)
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: wave.voiceState === "thinking" ? 280 : 150
                    easing.type: Easing.InOutQuad
                }
            }

            Behavior on baseColor {
                ColorAnimation {
                    duration: 300
                }
            }
        }
    }

    // Phase tracker for smooth traveling wave synthesis
    property real phase: 0

    Timer {
        interval: wave.voiceState === "thinking" ? 180 : 120
        repeat: true
        running: wave.active && wave.visible && wave.voiceState !== "idle"
        onTriggered: {
            wave.phase = (wave.phase + 0.5) % (Math.PI * 2);
            var n = barsRepeater.count;
            if (n === 0)
                return;
            for (var i = 0; i < n; i++) {
                var item = barsRepeater.itemAt(i);
                if (!item)
                    continue;
                if (wave.voiceState === "thinking") {
                    // Symmetrical gentle breathing wave radiating from center
                    var dist = Math.abs(i - (n - 1) / 2);
                    var pulse = (Math.sin(wave.phase - dist * 0.8) + 1.0) / 2.0;
                    item.level = 0.25 + 0.45 * pulse;
                } else if (wave.voiceState === "speaking") {
                    // Dynamic speech equalizer with pronounced peaks
                    var rnd = Math.random();
                    var bell = 1.0 - Math.pow((i - (n - 1) / 2) / (n / 1.8), 2);
                    item.level = Math.max(0.2, Math.min(1.0, (0.3 + 0.7 * rnd) * bell));
                } else {
                    // Listening: lively undulating organic acoustic wave
                    var waveVal = (Math.sin(wave.phase + i * 0.9) + 1.0) / 2.0;
                    var noise = (Math.random() - 0.5) * 0.35;
                    item.level = Math.max(0.18, Math.min(1.0, waveVal * 0.75 + 0.15 + noise));
                }
            }
        }
    }
}
