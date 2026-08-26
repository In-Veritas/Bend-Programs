import Base
import ../bend_engine/physics.bend as Physics
import ../../compat/list.bend as List
import ../../compat/nat.bend as Nat

# Bendy Birds: pure 3D soft-body projectile and destruction simulation.
# A host writes a ShotRequest module, then the auxiliary Core entry recomputes
# the next immutable state. Browser JavaScript never advances the physics.

# Types
# =====

type BirdMaterial:
  JelloBird{}
  RubberBird{}
  FurballBird{}
  StoneBird{}
  BubbleBird{}
  SpringBird{}

type BirdMaterialCopies:
  BirdMaterialCopies{a: BirdMaterial, b: BirdMaterial, c: BirdMaterial, d: BirdMaterial}

type BirdDynamics:
  BirdDynamics{x: Nat, y: Nat, vx: Nat, upward: Nat, downward: Nat, deformation: Nat}

type Bird:
  Bird{id: Nat, material: BirdMaterial, mass: Nat, dynamics: BirdDynamics}

type BirdPayload:
  BirdPayload{id: Nat, material: BirdMaterial, mass: Nat}

type FlightEvent:
  LaunchEvent{horizontal: Nat, vertical: Nat}
  GravityEvent{acceleration: Nat}
  DragEvent{loss: Nat}
  BounceEvent{restitution: Nat}
  DeformEvent{amount: Nat}

type FlightHistory:
  FlightHistoryEnd{}
  FlightHistoryFrame{event: FlightEvent, tail: FlightHistory}

type BlockMaterial:
  GlassBlock{}
  IceBlock{}
  WoodBlock{}
  BrickBlock{}
  MetalBlock{}
  JellyBlock{}
  BambooBlock{}

type BlockStatus:
  Standing{integrity: Nat}
  Broken{debris: Nat}

type DamageHistory:
  DamageHistoryEnd{}
  DamageHistoryStep{damage: Nat, tail: DamageHistory}

type Block:
  Block{id: Nat, material: BlockMaterial, x: U32, y: U32, z: U32, width: U32, height: U32, status: BlockStatus}

type BlockPayload:
  BlockPayload{id: Nat, material: BlockMaterial}

type PhysicalFactor:
  PhysicalFactor{primary: Nat, replica: Nat, -exact: {primary == replica : Nat}}

type CollisionEvent:
  CollisionEvent{momentum: PhysicalFactor, restitution: PhysicalFactor, resistance: PhysicalFactor}

type CollisionResponse:
  CollisionResponse{transferred: Nat, retained: Nat, deformation: Nat}

type FlightFrame:
  FlightFrame{tick: U32, x: U32, y: U32, rotation: U32, squash: U32, stretch: U32, trail: U32}

type FlightPoint:
  FlightPoint{x: U32, y: U32}

type VerifiedTrajectory<-expected: Nat>:
  VerifiedTrajectory{frames: List<FlightFrame>, -length_exact: {List.length(FlightFrame, frames) == expected : Nat}}

type ShotRequest:
  ShotRequest{bird: BirdMaterial, angle: U32, strength: U32, blocks: List<Block>, shot_number: U32}

type ShotResult:
  ShotResult{bird: BirdMaterial, angle: U32, strength: U32, frames: List<FlightFrame>, blocks: List<Block>, score: U32, shot_number: U32}

type BirdSpec:
  BirdSpec{material: BirdMaterial, mass: U32, elasticity: U32, drag: U32, softness: U32, fur: U32}

type Report:
  Report{title: String, birds: List<BirdSpec>, initial_blocks: List<Block>, previews: List<ShotResult>}

# Constants
# =========

assert bendy_u32_func:
  forall value: Nat
  U32

def bendy_u32_func(value):
  U32.from_nat(value)

# BirdMaterial-Section
# ====================

assert bird_material_copy:
  forall value: BirdMaterial
  BirdMaterial & BirdMaterial

def bird_material_copy(value):
  match value:
    case JelloBird{}: (JelloBird{}, JelloBird{})
    case RubberBird{}: (RubberBird{}, RubberBird{})
    case FurballBird{}: (FurballBird{}, FurballBird{})
    case StoneBird{}: (StoneBird{}, StoneBird{})
    case BubbleBird{}: (BubbleBird{}, BubbleBird{})
    case SpringBird{}: (SpringBird{}, SpringBird{})

assert bird_material_four:
  forall value: BirdMaterial
  BirdMaterialCopies

def bird_material_four(value):
  (left, right) = bird_material_copy(value)
  (a, b) = bird_material_copy(left)
  (c, d) = bird_material_copy(right)
  BirdMaterialCopies{a, b, c, d}

