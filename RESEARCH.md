# Audio: the owner's projects, Web Audio as browsers ship it, the native engines, kama's real-time model, and the state of the art

The design pass's evidence, gathered 2026-11-13 on the Mac (Apple M4, 16 GB, macOS 26.7.3) for the questions in
[AGENTS.audio.md](AGENTS.audio.md) § The design pass. Four research agents read the sources below; what each section
measured itself is marked *Measured*, and the probes are in `.scratch/aud-probe-*/` (git-ignored), each re-runnable
with its `run.sh`. *(unchecked)* marks a claim taken from one reading only. **Nothing here is a decision.** The
decisions are the owner's and go in AGENTS.audio.md with their reasons.

| Source | Version, as of 2026-11-13 |
|---|---|
| kama | 0.9.938+g94365be5, kyoten's pin, built from a clean clone on this Mac (§ 7 on 0.9.943+g590aa28a, § 9 on 0.9.945+gc474b5e9) |
| Chrome for Testing | 157.0.8103.50, pinned in `~/browsers`, headless and muted |
| Firefox | 160.0, pinned in `~/browsers`, headless, autoplay blocked |
| Safari | 27.2, the system's. Not measured yet: it has no headless mode, so a run waits for the owner |
| emscripten | emsdk 7.0.0 (`777e6e5d`), the latest; the Windows box verified 6.0.13 |
| node | 26.13.0 (§ 9's wasm legs) |
| Steam Audio | 4.8.1, its release's headers and its macOS and wasm libraries (§ 8, § 9) |

## 1. What the owner's projects already do

Read from friendly-fire-department (FFD), the-mallow-man (TMM) and cosmic-forge's `origin/main`, with paths.

- **Both games' audio is a miniaudio pull on its own thread, fed by an SPSC ring of flat value commands.**
  - miniaudio 0.11.25, f32, built with its decoding, encoding, resource manager and engine compiled out, and with
    `MA_NO_NULL`, so no device means silence rather than a fake device (FFD `audio/src/ffd_audio_native.c:14-25,89-102`).
  - The callback loads an atomic function pointer and calls kama's `RenderFn`, a `@foreignEntry`; a non-zero return
    latches the producer off and the device plays silence. Opening and starting are separate calls, so the synth is
    built at the device's real rate before the first callback (0 silent callbacks measured, FFD `docs/SPEC.md:1454`).
  - The ring: `InlineArray<AudioCmd>#(256)`, `Atomic<int32>` head and tail as monotonic counters masked only at the
    array, acquire and release. On overflow the producer drops the command and counts it; it never blocks. Levels go
    down the same ring as cues, so they stay ordered (FFD `engine/src/audio/core.kama:53-194,231-239`).
  - `renderInto` is `@noheap @onPanic(recover: 1)`: drain, synth, mix.
- **The mixers are pure kama, tested with no device.** FFD: 24 voices, Music, Sfx and Voice buses under a master,
  RBJ biquads, naive oscillators. TMM: 32 voices and 16 loop slots, quietest one-shot stolen, equal-power pan, gain
  ramps, linear-interpolated sample voices, a sealed sample bank of WAV PCM16/24 decoded whole before `start`, and 2D
  spatial only (earshot, −3 dB from behind, no height) (TMM `audio/src/synth.kama:31-59`, `space.kama:1-12`).
  - TMM's own open list: no limiter (output is clamped to ±1, "the seam a limiter replaces"), no PolyBLEP, a linear
    resampler, no streaming, sub-tick timing only to about one fill, no height (TMM `audio/README.md:211-217`). Steam
    Audio's HRTF is next on its roadmap (`ROADMAP.md:178`).
  - TMM renders offline byte-identically with `--capture-audio`, the device never opened (`game/src/audio.kama:603`).
- **Only FFD has a web leg, and it is pumped from the frame, not a worklet.** The frame calls the same `RenderFn` into an
  8192-frame scratch buffer, copies it into an `AudioBuffer`, and schedules an `AudioBufferSourceNode` at a cursor kept
  at most 40 ms ahead (FFD `audio/src/web.kama:92-112`, `ffd_audio_web.js:33,96-139`). No worklet, no shared memory, no
  thread. `resume()` only from a gesture. AGENTS.audio.md's "both games' … pumped from the frame on the web" overstated
  this: TMM has no web leg.
  - **Why no worklet:** FFD deferred it because cross-origin isolation "would break the relay's cross-origin
    WebSocket", never measured (FFD `docs/ROADMAP_DETAIL.md:1704-1707`). *Measured* below (§ 2.6): it does not.
- **Voice chat, two opposite choices.** Both use libopus 1.6.1 built fixed-point, so decoding is bit-identical on every
  leg, wasm included (16 kHz, 20 ms, 24 kbps; decode 6.8 µs and encode 375 µs in release, FFD `SPEC.md:1559-1585`).
  FFD jitter-buffers and decodes **on the audio thread**, through a `@noheap` function pointer; TMM decodes on the
  frame and hands the callback a sample ring, about 120–150 ms mouth to ear. Neither cancels echo.
- **cosmic-forge** generates its sounds offline (Python models, Csound, FluidSynth) with gates for loudness, true peak
  and loops exact to the sample, and plays them with an `<audio>` element on the web and nothing natively. CF-24: an
  `<audio>` element comes round a loop near its end, not on it; `AudioBufferSourceNode`'s `loopStart`/`loopEnd` would
  be exact, and natively that needs a mixer that wraps a buffer.
- **kama has no audio code of its own** (no std module, no example, 0.9.938).
- **Worth keeping:** the pull seam; the ring of flat commands with monotonic counters, dropped and counted, never
  blocking; levels on the ring with the cues; mixing in kama, tested offline; open and start apart; the latch; a sealed
  bank attached before start; timing the callback.
- **Problems they hit:** a module static is per isolate, so the first Opus adapter played nothing (FFD
  `mix.kama:128-133`); wasm's 64 KB stack forces state behind a pointer (FFD `core.kama:130-138`); `AudioDevice` is a
  `value`, not a `resource`. *(unchecked inference)* TMM's `int32` frame counters overflow after about 12.4 h at
  48 kHz, which a DAW would reach.

## 2. Measured: Web Audio as the browsers ship it

`.scratch/aud-probe-webaudio/`: a page served cross-origin isolated, run headless and muted in each pinned browser. It
reads the API's surface, never resumes a realtime context, and renders offline (`OfflineAudioContext`, 48 kHz) so
nothing is audible.

### 2.1 Web Audio 1.1 ships in Chrome only

| | Chrome 157 | Firefox 160 |
|---|---|---|
| `AudioContext.setSinkId`, `sinkId`, `onsinkchange` | yes | **no** (it has `mediaDevices.selectAudioOutput`, which Chrome lacks) |
| `renderSizeHint` → `renderQuantumSize` | yes: 256 is honoured realtime and offline; `"hardware"` gave 128 here | **no** |
| `AudioContext.playbackStats` (`AudioPlaybackStats`) | yes | no |
| `AudioContext.onerror` | yes | no |
| `getOutputTimestamp`, `baseLatency`, `outputLatency` | yes (`baseLatency` 5.33 ms, suspended) | yes (both 0 while suspended) |
| `renderCapacity` | no | no |
| `navigator.audioSession` | no | no |
| AudioWorklet, also in `OfflineAudioContext` | yes | yes |
| Web MIDI | yes | yes |
| `MediaStreamTrackProcessor`, `MediaStreamTrackAudioStats` | yes | no |
| cross-origin isolated, `SharedArrayBuffer` | yes | yes |

### 2.2 Decoding: WebCodecs decodes every common codec in both

`AudioDecoder.isConfigSupported`, 48 kHz stereo: Opus, FLAC, Vorbis, AAC-LC and MP3 are all supported in both
browsers. Encoding differs: Opus in both, AAC in Chrome only, Vorbis in Firefox only, FLAC in neither. WebCodecs takes
demuxed packets, so a container (Ogg, WebM, MP4, FLAC, WAV) is read by the program; `decodeAudioData` reads a whole
file in one call instead. `isConfigSupported` says what is claimed, not what decodes: **Safari fails FLAC and Vorbis
and half-passes MP3** in the web-platform tests (§ 3).

### 2.3 No built-in node makes the same samples in both browsers

Each case rendered 1 s of a deterministic noise buffer (or an oscillator) through one node; the samples were hashed and
compared. **Every hash differs.** By how much:

| Node | Chrome vs Firefox | So |
|---|---|---|
| `BiquadFilterNode` lowpass, `GainNode` with a linear ramp and `setTargetAtTime`, `StereoPannerNode`, `PannerNode` equal-power, `ConvolverNode` | RMS equal to 7 digits, samples within 2.4e-6 | the same algorithm, rounded differently |
| `OscillatorNode` sine | within 1.1e-5 | the same, a table of different precision |
| `OscillatorNode` sawtooth | RMS 0.4881 vs 0.4919 | different band-limiting |
| `AudioBufferSourceNode` at `playbackRate` 1.37 | RMS 0.4015 vs 0.3668, samples 0.22 apart | **different resamplers** |
| `AudioBufferSourceNode` started at a sub-sample time | samples 0.12 apart | **different sub-sample starts** |
| `PannerNode` HRTF | first samples of opposite sign | **different HRTF data** |
| `DynamicsCompressorNode`, defaults | RMS 0.43 vs 0.11 | **a different compressor** |
| `WaveShaperNode`, 4× oversampling | samples 1.85 apart | **different oversampling filters** |

**An `AudioWorkletNode` running the same code makes the same samples in both** (identical hash). So the web has no
single sound to match: a native implementation of Web Audio's nodes can match the spec, but not "the browser", since
the browsers disagree on exactly the nodes a game and a DAW lean on most (resampling, HRTF, compression). Only DSP the
program runs itself, in a worklet, sounds the same in every browser and can be held bit-exact to native.

### 2.4 The cost of voices: one wasm worklet is 2.7 to 4 times cheaper than built-in nodes

`.scratch/aud-probe-mixcost/`, on a quiet machine. N looping voices, each read at its own playback rate, given a gain
and panned equal-power to stereo, rendered offline for 10 s at 48 kHz. Three ways: as built-in nodes
(`AudioBufferSourceNode` → `GainNode` → `StereoPannerNode`, three nodes a voice); as one `AudioWorkletNode` whose
processor calls a 758-byte wasm mixer (`mix.c`, `emcc -O3 -msimd128`) each 128-frame quantum; and as the same C built
natively (`clang -O3`) and called the same way. Milliseconds of one M4 core per second of audio, the median of three:

| Voices | Chrome, built-in | Chrome, wasm worklet | Firefox, built-in | Firefox, wasm worklet | native C |
|---|---|---|---|---|---|
| 64 | 14.5 | 6.8 | 21.2 | 5.7 | 4.8 |
| 256 | 59.0 | 23.0 | 87.7 | 21.7 | 19.2 |
| 1024 | 241.0 | 90.6 | 352.5 | 87.5 | 77.0 |

- At 1024 voices the worklet is **2.7× cheaper** than built-in nodes in Chrome and **4.0×** in Firefox, and within
  **18%** (Chrome) and **14%** (Firefox) of native. At 64 voices the worklet's fixed cost a quantum shows (1.4× native
  in Chrome).
