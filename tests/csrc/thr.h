#pragma once
#include <stdint.h>
/* A second thread for the tests: calls cb(user) in a loop until it returns 0. A pthread natively, a Wasm Worker on
   wasm, as the audio thread is on each leg. One at a time. */
typedef int32_t (*thr_cb)(void *user);
int32_t thr_start(thr_cb cb, void *user);
void thr_join(void);        /* waits for the loop to end; its writes are visible after it (acquire) */
int64_t thr_now_ns(void);  /* the monotonic clock, for a case's deadline */
