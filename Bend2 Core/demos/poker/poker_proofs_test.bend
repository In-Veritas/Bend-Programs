import Base
import ./poker_proofs.bend as Proof

# Referencing the quantified theorem functions makes Bend check their complete
# bodies against the named public claims.  The erased arguments vanish before
# either executable backend runs, so the entry only reports True{}.
def verified(-payload: Proof.PokerPayloadConservationClaim(), -count: Proof.PokerChipCountConservationClaim(), -value: Proof.PokerChipValueConservationClaim()) -> Bool:
  True{}

def main_value() -> Bool:
  verified(
    Proof.history_payload_conservation_theorem,
    Proof.history_chip_count_conservation_theorem,
    Proof.history_chip_value_conservation_theorem
  )

def main_show_bool(value: Bool) -> IO(Unit):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

def main() -> IO(Unit):
  main_show_bool(main_value())
