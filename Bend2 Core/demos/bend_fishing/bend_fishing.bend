import Base
import ../bend_engine/fluids.bend as Fluids
import ../bend_engine/physics.bend as Physics
import ../../compat/list.bend as List
import ../../compat/nat.bend as Nat

# Bend Fishing: pure 3D fishing simulation with occult underwater models,
# bite timing, ripples, refraction, and multiple simultaneous fish.

# Types
# =====

type FishSpecies:
  RiverBass{}
  GoldenKoi{}
  BlueTuna{}
  MoonJelly{}
  ReefShark{}
  RibbonEel{}
  PufferFish{}
  Coelacanth{}
  MantaRay{}
  Seahorse{}

type FishSpeciesCopies:
  FishSpeciesCopies{left: FishSpecies, right: FishSpecies}

type FishDynamics:
  FishDynamics{x: Nat, y: Nat, depth: Nat, heading: Nat, speed: Nat}

type Fish:
  Fish{id: Nat, species: FishSpecies, size: Nat, dynamics: FishDynamics}

type FishPayload:
  FishPayload{id: Nat, species: FishSpecies, size: Nat}

type SwimEvent:
  CurrentPush{dx: Nat, dz: Nat}
  TailStroke{distance: Nat}
  Dive{amount: Nat}
  Rise{amount: Nat}
  Turn{amount: Nat}

type SwimHistory:
  SwimHistoryEnd{}
  SwimHistoryFrame{event: SwimEvent, tail: SwimHistory}

type BiteTiming:
  TooEarly{}
  EarlyNibble{}
  BiteWindow{}
  LateNibble{}
  TooLate{}

type CatchResult:
  Escaped{reason: U32}
  Caught{fish_id: Nat, species: FishSpecies}

type TimingOutcome:
  TimingOutcome{timing: BiteTiming, result: CatchResult, offset: U32}

type FishingFrame:
  FishingFrame{tick: U32, float_y: U32, ripple: U32, sink: U32, fish_phase: U32, refraction: U32, caustics: U32}

type VerifiedFishingFrames<-expected: Nat>:
  VerifiedFishingFrames{frames: List<FishingFrame>, -length_exact: {List.length(FishingFrame, frames) == expected : Nat}}

type FishModel:
  FishModel{id: Nat, species: FishSpecies, x: U32, y: U32, z: U32, size: U32, pattern: U32, heading: U32}

type WaterProfile:
  WaterProfile{clarity: U32, refraction: U32, fresnel: U32, absorption: U32, caustics: U32, ripple_layers: U32}

type FishingSpot:
  FishingSpot{name: String, fishes: List<FishModel>, frames: List<FishingFrame>, outcomes: List<TimingOutcome>, water: WaterProfile}

type FishingReport:
  FishingReport{title: String, spots: List<FishingSpot>, species_count: U32}

# This intrinsic shape makes an empty or over-populated pool unrepresentable.
type ActiveFish:
  OneActiveFish{first: FishModel}
  TwoActiveFish{first: FishModel, second: FishModel}

type FishingSession:
  FishingSession{
    seed: U32,
    cast_x: U32,
    cast_z: U32,
    active: ActiveFish,
    frames: List<FishingFrame>,
    bite_start: U32,
    bite_end: U32,
    water: WaterProfile
  }

type ReelFrame:
  ReelFrame{tick: U32, x: U32, y: U32, z: U32, tension: U32, ripple: U32, splash: U32, caught: Bool}

type VerifiedReelFrames<-expected: Nat>:
  VerifiedReelFrames{frames: List<ReelFrame>, -length_exact: {List.length(ReelFrame, frames) == expected : Nat}}

type ReelReport:
  ReelReport{timing: BiteTiming, result: CatchResult, animation: List<ReelFrame>, next: FishingSession, reel_tick: U32}

# Sixteen explicitly weighted buckets. The type fixes the denominator; the
# selector below chooses a field from this distribution using seed mod 16.
type SpeciesPool16:
  SpeciesPool16{
    b00: FishSpecies, b01: FishSpecies, b02: FishSpecies, b03: FishSpecies,
    b04: FishSpecies, b05: FishSpecies, b06: FishSpecies, b07: FishSpecies,
    b08: FishSpecies, b09: FishSpecies, b10: FishSpecies, b11: FishSpecies,
    b12: FishSpecies, b13: FishSpecies, b14: FishSpecies, b15: FishSpecies
  }

# Constants
# =========

assert fishing_u32_func:
  forall value: Nat
  U32

def fishing_u32_func(value):
  U32.from_nat(value)

# FishSpecies-Section
# ===================

assert fish_species_copy:
  forall value: FishSpecies
  FishSpeciesCopies

