import Base
import ../../compat/list.bend as List
import ../../compat/nat.bend as Nat

# Bendio 3D Land: a pure seed-generated autonomous platformer. The Core
# report contains the terrain and the NPC traversal segments. A browser may
# choose a seed and POV, but the generated Core function owns every platform,
# jump path, landing, action, and collectible count.

# Types
# =====

type PlatformMaterial:
  GrassStone{}
  GoldenBrick{}
  CloudGlass{}
  LavaRock{}
  MossRuins{}
  CrystalTile{}

type Platform:
  Platform{id: Nat, x: U32, y: U32, z: U32, width: U32, height: U32, depth: U32, material: PlatformMaterial}

type PlatformAnchor:
  PlatformAnchor{id: Nat, x: U32, y: U32, z: U32}

type PlatformEnvelope:
  PlatformEnvelope{x: U32, y: U32, z: U32, width: U32, depth: U32}

type Position:
  Position{x: U32, y: U32, z: U32}

type JumpGeometry:
  JumpGeometry{sx: U32, sy: U32, sz: U32, tx: U32, ty: U32, tz: U32}

type Frame:
  Frame{tick: U32, x: U32, y: U32, z: U32, pose: U32, action: U32, coins: U32, sparkle: U32}

type CourseSegment:
  CourseSegment{source: PlatformAnchor, target: PlatformAnchor, takeoff: Position, landing: Position, frames: List<Frame>, gap: U32, clearance: U32}

type Report:
  Report{title: String, seed: U32, platforms: List<Platform>, segments: List<CourseSegment>, platform_count: Nat, frame_count: Nat, viewpoints: U32}

# The generators construct their values and mathematical cardinality proofs in
# one induction.  The proof fields erase from generated JavaScript and C.
type VerifiedPlatforms<-count: Nat>:
  VerifiedPlatforms{
    value: List<Platform>,
    -length_exact: {List.length(Platform, value) == count : Nat}
  }

type VerifiedSegments<-count: Nat>:
  VerifiedSegments{
    value: List<CourseSegment>,
    -length_exact: {List.length(CourseSegment, value) == count : Nat}
  }

type VerifiedFrames<-count: Nat>:
  VerifiedFrames{
    value: List<Frame>,
    -length_exact: {List.length(Frame, value) == count : Nat}
  }

# Constants
# =========

assert bendio_u32_func:
  forall value: Nat
  U32

def bendio_u32_func(value):
  U32.from_nat(value)

assert bendio_default_seed_func:
  U32

def bendio_default_seed_func():
  U32.add(U32.mul(bendio_u32_func(7n), bendio_u32_func(1000n)), bendio_u32_func(319n))

# PlatformMaterial-Section
# ========================

assert bendio_platform_material_func:
  forall value: U32
  PlatformMaterial

def bendio_platform_material_func(value):
  ((test0, test0_exact), (rest0, rest0_exact)) = U32.copy(U32.mod(value, bendio_u32_func(6n)))
  match U32.is_eq(test0, bendio_u32_func(0n)):
    case True{}: GrassStone{}
    case False{}:
      ((test1, test1_exact), (rest1, rest1_exact)) = U32.copy(rest0)
      match U32.is_eq(test1, bendio_u32_func(1n)):
        case True{}: GoldenBrick{}
        case False{}:
          ((test2, test2_exact), (rest2, rest2_exact)) = U32.copy(rest1)
          match U32.is_eq(test2, bendio_u32_func(2n)):
            case True{}: CloudGlass{}
            case False{}:
              ((test3, test3_exact), (rest3, rest3_exact)) = U32.copy(rest2)
              match U32.is_eq(test3, bendio_u32_func(3n)):
                case True{}: LavaRock{}
                case False{}:
                  match U32.is_eq(rest3, bendio_u32_func(4n)):
                    case True{}: MossRuins{}
                    case False{}: CrystalTile{}

# Platform-Section
# ================

assert platform_anchor:
  forall value: Platform
  PlatformAnchor

def platform_anchor(value):
  match value:
    case Platform{id, x, y, z, width, height, depth, material}:
      PlatformAnchor{id, x, y, z}

assert platform_envelope:
  forall value: Platform
  PlatformEnvelope

