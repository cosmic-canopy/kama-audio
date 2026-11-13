# Audio: the owner's projects, Web Audio as browsers ship it, the native engines, kama's real-time model, and the state of the art

The design pass's evidence, gathered 2026-11-13 on the Mac (Apple M4, 16 GB, macOS 26.7.3) for the questions in
[AGENTS.audio.md](AGENTS.audio.md) § The design pass. Four research agents read the sources below; what each section
measured itself is marked *Measured*, and the probes are in `.scratch/aud-probe-*/` (git-ignored), each re-runnable
with its `run.sh`. *(unchecked)* marks a claim taken from one reading only. **Nothing here is a decision.** The
decisions are the owner's and go in AGENTS.audio.md with their reasons.

| Source | Version, as of 2026-11-13 |
|---|---|
| kama | 0.9.938+g94365be5, kyoten's pin, built from a clean clone on this Mac |
| Chrome for Testing | 157.0.8103.50, pinned in `~/browsers`, headless and muted |
| Firefox | 160.0, pinned in `~/browsers`, headless, autoplay blocked |
| Safari | 27.2, the system's. Not measured yet: it has no headless mode, so a run waits for the owner |
| emscripten | emsdk 7.0.0 (`777e6e5d`), the latest; the Windows box verified 6.0.13 |

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
