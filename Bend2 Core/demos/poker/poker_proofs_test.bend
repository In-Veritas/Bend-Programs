import ./poker_proofs.bend as Proof

# Referencing the polymorphic theorem functions makes Core validate their
# complete bodies.  The values erase before either executable backend runs.
assert verified:
  forall -payload: Proof.PokerPayloadConservationClaim()
  forall -count: Proof.PokerChipCountConservationClaim()
  forall -value: Proof.PokerChipValueConservationClaim()
  Bool

def verified(payload, count, value):
  True{}

assert main_value:
  Bool

def main_value():
  verified(
    Proof.history_payload_conservation_theorem,
    Proof.history_chip_count_conservation_theorem,
    Proof.history_chip_value_conservation_theorem
  )

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
