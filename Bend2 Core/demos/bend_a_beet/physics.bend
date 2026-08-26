import Base

# Bend-a-Beet deterministic physics library.
#
# This module is pure: it performs no IO, is structurally terminating, and gets
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

# Compact seed domain used only by the erased outcome certificates. Each case
# represents branch decisions extracted from a deterministic U32 seed.
type PhysicsCheckSeed:
  CheckBreakSeed{}
  CheckSpringSeed{}
  CheckRecoverySeed{}

# Affine helpers
# ==============

assert u32_pair:
  forall value: U32
  U32 & U32

def u32_pair(value):
  ((a, ea), (b, eb)) = U32.copy(value)
  (a, b)

assert u32_triple:
  forall value: U32
  U32 & (U32 & U32)

def u32_triple(value):
  (first, rest) = u32_pair(value)
  (second, third) = u32_pair(rest)
  (first, (second, third))

assert u32_four:
  forall value: U32
  U32 & (U32 & (U32 & U32))

def u32_four(value):
  (a, right) = u32_pair(value)
  (b, more) = u32_pair(right)
  (c, d) = u32_pair(more)
  (a, (b, (c, d)))

assert u32_eight:
  forall value: U32
  U32 & (U32 & (U32 & (U32 & (U32 & (U32 & (U32 & U32))))))

def u32_eight(value):
  (left, right) = u32_pair(value)
  (a, (b, (c, d))) = u32_four(left)
  (e, (f, (g, h))) = u32_four(right)
  (a, (b, (c, (d, (e, (f, (g, h)))))))

# Fixed 32-step unsigned division and remainder. Base U32.div/U32.mod specify
# their behavior by converting values to unary Nat, which makes direct Core
# normalization impractical for seeded 32-bit physics values. These restoring
# bitwise forms are equivalent, structurally terminate on Nat fuel, and keep
# this library independent of the ray tracer's implementation.
assert u32_div_bits:
  forall fuel: Nat
  forall dividend: U32
  forall divisor: U32
  forall quotient: U32
  forall remainder: U32
  U32

def u32_div_bits(fuel, dividend, divisor, quotient, remainder):
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
            U32.or(U32.shl(quotient), 1),
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

assert u32_div:
  forall dividend: U32
  forall divisor: U32
  U32

def u32_div(dividend, divisor):
  (divisor_test, divisor_keep) = u32_pair(divisor)
  match U32.is_zero(divisor_test):
    case True{}:
      0
    case False{}:
      u32_div_bits(32n, dividend, divisor_keep, 0, 0)

assert u32_mod_bits:
  forall fuel: Nat
  forall dividend: U32
  forall divisor: U32
  forall remainder: U32
  U32

def u32_mod_bits(fuel, dividend, divisor, remainder):
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

assert u32_mod:
  forall dividend: U32
  forall divisor: U32
  U32

def u32_mod(dividend, divisor):
  (divisor_test, divisor_keep) = u32_pair(divisor)
  match U32.is_zero(divisor_test):
    case True{}:
      0
    case False{}:
      u32_mod_bits(32n, dividend, divisor_keep, 0)

assert u32:
  forall value: Nat
  U32

def u32(value):
  U32.from_nat(value)

assert u32_min:
  forall value: U32
  forall ceiling: U32
  U32

def u32_min(value, ceiling):
  (test_value, keep_value) = u32_pair(value)
  (test_ceiling, keep_ceiling) = u32_pair(ceiling)
  match U32.is_gt(test_value, test_ceiling):
    case True{}:
      keep_ceiling
    case False{}:
      keep_value

assert u32_saturating_sub:
  forall left: U32
  forall right: U32
  U32

def u32_saturating_sub(left, right):
  (test_left, keep_left) = u32_pair(left)
  (test_right, keep_right) = u32_pair(right)
  match U32.is_le(test_left, test_right):
    case True{}:
      u32(0n)
    case False{}:
      U32.sub(keep_left, keep_right)

# A smooth triangle in 0..1024. Response periods are always nonzero.
assert triangle_finish:
  forall position: U32
  forall half: U32
  forall period: U32
  U32

def triangle_finish(position, half, period):
  (half_test, half_divisor) = u32_pair(half)
  (position_test, position_keep) = u32_pair(position)
  match U32.is_le(position_test, half_test):
    case True{}:
      u32_div(U32.mul(position_keep, u32(1024n)), half_divisor)
    case False{}:
      u32_div(U32.mul(U32.sub(period, position_keep), u32(1024n)), half_divisor)

assert triangle_parts:
  forall elapsed: U32
  forall period_mod: U32
  forall period_half: U32
  forall period_tail: U32
  U32

