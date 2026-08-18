import Base

# Pure fixed-point ray intersection and directional-lighting support for
# Bend-a-Beet.  There is no IO and no unsafe termination license in this file.
#
# Public units
# ------------
# Fix is signed Q24.8-style fixed point: raw 256 represents 1.0.  Farm scenes
# should stay within roughly +/- 256 world units so intermediate products fit
# comfortably in U32.  Light intensity is an integer in [0, 255].
#
# Public construction API
# -----------------------
# fix_pos(raw), fix_neg(raw), vec3(x,y,z), ray(origin,direction),
# sphere(center,radius), sun(direction,ambient,strength), default_sun().
# Radius and all Fix magnitudes are raw fixed-point U32 values.
#
# Public query API
# ----------------
# ray_sphere(ray,sphere) -> Hit, ray_plane_y(ray,height) -> Hit,
# shade_point(point,normal,sun,occluder) -> ShadeSample, and
# farm_light(ground,ground_normal,beet_surface,beet_normal,sun,beet)
# -> FarmLight.  Intersections, occlusion and Lambert lighting are all computed
# here in Bend; a browser renderer only decodes the resulting constructors.
# raytrace_proofs() packages ten erased, machine-checked reference theorems for
# arithmetic, intersections, lighting, and the combined farm sample.

type Fix:
  FixNeg{magnitude: U32}
  FixPos{magnitude: U32}

type Vec3:
  Vec3{x: Fix, y: Fix, z: Fix}

type Ray:
  Ray{origin: Vec3, direction: Vec3}

type Sphere:
  Sphere{center: Vec3, radius: U32}

type Sun:
  Sun{direction: Vec3, ambient: U32, strength: U32}

type Hit:
  Miss{}
  Hit{distance: U32}

type PositiveDistance:
  NoDistance{}
  HasDistance{distance: U32}

type ShadeSample:
  ShadeSample{intensity: U32, shadowed: Bool, hit_distance: U32}

type FarmLight:
  FarmLight{
    tile_intensity: U32,
    beet_intensity: U32,
    tile_shadowed: Bool,
    tile_hit_distance: U32
  }

type SurfaceLight:
  SurfaceLight{diffuse: U32, specular: U32, combined: U32, absorbed: U32}

type ShadowProjection:
  ShadowProjection{point: Vec3, visible: Bool, distance: U32}

# U32 helpers
# ===========

def u32_pair(value: U32) -> U32 & U32:
  ((left, left_exact), (right, right_exact)) = U32.copy(value)
  (left, right)

def u32_triple(value: U32) -> U32 & (U32 & U32):
  (first, rest) = u32_pair(value)
  (second, third) = u32_pair(rest)
  (first, (second, third))

def u32_clamp(value: U32, maximum: U32) -> U32:
  (test, keep) = u32_pair(value)
  (maximum_test, maximum_keep) = u32_pair(maximum)
  match U32.is_le(test, maximum_test):
    case True{}:
      keep
    case False{}:
      maximum_keep

# A 16-bit trial root covers every possible U32 square root.  Trying one bit
# per step avoids Base's unary-Nat U32.div specification and remains practical
# in both the normalizer and compiled backends.  The first live argument
# decreases structurally, so this requires no #[halts] escape hatch.
def u32_sqrt_bits(fuel: Nat, value: U32, root: U32, bit: U32) -> U32:
  match fuel:
    case 0n:
      root
    case 1n+rest:
      (value_test, value_next) = u32_pair(value)
      (root_candidate, root_keep) = u32_pair(root)
      (bit_candidate, bit_next) = u32_pair(bit)
      (candidate_left, (candidate_right, candidate_keep)) = u32_triple(U32.or(root_candidate, bit_candidate))
      match U32.is_le(U32.mul(candidate_left, candidate_right), value_test):
        case True{}:
          u32_sqrt_bits(rest, value_next, candidate_keep, U32.shr(bit_next))
        case False{}:
          u32_sqrt_bits(rest, value_next, root_keep, U32.shr(bit_next))

def u32_sqrt(value: U32) -> U32:
  u32_sqrt_bits(16n, value, U32.zero(), U32.shln(15n, U32.one()))

# Bitwise unsigned division.  Base's specification converts through unary Nat;
# this equivalent fixed 32-step form keeps ray arithmetic usable when directly
# normalized as well as when U32 operations are backend-intrinsic.
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

# Fixed point
# ===========

def fix_pos(raw: U32) -> Fix:
  FixPos{raw}

