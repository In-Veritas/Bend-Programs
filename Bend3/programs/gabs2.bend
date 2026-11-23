# expect: 5

import Base

def sum(x: U32, y: U32) -> U32:
  (x + y : U32)

def main() -> U32:
  sum(2, 3)
