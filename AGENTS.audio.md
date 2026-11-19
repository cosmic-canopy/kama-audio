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

**Seeded on 2026-11-13 with `kama seed` on kama 0.9.938+g94365be5 (kyoten's pin). The design pass is done
(2026-11-15): areas 1 to 5 are decided (§ Decided, 1 to 30), and so are the first slice's module cut (31) and its
command protocol's timing (32 and 33), its slots (34 and 35), the program's memory (36), the offline render (37),
where a node's samples live (38) and the first source (39),** on the evidence in [RESEARCH.md](RESEARCH.md), measured where it could be. This repository's documents, each to one purpose:
- [FEATURES.md](FEATURES.md) is every feature the library will have, with its rungs, status, example, test and budget
  (decision 27);
- [ROADMAP.md](ROADMAP.md) is the order, by example (decision 28), and [ROADMAP_DETAIL.md](ROADMAP_DETAIL.md) its
  reasoning;
- [SPEC.md](SPEC.md) is what is built.

**Now: AUD-29, a sample-exact loop, the first slice,** built test-first, depth-first, on the web and natively.
- **Built** ([SPEC.md](SPEC.md)):
  - on 2026-11-15:
    - the modules' first cut (decision 31);
    - AUD-1's two halves: `audio::rt::Ring`, which publishes a batch with one release store (`stage`, `publish`), and
      `audio::rt::Backlog` in front of it, which flushes what the ring has room for and counts its two high-water marks.
      Both refuse a make with `audio::rt::CapacityError`;
    - the tests program (`tests/`, one program), with its second-thread harness in `tests/src/crossing.kama`;
    - the gate, `tools/test.sh`: the guards, `kama check`, then the tests natively and on wasm under node.
  - on 2026-11-17:
    - **AUD-2's slot table, `audio::rt::SlotTable`** (decisions 4, 34 and 35), beside `Slots` in `src/rt/ring.kama`,
      with its 15 `slots` cases in `tests/src/slots_tests.kama`, each seen red against a stub first. An id is the slot
      in the low 32 bits and the generation in the high 32, read by `audio::rt::slotOf` and `generationOf`.
      Generations start at 1, so no live id is 0;
    - every wasm leg in debug and release, the release held to Closure (kama 0.9.966's KR-289; kyoten's rendering.md
      § Decided, 2026-11-17).
  - on 2026-11-18, **AUD-2's counted handle with the first node** (decisions 4, 34, 35 and 36):
    - `audio::AudioMemory` (`src/memory.kama`), the program's memory as a user pointer and three callbacks, ready-made
      for the global heap and an std `Arena`;
    - `audio::OfflineAudioContext` and its options, the `audio::BaseAudioContext` contract and `audio::AudioError`
      (`src/context.kama`);
    - `audio::GainNode` (`src/gain.kama`);
    - the internal module `audio::graph` (`src/graph/graph.kama`): `ContextState`, the slot table and the context's
      properties in one `Shared` made by `try new`, and `NodeHold`, which counts the row on a copy and at a drop;
    - its 11 `nodes` cases (`tests/src/nodes_tests.kama`), each seen red against a stub or a mutation first. The tests
      program hands the package its own allocator as callbacks, and counts its global heap (`tests/src/heap.kama`).
  - on 2026-11-18, **AUD-1's first commands over the handle** (decisions 7, 8, 33 and 35; SPEC.md § The commands):
    - `audio::graph::Command`, a kama enum whose variants carry only numbers: `Made(node, kind)` with `NodeKind`
      (`Gain`), and `Release(node)`. It is 24 bytes, so it crosses as its bytes, and the audio side applies it by name;
    - `ContextState` holds the backlog and the command ring beside the table. Its `flush()` stages the backlog, then,
      once the backlog has drained, the due releases while the ring has room, and publishes everything with one store;
    - `GainNode.make` sends its make. A full backlog answers `AudioError::TooManyCommands`, checked before a row is
      taken, so nothing changes;
    - `OfflineAudioContextOptions` declares `ringCapacity` and `backlogCapacity`. `audio::graph::stateFrom` draws the
      four parts in order, and gives back every part taken before a refusal;
    - `audio::rt::Ring.room()` and `audio::rt::Backlog.stageInto(ring:)`;
    - 8 `commands` cases (`tests/src/commands_tests.kama`), one each for the room and the move, and 4 `nodes` cases
      sharpened, each seen red against a stub first but the defaults'.
  - on 2026-11-18, **the audio side and the way back's first report** (AUD-1, AUD-2 and AUD-3; decisions 4, 5, 9, 32,
    34 and 35; SPEC.md § The slots and § The audio side and the way back):
    - `audio::rt::SlotArray`, the audio side's half of the slots: a value put at the slot an id names, read and removed
      only at the generation it was put at, beside `SlotTable` in `src/rt/ring.kama`, with its 12 `slot array` cases
      (`tests/src/slot_array_tests.kama`);
    - `audio::graph::Engine` (`src/graph/engine.kama`): a render quantum drains the command ring at its top, applies
      every command in order, and publishes its reports on the way back with one store. A released gain, having no
      input, is freed at once and reported as `Event::Freed`. A command it cannot apply is refused and counted;
    - the way back, a `Ring<Event>` of the node capacity, and `ContextState.poll()`, which reads it and frees each
      reported row in the table. A context now draws six parts;
    - 9 `audio side` cases (`tests/src/audio_side_tests.kama`) and 3 `nodes` cases sharpened to six parts, each seen
      red against a stub first, or, for the last two audio side cases, against the mutation each was written for.
  - on 2026-11-18, **`connect()` and the lifetime rule** (AUD-1 and AUD-2; decisions 3, 4, 6, 8 and 34; SPEC.md
    § Connections):
    - `audio::store`, an internal module holding `Slots`, moved out of `src/rt/ring.kama` so `audio::graph`'s parts take
      their storage the same way;
    - `SlotArray.set(id:, value:)` and `idAt(slot:)`, for the walk;
    - `audio::AudioNode`, the contract every node implements, with `connect(destination:)`; `AudioError::InvalidAccess`
      and `TooManyConnections`; `OfflineAudioContextOptions.connectionCapacity`, 4,096 by default;
    - `audio::graph::Connections` (`src/graph/connections.kama`), held by each side; the engine's lifetime walk, which
      keeps a released node while a node that can sound feeds it and frees a released cycle nothing feeds. A context
      draws eleven parts;
    - 16 `connect` cases (`tests/src/connect_tests.kama`), 2 `slot array` cases and 4 `nodes` cases sharpened, each
      seen red against a stub first, or, for the last two connect cases, against the mutations they were written for.

  - on 2026-11-19, **the offline render's first slice** (decision 37; AUD-29, AUD-5 and AUD-9; SPEC.md § The offline
    render):
    - `OfflineAudioContext.startRendering()`, answering an `audio::RenderRequest`, and `update()`, which flushes, renders
      whole quanta up to the new `framesPerUpdate` and reads the way back; `RenderRequest.poll()`, answering
      `audio::RenderStatus`;
    - `audio::AudioBuffer`, a counted resource over `audio::graph::Samples`, with Web Audio's `copyFromChannel`;
      `AudioError::InvalidState` and `IndexSize`; the engine's block, silence until a node renders into it; the output
      a declared part, fourteen in all;
    - `audio::store::Slots` refusing a capacity whose bytes overflow a `usize` as `OutOfMemory`: a ring of 2^62 had been
      made over 0 bytes;
    - 12 `render` cases (`tests/src/render_tests.kama`), 1 `command-ring` case and 4 `nodes` cases sharpened, each seen
      red against a stub first but the start's, or, for the last three render cases, against the mutations they were
      written for. The tests' allocator now poisons every block it hands out.

  - on 2026-11-19, **suspending and resuming a render** (decision 37, with decisions 3 and 6; SPEC.md § The offline
    render):
    - `OfflineAudioContext.suspend(suspendTime:)`, `resume()` and `currentTime()`; `RenderStatus::Suspended`;
      `OfflineAudioContextOptions.suspendCapacity` and `AudioError::TooManySuspends`; the suspends a declared part, the
      fifteenth;
    - decision 3's one rounding rule, `audio::graph::frameAt`, its first use;
    - 12 `suspend` cases (`tests/src/suspend_tests.kama`) and 4 `nodes` cases sharpened, each seen red against a stub
      first, or, for the two at each quantum's first frame after its start, against the rule they were written for.
      The first build reported pending where a suspend's frame was reached on an update's last quantum: the render now
      checks after each quantum.

  - on 2026-11-19, **the destination and the render's order** (decisions 3, 4, 6 and 37; SPEC.md § The destination and
    the render's order):
    - `audio::AudioDestinationNode` (`src/destination.kama`) and `destination()` on `BaseAudioContext` and
      `OfflineAudioContext`;
    - the engine's order, Web Audio's ordered node list, with every cycle muted, a sixteenth part;
    - the store's indexer skipping its division for an index in range, measured;
    - 11 `destination` cases (`tests/src/destination_tests.kama`) and 3 `nodes` cases sharpened to sixteen parts, each
      seen red against a stub first, or, for the cycles reached through their feeder, against the mutation it was
      written for.

  - on 2026-11-19, **the render over a block per node, and `ConstantSourceNode`** (decisions 38 and 39, with 3, 4 and
    32; SPEC.md § The render and the first source):
    - the engine's render: every node's block summed into the nodes it feeds, the destination's into the output, one
      channel up-mixed by the speaker rules, a silent flag per slot; `OfflineAudioContextOptions.channelCapacity`;
      eighteen parts;
    - `audio::ConstantSourceNode` and `ConstantSourceOptions` (`src/constant.kama`), `start(startTime:)`, a `Start`
      command carrying its frame, late starts counted, and a started source kept while it can sound;
      `AudioError::Range`;
    - 13 `constant` cases (`tests/src/constant_tests.kama`), each seen red against a stub first, or, for the last three,
      against the mutations they were written for; the `nodes`, `render` and `destination` cases sharpened;
    - `AudioNode.numberOfInputs()` and `numberOfOutputs()`, and a connect to a source refused as `IndexSize`, the
      defect the mutation pass found.

  - on 2026-11-19, **a source's stop and its end** (decisions 4, 9, 32 and 39; SPEC.md § The render and the first
    source):
    - `ConstantSourceNode.stop(stopTime:)` and `ended()`; a `Stop` command carrying its frame; `Event::Ended` on the
      way back, kept in the row's source state; a released source freed once it ends; the way back at two reports a
      row;
    - 8 `stop` cases (`tests/src/stop_tests.kama`), each seen red against a stub first, or, for the last two, against
      the mutations they were written for.

  154 cases, green on every leg: native debug and release, wasm debug and release.