def fix_neg(raw: U32) -> Fix:
  (test, keep) = u32_pair(raw)
  match U32.is_zero(test):
    case True{}:
      FixPos{U32.zero()}
    case False{}:
      FixNeg{keep}

def fix_zero() -> Fix:
  FixPos{U32.zero()}

def fix_one() -> Fix:
  FixPos{U32.from_nat(256n)}

def fix_copy(value: Fix) -> Fix & Fix:
  match value:
    case FixNeg{magnitude}:
      (left, right) = u32_pair(magnitude)
      (FixNeg{left}, FixNeg{right})
    case FixPos{magnitude}:
      (left, right) = u32_pair(magnitude)
      (FixPos{left}, FixPos{right})

def fix_triple(value: Fix) -> Fix & (Fix & Fix):
  (first, rest) = fix_copy(value)
  (second, third) = fix_copy(rest)
  (first, (second, third))

def fix_negate(value: Fix) -> Fix:
  match value:
    case FixNeg{magnitude}:
      FixPos{magnitude}
    case FixPos{magnitude}:
      fix_neg(magnitude)

def fix_mixed_difference(positive: U32, negative: U32) -> Fix:
  (positive_test, positive_keep) = u32_pair(positive)
  (negative_test, negative_keep) = u32_pair(negative)
  match U32.is_le(negative_test, positive_test):
    case True{}:
      FixPos{U32.sub(positive_keep, negative_keep)}
    case False{}:
      FixNeg{U32.sub(negative_keep, positive_keep)}

def fix_add(left: Fix, right: Fix) -> Fix:
  match left right:
    case FixNeg{a} FixNeg{b}:
      FixNeg{U32.add(a, b)}
    case FixNeg{a} FixPos{b}:
      fix_mixed_difference(b, a)
    case FixPos{a} FixNeg{b}:
      fix_mixed_difference(a, b)
    case FixPos{a} FixPos{b}:
      FixPos{U32.add(a, b)}

def fix_sub(left: Fix, right: Fix) -> Fix:
  fix_add(left, fix_negate(right))

def fix_mul(left: Fix, right: Fix) -> Fix:
  match left right:
    case FixNeg{a} FixNeg{b}:
      FixPos{U32.shrn(8n, U32.mul(a, b))}
    case FixNeg{a} FixPos{b}:
      fix_neg(U32.shrn(8n, U32.mul(a, b)))
    case FixPos{a} FixNeg{b}:
      fix_neg(U32.shrn(8n, U32.mul(a, b)))
    case FixPos{a} FixPos{b}:
      FixPos{U32.shrn(8n, U32.mul(a, b))}

def fix_div(left: Fix, right: Fix) -> Fix:
  match left right:
    case FixNeg{a} FixNeg{b}:
      FixPos{u32_div(U32.shln(8n, a), b)}
    case FixNeg{a} FixPos{b}:
      fix_neg(u32_div(U32.shln(8n, a), b))
    case FixPos{a} FixNeg{b}:
      fix_neg(u32_div(U32.shln(8n, a), b))
    case FixPos{a} FixPos{b}:
      FixPos{u32_div(U32.shln(8n, a), b)}

def fix_square(value: Fix) -> Fix:
  (left, right) = fix_copy(value)
  fix_mul(left, right)

def fix_sqrt(value: Fix) -> Fix:
  match value:
    case FixNeg{magnitude}:
      FixPos{U32.zero()}
    case FixPos{magnitude}:
      FixPos{u32_sqrt(U32.shln(8n, magnitude))}

def fix_positive_distance(value: Fix) -> PositiveDistance:
  match value:
    case FixNeg{magnitude}:
      NoDistance{}
    case FixPos{magnitude}:
      (test, keep) = u32_pair(magnitude)
      match U32.is_zero(test):
        case True{}:
          NoDistance{}
        case False{}:
          HasDistance{keep}

def fix_unit_clamp(value: Fix) -> U32:
  match value:
    case FixNeg{magnitude}:
      U32.zero()
    case FixPos{magnitude}:
      u32_clamp(magnitude, U32.from_nat(256n))

# Vectors and constructors
# ========================

def vec3(x: Fix, y: Fix, z: Fix) -> Vec3:
  Vec3{x, y, z}

def vec3_raw(x: U32, y: U32, z: U32) -> Vec3:
  Vec3{FixPos{x}, FixPos{y}, FixPos{z}}

