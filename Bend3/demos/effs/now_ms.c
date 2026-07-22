// clock_now_ms() -> IO<U32>
// Deliver monotonic milliseconds. U32 subtraction handles the wraparound.
static Term io_clock_now_ms(State st) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  u64 ms = (u64)ts.tv_sec * 1000ULL + (u64)ts.tv_nsec / 1000000ULL;
  return W32((u32)ms);
}
