# Clock: the shared monotonic millisecond clock for realtime demos.

import ../bend-base/Base

def clock_now_ms() -> IO(U32):
  IO.now_ms()
