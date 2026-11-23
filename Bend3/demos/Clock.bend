# Clock: the shared monotonic millisecond clock for realtime demos,
# ported to Bend 2.0.40. Import it from a demo folder as:
#
#   import ../Clock.bend as Clock
#
# and call `now : U32 <- Clock.now_ms()` (old: clock_now_ms()).
# Base's IO.now() answers monotonic milliseconds as a Nat; this wraps it
# to U32 (it wraps after ~49 days of uptime, so compare with
# differences, `(now - then : U32)`, never absolute values).
import Base

def now_ms() -> IO(U32):
  IO.bind(Nat, U32, IO.now(), n => IO.pure(U32, U32.from_nat(n)))

# Same as now_ms, under the old name.
def clock_now_ms() -> IO(U32):
  now_ms()