def vec3_copy(value: Vec3) -> Vec3 & Vec3:
  match value:
    case Vec3{x, y, z}:
      (x_left, x_right) = fix_copy(x)
      (y_left, y_right) = fix_copy(y)
      (z_left, z_right) = fix_copy(z)
      (Vec3{x_left, y_left, z_left}, Vec3{x_right, y_right, z_right})

def vec3_triple(value: Vec3) -> Vec3 & (Vec3 & Vec3):
  (first, rest) = vec3_copy(value)
  (second, third) = vec3_copy(rest)
  (first, (second, third))

def vec3_add(left: Vec3, right: Vec3) -> Vec3:
  match left right:
    case Vec3{ax, ay, az} Vec3{bx, by, bz}:
      Vec3{fix_add(ax, bx), fix_add(ay, by), fix_add(az, bz)}

def vec3_sub(left: Vec3, right: Vec3) -> Vec3:
  match left right:
    case Vec3{ax, ay, az} Vec3{bx, by, bz}:
      Vec3{fix_sub(ax, bx), fix_sub(ay, by), fix_sub(az, bz)}

def vec3_scale(value: Vec3, scalar: Fix) -> Vec3:
  match value:
    case Vec3{x, y, z}:
      (sx, (sy, sz)) = fix_triple(scalar)
      Vec3{fix_mul(x, sx), fix_mul(y, sy), fix_mul(z, sz)}

def vec3_dot(left: Vec3, right: Vec3) -> Fix:
  match left right:
    case Vec3{ax, ay, az} Vec3{bx, by, bz}:
      fix_add(
        fix_add(fix_mul(ax, bx), fix_mul(ay, by)),
        fix_mul(az, bz)
      )

def ray(origin: Vec3, direction: Vec3) -> Ray:
  Ray{origin, direction}

def sphere(center: Vec3, radius: U32) -> Sphere:
  Sphere{center, radius}

def sun(direction: Vec3, ambient: U32, strength: U32) -> Sun:
  Sun{direction, ambient, strength}

def default_sun() -> Sun:
  # A normalized-enough upward vector toward the upper-right/front sky.
  Sun{
    Vec3{FixPos{U32.from_nat(181n)}, FixPos{U32.from_nat(181n)}, FixPos{U32.from_nat(64n)}},
    U32.from_nat(40n),
    U32.from_nat(215n)
  }

# Intersections
# =============

def nearest_positive(near: Fix, far: Fix) -> Hit:
  match fix_positive_distance(near) fix_positive_distance(far):
    case NoDistance{} NoDistance{}:
      Miss{}
    case NoDistance{} HasDistance{distance}:
      Hit{distance}
    case HasDistance{distance} NoDistance{}:
      Hit{distance}
    case HasDistance{left} HasDistance{right}:
      (left_test, left_keep) = u32_pair(left)
      (right_test, right_keep) = u32_pair(right)
      match U32.is_le(left_test, right_test):
        case True{}:
          Hit{left_keep}
        case False{}:
          Hit{right_keep}

def ray_sphere(ray_value: Ray, sphere_value: Sphere) -> Hit:
  match ray_value sphere_value:
    case Ray{origin, direction} Sphere{center, radius}:
      (offset_half, (offset_len_left, offset_len_right)) = vec3_triple(vec3_sub(origin, center))
      (direction_half, (direction_len_left, direction_len_right)) = vec3_triple(direction)
      (half_b_square, half_b_roots) = fix_copy(vec3_dot(offset_half, direction_half))
      (a_discriminant, a_roots) = fix_copy(vec3_dot(direction_len_left, direction_len_right))
      match fix_sub(
        fix_square(half_b_square),
        fix_mul(
          a_discriminant,
          fix_sub(vec3_dot(offset_len_left, offset_len_right), fix_square(FixPos{radius}))
        )
      ):
        case FixNeg{magnitude}:
          Miss{}
        case FixPos{magnitude}:
          (half_b_near, half_b_far) = fix_copy(half_b_roots)
          (a_near, a_far) = fix_copy(a_roots)
          (root_near, root_far) = fix_copy(fix_sqrt(FixPos{magnitude}))
          near = fix_div(fix_sub(fix_negate(half_b_near), root_near), a_near)
          far = fix_div(fix_add(fix_negate(half_b_far), root_far), a_far)
          nearest_positive(near, far)

def ray_plane_y(ray_value: Ray, height: Fix) -> Hit:
  match ray_value:
    case Ray{Vec3{origin_x, origin_y, origin_z}, Vec3{direction_x, direction_y, direction_z}}:
      match fix_positive_distance(fix_div(fix_sub(height, origin_y), direction_y)):
        case NoDistance{}:
          Miss{}
        case HasDistance{distance}:
          Hit{distance}