- **Settled while building the table, reported to the owner to object to** (each within decisions 34 and 35):
  - the name `SlotTable`, and its calls: `take()`, `countUp(id:)`, `countDown(id:)`, `nextRelease()`, `free(id:)`,
    `countOf(id:)`, `length()`, `capacity()`, `retired()`;
  - an id is a bare `int64`, as decision 34 words it, not a type of its own: a `type value` would need `Equatable`
    for `==`, and a command's field is the `int64` either way;
  - generations start at 1, and the last is 2^32 − 1;
  - a row has five states: free, taken, marked (its last drop made), released (`nextRelease()` handed it to the flush)
    and retired. `free(id:)` takes only a released row, so a report can never free a row whose release was not sent;
  - an id that names no row in the state a call needs is refused with `false`, `None` or a count of 0, never a trap;
  - a capacity above 2^32 is `BadCapacity`, checked before the allocator is asked, and the error's message says so.
- **Settled while building the handle, reported to the owner to object to** (each within decisions 3, 4, 6, 34 to 36):
  - **`BaseAudioContext` is a contract, not a base type.** kama's inheritance forbids a derived type to add a public
    member, and each context adds its own, as `GainNode` adds `gain`. The node that `connect()` takes will be a
    contract, `AudioNode`, for the same reason, when `connect()` comes;
  - **what a context and its nodes share is an internal module, `audio::graph`,** which no program can import.
    `BaseAudioContext.stateFor(key:)` is public, as a contract's members are, but its key's type is in that module, so
    only the package can call it. Decision 31's cut gains it;
  - **a node is `Copyable` with a bare hand-off that moves,** as `@kama/gpu`'s handles are: `copy g` counts up;
  - **the first context is `OfflineAudioContext`,** made with `make(options:)` from `OfflineAudioContextOptions.make(
    length:, sampleRate:)`, whose other fields take Web Audio's defaults (`numberOfChannels` 1), then
    `nodeCapacity`, 1,024 by default, and `memory`, the global heap by default;
  - **`AudioError` is `NotSupported`, `OutOfMemory` or `TooManyNodes`.** `NotSupported` is Web Audio's
    `NotSupportedError` for its ranges: 1 to 32 channels, at least one frame, 3,000 to 768,000 Hz; a node capacity
    below one is the same;
  - **`GainNode.make(context:)` takes no options yet.** Its `gain` comes with `AudioParam` and the commands;
  - **the test seam into a context is two `friend` grants,** `audiotests::rowsHeldIn` and `releaseDueIn`.
- **Settled while building the commands, reported to the owner to object to** (each within decisions 6 to 8, 31 to 33
  and 35):
  - **`Command` is in the internal `audio::graph`,** since it is the protocol between a context, its nodes and the
    engine, and no program needs it. The tests read it as text through two more `friend` grants, `audiotests::flushIn`
    and `sentIn` (`made gain 0:1`). A probe showed that a module's `visibility` list names only the package's own
    modules, so the tests program cannot import it;
  - **a command is a kama enum with number payloads,** not a struct with a kind field. It is flat bytes all the same,
    and the audio side's `match` over it is exhaustive. Each kind arrives with the call that sends it, so there is no
    frame field yet: the first timed call brings it;
  - **the options are `ringCapacity`, 1,024 by default, and `backlogCapacity`, 4,096,** each at least one or
    `NotSupported`. The backlog is the larger, since every call of a frame waits in it until the flush (decision 33);
  - **a full backlog is `AudioError::TooManyCommands`,** and with both the backlog and the table full, the backlog
    answers first: it is checked before a row is taken;
  - **a release is taken from the table only when the ring has room,** by `Ring.room()`, so `nextRelease()` never hands
    over a release that cannot be sent;
  - **the backlog's move is `Backlog.stageInto(ring:)`,** and `flushInto` is it plus `publish()`, so a caller can stage
    more and publish once;
  - **the flush is not public yet.** Its callers come with their rows, `update()` (AUD-5) and the offline render's start
    (AUD-9).
- **Settled while building the audio side, reported to the owner to object to** (each within decisions 4, 5, 9, 31,
  32 and 34):
  - **the audio side's half of the slots is a public `audio::rt` primitive, `SlotArray<T, A>`,** the sibling of
    `SlotTable`: decision 31 gives `audio::rt` the real-time primitives the engine and a program's own DSP share, and
    the DAW and speech packages keep their own objects' audio-side state the same way. Its storage is the private
    `Slots`, since std's `FixedArray` traps when its allocator has no room (KAUD-7). Its calls are `put(id:, value:)`,
    `at(id:)`, `remove(id:)`, `length()` and `capacity()`; a value is put only into an empty slot, and generation 0
    marks one;
  - **the engine is `audio::graph::Engine`, internal,** in a file of its own. It owns only its array, and each quantum
    is handed the command ring and the way back, so the same engine serves a real-time context's audio thread and an
    offline render's. `EngineNode`, what it keeps of a node, holds the node's kind, which nothing reads until the
    render does;
  - **a command the audio side cannot apply is refused and counted,** not reported as an event: no call can send one,
    so each is the package's bug. Decision 9's error event comes with the first error a program can cause;
  - **the way back is a `Ring<Event>` of the node capacity,** so a report always has room (decision 9), and its one
    kind so far is `Event::Freed(node)`. Each later kind arrives with what sends it;
  - **the read of the way back is `ContextState.poll()`,** not yet public: `update()` (AUD-5) is its caller;
  - **five more seams to the tests program,** nine in all: `audiotests::quantumIn`, `pollIn`, `audioHeldIn`,
    `refusedIn` and `forgeIn`, the last adding a command no call would send, so a refusal can be tested.
