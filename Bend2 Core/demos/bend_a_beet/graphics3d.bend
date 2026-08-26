import Base
import ../../compat/list.bend as List

# Pure 3D scene construction for Bend-a-Beet. There is deliberately no IO,
# mutable frame state, renderer, physics, or ray intersection code here. The
# module returns deterministic algebraic data which a browser renderer can
# decode from Core's generated JavaScript.
#
# Public API (when imported as `Graphics`):
#
# - `Graphics.fixed_*` implements signed fixed-point arithmetic with eight
#   fractional bits; `fixed_from_q10` is the physics integration bridge.
# - `Graphics.vec3_*` constructs and transforms fixed-point 3D vectors.
# - `Graphics.camera_default()` and `Graphics.camera_project(camera, point)`
#   implement a quarter-turn yaw camera and perspective projection.
# - `Graphics.farm_tile_position(index)`, `Graphics.farm_tile(index)`, and
#   `Graphics.farm_grid()` construct the row-major 3 x 8 farm.
# - `Graphics.beet_geometry(...)` accepts fully explicit renderer geometry.
# - `Graphics.beet_procedural(...)` derives body, quadratic stem, and two leaf
#   tips from deterministic growth/wind/lift/bend/magic pose parameters.
# - `Graphics.scene_make(primitives)` installs the default camera and sun.
#
# Coordinate convention: X runs across the three columns, Y points upward,
# and Z runs down the eight rows. Fixed magnitudes are raw units / 256.

# Types
# =====

type Fixed:
  FixedPlus{magnitude: U32}
  FixedMinus{magnitude: U32}

type Vec2:
  Vec2{x: Fixed, y: Fixed}

type Vec3:
  Vec3{x: Fixed, y: Fixed, z: Fixed}

type Color:
  Color{red: U32, green: U32, blue: U32}

type Material:
  Material{color: Color, roughness: U32, emission: U32, shininess: U32}

type MeshQuality:
  MeshQuality{radial_segments: U32, vertical_segments: U32, leaf_segments: U32}

# `yaw` is an integer number of clockwise quarter turns, reduced modulo four.
# `center_x` and `center_y` are pixel-space principal-point coordinates.
type Camera:
  Camera{
    position: Vec3,
    yaw: U32,
    focal: Fixed,
    center_x: Fixed,
    center_y: Fixed,
    near: Fixed
  }

type ProjectedPoint:
  ProjectedPoint{screen: Vec2, depth: Fixed, visible: Bool}

type TileGeometry:
  TileGeometry{
    object_id: U32,
    center: Vec3,
    half_extents: Vec3,
    material: Material
  }

# A beet is renderer-ready without needing to infer topology. `stem_root`,
# `stem_control`, and `stem_tip` are a quadratic Bezier curve. Each leaf is a
# blade from `stem_tip` to its named tip. `flutter` is a signed displacement
# hint and `broken` tells the renderer to leave a visible gap in the stem.
type BeetGeometry:
  BeetGeometry{
    object_id: U32,
    body_center: Vec3,
    body_radii: Vec3,
    stem_root: Vec3,
    stem_control: Vec3,
    stem_tip: Vec3,
    leaf_left_tip: Vec3,
    leaf_right_tip: Vec3,
    leaf_width: Fixed,
    flutter: Fixed,
    broken: Bool,
    mesh_quality: MeshQuality,
    body_material: Material,
    stem_material: Material,
    leaf_material: Material
  }

type RenderPrimitive:
  RenderTile{geometry: TileGeometry}
  RenderBeet{geometry: BeetGeometry}

type Scene3D:
  Scene3D{
    camera: Camera,
    sun_direction: Vec3,
    ambient: U32,
    primitives: List<RenderPrimitive>
  }

# U32 helpers
# ===========

assert u32_pair:
  forall value: U32
  U32 & U32

def u32_pair(value):
  ((a, ea), (b, eb)) = U32.copy(value)
  (a, b)

# Fixed
# =====

assert fixed_zero:
  Fixed

def fixed_zero():
  FixedPlus{0}

assert fixed_from_nat:
  forall value: Nat
  Fixed

def fixed_from_nat(value):
  FixedPlus{U32.mul(U32.from_nat(value), U32.from_nat(256n))}

