# Sub-Project 1: Shell Form Factor, Appearance & Quick Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the NotchPixel-style dynamic form factor switcher (Notch vs. Floating Island), Liquid Glass/OLED/Graphite appearance presets, a unified Quick Controls deck (`QuickControlsView`), and one-tap microphone mute with live call duration timer in the Omarchy Dynamic Island plugin.

**Architecture:** A single morphing layer-shell surface without detached secondary windows. Quickshell and QtQuick spring animations transition the island shape smoothly between resting pill, media, and the new `controls` view. Live system data hooks into PipeWire (volume, mic mute, call detection), Quickshell Bluetooth, sysfs backlight, NetworkManager (`nmcli`), and power profiles.

**Tech Stack:** QML (Qt 6 / Quickshell), JavaScript (ES6), Python 3 (pytest test harness), Linux system tools (`nmcli`, `powerprofilesctl`, `gammastep`/`hyprsunset`).

**Spec:** [docs/superpowers/specs/2026-10-30-notchpixel-island-shell-design.md](file:///home/g0pi/Projects/Island/docs/superpowers/specs/2026-10-30-notchpixel-island-shell-design.md)

## Global Constraints
- Target platform is Linux Wayland (Hyprland / Omarchy shell).
- No global hotkeys/keybindings; all user actions are touch/click/pointer-driven on the Island UI.
- All dimensions must scale via `root.s(px)` and font sizes via `root.f(pt)`.
- Never block the UI thread: all system shell commands run asynchronously via `Quickshell.Io.Process`.
- Preserve existing 6/6 pytest verification suite compatibility in `verification/test_island.py`.

---

### Task 1: Geometry & Call Duration Helpers in `IslandModel.js` and Unit Tests

**Files:**
- Modify: `plugin/IslandModel.js:140-195`
- Test: `verification/test_island.py:100-160`

**Interfaces:**
- Produces: `Model.sizeFor("controls", counts, notchSize)` returning `{ w: 440, h: 380, r: 34 }`.
- Produces: `Model.formatCallDuration(seconds)` returning formatted `MM:SS` (or `H:MM:SS`).
- Produces: `Model.validAppearance(theme)` returning boolean.

- [ ] **Step 1: Write failing unit test in `verification/test_island.py`**

Add tests for `"controls"` view sizing, call duration string formatting, and appearance themes validation.

```python
def test_quick_controls_model_helpers():
    js = parse_island_model_js()
    # Test sizing for controls
    res = js.call("sizeFor", "controls", {}, {"w": 0, "h": 0, "r": 0})
    assert res["w"] == 440
    assert res["h"] == 380
    assert res["r"] == 34

    # Test call duration formatting
    assert js.call("formatCallDuration", 0) == "00:00"
    assert js.call("formatCallDuration", 75) == "01:15"
    assert js.call("formatCallDuration", 765) == "12:45"
    assert js.call("formatCallDuration", 3665) == "1:01:05"

    # Test appearance themes
    assert js.call("validAppearance", "glass") is True
    assert js.call("validAppearance", "black") is True
    assert js.call("validAppearance", "graphite") is True
    assert js.call("validAppearance", "theme") is True
    assert js.call("validAppearance", "invalid") is False
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/home/g0pi/Projects/JARVIS-OMA/.venv/bin/pytest verification/test_island.py -k test_quick_controls_model_helpers -v`  
Expected: FAIL (helper functions not found or return undefined).

- [ ] **Step 3: Implement functions in `plugin/IslandModel.js`**

Add `formatCallDuration`, `validAppearance`, and the `"controls"` case in `sizeFor`:

```javascript
export function validAppearance(name) {
  return ["glass", "black", "graphite", "theme"].indexOf(name) !== -1;
}

export function formatCallDuration(totalSeconds) {
  var s = Math.max(0, Math.floor(totalSeconds || 0));
  var hrs = Math.floor(s / 3600);
  var mins = Math.floor((s % 3600) / 60);
  var secs = s % 60;
  var pad = function(n) { return (n < 10 ? "0" : "") + n; };
  if (hrs > 0) {
    return hrs + ":" + pad(mins) + ":" + pad(secs);
  }
  return pad(mins) + ":" + pad(secs);
}
```

And in `sizeFor(view, counts, notchSize)`:
```javascript
  case "controls":
    return { w: 440, h: 380, r: 34 };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/home/g0pi/Projects/JARVIS-OMA/.venv/bin/pytest verification/test_island.py -k test_quick_controls_model_helpers -v`  
Expected: PASS.

---

### Task 2: Build `plugin/views/QuickControlsView.qml`

**Files:**
- Create: `plugin/views/QuickControlsView.qml`
- Test: `verification/test_island.py` (ensure QML parses clean with `qmllint`)

**Interfaces:**
- Consumes: `island` (root reference providing `s()`, `f()`, `fontFamily`, PipeWire properties, `setBrightness()`, theme tokens).
- Produces: Complete UI matching Option A mockup:
  - Header: Track thumbnail, title, and `[ Media ]` / `[ Control ]` switcher.
  - Row 1: Wi-Fi tile (`nmcli`) & Bluetooth tile (`Quickshell.Bluetooth`).
  - Row 2: Volume & Brightness horizontal interactive sliders.
  - Row 3: One-tap Mic Mute (PipeWire default source) with Call Timer label, Night Light toggle, Power Mode toggle.
  - Row 4: Form Factor (`Notch` / `Floating`) & Appearance (`Glass` / `Black` / `Graphite` / `Theme`) pickers.

- [ ] **Step 1: Write `plugin/views/QuickControlsView.qml`**

Create `plugin/views/QuickControlsView.qml`:
- Implement interactive mouse areas on the sliders with direct click and drag tracking.
- Implement network tiles with live connection states.
- Implement mic mute button with PipeWire source toggle and active call timer display.
- Implement segmented buttons for Form Factor and Appearance which call `island.setIslandStyle()` and `island.setIslandAppearance()`.

- [ ] **Step 2: Run QML syntax validation**

Run: `qmllint plugin/views/QuickControlsView.qml`  
Expected: Clean pass with 0 syntax errors.

---

### Task 3: Appearance Themes & Liquid Glass Shading in `plugin/Island.qml`

**Files:**
- Modify: `plugin/Island.qml:40-120` (Appearance properties & theme tokens)
- Modify: `plugin/Island.qml:1435-1510` (Surface shaders, colors, and border strokes)
- Test: `verification/test_island.py`

**Interfaces:**
- Consumes: `setting("appearance", "glass")`, `setting("style", "notch")`.
- Produces:
  - `root.appearance`: reactive string (`"glass"`, `"black"`, `"graphite"`, `"theme"`).
  - Dynamically adjusted `surfaceTop`, `surfaceBottom`, `rim`, and layer-shell blur namespace.
  - Config writing helper `savePluginSetting(key, value)` updating `~/.config/omarchy/shell.json`.

- [ ] **Step 1: Add appearance tokens and settings persistence in `plugin/Island.qml`**

Add properties:
```qml
readonly property string appearance: {
  var a = String(setting("appearance", "glass"))
  return Model.validAppearance(a) ? a : "glass"
}
```
Compute `surfaceTop`, `surfaceBottom`, and `rim` based on `root.appearance`:
- `"glass"`: translucent slate `#e02a2e39` / `#f014171f`, rim `#475569`.
- `"black"`: `#fa05070a` / `#fc05070a`, rim `#1f242d`.
- `"graphite"`: `#f21c1f26` / `#f21c1f26`, rim `#2d3340`.
- `"theme"`: system theme tokens.

Add helper to write settings to `~/.config/omarchy/shell.json`:
```qml
function setIslandStyle(newStyle) {
  savePluginSetting("style", newStyle)
}
function setIslandAppearance(newApp) {
  savePluginSetting("appearance", newApp)
}
```

- [ ] **Step 2: Run tests to ensure no regressions**

Run: `./run-tests.sh`  
Expected: 6/6 tests pass.

---

### Task 4: Connect `QuickControlsView` & State Transitions in `Island.qml`

**Files:**
- Modify: `plugin/Island.qml:1030-1120` (View selection & ViewSlot)
- Modify: `plugin/views/MediaExpanded.qml` (Add Control Center switcher icon in header)
- Modify: `plugin/views/IdleExpanded.qml` (Add Control Center switcher icon)
- Test: `verification/test_island.py`

**Interfaces:**
- Consumes: `root.view`, `root.requestedSubView`.
- Produces: Seamless cross-fade and spring resize into `QuickControlsView` when `"controls"` view is active.

- [ ] **Step 1: Register `QuickControlsView` in `Island.qml`**

Instantiate `QuickControlsView` inside the island's view stack alongside `MediaExpanded`, `CalendarView`, and `InboxView`.
Add `requestedSubView` property (`"media"` or `"controls"`) and wire the header pills to switch between them.

- [ ] **Step 2: Wire Call Duration Timer & Mic Stream Tracking**

In `Island.qml`:
- Detect when `root.micActive` transitions to true $\rightarrow$ record `callStartTime = Date.now()`.
- Run a 1-second `Timer` to compute `callDurationSeconds = Math.floor((Date.now() - callStartTime) / 1000)`.
- When `root.micActive` becomes false, reset timer.
- Expose `callDurationText: Model.formatCallDuration(callDurationSeconds)`.

- [ ] **Step 3: Run full verification suite**

Run: `./run-tests.sh`  
Expected: All tests pass.

---

### Task 5: End-to-End Verification & Desktop Test Run

**Files:**
- Test: Run `./run-tests.sh`
- Test: `./dev-install.sh` to update plugin deployment in `~/.config/omarchy/plugins/omarchy-dynamic-island`
- Test: Exercise IPC command `omarchy-shell dynamic-island state` to confirm `controls` state and settings persistence.

- [ ] **Step 1: Execute test suite**

Run: `./run-tests.sh`  
Expected: All test suites PASS (including all QML syntax checks, JavaScript model checks, and screen recovery).

- [ ] **Step 2: Sync and validate with dev-install**

Run: `./dev-install.sh`  
Expected: Successful validation of manifest, plugin rescan, and active island deployment.
