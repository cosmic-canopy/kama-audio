# @kama/audio features

**Every feature the library will have, and where each stands.** Each row gives:
- its name in Web Audio, where Web Audio has one;
- its rungs, from cheap to best, with what each needs;
- its status;
- the example that first needs it;
- its test;
- its budget.

When each is built is [ROADMAP.md](ROADMAP.md), and what is built, exactly, is [SPEC.md](SPEC.md). The survey this map
is drawn from is [RESEARCH.md](RESEARCH.md) § 10.

> **`tools/check-features.sh` holds every row complete:**
> - a status from the fixed set;
> - an example from the table below, or `asked`;
> - a test name, unique, which `tests/` has once a rung is built;
> - a budget once a rung is built, and none before;
> - every example scheduled by a live roadmap row.

## How to read a row

- **Web Audio's name:** the lower tier keeps Web Audio's names wherever the concept is the same (decision 3), so this is
  the feature's name in the library's API, and MDN documents it. `—` is a feature Web Audio does not have: the upper
  tier's, and what a DAW, MIDI or a platform adds.
- **Rungs, cheap to best:** a feature that is a ladder (area 4) lists its rungs. A program picks a rung per sound or per
  node, and **each rung makes the same samples on every leg**, so a rung is chosen by cost, never by platform. What a
  rung needs is in parentheses. One with no needs runs everywhere:
  - `sab`: memory shared with the audio thread, natively or on a cross-origin isolated page;
  - `workers`: native render workers (decision 19);
  - `input`: a microphone, with the user's permission;
  - `midi`: Web MIDI or the OS's MIDI;
  - `1.1`: a Web Audio 1.1 feature, used where the browser has it and reported, never required (decision 15);
  - `os`: the platform's own codec or service, whose samples may differ by platform (decision 23 allows it for AAC);
  - `xr`: a head pose from an XR runtime, OpenXR natively and WebXR on the web.
