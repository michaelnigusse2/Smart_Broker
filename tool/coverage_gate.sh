#!/usr/bin/env bash
# Fails when line coverage in coverage/lcov.info is below the given percentage.
# Usage: tool/coverage_gate.sh <min-percent> [lcov-file]
# Generated files (*.g.dart, *.freezed.dart) are excluded.
set -euo pipefail

min="${1:?usage: coverage_gate.sh <min-percent> [lcov-file]}"
lcov="${2:-coverage/lcov.info}"

if [[ ! -f "$lcov" ]]; then
  echo "coverage_gate: $lcov not found — run 'flutter test --coverage' first" >&2
  exit 2
fi

awk -v min="$min" '
  /^SF:/ { skip = ($0 ~ /\.(g|freezed)\.dart$/) }
  /^LF:/ { if (!skip) { split($0, a, ":"); found += a[2] } }
  /^LH:/ { if (!skip) { split($0, a, ":"); hit += a[2] } }
  END {
    if (found == 0) { print "coverage_gate: no lines found"; exit 2 }
    pct = 100 * hit / found
    printf "Line coverage: %.1f%% (%d/%d lines), minimum %s%%\n", pct, hit, found, min
    if (pct + 0.0001 < min) { print "coverage_gate: FAILED"; exit 1 }
  }
' "$lcov"
