import Base

# Pure fixed-point ray intersection and directional-lighting support for
# Bend-a-Beet. There is no IO, and every recursion is structurally terminating.
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
# raytrace_verification() packages one quantified theorem plus twelve erased,
# machine-checked reference certificates for arithmetic, intersections,
# lighting, and the combined farm sample.

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

assert u32_pair:
  forall value: U32
  U32 & U32

def u32_pair(value):
  ((left, left_exact), (right, right_exact)) = U32.copy(value)
  (left, right)

assert u32_triple:
  forall value: U32
  U32 & (U32 & U32)

def u32_triple(value):
  (first, rest) = u32_pair(value)
  (second, third) = u32_pair(rest)
  (first, (second, third))

assert u32_clamp:
  forall value: U32
  forall maximum: U32
  U32

def u32_clamp(value, maximum):
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
# decreases structurally, as required by the checker.
assert u32_sqrt_bits:
  forall fuel: Nat
  forall value: U32
  forall root: U32
  forall bit: U32
  U32

def u32_sqrt_bits(fuel, value, root, bit):
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

assert u32_sqrt:
  forall value: U32
  U32

def u32_sqrt(value):
  u32_sqrt_bits(16n, value, 0, U32.shln(15n, 1))

# Bitwise unsigned division.  Base's specification converts through unary Nat;
# this equivalent fixed 32-step form keeps ray arithmetic usable when directly
# normalized as well as when U32 operations are backend-intrinsic.
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

# Fixed point
# ===========

assert fix_pos:
  forall raw: U32
  Fix

def fix_pos(raw):
  FixPos{raw}

assert fix_neg:
  forall raw: U32
  Fix

def fix_neg(raw):
  (test, keep) = u32_pair(raw)
  match U32.is_zero(test):
    case True{}:
      FixPos{0}
    case False{}:
      FixNeg{keep}

assert fix_zero:
  Fix

def fix_zero():
  FixPos{0}

assert fix_one:
  Fix

def fix_one():
  FixPos{U32.from_nat(256n)}

assert fix_copy:
  forall value: Fix
  Fix & Fix

def fix_copy(value):
  match value:
    case FixNeg{magnitude}:
      (left, right) = u32_pair(magnitude)
      (FixNeg{left}, FixNeg{right})
    case FixPos{magnitude}:
      (left, right) = u32_pair(magnitude)
      (FixPos{left}, FixPos{right})

assert fix_triple:
  forall value: Fix
  Fix & (Fix & Fix)

def fix_triple(value):
  (first, rest) = fix_copy(value)
  (second, third) = fix_copy(rest)
  (first, (second, third))

assert fix_negate:
  forall value: Fix
  Fix

def fix_negate(value):
  match value:
    case FixNeg{magnitude}:
      FixPos{magnitude}
    case FixPos{magnitude}:
      fix_neg(magnitude)

assert fix_mixed_difference:
  forall positive: U32
  forall negative: U32
  Fix

def fix_mixed_difference(positive, negative):
  (positive_test, positive_keep) = u32_pair(positive)
  (negative_test, negative_keep) = u32_pair(negative)
  match U32.is_le(negative_test, positive_test):
    case True{}:
      FixPos{U32.sub(positive_keep, negative_keep)}
    case False{}:
      FixNeg{U32.sub(negative_keep, positive_keep)}

assert fix_add:
  forall left: Fix
  forall right: Fix
  Fix

def fix_add(left, right):
  match left right:
    case FixNeg{a} FixNeg{b}:
      FixNeg{U32.add(a, b)}
    case FixNeg{a} FixPos{b}:
      fix_mixed_difference(b, a)
    case FixPos{a} FixNeg{b}:
      fix_mixed_difference(a, b)
    case FixPos{a} FixPos{b}:
      FixPos{U32.add(a, b)}

assert fix_sub:
  forall left: Fix
  forall right: Fix
  Fix

def fix_sub(left, right):
  fix_add(left, fix_negate(right))

assert fix_mul:
  forall left: Fix
  forall right: Fix
  Fix

