import Base
import ./model3d.bend as Model3D
import ../../compat/list.bend as List

# Types
# =====

type Light:
  AmbientLight{color: Model3D.Color, intensity: U32}
  DirectionalLight{direction: Model3D.Vec3, color: Model3D.Color, intensity: U32}
  PointLight{position: Model3D.Vec3, color: Model3D.Color, intensity: U32, range: U32}
  SpotLight{
    position: Model3D.Vec3,
    direction: Model3D.Vec3,
    color: Model3D.Color,
    intensity: U32,
    range: U32,
    cone: U32,
    softness: U32
  }

type Visibility:
  ClearVisibility{}
  OccludedVisibility{opacity: U32}

type Fog:
  NoFog{}
  LinearFog{color: Model3D.Color, start: U32, finish: U32}
  ExponentialFog{color: Model3D.Color, density: U32}

type ShadowControl:
  ShadowControl{bias: U32, opacity: U32, softness: U32, samples: U32}

# RayQuery is the pure boundary shared with a ray tracer. The tracer resolves
# visibility; the light library consumes that visibility without owning IO.
type RayQuery:
  RayQuery{
    origin: Model3D.Vec3,
    direction: Model3D.Vec3,
    min_distance: U32,
    max_distance: U32
  }

type ReflectionSample:
  ReflectionSample{direction: Model3D.Vec3, strength: U32, fuzz: U32}

type SurfaceSample:
  SurfaceSample{
    point: Model3D.Vec3,
    normal: Model3D.Vec3,
    view: Model3D.Vec3,
    base_color: Model3D.Color,
    roughness: U32,
    metallic: U32,
    reflection: U32,
    fuzz: U32
  }

type LightingSample:
  LightingSample{
    color: Model3D.Color,
    diffuse_level: U32,
    specular_level: U32,
    reflection_level: U32,
    fuzz_level: U32,
    shadowed: Bool
  }

type ResolvedLight:
  ResolvedLight{light: Light, visibility: Visibility, distance: U32}

type LightRig:
  LightRig{
    lights: List<ResolvedLight>,
    ambient: Model3D.Color,
    fog: Fog,
    shadows: ShadowControl
  }

# Constants
# =========

# No implicit global rig: games construct lighting explicitly and reproducibly.

# Functions
# =========

assert light_u32_func:
  forall value: Nat
  U32

def light_u32_func(value):
  U32.from_nat(value)

assert light_u32_pair_func:
  forall value: U32
  U32 & U32

def light_u32_pair_func(value):
  ((left, left_exact), (right, right_exact)) = U32.copy(value)
  (left, right)

assert light_u32_triple_func:
  forall value: U32
  U32 & (U32 & U32)

def light_u32_triple_func(value):
  (first, rest) = light_u32_pair_func(value)
  (second, third) = light_u32_pair_func(rest)
  (first, (second, third))

assert light_u32_four_func:
  forall value: U32
  U32 & (U32 & (U32 & U32))

def light_u32_four_func(value):
  (first, rest) = light_u32_pair_func(value)
  (second, tail) = light_u32_pair_func(rest)
  (third, fourth) = light_u32_pair_func(tail)
  (first, (second, (third, fourth)))

assert light_channel_clamp_func:
  forall value: U32
  U32

def light_channel_clamp_func(value):
  (test, keep) = light_u32_pair_func(value)
  match U32.is_le(test, light_u32_func(255n)):
    case True{}:
      keep
    case False{}:
      light_u32_func(255n)

assert light_channel_multiply_func:
  forall left: U32
  forall right: U32
  U32

def light_channel_multiply_func(left, right):
  light_channel_clamp_func(
    U32.div(U32.mul(left, right), light_u32_func(255n))
  )

assert light_channel_add_func:
  forall left: U32
  forall right: U32
  U32

def light_channel_add_func(left, right):
  light_channel_clamp_func(U32.add(left, right))

assert light_color_copy_func:
  forall value: Model3D.Color
  Model3D.Color & Model3D.Color

