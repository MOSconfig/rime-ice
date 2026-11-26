#!/usr/bin/env bash
# Tests for scripts/fetch-grammar.sh using small local files (no network).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/fetch-test.XXXXXX")"
trap 'rm -rf "$T"' EXIT
NAME="wanxiang-lts-zh-hans.gram"
fail=0
check() { if eval "$2"; then echo "ok    $1"; else echo "FAIL  $1"; fail=$((fail + 1)); fi; }
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
run() { GRAM_DIR="$T/dest" GRAM_URL="file://$T/src/$NAME" GRAM_SHA256="$PIN" \
  bash "$ROOT/scripts/fetch-grammar.sh" "$@" > "$T/log" 2>&1; }

mkdir -p "$T/src" "$T/dest"
printf 'model-v1' > "$T/src/$NAME"; PIN="$(sha "$T/src/$NAME")"

run; rc=$?
check "fresh install succeeds" '[ $rc = 0 ] && [ "$(sha "$T/dest/$NAME")" = "$PIN" ]'

printf 'model-v2' > "$T/src/$NAME"
run; rc=$?
check "pinned file in place is not downloaded again" '[ $rc = 0 ] && grep -q "already installed" "$T/log" && [ "$(cat "$T/dest/$NAME")" = model-v1 ]'

printf 'corrupt' > "$T/dest/$NAME"
cp "$T/dest/$NAME" "$T/before"
run; rc=$?
check "hash mismatch exits non-zero" '[ $rc != 0 ]'
check "hash mismatch leaves existing model byte-for-byte" 'cmp -s "$T/dest/$NAME" "$T/before"'
check "hash mismatch leaves no .part file" '[ ! -e "$T/dest/$NAME.part" ]'

run --update; rc=$?
check "--update replaces the model and prints the new hash" '[ $rc = 0 ] && [ "$(cat "$T/dest/$NAME")" = model-v2 ] && grep -q "$(sha "$T/src/$NAME")" "$T/log"'

GRAM_DIR="$T/dest" bash "$ROOT/scripts/fetch-grammar.sh" --bogus > /dev/null 2>&1; rc=$?
check "unknown argument exits 2" '[ $rc = 2 ]'

echo "---"; echo "fetch-grammar: $fail failed"
[ "$fail" = 0 ]
