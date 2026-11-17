#!/usr/bin/env bash
# tools/test.sh — @kama/audio's gate, run before every commit:
#   - the feature map and the roadmap held to their rules (tools/check-features.sh, tools/check-roadmap.sh);
#   - `kama check` on the package and on its tests program;
#   - the tests program (tests/, one program) built debug and release and run natively;
#   - the tests program built for wasm, debug and release, and run under node.
#
# Every wasm leg runs a debug build and a release build, as every native leg does (kyoten's rendering.md § Decided,
# 2026-11-17, the owner's "(A) Debug + release"): since kama 0.9.966 (KR-289) a wasm release runs Closure over its JS,
# and a program ships that build. A release build's JS that still names emscripten's `ENVIRONMENT_IS_NODE` was not run
# through Closure, and fails; the debug build's must still name it, or the check could no longer tell.
#
#   tools/test.sh
#
# Run it from msys2 UCRT64 on Windows (bash -lic, so emcc and node are on PATH for the wasm leg), or any shell
# elsewhere. kama is $KAMA, or kyoten's pin beside this repository (../kyoten/.kama-pin), never kyoten's tools/kama
# shim, which reads $KAMA itself. Without emcc or node the wasm leg is skipped, and says so. Nothing here makes a sound
# or takes the focus: every render is offline.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) EXE=.exe ;;
    *) EXE= ;;
esac
if [ -n "${KAMA:-}" ]; then :
elif [ -x "$ROOT/../kyoten/.kama-pin/kama$EXE" ]; then KAMA="$ROOT/../kyoten/.kama-pin/kama$EXE"
elif command -v kama >/dev/null 2>&1; then KAMA=kama
else echo "test: no kama (set KAMA to kyoten's pin, ../kyoten/.kama-pin/kama)" >&2; exit 1
fi
echo "test: $("$KAMA" --version)"

OUT="$ROOT/tests/out"
mkdir -p "$OUT"
failed=0
step() { echo; echo "== $*"; }

step "the feature map"
tools/check-features.sh || failed=1

step "the roadmap"
tools/check-roadmap.sh || failed=1

step "kama check"
"$KAMA" check kama.json || failed=1
"$KAMA" pkg install tests/kama.json > /dev/null
"$KAMA" check tests/kama.json || failed=1

for mode in debug release; do
    step "tests, native, $mode"
    flag=""
    [ "$mode" = release ] && flag="--release"
    exe="$OUT/native-$mode/audiotests$EXE"
    if "$KAMA" build tests/kama.json $flag -o "$exe" > "$OUT/build-$mode.log" 2>&1; then
        "$exe" || failed=1
    else
        tail -n 20 "$OUT/build-$mode.log"
        failed=1
    fi
done

# Whether Closure ran over a wasm build's JS. emscripten's runtime always declares `ENVIRONMENT_IS_NODE`, and only
# Closure renames it. A release that still names it was never run through Closure (a root manifest's
# `"release": { "closure": false }` would do that), so the leg would test nothing of what a program ships.
# `UTF8ToString`, kyoten's marker, cannot serve here: this program never calls it, so emscripten's own dead-code pass
# drops it from a release built without Closure too.
closured() {
    local js="$1" mode="$2"
    if [ "$mode" = release ]; then
        if grep -q 'ENVIRONMENT_IS_NODE' "$js"; then
            echo "FAIL tests, wasm, release: $js still names ENVIRONMENT_IS_NODE, so Closure never ran over it"
            failed=1
        else
            echo "ok   tests, wasm, release: Closure ran over $js"
        fi
    elif ! grep -q 'ENVIRONMENT_IS_NODE' "$js"; then
        echo "FAIL tests, wasm, debug: $js does not name ENVIRONMENT_IS_NODE, so the release leg's check can no longer tell"
        failed=1
    fi
}

for mode in debug release; do
    step "tests, wasm, $mode, under node"
    if command -v emcc >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
        flag=""
        [ "$mode" = release ] && flag="--release"
        js="$OUT/wasm-$mode/audiotests.js"
        if "$KAMA" build tests/kama.json $flag --target WASM -o "$js" > "$OUT/build-wasm-$mode.log" 2>&1; then
            node "$js" || failed=1
            closured "$js" "$mode"
        else
            tail -n 20 "$OUT/build-wasm-$mode.log"
            failed=1
        fi
    else
        echo "skip no emcc or node on PATH (run from an interactive UCRT64 shell on Windows, bash -lic)"
    fi
done

echo
if [ "$failed" = 0 ]; then echo "test: all passed"; else echo "test: FAILED"; fi
exit "$failed"
