# @kama/audio roadmap

**The order of work, and nothing else.** One row per item: what it is, and a link to its reasoning in
[AGENTS.audio.md](AGENTS.audio.md) § Decided. Its history is in the git log.

> **`AUD-<n>` is a permanent id, not a position.** It is assigned once, from the counter below, which the same edit
> bumps. It is never reused or renumbered, and a shipped row's id retires with it.

**Next id: AUD-7**

## NOW: the design pass

Areas 3 to 5 of [AGENTS.audio.md](AGENTS.audio.md#the-design-pass-what-is-open). Nothing is built before the
decisions it depends on are recorded. Area 5 puts the rows below in order, by example.

## LATER: what area 2 decided, unordered until area 5

| id | item | why |
|---|---|---|
| AUD-1 | **The command protocol**: flat, typed commands stamped with an int64 frame, on one ordered ring per context. The ring in shared memory, and one transferred `ArrayBuffer` per flush where the page cannot be isolated. The backlog, bounded by its capacity, with an error to the caller past it. Late commands counted. Replay of a recorded stream offline | [decisions 7, 8](AGENTS.audio.md#decided) |
| AUD-2 | **Nodes and buffers as counted resources over a slot table with generations**: the program's side picks slots. Web Audio's lifetime rule on the audio side. `close()`, after which a call is a reported error | [decision 4](AGENTS.audio.md#decided) |
| AUD-3 | **The way back**: an event ring sized from the slot capacity (a sound's end, a slot freed, an error, a block handed back), and snapshots of meters and the playhead, all read in `update()` | [decision 9](AGENTS.audio.md#decided) |
| AUD-4 | **The context's options and its memory**: every capacity declared, an injected `Allocator` (the global heap by default), everything the audio side uses allocated and freed on the program's side, and a declared answer at every limit | [decisions 5, 6](AGENTS.audio.md#decided) |
| AUD-5 | **`update()`**: the upper tier's home on the program's thread. It polls the way back and turns the upper tier's decisions into stamped lower-tier commands | [decision 10](AGENTS.audio.md#decided) |
| AUD-6 | **`AudioWorkletProcessor` as a contract**: a `@noheap` `process`, a render callback typed `@noheap @noparks`, processors built and dropped on the program's side, and the web's quantum natively behind a FIFO | [decision 11](AGENTS.audio.md#decided) |