def fish_species_copy(value):
  match value:
    case RiverBass{}: FishSpeciesCopies{RiverBass{}, RiverBass{}}
    case GoldenKoi{}: FishSpeciesCopies{GoldenKoi{}, GoldenKoi{}}
    case BlueTuna{}: FishSpeciesCopies{BlueTuna{}, BlueTuna{}}
    case MoonJelly{}: FishSpeciesCopies{MoonJelly{}, MoonJelly{}}
    case ReefShark{}: FishSpeciesCopies{ReefShark{}, ReefShark{}}
    case RibbonEel{}: FishSpeciesCopies{RibbonEel{}, RibbonEel{}}
    case PufferFish{}: FishSpeciesCopies{PufferFish{}, PufferFish{}}
    case Coelacanth{}: FishSpeciesCopies{Coelacanth{}, Coelacanth{}}
    case MantaRay{}: FishSpeciesCopies{MantaRay{}, MantaRay{}}
    case Seahorse{}: FishSpeciesCopies{Seahorse{}, Seahorse{}}

assert fish_species_code:
  forall value: FishSpecies
  U32

def fish_species_code(value):
  match value:
    case RiverBass{}: fishing_u32_func(0n)
    case GoldenKoi{}: fishing_u32_func(1n)
    case BlueTuna{}: fishing_u32_func(2n)
    case MoonJelly{}: fishing_u32_func(3n)
    case ReefShark{}: fishing_u32_func(4n)
    case RibbonEel{}: fishing_u32_func(5n)
    case PufferFish{}: fishing_u32_func(6n)
    case Coelacanth{}: fishing_u32_func(7n)
    case MantaRay{}: fishing_u32_func(8n)
    case Seahorse{}: fishing_u32_func(9n)

# FishDynamics-Section
# ====================

assert fish_dynamics_step:
  forall value: FishDynamics
  forall event: SwimEvent
  FishDynamics

def fish_dynamics_step(value, event):
  match value event:
    case FishDynamics{x, y, depth, heading, speed} CurrentPush{dx, dz}:
      FishDynamics{Nat.add(x, dx), y, Nat.add(depth, dz), heading, speed}
    case FishDynamics{x, y, depth, heading, speed} TailStroke{distance}:
      ((distance_x, distance_x_exact), (distance_speed, distance_speed_exact)) = Nat.copy(distance)
      FishDynamics{Nat.add(x, distance_x), y, depth, heading, Nat.add(speed, distance_speed)}
    case FishDynamics{x, y, depth, heading, speed} Dive{amount}:
      FishDynamics{x, y, Nat.add(depth, amount), heading, speed}
    case FishDynamics{x, y, depth, heading, speed} Rise{amount}:
      FishDynamics{x, Nat.add(y, amount), depth, heading, speed}
    case FishDynamics{x, y, depth, heading, speed} Turn{amount}:
      FishDynamics{x, y, depth, Nat.add(heading, amount), speed}

# Fish-Section
# ============

assert fish_payload:
  forall value: Fish
  FishPayload

def fish_payload(value):
  match value:
    case Fish{id, species, size, dynamics}:
      FishPayload{id, species, size}

assert fish_step:
  forall value: Fish
  forall event: SwimEvent
  Fish

def fish_step(value, event):
  match value:
    case Fish{id, species, size, dynamics}:
      Fish{id, species, size, fish_dynamics_step(dynamics, event)}

assert fish_step_payload_theorem:
  forall value: Fish
  forall event: SwimEvent
  { fish_payload(fish_step(value, event)) == fish_payload(value) : FishPayload }

def fish_step_payload_theorem(value, event):
  match value:
    case Fish{id, species, size, dynamics}:
      {==}

# SwimHistory-Section
# ===================

assert swim_history_run:
  forall value: SwimHistory
  forall fish: Fish
  Fish

def swim_history_run(value, fish):
  match value:
    case SwimHistoryEnd{}:
      fish
    case SwimHistoryFrame{event, tail}:
      stepped = fish_step(fish, event)
      result = swim_history_run(tail, stepped)
      result

assert swim_history_payload_theorem_func:
  forall value: SwimHistory
  forall fish: Fish
  { fish_payload(swim_history_run(value, fish)) == fish_payload(fish) : FishPayload }

def swim_history_payload_theorem_func(value, fish):
  match value fish:
    case SwimHistoryEnd{} Fish{id, species, size, dynamics}:
      {==}
    case SwimHistoryFrame{event, tail} Fish{id, species, size, dynamics}:
      proof = swim_history_payload_theorem_func(tail, fish_step(Fish{id, species, size, dynamics}, event))
      proof

# BiteTiming-Section
# ==================

assert bite_timing_result:
  forall value: BiteTiming
  forall fish_id: Nat
  forall species: FishSpecies
  CatchResult

def bite_timing_result(value, fish_id, species):
  match value:
    case TooEarly{}:
      Escaped{fishing_u32_func(0n)}
    case EarlyNibble{}:
      Escaped{fishing_u32_func(1n)}
    case BiteWindow{}:
      Caught{fish_id, species}
    case LateNibble{}:
      Escaped{fishing_u32_func(2n)}
    case TooLate{}:
      Escaped{fishing_u32_func(3n)}

assert FishingTimingLawClaim_func:
  forall timing: BiteTiming
  forall fish_id: Nat
  forall species: FishSpecies
  Type