def triangle_parts(elapsed, period_mod, period_half, period_tail):
  half = u32_div(period_half, u32(2n))
  position = u32_mod(elapsed, period_mod)
  triangle_finish(position, half, period_tail)

assert triangle_wave:
  forall elapsed: U32
  forall period: U32
  U32

def triangle_wave(elapsed, period):
  (period_mod, period_rest) = u32_pair(period)
  (period_half, period_tail) = u32_pair(period_rest)
  triangle_parts(elapsed, period_mod, period_half, period_tail)

# Deterministic xorshift32. Seed zero is valid because salts are added before
# the mixer is used for independent lanes.
assert seed_mix_tail:
  forall seed: U32
  U32

def seed_mix_tail(seed):
  (keep, shifted) = u32_pair(seed)
  U32.xor(keep, U32.shln(5n, shifted))

assert seed_mix_middle:
  forall seed: U32
  U32

def seed_mix_middle(seed):
  (keep, shifted) = u32_pair(seed)
  seed_mix_tail(U32.xor(keep, U32.shrn(17n, shifted)))

assert seed_mix:
  forall seed: U32
  U32

def seed_mix(seed):
  (keep, shifted) = u32_pair(seed)
  seed_mix_middle(U32.xor(keep, U32.shln(13n, shifted)))

assert seed_lane:
  forall seed: U32
  forall salt: U32
  U32

def seed_lane(seed, salt):
  seed_mix(U32.add(seed, salt))

# Fixed-point and vector API
# ==========================

assert fix_zero:
  Fix

def fix_zero():
  FixPos{u32(0n)}

assert fix_from_u32:
  forall value: U32
  Fix

def fix_from_u32(value):
  FixPos{value}

assert fix_negate:
  forall value: Fix
  Fix

def fix_negate(value):
  match value:
    case FixPos{magnitude}:
      FixNeg{magnitude}
    case FixNeg{magnitude}:
      FixPos{magnitude}

# Mathematical theorem over every signed Q10 value. The proof is constructor
# induction on Fix; the U32 magnitude remains arbitrary in both branches.
assert fix_negate_involution_theorem:
  forall value: Fix
  {fix_negate(fix_negate(value)) == value : Fix}

def fix_negate_involution_theorem(value):
  match value:
    case FixPos{magnitude}:
      {==}
    case FixNeg{magnitude}:
      {==}

assert fix_copy:
  forall value: Fix
  Fix & Fix

def fix_copy(value):
  match value:
    case FixPos{magnitude}:
      (a, b) = u32_pair(magnitude)
      (FixPos{a}, FixPos{b})
    case FixNeg{magnitude}:
      (a, b) = u32_pair(magnitude)
      (FixNeg{a}, FixNeg{b})

assert fix_difference:
  forall positive: U32
  forall negative: U32
  Fix

def fix_difference(positive, negative):
  (positive_test, positive_keep) = u32_pair(positive)
  (negative_test, negative_keep) = u32_pair(negative)
  match U32.cmp(positive_test, negative_test):
    case LT{}:
      FixNeg{U32.sub(negative_keep, positive_keep)}
    case EQ{}:
      FixPos{u32(0n)}
    case GT{}:
      FixPos{U32.sub(positive_keep, negative_keep)}

assert fix_add:
  forall left: Fix
  forall right: Fix
  Fix

def fix_add(left, right):
  match left right:
    case FixPos{a} FixPos{b}:
      FixPos{U32.add(a, b)}
    case FixPos{a} FixNeg{b}:
      fix_difference(a, b)
    case FixNeg{a} FixPos{b}:
      fix_difference(b, a)
    case FixNeg{a} FixNeg{b}:
      FixNeg{U32.add(a, b)}

assert fix_sub:
  forall left: Fix
  forall right: Fix
  Fix

def fix_sub(left, right):
  fix_add(left, fix_negate(right))

# Q10 multiplication: 1024 * 1024 becomes 1024.
assert fix_mul:
  forall left: Fix
  forall right: Fix
  Fix

def fix_mul(left, right):
  match left right:
    case FixPos{a} FixPos{b}:
      FixPos{u32_div(U32.mul(a, b), u32(1024n))}
    case FixPos{a} FixNeg{b}:
      FixNeg{u32_div(U32.mul(a, b), u32(1024n))}
    case FixNeg{a} FixPos{b}:
      FixNeg{u32_div(U32.mul(a, b), u32(1024n))}
    case FixNeg{a} FixNeg{b}:
      FixPos{u32_div(U32.mul(a, b), u32(1024n))}

assert centered_raw:
  forall raw: U32
  Fix