assert bird_material_code:
  forall value: BirdMaterial
  U32

def bird_material_code(value):
  match value:
    case JelloBird{}: bendy_u32_func(0n)
    case RubberBird{}: bendy_u32_func(1n)
    case FurballBird{}: bendy_u32_func(2n)
    case StoneBird{}: bendy_u32_func(3n)
    case BubbleBird{}: bendy_u32_func(4n)
    case SpringBird{}: bendy_u32_func(5n)

assert bird_material_codes:
  forall value: BirdMaterial
  U32 & (U32 & (U32 & U32))

def bird_material_codes(value):
  match value:
    case JelloBird{}: (bendy_u32_func(0n), (bendy_u32_func(0n), (bendy_u32_func(0n), bendy_u32_func(0n))))
    case RubberBird{}: (bendy_u32_func(1n), (bendy_u32_func(1n), (bendy_u32_func(1n), bendy_u32_func(1n))))
    case FurballBird{}: (bendy_u32_func(2n), (bendy_u32_func(2n), (bendy_u32_func(2n), bendy_u32_func(2n))))
    case StoneBird{}: (bendy_u32_func(3n), (bendy_u32_func(3n), (bendy_u32_func(3n), bendy_u32_func(3n))))
    case BubbleBird{}: (bendy_u32_func(4n), (bendy_u32_func(4n), (bendy_u32_func(4n), bendy_u32_func(4n))))
    case SpringBird{}: (bendy_u32_func(5n), (bendy_u32_func(5n), (bendy_u32_func(5n), bendy_u32_func(5n))))

assert bird_material_damage:
  forall value: BirdMaterial
  Nat

def bird_material_damage(value):
  match value:
    case JelloBird{}: 5n
    case RubberBird{}: 8n
    case FurballBird{}: 4n
    case StoneBird{}: 18n
    case BubbleBird{}: 3n
    case SpringBird{}: 11n

assert bird_material_deformation:
  forall value: BirdMaterial
  Nat

def bird_material_deformation(value):
  match value:
    case JelloBird{}: 18n
    case RubberBird{}: 12n
    case FurballBird{}: 8n
    case StoneBird{}: 1n
    case BubbleBird{}: 20n
    case SpringBird{}: 14n

# BirdDynamics-Section
# ====================

assert bird_dynamics_step:
  forall value: BirdDynamics
  forall event: FlightEvent
  BirdDynamics

def bird_dynamics_step(value, event):
  match value event:
    case BirdDynamics{x, y, vx, up, down, deform} LaunchEvent{horizontal, vertical}:
      ((horizontal_position, horizontal_position_exact), (horizontal_velocity, horizontal_velocity_exact)) = Nat.copy(horizontal)
      ((vertical_position, vertical_position_exact), (vertical_velocity, vertical_velocity_exact)) = Nat.copy(vertical)
      BirdDynamics{Nat.add(x, horizontal_position), Nat.add(y, vertical_position), Nat.add(vx, horizontal_velocity), Nat.add(up, vertical_velocity), down, deform}
    case BirdDynamics{x, y, vx, up, down, deform} GravityEvent{acceleration}:
      ((vx_position, vx_position_exact), (vx_keep, vx_keep_exact)) = Nat.copy(vx)
      BirdDynamics{Nat.add(x, vx_position), y, vx_keep, up, Nat.add(down, acceleration), deform}
    case BirdDynamics{x, y, vx, up, down, deform} DragEvent{loss}:
      BirdDynamics{x, y, vx, up, down, Nat.add(deform, loss)}
    case BirdDynamics{x, y, vx, up, down, deform} BounceEvent{restitution}:
      ((restitution_up, restitution_up_exact), (restitution_deform, restitution_deform_exact)) = Nat.copy(restitution)
      BirdDynamics{x, y, vx, Nat.add(up, restitution_up), down, Nat.add(deform, restitution_deform)}
    case BirdDynamics{x, y, vx, up, down, deform} DeformEvent{amount}:
      BirdDynamics{x, y, vx, up, down, Nat.add(deform, amount)}

# Bird-Section
# ============

assert bird_payload:
  forall value: Bird
  BirdPayload

def bird_payload(value):
  match value:
    case Bird{id, material, mass, dynamics}:
      BirdPayload{id, material, mass}

assert bird_step:
  forall value: Bird
  forall event: FlightEvent
  Bird

def bird_step(value, event):
  match value:
    case Bird{id, material, mass, dynamics}:
      Bird{id, material, mass, bird_dynamics_step(dynamics, event)}

assert bird_step_payload_theorem:
  forall value: Bird
  forall event: FlightEvent
  { bird_payload(bird_step(value, event)) == bird_payload(value) : BirdPayload }