- **The comparison is close, not exact.** Each browser's `AudioBufferSourceNode` uses its own resampler (§ 2.3: they
  differ), where `mix.c` interpolates linearly, and Firefox's costs more; a better resampler costs the worklet too.
  `mix.c` stands in for the C kama would emit for the same loop, and kama's release wasm is `-Oz`, not `-O3` (§ 5).
  Offline rendering measures the work, not a realtime callback's deadline.

### 2.5 kama compiled to wasm runs in an AudioWorklet

Measured by the kama agent (§ 5), re-run here where marked. kama's own DSP, through emscripten's Wasm Audio Worklets
(`"emSettings": {"AUDIO_WORKLET": 1, "WASM_WORKERS": 1}` and a C seam on `emscripten/webaudio.h`), rendered on the
worklet thread in Chrome for Testing 157: "48384 frames rendered by the worklet after 59 ticks; context running=1, on
worklet thread=1". With a panic forced every quantum, `@onPanic` recovered all 376 and audio kept running. Two things
stand in the way, both in § 5: a C seam with `_Thread_local` or `_Atomic` does not link without a workaround (KAUD-1,
re-run here), and a program that spawns runs `main` in a worker, where `AudioContext` does not exist (re-run here:
`PROXY_TO_PTHREAD=1` in its link).

### 2.6 Cross-origin isolation keeps cross-origin WebSockets

`.scratch/aud-probe-isolation/`: a page served with `Cross-Origin-Opener-Policy: same-origin`, opening a WebSocket to
another origin and loading an image from it that sends no `Cross-Origin-Resource-Policy`.

| COEP | Chrome 157 | Firefox 160 |
|---|---|---|
| `require-corp` | isolated; WebSocket connects and receives; image **blocked** | the same |
| `credentialless` | isolated; WebSocket connects and receives; image **loads** | the same |

So isolation does not cost a multiplayer game its relay. Its real cost is a cross-origin subresource that sends no CORP
header, which `credentialless` admits (without cookies). Safari's support for `credentialless` is to be measured.

## 3. Web Audio's state of the art, from its sources

Read by the web agent from the specs, MDN's compatibility data (browser-compat-data 8.1.9, 2026-11-12), wpt.fyi,
chromestatus and release notes. Safari's rows are from those sources, not measured here.

