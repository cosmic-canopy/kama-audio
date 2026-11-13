# @kama/audio — what is true in THIS repo

The two generated files carry the general rules: `AGENTS.md` is the language, and `AGENTS.package.md` is the half a
publishable library needs. `kama agents install` writes both, and a re-install rewrites them, so they are **not**
hand-edited. This file is the project-specific third, and it is the one to edit.

## What this is

**An audio library for kama, on the browser's Web Audio and the same API natively:** playback, mixing, effects and
spatial sound. It names no engine concept, so a tool, an editor, a product or a game can use it. In the owner's words
(2026-11-13): "Then other apps can use the same audio engine." And on the Mac, the same day: "This will be a general
purpose audio package that can be used in DAWs and Kyoten game engine or any other application … it should be low
overhead on web by using the state of the art native web API for the purpose. Then the native side will be abstracted
by the same interface." So the bar is two at once: what a DAW's engine and a game's middleware do, and the least
overhead the web allows.

It is the audio half of kyoten's rule that each engine module is built on a general-purpose library (kyoten's
`../kyoten/docs/design/architecture.md` § Decided, 2026-11-02), as `@kama/graphics` is for rendering. Its first users:
- **cosmic-forge**, whose page cannot play a loop exact to the sample through an `<audio>` element (its
  `../cosmic-forge/docs/KAMA_GAPS.md` CF-24);
- **kyoten's audio module** (kyoten's KYR-15), which binds kyoten's components and phases to it;
- later, **kyoten's DAW tool** (KYR-35).

## Where things stand

**Seeded on 2026-11-13 with `kama seed` on kama 0.9.938+g94365be5 (kyoten's pin). Nothing is built.** A design pass
comes before any code, as `@kama/graphics`' did. **Its research is done and measured (2026-11-13, [RESEARCH.md](RESEARCH.md)).
Area 1 is decided (§ Decided, 1 and 2).**

**The next session starts area 2** (the owner, 2026-11-13: a session begun in plan mode). Read § Decided, then
[RESEARCH.md](RESEARCH.md) § 1 (the peers' ring and mixers) and § 5 (kama for real time). Then plan area 2's probes,
listed under it below, run them, and ask the area in full. The Mac's toolchain (emsdk's Python, Homebrew's paths, the
pinned browsers) is in kyoten's `AGENTS.kyoten.md` § Build, *On macOS*. Waiting, and not area 2's:
- Safari's measurements, which take the owner's focus, so ask first;
- a long convolution reverb's cost as a built-in node against the worklet (area 4);
- KAUD-1 and KAUD-2 upstream.

**It is designed and built on the Mac Mini, in parallel with kyoten's graphics track on Windows** (the owner,
2026-11-13: "the mac kyoten clone can then design it and develop it in parallel to what we are doing here for
graphics").

## The design pass: what is open

Each question is measured first where it can be (a probe on both legs, as `@kama/gpu`'s were), then asked of the owner
in full: the problem, an example, the options and the production answer. The answers are recorded here with their
reasons, and the rows they create go in a `ROADMAP.md` (ids `AUD-<n>`). kyoten first wrote the questions in its
`../kyoten/docs/design/audio.md`.

**The evidence is [RESEARCH.md](RESEARCH.md)** (2026-11-13): the peers' audio, Web Audio measured in Chrome 157 and
Firefox 160, the sources' picture of Safari and the leading edge, the native engines and their licences, and what kama
0.9.938 gives a real-time library. What it found that shapes every area:
- **The browsers' built-in nodes do not make the same sound** (§ 2.3): resampling, sub-sample starts, HRTF, the
  compressor and the waveshaper differ materially between Chrome and Firefox. An AudioWorklet running the same code
  makes identical samples in both.
- **One wasm worklet mixing N voices costs 2.7 to 4 times less than N voices of built-in nodes,** and within 14 to 18%
  of the same C natively (§ 2.4).
- **kama compiled to wasm already runs as an AudioWorklet's processor** through emscripten's Wasm Audio Worklets, and
  `@onPanic` keeps audio running through a panic (§ 2.5).
- **Web Audio 1.1 ships in Chrome only** (§ 2.1, § 3); Safari's WebCodecs fails FLAC and Vorbis (§ 3); cross-origin
  isolation keeps cross-origin WebSockets, which the peers had feared it would not (§ 2.6).
- **Natively, the clean stack is permissive end to end:** miniaudio's device layer (with a custom-backend seam for a
  private console package), Steam Audio (Apache-2.0), libopus and the dr_libs. web-audio-api-rs has no C API, cannot
  reach consoles and requires an MPL dependency; the ASIO SDK is GPLv3 or proprietary, so ASIO is a separate package
  if ever (§ 4).

The areas, each asked in full in turn (area 1 first):

1. **The engine and its tiers.** Both answers play through Web Audio; they differ in which half of it does the DSP.
   Wire Web Audio's built-in nodes on the web and reimplement them natively, or run **one engine written in kama on
   both legs**: the processor of one `AudioWorkletNode` (Web Audio's programmable node) on the web, called by
   the device's callback natively, with Web Audio supplying what only the browser can (the audio thread, the output
   device, the microphone, decoding where it is reliable, MIDI)? **Decided: one engine in kama (§ Decided, 1).** And
   its tiers: Web Audio's graph (a context, nodes, `AudioParam`s with the spec's automation) with a tier above it for
   sounds, voices, buses, snapshots and emitters, as `@kama/graphics` has a flat core with a scene graph on it?
   **Decided: two tiers in this package (§ Decided, 2).**
