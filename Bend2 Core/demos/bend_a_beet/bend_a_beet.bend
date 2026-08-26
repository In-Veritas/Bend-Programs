import Base
import ./physics.bend as Physics
import ./graphics3d.bend as Graphics
import ./raytrace.bend as Rays
import ./scene_proofs.bend as SceneProof
import ./physics_history_proofs.bend as PhysicsProof
import ./engine_features.bend as Engine

# Bend-a-Beet is a pure deterministic Core game report.  Core computes every
# farm tile, attribute, wind/growth pose, projected 3D point, ray-traced shade
# sample and bend trajectory.  The browser only schedules and draws the frames.

type ScreenPoint:
  ScreenPoint{x: U32, y: U32, depth: U32, visible: Bool}

type GeometryView:
  GeometryView{
    body: ScreenPoint,
    root: ScreenPoint,
    control: ScreenPoint,
    tip: ScreenPoint,
    leaf_left: ScreenPoint,
    leaf_right: ScreenPoint,
    radius: U32,
    radial_segments: U32,
    vertical_segments: U32,
    leaf_segments: U32
  }

type LightView:
  LightView{
    tile: U32,
    beet: U32,
    shadowed: Bool,
    distance: U32,
    specular: U32,
    absorbed: U32,
    shadow_anchor: ScreenPoint
  }

type ResponseView:
  ResponseView{
    outcome: String,
    detail: U32,
    impulse: U32,
    stiffness: U32,
    damping: U32,
    flexibility: U32,
    max_bend: U32,
    period: U32,
    duration: U32,
    signature: U32,
    break_at: U32
  }

type Pose:
  Pose{
    growth: Graphics.Fixed,
    wind: Graphics.Fixed,
    lift: Graphics.Fixed,
    bend: Graphics.Fixed,
    pulled: Bool,
    broken_geometry: Bool,
    broken_report: Bool,
    state: String,
    bend_amount: U32,
    integrity: U32,
    height_light: U32,
    height_report: U32,
    lift_light: U32,
    growth_percent: U32,
    wind_strength: U32
  }

type BeetView:
  BeetView{
    tile: U32,
    row: U32,
    column: U32,
    planted: Bool,
    water: U32,
    sugar: U32,
    fiber: U32,
    size: U32,
    magic: U32,
    pulled: Bool,
    outcome: String,
    detail: U32,
    state: String,
    bend: U32,
    integrity: U32,
    growth: U32,
    wind: U32,
    tile_light: U32,
    beet_light: U32,
    shadowed: Bool,
    body: ScreenPoint,
    root: ScreenPoint,
    control: ScreenPoint,
    tip: ScreenPoint,
    leaf_left: ScreenPoint,
    leaf_right: ScreenPoint,
    radius: U32,
    broken: Bool,
    impulse: U32,
    stiffness: U32,
    damping: U32,
    flexibility: U32,
    max_bend: U32,
    period: U32,
    response_duration: U32,
    signature: U32,
    break_at: U32,
    shine: U32,
    specular: U32,
    absorbed: U32,
    shadow_anchor: ScreenPoint,
    radial_segments: U32,
    vertical_segments: U32,
    leaf_segments: U32
  }

type FarmFrame:
  FarmFrame{
    time: U32,
    duration: U32,
    phase: String,
    note: String,
    active: U32,
    beets: List<BeetView>
  }

type Counts:
  Counts{planted: U32, broken: U32, spring: U32, recover: U32}

type UprootLift:
  UprootLift{geometry: Graphics.Fixed, light: U32}

type GameReport:
  GameReport{
    title: String,
    seed: U32,
    rows: U32,
    columns: U32,
    planted: U32,
    broken: U32,
    spring: U32,
    recover: U32,
    engine_profiles: List<Engine.EngineProfile>,
    frames: List<FarmFrame>
  }

type U32x4:
  U32x4{a: U32, b: U32, c: U32, d: U32}

type U32x8:
  U32x8{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32}

type U32x16:
  U32x16{
    a: U32, b: U32, c: U32, d: U32,
    e: U32, f: U32, g: U32, h: U32,
    i: U32, j: U32, k: U32, l: U32,
    m: U32, n: U32, o: U32, p: U32
  }

# Affine helpers
# ==============

assert u32:
  forall value: Nat
  U32

def u32(value):
  U32.from_nat(value)

assert u32_pair:
  forall value: U32
  U32 & U32

def u32_pair(value):
  ((left, left_exact), (right, right_exact)) = U32.copy(value)
  (left, right)

assert u32_four:
  forall value: U32
  U32x4

def u32_four(value):
  (left, right) = u32_pair(value)
  (a, b) = u32_pair(left)
  (c, d) = u32_pair(right)
  U32x4{a, b, c, d}

