import Base
# Arithmetic dispatch, ported from Bend3's appop example. The operator is an
# ASCII code ('*' 42, '+' 43, '-' 45, '/' 47); dispatch matches its Nat value
# in a helper, because Bend matches only parameters, never computed values.

def appop.div(a: U32, +b: U32, z: Bool) -> U32:
  # Bend3 divides by b + (b == 0), so division by zero means / 1.
  match z:
    case True{}:
      U32.div(a, U32.inc(b))
    case False{}:
      U32.div(a, b)

def appop.go(o: Nat, a: U32, +b: U32) -> U32:
  match o:
    case 42n:
      U32.mul(a, b)
    case 43n:
      U32.add(a, b)
    case 45n:
      U32.sub(a, b)
    case 47n:
      appop.div(a, b, U32.is_zero(b))
    case n:
      0

def appop(o: U32, a: U32, b: U32) -> U32:
  appop.go(U32.to_nat(o), a, b)

def main() -> Bool:
  x = appop(42, 6, 7)
  y = appop(43, 1, 1)
  z = appop(47, 84, 2)
  safe = appop(47, 9, 0)
  Bool.and(
    U32.is_eq(U32.add(U32.add(x, y), z), 86),
    U32.is_eq(safe, 9))