# Keeps the two possible source encodings of zero observationally consistent.
assert fixed_minus_magnitude:
  forall magnitude: U32
  Fixed

def fixed_minus_magnitude(magnitude):
  (test, result) = u32_pair(magnitude)
  match U32.is_zero(test):
    case True{}:
      FixedPlus{result}
    case False{}:
      FixedMinus{result}

# Constructs a fixed value from a raw magnitude. `negative=True{}`
# selects FixedMinus. This is the public route for fractional constants.
assert fixed_from_raw:
  forall negative: Bool
  forall magnitude: Nat
  Fixed

def fixed_from_raw(negative, magnitude):
  match negative:
    case False{}:
      FixedPlus{U32.from_nat(magnitude)}
    case True{}:
      fixed_minus_magnitude(U32.from_nat(magnitude))

# Converts the physics library's signed Q10 magnitude (1024 == 1.0) to this
# module's renderer scale (256 == 1.0), preserving its explicit sign.
assert fixed_from_q10:
  forall negative: Bool
  forall magnitude: U32
  Fixed

def fixed_from_q10(negative, magnitude):
  match negative:
    case False{}:
      FixedPlus{U32.div(magnitude, U32.from_nat(4n))}
    case True{}:
      fixed_minus_magnitude(U32.div(magnitude, U32.from_nat(4n)))

assert fixed_copy:
  forall value: Fixed
  Fixed & Fixed

def fixed_copy(value):
  match value:
    case FixedPlus{magnitude}:
      (a, b) = u32_pair(magnitude)
      (FixedPlus{a}, FixedPlus{b})
    case FixedMinus{magnitude}:
      (a, b) = u32_pair(magnitude)
      (FixedMinus{a}, FixedMinus{b})

assert fixed_triple:
  forall value: Fixed
  Fixed & (Fixed & Fixed)

def fixed_triple(value):
  (a, rest) = fixed_copy(value)
  (b, c) = fixed_copy(rest)
  (a, (b, c))

assert fixed_four:
  forall value: Fixed
  Fixed & (Fixed & (Fixed & Fixed))

def fixed_four(value):
  (left, right) = fixed_copy(value)
  (a, b) = fixed_copy(left)
  (c, d) = fixed_copy(right)
  (a, (b, (c, d)))

assert fixed_five:
  forall value: Fixed
  Fixed & (Fixed & (Fixed & (Fixed & Fixed)))

def fixed_five(value):
  (a, rest1) = fixed_copy(value)
  (b, rest2) = fixed_copy(rest1)
  (c, rest3) = fixed_copy(rest2)
  (d, e) = fixed_copy(rest3)
  (a, (b, (c, (d, e))))

assert fixed_eight:
  forall value: Fixed
  Fixed & (Fixed & (Fixed & (Fixed & (Fixed & (Fixed & (Fixed & Fixed))))))

def fixed_eight(value):
  (left, right) = fixed_copy(value)
  (a, rest1) = fixed_copy(left)
  (b, rest2) = fixed_copy(rest1)
  (c, d) = fixed_copy(rest2)
  (e, rest3) = fixed_copy(right)
  (f, rest4) = fixed_copy(rest3)
  (g, h) = fixed_copy(rest4)
  (a, (b, (c, (d, (e, (f, (g, h)))))))

assert fixed_neg:
  forall value: Fixed
  Fixed

def fixed_neg(value):
  match value:
    case FixedPlus{magnitude}:
      fixed_minus_magnitude(magnitude)
    case FixedMinus{magnitude}:
      FixedPlus{magnitude}

assert fixed_add:
  forall left: Fixed
  forall right: Fixed
  Fixed

def fixed_add(left, right):
  match left right:
    case FixedPlus{a} FixedPlus{b}:
      FixedPlus{U32.add(a, b)}
    case FixedMinus{a} FixedMinus{b}:
      fixed_minus_magnitude(U32.add(a, b))
    case FixedPlus{a} FixedMinus{b}:
      (a_test, a_sub) = u32_pair(a)
      (b_test, b_sub) = u32_pair(b)
      match U32.is_ge(a_test, b_test):
        case False{}:
          fixed_minus_magnitude(U32.sub(b_sub, a_sub))
        case True{}:
          FixedPlus{U32.sub(a_sub, b_sub)}
    case FixedMinus{a} FixedPlus{b}:
      (a_test, a_sub) = u32_pair(a)
      (b_test, b_sub) = u32_pair(b)
      match U32.is_ge(b_test, a_test):
        case False{}:
          fixed_minus_magnitude(U32.sub(a_sub, b_sub))
        case True{}:
          FixedPlus{U32.sub(b_sub, a_sub)}

