# @kama/audio — the specification

What this library **is**, written after each piece lands. Never speculative: what is described here exists and is
tested.
- What comes next is [ROADMAP.md](ROADMAP.md), and every feature it will have is [FEATURES.md](FEATURES.md).
- The decided design and the library's departures from kama's are [AGENTS.audio.md](AGENTS.audio.md).
- Its history is the git log and [CHANGELOG.md](CHANGELOG.md).

**Where it stands** (2026-11-18, kama 0.9.978): the first slice, AUD-29 (a sample-exact loop), is under way. The command
protocol's two halves are built (AUD-1): the ring it runs on, which publishes a batch with one store, and the backlog in
front of it. So is the slot table that a command names a node by (AUD-2), and the first node over it: an
`OfflineAudioContext` made from the program's memory, handed over as callbacks, and a `GainNode` counted in its table.
A node's make and its release travel as commands: the backlog, then a flush into the ring. Each is tested natively and
on wasm under node, in debug and release. Nothing reads the commands on the audio side yet, and nothing makes a sound.
Not published.

## The modules

Decision 31 sets the first cut:

| Module | What it holds |
|---|---|
| `audio` | the lower tier, Web Audio's graph under Web Audio's names: `AudioMemory`, `BaseAudioContext`, `OfflineAudioContext`, `OfflineAudioContextOptions`, `AudioError`, `GainNode` |
| `audio::sound` | the upper tier: sounds, voices, buses, snapshots and emitters. Not made yet |
| `audio::rt` | the real-time primitives that the engine and a program's own DSP share: `Ring`, `Backlog`, `SlotTable`, `CapacityError`, `slotOf`, `generationOf` |
| `audio::graph` | **internal**: what a context and its nodes share, `ContextState`, `NodeHold` and the commands, `Command` and `NodeKind`. The package's own modules import it, and no program can |

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
- **`room()`** is the producer's room: the capacity, less what is published and not yet popped, less what is staged.
  The consumer only adds to it, so a stage it allows is never refused.
- **`capacity()`** is the capacity it was made with.
- **The counters:**
  - they are monotonic int64s, masked only at the array, so any capacity works, not only a power of two;
  - each sits on its own 128-byte line, and so does the producer's count of what it has staged;
  - each side publishes its counter with a release store, and reads the other's with an acquire load.
- **Tested** (`tests/src/ring_tests.kama`, the `command-ring` cases, 13 of them):
  - a fresh ring is empty at its declared capacity;
  - what is pushed comes out in order;
  - a full ring refuses a push and keeps what it holds;
  - the counters go a thousand times round a capacity of 3, in order;
  - both refusals;
  - the storage comes from an injected allocator exactly once, and goes back at the drop;
  - a staged item cannot be popped until it is published, then comes out in order;
  - what is staged counts against the capacity;
  - a push publishes what was staged before it;
  - its room counts what is staged and what is not popped, grows only as items are popped, and a stage it allows is
    taken;
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
- **`stageInto(ring:)`** is the same move, staged and not published, so the caller can stage more behind it and
  publish everything with one store. `flushInto` is `stageInto` and the ring's `publish()`.
- **`length()`** is how many it holds now, and **`capacity()`** the capacity it was made with.
- **Its two high-water marks:**
  - `highWater()` is the most it has held at once, which its declared capacity must allow;
  - `mostLeft()` is the most a flush has left behind, which says by how much the ring was too small.
- **Tested** (`tests/src/backlog_tests.kama`, the `backlog` cases, 11 of them):
  - a fresh backlog is empty at its declared capacity, with both marks at zero;
  - what is added reaches the ring only at a flush, in order;
  - a flush moves what the ring has room for, and what is left goes first on the next one, ahead of what was added
    since;
  - a full backlog refuses an add and keeps what it holds;
  - a flush into a full ring moves nothing and keeps the order;
  - a move stages what the ring has room for without publishing it, counts what it leaves behind, and what is left
    goes first on the next;
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

## The program's memory

### `audio::AudioMemory`

**The program's memory, handed over as a user pointer and three callbacks** (decision 36), as miniaudio, FMOD and Wwise
take theirs. It is a `type value` that implements kama's `Allocator`, so it is the allocator of every type in the
package, and no type names the program's allocator.
- **Making one:**
  - `AudioMemory.global()` is the global heap;
  - `AudioMemory.inArena(arena:)` is an std `Arena`, which must outlive every context made from it;
  - `AudioMemory.make(user:, allocate:, reallocate:, deallocate:)` is a program's own allocator: three free functions
    of the types `AllocateFn`, `ReallocateFn` and `DeallocateFn`, each handed `user` first, then `Allocator`'s own
    arguments.
