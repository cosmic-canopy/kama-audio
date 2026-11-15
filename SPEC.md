# @kama/audio — the specification

What this library **is**, written after each piece lands. Never speculative: what is described here exists and is
tested.
- What comes next is [ROADMAP.md](ROADMAP.md), and every feature it will have is [FEATURES.md](FEATURES.md).
- The decided design and the library's departures from kama's are [AGENTS.audio.md](AGENTS.audio.md).
- Its history is the git log and [CHANGELOG.md](CHANGELOG.md).

**Where it stands** (2026-11-15, kama 0.9.960): the first slice, AUD-29 (a sample-exact loop), is under way. The command
protocol's two halves are built (AUD-1): the ring it runs on, which publishes a batch with one store, and the backlog in
front of it. Both are tested natively in debug and release and on wasm under node. The commands themselves come with
the nodes they name. Nothing makes a sound yet. Not published.

## The modules

Decision 31 sets the first cut:

| Module | What it holds |
|---|---|
| `audio` | the lower tier, Web Audio's graph under Web Audio's names. Nothing yet |
| `audio::sound` | the upper tier: sounds, voices, buses, snapshots and emitters. Not made yet |
| `audio::rt` | the real-time primitives that the engine and a program's own DSP share: `Ring`, `Backlog`, `CapacityError` |

## The command protocol's two halves

**Every call's command goes into the backlog on the program's side. A flush moves it into the ring, and the audio side
drains the ring at the top of each quantum** (decisions 7, 8, 32 and 33). The context's `update()` will be the flush.
- **Both halves take an element that is a `value`:** flat bytes with no destructor, so the side that pops never drops
  anything.
- **Both take an `Allocator` `A`,** `GlobalAllocator` by default. A backlog flushes into a ring of the same `A`, since
  one allocator handed to the context serves both (decision 6).
- **Both take their storage the same way:**
  - once, at the make, as `capacity` elements;
  - never grown;
  - given back to the same allocator at the drop.
  
  std's collections are not used for it, since each traps when its allocator has no room (KAMA_GAPS.md KAUD-7).
- **Both refuse a make the same way,** with `audio::rt::CapacityError`, and then nothing is made:
  - a capacity below one is `BadCapacity`;
  - an allocator with no room is `OutOfMemory`.

### `audio::rt::Ring<T, A>`

**One producer, one consumer, and nothing between them that waits.** The program's side flushes into it; the audio
side pops.

- **Making one:**
  - `Ring::<T>.withCapacity(capacity:)` takes its storage from the global heap;
  - `Ring::<T, A>.withCapacityAndAllocator(allocator:, capacity:)` takes it from `allocator`;
  - each returns `Result<Ring<T, A>, CapacityError>`.
- **The producer's side:**
  - `stage(item:)` writes an item where the consumer cannot see it yet. It answers `false` when the ring is full,
    counting what is already staged, and then writes nothing;
  - `publish()` makes everything staged visible at once, with one release store. So the consumer sees a batch whole or
    not at all;
  - `push(item:)` is one item staged and published, together with anything staged before it. A refused push publishes
    nothing.
- **`pop()` is the consumer's side.** It answers `None` on an empty ring. It is `@noheap`, so it never allocates, and
  it never waits.
- **`capacity()`** is the capacity it was made with.
- **The counters:**
  - they are monotonic int64s, masked only at the array, so any capacity works, not only a power of two;
  - each sits on its own 128-byte line, and so does the producer's count of what it has staged;
  - each side publishes its counter with a release store, and reads the other's with an acquire load.
- **Tested** (`tests/src/ring_tests.kama`, the `command-ring` cases, 12 of them):
  - a fresh ring is empty at its declared capacity;
  - what is pushed comes out in order;
  - a full ring refuses a push and keeps what it holds;
  - the counters go a thousand times round a capacity of 3, in order;
  - both refusals;
  - the storage comes from an injected allocator exactly once, and goes back at the drop;
  - a staged item cannot be popped until it is published, then comes out in order;
  - what is staged counts against the capacity;
  - a push publishes what was staged before it;
  - a million commands cross to a second thread (a pthread natively, a Wasm Worker on wasm) whole and in order;
  - a million staged in batches of 5 cross with each batch seen whole: whenever the consumer finds the ring empty, it
    has seen a whole number of batches.

### `audio::rt::Backlog<T, A>`

**The program's side's alone,** in front of the ring.

- **Making one:**
  - `Backlog::<T>.withCapacity(capacity:)` takes its storage from the global heap;
  - `Backlog::<T, A>.withCapacityAndAllocator(allocator:, capacity:)` takes it from `allocator`;
  - each returns `Result<Backlog<T, A>, CapacityError>`.
- **`add(item:)`** puts an item behind what the backlog holds. It answers `false` when the backlog is full, and then
  writes nothing. So the call that made the command can return an error, and nothing is lost (decision 8).
- **`flushInto(ring:)`** moves items from the front, in order, as many as the ring has room for. One release store
  publishes them (decision 33). It answers how many moved. What is left waits, in order, ahead of anything added later,
  and goes first on the next flush.
- **`length()`** is how many it holds now, and **`capacity()`** the capacity it was made with.
- **Its two high-water marks:**
  - `highWater()` is the most it has held at once, which its declared capacity must allow;
  - `mostLeft()` is the most a flush has left behind, which says by how much the ring was too small.
- **Tested** (`tests/src/backlog_tests.kama`, the `backlog` cases, 10 of them):
  - a fresh backlog is empty at its declared capacity, with both marks at zero;
  - what is added reaches the ring only at a flush, in order;
  - a flush moves what the ring has room for, and what is left goes first on the next one, ahead of what was added
    since;
  - a full backlog refuses an add and keeps what it holds;
  - a flush into a full ring moves nothing and keeps the order;
  - both marks, and that neither falls when less follows;
  - both refusals;
  - the storage comes from an injected allocator exactly once, and goes back at the drop;
  - a million commands flushed in batches of 5, each flush made when the ring surely has room for all of it, cross to a
    second thread: every such flush moves the whole batch, and the consumer sees each one whole.

### Proved by mutation

Each mutation of `src/rt/ring.kama` runs through the whole gate (`.scratch/aud29/mutate_ring.py`), and the file is
restored byte for byte after each. **38 of 39 mutations turn a case red, none by a hang,** since the thread cases have a
deadline.
- **The flush publishing each item on its own** can be seen only from another thread. The backlog's thread case
  catches it every time: red on every leg in 5 of 5 runs.
- **The one missed is the publish made relaxed.** That is a weak-memory race, and no deterministic test holds it: the
  million-command crossing caught it in one run and missed it in the next. So the release and acquire pair is held by
  review.
- **Removing `publish()`'s early return when nothing is staged** is equivalent, since it stores the same head, and it is
  dropped.
