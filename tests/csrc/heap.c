// The tests program's global heap, under its counting pool (tests/src/heap.kama): the platform's allocator, taken as
// kama's runtime takes it by default (include/kama_runtime.h, the allocation funnel), so the pool changes nothing but
// the counts. Above the fundamental alignment a block comes from the platform's aligned allocator and goes back to its
// own release.
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include "heap.h"

void* audiotests_heap_allocate(size_t n, size_t align) {
    if (align <= _Alignof(max_align_t)) return malloc(n);
#if defined(_WIN32)
    return _aligned_malloc(n, align);
#else
    return aligned_alloc(align, (n + align - 1) & ~(align - 1));
#endif
}

void audiotests_heap_deallocate(void* p, size_t n, size_t align) {
    (void)n;
#if defined(_WIN32)
    if (align > _Alignof(max_align_t)) { _aligned_free(p); return; }
#else
    (void)align;
#endif
    free(p);
}

void* audiotests_heap_reallocate(void* p, size_t n, size_t newN, size_t align) {
    if (align <= _Alignof(max_align_t)) return realloc(p, newN);
#if defined(_WIN32)
    (void)n;
    return _aligned_realloc(p, newN, align);
#else
    void* q = audiotests_heap_allocate(newN, align);
    if (!q) return NULL;
    memcpy(q, p, n < newN ? n : newN);
    audiotests_heap_deallocate(p, n, align);
    return q;
#endif
}