assert u32_eight:
  forall value: U32
  U32x8

def u32_eight(value):
  (left, right) = u32_pair(value)
  match u32_four(left) u32_four(right):
    case U32x4{a, b, c, d} U32x4{e, f, g, h}:
      U32x8{a, b, c, d, e, f, g, h}

assert u32_sixteen:
  forall value: U32
  U32x16

def u32_sixteen(value):
  (left, right) = u32_pair(value)
  match u32_eight(left) u32_eight(right):
    case U32x8{a, b, c, d, e, f, g, h} U32x8{i, j, k, l, m, n, o, p}:
      U32x16{a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p}

assert game_seed:
  U32

def game_seed():
  # 190 * 256 + 183, kept as U32 arithmetic so the source does not build a
  # 48,823-constructor unary Nat literal.
  U32.add(U32.shln(8n, u32(190n)), u32(183n))

assert kilo:
  forall multiplier: Nat
  U32

def kilo(multiplier):
  U32.mul(u32(multiplier), u32(1000n))

assert beet_seed:
  forall tile: U32
  U32

def beet_seed(tile):
  U32.add(game_seed(), U32.mul(tile, U32.add(kilo(7n), u32(919n))))

assert attributes_for:
  forall tile: U32
  Physics.BeetAttributes

def attributes_for(tile):
  (seed_tile, attribute_tile) = u32_pair(tile)
  Physics.attributes_from_seed(beet_seed(seed_tile), attribute_tile)

assert tile_planted:
  forall tile: U32
  Bool

def tile_planted(tile):
  match U32.is_zero(U32.mod(U32.xor(beet_seed(tile), u32(313n)), u32(5n))):
    case True{}: False{}
    case False{}: True{}

# Fixed-point bridges and projections
# ===================================

assert physics_fixed:
  forall value: Physics.Fix
  Graphics.Fixed

def physics_fixed(value):
  match value:
    case Physics.FixPos{magnitude}:
      Graphics.fixed_from_q10(False{}, magnitude)
    case Physics.FixNeg{magnitude}:
      Graphics.fixed_from_q10(True{}, magnitude)

assert growth_wind_fixed:
  forall value: Physics.Fix
  Graphics.Fixed

def growth_wind_fixed(value):
  Graphics.fixed_mul(physics_fixed(value), Graphics.fixed_from_nat(3n))

assert graphics_to_ray_fixed:
  forall value: Graphics.Fixed
  Rays.Fix

def graphics_to_ray_fixed(value):
  match value:
    case Graphics.FixedPlus{magnitude}:
      Rays.FixPos{magnitude}
    case Graphics.FixedMinus{magnitude}:
      Rays.FixNeg{magnitude}

assert graphics_to_ray_vec:
  forall value: Graphics.Vec3
  Rays.Vec3

def graphics_to_ray_vec(value):
  match value:
    case Graphics.Vec3{x, y, z}:
      Rays.Vec3{graphics_to_ray_fixed(x), graphics_to_ray_fixed(y), graphics_to_ray_fixed(z)}

assert ray_to_graphics_fixed:
  forall value: Rays.Fix
  Graphics.Fixed

def ray_to_graphics_fixed(value):
  match value:
    case Rays.FixPos{magnitude}:
      Graphics.FixedPlus{magnitude}
    case Rays.FixNeg{magnitude}:
      Graphics.FixedMinus{magnitude}

assert ray_to_graphics_vec:
  forall value: Rays.Vec3
  Graphics.Vec3

def ray_to_graphics_vec(value):
  match value:
    case Rays.Vec3{x, y, z}:
      Graphics.Vec3{ray_to_graphics_fixed(x), ray_to_graphics_fixed(y), ray_to_graphics_fixed(z)}

assert screen_magnitude:
  forall value: Graphics.Fixed
  U32

def screen_magnitude(value):
  match value:
    case Graphics.FixedPlus{magnitude}:
      Rays.u32_div(magnitude, u32(256n))
    case Graphics.FixedMinus{magnitude}:
      0

assert screen_point:
  forall point: Graphics.Vec3
  ScreenPoint

def screen_point(point):
  match Graphics.camera_project(Graphics.camera_default(), point):
    case Graphics.ProjectedPoint{Graphics.Vec2{x, y}, depth, visible}:
      ScreenPoint{screen_magnitude(x), screen_magnitude(y), screen_magnitude(depth), visible}

assert tile_point:
  forall tile: U32
  ScreenPoint

def tile_point(tile):
  screen_point(Graphics.farm_tile_position(tile))

# Seeded response and poses
# =========================

assert response_outcome:
  forall outcome: Physics.BendOutcome
  forall impulse: U32
  forall stiffness: U32
  forall damping: U32
  forall flexibility: U32
  forall max_bend: U32
  forall period: U32
  forall duration: U32
  forall signature: U32
  forall break_at: U32
  ResponseView

