#!/usr/bin/env bash
# Sync root battle mechanics markdown into Flutter assets.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/battle_game_mechanics.md"
DEST="$SCRIPT_DIR/app/assets/data/battle_game_mechanics.md"

if [[ ! -f "$SRC" ]]; then
  echo "[sync_mechanics] Source file not found: $SRC" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"

if [[ -f "$DEST" ]] && cmp -s "$SRC" "$DEST"; then
  echo "[sync_mechanics] Up to date"
  exit 0
fi

cp "$SRC" "$DEST"
echo "[sync_mechanics] Synced $(basename "$SRC") -> app/assets/data/battle_game_mechanics.md"
