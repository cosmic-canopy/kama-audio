#!/usr/bin/env bash
# tools/test.sh — @kama/audio's gate, run before every commit:
#   - the feature map and the roadmap held to their rules (tools/check-features.sh, tools/check-roadmap.sh);
#   - `kama check` on the package and on its tests program;
#   - the tests program (tests/, one program) built debug and release and run natively;
#   - the tests program built for wasm and run under node.
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

step "tests, wasm, under node"
if command -v emcc >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
    if "$KAMA" build tests/kama.json --target WASM -o "$OUT/wasm/audiotests.js" > "$OUT/build-wasm.log" 2>&1; then
        node "$OUT/wasm/audiotests.js" || failed=1
    else
        tail -n 20 "$OUT/build-wasm.log"
        failed=1
    fi
else
    echo "skip no emcc or node on PATH (run from an interactive UCRT64 shell on Windows, bash -lic)"
fi

echo
if [ "$failed" = 0 ]; then echo "test: all passed"; else echo "test: FAILED"; fi
exit "$failed"