- **Settled while building `connect()`, reported to the owner to object to** (each within decisions 3, 4, 6, 8, 31 and
  34, on Web Audio's text, read from its source on 2026-11-18):
  - **`connect(destination:)` alone,** Web Audio's `connect(destinationNode)` with `output` and `input` both 0: kama has
    no default arguments (a default is a parse error), and every node so far has one input and one output. The form
    that names them, and `connect` to an `AudioParam`, each take a name of their own when they come, since kama has no
    overloading;
  - **it answers `Result<Unit, AudioError>`,** std's idiom for a call that can fail and returns nothing, where Web Audio
    returns the destination for chaining: a refusal is an answer, never a trap;
  - **`AudioNode`'s members are `connect(destination:)` and `linkFor(key:)`,** the latter keyed as `stateFor` is, so only
    the package can call it;
  - **the refusals, in order:** a node of another context is `AudioError::InvalidAccess`, Web Audio's
    `InvalidAccessError`, contexts told apart by their state's address; a full backlog is `TooManyCommands`; every
    declared connection held is the new `TooManyConnections`. A duplicate is taken and sends nothing, even with every
    connection held, as Web Audio ignores "multiple connections with the same termini";
  - **`connectionCapacity`, 4,096 by default,** four for each of the default 1,024 node rows, at least one or
    `NotSupported`;
  - **cycles are allowed,** as in Web Audio, whose rendering algorithm mutes a cycle with no `DelayNode`. The muting
    comes with the render;
  - **the lifetime rule is a walk, a mark from the nodes that can sound,** not a count of live inputs, which would keep a
    released cycle forever: decision 4's "a node with a live input" read as Web Audio's dynamic lifetime does, a node
    kept while something that sounds reaches it. It runs only in a quantum that applied a release, and costs 5.0 µs
    natively and 6.6 µs on wasm at 1,024 nodes and 4,096 connections (`.scratch/aud1-mark/`), a quarter of a percent
    of a quantum. An incremental form can replace it later with no change to the API;
  - **`Connections` is internal, and each side holds one:** the program side's answers a duplicate and the limit at the
    call and gives a freed node's connections back when the way back is read; the audio side's is what the walk
    follows. A slot's list is the connections of the node in it, and leaves with it, so only outputs are listed and a
    connection records only its destination: a freed node's inputs all come from nodes freed in the same walk;
  - **`Slots` moved to an internal module, `audio::store`,** a fourth module beside decision 31's three and `audio::graph`;
  - **`SlotArray` gains `set(id:, value:)` and `idAt(slot:)`;**
  - **one more seam, ten in all:** `audiotests::forgeConnectIn`.
- **Settled while building the render's first slice, reported to the owner to object to** (each within decisions 3, 4,
  6, 15 and 37):
  - **`framesPerUpdate`, 8,192 frames by default** (64 quanta: a game at 60 frames a second renders about ten times
    faster than real time), at least one or `NotSupported`. An update renders whole quanta until it has rendered at
    least that many, so it can pass it by up to 127 frames;
  - **`startRendering()` answers `Result<RenderRequest, AudioError>`,** a second start `AudioError::InvalidState`;
  - **`RenderStatus` is `Pending(framesRendered)` or `Ready(buffer)`:** no `Failed` until something can fail mid-render,
    and `Suspended` comes with `suspend()`;
  - **`update()` before the start flushes and reads the way back, and renders nothing;** the flushed commands wait in the
    ring for the render's first quantum;
  - **`AudioBuffer` is a counted handle on internal `Samples`, channel-planar `float32`,** and outlives its context. Its
    first calls are `sampleRate()`, `length()`, `duration()` (a `float64`, Web Audio's double), `numberOfChannels()`
    and `copyFromChannel(destination:, channelNumber:, bufferOffset:)`, the offset always named; an offset below 0 is
    `IndexSize`. `getChannelData` and `copyToChannel` come with the buffers a program makes, whose sample memory is the
    owner's question then;
  - **the output is the fourteenth part,** drawn at the make; an output past an `isize`, or a capacity whose bytes pass
    a `usize`, is `OutOfMemory` before the allocator is asked;
  - **a quantum is a constant 128 frames** until the engine's declared block (decision 15, AUD-9) makes it the program's
    setting;
  - **one more seam, eleven in all:** `audiotests::markIn`, which writes a value into the render's output, where silence
    could not show an overrun or a read of the wrong channel.
- **Settled while building suspend and resume, reported to the owner to object to** (each within decisions 3, 6 and
  37, on Web Audio's text):
  - **decision 3's one rounding rule:** a time takes effect at the first frame whose own time, the frame divided by the
    rate in float64, is at or after it. A time made from a frame lands on that frame, where a plain round-up of
    `time × rate` would put one frame in six at 48 kHz a frame late, a quantum late on a quantum's edge. It is
    `audio::graph::frameAt`, and every later timed call uses it. A time past 2^51 frames, about 1,500 years at 48 kHz,
    is refused, as negative, NaN and infinite times are;
  - **`suspend(suspendTime:)` and `resume()` answer `Result<Unit, AudioError>`,** the program learning of the stop from
    `poll()`, which answers `RenderStatus::Suspended(framesRendered)`. Web Audio's refusals are `InvalidState`, checked
    first;
  - **`suspendCapacity`, 64 by default,** at least one or `NotSupported`; every declared suspend held is the new
    `AudioError::TooManySuspends`, and a suspend reached gives its place back;
  - **the render stops after the quantum that reaches the frame,** so `poll()` says so at once, and updates while
    suspended flush and read the way back but render nothing;
  - **`currentTime()` is on `OfflineAudioContext`,** the frames rendered over the rate; `BaseAudioContext` gains it with
    the real-time context.
- **Settled while building the destination and the order, reported to the owner to object to** (each within decisions
  3, 4, 6 and 37, on Web Audio's text):
  - **the destination takes no row in the program side's table,** where the session's plan had said one more row:
    a program never makes or releases it, so a counted row would hold nothing a program does. Its handle holds the
    context's state, the audio side holds it from the make at the slot past the table's rows, and `nodeCapacity` stays
    the nodes a program makes. A `nodeCapacity` of 2^32 or more leaves its slot no id, and is `OutOfMemory`;
  - **`destination()` is a member of `BaseAudioContext`,** as Web Audio's `destination` attribute is, and the node
    answers `channelCount()` and `maxChannelCount()`, both the context's channels; it has an output, as Web Audio's
    does, so it connects onward;
  - **the order holds every node, reaching the destination or not** (Web Audio §1.5), and a node in a cycle, the
    destination too, is muted and left out;
  - **the order is one Tarjan search over the whole graph, run in a quantum that changed it,** as Gecko's is: 27 to
    39 µs natively and 40 to 50 µs on wasm at 1,024 nodes and 4,096 connections, 1 to 2% of a quantum; 172 to 244 µs
    at 4,096 nodes. An incremental order can replace it with no change to the API;
  - **`Slots`' indexer skips its division for an index in range,** which was over half of the search; a ring's counter
    past the end still takes it, and every element is the same;
  - **two more seams, thirteen in all:** `audiotests::orderAtIn` and `mutedIn`. `audioHeldIn` counts the program's
    nodes the audio side holds, the destination not among them.
- **Settled while building the render and the first source, reported to the owner to object to** (each within
  decisions 3, 4, 32, 38 and 39, on Web Audio's text):
  - **`start(startTime:)`, where decision 3 wrote `start(when:)`:** kama reserves `when`, as it does `out` and `in`
    (KAMA_GAPS.md KAUD-11, with its ask), so the time takes the name Web Audio gives its other times
    (`setValueAtTime(value, startTime)`, `suspend(suspendTime)`); `stop` will take `stopTime:`. MDN's page still
    describes it, under another label;
  - **a time Web Audio refuses is the new `AudioError::Range`,** for its `RangeError`, negative; NaN and infinity,
    which Web Audio's IDL refuses as a `TypeError`, are folded into it, as is a time past 2^51 frames;
  - **the option is `channelCapacity`, 2 by default, 1 to 32 or `NotSupported`,** and a context uses its
    `numberOfChannels` when that is more, so the destination always fits;
  - **a node's input is summed by its feeders:** each adds its output into the block of the node it feeds as soon as
    it renders, so a node's block is its input and then its output, and no node keeps a second block for its sum;
  - **only the up-mixes a node can reach are built:** one channel by the speaker rules, equal counts, and discrete
    otherwise. The speakers' down-mixes, and decision 38's down-mix at the capacity with its count, come with the
    buffer player, the first source of more channels, since no node can pass the capacity before it;
  - **`ConstantSourceOptions.make()`, its `offset` a field, 1 by default,** sent in the make's own command as
    `NodeKind::Constant(offset)`, so a make and its offset land together; the `AudioParam` comes with parameters;
  - **a constant starts on a frame:** decision 3's sub-frame fraction is a buffer source's, and comes with it;
  - **the late count is on the audio side,** read through a fourteenth seam, `audiotests::lateIn`, until playback
    statistics make it public;
  - **the program side keeps a byte a row for its source's state,** the eighteenth part, so a second start is refused at
    the call; it is cleared when the row is taken;
  - **`stop(stopTime:)`, by the same rule as the start,** and **Web Audio's `ended` event is polled:** `ended()` on the
    source, true once an `update()` has read the end on the way back, as what kama cannot await is polled (decision
    37's reasoning). A stop after the end changes nothing, as in Web Audio;
  - **a source ends in the quantum that renders up to its stop,** reported then, and its freeing, if released, comes in
    the next quantum's walk;
  - **the way back holds two reports a row,** a node's end and its freeing, where decision 9 sized it at one: an update
    may render many quanta before it reads them;
  - **`numberOfInputs()` and `numberOfOutputs()` are members of `AudioNode`,** Web Audio's, and a connect to a node
    with no input is `IndexSize`, after `InvalidAccess`, as Web Audio's connect checks them. The first mutation pass
    found it: a connect to a constant was taken, and one not playing passed its input on.
- **Proved by mutation:**
  - a source's stop and its end (`.scratch/aud29/mutate_stop.py`, through the whole gate): **33 of 38 caught,** none
    by a hang, none refused by kama, the other 5 equivalent (refusals of stops no call can send, an unstarted source
    ending, and a stop before its start written as silence). Four cases were written before the pass for the misses it
    would have had; its one miss showed an ended source's repeated report, now written as a way back filled by it.
  - the render and the first source (`.scratch/aud29/mutate_render2.py`, through the whole gate): **69 of 81 caught,**
    none by a hang, none refused by kama. The first pass caught 58 of 75, `blockAt`'s channel and `frameAt`'s negative
    time among them, and found a defect: a connect to a source was taken, so a constant not playing passed its input
    on. Now `numberOfInputs()` refuses it as `IndexSize`, and its 8 mutations are caught. Three misses showed a case
    too loose, now written (a node feeding two, a destination muted mid-render, a start's command); two were redundant,
    now gone; eleven are equivalent for now (seven wait for a node of more than one channel besides the destination,
    two only cost, two are refused by the program side first), and one is held by review.
  - the destination and the render's order (`.scratch/aud29/mutate_order.py`, through the whole gate): **72 of 77
    caught,** 3 by a hang, none refused by kama, the other 5 equivalent. The first pass caught 71 of 78. One miss showed
    every cycle reached from its own lowest slot, now written as cycles reached through their feeder; one was a
    redundant clearing, now gone. The equivalents: a node made muted (the search writes it first), the search every
    quantum or left due (cost only), a muted node never unmuted (until `disconnect()`), and the 2^32-row guard (held
    by review).
  - the ring and the backlog (`.scratch/aud29/mutate_ring.py`, through the whole gate): 38 of 39 mutations of
    `src/rt/ring.kama` are caught, none by a hang.
    - **The miss is the publish made relaxed,** a weak-memory race: caught in one run, missed in the next. So the
      release and acquire pair is held by review. RESEARCH.md § 6.1 found that ThreadSanitizer is not the evidence
      either.
    - **A flush publishing each item on its own** is visible only from another thread. The backlog's thread case
      catches it on every leg in 5 of 5 runs.
  - the slot table (`.scratch/aud29/mutate_slots.py`, through the whole gate): **47 of 47 mutations caught,** none by
    a hang. The first pass caught 43, and each of the four it missed showed a case too loose, now sharpened (SPEC.md
    § Proved by mutation). `free()`'s second clearing of a row's link was dropped before the pass as redundant.
  - the memory, the context and the first node (`.scratch/aud29/mutate_handle.py`, through the whole gate): **39 of 40
    caught,** none by a hang, the 40th equivalent (the options' default `length`, which the one constructor writes
    first). The first pass caught 37; its two other misses showed the tests blind to the global heap, which the tests
    program now counts.
  - the commands (`.scratch/aud29/mutate_commands.py`, through the whole gate): **52 of 53 caught,** none by a hang, and
    none refused by kama. The miss is the flush sending releases while the backlog still holds commands. On one
    thread that is invisible, since a backlog left holding commands means the ring is full. It matters only when the
    audio side pops on another thread between the move and the releases, a race held by review, as the ring's release
    store is.
  - the slot array, the engine and the way back (`.scratch/aud29/mutate_audio_side.py`, through the whole gate):
    **52 of 52 caught,** none by a hang, and none refused by kama. The first pass caught 49 of 51, and each miss showed
    a case too loose, now sharpened: the slot array's read past the array, which wraps onto slot 0, held nothing there;
    and no case had a command ring smaller than its rows, so the way back sized by the ring passed. The 52nd proves the
    no-room case, green against the stub.
  - suspending and resuming (`.scratch/aud29/mutate_suspend.py`, through the whole gate): **35 of 37 caught,** none by a
    hang, none refused by kama, the rule's edges held by the cases written for them before the pass. The other 2 are
    equivalent for suspend, since a frame of 0 or below is always at or before the current time: `frameAt` taking a
    negative time, and an unconvertible time read as frame 0. **The first guard waits for the first timed call:** a
    source's `start(when:)` with a negative time, Web Audio's `RangeError`, brings the case that catches it.
  - the offline render's first slice (`.scratch/aud29/mutate_render.py`, through the whole gate): **54 of 55 caught,** 1 by
    a hang, none refused by kama. The first pass caught 45 of 54, silence hiding most misses; seven are caught by
    sharpened cases (a mark where the last quantum's overrun lands, a render with less than a quantum left, the bytes
    each channel adds, the copy case's channels marked apart), and `renderDone`'s check of the start was equivalent and
    is gone. **The 55th, `blockAt` reading channel 0 for every channel, waits for a node that renders:** only the engine
    writes its block, with silence.
  - connect and the lifetime rule (`.scratch/aud29/mutate_connect.py`, through the whole gate): **78 of 81 caught,** 4 by
    a hang, none refused by kama, and the other 3 equivalent. The first pass caught 66 of 82. Eleven misses showed a
    case too loose, now sharpened or written: no node had two outputs, no pool of more than one was filled, no freed
    slot was reused and connected from, the engine's duplicate and second release were forged only where they would be
    refused anyway, and no case filled the backlog and the connections at once. Two showed the connections' source
    field could not matter, and it is gone. The equivalents: `firstOut`'s range guard, whose callers name held slots,
    and the walk in every quantum, which frees nothing more, only costs more.
- **Decided on the way:**
  - on 2026-11-15, where a call scheduled ahead waits (32, in its node, as in Web Audio) and that a flush lands whole
    (33);
  - on 2026-11-16, AUD-2's four questions: a node's count in the program side's slot table, a public `audio::rt`
    primitive, its ids 32 + 32 bits (34), and a dropped node's release sent after the backlog (35);
  - on 2026-11-18, the program's memory as callbacks, `AudioMemory` (36), and kyoten's pin at 0.9.978 on both
    machines, for `try new` into a `Shared` (KR-399 to KR-402);
  - on 2026-11-19, the offline render as a request the program polls, advanced by `update()` (37), a node's output
    samples in a block of its own drawn at the make (38), and `ConstantSourceNode` as the first source (39).
- **Found on the way: KAUD-7, KAUD-8, KAUD-9 and KAUD-10.**
  - std's collections trap when their allocator has no room (KAUD-7, kama's KR-403, briefed). So every declared
    capacity takes its storage as the ring's does, through `Slots`, since 2026-11-18 in the internal module
    `audio::store` (`src/store/slots.kama`), so `audio::graph`'s parts take theirs the same way.
  - `try new(allocator:)` into a `Shared` trapped when the object fit and its control block did not (KAUD-8). Fixed in
    0.9.973 and retired.
  - A generic function's instance cannot be bound to an `fnptr` (KAUD-9), so the package cannot write the callbacks
    for any allocator, and a program with its own writes three free functions.
  - `try new(allocator:)` whose box has no room leaks a temporary built in its argument list (KAUD-10), though KR-402
    drops a local given to it. The nodes' no-room case caught the engine's array left out at a budget of 640 bytes,
    so the engine is bound to a local before the state's `try new`.
  - std's `FixedArray` traps when its allocator has no room, as KAUD-7's collections do, so the slot array takes its
    storage through `Slots` too.
- **Next:**
  - **`AudioParam`,** Web Audio's, with its automation timeline (decision 32: each parameter's events kept in its node,
    a declared capacity, a full timeline an error at the call), first as the gain's `gain` and the constant's `offset`,
    in place of the offset set at the make. Its questions are the owner's when it comes up: the timeline's declared
    capacity per parameter, a-rate and k-rate (FEATURES.md puts the second rung with the synth), and how the program
    side counts the events the playhead has passed (decision 9's snapshots);
  - **then the buffer player and the first golden** (AUD-29's 2 s buffer looped 8 times through a gain with a ramp).
    The buffer player's stereo buffers bring the cases for the seven mutations of the render that only a node of more
    than one channel besides the destination can reach (SPEC.md § Proved by mutation, the render and the first source),
    and the speakers' down-mixes with decision 38's down-mix at the capacity. **The `AudioBuffer`'s sample memory is the
    owner's question,** asked when a buffer is made to be played: how its samples count against decision 6's sample
    memory;
  - **the rest of AUD-1's commands, each with its call:** `disconnect()` and its forms, each needing a name of its own
    since kama has no overloading, which brings the cases for a muted node unmuted and a slot reused after a node of
    more channels; a parameter's events with `AudioParam`;
  - then the context's options and memory (AUD-4) and `update()` (AUD-5).
- **Read first:** § Decided (4, 6, 9 and 32 to 39 above all), SPEC.md § Contexts and nodes, § The commands, § The
  audio side and the way back, § Connections and § The offline render, ROADMAP_DETAIL.md § AUD-29, and the probes it starts from (`aud-probe-cmd` for the
  commands and the way back, `aud-probe-routes` for slots and a block split at a frame).
- **Each slice checks the owner's games for code it can take** (2026-11-18, after the owner asked why audio came so
  fast in them). `../friendly-fire-department/audio/` and `../the-mallow-man/audio/` each answer one game: a fixed set
  of commands, a ring that drops when full, and the web leg rendered on the page's thread. But parts of them fit rungs
  already decided, and kyoten's rule lets them be taken with no credit line, their source named as provenance:
  - the mallow man's RBJ biquads (`biquad.kama`), the cookbook Web Audio's `BiquadFilterNode` is specified by
    (AUD-30, AUD-34);
  - its equal-power pan law (`space.kama`), decision 20's first spatial rung (AUD-30);
  - FFD's microphone capture through miniaudio (`mic_native.kama`, `ffd_mic_native.h`), for voice chat's native input
    (AUD-32).

  The synth's oscillators (`synth.kama`) need band-limiting first, since Web Audio's must not alias. Taken code is held
  to this package's rules like any other: test-first, proved by mutation.
- **The pin is 0.9.978 (`5e542c55`) on both machines.**
  - The Windows box bumped kyoten's `.kama-version` to it on 2026-11-18. The Mac rebuilt it from a clean clone the same
    day, at the owner's word ("Match Windows: 0.9.978"), after first building 0.9.981, origin's head: 0.9.978 already
    holds KR-399 to KR-402, which the context's state needs.
  - kyoten's `tools/test.sh` and this package's are green on it on the Mac. The 0.9.966 pin is kept in kyoten's
    `.scratch/kama-pin-0.9.966`, 0.9.981 in `.scratch/kama-pin-0.9.981`, and P5 to P9's 0.9.945 in
    `.scratch/kama-pin-0.9.945`.
  - **`try new` covers a `Shared`'s whole box since 0.9.973 (KR-399), and leaks nothing it was given since 0.9.971
    (KR-402).** So KAUD-8 is retired, and the context's state is one `Shared` made by `try new(allocator:)`
    (`.scratch/aud2-trynew/`: `None` at every budget below 224 bytes, 0 bytes left out each time).
  - **A wasm release runs Closure over its JS since 0.9.966 (KR-289),** so the gate's wasm leg runs debug and release,
    as the owner decided for every gate on 2026-11-17 (kyoten's rendering.md § Decided). The release JS is held to
    Closure by emscripten's `ENVIRONMENT_IS_NODE`, which only Closure renames.
  - **KAUD-6 is fixed by KR-332 (0.9.965) and retired.** A wasm `--release` is `-O3`, a size-first program sets
    `release.optimize: "size"` and names the code it wants fast under `release.speed`, and an `-O` in a manifest's
    flags is refused by name.
  - On 0.9.978, KAUD-2, KAUD-7 and KAUD-9 reproduce, and two of KAUD-5's three causes stand: one build makes one
    artifact, and KR-327's shared-memory flag is still open. KAUD-7's ask is kama's KR-403, briefed and not built.
    kama's origin `dev` was at 0.9.981 on 2026-11-18, with nothing more for this package.
  - The pin moves at the owner's word.
- **What area 4 taught, which the build rows need:**
  - **A wasm release is `-O3` since KR-332** (KAMA_GAPS.md KAUD-6, measured on the pin, 2026-11-17, under node):
    - the 129-bin complex multiply-accumulate over views takes 75 ns, as over raw pointers; it took 4,446 at `-Oz`;
    - the 256-tap FIR over views takes 51 µs and over raw pointers 27, so a hot kernel is still measured both ways;
    - a size-first build is still `-Oz` where it does not name the package under `release.speed`, and P7 to P9's wasm
      costs were measured at both levels through `.scratch/area4/tools/emcc`, which swapped the flag.
    - The kama FFT cannot carry a long reverb's stages at `-Oz`; pffft can.
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
- KAUD-2, KAUD-5, KAUD-7 and KAUD-8 upstream.
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
5. **The feature map and the order of work.** **Decided (§ Decided, 27 to 30)** after a survey of Web Audio 1.1, the
   game middleware, the DAW engines and speech (RESEARCH.md § 10):
   - **The map:** [FEATURES.md](FEATURES.md), one row per feature, naming features only, each with golden samples as
     its test and three measured numbers as its budget.
   - **The order, by example:** a sample-exact loop, a game's sounds, adaptive music, voice chat, spatial sound on a
     headset, a synth on MIDI, and a multitrack session.
   - **A DAW's own engine** is a package of its own, on this one's public API.
   - **Speech, for kyoten's accessibility** (KYR-76), is a package of its own too. This package's half is a tap, a
     source the program feeds, and the output as a media stream.

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
   - **Decided in area 5 (decision 29):** a DAW's own engine (transport, clips, plugin hosting) is a package of its
     own, on this one's public API. Delay compensation and the other properties of the graph stay here.

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
   - **Amended on 2026-11-16:** decision 34 says what keeps the count (a row of the program side's slot table) and
     an id's width, and decision 35 when a dropped node's release is sent.
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
   - **Amended on 2026-11-18:** decision 36 says how the allocator is handed over: as callbacks, `AudioMemory`.
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
   - **Amended on 2026-11-15:** decision 32 says what the stamp is (a call's own time, which its node keeps), and
     decision 33 says that a flush lands whole.
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
   - **Amended on 2026-11-15:** every call waits in the backlog until a flush (decision 33), and a late command is one
     whose own time has passed when it lands (decision 32).
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

27. **Decided on 2026-11-15: the feature map is [FEATURES.md](FEATURES.md), one row per feature, naming only features**
    (area 5, question 1). The owner: "I think yes as drafted... I'm not sure if we should be listing production names
    though. Can we just focus on the features?" So the draft's column of the middleware's and the DAWs' names was
    removed.
    - **A row says:**
      - the feature, and its Web Audio name, which is the lower tier's own (decision 3);
      - its rungs from cheap to best, with what each needs;
      - its status (`planned`, `partial` or `built`);
      - the example that first needs it, or `asked`;
      - its test and its budget.
    - **No other product is named in the map.**
      - It names features, Web Audio's names, and the standards a feature meets (SOFA, MIDI, BS.1770).
      - A rung names its technique. Which library implements it is a decision here.
      - The products the survey read stay in RESEARCH.md § 10, as the evidence.
    - **Its test is golden samples.**
      - An offline render is hashed, and the hash must be the same in native debug, native release and wasm, and equal
        to the golden.
      - When a golden is made or changed, its render is compared with a reference within a stated dB: a float64
        implementation, the spec's formula or a reference library. Only an explicit command changes a golden.
      - The platform's own samples (AAC) are compared in dB instead.
    - **Its budget is three measurements,** and never limits what is built:
      - the wasm a feature adds (KB, brotli);
      - its render cost, in ms of a core per second of audio for one instance, natively and in wasm at `-Oz`, with
        `-O3` noted while KAUD-6 is open;
      - its memory for one instance (decision 6).
    - **Two guards hold it,** ported from `@kama/graphics`': `tools/check-features.sh` and `tools/check-roadmap.sh`.
      Each of their 27 failure cases was seen to fail, for its own reason, on a mutated copy
      (`.scratch/area5/mutate_guards.py`).
    - **Why:**
      - It is `@kama/graphics`' reason (kyoten's `rendering.md`, 2026-11-11): one list says what is built, what each
        example needs and what each costs, so the order cannot drift and nothing lands untested.
      - A hash that holds on every leg is audio's golden image. It is possible because decision 14 makes the samples
        identical.
      - The reference check keeps a wrong first render from becoming the golden.
28. **Decided on 2026-11-15: the order is by example** (area 5, question 2). The owner: "option 1 sounds good to me so
    far."
    - **Seven slices,** each what one of the library's examples needs, built end to end on the web and natively, each
      example a test (ROADMAP.md, AUD-29 to AUD-35):
      1. a sample-exact loop (cosmic-forge's CF-24), the first slice through every part;
      2. a game's sounds;
      3. adaptive music;
      4. voice chat;
      5. spatial sound on a standalone headset;
      6. a synth on MIDI;
      7. a multitrack session.
    - **Then the state of the art, as programs ask:**
      - SOFA at run time (AUD-19);
      - geometric acoustics (AUD-20);
      - audio objects (AUD-36) and haptics (AUD-37);
      - kama in place of the vendored C (AUD-38).

      The first publish runs alongside (AUD-39).
    - **The 28 parts that areas 2 to 4 decided keep their ids,** and each is built by the first slice that needs it
      (ROADMAP.md § The parts).
    - **The headset slice moves earlier** as soon as kama's Android app (kyoten's KY-2) and an XR package (kyoten's
      KYR-31) land.
    - **Why:**
      - The games come first. kyoten's audio module (KYR-15) binds the game's-sounds slice for its fps example (KYR-65),
        and the DAW (KYR-35) is later on kyoten's roadmap.
      - The loop is first because it is the smallest slice through every part, and a real user is waiting on it.
      - The survey added adaptive music, which all the game middleware has (RESEARCH.md § 10.1).
29. **Decided on 2026-11-15: a DAW's own engine is a package of its own, on this package's public API** (area 5,
    question 3, and decision 2's open question). The owner took the recommendation.
    - **That package holds what is a DAW's alone:**
      - editing the tempo and meter map, and positions in beats;
      - tracks and clips, with fades, crossfades and warping;
      - punch and loop recording, takes and comping;
      - plugin hosting (CLAP natively and WebCLAP on the web), with process isolation natively;
      - sync by MIDI clock and MTC;
      - the project document and its undo.

      It is built when kyoten's DAW tool (KYR-35) or another DAW asks for it, and named then.
    - **This package keeps what a game also uses:**
      - sample-accurate automation;
      - latency reported and compensated;
      - sidechain inputs, buses and sends;
      - an offline bounce, and render workers;
      - metering and loudness, and recording to a file;
      - the tempo map as a function from beats to frames, which adaptive music needs too.

      The multitrack session slice (AUD-35) proves the graph carries a DAW before that package exists.
    - **It uses only the public API,** as the upper tier uses the graph's (decision 2), so nothing it needs is out of
      another program's reach.
    - **Why** (RESEARCH.md § 10.2):
      - Plugin hosting loads a third party's code at run time. Natively that is a binary called on the audio thread or
        in a sandbox process, and on the web a third party's wasm instantiated in the worklet. A game never ships it,
        and a console's platform may not allow it.
      - The project document and its undo are an application's.
      - The engines that split them show the line: one DAW engine ships its graph as a layer usable without its
        session model, and a widely used plugin framework keeps its graph apart from any session.
      - The mature DAW engines are GPL or AGPL, as are Rubber Band and Ableton Link, so they are references, never
        dependencies.
30. **Decided on 2026-11-15: speech is a package of its own, on this package's public API** (area 5, question 4, for
    kyoten's KYR-76). The owner took the recommendation.
    - **Its two ladders:**
      - **text to speech:**
        - the platform's voice played by the platform. On the web it is the only rung with no model, and the engine
          ducks the mix around it;
        - the platform's voice as samples into the mix (Apple, Windows and Android);
        - a local voice model rendering into the mix on every leg;
      - **speech to text:**
        - the platform's recognizer on the device, fed the engine's frames: Chrome and Firefox through a
          `MediaStreamTrack`, Apple and Android through buffers;
        - a local model on every leg, downloaded only when a player turns it on.
    - **This package's half is three lower-tier features, built by the voice-chat slice (AUD-32):**
      - frames tapped from any node to the program's thread;
      - a source the program feeds;
      - on the web, the output as a media stream.

      None of them is speech's alone: voice chat's encoder and the network use them too.
    - **Wherever the platform or a model gives samples, the voice renders into the mix,** so it can be placed, ducked
      and sent over voice chat. One accessibility guideline sends a player's typed chat as speech on the voice channel.
    - **Which rung each leg defaults to, and what may leave the device,** are that package's and kyoten's to decide
      (kyoten's `accessibility.md`, questions 4 and 5).
    - **Why** (RESEARCH.md § 10.3):
      - Web Speech's synthesis never reaches Web Audio: measured in Chrome 157 and Firefox 160, and its proposal has
        had no activity since 2019.
      - Natively, three of the four OSes hand back samples; Linux's does not.
      - The models are tens of MB and need an inference runtime, which an audio engine does not.
      - The platforms' speech services are bindings of their own.
      - Recognition runs off the audio thread anyway.
31. **Decided on 2026-11-15: the package's first cut of modules** (AUD-29's first question). The owner took the
    recommendation.
    - **`audio`** is the lower tier, Web Audio's graph under Web Audio's names (decision 3).
    - **`audio::sound`** is the upper tier: `Sound`, `Voice`, `Bus`, `Snapshot` and `Emitter` (decision 3's proposal).
    - **`audio::rt` is public,** and holds the real-time primitives that the engine and a program's own DSP share. The
      first is the lock-free ring the command protocol runs on (AUD-1), and the tap's and the fed source's rings of
      frames follow.
    - **Why `audio::rt` is public:**
      - the tests program is a package of its own, and reaches only public modules;
      - the DAW and speech packages are built on this package's public API only (decisions 29 and 30), and move data
        between a real-time thread and the program's the same way;
      - kama's `internal` visibility would hide it from both.
    - **Amended on 2026-11-16:** the backlog in front of the ring (decision 33) and the slot table (decision 34) are
      among its primitives.
    - **Amended on 2026-11-18:** an internal module, `audio::graph`, holds what a context and its nodes share, so the
      lower tier's files share it and no program can import it (settled under decisions 4 and 34, and reported).
32. **Decided on 2026-11-15: a call scheduled ahead waits in its node, as in Web Audio** (AUD-29, the command
    protocol). Decisions 3, 7 and 8 had left this open: the audio side drains the ring once a quantum, so something
    has to hold a `src.start(when: 2.0)` for the 750 quanta until its time comes. The owner took the recommendation.
    - **A command applies in the quantum it lands in.** The audio side drains the ring at the top of each quantum and
      applies every command there, in order. A call with no time of its own takes effect in that quantum, as Web
      Audio's control messages do: a node made, a `connect()`, a property set.
    - **A call's time travels inside its command,** as the int64 frame decision 3 converts it to (a source's start
      also carries its sub-frame fraction). That is decision 7's stamp, and the node keeps it:
      - a source keeps its start and stop frames in its slot;
      - a parameter keeps its events in its timeline. The timeline's capacity is declared per parameter (decision 6),
        and a full timeline is an error at the call. The program's side knows every event it added, and from the
        playhead (decision 9) which ones have passed. So its count never says fewer than the audio side holds;
      - the render splits a quantum at each frame that falls inside it.
    - **A time that has already passed when its command lands** follows Web Audio's rule: a start begins at once, and
      an automation event takes effect at once. The command is counted as late (decision 8).
    - **Nothing queues on the audio side but the nodes' own state,** so its memory is the slots and the timelines, and
      both are declared.
    - **Why:**
      - A ramp has to reach the audio side before its end time. `linearRampToValueAtTime(value: 1, endTime: 2.0)`
        ramps from the event before it, so the timeline must live in the node either way.
      - Holding every command until its own frame would take a pending table on the audio side, a third limit. It
        would also add a lead to every untimed call, to make a `connect()` exact to the sample when Web Audio gives a
        `connect()` no time at all.
      - Web Audio's model is decision 3's, so MDN documents the lower tier's timing as well as its names.
    - **For replay** (decision 7), a run made in real time also needs the quantum each flush landed in. The way back
      can report it. How is decided when replay is built (the `session` example).
33. **Decided on 2026-11-15: a flush lands whole, in one quantum** (AUD-29, the command protocol). The owner took the
    recommendation.
    - **Calls collect in the program side's backlog** (decision 8), in order. The context's `update()` flushes it
      (decision 10), and so does an offline render before it starts:
      - as many calls as the ring has room for move into it;
      - one release store publishes them, so the audio side sees all of them in the same quantum, or none.
    - **What does not fit waits,** in order, and goes first on the next flush (decision 8). Only then can a frame's
      calls split across quanta, and the backlog's counts show it.
    - **Both web routes behave the same.** The page route already sends one transferred `ArrayBuffer` a flush
      (decision 12), and the worklet's instance applies it between quanta.
    - **Why:**
      - a crossfade made of two `.value` sets cannot land a quantum apart;
      - the shared route and the page route apply a frame's calls alike;
      - a call waits only until the end of its frame's `update()`, which is where the upper tier makes its calls
        (decision 10).
34. **Decided on 2026-11-16: a node's count is kept in the program side's slot table** (AUD-2's questions 1, 3 and 4).
    The owner took the recommendations.
    - **One row per slot, on the program's side alone,** so the audio thread never touches a count (decision 4).
      - A node's handle holds the context's state, its slot and its generation.
      - A copy counts its row up and a drop counts it down, as `@kama/gpu`'s `StateHold` counts its C block by hand.
      - A buffer is counted the same way.
    - **Its capacity is declared** (decision 6):
      - the table is taken once, when the context is made, from the allocator the context is handed, and never grown;
      - a full table is an error at the call that makes a node, and nothing is made;
      - nothing is allocated per node.
    - **An id is a 32-bit slot and a 32-bit generation in one int64,** the field a command names a node by.
      - A freed slot is reused with the next generation.
      - A slot whose generation would wrap is retired, never reused.
    - **The table is one of `audio::rt`'s public primitives,** beside `Ring` and `Backlog`, for the reasons decision 31
      gives (the owner, 2026-11-16, asked once it was found that the tests program cannot reach an `internal`
      module).
      - The DAW and speech packages (decisions 29 and 30) can keep their own objects, whose ids cross to the audio
        thread, in tables of their own of the same type.
      - It is built and tested on its own, test-first, before the first node.
    - **Its storage is the ring's `Slots`,** in the same file and never exported. std's `SlotMap` cannot serve, since
      it traps when its allocator has no room (KAUD-7).
      - The free rows are chained in the order they were freed, so a freed slot waits longest before its reuse.
    - **Why:**
      - The other way, a `Shared` per node drawn by `try new(allocator:)`, traps at an arena's limit even where the
        node fits (KAUD-8).
      - A bump arena gives nothing back before its reset, and Web Audio's sources are single-use, one per sound. So a
        `Shared` per node would spend a game's arena as it plays, where a table's release costs the allocator nothing.
      - Commands and reports are ordered, so the generation is a check that catches a bug, and it lets a report name
        its node. At 32 bits one slot wraps only after four billion reuses.
35. **Decided on 2026-11-16: a dropped node's release never needs room** (AUD-2's question 2). The owner took the
    recommendation.
    - **The last drop marks its row.** A flush sends the marked rows' releases once the backlog has drained, in the
      order they were marked.
    - **So a release is never refused, and never overtakes a command that names its node:** every such command was
      added before the drop.
    - **The table's capacity bounds the marked rows,** so they need no limit of their own.
    - **What a release means is decision 4's:** the program holds the node no more. The audio side keeps it while it
      can still sound, then reports the slot freed.
    - **Why:**
      - A destructor cannot return an error, and decision 8's error is a call's.
      - A release added to the backlog could find it full.
      - A release sent ahead of the backlog could overtake the node's own commands.
36. **Decided on 2026-11-18: the program's memory is handed over as callbacks** (AUD-2's handle; how decision 6's
    allocator is injected). The owner first asked of the erased option as framed, whose context kept its bookkeeping on
    the global heap: "is option 1 the no hack production grade answer for general purpose?" It was not. The callbacks
    were probed next and taken as recommended.
    - **`AudioMemory` is a user pointer and the allocator's functions,** as miniaudio's `ma_allocation_callbacks`,
      FMOD's memory callbacks and Wwise's memory hooks take a program's memory. It is a plain `type value` that
      implements kama's `Allocator`, so it is the allocator of every package type, and no type names the program's:
      `GainNode` and `OfflineAudioContext` are written as MDN writes them (decision 3).
    - **Every byte the library allocates is drawn through it,** the context's state included. Nothing is boxed, and
      nothing goes to the global heap behind the program's back (decision 6).
    - **The package ships the callbacks for kama's two allocators:**
      - `AudioMemory.global()`, the global heap;
      - `AudioMemory.inArena(arena:)`, an std `Arena`, which outlives every context made from it, as it outlives its
        containers.

      A program with an allocator of its own hands its pointer and three free functions, as it would in C.
    - **Its cost is one indirect call per allocation.** An allocation happens only at a make or a hand-back, on the
      program's side, never on the audio thread (decision 5).
    - **Why:**
      - kama reaches an allocator through a type parameter, so an allocator injected plainly puts its type into every
        type that holds it (`GainNode<BumpAllocator>`). kama 0.9.966, 0.9.978 and 0.9.981 infer it at no make, not
        even the default, so every program would write `GainNode::<GlobalAllocator>.make(…)` (`.scratch/aud2-generic/`).
      - kama cannot yet erase an allocator without a box. A generic function's instance cannot be bound to an `fnptr`
        ("a FunctionPtr binds a free function name or another FunctionPtr"), and a contract handle or a
        `BindableFunctionPtr` boxes on the global heap (`.scratch/aud2-handle/`, `.scratch/aud2-erased/`; KAUD-9).
      - The callbacks need neither. On 0.9.966, 0.9.978 and 0.9.981, an `Arena`'s, the global heap's and a
        program's own allocator each served a slot table and the state's `Shared`, and the program's own had every byte back
        (`.scratch/aud2-callbacks/`).
    - **Later:** once a generic function's instance binds to an `fnptr` (KAUD-9), the package can write the callbacks
      for any allocator (`AudioMemory.of(allocator:)`). That adds to the API and changes nothing in it.
37. **Decided on 2026-11-19: an offline render is a request the program polls, advanced by `update()`** (AUD-29, the
    render; AUD-5 and AUD-9). Web Audio's `startRendering()` is a promise the browser fulfils from its own thread, kama
    has no promises, and the package starts no thread (decision 10), so something had to say who runs the render's
    quanta and when. Offered a render the program steps with a one-call form, one call only, or stepped only, the owner
    asked: "I assume option 1 is the production answer? I know we already had answered similar questions regarding lack
    of promises in kama where we decided the best answer was a poll mechanism per frame?" Told that it was, and how the
    stepped render lines up with `@kama/gpu`'s polling, the owner said: "yes record it and build the first slice".
    - **`startRendering()` answers a request,** as `@kama/gpu`'s `requestAdapter(options:)` does, and starts the render
      without rendering anything. A second start is Web Audio's `InvalidStateError`.
    - **The program's `update()` does the work,** once a frame (decision 10): it flushes, renders whole quanta on the
      calling thread until it has rendered the context's declared frames per update, or the end, and reads the way back
      (decision 9). Unlike a GPU request, which the browser or the driver works on while the program polls, an offline
      render has no one else to run it, so the per-frame call that polls also advances it.
    - **`request.poll()` answers where it is:** pending, with the frames rendered so far, or ready, with the
      `AudioBuffer`. A poll after ready answers ready again.
    - **The frames per update are a declared option of the context** (decision 6), so the stall one update can cause is
      bounded. A golden or a short bounce declares the whole length, and one `update()` renders it all.
    - **Web Audio's `suspend()` and `resume()` keep their names,** in a step of their own: the render stops at the frame
      asked, `poll()` answers suspended, the program makes its calls, and `resume()` carries on, so a change lands at
      that exact frame.
    - **The output buffer is a declared part,** sized by the context's length and channels and drawn at the make with
      the rest (decision 6). The `AudioBuffer` handed over is a counted resource that outlives the context, as Web Audio's
      does.
    - **Why:**
      - It is the one asynchronous pattern the siblings share: what kama cannot await is polled, never a callback into
        kama (`@kama/gpu`'s SPEC; decision 9).
      - The program owns the thread and the pacing (decision 10): a game advances a long bounce a little each frame, and
        a test or a tool renders the whole length in one update.
      - A render in one call would stall a game's frame for the whole length (a 3-minute bounce is about 67,000 quanta),
        and would leave Web Audio's `suspend()` nowhere to run.
      - It gives FEATURES.md's "an open length rendered in chunks" its mechanism.
    - **What it pulls forward:** `update()` (AUD-5) becomes the offline render's driver as well as the way back's reader,
      and the flush and the read become public through it.
38. **Decided on 2026-11-19: a node's output samples live in a block of its own, drawn at the make** (AUD-29, the render;
    decisions 5, 6 and 19). Each quantum every node writes its samples and the nodes after it read them; a node carries
    1 to 32 channels, and its count changes as it plays (a stereo buffer makes everything after it stereo). Every engine
    surveyed allocates on the audio thread for this (RESEARCH.md § 11.1), so none could be copied. Offered a block per
    node, with a silent flag, or a shared pool with pushed sums, both timed (§ 11.2), the owner took the recommendation.
    - **Each node's slot has an output block, drawn with the context at the make** (decision 6): a quantum for each of
      a declared most channels per node, a context option. Its default is 2, or the context's channels when it has more.
      So the render's sample memory is the slots times that many quanta: 1 MiB at 1,024 rows in stereo.
    - **It never runs out while rendering.** A node whose channels would pass the declared most is down-mixed to it by Web
      Audio's speaker rules, and counted, so a program that carries more channels declares more.
    - **A silent flag per block,** as Chromium's per channel: a silent node writes nothing, and a sum skips it, so silence
      costs about what a pool's costs.
    - **Why:**
      - With everything sounding, a block per node was 10 to 28% faster than the pool, the arithmetic being the cost and a
        megabyte of blocks sitting in L2; with the flag, it matched the pool with half the sources silent (93 µs and
        105 µs a quantum at 511 stereo sources natively, 148 and 187 on wasm).
      - It cannot run out at a graph's shape, where a pool would need a reported silence at its limit, and a program
        sizes it from what it declares, not from what it measured.
      - Each node owning its output is what declared render workers need (decision 19): a pool's shared sums would make
        workers contend.
      - The pool's one gain was memory, 32 times less (3 blocks for 511 stereo sources).
39. **Decided on 2026-11-19: the render's first source is Web Audio's `ConstantSourceNode`** (AUD-29, the render). Until
    a source exists, every render is silence. Offered `ConstantSourceNode` first or `AudioBufferSourceNode` directly, the
    owner took the recommendation.
    - **`ConstantSourceNode` makes the render's first samples:** a constant, set at its make (its `offset` option; the
      `AudioParam` comes with parameters), started and stopped on exact frames with `start(when:)` and `stop(when:)`, its
      end reported on the way back, and a released one kept while it plays.
    - **Why:** the buffer player needs every one of those pieces, and this one needs no answer on how a buffer's samples
      count against the sample memory. It pulls the constant source forward from the synth example to the loop.

## Where the truth is

- **This repository's documents, each to one purpose:**
  - [FEATURES.md](FEATURES.md) is every feature and where it stands;
  - [ROADMAP.md](ROADMAP.md) is the order of work, with [ROADMAP_DETAIL.md](ROADMAP_DETAIL.md) its reasoning;
  - [SPEC.md](SPEC.md) is what is built;
  - [RESEARCH.md](RESEARCH.md) is the design pass's evidence;
  - this file is the brief and the record of decisions.
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
    tools/check-features.sh   # FEATURES.md stays complete: statuses, examples, tests and budgets
    tools/check-roadmap.sh    # ROADMAP.md stays short, its ids valid and every detail section scheduled

kyoten builds with its own pinned kama (`../kyoten/.kama-version` names the commit, and its `AGENTS.kyoten.md` § Build
says how to make the pin from a clean clone, with the Mac's steps). Run it as `../kyoten/tools/kama`. A web build needs
emscripten's `emcc`. The probes in `.scratch/aud-probe-*/` each run with their `run.sh`, headless and muted, in the
pinned browsers in `~/browsers`.