def bird_step_payload_theorem(value, event):
  match value:
    case Bird{id, material, mass, dynamics}:
      {==}

# FlightHistory-Section
# =====================

assert flight_history_run:
  forall value: FlightHistory
  forall bird: Bird
  Bird

def flight_history_run(value, bird):
  match value:
    case FlightHistoryEnd{}:
      bird
    case FlightHistoryFrame{event, tail}:
      stepped = bird_step(bird, event)
      result = flight_history_run(tail, stepped)
      result

assert flight_history_payload_theorem_func:
  forall value: FlightHistory
  forall bird: Bird
  { bird_payload(flight_history_run(value, bird)) == bird_payload(bird) : BirdPayload }

def flight_history_payload_theorem_func(value, bird):
  match value bird:
    case FlightHistoryEnd{} Bird{id, material, mass, dynamics}:
      {==}
    case FlightHistoryFrame{event, tail} Bird{id, material, mass, dynamics}:
      proof = flight_history_payload_theorem_func(tail, bird_step(Bird{id, material, mass, dynamics}, event))
      proof

# BlockMaterial-Section
# =====================

assert block_material_copy:
  forall value: BlockMaterial
  BlockMaterial & BlockMaterial

def block_material_copy(value):
  match value:
    case GlassBlock{}: (GlassBlock{}, GlassBlock{})
    case IceBlock{}: (IceBlock{}, IceBlock{})
    case WoodBlock{}: (WoodBlock{}, WoodBlock{})
    case BrickBlock{}: (BrickBlock{}, BrickBlock{})
    case MetalBlock{}: (MetalBlock{}, MetalBlock{})
    case JellyBlock{}: (JellyBlock{}, JellyBlock{})
    case BambooBlock{}: (BambooBlock{}, BambooBlock{})

# BlockStatus-Section
# ===================

assert block_integrity_damage_func:
  forall damage: Nat
  forall integrity: Nat
  BlockStatus

def block_integrity_damage_func(damage, integrity):
  match damage integrity:
    case 0n 0n:
      Standing{0n}
    case 0n 1n+integrity_pred:
      Standing{1n+integrity_pred}
    case 1n+damage_pred 0n:
      Broken{1n+damage_pred}
    case 1n+damage_pred 1n+integrity_pred:
      block_integrity_damage_func(damage_pred, integrity_pred)

assert block_status_damage:
  forall value: BlockStatus
  forall damage: Nat
  BlockStatus

def block_status_damage(value, damage):
  match value:
    case Broken{debris}:
      Broken{debris}
    case Standing{integrity}:
      block_integrity_damage_func(damage, integrity)

assert block_status_broken_absorbing_theorem:
  forall value: Nat
  forall damage: Nat
  { block_status_damage(Broken{value}, damage) == Broken{value} : BlockStatus }

def block_status_broken_absorbing_theorem(value, damage):
  {==}

assert block_damage_history_run_func:
  forall history: DamageHistory
  forall status: BlockStatus
  BlockStatus

def block_damage_history_run_func(history, status):
  match history:
    case DamageHistoryEnd{}: status
    case DamageHistoryStep{damage, tail}:
      block_damage_history_run_func(tail, block_status_damage(status, damage))

# Structural induction: once broken, no arbitrary finite sequence of later
# impacts can restore a block or alter its debris identity.
assert block_damage_history_broken_absorbing_theorem_func:
  forall history: DamageHistory
  forall debris: Nat
  { block_damage_history_run_func(history, Broken{debris}) == Broken{debris} : BlockStatus }

def block_damage_history_broken_absorbing_theorem_func(history, debris):
  match history:
    case DamageHistoryEnd{}:
      {==}
    case DamageHistoryStep{damage, tail}:
      block_damage_history_broken_absorbing_theorem_func(tail, debris)

# Block-Section
# =============

assert block_payload:
  forall value: Block
  BlockPayload

def block_payload(value):
  match value:
    case Block{id, material, x, y, z, width, height, status}:
      BlockPayload{id, material}

assert block_apply_damage:
  forall value: Block
  forall damage: Nat
  Block

def block_apply_damage(value, damage):
  match value:
    case Block{id, material, x, y, z, width, height, status}:
      Block{id, material, x, y, z, width, height, block_status_damage(status, damage)}

assert block_apply_damage_payload_theorem:
  forall value: Block
  forall damage: Nat
  { block_payload(block_apply_damage(value, damage)) == block_payload(value) : BlockPayload }

def block_apply_damage_payload_theorem(value, damage):
  match value:
    case Block{id, material, x, y, z, width, height, status}:
      {==}

# CollisionEvent-Section
# ======================