def FishingTimingLawClaim_func(timing, fish_id, species):
  match timing:
    case TooEarly{}:
      {bite_timing_result(timing, fish_id, species) == Escaped{fishing_u32_func(0n)} : CatchResult}
    case EarlyNibble{}:
      {bite_timing_result(timing, fish_id, species) == Escaped{fishing_u32_func(1n)} : CatchResult}
    case BiteWindow{}:
      {bite_timing_result(timing, fish_id, species) == Caught{fish_id, species} : CatchResult}
    case LateNibble{}:
      {bite_timing_result(timing, fish_id, species) == Escaped{fishing_u32_func(2n)} : CatchResult}
    case TooLate{}:
      {bite_timing_result(timing, fish_id, species) == Escaped{fishing_u32_func(3n)} : CatchResult}

assert bite_timing_law_theorem_func:
  forall value: BiteTiming
  forall fish_id: Nat
  forall species: FishSpecies
  FishingTimingLawClaim_func(value, fish_id, species)

def bite_timing_law_theorem_func(value, fish_id, species):
  match value:
    case TooEarly{}: {==}
    case EarlyNibble{}: {==}
    case BiteWindow{}: {==}
    case LateNibble{}: {==}
    case TooLate{}: {==}

assert bite_timing_copy:
  forall value: BiteTiming
  BiteTiming & BiteTiming

def bite_timing_copy(value):
  match value:
    case TooEarly{}: (TooEarly{}, TooEarly{})
    case EarlyNibble{}: (EarlyNibble{}, EarlyNibble{})
    case BiteWindow{}: (BiteWindow{}, BiteWindow{})
    case LateNibble{}: (LateNibble{}, LateNibble{})
    case TooLate{}: (TooLate{}, TooLate{})

assert bite_timing_is_caught:
  forall value: BiteTiming
  Bool

def bite_timing_is_caught(value):
  match value:
    case BiteWindow{}: True{}
    case TooEarly{}: False{}
    case EarlyNibble{}: False{}
    case LateNibble{}: False{}
    case TooLate{}: False{}

# Func-Section
# ============

assert fishing_fishes_payload_func:
  forall values: List<Fish>
  List<FishPayload>

def fishing_fishes_payload_func(values):
  match values:
    case Nil{}: Nil{}
    case Con{head, tail}: Con{fish_payload(head), fishing_fishes_payload_func(tail)}

assert fishing_fishes_step_claim_func:
  forall values: List<Fish>
  forall event: SwimEvent
  Physics.Claim<List<Fish>, output => { fishing_fishes_payload_func(output) == fishing_fishes_payload_func(values) : List<FishPayload> }>

def fishing_fishes_step_claim_func(values, event):
  match values:
    case Nil{}:
      Physics.Claim{Nil{}, {==}}
    case Con{Fish{id, species, size, dynamics}, tail}:
      match event:
        case CurrentPush{dx, dz}:
          ((dx_head, dx_head_exact), (dx_tail, dx_tail_exact)) = Nat.copy(dx)
          ((dz_head, dz_head_exact), (dz_tail, dz_tail_exact)) = Nat.copy(dz)
          match fishing_fishes_step_claim_func(tail, CurrentPush{dx_tail, dz_tail}):
            case Physics.Claim{tail_output, tail_proof}:
              Physics.Claim{Con{fish_step(Fish{id, species, size, dynamics}, CurrentPush{dx_head, dz_head}), tail_output}, Equal.cong(List<FishPayload>, List<FishPayload>, rest => Con{FishPayload{id, species, size}, rest}, fishing_fishes_payload_func(tail_output), fishing_fishes_payload_func(tail), tail_proof)}
        case TailStroke{distance}:
          ((head_distance, head_distance_exact), (tail_distance, tail_distance_exact)) = Nat.copy(distance)
          match fishing_fishes_step_claim_func(tail, TailStroke{tail_distance}):
            case Physics.Claim{tail_output, tail_proof}:
              Physics.Claim{Con{fish_step(Fish{id, species, size, dynamics}, TailStroke{head_distance}), tail_output}, Equal.cong(List<FishPayload>, List<FishPayload>, rest => Con{FishPayload{id, species, size}, rest}, fishing_fishes_payload_func(tail_output), fishing_fishes_payload_func(tail), tail_proof)}
        case Dive{amount}:
          ((head_amount, head_amount_exact), (tail_amount, tail_amount_exact)) = Nat.copy(amount)
          match fishing_fishes_step_claim_func(tail, Dive{tail_amount}):
            case Physics.Claim{tail_output, tail_proof}:
              Physics.Claim{Con{fish_step(Fish{id, species, size, dynamics}, Dive{head_amount}), tail_output}, Equal.cong(List<FishPayload>, List<FishPayload>, rest => Con{FishPayload{id, species, size}, rest}, fishing_fishes_payload_func(tail_output), fishing_fishes_payload_func(tail), tail_proof)}
        case Rise{amount}:
          ((head_amount, head_amount_exact), (tail_amount, tail_amount_exact)) = Nat.copy(amount)
          match fishing_fishes_step_claim_func(tail, Rise{tail_amount}):
            case Physics.Claim{tail_output, tail_proof}:
              Physics.Claim{Con{fish_step(Fish{id, species, size, dynamics}, Rise{head_amount}), tail_output}, Equal.cong(List<FishPayload>, List<FishPayload>, rest => Con{FishPayload{id, species, size}, rest}, fishing_fishes_payload_func(tail_output), fishing_fishes_payload_func(tail), tail_proof)}
        case Turn{amount}:
          ((head_amount, head_amount_exact), (tail_amount, tail_amount_exact)) = Nat.copy(amount)
          match fishing_fishes_step_claim_func(tail, Turn{tail_amount}):
            case Physics.Claim{tail_output, tail_proof}:
              Physics.Claim{Con{fish_step(Fish{id, species, size, dynamics}, Turn{head_amount}), tail_output}, Equal.cong(List<FishPayload>, List<FishPayload>, rest => Con{FishPayload{id, species, size}, rest}, fishing_fishes_payload_func(tail_output), fishing_fishes_payload_func(tail), tail_proof)}

