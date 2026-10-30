#!/usr/bin/env bash
# dev-install.sh — Install and sync Dynamic Island into Omarchy shell
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/plugin" ]]; then
  SOURCE_DIR="$SCRIPT_DIR/plugin"
else
  SOURCE_DIR="$SCRIPT_DIR"
fi

PLUGIN_ID="omarchy-dynamic-island"
TARGET_DIR="${HOME}/.config/omarchy/plugins/${PLUGIN_ID}"

echo "============================================================"
echo " Setting up Dynamic Island for Omarchy ($PLUGIN_ID)"
echo "============================================================"
echo "Source: $SOURCE_DIR"
echo "Target: $TARGET_DIR"

mkdir -p "$(dirname "$TARGET_DIR")"

# If target directory already exists and matches source, skip copying
if [[ -d "$TARGET_DIR" ]]; then
  if diff -rq "$SOURCE_DIR" "$TARGET_DIR" >/dev/null 2>&1; then
    echo "✓ Target plugin directory is already up to date."
  else
    BACKUP_DIR="${HOME}/.config/omarchy/plugins/.${PLUGIN_ID}.bak.$(date +%Y%m%d%H%M%S)"
    echo "Backing up previous installation to $BACKUP_DIR..."
    cp -a "$TARGET_DIR" "$BACKUP_DIR"
    echo "Syncing plugin files..."
    cp -a "$SOURCE_DIR"/. "$TARGET_DIR"/
    echo "✓ Files synced."
  fi
else
  echo "Installing plugin files to $TARGET_DIR..."
  mkdir -p "$TARGET_DIR"
  cp -a "$SOURCE_DIR"/. "$TARGET_DIR"/
  echo "✓ Installed."
fi

# Validate manifest
if command -v omarchy >/dev/null 2>&1; then
  echo "Validating plugin manifest..."
  omarchy plugin validate "$TARGET_DIR"
fi

# Rescan in running omarchy-shell
if command -v omarchy-shell >/dev/null 2>&1; then
  echo "Rescanning shell plugins..."
  omarchy-shell shell rescanPlugins 2>/dev/null || true
fi

# Enable plugin in Omarchy
if command -v omarchy >/dev/null 2>&1; then
  echo "Enabling plugin in Omarchy shell..."
  omarchy plugin enable "$PLUGIN_ID" || true
fi

echo ""
echo "============================================================"
echo " ✓ Dynamic Island setup complete and enabled!"
echo "============================================================"
echo "Commands to interact with Dynamic Island:"
echo "  • State check:    omarchy-shell dynamic-island state"
echo "  • Toggle open:    omarchy-shell dynamic-island toggle"
echo "  • Send toast:     omarchy-shell dynamic-island toast 'Title' 'Message' '󰄬' green"
echo "  • Start timer:    omarchy-shell dynamic-island timer 25m 'Focus'"
echo "  • Demo modes:     omarchy-shell dynamic-island demo media (or 'demo off')"
echo "============================================================"
