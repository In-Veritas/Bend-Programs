# Pure smoke probe for web_belote.bend: `bend probe.bend` must print 1
# (five then eight cards per seat, all 32 cards dealt once, trump points).
import Base
import ./web_belote.bend as Belote

def main() -> U32:
  Belote.test()
