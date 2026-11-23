import Base
import ../bend_engine/fluids.bend as Fluids
import ../bend_engine/physics.bend as Physics
import ../bend_engine/light.bend as Light
import ../../compat/list.bend as List
import ../../compat/nat.bend as Nat

# Bend Aquarium: a pure rectangular reef-aquarium simulation. Core emits fish,
# coral, equipment and coupled water/light frames; WebGL only renders them.

# Types
# =====

type AquariumFishKind:
  Clownfish{}
  BlueTang{}
  MoorishIdol{}
  RoyalGramma{}
  MandarinDragonet{}
  Butterflyfish{}
  Angelfish{}
  Firefish{}
  Chromis{}
  YellowTang{}
  CleanerWrasse{}
  Cardinalfish{}

type EquipmentKind:
  BubbleMaker{}
  CanisterFilter{}
  HangingLight{}
  Heater{}
  ReturnJet{}

type Equipment:
  Equipment{id: Nat, kind: EquipmentKind}

type EquipmentPayload:
  EquipmentPayload{id: Nat, kind: EquipmentKind}

type TankDynamics:
  TankDynamics{wave_energy: Nat, bubble_energy: Nat, filter_energy: Nat, heat: Nat}

type TankState:
  TankState{equipment: List<Equipment>, dynamics: TankDynamics}

type TankPayload:
  TankPayload{equipment: List<EquipmentPayload>}

type TankEvent:
  FishStroke{wave: Nat, caustic: Nat}
  BubblePulse{wave: Nat, foam: Nat}
  FilterFlow{wave: Nat, foam: Nat}
  LightHeat{heat: Nat}

type TankHistory:
  TankHistoryEnd{}
  TankHistoryFrame{event: TankEvent, tail: TankHistory}

type TankForcing:
  TankForcing{wave: Nat, foam: Nat, caustic: Nat, heat: Nat}

type FishModel:
  FishModel{id: Nat, kind: AquariumFishKind, x: U32, y: U32, z: U32, size: U32, color_a: U32, color_b: U32, pattern: U32}

type CoralKind:
  EuphylliaParancora{}
  EuphylliaGlabrescens{}
  EuphylliaAncora{}
  CoralliumRubrum{}
  AcroporaBranch{}
  BrainCoral{}
  PlateCoral{}
  Anemone{}

type CoralModel:
  CoralModel{id: Nat, kind: CoralKind, x: U32, y: U32, z: U32, size: U32, color: U32, polyps: U32, sway: U32, fluorescence: U32}

type CoralMotionProfile:
  CoralMotionProfile{id: Nat, current_response: U32, tissue_bend: U32, polyp_coupling: U32}

type AquariumFrame:
  AquariumFrame{tick: U32, current_x: U32, current_z: U32, wave: U32, bubbles: U32, caustics: U32, refraction: U32, filter_flow: U32, fish_phase: U32}

type VerifiedAquariumFrames<-expected: Nat>:
  VerifiedAquariumFrames{frames: List<AquariumFrame>, -length_exact: {List.length(AquariumFrame, frames) == expected : Nat}}

type TankGeometry:
  TankGeometry{width: U32, height: U32, depth: U32, glass: U32, waterline: U32}

type AquariumEquipment:
  AquariumEquipment{bubble_makers: U32, filter_power: U32, light_width: U32, light_intensity: U32, return_jets: U32}

type AquariumReport:
  AquariumReport{title: String, tank: TankGeometry, fish: List<FishModel>, coral: List<CoralModel>, equipment: AquariumEquipment, water: List<AquariumFrame>, frame_count: Nat}

# Constants
# =========

assert aquarium_u32_func:
  forall value: Nat
  U32

def aquarium_u32_func(value):
  U32.from_nat(value)

# EquipmentKind-Section
# =====================

assert equipment_kind_copy:
  forall value: EquipmentKind
  EquipmentKind & EquipmentKind

