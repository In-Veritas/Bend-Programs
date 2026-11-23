import Base

# Compatibility for small Nat projections that the old bend2-core Base lacked.
# Programs import this file as Nat.
# Ported to the latest Bend (bendlang/bend): `assert`+`def` pairs became typed defs.

def mod(dividend: Nat, divisor: Nat) -> Nat:
  Nat.mod(dividend, divisor)

def is_eq(left: Nat, right: Nat) -> Bool:
  Nat.is_eq(left, right)
