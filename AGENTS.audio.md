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
Areas 1 to 3 are decided (§ Decided, 1 to 19),** and their rows are in [ROADMAP.md](ROADMAP.md).

**The next session runs area 4, the ladders** (spatial sound, decoding, resampling, streaming). Its questions and
probes are planned in § The design pass, 4, and their parts are staged and smoke-tested (RESEARCH.md § 8). So it
starts by running the probes, not by planning them. It begins in plan mode only to adjust the plan to what the smoke
run and the licences showed.
- **The Mac's pin is kyoten's 0.9.945 (`c474b5e9`),** taken from the Mac on 2026-11-13 at the owner's word (kyoten
  `09943ab`, every suite with 0.9.943's results). It is built from a clean clone of `../cstar`, kama's working clone on
  this Mac until the owner renames it `kama`. On it:
  - KAUD-1 and KAUD-3 are fixed and retired, so a program checks by any path;
  - KAUD-2, KAUD-4 and KAUD-5 reproduce.
- **Read first:**
  - § Decided;
  - § The design pass, 4;
  - [RESEARCH.md](RESEARCH.md) § 8 (what is staged, and what the smoke run showed), § 3 (the state of the art's
    spatial and decoding rows) and § 4 (Steam Audio, the decoders and the resamplers).
- **Staged in `.scratch/area4/`:**
  - `third_party/` holds every candidate at a pinned tag, and its `README.md` lists them;
  - `steamaudio/` holds Steam Audio 4.8.1's headers and its macOS and wasm libraries;
  - `fixtures/make.sh` generates the test audio, and each codec's encodes;
  - `smoke/run.sh` builds every library natively, natively with no FMA contraction, and in wasm, then compares the
    hashes.
- **The Mac's toolchain** (emsdk's Python, Homebrew's paths, the pinned browsers) is in kyoten's `AGENTS.kyoten.md`
  § Build, *On macOS*.
  - ffmpeg 9.0.2 (Homebrew) has libopus, LAME and Apple's AAC encoder;
  - CMake 4 needs `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` for libsamplerate.
