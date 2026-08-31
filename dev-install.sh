#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID=io.github.nuu-maan.coffer
SRC=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"

mkdir -p "$DEST"
rsync -a --delete \
  --exclude '.git/' \
  --exclude '.github/' \
  --exclude 'node_modules/' \
  "$SRC/" "$DEST/"

printf 'installed %s -> %s\n' "$PLUGIN_ID" "$DEST"

if command -v omarchy-plugin-validate >/dev/null 2>&1; then
  omarchy-plugin-validate "$DEST" || { printf 'manifest validation failed\n' >&2; exit 1; }
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 \
    && printf 'shell reloaded\n' \
    || printf 'could not reach omarchy-shell (is the shell running?)\n' >&2
fi

printf '\nEnable it with:  omarchy plugin enable %s right\n' "$PLUGIN_ID"
