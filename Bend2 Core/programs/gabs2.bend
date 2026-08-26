import Base
# Minimal addition, ported from Bend3. The Bool result checks that 2 + 3 = 5.

assert sum:
  forall x: U32
  forall y: U32
  U32

def sum(x, y):
  U32.add(x, y)

assert main_value:
  Bool

def main_value():
  U32.is_eq(sum(U32.from_nat(2n), U32.from_nat(3n)), U32.from_nat(5n))

assert main_show_bool:
  forall value: Bool
  IO(Unit)

def main_show_bool(value):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

assert main:
  IO(Unit)

def main():
  main_show_bool(main_value!())