def fix_mul(left, right):
  match left right:
    case FixNeg{a} FixNeg{b}:
      FixPos{U32.shrn(8n, U32.mul(a, b))}
    case FixNeg{a} FixPos{b}:
      fix_neg(U32.shrn(8n, U32.mul(a, b)))
    case FixPos{a} FixNeg{b}:
      fix_neg(U32.shrn(8n, U32.mul(a, b)))
    case FixPos{a} FixPos{b}:
      FixPos{U32.shrn(8n, U32.mul(a, b))}

assert fix_div:
  forall left: Fix
  forall right: Fix
  Fix

def fix_div(left, right):
  match left right:
    case FixNeg{a} FixNeg{b}:
      FixPos{u32_div(U32.shln(8n, a), b)}
    case FixNeg{a} FixPos{b}:
      fix_neg(u32_div(U32.shln(8n, a), b))
    case FixPos{a} FixNeg{b}:
      fix_neg(u32_div(U32.shln(8n, a), b))
    case FixPos{a} FixPos{b}:
      FixPos{u32_div(U32.shln(8n, a), b)}

assert fix_square:
  forall value: Fix
  Fix

def fix_square(value):
  (left, right) = fix_copy(value)
  fix_mul(left, right)

assert fix_sqrt:
  forall value: Fix
  Fix

def fix_sqrt(value):
  match value:
    case FixNeg{magnitude}:
      FixPos{0}
    case FixPos{magnitude}:
      FixPos{u32_sqrt(U32.shln(8n, magnitude))}

assert fix_positive_distance:
  forall value: Fix
  PositiveDistance

def fix_positive_distance(value):
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

# Mathematical theorem over every negative fixed-point magnitude: a negative
# ray parameter can never be promoted to a forward hit. The magnitude is an
# arbitrary U32, not one of the closed reference-scene constants below.
assert negative_distance_rejected_theorem:
  forall magnitude: U32
  { fix_positive_distance(FixNeg{magnitude}) == NoDistance{} : PositiveDistance }

def negative_distance_rejected_theorem(magnitude):
  {==}

assert fix_unit_clamp:
  forall value: Fix
  U32

def fix_unit_clamp(value):
  match value:
    case FixNeg{magnitude}:
      0
    case FixPos{magnitude}:
      u32_clamp(magnitude, U32.from_nat(256n))

# Vectors and constructors
# ========================

assert vec3:
  forall x: Fix
  forall y: Fix
  forall z: Fix
  Vec3

def vec3(x, y, z):
  Vec3{x, y, z}

assert vec3_raw:
  forall x: U32
  forall y: U32
  forall z: U32
  Vec3

def vec3_raw(x, y, z):
  Vec3{FixPos{x}, FixPos{y}, FixPos{z}}

assert vec3_copy:
  forall value: Vec3
  Vec3 & Vec3

def vec3_copy(value):
  match value:
    case Vec3{x, y, z}:
      (x_left, x_right) = fix_copy(x)
      (y_left, y_right) = fix_copy(y)
      (z_left, z_right) = fix_copy(z)
      (Vec3{x_left, y_left, z_left}, Vec3{x_right, y_right, z_right})

assert vec3_triple:
  forall value: Vec3
  Vec3 & (Vec3 & Vec3)

def vec3_triple(value):
  (first, rest) = vec3_copy(value)
  (second, third) = vec3_copy(rest)
  (first, (second, third))

assert vec3_add:
  forall left: Vec3
  forall right: Vec3
  Vec3

def vec3_add(left, right):
  match left right:
    case Vec3{ax, ay, az} Vec3{bx, by, bz}:
      Vec3{fix_add(ax, bx), fix_add(ay, by), fix_add(az, bz)}

assert vec3_sub:
  forall left: Vec3
  forall right: Vec3
  Vec3

def vec3_sub(left, right):
  match left right:
    case Vec3{ax, ay, az} Vec3{bx, by, bz}:
      Vec3{fix_sub(ax, bx), fix_sub(ay, by), fix_sub(az, bz)}

assert vec3_scale:
  forall value: Vec3
  forall scalar: Fix
  Vec3