assert fishing_u32_six_func:
  forall value: U32
  U32 & (U32 & (U32 & (U32 & (U32 & U32))))

def fishing_u32_six_func(value):
  ((a, a_exact), (r1, r1_exact)) = U32.copy(value)
  ((b, b_exact), (r2, r2_exact)) = U32.copy(r1)
  ((c, c_exact), (r3, r3_exact)) = U32.copy(r2)
  ((d, d_exact), (r4, r4_exact)) = U32.copy(r3)
  ((e, e_exact), (f, f_exact)) = U32.copy(r4)
  (a, (b, (c, (d, (e, f)))))

assert fishing_frame_func:
  forall index: U32
  forall seed: U32
  FishingFrame

def fishing_frame_func(index, seed):
  (i0, (i1, (i2, (i3, (i4, i5))))) = fishing_u32_six_func(index)
  ((seed_ripple, seed_ripple_exact), (seed_caustic, seed_caustic_exact)) = U32.copy(seed)
  FishingFrame{
    i0,
    U32.add(fishing_u32_func(420n), U32.mod(U32.mul(i1, fishing_u32_func(7n)), fishing_u32_func(34n))),
    U32.add(fishing_u32_func(12n), U32.mod(U32.mul(i2, fishing_u32_func(17n)), fishing_u32_func(180n))),
    U32.mod(U32.mul(i3, fishing_u32_func(9n)), fishing_u32_func(150n)),
    U32.mod(i4, fishing_u32_func(24n)),
    U32.add(fishing_u32_func(24n), U32.mod(U32.mul(i5, fishing_u32_func(11n)), fishing_u32_func(80n))),
    U32.add(fishing_u32_func(80n), U32.mod(seed_caustic, fishing_u32_func(150n)))
  }

assert fishing_verified_frames_func:
  forall fuel: Nat
  forall index: U32
  forall seed: U32
  VerifiedFishingFrames<fuel>

def fishing_verified_frames_func(fuel, index, seed):
  match fuel:
    case 0n:
      VerifiedFishingFrames{Nil{}, {==}}
    case 1n+pred:
      ((frame_index, frame_index_exact), (next_index, next_index_exact)) = U32.copy(index)
      ((frame_seed, frame_seed_exact), (tail_seed, tail_seed_exact)) = U32.copy(seed)
      match fishing_verified_frames_func(pred, U32.inc(next_index), U32.add(tail_seed, fishing_u32_func(13n))):
        case VerifiedFishingFrames{tail, tail_exact}:
          frame = fishing_frame_func(frame_index, frame_seed)
          VerifiedFishingFrames{Con{frame, tail}, Equal.cong(Nat, Nat, length => 1n+length, List.length(FishingFrame, tail), pred, tail_exact)}

assert fishing_frames_func:
  forall fuel: Nat
  forall seed: U32
  List<FishingFrame>

def fishing_frames_func(fuel, seed):
  match fishing_verified_frames_func(fuel, 0, seed):
    case VerifiedFishingFrames{frames, length_exact}:
      frames

assert fishing_frame_bite_dispatch_func:
  forall is_bite: Bool
  forall value: FishingFrame
  FishingFrame

def fishing_frame_bite_dispatch_func(is_bite, value):
  match is_bite value:
    case True{} FishingFrame{tick, float_y, ripple, sink, fish_phase, refraction, caustics}:
      FishingFrame{tick, fishing_u32_func(365n), U32.add(ripple, fishing_u32_func(110n)), fishing_u32_func(145n), fish_phase, refraction, caustics}
    case False{} other:
      other

assert fishing_session_frame_func:
  forall index: U32
  forall bite_start: U32
  forall bite_end: U32
  forall seed: U32
  FishingFrame

def fishing_session_frame_func(index, bite_start, bite_end, seed):
  ((index_frame, index_frame_exact), (index_tests, index_tests_exact)) = U32.copy(index)
  ((index_start, index_start_exact), (index_end, index_end_exact)) = U32.copy(index_tests)
  fishing_frame_bite_dispatch_func(
    Bool.and(U32.is_le(bite_start, index_start), U32.is_le(index_end, bite_end)),
    fishing_frame_func(index_frame, seed)
  )

assert fishing_verified_session_frames_func:
  forall fuel: Nat
  forall index: U32
  forall bite_start: U32
  forall bite_end: U32
  forall seed: U32
  VerifiedFishingFrames<fuel>