def equipment_kind_copy(value):
  match value:
    case BubbleMaker{}: (BubbleMaker{}, BubbleMaker{})
    case CanisterFilter{}: (CanisterFilter{}, CanisterFilter{})
    case HangingLight{}: (HangingLight{}, HangingLight{})
    case Heater{}: (Heater{}, Heater{})
    case ReturnJet{}: (ReturnJet{}, ReturnJet{})

# Equipment-Section
# =================

assert equipment_payload:
  forall value: Equipment
  EquipmentPayload

def equipment_payload(value):
  match value:
    case Equipment{id, kind}:
      EquipmentPayload{id, kind}

# TankDynamics-Section
# ====================

assert tank_dynamics_step:
  forall value: TankDynamics
  forall event: TankEvent
  TankDynamics

def tank_dynamics_step(value, event):
  match value event:
    case TankDynamics{wave, bubbles, filter, heat} FishStroke{stroke_wave, caustic}:
      TankDynamics{Nat.add(wave, stroke_wave), bubbles, filter, Nat.add(heat, caustic)}
    case TankDynamics{wave, bubbles, filter, heat} BubblePulse{bubble_wave, foam}:
      TankDynamics{Nat.add(wave, bubble_wave), Nat.add(bubbles, foam), filter, heat}
    case TankDynamics{wave, bubbles, filter, heat} FilterFlow{filter_wave, foam}:
      TankDynamics{Nat.add(wave, filter_wave), bubbles, Nat.add(filter, foam), heat}
    case TankDynamics{wave, bubbles, filter, heat} LightHeat{added_heat}:
      TankDynamics{wave, bubbles, filter, Nat.add(heat, added_heat)}

# TankState-Section
# =================

assert tank_state_step:
  forall value: TankState
  forall event: TankEvent
  TankState

def tank_state_step(value, event):
  match value:
    case TankState{equipment, dynamics}:
      TankState{equipment, tank_dynamics_step(dynamics, event)}

# TankEvent-Section
# =================

assert tank_event_forcing:
  forall value: TankEvent
  TankForcing

def tank_event_forcing(value):
  match value:
    case FishStroke{wave, caustic}:
      TankForcing{wave, 0n, caustic, 0n}
    case BubblePulse{wave, foam}:
      TankForcing{wave, foam, 0n, 0n}
    case FilterFlow{wave, foam}:
      TankForcing{wave, foam, 0n, 0n}
    case LightHeat{heat}:
      TankForcing{0n, 0n, 0n, heat}

assert AquariumEventLawClaim_func:
  forall event: TankEvent
  Type

def AquariumEventLawClaim_func(event):
  match event:
    case FishStroke{wave, caustic}:
      {tank_event_forcing(event) == TankForcing{wave, 0n, caustic, 0n} : TankForcing}
    case BubblePulse{wave, foam}:
      {tank_event_forcing(event) == TankForcing{wave, foam, 0n, 0n} : TankForcing}
    case FilterFlow{wave, foam}:
      {tank_event_forcing(event) == TankForcing{wave, foam, 0n, 0n} : TankForcing}
    case LightHeat{heat}:
      {tank_event_forcing(event) == TankForcing{0n, 0n, 0n, heat} : TankForcing}

assert tank_event_law_theorem:
  forall value: TankEvent
  AquariumEventLawClaim_func(value)

def tank_event_law_theorem(value):
  match value:
    case FishStroke{wave, caustic}: {==}
    case BubblePulse{wave, foam}: {==}
    case FilterFlow{wave, foam}: {==}
    case LightHeat{heat}: {==}

# TankHistory-Section
# ===================

assert AquariumHistoryPhysicsClaim_func:
  forall history: TankHistory
  Type

def AquariumHistoryPhysicsClaim_func(history):
  match history:
    case TankHistoryEnd{}:
      Unit
    case TankHistoryFrame{event, tail}:
      AquariumEventLawClaim_func(event) & AquariumHistoryPhysicsClaim_func(tail)

