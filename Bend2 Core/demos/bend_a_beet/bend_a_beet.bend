import Base
import ./physics.bend as Physics
import ./graphics3d.bend as Graphics
import ./raytrace.bend as Rays

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

def u32(value: Nat) -> U32:
  U32.from_nat(value)

def u32_pair(value: U32) -> U32 & U32:
  ((left, left_exact), (right, right_exact)) = U32.copy(value)
  (left, right)

def u32_four(value: U32) -> U32x4:
  (left, right) = u32_pair(value)
  (a, b) = u32_pair(left)
  (c, d) = u32_pair(right)
  U32x4{a, b, c, d}

def u32_eight(value: U32) -> U32x8:
  (left, right) = u32_pair(value)
  match u32_four(left) u32_four(right):
    case U32x4{a, b, c, d} U32x4{e, f, g, h}:
      U32x8{a, b, c, d, e, f, g, h}

def u32_sixteen(value: U32) -> U32x16:
  (left, right) = u32_pair(value)
  match u32_eight(left) u32_eight(right):
    case U32x8{a, b, c, d, e, f, g, h} U32x8{i, j, k, l, m, n, o, p}:
      U32x16{a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p}

def game_seed() -> U32:
  # 190 * 256 + 183, kept as U32 arithmetic so the source does not build a
  # 48,823-constructor unary Nat literal.
  U32.add(U32.shln(8n, u32(190n)), u32(183n))

def kilo(multiplier: Nat) -> U32:
  U32.mul(u32(multiplier), u32(1000n))

def beet_seed(tile: U32) -> U32:
  U32.add(game_seed(), U32.mul(tile, U32.add(kilo(7n), u32(919n))))

def attributes_for(tile: U32) -> Physics.BeetAttributes:
  (seed_tile, attribute_tile) = u32_pair(tile)
  Physics.attributes_from_seed(beet_seed(seed_tile), attribute_tile)

def tile_planted(tile: U32) -> Bool:
  match U32.is_zero(U32.mod(U32.xor(beet_seed(tile), u32(313n)), u32(5n))):
    case True{}: False{}
    case False{}: True{}

# Fixed-point bridges and projections
# ===================================

def physics_fixed(value: Physics.Fix) -> Graphics.Fixed:
  match value:
    case Physics.FixPos{magnitude}:
      Graphics.fixed_from_q10(False{}, magnitude)
    case Physics.FixNeg{magnitude}:
      Graphics.fixed_from_q10(True{}, magnitude)

def growth_wind_fixed(value: Physics.Fix) -> Graphics.Fixed:
  Graphics.fixed_mul(physics_fixed(value), Graphics.fixed_from_nat(3n))

def graphics_to_ray_fixed(value: Graphics.Fixed) -> Rays.Fix:
  match value:
    case Graphics.FixedPlus{magnitude}:
      Rays.FixPos{magnitude}
    case Graphics.FixedMinus{magnitude}:
      Rays.FixNeg{magnitude}

def graphics_to_ray_vec(value: Graphics.Vec3) -> Rays.Vec3:
  match value:
    case Graphics.Vec3{x, y, z}:
      Rays.Vec3{graphics_to_ray_fixed(x), graphics_to_ray_fixed(y), graphics_to_ray_fixed(z)}

def ray_to_graphics_fixed(value: Rays.Fix) -> Graphics.Fixed:
  match value:
    case Rays.FixPos{magnitude}:
      Graphics.FixedPlus{magnitude}
    case Rays.FixNeg{magnitude}:
      Graphics.FixedMinus{magnitude}

def ray_to_graphics_vec(value: Rays.Vec3) -> Graphics.Vec3:
  match value:
    case Rays.Vec3{x, y, z}:
      Graphics.Vec3{ray_to_graphics_fixed(x), ray_to_graphics_fixed(y), ray_to_graphics_fixed(z)}

def screen_magnitude(value: Graphics.Fixed) -> U32:
  match value:
    case Graphics.FixedPlus{magnitude}:
      Rays.u32_div(magnitude, u32(256n))
    case Graphics.FixedMinus{magnitude}:
      U32.zero()

def screen_point(point: Graphics.Vec3) -> ScreenPoint:
  match Graphics.camera_project(Graphics.camera_default(), point):
    case Graphics.ProjectedPoint{Graphics.Vec2{x, y}, depth, visible}:
      ScreenPoint{screen_magnitude(x), screen_magnitude(y), screen_magnitude(depth), visible}

