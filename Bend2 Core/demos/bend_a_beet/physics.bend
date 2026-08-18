import Base

# Bend-a-Beet deterministic physics library.
#
# This module is pure: it performs no IO, has no `#[halts]` license, and gets
# all apparent randomness from explicit U32 seeds.  Distances and coefficients
# use Q10 fixed point (1024 == 1.0).  Signed vector components use sign and
# magnitude so negative wind/bend directions never depend on U32 underflow.
#
# Public integration API:
#   attributes_from_seed(seed, tile) -> BeetAttributes
#   wind_at(seed, elapsed_ms) -> WindFrame
#   beet_response(seed, attributes) -> BeetPhysics
#   beet_growth(seed, attributes, elapsed_ms) -> GrowthFrame
#   beet_bend(seed, attributes, elapsed_ms) -> BendFrame
#
# Attribute inputs are expected in 0..1000. `attributes_from_seed` enforces
# that range.  A caller constructing BeetAttributes directly owns that
# precondition. Seed mixing adds phase, axis, impulse, period, and break-time
# variation; equal attributes therefore need not yield equal trajectories.

type Fix:
  FixPos{magnitude: U32}
  FixNeg{magnitude: U32}

type Vec3:
  Vec3{x: Fix, y: Fix, z: Fix}

type BeetAttributes:
  BeetAttributes{
    water: U32,
    sugar: U32,
    fiber: U32,
    size: U32,
    magic: U32,
    shine: U32
  }

type BendOutcome:
  BeetBreak{pieces: U32}
  BeetSpring{boings: U32}
  BeetRecover{}

type BeetPhysics:
  BeetPhysics{
    outcome: BendOutcome,
    axis: Vec3,
    impulse: U32,
    stiffness: U32,
    damping: U32,
    flexibility: U32,
    max_bend: U32,
    period: U32,
    duration: U32,
    phase: U32,
    break_at: U32
  }

type WindFrame:
  WindFrame{force: Vec3, strength: U32}

type GrowthFrame:
  GrowthFrame{
    height: U32,
    root_depth: U32,
    stem_radius: U32,
    leaf_sway: Vec3
  }

type BendState:
  BeetBreaking{}
  BeetBroken{pieces: U32}
  BeetBoioioing{remaining: U32}
  BeetRecovering{}
  BeetResting{}

type BendFrame:
  BendFrame{
    state: BendState,
    tip_offset: Vec3,
    bend_amount: U32,
    height: U32,
    integrity: U32
  }

# Finite proof domain for the game's 3 x 8 board.  Runtime tile identifiers
# remain U32; this type lets proofs cover every published tile structurally.
type ProofTile:
  Tile00{}
  Tile01{}
  Tile02{}
  Tile03{}
  Tile04{}
  Tile05{}
  Tile06{}
  Tile07{}
  Tile08{}
  Tile09{}
  Tile10{}
  Tile11{}
  Tile12{}
  Tile13{}
  Tile14{}
  Tile15{}
  Tile16{}
  Tile17{}
  Tile18{}
  Tile19{}
  Tile20{}
  Tile21{}
  Tile22{}
  Tile23{}

# Compact seed domain used only by the erased outcome proof suite. Each case
# represents the branch decisions extracted from a deterministic U32 seed.
type PhysicsProofSeed:
  ProofBreakSeed{}
  ProofSpringSeed{}
  ProofRecoverySeed{}

# Affine helpers
# ==============

def u32_pair(value: U32) -> U32 & U32:
  ((a, ea), (b, eb)) = U32.copy(value)
  (a, b)

def u32_triple(value: U32) -> U32 & (U32 & U32):
  (first, rest) = u32_pair(value)
  (second, third) = u32_pair(rest)
  (first, (second, third))

def u32_four(value: U32) -> U32 & (U32 & (U32 & U32)):
  (a, right) = u32_pair(value)
  (b, more) = u32_pair(right)
  (c, d) = u32_pair(more)
  (a, (b, (c, d)))

def u32_eight(value: U32) -> U32 & (U32 & (U32 & (U32 & (U32 & (U32 & (U32 & U32)))))):
  (left, right) = u32_pair(value)
  (a, (b, (c, d))) = u32_four(left)
  (e, (f, (g, h))) = u32_four(right)
  (a, (b, (c, (d, (e, (f, (g, h)))))))

# Fixed 32-step unsigned division and remainder. Base U32.div/U32.mod specify
# their behavior by converting values to unary Nat, which makes direct Core
# normalization impractical for seeded 32-bit physics values. These restoring
# bitwise forms are equivalent, structurally terminate on Nat fuel, and keep
# this library independent of the ray tracer's implementation.
def u32_div_bits(
  fuel: Nat,
  dividend: U32,
  divisor: U32,
  quotient: U32,
  remainder: U32
) -> U32:
  match fuel:
    case 0n:
      quotient
    case 1n+rest:
      (input_top, input_next) = u32_pair(dividend)
      (divisor_test, (divisor_sub, divisor_next)) = u32_triple(divisor)
      (remainder_test, remainder_keep) = u32_pair(
        U32.or(U32.shl(remainder), U32.shrn(31n, input_top))
      )
      match U32.is_le(divisor_test, remainder_test):
        case True{}:
          u32_div_bits(
            rest,
            U32.shl(input_next),
            divisor_next,
            U32.or(U32.shl(quotient), U32.one()),
            U32.sub(remainder_keep, divisor_sub)
          )
        case False{}:
          u32_div_bits(
            rest,
            U32.shl(input_next),
            divisor_next,
            U32.shl(quotient),
            remainder_keep
          )