assert tank_history_physics_theorem_func:
  forall value: TankHistory
  AquariumHistoryPhysicsClaim_func(value)

def tank_history_physics_theorem_func(value):
  match value:
    case TankHistoryEnd{}:
      Unit{}
    case TankHistoryFrame{event, tail}:
      (tank_event_law_theorem(event), tank_history_physics_theorem_func(tail))

# Func-Section
# ============

assert aquarium_equipment_payloads_func:
  forall values: List<Equipment>
  List<EquipmentPayload>

def aquarium_equipment_payloads_func(values):
  match values:
    case Nil{}: Nil{}
    case Con{head, tail}: Con{equipment_payload(head), aquarium_equipment_payloads_func(tail)}

assert aquarium_tank_payload_func:
  forall value: TankState
  TankPayload

def aquarium_tank_payload_func(value):
  match value:
    case TankState{equipment, dynamics}:
      TankPayload{aquarium_equipment_payloads_func(equipment)}

assert aquarium_tank_step_payload_theorem_func:
  forall value: TankState
  forall event: TankEvent
  { aquarium_tank_payload_func(tank_state_step(value, event)) == aquarium_tank_payload_func(value) : TankPayload }

def aquarium_tank_step_payload_theorem_func(value, event):
  match value:
    case TankState{equipment, dynamics}:
      {==}

assert aquarium_tank_history_run_func:
  forall history: TankHistory
  forall state: TankState
  TankState

def aquarium_tank_history_run_func(history, state):
  match history:
    case TankHistoryEnd{}:
      state
    case TankHistoryFrame{event, tail}:
      stepped = tank_state_step(state, event)
      result = aquarium_tank_history_run_func(tail, stepped)
      result

assert aquarium_tank_history_payload_theorem_func:
  forall history: TankHistory
  forall state: TankState
  { aquarium_tank_payload_func(aquarium_tank_history_run_func(history, state)) == aquarium_tank_payload_func(state) : TankPayload }

def aquarium_tank_history_payload_theorem_func(history, state):
  match history state:
    case TankHistoryEnd{} TankState{equipment, dynamics}:
      {==}
    case TankHistoryFrame{event, tail} TankState{equipment, dynamics}:
      proof = aquarium_tank_history_payload_theorem_func(tail, tank_state_step(TankState{equipment, dynamics}, event))
      proof

assert aquarium_u32_nine_func:
  forall value: U32
  U32 & (U32 & (U32 & (U32 & (U32 & (U32 & (U32 & (U32 & U32)))))))

def aquarium_u32_nine_func(value):
  ((a, a_exact), (r1, r1_exact)) = U32.copy(value)
  ((b, b_exact), (r2, r2_exact)) = U32.copy(r1)
  ((c, c_exact), (r3, r3_exact)) = U32.copy(r2)
  ((d, d_exact), (r4, r4_exact)) = U32.copy(r3)
  ((e, e_exact), (r5, r5_exact)) = U32.copy(r4)
  ((f, f_exact), (r6, r6_exact)) = U32.copy(r5)
  ((g, g_exact), (r7, r7_exact)) = U32.copy(r6)
  ((h, h_exact), (i, i_exact)) = U32.copy(r7)
  (a, (b, (c, (d, (e, (f, (g, (h, i))))))))

assert aquarium_frame_func:
  forall index: U32
  forall seed: U32
  AquariumFrame

