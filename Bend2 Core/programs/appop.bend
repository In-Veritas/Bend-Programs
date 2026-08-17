import Base
# Arithmetic dispatch, ported from Bend3's appop example.
# Bend2 Core has no U32 infix surface, so dispatch and arithmetic use Base.

def appop(o: U32, a: U32, b: U32) -> U32:
  match U32.to_nat(o):
    case 42n:
      U32.mul(a, b)
    case 43n:
      U32.add(a, b)
    case 45n:
      U32.sub(a, b)
    case 47n:
      # Bend3 divides by b + (b == 0), so division by zero means / 1.
      match U32.copy(b):
        case ((b1, eb1), (b2, eb2)):
          match U32.is_zero(b1):
            case True{}:
              U32.div(a, U32.inc(b2))
            case False{}:
              U32.div(a, b2)
    case n:
      U32.zero()

def main() -> Bool:
  x = appop(U32.from_nat(42n), U32.from_nat(6n), U32.from_nat(7n))
  y = appop(U32.from_nat(43n), U32.one(), U32.one())
  z = appop(U32.from_nat(47n), U32.from_nat(84n), U32.from_nat(2n))
  safe = appop(U32.from_nat(47n), U32.from_nat(9n), U32.zero())
  Bool.and(
    U32.is_eq(U32.add(U32.add(x, y), z), U32.from_nat(86n)),
    U32.is_eq(safe, U32.from_nat(9n)))