def response_outcome(outcome, impulse, stiffness, damping, flexibility, max_bend, period, duration, signature, break_at):
  match outcome:
    case Physics.BeetBreak{pieces}:
      ResponseView{"break", pieces, impulse, stiffness, damping, flexibility, max_bend, period, duration, signature, break_at}
    case Physics.BeetSpring{boings}:
      ResponseView{"boioioioing", boings, impulse, stiffness, damping, flexibility, max_bend, period, duration, signature, break_at}
    case Physics.BeetRecover{}:
      ResponseView{"bend and recover", 0, impulse, stiffness, damping, flexibility, max_bend, period, duration, signature, break_at}

assert response_finish:
  forall response: Physics.BeetPhysics
  forall signature: U32
  ResponseView

def response_finish(response, signature):
  match response:
    case Physics.BeetPhysics{outcome, axis, impulse, stiffness, damping, flexibility, max_bend, period, duration, phase, break_at}:
      response_outcome(outcome, impulse, stiffness, damping, flexibility, max_bend, period, duration, signature, break_at)

assert response_view:
  forall tile: U32
  ResponseView

def response_view(tile):
  match u32_four(tile):
    case U32x4{seed_tile, attribute_tile, signature_tile, spare_tile}:
      response_finish(
        Physics.beet_response(beet_seed(seed_tile), attributes_for(attribute_tile)),
        beet_seed(signature_tile)
      )

assert graphics_growth:
  forall elapsed: U32
  Graphics.Fixed

def graphics_growth(elapsed):
  Graphics.fixed_from_q10(
    False{},
    Rays.u32_div(U32.shln(10n, elapsed), kilo(5n))
  )

assert growth_pose:
  forall tile: U32
  forall elapsed: U32
  Pose

def growth_pose(tile, elapsed):
  match u32_four(tile) u32_four(elapsed):
    case U32x4{seed_tile, attribute_tile, spare_tile, rest_tile} U32x4{growth_time, percent_time, spare_time, rest_time}:
      match Physics.beet_growth(beet_seed(seed_tile), attributes_for(attribute_tile), growth_time):
        case Physics.GrowthFrame{height, root_depth, stem_radius, Physics.Vec3{sway_x, sway_y, sway_z}}:
          (height_light, height_report) = u32_pair(height)
          (growth_fixed_time, growth_percent_time) = u32_pair(percent_time)
          Pose{
            graphics_growth(growth_fixed_time),
            growth_wind_fixed(sway_x),
            Graphics.fixed_zero(),
            Graphics.fixed_zero(),
            False{}, False{}, False{}, "growing", 0, U32.shln(10n, 1),
            height_light, height_report, 0,
            Rays.u32_div(U32.mul(growth_percent_time, u32(100n)), kilo(5n)),
            Rays.u32_div(U32.add(root_depth, stem_radius), u32(2n))
          }

assert grown_pose:
  forall tile: U32
  forall lift: Graphics.Fixed
  forall lift_light: U32
  forall pulled: Bool
  forall state: String
  Pose

def grown_pose(tile, lift, lift_light, pulled, state):
  match u32_four(tile):
    case U32x4{seed_tile, attribute_tile, spare_tile, rest_tile}:
      match Physics.beet_growth(beet_seed(seed_tile), attributes_for(attribute_tile), kilo(5n)):
        case Physics.GrowthFrame{height, root_depth, stem_radius, Physics.Vec3{sway_x, sway_y, sway_z}}:
          (height_light, height_report) = u32_pair(height)
          Pose{
            Graphics.fixed_from_nat(1n), physics_fixed(sway_x),
            lift, Graphics.fixed_zero(),
            pulled, False{}, False{}, state, 0, U32.shln(10n, 1),
            height_light, height_report, lift_light, u32(100n),
            Rays.u32_div(U32.add(root_depth, stem_radius), u32(2n))
          }

assert full_growth_pose:
  forall tile: U32
  forall pulled: Bool
  forall state: String
  Pose

def full_growth_pose(tile, pulled, state):
  grown_pose(tile, Graphics.fixed_from_raw(False{}, 410n), u32(410n), pulled, state)

# The 800 ms uproot has a short downward load, an accelerating release,
# overshoot, and damped return. Raw values are Q24.8 vertical displacement.
assert uproot_lift:
  forall elapsed: U32
  UprootLift