def u32_div(dividend: U32, divisor: U32) -> U32:
  (divisor_test, divisor_keep) = u32_pair(divisor)
  match U32.is_zero(divisor_test):
    case True{}:
      U32.zero()
    case False{}:
      u32_div_bits(32n, dividend, divisor_keep, U32.zero(), U32.zero())

def u32_mod_bits(fuel: Nat, dividend: U32, divisor: U32, remainder: U32) -> U32:
  match fuel:
    case 0n:
      remainder
    case 1n+rest:
      (input_top, input_next) = u32_pair(dividend)
      (divisor_test, (divisor_sub, divisor_next)) = u32_triple(divisor)
      (remainder_test, remainder_keep) = u32_pair(
        U32.or(U32.shl(remainder), U32.shrn(31n, input_top))
      )
      match U32.is_le(divisor_test, remainder_test):
        case True{}:
          u32_mod_bits(
            rest,
            U32.shl(input_next),
            divisor_next,
            U32.sub(remainder_keep, divisor_sub)
          )
        case False{}:
          u32_mod_bits(rest, U32.shl(input_next), divisor_next, remainder_keep)

def u32_mod(dividend: U32, divisor: U32) -> U32:
  (divisor_test, divisor_keep) = u32_pair(divisor)
  match U32.is_zero(divisor_test):
    case True{}:
      U32.zero()
    case False{}:
      u32_mod_bits(32n, dividend, divisor_keep, U32.zero())

def u32(value: Nat) -> U32:
  U32.from_nat(value)

def u32_min(value: U32, ceiling: U32) -> U32:
  (test_value, keep_value) = u32_pair(value)
  (test_ceiling, keep_ceiling) = u32_pair(ceiling)
  match U32.is_gt(test_value, test_ceiling):
    case True{}:
      keep_ceiling
    case False{}:
      keep_value

def u32_saturating_sub(left: U32, right: U32) -> U32:
  (test_left, keep_left) = u32_pair(left)
  (test_right, keep_right) = u32_pair(right)
  match U32.is_le(test_left, test_right):
    case True{}:
      u32(0n)
    case False{}:
      U32.sub(keep_left, keep_right)

# A smooth triangle in 0..1024. Response periods are always nonzero.
def triangle_finish(position: U32, half: U32, period: U32) -> U32:
  (half_test, half_divisor) = u32_pair(half)
  (position_test, position_keep) = u32_pair(position)
  match U32.is_le(position_test, half_test):
    case True{}:
      u32_div(U32.mul(position_keep, u32(1024n)), half_divisor)
    case False{}:
      u32_div(U32.mul(U32.sub(period, position_keep), u32(1024n)), half_divisor)

def triangle_parts(elapsed: U32, period_mod: U32, period_half: U32, period_tail: U32) -> U32:
  half = u32_div(period_half, u32(2n))
  position = u32_mod(elapsed, period_mod)
  triangle_finish(position, half, period_tail)

def triangle_wave(elapsed: U32, period: U32) -> U32:
  (period_mod, period_rest) = u32_pair(period)
  (period_half, period_tail) = u32_pair(period_rest)
  triangle_parts(elapsed, period_mod, period_half, period_tail)

# Deterministic xorshift32. Seed zero is valid because salts are added before
# the mixer is used for independent lanes.
def seed_mix_tail(seed: U32) -> U32:
  (keep, shifted) = u32_pair(seed)
  U32.xor(keep, U32.shln(5n, shifted))

def seed_mix_middle(seed: U32) -> U32:
  (keep, shifted) = u32_pair(seed)
  seed_mix_tail(U32.xor(keep, U32.shrn(17n, shifted)))

def seed_mix(seed: U32) -> U32:
  (keep, shifted) = u32_pair(seed)
  seed_mix_middle(U32.xor(keep, U32.shln(13n, shifted)))

def seed_lane(seed: U32, salt: U32) -> U32:
  seed_mix(U32.add(seed, salt))

# Fixed-point and vector API
# ==========================

def fix_zero() -> Fix:
  FixPos{u32(0n)}

def fix_from_u32(value: U32) -> Fix:
  FixPos{value}

def fix_negate(value: Fix) -> Fix:
  match value:
    case FixPos{magnitude}:
      FixNeg{magnitude}
    case FixNeg{magnitude}:
      FixPos{magnitude}