- **There is no Web Audio 2.** The draft 2026 charter: "Rather than creating a v2.0, Web Audio API will be maintained
  by updating the Recommendation" (<https://w3c.github.io/charter-drafts/2026/audio-wg.html>). **Web Audio 1.1** is a
  Working Draft (2026-09-22, <https://www.w3.org/TR/2026/WD-webaudio-1.1-20260922/>), expected to close in Q4 2026. It
  adds `setSinkId`, `onerror`, `playbackStats`, `renderSizeHint` (1 frame to 6 s), an `"interrupted"` state, a
  worklet-wide `port`, and chunked offline rendering.
- **Who ships it** (Safari from the sources; Chrome and Firefox agree with § 2.1):

  | | Chrome/Edge | Firefox | Safari |
  |---|---|---|---|
  | `setSinkId` | 110 | no | no |
  | `onerror` | 128 | no | no |
  | `"interrupted"` | 136 | no | yes |
  | `playbackStats` | 146 | no | no |
  | `renderSizeHint` | 153 | no ("no signal") | no ("no signal") |
  | worklet-wide `port` | 160, planned | 138 | no |
  | `COEP: credentialless` | 96 | 119 | **no**, so isolation on Safari means `require-corp` |
  | WebCodecs `AudioDecoder` | 94 | 130, desktop only | 26 |
  | Web MIDI | 43, with a prompt since 124 | 108, desktop, behind a site-permission add-on | **no** |
  | `navigator.audioSession` | no | 155, behind a pref | 16.4 |

- **AudioWorklet** is everywhere (Chrome 66, Firefox 76, Safari 14.1). `process()`'s arguments allocate each block,
  feeding the collector; MessagePort is "suboptimal for real-time audio" (Chrome's own guidance); and a worklet agent
  cannot block (HTML: `canBlock` is false), so **`Atomics.wait` is refused there** and emscripten moved worklet locks to
  spinlocks (emscripten#22962). A worklet polls; only a worker waits.
- **emscripten's Wasm Audio Worklets** have existed since 3.1.32 (2023): one audio thread per context, a Wasm Worker,
  no `fetch` inside, no blocking. 4.0.23 (2026-01-10) added `-sENVIRONMENT=worklet`, **which runs without shared
  memory**: the route for a page that cannot be cross-origin isolated. 7.0.0 passes `renderSizeHint` through.
- **What production does on the web:**
  - **FMOD 2.03:** the whole mixer in wasm, out through an AudioWorklet (or `ScriptProcessorNode`); its threaded build
    needs isolation.
  - **openDAW:** a Rust engine in wasm as the worklet's processor, the default since mid 2026; it hosts **WebCLAP**
    plugins (CLAP compiled to wasm) since 2026-10-08.
  - **Godot 4:** its web export defaults to "Sample" playback, built-in `AudioBufferSourceNode`s and `GainNode`s,
    because its "Stream" mode fills the worklet's ring from the main thread and crackles without threads. In Sample
    mode "AudioEffects are not supported". Godot pans in 3D itself, as gains.
  - **Unity 6.3:** built-in Web Audio, not FMOD, on the web: volume only, no effects, no microphone.
  - So the engines that keep their features on the web run them in wasm in a worklet; the ones on built-in nodes give
    features up there.
- **Plugins for a DAW on the web:** WAM 2.0 has gone quiet (its API last published 2023-03-06); the momentum is
  **WebCLAP**, CLAP in wasm hosted in an `AudioWorkletNode`, its spec still a drafting sandbox
  (<https://github.com/free-audio/web-clap>).
- **Decoding:** `decodeAudioData` takes a whole file and makes main-thread `AudioBuffer`s. WebCodecs runs in workers.
  wpt.fyi, 2026-11-13: AAC and PCM pass everywhere; Opus 11/11 Chrome, 10/11 Firefox, 9/11 Safari; **Safari fails FLAC
  (0/10) and Vorbis (0/10) and half-passes MP3 (6/10)**, and Firefox passes Vorbis 6/10. So the web cannot lean on the
  browser for every codec.
- **Latency:** measured round trips (WAC 2025, loopback): MacBook Pro 2021, Firefox 38.9 ms, Chrome 52.3 ms, Safari
  100 ms; Windows 10, Chrome 62.8 ms, Firefox 104.7 ms. Chrome 153 on an M4 Mac with an RME interface: 25.7 ms at 64
  frames, 28.6 at 128, 31.5 at 256.
- **iOS:** contexts start suspended until a gesture; the default session is `ambient`, so the silent switch mutes Web
  Audio unless `navigator.audioSession.type = "playback"` (iOS 17+).
- **Spatial:** `PannerNode`'s HRTF is one generic IRCAM set in Chromium and Firefox (Firefox's code is Blink's), with no
  personal (SOFA) HRTFs and no room model; but the two still render differently (§ 2.3). Resonance Audio's web SDK is
  archived (2022). Steam Audio's wasm build is experimental with open link errors (steam-audio#496). WebXR has no audio
  API: spatial audio in XR is Web Audio driven by the head pose.

## 4. The native engines and devices

Read by the native agent from each project's repository, licence files and release pages, 2026-11-13.

- **Native implementations of Web Audio's graph:**
  - **web-audio-api-rs** 1.8.0 (2026-11-12), MIT: 21 node types, a Rust `AudioWorkletProcessor`, 5172 WPT subtests
    passing and 405 failing (2026-07-20, through IRCAM's Node binding). **No C API**, and none in its dependents; its
    device layer is cpal or cubeb with no documented custom-device hook; **Symphonia (MPL-2.0) is a required
    dependency**; and Rust has no PS5 or Xbox target and Switch only as Tier-3 `no_std`, which **blocks consoles**.
  - **LabSound**, BSD-2, C++: no release since 2023-02, spec coverage unstated, no AudioWorklet.
  - Nothing written in C.
- **Device layers:**

  | | Licence | Backends | What it exposes |
  |---|---|---|---|
  | **miniaudio** 0.11.26 (2026-10-31) | public domain or MIT-0 | WASAPI, CoreAudio, AAudio, OpenSL, ALSA, PulseAudio, JACK, Web Audio, a null device, and **a custom backend** (a vtable the program supplies); `dev-0.12` adds PipeWire | WASAPI exclusive and `IAudioClient3` low-latency shared, CoreAudio buffer size and sample rate change, AAudio exclusive, duplex, enumeration. No ASIO, no device added/removed events |
  | cubeb (Mozilla) | ISC | its macOS and Linux backends are Rust | AEC/NS/AGC, device-collection events |
  | SDL3 audio 3.4.20 | zlib | adds PipeWire, consoles' homebrew | shared WASAPI only, device events |
  | RtAudio 6.0.1, PortAudio 19.7 | MIT-like | **ASIO**; no mobile | |

- **The licences that bind a DAW:** **VST3's SDK is MIT since 3.8** (Steinberg, 2025-10-29). **The ASIO SDK is GPLv3
  or proprietary** (October 2025), so ASIO can only be a separate, optional package, never in this MIT OR Apache-2.0
  one. **CLAP** is MIT with a C ABI; LV2 is ISC.
- **Spatial:** **Steam Audio is Apache-2.0** (open-sourced 2024-02-19; 4.8.1, 2026-02-11), a C API, HRTF from SOFA
  files, Ambisonics, occlusion, transmission, reflections, convolution reverb; Windows, Linux, macOS, Android arm64,
  iOS (Quest not named). Meta's XR Audio SDK is frozen at v85 ("final version"). OpenAL Soft is LGPL, awkward to link
  statically on iOS and consoles. miniaudio's spatializer has no HRTF and no occlusion.
- **Decoders and resamplers, all permissive:** libopus 1.6.1 (BSD-3), dr_flac, dr_wav, dr_mp3 (public domain or
  MIT-0), stb_vorbis (public domain or MIT), libFLAC 1.5.0 (BSD); r8brain-free-src 7.7 (MIT), libsamplerate 0.2.2
  (BSD-2), speexdsp 1.2.1 (BSD-3). **Avoid fdk-aac** ("NO PATENT LICENSE"): AAC natively through the OS's decoder.
- **What the state of the art covers**, as Wwise, FMOD 2.03, Unreal 5.9 (MetaSounds, Quartz) and Unity 6.2 have it:
  voices with virtualization and concurrency rules, buses and VCAs, snapshots, ducking and sidechain, a DSP graph,
  spatial audio with occlusion, rooms and portals, streaming, and sample-accurate scheduling. A DAW adds parallel graph
  scheduling, plugin delay compensation, plugin isolation and offline bounce (Tracktion Engine, Ardour). **Web Audio's
  graph has none of the first list but sample-accurate automation, and none of the DAW's**: every one sits above the
  graph, in every architecture.

## 5. kama 0.9.938 for real-time audio

From the pin and its source (`.scratch/kama-pin-src` in kyoten), by the kama agent; *re-run here* where marked. Its
probes are in `.scratch/aud-probe-kama/`.

- **Callbacks from C:** an `fnptr` handed to C is `@foreignEntry` (it may run on a thread kama did not make). Module
  statics are `_Thread_local`, and reading one assigned outside the region is a compile error ("carry the state through
  the pointer the C API hands the callback instead"), which is the peers' "state only through `user`". A C pthread
  called a `@noheap @onPanic` kama render 4 × 256 frames, and a forced bounds panic was recovered every block.
- **`@noheap` proves no allocation, transitively, and nothing else.** *Re-run here:* it accepts a `Locked` window,
  `Atomic.wait`, `sleep` and `println` (KAUD-2). `@noparks` on the callback's type refuses waits on another task, but
  still admits a `Locked` window, `sleep` and output. A blocking check is planned upstream as KR-79.
- **Atomics:** `Atomic<T>` over integers, `bool`, floats and `UnsafePtr`, five memory orders, CAS with separate
  orders, wait and notify; no fence, no weak CAS. **No lock-free SPSC ring in std** (`Channel` is one mutex), so the
  rings are this package's, as they were the peers'.
- **SIMD:** `Simd<T>#(N)`, 128 bits, lowers to SSE2, NEON or wasm `v128`, and works inside `@noheap`; no FMA, nothing
  wider. `reproducible-float` turns off FMA contraction and compiles musl's 14 math functions into the program, so
  `sin` and `exp` give the same bits on every target, all or nothing per program. `debug.optimize` builds named
  packages at release level in a debug build, written for DSP ("1.36 ms a frame in debug against 14.8 µs").
- **The web leg:** a package ships JS with `jsLibraries` and sets emscripten's settings with `emSettings`, which reach
  the consumer. Every wasm build gets `-msimd128`; **release is `-Oz`**, not `-O3`. A program that spawns gets
  `-pthread` and `PROXY_TO_PTHREAD=1`, so its `main` runs in a worker (*re-run here*), where `AudioContext` is not
  defined: the web seam has to create and drive the context on the page's thread, as an emscripten JS library function
  can with `__proxy: 'sync'` (not yet probed). `kama run` sends COOP and COEP when the memory is shared.
- **`kama run --target WASM --headless` never starts a realtime context:** it cannot pass an autoplay flag or a
  gesture, so the worklet rendered 0 frames in Firefox 160 and Chrome for Testing 157 (unchecked; a test renders
  offline in any case).
- **Vendoring:** a C library is sources under `third_party/` gated per target (`"compileFor": ["!ARCH_WASM32"]`), as
  `@kama/window` vendors SDL 3; a package never ships binaries. miniaudio would be one header and one `.c` there.

## 6. Area 2, measured

Probes for area 2 ([AGENTS.audio.md](AGENTS.audio.md) § The design pass, 2), run 2026-11-13 on the Mac in the
pinned browsers, headless. Each worklet writes zeros, so nothing could be heard. Each probe re-runs with its `run.sh`
and writes `results/`. **A quantum is 128 frames, 2.67 ms at 48 kHz.** Chrome reports underruns through
`AudioContext.playbackStats`. Firefox has no such API, so its underruns are unknown, not zero.

- **A realtime context runs headless in both browsers** when Chrome is given `--autoplay-policy=no-user-gesture-required`
  and Firefox `media.autoplay.default=0`. This corrects § 5's "0 frames": what was missing was the autoplay switch.
- **Headless Chrome slows frames to 15 Hz** on a page that draws nothing. A page that changes the DOM each frame keeps
  60 Hz, so the probes do that.

### 6.1 The ring, in kama (`.scratch/aud-probe-ring/`)

The peers' single-producer ring, written in kama: `Atomic<int64>` head and tail as monotonic counters on separate
128-byte lines (the M4's line size), and an acquire load and a release store on each side. Each command is a typed
`type value` of 48 bytes, holding an enum whose variants carry payloads, stored in an `InlineArray`. FFD had left that
shape unprobed. The consumer is a C thread calling a `@noheap @onPanic` kama drain through the pointer C hands it, as
an audio callback will.

- **10⁷ commands with nothing lost or reordered, natively:**
  - every sequence number in order and every checksum intact, in each of 13 release runs, at 27 to 35 million
    commands a second (8.6 million in debug);
  - **on wasm**, between the main thread and a Wasm Worker under node: the same, at 16 million a second.
- **The test catches a missing release.** With the publish and its read made relaxed, 3 of 5 release runs on the M4
  delivered 1 to 8 torn or reordered commands. The M4's memory model is weak enough to show it.
- **ThreadSanitizer is not the evidence.** Apple clang 21's TSan reports a plain race and relaxed message passing on
  one scalar, but stays silent on the ring with its release and acquire removed. That holds for kama's ring and for
  the same ring written in plain C.
- **The atomics are real hardware atomics:**
  - the emitted C calls `__atomic_load_n` and `__atomic_store_n` with the stated orders, through std's width switch;
  - on wasm, `Atomic<int64>` is `i64.atomic.load` and `i64.atomic.store`, lock-free, with no lock in the C. Every
    wasm atomic is sequentially consistent, so acquire and release cost no less there.
- **A safe function can call `storeExplicit`:** kama's `unsafe` marks a body, not a call, so a ring's `push` need not
  be `unsafe`.
- **kama holds a program's DSP to the real-time rules through a contract** (`aud-probe-ring/contract/`):

  | The check | Result |
  |---|---|
  | an implementation of a `@noheap` contract member that is not itself `@noheap` | refused |
  | a `@noheap fn` calling through a contract value, a generic or not | the walk enters every implementation, and refuses one that allocates |
  | `@noparks` on a contract member | refused: kama allows it only on a `fnptr` type |
  | a render `fnptr` typed `@noheap @noparks`, calling a processor held as an `Owned<Processor>` | the walk finds a `wait` in any implementation and refuses it |

  So the render callback's type carries both checks for every processor a program could hand the engine. What still
  passes is KAUD-2's: a lock window, `sleep` and output.

### 6.2 Commands into the worklet, and the way back (`.scratch/aud-probe-cmd/`)

**The setup:**
- **The program.** kama on emscripten's Wasm Audio Worklets, built in release. The worklet counts finished quanta into
  an `Atomic<int64>`.
- **The stamp.** Each command carries the counter's value when the main thread sent it, so 0 means the command landed
  in the very next quantum.
- **The arms.** The ring, drained at the top of each quantum, against emscripten's `postMessage` route
  (`emscripten_audio_worklet_post_function_viii`).
- **The load.** Eight commands each frame at 60 Hz. "Busy" means the main thread spins for 12 ms of each frame and
  makes 20,000 JS objects.
- **The way back.** A sound's end every 37 quanta, and a meter every quantum. On the ring arm the main thread drains
  the events and reads the meter's snapshot once a frame; on the other arm they come back by `postMessage`.
- **The length.** 8 s a phase.

Quanta from the stamp to arrival, as median / 99th percentile / worst:

| | Chrome 157, idle | Chrome, busy | Firefox 160, idle | Firefox, busy |
|---|---|---|---|---|
| command in, ring | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| command in, `postMessage` | 0 / 0 / 2 | 0 / 0 / 2 | 0 / 2 / 6 | 0 / 4 / 4 |
| a sound's end back, ring polled each frame | 4 / 8 / 8 | 3 / 8 / 8 | 4 / 9 / 9 | 4 / 12 / 12 |
| a sound's end back, `postMessage` | 2 / 2 / 2 | 2 / 6 / 6 | 2 / 4 / 4 | 3 / 9 / 9 |
| meter, snapshot (staleness when read) | 1 / 1 / 1 | 1 / 1 / 1 | 1 / 1 / 1 | 1 / 1 / 1 |
| meter, `postMessage` (staleness on arrival) | 1 / 2 / 2 | 2 / 6 / 6 | 2 / 4 / 8 | 3 / 9 / 18 |
| **64 meters a quantum** (24,000 messages a second), `postMessage`, busy | | 2 / 6 / 6 | | 3 / 9 / 12 |

- **Chrome counted no underrun in any phase,** including 24,000 messages a second posted from the audio thread. One
  12 ms underrun in the first phase of the first run did not recur.
- **Nothing was lost.** Every phase delivered exactly 8 commands per frame. Firefox ran fewer frames when busy (464
  of 480).
- **A ring polled once a frame answers no later than the frame that acts on it.** Posted events reach the main thread
  sooner, but a program reads them at its next frame either way.
- **A program whose `main` runs in a worker** (`spawn/`; a program that spawns gets `PROXY_TO_PTHREAD`):
  - a JS library function with `__proxy: 'sync'` ran the C seam on the page's thread and started the context;
  - the worker then pushed straight into the ring: 0 / 0 / 0 quanta in both browsers;
  - the way back was 4 / 8 / 8, polled by the worker;
  - Firefox's frames were steadier with the page's thread free.
- **emscripten's `postMessage` route cannot serve that program:**
  - it posts through `emAudio[context].audioWorklet.port`, a table only the page's thread has;
  - its replies arrive on the page's thread, not on the program's;
  - each message is a new `{_wsc, args}` object, made on the sending thread, the audio thread included.
  - emscripten's Web Audio library proxies nothing itself (`src/lib/libwebaudio.js` has no `__proxy`).

### 6.3 Allocation on the audio thread (`.scratch/aud-probe-alloc/`)

**The setup:**
- **The allocation.** Inside a Wasm Audio Worklet with shared memory, each quantum's `process()` makes 16
  `malloc`/`free` pairs of 64 B to 64 KB.
- **The clock.** A Wasm Worker publishes `performance.now()` into shared memory, since a worklet has no
  `performance.now()` (Web Audio issue 2527). It resolves 20 to 25 µs.
- **The phases, 8 s each:**
  - the worklet alone;
  - against the page's thread and a Wasm Worker churning the same heap;
  - the same, while the page's thread also grows the heap by 16 MB twice a second.
- **The reference.** The same pattern natively on macOS, on a thread woken every 2.67 ms.

The worst quantum's allocation time, in µs (99th percentile in brackets):

| | alone | contended | contended, heap growing |
|---|---|---|---|
| Chrome, dlmalloc (emscripten's default) | 80 | 825 (80) | 940 (80) |
| Chrome, mimalloc | 410 (30) | 70 (20) | 90 (20) |
| Firefox, dlmalloc, run 1 | 20 | **6,000** (480) | 2,320 (80) |
| Firefox, dlmalloc, run 2 | 20 | **63,500** (≥ 4,000) | **42,420** (≥ 4,000) |
| Firefox, mimalloc | 80 (20) | 300 (20) | 40 (20) |
| macOS natively, libmalloc | 75 (10) | 213 (20) | 523 (20) |

- **With shared memory, a `malloc` on the audio thread has no bound.** In Firefox, one call waited 63.5 ms for the
  allocator's lock: 24 quanta. In that run, more than 1 in 100 quanta lost a whole quantum to allocation.
- **mimalloc's per-thread heaps shorten the tail but do not bound it:** 410 µs in a quantum with nothing else running.
- **Natively the tail is shorter but still real:** half a millisecond while the heap grows.
- **kama's heap is this `malloc`.** `kama_runtime.h` sends the default `GlobalAllocator` to `malloc` and `free`, unless
  the program declares `@globalAllocator`.

### 6.4 A page that cannot be isolated (`.scratch/aud-probe-noiso/`)

**The setup:**
- **The page.** Served with no COOP or COEP, so `crossOriginIsolated` is false and `SharedArrayBuffer` is undefined,
  on the page and in the worklet.
- **The engine.** A second wasm instance, built with `-sENVIRONMENT=worklet -sSINGLE_FILE -sMODULARIZE -sEXPORT_ES6`
  and imported by the processor's module. A worklet loads scripts as ES modules, so a top-level `var` from one
  `addModule` is invisible to the next.
- **The arms.** A frame's 8 commands go as 8 messages, as one structured-clone batch, or as one transferred
  `ArrayBuffer`.
- **The measure.** With no shared clock, a command's landing quantum on the audio clock, minus its send time on the
  page's clock, is counted as its **excess over the best case in the run**.

| | Chrome, idle | Chrome, busy | Firefox, idle | Firefox, busy |
|---|---|---|---|---|
| excess quanta, median / 99th / worst (the worst of the three arms) | 1.0 / 2.1 / 4.7 | 1.6 / 2.4 / 2.4 | 1.3 / 2.4 / 4.5 | 1.3 / 2.4 / 2.4 |
| round trip, ms, median / 99th | 0.2 / 0.3 | 12.4 / 12.6 | 3 / 7 | 12 / 18 |

- **The three arms differ by less than one quantum.** One batch a frame is as prompt as one message per command.
- **A busy main thread does not delay the commands it has already sent.** It delays only the replies, by its own
  busy time.
- **Allocation is fast here.** In the worklet's own instance no other thread shares the heap: 10⁶ `malloc`/`free`
  pairs took 7 ms (7 ns each), and growing the memory took about 1 ms (by `Date.now`, whole milliseconds).
- **Firefox's `performance.now()` counts whole milliseconds on a page that is not isolated,** so its round trips are
  coarse.
- **kama can build the worklet's instance with no gap** (`kama/`). Set through `emSettings` alone (`ENVIRONMENT`,
  `SINGLE_FILE`, `MODULARIZE`, `EXPORT_ES6`, `EXIT_RUNTIME: 0`, `EXPORTED_FUNCTIONS`), a kama program loaded in both
  browsers' worklets:
  - its `main` ran, and its `println` reached the processor;
  - `expose fn`s answered;
  - a `DynamicArray` allocated.

  So the route for a page that cannot be isolated is two builds of one program: the page's, and the worklet's.

## 7. Area 3, measured

Probes for area 3 ([AGENTS.audio.md](AGENTS.audio.md) § The design pass, 3), run 2026-11-13 on the Mac (Apple M4,
4 performance and 6 efficiency cores) **on kama 0.9.943** (`590aa28a`, kyoten's pin from that day), emsdk 7.0.0 and the
pinned browsers, headless. Nothing was audible: every device and worklet got zeros, and no input device was opened
(the microphone rows use the browsers' fake devices). Each probe re-runs with its `run.sh` and writes `results/`.
**KAUD-1 is fixed on 0.9.943** (its repro, `aud-probe-kama/aw_tls_nofix/`, now builds); KAUD-3 still reproduces.

### 7.1 One program on both web routes (`.scratch/aud-probe-routes/`)

**The setup:**
- **The code.** A library (`lib/`, standing in for this package) holds the engine (stamped commands, slots, a render
  that splits each block at a command's frame), its web seam in C and JS, and the defaults `AUDIO_WORKLET` and
  `WASM_WORKERS` in its `emSettings`. A program (`app/`) holds its own processor (a sawtooth, a one-pole lowpass, a gain
  changed by a command mid-block, and a tremolo through libm's `sin`) and a factory that builds it from its options.
- **The builds.** One source tree, four `kama build`s, each one of the program's `select.TARGET`s:
  - natively;
  - `WEB_SHARED`: one build whose memory is shared. The processor is built on the program's side and handed over; the
    engine runs in emscripten's Wasm Audio Worklet; commands go through the ring;
  - `WEB_PAGE` and `WEB_WORKLET`: the pair for a page that cannot be isolated. The page's build only sends commands, as
    one transferred `ArrayBuffer` per flush. The worklet's build is the same program with `ENVIRONMENT=worklet`, and it
    builds the processor itself from the create command's options (Web Audio's `registerProcessor` and
    `processorOptions` model).
- **The loader.** One page picks a build at load by `crossOriginIsolated`; the server isolates the page or not.
- **The check.** Each route hashes its processor's first 96,000 samples (2 s), which start 40 quanta ahead of "now".

**Results** (`results/`):

| | the hash | late commands |
|---|---|---|
| `WEB_SHARED`, Chrome 157 and Firefox 160 | `3166511926/1473068030` | 0 |
| `WEB_PAGE` + `WEB_WORKLET`, Chrome and Firefox | `3166511926/1473068030` | 0 |
| native, `reproducible-float`, release and debug | `3166511926/1473068030` | 0 |
| native, release | `1521166993/2633355939` (3 `fmadd`s in its code) | 0 |
| native, debug | `4005530778/2242939657` | 0 |

- **Both routes make the same samples in both browsers,** and so does native, but **only with `reproducible-float`.**
  Without it, native release (fused multiply-adds, Apple's `sinf`) and native debug each differ from the web and from
  each other. A dependency may set `reproducible-float`, and it then holds for the whole program.
- **A processor built on the program's side and one built from its options in the worklet's instance are the same.**
- **A library's C seam can pick its route when it compiles.** 0.9.942's KR-386 hands `WASM_WORKERS` to every C source,
  so the shared build's seam saw `__EMSCRIPTEN_WASM_WORKERS__` and `__EMSCRIPTEN_SHARED_MEMORY__`, and the others saw
  neither. The library's `emSettings` set the shared route as the default; the program's targets set both to 0 for the
  pair (the project wins a scalar).
- **The sizes:**
  - the shared build: 56,192 B of wasm and 31,573 B of JS;
  - the page's build: 44,242 B and 19,713 B;
  - the worklet's instance: one 25,546 B file (`SINGLE_FILE`).
- **What the program had to write, because kama gives a library no way to:**
  - three targets: the worklet's with 8 emscripten settings, including an `EXPORTED_FUNCTIONS` list of mangled names
    (`_routesapp_rw_*`);
  - a `main` for each target, gated by the program's own target names;
  - the worklet's entry points as `expose fn`s;
  - the loader page, and the processor script that imports the worklet's build;
  - four `kama build` runs, each with its own `-o`. `kama run` serves one artifact, and a `SINGLE_FILE` build is served
    unisolated.
- **Why a library cannot carry it** (`flags/`):
  - no flag says "this build's memory is shared" (kama's KR-327 is open);
  - one `kama build` makes one artifact;
  - a flag or a `select` group a library declares cannot be set by its consumer
    (*"--define references undeclared flag"*, *"--select names no such group"*);
  - **a library that gates code on its own declared flag passes its own check, but every consumer's build fails**,
    with an error that names no file (`:3:0: error: … undeclared flag`). It builds only when the consumer declares the
    same flag.

### 7.2 What each browser gives a running context (`.scratch/aud-probe-context/`)

| | Chrome 157 | Firefox 160 |
|---|---|---|
| `latencyHint` → `baseLatency` / `outputLatency`, ms | `interactive` and 0.005: 5.3 / 17; `balanced`: 10 / 23; `playback` and 0.02: 21.3 / 33; 0.1: 170.7 / 182 | 0 / 11.4 for every hint: **ignored** |
| `sampleRate` asked (22,050 to 192,000) | honoured; the default is 48,000 | honoured; the default is 48,000 |
| `renderSizeHint` 64, 256, 512 | honoured: `renderQuantumSize` and the block a JS worklet's `process()` gets; `"hardware"` gave 128 | **ignored**: always 128, no `renderQuantumSize` |
| emscripten's Wasm Audio Worklet with a hint | `samplesPerChannel` 64, 256, 512 as asked | 128 |
| `getOutputTimestamp()` over 20 s | drift −6.1 ppm; the mapping's residual 1.4 µs median, 4.9 µs worst | drift −1.4 ppm; residual 1.4 ms median, 2.9 ms worst |
| `playbackStats` | `underrunEvents`, `underrunDuration`, `totalDuration`, `averageLatency` (18.0 ms), `minimumLatency`, `maximumLatency` | none |
| `onerror`, `setSinkId` | yes | no |
| `mediaDevices.selectAudioOutput` | no | yes |
| `navigator.audioSession` | no | no |

- **The microphone path** (the fake devices, `getUserMedia` → `MediaStreamAudioSourceNode` → an `AudioWorkletNode`'s
  input):
  - The input reached the worklet as planar channels of 128 frames in both browsers.
  - Chrome turns echo cancellation, noise suppression and gain control **on by default**. Each turns off by constraint,
    and its echo cancellation also offers `"remote-only"` and `"all"`.
  - Firefox's fake device offers none of them, so a real microphone's answer waits for the owner's hardware.
- **Starting with no autoplay switch** (Chrome, a trusted click through `@kama/window`'s driver; one case a page):
  - With no gesture, a context made at load is `suspended`, and `resume()` stays pending.
  - After one click, `resume()` starts it from the click's handler. It also starts it 1 s later from a timer, from a
    Worker's message 1 s later (a program whose `main` is in a worker), and 6.5 s later, after the transient
    activation has expired.
  - A context made after the click starts `running`.
  - So Chrome holds the gesture for the page (sticky activation). Safari's rule is not measured: it has no headless
    mode, so it waits for the owner.

### 7.3 miniaudio's device layer from kama, on CoreAudio (`.scratch/aud-probe-device/`)

**The setup:** miniaudio 0.11.25 (FFD's copy) with only its device layer, `MA_NO_RUNTIME_LINKING` and the four frameworks
linked through gated `ldflags`. A kama render (`@foreignEntry @noheap @noparks`, `@onPanic(recover: 1)`) writes zeros
and forces one bounds panic. The Mac's default output ran at 48 kHz, 15 s a case, while a second process read the
device's buffer size every 500 ms.

| asked | the callback's frames, every call | gap between calls, µs: median / 99.9th / worst |
|---|---|---|
| 128, miniaudio's fixed-size callback | 128 | 2,667 / 2,688 / 2,702 |
| 64 | 64 | 1,333 / 1,360 / 1,372 |
| 32 | 32 | 667 / 693 / 705 |
| 256 | 256 | 5,333 / 5,354 / 5,357 |
| 128, the raw callback | 128 | 2,667 / 2,688 / 2,689 |
| 128, the null device | 128 | 2 / 15,058 / 15,132 |

- **CoreAudio gave the period asked for, from 32 to 256 frames,** so on this Mac a 128-frame engine needs no FIFO.
- **The latency:** at 128 frames CoreAudio reports 60 frames of device latency, a safety offset of 48, a stream latency
  of 183 and the 128 buffer: 419 frames, 8.7 ms.
- **The callback's thread is real-time** (`SCHED_FIFO` 63, with a time constraint of one block) and **already a member
  of the device's workgroup**: `os_workgroup_join` from it returned `EALREADY`.
- **Another process kept seeing a 512-frame buffer** in every reading, so a program's period does not change other
  programs'.
- **The kama render's panic was recovered every time** and the stream kept running. But the recovered panic's message
  is written from the audio thread: output on the real-time path, on that rare path.
- **The null device runs in bursts,** a batch of callbacks every 15 ms on a normal-priority thread. It suits a smoke
  test of the seam, never timing; a test renders offline.
- **The cost:** the seam compiles in 1.2 s and adds 121 KB to a stripped program (155,392 B against 33,824 B).
- **What miniaudio does not do** (read in its source, § 4 and the session's survey): Audio Workgroups or MMCSS for
  threads of its own, and device added or removed events.

### 7.4 The render across cores (`.scratch/aud-probe-parallel/`)

**The work:** 1,024 voices, each a chain of 8 biquads over noise, about half of one core's 2.67 ms quantum. Each voice
writes its own row, and the rows are summed in voice order. The device gets zeros. 15 s a case. "Busy" means one
spinning thread per core (10 natively, 8 Wasm Workers on the web).

**Natively, in CoreAudio's callback** (compute per quantum in µs, and CoreAudio's overload notifications):

| threads | workers | wake | idle: median / worst / overloads | busy: median / worst / overloads |
|---|---|---|---|---|
| 1 | none | | 1,283 / 1,445 / 0 | 1,098 / 1,187 / 0 |
| 4 | plain threads | semaphore | 1,735 / 6,001 / 1 | 1,342 / 9,689 / 417 |
| 4 | real-time | semaphore | 1,732 / 1,903 / 0 | 337 / 356 / 0 |
| 4 | real-time, **joined to the device's workgroup** | semaphore | **438 / 501 / 0** | **336 / 351 / 0** |
| 4 | real-time, joined | spinning | 1,710 / 5,825 / 9 | collapsed: 339 quanta in 15 s |
| 2 | real-time, joined | semaphore | | 590 / 623 / 0 |
| 8 | real-time, joined | semaphore | | 466 / 508 / 0 |
| 8 | plain threads | semaphore | | 1,186 / 16,801 / 550 |

- **A parallel render works natively only with real-time workers joined to the device's workgroup and woken by a
  semaphore.** Then 4 workers ran a quantum 3 to 4 times faster than one thread, idle or loaded, with no overload.
- **Plain threads were slower than one thread** (the scheduler put them on efficiency cores at low clocks) and
  overloaded the device under load.
- **Real-time without the workgroup** was fast only when the machine was loaded.
- **Spinning workers failed.**
- **More workers than performance cores (8 on the M4's 4) were slower than 4.**
- **The sum's bits equalled the serial render's in every case that ran 2,000 quanta.**

**On the web, in the AudioWorklet with Wasm Workers on an isolated page** (compute per quantum in µs; underruns from
`playbackStats`, which Firefox lacks):

| | 1 thread, idle | 1 thread, busy | 4 threads, idle | 4 threads, busy |
|---|---|---|---|---|
| Chrome | 1,295 median, 0 underruns | 1,335, 0 underruns | 2,025, 0 underruns | **2,985 underruns, 15.9 s of 16 s** |
| Firefox | 1,360, 2 over the deadline | 1,380, 44 over | 2,020, 193 over | **2,013 over; 2,251 quanta rendered of 6,000** |

- **On the web, splitting a quantum across Wasm Workers is slower than one thread, and collapses under load.** A worker
  is not a real-time thread and cannot join one. A worker woke 20 µs after its notify at the median when idle, and
  360 to 465 µs at the median under load, up to 1 ms and more.
- **One worklet thread held up under the same load:** no underrun in Chrome.
- **The sums matched one thread's in both browsers.**

## 8. Area 4, staged

Staged 2026-11-13 on the Mac for area 4 ([AGENTS.audio.md](AGENTS.audio.md) § The design pass, 4), so its probes
start from parts known to build. **A smoke run, not a measurement:** one run per case, and its timings are noise.
Everything is in `.scratch/area4/` (git-ignored):
- `third_party/`: each candidate at a pinned tag or commit (its `README.md` lists them);
- `steamaudio/`: Steam Audio 4.8.1's release, its headers and its macOS and wasm libraries;
- `fixtures/`: the test audio, made by `make.sh` so no licence applies;
- `smoke/`: `build-libs.sh` and `run.sh`, each case natively and in wasm under node.

**The fixtures:** a log sweep (left) with pink noise (right), a chord, a 2 s loop whose last sample joins its first,
and a 10 min stream, at 48 kHz and 44.1 kHz. Each is encoded as WAV, FLAC (16 and 24 bit), MP3 (LAME), AAC-LC (Apple's
encoder, in M4A), Vorbis and Opus (in Ogg and WebM). The encodes come from ffmpeg 9.0.2, and `SHA256SUMS` records them.

**What the smoke run showed** (`smoke/results/`):
- **Every permissive C decoder makes the same samples natively and in wasm,** given what kama's `reproducible-float`
  already sends to C (`-ffp-contract=off`):
  - the decoders: dr_flac, dr_wav, dr_mp3 (with `DR_MP3_NO_SIMD`), stb_vorbis, and libopus 1.6.1 through opusfile
    0.12, the 10 min stream included;
  - the resamplers: libsamplerate's four qualities, and speexdsp's at 3, 5 and 10;
  - libmysofa's HRIR lookup, resampled to 48 kHz.

  With the platform's default contraction, MP3, Vorbis, Opus, speexdsp and the HRIR differ. Lossless decoding (FLAC,
  WAV) and libsamplerate are identical either way.
- **r8brain 7.7 differs.** On arm64 it always takes its NEON path, which has no switch to turn off.
- **`reproducible-float` covers a C seam only in part.** kama sends `-ffp-contract=off` to every C compile, the seam's
  included, but its musl math reaches only `std::math`: a C library calling `sin` still gets the platform's libm
  (`kama.driver.cpp`, at `KAMA_REPRODUCIBLE_FLOAT`). The decoders above matched anyway. Whether r8brain's difference
  is its NEON or its libm is unmeasured.
- **Gapless decoding held:** the 2 s loop decoded to exactly 96,000 frames from MP3 (the LAME tag), Vorbis and Opus
  (opusfile applies the pre-skip).
- **Steam Audio 4.8.1 ships a wasm library** (`lib/wasm/libphonon.a`, 7 MB). Its wasm build is still "experimental",
  and steam-audio#496 is still open: the archive leaves libmysofa's, pffft's and zlib's symbols undefined.
  - It links once libmysofa, pffft and emscripten's zlib are added: a 6.0 MB `.wasm` for one binaural effect.
  - Its binaural output differs between native and wasm, with the default HRTF and with a SOFA one.
  - The macOS library is universal (arm64 and x86_64) and ad hoc signed.
- **Sizes:** one wasm with every decoder, libsamplerate and libmysofa is 1.9 MB unstripped at `-O2`. r8brain with
  speexdsp is 128 KB. Steam Audio is 6.0 MB.
- **Ports:**
  - libmysofa 1.3.5 needs one define for emscripten (`portable_endian.h` has no emscripten case; `-D__linux__` takes
    musl's `<endian.h>`);
  - libsamplerate 0.2.2's CMake needs `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` on CMake 4;
  - kama's `csources` compile C++ too, with `cxxflags`, so r8brain and Steam Audio's sources are reachable from a seam.
- **SOFA files:** libmysofa's own test set carries the reference datasets, each with its licence file. Its
  `D1_48K_24bit_0.3s_FIR_SOFA.sofa` is a `MultiSpeakerBRIR`, not an HRIR set, and both libmysofa and Steam Audio
  refuse it.

**The HRTF data and its licences** (`.scratch/area4/hrtf/`). A research agent read each set's own page, its licence
file and the `License` attribute inside its SOFA file. The rows marked *loaded* were then loaded here with libmysofa
1.3.5, and the HRIR at 60° left came out identical natively and in wasm. Each set is offered as a candidate default,
or as a set a program loads itself.

| Set | Terms | Format | Here |
|---|---|---|---|
| **SADIE II** (University of York): KU100 dummy head (D1), KEMAR (D2), 18 people | **Apache-2.0**. The dataset must be referenced, in original or modified form | 44.1 and 48 kHz, 256 taps (512 at 96 kHz). D1 and D2 have 8,802 directions; the people 2,114 to 2,818 | **Loaded:** D1 and D2 at 48 kHz, 36.6 MB each. Steam Audio loads D1 too |
| HUTUBS (TU Berlin) | CC BY 4.0 | 44.1 kHz, 440 directions, 256 taps | **Loaded:** person 1, 279 taps at 48 kHz |
| 3D3A (Princeton) | CC BY 4.0 | 96 kHz, 648 directions, 2,048 taps | libmysofa refuses it (10005) |
| MIT KEMAR | "free with no restrictions on use, provided the authors are cited"; redistribution and modification not addressed | 44.1 kHz, 710 directions, 512 taps | **Loaded** (libmysofa's copy) |
| CIPIC (UC Regents) | use for any purpose; each reproduction keeps the copyright notice; written acknowledgement asked for commercial use | 44.1 kHz, 1,250 directions, 200 taps | in libmysofa's tests |
| IRCAM Listen | use for any purpose with the notice kept; modification not addressed | 44.1 kHz, 187 directions, 8,192 taps | one file opens, another does not (10001) |
| ARI (ÖAW); TH Köln KU100 | CC BY-SA 3.0 (TH Köln: CC BY 3.0 on Zenodo, BY-SA in the file) | 48 kHz | share-alike binds anything made from them |
| SADIE II's predecessor, Subject 002 | Apache-2.0, as Resonance Audio bundles it | 48 kHz WAVs, compiled in as spherical-harmonic HRIRs of orders 1 to 3 | not SOFA |
| The browsers' `PannerNode` set (IRCAM "Composite", averaged by Chris Rogers) | Firefox's copy says "granted to the Public Domain"; Chromium's README states no licence | 44.1 kHz, 240 directions, 256 taps | |

- **Steam Audio's built-in default HRTF is CIPIC subject 124,** under CIPIC's terms (its `THIRDPARTY.md`), and
  steam-audio#525 asks for a build without it.
- **What a default costs:** SADIE II's D1 is 8,802 directions × 2 ears × 256 taps, 18 MB as float32. So shipping one
  in every program means reducing it: fewer directions, shorter filters, or Resonance's spherical-harmonic form. That
  is area 4's question 2.
- **libmysofa** needs only zlib and libm: it has its own HDF5 reader. It bundles the Speex resampler, and Steam Audio
  builds it for wasm with the same `-D__linux__` define as here.

## 9. Area 4, measured

Probes for area 4 ([AGENTS.audio.md](AGENTS.audio.md) § The design pass, 4), run 2026-11-13 on the Mac (Apple M4)
**on kama 0.9.945** (`c474b5e9`, kyoten's pin from that day), emsdk 7.0.0, node 26.13.0 and the pinned browsers,
headless and muted. Nothing was audible: every case rendered offline or into memory. Each probe re-runs with its
`run.sh` and writes `results/`. **Costs are ms of one core per second of audio**, the median of 3 runs of 1 s, at
128-frame blocks and 48 kHz. Some ran with the kama project's own test matrix on the same machine (load average 5 to
8), so a row can vary by 10 to 20% between runs; each comparison below is made within a run.

### 9.1 Where a sound seems to come from (`.scratch/aud-probe-spatial/`, P5)

**What was built.** A binaural renderer and an Ambisonics rung in kama, the same source on every leg
(`app/src/`, on area 4's shared FFT and partitioned convolver in `.scratch/area4/dsp/`):
- **The data.** SADIE II's D1 (KU100, Apache-2.0) converted at build time by `.scratch/area4/hrtfconv/conv` (C,
  native): its regular 1° grid (22 rings of 360 azimuths and the two poles, 7,922 directions; the set's 880 other
  points are left out), each HRIR made minimum phase (by the real cepstrum) with its onset kept as a fractional delay,
  and spherical-harmonic HRIRs to order 3 by least squares. Where no file can be read (a browser page), a synthetic set
  of the same shape stands in: a render's cost depends on the shape only.
- **A binaural voice.**
  - The HRIR comes from the four grid directions around the source, blended bilinearly.
  - It is convolved directly (FIR) or by uniformly partitioned FFT (overlap-save, an FFT of 256, one forward
    transform a block shared by both ears).
  - Each ear is then delayed by its interpolated onset (the ITD) through a cubic Lagrange delay line, the delay
    ramped across the block.
  - When the source moves, the block is rendered through the old and the new filters and crossfaded, every block or
    every 4 blocks (10.7 ms, a usual update rate).
- **Ambisonics.** Every source is encoded into one field (ACN, SN3D, its gains ramped across the block), the field is
  rotated by a turning head (a block-diagonal matrix applied in full), and decoded binaurally once by convolving each
  channel with the SH HRIRs. A symmetric head needs one ear's filters: L = S + A and R = S - A.
- **The checks.** Hashes of each case's output over 200 blocks, a moving 1 kHz sine with and without the crossfade,
  and the FFT's output against the FIR's.
- **The references.** Steam Audio 4.8.1's binaural and Ambisonics effects on the same SOFA file (`steam/`), natively
  (its release's dylib) and in wasm (its `libphonon.a`, linked with libmysofa, pffft and zlib, under node); and N
  `PannerNode`s with HRTF in each browser, rendered offline (`panner/`).

**Correctness:**
- **Every leg makes the same samples.** With D1, native with `reproducible-float` equals wasm under node at `-Oz` and
  at `-O3`. With the synthetic set, native equals Chrome and Firefox at both levels. Native without the flag differs,
  as decision 14 found.
- **The FFT path equals the FIR path to 4.2e-7** on a peak of 0.45.
- **The crossfade removes the click.** A 1 kHz sine moving at 180°/s has a largest second difference of 0.0086 with
  the crossfade, the sine's own. Without it, it has 0.0171: a step at each filter switch, which the ITD's delay moves
  off the block's edge.

**The cost** (`results/`; `summarize.py` prints the whole table). 64 voices, ms of one core per second of audio.
"kama `-Oz`" is kama's release; "kama `-O3`" is the same emitted C at `-O3`, which kama 0.9.945 lets no program choose
(KAUD-6, filed from this probe; `.scratch/area4/tools/emcc` swaps the flag and nothing else):

| 64 voices | native | Chrome, kama `-Oz` | Chrome, `-O3` | Firefox, kama `-Oz` | Firefox, `-O3` | Steam Audio native | Steam Audio wasm (node) | `PannerNode` HRTF, Chrome | `PannerNode` HRTF, Firefox |
|---|---|---|---|---|---|---|---|---|---|
| static | 170 | 1,397 | 127 | 489 | 191 | 184 | 293 | 40 | 76 |
| moving, filters every 4 blocks | 223 | 2,084 | 187 | 657 | 266 | 206 | 304 | 275 | 108 |
| moving, filters every block | 413 | 4,032 | 355 | 1,325 | 551 | 206 | 309 | | |

- **256 voices:** static 618 natively, 522 in Chrome at `-O3`, 669 in Firefox at `-O3`; Steam Audio 830 natively and
  1,266 in wasm; `PannerNode` 211 (Chrome) and 306 (Firefox). Moving with filters every 4 blocks: 850 natively, 758
  and 982 in the browsers at `-O3`; Steam Audio 845 natively; `PannerNode` 1,322 and 633.
- **Shorter filters cost less:** 128 taps, 64 voices, static, 133 natively (256 taps: 170). The FIR is dearer than the
  FFT at 256 taps (16 voices: 282 against 29) and close to it at 64 taps (64 voices: 250).
- **Ambisonics** (sources moving, the head turning):

  | | native | Chrome `-O3` | Firefox `-O3` | Chrome, kama `-Oz` | Steam Audio native | Steam Audio wasm |
  |---|---|---|---|---|---|---|
  | order 1, 256 sources | 60 | 46 | 71 | 300 | 26 | 27 |
  | order 3, 64 sources | 61 | 45 | 59 | 388 | 29 | 41 |
  | order 3, 256 sources | 175 | 144 | 186 | 1,035 | 70 | 85 |

- **Sizes and loading:** the renderer's wasm is 76 KB (`-Oz`) or 101 KB (`-O3`). Steam Audio's is 6.03 MB, and it
  loads D1's SOFA in 714 ms natively and 1,004 ms in wasm.
- **Steam Audio's legs differ only by rounding:** 107 dB below the signal for binaural and 112 dB for order-3
  Ambisonics, at most 4.2e-6, but only 359 of 51,200 samples are equal. Its prebuilt libraries cannot be held to equal
  samples.

**Where the renderer's time goes: the FFT.** A forward and an inverse of 256 real points:

| | native | wasm `-O3` | wasm, kama `-Oz` | same bits on every leg |
|---|---|---|---|---|
| area 4's FFT, in kama (radix 2, checked indexing) | 2,701 ns | 2,221 ns | 26,357 ns | yes |
| pffft (r8brain 7.7's copy), SIMD | 180 ns | 193 ns | | **yes, with `-ffp-contract=off`**: NEON, wasm SIMD and wasm scalar all hash `7303612289528294521`; native with contraction on differs |
| pffft, wasm scalar | | 648 ns | | yes |

- A static voice does one forward and two inverse transforms a block: 1.52 ms a second, 85% of a voice's cost at 16
  voices and 57% at 64. **At pffft's speed a voice would cost a fifth to a half of what it does,** under Steam
  Audio's binaural.
- **pffft is permissive** (FFTPACK v5's terms: keep the notice, no endorsement) and adds 37 KB of wasm at `-Oz`.
  kama's `reproducible-float` already sends `-ffp-contract=off` to a C seam. The x86-64 SSE path is not yet compared
  (the Windows box).
- **The kernels on their own** (`.scratch/area4/dsp/kernels/`): natively, checked indexing costs nothing measurable
  (a 129-bin complex multiply-accumulate in 18 ns either way). In wasm at `-Oz` the same loop takes 4,446 ns over views
  and 326 ns over raw pointers; at `-O2`, 100 and 84 ns. That is KAUD-6's repro.

**So:**
- **One renderer in kama makes the same samples on every leg**, natively and in both browsers, with SADIE's data.
  Neither Steam Audio's libraries nor the browsers' `PannerNode` can (§ 2.3).
- **Natively it already costs what Steam Audio's binaural does,** with an FFT 15 times slower than the state of the
  art. **In the browser it costs the same as natively at `-O3`, and 5 to 10 times more at kama's `-Oz`.** So the web's
  voice count depends on KAUD-6.
- **The browser's own `PannerNode` is cheaper while static** (native C++, a different sound per browser), and
  Chrome's costs 6 times more while its position is automated.
- **Ambisonics' cost per source is a few gains**, so at 256 sources order 3 costs a third of binaural. Steam Audio's
  encode is 2.5 times cheaper than this first one, which ramps gains per sample through checked indexing.

### 9.2 Which HRTF data, and how small a default can be (`.scratch/aud-probe-hrtf/`, P10)

`reduce.c` (C, native, a build-time analysis) takes SADIE II's D1 on its 1° grid and measures each reduction against
the measured HRIR at the same direction and ear: the **log-spectral distortion** (LSD, dB RMS from 100 Hz to 20 kHz on
a 1,024-point spectrum; about 1 dB is the usual threshold of audibility), as a mean and a 95th percentile over every
direction and ear, and where it applies the ITD's error. `sofaload.c` times reading SOFA at run time.

| reduction (float32 unless said) | size | LSD mean / p95, dB |
|---|---|---|
| the full grid, minimum phase, 256 taps | 16.3 MB | 0.00 / 0.00 |
| minimum phase cut to 128 / 96 / 64 taps | 8.2 / 6.2 / 4.1 MB | 0.08 / 0.20; 0.17 / 0.34; 0.29 / 0.66 |
| cut to 48 / 32 / 16 taps | 3.1 / 2.1 / 1.1 MB | 0.41 / 0.96; 0.68 / 1.56; 1.65 / 3.11 |
| every 2nd / 3rd / 5th / 10th / 15th azimuth, the rest interpolated (minimum phase, onsets interpolated) | 8.2 / 5.4 / 3.3 / 1.6 / 1.1 MB | 0.19 / 0.91; 0.28 / 1.43; 0.45 / 2.35; 0.76 / 3.48; 0.99 / 4.09 |
| the same, the raw HRIRs blended as they are | | 0.37 / 0.98; 0.67 / 1.93; 1.57 / 5.25; 2.93 / 8.22; 3.30 / 8.14 |
| every 5th azimuth and every 2nd ring | 1.8 MB | 1.26 / 4.19 |
| 64 taps in float16 / int16, against float32 | half | adds 0.003 / 0.005 (p95 0.008 / 0.016) |
| **2°, 64 taps, float16** | **1.05 MB** | **0.38 / 1.09** |
| 2°, 128 taps, float16 | 2.06 MB | 0.22 / 0.92 |
| 3°, 64 taps, float16 | 0.70 MB | 0.44 / 1.49 |
| 5°, 64 taps, float16 | 0.42 MB | 0.59 / 2.39 |
| SH HRIRs, order 1 / 2 / 3, least squares | 4 / 9 / 16 KB | 19.2 / 26.0; 16.4 / 24.1; 14.9 / 21.9 |
| SH HRIRs, order 1 / 2 / 3, MagLS (magnitudes only above 2 kHz) | 4 / 9 / 16 KB | 6.0 / 10.9; 6.5 / 9.8; 6.1 / 8.9 |

- **The ITD's error** when directions are left out: 15 µs mean at 2° and 24 at 5°. The 95th percentile is already
  80 µs at 2°, which looks like the onset estimate's own noise at the far ear rather than the interpolation's.
- **Minimum phase with the onset as a delay interpolates far better than raw HRIRs:** at 5°, 0.45 dB against 1.57.
  So the converter's form is the one to interpolate.
- **SH HRIRs at order 3 or less are the Ambisonics rung's known price:** a sound field of 16 channels cannot hold a
  head's high frequencies. MagLS takes the error from 15 to 6 dB. This first MagLS has no diffuse-field covariance
  constraint, so 6 dB is an upper bound for the method.
- **Reading SOFA at run time** (D1, 36.6 MB, 8,802 directions): libmysofa takes 101 ms natively and 117 ms in wasm
  (node), and with zlib adds 48 KB of wasm (68,058 against 19,828 B for the same program without it). Reading the
  converter's table takes 2.5 ms.
- **So a default that ships in every program can be about 1 MB** (2°, 64 taps, float16: 0.38 dB mean, 1.1 dB p95),
  before the transfer's own compression. The full set stays available to a program that wants it. Steam Audio's
  default instead is CIPIC subject 124, under CIPIC's terms (§ 8).