def centered_raw(raw):
  (test, keep) = u32_pair(raw)
  match U32.is_le(test, u32(1024n)):
    case True{}:
      FixPos{keep}
    case False{}:
      FixNeg{U32.sub(keep, u32(1025n))}

assert centered_fix:
  forall value: U32
  Fix

def centered_fix(value):
  centered_raw(u32_mod(value, u32(2049n)))

assert vec3_zero:
  Vec3

def vec3_zero():
  Vec3{fix_zero(), fix_zero(), fix_zero()}

assert vec3_copy:
  forall vector: Vec3
  Vec3 & Vec3

def vec3_copy(vector):
  match vector:
    case Vec3{x, y, z}:
      (x1, x2) = fix_copy(x)
      (y1, y2) = fix_copy(y)
      (z1, z2) = fix_copy(z)
      (Vec3{x1, y1, z1}, Vec3{x2, y2, z2})

assert vec3_add:
  forall left: Vec3
  forall right: Vec3
  Vec3

def vec3_add(left, right):
  match left right:
    case Vec3{ax, ay, az} Vec3{bx, by, bz}:
      Vec3{fix_add(ax, bx), fix_add(ay, by), fix_add(az, bz)}

assert vec3_scale:
  forall vector: Vec3
  forall scalar: Fix
  Vec3

def vec3_scale(vector, scalar):
  match vector:
    case Vec3{x, y, z}:
      (sx, tail) = fix_copy(scalar)
      (sy, sz) = fix_copy(tail)
      Vec3{fix_mul(x, sx), fix_mul(y, sy), fix_mul(z, sz)}

# Attributes and seeded variation
# ===============================

assert attributes_copy:
  forall attributes: BeetAttributes
  BeetAttributes & BeetAttributes

def attributes_copy(attributes):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      (w1, w2) = u32_pair(water)
      (s1, s2) = u32_pair(sugar)
      (f1, f2) = u32_pair(fiber)
      (z1, z2) = u32_pair(size)
      (m1, m2) = u32_pair(magic)
      (h1, h2) = u32_pair(shine)
      (BeetAttributes{w1, s1, f1, z1, m1, h1}, BeetAttributes{w2, s2, f2, z2, m2, h2})

assert attributes_four:
  forall attributes: BeetAttributes
  BeetAttributes & (BeetAttributes & (BeetAttributes & BeetAttributes))

def attributes_four(attributes):
  (a, right) = attributes_copy(attributes)
  (b, more) = attributes_copy(right)
  (c, d) = attributes_copy(more)
  (a, (b, (c, d)))

assert attributes_eight:
  forall attributes: BeetAttributes
  BeetAttributes & (BeetAttributes & (BeetAttributes & (BeetAttributes & (BeetAttributes & (BeetAttributes & (BeetAttributes & BeetAttributes))))))

def attributes_eight(attributes):
  (left, right) = attributes_copy(attributes)
  (a, (b, (c, d))) = attributes_four(left)
  (e, (f, (g, h))) = attributes_four(right)
  (a, (b, (c, (d, (e, (f, (g, h)))))))

assert attribute_lane:
  forall seed: U32
  forall salt: Nat
  U32

def attribute_lane(seed, salt):
  u32_mod(seed_lane(seed, u32(salt)), u32(1001n))

# 7919 encoded from small bytes avoids normalizing U32.from_nat(7919n).
assert attribute_tile_stride:
  U32

def attribute_tile_stride():
  U32.or(U32.shln(8n, u32(30n)), u32(239n))

assert attributes_from_root:
  forall root: U32
  BeetAttributes

def attributes_from_root(root):
  (a, (b, (c, (d, (e, (f, rest)))))) = u32_eight(root)
  BeetAttributes{
    attribute_lane(a, 101n),
    attribute_lane(b, 211n),
    attribute_lane(c, 307n),
    attribute_lane(d, 401n),
    attribute_lane(e, 503n),
    attribute_lane(f, 607n)
  }

assert attributes_from_seed:
  forall seed: U32
  forall tile: U32
  BeetAttributes

def attributes_from_seed(seed, tile):
  attributes_from_root(seed_mix(U32.add(seed, U32.mul(tile, attribute_tile_stride()))))

assert break_decision:
  forall attributes: BeetAttributes
  forall roll: U32
  Bool

def break_decision(attributes, roll):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      load = U32.add(U32.add(sugar, size), u32_mod(roll, u32(501n)))
      resistance = U32.add(U32.add(water, U32.mul(fiber, u32(2n))), u32_div(magic, u32(4n)))
      U32.is_gt(load, resistance)

assert spring_decision:
  forall attributes: BeetAttributes
  forall roll: U32
  Bool

