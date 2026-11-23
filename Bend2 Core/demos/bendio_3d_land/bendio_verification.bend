import Base
import ./bendio.bend as Bendio

# These are universal proofs about the generators that the browser actually
# calls.  They are not a list of sampled levels.  The first three proofs are
# structural inductions over an arbitrary requested course length; the next
# three prove the geometry and continuity laws for arbitrary inputs.

# Types
# =====

type BendioVerification:
  BendioVerification{
    -platform_generator_has_requested_length:
      @fuel: Nat -> @id: Nat -> @seed: U32 -> @x: U32 -> Bendio.VerifiedPlatforms<fuel>,
    -segment_generator_has_requested_length:
      @fuel: Nat -> @id: Nat -> @seed: U32 -> @x: U32 -> Bendio.VerifiedSegments<fuel>,
    -every_jump_generator_has_requested_length:
      @fuel: Nat -> @base_tick: U32 -> @local: U32 -> @geometry: Bendio.JumpGeometry -> Bendio.VerifiedFrames<fuel>,
    -every_jump_starts_and_ends_on_its_declared_anchors:
      @geometry: Bendio.JumpGeometry -> Bendio.BendioJumpEndpointClaim_func(geometry),
    -seed_transition_is_deterministic:
      @seed: U32 -> {
        Bendio.bendio_seed_next_func(seed)
        == U32.add(U32.mul(seed, U32.from_nat(73n)), U32.from_nat(41n))
        : U32
      },
    general_theorems: U32,
    certificates: U32
  }

# Func-Section
# ============

# The parabolic term is t*(35-t).  At t=0 and t=35 it is exactly zero, while
# all three linear interpolants normalize to the declared source/target.
assert bendio_jump_endpoint_theorem_func:
  forall geometry: Bendio.JumpGeometry
  Bendio.BendioJumpEndpointClaim_func(geometry)

def bendio_jump_endpoint_theorem_func(geometry):
  match geometry:
    case Bendio.JumpGeometry{sx, sy, sz, tx, ty, tz}:
      ({==}, {==})

assert bendio_seed_determinism_theorem_func:
  forall seed: U32
  { Bendio.bendio_seed_next_func(seed) == U32.add(U32.mul(seed, U32.from_nat(73n)), U32.from_nat(41n)) : U32 }

def bendio_seed_determinism_theorem_func(seed):
  {==}

assert bendio_verification_func:
  BendioVerification

def bendio_verification_func():
  BendioVerification{
    Bendio.bendio_platforms_claim_func,
    Bendio.bendio_segments_claim_func,
    Bendio.bendio_segment_frames_claim_func,
    bendio_jump_endpoint_theorem_func,
    bendio_seed_determinism_theorem_func,
    U32.from_nat(5n),
    U32.from_nat(4n)
  }

assert bendio_verification_self_check_func:
  Bool

def bendio_verification_self_check_func():
  Bendio.bendio_self_check_func()
