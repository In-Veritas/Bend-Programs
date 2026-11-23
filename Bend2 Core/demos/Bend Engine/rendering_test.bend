import Base
import ./model3d.bend as Model3D
import ./light.bend as Light
import ./raytrace.bend as Raytrace
import ./rendering_verification.bend as Verification
import ../../compat/nat.bend as Nat

# Types
# =====

# This focused entry introduces no additional data types.

# Constants
# =========

# Inputs remain explicit so there are no hidden runtime globals.

# Functions
# =========

assert rendering_model_test_func:
  forall seed: U32
  Bool

def rendering_model_test_func(seed):
  match Model3D.model3d_mesh_stats_func(Model3D.model3d_beet_mesh_func(seed)):
    case Model3D.MeshStats{vertices, facets, strands}:
      Bool.and(
        Nat.is_eq(vertices, 104n),
        Bool.and(Nat.is_eq(facets, 192n), Nat.is_eq(strands, 104n))
      )

assert rendering_query_func:
  forall marker: U32
  Light.RayQuery

def rendering_query_func(marker):
  Light.RayQuery{
    Model3D.Vec3{
      Model3D.ScalarPos{0},
      Model3D.ScalarPos{0},
      Model3D.ScalarPos{0}
    },
    Model3D.Vec3{
      Model3D.ScalarPos{U32.from_nat(256n)},
      Model3D.ScalarPos{0},
      Model3D.ScalarPos{0}
    },
    U32.from_nat(1n),
    U32.from_nat(2048n)
  }

assert rendering_scene_func:
  forall marker: U32
  List<Raytrace.Primitive>

def rendering_scene_func(marker):
  Con{
    Raytrace.SpherePrimitive{
      Raytrace.Sphere{
        Model3D.Vec3{
          Model3D.ScalarPos{U32.from_nat(512n)},
          Model3D.ScalarPos{0},
          Model3D.ScalarPos{0}
        },
        U32.from_nat(256n),
        U32.from_nat(220n)
      }
    },
    Nil{}
  }

assert rendering_visibility_distance_test_func:
  forall visibility: Light.Visibility
  forall distance: U32
  forall expected_opacity: U32
  forall expected_distance: U32
  Bool

def rendering_visibility_distance_test_func(visibility, distance, expected_opacity, expected_distance):
  match visibility:
    case Light.ClearVisibility{}:
      False{}
    case Light.OccludedVisibility{opacity}:
      Bool.and(
        U32.is_eq(opacity, expected_opacity),
        U32.is_eq(distance, expected_distance)
      )

assert rendering_ray_light_interop_test_func:
  forall marker: U32
  Bool

def rendering_ray_light_interop_test_func(marker):
  match Raytrace.raytrace_scene_sample_func(
    rendering_query_func(0),
    rendering_scene_func(marker)
  ):
    case Raytrace.TraceSample{visibility, distance}:
      rendering_visibility_distance_test_func(
        visibility,
        distance,
        U32.from_nat(220n),
        U32.from_nat(256n)
      )

assert rendering_triangle_interop_test_func:
  forall marker: U32
  Bool

def rendering_triangle_interop_test_func(marker):
  match Raytrace.raytrace_scene_sample_func(
    Raytrace.raytrace_reference_triangle_query_func(True{}),
    Con{
      Raytrace.TrianglePrimitive{
        Raytrace.raytrace_reference_triangle_func(marker)
      },
      Nil{}
    }
  ):
    case Raytrace.TraceSample{visibility, distance}:
      rendering_visibility_distance_test_func(
        visibility,
        distance,
        U32.from_nat(180n),
        U32.from_nat(512n)
      )

assert rendering_surface_func:
  forall marker: U32
  Light.SurfaceSample

def rendering_surface_func(marker):
  Light.SurfaceSample{
    Model3D.Vec3{
      Model3D.ScalarPos{0},
      Model3D.ScalarPos{0},
      Model3D.ScalarPos{0}
    },
    Model3D.Vec3{
      Model3D.ScalarPos{U32.from_nat(256n)},
      Model3D.ScalarPos{0},
      Model3D.ScalarPos{0}
    },
    Model3D.Vec3{
      Model3D.ScalarNeg{U32.from_nat(256n)},
      Model3D.ScalarPos{0},
      Model3D.ScalarPos{0}
    },
    Model3D.Color{
      U32.from_nat(180n),
      U32.from_nat(80n),
      U32.from_nat(60n)
    },
    U32.from_nat(64n),
    U32.from_nat(32n),
    U32.from_nat(80n),
    U32.from_nat(10n)
  }

assert rendering_shading_test_func:
  forall marker: U32
  Bool

def rendering_shading_test_func(marker):
  match Light.light_shade_directional_func(
    rendering_surface_func(marker),
    Model3D.Vec3{
      Model3D.ScalarPos{U32.from_nat(256n)},
      Model3D.ScalarPos{0},
      Model3D.ScalarPos{0}
    },
    Model3D.Color{
      U32.from_nat(255n),
      U32.from_nat(240n),
      U32.from_nat(220n)
    },
    U32.from_nat(200n),
    Light.ClearVisibility{},
    Light.NoFog{},
    U32.from_nat(512n)
  ):
    case Light.LightingSample{color, diffuse, specular, reflection, fuzz, shadowed}:
      Bool.and(
        U32.is_eq(diffuse, U32.from_nat(200n)),
        Bool.and(
          U32.is_eq(reflection, U32.from_nat(80n)),
          Bool.and(
            U32.is_eq(fuzz, U32.from_nat(10n)),
            Bool.not(shadowed)
          )
        )
      )