assert collision_event_resolve:
  forall value: CollisionEvent
  CollisionResponse

def collision_event_resolve(value):
  match value:
    case CollisionEvent{PhysicalFactor{momentum_transfer, momentum_retain, momentum_exact}, PhysicalFactor{restitution_transfer, restitution_deform, restitution_exact}, PhysicalFactor{resistance_retain, resistance_deform, resistance_exact}}:
      CollisionResponse{
        Nat.mul(momentum_transfer, restitution_transfer),
        Nat.mul(momentum_retain, resistance_retain),
        Nat.add(restitution_deform, resistance_deform)
      }

assert BendyCollisionLawClaim_func:
  forall event: CollisionEvent
  Type

def BendyCollisionLawClaim_func(event):
  match event:
    case CollisionEvent{PhysicalFactor{momentum_transfer, momentum_retain, momentum_exact}, PhysicalFactor{restitution_transfer, restitution_deform, restitution_exact}, PhysicalFactor{resistance_retain, resistance_deform, resistance_exact}}:
      {
        collision_event_resolve(event)
        == CollisionResponse{Nat.mul(momentum_transfer, restitution_transfer), Nat.mul(momentum_retain, resistance_retain), Nat.add(restitution_deform, resistance_deform)}
        : CollisionResponse
      }

assert collision_event_momentum_law_theorem:
  forall value: CollisionEvent
  BendyCollisionLawClaim_func(value)

def collision_event_momentum_law_theorem(value):
  match value:
    case CollisionEvent{PhysicalFactor{momentum_transfer, momentum_retain, momentum_exact}, PhysicalFactor{restitution_transfer, restitution_deform, restitution_exact}, PhysicalFactor{resistance_retain, resistance_deform, resistance_exact}}:
      {==}

# Func-Section
# ============

assert bendy_blocks_payload_func:
  forall values: List<Block>
  List<BlockPayload>

def bendy_blocks_payload_func(values):
  match values:
    case Nil{}: Nil{}
    case Con{head, tail}: Con{block_payload(head), bendy_blocks_payload_func(tail)}

assert bendy_blocks_damage_claim_func:
  forall values: List<Block>
  forall damage: Nat
  Physics.Claim<List<Block>, output => { bendy_blocks_payload_func(output) == bendy_blocks_payload_func(values) : List<BlockPayload> }>

def bendy_blocks_damage_claim_func(values, damage):
  match values:
    case Nil{}:
      Physics.Claim{Nil{}, {==}}
    case Con{Block{id, material, x, y, z, width, height, status}, tail}:
      ((head_damage, head_damage_exact), (tail_damage, tail_damage_exact)) = Nat.copy(damage)
      match bendy_blocks_damage_claim_func(tail, tail_damage):
        case Physics.Claim{tail_output, tail_proof}:
          Physics.Claim{
            Con{block_apply_damage(Block{id, material, x, y, z, width, height, status}, head_damage), tail_output},
            Equal.cong(
              List<BlockPayload>,
              List<BlockPayload>,
              rest => Con{BlockPayload{id, material}, rest},
              bendy_blocks_payload_func(tail_output),
              bendy_blocks_payload_func(tail),
              tail_proof
            )
          }

assert bendy_blocks_damage_func:
  forall values: List<Block>
  forall damage: Nat
  List<Block>

def bendy_blocks_damage_func(values, damage):
  match bendy_blocks_damage_claim_func(values, damage):
    case Physics.Claim{output, proof}:
      output

assert bendy_u32_distance_func:
  forall left: U32
  forall right: U32
  U32

def bendy_u32_distance_func(left, right):
  ((left_test, left_test_exact), (left_live, left_live_exact)) = U32.copy(left)
  ((right_test, right_test_exact), (right_live, right_live_exact)) = U32.copy(right)
  match U32.is_le(left_test, right_test):
    case True{}: U32.sub(right_live, left_live)
    case False{}: U32.sub(left_live, right_live)

assert bendy_block_impact_claim_func:
  forall hit: Bool
  forall block: Block
  forall damage: Nat
  Physics.Claim<Block, output => { block_payload(output) == block_payload(block) : BlockPayload }>

def bendy_block_impact_claim_func(hit, block, damage):
  match hit block:
    case True{} Block{id, material, x, y, z, width, height, status}:
      Physics.Claim{
        block_apply_damage(Block{id, material, x, y, z, width, height, status}, damage),
        {==}
      }
    case False{} Block{id, material, x, y, z, width, height, status}:
      Physics.Claim{Block{id, material, x, y, z, width, height, status}, {==}}

