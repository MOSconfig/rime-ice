#!/usr/bin/env bash
# Regression tests for this Rime config, run on a real librime engine.
#
#   bash tests/run.sh                  # model ON: needs wanxiang-lts-zh-hans.gram (scripts/fetch-grammar.sh)
#   RIME_SKIP_GRAM=1 bash tests/run.sh # model OFF (only the value 1): fallback must equal a no-grammar control
#   RIME_LIB=... RIME_SHARED=... bash tests/run.sh   # other engine / shared data
#
# Deploys scratch copies of the working tree into a temp dir. Never touches
# the live Rime user folder (~/Library/Rime) or its learned-word databases.
set -euo pipefail
export LC_ALL=en_US.UTF-8

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$ROOT/tests/.cache"
LIBRIME_TAG="1.16.0" # matches Squirrel 1.1.2; bump with the engine
SQUIRREL="/Library/Input Methods/Squirrel.app/Contents"
RIME_LIB="${RIME_LIB:-$SQUIRREL/Frameworks/librime.1.dylib}"
RIME_SHARED="${RIME_SHARED:-$SQUIRREL/SharedSupport}"
MODEL="wanxiang-lts-zh-hans.gram"

[ -f "$RIME_LIB" ] || { echo "librime not found: $RIME_LIB (set RIME_LIB)" >&2; exit 2; }
[ -d "$RIME_SHARED" ] || { echo "shared data not found: $RIME_SHARED (set RIME_SHARED)" >&2; exit 2; }
if [ "${RIME_SKIP_GRAM:-0}" = 1 ]; then GRAM=0
elif [ -f "$ROOT/$MODEL" ]; then GRAM=1
else echo "$MODEL not found: run scripts/fetch-grammar.sh, or set RIME_SKIP_GRAM=1" >&2; exit 2
fi

fail=0
failed() { fail=$((fail + 1)); echo "FAIL  $*"; }

# 1. Repo policy: trimmed upstream files must stay out of the index.
stray="$(git -C "$ROOT" ls-files | grep -E \
  '^(double_pinyin|t9\.|symbols_caps_v|recipe\.yaml|AGENTS\.md|others/|build/|\.github/(ISSUE_TEMPLATE|workflows)/|cn_dicts/41448|en_dicts/cn_en_.|lua/((cn_)?en_spacer|t9_preedit|cold_word_drop/|debuger|is_in_user_dict))' || true)"
if [ -n "$stray" ]; then failed "trimmed files are tracked:"; printf '      %s\n' $stray; fi

# 2. Build the harness; rebuild when the source or the engine changes.
mkdir -p "$CACHE"
for h in rime_api.h rime_api_deprecated.h rime_api_stdbool.h; do
  [ -f "$CACHE/$h" ] || curl -fsSL -o "$CACHE/$h" \
    "https://raw.githubusercontent.com/rime/librime/$LIBRIME_TAG/src/$h" || [ "$h" != rime_api.h ]
done
stamp="$LIBRIME_TAG|$RIME_LIB|$(shasum -a 256 "$RIME_LIB" "$ROOT/tests/harness.c" | cut -d' ' -f1 | tr '\n' ' ')"
if [ ! -x "$CACHE/harness" ] || [ "$(cat "$CACHE/harness.stamp" 2>/dev/null)" != "$stamp" ]; then
  cc -o "$CACHE/harness" "$ROOT/tests/harness.c" -I "$CACHE" \
    "$RIME_LIB" -Wl,-rpath,"$(dirname "$RIME_LIB")"
  printf '%s' "$stamp" > "$CACHE/harness.stamp"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/rime-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Stage tracked + untracked-but-not-ignored regular files, one literal path at a