def light_color_copy_func(value):
  match value:
    case Model3D.Color{red, green, blue}:
      (r1, r2) = light_u32_pair_func(red)
      (g1, g2) = light_u32_pair_func(green)
      (b1, b2) = light_u32_pair_func(blue)
      (Model3D.Color{r1, g1, b1}, Model3D.Color{r2, g2, b2})

assert light_color_add_func:
  forall left: Model3D.Color
  forall right: Model3D.Color
  Model3D.Color

def light_color_add_func(left, right):
  match left right:
    case Model3D.Color{lr, lg, lb} Model3D.Color{rr, rg, rb}:
      Model3D.Color{
        light_channel_add_func(lr, rr),
        light_channel_add_func(lg, rg),
        light_channel_add_func(lb, rb)
      }

assert light_color_modulate_func:
  forall left: Model3D.Color
  forall right: Model3D.Color
  Model3D.Color

def light_color_modulate_func(left, right):
  match left right:
    case Model3D.Color{lr, lg, lb} Model3D.Color{rr, rg, rb}:
      Model3D.Color{
        light_channel_multiply_func(lr, rr),
        light_channel_multiply_func(lg, rg),
        light_channel_multiply_func(lb, rb)
      }

assert light_color_scale_func:
  forall value: Model3D.Color
  forall amount: U32
  Model3D.Color

def light_color_scale_func(value, amount):
  match value:
    case Model3D.Color{red, green, blue}:
      (a1, (a2, a3)) = light_u32_triple_func(amount)
      Model3D.Color{
        light_channel_multiply_func(red, a1),
        light_channel_multiply_func(green, a2),
        light_channel_multiply_func(blue, a3)
      }

assert light_color_mix_func:
  forall scene: Model3D.Color
  forall fog: Model3D.Color
  forall fog_amount: U32
  Model3D.Color

def light_color_mix_func(scene, fog, fog_amount):
  match light_u32_pair_func(light_channel_clamp_func(fog_amount)):
    case (scene_amount_source, fog_amount_copy):
      light_color_add_func(
        light_color_scale_func(scene, U32.sub(light_u32_func(255n), scene_amount_source)),
        light_color_scale_func(fog, fog_amount_copy)
      )

assert light_visibility_copy_func:
  forall value: Visibility
  Visibility & Visibility

def light_visibility_copy_func(value):
  match value:
    case ClearVisibility{}:
      (ClearVisibility{}, ClearVisibility{})
    case OccludedVisibility{opacity}:
      (left, right) = light_u32_pair_func(opacity)
      (OccludedVisibility{left}, OccludedVisibility{right})

assert light_visibility_apply_func:
  forall visibility: Visibility
  forall color: Model3D.Color
  Model3D.Color

def light_visibility_apply_func(visibility, color):
  match visibility:
    case ClearVisibility{}:
      color
    case OccludedVisibility{opacity}:
      light_color_mix_func(
        color,
        Model3D.Color{0, 0, 0},
        opacity
      )

assert light_visibility_shadowed_func:
  forall visibility: Visibility
  Bool

def light_visibility_shadowed_func(visibility):
  match visibility:
    case ClearVisibility{}:
      False{}
    case OccludedVisibility{opacity}:
      True{}

assert light_fog_copy_func:
  forall value: Fog
  Fog & Fog

def light_fog_copy_func(value):
  match value:
    case NoFog{}:
      (NoFog{}, NoFog{})
    case LinearFog{color, start, finish}:
      (color_left, color_right) = light_color_copy_func(color)
      (start_left, start_right) = light_u32_pair_func(start)
      (finish_left, finish_right) = light_u32_pair_func(finish)
      (
        LinearFog{color_left, start_left, finish_left},
        LinearFog{color_right, start_right, finish_right}
      )
    case ExponentialFog{color, density}:
      (color_left, color_right) = light_color_copy_func(color)
      (density_left, density_right) = light_u32_pair_func(density)
      (
        ExponentialFog{color_left, density_left},
        ExponentialFog{color_right, density_right}
      )