def uproot_lift(elapsed):
  match U32.to_nat(Rays.u32_div(elapsed, u32(50n))):
    case 0n: UprootLift{Graphics.fixed_from_raw(True{}, 10n), 0}
    case 1n: UprootLift{Graphics.fixed_from_raw(True{}, 18n), 0}
    case 2n: UprootLift{Graphics.fixed_from_raw(True{}, 28n), 0}
    case 3n: UprootLift{Graphics.fixed_from_raw(True{}, 20n), 0}
    case 4n: UprootLift{Graphics.fixed_from_raw(False{}, 0n), 0}
    case 5n: UprootLift{Graphics.fixed_from_raw(False{}, 45n), u32(45n)}
    case 6n: UprootLift{Graphics.fixed_from_raw(False{}, 110n), u32(110n)}
    case 7n: UprootLift{Graphics.fixed_from_raw(False{}, 205n), u32(205n)}
    case 8n: UprootLift{Graphics.fixed_from_raw(False{}, 330n), u32(330n)}
    case 9n: UprootLift{Graphics.fixed_from_raw(False{}, 480n), u32(480n)}
    case 10n: UprootLift{Graphics.fixed_from_raw(False{}, 650n), u32(650n)}
    case 11n: UprootLift{Graphics.fixed_from_raw(False{}, 720n), u32(720n)}
    case 12n: UprootLift{Graphics.fixed_from_raw(False{}, 610n), u32(610n)}
    case 13n: UprootLift{Graphics.fixed_from_raw(False{}, 500n), u32(500n)}
    case 14n: UprootLift{Graphics.fixed_from_raw(False{}, 445n), u32(445n)}
    case other: UprootLift{Graphics.fixed_from_raw(False{}, 410n), u32(410n)}

assert uproot_state:
  forall elapsed: U32
  String

def uproot_state(elapsed):
  match U32.to_nat(Rays.u32_div(elapsed, u32(50n))):
    case 0n: "roots loading"
    case 1n: "roots loading"
    case 2n: "soil compressing"
    case 3n: "soil cracking"
    case 4n: "release"
    case 5n: "accelerating"
    case 6n: "accelerating"
    case 7n: "tearing free"
    case 8n: "airborne"
    case 9n: "airborne"
    case 10n: "overshoot"
    case 11n: "overshoot"
    case 12n: "rebound"
    case 13n: "rebound"
    case 14n: "settling"
    case other: "uprooted"

assert uproot_pose:
  forall tile: U32
  forall elapsed: U32
  Pose

def uproot_pose(tile, elapsed):
  match u32_pair(elapsed):
    case (lift_time, state_time):
      match uproot_lift(lift_time):
        case UprootLift{geometry, light}:
          grown_pose(tile, geometry, light, True{}, uproot_state(state_time))

type StateView:
  StateView{name: String, broken_geometry: Bool, broken_report: Bool}

assert bend_state_view:
  forall state: Physics.BendState
  StateView

def bend_state_view(state):
  match state:
    case Physics.BeetBreaking{}: StateView{"creak...", False{}, False{}}
    case Physics.BeetBroken{pieces}: StateView{"snap!", True{}, True{}}
    case Physics.BeetBoioioing{remaining}: StateView{"boioioioing!", False{}, False{}}
    case Physics.BeetRecovering{}: StateView{"bending", False{}, False{}}
    case Physics.BeetResting{}: StateView{"resting", False{}, False{}}

assert active_pose:
  forall tile: U32
  forall elapsed: U32
  Pose

def active_pose(tile, elapsed):
  match u32_four(tile) u32_four(elapsed):
    case U32x4{seed_bend, attribute_bend, seed_wind, attribute_growth} U32x4{bend_time, wind_time, spare_time, rest_time}:
      match Physics.beet_bend(beet_seed(seed_bend), attributes_for(attribute_bend), bend_time):
        case Physics.BendFrame{state, Physics.Vec3{bend_x, bend_y, bend_z}, bend_amount, height, integrity}:
          match Physics.wind_at(beet_seed(seed_wind), wind_time):
            case Physics.WindFrame{Physics.Vec3{wind_x, wind_y, wind_z}, strength}:
              (height_light, height_report) = u32_pair(height)
              match bend_state_view(state):
                case StateView{state_name, broken_geometry, broken_report}:
                  Pose{
                    Graphics.fixed_from_nat(1n), physics_fixed(wind_x),
                    Graphics.fixed_from_raw(False{}, 410n), physics_fixed(bend_x),
                    True{}, broken_geometry, broken_report, state_name,
                    bend_amount, integrity, height_light, height_report, u32(410n),
                    u32(100n), strength
                  }

assert beet_pose:
  forall stage: U32
  forall tile: U32
  forall active: U32
  forall elapsed: U32
  Pose