# time (no tar: bsdtar treats "@name" arguments as archives to import).
# Symlinks and engine-writable paths (user dictionaries, user.yaml, build, sync)
# are never copied, so librime can only open databases inside the scratch dir.
stage() {
  mkdir -p "$1/build"
  (cd "$ROOT" && git ls-files -z -co --exclude-standard) |
    while IFS= read -r -d '' f; do
      [ -L "$ROOT/$f" ] && continue
      [ -f "$ROOT/$f" ] || continue
      case "$f" in *.userdb|*.userdb/*|*.userdb.txt|user.yaml|installation.yaml|build/*|sync/*) continue ;; esac
      mkdir -p "$1/$(dirname -- "$f")"
      cp -p -- "$ROOT/$f" "$1/$f"
    done
}
deploy_run() { # data_dir keys_file out_file log_file
  "$CACHE/harness" "$1" "$RIME_SHARED" rime_ice < "$2" > "$3" 2> "$4"
}
# E lines from a log, minus the three known "model file is missing" lines,
# matched as literal line endings (no regex on paths or the model name).
engine_errors() { # log_file allow_missing_model(0/1)
  grep -E '^E' "$1" | awk -v allow="$2" -v a="/$MODEL'." -v b="failed to load grammar database: ${MODEL%.gram}" '
    function ends(s, t) { return length(s) >= length(t) && substr(s, length(s) - length(t) + 1) == t }
    allow == 1 && (index($0, "non-existent file ") || index($0, "error opening gram db ")) && ends($0, a) { next }
    allow == 1 && ends($0, b) { next }
    { print }' || true
}
report_errors() { # label errors
  [ -z "$2" ] && return 0
  failed "$1 engine errors ($(printf '%s\n' "$2" | wc -l | tr -d ' ') lines):"
  printf '%s\n' "$2" | sed -E 's/^E[0-9]+ [0-9:.]+ +0x[0-9a-f]+ //' |
    cut -c1-200 | sort | uniq -c | sort -rn | head -10
}

stage "$WORK/data"
[ "$GRAM" = 1 ] && ln -s "$ROOT/$MODEL" "$WORK/data/$MODEL"

# 3. Collect cases: keys<TAB>mode<TAB>regex[<TAB>tags]
#    @gram rows assert only with the model; @nogram rows only without it.
#    Both still run in every mode so the fallback comparison covers them.
: > "$WORK/keys"; : > "$WORK/cases"; gram_cases=0
while IFS=$'\t' read -r keys mode regex tags; do
  case "$keys" in ''|'#'*) continue ;; esac
  printf '%s\n' "$keys" >> "$WORK/keys"
  printf '%s\t%s\t%s\t%s\n' "$keys" "$mode" "$regex" "${tags:-}" >> "$WORK/cases"
done < "$ROOT/tests/cases.tsv"
expected="$(wc -l < "$WORK/cases" | tr -d ' ')"

deploy_run "$WORK/data" "$WORK/keys" "$WORK/out" "$WORK/log"
got_rows="$(wc -l < "$WORK/out" | tr -d ' ')"
[ "$got_rows" = "$expected" ] || failed "harness returned $got_rows rows, expected $expected"

# 4. Check each case.
n=0; checked=0
while IFS=$'\t' read -r keys mode regex tags <&3; do
  n=$((n + 1))
  out="$(sed -n "${n}p" "$WORK/out")"
  if [ "$(printf '%s' "$out" | cut -f1)" != "$keys" ]; then
    failed "row $n: harness answered '$(printf '%s' "$out" | cut -f1)', expected '$keys'"; continue
  fi
  case " $tags " in
    *" @gram "*)   [ "$GRAM" = 0 ] && continue; gram_cases=$((gram_cases + 1)) ;;
    *" @nogram "*) [ "$GRAM" = 1 ] && continue ;;
  esac
  checked=$((checked + 1))
  commit="$(printf '%s' "$out" | cut -f2)"
  cands="$(printf '%s' "$out" | cut -f3- | tr '\t' '\n' | sed '/^$/d')"
  case "$mode" in
    top)   subject="${commit:-$(printf '%s\n' "$cands" | head -1)}"
           printf '%s\n' "$subject" | grep -Eq -- "$regex" && ok=1 || ok=0 ;;
    in5)   printf '%s\n' "$cands" | grep -Eq -- "$regex" && ok=1 || ok=0 ;;
    none5) if [ -z "$cands" ]; then ok=0
           else printf '%s\n' "$cands" | grep -Eq -- "$regex" && ok=0 || ok=1; fi ;;
    *)     ok=0 ;;
  esac
  if [ "$ok" = 1 ]; then printf 'ok    %-36s %s\n' "$keys" "$mode"
  else failed "$(printf '%-36s %s /%s/  got: %s' "$keys" "$mode" "$regex" \
    "$(printf '%s' "$out" | cut -f2- | tr '\t' ' ')")"; fi
done 3< "$WORK/cases"

# 5. Grammar model: prove the named file loaded, or prove the fallback equals no grammar.
if [ "$GRAM" = 1 ]; then
  grep -F "loading gram db: " "$WORK/log" | grep -qF "/$MODEL" || failed "grammar model $MODEL was not opened"
  grep -qE 'gram_db\.cc:[0-9]+\] found double array image' "$WORK/log" || failed "grammar model did not map"
  [ "$gram_cases" -gt 0 ] || failed "no @gram cases were checked"
  report_errors "" "$(engine_errors "$WORK/log" 0)"
else
  grep -F "error opening gram db " "$WORK/log" | grep -qF "/$MODEL'." ||
    failed "expected the missing-model diagnostic for $MODEL"
  report_errors "" "$(engine_errors "$WORK/log" 1)"
  stage "$WORK/control"
  awk '/^grammar:/{skip=1; next} skip && /^[^ #]/{skip=0} !skip' \
    "$WORK/control/rime_ice.schema.yaml" > "$WORK/schema" &&
    mv "$WORK/schema" "$WORK/control/rime_ice.schema.yaml"
  ! grep -q '^grammar:' "$WORK/control/rime_ice.schema.yaml" || failed "control still has a grammar block"
  deploy_run "$WORK/control" "$WORK/keys" "$WORK/control.out" "$WORK/control.log"
  report_errors "control" "$(engine_errors "$WORK/control.log" 0)"
  paste "$WORK/cases" "$WORK/out" | awk -F'\t' '$4 !~ /@clock/' | cut -f5- > "$WORK/a"
  paste "$WORK/cases" "$WORK/control.out" | awk -F'\t' '$4 !~ /@clock/' | cut -f5- > "$WORK/b"
  if [ -s "$WORK/a" ] && cmp -s "$WORK/a" "$WORK/b"; then
    echo "ok    fallback without model == no grammar block ($(wc -l < "$WORK/a" | tr -d ' ') rows)"
  else failed "fallback differs from no-grammar control:"; diff "$WORK/a" "$WORK/b" | head -10; fi
fi

echo "---"
echo "$checked of $n cases checked, $fail failed (grammar model: $([ "$GRAM" = 1 ] && echo on || echo off))"
[ "$fail" = 0 ]