assert light_linear_fog_amount_func:
  forall start: U32
  forall finish: U32
  forall distance: U32
  U32

def light_linear_fog_amount_func(start, finish, distance):
  match
    light_u32_triple_func(distance)
    light_u32_triple_func(start)
    light_u32_pair_func(finish):
    case
      (distance_start, (distance_finish, distance_mix))
      (start_test, (start_mix, start_denominator))
      (finish_test, finish_mix):
      match U32.is_le(distance_start, start_test):
        case True{}:
          0
        case False{}:
          match U32.is_ge(distance_finish, finish_test):
            case True{}:
              light_u32_func(255n)
            case False{}:
              light_channel_clamp_func(
                U32.div(
                  U32.mul(U32.sub(distance_mix, start_mix), light_u32_func(255n)),
                  U32.sub(finish_mix, start_denominator)
                )
              )

assert light_fog_apply_func:
  forall fog: Fog
  forall color: Model3D.Color
  forall distance: U32
  Model3D.Color

def light_fog_apply_func(fog, color, distance):
  match fog:
    case NoFog{}:
      color
    case LinearFog{fog_color, start, finish}:
      light_color_mix_func(
        color,
        fog_color,
        light_linear_fog_amount_func(start, finish, distance)
      )
    case ExponentialFog{fog_color, density}:
      light_color_mix_func(
        color,
        fog_color,
        light_channel_clamp_func(U32.shrn(8n, U32.mul(distance, density)))
      )

assert light_scalar_positive_func:
  forall value: Model3D.Scalar
  U32

def light_scalar_positive_func(value):
  match value:
    case Model3D.ScalarNeg{magnitude}:
      0
    case Model3D.ScalarPos{magnitude}:
      light_channel_clamp_func(magnitude)

assert light_lambert_func:
  forall normal: Model3D.Vec3
  forall toward_light: Model3D.Vec3
  U32

def light_lambert_func(normal, toward_light):
  light_scalar_positive_func(Model3D.model3d_vec3_dot_func(normal, toward_light))

assert light_surface_from_material_func:
  forall material: Model3D.Material
  forall point: Model3D.Vec3
  forall normal: Model3D.Vec3
  forall view: Model3D.Vec3
  forall uv: Model3D.Vec2
  forall facet_id: U32
  SurfaceSample

def light_surface_from_material_func(material, point, normal, view, uv, facet_id):
  match material:
    case Model3D.Material{texture, roughness, metallic, reflection, fuzz, fur_length, fur_density}:
      SurfaceSample{
        point,
        normal,
        view,
        Model3D.model3d_texture_sample_func(texture, uv, facet_id),
        roughness,
        metallic,
        reflection,
        fuzz
      }

assert light_surface_copy_func:
  forall value: SurfaceSample
  SurfaceSample & SurfaceSample

def light_surface_copy_func(value):
  match value:
    case SurfaceSample{point, normal, view, base_color, roughness, metallic, reflection, fuzz}:
      (point_left, point_right) = Model3D.model3d_vec3_copy_func(point)
      (normal_left, normal_right) = Model3D.model3d_vec3_copy_func(normal)
      (view_left, view_right) = Model3D.model3d_vec3_copy_func(view)
      (color_left, color_right) = light_color_copy_func(base_color)
      (rough_left, rough_right) = light_u32_pair_func(roughness)
      (metal_left, metal_right) = light_u32_pair_func(metallic)
      (reflection_left, reflection_right) = light_u32_pair_func(reflection)
      (fuzz_left, fuzz_right) = light_u32_pair_func(fuzz)
      (
        SurfaceSample{
          point_left, normal_left, view_left, color_left,
          rough_left, metal_left, reflection_left, fuzz_left
        },
        SurfaceSample{
          point_right, normal_right, view_right, color_right,
          rough_right, metal_right, reflection_right, fuzz_right
        }
      )