def beet_pose(stage, tile, active, elapsed):
  match U32.to_nat(stage):
    case 0n:
      growth_pose(tile, elapsed)
    case 1n:
      uproot_pose(tile, U32.sub(elapsed, kilo(5n)))
    case other:
      match u32_four(tile) u32_pair(active):
        case U32x4{tile_less, tile_equal_test, tile_active, tile_waiting} (active_less, active_equal):
          match U32.is_lt(tile_less, active_less):
            case True{}:
              active_pose(tile_active, U32.mul(u32(100n), u32(100n)))
            case False{}:
              match U32.is_eq(tile_equal_test, active_equal):
                case True{}:
                  active_pose(tile_active, elapsed)
                case False{}:
                  full_growth_pose(tile_waiting, True{}, "waiting to bend")

# 3D geometry and ray lighting
# ============================

assert point_geometry:
  forall tile: U32
  GeometryView

def point_geometry(tile):
  match u32_eight(tile):
    case U32x8{a, b, c, d, e, f, g, h}:
      GeometryView{
        tile_point(a), tile_point(b), tile_point(c),
        tile_point(d), tile_point(e), tile_point(f), u32(1n),
        u32(28n), u32(14n), u32(10n)
      }

assert geometry_view:
  forall tile: U32
  forall growth: Graphics.Fixed
  forall wind: Graphics.Fixed
  forall lift: Graphics.Fixed
  forall bend: Graphics.Fixed
  forall magic: U32
  forall shine: U32
  forall signature: U32
  forall broken: Bool
  GeometryView

def geometry_view(tile, growth, wind, lift, bend, magic, shine, signature, broken):
  (object_tile, position_tile) = u32_pair(tile)
  match Graphics.beet_procedural(
    object_tile,
    Graphics.farm_tile_position(position_tile),
    growth,
    wind,
    lift,
    bend,
    Graphics.fixed_from_q10(False{}, magic),
    broken,
    signature,
    shine
  ):
    case Graphics.RenderTile{Graphics.TileGeometry{object_id, center, half_extents, material}}:
      point_geometry(object_id)
    case Graphics.RenderBeet{Graphics.BeetGeometry{
      object_id, body_center, Graphics.Vec3{radius_x, radius_y, radius_z},
      stem_root, stem_control, stem_tip, leaf_left_tip, leaf_right_tip,
      leaf_width, flutter, is_broken,
      Graphics.MeshQuality{radial_segments, vertical_segments, leaf_segments},
      body_material, stem_material, leaf_material
    }}:
      GeometryView{
        screen_point(body_center), screen_point(stem_root),
        screen_point(stem_control), screen_point(stem_tip),
        screen_point(leaf_left_tip), screen_point(leaf_right_tip),
        screen_magnitude(radius_y),
        radial_segments, vertical_segments, leaf_segments
      }

assert ray_add_y:
  forall point: Rays.Vec3
  forall y: Rays.Fix
  Rays.Vec3

def ray_add_y(point, y):
  match point:
    case Rays.Vec3{x, base_y, z}:
      Rays.Vec3{x, Rays.fix_add(base_y, y), z}

assert radius_from_size:
  forall size: U32
  U32

def radius_from_size(size):
  U32.add(u32(58n), Rays.u32_div(size, u32(8n)))

assert light_finish:
  forall sample: Rays.FarmLight
  forall surface: Rays.SurfaceLight
  forall shadow: Rays.ShadowProjection
  LightView

def light_finish(sample, surface, shadow):
  match sample surface shadow:
    case Rays.FarmLight{tile_intensity, beet_intensity, tile_shadowed, tile_hit_distance}
         Rays.SurfaceLight{diffuse, specular, combined, absorbed}
         Rays.ShadowProjection{shadow_point, shadow_visible, shadow_distance}:
      LightView{
        tile_intensity, combined, tile_shadowed, tile_hit_distance,
        specular, absorbed, screen_point(ray_to_graphics_vec(shadow_point))
      }

assert light_up:
  Rays.Vec3

def light_up():
  Rays.Vec3{Rays.fix_zero(), Rays.fix_one(), Rays.fix_zero()}

assert light_toward_sun:
  Rays.Vec3

def light_toward_sun():
  Rays.Vec3{
    Rays.FixPos{u32(181n)}, Rays.FixPos{u32(181n)}, Rays.FixPos{u32(64n)}
  }

assert light_toward_viewer:
  Rays.Vec3

def light_toward_viewer():
  Rays.Vec3{Rays.fix_zero(), Rays.FixPos{u32(181n)}, Rays.FixNeg{u32(181n)}}

assert light_travel:
  Rays.Vec3

def light_travel():
  Rays.Vec3{
    Rays.FixNeg{u32(181n)}, Rays.FixNeg{u32(181n)}, Rays.FixNeg{u32(64n)}
  }

assert light_sample_channels:
  forall ground: Rays.Vec3
  forall surface: Rays.Vec3
  forall center: Rays.Vec3
  forall radius: U32
  forall mapped_shine: U32
  LightView