def tile_point(tile: U32) -> ScreenPoint:
  screen_point(Graphics.farm_tile_position(tile))

# Seeded response and poses
# =========================

def response_outcome(
  outcome: Physics.BendOutcome,
  impulse: U32,
  stiffness: U32,
  damping: U32,
  flexibility: U32,
  max_bend: U32,
  period: U32,
  duration: U32,
  signature: U32,
  break_at: U32
) -> ResponseView:
  match outcome:
    case Physics.BeetBreak{pieces}:
      ResponseView{"break", pieces, impulse, stiffness, damping, flexibility, max_bend, period, duration, signature, break_at}
    case Physics.BeetSpring{boings}:
      ResponseView{"boioioioing", boings, impulse, stiffness, damping, flexibility, max_bend, period, duration, signature, break_at}
    case Physics.BeetRecover{}:
      ResponseView{"bend and recover", U32.zero(), impulse, stiffness, damping, flexibility, max_bend, period, duration, signature, break_at}

def response_finish(response: Physics.BeetPhysics, signature: U32) -> ResponseView:
  match response:
    case Physics.BeetPhysics{outcome, axis, impulse, stiffness, damping, flexibility, max_bend, period, duration, phase, break_at}:
      response_outcome(outcome, impulse, stiffness, damping, flexibility, max_bend, period, duration, signature, break_at)

def response_view(tile: U32) -> ResponseView:
  match u32_four(tile):
    case U32x4{seed_tile, attribute_tile, signature_tile, spare_tile}:
      response_finish(
        Physics.beet_response(beet_seed(seed_tile), attributes_for(attribute_tile)),
        beet_seed(signature_tile)
      )

def graphics_growth(elapsed: U32) -> Graphics.Fixed:
  Graphics.fixed_from_q10(
    False{},
    Rays.u32_div(U32.shln(10n, elapsed), kilo(5n))
  )

def growth_pose(tile: U32, elapsed: U32) -> Pose:
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
            False{}, False{}, False{}, "growing", U32.zero(), U32.shln(10n, U32.one()),
            height_light, height_report, U32.zero(),
            Rays.u32_div(U32.mul(growth_percent_time, u32(100n)), kilo(5n)),
            Rays.u32_div(U32.add(root_depth, stem_radius), u32(2n))
          }

def grown_pose(tile: U32, lift: Graphics.Fixed, lift_light: U32, pulled: Bool, state: String) -> Pose:
  match u32_four(tile):
    case U32x4{seed_tile, attribute_tile, spare_tile, rest_tile}:
      match Physics.beet_growth(beet_seed(seed_tile), attributes_for(attribute_tile), kilo(5n)):
        case Physics.GrowthFrame{height, root_depth, stem_radius, Physics.Vec3{sway_x, sway_y, sway_z}}:
          (height_light, height_report) = u32_pair(height)
          Pose{
            Graphics.fixed_from_nat(1n), physics_fixed(sway_x),
            lift, Graphics.fixed_zero(),
            pulled, False{}, False{}, state, U32.zero(), U32.shln(10n, U32.one()),
            height_light, height_report, lift_light, u32(100n),
            Rays.u32_div(U32.add(root_depth, stem_radius), u32(2n))
          }

def full_growth_pose(tile: U32, pulled: Bool, state: String) -> Pose:
  grown_pose(tile, Graphics.fixed_from_raw(False{}, 410n), u32(410n), pulled, state)

# The 800 ms uproot has a short downward load, an accelerating release,
# overshoot, and damped return. Raw values are Q24.8 vertical displacement.
def uproot_lift(elapsed: U32) -> UprootLift:
  match U32.to_nat(Rays.u32_div(elapsed, u32(50n))):
    case 0n: UprootLift{Graphics.fixed_from_raw(True{}, 10n), U32.zero()}
    case 1n: UprootLift{Graphics.fixed_from_raw(True{}, 18n), U32.zero()}
    case 2n: UprootLift{Graphics.fixed_from_raw(True{}, 28n), U32.zero()}
    case 3n: UprootLift{Graphics.fixed_from_raw(True{}, 20n), U32.zero()}
    case 4n: UprootLift{Graphics.fixed_from_raw(False{}, 0n), U32.zero()}
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

def uproot_state(elapsed: U32) -> String:
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