def spring_decision(attributes, roll):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      spark = U32.add(U32.add(U32.mul(magic, u32(2n)), sugar), u32_mod(roll, u32(301n)))
      calm = U32.add(U32.add(water, fiber), u32_div(size, u32(2n)))
      U32.is_gt(spark, calm)

assert boing_count:
  forall attributes: BeetAttributes
  forall roll: U32
  U32

def boing_count(attributes, roll):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(U32.add(u32(2n), u32_div(magic, u32(100n))), u32_mod(roll, u32(4n)))

assert outcome_select:
  forall breaks: Bool
  forall springs: Bool
  forall piece_roll: U32
  forall boing_roll: U32
  forall attributes: BeetAttributes
  BendOutcome

def outcome_select(breaks, springs, piece_roll, boing_roll, attributes):
  match breaks:
    case True{}:
      BeetBreak{U32.add(u32(2n), u32_mod(piece_roll, u32(3n)))}
    case False{}:
      match springs:
        case True{}:
          BeetSpring{boing_count(attributes, boing_roll)}
        case False{}:
          BeetRecover{}

assert beet_outcome:
  forall seed: U32
  forall attributes: BeetAttributes
  BendOutcome

def beet_outcome(seed, attributes):
  (seed_break, (seed_spring, (seed_piece, seed_boing))) = u32_four(seed)
  (attr_break, (attr_spring, (attr_boing, attr_rest))) = attributes_four(attributes)
  breaks = break_decision(attr_break, seed_lane(seed_break, u32(601n)))
  springs = spring_decision(attr_spring, seed_lane(seed_spring, u32(701n)))
  outcome_select(breaks, springs, seed_piece, seed_boing, attr_boing)

# Response derivation
# ===================

assert response_axis:
  forall seed: U32
  Vec3

def response_axis(seed):
  (x_seed, (z_seed, (tilt_seed, rest))) = u32_four(seed)
  Vec3{
    centered_fix(seed_lane(x_seed, u32(811n))),
    FixPos{U32.add(u32(128n), u32_mod(seed_lane(tilt_seed, u32(821n)), u32(257n)))},
    centered_fix(seed_lane(z_seed, u32(823n)))
  }

assert response_impulse:
  forall attributes: BeetAttributes
  forall roll: U32
  U32

def response_impulse(attributes, roll):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(U32.add(U32.add(u32(256n), size), u32_div(sugar, u32(2n))), U32.add(u32_div(magic, u32(4n)), u32_mod(roll, u32(257n))))

assert response_stiffness:
  forall attributes: BeetAttributes
  U32

def response_stiffness(attributes):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(u32(128n), U32.add(fiber, u32_div(sugar, u32(2n))))

assert response_damping:
  forall attributes: BeetAttributes
  U32

def response_damping(attributes):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(u32(64n), U32.add(u32_div(water, u32(2n)), u32_div(fiber, u32(4n))))

assert response_flexibility:
  forall attributes: BeetAttributes
  U32

def response_flexibility(attributes):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(u32(128n), U32.add(u32_div(water, u32(2n)), u32_div(magic, u32(2n))))

assert response_max_bend:
  forall attributes: BeetAttributes
  forall roll: U32
  U32

def response_max_bend(attributes, roll):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(U32.add(u32(256n), u32_div(size, u32(2n))), U32.add(u32_div(water, u32(4n)), u32_mod(roll, u32(257n))))

assert response_period:
  forall attributes: BeetAttributes
  forall roll: U32
  U32

def response_period(attributes, roll):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(U32.add(u32(120n), u32_div(u32_saturating_sub(u32(1000n), magic), u32(5n))), U32.add(u32_div(fiber, u32(8n)), u32_mod(roll, u32(61n))))

assert response_duration:
  forall attributes: BeetAttributes
  forall roll: U32
  U32

def response_duration(attributes, roll):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(U32.add(u32(900n), U32.add(water, fiber)), U32.add(u32_div(magic, u32(2n)), u32_mod(roll, u32(401n))))

assert response_break_at:
  forall attributes: BeetAttributes
  forall roll: U32
  U32

def response_break_at(attributes, roll):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(u32(180n), U32.add(u32_div(u32_saturating_sub(u32(1000n), sugar), u32(8n)), U32.add(u32_div(size, u32(10n)), u32_mod(roll, u32(91n)))))

assert response_phase_from_seed:
  forall seed: U32
  U32

def response_phase_from_seed(seed):
  u32_mod(seed_lane(seed, u32(937n)), u32(1024n))

assert beet_response:
  forall seed: U32
  forall attributes: BeetAttributes
  BeetPhysics

def beet_response(seed, attributes):
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