def aquarium_frame_func(index, seed):
  (i0, (i1, (i2, (i3, (i4, (i5, (i6, (i7, i8)))))))) = aquarium_u32_nine_func(index)
  AquariumFrame{
    i0,
    U32.mod(U32.mul(i1, aquarium_u32_func(7n)), aquarium_u32_func(160n)),
    U32.mod(U32.mul(i2, aquarium_u32_func(11n)), aquarium_u32_func(190n)),
    U32.add(aquarium_u32_func(20n), U32.mod(U32.mul(i3, aquarium_u32_func(13n)), aquarium_u32_func(90n))),
    U32.add(aquarium_u32_func(34n), U32.mod(U32.mul(i4, aquarium_u32_func(19n)), aquarium_u32_func(180n))),
    U32.add(aquarium_u32_func(80n), U32.mod(U32.mul(i5, aquarium_u32_func(23n)), aquarium_u32_func(170n))),
    U32.add(aquarium_u32_func(28n), U32.mod(U32.mul(i6, aquarium_u32_func(5n)), aquarium_u32_func(90n))),
    U32.add(aquarium_u32_func(70n), U32.mod(U32.mul(i7, aquarium_u32_func(17n)), aquarium_u32_func(140n))),
    U32.mod(U32.add(i8, seed), aquarium_u32_func(360n))
  }

assert aquarium_verified_frames_func:
  forall fuel: Nat
  forall index: U32
  forall seed: U32
  VerifiedAquariumFrames<fuel>

def aquarium_verified_frames_func(fuel, index, seed):
  match fuel:
    case 0n:
      VerifiedAquariumFrames{Nil{}, {==}}
    case 1n+pred:
      ((frame_index, frame_index_exact), (next_index, next_index_exact)) = U32.copy(index)
      ((frame_seed, frame_seed_exact), (tail_seed, tail_seed_exact)) = U32.copy(seed)
      match aquarium_verified_frames_func(pred, U32.inc(next_index), U32.add(tail_seed, aquarium_u32_func(3n))):
        case VerifiedAquariumFrames{tail, tail_exact}:
          frame = aquarium_frame_func(frame_index, frame_seed)
          VerifiedAquariumFrames{Con{frame, tail}, Equal.cong(Nat, Nat, length => 1n+length, List.length(AquariumFrame, tail), pred, tail_exact)}

assert aquarium_frames_func:
  forall fuel: Nat
  forall seed: U32
  List<AquariumFrame>

def aquarium_frames_func(fuel, seed):
  match aquarium_verified_frames_func(fuel, 0, seed):
    case VerifiedAquariumFrames{frames, length_exact}:
      frames

# Browser visualizers can request an ever-increasing Core frame instead of
# replaying a short checked-in ring.  Seed evolution remains inside Core.
assert aquarium_frame_at_func:
  forall index: U32
  forall seed: U32
  AquariumFrame

def aquarium_frame_at_func(index, seed):
  ((index_frame, index_frame_exact), (index_seed, index_seed_exact)) = U32.copy(index)
  aquarium_frame_func(index_frame, U32.add(seed, U32.mul(index_seed, aquarium_u32_func(3n))))

assert aquarium_coral_kind_motion_func:
  forall kind: CoralKind
  forall id: Nat
  CoralMotionProfile

def aquarium_coral_kind_motion_func(kind, id):
  match kind:
    case EuphylliaParancora{}: CoralMotionProfile{id, aquarium_u32_func(72n), aquarium_u32_func(62n), aquarium_u32_func(88n)}
    case EuphylliaGlabrescens{}: CoralMotionProfile{id, aquarium_u32_func(96n), aquarium_u32_func(91n), aquarium_u32_func(94n)}
    case EuphylliaAncora{}: CoralMotionProfile{id, aquarium_u32_func(64n), aquarium_u32_func(58n), aquarium_u32_func(82n)}
    case CoralliumRubrum{}: CoralMotionProfile{id, aquarium_u32_func(28n), aquarium_u32_func(17n), aquarium_u32_func(45n)}
    case AcroporaBranch{}: CoralMotionProfile{id, aquarium_u32_func(22n), aquarium_u32_func(12n), aquarium_u32_func(34n)}
    case BrainCoral{}: CoralMotionProfile{id, aquarium_u32_func(8n), aquarium_u32_func(4n), aquarium_u32_func(18n)}
    case PlateCoral{}: CoralMotionProfile{id, aquarium_u32_func(12n), aquarium_u32_func(7n), aquarium_u32_func(22n)}
    case Anemone{}: CoralMotionProfile{id, aquarium_u32_func(105n), aquarium_u32_func(110n), aquarium_u32_func(97n)}