def uproot_pose(tile: U32, elapsed: U32) -> Pose:
  match u32_pair(elapsed):
    case (lift_time, state_time):
      match uproot_lift(lift_time):
        case UprootLift{geometry, light}:
          grown_pose(tile, geometry, light, True{}, uproot_state(state_time))

type StateView:
  StateView{name: String, broken_geometry: Bool, broken_report: Bool}

def bend_state_view(state: Physics.BendState) -> StateView:
  match state:
    case Physics.BeetBreaking{}: StateView{"creak...", False{}, False{}}
    case Physics.BeetBroken{pieces}: StateView{"snap!", True{}, True{}}
    case Physics.BeetBoioioing{remaining}: StateView{"boioioioing!", False{}, False{}}
    case Physics.BeetRecovering{}: StateView{"bending", False{}, False{}}
    case Physics.BeetResting{}: StateView{"resting", False{}, False{}}

def active_pose(tile: U32, elapsed: U32) -> Pose:
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

def beet_pose(stage: U32, tile: U32, active: U32, elapsed: U32) -> Pose:
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

def point_geometry(tile: U32) -> GeometryView:
  match u32_eight(tile):
    case U32x8{a, b, c, d, e, f, g, h}:
      GeometryView{
        tile_point(a), tile_point(b), tile_point(c),
        tile_point(d), tile_point(e), tile_point(f), u32(1n),
        u32(28n), u32(14n), u32(10n)
      }

def geometry_view(
  tile: U32,
  growth: Graphics.Fixed,
  wind: Graphics.Fixed,
  lift: Graphics.Fixed,
  bend: Graphics.Fixed,
  magic: U32,
  shine: U32,
  signature: U32,
  broken: Bool
) -> GeometryView:
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

def ray_add_y(point: Rays.Vec3, y: Rays.Fix) -> Rays.Vec3:
  match point:
    case Rays.Vec3{x, base_y, z}:
      Rays.Vec3{x, Rays.fix_add(base_y, y), z}

def radius_from_size(size: U32) -> U32:
  U32.add(u32(58n), Rays.u32_div(size, u32(8n)))

def light_finish(
  sample: Rays.FarmLight,
  surface: Rays.SurfaceLight,
  shadow: Rays.ShadowProjection
) -> LightView:
  match sample surface shadow:
    case Rays.FarmLight{tile_intensity, beet_intensity, tile_shadowed, tile_hit_distance}
         Rays.SurfaceLight{diffuse, specular, combined, absorbed}
         Rays.ShadowProjection{shadow_point, shadow_visible, shadow_distance}:
      LightView{
        tile_intensity, combined, tile_shadowed, tile_hit_distance,
        specular, absorbed, screen_point(ray_to_graphics_vec(shadow_point))
      }

def light_up() -> Rays.Vec3:
  Rays.Vec3{Rays.fix_zero(), Rays.fix_one(), Rays.fix_zero()}

def light_toward_sun() -> Rays.Vec3:
  Rays.Vec3{
    Rays.FixPos{u32(181n)}, Rays.FixPos{u32(181n)}, Rays.FixPos{u32(64n)}
  }

def light_toward_viewer() -> Rays.Vec3:
  Rays.Vec3{Rays.fix_zero(), Rays.FixPos{u32(181n)}, Rays.FixNeg{u32(181n)}}

def light_travel() -> Rays.Vec3:
  Rays.Vec3{
    Rays.FixNeg{u32(181n)}, Rays.FixNeg{u32(181n)}, Rays.FixNeg{u32(64n)}
  }

def light_sample_channels(
  ground: Rays.Vec3,
  surface: Rays.Vec3,
  center: Rays.Vec3,
  radius: U32,
  mapped_shine: U32
) -> LightView:
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

def light_sample(
  ground: Rays.Vec3,
  surface: Rays.Vec3,
  center: Rays.Vec3,
  radius: U32,
  shine: U32
) -> LightView:
  light_sample_channels(ground, surface, center, radius, Rays.u32_div(shine, u32(4n)))

def light_view(tile: U32, height: U32, lift: U32, size: U32, shine: U32) -> LightView:
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

def empty_geometry(tile: U32) -> GeometryView:
  point_geometry(tile)