# Directional sunlight and farm samples
# ======================================

def light_intensity(ambient: U32, strength: U32, lambert: U32) -> U32:
  u32_clamp(
    U32.add(ambient, U32.shrn(8n, U32.mul(strength, lambert))),
    U32.from_nat(255n)
  )

def reflected_direction(normal: Vec3, toward_light: Vec3) -> Vec3:
  (normal_dot, normal_scale) = vec3_copy(normal)
  (light_dot, light_subtract) = vec3_copy(toward_light)
  twice_lambert = fix_mul(
    vec3_dot(normal_dot, light_dot),
    FixPos{U32.shln(9n, U32.one())}
  )
  vec3_sub(vec3_scale(normal_scale, twice_lambert), light_subtract)

def surface_light_finish(diffuse: U32, specular: U32, combined: U32) -> SurfaceLight:
  (combined_report, combined_absorb) = u32_pair(combined)
  SurfaceLight{diffuse, specular, combined_report, U32.sub(U32.from_nat(255n), combined_absorb)}

def surface_light_parts(diffuse: U32, specular: U32) -> SurfaceLight:
  match u32_pair(diffuse) u32_pair(specular):
    case (diffuse_report, diffuse_combined) (specular_report, specular_combined):
      surface_light_finish(
        diffuse_report,
        specular_report,
        u32_clamp(U32.add(diffuse_combined, specular_combined), U32.from_nat(255n))
      )

# View-dependent Phong-style material response. Inputs are normalized Q24.8
# directions. `shine` and `roughness` are 0..255 material channels.
def surface_light(
  normal: Vec3,
  toward_light: Vec3,
  toward_viewer: Vec3,
  ambient: U32,
  strength: U32,
  shine: U32,
  roughness: U32
) -> SurfaceLight:
  (normal_diffuse, normal_reflect) = vec3_copy(normal)
  (light_diffuse, light_reflect) = vec3_copy(toward_light)
  lambert = fix_unit_clamp(vec3_dot(normal_diffuse, light_diffuse))
  diffuse = light_intensity(ambient, strength, lambert)
  reflection = fix_unit_clamp(vec3_dot(reflected_direction(normal_reflect, light_reflect), toward_viewer))
  dry = U32.sub(U32.from_nat(255n), u32_clamp(roughness, U32.from_nat(255n)))
  specular = U32.shrn(16n, U32.mul(U32.mul(shine, dry), reflection))
  surface_light_parts(diffuse, specular)

# Projects a world point along the direction travelled by sunlight onto Y=0.
# The result is world-space and therefore camera-independent; a renderer's
# view/projection matrix makes the visible shadow move correctly as it orbits.
def shadow_to_ground(origin: Vec3, light_travel: Vec3) -> ShadowProjection:
  (origin_ray, origin_result) = vec3_copy(origin)
  (direction_ray, direction_result) = vec3_copy(light_travel)
  match ray_plane_y(Ray{origin_ray, direction_ray}, fix_zero()):
    case Miss{}:
      ShadowProjection{origin_result, False{}, U32.zero()}
    case Hit{distance}:
      (distance_scale, distance_report) = u32_pair(distance)
      ShadowProjection{
        vec3_add(origin_result, vec3_scale(direction_result, FixPos{distance_scale})),
        True{},
        distance_report
      }

def shade_point(point: Vec3, normal: Vec3, sunlight: Sun, occluder: Sphere) -> ShadeSample:
  match sunlight:
    case Sun{direction, ambient, strength}:
      (light_direction, ray_direction) = vec3_copy(direction)
      match ray_sphere(Ray{point, ray_direction}, occluder):
        case Miss{}:
          ShadeSample{
            light_intensity(ambient, strength, fix_unit_clamp(vec3_dot(normal, light_direction))),
            False{},
            U32.zero()
          }
        case Hit{distance}:
          ShadeSample{ambient, True{}, distance}

def shade_unoccluded(normal: Vec3, sunlight: Sun) -> U32:
  match sunlight:
    case Sun{direction, ambient, strength}:
      light_intensity(ambient, strength, fix_unit_clamp(vec3_dot(normal, direction)))

def sun_copy(value: Sun) -> Sun & Sun:
  match value:
    case Sun{direction, ambient, strength}:
      (direction_left, direction_right) = vec3_copy(direction)
      (ambient_left, ambient_right) = u32_pair(ambient)
      (strength_left, strength_right) = u32_pair(strength)
      (
        Sun{direction_left, ambient_left, strength_left},
        Sun{direction_right, ambient_right, strength_right}
      )