assert light_shadow_query_func:
  forall point: Model3D.Vec3
  forall toward_light: Model3D.Vec3
  forall control: ShadowControl
  forall max_distance: U32
  RayQuery

def light_shadow_query_func(point, toward_light, control, max_distance):
  match control:
    case ShadowControl{bias, opacity, softness, samples}:
      RayQuery{point, toward_light, bias, max_distance}

assert light_default_shadow_query_func:
  forall point: Model3D.Vec3
  RayQuery

def light_default_shadow_query_func(point):
  RayQuery{
    point,
    Model3D.Vec3{
      Model3D.ScalarNeg{light_u32_func(128n)},
      Model3D.ScalarPos{light_u32_func(221n)},
      Model3D.ScalarNeg{light_u32_func(64n)}
    },
    light_u32_func(1n),
    light_u32_func(4096n)
  }

assert light_shadow_queries_from_points_func:
  forall points: List<Model3D.Vec3>
  List<RayQuery>

def light_shadow_queries_from_points_func(points):
  match points:
    case Nil{}:
      Nil{}
    case Con{point, tail}:
      Con{
        light_default_shadow_query_func(point),
        light_shadow_queries_from_points_func(tail)
      }

assert light_fuzz_vector_func:
  forall seed: U32
  forall fuzz: U32
  Model3D.Vec3

def light_fuzz_vector_func(seed, fuzz):
  match light_u32_triple_func(seed) light_u32_triple_func(fuzz):
    case (sx, (sy, sz)) (fx, (fy, fz)):
      Model3D.Vec3{
        Model3D.ScalarNeg{U32.mod(U32.mul(sx, fx), light_u32_func(65n))},
        Model3D.ScalarPos{U32.mod(U32.mul(sy, fy), light_u32_func(65n))},
        Model3D.ScalarNeg{U32.mod(U32.mul(sz, fz), light_u32_func(65n))}
      }

assert light_reflection_sample_finish_func:
  forall reflected: Model3D.Vec3
  forall seed: U32
  forall strength: U32
  forall fuzz: U32
  ReflectionSample

def light_reflection_sample_finish_func(reflected, seed, strength, fuzz):
  match light_u32_pair_func(fuzz):
    case (fuzz_vector, fuzz_output):
      ReflectionSample{
        Model3D.model3d_vec3_add_func(reflected, light_fuzz_vector_func(seed, fuzz_vector)),
        strength,
        fuzz_output
      }

assert light_reflection_sample_func:
  forall surface: SurfaceSample
  forall seed: U32
  ReflectionSample

def light_reflection_sample_func(surface, seed):
  match surface:
    case SurfaceSample{point, normal, view, base_color, roughness, metallic, reflection, fuzz}:
      ReflectionSample{
        Model3D.model3d_vec3_reflect_func(view, normal),
        reflection,
        fuzz
      }

# Fuzz is applied on demand so inspecting the strength field does not force the
# independent direction computation. This also lets proof erasure remove all
# vector work when a theorem concerns reflection energy alone.
assert light_reflection_fuzzed_direction_func:
  forall sample: ReflectionSample
  forall seed: U32
  Model3D.Vec3

def light_reflection_fuzzed_direction_func(sample, seed):
  match sample:
    case ReflectionSample{direction, strength, fuzz}:
      Model3D.model3d_vec3_add_func(
        direction,
        light_fuzz_vector_func(seed, fuzz)
      )

assert light_reflection_strength_func:
  forall sample: ReflectionSample
  U32

def light_reflection_strength_func(sample):
  match sample:
    case ReflectionSample{direction, strength, fuzz}:
      strength

assert light_specular_level_func:
  forall intensity: U32
  forall lambert: U32
  forall roughness: U32
  forall metallic: U32
  U32

def light_specular_level_func(intensity, lambert, roughness, metallic):
  light_channel_multiply_func(
    light_channel_multiply_func(intensity, lambert),
    light_channel_add_func(
      U32.sub(light_u32_func(255n), roughness),
      U32.div(metallic, light_u32_func(2n))
    )
  )

