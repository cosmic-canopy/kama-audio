# @kama/audio roadmap

**The order of work, and nothing else.** One row per item: what it is, and a link to its reasoning in
[ROADMAP_DETAIL.md](ROADMAP_DETAIL.md) or in [AGENTS.audio.md](AGENTS.audio.md) § Decided.
- Every feature the library will have, with its rungs, status, test and budget, is [FEATURES.md](FEATURES.md).
- What the library is, as each piece lands, is [SPEC.md](SPEC.md).
- The history is the git log.

> **Keep this file short.** `tools/check-roadmap.sh` holds the split, as `@kama/graphics`' guard does:
> - a line ceiling, and a ceiling per row;
> - every detail section scheduled by a row;
> - every id valid.
>
> **`AUD-<n>` is a permanent id, not a position.** It is assigned once, from the counter below, which the same edit
> bumps. It is never reused or renumbered, and a shipped row's id retires with it.

**Next id: AUD-40**

**The order is by example** (decision 28, 2026-11-15: "sounds good to me so far", so it may change). Each slice is what one of the library's examples needs, built depth-first on
the web and natively, and every example is a test. The parts that areas 2 to 4 decided are built by the first slice
that needs each ([§ The parts](#the-parts)).

## NOW: the first slice

| id | item | why |
|---|---|---|
| AUD-29 | **A sample-exact loop**, the first slice through every part. It builds the real-time and offline contexts, the command ring, the slots and the way back, the declared block, a buffer player with exact loop points through a gain, WAV, miniaudio natively, both web routes, the first gesture's unlock, and the first golden | [detail](ROADMAP_DETAIL.md#loop) |

## NEXT: a slice per example

| id | item | why |
|---|---|---|
| AUD-30 | **A game's sounds**: the upper tier's sounds, variations, voices, stealing, buses, sends and ducking; emitters and a listener with panning and HRTF; Vorbis and Opus; the voices' resampling; a streamed bed; the reverbs | [detail](ROADMAP_DETAIL.md#sfx) |
| AUD-31 | **Adaptive music**: a tempo and bar clock, quantized starts, transitions, playlists, layers and stingers, exact seeks, gapless hand-offs, and snapshots | [detail](ROADMAP_DETAIL.md#music) |
| AUD-32 | **Voice chat**: the microphone with the platform's echo cancellation, a tap to the program, Opus encoded, a source the program feeds, voice activity, and the output as a media stream on the web | [detail](ROADMAP_DETAIL.md#voice) |
| AUD-33 | **Spatial sound on a standalone headset**: Ambisonics turned by the head's pose, natively on Android and on WebXR | [detail](ROADMAP_DETAIL.md#headset) |
| AUD-34 | **A synth on MIDI**: oscillators, noise, envelopes and modulators, a-rate parameters, the waveshaper and modulation effects, polyphony, MIDI in as stamped frames, and a program's processor registered by name | [detail](ROADMAP_DETAIL.md#synth) |
| AUD-35 | **A multitrack session**: tracks as clip players with inserts, faders, sends and sidechains; latency compensation; EQ, the limiter and dither; loudness and true peak; recording; render workers; and a bounce | [detail](ROADMAP_DETAIL.md#session) |

## LATER: the state of the art, as programs ask

| id | item | why |
|---|---|---|
| AUD-19 | **Reading SOFA at run time**, a module a program opts into, natively and on the web: libmysofa, converted in memory into the same table | [decision 22](AGENTS.audio.md#decided) |
| AUD-20 | **Geometric acoustics, a later tier**: triangles with acoustic materials and a ray-tracing contract the program fills; occlusion and transmission by ray casts, a reverb from the room, pathing around corners, convolution reflections. Its own probe, Steam Audio the reference | [decision 20](AGENTS.audio.md#decided) |
| AUD-36 | **Audio objects and height beds**: 7.1.4 and object output through each platform's spatial audio | [detail](ROADMAP_DETAIL.md#objects) |
| AUD-37 | **Haptics from sound**: a controller's or a headset's vibration as a bus | [detail](ROADMAP_DETAIL.md#haptics) |
| AUD-38 | **kama in place of the vendored C**, behind each seam, once it measures equal: a kama FFT for pffft, kama device backends for miniaudio, a kama rung for libsamplerate | [detail](ROADMAP_DETAIL.md#kama-native) |

## ALONGSIDE

| id | item | why |
|---|---|---|
| AUD-39 | **The first publish**: `tests/` green on every target the library claims, the notices complete, and the README and description written for the registry | [detail](ROADMAP_DETAIL.md#publish) |

<a id="the-parts"></a>
## The parts: what areas 2 to 4 decided, by the slice that first builds each

| id | item | why |
|---|---|---|
| AUD-1 | **The command protocol**: flat, typed commands on one ordered ring per context, each applied in the quantum it lands, a call's time inside it as an int64 frame its node keeps; a flush published whole, by the shared ring or one transferred buffer; the backlog bounded, an error past it; late calls counted; replay offline | [decisions 7, 8, 32, 33](AGENTS.audio.md#decided) · AUD-29 |
| AUD-2 | **Nodes and buffers as counted resources over a slot table with generations**: the program's side picks slots. Web Audio's lifetime rule on the audio side. `close()`, after which a call is a reported error | [decision 4](AGENTS.audio.md#decided) · AUD-29 |
| AUD-3 | **The way back**: an event ring sized from the slot capacity (a sound's end, a slot freed, an error, a block handed back), and snapshots of meters and the playhead, all read in `update()` | [decision 9](AGENTS.audio.md#decided) · AUD-29 |
| AUD-4 | **The context's options and its memory**: every capacity declared (each parameter's events among them), an injected `Allocator` (the global heap by default), everything the audio side uses allocated and freed on the program's side, and a declared answer at every limit | [decisions 5, 6, 32](AGENTS.audio.md#decided) · AUD-29 |
| AUD-5 | **`update()`**: the upper tier's home on the program's thread. It polls the way back and turns the upper tier's decisions into stamped lower-tier commands | [decision 10](AGENTS.audio.md#decided) · AUD-29 |
| AUD-6 | **`AudioWorkletProcessor` as a contract**: a `@noheap` `process`, a render callback typed `@noheap @noparks`, processors built and dropped on the program's side, and the web's quantum natively behind a FIFO | [decision 11](AGENTS.audio.md#decided) · AUD-29 |
| AUD-7 | **The web's two routes**: the shared build (the Wasm Audio Worklet and the ring) and the pair (the program's build and the worklet's instance, one transferred `ArrayBuffer` a flush), a loader that picks by `crossOriginIsolated`, and the template a program copies until kama can build the second artifact (KAUD-5) | [decision 12](AGENTS.audio.md#decided) · AUD-29 |
| AUD-8 | **Processors registered by name**: a factory per type over plain-data options, run on the program's side with shared memory and in the worklet's instance without | [decision 13](AGENTS.audio.md#decided) · AUD-34 |
| AUD-9 | **The engine's declared block**: a callback-size request per platform (`renderSizeHint`, the device's period), several blocks a call or a FIFO between them, and Web Audio 1.1's features reported on the context | [decision 15](AGENTS.audio.md#decided) · AUD-29 |
| AUD-10 | **Starting**: the page-side unlock on the first gesture, the context's states in `update()`, and iOS's audio session as an option | [decision 16](AGENTS.audio.md#decided) · AUD-29 |
| AUD-11 | **The native device layer**: miniaudio vendored (its device layer only, frameworks linked on Apple), device added and removed events from each OS, the custom-backend seam for a console's package, offline rendering for tests | [decision 17](AGENTS.audio.md#decided) · AUD-29 |
| AUD-12 | **Input**: a media-stream source node on the web, a capture or duplex device natively, echo cancellation from the OS's voice processing where it has one | [decision 18](AGENTS.audio.md#decided) · AUD-32 |
| AUD-13 | **Render workers natively**: a declared count, real-time threads joined to the device's workgroup (MMCSS, rtkit elsewhere), woken by a semaphore, summed in a fixed order | [decision 19](AGENTS.audio.md#decided) · AUD-35 |
| AUD-14 | **`reproducible-float` is the program's**: the package's tests program sets it, and its docs say what it buys (the same samples between builds) | [decision 14](AGENTS.audio.md#decided) · AUD-29 |
| AUD-15 | **Spatial sound's core, in kama on both legs**: equal-power panning; HRTF binaural (four HRIRs blended, minimum phase with onsets, partitioned FFT convolution, crossfaded); Ambisonics (encoded, rotated by the head, decoded binaurally once); the room's inputs | [decision 20](AGENTS.audio.md#decided) · AUD-30 |
| AUD-16 | **pffft vendored through the C seam** as the core's FFT, its FFTPACK notice kept, built with `-ffp-contract=off`, its twiddles computed in double and rounded once to float; its SSE path compared with NEON's and wasm's on the Windows box first | [decisions 21, 26](AGENTS.audio.md#decided) · AUD-30 |
| AUD-17 | **The HRTF converter**, the package's build tool: any SOFA set to the compact table (the regular grid, minimum phase with onsets, MagLS SH HRIRs), another grid resampled onto one | [decision 22](AGENTS.audio.md#decided) · AUD-30 |
| AUD-18 | **The default HRTF set**: SADIE II's D1 (KU100) at 2°, 64 taps and float16, about 1 MB, its citation in the package's notices | [decision 22](AGENTS.audio.md#decided) · AUD-30 |
| AUD-21 | **The decoders and containers, in the C seam on every leg**, each codec a module a program opts into: dr_wav, dr_flac, dr_mp3 (LAME's delay and padding), stb_vorbis, libopus through opusfile (Ogg) and nestegg (WebM); libogg, nestegg and minimp4; each container's priming trimmed | [decision 23](AGENTS.audio.md#decided) · AUD-29 |
| AUD-22 | **AAC through the platform**: WebCodecs on the web, fed by the package's MP4 reader, which trims the edit list's priming; AudioToolbox and Media Foundation natively. Documented as the one codec whose samples differ between legs | [decision 23](AGENTS.audio.md#decided) · asked |
| AUD-23 | **The voices' resampling ladder, in kama**: linear, cubic, and band-limited interpolation at 8, 16 and 32 zero crossings (the cutoff following the pitch), a fractional read position and a ratio per frame; a polyphase bank and SIMD | [decision 24](AGENTS.audio.md#decided) · AUD-30 |
| AUD-24 | **libsamplerate's best vendored behind the package's seam** for converting a whole buffer (at load, in a bounce); replaceable by a kama rung measured at 140 dB or better | [decision 24](AGENTS.audio.md#decided) · AUD-30 |
| AUD-25 | **Streams**: one decode step for our decoders, on a decode thread natively, a Wasm Worker on the shared route, and a decode Worker on the page route paced by the worklet's read count; each stream's ring a declared capacity; prepared, then started, stopped and handed off on stamped frames | [decision 25](AGENTS.audio.md#decided) · AUD-30 |
| AUD-26 | **Exact seeks and loops**: each codec's pre-roll measured and decoded before the target (Opus: 1 s), a seek as a second stream handed off on a stamped frame; a loop back to the start exact, a loop point mid-file by the exact seek | [decision 25](AGENTS.audio.md#decided) · AUD-31 |
| AUD-27 | **A stream's bytes and AAC streams**: the compressed bytes through the package's source, whole in memory or read in chunks (a file natively, a fetch's body on the web) through each decoder's callbacks; AAC streams through the platform's decoder in the same decode step | [decisions 23, 25](AGENTS.audio.md#decided) · AUD-30 |
| AUD-28 | **The convolution reverb**: a non-uniform partitioned convolution in kama on every leg, a 128-frame head and longer stages spread over the quanta before they are due, staggered; the layout from the response's length; natively the tail optionally on render workers | [decision 26](AGENTS.audio.md#decided) · AUD-30 |
