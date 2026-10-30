# Sub-Project 1 Design Specification: Shell Form Factor, Appearance & Quick Controls

**Date:** 2026-10-30  
**Status:** Approved  
**Project:** Island (Omarchy Dynamic Island)  
**Reference Mockup:** Option A (Unified Morphing Deck)

---

## 1. Executive Summary

This specification outlines the architecture, visual rendering, and hardware integration for **Sub-Project 1** of the NotchPixel feature implementation in the **Island** plugin for Omarchy.

This phase equips Island with:
1. **Dynamic Form Factor Switching:** Runtime toggling between a top-bezel **Hanging Notch** and a floating capsule **Island**.
2. **Liquid Glass & Aesthetic Themes:** Translucent backdrop blur with specular glass accents, OLED Black, Graphite, and dynamic Omarchy system theme presets.
3. **Unified Quick Controls Deck (`QuickControlsView`):** An all-in-one morphing card containing Wi-Fi, Bluetooth, volume & brightness sliders, Night Light, Power Profiles, and live styling controls.
4. **One-Tap Microphone Mute & Call Timer:** An interactive on-island mute button communicating with PipeWire, featuring a live elapsed call duration counter for active communication streams.

No global keybindings are introduced; all interactions are touch/pointer and click-driven directly on the Island interface.

---

## 2. Architecture & View State Management

### 2.1 View Hierarchy and Sizing

In `Island.qml`, the island expands into a unified card without spawning secondary detached surfaces.

```
                      ┌──────────────────────┐
                      │   Idle Resting Pill  │ (Clock, Glances, Ticker)
                      └──────────┬───────────┘
                                 │ Click / Hover
                                 ▼
                      ┌──────────────────────┐
         ┌────────────┤   Expanded Island    ├────────────┐
         │            └──────────────────────┘            │
         ▼                                                ▼
┌──────────────────┐                            ┌───────────────────┐
│ Now Playing View │  ◄── Header Switcher ──►   │ QuickControlsView │
│ (Artwork, Scrub, │                            │ (Tiles, Sliders,  │
│  Equalizer)      │                            │  Form, Themes)    │
└──────────────────┘                            └───────────────────┘
```

- When active media is playing, the default expanded view is `media-expanded`.
- When clicking the header's `Control` toggle pill, the view state transitions smoothly to `controls`.
- If no media is playing and the idle pill is clicked, the island expands directly into `controls` or `idle-expanded`.

### 2.2 Geometry Specification (`IslandModel.js`)

In `IslandModel.sizeFor()`, add the `"controls"` view configuration:
- **Width:** `s(440)` (device-scaled)
- **Height:** `s(380)` (device-scaled)
- **Corner Radius:** `s(34)`
- **Ear Fillet Radius:** `s(8)` (when in Notch mode)

Transition animations use Quickshell's existing spring-physics curves (`NumberAnimation` with `duration: 350`, `easing.type: Easing.OutCubic`) to ensure smooth expansion and morphing.

---

## 3. Form Factor & Appearance Shading Pipeline

### 3.1 Form Factor Switcher

1. **Hanging Notch (`notch: true`):**
   - Top edge anchored directly to the display bezel (`topMargin = 0`).
   - Drawn via `notchShape` (`ShapePath` with `PathArc` concave fillets on both sides).
   - Top border is open to the monitor bezel; rim stroke wraps around the sides and bottom curve.
2. **Floating Island (`notch: false`):**
   - Floats below the top bar or top bezel (`topMargin = s(8)`).
   - Drawn via `capsule` (`PathRectangle` with full $360^\circ$ perimeter rim).
3. **Persistence:**
   - Switching form factor writes `"style": "notch"` or `"style": "island"` to `~/.config/omarchy/shell.json` in the plugin's configuration block.

### 3.2 Appearance Themes

Add the `appearance` property in `Island.qml` with 4 distinct visual presets:

1. **Liquid Glass (`"glass"`):**
   - **Surface Gradient:** Top stop `#2a2e39` @ $88\%$ alpha, bottom stop `#14171f` @ $94\%$ alpha.
   - **Backdrop Blur:** Quickshell window namespace is set to `"omarchy-dynamic-island"`, bound to Hyprland's layer-shell blur (`layerrule = blur, omarchy-dynamic-island; layerrule = ignorezero, omarchy-dynamic-island`).
   - **Rim Highlight:** 1px hairline stroke `#475569` with specular top reflection.
2. **OLED Black (`"black"`):**
   - **Surface:** `#05070a` @ $98\%$ alpha.
   - **Rim:** `#1f242d` @ $100\%$ alpha.
3. **Graphite (`"graphite"`):**
   - **Surface:** `#1c1f26` @ $95\%$ alpha.
   - **Rim:** `#2d3340` @ $100\%$ alpha.
4. **Omarchy Theme (`"theme"`):**
   - Dynamically pulls tokens from `Style.view` (`root.surfaceTop`, `root.surfaceBottom`, `root.rim`).