assert fixed_sub:
  forall left: Fixed
  forall right: Fixed
  Fixed

def fixed_sub(left, right):
  fixed_add(left, fixed_neg(right))

assert fixed_mul:
  forall left: Fixed
  forall right: Fixed
  Fixed

def fixed_mul(left, right):
  match left right:
    case FixedPlus{a} FixedPlus{b}:
      FixedPlus{U32.div(U32.mul(a, b), U32.from_nat(256n))}
    case FixedMinus{a} FixedMinus{b}:
      FixedPlus{U32.div(U32.mul(a, b), U32.from_nat(256n))}
    case FixedPlus{a} FixedMinus{b}:
      fixed_minus_magnitude(U32.div(U32.mul(a, b), U32.from_nat(256n)))
    case FixedMinus{a} FixedPlus{b}:
      fixed_minus_magnitude(U32.div(U32.mul(a, b), U32.from_nat(256n)))

# Division by either representation of zero deterministically returns +0.
assert fixed_div:
  forall left: Fixed
  forall right: Fixed
  Fixed

def fixed_div(left, right):
  match left right:
    case FixedPlus{a} FixedPlus{b}:
      (test, divisor) = u32_pair(b)
      match U32.is_zero(test):
        case True{}:
          FixedPlus{0}
        case False{}:
          FixedPlus{U32.div(U32.mul(a, U32.from_nat(256n)), divisor)}
    case FixedMinus{a} FixedMinus{b}:
      (test, divisor) = u32_pair(b)
      match U32.is_zero(test):
        case True{}:
          FixedPlus{0}
        case False{}:
          FixedPlus{U32.div(U32.mul(a, U32.from_nat(256n)), divisor)}
    case FixedPlus{a} FixedMinus{b}:
      (test, divisor) = u32_pair(b)
      match U32.is_zero(test):
        case True{}:
          FixedPlus{0}
        case False{}:
          fixed_minus_magnitude(U32.div(U32.mul(a, U32.from_nat(256n)), divisor))
    case FixedMinus{a} FixedPlus{b}:
      (test, divisor) = u32_pair(b)
      match U32.is_zero(test):
        case True{}:
          FixedPlus{0}
        case False{}:
          fixed_minus_magnitude(U32.div(U32.mul(a, U32.from_nat(256n)), divisor))

assert fixed_is_ge:
  forall left: Fixed
  forall right: Fixed
  Bool

def fixed_is_ge(left, right):
  match left right:
    case FixedPlus{a} FixedPlus{b}:
      U32.is_ge(a, b)
    case FixedMinus{a} FixedMinus{b}:
      U32.is_le(a, b)
    case FixedPlus{a} FixedMinus{b}:
      True{}
    case FixedMinus{a} FixedPlus{b}:
      Bool.and(U32.is_zero(a), U32.is_zero(b))

assert fixed_is_equal:
  forall left: Fixed
  forall right: Fixed
  Bool

def fixed_is_equal(left, right):
  match left right:
    case FixedPlus{a} FixedPlus{b}:
      U32.is_eq(a, b)
    case FixedMinus{a} FixedMinus{b}:
      U32.is_eq(a, b)
    case FixedPlus{a} FixedMinus{b}:
      Bool.and(U32.is_zero(a), U32.is_zero(b))
    case FixedMinus{a} FixedPlus{b}:
      Bool.and(U32.is_zero(a), U32.is_zero(b))

# Vec2 / Vec3
# ===========

assert vec2_make:
  forall x: Fixed
  forall y: Fixed
  Vec2

def vec2_make(x, y):
  Vec2{x, y}

assert vec3_make:
  forall x: Fixed
  forall y: Fixed
  forall z: Fixed
  Vec3

def vec3_make(x, y, z):
  Vec3{x, y, z}