- **Status:** `planned` (nothing built), `partial` (some rungs built, each marked ✓) or `built` (every rung listed).
- **Example:** the example that first needs it ([§ The examples](#the-examples)). `asked` is a feature no planned example
  needs yet. It gets a roadmap row when a program asks for it.
- **Test:** the feature's golden samples. An offline render is hashed, and the hash must be the same in native debug,
  native release and wasm (decision 14), and equal to the golden.
  - **A golden is checked before it is kept.** When it is made or changed, its render is compared with a reference
    within a stated tolerance in dB: a float64 implementation, the spec's formula, or a reference library. Only an
    explicit update command changes a golden, and its diff is reviewed. So a wrong first render never becomes the
    golden.
  - A rung whose samples are the platform's (`os`) is compared within a measured tolerance in dB instead, and says so.
  - A feature with no samples of its own, such as a ring or a slot table, is tested by its behaviour.
- **Budget:** `—` until the first measurement sets it. It holds three numbers:
  - the wasm the feature adds, in KB after brotli;
  - its render cost, in ms of one core per second of audio for one instance (a voice, a node), offline, natively and
    in wasm under node at kama's release default, `-O3` since KR-332 (KAMA_GAPS.md KAUD-6). `-Oz` is noted beside it,
    since a size-first program builds the package so unless it lists it under `release.speed`;
  - its memory for one instance at its default options (decision 6). A footprint you can calculate needs it.

  **A budget never limits what is built** (kyoten's rule, the owner, 2026-11-11):
  - a feature enters with whatever it first measures;
  - a ratchet fails only when something already built gets costlier, and raising one is a change with its reason, never
    a refusal;
  - a rung's cost decides which rung a program's default picks, never whether the rung exists;
  - a program pays only for what it uses, since an unused feature drops out at link time;
  - a time is compared within a tolerance measured from its own noise.

## The examples

Each example is the library's own program, and a test. It names no engine or game: each stands for what a program of
that kind needs.

| Example | What it is | Row |
|---|---|---|
| loop | a sample-exact loop on the web and natively: a decoded buffer looped through a gain, its seam exact | AUD-29 |
| sfx | a game's sounds: one-shots with variations, voices limited and stolen, buses and ducking, sounds placed around a listener, a streamed bed | AUD-30 |
| music | adaptive music: sections and layers joined on the beat, stingers, and the music ducked under dialogue | AUD-31 |
| voice | voice chat: the microphone in with echo cancellation, encoded; remote voices decoded, placed and tapped for captions | AUD-32 |
| headset | spatial sound on a standalone headset: an Ambisonics field turned by the head, natively and on WebXR | AUD-33 |
| synth | a synth played from MIDI: oscillators, envelopes, filters, polyphony and a program's own processor | AUD-34 |
| session | a multitrack session: tracks as clip players with inserts, faders, sends and sidechains, automation, delay compensation, loudness and an offline bounce | AUD-35 |

## The context and the graph

| Feature | Web Audio's name | Rungs, cheap to best (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Real-time context | `AudioContext` | the device's callback natively · the Wasm Audio Worklet on the web | planned | loop | context | — |
| Offline rendering | `OfflineAudioContext` | as fast as the CPU allows, the samples real time makes · an open length rendered in chunks | planned | loop | offline-render | — |
| Stamped commands on one ring | — | one transferred buffer a flush · the shared ring (`sab`) | planned | loop | command-ring | — |
| The backlog, and late commands counted | — | — | planned | loop | backlog | — |
| Command capture and replay | — | a recorded stream rendered offline | planned | session | replay | — |
| Nodes and buffers as counted resources | `AudioNode`, `AudioBuffer` | slots with generations, chosen on the program's side | planned | loop | slots | — |
| A node kept while it can sound | Web Audio's lifetime rule | a playing source until it ends · a live input or a tail not yet silent | planned | loop | node-lifetime | — |
| The way back: events and levels | `onended` | an event ring · latest-value snapshots | planned | loop | way-back | — |
| Declared capacities and the program's memory | — | the global heap · an std `Arena` · the program's own allocator, as callbacks (`AudioMemory`) | planned | loop | capacities | — |
| The engine's declared block | `renderSizeHint`, `renderQuantumSize` (1.1) | several blocks a callback · a FIFO between the block and the device | planned | loop | block | — |
| Connections and fan-in | `connect`, `disconnect` | — | planned | loop | connect | — |
| Channel count, mode and interpretation | `channelCount`, `channelCountMode`, `channelInterpretation` | discrete · the speakers' up-mix and down-mix | planned | sfx | channel-rules | — |
| Speaker layouts | Web Audio's mono to 5.1 | stereo · quad · 5.1 · 7.1 · 7.1.4 | planned | asked | speaker-layouts | — |
| Starting and the context's states | `resume()`, `state`, `"interrupted"` (1.1) | unlocked on the first gesture · `resume()` from the program | planned | loop | context-states | — |
| Output timestamps and latency | `getOutputTimestamp()`, `outputLatency`, `baseLatency` | — | planned | loop | output-timestamp | — |
| Device errors | `onerror` (1.1) | reported on the context (`1.1` on the web) | planned | loop | device-error | — |
| Playback statistics | `playbackStats` (1.1) | the engine's own counts · the platform's underruns (`1.1` on the web) | planned | loop | playback-stats | — |
| The web's two routes, picked by the loader | — | the page route, the worklet's own instance · the shared route (`sab`) | planned | loop | web-routes | — |
| The same samples on every leg | — | the program's `reproducible-float` | planned | loop | same-samples | — |
| Render workers | — | the device's thread · declared workers joined to its workgroup (`workers`) | planned | session | render-workers | — |
| An iOS audio session | — | — | planned | asked | ios-session | — |

## Parameters and automation

| Feature | Web Audio's name | Rungs, cheap to best (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Parameters | `AudioParam` | — | planned | loop | param | — |
| The automation timeline | `setValueAtTime`, `linearRampToValueAtTime`, `exponentialRampToValueAtTime`, `setTargetAtTime`, `setValueCurveAtTime`, `cancelScheduledValues`, `cancelAndHoldAtTime` | — | planned | loop | param-automation | — |
| a-rate and k-rate | `automationRate` | once a block · once a frame | planned | synth | automation-rate | — |
| A parameter driven by a node | `connect(param)`, `computedValue` | — | planned | synth | param-modulation | — |
| Modulators | — | an LFO · an envelope · an envelope follower · random | planned | synth | modulators | — |

## Sources

| Feature | Web Audio's name | Rungs, cheap to best (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Buffer player | `AudioBufferSourceNode` | — | planned | loop | buffer-source | — |
| Loop points, exact | `loop`, `loopStart`, `loopEnd` | — | planned | loop | loop-exact | — |
| Sub-sample starts, offsets and durations | `start(when:, offset:, duration:)` | — | planned | loop | sub-sample-start | — |
| Playback rate and detune | `playbackRate`, `detune` | the resampling ladder's rungs | planned | sfx | playback-rate | — |
| Loop counts and bidirectional loops | — | — | planned | asked | loop-modes | — |
| Oscillator | `OscillatorNode`, `PeriodicWave` | band-limited, as the spec asks · a `PeriodicWave`'s own harmonics | planned | synth | oscillator | — |
| Constant source | `ConstantSourceNode` | — | planned | loop | constant-source | — |
| Noise | — | white · pink | planned | synth | noise | — |
| A source the program feeds | — | a ring of frames the program fills | planned | voice | fed-source | — |
| Media-stream sources | `MediaStreamAudioSourceNode`, `MediaStreamTrackAudioSourceNode` | the web; natively, a capture device | planned | voice | stream-source | — |
| Media element source | `MediaElementAudioSourceNode` | the web only | planned | asked | media-element | — |
| Streams | — | decoded ahead on a decode thread, a Wasm Worker (`sab`) or a decode Worker | planned | sfx | stream | — |
| Exact seeks in a stream | — | the codec's pre-roll decoded and discarded | planned | music | stream-seek | — |
| Gapless hand-offs between streams | — | on a stamped frame | planned | music | stream-handoff | — |
| Sync points in a sound | — | reported on the way back | planned | music | sync-points | — |
| Compressed samples decoded per voice | — | — | planned | asked | compressed-sample | — |

## Effects

| Feature | Web Audio's name | Rungs, cheap to best (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Gain | `GainNode` | — | planned | loop | gain | — |
| Delay | `DelayNode` | a whole frame · a fractional delay, interpolated | planned | session | delay | — |
| Biquad filters | `BiquadFilterNode`'s eight types | — | planned | sfx | biquad | — |
| IIR filter | `IIRFilterNode` | — | planned | asked | iir | — |
| Parametric EQ | — | biquads in series · linear phase, with latency | planned | session | eq | — |
| Waveshaper | `WaveShaperNode` | none · 2× · 4× oversampled | planned | synth | waveshaper | — |
| Compressor | `DynamicsCompressorNode` | Web Audio's parameters · multiband | planned | sfx | compressor | — |
| Expander and gate | — | — | planned | voice | expander | — |
| Limiter | — | lookahead, with latency · true peak, oversampled | planned | session | limiter | — |
| Algorithmic reverb | — | a feedback delay network · with early reflections | planned | sfx | reverb | — |
| Convolution reverb | `ConvolverNode` | non-uniform partitions · the tail on render workers (`workers`) | planned | sfx | convolver | — |
| Chorus, flanger, phaser and tremolo | — | — | planned | synth | modulation-effects | — |
| Pitch shift | — | granular · a phase vocoder | planned | asked | pitch-shift | — |
| Time stretch | — | a phase vocoder · a kama rung later | planned | asked | time-stretch | — |
| Stereo panner | `StereoPannerNode` | equal power | planned | sfx | stereo-panner | — |
| Channel splitter and merger | `ChannelSplitterNode`, `ChannelMergerNode` | — | planned | session | split-merge | — |
| Stereo width | — | mid and side | planned | asked | stereo-width | — |
| Bypass and wet and dry | — | — | planned | session | bypass | — |
| Dither | — | TPDF · noise-shaped | planned | session | dither | — |
| A program's own processor | `AudioWorkletProcessor`, `AudioWorkletNode`, `registerProcessor` | registered by name, built from plain-data options | planned | synth | processor | — |

## Spatial sound

| Feature | Web Audio's name | Rungs, cheap to best (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Listener | `AudioListener` | one · several, each sound heard by the nearest | planned | sfx | listener | — |
| Emitter | `PannerNode`'s position and orientation | — | planned | sfx | emitter | — |
| Panning | `PannerNode`'s `"equalpower"` and `"HRTF"` | equal power · HRTF binaural, four HRIRs blended, minimum phase with onsets | planned | sfx | panning | — |
| Ambisonics | — | first order · third order, rotated by the head and decoded binaurally once | planned | headset | ambisonics | — |
| Head tracking | — | the pose turning the field (`xr`) | planned | headset | head-pose | — |
| HRTF data | — | the default table (2°, 64 taps, float16) · any SOFA set converted at build · a set read at run time | planned | sfx | hrtf-data | — |
| Distance attenuation | `distanceModel` | linear · inverse · exponential · a curve | planned | sfx | distance | — |
| Cones | `coneInnerAngle`, `coneOuterAngle`, `coneOuterGain` | — | planned | sfx | cone | — |
| Air absorption | — | a low-pass by distance | planned | sfx | air-absorption | — |
| Doppler | — | the voice's read ratio per frame | planned | sfx | doppler | — |
| Head-relative sounds and a 2D-to-3D blend | — | — | planned | sfx | head-relative | — |
| Spread and size | — | — | planned | asked | spread | — |
| Occlusion and transmission | — | filters the program sets · ray casts from the geometric tier | planned | sfx | occlusion | — |
| Reverb sends and zones | — | sends the program sets · rooms from the geometric tier | planned | sfx | reverb-sends | — |
| Rooms, portals and diffraction | — | the geometric tier | planned | asked | rooms-portals | — |
| Early reflections | — | an impulse response the program sets · traced by the geometric tier | planned | asked | early-reflections | — |
| Emitter clustering | — | — | planned | asked | clustering | — |

## Decoding, encoding and resampling

| Feature | Web Audio's name | Rungs, cheap to best (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| WAV | `decodeAudioData` | — | planned | loop | decode-wav | — |
| FLAC | — | — | planned | session | decode-flac | — |
| MP3 | — | the encoder's delay and padding trimmed | planned | asked | decode-mp3 | — |
| Vorbis | — | — | planned | sfx | decode-vorbis | — |
| Opus in Ogg | — | — | planned | sfx | decode-opus | — |
| Opus in WebM | — | — | planned | asked | decode-webm | — |
| AAC in MP4 | — | the platform's decoder, fed by the package's MP4 reader (`os`) | planned | asked | decode-aac | — |
| Resampling a voice | `playbackRate`'s resampler | linear · cubic · band-limited at 8, 16 and 32 zero crossings | planned | sfx | resample-voice | — |
| Converting a whole buffer | `decodeAudioData`'s conversion | the vendored converter's best · a kama rung at 140 dB or better | planned | sfx | resample-buffer | — |
| Encoding Opus | — | — | planned | voice | encode-opus | — |
| Writing WAV | — | — | planned | session | encode-wav | — |

## Input and capture

| Feature | Web Audio's name | Rungs, cheap to best (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Microphone | `MediaStreamAudioSourceNode` over `getUserMedia` | the browser's stream · a capture device natively (`input`) | planned | voice | microphone | — |
| Echo cancellation, noise suppression and gain control | `getUserMedia`'s constraints | the browser's · the OS's voice processing (`input`) | planned | voice | echo-cancel | — |
| Duplex | — | — | planned | voice | duplex | — |
| Frames tapped to the program | — | a ring of frames from any node to the program's thread | planned | voice | tap | — |
| The engine's output as a media stream | `MediaStreamAudioDestinationNode` | the web only | planned | voice | stream-destination | — |
| Voice activity detection | — | an energy gate · a statistical model | planned | voice | vad | — |
| Recording to a file | — | a tap to a disk thread natively · to the program on the web | planned | session | record | — |
| Input latency, reported and compensated | — | — | planned | session | input-latency | — |

## Analysis and metering

| Feature | Web Audio's name | Rungs, cheap to best (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Meters | — | peak · RMS, as snapshots | planned | sfx | meter | — |
| Analyser | `AnalyserNode` | the time domain · the frequency domain | planned | session | analyser | — |
| Loudness | — | momentary, short-term and integrated LUFS, and loudness range (ITU-R BS.1770-5, EBU R 128) | planned | session | loudness | — |
| True peak | — | 4× oversampled | planned | session | true-peak | — |
| Loudness normalization | — | per sound, from its measured loudness | planned | asked | normalize | — |

## The mix: sounds, voices and buses (the upper tier)

| Feature | Web Audio's name | Rungs, cheap to best (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Sounds and their variations | — | sequence · shuffle · random without repeats · weighted; random pitch and volume | planned | sfx | variations | — |
| Sound definitions as data | — | records a program loads | planned | sfx | sound-data | — |
| Voices | — | — | planned | sfx | voices | — |
| Voice limits and stealing | — | none · oldest · furthest · quietest · lowest priority | planned | sfx | voice-stealing | — |
| Virtual voices | — | killed · paused · played on silently, resumed from the elapsed time | planned | sfx | virtual-voices | — |
| Priority | — | — | planned | sfx | priority | — |
| Cooldown | — | — | planned | sfx | cooldown | — |
| Buses | — | — | planned | sfx | buses | — |
| Sends and returns | — | before the fader · after it | planned | sfx | sends | — |
| Ducking | — | a snapshot on an event · a sidechain compressor on a bus | planned | sfx | ducking | — |
| Game parameters | — | continuous · discrete · labelled; local · global | planned | sfx | game-params | — |
| Built-in parameters | — | distance · direction · elevation · speed | planned | sfx | builtin-params | — |
| Snapshots | — | overriding · blending by intensity | planned | music | snapshots | — |
| States and switches | — | — | planned | music | states-switches | — |
| Volume groups that are not buses | — | — | planned | asked | vca | — |
| Dialogue chosen by key | — | — | planned | asked | dialogue | — |
| Localized sound sets | — | — | planned | asked | localization | — |

## Musical time

| Feature | Web Audio's name | Rungs, cheap to best (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| A tempo and bar clock | — | — | planned | music | beat-clock | — |
| Quantized starts | — | now · the next beat · the next bar · the next cue | planned | music | quantized-start | — |
| Events on beats and markers | — | on the way back | planned | music | beat-events | — |
| Music transitions | — | a cut · a crossfade · a transition segment | planned | music | music-transitions | — |
| Horizontal sequences | — | — | planned | music | playlists | — |
| Vertical layers | — | — | planned | music | layers | — |
| Stingers | — | on the next beat, bar or cue | planned | music | stingers | — |

## MIDI

| Feature | Web Audio's name | Rungs, cheap to best (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| MIDI input | — | MIDI 1.0 (`midi`) · UMP and MIDI 2.0, natively | planned | synth | midi-in | — |
| MIDI timestamps as stamped frames | — | — | planned | synth | midi-timing | — |
| Polyphony and voice allocation | — | — | planned | synth | polyphony | — |
| MIDI output | — | — | planned | asked | midi-out | — |
| Per-note expression | — | MPE · MIDI 2.0's per-note controllers | planned | asked | note-expression | — |

## What a DAW needs of the graph

| Feature | Web Audio's name | Rungs, cheap to best (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Latency, reported and compensated | — | delays added at the sum points | planned | session | latency-compensation | — |
| Sidechain inputs | a node's second input | — | planned | session | sidechain | — |
| A bounce faster than real time | `OfflineAudioContext` | — | planned | session | bounce | — |
| Freeze | — | a subgraph bounced to a buffer | planned | asked | freeze | — |

## Platforms and output

| Feature | Web Audio's name | Rungs, cheap to best (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| The native device | — | the vendored device layer · kama backends later | planned | loop | device | — |
| Choosing the device, and following it | `setSinkId`, `onsinkchange` (1.1) | the default · a chosen one, followed when it changes (`1.1` on the web) | planned | sfx | device-choice | — |
| A console's backend | — | a console's private package | planned | asked | console-backend | — |
| Audio objects and height beds | — | — | planned | asked | audio-objects | — |
| A controller's speaker | — | — | planned | asked | controller-speaker | — |
| Haptics | — | — | planned | asked | haptics | — |

## Tools

| Feature | Web Audio's name | Rungs, cheap to best (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| A profiler's feed | — | the engine's voices, levels and cost, streamed to a tool | planned | asked | profiler | — |
| Live update | — | — | planned | asked | live-update | — |
| CPU per node | — | — | planned | asked | node-cpu | — |
