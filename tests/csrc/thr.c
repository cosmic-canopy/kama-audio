#include "thr.h"
static thr_cb g_cb;
static void *g_user;
static int32_t g_done;
static void body(void) {
    while (g_cb(g_user)) {}
    __atomic_store_n(&g_done, 1, __ATOMIC_RELEASE);
}
#ifdef __EMSCRIPTEN__
#include <emscripten/wasm_worker.h>
#include <emscripten/emscripten.h>
int64_t thr_now_ns(void) { return (int64_t)(emscripten_get_now() * 1e6); }
static emscripten_wasm_worker_t g_w;
int32_t thr_start(thr_cb cb, void *user) {
    g_cb = cb; g_user = user;
    __atomic_store_n(&g_done, 0, __ATOMIC_RELEASE);
    g_w = emscripten_malloc_wasm_worker(64 * 1024);
    if (g_w <= 0) return 1;
    emscripten_wasm_worker_post_function_v(g_w, body);
    return 0;
}
/* The worker is ended once its loop is done: a live one would keep node running after main returns. */
void thr_join(void) {
    while (!__atomic_load_n(&g_done, __ATOMIC_ACQUIRE)) {}
    emscripten_terminate_wasm_worker(g_w);
}
#else
#include <pthread.h>
#include <time.h>
int64_t thr_now_ns(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return (int64_t)t.tv_sec * 1000000000 + t.tv_nsec; }
static pthread_t g_t;
static void *run(void *p) { (void)p; body(); return 0; }
int32_t thr_start(thr_cb cb, void *user) {
    g_cb = cb; g_user = user;
    __atomic_store_n(&g_done, 0, __ATOMIC_RELEASE);
    return pthread_create(&g_t, 0, run, 0);
}
void thr_join(void) { pthread_join(g_t, 0); }
#endif
