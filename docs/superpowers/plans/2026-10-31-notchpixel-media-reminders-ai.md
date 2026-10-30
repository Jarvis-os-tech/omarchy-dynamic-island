# Sub-Project 3: Media Lyrics, Reminders & AI Fleet Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement synchronized Now Playing song lyrics with auto-scrolling karaoke view, an AI multi-agent fleet activity monitor integrating with `brain-who`, interactive reminders with inline `[ Done ]` and `[ Snooze +10m ]` actions, and a 3-way header switcher (`[ Media | Control | AI Fleet ]`).

**Architecture:** A single morphing layer-shell surface without detached windows. The media player adds a lyrics flip view with timestamp synchronization. A background process polls `brain-who` for local agent status (Claude, Codex, Gemini, OpenCode, Hermes, OMP), routing active states into resting pill glances and an `AIFleetView` deck. A persistent reminder engine schedules timed tasks in `~/.config/omarchy/reminders.json` with interactive on-island actions.

**Tech Stack:** QML (Qt 6 / Quickshell), JavaScript (ES6), Python 3 (pytest), Linux system commands (`brain-who`, `curl`).

**Spec:** [docs/superpowers/specs/2026-10-31-notchpixel-media-reminders-ai-design.md](file:///home/g0pi/Projects/Island/docs/superpowers/specs/2026-10-31-notchpixel-media-reminders-ai-design.md)

## Global Constraints
- Target platform is Linux Wayland (Hyprland / Omarchy shell).
- No global hotkeys; all user interactions are touch/click/pointer-driven on the Island UI.
- All dimensions must scale via `root.s(px)` and font sizes via `root.f(pt)`.
- Never block the UI thread: all system shell commands run asynchronously via `Quickshell.Io.Process`.
- Preserve existing verification suite compatibility in `verification/test_island.py`.

---

### Task 1: JavaScript Parsing & Model Logic in `IslandModel.js` and Unit Tests

**Files:**
- Modify: `plugin/IslandModel.js`
- Test: `verification/test_island.py`

**Interfaces:**
- Produces: `Model.parseLrc(lrcText)` returning array of `{ time: float, text: string }`.
- Produces: `Model.findActiveLrcIndex(lines, currentSeconds)` returning integer index.
- Produces: `Model.parseBrainWho(rawOutput)` returning array of structured agent objects.
- Produces: `Model.parseReminderDuration(str)` returning integer milliseconds.
- Produces: `Model.sizeFor("aifleet", counts, notchSize)` returning `{ w: 440, h: 380, r: 34 }`.

- [ ] **Step 1: Write unit tests in `verification/test_island.py`**

Add `test_subproject3_model_helpers()` testing LRC timestamp parsing, active index search, `brain-who` output parsing, and reminder duration calculations:

```python
def test_subproject3_model_helpers():
    source = (PLUGIN/'IslandModel.js').read_text().replace('.pragma library','',1)
    assertions = r'''
const assert = require('node:assert/strict');

// 1. LRC parser
const lrc = "[00:04.50]Line one\n[00:12.00]Line two\n[01:05.25]Line three";
const lines = parseLrc(lrc);
assert.equal(lines.length, 3);
assert.equal(lines[0].time, 4.5);
assert.equal(lines[0].text, "Line one");
assert.equal(lines[1].time, 12.0);
assert.equal(lines[2].time, 65.25);

// 2. Active LRC index
assert.equal(findActiveLrcIndex(lines, 0), 0);
assert.equal(findActiveLrcIndex(lines, 8.0), 0);
assert.equal(findActiveLrcIndex(lines, 12.0), 1);
assert.equal(findActiveLrcIndex(lines, 30.0), 1);
assert.equal(findActiveLrcIndex(lines, 70.0), 2);

// 3. brain-who parser
const rawWho = `agent     status    last active  doing
opencode  idle      16h ago      chat session
codex     WORKING   now          Writing tests
claude    idle      5d ago       [interrupted]
`;
const fleet = parseBrainWho(rawWho);
assert.equal(fleet.length, 3);
assert.equal(fleet[1].agent, "codex");
assert.equal(fleet[1].isWorking, true);
assert.equal(fleet[1].doing, "Writing tests");
assert.equal(fleet[0].isWorking, false);

// 4. Reminder duration parser
assert.equal(parseReminderDuration("15m"), 15 * 60 * 1000);
assert.equal(parseReminderDuration("1h"), 60 * 60 * 1000);
assert.equal(parseReminderDuration("30s"), 30 * 1000);

// 5. aifleet sizing
assert.deepEqual(sizeFor("aifleet", {}, {w:0,h:0,r:0}), { w: 440, h: 380, r: 34 });
'''
    result = subprocess.run(['/usr/bin/node', '-e', source + '\n' + assertions], capture_output=True, text=True, timeout=15)
    assert result.returncode == 0, result.stderr
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/home/g0pi/Projects/JARVIS-OMA/.venv/bin/pytest verification/test_island.py -k test_subproject3_model_helpers -v`  
Expected: FAIL (functions not defined).

- [ ] **Step 3: Implement helper functions in `plugin/IslandModel.js`**

Implement `parseLrc`, `findActiveLrcIndex`, `parseBrainWho`, `parseReminderDuration`, and register `"aifleet"` in `sizes` and `sizeFor()`.

- [ ] **Step 4: Run test to verify it passes**

Run: `/home/g0pi/Projects/JARVIS-OMA/.venv/bin/pytest verification/test_island.py -k test_subproject3_model_helpers -v`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugin/IslandModel.js verification/test_island.py verification/source_manifest.json
git commit -m "feat: add LRC, brain-who, reminder, and aifleet model helpers"
```

---

### Task 2: Synchronized Lyrics in `MediaExpanded.qml` & Fetcher in `Island.qml`

**Files:**
- Modify: `plugin/Island.qml` (Lyrics fetcher & caching)
- Modify: `plugin/views/MediaExpanded.qml` (Flip button & auto-scrolling lyrics view)
- Test: `verification/test_island.py`

**Interfaces:**
- Consumes: `island.mediaTitle`, `island.mediaArtist`, `player.position`.
- Produces: `island.lyricsLines`, `island.activeLyricIndex`, `island.lyricsLoading`.
- Produces: Karaoke-style auto-scrolling list in `MediaExpanded.qml`.

- [ ] **Step 1: Implement lyrics fetcher in `plugin/Island.qml`**

Add `Process` to query `https://lrclib.net/api/get` via `curl` with cache path `~/.cache/omarchy/lyrics/<sig>.json`.
Parse `syncedLyrics` or `plainLyrics` via `Model.parseLrc`.
Expose `lyricsLines`, `hasLyrics`, `activeLyricIndex`, and `lyricsLoading`.

- [ ] **Step 2: Implement Lyrics Flip View in `plugin/views/MediaExpanded.qml`**

Add header button `IconButton { glyph: "󰎆"; onClicked: showingLyrics = !showingLyrics }`.
When `showingLyrics` is true, cross-fade to a `ListView` displaying lyric lines:
- Center active line (`currentIndex = island.activeLyricIndex`).
- Highlight active line with `#ffffff` and larger font.
- Click on any line invokes `player.position = line.time * 1000000`.

- [ ] **Step 3: Run full verification suite**

Run: `./run-tests.sh`  
Expected: All 7 tests pass.

- [ ] **Step 4: Commit**

```bash
git add plugin/Island.qml plugin/views/MediaExpanded.qml verification/source_manifest.json
git commit -m "feat: add synchronized Now Playing lyrics engine and interactive view"
```

---

### Task 3: AI Fleet Monitor (`plugin/sources/AIFleet.qml` & `plugin/views/AIFleetView.qml`)

**Files:**
- Create: `plugin/sources/AIFleet.qml`
- Create: `plugin/views/AIFleetView.qml`
- Modify: `plugin/Island.qml` (Header switcher pill & resting pill glances)
- Modify: `plugin/views/QuickControlsView.qml` (Header switcher pill)
- Test: `verification/test_island.py`

**Interfaces:**
- Consumes: System CLI `brain-who`.
- Produces: `island.fleetAgents: []`, `island.activeFleetCount: int`, `island.workingAgentText: string`.
- Produces: `AIFleetView.qml` rendering 6 agent cards with live status badges.
- Produces: 3-way header switcher `[ Media | Control | AI Fleet ]` in all expanded views.

- [ ] **Step 1: Create `plugin/sources/AIFleet.qml`**

Implement periodic poller running `brain-who` via `Process`.
Expose `fleetList`, `workingAgents`, and `isAnyWorking`.

- [ ] **Step 2: Create `plugin/views/AIFleetView.qml`**

Create $440 \times 380\text{px}$ view with:
- Header: "AI Agents Fleet", count summary, and `[ Media | Control | AI Fleet ]` segmented switcher.
- 6-card grid for Claude, Codex, Gemini, OpenCode, Hermes, and OMP.
- Active pulsing dot for `WORKING` agents.

- [ ] **Step 3: Integrate into `Island.qml` and header switchers**

Register `AIFleet` source and `AIFleetView` in `ViewSlot`.
Add AI activity glance to resting ticker when `isAnyWorking` is true.
Update header switchers in `MediaExpanded.qml`, `QuickControlsView.qml`, and `AIFleetView.qml` to support all 3 views.

- [ ] **Step 4: Run test suite**

Run: `./run-tests.sh`  
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add plugin/sources/AIFleet.qml plugin/views/AIFleetView.qml plugin/Island.qml plugin/views/QuickControlsView.qml plugin/views/MediaExpanded.qml verification/source_manifest.json verification/test_island.py
git commit -m "feat: add AI Fleet Monitor source, AIFleetView, and 3-way header switcher"
```

---

### Task 4: Interactive Reminders Engine (`plugin/sources/Reminders.qml` & Inline Actions)

**Files:**
- Create: `plugin/sources/Reminders.qml`
- Modify: `plugin/views/IdleExpanded.qml` (Quick reminder creator row)
- Modify: `plugin/Island.qml` (Reminder trigger alert & IPC `remind` handler)
- Test: `verification/test_island.py`

**Interfaces:**
- Produces: Persistent reminder records in `~/.config/omarchy/reminders.json`.
- Produces: Interactive alert banner with `[ Done ]` and `[ Snooze (+10m) ]` actions.
- Produces: IPC handler for `omarchy-shell dynamic-island remind <duration> <title>`.

- [ ] **Step 1: Create `plugin/sources/Reminders.qml`**

Manage `~/.config/omarchy/reminders.json`.
Check pending reminders every second.
Provide `addReminder(title, durationMs, repeat)`, `snoozeReminder(id, minutes)`, and `completeReminder(id)`.

- [ ] **Step 2: Wire Island Banner Trigger with `[ Done ]` and `[ Snooze ]` Buttons**

When a reminder triggers, display an interactive island alert banner with:
- Glyph `󰔛`, Reminder Title, and inline action buttons `[ Done ]` and `[ Snooze (+10m) ]`.
- Clicking `[ Done ]` marks completed and dismisses.
- Clicking `[ Snooze ]` reschedules for 10 minutes later.

- [ ] **Step 3: Add Reminder Creator in `IdleExpanded.qml` & IPC handler in `Island.qml`**

Add text input field and quick buttons (`+15m`, `+30m`, `+1h`) in `IdleExpanded.qml`.
Add `remind` command to `handleCommand` in `Island.qml`.

- [ ] **Step 4: Run test suite**

Run: `./run-tests.sh`  
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add plugin/sources/Reminders.qml plugin/views/IdleExpanded.qml plugin/Island.qml verification/source_manifest.json verification/test_island.py
git commit -m "feat: add interactive Reminders engine, inline Snooze/Done actions, and IPC command"
```

---

### Task 5: End-to-End Verification, Live IPC & Desktop Sync

**Files:**
- Test: `./run-tests.sh`
- Test: `./dev-install.sh`
- Test: Live IPC exercise with `omarchy-shell dynamic-island aifleet` and `remind`

- [ ] **Step 1: Execute test suite**

Run: `./run-tests.sh`  
Expected: All test suites PASS (100%).

- [ ] **Step 2: Sync and validate with dev-install**

Run: `./dev-install.sh`  
Expected: Successful manifest validation and live shell sync.

- [ ] **Step 3: Exercise live desktop IPC**

Test `aifleet`, `remind 10s "Test reminder"`, and inspect `state`.

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "chore: complete Sub-Project 3 verification and deployment sync"
```