assert vec3_copy:
  forall value: Vec3
  Vec3 & Vec3

def vec3_copy(value):
  match value:
    case Vec3{x, y, z}:
      (x1, x2) = fixed_copy(x)
      (y1, y2) = fixed_copy(y)
      (z1, z2) = fixed_copy(z)
      (Vec3{x1, y1, z1}, Vec3{x2, y2, z2})

assert vec3_six:
  forall value: Vec3
  Vec3 & (Vec3 & (Vec3 & (Vec3 & (Vec3 & Vec3))))

def vec3_six(value):
  (a, rest1) = vec3_copy(value)
  (b, rest2) = vec3_copy(rest1)
  (c, rest3) = vec3_copy(rest2)
  (d, rest4) = vec3_copy(rest3)
  (e, f) = vec3_copy(rest4)
  (a, (b, (c, (d, (e, f)))))

assert vec3_add:
  forall left: Vec3
  forall right: Vec3
  Vec3

def vec3_add(left, right):
  match left right:
    case Vec3{ax, ay, az} Vec3{bx, by, bz}:
      Vec3{fixed_add(ax, bx), fixed_add(ay, by), fixed_add(az, bz)}

assert vec3_sub:
  forall left: Vec3
  forall right: Vec3
  Vec3

def vec3_sub(left, right):
  match left right:
    case Vec3{ax, ay, az} Vec3{bx, by, bz}:
      Vec3{fixed_sub(ax, bx), fixed_sub(ay, by), fixed_sub(az, bz)}

assert vec3_scale:
  forall value: Vec3
  forall factor: Fixed
  Vec3

def vec3_scale(value, factor):
  match value:
    case Vec3{x, y, z}:
      (fx, (fy, fz)) = fixed_triple(factor)
      Vec3{fixed_mul(x, fx), fixed_mul(y, fy), fixed_mul(z, fz)}

# Camera
# ======

assert camera_default:
  Camera

def camera_default():
  Camera{
    Vec3{fixed_zero(), fixed_from_nat(7n), fixed_from_raw(True{}, 4608n)},
    0,
    fixed_from_nat(560n),
    fixed_from_nat(640n),
    fixed_from_nat(360n),
    fixed_from_raw(False{}, 64n)
  }

assert camera_space:
  forall position: Vec3
  forall yaw: U32
  forall point: Vec3
  Vec3

def camera_space(position, yaw, point):
  match vec3_sub(point, position):
    case Vec3{x, y, z}:
      match U32.to_nat(U32.mod(yaw, U32.from_nat(4n))):
        case 0n:
          Vec3{x, y, z}
        case 1n:
          Vec3{z, y, fixed_neg(x)}
        case 2n:
          Vec3{fixed_neg(x), y, fixed_neg(z)}
        case other:
          Vec3{fixed_neg(z), y, x}

assert camera_project:
  forall camera: Camera
  forall point: Vec3
  ProjectedPoint

def camera_project(camera, point):
  match camera:
    case Camera{position, yaw, focal, center_x, center_y, near}:
      match camera_space(position, yaw, point):
        case Vec3{x, y, z}:
          (z_test, (z_x, (z_y, z_result))) = fixed_four(z)
          match fixed_is_ge(z_test, near):
            case False{}:
              ProjectedPoint{Vec2{center_x, center_y}, z_result, False{}}
            case True{}:
              (focal_x, focal_y) = fixed_copy(focal)
              projected_x = fixed_add(center_x, fixed_div(fixed_mul(x, focal_x), z_x))
              projected_y = fixed_sub(center_y, fixed_div(fixed_mul(y, focal_y), z_y))
              ProjectedPoint{Vec2{projected_x, projected_y}, z_result, True{}}

assert projected_visible:
  forall point: ProjectedPoint
  Bool

def projected_visible(point):
  match point:
    case ProjectedPoint{screen, depth, visible}:
      visible

# Materials
# =========

assert material_soil:
  Material

def material_soil():
  Material{Color{U32.from_nat(104n), U32.from_nat(63n), U32.from_nat(38n)}, U32.from_nat(220n), 0, U32.from_nat(8n)}

assert material_beet:
  Material

def material_beet():
  Material{Color{U32.from_nat(142n), U32.from_nat(30n), U32.from_nat(91n)}, U32.from_nat(132n), 0, U32.from_nat(123n)}