- **The probes' harness** is in `.scratch/`, which is git-ignored:
  - `env.sh` sets the toolchain;
  - `browsers.sh` runs a page headless and muted, with the autoplay switches that let a realtime context start.
    `CHROME_EXTRA`, `FF_EXTRA_PREFS` and `RUN_PATH` add flags, prefs and a query;
  - `serve.mjs` serves a page, isolated or not, and collects its printed rows;
  - a trusted click comes from `@kama/window`'s `tools/webtest.mjs`, as `aud-probe-context/act/` uses it;
  - KR-387 (0.9.943) lets `kama run --headless` start sound. But `kama run` serves one artifact, so the two-build web
    route still needs this harness (KAUD-5).

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
- KAUD-2 to KAUD-5 upstream.

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
   and smoke-tested (RESEARCH.md § 8). A ladder is a feature in rungs from cheap to best. A program picks a rung per
   sound, and each rung is the same on every leg. Each question below is measured first, then asked in full.
   1. **Where a sound seems to come from.**
      - *The problem:* a game says "this footstep is behind you, 3 m away, around a corner", and the listener should
        hear the direction, the distance and the wall. Web Audio's `PannerNode` HRTF is one generic data set, and it
        renders differently in each browser (§ 2.3). It has no personal HRTFs, no occlusion and no rooms.
      - *The rungs:*
        - equal-power panning (Web Audio's formula);
        - HRTF binaural from SOFA data;
        - Ambisonics: many sources encoded into one sound field, rotated by the head's pose and decoded binaurally
          once, XR's usual path;
        - the room: distance and air absorption, occlusion and transmission through walls, reflections and reverb,
          and paths around corners.
      - *The options:*
        - our own rungs in kama on both legs, the room's inputs (occlusion, a reverb's parameters) supplied by the
          program from its own geometry;
        - Steam Audio on both legs, through its native libraries and its new wasm one (6.0 MB, and its samples
          differ between the legs);
        - our own rungs as the core, and Steam Audio as an optional package for geometric acoustics (baked
          reflections, pathing). That would be a different sound from the core's, on the legs it supports.
      - **P5** (`aud-probe-spatial/`): an HRTF binaural renderer in kama. Direct convolution against a partitioned
        FFT, interpolation between measured directions, and a moving source with no clicks. Then:
        - its cost per voice natively and in the worklet, and its samples on both legs;
        - Steam Audio's binaural and Ambisonics effects natively and in wasm: cost per voice, wasm size, load time;
        - `PannerNode`'s HRTF cost, the reference the web already has.
   2. **Which HRTF data, and how a program brings its own.**
      - *The problem:* HRTF sets are measurements under licences that range from Apache-2.0 to non-commercial, and a
        default must be shippable in any program. A SOFA file is HDF5, a heavy format to read in a worklet.
      - *The options:*
        - read SOFA at run time, with libmysofa (66 KB of wasm, plus zlib);
        - convert it at build time into a compact table the package reads, so no HDF5 runs at all.

        The default set comes from the licence survey (RESEARCH.md § 8). SADIE II is Apache-2.0, and its KU100 and KEMAR
        sets load identically on both legs, but each is 18 MB as float32. So the question includes how a default is
        reduced: fewer directions, shorter filters, or spherical harmonics, as Resonance Audio ships.
   3. **Which code turns a file into samples, on each leg.**
      - *The problem:* a sample-exact loop and a bounce need the same samples from the same file everywhere. But a
        game ships formats each browser decodes differently or not at all: Safari fails FLAC and Vorbis (§ 3).
        WebCodecs decodes packets, not files, so a program needs a container reader as well.
      - *The options:*
        - kama-built decoders on both legs. The smoke run made identical samples natively and in wasm. The browser
          decodes only AAC, whose patents keep it out, and is otherwise an option;
        - the browser's decoders on the web (`decodeAudioData`, WebCodecs) and ours natively. No decoder wasm, but
          the samples differ per browser and Safari has gaps;
        - a choice per codec.
      - *Also:* the containers (Ogg, WebM, MP4, FLAC, WAV), and the metadata that makes decoding gapless: Opus's
        pre-skip, LAME's tag, and AAC's priming in MP4's edit list.
      - **P6** (`aud-probe-decode/`): every fixture through WebCodecs and `decodeAudioData` in Chrome and Firefox,
        against the C decoders in wasm and natively (through kama, with `reproducible-float`). It compares:
        - the samples (FLAC must be exact);
        - the frame counts and the priming;
        - decode speed in a worker, and wasm size per decoder.

        Natively, AAC goes through AudioToolbox, and through Media Foundation on the Windows box.
   4. **Changing a sound's rate, and its pitch.**
      - *The problem:* a 44.1 kHz sound in a 48 kHz context needs resampling, and so do a `playbackRate` change and
        Doppler. A cheap resampler aliases, which is audible as whistles on a sweep; a good one costs CPU per voice.
        The browsers already differ here (§ 2.3).
      - *The rungs:* linear, cubic, and windowed sinc at chosen lengths. A variable ratio per sample serves pitch and
        Doppler, and a fixed high-quality conversion serves loading.
      - *The options:* our own polyphase sinc in kama, or a vendored one: libsamplerate or speexdsp. r8brain only
        fits offline conversion, and its NEON path differs from wasm.
      - **P7** (`aud-probe-resample/`), for each rung and candidate, at a fixed and a moving ratio, natively and in
        wasm:
        - the quality: aliasing on the sweep, passband ripple, noise;
        - the cost per voice;
        - whether it makes the same samples on both legs.
   5. **Playing a long sound without loading it whole.**
      - *The problem:* 10 minutes of stereo at 48 kHz is 230 MB as floats. Music and dialogue are decoded a little
        ahead, off the audio thread, and the audio thread must never wait for the decoder.
      - *The options, per leg:*
        - natively, a decode thread fills a ring;
        - on the web's shared route, a Worker decodes (wasm or WebCodecs) into the shared ring;
        - on the page route, the Worker posts transferred buffers.
      - *Also:* sample-exact loops and seams between streamed sections, seeking, and starting a stream with no gap.
      - **P8** (`aud-probe-stream/`): `long_48000.opus` streamed through a decode worker into the engine, natively
        and on both web routes. It measures:
        - underruns, idle and loaded;
        - memory, and the time to the first sample;
        - a seek's accuracy, and a loop's seam.
   6. **A long convolution reverb: the one built-in node in question** (decision 1).
      - *The problem:* a concert hall's reverb is a 2 to 4 s impulse response, a heavy convolution. The browser's
        `ConvolverNode` may run part of it off the audio thread, which one worklet cannot.
      - **P9** (`aud-probe-convolver/`): a 3 s impulse response as a `ConvolverNode`, against a partitioned
        convolution in the worklet, in Chrome and Firefox, and natively. It measures their cost and underruns, and
        whether the two sound the same.
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