def platform_envelope(value):
  match value:
    case Platform{id, x, y, z, width, height, depth, material}:
      PlatformEnvelope{x, y, z, width, depth}

# PlatformAnchor-Section
# ======================

assert platform_anchor_position:
  forall value: PlatformAnchor
  Position

def platform_anchor_position(value):
  match value:
    case PlatformAnchor{id, x, y, z}:
      Position{x, y, z}

# Position-Section
# ================

assert position_copy:
  forall value: Position
  Position & Position

def position_copy(value):
  match value:
    case Position{x, y, z}:
      ((x_a, x_a_exact), (x_b, x_b_exact)) = U32.copy(x)
      ((y_a, y_a_exact), (y_b, y_b_exact)) = U32.copy(y)
      ((z_a, z_a_exact), (z_b, z_b_exact)) = U32.copy(z)
      (Position{x_a, y_a, z_a}, Position{x_b, y_b, z_b})

# JumpGeometry-Section
# ====================

assert jump_geometry_copy:
  forall value: JumpGeometry
  JumpGeometry & JumpGeometry

def jump_geometry_copy(value):
  match value:
    case JumpGeometry{sx, sy, sz, tx, ty, tz}:
      ((sx_a, sx_a_exact), (sx_b, sx_b_exact)) = U32.copy(sx)
      ((sy_a, sy_a_exact), (sy_b, sy_b_exact)) = U32.copy(sy)
      ((sz_a, sz_a_exact), (sz_b, sz_b_exact)) = U32.copy(sz)
      ((tx_a, tx_a_exact), (tx_b, tx_b_exact)) = U32.copy(tx)
      ((ty_a, ty_a_exact), (ty_b, ty_b_exact)) = U32.copy(ty)
      ((tz_a, tz_a_exact), (tz_b, tz_b_exact)) = U32.copy(tz)
      (JumpGeometry{sx_a, sy_a, sz_a, tx_a, ty_a, tz_a}, JumpGeometry{sx_b, sy_b, sz_b, tx_b, ty_b, tz_b})

# Frame-Section
# =============

assert frame_position:
  forall value: Frame
  Position

def frame_position(value):
  match value:
    case Frame{tick, x, y, z, pose, action, coins, sparkle}:
      Position{x, y, z}

# CourseSegment-Section
# =====================

assert course_segment_source_position:
  forall value: CourseSegment
  Position

def course_segment_source_position(value):
  match value:
    case CourseSegment{source, target, takeoff, landing, frames, gap, clearance}:
      platform_anchor_position(source)

assert course_segment_target_position:
  forall value: CourseSegment
  Position

def course_segment_target_position(value):
  match value:
    case CourseSegment{source, target, takeoff, landing, frames, gap, clearance}:
      platform_anchor_position(target)

assert course_segment_takeoff:
  forall value: CourseSegment
  Position

def course_segment_takeoff(value):
  match value:
    case CourseSegment{source, target, takeoff, landing, frames, gap, clearance}:
      takeoff

assert course_segment_landing:
  forall value: CourseSegment
  Position

def course_segment_landing(value):
  match value:
    case CourseSegment{source, target, takeoff, landing, frames, gap, clearance}:
      landing

# Func-Section
# ============

assert bendio_u32_three_func:
  forall value: U32
  U32 & (U32 & U32)

def bendio_u32_three_func(value):
  ((a, a_exact), (rest, rest_exact)) = U32.copy(value)
  ((b, b_exact), (c, c_exact)) = U32.copy(rest)
  (a, (b, c))

assert bendio_u32_eight_func:
  forall value: U32
  U32 & (U32 & (U32 & (U32 & (U32 & (U32 & (U32 & U32))))))

def bendio_u32_eight_func(value):
  ((a, a_exact), (r1, r1_exact)) = U32.copy(value)
  ((b, b_exact), (r2, r2_exact)) = U32.copy(r1)
  ((c, c_exact), (r3, r3_exact)) = U32.copy(r2)
  ((d, d_exact), (r4, r4_exact)) = U32.copy(r3)
  ((e, e_exact), (r5, r5_exact)) = U32.copy(r4)
  ((f, f_exact), (r6, r6_exact)) = U32.copy(r5)
  ((g, g_exact), (h, h_exact)) = U32.copy(r6)
  (a, (b, (c, (d, (e, (f, (g, h)))))))

