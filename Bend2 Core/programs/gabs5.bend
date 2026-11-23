import ./transtyping.bend as Port
# The original gabs5 intentionally duplicates gabs3; this import preserves
# that regression-test identity without maintaining a second implementation.

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