def fishing_verified_session_frames_func(fuel, index, bite_start, bite_end, seed):
  match fuel:
    case 0n:
      VerifiedFishingFrames{Nil{}, {==}}
    case 1n+pred:
      ((index_head, index_head_exact), (index_tail, index_tail_exact)) = U32.copy(index)
      ((start_head, start_head_exact), (start_tail, start_tail_exact)) = U32.copy(bite_start)
      ((end_head, end_head_exact), (end_tail, end_tail_exact)) = U32.copy(bite_end)
      ((seed_head, seed_head_exact), (seed_tail, seed_tail_exact)) = U32.copy(seed)
      match fishing_verified_session_frames_func(pred, U32.inc(index_tail), start_tail, end_tail, U32.add(seed_tail, fishing_u32_func(13n))):
        case VerifiedFishingFrames{tail, tail_exact}:
          VerifiedFishingFrames{
            Con{fishing_session_frame_func(index_head, start_head, end_head, seed_head), tail},
            Equal.cong(Nat, Nat, length => 1n+length, List.length(FishingFrame, tail), pred, tail_exact)
          }

assert fishing_session_frames_func:
  forall fuel: Nat
  forall bite_start: U32
  forall bite_end: U32
  forall seed: U32
  List<FishingFrame>

def fishing_session_frames_func(fuel, bite_start, bite_end, seed):
  match fishing_verified_session_frames_func(fuel, 0, bite_start, bite_end, seed):
    case VerifiedFishingFrames{frames, length_exact}: frames

assert fishing_models_func:
  List<FishModel>

def fishing_models_func():
  Con{FishModel{0n, GoldenKoi{}, fishing_u32_func(450n), fishing_u32_func(280n), fishing_u32_func(620n), fishing_u32_func(90n), fishing_u32_func(1n), fishing_u32_func(20n)},
  Con{FishModel{1n, RiverBass{}, fishing_u32_func(650n), fishing_u32_func(300n), fishing_u32_func(720n), fishing_u32_func(115n), fishing_u32_func(2n), fishing_u32_func(190n)},
  Con{FishModel{2n, RibbonEel{}, fishing_u32_func(820n), fishing_u32_func(240n), fishing_u32_func(540n), fishing_u32_func(145n), fishing_u32_func(3n), fishing_u32_func(70n)},
  Con{FishModel{3n, PufferFish{}, fishing_u32_func(980n), fishing_u32_func(330n), fishing_u32_func(680n), fishing_u32_func(80n), fishing_u32_func(4n), fishing_u32_func(260n)},
  Con{FishModel{4n, Coelacanth{}, fishing_u32_func(1160n), fishing_u32_func(250n), fishing_u32_func(760n), fishing_u32_func(165n), fishing_u32_func(5n), fishing_u32_func(140n)},
  Con{FishModel{5n, MantaRay{}, fishing_u32_func(1380n), fishing_u32_func(210n), fishing_u32_func(590n), fishing_u32_func(185n), fishing_u32_func(6n), fishing_u32_func(330n)},
  Con{FishModel{6n, Seahorse{}, fishing_u32_func(1540n), fishing_u32_func(340n), fishing_u32_func(640n), fishing_u32_func(55n), fishing_u32_func(7n), fishing_u32_func(80n)}, Nil{}}}}}}}}

assert fishing_outcomes_func:
  List<TimingOutcome>

def fishing_outcomes_func():
  Con{TimingOutcome{TooEarly{}, bite_timing_result(TooEarly{}, 0n, GoldenKoi{}), fishing_u32_func(0n)},
  Con{TimingOutcome{EarlyNibble{}, bite_timing_result(EarlyNibble{}, 0n, GoldenKoi{}), fishing_u32_func(1n)},
  Con{TimingOutcome{BiteWindow{}, bite_timing_result(BiteWindow{}, 0n, GoldenKoi{}), fishing_u32_func(2n)},
  Con{TimingOutcome{LateNibble{}, bite_timing_result(LateNibble{}, 0n, GoldenKoi{}), fishing_u32_func(3n)},
  Con{TimingOutcome{TooLate{}, bite_timing_result(TooLate{}, 0n, GoldenKoi{}), fishing_u32_func(4n)}, Nil{}}}}}}

assert fishing_water_profile_func:
  WaterProfile

def fishing_water_profile_func():
  match Fluids.fluids_default_water_func():
    case Fluids.WaterMaterial{shallow, deep, clarity, refraction, fresnel, absorption, caustics, roughness}:
      WaterProfile{clarity, refraction, fresnel, absorption, caustics, fishing_u32_func(12n)}

assert fishing_species_pool_func:
  SpeciesPool16

def fishing_species_pool_func():
  SpeciesPool16{
    RiverBass{}, RiverBass{}, RiverBass{},
    GoldenKoi{}, GoldenKoi{},
    BlueTuna{}, BlueTuna{},
    MoonJelly{}, ReefShark{},
    RibbonEel{}, RibbonEel{},
    PufferFish{}, PufferFish{},
    Coelacanth{}, MantaRay{}, Seahorse{}
  }

assert fishing_species_bucket_func:
  forall value: U32
  FishSpecies