def farm_light(
  ground: Vec3,
  ground_normal: Vec3,
  beet_surface: Vec3,
  beet_normal: Vec3,
  sunlight: Sun,
  beet: Sphere
) -> FarmLight:
  (ground_sun, beet_sun) = sun_copy(sunlight)
  match shade_point(ground, ground_normal, ground_sun, beet):
    case ShadeSample{tile_intensity, tile_shadowed, tile_hit_distance}:
      FarmLight{
        tile_intensity,
        shade_unoccluded(beet_normal, beet_sun),
        tile_shadowed,
        tile_hit_distance
      }

# Machine-checked reference cases
# ===============================
#
# Core's proof generator is unavailable, so these are explicit proof terms.
# They establish exact results for the arithmetic primitives and a canonical
# one-dimensional scene.  These claims are deliberately precise: they prove
# the named cases, rather than claiming universal floating-point accuracy or a
# complete renderer correctness theorem.

def proof_origin() -> Vec3:
  Vec3{fix_zero(), fix_zero(), fix_zero()}

def proof_x_normal() -> Vec3:
  Vec3{fix_one(), fix_zero(), fix_zero()}

def proof_front_ray() -> Ray:
  Ray{proof_origin(), proof_x_normal()}

def proof_back_ray() -> Ray:
  Ray{
    proof_origin(),
    Vec3{fix_neg(U32.shln(8n, U32.one())), fix_zero(), fix_zero()}
  }

def proof_down_ray() -> Ray:
  Ray{
    Vec3{fix_zero(), FixPos{U32.shln(9n, U32.one())}, fix_zero()},
    Vec3{fix_zero(), fix_neg(U32.shln(8n, U32.one())), fix_zero()}
  }

def proof_front_sphere() -> Sphere:
  Sphere{
    Vec3{FixPos{U32.shln(9n, U32.one())}, fix_zero(), fix_zero()},
    U32.shln(8n, U32.one())
  }

def proof_back_sphere() -> Sphere:
  Sphere{
    Vec3{FixNeg{U32.shln(9n, U32.one())}, fix_zero(), fix_zero()},
    U32.shln(8n, U32.one())
  }

def proof_x_sun() -> Sun:
  Sun{proof_x_normal(), U32.from_nat(40n), U32.from_nat(215n)}

def proof_divider_power_of_two() -> {
  u32_div(U32.shln(10n, U32.one()), U32.shln(8n, U32.one()))
  == U32.from_nat(4n) : U32
}:
  {==}

def proof_sqrt_square() -> {
  u32_sqrt(U32.shln(16n, U32.one())) == U32.shln(8n, U32.one()) : U32
}:
  {==}

def proof_sqrt_floor() -> {
  u32_sqrt(U32.from_nat(90n)) == U32.from_nat(9n) : U32
}:
  {==}

def proof_fixed_half_product() -> {
  fix_mul(fix_one(), FixPos{U32.shln(7n, U32.one())})
  == FixPos{U32.shln(7n, U32.one())} : Fix
}:
  {==}

def proof_sphere_front_hit() -> {
  ray_sphere(proof_front_ray(), proof_front_sphere())
  == Hit{U32.shln(8n, U32.one())} : Hit
}:
  {==}

def proof_sphere_behind_miss() -> {
  ray_sphere(proof_back_ray(), proof_front_sphere()) == Miss{} : Hit
}:
  {==}

def proof_plane_down_hit() -> {
  ray_plane_y(proof_down_ray(), fix_zero())
  == Hit{U32.shln(9n, U32.one())} : Hit
}:
  {==}

def proof_shadow_expected() -> {
  shade_point(proof_origin(), proof_x_normal(), proof_x_sun(), proof_front_sphere())
  == ShadeSample{
    U32.from_nat(40n),
    True{},
    U32.shln(8n, U32.one())
  } : ShadeSample
}:
  {==}

def proof_clear_expected() -> {
  shade_point(proof_origin(), proof_x_normal(), proof_x_sun(), proof_back_sphere())
  == ShadeSample{U32.from_nat(255n), False{}, U32.zero()} : ShadeSample
}:
  {==}

