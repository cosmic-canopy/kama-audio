# @kama/audio roadmap, the detail

Each row's reasoning: what drives it, what it builds, what it needs, what is open, and what done means.
- A row's questions are asked when it comes up. Their answers are recorded in [AGENTS.audio.md](AGENTS.audio.md)
  § Decided, and kyoten's `docs/design/audio.md` gets what binds kyoten.
- When a row ships, its section goes. What was built is the [SPEC](SPEC.md), its features turn `built` in
  [FEATURES.md](FEATURES.md), and how it was decided is the git log.
- `tools/check-roadmap.sh` holds every section to a row.

**Every row keeps the decided design** (AGENTS.audio.md § Decided, 1 to 37): one engine in kama on both legs, the two
tiers, Web Audio's names, the real-time model, the two legs, the ladders, the module cut, the commands' timing, the
slots, the program's memory as callbacks, and the offline render as a request the program polls.
- **Every row is test-first.** Every feature it builds gets golden samples: an offline render whose hash is the same in
  native debug, native release and wasm (FEATURES.md § How to read a row).
- **A test makes no sound the owner hears and never takes the focus:** it renders offline. A real device runs only
  muted, or as the null device.

**A budget never limits what is built** (kyoten's rule, the owner, 2026-11-11). Each feature's wasm size and render
cost are set by its first measurement. A ratchet fails only when something built gets costlier without a written
reason.

<a id="loop"></a>
## AUD-29: a sample-exact loop

**What drives it:** cosmic-forge's CF-24. Its page cannot judge a loop's seam by ear, because a media element comes
round a loop near its end, not exact to the sample. Web Audio's `AudioBufferSourceNode` (`loop`, `loopStart`,
`loopEnd`) plays one exactly, and natively the same wants a mixer that wraps a buffer. The library's own
`examples/loop` is that page's need without the page.

- **What it builds:**
  - the parts it is first to need:
    - the command protocol (AUD-1);
    - the slots (AUD-2);
    - the way back (AUD-3);
    - the context's options and memory (AUD-4);
    - `update()` (AUD-5);
    - the render path as `@noheap @noparks`, with the FIFO natively (AUD-6);
    - both web routes and the loader (AUD-7);
    - the declared block (AUD-9);
    - starting (AUD-10);
    - miniaudio natively (AUD-11);
    - `reproducible-float` in the tests (AUD-14);
    - WAV through dr_wav (AUD-21);
  - `AudioContext` and `OfflineAudioContext`, `AudioBuffer`, `AudioBufferSourceNode` with `loop`, `loopStart`, `loopEnd`
    and sub-sample `start(when:, offset:, duration:)`, `GainNode`, and `AudioParam`'s whole automation timeline;
  - output timestamps, device errors and playback statistics, each reported where the platform has it;
  - the package's frame: `tests/` as one program, and `tools/test.sh` running natively in debug and release and on
    wasm under node, with the guards;
  - the first golden: a 2 s buffer looped 8 times through a gain with a ramp, rendered offline. Its hash must be the
    same on every leg, and its seam equal to the buffer's own samples, frame for frame.
- **It starts from** the probes of areas 2 and 3: the ring (`aud-probe-ring`), the commands and the way back
  (`aud-probe-cmd`), the unisolated route (`aud-probe-noiso`, `aud-probe-routes`), the device (`aud-probe-device`) and
  the context (`aud-probe-context`).
- **Questions for when it comes up:**
  - the first cut of `audio::` (its modules, and which names are exported): decided, 31;
  - where a call scheduled ahead waits, and whether a frame's calls land together: decided, 32 and 33;
  - the slots' (AUD-2): what keeps a node's count, what a drop does when the backlog is full, the generation's
    width, and the table's storage: decided, 34 and 35;
  - how an offline render runs without promises or a thread of its own: decided, 37;
  - where a node's output samples live while a quantum renders: decided, 38;
  - which source makes the render's first samples: decided, 39;
  - how an `AudioBuffer`'s samples count against decision 6's sample memory, when a buffer is made to be played;
  - whether cosmic-forge's page is isolated, which decides the route it tests first;
  - the loop seam's test: its fixture, and how a seam is compared.