assert material_beet_channels:
  forall roughness_source: U32
  forall shininess: U32
  Material

def material_beet_channels(roughness_source, shininess):
  Material{
    Color{U32.from_nat(142n), U32.from_nat(30n), U32.from_nat(91n)},
    U32.sub(U32.from_nat(255n), roughness_source), 0, shininess
  }

assert material_beet_with_shine:
  forall shine: U32
  Material

def material_beet_with_shine(shine):
  match u32_pair(U32.div(shine, U32.from_nat(4n))):
    case (for_roughness, for_shininess):
      material_beet_channels(for_roughness, for_shininess)

assert material_stem:
  Material

def material_stem():
  Material{Color{U32.from_nat(83n), U32.from_nat(145n), U32.from_nat(65n)}, U32.from_nat(188n), 0, U32.from_nat(32n)}

assert material_leaf:
  Material

def material_leaf():
  Material{Color{U32.from_nat(53n), U32.from_nat(125n), U32.from_nat(58n)}, U32.from_nat(196n), 0, U32.from_nat(48n)}

assert mesh_quality_channels:
  forall radial_signature: U32
  forall vertical_signature: U32
  forall shine: U32
  MeshQuality

def mesh_quality_channels(radial_signature, vertical_signature, shine):
  MeshQuality{
    U32.add(U32.from_nat(28n), U32.and(radial_signature, U32.from_nat(7n))),
    U32.add(U32.from_nat(14n), U32.and(U32.shrn(3n, vertical_signature), U32.from_nat(3n))),
    U32.add(U32.from_nat(10n), U32.and(U32.shrn(6n, shine), U32.from_nat(3n)))
  }

assert high_mesh_quality:
  forall signature: U32
  forall shine: U32
  MeshQuality

def high_mesh_quality(signature, shine):
  match u32_pair(signature):
    case (radial_signature, vertical_signature):
      mesh_quality_channels(radial_signature, vertical_signature, shine)

# Farm
# ====

# Row-major indexing: index = row * 3 + column. Out-of-range indices retain
# deterministic wrapped column/row placement but `farm_grid` emits only 0..23.
assert farm_column:
  forall column: Nat
  Fixed

def farm_column(column):
  match column:
    case 0n:
      fixed_neg(fixed_from_nat(3n))
    case 1n:
      fixed_zero()
    case other:
      fixed_from_nat(3n)

assert farm_row:
  forall row: Nat
  Fixed

def farm_row(row):
  match row:
    case 0n: fixed_neg(fixed_from_nat(7n))
    case 1n: fixed_neg(fixed_from_nat(5n))
    case 2n: fixed_neg(fixed_from_nat(3n))
    case 3n: fixed_neg(fixed_from_nat(1n))
    case 4n: fixed_from_nat(1n)
    case 5n: fixed_from_nat(3n)
    case 6n: fixed_from_nat(5n)
    case other: fixed_from_nat(7n)

assert farm_tile_position:
  forall index: U32
  Vec3

def farm_tile_position(index):
  (for_column, for_row) = u32_pair(index)
  column = U32.to_nat(U32.mod(for_column, U32.from_nat(3n)))
  row = U32.to_nat(U32.div(for_row, U32.from_nat(3n)))
  Vec3{farm_column(column), fixed_zero(), farm_row(row)}

assert farm_tile:
  forall index: U32
  RenderPrimitive

def farm_tile(index):
  (object_id, position_index) = u32_pair(index)
  RenderTile{TileGeometry{
    object_id,
    farm_tile_position(position_index),
    Vec3{fixed_from_raw(False{}, 346n), fixed_from_raw(False{}, 64n), fixed_from_raw(False{}, 218n)},
    material_soil()
  }}

assert farm_indices_go:
  forall fuel: Nat
  forall index: U32
  List<U32>

def farm_indices_go(fuel, index):
  match fuel:
    case 0n:
      Nil{}
    case 1n+pred:
      (for_tile, for_next) = u32_pair(index)
      Con{for_tile, farm_indices_go(pred, U32.inc(for_next))}

assert farm_tiles_from_indices:
  forall indices: List<U32>
  List<RenderPrimitive>