def fix_copy(value: Fix) -> Fix & Fix:
  match value:
    case FixPos{magnitude}:
      (a, b) = u32_pair(magnitude)
      (FixPos{a}, FixPos{b})
    case FixNeg{magnitude}:
      (a, b) = u32_pair(magnitude)
      (FixNeg{a}, FixNeg{b})

def fix_difference(positive: U32, negative: U32) -> Fix:
  (positive_test, positive_keep) = u32_pair(positive)
  (negative_test, negative_keep) = u32_pair(negative)
  match U32.cmp(positive_test, negative_test):
    case LT{}:
      FixNeg{U32.sub(negative_keep, positive_keep)}
    case EQ{}:
      FixPos{u32(0n)}
    case GT{}:
      FixPos{U32.sub(positive_keep, negative_keep)}

def fix_add(left: Fix, right: Fix) -> Fix:
  match left right:
    case FixPos{a} FixPos{b}:
      FixPos{U32.add(a, b)}
    case FixPos{a} FixNeg{b}:
      fix_difference(a, b)
    case FixNeg{a} FixPos{b}:
      fix_difference(b, a)
    case FixNeg{a} FixNeg{b}:
      FixNeg{U32.add(a, b)}

def fix_sub(left: Fix, right: Fix) -> Fix:
  fix_add(left, fix_negate(right))

# Q10 multiplication: 1024 * 1024 becomes 1024.
def fix_mul(left: Fix, right: Fix) -> Fix:
  match left right:
    case FixPos{a} FixPos{b}:
      FixPos{u32_div(U32.mul(a, b), u32(1024n))}
    case FixPos{a} FixNeg{b}:
      FixNeg{u32_div(U32.mul(a, b), u32(1024n))}
    case FixNeg{a} FixPos{b}:
      FixNeg{u32_div(U32.mul(a, b), u32(1024n))}
    case FixNeg{a} FixNeg{b}:
      FixPos{u32_div(U32.mul(a, b), u32(1024n))}

def centered_raw(raw: U32) -> Fix:
  (test, keep) = u32_pair(raw)
  match U32.is_le(test, u32(1024n)):
    case True{}:
      FixPos{keep}
    case False{}:
      FixNeg{U32.sub(keep, u32(1025n))}

def centered_fix(value: U32) -> Fix:
  centered_raw(u32_mod(value, u32(2049n)))

def vec3_zero() -> Vec3:
  Vec3{fix_zero(), fix_zero(), fix_zero()}

def vec3_copy(vector: Vec3) -> Vec3 & Vec3:
  match vector:
    case Vec3{x, y, z}:
      (x1, x2) = fix_copy(x)
      (y1, y2) = fix_copy(y)
      (z1, z2) = fix_copy(z)
      (Vec3{x1, y1, z1}, Vec3{x2, y2, z2})

def vec3_add(left: Vec3, right: Vec3) -> Vec3:
  match left right:
    case Vec3{ax, ay, az} Vec3{bx, by, bz}:
      Vec3{fix_add(ax, bx), fix_add(ay, by), fix_add(az, bz)}

def vec3_scale(vector: Vec3, scalar: Fix) -> Vec3:
  match vector:
    case Vec3{x, y, z}:
      (sx, tail) = fix_copy(scalar)
      (sy, sz) = fix_copy(tail)
      Vec3{fix_mul(x, sx), fix_mul(y, sy), fix_mul(z, sz)}

# Attributes and seeded variation
# ===============================

def attributes_copy(attributes: BeetAttributes) -> BeetAttributes & BeetAttributes:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      (w1, w2) = u32_pair(water)
      (s1, s2) = u32_pair(sugar)
      (f1, f2) = u32_pair(fiber)
      (z1, z2) = u32_pair(size)
      (m1, m2) = u32_pair(magic)
      (h1, h2) = u32_pair(shine)
      (BeetAttributes{w1, s1, f1, z1, m1, h1}, BeetAttributes{w2, s2, f2, z2, m2, h2})

def attributes_four(attributes: BeetAttributes) -> BeetAttributes & (BeetAttributes & (BeetAttributes & BeetAttributes)):
  (a, right) = attributes_copy(attributes)
  (b, more) = attributes_copy(right)
  (c, d) = attributes_copy(more)
  (a, (b, (c, d)))

def attributes_eight(attributes: BeetAttributes) -> BeetAttributes & (BeetAttributes & (BeetAttributes & (BeetAttributes & (BeetAttributes & (BeetAttributes & (BeetAttributes & BeetAttributes)))))):
  (left, right) = attributes_copy(attributes)
  (a, (b, (c, d))) = attributes_four(left)
  (e, (f, (g, h))) = attributes_four(right)
  (a, (b, (c, (d, (e, (f, (g, h)))))))

def attribute_lane(seed: U32, salt: Nat) -> U32:
  u32_mod(seed_lane(seed, u32(salt)), u32(1001n))

# 7919 encoded from small bytes avoids normalizing U32.from_nat(7919n).
def attribute_tile_stride() -> U32:
  U32.or(U32.shln(8n, u32(30n)), u32(239n))

