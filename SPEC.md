# @kama/audio — the specification

What this library **is**, written after each piece lands. Never speculative: what is described here exists and is
tested.
- What comes next is [ROADMAP.md](ROADMAP.md), and every feature it will have is [FEATURES.md](FEATURES.md).
- The decided design and the library's departures from kama's are [AGENTS.audio.md](AGENTS.audio.md).
- Its history is the git log and [CHANGELOG.md](CHANGELOG.md).

**Where it stands** (2026-11-17, kama 0.9.966): the first slice, AUD-29 (a sample-exact loop), is under way. The command
protocol's two halves are built (AUD-1): the ring it runs on, which publishes a batch with one store, and the backlog in
front of it. So is the slot table that a command names a node by (AUD-2). Each is tested natively and on wasm under
node, in debug and release. The commands themselves come with the nodes they name. Nothing makes a sound yet. Not
published.

## The modules

Decision 31 sets the first cut:

| Module | What it holds |
|---|---|
| `audio` | the lower tier, Web Audio's graph under Web Audio's names. Nothing yet |
| `audio::sound` | the upper tier: sounds, voices, buses, snapshots and emitters. Not made yet |
| `audio::rt` | the real-time primitives that the engine and a program's own DSP share: `Ring`, `Backlog`, `SlotTable`, `CapacityError`, `slotOf`, `generationOf` |

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

## The slot table

**A node's handle names its row in the program side's table, and only the row's id crosses to the audio side, never a
pointer** (decisions 4, 34 and 35). The handle comes with the first node; the table is built and tested on its own,
before it.

### `audio::rt::SlotTable<A>`

- **Making one:**
  - `SlotTable::<A>.withCapacity(capacity:)` takes its storage from `A`'s default, the global heap;
  - `SlotTable::<A>.withCapacityAndAllocator(allocator:, capacity:)` takes it from `allocator`;
  - each returns `Result<SlotTable<A>, CapacityError>`, and takes its storage as the ring does: once, never grown, and
    given back at the drop. Nothing is allocated per row;
  - a capacity below one is `BadCapacity`, and so is one above 2^32, which a 32-bit slot cannot name. That bound is
    checked before the allocator is asked.
- **An id is one `int64`:** the slot in its low 32 bits, the generation in its high 32. Generations start at 1, so no
  live id is 0. `audio::rt::slotOf(id:)` and `audio::rt::generationOf(id:)` read its halves.
- **A row's life:**
  - **`take()`** answers the id of the row freed longest ago, counted once. A fresh table's rows count as freed at the
    make, in slot order. It answers `None` when every row is held or retired, and then nothing changes;
  - **`countUp(id:)`** is a copy of the handle, and **`countDown(id:)`** a drop. The last drop marks the row, behind
    every row marked before it. The row is still held;
  - **`nextRelease()`** answers the id of the row marked longest ago, whose release the flush sends now, or `None`
    (decision 35). The row is still held, since the audio side keeps a node while it can still sound;
  - **`free(id:)`** is the audio side's report. The row waits behind every row freed before it, at the next
    generation. A row whose generation is the last, 2^32 − 1, is retired instead and never handed out again.
- **An id that names no row in the state a call needs is refused,** never trapped: `countUp`, `countDown` and `free`
  answer `false`, and `countOf` answers 0. That covers an id of a row's earlier generation, a slot past the table, a
  free slot, 0 and −1, a row freed before its release was sent, and a row freed twice. Nothing a program passes ends it.
- **What it answers:** `countOf(id:)` is the copies held; `length()` is the rows held (taken, marked, or released and
  not yet freed); `capacity()` is the rows it was made with; `retired()` is the slots whose generations are spent.
- **The test seam.** The table grants one function of the tests program, `audiotests::ageSlot`, a free row's
  generation (`friend audiotests::ageSlot[ageTo];`), so the wrap case need not free a slot four billion times. It is
  the package's only seam, named in its source.
- **Tested** (`tests/src/slots_tests.kama`, the `slots` cases, 15 of them):
  - a fresh table is empty at its declared capacity, with nothing retired and no release due;
  - both refusals, and more slots than 32 bits can name refused as `BadCapacity` before the allocator is asked. On a
    32-bit target no `isize` can pass the bound, so the case holds there by construction;
  - the storage comes from an injected allocator exactly once, and goes back at the drop;
  - a fresh table hands out its slots in order, at generation 1, each counted once, and refuses a take when full,
    changing nothing;
  - a row's count goes up with each copy and down with each drop, and the last drop marks it. A marked row is still
    held: neither a take nor its release hands its slot out again before the report frees it;
  - releases come out in the order the rows were marked;
  - a freed slot is reused at the next generation, after every slot freed before it, in the order the reports freed
    them, whatever the order of the takes and releases, and a full table is full again once they are retaken;
  - a slot whose generation would wrap is retired, never handed out again, and its last id is refused;
  - an id of a row's earlier generation is refused and changes nothing, and so is every id no take answered: the slot
    just past the table, which the storage's index would otherwise wrap onto slot 0, and a freed row's next generation
    before a take answers it.

## Proved by mutation

### The ring and the backlog

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

### The slot table

Each of 47 mutations of the table's code runs through the whole gate (`.scratch/aud29/mutate_slots.py`), and the file
is restored byte for byte after each. **All 47 turn a case red, none by a hang.**
- **The first pass caught 43.** Each of the four it missed showed a case too loose, and the case was sharpened:
  - **a slot exactly at the bound passing:** the case named slot 7, and the storage's index wraps, so only the slot just
    past the table lands on a taken row;
  - **`nextRelease()` keeping the row's link:** the stale link only reaches the free chain's end, so a full table must
    stay full once its slots are retaken;
  - **a freed row left released:** an id of its next generation could then be freed before any take answered it;
  - **`retired()` answering how many are held:** the wrap case checked it only where the two were equal.
- **`free()` clearing the row's link** was dropped before the pass, since `nextRelease()` has already cleared it: a row
  leaving a chain has its link cleared where it leaves, as `take()` does.

