import Base
import ./bendy_birds.bend as Bendy
import ../bend_engine/physics.bend as Physics

# Types
# =====

type BendyBirdsVerification:
  BendyBirdsVerification{
    -bird_step_preserves_identity_material_mass:
      @bird: Bendy.Bird -> @event: Bendy.FlightEvent -> {
        Bendy.bird_payload(Bendy.bird_step(bird, event)) == Bendy.bird_payload(bird)
        : Bendy.BirdPayload
      },
    -arbitrary_flight_history_preserves_identity_material_mass:
      @history: Bendy.FlightHistory -> @bird: Bendy.Bird -> {
        Bendy.bird_payload(Bendy.flight_history_run(history, bird)) == Bendy.bird_payload(bird)
        : Bendy.BirdPayload
      },
    -block_damage_preserves_identity_material:
      @block: Bendy.Block -> @damage: Nat -> {
        Bendy.block_payload(Bendy.block_apply_damage(block, damage)) == Bendy.block_payload(block)
        : Bendy.BlockPayload
      },
    -arbitrary_block_field_damage_preserves_alignment:
      @blocks: List<Bendy.Block> -> @damage: Nat ->
      Physics.Claim<List<Bendy.Block>, output => {
        Bendy.bendy_blocks_payload_func(output)
        == Bendy.bendy_blocks_payload_func(blocks)
        : List<Bendy.BlockPayload>
      }>,
    -broken_blocks_remain_broken_through_every_arbitrary_damage_history:
      @history: Bendy.DamageHistory -> @debris: Nat -> {
        Bendy.block_damage_history_run_func(history, Bendy.Broken{debris}) == Bendy.Broken{debris}
        : Bendy.BlockStatus
      },
    -collision_response_obeys_momentum_law:
      @event: Bendy.CollisionEvent -> Bendy.BendyCollisionLawClaim_func(event),
    -trajectory_generator_is_length_certified:
      @fuel: Nat -> @index: U32 -> @angle: U32 -> @strength: U32 -> @material: Bendy.BirdMaterial ->
      Bendy.VerifiedTrajectory<fuel>,
    -arbitrary_angle_arc_has_exact_ground_endpoints:
      @angle: U32 -> Bendy.BendyArcEndpointClaim_func(angle),
    -arbitrary_angle_and_strength_determine_terminal_x:
      @angle: U32 -> @strength: U32 -> {
        Bendy.bendy_impact_x_func(angle, strength)
        == U32.add(U32.from_nat(120n), U32.mul(U32.from_nat(96n), Bendy.bendy_horizontal_speed_func(angle, strength)))
        : U32
      },
    -engine_vector_negation_is_involutive:
      @value: Physics.Vec3 -> {
        Physics.vec3_negate(Physics.vec3_negate(value)) == value
        : Physics.Vec3
      },
    general_theorems: U32,
    certificates: U32
  }

# Constants
# =========

# Func-Section
# ============

assert bendy_birds_verification_func:
  BendyBirdsVerification

def bendy_birds_verification_func():
  BendyBirdsVerification{
    Bendy.bird_step_payload_theorem,
    Bendy.flight_history_payload_theorem_func,
    Bendy.block_apply_damage_payload_theorem,
    Bendy.bendy_blocks_damage_claim_func,
    Bendy.block_damage_history_broken_absorbing_theorem_func,
    Bendy.collision_event_momentum_law_theorem,
    Bendy.bendy_verified_trajectory_func,
    Bendy.bendy_arc_endpoint_theorem_func,
    Bendy.bendy_impact_x_theorem_func,
    Physics.vec3_negation_involution_theorem,
    U32.from_nat(10n),
    U32.from_nat(4n)
  }

assert bendy_birds_verification_self_check_func:
  Bool

def bendy_birds_verification_self_check_func():
  Bendy.bendy_self_check_func()
