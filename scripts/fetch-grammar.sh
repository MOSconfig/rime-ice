#!/usr/bin/env bash
# Download the wanxiang grammar model (~391 MB) used by `grammar:` in
# rime_ice.schema.yaml, verify it, and place it in the Rime user folder
# (this repo root). The file is gitignored; run this once per machine.
#
#   bash scripts/fetch-grammar.sh           # install or verify the pinned model
#   bash scripts/fetch-grammar.sh --update  # download again, accept any hash, print it
#
# Without the model the schema still works: ranking falls back to the dictionary.
# Rules: a pinned file already in place is never downloaded again (unless --update).
# A download whose hash differs from the pin is discarded and the existing model
# is left untouched. --update replaces the model with whatever upstream serves.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="wanxiang-lts-zh-hans.gram"
URL="${GRAM_URL:-https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/$NAME}"
SHA256="${GRAM_SHA256:-e9ddd501b7d536bc5ea1346f8f900ae49a719a05be349e0a17cb27e717143ca5}" # LTS, 2026-11-18
DEST="${GRAM_DIR:-$ROOT}/$NAME"
PART="$DEST.part"

update=0
case "${1:-}" in
  --update) update=1 ;;
  "") ;;
  *) echo "usage: $0 [--update]" >&2; exit 2 ;;
esac

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

if [ "$update" = 0 ] && [ -f "$DEST" ] && [ "$(sha "$DEST")" = "$SHA256" ]; then
  echo "$NAME is already installed and verified."
  exit 0
fi

trap 'rm -f "$PART"' EXIT
echo "Downloading $NAME (~391 MB)..."
curl -fL --retry 3 -o "$PART" "$URL"
got="$(sha "$PART")"

if [ "$update" = 0 ] && [ "$got" != "$SHA256" ]; then
  echo "sha256 mismatch: expected $SHA256, got $got" >&2
  echo "Upstream may have published a new model; re-run with --update to accept it." >&2
  exit 1
fi

mv -f "$PART" "$DEST"
echo "Installed $DEST"
[ "$update" = 1 ] && echo "sha256: $got  (set SHA256 in scripts/fetch-grammar.sh to pin it)"
echo "Redeploy Rime to load it (Squirrel: menu → 重新部署, or"
echo "  \"/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel\" --reload)."