def light_sample_channels(ground, surface, center, radius, mapped_shine):
  match Rays.vec3_copy(center) u32_pair(mapped_shine):
    case (center_farm, center_shadow) (shine_channel, roughness_source):
      light_finish(
        Rays.farm_light(
          ground, light_up(), surface, light_up(), Rays.default_sun(),
          Rays.sphere(center_farm, radius)
        ),
        Rays.surface_light(
          light_up(), light_toward_sun(), light_toward_viewer(),
          u32(40n), u32(215n), shine_channel,
          U32.sub(u32(255n), roughness_source)
        ),
        Rays.shadow_to_ground(center_shadow, light_travel())
      )

assert light_sample:
  forall ground: Rays.Vec3
  forall surface: Rays.Vec3
  forall center: Rays.Vec3
  forall radius: U32
  forall shine: U32
  LightView

def light_sample(ground, surface, center, radius, shine):
  light_sample_channels(ground, surface, center, radius, Rays.u32_div(shine, u32(4n)))

assert light_view:
  forall tile: U32
  forall height: U32
  forall lift: U32
  forall size: U32
  forall shine: U32
  LightView

def light_view(tile, height, lift, size, shine):
  match u32_four(tile) u32_four(height) u32_four(lift) u32_four(size):
    case U32x4{ground_tile, surface_tile, center_tile, spare_tile}
         U32x4{height_surface, height_spare, height_rest, height_last}
         U32x4{lift_surface, lift_center, lift_spare, lift_rest}
         U32x4{size_center, size_sphere, size_rest, size_last}:
      light_sample(
        graphics_to_ray_vec(Graphics.farm_tile_position(ground_tile)),
        ray_add_y(
          graphics_to_ray_vec(Graphics.farm_tile_position(surface_tile)),
          Rays.FixPos{U32.add(lift_surface, Rays.u32_div(height_surface, u32(4n)))}
        ),
        ray_add_y(
          graphics_to_ray_vec(Graphics.farm_tile_position(center_tile)),
          Rays.FixPos{U32.add(lift_center, radius_from_size(size_center))}
        ),
        radius_from_size(size_sphere),
        shine
      )

# Farm views
# ==========

assert empty_geometry:
  forall tile: U32
  GeometryView

def empty_geometry(tile):
  point_geometry(tile)

assert empty_beet:
  forall tile: U32
  BeetView

def empty_beet(tile):
  match u32_eight(tile):
    case U32x8{tile_out, row_tile, column_tile, geometry_tile, shadow_tile, t5, t6, t7}:
      match empty_geometry(geometry_tile):
        case GeometryView{body, root, control, tip, leaf_left, leaf_right, radius, radial_segments, vertical_segments, leaf_segments}:
          BeetView{
            tile_out,
            Rays.u32_div(row_tile, u32(3n)), U32.mod(column_tile, u32(3n)), False{},
            0, 0, 0, 0, 0,
            False{}, "empty", 0, "bare soil", 0, 0,
            0, 0, u32(220n), u32(220n), False{},
            body, root, control, tip, leaf_left, leaf_right, radius, False{},
            0, 0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, u32(255n), tile_point(shadow_tile),
            radial_segments, vertical_segments, leaf_segments
          }

assert planted_beet:
  forall stage: U32
  forall active: U32
  forall elapsed: U32
  forall tile: U32
  BeetView

def planted_beet(stage, active, elapsed, tile):
  match u32_sixteen(tile) u32_four(stage) u32_four(active) u32_four(elapsed):
    case U32x16{t0,t1,t2,t3,t4,t5,t6,t7,t8,t9,t10,t11,t12,t13,t14,t15}
         U32x4{s0,s1,s2,s3} U32x4{a0,a1,a2,a3} U32x4{e0,e1,e2,e3}:
      match attributes_for(t3) response_view(t4) beet_pose(s0, t5, a0, e0):
        case Physics.BeetAttributes{water, sugar, fiber, size, magic, shine}
             ResponseView{outcome, detail, impulse, stiffness, damping, flexibility, max_bend, period, response_duration, signature, break_at}
             Pose{growth_fixed, wind_fixed, lift_fixed, bend_fixed, pulled, broken_geometry, broken_report, state, bend_amount, integrity, height_light, height_report, lift_light, growth_percent, wind_strength}:
          (size_light, size_report) = u32_pair(size)
          (magic_geometry, magic_report) = u32_pair(magic)
          match u32_four(shine) u32_pair(signature):
            case U32x4{shine_geometry, shine_light, shine_report, shine_spare}
                 (signature_geometry, signature_report):
              match
                geometry_view(t6, growth_fixed, wind_fixed, lift_fixed, bend_fixed, magic_geometry, shine_geometry, signature_geometry, broken_geometry)
                light_view(t7, height_light, lift_light, size_light, shine_light):
                case GeometryView{body, root, control, tip, leaf_left, leaf_right, radius, radial_segments, vertical_segments, leaf_segments}
                     LightView{tile_light, beet_light, shadowed, distance, specular, absorbed, shadow_anchor}:
                  BeetView{
                    t0, Rays.u32_div(t1, u32(3n)), U32.mod(t2, u32(3n)), True{},
                    water, sugar, fiber, size_report, magic_report, pulled, outcome, detail, state,
                    bend_amount, integrity, growth_percent, wind_strength,
                    tile_light, beet_light, shadowed,
                    body, root, control, tip, leaf_left, leaf_right, radius,
                    broken_report, impulse, stiffness, damping, flexibility,
                    max_bend, period, response_duration, signature_report, break_at,
                    shine_report, specular, absorbed, shadow_anchor,
                    radial_segments, vertical_segments, leaf_segments
                  }

