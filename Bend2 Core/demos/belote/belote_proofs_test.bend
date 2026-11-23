import ./belote_proofs.bend as Proof

assert verified:
  forall -payload: Proof.BelotePayloadConservationClaim()
  forall -count: Proof.BeloteCardCountConservationClaim()
  forall -points: Proof.BeloteCardPointConservationClaim()
  Bool

def verified(payload, count, points):
  True{}

assert main_value:
  Bool

def main_value():
  verified(
    Proof.history_payload_conservation_theorem,
    Proof.history_card_count_conservation_theorem,
    Proof.history_card_value_conservation_theorem
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
