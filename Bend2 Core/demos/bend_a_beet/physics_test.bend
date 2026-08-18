import ./physics.bend as Physics

# Minimal namespace-qualified integration example.
def sample() -> Physics.BendFrame:
  Physics.beet_bend(
    U32.from_nat(77n),
    Physics.attributes_from_seed(U32.from_nat(77n), U32.from_nat(13n)),
    U32.from_nat(700n)
  )

def certified(-proofs: Physics.PhysicsProofAudit, result: Bool) -> Bool:
  result

def main() -> Bool:
  certified(Physics.physics_proofs(), Physics.physics_self_test())
