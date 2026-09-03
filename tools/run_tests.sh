#!/usr/bin/env bash
# Runs the Underlight test suites headlessly.
#
#   tools/run_tests.sh [path-to-godot]
#
# Exits non-zero if any check fails, so it can gate CI. Godot's headless
# renderer emits a harmless "Parameter \"m\" is null" for every MeshInstance3D
# because the dummy rasteriser has no real meshes; those lines are filtered.

set -uo pipefail

GODOT="${1:-${GODOT_BIN:-godot}}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILTER='(Parameter "m" is null|mesh_get_surface_count|^Godot Engine|^Please see|ObjectDB instances leaked|RID of type|at: (cleanup|_free_rids))'

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "Godot 4 executable not found: $GODOT" >&2
  echo "Pass a path, or set GODOT_BIN." >&2
  exit 2
fi

status=0

run_suite() {
  local label="$1" scene="$2"
  echo ""
  echo "==> $label"
  "$GODOT" --headless --fixed-fps 60 --path "$PROJECT_DIR" "$scene" 2>&1 \
    | grep -viE "$FILTER"
  local code="${PIPESTATUS[0]}"
  if [ "$code" -ne 0 ]; then
    echo "!! $label failed (exit $code)"
    status=1
  fi
}

echo "==> Importing project"
"$GODOT" --headless --path "$PROJECT_DIR" --import 2>&1 | grep -viE "$FILTER" || true

run_suite "Rules smoke test" "res://scenes/dev/smoke_test.tscn"
run_suite "World integration test" "res://scenes/dev/world_test.tscn"

echo ""
echo "==> Boot soak (five in-game days)"
"$GODOT" --headless --fixed-fps 60 --quit-after 30000 --path "$PROJECT_DIR" \
  -- --autostart --fasttime 2>&1 | grep -viE "$FILTER" | grep -E "(ERROR|SCRIPT ERROR|World\])" || true

if [ "$status" -eq 0 ]; then
  echo ""
  echo "All suites passed."
fi
exit "$status"