def farm_tiles_from_indices(indices):
  match indices:
    case Nil{}:
      Nil{}
    case Con{index, tail}:
      Con{farm_tile(index), farm_tiles_from_indices(tail)}

# Mathematical theorem: rendering arbitrary finite tile-index lists preserves
# their cardinality. This is structural induction over List<U32>, independent
# of the fixed 24-element farm used by the demo.
assert farm_tiles_length_theorem:
  forall indices: List<U32>
  { List.length(RenderPrimitive, farm_tiles_from_indices(indices)) == List.length(U32, indices) : Nat }

def farm_tiles_length_theorem(indices):
  match indices:
    case Nil{}:
      {==}
    case Con{index, tail}:
      %farm_tiles_length_theorem(tail) : {1n+List.length(RenderPrimitive, farm_tiles_from_indices(tail)) == 1n+_ : Nat}
      {==}

assert farm_grid_go:
  forall fuel: Nat
  forall index: U32
  List<RenderPrimitive>

def farm_grid_go(fuel, index):
  farm_tiles_from_indices(farm_indices_go(fuel, index))

assert farm_grid:
  List<RenderPrimitive>

def farm_grid():
  farm_grid_go(24n, 0)

# Beet geometry
# =============

# Direct constructor for integration code which already owns every point.
assert beet_geometry:
  forall object_id: U32
  forall body_center: Vec3
  forall body_radii: Vec3
  forall stem_root: Vec3
  forall stem_control: Vec3
  forall stem_tip: Vec3
  forall leaf_left_tip: Vec3
  forall leaf_right_tip: Vec3
  forall leaf_width: Fixed
  forall flutter: Fixed
  forall broken: Bool
  forall signature: U32
  forall shine: U32
  RenderPrimitive

def beet_geometry(object_id, body_center, body_radii, stem_root, stem_control, stem_tip, leaf_left_tip, leaf_right_tip, leaf_width, flutter, broken, signature, shine):
  (shine_material, shine_quality) = u32_pair(shine)
  RenderBeet{BeetGeometry{
    object_id,
    body_center,
    body_radii,
    stem_root,
    stem_control,
    stem_tip,
    leaf_left_tip,
    leaf_right_tip,
    leaf_width,
    flutter,
    broken,
    high_mesh_quality(signature, shine_quality),
    material_beet_with_shine(shine_material),
    material_stem(),
    material_leaf()
  }}

# Procedural pose builder. `growth` is normally 0..1, while `wind`, `lift`,
# `bend`, and `magic` are signed world-space quantities. Physics may pass a
# time-varying `bend` for bend/return/boing motion. Magic only amplifies the
# leaf flutter hint here; it remains the physics library's job to determine
# the actual bounce. All inputs are pure values, so equal seeds/frames yield
# byte-for-byte equal scene data.
assert beet_procedural:
  forall object_id: U32
  forall base: Vec3
  forall growth: Fixed
  forall wind: Fixed
  forall lift: Fixed
  forall bend: Fixed
  forall magic: Fixed
  forall broken: Bool
  forall signature: U32
  forall shine: U32
  RenderPrimitive

