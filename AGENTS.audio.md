# @kama/audio — what is true in THIS repo

The two generated files carry the general rules: `AGENTS.md` is the language, and `AGENTS.package.md` is the half a
publishable library needs. `kama agents install` writes both, and a re-install rewrites them, so they are **not**
hand-edited. This file is the project-specific third, and it is the one to edit.

## What this is

**An audio library for kama, on the browser's Web Audio and the same API natively:** playback, mixing, effects and
spatial sound. It names no engine concept, so a tool, an editor, a product or a game can use it. In the owner's words
(2026-11-13): "Then other apps can use the same audio engine."

It is the audio half of kyoten's rule that each engine module is built on a general-purpose library (kyoten's
`../kyoten/docs/design/architecture.md` § Decided, 2026-11-02), as `@kama/graphics` is for rendering. Its first users:
- **cosmic-forge**, whose page cannot play a loop exact to the sample through an `<audio>` element (its
  `../cosmic-forge/docs/KAMA_GAPS.md` CF-24);
- **kyoten's audio module** (kyoten's KYR-15), which binds kyoten's components and phases to it;
- later, **kyoten's DAW tool** (KYR-35).

## Where things stand

**Seeded on 2026-11-13 with `kama seed` on kama 0.9.938+g94365be5 (kyoten's pin). Nothing is built.** A design pass
comes before any code, as `@kama/graphics`' did.

**It is designed and built on the Mac Mini, in parallel with kyoten's graphics track on Windows** (the owner,
2026-11-13: "the mac kyoten clone can then design it and develop it in parallel to what we are doing here for
graphics").

## The design pass: what is open

Each question is measured first where it can be (a probe on both legs, as `@kama/gpu`'s were), then asked of the owner
in full: the problem, an example, the options and the production answer. The answers are recorded here with their
reasons, and the rows they create go in a `ROADMAP.md` (ids `AUD-<n>`). kyoten's `../kyoten/docs/design/audio.md`
lists the questions as kyoten first wrote them:

1. **The interface.** A graph of nodes, as Web Audio is (sources, gain, filters, panners, a destination), or a smaller
   API (play this sound here, on this bus) over one? Web first: designed against Web Audio's own concepts.
2. **Custom DSP.** An `AudioWorklet` on the web, kama compiled to wasm inside it, and a native audio callback: the
   same kama DSP code on both? A worklet fed through a `SharedArrayBuffer` needs the page cross-origin isolated
   (COOP and COEP).
3. **The native engine.** What implements the API natively. Candidates to measure, none decided:
   - **web-audio-api-rs**, which implements Web Audio's spec natively and runs its official test suite (1.5 on
     docs.rs, checked 2026-11-13); Rust, with no C API, so it would need a shim, as wgpu-native is Rust behind one;
   - **miniaudio**, the device both of the owner's games already use, with its own node graph and spatializer; the
     Web Audio-shaped graph would then be kama's own, over its device;
   - the OS APIs directly (WASAPI, Core Audio, AAudio, PipeWire).
4. **The leading edge.** The owner asked for "the most cutting edge audio (webaudio 2?)". There is no Web Audio 2:
   its v2 work became **Web Audio API 1.1**, a W3C Working Draft since November 2024, which adds `setSinkId` (choosing
   the output device) and a configurable render quantum (`renderSizeHint`, 128 frames by default, or the hardware's).
   Which browsers ship which of it is measured, in the pinned browsers and Safari.
5. **Spatial sound and the listener:** Web Audio's `PannerNode` (HRTF) on the web; natively, the engine's own or a
   library such as Steam Audio (its licence to be checked).
6. **Decoding:** the browser's own (`decodeAudioData`, WebCodecs' `AudioDecoder`) on the web, and natively a decoder
   per format (Opus, Vorbis, FLAC, WAV).
7. **What the peers already have:** both games' audio is a miniaudio pull on its own thread behind a lock-free command
   ring, with the identical synth entry pumped from the frame on the web (kyoten's
   `../kyoten/docs/research/peer-games.md` § platform split). kama's real-time constraints (`@noheap`, a lock window
   that cannot wait) are in `../kyoten/docs/research/kama-for-engines.md`.

What stays kyoten's, not this package's: how kyoten's frame phases schedule sound (Output, timestamps a little ahead),
its components, and the DAW. Those questions stay in kyoten's `audio.md`.

## Where the truth is

- **kyoten's decisions on it:** `../kyoten/docs/design/audio.md` § Decided, and `architecture.md` § Decided
  (the library pattern and the `@kama/<noun>` name).
- **The sibling packages show the shape to follow:** `../kama-gpu` and `../kama-window` (a `SPEC.md` of what is built,
  a `ROADMAP.md` of the order of work, `ROADMAP_DETAIL.md`, this file's record of decisions, `tests/` as one program,
  `tools/test.sh` as the gate on every leg, and `tools/browsers.mjs` for the browser legs).
- kama's own guidance: `AGENTS.md` and `AGENTS.package.md`, and <https://kama-lang.org/llms.txt>.

## Rules

- **Web first, native at parity, and lean on the web:** the web build uses Web Audio, and a native library stays
  native-only, adding nothing to the web build. A proposal for a native library says what the web uses instead.
- **The bar is the state of the art,** and a budget is a measurement, never a cap (kyoten's `AGENTS.kyoten.md`
  § Rules). A recommendation is the production answer, or says plainly that it is a stopgap and names what replaces it.
- **Test-driven, with one full suite** (`tools/test.sh`, once there is code): a change starts with a test that fails
  without it, and a case green on its first run is proved by mutation.
- **A test or a probe makes no sound the owner hears, and never takes the focus.** The owner works while suites run:
  render offline (an `OfflineAudioContext`, a null device) and compare samples. Anything audible waits for the owner
  and says so first.
- **Name no engine.** Nothing here names kyoten or a game.
- **Never edit `../kama` from here.** A compiler or std gap goes in [KAMA_GAPS.md](KAMA_GAPS.md), with a minimal repro
  and the kama version.
- **Verify, don't trust.** Compile the snippet, run it, read the emitted C. A doc is not evidence, including this one.
- **Commit on `main`, and push only when the owner asks.**

## Two machines

This repository is the Mac's row; kyoten's graphics track (`@kama/gpu`, `@kama/graphics`) is the Windows box's. Pull
before work and push after each commit. Audio's records live here. kyoten's docs get only what binds kyoten: a
decision recorded in `audio.md`, and the KYR-15 row. kyoten's hot spots, `FIRST-SLICE.md` § Where it stands and each
`ROADMAP.md`'s next id, are where two machines collide, so change them in a commit of their own, pulled first.

## Build

    kama check kama.json

kyoten builds with its own pinned kama (`../kyoten/.kama-version` names the commit, and its `AGENTS.kyoten.md` § Build
says how to make the pin from a clean clone). On macOS, build that commit the same way. A web build needs emscripten's
`emcc`.
