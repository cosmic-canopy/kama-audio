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
comes before any code, as `@kama/graphics`' did. **Its research is done and measured ([RESEARCH.md](RESEARCH.md)).
Areas 1 to 4 are decided (§ Decided, 1 to 26),** and their rows are in [ROADMAP.md](ROADMAP.md), AUD-1 to AUD-28.
Area 4 finished on 2026-11-14 with streaming (25, after P8) and a long convolution reverb (26, after P9).

**The next session is area 5: the feature map and the order of work** (§ The design pass, 5):
- a `FEATURES.md` drawn from Web Audio, the game middleware (FMOD, Wwise) and the DAW engines;
- the `ROADMAP.md` put in order by example: a sample-exact loop (cosmic-forge's CF-24), a game's sounds, voice chat, a
  synth on MIDI, a multitrack session with automation and bounce, and spatial sound on a headset;
- whether a DAW's engine is a tier here or a package of its own;
- speech, for kyoten's accessibility (KYR-76).

It is mostly a survey and an ordering, with no probe planned. Each question is still asked in full (the problem, an
example, the options, the production answer). Then the first rows are built, test-first.
- **Read first:** § Decided, § The design pass, 5, [ROADMAP.md](ROADMAP.md), and kyoten's `docs/design/audio.md` and
  `docs/design/accessibility.md` (its questions 4 and 5 are speech's).
- **The pin is 0.9.956 (`df5a6edf`) on both machines.**
  - The Windows box bumped kyoten's `.kama-version` to it on 2026-11-14, at the owner's word.
  - The Mac rebuilt it from a clean clone on 2026-11-15, and kyoten's `tools/test.sh` is green on it there.
  - P5 to P9 ran on 0.9.945, kept in kyoten's `.scratch/kama-pin-0.9.945`.
  - **KAUD-4 is fixed on the pin** (0.9.953, `54b44d61`, KR-390) and retired. A library's own flag is now its
    consumer's, so a build switch such as the worklet instance's can live in the library, with no re-declaration in
    the program. That removes one of KAUD-5's three causes. The other two remain: one build makes one artifact, and
    KR-327's shared-memory flag is still open.
  - On 0.9.956, KAUD-2 and KAUD-6 reproduce, and KAUD-1, KAUD-3 and KAUD-4 are retired.
- **What area 4 taught, which the build rows need:**
  - **kama's wasm release is `-Oz`, which no program can change (KAUD-6).** A kernel is an `unsafe fn` over raw
    pointers. Each wasm cost is measured at `-Oz` and at `-O3` through `.scratch/area4/tools/emcc`, which swaps the
    flag and nothing else (`KAMA_REAL_EMCC`, `KAMA_WASM_OPT`). The kama FFT cannot carry a long reverb's stages at
    `-Oz`; pffft can.
  - **Every leg makes the same samples with `reproducible-float`**, proved by hashes, and a C seam needs
    `-ffp-contract=off`, which the flag sends it. **But a C library that calls the platform's libm is still not
    reproducible:** pffft's twiddles came from `sinf` and differed between legs from 2,048 points up (RESEARCH.md
    § 9.6). Any vendored C that computes tables with libm gets the same check, and the same fix (double, rounded once,
    or the package's own math).
  - **Inputs that must be identical on every leg are written once natively** (`gen.c` in P7 and P9), since a C `sin`
    differs between legs.
  - **WebCodecs drops Opus's pre-skip itself** and keeps every codec's end padding and MP3's and AAC's priming
    (RESEARCH.md § 9.3, corrected on 2026-11-14).
  - **A seek is exact only with pre-roll beyond the decoder's own:** 1 s for Opus (§ 9.5). AUD-26 measures each codec.
- **Staged in `.scratch/` (git-ignored):**
  - `area4/rt/` is the real-time harness P8 and P9 built (library `area4rt`), with `check/` as its smoke test (the
    same hash natively and in both browsers). It provides:
    - the device natively (miniaudio on CoreAudio at 128 frames) and the Wasm Audio Worklet on the web;
    - each callback timed, and each phase's statistics printed as one row;
    - the device's own underruns (CoreAudio's overloads, Chrome's `playbackStats`) and the lag;
    - the load, workers (real-time and joined to the workgroup natively), files the page prefetches, a ring of
      frames, and the hash.

    **Its web clock is a spinning Wasm Worker at normal priority.** Under a loaded machine it stalls, so web maxima
    are upper bounds.
  - `aud-probe-stream/` (P8) and `aud-probe-convolver/` (P9), each with its `run.sh` and `summarize.py`. P9 holds the
    patched pffft (`app/csrc/pffft/`) and the per-size bit check (`pfbits/`).
  - `area4/`: `third_party/` (every candidate at a pinned tag), `steamaudio/`, `fixtures/` with `hrtf/` and
    `hrtfconv/`, `smoke/` (the libraries natively and in wasm), and `dsp/` (the shared kama DSP).
- **The Mac's toolchain** (emsdk's Python, Homebrew's paths, the pinned browsers) is in kyoten's `AGENTS.kyoten.md`
  § Build, *On macOS*.
  - ffmpeg 9.0.2 (Homebrew) has libopus, LAME and Apple's AAC encoder;
  - CMake 4 needs `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` for libsamplerate.
  - The machine is shared with the kama project's own session, whose test matrix lifts the load average to 5 to 21.
    A timing says what load it ran under.
- **The probes' harness** is in `.scratch/`:
  - `env.sh` sets the toolchain. In zsh, write a flag list out, since `$F` does not split;
  - `browsers.sh` runs a page headless and muted, with the autoplay switches that let a realtime context start.
    `CHROME_EXTRA`, `FF_EXTRA_PREFS` and `RUN_PATH` add flags, prefs, and the page and its query;
  - `serve.mjs` serves a page, isolated or not, and collects its printed rows;
  - a trusted click comes from `@kama/window`'s `tools/webtest.mjs`, as `aud-probe-context/act/` uses it;
  - KR-387 (0.9.943) lets `kama run --headless` start sound. But `kama run` serves one artifact, so the two-build web
    route still needs this harness (KAUD-5).
  - A manifest's paths may not leave the project with `..` (link a folder in instead), and `ldflags` paths resolve
    against the working directory. A published package vendors its C as `csources` instead.

Waiting, and not area 4's:
- **Safari's measurements, deferred by the owner** (2026-11-13: "we can do safari measurements later"). They take the
  owner's focus, so they are asked for, never planned into a session:
  - its gesture rule (decision 16);
  - isolation with `require-corp`;
  - its Web Audio 1.1 rows;
  - its decoders (area 4 records Safari's rows from the sources until then).
- A real microphone, on the owner's hardware with the owner's OK (macOS asks permission): its round trip, duplex, and
  each OS's echo cancellation (decision 18).
- WASAPI's exclusive and `IAudioClient3` modes, and MMCSS for render workers (decisions 17 and 19), on the Windows box.
- What `reproducible-float` costs the DSP (decision 14), once there is DSP.
- KAUD-2, KAUD-5 and KAUD-6 upstream.
- Area 4's open ends, each for when its row is built:
  - pffft's SSE path compared on the Windows box (decision 21), with its twiddles computed in double;
  - the loop fixture's MP3 that WebCodecs decodes 16 dB from ours (RESEARCH.md § 9.3);
  - MagLS with a covariance constraint for the SH HRIRs (§ 9.2);
  - a stream's bytes arriving progressively (AUD-27);
  - each other codec's exact seek (AUD-26);
  - the convolver's partition layout for other response lengths (AUD-28).

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
2. **The object model, the names and the real-time model.** **Decided (§ Decided, 3 to 11)**, after five probes measured
   on both legs (RESEARCH.md § 6):
   - **Names:** Web Audio's names and units.
   - **Ownership:** counted resources over slots with generations, and an audio thread that never waits on an
     allocator.
   - **Memory:** declared capacities and an injected allocator.
   - **Commands:** stamped on one ordered ring per context, by two routes. An overflow never drops and never blocks.
   - **The way back:** a ring of events and snapshots of levels.
   - **The upper tier** runs in `update()` on the program's thread.
   - **A program's own DSP** implements `AudioWorkletProcessor`, in the same quantum on both legs.
3. **The two legs.** **Decided (§ Decided, 12 to 19)**, after four probes measured on both legs (RESEARCH.md § 7):
   - **The web's routes:** both, the loader picking one by `crossOriginIsolated`.
   - **A program's processor:** registered by name, and built from plain-data options on whichever side runs the
     engine.
   - **Floats:** the program chooses `reproducible-float`.
   - **The block:** the engine's own, declared, the same on every leg. Web Audio 1.1's features are reported, never
     required.
   - **Starting:** the package unlocks the context on the first gesture.
   - **Natively:** miniaudio's device layer, with small seams of our own for what it lacks.
   - **Input:** Web Audio's model on both legs.
   - **Cores:** declared render workers natively, one thread on the web.
4. **The ladders: spatial sound, decoding, resampling and streaming.** Planned on 2026-11-13, and its parts are staged
   and smoke-tested (RESEARCH.md § 8). **Decided (§ Decided, 20 to 26).** A ladder is a feature in
   rungs from cheap to best. A program picks a rung per sound, and each rung is the same on every leg. Each question
   below is measured first, then asked in full.
   1. **Where a sound seems to come from.** **Decided (§ Decided, 20 and 21)** after P5 (`aud-probe-spatial/`,
      RESEARCH.md § 9.1):
      - the core is our own rungs in kama on both legs (panning, HRTF binaural, Ambisonics, and the room's inputs);
      - geometric acoustics is a later tier of this package, in kama;
      - the core's FFT is pffft, through the C seam.
   2. **Which HRTF data, and how a program brings its own.** **Decided (§ Decided, 22)** after P10
      (`aud-probe-hrtf/`, RESEARCH.md § 9.2, added at the session's start because the licence survey made the
      reduction the real question): a build-time converter, a default of SADIE II's D1 at about 1 MB, and reading
      SOFA at run time as an option.
   3. **Which code turns a file into samples, on each leg.** **Decided (§ Decided, 23)** after P6
      (`aud-probe-decode/`, RESEARCH.md § 9.3): our C decoders and containers on both legs, each codec a module, and AAC
      through the platform.
   4. **Changing a sound's rate, and its pitch.** **Decided (§ Decided, 24)** after P7 (`aud-probe-resample/`,
      RESEARCH.md § 9.4): our ladder in kama for every voice, and libsamplerate's best for converting a whole buffer.
   5. **Playing a long sound without loading it whole.** **Decided (§ Decided, 25):** our decoders on a decode thread on
      every leg, exact seeks, streams started on stamped frames.
      - *The problem:* 10 minutes of stereo at 48 kHz is 230 MB as floats. Music and dialogue are decoded a little
        ahead, off the audio thread, and the audio thread must never wait for the decoder.
      - *The options, per leg:*
        - natively, a decode thread fills a ring;
        - on the web's shared route, a Worker decodes (wasm or WebCodecs) into the shared ring;
        - on the page route, the Worker posts transferred buffers.
      - *Also:* sample-exact loops and seams between streamed sections, seeking, and starting a stream with no gap.
      - **Measured by P8** (`aud-probe-stream/`, RESEARCH.md § 9.5), on area 4's real-time harness
        (`.scratch/area4/rt/`):
        - no stream ran dry on any leg, at any ring size from 85 ms, idle or loaded. That held natively, on the shared
          route (a Wasm Worker into the shared ring) and on the page route (a decode Worker transferring buffers
          through a `MessagePort` straight to the worklet's instance);
        - the same samples on every leg, the loop's seam and the end's trim exact;
        - a seek lands on its frame but is exact only with 0.8 s more pre-roll than opusfile's own (200 of 200
          targets), which costs about 1 ms;
        - WebCodecs works on the page route, but its samples are not native's, and Firefox's takes 150 to 200 ms to
          start.
   6. **A long convolution reverb: the one built-in node in question** (decision 1). **Decided (§ Decided, 26):** our
      non-uniform partitioned convolver on every leg, and no `ConvolverNode`.
      - *The problem:* a concert hall's reverb is a 2 to 4 s impulse response, a heavy convolution. The browser's
        `ConvolverNode` may run part of it off the audio thread, which one worklet cannot.
      - **Measured by P9** (`aud-probe-convolver/`, RESEARCH.md § 9.6):
        - our non-uniform partitioned convolver with pffft, its work spread over the quanta, ran 32 halls in Chrome's
          worklet at kama's `-Oz` with no underrun. Chrome's `ConvolverNode` collapsed between 24 and 32;
        - ours and the browsers' sound the same: all are float32 convolutions, about 130 dB apart;
        - ours makes the same samples on every leg once pffft's twiddles are computed in double: as vendored, they
          come from the platform's `sinf`, which differs from 2,048 points up;
        - uniform partitions cost 10 to 30 times more;
        - the kama FFT cannot carry the long stages at `-Oz` (KAUD-6).
5. **The feature map and the order of work:** a `FEATURES.md` from Web Audio, the middleware and the DAW engines, and a
   `ROADMAP.md` by example: a sample-exact loop (cosmic-forge's CF-24), a game's sounds, voice chat, a synth on MIDI, a
   multitrack session with automation and bounce, and spatial sound on a headset. Whether a DAW's engine (transport,
   tracks, clips, plugin hosting through CLAP natively and WebCLAP on the web, delay compensation) is a tier here or a
   package of its own.
   - **Speech, for kyoten's accessibility** (KYR-76, the owner, 2026-11-14: "Speach to text, text to speach"):
     whether text to speech renders into this engine on every leg (a local voice model) or comes from the platform
     (Web Speech's synthesis, which bypasses Web Audio, or the OS's), and whether speech to text runs on this
     package's input node or in a speech package of its own. Its questions are in kyoten's
     `docs/design/accessibility.md` (4 and 5); the audio half is answered here.

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

3. **Decided on 2026-11-13: the lower tier keeps Web Audio's names and units** (area 2, the names). The owner took the
   recommendation.
   - **The types are Web Audio's interfaces verbatim:** `AudioContext`, `OfflineAudioContext`, `AudioNode`,
     `AudioParam`, `AudioBuffer`, `GainNode`, `AudioBufferSourceNode`, `AudioWorkletNode`, `AudioWorkletProcessor`,
     `AudioListener`. Their methods and parameters become kama's named arguments, so MDN documents the lower tier:
     `src.start(when:, offset:, duration:)`, `p.setValueAtTime(value:, startTime:)`.
   - **Its times are Web Audio's:** float64 seconds on the context's clock. Each is converted once, at the API, with
     one rounding rule, to an int64 sample frame, plus a sub-frame fraction for a source's start. So no counter
     overflows in a session of any length; the peers' `int32` frames last about 12.4 hours at 48 kHz.
   - **kama's conventions bind where kama has one:**
     - construction is `GainNode.make(context:, …)`, Web Audio's constructor form, and not `createGain()` as well;
     - properties follow `@kama/graphics`' `x()`/`xMut()` pairs.
   - **The upper tier has the middleware's words, in a module of its own** (proposed `audio::sound`): `Sound` (a
     definition with its variations), `Voice` (one playing instance, which may be virtual), `Bus`, `Snapshot` and
     `Emitter`. It reuses `AudioListener`, the same concept.
   - **Why:** one decided rule, "Web Audio's names wherever the concept is the same", as `@kama/graphics` takes
     three.js's. Frames as the public unit would turn every MDN example into a conversion, and a game thinks in
     seconds; a float64 second round-trips a frame exactly.
4. **Decided on 2026-11-13: counted resources for the program, slots with generations for the engine** (area 2,
   ownership). The owner took the recommendation.
   - **What the program holds.** A node or a buffer is a `type resource`: a copy shares it, and the last copy dropped
     releases it, as `@kama/gpu`'s handles and `@kama/graphics`' assets do.
   - **What the audio side sees.** Only a slot index and a generation, never a pointer.
   - **Where the count lives.** On the program's side only, so the audio thread never touches it. The program's side
     picks the slot, so creating a node needs no round trip, and the next command can name it in the same frame.
   - **When a node dies, Web Audio's rule.** After the last drop the audio side keeps the node while it can still
     sound: a scheduled or playing source until it ends, and any node with a live input or a tail not yet silent. It
     then reports the slot freed (decision 9), and the program's side reuses the slot with the next generation.
   - **The context.** It is a resource, and every node holds the context's state, as `@kama/gpu`'s children hold the
     device's. Web Audio's `close()` ends it early. A later call on one of its nodes is a reported error, never a trap
     (`@kama/gpu`'s decision 9: nothing a program passes ends it).
   - **Why:**
     - A number crosses every boundary the engine has: shared memory, the separate wasm instance of a page that cannot
       be isolated (decision 7), and later a plugin in its own process.
     - A count the audio thread decremented would make it the thread that frees.
     - A plain handle with an explicit release would leak a slot when forgotten, and would depart from the siblings'
       RAII.
5. **Decided on 2026-11-13: the audio thread never waits on an allocator** (area 2, ownership). The owner: "I think
   option 1."
   - **Where memory is shared (natively, and on an isolated page).** The program's side allocates everything the
     audio side will use before the command that hands it over: a node's state, delay lines, sample data and a
     program's processor (decision 11). It frees what the audio side hands back on the way back (decision 9). The audio
     thread never calls the allocator.
   - **Where it is not shared (a page that cannot be isolated).** The worklet's own wasm instance is the engine
     (decision 7), and it allocates only in its message handler, between quanta, where no other thread can hold its
     heap.
   - **Why** (RESEARCH.md § 6.3, § 6.4):
     - With shared memory one `malloc` on Firefox's audio thread waited 63.5 ms for emscripten's allocator lock (24
       quanta), and Chrome's worst was 0.9 ms.
     - mimalloc's tail was still 410 µs, and macOS natively reached 0.5 ms while the heap grew.
     - In an instance of its own, a `malloc` took 7 ns, with no lock anyone else can hold.
6. **Decided on 2026-11-13: declared capacities and an injected allocator** (area 2, ownership; asked because of the
   owner's question on decision 5). The owner asked: "Does kyotens design so far allow for the custom allocator usage?
   does it allow for pre-computed max total allocation?" kyoten's answer is yes for its own stores: a Budget record
   per (zone, layer, prefab), reserved up front or committed in controlled steps, and one block per zone once kama's
   KR-326 lands (kyoten's `components.md` question 6, KY-17). Nothing yet said how audio takes memory. Asked, the
   owner took the recommendation.
   - **Declared capacities.** Every limit is a field of the context's options: node slots, voices, the command ring,
     the backlog (decision 8), sample memory and streaming buffers. So the library's footprint is known when the
     context is created.
   - **An injected allocator.** Everything the library allocates (on the program's side, decision 5) comes from a kama
     `Allocator` the program hands the context, defaulting to the global heap. kyoten hands audio an `Arena` sized from
     a Budget record. A program that replaces the whole heap with `@globalAllocator` needs nothing more.
   - **At a limit, the answer is declared.** The upper tier steals a voice by its rules, or the call returns an error.
     The library never allocates past a limit and never drops silently.
   - **Why:** kyoten's vision asks for "a footprint you can calculate" and budgets per element. Dependency injection
     (kyoten's rule) is how a library takes what it depends on.
7. **Decided on 2026-11-13: stamped commands on one ordered ring per context, by two routes** (area 2, the real-time
   model). The owner took the recommendation.
   - **The commands.** Each call becomes a flat, typed command stamped with the int64 frame it applies at. One ring per
     context keeps them in order, levels with cues, as the peers' rings do. Only the thread that owns the context
     pushes, and that thread may be a worker.
   - **The routes.** The same bytes travel two ways:
     - natively and on an isolated page, through a ring in shared memory that the audio thread drains at the top of
       each quantum;
     - on a page that cannot be isolated, as one transferred `ArrayBuffer` per flush, sent to the engine's own
       instance in the worklet (`-sENVIRONMENT=worklet`, a second build of the program).
   - **Replay.** A recorded command stream replays offline, so a bounce and a test that compares samples are the same
     run.
   - **Why** (RESEARCH.md § 6.1, § 6.2, § 6.4):
     - The ring in kama passed 10⁷ commands in order on both legs, and its test caught a missing release on the M4.
     - It delivered every command in the next quantum in both browsers, idle or busy, and from a worker `main`.
     - emscripten's `postMessage` route was up to 6 quanta late in Firefox. It allocates an object per message, and
       only the page's thread can use it.
     - A page that cannot be isolated still gets each frame's commands within 2.4 quanta of the best case, and kama
       builds the worklet's instance with no gap.
8. **Decided on 2026-11-13: overflow never drops and never blocks** (area 2, the real-time model). The owner took the
   recommendation.
   - **The backlog.** Commands that do not fit the ring wait in order in a backlog on the program's side, flushed
     first on the next flush. Its high-water mark is counted.
   - **Its bound.** The backlog's size is a declared capacity (decision 6). Past it the call returns an error to the
     program; the command is never lost silently.
   - **A late command,** one whose frame has passed, applies at the next quantum and is counted as late.
   - **The audio side** only ever sees whole commands, in order, and never waits.
   - **Why:** the peers drop and count, which loses a stop (a stuck note) or a release (a leaked slot). A DAW cannot
     accept that, and the program could not see it at the call.
9. **Decided on 2026-11-13: the way back is a ring of events and snapshots of levels** (area 2, the real-time model).
   The owner took the recommendation.
   - **Events go on a second ring:** a sound's end, a slot freed, an error, and a buffer or processor handed back to
     free. It is sized from the slot capacity, so lifecycle events cannot overflow it: a slot frees at most once before
     the program reuses it.
   - **Levels are latest-value snapshots** the audio side overwrites every quantum, never queued: meters, and the
     playhead's frame with its output timestamp.
   - **The program polls both** in the context's `update()`, as `@kama/gpu` polls and `@kama/window` pumps. The engine
     never calls back into kama.
   - **Why** (RESEARCH.md § 6.2):
     - A snapshot was 1 quantum old when read.
     - An event polled once a frame arrived by the frame that acts on it.
     - 64 meters a quantum by `postMessage` is 24,000 messages a second from the audio thread, up to 12 quanta stale
       in Firefox.
10. **Decided on 2026-11-13: the upper tier runs in `update()`, on the program's thread** (area 2, the real-time
    model). The owner took the recommendation.
    - **What runs there.** The program calls the context's `update()` once a frame, as FMOD Studio's synchronous update
      is called. In it the upper tier steals voices, applies snapshots, moves emitters and computes attenuation, and
      turns "play this footstep here, on the effects bus" into lower-tier commands stamped a little ahead.
    - **The audio side only executes.**
    - **The library starts no thread of its own.** A program that wants FMOD's asynchronous update calls `update()`
      from a thread it owns, and the context moves there whole.
    - **Why:**
      - Dependency injection: nothing is hidden.
      - A page that cannot be isolated has no second thread.
      - A worker `main` drove the ring as promptly as the page's thread did (RESEARCH.md § 6.2).
      - A stamped command scheduled ahead makes the update's thread irrelevant to timing.
11. **Decided on 2026-11-13: a program's own DSP implements `type contract AudioWorkletProcessor`, in the same quantum
    on both legs** (area 2, a program's own DSP). The owner took the recommendation.
    - **The contract.** `fn bool process(inputs:, outputs:, parameters:)`, Web Audio's shape: planar `View<float32>`
      channels; an a-rate parameter as one value per frame, or one when it is constant; and a return value that keeps
      the node alive.
    - **The checks.** The contract member is `@noheap`, and the render callback's `fnptr` type is
      `@noheap @noparks`. KAUD-2's no-blocking proof joins them when kama has one.
    - **Its lifetime.** The processor is built on the program's side, moved to the audio side by the create command,
      and handed back to be dropped on the program's side (decision 5).
    - **One block size on both legs.** Natively the engine renders in the same quantum as the web, 128 frames or what
      `renderSizeHint` sets, with a FIFO in front of the device. So a processor sees identical blocks on both legs and
      the samples compare bit for bit. The FIFO adds up to 127 frames, and only when the device's buffer is not a
      multiple of the quantum.
    - **Why** (RESEARCH.md § 6.1): kama 0.9.938 refuses an implementation of a `@noheap` member that is not
      `@noheap`. Its walk follows a call through a contract value, even an `Owned<Processor>` held in a field, into
      every implementation, and refuses an allocation or a wait in any of them. A device-sized block would put k-rate
      parameters on different frames on each leg.
    - **Amended the same day:** decision 13 adds how a processor is made (and its lifetime on a page that cannot be
      isolated), and decision 15 makes "one block size" the engine's declared block.

12. **Decided on 2026-11-13: both web routes, the loader picking one** (area 3, the web). The owner took the
    recommendation.
    - **The shared route is the default.** On an isolated page:
      - one build of the program, its memory shared;
      - the `AudioContext` on the page's thread, and the engine as the processor of one `AudioWorkletNode` through
        emscripten's Wasm Audio Worklet;
      - commands through the ring (decision 7).
    - **A program that may land on a page that cannot be isolated also ships the pair:**
      - the program's build, its memory not shared, which only sends commands, one transferred `ArrayBuffer` a flush;
      - a second build of the same program for the worklet (`ENVIRONMENT=worklet`), which is the engine.
    - **The loader picks one at start by `crossOriginIsolated`,** as kyoten's `web-and-native.md` (§ Decided, item 5)
      already does for a threaded game and its single-threaded build.
    - **Until kama can build the second artifact (KAUD-5),** the package ships what a program copies:
      - the targets;
      - the worklet's entry points;
      - the loader page.

      The package's C seam picks its route when it compiles, by `__EMSCRIPTEN_WASM_WORKERS__`.
    - **Why** (RESEARCH.md § 7.1):
      - One source tree built both routes, and both made the same samples in Chrome and Firefox.
      - Shared memory alone would leave a page that cannot send the headers (an embed, some hosts) with no engine.
      - The unshared route alone would give up the ring's next-quantum delivery, a worker `main` driving audio, and
        the shared heap.
13. **Decided on 2026-11-13: a program's processor is registered by name and built from plain-data options** (area 3,
    a program's own DSP). The owner, asked whether this was the production answer and whether it changed decision 11:
    "I assume option 1 is the production answer?" Told it does, in part, the owner said to record it.
    - **Web Audio's model, on both routes.**
      - The program registers each processor type under a name, with a factory, as `registerProcessor` does.
      - A node is created with options that are plain data, as `processorOptions`.
      - The same program code works on either route.
    - **On an isolated page, decision 11 holds in full:** the program's side runs the factory, hands the processor over
      with the create command, and drops it when it comes back.
    - **On a page that cannot be isolated,** the worklet's own instance runs the same factory between quanta, from the
      create command's bytes, and drops the processor itself. Decision 5 already lets that instance allocate there.
    - **Why** (RESEARCH.md § 7.1): a processor built inside the worklet's instance from its options made the same
      samples as one built on the program's side. The other answers were to serialize a built processor whole, which
      kama has no general way to do, or to have no program DSP on such a page.
14. **Decided on 2026-11-13: the program chooses `reproducible-float`** (area 3, identical samples). The recommendation
    was that the package set it. The owner: "Is there a reason you didn't recommend option 2? It seems like the program
    that consumes the package should be able to decide? Kyoten will prefer reproducible... but some applications will
    not I assume." Re-examined, the owner was right, and the owner took the revised answer.
    - **The package sets no float mode.** `reproducible-float` is program-wide: no FMA contraction anywhere, and musl's
      math compiled in. A library setting it would impose it on every program.
    - **What it buys:** the same samples between builds, native against web and debug against release. A bounce
      already equals its own playback within one build, with or without it: the same code, block and bits.
    - **The package's own tests program sets it,** so its tests that compare legs hold. Its docs say what it buys.
      kyoten keeps it on.
    - **Why** (RESEARCH.md § 7.1): with it, native debug and release made the web's hash; without it, native release
      (fused multiply-adds, Apple's `sinf`) and native debug each made another.
15. **Decided on 2026-11-13: the engine renders in its own declared block; Web Audio 1.1's features are reported, never
    required** (area 3, the platforms' differences). The owner first asked what the problem was. Told that the block
    decides when a k-rate parameter changes, so a block that followed the browser would make a program sound different in
    Chrome and Firefox, the owner said: "it sounds like option 1 is the flexible and best production answer?", and
    confirmed it.
    - **The engine's block is the program's setting,** 128 frames by default, and the same on every leg. So a program's
      samples never depend on the browser or the device.
    - **The platform's callback size is only a request:** `renderSizeHint` on the web, the period natively. When the
      callback is a multiple of the block, the engine runs several blocks a call; otherwise a FIFO bridges them. On the
      Mac at 128, CoreAudio gave the period asked, so no FIFO was needed.
    - **Each Web Audio 1.1 feature is used where present and reported on the context, never required:**
      - `setSinkId`, and Firefox's `selectAudioOutput`;
      - `renderSizeHint`;
      - `onerror`;
      - `playbackStats`. Underruns are counted where the platform or the engine can count them (Chrome, natively),
        and reported as unknown elsewhere.
    - **Why** (RESEARCH.md § 7.2, § 7.3):
      - Chrome honours `renderSizeHint` from 64 to 512 and hands the worklet that block. Firefox always gives 128.
      - `latencyHint` moves Chrome's output latency from 17 to 33 ms; Firefox ignores it.
      - CoreAudio gave every period asked from 32 to 256 frames.
16. **Decided on 2026-11-13: the package unlocks the context on the first gesture** (area 3, starting). The owner took
    the recommendation.
    - **The unlock:** the package's page-side JS adds a one-shot listener for the first `pointerdown`, `keydown` or
      `touchend`, which calls `resume()` inside the handler. Every browser accepts that, Safari included.
    - **The program sees the context's state** (`suspended`, `running`, `interrupted`, `closed`) in `update()`, and may
      call `resume()` itself.
    - **iOS's audio session type** (whether the silent switch mutes it) is an option of the context.
    - **Why** (RESEARCH.md § 7.2):
      - In Chrome, with no gesture, `resume()` stays pending. After one click it works from anywhere, a worker's
        message and 6.5 s later included.
      - Safari is said to want `resume()` inside the handler (not yet measured), and the listener meets that.
17. **Decided on 2026-11-13: miniaudio's device layer natively, with small seams of our own** (area 3, the native
    device). The owner: "it sounds like option 1... we may eventually want to write our own in kama in the future."
    - **The vendoring:** miniaudio's sources (public domain or MIT-0), its device layer only (`MA_NO_DECODING`,
      `MA_NO_ENCODING`, `MA_NO_GENERATION`, `MA_NO_RESOURCE_MANAGER`, `MA_NO_ENGINE`, `MA_NO_NODE_GRAPH`). On Apple,
      `MA_NO_RUNTIME_LINKING`, with the frameworks linked directly, for notarization. Nothing reaches the web build.
    - **What miniaudio lacks, in small C seams of our own:**
      - render workers joined to the device's workgroup (decision 19);
      - device added and removed events, from CoreAudio's listeners, `IMMNotificationClient` and PipeWire.
    - **Consoles:** a console's private package implements miniaudio's custom-backend vtable.
    - **Tests:** a test renders offline. The null device is a smoke test of the seam only.
    - **The device seam is the package's own,** so kama-native backends can replace miniaudio later, as the owner
      foresees.
    - **Why** (RESEARCH.md § 4, § 7.3):
      - On CoreAudio it gave the period asked from 32 to 256 frames, with 8.7 ms of output latency at 128.
      - Its callback thread is real-time and already in the device's workgroup.
      - It compiles in 1.2 s and adds 121 KB, and a kama `@noheap @noparks` render recovered a forced panic in it.
      - The alternatives:
        - SDL 3 has shared-mode WASAPI only and no promised callback size, and `@kama/window`'s SDL is Windows-only
          with audio off;
        - writing each OS's backend now is much more code, with no console seam for free.
18. **Decided on 2026-11-13: input is Web Audio's model on both legs** (area 3, input). The owner took the
    recommendation.
    - **An input is a source node feeding the engine.**
    - **On the web:** `getUserMedia`'s stream, then a `MediaStreamAudioSourceNode`, then the engine's worklet input. The
      browser's processing (echo cancellation, noise suppression, gain control) is set by constraints.
    - **Natively:** a miniaudio capture or duplex device feeds the same node. Echo cancellation comes from the OS's voice
      processing where it has one (Apple's VoiceProcessingIO, Windows' communications capture, Android's
      `VOICE_COMMUNICATION`), measured with the voice-chat example.
    - **A real microphone waits for the owner's hardware and OK.**
    - **Why** (RESEARCH.md § 7.2): in both browsers a stream reached the worklet's input as planar 128-frame channels.
      Chrome turns its processing on by default, and each part turns off.
19. **Decided on 2026-11-13: declared render workers natively, one thread on the web** (area 3, cores). The owner: "I
    assume option 1 is the production grade... most flexible and most performant option?" Told it is (one thread is
    still cheaper for a small mix, which is why the default is 0), the owner's answer stood.
    - **The setting:** natively the render may use a declared number of render workers, an option of the context. 0,
      the default, means the device's own thread.
    - **The workers:** the package starts them as real-time threads joined to the device's workgroup (`os_workgroup`
      on Apple; MMCSS "Pro Audio" on Windows; `SCHED_FIFO` through rtkit on Linux). They are woken by a semaphore,
      never by spinning.
    - **The sum:** rows are summed in a fixed order, so the samples equal the one-thread render's.
    - **The exception to decision 10:** the library starts no thread except these. Only the audio side can make a
      thread that joins the device's workgroup.
    - **On the web the render stays on the worklet's one thread.**
    - **Why** (RESEARCH.md § 7.4):
      - 4 real-time workers joined to the workgroup ran a quantum in 0.34 to 0.44 ms against one thread's 1.1 to
        1.3 ms, with no overload idle or under full load, and the same bits.
      - Plain threads were slower than one thread and overloaded the device under load, and spinning workers failed.
      - On the web, Wasm Workers made a quantum slower (2.0 against 1.3 ms) and collapsed under load: 2,985 underruns
        in 16 s in Chrome.

20. **Decided on 2026-11-13: spatial sound is our own rungs, in kama, on both legs; geometric acoustics is a later tier
    of this package, also in kama** (area 4, question 1). The owner first asked: "Do we need Steam Audio? can we write
    our own? … I'm just curious what Steam Audio brings and if we can do it in kama better?" Told what Steam Audio adds
    (geometric acoustics from the scene's triangles), the owner asked where it would live, whether to use Steam Audio
    first, and how big a lift it is. Told the plan in one line, the owner took the recommendation.
    - **The core, now: four rungs in kama, the same on every leg.** Each rung is chosen per sound:
      - equal-power panning;
      - HRTF binaural: the HRIR blended from the grid's four nearest directions, minimum phase with each ear's onset as
        a fractional delay, convolved by partitioned FFT, crossfaded when the filters change;
      - Ambisonics: sources encoded into one field, rotated by the head's pose, decoded binaurally once;
      - the room's inputs, set by the program: distance and air absorption, occlusion and transmission as filters,
        reverb sends, and a slot for a reflection impulse response.
    - **The room's inputs are the seam.** Whatever computes acoustics (a program's own code, or the later tier) drives
      them through the same commands (decision 7).
    - **Geometric acoustics comes later, as a tier of this package, written in kama:**
      - occlusion and transmission by ray casts (small);
      - a reverb whose decay is estimated from rays bounced through the room (medium);
      - pathing around corners from a baked probe graph (medium to large);
      - convolution reflections, Ambisonic impulse responses traced per source or baked at probes (large).
      It takes triangles with acoustic materials and a ray-tracing contract, which a program fills with its own scene
      (kyoten with its physics scene, or a WebGPU tracer). kyoten's part is only the binding. It runs on the program's
      side, never on the audio thread. When a program first needs it, it gets its own probe, with Steam Audio as the
      reference. At Steam Audio's quality it is the package's biggest feature.
    - **No Steam Audio wrapper first:** nothing that uses this package needs it yet.
    - **Why** (RESEARCH.md § 9.1):
      - The kama renderer made the same samples natively, in Chrome and in Firefox, with SADIE II's data. A moving
        source does not click.
      - Natively it costs what Steam Audio's binaural does (64 voices: 170 against 184 ms of a core per second).
      - Steam Audio's native and wasm builds differ by rounding (107 dB down, but 359 of 51,200 samples equal), so a
        bounce or a test cannot match across legs. Its wasm is 6.03 MB and experimental, against the renderer's 76 KB.
      - Its default HRTF is CIPIC's, under CIPIC's terms, and its GPU path is AMD's OpenCL.
      - **On the web the renderer costs what it does natively at `-O3`, and 5 to 10 times more at kama's fixed
        `-Oz`.** So the web's voice count waits on KAUD-6.
21. **Decided on 2026-11-13: the core's FFT is pffft, through the package's C seam** (area 4, question 1 continued). The
    owner took the recommendation.
    - **The vendoring:** pffft (the copy r8brain 7.7 bundles), its FFTPACK v5 notice kept in the package's notices.
      It is compiled with `-ffp-contract=off`, which `reproducible-float` already sends to a C seam.
    - **Before it ships,** its x86-64 SSE path is compared with NEON's and wasm's on the Windows box.
    - **A kama FFT can replace it later behind the same seam,** as kama-native device backends may replace miniaudio
      (decision 17).
    - **Why** (RESEARCH.md § 9.1):
      - The FFT is most of a voice's cost (57 to 85%), and the probe's kama FFT is 15 times slower than pffft:
        2,701 against 180 ns for a forward and an inverse of 256 points natively, and 2,221 against 193 ns in wasm.
      - pffft made the same bits natively (NEON), in wasm SIMD and in wasm scalar.
      - It adds 37 KB of wasm.
22. **Decided on 2026-11-13: HRTF data is converted at build time; reading SOFA at run time is an option** (area 4,
    question 2). The owner took the recommendation.
    - **The converter is the package's build tool.** It turns any SOFA set into the package's compact table: the
      set's regular grid, each HRIR minimum phase with each ear's onset, and SH HRIRs for the Ambisonics rung, fitted
      by MagLS. A set on another grid is resampled onto one.
    - **The default is SADIE II's D1 (the KU100 dummy head, Apache-2.0)** at 2° of azimuth, 64 taps and float16:
      about 1 MB. The dataset's citation goes in the package's notices. A program may ship the full set, or any other.
    - **Reading SOFA at run time is a module a program opts into,** natively and on the web, for a set the program
      cannot know when it is built, such as a listener's own measured HRTF. It reads through libmysofa and converts in
      memory into the same table.
    - **Why** (RESEARCH.md § 9.2):
      - The full set is 16.3 MB as float32.
      - At 2°, 64 taps and float16 the error is 0.38 dB mean and 1.1 dB at the 95th percentile, about the threshold
        of audibility.
      - Minimum phase with onsets interpolates far better than raw HRIRs (at 5°: 0.45 against 1.57 dB).
      - libmysofa reads D1 in 101 ms natively and 117 ms in wasm, and adds 48 KB of wasm. The table reads in 2.5 ms.
      - Plain least squares makes SH HRIRs 15 dB wrong at order 3, and MagLS makes them 6 dB wrong.
23. **Decided on 2026-11-14: our C decoders on both legs; AAC through the platform** (area 4, question 3). The owner
    took the recommendation.
    - **The decoders, in the package's C seam on every leg:**
      - dr_wav and dr_flac;
      - dr_mp3, LAME's tag read for its delay and padding;
      - stb_vorbis;
      - libopus through opusfile in Ogg, and through nestegg in WebM.
    - **The containers:** libogg, nestegg (WebM) and minimp4 (MP4), with the MP4 edit list read for AAC's priming.
    - **Each codec is a module a program opts into,** so a program ships only the decoders its files need:
      - dr_wav 21 KB, dr_mp3 30 KB, stb_vorbis 43 KB, dr_flac 52 KB;
      - Opus 168 KB with its Ogg reader;
      - the containers 11 to 15 KB each.
    - **AAC goes through the platform,** since its patents keep a decoder out of the package. On the web that is
      WebCodecs, fed by the package's MP4 reader, which trims the edit list's priming itself. Natively it is the OS's
      decoder: AudioToolbox on Apple, Media Foundation on Windows. AAC's samples are the one exception to "the same on
      every leg", and the docs say so.
    - **Decoding never runs on the audio thread.** A buffer is decoded before it is handed over (decision 5), and a
      stream is question 5's.
    - **Why** (RESEARCH.md § 9.3):
      - Our decoders made the same samples natively and in wasm for every fixture.
      - They trim each container's priming (the 2 s loop is exactly 96,000 frames from every codec).
      - In wasm they decode as fast as the browsers' own (10 min of Opus: 848 ms against Chrome's 838).
      - The browsers differ from ours and from each other. Chrome's `decodeAudioData` turns 16-bit PCM half an LSB
        from its own WebCodecs and drops 24 frames of WebM Opus, and the lossy codecs differ by 79 to 145 dB.
      - WebCodecs trims no padding and no priming but Opus's pre-skip, and Safari fails FLAC and Vorbis.
24. **Decided on 2026-11-14: our resampling ladder in kama for every voice; libsamplerate's best for converting a whole
    buffer** (area 4, question 4). The owner asked: "what is the best quality production answer? is that option 1? I
    assume if we choose option 1 we can later write it all in kama in the future?" Told yes to both, the owner took it.
    - **A voice reads its buffer through our ladder,** chosen per sound. The rungs:
      - linear and cubic (Catmull-Rom), the cheap ones, which alias;
      - band-limited interpolation at 8, 16 and 32 zero crossings, a Kaiser-windowed sinc whose cutoff follows the
        pitch.
      It reads at any fractional position, with a new ratio every frame, which a sub-sample start, a loop point and
      Doppler need. It is the same on every leg, and it is optimized as it is built (a polyphase bank, SIMD).
    - **Converting a whole buffer** (a file at another rate than the context's, at load or in a bounce) uses
      libsamplerate's best (BSD-2), vendored behind the package's own seam.
    - **A kama rung can replace libsamplerate later,** once it measures 140 dB or better. No program sees the change.
    - **Why** (RESEARCH.md § 9.4):
      - Every candidate but r8brain made the same samples natively and in wasm.
      - Only ours reads at a fractional position with a ratio per frame. On a Doppler sweep it leaks -115 dB at 32
        crossings; libsamplerate leaks -101 dB and speexdsp -48, since it steps its ratio per call.
      - libsamplerate's best (140 dB SINAD) is the highest quality that makes the same samples on every leg.
        r8brain reaches 152 dB, but its NEON path makes different samples in wasm.
      - Ours is not yet optimized: at equal quality libsamplerate is cheaper today.
25. **Decided on 2026-11-14: a stream is our decoders on a decode thread, on every leg** (area 4, question 5). The
    owner took the recommendation.
    - **One decode step, the same on every leg, fills each stream's ring of frames a little ahead, off the audio
      thread:**
      - natively, on a decode thread the package starts: a declared count, 1 by default, like decision 19's render
        workers. It is the second kind of thread the package starts natively;
      - on the shared route, in a Wasm Worker, into the ring in shared memory;
      - on the page route, in a decode Worker, the program's own instance. It transfers buffers of frames straight to
        the worklet's instance through a `MessagePort` the loader hands both, and the worklet hands back its read
        count. No more is in flight than the ring holds, and the main thread is never in the path. That is decision
        7's second route, carrying frames. It is a third artifact of the program, which kama cannot yet build for a
        library (KAUD-5).
    - **Each stream's ring is a declared capacity** (decision 5), 16,384 frames by default: 341 ms, or 128 KB for
      stereo.
    - **A stream is prepared, then started on a stamped frame.** Preparing opens it and fills its ring. A start, a
      stop and a hand-off from one stream to the next each fall on a stamped frame (decision 7), so the seams between
      sections are gapless.
    - **Seeks are exact.** A seek decodes from 1 s before its target and discards that, so the samples it plays are
      the file's own. It is a second stream prepared at the target and handed off on a stamped frame. Each codec's
      pre-roll is measured when its row is built.
    - **Loops:**
      - a loop back to the file's start is exact for free: the decoder restarts with its own pre-skip;
      - a loop point mid-file seeks exactly;
      - a short sample-exact loop is still a buffer (decision 5).
    - **AAC streams through the platform's decoder in the same decode step** (decision 23): WebCodecs on the web,
      AudioToolbox and Media Foundation natively.
    - **A stream reads its compressed bytes through the package's source:** whole in memory, as P8 measured, or read in
      chunks (a file natively, a fetch's body on the web) through each decoder's callbacks, which its row measures.
    - **Why** (RESEARCH.md § 9.5):
      - No stream ran dry on any leg, at any ring size from 85 ms, idle or loaded. That held natively, on the shared
        route and on the page route.
      - A stream's first frames were decoded 1 to 5 ms after it was asked for, from about 120 KB of decoder state. A
        stream is 0.3 MB, against 230 MB for 10 min decoded whole.
      - The samples are the same on every leg, the loop's seam and the end's trim included.
      - opusfile's own seek converges over half a second. 0.8 s more pre-roll made all 200 of 200 targets exact, for
        about 1 ms of decoding.
      - WebCodecs decodes 138 to 143 dB from ours and needs its end trimmed. Firefox's takes 150 to 200 ms to start,
        and Safari's fails FLAC and Vorbis (§ 3).
26. **Decided on 2026-11-14: a convolution reverb is our own convolver on every leg, and no `ConvolverNode`** (area 4,
    question 6). The owner took the recommendation. So decision 1 holds with no exception: every node is ours.
    - **A non-uniform partitioned convolution in kama:**
      - a 128-frame head, computed every quantum;
      - then longer stages. For a 3 s hall that is 16 partitions of 128 frames, 14 of 1,024 and 16 of 8,192;
      - each stage starts twice its block into the response, so its work for a block can take the whole next block.
        Its forward transform, its multiply-adds and its inverse are spread over the quanta before its output is due,
        and the stages' transforms are staggered so no quantum carries two;
      - the layout is chosen from the impulse response's length when it is loaded;
      - each output channel is convolved with its own channel of the response, as `ConvolverNode`'s stereo rule is.
        More channels (true stereo, decision 20's Ambisonic reflection slot) take the same code.
    - **pffft is its transform and its multiply-add** (decision 21), with its spectra left in its own order. **The
      vendored pffft computes its twiddles in double, rounded once to float.** As shipped, its setup takes them from
      the platform's `sinf`, so from 2,048 points up its bits differ between legs.
    - **Natively, the tail may run on a render worker** (decision 19): a stage's block is handed to a worker joined to
      the device's workgroup, and its output is due a block later.
    - **Why** (RESEARCH.md § 9.6):
      - In Chrome's worklet, at kama's `-Oz`, 32 halls ran with no underrun. Chrome's own `ConvolverNode` collapsed
        between 24 and 32.
      - A hall costs the worklet about 10 µs of its 2.67 ms (10.9 ms of a core per second offline at `-Oz`, 6.8
        natively), against 19 to 39 for a `ConvolverNode`.
      - Ours and the browsers' sound the same: all are float32 convolutions, about 130 dB from float64 and from each
        other. Ours makes the same samples on every leg, and `ConvolverNode`'s are its own.
      - Uniform partitions cost 10 to 30 times more.
      - The kama FFT's 16,384-point transform alone exceeds a quantum at `-Oz` (KAUD-6). So the long stages need
        pffft, as decision 21 has it.
      - Natively the tail on a worker took 70% off the audio thread with no late block. On one thread it already held
        32.

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
- **Commit on `main`, and push at the session's end** (§ Two machines).

## Two machines

This repository is the Mac's row; kyoten's graphics track (`@kama/gpu`, `@kama/graphics`) is the Windows box's. Pull
before work, commit as each step lands, and push at the session's end (the owner, 2026-11-13: "typically you will push
at the end"). Audio's records live here. kyoten's docs get only what binds kyoten: a
decision recorded in `audio.md`, and the KYR-15 row. kyoten's hot spots, `FIRST-SLICE.md` § Where it stands and each
`ROADMAP.md`'s next id, are where two machines collide, so change them in a commit of their own, pulled first.

**The Mac may take another package's Mac-only task when it is needed, even a GPU one,** such as a Metal-only
`@kama/gpu` failure (the owner, 2026-11-13: "we can take mac tasks if needed... even if they are GPU specific. for now
I think we focus on the audio tickets"). Offer one when it blocks something; audio's work stays the focus.

## Build

    kama check kama.json

kyoten builds with its own pinned kama (`../kyoten/.kama-version` names the commit, and its `AGENTS.kyoten.md` § Build
says how to make the pin from a clean clone, with the Mac's steps). Run it as `../kyoten/tools/kama`. A web build needs
emscripten's `emcc`. The probes in `.scratch/aud-probe-*/` each run with their `run.sh`, headless and muted, in the
pinned browsers in `~/browsers`.
