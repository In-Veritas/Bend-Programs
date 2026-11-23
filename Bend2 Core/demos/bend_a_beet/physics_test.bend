import ./physics.bend as Physics

# Minimal namespace-qualified integration example.
assert sample:
  Physics.BendFrame

def sample():
  Physics.beet_bend(
    U32.from_nat(77n),
    Physics.attributes_from_seed(U32.from_nat(77n), U32.from_nat(13n)),
    U32.from_nat(700n)
  )

assert verified:
  forall -audit: Physics.PhysicsVerificationAudit
  forall result: Bool
  Bool

def verified(audit, result):
  result

assert main_value:
  Bool

def main_value():
  verified(Physics.physics_verification(), Physics.physics_self_test())

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
