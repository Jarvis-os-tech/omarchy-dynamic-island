# Sub-Project 3 Design Specification: Media Lyrics, Reminders & AI Fleet Monitor

**Date:** 2026-10-31  
**Status:** Approved  
**Project:** Island (Omarchy Dynamic Island)  
**Scope:** Synchronized Song Lyrics, Multi-Agent AI Fleet Status, and Interactive Reminders

---

## 1. Executive Summary

This specification defines the architecture, data flow, user interface, and verification criteria for **Sub-Project 3** of the NotchPixel feature implementation in the **Island** plugin for Omarchy.

This phase equips Island with:
1. **Synchronized Lyrics for Now Playing:** An auto-scrolling karaoke-style lyrics view in the expanded media player powered by `lrclib.net` API with local caching and interactive seeking.
2. **AI Fleet Monitor:** Real-time multi-agent activity tracking via `brain-who` CLI, providing glance alerts in the resting pill when agents are working and a dedicated 6-agent status deck (`AIFleetView`).
3. **Interactive Reminders:** Quick scheduling with inline `[ Done ]` and `[ Snooze +10m ]` action buttons on trigger, backed by persistent storage in `~/.config/omarchy/reminders.json`.
4. **Unified 3-Way Header Switcher:** Seamless spring-animated navigation between `[ Media ]`, `[ Control ]`, and `[ AI Fleet ]`.

---

## 2. Architecture & View State Management

### 2.1 View Hierarchy

```
                      ┌──────────────────────┐
                      │   Idle Resting Pill  │ ◄─── AI Working Glances
                      └──────────┬───────────┘
                                 │ Click / Hover
                                 ▼
                      ┌──────────────────────┐
                      │   Expanded Island    │
                      └──────────┬───────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         ▼                       ▼                       ▼
┌──────────────────┐    ┌───────────────────┐    ┌──────────────────┐
│ Media Player &   │    │ QuickControlsView │    │ AIFleetView      │
│ Synced Lyrics    │    │ (Tiles, Sliders,  │    │ (6 Agent Cards,  │
│ [Media]          │    │  Pickers)         │    │  Tasks, Badges)  │
│                  │    │ [Control]         │    │ [AI Fleet]       │
└──────────────────┘    └───────────────────┘    └──────────────────┘
```

- Expanded views share the top-right 3-way segmented pill switcher: `[ Media ]` | `[ Control ]` | `[ AI Fleet ]`.
- Sizing specifications in `IslandModel.js`:
  - `"media-expanded"`: $404 \times 186\text{px}$, radius $34\text{px}$ (or $404 \times 240\text{px}$ in lyrics mode).
  - `"controls"`: $440 \times 380\text{px}$, radius $34\text{px}$.
  - `"aifleet"`: $440 \times 380\text{px}$, radius $34\text{px}$.

---

## 3. Synchronized Lyrics Engine

### 3.1 Data Flow & Caching
1. **Trigger:** When `mediaTitle` or `mediaArtist` changes and media is playing, trigger lyrics resolution.
2. **Local Cache:** Check `~/.cache/omarchy/lyrics/<trackSignature>.json`. If present, parse and load immediately.
3. **Remote Fetch:** If not in cache, query `https://lrclib.net/api/get?artist_name={artist}&track_name={track}&album_name={album}` asynchronously using a non-blocking `curl` command.
4. **Cache Write:** Save returned payload to local cache for offline reuse.

### 3.2 LRC Timestamp Parser (`IslandModel.js`)
- Parses LRC strings containing lines formatted as `[MM:SS.xx] lyrics text` into structured arrays:
  ```json
  [
    { "time": 0.0, "text": "♪ Intro ♪" },
    { "time": 12.4, "text": "Yeah, I've been tryna call" },
    { "time": 18.2, "text": "I've been on my own for long enough" }
  ]
  ```
- Binary search / scan `findActiveLrcIndex(lines, currentSeconds)` finds the active line matching `player.position / 1000000`.

