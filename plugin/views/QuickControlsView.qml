import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import "../IslandModel.js" as Model

// Unified Quick Controls Deck: Network tiles, Volume & Brightness sliders,
// Quick actions (Mic mute with call timer, Night Light, Power Mode),
// and live Form Factor & Appearance pickers.
Item {
    id: view

    property var island: null

    implicitWidth: view.s(440)
    implicitHeight: view.s(380)

    // ------------------------------------------------------------------
    // Helper accessors and scalers
    // ------------------------------------------------------------------
    function s(n) {
        return view.island && typeof view.island.s === "function" ? view.island.s(n) : n;
    }

    function f(n) {
        return view.island && typeof view.island.f === "function" ? view.island.f(n) : n;
    }

    readonly property int pad: view.s(14)
    readonly property string fontFamily: view.island && view.island.fontFamily ? view.island.fontFamily : "sans-serif"
    readonly property string textFamily: view.island && view.island.textFamily ? view.island.textFamily : "sans-serif"
    readonly property color fg: view.island && view.island.fg ? view.island.fg : "#ffffff"
    readonly property color fgDim: view.island && view.island.fgDim ? view.island.fgDim : Util.alpha(view.fg, 0.6)
    readonly property color accentColor: view.island && view.island.accentColor ? view.island.accentColor : "#38bdf8"
    readonly property color surfaceTop: view.island && view.island.surfaceTop ? view.island.surfaceTop : "#1e293b"

    // ------------------------------------------------------------------
    // PipeWire tracking
    // ------------------------------------------------------------------
    readonly property var pwSource: Pipewire.defaultAudioSource
    readonly property var pwSink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: {
            var list = [];
            if (view.pwSource)
                list.push(view.pwSource);
            if (view.pwSink)
                list.push(view.pwSink);
            return list;
        }
    }

    // ------------------------------------------------------------------
    // State: Wi-Fi
    // ------------------------------------------------------------------
    property bool wifiEnabled: true
    property string wifiSsid: ""

    Process {
        id: wifiToggleProc
        onExited: wifiQueryTimer.restart()
    }

    Process {
        id: wifiQueryProc
        command: ["sh", "-c", "nmcli radio wifi 2>/dev/null; nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2-"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(text || "").trim().split("\n");
                if (lines.length > 0 && lines[0]) {
                    view.wifiEnabled = lines[0].trim() === "enabled";
                }
                if (lines.length > 1 && lines[1]) {
                    view.wifiSsid = lines[1].trim();
                } else {
                    view.wifiSsid = "";
                }
            }
        }
    }

    Timer {
        id: wifiQueryTimer
        interval: 5000
        running: view.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!wifiQueryProc.running)
                wifiQueryProc.running = true;
        }
    }

    function toggleWifi() {
        view.wifiEnabled = !view.wifiEnabled;
        wifiToggleProc.command = ["nmcli", "radio", "wifi", view.wifiEnabled ? "on" : "off"];
        wifiToggleProc.running = true;
    }

    // ------------------------------------------------------------------
    // State: Bluetooth
    // ------------------------------------------------------------------
    readonly property bool btPowered: {
        if (!Bluetooth.defaultAdapter)
            return false;
        var adapter = Bluetooth.defaultAdapter;
        if (adapter["powered"] !== undefined)
            return adapter["powered"];
        return adapter.enabled === true;
    }
    readonly property var btDevicesList: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property string connectedDeviceName: {
        for (var i = 0; i < btDevicesList.length; i++) {
            var d = btDevicesList[i];
            if (d && d.connected) {
                return String(d.name || d.deviceName || "Connected");
            }
        }
        return "";
    }

    function toggleBluetooth() {
        if (Bluetooth.defaultAdapter) {
            var adapter = Bluetooth.defaultAdapter;
            if (adapter["powered"] !== undefined) {
                adapter["powered"] = !adapter["powered"];
            } else {
                adapter.enabled = !adapter.enabled;
            }
        }
    }

    // ------------------------------------------------------------------
    // State: Hardware sliders (Volume & Brightness)
    // ------------------------------------------------------------------
    readonly property real volumeFraction: {
        if (view.island && view.island.volume !== undefined) {
            return view.island.muted ? 0 : view.island.volume;
        }
        if (view.pwSink && view.pwSink.audio) {
            return view.pwSink.audio.muted ? 0 : view.pwSink.audio.volume;
        }
        return 0.75;
    }

    function setVolumeFraction(fraction) {
        var frac = Math.max(0, Math.min(1, fraction));
        if (view.island && typeof view.island.setVolumeFraction === "function") {
            view.island.setVolumeFraction(frac);
        } else if (view.island && view.island.sink && view.island.sink.audio) {
            view.island.sink.audio.muted = false;
            view.island.sink.audio.volume = frac;
        } else if (view.pwSink && view.pwSink.audio) {
            view.pwSink.audio.muted = false;
            view.pwSink.audio.volume = frac;
        }
    }

    property real currentBrightness: 0.6
    readonly property real brightnessFraction: {
        var b = (view.island && view.island.brightness !== undefined && view.island.brightness >= 0) ? view.island.brightness : (view.currentBrightness >= 0 ? view.currentBrightness : 0.6);
        return Math.max(0.01, Math.min(1.0, b));
    }

    Process {
        id: brightnessSetProc
    }

    function setBrightnessFraction(fraction) {
        var frac = Math.max(0.01, Math.min(1.0, Number(fraction) || 0.01));
        if (view.island && typeof view.island.setBrightnessFraction === "function") {
            view.island.setBrightnessFraction(frac);
        } else if (view.island && typeof view.island.setBrightness === "function") {
            view.island.setBrightness(frac);
        } else {
            if (view.island)
                view.island.brightness = frac;
            view.currentBrightness = frac;
            if (!brightnessSetProc.running) {
                brightnessSetProc.command = ["brightnessctl", "set", Math.round(frac * 100) + "%"];
                brightnessSetProc.running = true;
            }
        }
    }

    // ------------------------------------------------------------------
    // State: Action toggles (Mic, Night Light, Power Mode)
    // ------------------------------------------------------------------
    readonly property bool micMuted: {
        if (view.island && view.island.micMuted !== undefined) {
            return view.island.micMuted;
        }
        if (view.pwSource && view.pwSource.audio) {
            return view.pwSource.audio.muted;
        }
        return false;
    }

    readonly property string callDurationDisplay: (!view.island || !view.island.micActive || !view.island.callDurationText) ? "No call" : ("Call: " + view.island.callDurationText)

    function toggleMicMute() {
        if (view.island && typeof view.island.toggleMicMute === "function") {
            view.island.toggleMicMute();
        } else if (view.pwSource && view.pwSource.audio) {
            view.pwSource.audio.muted = !view.pwSource.audio.muted;
        }
    }

    property bool nightLightActive: false

    Process {
        id: nightLightToggleProc
        onExited: nightLightProbe.running = true
    }

    Process {
        id: nightLightProbe
        command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null && echo 'on' || echo 'off'"]
        stdout: StdioCollector {
            onStreamFinished: {
                view.nightLightActive = String(text || "").trim() === "on";
            }
        }
    }

    Timer {
        id: nightLightTimer
        interval: 5000
        running: view.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!nightLightProbe.running)
                nightLightProbe.running = true;
        }
    }

    function toggleNightLight() {
        nightLightToggleProc.command = ["sh", "-c", "pkill -x hyprsunset || hyprsunset -t 4000 &"];
        nightLightToggleProc.running = true;
    }

    property string powerProfile: "balanced"
    readonly property string powerProfileDisplay: {
        if (view.powerProfile === "performance")
            return "Performance";
        if (view.powerProfile === "power-saver")
            return "Power Saver";
        return "Balanced";
    }

    Process {
        id: powerProfileSetProc
        onExited: powerProfileProbe.running = true
    }

    Process {
        id: powerProfileProbe
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = String(text || "").trim();
                if (p)
                    view.powerProfile = p;
            }
        }
    }

    Timer {
        id: powerProfileTimer
        interval: 5000
        running: view.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!powerProfileProbe.running)
                powerProfileProbe.running = true;
        }
    }

    function cyclePowerMode() {
        var next = "balanced";
        if (view.powerProfile === "power-saver")
            next = "balanced";
        else if (view.powerProfile === "balanced")
            next = "performance";
        else
            next = "power-saver";
        view.powerProfile = next;
        if (view.island && typeof view.island.setPowerProfile === "function") {
            view.island.setPowerProfile(next);
        } else {
            powerProfileSetProc.command = ["powerprofilesctl", "set", next];
            powerProfileSetProc.running = true;
        }
    }

    // ------------------------------------------------------------------
    // State: Form Factor & Appearance
    // ------------------------------------------------------------------
    readonly property bool isNotch: view.island ? (view.island.notch !== false) : true

    function setFormFactor(style) {
        if (view.island && typeof view.island.setIslandStyle === "function") {
            view.island.setIslandStyle(style);
        }
    }

    readonly property string currentAppearance: view.island && view.island.appearance ? view.island.appearance : "glass"

    function setAppearance(mode) {
        if (view.island && typeof view.island.setIslandAppearance === "function") {
            view.island.setIslandAppearance(mode);
        }
    }

    function switchToMedia() {
        if (view.island) {
            if (typeof view.island.switchExpandedView === "function") {
                view.island.switchExpandedView("media");
            } else {
                view.island.requestedSubView = "media";
            }
        }
    }

    // ------------------------------------------------------------------
    // Layout Deck
    // ------------------------------------------------------------------
    Column {
        id: mainDeck
        anchors.fill: parent
        anchors.margins: view.pad
        spacing: view.s(10)

        // 1. Header Bar: Mini Album Art, Track Title, State & View Switcher
        Item {
            id: headerBar
            width: parent.width
            height: view.s(36)

            Rectangle {
                id: miniArt
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: view.s(32)
                height: width
                radius: view.s(8)
                color: Util.alpha(view.accentColor, 0.2)
                clip: true

                Image {
                    id: miniArtImage
                    anchors.fill: parent
                    source: view.island ? (view.island.mediaArt || "") : ""
                    visible: status === Image.Ready
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !miniArtImage.visible
                    text: "󰝚"
                    renderType: Text.NativeRendering
                    font.family: view.fontFamily
                    font.pixelSize: view.f(14)
                    color: view.accentColor
                }
            }

            Column {
                anchors.left: miniArt.right
                anchors.leftMargin: view.s(10)
                anchors.right: viewSwitcher.left
                anchors.rightMargin: view.s(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: view.s(2)

                Text {
                    width: parent.width
                    text: (view.island && (view.island.mediaTitle || view.island.trackTitle)) ? (view.island.mediaTitle || view.island.trackTitle) : "No Media Playing"
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                    font.family: view.textFamily
                    font.pixelSize: view.f(12.5)
                    font.weight: Font.DemiBold
                    color: view.fg
                }

                Text {
                    width: parent.width
                    text: (view.island && view.island.mediaPlaying) ? "Now Playing" : "Idle"
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                    font.family: view.textFamily
                    font.pixelSize: view.f(10.5)
                    color: view.fgDim
                }
            }

            Rectangle {
                id: viewSwitcher
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: view.s(132)
                height: view.s(26)
                radius: view.s(13)
                color: Util.alpha(view.fg, 0.08)

                Row {
                    anchors.fill: parent
                    anchors.margins: view.s(2)

                    Rectangle {
                        width: parent.width / 2
                        height: parent.height
                        radius: view.s(11)
                        color: mediaMouse.containsMouse ? Util.alpha(view.fg, 0.08) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Media"
                            renderType: Text.NativeRendering
                            font.family: view.textFamily
                            font.pixelSize: view.f(11)
                            font.weight: Font.Normal
                            color: view.fgDim
                        }

                        MouseArea {
                            id: mediaMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.switchToMedia()
                        }
                    }

                    Rectangle {
                        width: parent.width / 2
                        height: parent.height
                        radius: view.s(11)
                        color: Util.alpha(view.fg, 0.16)

                        Text {
                            anchors.centerIn: parent
                            text: "Control"
                            renderType: Text.NativeRendering
                            font.family: view.textFamily
                            font.pixelSize: view.f(11)
                            font.weight: Font.DemiBold
                            color: view.fg
                        }
                    }
                }
            }
        }

        // Hairline Separator
        Rectangle {
            width: parent.width
            height: 1
            color: "#334155"
        }

        // 2. Row 1: Network Tiles (Wi-Fi & Bluetooth)
        Row {
            id: row1
            width: parent.width
            height: view.s(56)
            spacing: view.s(8)

            // Wi-Fi Tile
            Rectangle {
                id: wifiTile
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                radius: view.s(12)
                color: wifiMouse.containsMouse ? Util.alpha(view.fg, 0.09) : Util.alpha(view.fg, 0.06)
                border.width: 1
                border.color: view.wifiEnabled ? Util.alpha(view.accentColor, 0.25) : Util.alpha(view.fg, 0.08)

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: view.s(12)
                    anchors.rightMargin: view.s(12)
                    spacing: view.s(10)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: view.wifiEnabled ? "󰤨" : "󰤮"
                        renderType: Text.NativeRendering
                        font.family: view.fontFamily
                        font.pixelSize: view.f(20)
                        color: view.wifiEnabled ? view.accentColor : view.fgDim
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - view.s(30)
                        spacing: view.s(2)

                        Text {
                            width: parent.width
                            text: "Wi-Fi"
                            textFormat: Text.PlainText
                            renderType: Text.NativeRendering
                            font.family: view.textFamily
                            font.pixelSize: view.f(12)
                            font.weight: Font.DemiBold
                            color: view.fg
                        }

                        Text {
                            width: parent.width
                            text: !view.wifiEnabled ? "Disconnected" : (view.wifiSsid ? view.wifiSsid + " (Connected)" : "Connected")
                            textFormat: Text.PlainText
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            font.family: view.textFamily
                            font.pixelSize: view.f(10.5)
                            color: view.fgDim
                        }
                    }
                }

                MouseArea {
                    id: wifiMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.toggleWifi()
                }
            }

            // Bluetooth Tile
            Rectangle {
                id: btTile
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                radius: view.s(12)
                color: btMouse.containsMouse ? Util.alpha(view.fg, 0.09) : Util.alpha(view.fg, 0.06)
                border.width: 1
                border.color: view.btPowered ? Util.alpha(view.accentColor, 0.25) : Util.alpha(view.fg, 0.08)

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: view.s(12)
                    anchors.rightMargin: view.s(12)
                    spacing: view.s(10)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: view.btPowered ? "󰂯" : "󰂲"
                        renderType: Text.NativeRendering
                        font.family: view.fontFamily
                        font.pixelSize: view.f(20)
                        color: view.btPowered ? view.accentColor : view.fgDim
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - view.s(30)
                        spacing: view.s(2)

                        Text {
                            width: parent.width
                            text: "Bluetooth"
                            textFormat: Text.PlainText
                            renderType: Text.NativeRendering
                            font.family: view.textFamily
                            font.pixelSize: view.f(12)
                            font.weight: Font.DemiBold
                            color: view.fg
                        }

                        Text {
                            width: parent.width
                            text: !view.btPowered ? "Off" : (view.connectedDeviceName ? view.connectedDeviceName : "No Devices")
                            textFormat: Text.PlainText
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            font.family: view.textFamily
                            font.pixelSize: view.f(10.5)
                            color: view.fgDim
                        }
                    }
                }

                MouseArea {
                    id: btMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.toggleBluetooth()
                }
            }
        }

        // 3. Row 2: Hardware Sliders (Volume & Brightness)
        Column {
            id: row2
            width: parent.width
            spacing: view.s(8)

            // Volume Slider
            Rectangle {
                id: volumeTrack
                width: parent.width
                height: view.s(40)
                radius: view.s(12)
                color: Util.alpha(view.fg, 0.08)
                clip: true

                Rectangle {
                    width: Math.max(0, Math.min(parent.width, parent.width * view.volumeFraction))
                    height: parent.height
                    radius: view.s(12)
                    color: "#3b82f6"
                    opacity: 0.85

                    Behavior on width {
                        enabled: !volumeMouse.pressed
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: view.s(12)
                    anchors.rightMargin: view.s(12)

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: view.s(8)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: view.volumeFraction === 0 ? "󰝟" : (view.volumeFraction < 0.5 ? "󰕿" : "󰕾")
                            renderType: Text.NativeRendering
                            font.family: view.fontFamily
                            font.pixelSize: view.f(15)
                            color: view.fg
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Volume"
                            textFormat: Text.PlainText
                            renderType: Text.NativeRendering
                            font.family: view.textFamily
                            font.pixelSize: view.f(12)
                            font.weight: Font.DemiBold
                            color: view.fg
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(view.volumeFraction * 100) + "%"
                        textFormat: Text.PlainText
                        renderType: Text.NativeRendering
                        font.family: view.textFamily
                        font.pixelSize: view.f(12)
                        font.weight: Font.Bold
                        color: view.fg
                    }
                }

                MouseArea {
                    id: volumeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => view.setVolumeFraction(mouse.x / width)
                    onPositionChanged: mouse => {
                        if (pressed)
                            view.setVolumeFraction(mouse.x / width);
                    }
                }
            }

            // Brightness Slider
            Rectangle {
                id: brightnessTrack
                width: parent.width
                height: view.s(40)
                radius: view.s(12)
                color: Util.alpha(view.fg, 0.08)
                clip: true

                Rectangle {
                    width: Math.max(0, Math.min(parent.width, parent.width * view.brightnessFraction))
                    height: parent.height
                    radius: view.s(12)
                    color: "#f59e0b"
                    opacity: 0.85

                    Behavior on width {
                        enabled: !brightnessMouse.pressed
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: view.s(12)
                    anchors.rightMargin: view.s(12)

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: view.s(8)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰃠"
                            renderType: Text.NativeRendering
                            font.family: view.fontFamily
                            font.pixelSize: view.f(15)
                            color: view.fg
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Brightness"
                            textFormat: Text.PlainText
                            renderType: Text.NativeRendering
                            font.family: view.textFamily
                            font.pixelSize: view.f(12)
                            font.weight: Font.DemiBold
                            color: view.fg
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(view.brightnessFraction * 100) + "%"
                        textFormat: Text.PlainText
                        renderType: Text.NativeRendering
                        font.family: view.textFamily
                        font.pixelSize: view.f(12)
                        font.weight: Font.Bold
                        color: view.fg
                    }
                }

                MouseArea {
                    id: brightnessMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => view.setBrightnessFraction(mouse.x / width)
                    onPositionChanged: mouse => {
                        if (pressed)
                            view.setBrightnessFraction(mouse.x / width);
                    }
                }
            }
        }

        // 4. Row 3: Action Toggles (Mic Mute, Night Light, Power Mode)
        Row {
            id: row3
            width: parent.width
            height: view.s(50)
            spacing: view.s(8)

            readonly property real tileWidth: (width - spacing * 2) / 3

            // Mic Mute Button
            Rectangle {
                id: micTile
                width: parent.tileWidth
                height: parent.height
                radius: view.s(12)
                color: view.micMuted ? Util.alpha("#ef4444", 0.22) : (micMouse.containsMouse ? Util.alpha(view.fg, 0.09) : Util.alpha(view.fg, 0.06))
                border.width: 1
                border.color: view.micMuted ? "#ef4444" : Util.alpha(view.fg, 0.08)

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: view.s(8)
                    anchors.rightMargin: view.s(8)
                    spacing: view.s(7)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: view.micMuted ? "󰍭" : "󰍬"
                        renderType: Text.NativeRendering
                        font.family: view.fontFamily
                        font.pixelSize: view.f(16)
                        color: view.micMuted ? "#ef4444" : view.fg
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - view.s(24)
                        spacing: view.s(2)

                        Text {
                            width: parent.width
                            text: view.micMuted ? "Mic Muted" : "Mic Active"
                            textFormat: Text.PlainText
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            font.family: view.textFamily
                            font.pixelSize: view.f(11)
                            font.weight: Font.DemiBold
                            color: view.micMuted ? "#ef4444" : view.fg
                        }

                        Text {
                            width: parent.width
                            text: view.callDurationDisplay
                            textFormat: Text.PlainText
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            font.family: view.textFamily
                            font.pixelSize: view.f(9.5)
                            color: view.micMuted ? Util.alpha("#ef4444", 0.8) : view.fgDim
                        }
                    }
                }

                MouseArea {
                    id: micMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.toggleMicMute()
                }
            }

            // Night Light Toggle
            Rectangle {
                id: nightLightTile
                width: parent.tileWidth
                height: parent.height
                radius: view.s(12)
                color: view.nightLightActive ? Util.alpha("#f59e0b", 0.22) : (nlMouse.containsMouse ? Util.alpha(view.fg, 0.09) : Util.alpha(view.fg, 0.06))
                border.width: 1
                border.color: view.nightLightActive ? "#f59e0b" : Util.alpha(view.fg, 0.08)

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: view.s(8)
                    anchors.rightMargin: view.s(8)
                    spacing: view.s(7)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰖔"
                        renderType: Text.NativeRendering
                        font.family: view.fontFamily
                        font.pixelSize: view.f(16)
                        color: view.nightLightActive ? "#f59e0b" : view.fg
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - view.s(24)
                        spacing: view.s(2)

                        Text {
                            width: parent.width
                            text: "Night Light"
                            textFormat: Text.PlainText
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            font.family: view.textFamily
                            font.pixelSize: view.f(11)
                            font.weight: Font.DemiBold
                            color: view.fg
                        }

                        Text {
                            width: parent.width
                            text: view.nightLightActive ? "On (Warm 4000K)" : "Off"
                            textFormat: Text.PlainText
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            font.family: view.textFamily
                            font.pixelSize: view.f(9.5)
                            color: view.nightLightActive ? "#f59e0b" : view.fgDim
                        }
                    }
                }

                MouseArea {
                    id: nlMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.toggleNightLight()
                }
            }

            // Power Mode Toggle
            Rectangle {
                id: powerTile
                width: parent.tileWidth
                height: parent.height
                radius: view.s(12)
                color: powerMouse.containsMouse ? Util.alpha(view.fg, 0.09) : Util.alpha(view.fg, 0.06)
                border.width: 1
                border.color: Util.alpha(view.fg, 0.08)

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: view.s(8)
                    anchors.rightMargin: view.s(8)
                    spacing: view.s(7)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰓅"
                        renderType: Text.NativeRendering
                        font.family: view.fontFamily
                        font.pixelSize: view.f(16)
                        color: view.accentColor
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - view.s(24)
                        spacing: view.s(2)

                        Text {
                            width: parent.width
                            text: "Power Mode"
                            textFormat: Text.PlainText
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            font.family: view.textFamily
                            font.pixelSize: view.f(11)
                            font.weight: Font.DemiBold
                            color: view.fg
                        }

                        Text {
                            width: parent.width
                            text: view.powerProfileDisplay
                            textFormat: Text.PlainText
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            font.family: view.textFamily
                            font.pixelSize: view.f(9.5)
                            color: view.fgDim
                        }
                    }
                }

                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.cyclePowerMode()
                }
            }
        }

        // 5. Row 4: Pickers (Form Factor & Appearance)
        Row {
            id: row4
            width: parent.width
            height: view.s(50)
            spacing: view.s(12)

            // FORM FACTOR Column
            Column {
                id: formFactorCol
                width: view.s(150)
                height: parent.height
                spacing: view.s(4)

                Text {
                    text: "FORM FACTOR"
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    font.family: view.textFamily
                    font.pixelSize: view.f(10)
                    font.weight: Font.Bold
                    color: view.fgDim
                }

                Rectangle {
                    width: parent.width
                    height: view.s(28)
                    radius: view.s(10)
                    color: Util.alpha(view.fg, 0.06)

                    Row {
                        anchors.fill: parent
                        anchors.margins: view.s(2)

                        Rectangle {
                            width: parent.width / 2
                            height: parent.height
                            radius: view.s(8)
                            color: view.isNotch ? Util.alpha(view.fg, 0.16) : (notchMouse.containsMouse ? Util.alpha(view.fg, 0.08) : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: "Notch"
                                renderType: Text.NativeRendering
                                font.family: view.textFamily
                                font.pixelSize: view.f(11)
                                font.weight: view.isNotch ? Font.DemiBold : Font.Normal
                                color: view.isNotch ? view.fg : view.fgDim
                            }

                            MouseArea {
                                id: notchMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.setFormFactor("notch")
                            }
                        }

                        Rectangle {
                            width: parent.width / 2
                            height: parent.height
                            radius: view.s(8)
                            color: !view.isNotch ? Util.alpha(view.fg, 0.16) : (floatingMouse.containsMouse ? Util.alpha(view.fg, 0.08) : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: "Floating"
                                renderType: Text.NativeRendering
                                font.family: view.textFamily
                                font.pixelSize: view.f(11)
                                font.weight: !view.isNotch ? Font.DemiBold : Font.Normal
                                color: !view.isNotch ? view.fg : view.fgDim
                            }

                            MouseArea {
                                id: floatingMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.setFormFactor("island")
                            }
                        }
                    }
                }
            }

            // APPEARANCE Column
            Column {
                id: appearanceCol
                width: parent.width - formFactorCol.width - parent.spacing
                height: parent.height
                spacing: view.s(4)

                Text {
                    text: "APPEARANCE"
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                    font.family: view.textFamily
                    font.pixelSize: view.f(10)
                    font.weight: Font.Bold
                    color: view.fgDim
                }

                Rectangle {
                    width: parent.width
                    height: view.s(28)
                    radius: view.s(10)
                    color: Util.alpha(view.fg, 0.06)

                    Row {
                        id: appRow
                        anchors.fill: parent
                        anchors.margins: view.s(2)

                        Repeater {
                            model: [
                                {
                                    id: "glass",
                                    label: "Glass"
                                },
                                {
                                    id: "black",
                                    label: "Black"
                                },
                                {
                                    id: "graphite",
                                    label: "Graphite"
                                },
                                {
                                    id: "theme",
                                    label: "Theme"
                                }
                            ]

                            Rectangle {
                                id: appSegment
                                required property var modelData
                                readonly property bool active: view.currentAppearance === modelData.id
                                width: appRow.width / 4
                                height: appRow.height
                                radius: view.s(8)
                                color: appSegment.active ? Util.alpha(view.fg, 0.16) : (appMouse.containsMouse ? Util.alpha(view.fg, 0.08) : "transparent")

                                Text {
                                    anchors.centerIn: parent
                                    text: appSegment.modelData.label
                                    renderType: Text.NativeRendering
                                    font.family: view.textFamily
                                    font.pixelSize: view.f(10.5)
                                    font.weight: appSegment.active ? Font.DemiBold : Font.Normal
                                    color: appSegment.active ? view.fg : view.fgDim
                                }

                                MouseArea {
                                    id: appMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: view.setAppearance(appSegment.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