def fishing_species_bucket_func(value):
  ((t2, t2_exact), (r2, r2_exact)) = U32.copy(U32.mod(value, fishing_u32_func(16n)))
  match U32.is_le(t2, fishing_u32_func(2n)):
    case True{}: RiverBass{}
    case False{}:
      ((t4, t4_exact), (r4, r4_exact)) = U32.copy(r2)
      match U32.is_le(t4, fishing_u32_func(4n)):
        case True{}: GoldenKoi{}
        case False{}:
          ((t6, t6_exact), (r6, r6_exact)) = U32.copy(r4)
          match U32.is_le(t6, fishing_u32_func(6n)):
            case True{}: BlueTuna{}
            case False{}:
              ((t7, t7_exact), (r7, r7_exact)) = U32.copy(r6)
              match U32.is_le(t7, fishing_u32_func(7n)):
                case True{}: MoonJelly{}
                case False{}:
                  ((t8, t8_exact), (r8, r8_exact)) = U32.copy(r7)
                  match U32.is_le(t8, fishing_u32_func(8n)):
                    case True{}: ReefShark{}
                    case False{}:
                      ((t10, t10_exact), (r10, r10_exact)) = U32.copy(r8)
                      match U32.is_le(t10, fishing_u32_func(10n)):
                        case True{}: RibbonEel{}
                        case False{}:
                          ((t12, t12_exact), (r12, r12_exact)) = U32.copy(r10)
                          match U32.is_le(t12, fishing_u32_func(12n)):
                            case True{}: PufferFish{}
                            case False{}:
                              ((t13, t13_exact), (r13, r13_exact)) = U32.copy(r12)
                              match U32.is_le(t13, fishing_u32_func(13n)):
                                case True{}: Coelacanth{}
                                case False{}:
                                  match U32.is_le(r13, fishing_u32_func(14n)):
                                    case True{}: MantaRay{}
                                    case False{}: Seahorse{}

assert fishing_model_from_seed_func:
  forall id: Nat
  forall seed: U32
  forall cast_x: U32
  forall cast_z: U32
  FishModel

def fishing_model_from_seed_func(id, seed, cast_x, cast_z):
  (s0, (s1, (s2, (s3, (s4, s5))))) = fishing_u32_six_func(seed)
  ((s1_position, s1_position_exact), (s1_heading, s1_heading_exact)) = U32.copy(s1)
  FishModel{
    id,
    fishing_species_bucket_func(s0),
    U32.add(cast_x, U32.mod(s1_position, fishing_u32_func(180n))),
    U32.add(fishing_u32_func(250n), U32.mod(s2, fishing_u32_func(130n))),
    U32.add(cast_z, U32.mod(s3, fishing_u32_func(160n))),
    U32.add(fishing_u32_func(70n), U32.mod(s4, fishing_u32_func(120n))),
    U32.mod(s5, fishing_u32_func(8n)),
    U32.mod(U32.mul(s1_heading, fishing_u32_func(19n)), fishing_u32_func(360n))
  }

assert fishing_active_dispatch_func:
  forall is_one: Bool
  forall seed: U32
  forall cast_x: U32
  forall cast_z: U32
  ActiveFish

def fishing_active_dispatch_func(is_one, seed, cast_x, cast_z):
  match is_one:
    case True{}:
      OneActiveFish{fishing_model_from_seed_func(0n, seed, cast_x, cast_z)}
    case False{}:
      ((seed_first, seed_first_exact), (seed_second, seed_second_exact)) = U32.copy(seed)
      ((x_first, x_first_exact), (x_second, x_second_exact)) = U32.copy(cast_x)
      ((z_first, z_first_exact), (z_second, z_second_exact)) = U32.copy(cast_z)
      TwoActiveFish{
        fishing_model_from_seed_func(0n, seed_first, x_first, z_first),
        fishing_model_from_seed_func(1n, U32.add(seed_second, fishing_u32_func(97n)), x_second, z_second)
      }

assert fishing_active_from_seed_func:
  forall seed: U32
  forall cast_x: U32
  forall cast_z: U32
  ActiveFish

def fishing_active_from_seed_func(seed, cast_x, cast_z):
  ((seed_test, seed_test_exact), (seed_live, seed_live_exact)) = U32.copy(seed)
  fishing_active_dispatch_func(U32.is_eq(U32.mod(seed_test, fishing_u32_func(3n)), 0), seed_live, cast_x, cast_z)

assert fishing_active_count_func:
  forall value: ActiveFish
  Nat

def fishing_active_count_func(value):
  match value:
    case OneActiveFish{first}: 1n
    case TwoActiveFish{first, second}: 2n

assert FishingActiveCountClaim_func:
  forall value: ActiveFish
  Type

def FishingActiveCountClaim_func(value):
  match value:
    case OneActiveFish{first}: {fishing_active_count_func(value) == 1n : Nat}
    case TwoActiveFish{first, second}: {fishing_active_count_func(value) == 2n : Nat}

assert fishing_active_count_theorem_func:
  forall value: ActiveFish
  FishingActiveCountClaim_func(value)

def fishing_active_count_theorem_func(value):
  match value:
    case OneActiveFish{first}: {==}
    case TwoActiveFish{first, second}: {==}

assert fishing_active_primary_func:
  forall value: ActiveFish
  FishModel

