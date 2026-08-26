import ./heroes_proofs.bend as Proof

# Proof audit
# ===========
#
# Import validation checks every theorem body before either backend is emitted.
# The executable result is intentionally tiny because equality evidence erases.

assert main:
  IO(Unit)

def main():
  IO.print("True{}")