def beet_procedural(object_id, base, growth, wind, lift, bend, magic, broken, signature, shine):
  match
    vec3_six(vec3_add(base, Vec3{fixed_zero(), lift, fixed_zero()}))
    fixed_eight(growth)
    fixed_five(wind)
    fixed_copy(bend):
    case
      (body_base, (root_base, (control_base, (tip_base, (left_base, right_base)))))
      (g0, (g1, (g2, (g3, (g4, (g5, (g6, g7)))))))
      (w_control, (w_tip, (w_left, (w_right, w_flutter))))
      (bend_control, bend_tip):
      body_center = vec3_add(body_base, Vec3{
        fixed_zero(),
        fixed_neg(fixed_mul(g0, fixed_from_raw(False{}, 90n))),
        fixed_zero()
      })
      body_radii = vec3_make(
        fixed_add(fixed_from_raw(False{}, 82n), fixed_mul(g1, fixed_from_raw(False{}, 72n))),
        fixed_add(fixed_from_raw(False{}, 102n), fixed_mul(g2, fixed_from_raw(False{}, 96n))),
        fixed_add(fixed_from_raw(False{}, 82n), fixed_mul(g3, fixed_from_raw(False{}, 72n)))
      )
      stem_root = vec3_add(root_base, Vec3{fixed_zero(), fixed_from_raw(False{}, 20n), fixed_zero()})
      stem_control = vec3_add(control_base, Vec3{
        fixed_add(bend_control, fixed_mul(w_control, fixed_from_raw(False{}, 64n))),
        g4,
        fixed_zero()
      })
      stem_tip = vec3_add(tip_base, Vec3{
        fixed_add(bend_tip, w_tip),
        fixed_mul(g5, fixed_from_nat(2n)),
        fixed_zero()
      })
      leaf_left_tip = vec3_add(left_base, Vec3{
        fixed_add(fixed_from_raw(True{}, 166n), w_left),
        fixed_mul(g6, fixed_from_raw(False{}, 384n)),
        fixed_from_raw(False{}, 48n)
      })
      leaf_right_tip = vec3_add(right_base, Vec3{
        fixed_add(fixed_from_raw(False{}, 166n), w_right),
        fixed_mul(g7, fixed_from_raw(False{}, 346n)),
        fixed_from_raw(True{}, 48n)
      })
      flutter = fixed_add(w_flutter, magic)
      beet_geometry(
        object_id,
        body_center,
        body_radii,
        stem_root,
        stem_control,
        stem_tip,
        leaf_left_tip,
        leaf_right_tip,
        fixed_from_raw(False{}, 54n),
        flutter,
        broken,
        signature,
        shine
      )

# Scene
# =====

assert scene_make:
  forall primitives: List<RenderPrimitive>
  Scene3D

def scene_make(primitives):
  Scene3D{
    camera_default(),
    Vec3{fixed_neg(fixed_from_nat(1n)), fixed_neg(fixed_from_nat(2n)), fixed_neg(fixed_from_nat(1n))},
    U32.from_nat(48n),
    primitives
  }

assert scene_base:
  Scene3D

def scene_base():
  scene_make(farm_grid())

# Mathematical theorem and closed certificates
# ============================================

# `farm_tiles_length_theorem` above is quantified over every finite List<U32>
# and proved by structural induction. The exact authored values below are
# closed regression certificates, not general mathematical proofs. All erased
# values are nevertheless checked by Core before backend generation.

assert Q10BridgeOne:
  Type

def Q10BridgeOne():
  {fixed_from_q10(False{}, U32.from_nat(1024n)) == fixed_from_nat(1n) : Fixed}

assert q10_bridge_one_certificate:
  Q10BridgeOne()

def q10_bridge_one_certificate():
  {==}

assert Q10BridgeNegativeHalf:
  Type

def Q10BridgeNegativeHalf():
  {fixed_from_q10(True{}, U32.from_nat(512n)) == fixed_from_raw(True{}, 128n) : Fixed}

assert q10_bridge_negative_half_certificate:
  Q10BridgeNegativeHalf()

def q10_bridge_negative_half_certificate():
  {==}

assert FarmGridCount24:
  Type

def FarmGridCount24():
  {List.length(RenderPrimitive, farm_grid()) == 24n : Nat}

assert farm_grid_count_24_certificate:
  FarmGridCount24()

def farm_grid_count_24_certificate():
  {==}

# This states the same count through the declared eight-row/three-column
# dimensions, tying the total to the intended grid shape rather than a magic
# literal alone.
assert FarmGridDimensions:
  Type

def FarmGridDimensions():
  {List.length(RenderPrimitive, farm_grid()) == Nat.mul(8n, 3n) : Nat}

assert farm_grid_dimensions_certificate:
  FarmGridDimensions()

def farm_grid_dimensions_certificate():
  {==}

assert FarmFirstCorner:
  Type

def FarmFirstCorner():
  {
    farm_tile_position(U32.from_nat(0n)) ==
    Vec3{fixed_neg(fixed_from_nat(3n)), fixed_zero(), fixed_neg(fixed_from_nat(7n))}
    : Vec3
  }

assert farm_first_corner_certificate:
  FarmFirstCorner()

def farm_first_corner_certificate():
  {==}

assert FarmLastCorner:
  Type

