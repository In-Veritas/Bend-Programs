import Base

# Compatibility for small Nat projections pruned from the upstream Base
# library. Programs import this file as Nat.

assert mod:
  forall dividend: Nat
  forall divisor: Nat
  Nat

def mod(dividend, divisor):
  (quotient, remainder) = Nat.divmod(dividend, divisor)
  remainder

assert is_eq:
  forall left: Nat
  forall right: Nat
  Bool

def is_eq(left, right):
  Cmp.is_eq(Nat.cmp(left, right))
