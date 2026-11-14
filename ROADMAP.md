# @kama/audio roadmap

**The order of work, and nothing else.** One row per item: what it is, and a link to its reasoning in
[AGENTS.audio.md](AGENTS.audio.md) § Decided. Its history is in the git log.

> **`AUD-<n>` is a permanent id, not a position.** It is assigned once, from the counter below, which the same edit
> bumps. It is never reused or renumbered, and a shipped row's id retires with it.

**Next id: AUD-23**

## NOW: the design pass

Areas 4 and 5 of [AGENTS.audio.md](AGENTS.audio.md#the-design-pass-what-is-open). Nothing is built before the
decisions it depends on are recorded. Area 5 puts the rows below in order, by example.

## LATER: what areas 2 to 4 decided, unordered until area 5

| id | item | why |
|---|---|---|
| AUD-1 | **The command protocol**: flat, typed commands stamped with an int64 frame, on one ordered ring per context. The ring in shared memory, and one transferred `ArrayBuffer` per flush where the page cannot be isolated. The backlog, bounded by its capacity, with an error to the caller past it. Late commands counted. Replay of a recorded stream offline | [decisions 7, 8](AGENTS.audio.md#decided) |
| AUD-2 | **Nodes and buffers as counted resources over a slot table with generations**: the program's side picks slots. Web Audio's lifetime rule on the audio side. `close()`, after which a call is a reported error | [decision 4](AGENTS.audio.md#decided) |
| AUD-3 | **The way back**: an event ring sized from the slot capacity (a sound's end, a slot freed, an error, a block handed back), and snapshots of meters and the playhead, all read in `update()` | [decision 9](AGENTS.audio.md#decided) |
| AUD-4 | **The context's options and its memory**: every capacity declared, an injected `Allocator` (the global heap by default), everything the audio side uses allocated and freed on the program's side, and a declared answer at every limit | [decisions 5, 6](AGENTS.audio.md#decided) |
| AUD-5 | **`update()`**: the upper tier's home on the program's thread. It polls the way back and turns the upper tier's decisions into stamped lower-tier commands | [decision 10](AGENTS.audio.md#decided) |
| AUD-6 | **`AudioWorkletProcessor` as a contract**: a `@noheap` `process`, a render callback typed `@noheap @noparks`, processors built and dropped on the program's side, and the web's quantum natively behind a FIFO | [decision 11](AGENTS.audio.md#decided) |
| AUD-7 | **The web's two routes**: the shared build (the Wasm Audio Worklet and the ring) and the pair (the program's build and the worklet's instance, one transferred `ArrayBuffer` a flush), a loader that picks by `crossOriginIsolated`, and the template a program copies until kama can build the second artifact (KAUD-5) | [decision 12](AGENTS.audio.md#decided) |
| AUD-8 | **Processors registered by name**: a factory per type over plain-data options, run on the program's side with shared memory and in the worklet's instance without | [decision 13](AGENTS.audio.md#decided) |
| AUD-9 | **The engine's declared block**: a callback-size request per platform (`renderSizeHint`, the device's period), several blocks a call or a FIFO between them, and Web Audio 1.1's features reported on the context | [decision 15](AGENTS.audio.md#decided) |
| AUD-10 | **Starting**: the page-side unlock on the first gesture, the context's states in `update()`, and iOS's audio session as an option | [decision 16](AGENTS.audio.md#decided) |
| AUD-11 | **The native device layer**: miniaudio vendored (its device layer only, frameworks linked on Apple), device added and removed events from each OS, the custom-backend seam for a console's package, offline rendering for tests | [decision 17](AGENTS.audio.md#decided) |
| AUD-12 | **Input**: a media-stream source node on the web, a capture or duplex device natively, echo cancellation from the OS's voice processing where it has one | [decision 18](AGENTS.audio.md#decided) |
| AUD-13 | **Render workers natively**: a declared count, real-time threads joined to the device's workgroup (MMCSS, rtkit elsewhere), woken by a semaphore, summed in a fixed order | [decision 19](AGENTS.audio.md#decided) |
| AUD-14 | **`reproducible-float` is the program's**: the package's tests program sets it, and its docs say what it buys (the same samples between builds) | [decision 14](AGENTS.audio.md#decided) |
| AUD-15 | **Spatial sound's core, in kama on both legs**: equal-power panning; HRTF binaural (the grid's four nearest HRIRs blended, minimum phase with each ear's onset as a fractional delay, partitioned FFT convolution, a crossfade when the filters change); Ambisonics (encode, rotate by the head's pose, decode binaurally once); and the room's inputs (distance, air absorption, occlusion and transmission filters, reverb sends, a slot for a reflection impulse response) | [decision 20](AGENTS.audio.md#decided) |
| AUD-16 | **pffft vendored through the C seam** as the core's FFT, its FFTPACK notice in the package's notices, built with `-ffp-contract=off`; its x86-64 SSE path compared with NEON's and wasm's on the Windows box before it ships | [decision 21](AGENTS.audio.md#decided) |
| AUD-17 | **The HRTF converter**, the package's build tool: any SOFA set to the compact table (the regular grid, minimum phase with onsets, MagLS SH HRIRs), another grid resampled onto one | [decision 22](AGENTS.audio.md#decided) |
| AUD-18 | **The default HRTF set**: SADIE II's D1 (KU100) at 2°, 64 taps and float16, about 1 MB, its citation in the package's notices | [decision 22](AGENTS.audio.md#decided) |
| AUD-19 | **Reading SOFA at run time**, a module a program opts into, natively and on the web: libmysofa, converted in memory into the same table | [decision 22](AGENTS.audio.md#decided) |
| AUD-20 | **Geometric acoustics, a later tier**: triangles with acoustic materials and a ray-tracing contract the program fills; occlusion and transmission by ray casts, a reverb estimated from the room, pathing around corners, convolution reflections. Run on the program's side. Its own probe, with Steam Audio as the reference, when a program first needs it | [decision 20](AGENTS.audio.md#decided) |
| AUD-21 | **The decoders and containers, in the C seam on every leg**, each codec a module a program opts into: dr_wav, dr_flac, dr_mp3 (LAME's delay and padding), stb_vorbis, libopus through opusfile (Ogg) and nestegg (WebM); libogg, nestegg and minimp4, with MP4's edit list read; each container's priming trimmed | [decision 23](AGENTS.audio.md#decided) |
| AUD-22 | **AAC through the platform**: WebCodecs on the web, fed by the package's MP4 reader, which trims the edit list's priming; AudioToolbox and Media Foundation natively. Documented as the one codec whose samples differ between legs | [decision 23](AGENTS.audio.md#decided) |
