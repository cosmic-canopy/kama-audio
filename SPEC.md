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
A node's make, its connections and its release travel as commands: the backlog, then a flush into the ring. The audio
side applies them: an engine stepped a quantum at a time keeps each node at its id's slot in an array of its own, with
the connections between them, keeps a released node while a node that can sound feeds it, and frees it once nothing
does, reporting it on the way back, whose read gives the row back to the table. An offline context renders its length
as a request the program polls, advanced by `update()`, into an `AudioBuffer`. Each is tested natively and on wasm
under node, in debug and release. No node renders samples yet, so a render is silence. Not published.

## The modules

Decision 31 sets the first cut:

| Module | What it holds |
|---|---|
| `audio` | the lower tier, Web Audio's graph under Web Audio's names: `AudioMemory`, `BaseAudioContext`, `OfflineAudioContext`, `OfflineAudioContextOptions`, `AudioError`, `AudioNode`, `GainNode`, `AudioBuffer`, `RenderRequest`, `RenderStatus` |
| `audio::sound` | the upper tier: sounds, voices, buses, snapshots and emitters. Not made yet |
| `audio::rt` | the real-time primitives that the engine and a program's own DSP share: `Ring`, `Backlog`, `SlotTable`, `SlotArray`, `CapacityError`, `slotOf`, `generationOf` |
| `audio::store` | **internal**: `Slots`, the storage under every declared capacity, taken once from the allocator a part is handed and never grown. std's collections cannot serve, since each traps when its allocator has no room (KAMA_GAPS.md KAUD-7) |
| `audio::graph` | **internal**: what a context and its nodes share, `ContextState`, `NodeHold`, `NodeLink`, the commands (`Command` and `NodeKind`), `Connections` and `Samples`; and the audio side, `Engine`, `EngineNode`, the lifetime walk's `Mark` and the way back's `Event`. The package's own modules import it, and no program can |

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

## The slots

**A node's handle names its row in the program side's table, and only the row's id crosses to the audio side, never a
pointer** (decisions 4, 34 and 35). The audio side keeps the node at the id's slot in an array of its own. Each half is
built and tested on its own, before what uses it.

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

### `audio::rt::SlotArray<T, A>`

**The audio side's half** (decisions 4, 5 and 34): it holds a value of a `value` type `T` at the slot an id names, for
each node the program side's table names. The DAW and speech packages keep their own objects' audio-side state the same
way.
- **Making one:** `SlotArray::<T, A>.withCapacity(capacity:)` and `withCapacityAndAllocator(allocator:, capacity:)`,
  each returning `Result<SlotArray<T, A>, CapacityError>`, with the table's refusals: below one, or above 2^32 before
  the allocator is asked, is `BadCapacity`. Its storage is taken as the ring's is, once, never grown and given back at
  the drop. Each slot holds its value and the generation it was put at, and nothing is allocated per value, so the
  audio thread never allocates (decision 5).
- **`put(id:, value:)`** puts `value` at the id's slot, at the id's generation, only into an empty slot. It answers
  `false`, changing nothing, when the slot holds a value at any generation.
- **`at(id:)`** answers the value when the slot holds one at the id's generation, and otherwise `None`.
- **`set(id:, value:)`** replaces the value when the slot holds one at the id's generation, and otherwise answers
  `false`, changing nothing.
- **`remove(id:)`** empties the slot when it holds a value at the id's generation, and otherwise answers `false`.
- **`idAt(slot:)`** answers the id of the value a slot holds, its slot and the generation the value was put at, or 0
  for an empty slot or one that is not the array's. A walk over the slots visits every value this way.
- **So a command naming a node the audio side no longer holds never reaches the node now in its slot.** An id of any
  other generation is refused, as is a slot past the array, generation 0 (which marks an empty slot, and no live id
  has) and −1. Every refusal is an answer, never a trap.
