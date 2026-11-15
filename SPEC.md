# @kama/audio — the specification

What this library **is**, written after each piece lands. Never speculative: what is described here exists and is
tested.
- What comes next is [ROADMAP.md](ROADMAP.md), and every feature it will have is [FEATURES.md](FEATURES.md).
- The decided design and the library's departures from kama's are [AGENTS.audio.md](AGENTS.audio.md).
- Its history is the git log and [CHANGELOG.md](CHANGELOG.md).

**Where it stands** (2026-11-15, kama 0.9.960): the first slice, AUD-29 (a sample-exact loop), is under way. Its first
part is built, the ring the command protocol runs on (AUD-1), and it is tested natively in debug and release and on
wasm under node. Nothing makes a sound yet. Not published.

## The modules

Decision 31 sets the first cut:

| Module | What it holds |
|---|---|
| `audio` | the lower tier, Web Audio's graph under Web Audio's names. Nothing yet |
| `audio::sound` | the upper tier: sounds, voices, buses, snapshots and emitters. Not made yet |
| `audio::rt` | the real-time primitives that the engine and a program's own DSP share: `Ring` |

## `audio::rt::Ring<T, A>`

**One producer, one consumer, and nothing between them that waits.** The program's side pushes; the audio side pops.

- **`T` is a `value`:** flat bytes with no destructor, so the side that pops never drops anything.
- **`A` is an `Allocator`,** and `GlobalAllocator` by default.
- **Making one:**
  - `Ring::<T>.withCapacity(capacity:)` takes its storage from the global heap;
  - `Ring::<T, A>.withCapacityAndAllocator(allocator:, capacity:)` takes it from `allocator`;
  - each returns `Result<Ring<T, A>, RingError>`.
- **Its storage:**
  - it is taken once, at the make, as `capacity` elements;
  - it is never grown;
  - it is given back to the same allocator when the ring drops.
- **What is refused:**
  - a capacity below one is `RingError::BadCapacity`;
  - an allocator with no room is `RingError::OutOfMemory`, and then no ring is made.
- **`push(item:)` is the producer's side.** It answers `false` on a full ring and writes nothing, so a full ring keeps
  what it holds.
- **`pop()` is the consumer's side.** It answers `None` on an empty ring. It is `@noheap`, so it never allocates, and
  it never waits.
- **`capacity()`** is the capacity it was made with.
- **The counters:**
  - they are monotonic int64s, masked only at the array, so any capacity works, not only a power of two;
  - each sits on its own 128-byte line;
  - each side publishes its counter with a release store, and reads the other's with an acquire load.
- **Tested** (`tests/src/ring_tests.kama`, the `command-ring` cases, 8 of them):
  - a fresh ring is empty at its declared capacity;
  - what is pushed comes out in order;
  - a full ring refuses a push and keeps what it holds;
  - the counters go a thousand times round a capacity of 3, in order;
  - both refusals;
  - the storage comes from an injected allocator exactly once, and goes back at the drop;
  - a million commands cross to a second thread (a pthread natively, a Wasm Worker on wasm) whole and in order.

  13 of 14 mutations of the ring turn a case red. The one that does not is its publish made relaxed, a weak-memory race
  no deterministic test holds, so the release and acquire pair is held by review.