### 3.3 UI Implementation (`MediaExpanded.qml`)
- **Toggle Icon:** A lyrics button (`󰎆` / Mic icon) in the player header flips between Album Art view and the Lyrics view.
- **Visuals:**
  - Active line: Centered in view, highlighted in crisp white (`#ffffff`) or accent color, DemiBold font (`f(15)`).
  - Inactive lines: Softly dimmed (`#94a3b8`, opacity $0.45$).
  - Smooth spring scroll animation smoothly glides the list as the song advances.
  - Interactive seeking: Clicking any line seeks playback directly to `line.time`.

---

## 4. AI Fleet Monitor (`AIFleet.qml` & `AIFleetView.qml`)

### 4.1 CLI Polling & Data Parsing (`plugin/sources/AIFleet.qml`)
- Executes `brain-who` via `Quickshell.Io.Process`.
- Parses tabular output into structured agent records:
  ```json
  [
    { "agent": "codex", "status": "WORKING", "lastActive": "now", "doing": "Writing tests...", "isWorking": true },
    { "agent": "claude", "status": "idle", "lastActive": "5d ago", "doing": "", "isWorking": false },
    { "agent": "gemini", "status": "idle", "lastActive": "11d ago", "doing": "", "isWorking": false },
    { "agent": "opencode", "status": "idle", "lastActive": "16h ago", "doing": "", "isWorking": false },
    { "agent": "hermes", "status": "idle", "lastActive": "6h ago", "doing": "", "isWorking": false },
    { "agent": "omp", "status": "idle", "lastActive": "4d ago", "doing": "", "isWorking": false }
  ]
  ```
- **Dynamic Cadence:**
  - Every 3.5s while any agent `isWorking` is true.
  - Every 15s when all agents are idle.
  - Immediate poll when `AIFleetView` becomes visible.

### 4.2 Resting Pill Glances
- When an agent is working, the resting pill ticker includes an AI activity glance:
  - Icon: `󰚩`
  - Text: e.g. `"Codex: working"` (pulsing green dot).

### 4.3 Full Deck Layout (`plugin/views/AIFleetView.qml`)
- Header: "AI Agents Fleet", count summary ("1 Working · 5 Idle"), and the 3-way view switcher `[ Media | Control | AI Fleet ]`.
- Body: 2-column or 3-column grid of 6 cards for each fleet agent:
  - Agent Glyph (`󰚩` Codex, `󰭹` Claude, `󰊢` OpenCode, `󰠠` Hermes, etc.).
  - Agent Name & Status Badge (`WORKING` in emerald green, `IDLE` in soft slate).
  - Doing excerpt and last active time.

---

## 5. Interactive Reminders Engine (`plugin/sources/Reminders.qml`)

### 5.1 Storage & Records
- Saved in `~/.config/omarchy/reminders.json`.
- Schema:
  ```json
  [
    {
      "id": "rem-1730332800",
      "title": "Review pull request",
      "dueTimestamp": 1730336400000,
      "repeat": "none",
      "status": "pending"
    }
  ]
  ```

### 5.2 Trigger & Inline Actions
- Checked once per second. When `dueTimestamp <= Date.now()`:
  - Pops an interactive alert banner on the Island with sound alert.
  - Action 1: **`[ Done ]`** — Marks reminder done, clears notification (or advances by 24h/7d if recurring).
  - Action 2: **`[ Snooze (+10m) ]`** — Reschedules `dueTimestamp = Date.now() + 600000`.

### 5.3 Quick Creation UX
- Inline row in `IdleExpanded.qml` with title field and quick offsets: `[ +15m ]`, `[ +30m ]`, `[ +1h ]`.
- CLI command: `omarchy-shell dynamic-island remind 15m "Drink water"`.

---

## 6. Testing & Verification

1. **Unit Tests in `verification/test_island.py`:**
   - LRC parser tests (`parseLrc`, `findActiveLrcIndex`).
   - `brain-who` table parser test (`parseBrainWho`).
   - Reminder time duration parser (`parseReminderDuration`).
2. **QML Syntax Validation:**
   - `qmlformat` and `qmllint` on all new and modified components.
3. **Full Suite:**
   - `./run-tests.sh` (all 7 suites pass with 100%).
4. **Desktop IPC & Sync:**
   - `./dev-install.sh` and live IPC testing with `omarchy-shell dynamic-island aifleet`.
