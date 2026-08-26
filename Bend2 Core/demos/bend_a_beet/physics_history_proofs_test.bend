import ./physics_history_proofs.bend as Proof

assert verified:
  forall -anchor: Proof.MotionHistoryAnchorClaim()
  forall -fracture: Proof.FracturedHistoryAbsorbingClaim()
  Bool

def verified(anchor, fracture):
  True{}

assert main_value:
  Bool

def main_value():
  verified(
    Proof.motion_history_anchor_theorem,
    Proof.fractured_history_absorbing_claim_theorem
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