def vec3_scale(value, scalar):
  match value:
    case Vec3{x, y, z}:
      (sx, (sy, sz)) = fix_triple(scalar)
      Vec3{fix_mul(x, sx), fix_mul(y, sy), fix_mul(z, sz)}

assert vec3_dot:
  forall left: Vec3
  forall right: Vec3
  Fix

def vec3_dot(left, right):
  match left right:
    case Vec3{ax, ay, az} Vec3{bx, by, bz}:
      fix_add(
        fix_add(fix_mul(ax, bx), fix_mul(ay, by)),
        fix_mul(az, bz)
      )

assert ray:
  forall origin: Vec3
  forall direction: Vec3
  Ray

def ray(origin, direction):
  Ray{origin, direction}

assert sphere:
  forall center: Vec3
  forall radius: U32
  Sphere

def sphere(center, radius):
  Sphere{center, radius}

assert sun:
  forall direction: Vec3
  forall ambient: U32
  forall strength: U32
  Sun

def sun(direction, ambient, strength):
  Sun{direction, ambient, strength}

assert default_sun:
  Sun

def default_sun():
  # A normalized-enough upward vector toward the upper-right/front sky.
  Sun{
    Vec3{FixPos{U32.from_nat(181n)}, FixPos{U32.from_nat(181n)}, FixPos{U32.from_nat(64n)}},
    U32.from_nat(40n),
    U32.from_nat(215n)
  }

# Intersections
# =============

assert nearest_positive:
  forall near: Fix
  forall far: Fix
  Hit

def nearest_positive(near, far):
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

assert ray_sphere:
  forall ray_value: Ray
  forall sphere_value: Sphere
  Hit

def ray_sphere(ray_value, sphere_value):
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

assert ray_plane_y:
  forall ray_value: Ray
  forall height: Fix
  Hit

def ray_plane_y(ray_value, height):
  match ray_value:
    case Ray{Vec3{origin_x, origin_y, origin_z}, Vec3{direction_x, direction_y, direction_z}}:
      match fix_positive_distance(fix_div(fix_sub(height, origin_y), direction_y)):
        case NoDistance{}:
          Miss{}
        case HasDistance{distance}:
          Hit{distance}

# Directional sunlight and farm samples
# ======================================

assert light_intensity:
  forall ambient: U32
  forall strength: U32
  forall lambert: U32
  U32

def light_intensity(ambient, strength, lambert):
  u32_clamp(
    U32.add(ambient, U32.shrn(8n, U32.mul(strength, lambert))),
    U32.from_nat(255n)
  )

assert reflected_direction:
  forall normal: Vec3
  forall toward_light: Vec3
  Vec3

def reflected_direction(normal, toward_light):
  (normal_dot, normal_scale) = vec3_copy(normal)
  (light_dot, light_subtract) = vec3_copy(toward_light)
  twice_lambert = fix_mul(
    vec3_dot(normal_dot, light_dot),
    FixPos{U32.shln(9n, 1)}
  )
  vec3_sub(vec3_scale(normal_scale, twice_lambert), light_subtract)

assert surface_light_finish:
  forall diffuse: U32
  forall specular: U32
  forall combined: U32
  SurfaceLight

def surface_light_finish(diffuse, specular, combined):
  (combined_report, combined_absorb) = u32_pair(combined)
  SurfaceLight{diffuse, specular, combined_report, U32.sub(U32.from_nat(255n), combined_absorb)}

assert surface_light_parts:
  forall diffuse: U32
  forall specular: U32
  SurfaceLight

def surface_light_parts(diffuse, specular):
  match u32_pair(diffuse) u32_pair(specular):
    case (diffuse_report, diffuse_combined) (specular_report, specular_combined):
      surface_light_finish(
        diffuse_report,
        specular_report,
        u32_clamp(U32.add(diffuse_combined, specular_combined), U32.from_nat(255n))
      )