- **What it answers:** `length()`, the slots holding a value, and `capacity()`, the slots it was made with.
- **Tested** (`tests/src/slot_array_tests.kama`, the `slot array` cases, 14 of them, each seen red against a stub first
  but the no-room case, which the mutations prove):
  - a fresh array is empty at its declared capacity;
  - both refusals, and more slots than 32 bits can name refused as `BadCapacity` before the allocator is asked;
  - the storage comes from an injected allocator exactly once, at least 16 bytes a slot for an `int64`, and goes back
    at the drop; an allocator with no room is `OutOfMemory`;
  - a value put at an id is read back there and only there, and every slot can hold one at once;
  - a held slot refuses a put at its own generation or another, and keeps what it holds;
  - a read and a removal name the generation the value was put at, up to the last a 32-bit field holds; a removed slot
    holds nothing, refuses a second removal, and takes a put again at the next generation, which the earlier
    generation's id cannot reach;
  - an id past the array, of generation 0, or −1 is refused by every call, with slot 0 held, since the storage's index
    would wrap the slot just past the array onto it;
  - a set replaces the value at the generation it was put at, and only there: another generation, an empty slot and a
    stranger are refused, changing nothing;
  - each slot names the id it holds a value at, or 0, and a slot past the array or below 0 names 0, with slot 0 held,
    onto which the storage's index would wrap slots 3 and −3 of an array of 3.

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
  - `connectionCapacity`, the connections between its nodes at once, 4,096 by default, four for each node row
    (decision 6);
  - `framesPerUpdate`, the frames an `update()` renders at least, in whole quanta, 8,192 by default (decision 37);
  - `memory`, `AudioMemory.global()` by default.
