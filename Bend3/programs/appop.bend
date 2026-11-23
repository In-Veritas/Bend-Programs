# branchless: each comparison becomes a 0/1 U32 that selects its operand
# expect: 86

import Base

def appop(+o: U32, +a: U32, +b: U32) -> U32:
  (Bool.to_u32(U32.is_eq(o, 43)) * (a + b) +
   Bool.to_u32(U32.is_eq(o, 45)) * (a - b) +
   Bool.to_u32(U32.is_eq(o, 42)) * (a * b) +
   Bool.to_u32(U32.is_eq(o, 47)) * (a / (b + Bool.to_u32(U32.is_eq(b, 0)))) : U32)

def main() -> U32:
  (appop(42, 6, 7) + appop(43, 1, 1) + appop(47, 84, 2) : U32)