assert light_directional_levels_func:
  forall base_color: Model3D.Color
  forall light_color: Model3D.Color
  forall intensity: U32
  forall lambert: U32
  forall roughness: U32
  forall metallic: U32
  forall reflection: U32
  forall fuzz: U32
  forall visibility: Visibility
  forall fog: Fog
  forall distance: U32
  LightingSample

def light_directional_levels_func(base_color, light_color, intensity, lambert, roughness, metallic, reflection, fuzz, visibility, fog, distance):
  match
    light_u32_pair_func(intensity)
    light_u32_pair_func(lambert)
    light_visibility_copy_func(visibility):
    case
      (intensity_diffuse, intensity_specular)
      (lambert_diffuse, lambert_specular)
      (visibility_color, visibility_output):
      match light_u32_pair_func(
        light_channel_multiply_func(intensity_diffuse, lambert_diffuse)
      ):
        case (diffuse_color, diffuse_output):
          LightingSample{
            light_fog_apply_func(
              fog,
              light_visibility_apply_func(
                visibility_color,
                light_color_scale_func(
                  light_color_modulate_func(base_color, light_color),
                  diffuse_color
                )
              ),
              distance
            ),
            diffuse_output,
            light_specular_level_func(
              intensity_specular,
              lambert_specular,
              roughness,
              metallic
            ),
            reflection,
            fuzz,
            light_visibility_shadowed_func(visibility_output)
          }

assert light_shade_directional_func:
  forall surface: SurfaceSample
  forall toward_light: Model3D.Vec3
  forall light_color: Model3D.Color
  forall intensity: U32
  forall visibility: Visibility
  forall fog: Fog
  forall distance: U32
  LightingSample

def light_shade_directional_func(surface, toward_light, light_color, intensity, visibility, fog, distance):
  match surface:
    case SurfaceSample{point, normal, view, base_color, roughness, metallic, reflection, fuzz}:
      light_directional_levels_func(
        base_color,
        light_color,
        intensity,
        light_lambert_func(normal, toward_light),
        roughness,
        metallic,
        reflection,
        fuzz,
        visibility,
        fog,
        distance
      )

assert light_point_attenuation_func:
  forall distance: U32
  forall range: U32
  U32

def light_point_attenuation_func(distance, range):
  match light_u32_pair_func(distance) light_u32_triple_func(range):
    case (distance_test, distance_sub) (range_test, (range_sub, range_denominator)):
      match U32.is_le(distance_test, range_test):
        case False{}:
          0
        case True{}:
          light_channel_clamp_func(
            U32.div(
              U32.mul(
                U32.sub(range_sub, distance_sub),
                light_u32_func(255n)
              ),
              range_denominator
            )
          )

assert light_spot_cone_sum_func:
  forall sum: U32
  forall cone: U32
  forall softness: U32
  U32

def light_spot_cone_sum_func(sum, cone, softness):
  match
    light_u32_pair_func(sum)
    light_u32_pair_func(cone)
    light_u32_pair_func(softness):
    case
      (sum_test, sum_sub)
      (cone_test, cone_sub)
      (softness_test, softness_denominator):
      match U32.is_ge(sum_test, cone_test):
        case False{}:
          0
        case True{}:
          match U32.is_zero(softness_test):
            case True{}:
              0
            case False{}:
              light_channel_clamp_func(
                U32.div(
                  U32.mul(U32.sub(sum_sub, cone_sub), light_u32_func(255n)),
                  softness_denominator
                )
              )

# alignment, cone, and softness are Q0.8 channels. Inside the hard cone the
# factor is 255; the authored softness band falls linearly toward zero.
assert light_spot_cone_func:
  forall alignment: U32
  forall cone: U32
  forall softness: U32
  U32

def light_spot_cone_func(alignment, cone, softness):
  match
    light_u32_pair_func(alignment)
    light_u32_pair_func(cone)
    light_u32_pair_func(softness):
    case
      (alignment_test, alignment_soft)
      (cone_test, cone_soft)
      (softness_add, softness_divide):
      match U32.is_ge(alignment_test, cone_test):
        case True{}:
          light_u32_func(255n)
        case False{}:
          light_spot_cone_sum_func(
            U32.add(alignment_soft, softness_add),
            cone_soft,
            softness_divide
          )