- **What a make takes:** fourteen parts, drawn from `options.memory` once each and in this order: the slot table, the
  command ring, the backlog, the way back, the program side's connections (the connections and a list head for each
  node row, two allocations), the audio side (its array of nodes, its connections, two allocations, the lifetime
  walk's marks, and its block, a quantum for each channel), the render's output (its samples and the box that counts
  them), then the state. The way back, the array, the list heads and the marks each have `nodeCapacity` places. The
  state is one `Shared`, made by `try new(allocator:)`, that holds the rest. All go back with the last hold, but the
  output's, which an `AudioBuffer` may still hold.
- **What a make answers instead** (`audio::AudioError`), with nothing left allocated:
  - `NotSupported` for an option outside Web Audio's ranges, as Web Audio's `NotSupportedError`: 1 to 32 channels, a
    length of at least one frame, a sample rate from 3,000 to 768,000 Hz. A node, ring, backlog or connection capacity
    below one is the same, and so is a `framesPerUpdate` below one;
  - `OutOfMemory` when the memory has no room for a part. Every part taken before it goes back. A capacity whose
    bytes no `usize` can hold, and an output whose samples no `isize` can count, are `OutOfMemory` too, before the
    allocator is asked: never a size that overflowed.
- **What it answers:** `sampleRate()`, `length()` and `numberOfChannels()`, as it was made.
- **Its render:** `startRendering()` and `update()` (§ The offline render).
- **The test seam:** eleven `friend` grants to the tests program:
  - `audiotests::rowsHeldIn` reads its rows held;
  - `audiotests::releaseDueIn` takes its next release due straight from the table;
  - `audiotests::flushIn` flushes it;
  - `audiotests::sentIn` takes the next command from its ring, as the audio side would, as text;
  - `audiotests::quantumIn` renders one quantum on its audio side;
  - `audiotests::pollIn` reads its way back;
  - `audiotests::audioHeldIn` reads the nodes its audio side holds, and `audiotests::refusedIn` the commands it refused;
  - `audiotests::forgeIn` adds a command no call would send, a make or a release of any id, to its backlog, and
    `audiotests::forgeConnectIn` a connection between any ids;
  - `audiotests::markIn` writes a value into its render's output at a channel and frame in range, where silence could
    not show a render's overrun or a read of the wrong channel or frame.

### `audio::GainNode`

**The first node, and the pattern every node follows** (decisions 4, 34 and 35). It implements `AudioNode`.
- **Making one:** `GainNode.make(context:)` takes a row in the context's table, adds its make to the context's
  backlog, and returns `Result<GainNode, AudioError>`. Making a node allocates nothing. It refuses, and nothing
  changes:
  - with the backlog full, as `TooManyCommands`. The backlog is checked first, before a row is taken;
  - with every row held, as `TooManyNodes`.
- **A counted resource,** `Copyable` with a bare hand-off that moves, as `@kama/gpu`'s handles are: `copy g` counts its
  row up, a `give` moves the handle without counting, and each drop counts it down.
- **The last drop marks the row,** and releases come out in the order the last drops were made. The row stays held
  until the program side reads the audio side's report that the node is freed, so a context whose rows are all held
  refuses a make even after a drop.
- **Tested** (the `nodes` cases, 11 of them, each seen red against a stub or a mutation first):
  - a context takes its eleven parts from the program's memory once, and making a node takes nothing; its state
    outlives the context's handle while a node holds it, and everything goes back at the last drop;
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

  The `nodes` cases cover the context's new parts: their allocations, each new capacity's range, every part in turn
  refused with what came before it given back, and nothing taken from the global heap behind the program's back.

## The audio side and the way back

**A render quantum applies what the flushes published before it, and the audio side reports on the way back what the
program side must act on** (decisions 4, 5, 9, 32, 34 and 35). Its public callers come with their rows: a real-time
context's device (AUD-11) and an offline render (AUD-9). An offline context's audio side runs on the program's thread,
so a quantum is a call.
- **The engine,** `audio::graph::Engine`, keeps each node it is told of in its own `SlotArray` of `EngineNode`s, of the
  context's node capacity, and the connections between them in `Connections` of its own. It owns only those and the
  lifetime walk's marks. Each quantum it is handed the command ring and the way back, so the same engine runs on a
  real-time context's audio thread or an offline render's.
- **A quantum** drains the command ring at its top and applies every command published before it, in order, then
  publishes the reports it made on the way back with one store:
  - `Made` puts the node at its id's slot;
  - `Connect` adds the connection;
  - `Release` marks the node released, and makes the lifetime walk due (§ Connections).
- **A command it cannot apply is refused and counted,** never applied to another node and never a trap: a make into a
  slot that holds a node; a connection naming a node it does not hold at that generation, one it holds already, or one
  past its declared connections; and a release of a node it does not hold at that generation, or has released. No
  call can send one, so each would be the package's bug, and the count is how it is seen.
- **The way back** is a `Ring` of `audio::graph::Event`, so far one kind, `Freed(node)`. Each later kind arrives with
  what sends it (decision 9): a sound's end, an error, a block handed back. **It always has room for a report:** its
  capacity is the node capacity, and a slot is reported freed at most once before the program side reads the report,
  since only that read lets the slot be taken again. A refused command reports nothing, so it takes no report's room.
- **The program side's read,** `ContextState.poll()`, takes each report in the order the audio side made them, and a
  node freed gives its row back to the table at the next generation. Its public caller is `update()` (AUD-5). Until the
  read, the row stays held, so a context whose rows are all released refuses a make.
- **Tested** (`tests/src/audio_side_tests.kama`, the `audio side` cases, 9 of them, each seen red against a stub first,
  or, for the last two, against the mutation each was written for):
  - a quantum applies what a flush published before it, each command once, and nothing still in the backlog; the ring
    it empties takes the next flush;
  - a gain released is freed at once, its report read only after the quantum, and its row back only after the read;
  - a node released in a later quantum is freed in that quantum;
  - a copy's drop sends nothing, and the audio side keeps the node;
  - every row released in one quantum is reported, the way back holding a report for each, and every row comes back;
  - a freed slot's next node takes the next generation, and a release of the earlier one is refused and cannot reach it;
  - a release of a node never made, a release at a later generation and a make into a held slot are each refused and
    counted, and change nothing;
  - a refused release reports nothing, so with one row the node's own report still fits beside it;
  - the way back holds a report for every row whatever the command ring's size: with a ring of 1, four releases in four
    quanta wait, unread, until one read frees all four rows.

  The `nodes` cases cover the state's two new parts, six allocations in all, each in turn refused with what came before
  it given back.

## Connections

**A node's output connected to another node's input, and the lifetime rule it brings** (decisions 3, 4, 6, 8 and 34;
Web Audio's `connect(destinationNode)`).

### `audio::AudioNode`

**A contract every node implements,** as Web Audio's `AudioNode` is the base of every node. kama's inheritance cannot
carry it, since a derived type may add no public member and each node adds its own. Its members:
- `connect(destination:)`, which takes any node;
- `linkFor(key:)`, the node's context and id. Its key's type is in `audio::graph`, so only the package can call it.

### `connect(destination:)`

- **It connects the node's output to `destination`'s input,** as Web Audio's `connect(destinationNode)` does with its
  `output` and `input` both 0. kama has no default arguments, and every node so far has one input and one output, so
  the form that names them comes with the first node that has more.
- **It answers `Result<Unit, AudioError>`** where Web Audio returns the destination: a refusal is an answer, never a
  trap, so there is no chaining.
- **It is recorded on the program side, and its command added to the backlog;** a flush sends it, and the audio side
  adds the connection in the quantum it lands in (decision 32).
- **A connection made twice is one,** and the second connect is taken and sends nothing, as Web Audio ignores "multiple
  connections with the same termini". The reverse is another connection, and a node may connect to itself, or into a
  cycle. The render will mute a cycle with no delay in it, as Web Audio's rendering algorithm does.
- **What it refuses, changing nothing,** checked in this order:
  - a node of another context, as `InvalidAccess`, Web Audio's `InvalidAccessError`. Contexts are told apart by their
    state's address;
  - a full backlog, as `TooManyCommands` (decision 8);
  - every declared connection held, as `TooManyConnections` (decision 6). A connection already held is taken even then,
    since it adds none.

### The connections on each side

`audio::graph::Connections` is a fixed pool of `connectionCapacity` connections, with a list of each node slot's
outputs, drawn from the program's memory at the make. Each side holds one:
- **the program side's** answers at the call whether a connection is held already and whether a declared one is free.
  A freed node takes its connections with it when the way back is read, so they come back then;
- **the audio side's** is what the lifetime walk follows, and a node it frees takes its connections with it at once.

**A slot's list is the connections of the node in it, and they leave with it.** Only outputs are listed, and a
connection records only its destination's id. Freeing a node takes its slot's whole list out before the slot can be
taken again, and a node is freed only once nothing that can sound feeds it, so every node connected into it is freed in
the same walk and takes its own list out. Every caller names a node it holds.

### The lifetime rule

**The audio side keeps a released node while a node that can sound feeds it, through any chain of connections**
(decision 4; Web Audio's normative "actively processing" and its non-normative dynamic lifetime, where a node is
deleted once nothing references it and then disconnects its outputs).
- **What can sound, of itself:** so far, a node the program holds. A playing source and a tail still ringing join it
  when they come.
- **A node's own outputs keep nothing alive,** so a released node feeding a held one is freed at once.
- **A released cycle that nothing feeds is freed whole,** though each of its nodes feeds another. A count of live
  inputs alone would keep it forever, which is why the rule is a walk.
- **The walk:** in a quantum that applied a release, the engine marks every node reached along the outputs from the
  nodes that can sound, with an explicit stack in its marks' storage, so it neither recurses nor allocates; then it
  frees every released node it did not reach, taking its connections out and reporting it on the way back. A quantum
  that releases nothing does not walk.
- **What it costs:** a pass over the slots and the connections. At 1,024 nodes and 4,096 connections a walk took 5.0 µs
  natively on the M4 and 6.6 µs on wasm under node, a quarter of a percent of a 128-frame quantum at 48 kHz; at 4,096
  nodes and 16,384 connections, 42 µs and 55 µs (`.scratch/aud1-mark/`, release builds, 2026-11-18, load average 4 to
  7).
- **Tested** (`tests/src/connect_tests.kama`, the `connect` cases, 16 of them, each seen red against a stub first, or,
  for the last two, against the mutations they were written for):
  - the options declare 4,096 connections by default;
  - a connect adds its command behind the makes, and only a flush sends it;
  - a connection made twice is one, also when repeated after a later connection from the same node, and the reverse
    and a node's loop to itself are others;
  - a node of another context is refused as `InvalidAccess`, both ways, and nothing is sent in either context;
  - with every declared connection held, a new one is `TooManyConnections` and a held one taken;
  - a full backlog is `TooManyCommands`, checked first, and the refusal takes no connection; with the backlog and the
    connections full at once, the backlog answers, and once a flush empties it, the connections do;
  - a released node fed by a held one is kept, and freed with its feeder;
  - a chain of released nodes is kept while its head is held, and freed whole after it;
  - a node's own outputs keep nothing alive;
  - a released cycle nothing feeds is freed whole, and one fed by a held node is kept, then freed whole with its
    feeder;
  - a released node connected only to itself is freed;
  - a freed node's connections go with it on both sides: the program side counts them until the way back is read, and
    the audio side has room for the next;
  - the audio side refuses and counts a connection naming a node at another generation, one it holds while it has room
    for more, and one past its declared, keeping what it holds, and a second release of a node it has released and
    still keeps;
  - a held node feeding two released nodes keeps both, and every declared connection comes back on both sides once all
    three are freed;
  - a freed node's slot, taken again, starts with no connections.

  The `nodes` cases cover the context's eleven parts, each in turn refused with what came before it given back, and a
  connection capacity's range.

## The offline render

**An offline render is a request the program polls, advanced by `update()`** (decision 37, with decisions 6, 9, 10 and
32), as `@kama/gpu`'s requests are polled: kama has no promises, and the package starts no thread.
- **`OfflineAudioContext.startRendering()`** starts the render and renders nothing. It answers
  `Result<RenderRequest, AudioError>`; a second start is `InvalidState`, Web Audio's `InvalidStateError`.
- **`OfflineAudioContext.update()`,** the program's call once a frame:
  - flushes the calls made since the last one (decision 33);
  - once the render has started, renders whole quanta on the calling thread, each applying the commands that landed
    (decision 32) and copied into the output, until this update has rendered at least `framesPerUpdate` frames or the
    end. The last quantum stops at the length. Before the start it renders nothing, and the flushed commands wait in
    the ring for the render's first quantum;
  - reads the way back (decision 9).
- **`RenderRequest.poll()`** answers `RenderStatus`: `Pending(framesRendered)`, or `Ready(buffer)` with the
  `AudioBuffer`, again at every poll after.
- **What the render makes:** each quantum is rendered into the engine's block, a quantum for each channel, then copied
  into the output. No node renders samples yet, so it is silence, written: the tests' allocator poisons every block
  it hands out. A quantum is Web Audio's 128 frames until the engine's declared block (decision 15, AUD-9).
- **Suspending at a frame** (Web Audio's `suspend()` and `resume()`) comes in a step of its own.

### `audio::AudioBuffer`

**Web Audio's `AudioBuffer`:** samples in channels of a length at a sample rate.
- **A counted resource** (decision 4), `Copyable` with a bare hand-off that moves. `copy b` shares its samples,
  channel-planar `float32` drawn from the program's memory, and they go back at its last drop. It outlives the context
  that made it.
- **So far a render makes one,** its output. A buffer the program makes to be played, and how its samples count
  against decision 6's sample memory, come with the source that plays it.
- **What it answers:** `sampleRate()`, in Hz; `length()`, the frames each channel holds; `duration()`, in seconds, a
  `float64`; and `numberOfChannels()`.
- **`copyFromChannel(destination:, channelNumber:, bufferOffset:)`** is Web Audio's: it copies as many frames as fit
  from `bufferOffset` into `destination`, a `View<float32>`, and leaves the rest of it untouched. An offset at or past
  the end copies nothing. A channel the buffer does not have is `IndexSize`, Web Audio's `IndexSizeError`, and so is an
  offset below 0, which Web Audio's unsigned argument cannot be. kama has no default arguments, so the offset is always
  named.
- **Tested** (`tests/src/render_tests.kama`, the `render` cases, 12 of them, each seen red against a stub first but the
  start's, which the mutations prove, or, for the last three, against the mutations they were written for):
  - the options declare 8,192 frames an update by default;
  - a start renders nothing, and the request is pending at 0;
  - updates before the start render nothing; after it, each update renders whole quanta up to its declared frames, and
    the last stops at the length: 1,000 frames at 256 an update are pending at 256, 512 and 768, then ready;
  - 200 frames an update render two quanta;
  - the ready buffer holds the context's channels, length and rate, its duration their quotient, and every sample of
    every channel is silence; it answers again at the next poll, and an update after the end renders nothing;
  - a second start is `InvalidState`, and the first request still renders;
  - an update flushes, renders and reads the way back: a make before the start is applied, and a drop is freed and its
    row back after the next update;
  - `copyFromChannel` copies what fits from its offset, leaves the rest untouched, copies nothing from the end, and
    refuses channel 2 of 2, channel −1 and frame −1 as `IndexSize`, writing nothing. Each channel's last frames are
    marked apart first, so a copy from the wrong channel or frame shows;
  - the buffer outlives its context and request: its two blocks are all that is still out, a copy keeps them out after
    the original's drop and reads as before, and they go back at its last drop;
  - the last quantum stops at the length: a mark at each channel's frame 0, where channel 0's overrun and the last
    channel's wrapped overrun would land, is still there when the render is ready;
  - with less than a quantum left the render is still pending: 300 frames at 128 an update are pending at 256;
  - each channel adds a quantum to the engine's block and its length to the output: two channels of 1,000 frames take
    4,512 bytes more than one.

  The `nodes` cases cover the fourteen parts, a `framesPerUpdate` below one, and an output of 32 channels of 2^62
  frames, `OutOfMemory`. A `command-ring` case covers a capacity whose bytes no `usize` can hold.

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

### The slot array, the audio side and the way back

Each of 52 mutations of the slot array (`src/rt/ring.kama`), the engine (`src/graph/engine.kama`), the way back's read
and the state's new parts (`src/graph/graph.kama`) and the context's new seams (`src/context.kama`) runs through the
whole gate (`.scratch/aud29/mutate_audio_side.py`), and each file is restored byte for byte after each. **All 52 turn a
case red, none by a hang, and kama refuses none.**
- **The first pass caught 49 of 51.** Each of the two it missed showed a case too loose, and the case was sharpened:
  - **the slot array's read and removal naming a slot past the array:** the storage's index wraps it onto slot 0, and
    the strangers' case held nothing there. It now holds a value at slot 0 throughout;
  - **the way back sized by the command ring's capacity, not the node capacity:** every case had a ring at least as
    large as its rows. A ring of 1 with four rows now sends four releases in four quanta, all unread until the end.
- **The no-room case,** green against the stub, catches the array's no room answered as `BadCapacity`, added for it.
- **A refused release reported all the same** was the one mutation a case was written for before the pass: the program
  side's table refuses a stale report, so only a report's room shows it, with one row.

### Connections and the lifetime rule

Each of 81 mutations of the connections (`src/graph/connections.kama`), the engine's connections and its lifetime walk
(`src/graph/engine.kama`), connect on the program side and the state's new parts (`src/graph/graph.kama`), the option
and the seam (`src/context.kama`), the contract's members (`src/gain.kama`) and the slot array's `set` and `idAt`
(`src/rt/ring.kama`) runs through the whole gate (`.scratch/aud29/mutate_connect.py`), and each file is restored byte
for byte after each. **78 turn a case red, 4 of them by a hang, and kama refuses none; the other 3 are equivalent.**
- **The first pass caught 66 of 82.** Eleven of its misses showed a case too loose, and the case was sharpened, or
  written:
  - **`idAt` past the array or below 0:** the storage's index wraps slots 3 and −3 of an array of 3 onto slot 0, which
    the case held nothing at;
  - **the connections' free chain one short, a new connection not joined to its node's list, `has()` looking at the
    first connection only, the walk following one output only, and `removeFrom` taking the first only:** no node had two
    outputs, and no pool of more than one was filled. A fan-out case, with two declared connections, now holds a feeder
    and two nodes it keeps, then two new connections once all three are freed; and a duplicate is repeated after a
    later connection from the same node;
  - **`removeFrom` leaving a slot's head on a connection it gave back:** no case reused a freed node's slot and connected
    from it. A case now does, and the mutation loops the list on itself;
  - **the engine adding a duplicate, and taking a second release:** the case forged its duplicate only into a full pool,
    and no case released a released node. It now forges each while it would be taken;
  - **the two limits checked in the other order:** no case had the backlog and the connections full at once.
- **Two showed code that could not matter:** a connection's source, checked by `has()` and `removeFrom`, is always the
  node in its slot, since a slot's list leaves with its node before the slot is taken again. The field is gone, and a
  freed node's slot gives back its whole list.
- **Three are equivalent, and dropped:**
  - **`firstOut` without its range guard:** every caller names the slot of a node it holds. The guard stays, for a
    caller that someday does not;
  - **the walk in every quantum, and its flag never cleared:** without a release no node stops being able to sound, and a
    connection only adds reach, so an extra walk frees nothing. The flag saves its cost, which the gate does not
    measure.

### The offline render's first slice

Each of 55 mutations of the option, the start and `update()` (`src/context.kama`), the render in `update()`, the
output part and the marking seam (`src/graph/graph.kama`), the engine's block (`src/graph/engine.kama`), the samples
(`src/graph/samples.kama`), the buffer (`src/buffer.kama`) and the request (`src/render.kama`) runs through the whole
gate (`.scratch/aud29/mutate_render.py`), and each file is restored byte for byte after each. **54 turn a case red, 1 of
them by a hang, and kama refuses none; the 55th waits for a node that renders.**
- **The first pass caught 45 of 54.** Silence hid most of its misses: a render of zeros cannot show an overrun of zeros,
  a channel read for another, or a copy from the wrong frame. Seven were caught once the cases were sharpened:
  - **the last quantum written whole, past the length:** a mark at each channel's frame 0, where the overrun lands, now
    shows it, through a seam that marks the output;
  - **done a quantum early:** no case looked at a render with less than a quantum left;
  - **the engine's block, and the output, sized for one channel:** each read of channel 1 wrapped onto channel 0. Two
    contexts that differ only in their channels now differ in bytes by a quantum of block and a length of output;
  - **`Samples.at` and `copyFromChannel` reading channel 0, and the copy from frame 0:** the copy case marks each
    channel's last frames apart first.
- **`renderDone` checking that the render had started** was equivalent, since frames are rendered only after a start and
  a length is at least one. The check is gone.
- **`blockAt` reading channel 0 for every channel** is not equivalent, and no case can see it yet: only the engine
  writes its block, and it writes silence. The first node that renders different samples into different channels
  brings the case that catches it.