2. **The object model, the names and the real-time model.** What it settles:
   - **The names.** Web Audio's in the lower tier wherever the concept is the same (context, node, param, buffer, and
     each node's own). The middleware's in the upper tier (sound, voice, bus, snapshot, emitter, listener).
   - **Ownership.**
     - The context is a resource.
     - A node or a buffer is either a handle into a slot map with generations, or a shared count.
     - When it dies: a Web Audio node outlives the program's last reference while it plays or has a tail.
     - Freeing happens off the audio thread.
   - **The real-time model.**
     - Commands to the audio thread are stamped in sample frames, as `int64`: TMM's `int32` counters overflow after
       about 12.4 h at 48 kHz, which a DAW reaches.
     - They go on a ring that never blocks. What an overflow does is open: the peers drop the command and count it.
     - The way back carries a sound's end, the meters and a playhead.
     - Where the upper tier runs: on the control side, with the audio side only executing, or on an update thread of
       its own, as FMOD Studio's does.
   - **A program's own DSP:** kama implementing a contract shaped like `AudioWorkletProcessor.process`, held to
     `@noheap` and, once kama has it, to a no-blocking proof (KAUD-2).

   **Measured first**, in `.scratch/aud-probe-*/`, headless and muted in Chrome for Testing 157 and Firefox 160:
   1. Commands into the worklet: a `SharedArrayBuffer` ring polled each quantum against `port.postMessage`. Measure
      the latency and jitter in quanta, with the main thread idle and then busy with a frame's work.
   2. The way back: the same two routes, for a sound's end and for meters.
   3. Allocation on the audio thread: emscripten's `malloc` and `free` inside a Wasm Audio Worklet while the main
      thread allocates. With shared memory the allocator takes a lock, which is what freeing off the audio thread
      guards against. Measure the worst case a quantum.
   4. A page that cannot be isolated (`-sENVIRONMENT=worklet`, no shared memory), where `postMessage` is all that is
      left. This is area 3's input, measured here because the probe is the same.
   5. The peers' ring written in kama on 0.9.938, with `Atomic` `int64` counters, acquire and release, natively and on
      wasm with shared memory, reading the emitted C.

   **Known before measuring** (RESEARCH.md § 5):
   - std has no lock-free single-producer ring (`Channel` is one mutex), so the rings are this package's.
   - Module statics are thread-local, so the audio side's state travels through the pointer C hands the callback.
   - A program that spawns runs `main` in a worker, where `AudioContext` does not exist. The seam's route, a JS
     library function with `__proxy: 'sync'`, is not yet probed.
3. **The two legs.** On the web: shared memory when the page is isolated, and emscripten's worklet without shared
   memory when it cannot be; Web Audio 1.1's features used where present and reported, never required; Safari's
   quirks (the audio session, gestures). Natively: miniaudio's device layer only (low-latency modes, duplex, a null
   device for tests, a custom backend for consoles), and the render graph across cores natively where the web has one
   thread.
4. **The ladders:** spatial sound (HRTF from SOFA data in kama on both legs, Steam Audio natively for occlusion and
   rooms, equal-power panning), decoding (WebCodecs where it works, kama-built decoders where it does not, the OS's
   AAC natively), resampling quality, and streaming.
5. **The feature map and the order of work:** a `FEATURES.md` from Web Audio, the middleware and the DAW engines, and a
   `ROADMAP.md` by example: a sample-exact loop (cosmic-forge's CF-24), a game's sounds, voice chat, a synth on MIDI, a
   multitrack session with automation and bounce, and spatial sound on a headset. Whether a DAW's engine (transport,
   tracks, clips, plugin hosting through CLAP natively and WebCLAP on the web, delay compensation) is a tier here or a
   package of its own.

