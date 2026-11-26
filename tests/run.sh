#!/usr/bin/env bash
# Regression tests for this Rime config, run on a real librime engine.
#
#   bash tests/run.sh                  # Squirrel's librime; grammar model if installed
#   RIME_SKIP_GRAM=1 bash tests/run.sh # test without the grammar model
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

fail=0
failed() { fail=$((fail + 1)); echo "FAIL  $*"; }

# 1. Repo policy: trimmed upstream files must stay out of the index.
stray="$(git -C "$ROOT" ls-files | grep -E \
  '^(double_pinyin|t9\.|symbols_caps_v|recipe\.yaml|AGENTS\.md|others/|\.github/(ISSUE_TEMPLATE|workflows)/|cn_dicts/41448|en_dicts/cn_en_.|lua/(cn_)?en_spacer)' || true)"
if [ -n "$stray" ]; then failed "trimmed files are tracked:"; printf '      %s\n' $stray; fi

# 2. Build the harness once per source change.
mkdir -p "$CACHE"
for h in rime_api.h rime_api_deprecated.h rime_api_stdbool.h; do
  [ -f "$CACHE/$h" ] || curl -fsSL -o "$CACHE/$h" \
    "https://raw.githubusercontent.com/rime/librime/$LIBRIME_TAG/src/$h" || [ "$h" != rime_api.h ]
done
if [ ! -x "$CACHE/harness" ] || [ "$ROOT/tests/harness.c" -nt "$CACHE/harness" ]; then
  cc -o "$CACHE/harness" "$ROOT/tests/harness.c" -I "$CACHE" \
    "$RIME_LIB" -Wl,-rpath,"$(dirname "$RIME_LIB")"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/rime-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Stage tracked + untracked-but-not-ignored files (no userdb, build, custom).
stage() {
  mkdir -p "$1/build"
  (cd "$ROOT" && git ls-files -z -co --exclude-standard | xargs -0 tar -cf - --) |
    tar -xf - -C "$1"
}
deploy_run() { # data_dir keys_file out_file log_file
  "$CACHE/harness" "$1" "$RIME_SHARED" rime_ice < "$2" > "$3" 2> "$4"
}

stage "$WORK/data"
GRAM=0
if [ -z "${RIME_SKIP_GRAM:-}" ] && [ -f "$ROOT/$MODEL" ]; then
  ln -s "$ROOT/$MODEL" "$WORK/data/$MODEL"
  GRAM=1
fi

# 3. Collect cases: keys<TAB>mode<TAB>regex[<TAB>tags]
: > "$WORK/keys"; : > "$WORK/cases"; gram_cases=0
while IFS=$'\t' read -r keys mode regex tags; do
  case "$keys" in ''|'#'*) continue ;; esac
  case " ${tags:-} " in *" @gram "*) [ "$GRAM" = 0 ] && continue; gram_cases=$((gram_cases + 1)) ;; esac
  printf '%s\n' "$keys" >> "$WORK/keys"
  printf '%s\t%s\t%s\t%s\n' "$keys" "$mode" "$regex" "${tags:-}" >> "$WORK/cases"
done < "$ROOT/tests/cases.tsv"

deploy_run "$WORK/data" "$WORK/keys" "$WORK/out" "$WORK/log"

# 4. Check each case.
n=0
while IFS=$'\t' read -r keys mode regex tags <&3 && IFS= read -r out <&4; do
  n=$((n + 1))
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
done 3< "$WORK/cases" 4< "$WORK/out"

# 5. Grammar model: prove it loaded, or prove the fallback equals no grammar.
if [ "$GRAM" = 1 ]; then
  grep -q 'found double array image' "$WORK/log" || failed "grammar model did not load"
  [ "$gram_cases" -gt 0 ] || failed "no @gram cases ran"
else
  stage "$WORK/control"
  awk '/^grammar:/{skip=1; next} skip && /^[^ #]/{skip=0} !skip' \
    "$WORK/control/rime_ice.schema.yaml" > "$WORK/schema" &&
    mv "$WORK/schema" "$WORK/control/rime_ice.schema.yaml"
  deploy_run "$WORK/control" "$WORK/keys" "$WORK/control.out" "$WORK/control.log"
  paste "$WORK/cases" "$WORK/out" | awk -F'\t' '$4 !~ /@clock/' | cut -f5- > "$WORK/a"
  paste "$WORK/cases" "$WORK/control.out" | awk -F'\t' '$4 !~ /@clock/' | cut -f5- > "$WORK/b"
  if cmp -s "$WORK/a" "$WORK/b"; then echo "ok    fallback without model == no grammar block"
  else failed "fallback differs from no-grammar control:"; diff "$WORK/a" "$WORK/b" | head -10; fi
fi

# 6. Engine errors fail the run; a missing model is expected when it is absent.
errors="$(grep -E '^E' "$WORK/log" || true)"
[ "$GRAM" = 0 ] && errors="$(printf '%s\n' "$errors" | grep -vE '\.gram|grammar database' || true)"
if [ -n "$errors" ]; then
  failed "engine errors ($(printf '%s\n' "$errors" | wc -l | tr -d ' ') lines):"
  printf '%s\n' "$errors" | sed -E 's/^E[0-9]+ [0-9:.]+ +0x[0-9a-f]+ //' |
    cut -c1-200 | sort | uniq -c | sort -rn | head -10
fi

echo "---"
echo "$n cases, $fail failed (grammar model: $([ "$GRAM" = 1 ] && echo on || echo off))"
[ "$fail" = 0 ]