assert aquarium_coral_motion_profiles_func:
  forall values: List<CoralModel>
  List<CoralMotionProfile>

def aquarium_coral_motion_profiles_func(values):
  match values:
    case Nil{}: Nil{}
    case Con{CoralModel{id, kind, x, y, z, size, color, polyps, sway, fluorescence}, tail}:
      Con{aquarium_coral_kind_motion_func(kind, id), aquarium_coral_motion_profiles_func(tail)}

# Structural induction: every coral in every arbitrary finite reef is assigned
# exactly one species-specific current/bend/polyp motion law, in order.
assert aquarium_coral_motion_cardinality_theorem_func:
  forall values: List<CoralModel>
  { List.length(CoralMotionProfile, aquarium_coral_motion_profiles_func(values)) == List.length(CoralModel, values) : Nat }

def aquarium_coral_motion_cardinality_theorem_func(values):
  match values:
    case Nil{}: {==}
    case Con{CoralModel{id, kind, x, y, z, size, color, polyps, sway, fluorescence}, tail}:
      Equal.cong(
        Nat,
        Nat,
        count => 1n+count,
        List.length(CoralMotionProfile, aquarium_coral_motion_profiles_func(tail)),
        List.length(CoralModel, tail),
        aquarium_coral_motion_cardinality_theorem_func(tail)
      )

assert aquarium_fish_func:
  List<FishModel>

def aquarium_fish_func():
  Con{FishModel{0n, Clownfish{}, aquarium_u32_func(320n), aquarium_u32_func(420n), aquarium_u32_func(520n), aquarium_u32_func(65n), aquarium_u32_func(255n), aquarium_u32_func(95n), aquarium_u32_func(1n)},
  Con{FishModel{1n, BlueTang{}, aquarium_u32_func(520n), aquarium_u32_func(500n), aquarium_u32_func(700n), aquarium_u32_func(90n), aquarium_u32_func(35n), aquarium_u32_func(150n), aquarium_u32_func(2n)},
  Con{FishModel{2n, MoorishIdol{}, aquarium_u32_func(760n), aquarium_u32_func(600n), aquarium_u32_func(580n), aquarium_u32_func(85n), aquarium_u32_func(250n), aquarium_u32_func(40n), aquarium_u32_func(3n)},
  Con{FishModel{3n, RoyalGramma{}, aquarium_u32_func(940n), aquarium_u32_func(360n), aquarium_u32_func(780n), aquarium_u32_func(55n), aquarium_u32_func(175n), aquarium_u32_func(80n), aquarium_u32_func(4n)},
  Con{FishModel{4n, MandarinDragonet{}, aquarium_u32_func(1180n), aquarium_u32_func(300n), aquarium_u32_func(650n), aquarium_u32_func(58n), aquarium_u32_func(45n), aquarium_u32_func(230n), aquarium_u32_func(5n)},
  Con{FishModel{5n, Butterflyfish{}, aquarium_u32_func(1420n), aquarium_u32_func(520n), aquarium_u32_func(490n), aquarium_u32_func(78n), aquarium_u32_func(245n), aquarium_u32_func(210n), aquarium_u32_func(6n)},
  Con{FishModel{6n, Angelfish{}, aquarium_u32_func(1660n), aquarium_u32_func(680n), aquarium_u32_func(720n), aquarium_u32_func(95n), aquarium_u32_func(65n), aquarium_u32_func(190n), aquarium_u32_func(7n)},
  Con{FishModel{7n, Firefish{}, aquarium_u32_func(1880n), aquarium_u32_func(410n), aquarium_u32_func(610n), aquarium_u32_func(52n), aquarium_u32_func(255n), aquarium_u32_func(70n), aquarium_u32_func(8n)},
  Con{FishModel{8n, Chromis{}, aquarium_u32_func(2050n), aquarium_u32_func(560n), aquarium_u32_func(800n), aquarium_u32_func(48n), aquarium_u32_func(70n), aquarium_u32_func(210n), aquarium_u32_func(9n)},
  Con{FishModel{9n, YellowTang{}, aquarium_u32_func(2240n), aquarium_u32_func(460n), aquarium_u32_func(550n), aquarium_u32_func(88n), aquarium_u32_func(255n), aquarium_u32_func(210n), aquarium_u32_func(10n)},
  Con{FishModel{10n, CleanerWrasse{}, aquarium_u32_func(2480n), aquarium_u32_func(620n), aquarium_u32_func(690n), aquarium_u32_func(50n), aquarium_u32_func(90n), aquarium_u32_func(235n), aquarium_u32_func(11n)},
  Con{FishModel{11n, Cardinalfish{}, aquarium_u32_func(2690n), aquarium_u32_func(390n), aquarium_u32_func(760n), aquarium_u32_func(60n), aquarium_u32_func(215n), aquarium_u32_func(85n), aquarium_u32_func(12n)}, Nil{}}}}}}}}}}}}}