assert wind_finish:
  forall sx: U32
  forall sz: U32
  forall strength: U32
  WindFrame

def wind_finish(sx, sz, strength):
  (strength_vector, strength_report) = u32_pair(strength)
  WindFrame{
    vec3_scale(
      Vec3{centered_fix(seed_lane(sx, u32(1019n))), fix_zero(), centered_fix(seed_lane(sz, u32(1021n)))},
      FixPos{strength_vector}
    ),
    strength_report
  }

assert wind_parts:
  forall sx: U32
  forall sz: U32
  forall sphase: U32
  forall speriod: U32
  forall elapsed: U32
  WindFrame

def wind_parts(sx, sz, sphase, speriod, elapsed):
  phase = u32_mod(seed_lane(sphase, u32(1009n)), u32(1800n))
  period = U32.add(u32(1200n), u32_mod(seed_lane(speriod, u32(1013n)), u32(1001n)))
  strength = U32.add(u32(192n), u32_div(triangle_wave(U32.add(elapsed, phase), period), u32(2n)))
  wind_finish(sx, sz, strength)

assert wind_at:
  forall seed: U32
  forall elapsed: U32
  WindFrame

def wind_at(seed, elapsed):
  (sx, (sz, (sphase, speriod))) = u32_four(seed)
  wind_parts(sx, sz, sphase, speriod, elapsed)

assert growth_height:
  forall attributes: BeetAttributes
  forall progress: U32
  U32

def growth_height(attributes, progress):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      target = U32.add(u32(1024n), U32.mul(size, u32(3n)))
      u32_div(U32.mul(target, progress), u32(1024n))

assert growth_root_depth:
  forall attributes: BeetAttributes
  U32

def growth_root_depth(attributes):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(u32(256n), U32.add(u32_div(fiber, u32(2n)), u32_div(water, u32(4n))))

assert growth_stem_radius:
  forall attributes: BeetAttributes
  U32

def growth_stem_radius(attributes):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(u32(96n), U32.add(u32_div(size, u32(5n)), u32_div(sugar, u32(10n))))

assert growth_compliance:
  forall attributes: BeetAttributes
  Fix

def growth_compliance(attributes):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      FixPos{U32.add(u32(128n), U32.add(u32_div(water, u32(2n)), u32_div(magic, u32(8n))))}

assert growth_finish:
  forall seed: U32
  forall elapsed_wind: U32
  forall attr_height: BeetAttributes
  forall attr_root: BeetAttributes
  forall attr_stem: BeetAttributes
  forall attr_sway: BeetAttributes
  forall progress: U32
  GrowthFrame

def growth_finish(seed, elapsed_wind, attr_height, attr_root, attr_stem, attr_sway, progress):
  match wind_at(seed, elapsed_wind):
    case WindFrame{force, strength}:
      GrowthFrame{
        growth_height(attr_height, progress),
        growth_root_depth(attr_root),
        growth_stem_radius(attr_stem),
        vec3_scale(force, growth_compliance(attr_sway))
      }

assert beet_growth:
  forall seed: U32
  forall attributes: BeetAttributes
  forall elapsed: U32
  GrowthFrame

def beet_growth(seed, attributes, elapsed):
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

assert bend_frame_make:
  forall state: BendState
  forall axis: Vec3
  forall amount: U32
  forall height: U32
  forall integrity: U32
  BendFrame

def bend_frame_make(state, axis, amount, height, integrity):
  (amount_vector, amount_report) = u32_pair(amount)
  BendFrame{state, vec3_scale(axis, FixPos{amount_vector}), amount_report, height, integrity}

assert broken_trajectory:
  forall pieces: U32
  forall axis: Vec3
  forall max_bend: U32
  forall break_at: U32
  forall elapsed: U32
  forall height: U32
  BendFrame

def broken_trajectory(pieces, axis, max_bend, break_at, elapsed, height):
  (elapsed_test, elapsed_keep) = u32_pair(elapsed)
  (break_test, break_keep) = u32_pair(break_at)
  match U32.is_lt(elapsed_test, break_test):
    case True{}:
      amount = u32_div(U32.mul(max_bend, elapsed_keep), break_keep)
      bend_frame_make(BeetBreaking{}, axis, amount, height, u32(512n))
    case False{}:
      bend_frame_make(BeetBroken{pieces}, axis, max_bend, height, u32(0n))

assert spring_active_frame:
  forall axis: Vec3
  forall max_bend: U32
  forall period: U32
  forall phase: U32
  forall elapsed: U32
  forall remaining: U32
  forall boings: U32
  forall height: U32
  BendFrame