def fishing_active_primary_func(value):
  match value:
    case OneActiveFish{first}: first
    case TwoActiveFish{first, second}: first

assert fishing_session_func:
  forall seed: U32
  forall cast_x: U32
  forall cast_z: U32
  FishingSession

def fishing_session_func(seed, cast_x, cast_z):
  (seed_output, (seed_active, (seed_frames, (seed_bite, (seed_spare, seed_keep))))) = fishing_u32_six_func(seed)
  ((x_output, x_output_exact), (x_active, x_active_exact)) = U32.copy(cast_x)
  ((z_output, z_output_exact), (z_active, z_active_exact)) = U32.copy(cast_z)
  (bite_output, (bite_frames, (bite_end_base, (bite_spare_a, (bite_spare_b, bite_spare_c))))) = fishing_u32_six_func(U32.add(fishing_u32_func(40n), U32.mod(seed_bite, fishing_u32_func(36n))))
  ((bite_end_output, bite_end_output_exact), (bite_end_frames, bite_end_frames_exact)) = U32.copy(U32.add(bite_end_base, fishing_u32_func(7n)))
  FishingSession{
    seed_output,
    x_output,
    z_output,
    fishing_active_from_seed_func(seed_active, x_active, z_active),
    fishing_session_frames_func(120n, bite_frames, bite_end_frames, seed_frames),
    bite_output,
    bite_end_output,
    fishing_water_profile_func()
  }

assert fishing_timing_after_start_func:
  forall in_window: Bool
  forall tick: U32
  forall bite_end: U32
  BiteTiming

def fishing_timing_after_start_func(in_window, tick, bite_end):
  match in_window:
    case True{}: BiteWindow{}
    case False{}:
      match U32.is_le(tick, U32.add(bite_end, fishing_u32_func(12n))):
        case True{}: LateNibble{}
        case False{}: TooLate{}

assert fishing_timing_before_start_func:
  forall before: Bool
  forall tick: U32
  forall bite_start: U32
  forall bite_end: U32
  BiteTiming

def fishing_timing_before_start_func(before, tick, bite_start, bite_end):
  match before:
    case True{}:
      match U32.is_le(U32.add(tick, fishing_u32_func(12n)), bite_start):
        case True{}: TooEarly{}
        case False{}: EarlyNibble{}
    case False{}:
      ((tick_test, tick_test_exact), (tick_live, tick_live_exact)) = U32.copy(tick)
      ((end_test, end_test_exact), (end_live, end_live_exact)) = U32.copy(bite_end)
      fishing_timing_after_start_func(U32.is_le(tick_test, end_test), tick_live, end_live)

assert fishing_timing_func:
  forall tick: U32
  forall bite_start: U32
  forall bite_end: U32
  BiteTiming

def fishing_timing_func(tick, bite_start, bite_end):
  ((tick_test, tick_test_exact), (tick_live, tick_live_exact)) = U32.copy(tick)
  ((start_test, start_test_exact), (start_live, start_live_exact)) = U32.copy(bite_start)
  fishing_timing_before_start_func(U32.is_lt(tick_test, start_test), tick_live, start_live, bite_end)

assert fishing_reel_frame_dispatch_func:
  forall caught: Bool
  forall index: U32
  forall cast_x: U32
  forall cast_z: U32
  ReelFrame

def fishing_reel_frame_dispatch_func(caught, index, cast_x, cast_z):
  match caught:
    case True{}:
      (i0, (i1, (i2, (i3, (i4, i5))))) = fishing_u32_six_func(index)
      ReelFrame{i0, cast_x, U32.add(fishing_u32_func(180n), U32.mul(i1, fishing_u32_func(8n))), cast_z, U32.add(fishing_u32_func(90n), U32.mul(i2, fishing_u32_func(3n))), U32.sub(fishing_u32_func(220n), U32.mul(i3, fishing_u32_func(4n))), U32.add(fishing_u32_func(40n), U32.mul(i4, fishing_u32_func(5n))), True{}}
    case False{}:
      (i0, (i1, (i2, (i3, (i4, i5))))) = fishing_u32_six_func(index)
      ReelFrame{i0, U32.add(cast_x, U32.mul(i1, fishing_u32_func(5n))), fishing_u32_func(260n), U32.add(cast_z, U32.mul(i2, fishing_u32_func(3n))), U32.sub(fishing_u32_func(80n), i3), U32.add(fishing_u32_func(50n), U32.mul(i4, fishing_u32_func(3n))), U32.add(fishing_u32_func(20n), i5), False{}}

assert fishing_verified_reel_frames_func:
  forall fuel: Nat
  forall index: U32
  forall caught: Bool
  forall cast_x: U32
  forall cast_z: U32
  VerifiedReelFrames<fuel>