assert bendy_impact_cons_payload_theorem_func:
  forall -id: Nat
  forall -material: BlockMaterial
  forall -head_output: Block
  forall -tail: List<Block>
  forall -tail_output: List<Block>
  forall head_exact: {
    block_payload(head_output) == BlockPayload{id, material}
    : BlockPayload
  }
  forall tail_exact: {
    bendy_blocks_payload_func(tail_output) == bendy_blocks_payload_func(tail)
    : List<BlockPayload>
  }
  {
    Con{block_payload(head_output), bendy_blocks_payload_func(tail_output)}
    == Con{BlockPayload{id, material}, bendy_blocks_payload_func(tail)}
    : List<BlockPayload>
  }

def bendy_impact_cons_payload_theorem_func(
  id,
  material,
  head_output,
  tail,
  tail_output,
  head_exact,
  tail_exact
):
  Equal.trans(
    List<BlockPayload>,
    Con{block_payload(head_output), bendy_blocks_payload_func(tail_output)},
    Con{BlockPayload{id, material}, bendy_blocks_payload_func(tail_output)},
    Con{BlockPayload{id, material}, bendy_blocks_payload_func(tail)},
    Equal.cong(
      BlockPayload,
      List<BlockPayload>,
      payload => Con{payload, bendy_blocks_payload_func(tail_output)},
      block_payload(head_output),
      BlockPayload{id, material},
      head_exact
    ),
    Equal.cong(
      List<BlockPayload>,
      List<BlockPayload>,
      rest => Con{BlockPayload{id, material}, rest},
      bendy_blocks_payload_func(tail_output),
      bendy_blocks_payload_func(tail),
      tail_exact
    )
  )

# Only blocks within 260 Core units of the terminal x-coordinate receive the
# material-dependent impact.  The proof follows the actual conditional map and
# preserves every block identity/material in order for arbitrary input fields.
assert bendy_blocks_impact_claim_func:
  forall values: List<Block>
  forall impact_x: U32
  forall damage: Nat
  Physics.Claim<List<Block>, output => { bendy_blocks_payload_func(output) == bendy_blocks_payload_func(values) : List<BlockPayload> }>

def bendy_blocks_impact_claim_func(values, impact_x, damage):
  match values:
    case Nil{}:
      Physics.Claim{Nil{}, {==}}
    case Con{Block{id, material, x, y, z, width, height, status}, tail}:
      ((impact_head, impact_head_exact), (impact_tail, impact_tail_exact)) = U32.copy(impact_x)
      ((damage_head, damage_head_exact), (damage_tail, damage_tail_exact)) = Nat.copy(damage)
      ((x_test, x_test_exact), (x_live, x_live_exact)) = U32.copy(x)
      match bendy_block_impact_claim_func(
        U32.is_le(bendy_u32_distance_func(impact_head, x_test), bendy_u32_func(260n)),
        Block{id, material, x_live, y, z, width, height, status},
        damage_head
      ):
        case Physics.Claim{head_output, head_exact}:
          match bendy_blocks_impact_claim_func(tail, impact_tail, damage_tail):
            case Physics.Claim{tail_output, tail_exact}:
              Physics.Claim{
                Con{head_output, tail_output},
                bendy_impact_cons_payload_theorem_func(
                  id,
                  material,
                  head_output,
                  tail,
                  tail_output,
                  head_exact,
                  tail_exact
                )
              }

assert bendy_blocks_impact_func:
  forall values: List<Block>
  forall impact_x: U32
  forall damage: Nat
  List<Block>

def bendy_blocks_impact_func(values, impact_x, damage):
  match bendy_blocks_impact_claim_func(values, impact_x, damage):
    case Physics.Claim{output, proof}:
      output

assert bendy_u32_four_func:
  forall value: U32
  U32 & (U32 & (U32 & U32))

def bendy_u32_four_func(value):
  ((a, a_exact), (rest, rest_exact)) = U32.copy(value)
  ((b, b_exact), (rest2, rest2_exact)) = U32.copy(rest)
  ((c, c_exact), (d, d_exact)) = U32.copy(rest2)
  (a, (b, (c, d)))

assert bendy_u32_three_func:
  forall value: U32
  U32 & (U32 & U32)

def bendy_u32_three_func(value):
  ((first, first_exact), (rest, rest_exact)) = U32.copy(value)
  ((second, second_exact), (third, third_exact)) = U32.copy(rest)
  (first, (second, third))

assert bird_angle_pair_func:
  forall value: U32
  U32 & U32

def bird_angle_pair_func(value):
  ((left, left_exact), (right, right_exact)) = U32.copy(value)
  (left, right)

assert bendy_horizontal_speed_func:
  forall angle: U32
  forall strength: U32
  U32

