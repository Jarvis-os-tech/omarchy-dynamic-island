import QtQuick

// The detached circle that carries a second live activity while the pill is
// busy with the first, like iOS's split island.
Item {
    id: view

    property var island: null
    property string kind: ""

    AlbumArt {
        anchors.centerIn: parent
        visible: view.kind === "media"
        width: parent.width - island.s(10)
        height: width
        radius: width / 2
        source: island.mediaArt
        tint: island.accentColor
        fontFamily: island.fontFamily
    }

    RecordDot {
        anchors.centerIn: parent
        visible: view.kind === "recording"
        size: island.s(11)
        color: island.urgentColor
    }

    Text {
        anchors.centerIn: parent
        visible: view.kind === "inbox"
        text: "󰂚"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(15)
        color: island.accentColor
    }

    Rectangle {
        visible: view.kind === "inbox" && island && island.inbox.length > 1
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: island ? island.s(1) : 1
        anchors.rightMargin: island ? island.s(1) : 1
        height: island ? island.s(12) : 12
        width: Math.max(height, badgeText.implicitWidth + (island ? island.s(6) : 6))
        radius: height / 2
        color: island ? island.urgentColor : "#ef4444"

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: island ? island.inbox.length : ""
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island ? island.textFamily : "sans-serif"
            font.pixelSize: island ? island.f(8) : 8
            font.weight: Font.Bold
            color: "#ffffff"
        }
    }

    // Timer / activity: their ring, so progress is readable even here.
    ProgressRing {
        anchors.fill: parent
        anchors.margins: island.s(5)
        visible: (view.kind === "timer") || (view.kind === "activity" && !!island.activity && island.activity.progress >= 0)
        progress: view.kind === "timer" ? island.clocks.timerProgress : (island.activity ? Math.max(0, island.activity.progress) : 0)
        color: view.kind === "timer" ? island.orangeColor : (island.activity ? island.toneFor(island.activity.color) : island.accentColor)
        lineWidth: island.s(2)
    }

    Text {
        anchors.centerIn: parent
        visible: view.kind === "timer" || view.kind === "stopwatch" || view.kind === "activity" || view.kind === "calendar"
        text: view.kind === "timer" ? "󰔛" : (view.kind === "stopwatch" ? "󱎫" : (view.kind === "calendar" ? "󰃭" : (island.activity ? island.activity.icon : "")))
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: view.kind === "timer" || view.kind === "activity" ? island.f(11) : island.f(15)
        color: view.kind === "timer" ? island.orangeColor : (view.kind === "activity" && island.activity ? island.toneFor(island.activity.color) : island.accentColor)
    }

    Text {
        anchors.centerIn: parent
        visible: view.kind === "mic" && island && island.cameraActive
        text: "󰄀"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(15)
        color: island.greenColor
    }

    VoiceWaveform {
        anchors.centerIn: parent
        visible: view.kind === "mic" && (!island || !island.cameraActive)
        island: view.island
        voiceState: island && island.activeVoiceState ? island.activeVoiceState : "listening"
        active: true
        barCount: 3
        barWidth: island ? island.s(2.5) : 2.5
        maxHeight: island ? island.s(12) : 12
        minHeight: island ? island.s(2.5) : 2.5
    }
}