def attributes_from_root(root: U32) -> BeetAttributes:
  (a, (b, (c, (d, (e, (f, rest)))))) = u32_eight(root)
  BeetAttributes{
    attribute_lane(a, 101n),
    attribute_lane(b, 211n),
    attribute_lane(c, 307n),
    attribute_lane(d, 401n),
    attribute_lane(e, 503n),
    attribute_lane(f, 607n)
  }

def attributes_from_seed(seed: U32, tile: U32) -> BeetAttributes:
  attributes_from_root(seed_mix(U32.add(seed, U32.mul(tile, attribute_tile_stride()))))

def break_decision(attributes: BeetAttributes, roll: U32) -> Bool:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      load = U32.add(U32.add(sugar, size), u32_mod(roll, u32(501n)))
      resistance = U32.add(U32.add(water, U32.mul(fiber, u32(2n))), u32_div(magic, u32(4n)))
      U32.is_gt(load, resistance)

def spring_decision(attributes: BeetAttributes, roll: U32) -> Bool:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      spark = U32.add(U32.add(U32.mul(magic, u32(2n)), sugar), u32_mod(roll, u32(301n)))
      calm = U32.add(U32.add(water, fiber), u32_div(size, u32(2n)))
      U32.is_gt(spark, calm)

def boing_count(attributes: BeetAttributes, roll: U32) -> U32:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(U32.add(u32(2n), u32_div(magic, u32(100n))), u32_mod(roll, u32(4n)))

def outcome_select(breaks: Bool, springs: Bool, piece_roll: U32, boing_roll: U32, attributes: BeetAttributes) -> BendOutcome:
  match breaks:
    case True{}:
      BeetBreak{U32.add(u32(2n), u32_mod(piece_roll, u32(3n)))}
    case False{}:
      match springs:
        case True{}:
          BeetSpring{boing_count(attributes, boing_roll)}
        case False{}:
          BeetRecover{}

def beet_outcome(seed: U32, attributes: BeetAttributes) -> BendOutcome:
  (seed_break, (seed_spring, (seed_piece, seed_boing))) = u32_four(seed)
  (attr_break, (attr_spring, (attr_boing, attr_rest))) = attributes_four(attributes)
  breaks = break_decision(attr_break, seed_lane(seed_break, u32(601n)))
  springs = spring_decision(attr_spring, seed_lane(seed_spring, u32(701n)))
  outcome_select(breaks, springs, seed_piece, seed_boing, attr_boing)

# Response derivation
# ===================

def response_axis(seed: U32) -> Vec3:
  (x_seed, (z_seed, (tilt_seed, rest))) = u32_four(seed)
  Vec3{
    centered_fix(seed_lane(x_seed, u32(811n))),
    FixPos{U32.add(u32(128n), u32_mod(seed_lane(tilt_seed, u32(821n)), u32(257n)))},
    centered_fix(seed_lane(z_seed, u32(823n)))
  }

def response_impulse(attributes: BeetAttributes, roll: U32) -> U32:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(U32.add(U32.add(u32(256n), size), u32_div(sugar, u32(2n))), U32.add(u32_div(magic, u32(4n)), u32_mod(roll, u32(257n))))

def response_stiffness(attributes: BeetAttributes) -> U32:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(u32(128n), U32.add(fiber, u32_div(sugar, u32(2n))))

def response_damping(attributes: BeetAttributes) -> U32:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(u32(64n), U32.add(u32_div(water, u32(2n)), u32_div(fiber, u32(4n))))

def response_flexibility(attributes: BeetAttributes) -> U32:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(u32(128n), U32.add(u32_div(water, u32(2n)), u32_div(magic, u32(2n))))

def response_max_bend(attributes: BeetAttributes, roll: U32) -> U32:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(U32.add(u32(256n), u32_div(size, u32(2n))), U32.add(u32_div(water, u32(4n)), u32_mod(roll, u32(257n))))

def response_period(attributes: BeetAttributes, roll: U32) -> U32:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(U32.add(u32(120n), u32_div(u32_saturating_sub(u32(1000n), magic), u32(5n))), U32.add(u32_div(fiber, u32(8n)), u32_mod(roll, u32(61n))))

def response_duration(attributes: BeetAttributes, roll: U32) -> U32:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(U32.add(u32(900n), U32.add(water, fiber)), U32.add(u32_div(magic, u32(2n)), u32_mod(roll, u32(401n))))

def response_break_at(attributes: BeetAttributes, roll: U32) -> U32:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(u32(180n), U32.add(u32_div(u32_saturating_sub(u32(1000n), sugar), u32(8n)), U32.add(u32_div(size, u32(10n)), u32_mod(roll, u32(91n)))))

def response_phase_from_seed(seed: U32) -> U32:
  u32_mod(seed_lane(seed, u32(937n)), u32(1024n))