def bendy_horizontal_speed_func(angle, strength):
  U32.add(bendy_u32_func(8n), U32.add(U32.mul(strength, bendy_u32_func(2n)), U32.div(angle, bendy_u32_func(10n))))

assert bendy_arc_height_middle_func:
  forall index: U32
  forall angle: U32
  U32

def bendy_arc_height_middle_func(index, angle):
  ((time_left, time_left_exact), (time_right, time_right_exact)) = U32.copy(index)
  U32.add(
    bendy_u32_func(120n),
    U32.div(
      U32.mul(U32.mul(time_left, U32.sub(bendy_u32_func(96n), time_right)), U32.add(angle, bendy_u32_func(10n))),
      bendy_u32_func(64n)
    )
  )

assert bendy_arc_height_end_dispatch_func:
  forall is_end: Bool
  forall index: U32
  forall angle: U32
  U32

def bendy_arc_height_end_dispatch_func(is_end, index, angle):
  match is_end:
    case True{}: bendy_u32_func(120n)
    case False{}: bendy_arc_height_middle_func(index, angle)

assert bendy_arc_height_start_dispatch_func:
  forall is_start: Bool
  forall index: U32
  forall angle: U32
  U32

def bendy_arc_height_start_dispatch_func(is_start, index, angle):
  match is_start:
    case True{}: bendy_u32_func(120n)
    case False{}:
      ((time_test, time_test_exact), (time_live, time_live_exact)) = U32.copy(index)
      bendy_arc_height_end_dispatch_func(U32.is_eq(time_test, bendy_u32_func(96n)), time_live, angle)

assert bendy_arc_height_func:
  forall index: U32
  forall angle: U32
  U32

def bendy_arc_height_func(index, angle):
  ((time_test, time_test_exact), (time_live, time_live_exact)) = U32.copy(index)
  bendy_arc_height_start_dispatch_func(U32.is_eq(time_test, 0), time_live, angle)

assert bendy_impact_x_func:
  forall angle: U32
  forall strength: U32
  U32

def bendy_impact_x_func(angle, strength):
  U32.add(bendy_u32_func(120n), U32.mul(bendy_u32_func(96n), bendy_horizontal_speed_func(angle, strength)))

assert BendyArcEndpointClaim_func:
  forall angle: U32
  Type

def BendyArcEndpointClaim_func(angle):
  ({bendy_arc_height_func(0, angle) == bendy_u32_func(120n) : U32}
  & {bendy_arc_height_func(bendy_u32_func(96n), angle) == bendy_u32_func(120n) : U32})

assert bendy_arc_endpoint_theorem_func:
  forall angle: U32
  BendyArcEndpointClaim_func(angle)

def bendy_arc_endpoint_theorem_func(angle):
  ({==}, {==})

assert bendy_impact_x_theorem_func:
  forall angle: U32
  forall strength: U32
  { bendy_impact_x_func(angle, strength) == U32.add(bendy_u32_func(120n), U32.mul(bendy_u32_func(96n), bendy_horizontal_speed_func(angle, strength))) : U32 }

def bendy_impact_x_theorem_func(angle, strength):
  {==}

assert bendy_flight_frame_func:
  forall index: U32
  forall angle: U32
  forall strength: U32
  forall material: BirdMaterial
  FlightFrame

def bendy_flight_frame_func(index, angle, strength, material):
  (i0, (i1, (i2, i3))) = bendy_u32_four_func(index)
  (angle_x, angle_y) = bird_angle_pair_func(angle)
  (code_squash, (code_stretch, (code_trail, code_keep))) = bird_material_codes(material)
  FlightFrame{
    i0,
    U32.add(bendy_u32_func(120n), U32.mul(i1, bendy_horizontal_speed_func(angle_x, strength))),
    bendy_arc_height_func(i2, angle_y),
    U32.mod(U32.mul(i3, bendy_u32_func(19n)), bendy_u32_func(360n)),
    U32.add(bendy_u32_func(20n), U32.mul(code_squash, bendy_u32_func(9n))),
    U32.add(bendy_u32_func(100n), U32.mul(code_stretch, bendy_u32_func(7n))),
    U32.add(bendy_u32_func(4n), code_trail)
  }

assert bendy_verified_trajectory_func:
  forall fuel: Nat
  forall index: U32
  forall angle: U32
  forall strength: U32
  forall material: BirdMaterial
  VerifiedTrajectory<fuel>