assert bendio_seed_next_func:
  forall seed: U32
  U32

def bendio_seed_next_func(seed):
  U32.add(U32.mul(seed, bendio_u32_func(73n)), bendio_u32_func(41n))

assert bendio_platform_gap_func:
  forall seed: U32
  U32

def bendio_platform_gap_func(seed):
  U32.add(bendio_u32_func(610n), U32.mod(seed, bendio_u32_func(170n)))

assert bendio_platform_from_state_func:
  forall id: Nat
  forall x: U32
  forall seed: U32
  Platform

def bendio_platform_from_state_func(id, x, seed):
  (s0, (s1, (s2, (s3, (s4, (s5, (s6, s7))))))) = bendio_u32_eight_func(seed)
  Platform{
    id,
    x,
    U32.add(bendio_u32_func(210n), U32.mod(U32.mul(s0, bendio_u32_func(13n)), bendio_u32_func(240n))),
    U32.add(bendio_u32_func(390n), U32.mod(U32.mul(s1, bendio_u32_func(17n)), bendio_u32_func(390n))),
    U32.add(bendio_u32_func(420n), U32.mod(U32.mul(s2, bendio_u32_func(7n)), bendio_u32_func(260n))),
    U32.add(bendio_u32_func(90n), U32.mod(U32.mul(s3, bendio_u32_func(5n)), bendio_u32_func(70n))),
    U32.add(bendio_u32_func(370n), U32.mod(U32.mul(s4, bendio_u32_func(11n)), bendio_u32_func(310n))),
    bendio_platform_material_func(U32.add(U32.add(s5, s6), s7))
  }

assert bendio_platform_expected_envelope_func:
  forall x: U32
  forall seed: U32
  PlatformEnvelope

def bendio_platform_expected_envelope_func(x, seed):
  (s0, (s1, (s2, (s3, (s4, (s5, (s6, s7))))))) = bendio_u32_eight_func(seed)
  PlatformEnvelope{
    x,
    U32.add(bendio_u32_func(210n), U32.mod(U32.mul(s0, bendio_u32_func(13n)), bendio_u32_func(240n))),
    U32.add(bendio_u32_func(390n), U32.mod(U32.mul(s1, bendio_u32_func(17n)), bendio_u32_func(390n))),
    U32.add(bendio_u32_func(420n), U32.mod(U32.mul(s2, bendio_u32_func(7n)), bendio_u32_func(260n))),
    U32.add(bendio_u32_func(370n), U32.mod(U32.mul(s4, bendio_u32_func(11n)), bendio_u32_func(310n)))
  }

assert bendio_platforms_claim_func:
  forall fuel: Nat
  forall id: Nat
  forall seed: U32
  forall x: U32
  VerifiedPlatforms<fuel>

def bendio_platforms_claim_func(fuel, id, seed, x):
  match fuel:
    case 0n:
      VerifiedPlatforms{Nil{}, {==}}
    case 1n+pred:
      ((id_head, id_head_exact), (id_tail, id_tail_exact)) = Nat.copy(id)
      (seed_head, (seed_gap, seed_tail)) = bendio_u32_three_func(seed)
      ((x_head, x_head_exact), (x_tail, x_tail_exact)) = U32.copy(x)
      match bendio_platforms_claim_func(pred, 1n+id_tail, bendio_seed_next_func(seed_tail), U32.add(x_tail, bendio_platform_gap_func(seed_gap))):
        case VerifiedPlatforms{tail, tail_length_exact}:
          VerifiedPlatforms{
            Con{bendio_platform_from_state_func(id_head, x_head, seed_head), tail},
            Equal.cong(Nat, Nat, length => 1n+length, List.length(Platform, tail), pred, tail_length_exact)
          }

assert bendio_platforms_func:
  forall fuel: Nat
  forall id: Nat
  forall seed: U32
  forall x: U32
  List<Platform>

def bendio_platforms_func(fuel, id, seed, x):
  match bendio_platforms_claim_func(fuel, id, seed, x):
    case VerifiedPlatforms{value, length_exact}:
      value

assert bendio_lerp_func:
  forall start: U32
  forall finish: U32
  forall time: U32
  U32