- **Done:**
  - `examples/loop` plays from one source natively and in both pinned browsers, muted, on both web routes;
  - its golden passes on every leg;
  - its wasm and render cost are measured, and its FEATURES.md rows are `built`;
  - cosmic-forge can drop its seam file (CF-24), which is that project's to do.

<a id="sfx"></a>
## AUD-30: a game's sounds

**What drives it:** a game's first sound: footsteps, shots and impacts with variations, placed around a listener,
mixed on buses with a voice limit, and an ambience bed streamed. It is what kyoten's audio module (KYR-15) binds, for
kyoten's fps example (KYR-65).

- **What it builds:**
  - the upper tier: sounds and their variations, sound definitions as data, voices, limits and stealing, virtual voices,
    priority, cooldown, buses, sends, ducking, game parameters and built-in parameters;
  - spatial sound: the listener, emitters, equal-power and HRTF panning (AUD-15), distance, cones, air absorption,
    Doppler, head-relative sounds, occlusion and reverb sends as the program sets them;
  - pffft (AUD-16), the HRTF converter and the default set (AUD-17, AUD-18);
  - Vorbis and Opus (AUD-21), the voices' resampling ladder (AUD-23) and a whole buffer's conversion (AUD-24);
  - streams with their bytes read in chunks (AUD-25, AUD-27);
  - the convolution reverb (AUD-28), and an algorithmic reverb;
  - biquads, the compressor and the stereo panner;
  - meters, the channel rules, and choosing the device and following it.
- **Questions for when it comes up:**
  - the upper tier's API (a `Sound`'s record, a `Voice`'s handle);
  - each sound's default resampling rung;
  - the algorithmic reverb's design: a feedback delay network, and which reference;
  - voice stealing's defaults.
- **Done:**
  - `examples/sfx` runs natively and on the web, with 64 voices placed and a bed streamed;
  - every row's golden passes, and each rung's cost is measured on both legs.

<a id="music"></a>
## AUD-31: adaptive music

**What drives it:** a game's music, which follows play: sections joined on the bar, layers brought in by intensity,
stingers on the beat, and the music ducked under dialogue. The game middleware has all of it (RESEARCH.md § 10.1).

- **What it builds:**
  - a tempo and bar clock, and quantized starts;
  - events on beats and markers, and sync points;
  - music transitions, horizontal sequences, vertical layers and stingers;
  - exact seeks and loops in streams (AUD-26), and gapless hand-offs;
  - snapshots, and states and switches.
- **Questions for when it comes up:**
  - the tempo map's shape as a function from beats to frames, which this clock reads and a DAW engine edits
    (decision 29);
  - how a section's grid is authored (in the sound's record, or read from the file's markers).
- **Done:** `examples/music` moves between three sections and two layers on the bar, with no gap, on both legs, and its
  golden passes.

<a id="voice"></a>
## AUD-32: voice chat

**What drives it:** players talking. The microphone is captured and cleaned of the game's own sound, encoded and handed
to the program's network, and the remote voices come back to be decoded, placed and mixed. Captions read the same
frames. kyoten's networked play (KYR-18) and its accessibility (KYR-76) both need it.

- **What it builds:**
  - input (AUD-12): the microphone, the platform's echo cancellation, noise suppression and gain control, and duplex;
  - frames tapped to the program, and a source the program feeds;
  - the engine's output as a media stream on the web;
  - Opus encoding, voice activity detection, and an expander as a gate.
- **The network is the program's.** On the web, WebRTC has its own Opus, jitter buffer and echo canceller, so a remote
  WebRTC track may enter as a media-stream source instead.
- **Questions for when it comes up:**
  - WebRTC's media path against our own Opus over a data channel, on the web;
  - the jitter buffer and loss concealment: Opus's own, or ours;
  - echo cancellation natively where the OS has none (Linux).
- **Needs the owner:** a real microphone, on the owner's hardware with the owner's OK (decision 18).
- **Done:**
  - `examples/voice` loops a recorded voice through encode and decode on both legs;
  - its echo cancellation is measured with the owner's microphone;
  - its taps carry the frames a recognizer needs: the tap, the fed source and the media-stream output are speech's
    half here (decision 30).

<a id="headset"></a>
## AUD-33: spatial sound on a standalone headset