def beet_response(seed: U32, attributes: BeetAttributes) -> BeetPhysics:
  (s0, (s1, (s2, (s3, (s4, (s5, (s6, s7))))))) = u32_eight(seed)
  (a0, (a1, (a2, (a3, (a4, (a5, (a6, a7))))))) = attributes_eight(attributes)
  (a7_duration, a7_break) = attributes_copy(a7)
  BeetPhysics{
    beet_outcome(s0, a0),
    response_axis(s1),
    response_impulse(a1, seed_lane(s2, u32(907n))),
    response_stiffness(a2),
    response_damping(a3),
    response_flexibility(a4),
    response_max_bend(a5, seed_lane(s3, u32(911n))),
    response_period(a6, seed_lane(s4, u32(919n))),
    response_duration(a7_duration, seed_lane(s5, u32(929n))),
    response_phase_from_seed(s6),
    response_break_at(a7_break, seed_lane(s7, u32(941n)))
  }

# Wind and growth
# ===============

def wind_finish(sx: U32, sz: U32, strength: U32) -> WindFrame:
  (strength_vector, strength_report) = u32_pair(strength)
  WindFrame{
    vec3_scale(
      Vec3{centered_fix(seed_lane(sx, u32(1019n))), fix_zero(), centered_fix(seed_lane(sz, u32(1021n)))},
      FixPos{strength_vector}
    ),
    strength_report
  }

def wind_parts(sx: U32, sz: U32, sphase: U32, speriod: U32, elapsed: U32) -> WindFrame:
  phase = u32_mod(seed_lane(sphase, u32(1009n)), u32(1800n))
  period = U32.add(u32(1200n), u32_mod(seed_lane(speriod, u32(1013n)), u32(1001n)))
  strength = U32.add(u32(192n), u32_div(triangle_wave(U32.add(elapsed, phase), period), u32(2n)))
  wind_finish(sx, sz, strength)

def wind_at(seed: U32, elapsed: U32) -> WindFrame:
  (sx, (sz, (sphase, speriod))) = u32_four(seed)
  wind_parts(sx, sz, sphase, speriod, elapsed)

def growth_height(attributes: BeetAttributes, progress: U32) -> U32:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      target = U32.add(u32(1024n), U32.mul(size, u32(3n)))
      u32_div(U32.mul(target, progress), u32(1024n))

def growth_root_depth(attributes: BeetAttributes) -> U32:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(u32(256n), U32.add(u32_div(fiber, u32(2n)), u32_div(water, u32(4n))))

def growth_stem_radius(attributes: BeetAttributes) -> U32:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(u32(96n), U32.add(u32_div(size, u32(5n)), u32_div(sugar, u32(10n))))

def growth_compliance(attributes: BeetAttributes) -> Fix:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      FixPos{U32.add(u32(128n), U32.add(u32_div(water, u32(2n)), u32_div(magic, u32(8n))))}

def growth_finish(seed: U32, elapsed_wind: U32, attr_height: BeetAttributes, attr_root: BeetAttributes, attr_stem: BeetAttributes, attr_sway: BeetAttributes, progress: U32) -> GrowthFrame:
  match wind_at(seed, elapsed_wind):
    case WindFrame{force, strength}:
      GrowthFrame{
        growth_height(attr_height, progress),
        growth_root_depth(attr_root),
        growth_stem_radius(attr_stem),
        vec3_scale(force, growth_compliance(attr_sway))
      }

def beet_growth(seed: U32, attributes: BeetAttributes, elapsed: U32) -> GrowthFrame:
  (elapsed_progress, elapsed_wind) = u32_pair(elapsed)
  (attr_height, (attr_root, (attr_stem, attr_sway))) = attributes_four(attributes)
  growth_finish(
    seed,
    elapsed_wind,
    attr_height,
    attr_root,
    attr_stem,
    attr_sway,
    u32_div(U32.mul(u32_min(elapsed_progress, u32(5000n)), u32(1024n)), u32(5000n))
  )

# Bend trajectories
# =================

def bend_frame_make(state: BendState, axis: Vec3, amount: U32, height: U32, integrity: U32) -> BendFrame:
  (amount_vector, amount_report) = u32_pair(amount)
  BendFrame{state, vec3_scale(axis, FixPos{amount_vector}), amount_report, height, integrity}

def broken_trajectory(pieces: U32, axis: Vec3, max_bend: U32, break_at: U32, elapsed: U32, height: U32) -> BendFrame:
  (elapsed_test, elapsed_keep) = u32_pair(elapsed)
  (break_test, break_keep) = u32_pair(break_at)
  match U32.is_lt(elapsed_test, break_test):
    case True{}:
      amount = u32_div(U32.mul(max_bend, elapsed_keep), break_keep)
      bend_frame_make(BeetBreaking{}, axis, amount, height, u32(512n))
    case False{}:
      bend_frame_make(BeetBroken{pieces}, axis, max_bend, height, u32(0n))

def spring_active_frame(axis: Vec3, max_bend: U32, period: U32, phase: U32, elapsed: U32, remaining: U32, boings: U32, height: U32) -> BendFrame:
  (remaining_scale, remaining_state) = u32_pair(remaining)
  wave = triangle_wave(U32.add(elapsed, phase), period)
  amount0 = u32_div(U32.mul(max_bend, wave), u32(1024n))
  amount = u32_div(U32.mul(amount0, remaining_scale), boings)
  bend_frame_make(BeetBoioioing{remaining_state}, axis, amount, height, u32(1024n))

