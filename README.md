# Island

A complete island-only source copy of the installed **Dynamic Island for Omarchy** plugin. The original independent plugin was used instead of the assistant-customized variant, so no assistant bridge, voice daemon, tool-approval handler or assistant-specific dashboard is included.

The 44 original files are preserved unchanged, including the MIT license. This folder is separate from the assistant project.

## Setup & System Integration

The plugin has been deployed and enabled in the system's Omarchy shell (`~/.config/omarchy/plugins/omarchy-dynamic-island`).

- **Installation / Sync script:** `./dev-install.sh` (validates manifest, rescans plugins, and enables the island).
- **Run verification tests:** `./run-tests.sh` (runs all 6 test suites checking QML syntax, JavaScript logic, and screen recovery).
- **Control / IPC commands:**
  ```bash
  omarchy-shell dynamic-island state       # View live state
  omarchy-shell dynamic-island toggle      # Expand/collapse island
  omarchy-shell dynamic-island toast "Title" "Message" "󰄬" green
  omarchy-shell dynamic-island timer 25m "Focus"
  omarchy-shell dynamic-island demo media  # Interactive demo mode
  omarchy-shell dynamic-island demo off
  ```

## Code

| Location | Contents |
| --- | --- |
| [plugin/Island.qml](plugin/Island.qml) | Main island, animation, sizing, view selection and desktop interaction |
| [plugin/IslandModel.js](plugin/IslandModel.js) | Activity priorities, geometry, timers, calendar parsing and presentation helpers |
| [plugin/views/](plugin/views/) | Media, clocks, calendar, notifications, recording indicators and reusable visual components |
| [plugin/sources/](plugin/sources/) | Clocks/timers, calendar feeds, devices and generic live activities |
| [plugin/Notifications.qml](plugin/Notifications.qml) | Desktop notification handling |
| [plugin/ScreenRecovery.qml](plugin/ScreenRecovery.qml) | Monitor disconnection/reconnection handling |
| [plugin/tests/](plugin/tests/) | Existing screen-recovery regression tests |
| [verification/](verification/) | Source hashes and additional validation evidence |

This is independent of assistant applications, but it is still an **Omarchy/Quickshell plugin**, not a standalone desktop executable. Its host provides QtQuick, Quickshell services, `qs.Commons`, MPRIS, PipeWire, UPower, Bluetooth and desktop helper commands. Optional calendar feeds use curl; clipboard actions use wl-paste. No other application's source code was bundled.

For plugin settings and later installation, see the [original documentation](plugin/README.md). The documentation references optional screenshots that were absent from the installed source; those illustrations are not part of this package. Do not launch the main plugin merely to inspect the files: enabling it intentionally integrates with the desktop notification and on-screen-display services.

## Verification

Six automated checks passed:

- Every copied file matches its original bytes and permissions; all local QML imports resolve.
- No assistant-specific integration names, bridges or hooks were found in the plugin files.
- All 39 QML files parse without modifying or executing them.
- Fourteen JavaScript assertions check timer parsing, activity priority, view selection, microphone-stream classification and configuration handling.
- The original screen-recovery suite passed its five behavioral cases plus setup and cleanup (seven QtTest passes), using an isolated offscreen environment.

The main plugin was not enabled or exercised against the live desktop. The isolated tests do not certify every desktop feature end to end.

See [test results](verification/results.xml), [screen-recovery log](verification/screen_recovery.log) and [source manifest](verification/source_manifest.json).