def bendy_verified_trajectory_func(fuel, index, angle, strength, material):
  match fuel:
    case 0n:
      VerifiedTrajectory{Nil{}, {==}}
    case 1n+pred:
      ((frame_index, frame_index_exact), (next_index, next_index_exact)) = U32.copy(index)
      ((frame_angle, frame_angle_exact), (tail_angle, tail_angle_exact)) = U32.copy(angle)
      ((frame_strength, frame_strength_exact), (tail_strength, tail_strength_exact)) = U32.copy(strength)
      (frame_material, tail_material) = bird_material_copy(material)
      match bendy_verified_trajectory_func(pred, U32.inc(next_index), tail_angle, tail_strength, tail_material):
        case VerifiedTrajectory{tail, tail_exact}:
          frame = bendy_flight_frame_func(frame_index, frame_angle, frame_strength, frame_material)
          VerifiedTrajectory{
            Con{frame, tail},
            Equal.cong(Nat, Nat, length => 1n+length, List.length(FlightFrame, tail), pred, tail_exact)
          }

assert bendy_trajectory_func:
  forall fuel: Nat
  forall angle: U32
  forall strength: U32
  forall material: BirdMaterial
  List<FlightFrame>

def bendy_trajectory_func(fuel, angle, strength, material):
  match bendy_verified_trajectory_func(fuel, 0, angle, strength, material):
    case VerifiedTrajectory{frames, length_exact}:
      frames

assert bendy_shot_result_func:
  forall request: ShotRequest
  ShotResult

def bendy_shot_result_func(request):
  match request:
    case ShotRequest{bird, angle, strength, blocks, shot_number}:
      match bird_material_four(bird):
        case BirdMaterialCopies{bird_output, bird_trajectory, bird_damage, bird_score}:
          ((angle_output, angle_output_exact), (angle_trajectory, angle_trajectory_exact)) = U32.copy(angle)
          (strength_output, (strength_damage, strength_score)) = bendy_u32_three_func(strength)
          ((angle_trajectory, angle_trajectory_exact), (angle_impact, angle_impact_exact)) = U32.copy(angle_trajectory)
          (strength_trajectory, (strength_impact, strength_damage_live)) = bendy_u32_three_func(strength_damage)
          damage = Nat.mul(bird_material_damage(bird_damage), U32.to_nat(strength_damage_live))
          ShotResult{
            bird_output,
            angle_output,
            strength_output,
            bendy_trajectory_func(97n, angle_trajectory, strength_trajectory, bird_trajectory),
            bendy_blocks_impact_func(blocks, bendy_impact_x_func(angle_impact, strength_impact), damage),
            U32.add(U32.mul(strength_score, bendy_u32_func(90n)), U32.mul(bird_material_code(bird_score), bendy_u32_func(250n))),
            U32.inc(shot_number)
          }

assert bendy_bird_from_code_func:
  forall value: U32
  BirdMaterial

def bendy_bird_from_code_func(value):
  ((test0, test0_exact), (rest0, rest0_exact)) = U32.copy(U32.mod(value, bendy_u32_func(6n)))
  match U32.is_eq(test0, bendy_u32_func(0n)):
    case True{}: JelloBird{}
    case False{}:
      ((test1, test1_exact), (rest1, rest1_exact)) = U32.copy(rest0)
      match U32.is_eq(test1, bendy_u32_func(1n)):
        case True{}: RubberBird{}
        case False{}:
          ((test2, test2_exact), (rest2, rest2_exact)) = U32.copy(rest1)
          match U32.is_eq(test2, bendy_u32_func(2n)):
            case True{}: FurballBird{}
            case False{}:
              ((test3, test3_exact), (rest3, rest3_exact)) = U32.copy(rest2)
              match U32.is_eq(test3, bendy_u32_func(3n)):
                case True{}: StoneBird{}
                case False{}:
                  match U32.is_eq(rest3, bendy_u32_func(4n)):
                    case True{}: BubbleBird{}
                    case False{}: SpringBird{}

# Browser input enters here after JS has only captured the controls.  The
# selected bird, exact integer angle, strength, current block state, trajectory,
# collision window, damage and next state are all evaluated by generated Core.
assert bendy_browser_shot_func:
  forall bird_code: U32
  forall angle: U32
  forall strength: U32
  forall blocks: List<Block>
  forall shot_number: U32
  ShotResult

def bendy_browser_shot_func(bird_code, angle, strength, blocks, shot_number):
  bendy_shot_result_func(ShotRequest{bendy_bird_from_code_func(bird_code), angle, strength, blocks, shot_number})

assert bendy_birds_func:
  List<BirdSpec>

