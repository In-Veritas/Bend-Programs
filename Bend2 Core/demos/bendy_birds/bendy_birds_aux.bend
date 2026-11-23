import ./bendy_birds.bend as Bendy
import ./shot_input.bend as Input

# Types
# =====

# The auxiliary entry reuses Bendy.ShotResult.

# Constants
# =========

# Func-Section
# ============

assert main_value:
  Bendy.ShotResult

def main_value():
  Bendy.bendy_shot_result_func(Input.shot_input_func())

assert main_accept_value:
  forall value: Bendy.ShotResult
  IO(Unit)

def main_accept_value(value):
  IO.print("Ready{}")

assert main:
  IO(Unit)

def main():
  main_accept_value(main_value!())