def empty_beet(tile: U32) -> BeetView:
  match u32_eight(tile):
    case U32x8{tile_out, row_tile, column_tile, geometry_tile, shadow_tile, t5, t6, t7}:
      match empty_geometry(geometry_tile):
        case GeometryView{body, root, control, tip, leaf_left, leaf_right, radius, radial_segments, vertical_segments, leaf_segments}:
          BeetView{
            tile_out,
            Rays.u32_div(row_tile, u32(3n)), U32.mod(column_tile, u32(3n)), False{},
            U32.zero(), U32.zero(), U32.zero(), U32.zero(), U32.zero(),
            False{}, "empty", U32.zero(), "bare soil", U32.zero(), U32.zero(),
            U32.zero(), U32.zero(), u32(220n), u32(220n), False{},
            body, root, control, tip, leaf_left, leaf_right, radius, False{},
            U32.zero(), U32.zero(), U32.zero(), U32.zero(), U32.zero(),
            U32.zero(), U32.zero(), U32.zero(), U32.zero(),
            U32.zero(), U32.zero(), u32(255n), tile_point(shadow_tile),
            radial_segments, vertical_segments, leaf_segments
          }

def planted_beet(stage: U32, active: U32, elapsed: U32, tile: U32) -> BeetView:
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

def beet_view(stage: U32, active: U32, elapsed: U32, tile: U32) -> BeetView:
  match u32_pair(tile):
    case (test_tile, keep_tile):
      match tile_planted(test_tile):
        case False{}:
          empty_beet(keep_tile)
        case True{}:
          planted_beet(stage, active, elapsed, keep_tile)

def beet_views(fuel: Nat, tile: U32, stage: U32, active: U32, elapsed: U32) -> List<BeetView>:
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

def farm_frame(stage: U32, active: U32, time: U32, duration: U32, phase: String, note: String) -> FarmFrame:
  match u32_pair(active) u32_pair(time):
    case (active_report, active_views) (time_report, time_views):
      FarmFrame{
        time_report, duration, phase, note, active_report,
        beet_views(24n, U32.zero(), stage, active_views, time_views)
      }

# Counts and timeline
# ===================

def count_add(outcome: Physics.BendOutcome, counts: Counts) -> Counts:
  match outcome counts:
    case Physics.BeetBreak{pieces} Counts{planted, broken, spring, recover}:
      Counts{U32.inc(planted), U32.inc(broken), spring, recover}
    case Physics.BeetSpring{boings} Counts{planted, broken, spring, recover}:
      Counts{U32.inc(planted), broken, U32.inc(spring), recover}
    case Physics.BeetRecover{} Counts{planted, broken, spring, recover}:
      Counts{U32.inc(planted), broken, spring, U32.inc(recover)}

def farm_counts(fuel: Nat, tile: U32) -> Counts:
  match fuel:
    case 0n:
      Counts{U32.zero(), U32.zero(), U32.zero(), U32.zero()}
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

def bend_frames_go(fuel: Nat, tile: U32, time: U32, tail: List<FarmFrame>) -> List<FarmFrame>:
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

def bend_frames(tile: U32, tail: List<FarmFrame>) -> List<FarmFrame>:
  bend_frames_go(50n, tile, U32.zero(), tail)

def bend_frames_if(planted: Bool, tile: U32, tail: List<FarmFrame>) -> List<FarmFrame>:
  match planted:
    case False{}:
      tail
    case True{}:
      bend_frames(tile, tail)

def bend_sequence(fuel: Nat, tile: U32) -> List<FarmFrame>:
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

def uproot_frames_go(fuel: Nat, time: U32, tail: List<FarmFrame>) -> List<FarmFrame>:
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

def growth_frames_go(fuel: Nat, time: U32, tail: List<FarmFrame>) -> List<FarmFrame>:
  match fuel:
    case 0n:
      tail
    case 1n+pred:
      match u32_pair(time):
        case (frame_time, next_time):
          Con{
            farm_frame(
              U32.zero(), u32(24n), frame_time, u32(50n),
              "Growing", "Core wind, growth, projection and light update at 20 frames per second."
            ),
            growth_frames_go(pred, U32.add(next_time, u32(50n)), tail)
          }

def growth_frames(tail: List<FarmFrame>) -> List<FarmFrame>:
  growth_frames_go(
    100n,
    U32.zero(),
    uproot_frames_go(16n, kilo(5n), tail)
  )

def main() -> GameReport:
  match farm_counts(24n, U32.zero()):
    case Counts{planted, broken, spring, recover}:
      GameReport{
        "Bend-a-Beet", game_seed(), u32(8n), u32(3n),
        planted, broken, spring, recover,
        growth_frames(bend_sequence(24n, U32.zero()))
      }
