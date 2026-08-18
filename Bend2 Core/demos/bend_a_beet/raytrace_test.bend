import Base
import ./raytrace.bend as RT

# Focused executable checks for the public ray-tracing API.  `main` is Bool so
# it can be validated through Core's normalizer and generated JS/C backends.

def proofs_checked(-proofs: RT.RaytraceProofs) -> Bool:
  True{}

def hit_at(value: RT.Hit, expected: U32) -> Bool:
  match value:
    case RT.Miss{}:
      False{}
    case RT.Hit{distance}:
      U32.is_eq(distance, expected)

def is_miss(value: RT.Hit) -> Bool:
  match value:
    case RT.Miss{}:
      True{}
    case RT.Hit{distance}:
      False{}

def is_shadow(value: RT.ShadeSample) -> Bool:
  match value:
    case RT.ShadeSample{intensity, shadowed, hit_distance}:
      Bool.and(
        shadowed,
        Bool.and(
          U32.is_eq(intensity, U32.from_nat(40n)),
          U32.is_gt(hit_distance, U32.zero())
        )
      )

def is_clear(value: RT.ShadeSample) -> Bool:
  match value:
    case RT.ShadeSample{intensity, shadowed, hit_distance}:
      Bool.and(
        Bool.not(shadowed),
        Bool.and(
          U32.is_gt(intensity, U32.from_nat(40n)),
          U32.is_zero(hit_distance)
        )
      )

def is_farm_light(value: RT.FarmLight) -> Bool:
  match value:
    case RT.FarmLight{tile_intensity, beet_intensity, tile_shadowed, tile_hit_distance}:
      Bool.and(
        tile_shadowed,
        Bool.and(
          U32.is_eq(tile_intensity, U32.from_nat(40n)),
          Bool.and(
            U32.is_gt(beet_intensity, U32.from_nat(40n)),
            U32.is_gt(tile_hit_distance, U32.zero())
          )
        )
      )

def main() -> Bool:
  proofs = proofs_checked(RT.raytrace_proofs())
  sphere_hit = hit_at(
    RT.ray_sphere(
      RT.ray(
        RT.vec3_raw(U32.zero(), U32.zero(), U32.zero()),
        RT.vec3(RT.fix_one(), RT.fix_zero(), RT.fix_zero())
      ),
      RT.sphere(
        RT.vec3_raw(U32.from_nat(512n), U32.zero(), U32.zero()),
        U32.from_nat(256n)
      )
    ),
    U32.from_nat(256n)
  )
  sphere_behind = is_miss(
    RT.ray_sphere(
      RT.ray(
        RT.vec3_raw(U32.zero(), U32.zero(), U32.zero()),
        RT.vec3(RT.fix_neg(U32.from_nat(256n)), RT.fix_zero(), RT.fix_zero())
      ),
      RT.sphere(
        RT.vec3_raw(U32.from_nat(512n), U32.zero(), U32.zero()),
        U32.from_nat(256n)
      )
    )
  )
  plane_hit = hit_at(
    RT.ray_plane_y(
      RT.ray(
        RT.vec3_raw(U32.zero(), U32.from_nat(512n), U32.zero()),
        RT.vec3(RT.fix_zero(), RT.fix_neg(U32.from_nat(256n)), RT.fix_zero())
      ),
      RT.fix_zero()
    ),
    U32.from_nat(512n)
  )
  shadow = is_shadow(
    RT.shade_point(
      RT.vec3_raw(U32.zero(), U32.zero(), U32.zero()),
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
      RT.vec3_raw(U32.zero(), U32.zero(), U32.zero()),
      RT.vec3(RT.fix_zero(), RT.fix_one(), RT.fix_zero()),
      RT.default_sun(),
      RT.sphere(
        RT.vec3_raw(U32.shln(11n, U32.one()), U32.from_nat(256n), U32.zero()),
        U32.from_nat(64n)
      )
    )
  )
  farm = is_farm_light(
    RT.farm_light(
      RT.vec3_raw(U32.zero(), U32.zero(), U32.zero()),
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
    proofs,
    Bool.and(
      sphere_hit,
      Bool.and(sphere_behind, Bool.and(plane_hit, Bool.and(shadow, Bool.and(clear, farm))))
    )
  )