def fishing_verified_reel_frames_func(fuel, index, caught, cast_x, cast_z):
  match fuel:
    case 0n:
      VerifiedReelFrames{Nil{}, {==}}
    case 1n+pred:
      match caught:
        case True{}:
          ((index_head, index_head_exact), (index_tail, index_tail_exact)) = U32.copy(index)
          ((x_head, x_head_exact), (x_tail, x_tail_exact)) = U32.copy(cast_x)
          ((z_head, z_head_exact), (z_tail, z_tail_exact)) = U32.copy(cast_z)
          match fishing_verified_reel_frames_func(pred, U32.inc(index_tail), True{}, x_tail, z_tail):
            case VerifiedReelFrames{tail, tail_exact}:
              VerifiedReelFrames{Con{fishing_reel_frame_dispatch_func(True{}, index_head, x_head, z_head), tail}, Equal.cong(Nat, Nat, length => 1n+length, List.length(ReelFrame, tail), pred, tail_exact)}
        case False{}:
          ((index_head, index_head_exact), (index_tail, index_tail_exact)) = U32.copy(index)
          ((x_head, x_head_exact), (x_tail, x_tail_exact)) = U32.copy(cast_x)
          ((z_head, z_head_exact), (z_tail, z_tail_exact)) = U32.copy(cast_z)
          match fishing_verified_reel_frames_func(pred, U32.inc(index_tail), False{}, x_tail, z_tail):
            case VerifiedReelFrames{tail, tail_exact}:
              VerifiedReelFrames{Con{fishing_reel_frame_dispatch_func(False{}, index_head, x_head, z_head), tail}, Equal.cong(Nat, Nat, length => 1n+length, List.length(ReelFrame, tail), pred, tail_exact)}

assert fishing_reel_frames_func:
  forall fuel: Nat
  forall caught: Bool
  forall cast_x: U32
  forall cast_z: U32
  List<ReelFrame>

def fishing_reel_frames_func(fuel, caught, cast_x, cast_z):
  match fishing_verified_reel_frames_func(fuel, 0, caught, cast_x, cast_z):
    case VerifiedReelFrames{frames, length_exact}: frames

assert fishing_reel_primary_func:
  forall seed: U32
  forall cast_x: U32
  forall cast_z: U32
  forall bite_start: U32
  forall bite_end: U32
  forall fish_id: Nat
  forall species: FishSpecies
  forall reel_tick: U32
  ReelReport

def fishing_reel_primary_func(seed, cast_x, cast_z, bite_start, bite_end, fish_id, species, reel_tick):
  ((tick_timing, tick_timing_exact), (tick_output, tick_output_exact)) = U32.copy(reel_tick)
  ((x_animation, x_animation_exact), (x_next, x_next_exact)) = U32.copy(cast_x)
  ((z_animation, z_animation_exact), (z_next, z_next_exact)) = U32.copy(cast_z)
  (timing_output, timing_rest) = bite_timing_copy(fishing_timing_func(tick_timing, bite_start, bite_end))
  (timing_caught, timing_result) = bite_timing_copy(timing_rest)
  caught = bite_timing_is_caught(timing_caught)
  ReelReport{
    timing_output,
    bite_timing_result(timing_result, fish_id, species),
    fishing_reel_frames_func(48n, caught, x_animation, z_animation),
    fishing_session_func(U32.add(seed, fishing_u32_func(101n)), x_next, z_next),
    tick_output
  }

assert fishing_reel_func:
  forall session: FishingSession
  forall reel_tick: U32
  ReelReport

def fishing_reel_func(session, reel_tick):
  match session:
    case FishingSession{seed, cast_x, cast_z, OneActiveFish{FishModel{id, species, x, y, z, size, pattern, heading}}, frames, bite_start, bite_end, water}:
      fishing_reel_primary_func(seed, cast_x, cast_z, bite_start, bite_end, id, species, reel_tick)
    case FishingSession{seed, cast_x, cast_z, TwoActiveFish{FishModel{id, species, x, y, z, size, pattern, heading}, second}, frames, bite_start, bite_end, water}:
      fishing_reel_primary_func(seed, cast_x, cast_z, bite_start, bite_end, id, species, reel_tick)

assert fishing_spot_func:
  FishingSpot

def fishing_spot_func():
  FishingSpot{"Prismatic Lagoon", fishing_models_func(), fishing_frames_func(120n, fishing_u32_func(731n)), fishing_outcomes_func(), fishing_water_profile_func()}

assert fishing_reference_history_func:
  SwimHistory

def fishing_reference_history_func():
  SwimHistoryFrame{CurrentPush{2n, 1n}, SwimHistoryFrame{TailStroke{3n}, SwimHistoryFrame{Dive{2n}, SwimHistoryFrame{Turn{4n}, SwimHistoryFrame{Rise{1n}, SwimHistoryEnd{}}}}}}

assert fishing_self_check_func:
  Bool

def fishing_self_check_func():
  Bool.and(
    Nat.is_eq(List.length(FishModel, fishing_models_func()), 7n),
    Bool.and(
      Nat.is_eq(List.length(FishingFrame, fishing_frames_func(120n, fishing_u32_func(731n))), 120n),
      Nat.is_eq(List.length(TimingOutcome, fishing_outcomes_func()), 5n)
    )
  )

assert main_value:
  FishingReport

def main_value():
  FishingReport{"Bend Fishing", Con{fishing_spot_func(), Nil{}}, fishing_u32_func(10n)}

assert main_accept_value:
  forall value: FishingReport
  IO(Unit)

def main_accept_value(value):
  IO.print("Ready{}")

assert main:
  IO(Unit)

def main():
  main_accept_value(main_value!())
