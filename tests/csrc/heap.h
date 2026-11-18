#ifndef AUDIOTESTS_HEAP_H
#define AUDIOTESTS_HEAP_H
#include <stddef.h>
void* audiotests_heap_allocate(size_t n, size_t align);
void* audiotests_heap_reallocate(void* p, size_t n, size_t newN, size_t align);
void  audiotests_heap_deallocate(void* p, size_t n, size_t align);
#endif