def bendio_lerp_func(start, finish, time):
  ((time_left, time_left_exact), (time_right, time_right_exact)) = U32.copy(time)
  U32.div(U32.add(U32.mul(start, U32.sub(bendio_u32_func(35n), time_left)), U32.mul(finish, time_right)), bendio_u32_func(35n))

assert bendio_jump_action_func:
  forall local: U32
  U32

def bendio_jump_action_func(local):
  match U32.is_le(local, bendio_u32_func(17n)):
    case True{}: bendio_u32_func(2n)
    case False{}: bendio_u32_func(3n)

assert bendio_jump_middle_frame_func:
  forall tick: U32
  forall local: U32
  forall geometry: JumpGeometry
  Frame

def bendio_jump_middle_frame_func(tick, local, geometry):
  match geometry:
    case JumpGeometry{sx, sy, sz, tx, ty, tz}:
      (t0, (t1, (t2, (t3, (t4, (t5, (t6, t7))))))) = bendio_u32_eight_func(local)
      ((coin_time, coin_time_exact), (sparkle_time, sparkle_time_exact)) = U32.copy(t7)
      Frame{
        tick,
        bendio_lerp_func(sx, tx, t0),
        U32.add(bendio_lerp_func(sy, ty, t1), U32.mul(t2, U32.sub(bendio_u32_func(35n), t3))),
        bendio_lerp_func(sz, tz, t4),
        U32.mod(U32.mul(t5, bendio_u32_func(21n)), bendio_u32_func(360n)),
        bendio_jump_action_func(t6),
        U32.div(coin_time, bendio_u32_func(9n)),
        U32.mod(U32.mul(sparkle_time, bendio_u32_func(37n)), bendio_u32_func(255n))
      }

assert bendio_jump_end_dispatch_func:
  forall is_end: Bool
  forall tick: U32
  forall local: U32
  forall geometry: JumpGeometry
  Frame

def bendio_jump_end_dispatch_func(is_end, tick, local, geometry):
  match is_end geometry:
    case True{} JumpGeometry{sx, sy, sz, tx, ty, tz}:
      Frame{tick, tx, ty, tz, bendio_u32_func(15n), bendio_u32_func(3n), bendio_u32_func(4n), bendio_u32_func(20n)}
    case False{} other:
      bendio_jump_middle_frame_func(tick, local, other)

assert bendio_jump_start_dispatch_func:
  forall is_start: Bool
  forall tick: U32
  forall local: U32
  forall geometry: JumpGeometry
  Frame

def bendio_jump_start_dispatch_func(is_start, tick, local, geometry):
  match is_start geometry:
    case True{} JumpGeometry{sx, sy, sz, tx, ty, tz}:
      Frame{tick, sx, sy, sz, 0, bendio_u32_func(2n), 0, 0}
    case False{} other:
      ((local_test, local_test_exact), (local_live, local_live_exact)) = U32.copy(local)
      bendio_jump_end_dispatch_func(U32.is_eq(local_test, bendio_u32_func(35n)), tick, local_live, other)

# The two endpoint branches are explicit.  Besides preventing fixed-point
# interpolation truncation from moving a landing by one unit, this makes the
# endpoint theorem computational: the checker does not need an unprovided
# symbolic division lemma for arbitrary U32 coordinates.
assert bendio_jump_frame_func:
  forall tick: U32
  forall local: U32
  forall geometry: JumpGeometry
  Frame

def bendio_jump_frame_func(tick, local, geometry):
  ((local_test, local_test_exact), (local_live, local_live_exact)) = U32.copy(local)
  bendio_jump_start_dispatch_func(U32.is_eq(local_test, 0), tick, local_live, geometry)

assert BendioJumpEndpointClaim_func:
  forall geometry: JumpGeometry
  Type

def BendioJumpEndpointClaim_func(geometry):
  match geometry:
    case JumpGeometry{sx, sy, sz, tx, ty, tz}:
      ({frame_position(bendio_jump_frame_func(0, 0, geometry)) == Position{sx, sy, sz} : Position}
      & {frame_position(bendio_jump_frame_func(bendio_u32_func(35n), bendio_u32_func(35n), geometry)) == Position{tx, ty, tz} : Position})

assert bendio_segment_frames_claim_func:
  forall fuel: Nat
  forall base_tick: U32
  forall local: U32
  forall geometry: JumpGeometry
  VerifiedFrames<fuel>

