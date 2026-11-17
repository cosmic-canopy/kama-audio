# Changelog

All notable changes to `@kama/audio`. The format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