# View-dependent Phong-style material response. Inputs are normalized Q24.8
# directions. `shine` and `roughness` are 0..255 material channels.
assert surface_light:
  forall normal: Vec3
  forall toward_light: Vec3
  forall toward_viewer: Vec3
  forall ambient: U32
  forall strength: U32
  forall shine: U32
  forall roughness: U32
  SurfaceLight

def surface_light(normal, toward_light, toward_viewer, ambient, strength, shine, roughness):
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
assert shadow_to_ground:
  forall origin: Vec3
  forall light_travel: Vec3
  ShadowProjection

def shadow_to_ground(origin, light_travel):
  (origin_ray, origin_result) = vec3_copy(origin)
  (direction_ray, direction_result) = vec3_copy(light_travel)
  match ray_plane_y(Ray{origin_ray, direction_ray}, fix_zero()):
    case Miss{}:
      ShadowProjection{origin_result, False{}, 0}
    case Hit{distance}:
      (distance_scale, distance_report) = u32_pair(distance)
      ShadowProjection{
        vec3_add(origin_result, vec3_scale(direction_result, FixPos{distance_scale})),
        True{},
        distance_report
      }

assert shade_point:
  forall point: Vec3
  forall normal: Vec3
  forall sunlight: Sun
  forall occluder: Sphere
  ShadeSample

def shade_point(point, normal, sunlight, occluder):
  match sunlight:
    case Sun{direction, ambient, strength}:
      (light_direction, ray_direction) = vec3_copy(direction)
      match ray_sphere(Ray{point, ray_direction}, occluder):
        case Miss{}:
          ShadeSample{
            light_intensity(ambient, strength, fix_unit_clamp(vec3_dot(normal, light_direction))),
            False{},
            0
          }
        case Hit{distance}:
          ShadeSample{ambient, True{}, distance}

assert shade_unoccluded:
  forall normal: Vec3
  forall sunlight: Sun
  U32

def shade_unoccluded(normal, sunlight):
  match sunlight:
    case Sun{direction, ambient, strength}:
      light_intensity(ambient, strength, fix_unit_clamp(vec3_dot(normal, direction)))

assert sun_copy:
  forall value: Sun
  Sun & Sun

def sun_copy(value):
  match value:
    case Sun{direction, ambient, strength}:
      (direction_left, direction_right) = vec3_copy(direction)
      (ambient_left, ambient_right) = u32_pair(ambient)
      (strength_left, strength_right) = u32_pair(strength)
      (
        Sun{direction_left, ambient_left, strength_left},
        Sun{direction_right, ambient_right, strength_right}
      )

assert farm_light:
  forall ground: Vec3
  forall ground_normal: Vec3
  forall beet_surface: Vec3
  forall beet_normal: Vec3
  forall sunlight: Sun
  forall beet: Sphere
  FarmLight

def farm_light(ground, ground_normal, beet_surface, beet_normal, sunlight, beet):
  (ground_sun, beet_sun) = sun_copy(sunlight)
  match shade_point(ground, ground_normal, ground_sun, beet):
    case ShadeSample{tile_intensity, tile_shadowed, tile_hit_distance}:
      FarmLight{
        tile_intensity,
        shade_unoccluded(beet_normal, beet_sun),
        tile_shadowed,
        tile_hit_distance
      }

# Mathematical theorem and closed certificates
# ============================================
#
# `negative_distance_rejected_theorem` above is quantified over every U32
# magnitude. The authored arithmetic and scene values below are closed
# regression certificates, not general mathematical proofs. They establish
# only the named values and do not claim universal fixed-point accuracy or a
# complete renderer correctness theorem.

assert certificate_origin:
  Vec3

def certificate_origin():
  Vec3{fix_zero(), fix_zero(), fix_zero()}

assert certificate_x_normal:
  Vec3

def certificate_x_normal():
  Vec3{fix_one(), fix_zero(), fix_zero()}

assert certificate_front_ray:
  Ray

def certificate_front_ray():
  Ray{certificate_origin(), certificate_x_normal()}

assert certificate_back_ray:
  Ray

def certificate_back_ray():
  Ray{
    certificate_origin(),
    Vec3{fix_neg(U32.shln(8n, 1)), fix_zero(), fix_zero()}
  }

