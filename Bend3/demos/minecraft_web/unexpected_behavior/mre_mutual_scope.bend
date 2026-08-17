# Reachable mutual-recursion termination reproduction. Current Bend3 resolves
# both definitions in default mode but accepts this nonterminating cycle.

def u32_first(x: U32) -> U32:
  u32_second(x)

def u32_second(x: U32) -> U32:
  u32_first(x)

def main() -> U32:
  u32_first(0)