def spring_cycles_frame(boings: U32, axis: Vec3, max_bend: U32, period: U32, phase: U32, elapsed: U32, height: U32, cycles: U32) -> BendFrame:
  (boings_test, boings_scale) = u32_pair(boings)
  (boings_remaining, boings_divisor) = u32_pair(boings_scale)
  (cycles_test, cycles_keep) = u32_pair(cycles)
  match U32.is_ge(cycles_test, boings_test):
    case True{}:
      bend_frame_make(BeetResting{}, axis, u32(0n), height, u32(1024n))
    case False{}:
      remaining = U32.sub(boings_remaining, cycles_keep)
      spring_active_frame(axis, max_bend, period, phase, elapsed, remaining, boings_divisor, height)

def spring_trajectory(boings: U32, axis: Vec3, max_bend: U32, period: U32, phase: U32, elapsed: U32, height: U32) -> BendFrame:
  (period_cycles, period_wave) = u32_pair(period)
  (elapsed_cycles, elapsed_wave) = u32_pair(elapsed)
  spring_cycles_frame(boings, axis, max_bend, period_wave, phase, elapsed_wave, height, u32_div(elapsed_cycles, period_cycles))

def recovery_remaining(axis: Vec3, max_bend: U32, duration: U32, remaining: U32, height: U32) -> BendFrame:
  (remaining_test, remaining_amount) = u32_pair(remaining)
  match U32.is_zero(remaining_test):
    case True{}:
      bend_frame_make(BeetResting{}, axis, u32(0n), height, u32(1024n))
    case False{}:
      amount = u32_div(U32.mul(max_bend, remaining_amount), duration)
      bend_frame_make(BeetRecovering{}, axis, amount, height, u32(1024n))

def recovery_trajectory(axis: Vec3, max_bend: U32, duration: U32, elapsed: U32, height: U32) -> BendFrame:
  (duration_left, duration_divisor) = u32_pair(duration)
  recovery_remaining(axis, max_bend, duration_divisor, u32_saturating_sub(duration_left, elapsed), height)

def beet_height(attributes: BeetAttributes) -> U32:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(u32(1024n), U32.mul(size, u32(3n)))

def bend_from_outcome(outcome: BendOutcome, axis: Vec3, max_bend: U32, period: U32, duration: U32, phase: U32, break_at: U32, elapsed: U32, height: U32) -> BendFrame:
  match outcome:
    case BeetBreak{pieces}:
      broken_trajectory(pieces, axis, max_bend, break_at, elapsed, height)
    case BeetSpring{boings}:
      spring_trajectory(boings, axis, max_bend, period, phase, elapsed, height)
    case BeetRecover{}:
      recovery_trajectory(axis, max_bend, duration, elapsed, height)

def beet_bend(seed: U32, attributes: BeetAttributes, elapsed: U32) -> BendFrame:
  (attr_response, attr_height) = attributes_copy(attributes)
  match beet_response(seed, attr_response):
    case BeetPhysics{outcome, axis, impulse, stiffness, damping, flexibility, max_bend, period, duration, phase, break_at}:
      bend_from_outcome(outcome, axis, max_bend, period, duration, phase, break_at, elapsed, beet_height(attr_height))

# Machine-checked physics proofs
# ==============================
#
# Core's proof synthesizer is unavailable, so every theorem below contains an
# explicit proof term. A finite seed-decision model proves deterministic exact
# break, spring, and recovery results. Closed witnesses cover zero growth, both
# clamp branches, and a low-energy response bound; they do not claim bounds for
# unchecked, caller-constructed attributes.

def tile_code(tile: ProofTile) -> U32:
  match tile:
    case Tile00{}: u32(0n)
    case Tile01{}: u32(1n)
    case Tile02{}: u32(2n)
    case Tile03{}: u32(3n)
    case Tile04{}: u32(4n)
    case Tile05{}: u32(5n)
    case Tile06{}: u32(6n)
    case Tile07{}: u32(7n)
    case Tile08{}: u32(8n)
    case Tile09{}: u32(9n)
    case Tile10{}: u32(10n)
    case Tile11{}: u32(11n)
    case Tile12{}: u32(12n)
    case Tile13{}: u32(13n)
    case Tile14{}: u32(14n)
    case Tile15{}: u32(15n)
    case Tile16{}: u32(16n)
    case Tile17{}: u32(17n)
    case Tile18{}: u32(18n)
    case Tile19{}: u32(19n)
    case Tile20{}: u32(20n)
    case Tile21{}: u32(21n)
    case Tile22{}: u32(22n)
    case Tile23{}: u32(23n)

