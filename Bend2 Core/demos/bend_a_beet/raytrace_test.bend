import Base
import ./raytrace.bend as RT

# Focused executable checks for the public ray-tracing API.  `main` is Bool so
# it can be validated through Core's normalizer and generated JS/C backends.

assert verification_checked:
  forall -audit: RT.RaytraceVerificationAudit
  Bool

def verification_checked(audit):
  True{}

assert hit_at:
  forall value: RT.Hit
  forall expected: U32
  Bool

def hit_at(value, expected):
  match value:
    case RT.Miss{}:
      False{}
    case RT.Hit{distance}:
      U32.is_eq(distance, expected)

assert is_miss:
  forall value: RT.Hit
  Bool

def is_miss(value):
  match value:
    case RT.Miss{}:
      True{}
    case RT.Hit{distance}:
      False{}

assert is_shadow:
  forall value: RT.ShadeSample
  Bool

def is_shadow(value):
  match value:
    case RT.ShadeSample{intensity, shadowed, hit_distance}:
      Bool.and(
        shadowed,
        Bool.and(
          U32.is_eq(intensity, U32.from_nat(40n)),
          U32.is_gt(hit_distance, 0)
        )
      )

assert is_clear:
  forall value: RT.ShadeSample
  Bool

def is_clear(value):
  match value:
    case RT.ShadeSample{intensity, shadowed, hit_distance}:
      Bool.and(
        Bool.not(shadowed),
        Bool.and(
          U32.is_gt(intensity, U32.from_nat(40n)),
          U32.is_zero(hit_distance)
        )
      )

assert is_farm_light:
  forall value: RT.FarmLight
  Bool

def is_farm_light(value):
  match value:
    case RT.FarmLight{tile_intensity, beet_intensity, tile_shadowed, tile_hit_distance}:
      Bool.and(
        tile_shadowed,
        Bool.and(
          U32.is_eq(tile_intensity, U32.from_nat(40n)),
          Bool.and(
            U32.is_gt(beet_intensity, U32.from_nat(40n)),
            U32.is_gt(tile_hit_distance, 0)
          )
        )
      )

assert main_value:
  Bool

def main_value():
  verification = verification_checked(RT.raytrace_verification())
  sphere_hit = hit_at(
    RT.ray_sphere(
      RT.ray(
        RT.vec3_raw(0, 0, 0),
        RT.vec3(RT.fix_one(), RT.fix_zero(), RT.fix_zero())
      ),
      RT.sphere(
        RT.vec3_raw(U32.from_nat(512n), 0, 0),
        U32.from_nat(256n)
      )
    ),
    U32.from_nat(256n)
  )
  sphere_behind = is_miss(
    RT.ray_sphere(
      RT.ray(
        RT.vec3_raw(0, 0, 0),
        RT.vec3(RT.fix_neg(U32.from_nat(256n)), RT.fix_zero(), RT.fix_zero())
      ),
      RT.sphere(
        RT.vec3_raw(U32.from_nat(512n), 0, 0),
        U32.from_nat(256n)
      )
    )
  )
  plane_hit = hit_at(
    RT.ray_plane_y(
      RT.ray(
        RT.vec3_raw(0, U32.from_nat(512n), 0),
        RT.vec3(RT.fix_zero(), RT.fix_neg(U32.from_nat(256n)), RT.fix_zero())
      ),
      RT.fix_zero()
    ),
    U32.from_nat(512n)
  )
  shadow = is_shadow(
    RT.shade_point(
      RT.vec3_raw(0, 0, 0),
      RT.vec3(RT.fix_zero(), RT.fix_one(), RT.fix_zero()),
      RT.default_sun(),
      RT.sphere(
        RT.vec3_raw(U32.from_nat(362n), U32.from_nat(362n), U32.from_nat(128n)),
        U32.from_nat(96n)
      )
    )
  )
  clear = is_clear(
    RT.shade_point(
      RT.vec3_raw(0, 0, 0),
      RT.vec3(RT.fix_zero(), RT.fix_one(), RT.fix_zero()),
      RT.default_sun(),
      RT.sphere(
        RT.vec3_raw(U32.shln(11n, 1), U32.from_nat(256n), 0),
        U32.from_nat(64n)
      )
    )
  )
  farm = is_farm_light(
    RT.farm_light(
      RT.vec3_raw(0, 0, 0),
      RT.vec3(RT.fix_zero(), RT.fix_one(), RT.fix_zero()),
      RT.vec3_raw(U32.from_nat(362n), U32.from_nat(458n), U32.from_nat(128n)),
      RT.vec3(RT.fix_zero(), RT.fix_one(), RT.fix_zero()),
      RT.default_sun(),
      RT.sphere(
        RT.vec3_raw(U32.from_nat(362n), U32.from_nat(362n), U32.from_nat(128n)),
        U32.from_nat(96n)
      )
    )
  )
  Bool.and(
    verification,
    Bool.and(
      sphere_hit,
      Bool.and(sphere_behind, Bool.and(plane_hit, Bool.and(shadow, Bool.and(clear, farm))))
    )
  )

assert main_show_bool:
  forall value: Bool
  IO(Unit)

def main_show_bool(value):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

assert main:
  IO(Unit)

def main():
  main_show_bool(main_value!())
