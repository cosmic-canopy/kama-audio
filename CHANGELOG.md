# Changelog

All notable changes to `@kama/audio`. The format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- An offline render is a request the program polls, advanced by `update()` (decision 37):
  `OfflineAudioContext.startRendering()` answers an `audio::RenderRequest` and renders nothing; `update()` flushes,
  renders whole quanta up to the new `OfflineAudioContextOptions.framesPerUpdate` (8,192 by default) and reads the way
  back; `RenderRequest.poll()` answers `audio::RenderStatus`, `Pending(framesRendered)` or `Ready(buffer)`. A second
  start is the new `AudioError::InvalidState` (2026-11-19).
- `audio::AudioBuffer`, Web Audio's, a counted resource that outlives its context: `sampleRate()`, `length()`,
  `duration()`, `numberOfChannels()` and `copyFromChannel(destination:, channelNumber:, bufferOffset:)`, a channel or
  offset out of range being the new `AudioError::IndexSize`. So far a render makes one, silence until a node renders
  (2026-11-19).
- A context draws its render's output and the engine's block from the program's memory: fourteen allocations at a make
  (2026-11-19).
- Fixed: a declared capacity whose bytes overflow a `usize` was made over a wrapped size (a ring of 2^62 over 0 bytes);
  it is `OutOfMemory` now, before the allocator is asked (2026-11-19).
- `audio::AudioNode`, the contract every node implements, and `connect(destination:)`, Web Audio's
  `connect(destinationNode)` (decisions 3, 4, 6 and 8): a connection made twice is one, a node of another context is
  `AudioError::InvalidAccess`, a full backlog `TooManyCommands`, and every declared connection held the new
  `TooManyConnections`, against `OfflineAudioContextOptions.connectionCapacity` (4,096 by default). The audio side keeps
  a released node while a node that can sound feeds it, through any chain of connections, and frees a released cycle
  that nothing feeds; a freed node's connections go with it on both sides (2026-11-18).
- `audio::rt::SlotArray.set(id:, value:)`, which replaces a value at the generation it was put at, and `idAt(slot:)`,
  the id a slot holds, for a walk over every value (2026-11-18).
- A context draws its connections, on each side, and the lifetime walk's marks from the program's memory: eleven
  allocations at a make (2026-11-18).
- The audio side applies a context's commands, and the way back returns a released node's row (AUD-1, AUD-2 and AUD-3,
  decisions 4, 5, 9, 32, 34 and 35): a render quantum drains the command ring at its top and applies every command
  published before it, in order; a released gain, having no input, is freed at once and reported on the way back, a
  ring of the node capacity that always has room for a report; and the program side's read of it frees the row in the
  table for reuse at the next generation. A command the audio side cannot apply (a make into a held slot, a release of a
  node it does not hold at that generation) is refused and counted, never a trap. The renders' public callers come with
  their rows (2026-11-18).
- A context draws the way back and the audio side's array from the program's memory too: six allocations at a make,
  every part taken before a refusal given back (2026-11-18).
- `audio::rt::SlotArray<T, A>`, the audio side's array of slots: a value put at the slot an id names, at the id's
  generation, only into an empty slot, and read or removed only at the generation it was put at; a declared capacity of
  at most 2^32 slots, its storage from an injected allocator, and every id that names no value refused (decisions 4, 5
  and 34) (2026-11-18).
- A call's command reaches the audio side (AUD-1 over AUD-2's handle, decisions 7, 8, 33 and 35): `GainNode.make`
  adds its make to the context's backlog, and the context's flush moves the backlog into the command ring, then the
  due releases once the backlog has drained, all published with one store. A release is never refused and never
  overtakes a command naming its node; a full ring keeps it due (2026-11-18).
- `OfflineAudioContextOptions` declares `ringCapacity` (1,024) and `backlogCapacity` (4,096), each at least one, and a
  context draws both from the program's memory beside its slot table: four allocations at a make, every part taken
  before a refusal given back (2026-11-18).
- `AudioError::TooManyCommands`: a make with the context's backlog full, answered before a row is taken, so nothing
  changes (decision 8) (2026-11-18).
- `audio::rt::Ring.room()`, the producer's room counting what is staged and not yet popped, and
  `audio::rt::Backlog.stageInto(ring:)`, a move that stages without publishing, so a caller can stage more behind it
  and publish once; `flushInto` is the two together (2026-11-18).
- `audio::AudioMemory`, the program's memory handed to a context as a user pointer and three callbacks (decision 36):
  `global()`, `inArena(arena:)`, or `make(user:, allocate:, reallocate:, deallocate:)` for a program's own allocator;
  every byte the package allocates is drawn through it (2026-11-18).
- `audio::OfflineAudioContext` and its `OfflineAudioContextOptions` (Web Audio's, with `nodeCapacity` and `memory`),
  the `audio::BaseAudioContext` contract, and `audio::AudioError` (`NotSupported`, `OutOfMemory`, `TooManyNodes`): a
  make that answers every limit and leaves nothing allocated when it refuses (2026-11-18).
- `audio::GainNode`, the first node: a counted resource whose row in its context's slot table is counted up by `copy`
  and down at each drop, the last drop marking it for release (AUD-2, decisions 4, 34 and 35) (2026-11-18).
- The internal module `audio::graph`, which holds what a context and its nodes share and which no program can import
  (2026-11-18).
- The seed's placeholder `answer()` is gone (2026-11-18).
- `audio::rt::SlotTable<A>`, the program side's table of slots with generations that a command names a node by (AUD-2,
  decisions 4, 34 and 35): a declared capacity of at most 2^32 rows, its storage from an injected allocator, an id of
  a 32-bit slot and a 32-bit generation in one `int64` (`audio::rt::slotOf`, `generationOf`), a row counted up and
  down, its last drop marking it, releases in the order marked, reuse in the order freed at the next generation, a
  slot retired before its generation wraps, and every id that names no row refused (2026-11-17).
- The gate's wasm leg runs debug and release, the release held to Closure (2026-11-17).
- `audio::rt::Backlog<T, A>`, the backlog in front of the command ring (AUD-1, decisions 8 and 33): a declared capacity,
  its storage from an injected allocator, a refused add when full, a flush that moves what the ring has room for and
  publishes it with one store, and its two high-water marks (2026-11-15).
- `audio::rt::Ring` publishes a batch: `stage(item:)` and `publish()`, with `push` the two together (decision 33)
  (2026-11-15).
- `RingError` is now `audio::rt::CapacityError`, the refusal of every declared capacity (2026-11-15).
- `audio::rt::Ring<T, A>`, the single-producer, single-consumer ring the command protocol runs on (AUD-1): a declared
  capacity, its storage from an injected allocator, a refused push when full, and a `@noheap` pop (2026-11-15).
- The tests program (`tests/`) and the gate (`tools/test.sh`): the guards, `kama check`, and the tests natively in
  debug and release and on wasm under node (2026-11-15).
- The design pass's documents: FEATURES.md, ROADMAP.md by example, ROADMAP_DETAIL.md and SPEC.md, with their guards
  (2026-11-15).
- Seeded with `kama seed` on kama 0.9.938 (2026-11-13).