assert rendering_ambient_test_func:
  forall marker: U32
  Bool

def rendering_ambient_test_func(marker):
  match Light.light_shade_func(
    Light.AmbientLight{
      Model3D.Color{
        U32.from_nat(255n), U32.from_nat(240n), U32.from_nat(220n)
      },
      U32.from_nat(100n)
    },
    rendering_surface_func(marker),
    Light.OccludedVisibility{U32.from_nat(255n)},
    Light.NoFog{},
    U32.from_nat(500n)
  ):
    case Light.LightingSample{color, diffuse, specular, reflection, fuzz, shadowed}:
      Bool.and(
        U32.is_eq(diffuse, U32.from_nat(100n)),
        Bool.and(U32.is_eq(specular, 0), Bool.not(shadowed))
      )

assert rendering_point_test_func:
  forall marker: U32
  Bool

def rendering_point_test_func(marker):
  match Light.light_shade_func(
    Light.PointLight{
      Model3D.Vec3{
        Model3D.ScalarPos{U32.from_nat(256n)},
        Model3D.ScalarPos{0},
        Model3D.ScalarPos{0}
      },
      Model3D.Color{
        U32.from_nat(255n), U32.from_nat(255n), U32.from_nat(255n)
      },
      U32.from_nat(255n),
      U32.from_nat(256n)
    },
    rendering_surface_func(marker),
    Light.ClearVisibility{},
    Light.NoFog{},
    U32.from_nat(128n)
  ):
    case Light.LightingSample{color, diffuse, specular, reflection, fuzz, shadowed}:
      U32.is_eq(diffuse, U32.from_nat(127n))

assert rendering_spot_test_func:
  forall marker: U32
  Bool

def rendering_spot_test_func(marker):
  match Light.light_shade_func(
    Light.SpotLight{
      Model3D.Vec3{
        Model3D.ScalarPos{U32.from_nat(256n)},
        Model3D.ScalarPos{0},
        Model3D.ScalarPos{0}
      },
      Model3D.Vec3{
        Model3D.ScalarNeg{U32.from_nat(256n)},
        Model3D.ScalarPos{0},
        Model3D.ScalarPos{0}
      },
      Model3D.Color{
        U32.from_nat(255n), U32.from_nat(255n), U32.from_nat(255n)
      },
      U32.from_nat(255n),
      U32.from_nat(256n),
      U32.from_nat(200n),
      U32.from_nat(32n)
    },
    rendering_surface_func(marker),
    Light.ClearVisibility{},
    Light.NoFog{},
    U32.from_nat(64n)
  ):
    case Light.LightingSample{color, diffuse, specular, reflection, fuzz, shadowed}:
      U32.is_eq(diffuse, U32.from_nat(191n))

assert rendering_rig_test_func:
  forall marker: U32
  Bool

def rendering_rig_test_func(marker):
  match Light.light_rig_shade_func(
    Light.LightRig{
      Con{
        Light.ResolvedLight{
          Light.AmbientLight{
            Model3D.Color{
              U32.from_nat(255n), U32.from_nat(240n), U32.from_nat(220n)
            },
            U32.from_nat(48n)
          },
          Light.ClearVisibility{},
          0
        },
        Con{
          Light.ResolvedLight{
            Light.PointLight{
              Model3D.Vec3{
                Model3D.ScalarPos{U32.from_nat(256n)},
                Model3D.ScalarPos{0},
                Model3D.ScalarPos{0}
              },
              Model3D.Color{
                U32.from_nat(255n), U32.from_nat(220n), U32.from_nat(180n)
              },
              U32.from_nat(200n),
              U32.from_nat(512n)
            },
            Light.ClearVisibility{},
            U32.from_nat(128n)
          },
          Nil{}
        }
      },
      Model3D.Color{U32.from_nat(4n), U32.from_nat(5n), U32.from_nat(8n)},
      Light.LinearFog{
        Model3D.Color{U32.from_nat(80n), U32.from_nat(90n), U32.from_nat(110n)},
        U32.from_nat(512n),
        U32.from_nat(2048n)
      },
      Light.ShadowControl{
        U32.from_nat(1n), U32.from_nat(220n), U32.from_nat(32n), U32.from_nat(8n)
      }
    },
    rendering_surface_func(marker)
  ):
    case Model3D.Color{red, green, blue}:
      Bool.or(U32.is_ne(red, 0), U32.is_ne(green, 0))

# These Boolean calls retain no proof payload at runtime. Type-checking their
# erased arguments validates fourteen reusable library theorems, four semantic
# headline claims, and five closed certificates. The semantic claims quantify
# over arbitrary object/light lists, meshes, and positive reflection witnesses.
assert rendering_verification_test_func:
  forall marker: U32
  Bool

def rendering_verification_test_func(marker):
  Bool.and(
    Model3D.model3d_verification_func(),
    Bool.and(
      Light.light_verification_func(),
      Bool.and(
        Raytrace.raytrace_verification_func(),
        Verification.rendering_semantic_verification_func()
      )
    )
  )

assert main_value:
  Bool

def main_value():
  Bool.and(
    rendering_model_test_func(U32.from_nat(190n)),
    Bool.and(
      rendering_ray_light_interop_test_func(0),
      Bool.and(
        rendering_triangle_interop_test_func(0),
        Bool.and(
          rendering_shading_test_func(0),
          Bool.and(
            rendering_ambient_test_func(0),
            Bool.and(
              rendering_point_test_func(0),
              Bool.and(
                rendering_spot_test_func(0),
                Bool.and(
                  rendering_rig_test_func(0),
                  rendering_verification_test_func(0)
                )
              )
            )
          )
        )
      )
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