assert certificate_down_ray:
  Ray

def certificate_down_ray():
  Ray{
    Vec3{fix_zero(), FixPos{U32.shln(9n, 1)}, fix_zero()},
    Vec3{fix_zero(), fix_neg(U32.shln(8n, 1)), fix_zero()}
  }

assert certificate_front_sphere:
  Sphere

def certificate_front_sphere():
  Sphere{
    Vec3{FixPos{U32.shln(9n, 1)}, fix_zero(), fix_zero()},
    U32.shln(8n, 1)
  }

assert certificate_back_sphere:
  Sphere

def certificate_back_sphere():
  Sphere{
    Vec3{FixNeg{U32.shln(9n, 1)}, fix_zero(), fix_zero()},
    U32.shln(8n, 1)
  }

assert certificate_x_sun:
  Sun

def certificate_x_sun():
  Sun{certificate_x_normal(), U32.from_nat(40n), U32.from_nat(215n)}

assert certificate_divider_power_of_two:
  { u32_div(U32.shln(10n, 1), U32.shln(8n, 1)) == U32.from_nat(4n) : U32 }

def certificate_divider_power_of_two():
  {==}

assert certificate_sqrt_square:
  { u32_sqrt(U32.shln(16n, 1)) == U32.shln(8n, 1) : U32 }

def certificate_sqrt_square():
  {==}

assert certificate_sqrt_floor:
  { u32_sqrt(U32.from_nat(90n)) == U32.from_nat(9n) : U32 }

def certificate_sqrt_floor():
  {==}

assert certificate_fixed_half_product:
  { fix_mul(fix_one(), FixPos{U32.shln(7n, 1)}) == FixPos{U32.shln(7n, 1)} : Fix }

def certificate_fixed_half_product():
  {==}

assert certificate_sphere_front_hit:
  { ray_sphere(certificate_front_ray(), certificate_front_sphere()) == Hit{U32.shln(8n, 1)} : Hit }

def certificate_sphere_front_hit():
  {==}

assert certificate_sphere_behind_miss:
  { ray_sphere(certificate_back_ray(), certificate_front_sphere()) == Miss{} : Hit }

def certificate_sphere_behind_miss():
  {==}

assert certificate_plane_down_hit:
  { ray_plane_y(certificate_down_ray(), fix_zero()) == Hit{U32.shln(9n, 1)} : Hit }

def certificate_plane_down_hit():
  {==}

assert certificate_shadow_expected:
  { shade_point(certificate_origin(), certificate_x_normal(), certificate_x_sun(), certificate_front_sphere()) == ShadeSample{ U32.from_nat(40n), True{}, U32.shln(8n, 1) } : ShadeSample }

def certificate_shadow_expected():
  {==}

assert certificate_clear_expected:
  { shade_point(certificate_origin(), certificate_x_normal(), certificate_x_sun(), certificate_back_sphere()) == ShadeSample{U32.from_nat(255n), False{}, 0} : ShadeSample }

def certificate_clear_expected():
  {==}

assert certificate_farm_expected:
  { farm_light( certificate_origin(), certificate_x_normal(), certificate_origin(), certificate_x_normal(), certificate_x_sun(), certificate_front_sphere() ) == FarmLight{ U32.from_nat(40n), U32.from_nat(255n), True{}, U32.shln(8n, 1) } : FarmLight }

def certificate_farm_expected():
  {==}

assert certificate_surface_light_expected:
  { surface_light( certificate_x_normal(), certificate_x_normal(), certificate_x_normal(), U32.from_nat(20n), U32.from_nat(100n), U32.from_nat(128n), U32.from_nat(64n) ) == SurfaceLight{ U32.from_nat(120n), U32.from_nat(95n), U32.from_nat(215n), U32.from_nat(40n) } : SurfaceLight }

def certificate_surface_light_expected():
  {==}