assert light_ambient_finish_func:
  forall base_color: Model3D.Color
  forall ambient_color: Model3D.Color
  forall intensity: U32
  forall reflection: U32
  forall fuzz: U32
  forall fog: Fog
  forall distance: U32
  LightingSample

def light_ambient_finish_func(base_color, ambient_color, intensity, reflection, fuzz, fog, distance):
  match light_u32_pair_func(intensity):
    case (intensity_color, intensity_output):
      LightingSample{
        light_fog_apply_func(
          fog,
          light_color_scale_func(
            light_color_modulate_func(base_color, ambient_color),
            intensity_color
          ),
          distance
        ),
        intensity_output,
        0,
        reflection,
        fuzz,
        False{}
      }

assert light_shade_ambient_func:
  forall surface: SurfaceSample
  forall ambient_color: Model3D.Color
  forall intensity: U32
  forall fog: Fog
  forall distance: U32
  LightingSample

def light_shade_ambient_func(surface, ambient_color, intensity, fog, distance):
  match surface:
    case SurfaceSample{point, normal, view, base_color, roughness, metallic, reflection, fuzz}:
      light_ambient_finish_func(
        base_color,
        ambient_color,
        intensity,
        reflection,
        fuzz,
        fog,
        distance
      )

assert light_point_surface_func:
  forall point_surface: SurfaceSample
  forall shade_surface: SurfaceSample
  forall light_position: Model3D.Vec3
  forall light_color: Model3D.Color
  forall intensity: U32
  forall range: U32
  forall visibility: Visibility
  forall fog: Fog
  forall attenuation_distance: U32
  forall fog_distance: U32
  LightingSample

def light_point_surface_func(point_surface, shade_surface, light_position, light_color, intensity, range, visibility, fog, attenuation_distance, fog_distance):
  match point_surface:
    case SurfaceSample{point, normal, view, base_color, roughness, metallic, reflection, fuzz}:
      light_shade_directional_func(
        shade_surface,
        Model3D.model3d_vec3_sub_func(light_position, point),
        light_color,
        light_channel_multiply_func(
          intensity,
          light_point_attenuation_func(attenuation_distance, range)
        ),
        visibility,
        fog,
        fog_distance
      )

assert light_shade_point_func:
  forall surface: SurfaceSample
  forall light_position: Model3D.Vec3
  forall light_color: Model3D.Color
  forall intensity: U32
  forall range: U32
  forall visibility: Visibility
  forall fog: Fog
  forall distance: U32
  LightingSample

def light_shade_point_func(surface, light_position, light_color, intensity, range, visibility, fog, distance):
  match light_surface_copy_func(surface) light_u32_pair_func(distance):
    case (point_surface, shade_surface) (attenuation_distance, fog_distance):
      light_point_surface_func(
        point_surface,
        shade_surface,
        light_position,
        light_color,
        intensity,
        range,
        visibility,
        fog,
        attenuation_distance,
        fog_distance
      )

assert light_spot_surface_func:
  forall point_surface: SurfaceSample
  forall shade_surface: SurfaceSample
  forall light_position: Model3D.Vec3
  forall spot_direction: Model3D.Vec3
  forall light_color: Model3D.Color
  forall intensity: U32
  forall range: U32
  forall cone: U32
  forall softness: U32
  forall visibility: Visibility
  forall fog: Fog
  forall attenuation_distance: U32
  forall fog_distance: U32
  LightingSample