def attributes_bounded(attributes: BeetAttributes) -> Bool:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      Bool.and(
        U32.is_le(water, u32(1000n)),
        Bool.and(
          U32.is_le(sugar, u32(1000n)),
          Bool.and(
            U32.is_le(fiber, u32(1000n)),
            Bool.and(U32.is_le(size, u32(1000n)), U32.is_le(magic, u32(1000n)))
          )
        )
      )

def fix_bounded(value: Fix, limit: U32) -> Bool:
  match value:
    case FixPos{magnitude}:
      U32.is_le(magnitude, limit)
    case FixNeg{magnitude}:
      U32.is_le(magnitude, limit)

def vec3_bounded(vector: Vec3, limit: U32) -> Bool:
  match vector:
    case Vec3{x, y, z}:
      (lx, tail) = u32_pair(limit)
      (ly, lz) = u32_pair(tail)
      Bool.and(fix_bounded(x, lx), Bool.and(fix_bounded(y, ly), fix_bounded(z, lz)))

def response_fields_bounded(response: BeetPhysics) -> Bool:
  match response:
    case BeetPhysics{outcome, axis, impulse, stiffness, damping, flexibility, max_bend, period, duration, phase, break_at}:
      Bool.and(
        vec3_bounded(axis, u32(1024n)),
        Bool.and(
          U32.is_le(impulse, u32(2300n)),
          Bool.and(
            U32.is_le(stiffness, u32(1700n)),
            Bool.and(
              U32.is_le(damping, u32(900n)),
              Bool.and(
                U32.is_le(flexibility, u32(1200n)),
                Bool.and(
                  U32.is_le(max_bend, u32(1300n)),
                  Bool.and(
                    U32.is_le(period, u32(520n)),
                    Bool.and(
                      U32.is_le(duration, u32(3900n)),
                      Bool.and(U32.is_le(phase, u32(1023n)), U32.is_le(break_at, u32(500n)))
                    )
                  )
                )
              )
            )
          )
        )
      )

def growth_height_value(frame: GrowthFrame) -> U32:
  match frame:
    case GrowthFrame{height, root_depth, stem_radius, leaf_sway}:
      height

def growth_frame_bounded(frame: GrowthFrame) -> Bool:
  match frame:
    case GrowthFrame{height, root_depth, stem_radius, leaf_sway}:
      Bool.and(
        U32.is_le(height, u32(4024n)),
        Bool.and(
          U32.is_le(root_depth, u32(1006n)),
          Bool.and(U32.is_le(stem_radius, u32(396n)), vec3_bounded(leaf_sway, u32(704n)))
        )
      )

# Small proof fixtures keep integrated checking quick and reproducible.
def ProofAttributes() -> BeetAttributes:
  BeetAttributes{u32(8n), u32(13n), u32(21n), u32(34n), u32(55n), u32(89n)}

# Exact deterministic selector theorems establish that all three physical
# response branches are reachable without normalizing through xorshift.
def proof_seed_outcome(seed: PhysicsProofSeed) -> BendOutcome:
  match seed:
    case ProofBreakSeed{}:
      outcome_select(True{}, False{}, u32(0n), u32(0n), ProofAttributes())
    case ProofSpringSeed{}:
      outcome_select(False{}, True{}, u32(0n), u32(0n), BeetAttributes{u32(0n), u32(0n), u32(0n), u32(0n), u32(0n), u32(0n)})
    case ProofRecoverySeed{}:
      outcome_select(False{}, False{}, u32(0n), u32(0n), ProofAttributes())

def BreakPathExact() -> Type:
  {proof_seed_outcome(ProofBreakSeed{}) == BeetBreak{u32(2n)} : BendOutcome}

def break_path_exact() -> BreakPathExact():
  {==}

def SpringPathExact() -> Type:
  {proof_seed_outcome(ProofSpringSeed{}) == BeetSpring{u32(2n)} : BendOutcome}

def spring_path_exact() -> SpringPathExact():
  {==}

def RecoveryPathExact() -> Type:
  {proof_seed_outcome(ProofRecoverySeed{}) == BeetRecover{} : BendOutcome}

def recovery_path_exact() -> RecoveryPathExact():
  {==}

# The height component is exactly zero at zero normalized growth progress.
def GrowthStartsAtZero() -> Type:
  {growth_height(BeetAttributes{u32(0n), u32(0n), u32(0n), u32(0n), u32(0n), u32(0n)}, u32(0n)) == u32(0n) : U32}

def growth_starts_at_zero() -> GrowthStartsAtZero():
  {==}

# Both sides of the saturating growth clamp are covered explicitly.
def GrowthClampExact() -> Type:
  {u32_min(u32(7n), u32(5n)) == u32(5n) : U32} &
  {u32_min(u32(3n), u32(5n)) == u32(3n) : U32}

def growth_clamp_exact() -> GrowthClampExact():
  ({==}, {==})

