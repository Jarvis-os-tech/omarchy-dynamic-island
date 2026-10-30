#!/usr/bin/env bash
# run-tests.sh — Run Dynamic Island validation and verification tests
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEST_FILE="$SCRIPT_DIR/verification/test_island.py"

# Find a suitable pytest executable
PYTEST_CMD=""
if command -v pytest >/dev/null 2>&1; then
  PYTEST_CMD="pytest"
elif [[ -x "/home/g0pi/Projects/JARVIS-OMA/.venv/bin/pytest" ]]; then
  PYTEST_CMD="/home/g0pi/Projects/JARVIS-OMA/.venv/bin/pytest"
elif command -v uv >/dev/null 2>&1; then
  PYTEST_CMD="uv run pytest"
fi

if [[ -z "$PYTEST_CMD" ]]; then
  echo "Error: pytest not found." >&2
  exit 1
fi

echo "==> Running Dynamic Island verification tests with $PYTEST_CMD..."
exec $PYTEST_CMD "$TEST_FILE" "$@"
