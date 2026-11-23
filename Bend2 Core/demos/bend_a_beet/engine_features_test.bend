import ./engine_features.bend as Engine

assert verified:
  forall -contract: Engine.EngineProfilesContractClaim_func()
  forall -count: Engine.EngineProfilesCountClaim_func()
  Bool

def verified(contract, count):
  True{}

assert main_value:
  Bool

def main_value():
  Bool.and(
    Model3D.model3d_verification_func(),
    Bool.and(
      EngineLight.light_verification_func(),
      verified(
        Engine.engine_profiles_contract_theorem_func,
        Engine.engine_profiles_count_theorem_func
      )
    )
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
