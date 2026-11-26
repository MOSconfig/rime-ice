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
no_temp() { [ -z "$(find "$T/dest" -name "$NAME.part*")" ]; }

mkdir -p "$T/src" "$T/dest"
printf 'model-v1' > "$T/src/$NAME"; PIN="$(sha "$T/src/$NAME")"

run; rc=$?
check "fresh install succeeds" '[ $rc = 0 ] && [ "$(sha "$T/dest/$NAME")" = "$PIN" ]'

printf 'model-v2' > "$T/src/$NAME"
run; rc=$?
check "pinned file in place is not downloaded again" '[ $rc = 0 ] && grep -q "already installed" "$T/log" && [ "$(cat "$T/dest/$NAME")" = model-v1 ]'

run --update; rc=$?
check "--update replaces a model that still matches the pin" '[ $rc = 0 ] && [ "$(cat "$T/dest/$NAME")" = model-v2 ] && grep -q "$(sha "$T/src/$NAME")" "$T/log"'

printf 'corrupt' > "$T/dest/$NAME"
cp "$T/dest/$NAME" "$T/before"
run; rc=$?
check "hash mismatch exits non-zero" '[ $rc != 0 ]'
check "hash mismatch leaves existing model byte-for-byte" 'cmp -s "$T/dest/$NAME" "$T/before"'
check "hash mismatch leaves no temp file" 'no_temp'

# Concurrent runs: one good source, one failing source. The installed file must
# end up as a complete verified copy, never a partial one.
printf 'model-v1' > "$T/src/$NAME"; rm -f "$T/dest/$NAME"
GRAM_DIR="$T/dest" GRAM_URL="file://$T/src/$NAME" GRAM_SHA256="$PIN" \
  bash "$ROOT/scripts/fetch-grammar.sh" > "$T/a.log" 2>&1 & a=$!
GRAM_DIR="$T/dest" GRAM_URL="file://$T/missing/$NAME" GRAM_SHA256="$PIN" \
  bash "$ROOT/scripts/fetch-grammar.sh" > "$T/b.log" 2>&1 & b=$!
wait $a; ra=$?; wait $b; rb=$?
check "concurrent runs: good run installs a verified file" '[ $ra = 0 ] && [ "$(sha "$T/dest/$NAME")" = "$PIN" ]'
# The failing run either lost the race (exit != 0) or found the verified file
# already installed and skipped the download; both are correct.
check "concurrent runs: failing run fails or skips a verified file" '[ $rb != 0 ] || grep -q "already installed" "$T/b.log"'
check "concurrent runs leave no temp file" 'no_temp'

GRAM_DIR="$T/dest" bash "$ROOT/scripts/fetch-grammar.sh" --bogus > /dev/null 2>&1; rc=$?
check "unknown argument exits 2" '[ $rc = 2 ]'

echo "---"; echo "fetch-grammar: $fail failed"
[ "$fail" = 0 ]