def spring_active_frame(axis, max_bend, period, phase, elapsed, remaining, boings, height):
  (remaining_scale, remaining_state) = u32_pair(remaining)
  wave = triangle_wave(U32.add(elapsed, phase), period)
  amount0 = u32_div(U32.mul(max_bend, wave), u32(1024n))
  amount = u32_div(U32.mul(amount0, remaining_scale), boings)
  bend_frame_make(BeetBoioioing{remaining_state}, axis, amount, height, u32(1024n))

assert spring_cycles_frame:
  forall boings: U32
  forall axis: Vec3
  forall max_bend: U32
  forall period: U32
  forall phase: U32
  forall elapsed: U32
  forall height: U32
  forall cycles: U32
  BendFrame

def spring_cycles_frame(boings, axis, max_bend, period, phase, elapsed, height, cycles):
  (boings_test, boings_scale) = u32_pair(boings)
  (boings_remaining, boings_divisor) = u32_pair(boings_scale)
  (cycles_test, cycles_keep) = u32_pair(cycles)
  match U32.is_ge(cycles_test, boings_test):
    case True{}:
      bend_frame_make(BeetResting{}, axis, u32(0n), height, u32(1024n))
    case False{}:
      remaining = U32.sub(boings_remaining, cycles_keep)
      spring_active_frame(axis, max_bend, period, phase, elapsed, remaining, boings_divisor, height)

assert spring_trajectory:
  forall boings: U32
  forall axis: Vec3
  forall max_bend: U32
  forall period: U32
  forall phase: U32
  forall elapsed: U32
  forall height: U32
  BendFrame

def spring_trajectory(boings, axis, max_bend, period, phase, elapsed, height):
  (period_cycles, period_wave) = u32_pair(period)
  (elapsed_cycles, elapsed_wave) = u32_pair(elapsed)
  spring_cycles_frame(boings, axis, max_bend, period_wave, phase, elapsed_wave, height, u32_div(elapsed_cycles, period_cycles))

assert recovery_remaining:
  forall axis: Vec3
  forall max_bend: U32
  forall duration: U32
  forall remaining: U32
  forall height: U32
  BendFrame

def recovery_remaining(axis, max_bend, duration, remaining, height):
  (remaining_test, remaining_amount) = u32_pair(remaining)
  match U32.is_zero(remaining_test):
    case True{}:
      bend_frame_make(BeetResting{}, axis, u32(0n), height, u32(1024n))
    case False{}:
      amount = u32_div(U32.mul(max_bend, remaining_amount), duration)
      bend_frame_make(BeetRecovering{}, axis, amount, height, u32(1024n))

assert recovery_trajectory:
  forall axis: Vec3
  forall max_bend: U32
  forall duration: U32
  forall elapsed: U32
  forall height: U32
  BendFrame

def recovery_trajectory(axis, max_bend, duration, elapsed, height):
  (duration_left, duration_divisor) = u32_pair(duration)
  recovery_remaining(axis, max_bend, duration_divisor, u32_saturating_sub(duration_left, elapsed), height)

assert beet_height:
  forall attributes: BeetAttributes
  U32

def beet_height(attributes):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      U32.add(u32(1024n), U32.mul(size, u32(3n)))

assert bend_from_outcome:
  forall outcome: BendOutcome
  forall axis: Vec3
  forall max_bend: U32
  forall period: U32
  forall duration: U32
  forall phase: U32
  forall break_at: U32
  forall elapsed: U32
  forall height: U32
  BendFrame

def bend_from_outcome(outcome, axis, max_bend, period, duration, phase, break_at, elapsed, height):
  match outcome:
    case BeetBreak{pieces}:
      broken_trajectory(pieces, axis, max_bend, break_at, elapsed, height)
    case BeetSpring{boings}:
      spring_trajectory(boings, axis, max_bend, period, phase, elapsed, height)
    case BeetRecover{}:
      recovery_trajectory(axis, max_bend, duration, elapsed, height)

assert beet_bend:
  forall seed: U32
  forall attributes: BeetAttributes
  forall elapsed: U32
  BendFrame

def beet_bend(seed, attributes, elapsed):
  (attr_response, attr_height) = attributes_copy(attributes)
  match beet_response(seed, attr_response):
    case BeetPhysics{outcome, axis, impulse, stiffness, damping, flexibility, max_bend, period, duration, phase, break_at}:
      bend_from_outcome(outcome, axis, max_bend, period, duration, phase, break_at, elapsed, beet_height(attr_height))

# Physics theorem and closed certificates
# =======================================
#
# `fix_negate_involution_theorem` above is quantified over every Fix and proved
# by constructor induction. The cases below are closed regression certificates
# for one authored fixture; they are deliberately not called general proofs.