def light_spot_surface_func(point_surface, shade_surface, light_position, spot_direction, light_color, intensity, range, cone, softness, visibility, fog, attenuation_distance, fog_distance):
  match point_surface:
    case SurfaceSample{point, normal, view, base_color, roughness, metallic, reflection, fuzz}:
      match
        Model3D.model3d_vec3_copy_func(point)
        Model3D.model3d_vec3_copy_func(light_position):
        case
          (point_from_light, point_toward_light)
          (position_from_light, position_toward_light):
          light_shade_directional_func(
            shade_surface,
            Model3D.model3d_vec3_sub_func(position_toward_light, point_toward_light),
            light_color,
            light_channel_multiply_func(
              light_channel_multiply_func(
                intensity,
                light_point_attenuation_func(attenuation_distance, range)
              ),
              light_spot_cone_func(
                light_lambert_func(
                  spot_direction,
                  Model3D.model3d_vec3_sub_func(point_from_light, position_from_light)
                ),
                cone,
                softness
              )
            ),
            visibility,
            fog,
            fog_distance
          )

assert light_shade_spot_func:
  forall surface: SurfaceSample
  forall light_position: Model3D.Vec3
  forall spot_direction: Model3D.Vec3
  forall light_color: Model3D.Color
  forall intensity: U32
  forall range: U32
  forall cone: U32
  forall softness: U32
  forall visibility: Visibility
  forall fog: Fog
  forall distance: U32
  LightingSample

def light_shade_spot_func(surface, light_position, spot_direction, light_color, intensity, range, cone, softness, visibility, fog, distance):
  match light_surface_copy_func(surface) light_u32_pair_func(distance):
    case (point_surface, shade_surface) (attenuation_distance, fog_distance):
      light_spot_surface_func(
        point_surface,
        shade_surface,
        light_position,
        spot_direction,
        light_color,
        intensity,
        range,
        cone,
        softness,
        visibility,
        fog,
        attenuation_distance,
        fog_distance
      )

assert light_shade_func:
  forall light: Light
  forall surface: SurfaceSample
  forall visibility: Visibility
  forall fog: Fog
  forall distance: U32
  LightingSample

def light_shade_func(light, surface, visibility, fog, distance):
  match light:
    case AmbientLight{color, intensity}:
      light_shade_ambient_func(surface, color, intensity, fog, distance)
    case DirectionalLight{direction, color, intensity}:
      light_shade_directional_func(
        surface, direction, color, intensity, visibility, fog, distance
      )
    case PointLight{position, color, intensity, range}:
      light_shade_point_func(
        surface, position, color, intensity, range, visibility, fog, distance
      )
    case SpotLight{position, direction, color, intensity, range, cone, softness}:
      light_shade_spot_func(
        surface, position, direction, color, intensity, range, cone, softness,
        visibility, fog, distance
      )

assert light_sample_color_func:
  forall sample: LightingSample
  Model3D.Color

def light_sample_color_func(sample):
  match sample:
    case LightingSample{color, diffuse, specular, reflection, fuzz, shadowed}:
      color

assert light_resolved_fold_func:
  forall resolved: List<ResolvedLight>
  forall surface: SurfaceSample
  forall fog: Fog
  forall ambient: Model3D.Color
  Model3D.Color

def light_resolved_fold_func(resolved, surface, fog, ambient):
  match resolved:
    case Nil{}:
      ambient
    case Con{ResolvedLight{light, visibility, distance}, tail}:
      match light_surface_copy_func(surface) light_fog_copy_func(fog):
        case (surface_here, surface_tail) (fog_here, fog_tail):
          light_color_add_func(
            light_sample_color_func(
              light_shade_func(light, surface_here, visibility, fog_here, distance)
            ),
            light_resolved_fold_func(tail, surface_tail, fog_tail, ambient)
          )

assert light_rig_shade_func:
  forall rig: LightRig
  forall surface: SurfaceSample
  Model3D.Color

def light_rig_shade_func(rig, surface):
  match rig:
    case LightRig{lights, ambient, fog, shadows}:
      light_resolved_fold_func(lights, surface, fog, ambient)

# Universal theorem: a clear ray-tracer result preserves every possible color.
assert light_clear_visibility_identity_theorem_func:
  forall color: Model3D.Color
  { light_visibility_apply_func(ClearVisibility{}, color) == color : Model3D.Color }

