# Smoke probe for web_poker.bend: `bend probe.bend` must print 1. main is
# IO so the probe runs compiled (checker normalization of a whole AI-played
# deal is far too slow)
# (deal, distinct personas, royal/pair/wheel scores, Omaha two-plus-three vs Texas best five).
import Base
import ./web_poker.bend as Poker

def main() -> IO(Unit):
  IO.print(U32.show(Poker.test()))