assert certificate_shadow_projection_expected:
  { shadow_to_ground( Vec3{fix_zero(), FixPos{U32.shln(9n, 1)}, fix_zero()}, Vec3{fix_zero(), fix_neg(U32.shln(8n, 1)), fix_zero()} ) == ShadowProjection{ certificate_origin(), True{}, U32.shln(9n, 1) } : ShadowProjection }

def certificate_shadow_projection_expected():
  {==}

type RaytraceVerificationAudit:
  RaytraceVerificationAudit{
    -negative_distance_rejected: @magnitude: U32 -> {
      fix_positive_distance(FixNeg{magnitude}) == NoDistance{}
      : PositiveDistance
    },
    -divider_power_of_two: {
      u32_div(U32.shln(10n, 1), U32.shln(8n, 1))
      == U32.from_nat(4n) : U32
    },
    -sqrt_square: {
      u32_sqrt(U32.shln(16n, 1)) == U32.shln(8n, 1) : U32
    },
    -sqrt_floor: {
      u32_sqrt(U32.from_nat(90n)) == U32.from_nat(9n) : U32
    },
    -fixed_half_product: {
      fix_mul(fix_one(), FixPos{U32.shln(7n, 1)})
      == FixPos{U32.shln(7n, 1)} : Fix
    },
    -sphere_front_hit: {
      ray_sphere(certificate_front_ray(), certificate_front_sphere())
      == Hit{U32.shln(8n, 1)} : Hit
    },
    -sphere_behind_miss: {
      ray_sphere(certificate_back_ray(), certificate_front_sphere()) == Miss{} : Hit
    },
    -plane_down_hit: {
      ray_plane_y(certificate_down_ray(), fix_zero())
      == Hit{U32.shln(9n, 1)} : Hit
    },
    -shadow_expected: {
      shade_point(certificate_origin(), certificate_x_normal(), certificate_x_sun(), certificate_front_sphere())
      == ShadeSample{U32.from_nat(40n), True{}, U32.shln(8n, 1)} : ShadeSample
    },
    -clear_expected: {
      shade_point(certificate_origin(), certificate_x_normal(), certificate_x_sun(), certificate_back_sphere())
      == ShadeSample{U32.from_nat(255n), False{}, 0} : ShadeSample
    },
    -farm_expected: {
      farm_light(
        certificate_origin(),
        certificate_x_normal(),
        certificate_origin(),
        certificate_x_normal(),
        certificate_x_sun(),
        certificate_front_sphere()
      )
      == FarmLight{
        U32.from_nat(40n),
        U32.from_nat(255n),
        True{},
        U32.shln(8n, 1)
      } : FarmLight
    },
    -surface_light_expected: {
      surface_light(
        certificate_x_normal(), certificate_x_normal(), certificate_x_normal(),
        U32.from_nat(20n), U32.from_nat(100n),
        U32.from_nat(128n), U32.from_nat(64n)
      ) == SurfaceLight{
        U32.from_nat(120n), U32.from_nat(95n),
        U32.from_nat(215n), U32.from_nat(40n)
      } : SurfaceLight
    },
    -shadow_projection_expected: {
      shadow_to_ground(
        Vec3{fix_zero(), FixPos{U32.shln(9n, 1)}, fix_zero()},
        Vec3{fix_zero(), fix_neg(U32.shln(8n, 1)), fix_zero()}
      ) == ShadowProjection{
        certificate_origin(), True{}, U32.shln(9n, 1)
      } : ShadowProjection
    },
    certified_cases: U32,
    general_theorems: U32
  }

assert raytrace_verification:
  RaytraceVerificationAudit

def raytrace_verification():
  RaytraceVerificationAudit{
    negative_distance_rejected_theorem,
    certificate_divider_power_of_two(),
    certificate_sqrt_square(),
    certificate_sqrt_floor(),
    certificate_fixed_half_product(),
    certificate_sphere_front_hit(),
    certificate_sphere_behind_miss(),
    certificate_plane_down_hit(),
    certificate_shadow_expected(),
    certificate_clear_expected(),
    certificate_farm_expected(),
    certificate_surface_light_expected(),
    certificate_shadow_projection_expected(),
    U32.from_nat(12n),
    U32.from_nat(1n)
  }