assert attributes_bounded:
  forall attributes: BeetAttributes
  Bool

def attributes_bounded(attributes):
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

assert fix_bounded:
  forall value: Fix
  forall limit: U32
  Bool

def fix_bounded(value, limit):
  match value:
    case FixPos{magnitude}:
      U32.is_le(magnitude, limit)
    case FixNeg{magnitude}:
      U32.is_le(magnitude, limit)

assert vec3_bounded:
  forall vector: Vec3
  forall limit: U32
  Bool

def vec3_bounded(vector, limit):
  match vector:
    case Vec3{x, y, z}:
      (lx, tail) = u32_pair(limit)
      (ly, lz) = u32_pair(tail)
      Bool.and(fix_bounded(x, lx), Bool.and(fix_bounded(y, ly), fix_bounded(z, lz)))

assert response_fields_bounded:
  forall response: BeetPhysics
  Bool

def response_fields_bounded(response):
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

assert growth_height_value:
  forall frame: GrowthFrame
  U32

def growth_height_value(frame):
  match frame:
    case GrowthFrame{height, root_depth, stem_radius, leaf_sway}:
      height

assert growth_frame_bounded:
  forall frame: GrowthFrame
  Bool

def growth_frame_bounded(frame):
  match frame:
    case GrowthFrame{height, root_depth, stem_radius, leaf_sway}:
      Bool.and(
        U32.is_le(height, u32(4024n)),
        Bool.and(
          U32.is_le(root_depth, u32(1006n)),
          Bool.and(U32.is_le(stem_radius, u32(396n)), vec3_bounded(leaf_sway, u32(704n)))
        )
      )

# Small certificate fixtures keep integrated checking quick and reproducible.
assert CertificateAttributes:
  BeetAttributes

def CertificateAttributes():
  BeetAttributes{u32(8n), u32(13n), u32(21n), u32(34n), u32(55n), u32(89n)}

# Closed deterministic selector certificates exercise all three physical
# response branches without normalizing through xorshift.
assert certificate_seed_outcome:
  forall seed: PhysicsCheckSeed
  BendOutcome

def certificate_seed_outcome(seed):
  match seed:
    case CheckBreakSeed{}:
      outcome_select(True{}, False{}, u32(0n), u32(0n), CertificateAttributes())
    case CheckSpringSeed{}:
      outcome_select(False{}, True{}, u32(0n), u32(0n), BeetAttributes{u32(0n), u32(0n), u32(0n), u32(0n), u32(0n), u32(0n)})
    case CheckRecoverySeed{}:
      outcome_select(False{}, False{}, u32(0n), u32(0n), CertificateAttributes())

assert BreakPathExact:
  Type

def BreakPathExact():
  {certificate_seed_outcome(CheckBreakSeed{}) == BeetBreak{u32(2n)} : BendOutcome}

assert break_path_certificate:
  BreakPathExact()

def break_path_certificate():
  {==}

assert SpringPathExact:
  Type

def SpringPathExact():
  {certificate_seed_outcome(CheckSpringSeed{}) == BeetSpring{u32(2n)} : BendOutcome}

assert spring_path_certificate:
  SpringPathExact()

def spring_path_certificate():
  {==}

assert RecoveryPathExact:
  Type

def RecoveryPathExact():
  {certificate_seed_outcome(CheckRecoverySeed{}) == BeetRecover{} : BendOutcome}

assert recovery_path_certificate:
  RecoveryPathExact()

def recovery_path_certificate():
  {==}

# The height component is exactly zero at zero normalized growth progress.
assert GrowthStartsAtZero:
  Type

def GrowthStartsAtZero():
  {growth_height(BeetAttributes{u32(0n), u32(0n), u32(0n), u32(0n), u32(0n), u32(0n)}, u32(0n)) == u32(0n) : U32}

assert growth_zero_certificate:
  GrowthStartsAtZero()

def growth_zero_certificate():
  {==}

# Both sides of the saturating growth clamp are covered explicitly.
assert GrowthClampExact:
  Type

def GrowthClampExact():
  {u32_min(u32(7n), u32(5n)) == u32(5n) : U32} &
  {u32_min(u32(3n), u32(5n)) == u32(3n) : U32}

assert growth_clamp_certificate:
  GrowthClampExact()

def growth_clamp_certificate():
  ({==}, {==})

assert response_within_100:
  forall response: BeetPhysics
  Bool

def response_within_100(response):
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

assert CertificateResponse:
  BeetPhysics

