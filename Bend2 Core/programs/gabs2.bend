import Base
# Minimal addition, ported from Bend3. The Bool result checks that 2 + 3 = 5.

def sum(x: U32, y: U32) -> U32:
  U32.add(x, y)

def main() -> Bool:
  U32.is_eq(sum(2, 3), 5)