assert aquarium_coral_func:
  List<CoralModel>

def aquarium_coral_func():
  Con{CoralModel{0n, EuphylliaParancora{}, aquarium_u32_func(260n), aquarium_u32_func(80n), aquarium_u32_func(700n), aquarium_u32_func(185n), aquarium_u32_func(222n), aquarium_u32_func(28n), aquarium_u32_func(72n), aquarium_u32_func(220n)},
  Con{CoralModel{1n, EuphylliaGlabrescens{}, aquarium_u32_func(520n), aquarium_u32_func(70n), aquarium_u32_func(520n), aquarium_u32_func(170n), aquarium_u32_func(110n), aquarium_u32_func(34n), aquarium_u32_func(96n), aquarium_u32_func(245n)},
  Con{CoralModel{2n, EuphylliaAncora{}, aquarium_u32_func(780n), aquarium_u32_func(90n), aquarium_u32_func(800n), aquarium_u32_func(205n), aquarium_u32_func(185n), aquarium_u32_func(38n), aquarium_u32_func(64n), aquarium_u32_func(210n)},
  Con{CoralModel{3n, CoralliumRubrum{}, aquarium_u32_func(1040n), aquarium_u32_func(75n), aquarium_u32_func(580n), aquarium_u32_func(180n), aquarium_u32_func(245n), aquarium_u32_func(46n), aquarium_u32_func(28n), aquarium_u32_func(175n)},
  Con{CoralModel{4n, AcroporaBranch{}, aquarium_u32_func(1300n), aquarium_u32_func(65n), aquarium_u32_func(740n), aquarium_u32_func(190n), aquarium_u32_func(60n), aquarium_u32_func(24n), aquarium_u32_func(22n), aquarium_u32_func(120n)},
  Con{CoralModel{5n, BrainCoral{}, aquarium_u32_func(1560n), aquarium_u32_func(80n), aquarium_u32_func(620n), aquarium_u32_func(155n), aquarium_u32_func(175n), aquarium_u32_func(80n), aquarium_u32_func(8n), aquarium_u32_func(90n)},
  Con{CoralModel{6n, PlateCoral{}, aquarium_u32_func(1820n), aquarium_u32_func(70n), aquarium_u32_func(790n), aquarium_u32_func(175n), aquarium_u32_func(110n), aquarium_u32_func(64n), aquarium_u32_func(12n), aquarium_u32_func(135n)},
  Con{CoralModel{7n, Anemone{}, aquarium_u32_func(2080n), aquarium_u32_func(60n), aquarium_u32_func(500n), aquarium_u32_func(185n), aquarium_u32_func(230n), aquarium_u32_func(52n), aquarium_u32_func(105n), aquarium_u32_func(240n)},
  Con{CoralModel{8n, EuphylliaParancora{}, aquarium_u32_func(2320n), aquarium_u32_func(78n), aquarium_u32_func(650n), aquarium_u32_func(155n), aquarium_u32_func(75n), aquarium_u32_func(26n), aquarium_u32_func(70n), aquarium_u32_func(205n)},
  Con{CoralModel{9n, EuphylliaGlabrescens{}, aquarium_u32_func(2520n), aquarium_u32_func(72n), aquarium_u32_func(760n), aquarium_u32_func(148n), aquarium_u32_func(195n), aquarium_u32_func(32n), aquarium_u32_func(92n), aquarium_u32_func(238n)},
  Con{CoralModel{10n, EuphylliaAncora{}, aquarium_u32_func(2720n), aquarium_u32_func(76n), aquarium_u32_func(560n), aquarium_u32_func(165n), aquarium_u32_func(145n), aquarium_u32_func(36n), aquarium_u32_func(62n), aquarium_u32_func(215n)},
  Con{CoralModel{11n, CoralliumRubrum{}, aquarium_u32_func(2880n), aquarium_u32_func(68n), aquarium_u32_func(720n), aquarium_u32_func(138n), aquarium_u32_func(250n), aquarium_u32_func(42n), aquarium_u32_func(25n), aquarium_u32_func(180n)}, Nil{}}}}}}}}}}}}}

