import Base
import ./landscape.bend as Landscape
import ../../compat/list.bend as List

# Proof-carrying transition histories for the live landscape state machines.
# The finite constructor tables below are only one-step specifications.  The
# exported claims are structural inductions over arbitrary horizons.

type TideTransition:
  TideTransition{
    before: Landscape.TidePhase,
    after: Landscape.TidePhase,
    before_height: Nat,
    after_height: Nat,
    distance: Nat,
    -after_is_next: {after == Landscape.tide_next_func(before) : Landscape.TidePhase},
    -before_height_exact: {before_height == Landscape.tide_height_nat_func(before) : Nat},
    -after_height_exact: {after_height == Landscape.tide_height_nat_func(after) : Nat},
    -distance_bounded: Landscape.NatAtMost<distance, 12n>
  }

type TideTransitionStep:
  TideTransitionStep{transition: TideTransition, next: Landscape.TidePhase}

type VerifiedTideHistory<-expected: Nat>:
  VerifiedTideHistory{
    transitions: List<TideTransition>,
    final: Landscape.TidePhase,
    -length_exact: {List.length(TideTransition, transitions) == expected : Nat}
  }

type TerrainTransition:
  TerrainTransition{
    before: Landscape.TerrainBand,
    after: Landscape.TerrainBand,
    before_height: Nat,
    after_height: Nat,
    distance: Nat,
    -after_is_next: {after == Landscape.terrain_next_func(before) : Landscape.TerrainBand},
    -before_height_exact: {before_height == Landscape.terrain_height_nat_func(before) : Nat},
    -after_height_exact: {after_height == Landscape.terrain_height_nat_func(after) : Nat},
    -distance_bounded: Landscape.NatAtMost<distance, 36n>
  }

type TerrainTransitionStep:
  TerrainTransitionStep{transition: TerrainTransition, next: Landscape.TerrainBand}

type VerifiedTerrainHistory<-expected: Nat>:
  VerifiedTerrainHistory{
    transitions: List<TerrainTransition>,
    final: Landscape.TerrainBand,
    -length_exact: {List.length(TerrainTransition, transitions) == expected : Nat}
  }

type CloudTransition:
  CloudTransition{
    before: Landscape.CloudPhase,
    after: Landscape.CloudPhase,
    rain: Landscape.RainBand,
    sun: Landscape.SunBand,
    -after_is_next: {after == Landscape.cloud_next_func(before) : Landscape.CloudPhase},
    -rain_exact: {rain == Landscape.cloud_rain_func(after) : Landscape.RainBand},
    -sun_exact: {sun == Landscape.cloud_sun_func(after) : Landscape.SunBand}
  }

type CloudTransitionStep:
  CloudTransitionStep{transition: CloudTransition, next: Landscape.CloudPhase}

type VerifiedCloudHistory<-expected: Nat>:
  VerifiedCloudHistory{
    transitions: List<CloudTransition>,
    final: Landscape.CloudPhase,
    -length_exact: {List.length(CloudTransition, transitions) == expected : Nat}
  }

assert tide_transition_step_func:
  forall value: Landscape.TidePhase
  TideTransitionStep

def tide_transition_step_func(value):
  match value:
    case Landscape.TideLow{}:
      TideTransitionStep{TideTransition{Landscape.TideLow{}, Landscape.TideRisingOne{}, 170n, 182n, 12n, {==}, {==}, {==}, Landscape.NatAtMost{0n, {==}}}, Landscape.TideRisingOne{}}
    case Landscape.TideRisingOne{}:
      TideTransitionStep{TideTransition{Landscape.TideRisingOne{}, Landscape.TideRisingTwo{}, 182n, 194n, 12n, {==}, {==}, {==}, Landscape.NatAtMost{0n, {==}}}, Landscape.TideRisingTwo{}}
    case Landscape.TideRisingTwo{}:
      TideTransitionStep{TideTransition{Landscape.TideRisingTwo{}, Landscape.TideCrest{}, 194n, 206n, 12n, {==}, {==}, {==}, Landscape.NatAtMost{0n, {==}}}, Landscape.TideCrest{}}
    case Landscape.TideCrest{}:
      TideTransitionStep{TideTransition{Landscape.TideCrest{}, Landscape.TideFallingOne{}, 206n, 194n, 12n, {==}, {==}, {==}, Landscape.NatAtMost{0n, {==}}}, Landscape.TideFallingOne{}}
    case Landscape.TideFallingOne{}:
      TideTransitionStep{TideTransition{Landscape.TideFallingOne{}, Landscape.TideFallingTwo{}, 194n, 182n, 12n, {==}, {==}, {==}, Landscape.NatAtMost{0n, {==}}}, Landscape.TideFallingTwo{}}
    case Landscape.TideFallingTwo{}:
      TideTransitionStep{TideTransition{Landscape.TideFallingTwo{}, Landscape.TideRest{}, 182n, 170n, 12n, {==}, {==}, {==}, Landscape.NatAtMost{0n, {==}}}, Landscape.TideRest{}}
    case Landscape.TideRest{}:
      TideTransitionStep{TideTransition{Landscape.TideRest{}, Landscape.TideLow{}, 170n, 170n, 0n, {==}, {==}, {==}, Landscape.NatAtMost{12n, {==}}}, Landscape.TideLow{}}

assert tide_history_claim_func:
  forall fuel: Nat
  forall phase: Landscape.TidePhase
  VerifiedTideHistory<fuel>