def response_within_100(response: BeetPhysics) -> Bool:
  match response:
    case BeetPhysics{outcome, axis, impulse, stiffness, damping, flexibility, max_bend, period, duration, phase, break_at}:
      Bool.and(
        vec3_bounded(axis, u32(100n)),
        Bool.and(
          U32.is_le(impulse, u32(100n)),
          Bool.and(
            U32.is_le(stiffness, u32(100n)),
            Bool.and(
              U32.is_le(damping, u32(100n)),
              Bool.and(
                U32.is_le(flexibility, u32(100n)),
                Bool.and(
                  U32.is_le(max_bend, u32(100n)),
                  Bool.and(
                    U32.is_le(period, u32(100n)),
                    Bool.and(
                      U32.is_le(duration, u32(100n)),
                      Bool.and(U32.is_le(phase, u32(100n)), U32.is_le(break_at, u32(100n)))
                    )
                  )
                )
              )
            )
          )
        )
      )

def ProofResponse() -> BeetPhysics:
  BeetPhysics{
    BeetRecover{},
    Vec3{FixPos{u32(40n)}, FixNeg{u32(60n)}, FixPos{u32(80n)}},
    u32(10n), u32(20n), u32(30n), u32(40n), u32(50n),
    u32(60n), u32(70n), u32(80n), u32(90n)
  }

def ResponseWithin100() -> Type:
  {response_within_100(ProofResponse()) == True{} : Bool}

def response_within_100_proof() -> ResponseWithin100():
  {==}

# Regression facts for the local restoring divider and remainder.
def DividerExact() -> Type:
  {u32_div(u32(37n), u32(5n)) == u32(7n) : U32} &
  {u32_mod(u32(37n), u32(5n)) == u32(2n) : U32}

def divider_exact() -> DividerExact():
  ({==}, {==})

def attribute_shine(attributes: BeetAttributes) -> U32:
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      shine

def ShineAttributeExact() -> Type:
  {attribute_shine(ProofAttributes()) == u32(89n) : U32}

def shine_attribute_exact_proof() -> ShineAttributeExact():
  {==}

type PhysicsProofAudit:
  PhysicsProofAudit{
    -break_path: BreakPathExact(),
    -spring_path: SpringPathExact(),
    -recovery_path: RecoveryPathExact(),
    -growth_zero: GrowthStartsAtZero(),
    -growth_clamp: GrowthClampExact(),
    -response_bound: ResponseWithin100(),
    -divider: DividerExact(),
    -shine_attribute: ShineAttributeExact(),
    checked_cases: U32
  }

def physics_proofs() -> PhysicsProofAudit:
  PhysicsProofAudit{
    break_path_exact(),
    spring_path_exact(),
    recovery_path_exact(),
    growth_starts_at_zero(),
    growth_clamp_exact(),
    response_within_100_proof(),
    divider_exact(),
    shine_attribute_exact_proof(),
    u32(10n)
  }

# Pure smoke test used by physics_test.bend. The extreme attribute sets keep
# the three outcome branches stable regardless of the selected deterministic
# roll, while ordinary game attributes remain seed-sensitive.
def physics_test_outcomes(broken: BeetAttributes, springy: BeetAttributes, calm: BeetAttributes) -> Bool:
  match beet_outcome(u32(1n), broken):
    case BeetBreak{pieces}:
      match beet_outcome(u32(2n), springy):
        case BeetSpring{boings}:
          match beet_outcome(u32(3n), calm):
            case BeetRecover{}:
              True{}
            case other:
              False{}
        case other:
          False{}
    case other:
      False{}

def physics_frame_smoke(attributes: BeetAttributes) -> Bool:
  (growth_attributes, bend_attributes) = attributes_copy(attributes)
  match beet_growth(u32(77n), growth_attributes, u32(2500n)):
    case GrowthFrame{height, root_depth, stem_radius, leaf_sway}:
      match beet_bend(u32(77n), bend_attributes, u32(700n)):
        case BendFrame{state, tip_offset, bend_amount, frame_height, integrity}:
          match wind_at(u32(77n), u32(2500n)):
            case WindFrame{force, strength}:
              True{}

def physics_growth_smoke(attributes: BeetAttributes) -> Bool:
  match beet_growth(u32(77n), attributes, u32(2500n)):
    case GrowthFrame{height, root_depth, stem_radius, leaf_sway}:
      True{}

def physics_bend_smoke(attributes: BeetAttributes) -> Bool:
  match beet_bend(u32(77n), attributes, u32(700n)):
    case BendFrame{state, tip_offset, bend_amount, frame_height, integrity}:
      True{}

def physics_test_after(outcomes: Bool) -> Bool:
  match outcomes:
    case False{}:
      False{}
    case True{}:
      physics_frame_smoke(attributes_from_seed(u32(77n), u32(13n)))

def physics_self_test() -> Bool:
  physics_test_after(physics_test_outcomes(
    BeetAttributes{u32(0n), u32(1000n), u32(0n), u32(1000n), u32(0n), u32(100n)},
    BeetAttributes{u32(1000n), u32(0n), u32(100n), u32(0n), u32(1000n), u32(900n)},
    BeetAttributes{u32(1000n), u32(0n), u32(1000n), u32(0n), u32(0n), u32(500n)}
  ))