- **Every byte the package allocates is drawn through it,** the context's state included: nothing is boxed, and
  nothing goes to the global heap behind the program's back. An allocation happens only at a make, on the program's
  side, never on the audio thread (decision 5).
- **Tested** (`tests/src/nodes_tests.kama`, the `nodes` cases):
  - the ready-made callbacks draw from the global heap, which keeps a block's bytes when it grows, and from an arena,
    which runs out where the heap would not, has room again after its reset, and grows a block in place;
  - nothing is drawn from the global heap behind the program's back. While a context is made from the program's own
    memory, and a node, a copy and their drops, every block the global heap gives is one the program's allocator asked
    for; `global()` gives back every byte it takes; and an arena's block, taken and given back, never reaches the heap.

  The tests program is itself a program with an allocator of its own, three free functions over a few counters. It
  also counts its global heap, its own choice through kama's `@globalAllocator` (`tests/src/heap.kama`, the blocks
  from the platform's allocator as kama's runtime takes them, `tests/csrc/heap.c`).

## Contexts and nodes

**A context is a resource, and every node made from it holds its state** (decision 4). The state lives until the
last of them is dropped, the context's own handle included.

### `audio::BaseAudioContext`

**A contract,** as Web Audio's `BaseAudioContext` is the base of its two contexts. kama's inheritance cannot carry
it: a derived type may add no public member, and each context adds its own. A node is made from any context through
it. Its members:
- `sampleRate()`, in Hz;
- `stateFor(key:)`, the state a node holds. Its key's type is in `audio::graph`, which no program can import, so only
  the package can call it.

### `audio::OfflineAudioContext`

- **Making one:** `OfflineAudioContext.make(options:)` returns `Result<OfflineAudioContext, AudioError>`.
  `OfflineAudioContextOptions.make(length:, sampleRate:)` holds Web Audio's options, then the package's:
  - `numberOfChannels`, 1 by default;
  - `length`, in sample frames;
  - `sampleRate`, in Hz;
  - `nodeCapacity`, the nodes it can hold at once, 1,024 by default: the rows of its slot table (decisions 6, 34);
  - `ringCapacity`, the commands that can cross to the audio side at once, 1,024 by default: its command ring
    (decision 7);
  - `backlogCapacity`, the commands that can wait for a flush, 4,096 by default: its backlog (decisions 8, 33);
  - `memory`, `AudioMemory.global()` by default.
- **What a make takes:** the slot table, the command ring, the backlog and the state, drawn from `options.memory` once
  each and in that order, four allocations. The state is one `Shared`, made by `try new(allocator:)`, that holds the
  other three. All go back with the last hold.
- **What a make answers instead** (`audio::AudioError`), with nothing left allocated:
  - `NotSupported` for an option outside Web Audio's ranges, as Web Audio's `NotSupportedError`: 1 to 32 channels, a
    length of at least one frame, a sample rate from 3,000 to 768,000 Hz. A node, ring or backlog capacity below one
    is the same;
  - `OutOfMemory` when the memory has no room for a part. Every part taken before it goes back.
- **What it answers:** `sampleRate()`, `length()` and `numberOfChannels()`, as it was made.
- **The test seam:** four `friend` grants to the tests program:
  - `audiotests::rowsHeldIn` reads its rows held;
  - `audiotests::releaseDueIn` takes its next release due straight from the table;
  - `audiotests::flushIn` flushes it;
  - `audiotests::sentIn` takes the next command from its ring, as the audio side would, as text.

### `audio::GainNode`

**The first node, and the pattern every node follows** (decisions 4, 34 and 35).
- **Making one:** `GainNode.make(context:)` takes a row in the context's table, adds its make to the context's
  backlog, and returns `Result<GainNode, AudioError>`. Making a node allocates nothing. It refuses, and nothing
  changes:
  - with the backlog full, as `TooManyCommands`. The backlog is checked first, before a row is taken;
  - with every row held, as `TooManyNodes`.
- **A counted resource,** `Copyable` with a bare hand-off that moves, as `@kama/gpu`'s handles are: `copy g` counts its
  row up, a `give` moves the handle without counting, and each drop counts it down.
- **The last drop marks the row,** and releases come out in the order the last drops were made. The row stays held
  until the audio side frees it, so a context whose rows are all held refuses a make even after a drop.
