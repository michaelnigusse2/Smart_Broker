#!/usr/bin/env bash
# Finds buttons that do nothing and stray print() calls in lib/.
# Usage: tool/no_dead_handlers.sh [--warn]   (--warn reports but never fails)
set -uo pipefail

mode="${1:-}"
pattern='on(Tap|Pressed|LongPress|Changed)[[:space:]]*:[[:space:]]*\([^)]*\)[[:space:]]*(\{[[:space:]]*\}|=>[[:space:]]*\{[[:space:]]*\})|(^|[^A-Za-z_.])print\('

matches="$(grep -rnE "$pattern" lib --include='*.dart' || true)"
if [[ -z "$matches" ]]; then
  echo "no_dead_handlers: OK"
  exit 0
fi

echo "no_dead_handlers: found empty handlers or print() calls:"
echo "$matches"
if [[ "$mode" == "--warn" ]]; then
  echo "(warning only)"
  exit 0
fi
exit 1