What stays kyoten's, not this package's: how kyoten's frame phases schedule sound (Output, timestamps a little ahead),
its components, and its DAW tool (KYR-35). This package must be able to serve a DAW; the DAW tool itself is kyoten's.
Those questions stay in kyoten's `audio.md`.

## Decided

1. **Decided on 2026-11-13: one engine, written in kama, on both legs** (area 1's first question). The owner first
   asked whether it meant getting sound out of the browser without its API ("How do you get sound out of the browser
   without using a browser API?"). Told that both options play through Web Audio and differ only in which half of it
   runs the DSP, the owner answered: "AH ok that makes much more sense. Yes I agree with your recommendation."
   - **Both legs play through the platform's own audio.** On the web, Web Audio supplies:
     - the audio thread, the output device and the clock (`AudioContext`, and `setSinkId` where present);
     - the microphone (`getUserMedia` into a `MediaStreamAudioSourceNode`);
     - decoding where it is reliable (`decodeAudioData`, WebCodecs);
     - MIDI (Web MIDI).

     The DSP is kama compiled to wasm, running as the processor of one `AudioWorkletNode`, Web Audio's programmable
     node, as a renderer is kama on WebGPU. The DSP is the mixing, the voices, the effects, spatial sound and
     sample-exact scheduling. Natively, the same kama runs in the device's callback; what implements the device is
     area 3.
   - **Why** ([RESEARCH.md](RESEARCH.md) § 2.3 to § 2.5):
     - The built-in nodes make different samples in each browser: their resamplers, HRTF data, compressors and
       oversampling differ. A native implementation could match the spec, but not "the browser", so neither a bounce
       nor a test comparing samples could hold between the legs. One worklet made the same samples in Chrome and Firefox.
     - Many voices mixed in one loop cost 2.7 to 4 times less than the same voices as built-in nodes, and came within
       14 to 18% of native.
     - The built-in set has no voice limits or stealing, no sidechain, no plugin hosting and no latency compensation.
       Built from nodes, each would be JavaScript on the main thread rewiring the graph.
   - **A built-in node is used only where a measurement shows it is the better tool and its differences between
     browsers do not matter,** each as a decision of its own. The likely first is a long convolution reverb, which is
     not yet measured: the browser may run part of it off the audio thread, which one worklet cannot.
   - **It keeps the web light,** as kyoten's vision asks ("The web build does not ship heavy features of its own").
     Everything the browser does best comes from Web Audio. The wasm carries only the DSP, and its size is measured as
     each feature enters. A budget is a measurement, never a cap.
2. **Decided on 2026-11-13: two tiers, in this one package** (area 1's second question). The owner: "Yes I take your
   recommendation. I like the split which is similar to what we are doing with kama graphics."
   - **The lower tier is Web Audio's graph:** a context, nodes, and `AudioParam`s with the spec's automation
     (`setValueAtTime`, the linear and exponential ramps, `setTargetAtTime`, `setValueCurveAtTime`). A DAW works here:
     a track is a clip player, its inserts, a fader and a bus, and an automation lane is a parameter's curve.
   - **The upper tier is what a game's middleware gives:** sounds with their variations, voices (limits, priority,
     stealing, virtual voices), buses, snapshots (a mix state such as music ducked under dialogue), and emitters with a
     listener for spatial sound. A game says what to play and where, as in "play this footstep here, on the effects
     bus", and the limit, the stealing, the attenuation and the ducking are settings, not wiring.
   - **The upper tier is built only on the lower tier's public API,** so a program that wants only the graph ignores
     it, and nothing the upper tier does is out of a graph user's reach. It names no engine concept: an emitter is
     audio's own word, and an engine binds its components to emitters.
   - **Why:**
     - Without the upper tier, every game solves voices, buses and ducking again.
     - As a second package, it would add a package to version and publish for code that runs in the same audio callback
       and the same wasm anyway.
     - The split is FMOD's: its Core API is channels and a DSP graph, and its Studio API adds events, buses and snapshots
       on top. It is also `@kama/graphics`', a flat core with a scene graph on it.
   - **Still open, in area 5:** whether a DAW's own engine (transport, clips, plugin hosting, delay compensation) is a
     tier here or a package of its own.

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
says how to make the pin from a clean clone, with the Mac's steps). Run it as `../kyoten/tools/kama`. A web build needs
emscripten's `emcc`. The probes in `.scratch/aud-probe-*/` each run with their `run.sh`, headless and muted, in the
pinned browsers in `~/browsers`.