- **Tested** (the `nodes` cases, 11 of them, each seen red against a stub or a mutation first):
  - a context takes its table, its ring, its backlog and its state from the program's memory once, and making a node
    takes nothing; its state outlives the context's handle while a node holds it, and everything goes back at the last
    drop;
  - it answers the channels, length and sample rate it was made with;
  - each of Web Audio's ranges, and each capacity below one, refused as `NotSupported`, each bound made, and nothing
    allocated;
  - `OutOfMemory` at every budget short of the context, leaving nothing out, each part in turn the one refused;
  - a make takes a row, the first at slot 0, held after the last drop, its release due once;
  - a copy counts the row up, a give moves it, and the last drop releases it once;
  - releases in the order of the last drops;
  - a full table refuses a make, before and after a drop, and changes nothing;
  - a thousand copies and their drops balance;
  - and the memory's two cases above.

## The commands

**A call's command waits in the context's backlog, and a flush sends it into the ring the audio side reads**
(decisions 7, 8, 32, 33 and 35). The flush's public callers come with their rows: a real-time context's `update()`
(AUD-5) and an offline render's start (AUD-9).

- **A command is flat and typed:** `audio::graph::Command`, a kama enum whose variants carry only numbers. So it
  crosses a ring, or a transferred buffer, as its bytes, and the audio side applies each kind by name. It names its
  node by the row's id, never by a pointer (decision 34). Two kinds are built so far, each sent by a call that is:
  - `Made(node, kind)`, sent by a node's make. `NodeKind` names what to make, `Gain` so far;
  - `Release(node)`, sent for a node whose last handle was dropped (decision 35).

  Each later kind arrives with the call that sends it. `describe()` gives a command as text, `made gain 0:1` for a gain
  made at slot 0, generation 1. Tests read it that way, since they cannot import the internal module.
- **What a flush sends,** all published with one store (decision 33):
  - first, the backlog's commands, in the order the calls were made, as many as the ring has room for;
  - then, only once the backlog has drained, the due releases, in the order the last drops were made, while the ring
    has room.
- **So a release is never refused, and never overtakes a command naming its node.** Every such command was added
  before the node's last drop.
  - A release is taken from the table only when the ring has room, so a ring with no room keeps it due. The row stays
    marked, and the release goes on a later flush, once.
  - The drained backlog is checked, not inferred from the ring's room, because the audio side can free room on
    another thread between the move and the releases.
- **Tested** (`tests/src/commands_tests.kama`, the `commands` cases, 8 of them, each red against a stub first but the
  defaults', which the mutations prove):
  - the options declare a ring of 1,024 and a backlog of 4,096 by default, beside the table's 1,024 rows;
  - a make adds its command to the backlog, and only a flush sends it, once;
  - a flush sends the backlog's commands in the order the calls were made;
  - a copy's drop sends nothing, and releases follow the backlog in the order of the last drops;
  - a release waits behind the commands the backlog still holds;
  - a ring with no room keeps a release due, sent on a later flush once;
  - a full backlog refuses a make with `TooManyCommands`, and nothing changes;
  - with the backlog and the table full, the backlog answers first.

  The `nodes` cases cover the context's new parts: four allocations, each new capacity's range, every part in turn
  refused with what came before it given back, and nothing taken from the global heap behind the program's back.

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

### The program's memory, the contexts and the first node

Each of 40 mutations of `src/memory.kama`, `src/context.kama`, `src/gain.kama` and `src/graph/graph.kama` runs through the
whole gate (`.scratch/aud29/mutate_handle.py`), and each file is restored byte for byte after each. **39 of 40 turn a
case red, none by a hang.**
- **The first pass caught 37.** Two of its misses showed the tests blind to the global heap: `global()`'s deallocate
  giving nothing back, and an arena's blocks handed back to the global heap. The tests program now counts its global
  heap, and the case that reads it catches both.
- **The options' default `length` made 0 is equivalent,** and is dropped: the one constructor,
  `make(length:, sampleRate:)`, writes `length` before anything reads it.

### The commands

Each of 53 mutations of the ring's room and the backlog's move (`src/rt/ring.kama`), the commands, the flush, the
state's parts and a make that sends (`src/graph/graph.kama`), and the context's new options and seams
(`src/context.kama`) runs through the whole gate (`.scratch/aud29/mutate_commands.py`). Each file is restored byte for
byte after each, and a mutation kama refuses to compile would count as invalid, not caught. **52 of 53 turn a case red,
none by a hang.**
- **The defaults' case, green on its first run,** catches each default made one smaller: the nodes', the ring's and
  the backlog's.
- **The one missed is the flush sending releases while the backlog still holds commands.** On one thread it cannot be
  seen: the backlog stops moving only when the ring is full, so no release has room. The check matters only when the
  audio side pops on another thread between the move and the releases, which would let a release overtake its node's
  make. That is a race no deterministic case holds, so the check is held by review, as the ring's release store is.