def tide_history_claim_func(fuel, phase):
  match fuel:
    case 0n:
      VerifiedTideHistory{Nil{}, phase, {==}}
    case 1n+pred:
      match tide_transition_step_func(phase):
        case TideTransitionStep{transition, next}:
          match tide_history_claim_func(pred, next):
            case VerifiedTideHistory{tail, final, tail_exact}:
              VerifiedTideHistory{Con{transition, tail}, final, Equal.cong(Nat, Nat, count => 1n+count, List.length(TideTransition, tail), pred, tail_exact)}

assert terrain_transition_step_func:
  forall value: Landscape.TerrainBand
  TerrainTransitionStep

def terrain_transition_step_func(value):
  match value:
    case Landscape.TerrainShore{}:
      TerrainTransitionStep{TerrainTransition{Landscape.TerrainShore{}, Landscape.TerrainDune{}, 220n, 238n, 18n, {==}, {==}, {==}, Landscape.NatAtMost{18n, {==}}}, Landscape.TerrainDune{}}
    case Landscape.TerrainDune{}:
      TerrainTransitionStep{TerrainTransition{Landscape.TerrainDune{}, Landscape.TerrainMeadow{}, 238n, 256n, 18n, {==}, {==}, {==}, Landscape.NatAtMost{18n, {==}}}, Landscape.TerrainMeadow{}}
    case Landscape.TerrainMeadow{}:
      TerrainTransitionStep{TerrainTransition{Landscape.TerrainMeadow{}, Landscape.TerrainRise{}, 256n, 274n, 18n, {==}, {==}, {==}, Landscape.NatAtMost{18n, {==}}}, Landscape.TerrainRise{}}
    case Landscape.TerrainRise{}:
      TerrainTransitionStep{TerrainTransition{Landscape.TerrainRise{}, Landscape.TerrainHill{}, 274n, 292n, 18n, {==}, {==}, {==}, Landscape.NatAtMost{18n, {==}}}, Landscape.TerrainHill{}}
    case Landscape.TerrainHill{}:
      TerrainTransitionStep{TerrainTransition{Landscape.TerrainHill{}, Landscape.TerrainDescent{}, 292n, 256n, 36n, {==}, {==}, {==}, Landscape.NatAtMost{0n, {==}}}, Landscape.TerrainDescent{}}
    case Landscape.TerrainDescent{}:
      TerrainTransitionStep{TerrainTransition{Landscape.TerrainDescent{}, Landscape.TerrainShore{}, 256n, 220n, 36n, {==}, {==}, {==}, Landscape.NatAtMost{0n, {==}}}, Landscape.TerrainShore{}}

assert terrain_history_claim_func:
  forall fuel: Nat
  forall band: Landscape.TerrainBand
  VerifiedTerrainHistory<fuel>

def terrain_history_claim_func(fuel, band):
  match fuel:
    case 0n:
      VerifiedTerrainHistory{Nil{}, band, {==}}
    case 1n+pred:
      match terrain_transition_step_func(band):
        case TerrainTransitionStep{transition, next}:
          match terrain_history_claim_func(pred, next):
            case VerifiedTerrainHistory{tail, final, tail_exact}:
              VerifiedTerrainHistory{Con{transition, tail}, final, Equal.cong(Nat, Nat, count => 1n+count, List.length(TerrainTransition, tail), pred, tail_exact)}

assert cloud_transition_step_func:
  forall value: Landscape.CloudPhase
  CloudTransitionStep

def cloud_transition_step_func(value):
  match value:
    case Landscape.CloudClear{}:
      CloudTransitionStep{CloudTransition{Landscape.CloudClear{}, Landscape.CloudForming{}, Landscape.RainNone{}, Landscape.SunBright{}, {==}, {==}, {==}}, Landscape.CloudForming{}}
    case Landscape.CloudForming{}:
      CloudTransitionStep{CloudTransition{Landscape.CloudForming{}, Landscape.CloudCharging{}, Landscape.RainDrizzle{}, Landscape.SunSoft{}, {==}, {==}, {==}}, Landscape.CloudCharging{}}
    case Landscape.CloudCharging{}:
      CloudTransitionStep{CloudTransition{Landscape.CloudCharging{}, Landscape.CloudRainReady{}, Landscape.RainSteady{}, Landscape.SunDim{}, {==}, {==}, {==}}, Landscape.CloudRainReady{}}
    case Landscape.CloudRainReady{}:
      CloudTransitionStep{CloudTransition{Landscape.CloudRainReady{}, Landscape.CloudRaining{}, Landscape.RainHeavy{}, Landscape.SunDim{}, {==}, {==}, {==}}, Landscape.CloudRaining{}}
    case Landscape.CloudRaining{}:
      CloudTransitionStep{CloudTransition{Landscape.CloudRaining{}, Landscape.CloudDissipating{}, Landscape.RainDrizzle{}, Landscape.SunSoft{}, {==}, {==}, {==}}, Landscape.CloudDissipating{}}
    case Landscape.CloudDissipating{}:
      CloudTransitionStep{CloudTransition{Landscape.CloudDissipating{}, Landscape.CloudClear{}, Landscape.RainNone{}, Landscape.SunBright{}, {==}, {==}, {==}}, Landscape.CloudClear{}}

assert cloud_history_claim_func:
  forall fuel: Nat
  forall phase: Landscape.CloudPhase
  VerifiedCloudHistory<fuel>

def cloud_history_claim_func(fuel, phase):
  match fuel:
    case 0n:
      VerifiedCloudHistory{Nil{}, phase, {==}}
    case 1n+pred:
      match cloud_transition_step_func(phase):
        case CloudTransitionStep{transition, next}:
          match cloud_history_claim_func(pred, next):
            case VerifiedCloudHistory{tail, final, tail_exact}:
              VerifiedCloudHistory{Con{transition, tail}, final, Equal.cong(Nat, Nat, count => 1n+count, List.length(CloudTransition, tail), pred, tail_exact)}