def light_clear_visibility_identity_theorem_func(color):
  {==}

# Universal theorem: disabling fog preserves every color at every distance.
assert light_no_fog_identity_theorem_func:
  forall color: Model3D.Color
  forall distance: U32
  { light_fog_apply_func(NoFog{}, color, distance) == color : Model3D.Color }

def light_no_fog_identity_theorem_func(color, distance):
  {==}

# Universal algebraic theorem: reflecting twice across the x-axis is identity.
assert light_axis_x_reflection_involution_theorem_func:
  forall value: Model3D.Vec3
  { Model3D.model3d_vec3_reflect_axis_x_func( Model3D.model3d_vec3_reflect_axis_x_func(value) ) == value : Model3D.Vec3 }

def light_axis_x_reflection_involution_theorem_func(value):
  match value:
    case Model3D.Vec3{x, y, z}:
      %Model3D.model3d_scalar_negation_involution_theorem_func(x) : {
        Model3D.Vec3{
          Model3D.model3d_scalar_negate_func(Model3D.model3d_scalar_negate_func(x)),
          y,
          z
        } == Model3D.Vec3{_, y, z} : Model3D.Vec3
      }
      {==}

# Structural induction over arbitrary point lists: ray cooperation emits one
# and only one shadow query for every requested surface point.
assert light_shadow_query_cardinality_theorem_func:
  forall points: List<Model3D.Vec3>
  { List.length(RayQuery, light_shadow_queries_from_points_func(points)) == List.length(Model3D.Vec3, points) : Nat }

def light_shadow_query_cardinality_theorem_func(points):
  match points:
    case Nil{}:
      {==}
    case Con{point, tail}:
      %light_shadow_query_cardinality_theorem_func(tail) : {
        1n+List.length(RayQuery, light_shadow_queries_from_points_func(tail)) == 1n+_
        : Nat
      }
      {==}

# One closed regression certificate, deliberately not called a theorem.
assert light_clear_reference_certificate_func:
  { light_visibility_apply_func( ClearVisibility{}, Model3D.Color{light_u32_func(17n), light_u32_func(99n), light_u32_func(201n)} ) == Model3D.Color{light_u32_func(17n), light_u32_func(99n), light_u32_func(201n)} : Model3D.Color }

def light_clear_reference_certificate_func():
  {==}

assert light_verification_consume_func:
  forall -clear_identity: @color: Model3D.Color -> { light_visibility_apply_func(ClearVisibility{}, color) == color : Model3D.Color }
  forall -no_fog_identity: @color: Model3D.Color -> @distance: U32 -> { light_fog_apply_func(NoFog{}, color, distance) == color : Model3D.Color }
  forall -axis_reflection_involution: @value: Model3D.Vec3 -> { Model3D.model3d_vec3_reflect_axis_x_func( Model3D.model3d_vec3_reflect_axis_x_func(value) ) == value : Model3D.Vec3 }
  forall -shadow_query_cardinality: @points: List<Model3D.Vec3> -> { List.length(RayQuery, light_shadow_queries_from_points_func(points)) == List.length(Model3D.Vec3, points) : Nat }
  forall -clear_reference: { light_visibility_apply_func( ClearVisibility{}, Model3D.Color{light_u32_func(17n), light_u32_func(99n), light_u32_func(201n)} ) == Model3D.Color{light_u32_func(17n), light_u32_func(99n), light_u32_func(201n)} : Model3D.Color }
  Bool

def light_verification_consume_func(clear_identity, no_fog_identity, axis_reflection_involution, shadow_query_cardinality, clear_reference):
  True{}

assert light_verification_func:
  Bool

def light_verification_func():
  light_verification_consume_func(
    light_clear_visibility_identity_theorem_func,
    light_no_fog_identity_theorem_func,
    light_axis_x_reflection_involution_theorem_func,
    light_shadow_query_cardinality_theorem_func,
    light_clear_reference_certificate_func()
  )
