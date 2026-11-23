import Base
import ./belote_proofs.bend as Proof

# Executable entry for the conservation kernel: the three erased parameters
# demand the three history theorems, so this file checks only if the proofs
# do; at runtime they are gone and main prints True{}.

def verified(
  -payload: Proof.BelotePayloadConservationClaim(),
  -count: Proof.BeloteCardCountConservationClaim(),
  -points: Proof.BeloteCardPointConservationClaim()
) -> Bool:
  True{}

def main_value() -> Bool:
  verified(
    Proof.history_payload_conservation_theorem,
    Proof.history_card_count_conservation_theorem,
    Proof.history_card_value_conservation_theorem
  )

def main_show_bool(value: Bool) -> IO(Unit):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

def main() -> IO(Unit):
  main_show_bool(main_value())