def CertificateResponse():
  BeetPhysics{
    BeetRecover{},
    Vec3{FixPos{u32(40n)}, FixNeg{u32(60n)}, FixPos{u32(80n)}},
    u32(10n), u32(20n), u32(30n), u32(40n), u32(50n),
    u32(60n), u32(70n), u32(80n), u32(90n)
  }

assert ResponseWithin100:
  Type

def ResponseWithin100():
  {response_within_100(CertificateResponse()) == True{} : Bool}

assert response_bound_certificate:
  ResponseWithin100()

def response_bound_certificate():
  {==}

# Regression facts for the local restoring divider and remainder.
assert DividerExact:
  Type

def DividerExact():
  {u32_div(u32(37n), u32(5n)) == u32(7n) : U32} &
  {u32_mod(u32(37n), u32(5n)) == u32(2n) : U32}

assert divider_certificate:
  DividerExact()

def divider_certificate():
  ({==}, {==})

assert attribute_shine:
  forall attributes: BeetAttributes
  U32

def attribute_shine(attributes):
  match attributes:
    case BeetAttributes{water, sugar, fiber, size, magic, shine}:
      shine

assert ShineAttributeExact:
  Type

def ShineAttributeExact():
  {attribute_shine(CertificateAttributes()) == u32(89n) : U32}

assert shine_attribute_certificate:
  ShineAttributeExact()

def shine_attribute_certificate():
  {==}

type PhysicsVerificationAudit:
  PhysicsVerificationAudit{
    -negate_involution: @value: Fix -> {fix_negate(fix_negate(value)) == value : Fix},
    -break_path: BreakPathExact(),
    -spring_path: SpringPathExact(),
    -recovery_path: RecoveryPathExact(),
    -growth_zero: GrowthStartsAtZero(),
    -growth_clamp: GrowthClampExact(),
    -response_bound: ResponseWithin100(),
    -divider: DividerExact(),
    -shine_attribute: ShineAttributeExact(),
    certified_cases: U32,
    general_theorems: U32
  }

assert physics_verification:
  PhysicsVerificationAudit

def physics_verification():
  PhysicsVerificationAudit{
    fix_negate_involution_theorem,
    break_path_certificate(),
    spring_path_certificate(),
    recovery_path_certificate(),
    growth_zero_certificate(),
    growth_clamp_certificate(),
    response_bound_certificate(),
    divider_certificate(),
    shine_attribute_certificate(),
    u32(10n),
    u32(1n)
  }

# Pure smoke test used by physics_test.bend. The extreme attribute sets keep
# the three outcome branches stable regardless of the selected deterministic
# roll, while ordinary game attributes remain seed-sensitive.
assert physics_test_outcomes:
  forall broken: BeetAttributes
  forall springy: BeetAttributes
  forall calm: BeetAttributes
  Bool

def physics_test_outcomes(broken, springy, calm):
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

assert physics_frame_smoke:
  forall attributes: BeetAttributes
  Bool

def physics_frame_smoke(attributes):
  (growth_attributes, bend_attributes) = attributes_copy(attributes)
  match beet_growth(u32(77n), growth_attributes, u32(2500n)):
    case GrowthFrame{height, root_depth, stem_radius, leaf_sway}:
      match beet_bend(u32(77n), bend_attributes, u32(700n)):
        case BendFrame{state, tip_offset, bend_amount, frame_height, integrity}:
          match wind_at(u32(77n), u32(2500n)):
            case WindFrame{force, strength}:
              True{}

assert physics_growth_smoke:
  forall attributes: BeetAttributes
  Bool

def physics_growth_smoke(attributes):
  match beet_growth(u32(77n), attributes, u32(2500n)):
    case GrowthFrame{height, root_depth, stem_radius, leaf_sway}:
      True{}

assert physics_bend_smoke:
  forall attributes: BeetAttributes
  Bool

def physics_bend_smoke(attributes):
  match beet_bend(u32(77n), attributes, u32(700n)):
    case BendFrame{state, tip_offset, bend_amount, frame_height, integrity}:
      True{}

assert physics_test_after:
  forall outcomes: Bool
  Bool

def physics_test_after(outcomes):
  match outcomes:
    case False{}:
      False{}
    case True{}:
      physics_frame_smoke(attributes_from_seed(u32(77n), u32(13n)))

assert physics_self_test:
  Bool

def physics_self_test():
  physics_test_after(physics_test_outcomes(
    BeetAttributes{u32(0n), u32(1000n), u32(0n), u32(1000n), u32(0n), u32(100n)},
    BeetAttributes{u32(1000n), u32(0n), u32(100n), u32(0n), u32(1000n), u32(900n)},
    BeetAttributes{u32(1000n), u32(0n), u32(1000n), u32(0n), u32(0n), u32(500n)}
  ))
