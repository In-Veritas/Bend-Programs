import ./scene_proofs.bend as Proof

assert verified:
  forall -scene: Proof.SceneLightContractClaim()
  forall -pairs: Proof.SurfacePairCoverageClaim()
  forall -count: Proof.PairResponseCountClaim()
  Bool

def verified(scene, pairs, count):
  True{}

assert main_value:
  Bool

def main_value():
  verified(
    Proof.scene_light_contract_theorem,
    Proof.surface_pair_coverage_theorem,
    Proof.pair_response_count_theorem
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
