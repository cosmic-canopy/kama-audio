# Changelog

All notable changes to `@kama/audio`. The format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
