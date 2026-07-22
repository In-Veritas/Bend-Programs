# Clock: the shared monotonic millisecond clock for realtime demos.

import IO

def clock_now_ms() -> IO<U32>:
  import ./effs/now_ms.c