**What drives it:** a headset's sound must follow the head: an Ambisonics field turned by the head's pose every frame,
decoded binaurally once, with low latency. kyoten's VR example (kyoten-example-vr) runs on Meta Quest.

- **What it builds:**
  - Ambisonics at first and third order, rotated by the head's pose (AUD-15);
  - the head pose from OpenXR natively and WebXR on the web;
  - miniaudio's AAudio backend on Android.
- **It needs** kama's Android app (kyoten's KY-2) and an XR package (kyoten's KYR-31). It moves earlier as soon as
  those land, since its audio needs are small.
- **Done:** `examples/headset` turns a field with a pose read from the runtime, natively on Quest and on WebXR, and its
  golden (a recorded pose path rendered offline) passes.

<a id="synth"></a>
## AUD-34: a synth on MIDI

**What drives it:** an instrument played live: a key pressed on a MIDI keyboard sounds within a few milliseconds,
polyphonic, shaped by envelopes and filters, with a program's own oscillator as a processor.

- **What it builds:**
  - oscillators, `PeriodicWave`, the constant source and noise;
  - a-rate parameters, parameters driven by nodes, and modulators;
  - the waveshaper, and chorus, flanger, phaser and tremolo;
  - polyphony and voice allocation;
  - MIDI in, its timestamps as stamped frames;
  - processors registered by name (AUD-8).
- **Questions for when it comes up:**
  - MIDI 2.0 natively, where Web MIDI has only 1.0;
  - Safari, which has no Web MIDI.
- **Done:** `examples/synth` plays a recorded MIDI file offline into its golden on both legs, and live from Web MIDI and
  the OS's MIDI.

<a id="session"></a>
## AUD-35: a multitrack session

**What drives it:** a DAW's engine and a game's cinematic mix need the same graph: tracks of clip players, each with
inserts, a fader and sends, automation lanes as parameters' curves, every path's latency compensated, and the mix
bounced offline faster than real time to a file that equals its playback. Decision 2 already put this in the lower
tier.

- **What it builds:**
  - latency reported and compensated, sidechain inputs, and a bounce;
  - delay, parametric EQ, the limiter, the channel splitter and merger, bypass, and dither;
  - the analyser, loudness and true peak;
  - recording to a file, and input latency;
  - FLAC, and writing WAV;
  - command capture and replay;
  - render workers (AUD-13).
- **What is not built here** (decision 29): the transport, editing the tempo map, tracks, clips, takes and plugin hosting
  (CLAP natively, WebCLAP on the web) are a DAW engine's, a package of its own on this one's public API. This slice
  proves the graph carries it.
- **Done:**
  - `examples/session` mixes 16 tracks with automation and sidechains, and bounces;
  - the bounce equals its real-time playback, sample for sample, on every leg;
  - its loudness matches libebur128's reference.

<a id="objects"></a>
## AUD-36: audio objects and height beds

**When:** a program asks for 7.1.4 or object output. Each platform's object API, and the web's lack of one, are
measured first.

<a id="haptics"></a>
## AUD-37: haptics from sound

**When:** a program asks. A haptics bus feeds a controller's or a headset's vibration from sound, through the
platform's haptics API. On the web that is the Gamepad API's vibration.

<a id="kama-native"></a>
## AUD-38: kama in place of the vendored C

**When each measures equal.** Each vendored C library sits behind the package's own seam so kama can replace it, and the
owner foresees that it will (decision 17):
- a kama FFT for pffft, measured against it at `-O3`: a wasm release is `-O3` since KR-332, and a size-first program
  keeps the package at speed with `release.speed` (KAMA_GAPS.md KAUD-6, retired 2026-11-17);
- kama device backends for miniaudio;
- a kama rung for libsamplerate, at 140 dB or better.

No program sees the change.

<a id="publish"></a>
## AUD-39: the first publish

**What drives it:** the library's first users take it from the registry, not from a path.
- **What it needs:**
  - `tests/` green on every target the library claims;
  - the notices complete (pffft's FFTPACK notice, SADIE II's citation, each vendored decoder's);
  - the README and the description written for the registry.
- **Done:** a program outside the repository builds the loop example from the registry, natively and on the web.