assert beet_view:
  forall stage: U32
  forall active: U32
  forall elapsed: U32
  forall tile: U32
  BeetView

def beet_view(stage, active, elapsed, tile):
  match u32_pair(tile):
    case (test_tile, keep_tile):
      match tile_planted(test_tile):
        case False{}:
          empty_beet(keep_tile)
        case True{}:
          planted_beet(stage, active, elapsed, keep_tile)

assert beet_views:
  forall fuel: Nat
  forall tile: U32
  forall stage: U32
  forall active: U32
  forall elapsed: U32
  List<BeetView>

def beet_views(fuel, tile, stage, active, elapsed):
  match fuel:
    case 0n:
      Nil{}
    case 1n+pred:
      (tile_view, tile_next) = u32_pair(tile)
      (stage_view, stage_next) = u32_pair(stage)
      (active_view, active_next) = u32_pair(active)
      (elapsed_view, elapsed_next) = u32_pair(elapsed)
      Con{
        beet_view(stage_view, active_view, elapsed_view, tile_view),
        beet_views(pred, U32.inc(tile_next), stage_next, active_next, elapsed_next)
      }

assert farm_frame:
  forall stage: U32
  forall active: U32
  forall time: U32
  forall duration: U32
  forall phase: String
  forall note: String
  FarmFrame

def farm_frame(stage, active, time, duration, phase, note):
  match u32_pair(active) u32_pair(time):
    case (active_report, active_views) (time_report, time_views):
      FarmFrame{
        time_report, duration, phase, note, active_report,
        beet_views(24n, 0, stage, active_views, time_views)
      }

# Counts and timeline
# ===================

assert count_add:
  forall outcome: Physics.BendOutcome
  forall counts: Counts
  Counts

def count_add(outcome, counts):
  match outcome counts:
    case Physics.BeetBreak{pieces} Counts{planted, broken, spring, recover}:
      Counts{U32.inc(planted), U32.inc(broken), spring, recover}
    case Physics.BeetSpring{boings} Counts{planted, broken, spring, recover}:
      Counts{U32.inc(planted), broken, U32.inc(spring), recover}
    case Physics.BeetRecover{} Counts{planted, broken, spring, recover}:
      Counts{U32.inc(planted), broken, spring, U32.inc(recover)}

assert farm_counts:
  forall fuel: Nat
  forall tile: U32
  Counts

def farm_counts(fuel, tile):
  match fuel:
    case 0n:
      Counts{0, 0, 0, 0}
    case 1n+pred:
      match u32_four(tile):
        case U32x4{test_tile, seed_tile, attribute_tile, next_tile}:
          match tile_planted(test_tile):
            case False{}:
              farm_counts(pred, U32.inc(next_tile))
            case True{}:
              match Physics.beet_response(beet_seed(seed_tile), attributes_for(attribute_tile)):
                case Physics.BeetPhysics{outcome, axis, impulse, stiffness, damping, flexibility, max_bend, period, duration, phase, break_at}:
                  count_add(outcome, farm_counts(pred, U32.inc(next_tile)))

assert bend_frames_go:
  forall fuel: Nat
  forall tile: U32
  forall time: U32
  forall tail: List<FarmFrame>
  List<FarmFrame>

def bend_frames_go(fuel, tile, time, tail):
  match fuel:
    case 0n:
      Con{
        farm_frame(
          u32(2n), tile, kilo(6n), u32(300n), "Settle",
          "The elastic response has finished before the next tile is selected."
        ),
        tail
      }
    case 1n+pred:
      match u32_pair(tile) u32_pair(time):
        case (frame_tile, next_tile) (frame_time, next_time):
          Con{
            farm_frame(
              u32(2n), frame_tile, frame_time, u32(50n), "Elastic response",
              "Core samples the bend, snap, or boioioioing trajectory at 20 frames per second."
            ),
            bend_frames_go(pred, next_tile, U32.add(next_time, u32(50n)), tail)
          }