def bendio_segment_frames_claim_func(fuel, base_tick, local, geometry):
  match fuel:
    case 0n:
      VerifiedFrames{Nil{}, {==}}
    case 1n+pred:
      ((base_head, base_head_exact), (base_tail, base_tail_exact)) = U32.copy(base_tick)
      ((local_head, local_head_exact), (local_tail, local_tail_exact)) = U32.copy(local)
      ((local_tick, local_tick_exact), (local_frame, local_frame_exact)) = U32.copy(local_head)
      (geometry_head, geometry_tail) = jump_geometry_copy(geometry)
      match bendio_segment_frames_claim_func(pred, base_tail, U32.inc(local_tail), geometry_tail):
        case VerifiedFrames{tail, tail_length_exact}:
          VerifiedFrames{
            Con{bendio_jump_frame_func(U32.add(base_head, local_tick), local_frame, geometry_head), tail},
            Equal.cong(Nat, Nat, length => 1n+length, List.length(Frame, tail), pred, tail_length_exact)
          }

assert bendio_segment_frames_func:
  forall fuel: Nat
  forall base_tick: U32
  forall local: U32
  forall geometry: JumpGeometry
  List<Frame>

def bendio_segment_frames_func(fuel, base_tick, local, geometry):
  match bendio_segment_frames_claim_func(fuel, base_tick, local, geometry):
    case VerifiedFrames{value, length_exact}:
      value

assert bendio_segment_between_func:
  forall source: Platform
  forall target: Platform
  CourseSegment

def bendio_segment_between_func(source, target):
  match source target:
    case Platform{sid, sx, sy, sz, sw, sh, sd, sm} Platform{tid, tx, ty, tz, tw, th, td, tm}:
      ((sid_anchor, sid_anchor_exact), (sid_tick, sid_tick_exact)) = Nat.copy(sid)
      (sx_anchor, (sx_takeoff, sx_geometry)) = bendio_u32_three_func(sx)
      (sy_anchor, (sy_takeoff, sy_geometry)) = bendio_u32_three_func(sy)
      (sz_anchor, (sz_takeoff, sz_geometry)) = bendio_u32_three_func(sz)
      (tx_anchor, (tx_landing, tx_geometry)) = bendio_u32_three_func(tx)
      (ty_anchor, (ty_landing, ty_geometry)) = bendio_u32_three_func(ty)
      (tz_anchor, (tz_landing, tz_geometry)) = bendio_u32_three_func(tz)
      ((sx_anchor_live, sx_anchor_live_exact), (sx_gap, sx_gap_exact)) = U32.copy(sx_anchor)
      ((tx_anchor_live, tx_anchor_live_exact), (tx_gap, tx_gap_exact)) = U32.copy(tx_anchor)
      CourseSegment{
        PlatformAnchor{sid_anchor, sx_anchor_live, sy_anchor, sz_anchor},
        PlatformAnchor{tid, tx_anchor_live, ty_anchor, tz_anchor},
        Position{sx_takeoff, sy_takeoff, sz_takeoff},
        Position{tx_landing, ty_landing, tz_landing},
        bendio_segment_frames_func(36n, U32.mul(U32.from_nat(sid_tick), bendio_u32_func(36n)), 0, JumpGeometry{sx_geometry, sy_geometry, sz_geometry, tx_geometry, ty_geometry, tz_geometry}),
        U32.sub(tx_gap, sx_gap),
        bendio_u32_func(306n)
      }

assert bendio_segment_takeoff_state_func:
  forall id: Nat
  forall seed: U32
  forall x: U32
  Position

def bendio_segment_takeoff_state_func(id, seed, x):
  platform_anchor_position(platform_anchor(bendio_platform_from_state_func(id, x, seed)))

assert bendio_segment_landing_state_func:
  forall id: Nat
  forall seed: U32
  forall x: U32
  Position

def bendio_segment_landing_state_func(id, seed, x):
  ((id_source, id_source_exact), (id_next, id_next_exact)) = Nat.copy(id)
  ((seed_gap, seed_gap_exact), (seed_next_source, seed_next_source_exact)) = U32.copy(seed)
  ((x_source, x_source_exact), (x_next_source, x_next_source_exact)) = U32.copy(x)
  platform_anchor_position(platform_anchor(bendio_platform_from_state_func(
    1n+id_next,
    U32.add(x_next_source, bendio_platform_gap_func(seed_gap)),
    bendio_seed_next_func(seed_next_source)
  )))