def proof_farm_expected() -> {
  farm_light(
    proof_origin(),
    proof_x_normal(),
    proof_origin(),
    proof_x_normal(),
    proof_x_sun(),
    proof_front_sphere()
  )
  == FarmLight{
    U32.from_nat(40n),
    U32.from_nat(255n),
    True{},
    U32.shln(8n, U32.one())
  } : FarmLight
}:
  {==}

def proof_surface_light_expected() -> {
  surface_light(
    proof_x_normal(), proof_x_normal(), proof_x_normal(),
    U32.from_nat(20n), U32.from_nat(100n),
    U32.from_nat(128n), U32.from_nat(64n)
  ) == SurfaceLight{
    U32.from_nat(120n), U32.from_nat(95n),
    U32.from_nat(215n), U32.from_nat(40n)
  } : SurfaceLight
}:
  {==}

def proof_shadow_projection_expected() -> {
  shadow_to_ground(
    Vec3{fix_zero(), FixPos{U32.shln(9n, U32.one())}, fix_zero()},
    Vec3{fix_zero(), fix_neg(U32.shln(8n, U32.one())), fix_zero()}
  ) == ShadowProjection{
    proof_origin(), True{}, U32.shln(9n, U32.one())
  } : ShadowProjection
}:
  {==}

type RaytraceProofs:
  RaytraceProofs{
    -divider_power_of_two: {
      u32_div(U32.shln(10n, U32.one()), U32.shln(8n, U32.one()))
      == U32.from_nat(4n) : U32
    },
    -sqrt_square: {
      u32_sqrt(U32.shln(16n, U32.one())) == U32.shln(8n, U32.one()) : U32
    },
    -sqrt_floor: {
      u32_sqrt(U32.from_nat(90n)) == U32.from_nat(9n) : U32
    },
    -fixed_half_product: {
      fix_mul(fix_one(), FixPos{U32.shln(7n, U32.one())})
      == FixPos{U32.shln(7n, U32.one())} : Fix
    },
    -sphere_front_hit: {
      ray_sphere(proof_front_ray(), proof_front_sphere())
      == Hit{U32.shln(8n, U32.one())} : Hit
    },
    -sphere_behind_miss: {
      ray_sphere(proof_back_ray(), proof_front_sphere()) == Miss{} : Hit
    },
    -plane_down_hit: {
      ray_plane_y(proof_down_ray(), fix_zero())
      == Hit{U32.shln(9n, U32.one())} : Hit
    },
    -shadow_expected: {
      shade_point(proof_origin(), proof_x_normal(), proof_x_sun(), proof_front_sphere())
      == ShadeSample{U32.from_nat(40n), True{}, U32.shln(8n, U32.one())} : ShadeSample
    },
    -clear_expected: {
      shade_point(proof_origin(), proof_x_normal(), proof_x_sun(), proof_back_sphere())
      == ShadeSample{U32.from_nat(255n), False{}, U32.zero()} : ShadeSample
    },
    -farm_expected: {
      farm_light(
        proof_origin(),
        proof_x_normal(),
        proof_origin(),
        proof_x_normal(),
        proof_x_sun(),
        proof_front_sphere()
      )
      == FarmLight{
        U32.from_nat(40n),
        U32.from_nat(255n),
        True{},
        U32.shln(8n, U32.one())
      } : FarmLight
    },
    -surface_light_expected: {
      surface_light(
        proof_x_normal(), proof_x_normal(), proof_x_normal(),
        U32.from_nat(20n), U32.from_nat(100n),
        U32.from_nat(128n), U32.from_nat(64n)
      ) == SurfaceLight{
        U32.from_nat(120n), U32.from_nat(95n),
        U32.from_nat(215n), U32.from_nat(40n)
      } : SurfaceLight
    },
    -shadow_projection_expected: {
      shadow_to_ground(
        Vec3{fix_zero(), FixPos{U32.shln(9n, U32.one())}, fix_zero()},
        Vec3{fix_zero(), fix_neg(U32.shln(8n, U32.one())), fix_zero()}
      ) == ShadowProjection{
        proof_origin(), True{}, U32.shln(9n, U32.one())
      } : ShadowProjection
    }
  }

def raytrace_proofs() -> RaytraceProofs:
  RaytraceProofs{
    proof_divider_power_of_two(),
    proof_sqrt_square(),
    proof_sqrt_floor(),
    proof_fixed_half_product(),
    proof_sphere_front_hit(),
    proof_sphere_behind_miss(),
    proof_plane_down_hit(),
    proof_shadow_expected(),
    proof_clear_expected(),
    proof_farm_expected(),
    proof_surface_light_expected(),
    proof_shadow_projection_expected()
  }
