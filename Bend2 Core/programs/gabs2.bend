import Base
# Minimal addition, ported from Bend3. The Bool result checks that 2 + 3 = 5.

def sum(x: U32, y: U32) -> U32:
  U32.add(x, y)

def main_value() -> Bool:
  U32.is_eq(sum(2, 3), 5)

# The executable entry prints the pure self-check, so `bend FILE`, a native
# build and the JS build all report True{} through the same IO path.
def main_show_bool(value: Bool) -> IO(Unit):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

def main() -> IO(Unit):
  main_show_bool(main_value())
