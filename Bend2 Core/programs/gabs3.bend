import ./transtyping.bend as Port
# The original gabs3 is the same transtyping program; this wrapper preserves
# its authored filename while reusing the checked Bend2 Core port.

assert main_value:
  Bool

def main_value():
  Port.main_value()

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