def bendy_birds_func():
  Con{BirdSpec{JelloBird{}, bendy_u32_func(6n), bendy_u32_func(230n), bendy_u32_func(50n), bendy_u32_func(245n), bendy_u32_func(0n)},
  Con{BirdSpec{RubberBird{}, bendy_u32_func(8n), bendy_u32_func(250n), bendy_u32_func(30n), bendy_u32_func(170n), bendy_u32_func(0n)},
  Con{BirdSpec{FurballBird{}, bendy_u32_func(5n), bendy_u32_func(120n), bendy_u32_func(90n), bendy_u32_func(200n), bendy_u32_func(255n)},
  Con{BirdSpec{StoneBird{}, bendy_u32_func(18n), bendy_u32_func(25n), bendy_u32_func(12n), bendy_u32_func(25n), bendy_u32_func(0n)},
  Con{BirdSpec{BubbleBird{}, bendy_u32_func(2n), bendy_u32_func(80n), bendy_u32_func(140n), bendy_u32_func(255n), bendy_u32_func(0n)},
  Con{BirdSpec{SpringBird{}, bendy_u32_func(10n), bendy_u32_func(255n), bendy_u32_func(20n), bendy_u32_func(190n), bendy_u32_func(0n)}, Nil{}}}}}}}

assert bendy_blocks_func:
  List<Block>

def bendy_blocks_func():
  Con{Block{0n, WoodBlock{}, bendy_u32_func(1040n), bendy_u32_func(180n), bendy_u32_func(0n), bendy_u32_func(80n), bendy_u32_func(360n), Standing{18n}},
  Con{Block{1n, GlassBlock{}, bendy_u32_func(1180n), bendy_u32_func(180n), bendy_u32_func(0n), bendy_u32_func(70n), bendy_u32_func(360n), Standing{7n}},
  Con{Block{2n, BrickBlock{}, bendy_u32_func(1320n), bendy_u32_func(180n), bendy_u32_func(0n), bendy_u32_func(100n), bendy_u32_func(360n), Standing{30n}},
  Con{Block{3n, IceBlock{}, bendy_u32_func(1110n), bendy_u32_func(570n), bendy_u32_func(0n), bendy_u32_func(420n), bendy_u32_func(70n), Standing{10n}},
  Con{Block{4n, MetalBlock{}, bendy_u32_func(1500n), bendy_u32_func(300n), bendy_u32_func(0n), bendy_u32_func(80n), bendy_u32_func(520n), Standing{50n}},
  Con{Block{5n, JellyBlock{}, bendy_u32_func(1660n), bendy_u32_func(220n), bendy_u32_func(0n), bendy_u32_func(180n), bendy_u32_func(280n), Standing{14n}},
  Con{Block{6n, BambooBlock{}, bendy_u32_func(1880n), bendy_u32_func(180n), bendy_u32_func(0n), bendy_u32_func(55n), bendy_u32_func(430n), Standing{12n}}, Nil{}}}}}}}}

assert bendy_preview_func:
  forall material: BirdMaterial
  forall angle: Nat
  forall strength: Nat
  ShotResult

def bendy_preview_func(material, angle, strength):
  bendy_shot_result_func(ShotRequest{material, bendy_u32_func(angle), bendy_u32_func(strength), bendy_blocks_func(), 0})

assert bendy_previews_func:
  List<ShotResult>

def bendy_previews_func():
  Con{bendy_preview_func(JelloBird{}, 28n, 3n),
  Con{bendy_preview_func(RubberBird{}, 36n, 3n),
  Con{bendy_preview_func(FurballBird{}, 44n, 2n),
  Con{bendy_preview_func(StoneBird{}, 24n, 4n),
  Con{bendy_preview_func(BubbleBird{}, 52n, 2n),
  Con{bendy_preview_func(SpringBird{}, 34n, 3n), Nil{}}}}}}}

assert bendy_reference_history_func:
  FlightHistory

def bendy_reference_history_func():
  FlightHistoryFrame{LaunchEvent{8n, 12n}, FlightHistoryFrame{GravityEvent{2n}, FlightHistoryFrame{DragEvent{1n}, FlightHistoryFrame{BounceEvent{6n}, FlightHistoryFrame{DeformEvent{4n}, FlightHistoryEnd{}}}}}}

assert bendy_self_check_func:
  Bool

def bendy_self_check_func():
  Bool.and(
    Nat.is_eq(List.length(BirdSpec, bendy_birds_func()), 6n),
    Bool.and(
      Nat.is_eq(List.length(Block, bendy_blocks_func()), 7n),
      Nat.is_eq(List.length(ShotResult, bendy_previews_func()), 6n)
    )
  )

assert main_value:
  Report

def main_value():
  Report{"Bendy Birds", bendy_birds_func(), bendy_blocks_func(), bendy_previews_func()}

assert main_accept_value:
  forall value: Report
  IO(Unit)

def main_accept_value(value):
  IO.print("Ready{}")

assert main:
  IO(Unit)

def main():
  main_accept_value(main_value!())