assert bend_frames:
  forall tile: U32
  forall tail: List<FarmFrame>
  List<FarmFrame>

def bend_frames(tile, tail):
  bend_frames_go(50n, tile, 0, tail)

assert bend_frames_if:
  forall planted: Bool
  forall tile: U32
  forall tail: List<FarmFrame>
  List<FarmFrame>

def bend_frames_if(planted, tile, tail):
  match planted:
    case False{}:
      tail
    case True{}:
      bend_frames(tile, tail)

assert bend_sequence:
  forall fuel: Nat
  forall tile: U32
  List<FarmFrame>

def bend_sequence(fuel, tile):
  match fuel:
    case 0n:
      Con{farm_frame(u32(2n),u32(24n),U32.mul(u32(100n),u32(100n)),U32.mul(u32(14n),u32(100n)),"Harvest complete", "Broken roots remain apart; every other beet has returned to rest."), Nil{}}
    case 1n+pred:
      match u32_four(tile):
        case U32x4{test_tile, frame_tile, next_tile, spare_tile}:
          bend_frames_if(
            tile_planted(test_tile),
            frame_tile,
            bend_sequence(pred, U32.inc(next_tile))
          )

assert uproot_frames_go:
  forall fuel: Nat
  forall time: U32
  forall tail: List<FarmFrame>
  List<FarmFrame>

def uproot_frames_go(fuel, time, tail):
  match fuel:
    case 0n:
      tail
    case 1n+pred:
      match u32_pair(time):
        case (frame_time, next_time):
          Con{
            farm_frame(
              u32(1n), u32(24n), frame_time, u32(50n), "Uproot",
              "The field loads, tears free, overshoots, and rebounds as one physical pull."
            ),
            uproot_frames_go(pred, U32.add(next_time, u32(50n)), tail)
          }

assert growth_frames_go:
  forall fuel: Nat
  forall time: U32
  forall tail: List<FarmFrame>
  List<FarmFrame>

def growth_frames_go(fuel, time, tail):
  match fuel:
    case 0n:
      tail
    case 1n+pred:
      match u32_pair(time):
        case (frame_time, next_time):
          Con{
            farm_frame(
              0, u32(24n), frame_time, u32(50n),
              "Growing", "Core wind, growth, projection and light update at 20 frames per second."
            ),
            growth_frames_go(pred, U32.add(next_time, u32(50n)), tail)
          }

assert growth_frames:
  forall tail: List<FarmFrame>
  List<FarmFrame>

def growth_frames(tail):
  growth_frames_go(
    100n,
    0,
    uproot_frames_go(16n, kilo(5n), tail)
  )

# The reusable Engine appearance is invariant across playback frames, so Core
# computes one checked material/light profile per tile instead of repeating the
# same multi-light calculation in all 1,086 immutable frames.
assert engine_input:
  forall tile: U32
  Engine.EngineInput

def engine_input(tile):
  match u32_four(tile):
    case U32x4{object_tile, planted_tile, attribute_tile, spare_tile}:
      match tile_planted(planted_tile):
        case False{}:
          Engine.EngineInput{
            object_tile, 0, 0, 0,
            u32(256n), False{}
          }
        case True{}:
          match attributes_for(attribute_tile):
            case Physics.BeetAttributes{water, sugar, fiber, size, magic, shine}:
              Engine.EngineInput{
                object_tile, shine, fiber, magic, u32(512n), False{}
              }

assert engine_inputs_go:
  forall fuel: Nat
  forall tile: U32
  List<Engine.EngineInput>

def engine_inputs_go(fuel, tile):
  match fuel:
    case 0n:
      Nil{}
    case 1n+pred:
      match u32_pair(tile):
        case (input_tile, next_tile):
          Con{
            engine_input(input_tile),
            engine_inputs_go(pred, U32.inc(next_tile))
          }

assert engine_profiles:
  List<Engine.EngineProfile>

def engine_profiles():
  Engine.engine_profiles_func(engine_inputs_go(24n, 0))

assert main_value:
  GameReport

def main_value():
  match farm_counts(24n, 0):
    case Counts{planted, broken, spring, recover}:
      GameReport{
        "Bend-a-Beet", game_seed(), u32(8n), u32(3n),
        planted, broken, spring, recover,
        engine_profiles(),
        growth_frames(bend_sequence(24n, 0))
      }

assert main_accept_value:
  forall value: GameReport
  IO(Unit)

def main_accept_value(value):
  IO.print("Ready{}")

assert main:
  IO(Unit)

def main():
  main_accept_value(main_value!())