---

## 4. Quick Controls Deck Layout (`QuickControlsView.qml`)

The view implements the exact layout validated in the Option A mockup:

### 4.1 Header Bar
- **Left:** Mini artwork thumbnail (32x32 rounded rect), Track Title ("Starboy — The Weeknd"), and playback subtitle.
- **Right:** Segmented view switcher pills: `[ Media ]` and `[ Control ]` (active).
- **Divider:** Subtle 1px hairline divider (`#334155`).

### 4.2 Network Tiles (Row 1)
- **Wi-Fi Tile (206px $\times$ 58px):**
  - Icon: `󰤨`
  - Title: "Wi-Fi"
  - Subtitle: Connected SSID (e.g. "Fiber-5G (Connected)") or "Disconnected".
  - Click Action: Executes `nmcli radio wifi on` or `nmcli radio wifi off`.
- **Bluetooth Tile (206px $\times$ 58px):**
  - Icon: `󰂯`
  - Title: "Bluetooth"
  - Subtitle: Connected audio device / battery (e.g. "Sony WH-1000XM5") or "No Devices".
  - Click Action: Toggles `Quickshell.Bluetooth.defaultAdapter.powered`.

### 4.3 Hardware Sliders (Row 2)
- **Volume Slider (432px $\times$ 42px):**
  - Icon: `󰕾`, Label: "Volume", Percentage text: e.g. "75%".
  - Bar Fill: Blue gradient `#60a5fa` $\rightarrow$ `#3b82f6`.
  - Interaction: Direct click or drag updates `Pipewire.defaultAudioSink.audio.volume`.
- **Brightness Slider (432px $\times$ 42px):**
  - Icon: `󰃠`, Label: "Brightness", Percentage text: e.g. "60%".
  - Bar Fill: Amber `#f59e0b`.
  - Interaction: Direct click or drag adjusts system backlight via existing `setBrightness()`.

### 4.4 Quick Action Toggles (Row 3)
- **One-Tap Mic Mute Button (136px $\times$ 52px):**
  - Muted State: Red background tint (`#ef4444` @ 20%), border `#ef4444`, icon `󰍭`, label "Mic Muted".
  - Active State: Neutral/Emerald tint, icon `󰍬`, label "Mic Active".
  - Subtitle: Active call timer (e.g. "Call: 12:45").
  - Click Action: Toggles `Pipewire.defaultAudioSource.audio.muted = !muted`.
- **Night Light Toggle (136px $\times$ 52px):**
  - Icon: `󰖔`, Label: "Night Light".
  - Subtitle: "On (Warm 4000K)" or "Off".
  - Click Action: Toggles `hyprsunset` / `gammastep`.
- **Power Profile Toggle (136px $\times$ 52px):**
  - Icon: `󰓅`, Label: "Power Mode".
  - Subtitle: "Performance" / "Balanced" / "Power Saver".
  - Click Action: Cycles profile via `powerprofilesctl set <profile>`.

### 4.5 Configuration Pickers (Row 4)
- **Form Factor Selector:**
  - Header: "FORM FACTOR".
  - Segmented buttons: `[ Notch ]` | `[ Floating ]`.
- **Appearance Selector:**
  - Header: "APPEARANCE".
  - Segmented buttons: `[ Glass ]` | `[ Black ]` | `[ Graphite ]` | `[ Theme ]`.

---

## 5. Microphone Stream & Call Duration Tracking

1. **Detection:**
   - In `IslandModel.isMicStream(node)`, monitor PipeWire audio input streams.
   - When any communication client (Discord, WebRTC, Zoom, OBS) binds an audio input source, record `streamStartTime = Date.now()`.
2. **Timer Ticker:**
   - While `root.micActive` is true, an internal 1-second `Timer` updates `callDurationText`.
   - Format: `MM:SS` (e.g., `04:12`) or `H:MM:SS` if $> 60$ minutes.
3. **Mute Synchronization:**
   - Bind bidirectionally to `Pipewire.defaultAudioSource.audio.muted`.
   - Tapping the mute button immediately updates the source; any external mute from PipeWire/wireplumber reflects back into the UI.

---

## 6. Testing & Quality Verification Plan

1. **Syntax & QML Compilation:**
   - Execute `qmllint` across `plugin/Island.qml`, `plugin/views/QuickControlsView.qml`, and all modified QML components.
2. **Model Unit Tests (`verification/test_island.py`):**
   - Add test case verifying `Model.sizeFor("controls", ...)` returns expected dimensions.
   - Add test case verifying call timer formatting logic (`0s` $\rightarrow$ `00:00`, `765s` $\rightarrow$ `12:45`, `3665s` $\rightarrow$ `1:01:05`).
   - Add test case validating setting parsing for `style` and `appearance`.
3. **Full Regression Suite:**
   - Run `./run-tests.sh` to ensure all existing tests pass without regressions.