def FarmLastCorner():
  {
    farm_tile_position(U32.from_nat(23n)) ==
    Vec3{fixed_from_nat(3n), fixed_zero(), fixed_from_nat(7n)}
    : Vec3
  }

assert farm_last_corner_certificate:
  FarmLastCorner()

def farm_last_corner_certificate():
  {==}

assert FarmFirstVisible:
  Type

def FarmFirstVisible():
  {
    projected_visible(camera_project(camera_default(), farm_tile_position(U32.from_nat(0n)))) ==
    True{}
    : Bool
  }

assert farm_first_visible_certificate:
  FarmFirstVisible()

def farm_first_visible_certificate():
  {==}

assert FarmLastVisible:
  Type

def FarmLastVisible():
  {
    projected_visible(camera_project(camera_default(), farm_tile_position(U32.from_nat(23n)))) ==
    True{}
    : Bool
  }

assert farm_last_visible_certificate:
  FarmLastVisible()

def farm_last_visible_certificate():
  {==}

# A point directly along the default camera axis projects to the exact screen
# center at depth 18. This checks translation, perspective signs, and scale.
assert CameraAxisProjection:
  Type

def CameraAxisProjection():
  {
    camera_project(
      camera_default(),
      Vec3{fixed_zero(), fixed_from_nat(7n), fixed_zero()}
    ) ==
    ProjectedPoint{
      Vec2{fixed_from_nat(640n), fixed_from_nat(360n)},
      fixed_from_nat(18n),
      True{}
    }
    : ProjectedPoint
  }

assert camera_axis_projection_certificate:
  CameraAxisProjection()

def camera_axis_projection_certificate():
  {==}

assert HighMeshQualityExact:
  Type

def HighMeshQualityExact():
  {
    high_mesh_quality(U32.from_nat(5n), U32.from_nat(512n)) ==
    MeshQuality{U32.from_nat(33n), U32.from_nat(14n), U32.from_nat(10n)}
    : MeshQuality
  }

assert high_mesh_quality_exact_certificate:
  HighMeshQualityExact()

def high_mesh_quality_exact_certificate():
  {==}

assert ShinyMaterialExact:
  Type

def ShinyMaterialExact():
  {
    material_beet_with_shine(U32.from_nat(512n)) ==
    Material{
      Color{U32.from_nat(142n), U32.from_nat(30n), U32.from_nat(91n)},
      U32.from_nat(127n), 0, U32.from_nat(128n)
    }
    : Material
  }

assert shiny_material_exact_certificate:
  ShinyMaterialExact()

def shiny_material_exact_certificate():
  {==}

assert GraphicsReferenceCertificates:
  Type

def GraphicsReferenceCertificates():
  Q10BridgeOne() &
  (Q10BridgeNegativeHalf() &
  (FarmGridCount24() &
  (FarmGridDimensions() &
  (FarmFirstCorner() &
  (FarmLastCorner() &
  (FarmFirstVisible() &
  (FarmLastVisible() &
  (CameraAxisProjection() &
  (HighMeshQualityExact() & ShinyMaterialExact())))))))))

assert graphics_reference_certificates:
  GraphicsReferenceCertificates()

def graphics_reference_certificates():
  (
    q10_bridge_one_certificate(),
    (q10_bridge_negative_half_certificate(),
    (farm_grid_count_24_certificate(),
    (farm_grid_dimensions_certificate(),
    (farm_first_corner_certificate(),
    (farm_last_corner_certificate(),
    (farm_first_visible_certificate(),
    (farm_last_visible_certificate(),
    (camera_axis_projection_certificate(),
    (high_mesh_quality_exact_certificate(), shiny_material_exact_certificate()))))))))))

type GraphicsVerificationAudit:
  GraphicsVerificationAudit{
    -farm_tiles_length: @indices: List<U32> -> {
      List.length(RenderPrimitive, farm_tiles_from_indices(indices)) == List.length(U32, indices)
      : Nat
    },
    -reference_certificates: GraphicsReferenceCertificates(),
    certified_cases: U32,
    general_theorems: U32
  }

assert graphics_verification:
  GraphicsVerificationAudit

def graphics_verification():
  GraphicsVerificationAudit{
    farm_tiles_length_theorem,
    graphics_reference_certificates(),
    U32.from_nat(11n),
    U32.from_nat(1n)
  }