assert aquarium_equipment_func:
  List<Equipment>

def aquarium_equipment_func():
  Con{Equipment{0n, BubbleMaker{}}, Con{Equipment{1n, BubbleMaker{}}, Con{Equipment{2n, CanisterFilter{}}, Con{Equipment{3n, HangingLight{}}, Con{Equipment{4n, Heater{}}, Con{Equipment{5n, ReturnJet{}}, Con{Equipment{6n, ReturnJet{}}, Nil{}}}}}}}}

assert aquarium_reference_history_func:
  TankHistory

def aquarium_reference_history_func():
  TankHistoryFrame{FishStroke{3n, 2n}, TankHistoryFrame{BubblePulse{4n, 6n}, TankHistoryFrame{FilterFlow{5n, 2n}, TankHistoryFrame{LightHeat{1n}, TankHistoryEnd{}}}}}

assert aquarium_self_check_func:
  Bool

def aquarium_self_check_func():
  Bool.and(
    Nat.is_eq(List.length(FishModel, aquarium_fish_func()), 12n),
    Bool.and(
      Nat.is_eq(List.length(CoralModel, aquarium_coral_func()), 12n),
      Nat.is_eq(List.length(AquariumFrame, aquarium_frames_func(360n, aquarium_u32_func(91n))), 360n)
    )
  )

assert main_value:
  AquariumReport

def main_value():
  AquariumReport{
    "Bend Aquarium",
    TankGeometry{aquarium_u32_func(3000n), aquarium_u32_func(1400n), aquarium_u32_func(1100n), aquarium_u32_func(24n), aquarium_u32_func(1260n)},
    aquarium_fish_func(),
    aquarium_coral_func(),
    AquariumEquipment{aquarium_u32_func(2n), aquarium_u32_func(220n), aquarium_u32_func(1900n), aquarium_u32_func(245n), aquarium_u32_func(2n)},
    aquarium_frames_func(360n, aquarium_u32_func(91n)),
    360n
  }

assert main_accept_value:
  forall value: AquariumReport
  IO(Unit)

def main_accept_value(value):
  IO.print("Ready{}")

assert main:
  IO(Unit)

def main():
  main_accept_value(main_value!())