assert bendio_segment_func:
  forall id: Nat
  forall seed: U32
  forall x: U32
  CourseSegment

def bendio_segment_func(id, seed, x):
  ((id_source, id_source_exact), (id_next, id_next_exact)) = Nat.copy(id)
  (seed_source, (seed_gap, seed_next_source)) = bendio_u32_three_func(seed)
  ((x_source, x_source_exact), (x_next_source, x_next_source_exact)) = U32.copy(x)
  next_seed = bendio_seed_next_func(seed_next_source)
  next_x = U32.add(x_next_source, bendio_platform_gap_func(seed_gap))
  source = bendio_platform_from_state_func(id_source, x_source, seed_source)
  target = bendio_platform_from_state_func(1n+id_next, next_x, next_seed)
  bendio_segment_between_func(source, target)

assert BendioGeneratedChainClaim_func:
  forall id: Nat
  forall seed: U32
  forall x: U32
  Type

def BendioGeneratedChainClaim_func(id, seed, x):
  {bendio_segment_landing_state_func(id, seed, x)
  == bendio_segment_takeoff_state_func(1n+id, bendio_seed_next_func(seed), U32.add(x, bendio_platform_gap_func(seed)))
  : Position}

assert bendio_segments_claim_func:
  forall fuel: Nat
  forall id: Nat
  forall seed: U32
  forall x: U32
  VerifiedSegments<fuel>

def bendio_segments_claim_func(fuel, id, seed, x):
  match fuel:
    case 0n:
      VerifiedSegments{Nil{}, {==}}
    case 1n+pred:
      ((id_head, id_head_exact), (id_tail, id_tail_exact)) = Nat.copy(id)
      (seed_head, (seed_gap, seed_tail)) = bendio_u32_three_func(seed)
      ((x_head, x_head_exact), (x_tail, x_tail_exact)) = U32.copy(x)
      match bendio_segments_claim_func(pred, 1n+id_tail, bendio_seed_next_func(seed_tail), U32.add(x_tail, bendio_platform_gap_func(seed_gap))):
        case VerifiedSegments{tail, tail_length_exact}:
          VerifiedSegments{
            Con{bendio_segment_func(id_head, seed_head, x_head), tail},
            Equal.cong(Nat, Nat, length => 1n+length, List.length(CourseSegment, tail), pred, tail_length_exact)
          }

assert bendio_segments_from_func:
  forall fuel: Nat
  forall id: Nat
  forall seed: U32
  forall x: U32
  List<CourseSegment>

def bendio_segments_from_func(fuel, id, seed, x):
  match bendio_segments_claim_func(fuel, id, seed, x):
    case VerifiedSegments{value, length_exact}:
      value

assert bendio_segments_func:
  forall seed: U32
  List<CourseSegment>

def bendio_segments_func(seed):
  bendio_segments_from_func(17n, 0n, seed, 0)

assert bendio_report_seed_func:
  forall seed: U32
  Report

def bendio_report_seed_func(seed):
  (seed_output, (seed_platforms, seed_segments)) = bendio_u32_three_func(seed)
  Report{"Bendio 3D Land", seed_output, bendio_platforms_func(18n, 0n, seed_platforms, 0), bendio_segments_func(seed_segments), 18n, 612n, bendio_u32_func(5n)}

assert bendio_self_check_func:
  Bool

def bendio_self_check_func():
  match bendio_report_seed_func(bendio_default_seed_func()):
    case Report{title, seed, platforms, segments, platform_count, frame_count, viewpoints}:
      Bool.and(Nat.is_eq(List.length(Platform, platforms), 18n), Nat.is_eq(List.length(CourseSegment, segments), 17n))

assert main_value:
  Report

def main_value():
  bendio_report_seed_func(bendio_default_seed_func())

assert main_accept_value:
  forall value: Report
  IO(Unit)

def main_accept_value(value):
  IO.print("Ready{}")

assert main:
  IO(Unit)

def main():
  main_accept_value(main_value!())
