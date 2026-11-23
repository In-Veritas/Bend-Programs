import Base
import ./engine/light.bend as EngineLight
import ../../compat/list.bend as List

# Bend-a-Beet adapter for the reusable Bend Engine model and light libraries.
# The `engine` path is a repository symlink to the sibling `Bend Engine`
# package because Core import tokens cannot contain spaces. The imported files
# remain the single source of truth.

type PositiveChannel:
  PositiveChannel{excess: U32}

type MaterialSpec:
  MaterialSpec{
    texture_kind: U32,
    texture_seed: U32,
    roughness: U32,
    metallic: U32,
    reflection: PositiveChannel,
    fuzz: U32,
    fur_length: U32,
    fur_density: PositiveChannel
  }

type EngineInput:
  EngineInput{
    object_id: U32,
    shine: U32,
    fiber: U32,
    magic: U32,
    height: U32,
    shadowed: Bool
  }

type EngineAppearance:
  EngineAppearance{
    color: Model3D.Color,
    material: MaterialSpec,
    shadow_softness: U32,
    shadow_samples: U32,
    fog_amount: U32
  }

type EngineProfile:
  EngineProfile{object_id: U32, appearance: EngineAppearance}

assert engine_u32_func:
  forall value: Nat
  U32

def engine_u32_func(value):
  U32.from_nat(value)

assert engine_u32_pair_func:
  forall value: U32
  U32 & U32

def engine_u32_pair_func(value):
  ((left, left_exact), (right, right_exact)) = U32.copy(value)
  (left, right)

assert engine_u32_four_func:
  forall value: U32
  U32 & (U32 & (U32 & U32))

def engine_u32_four_func(value):
  (first, rest) = engine_u32_pair_func(value)
  (second, tail) = engine_u32_pair_func(rest)
  (third, fourth) = engine_u32_pair_func(tail)
  (first, (second, (third, fourth)))

assert engine_positive_value_func:
  forall value: PositiveChannel
  U32

def engine_positive_value_func(value):
  match value:
    case PositiveChannel{excess}:
      U32.inc(excess)

assert engine_positive_copy_func:
  forall value: PositiveChannel
  PositiveChannel & PositiveChannel

def engine_positive_copy_func(value):
  match value:
    case PositiveChannel{excess}:
      (left, right) = engine_u32_pair_func(excess)
      (PositiveChannel{left}, PositiveChannel{right})

assert engine_material_spec_copy_func:
  forall value: MaterialSpec
  MaterialSpec & MaterialSpec

def engine_material_spec_copy_func(value):
  match value:
    case MaterialSpec{texture_kind, texture_seed, roughness, metallic, reflection, fuzz, fur_length, fur_density}:
      (kind_left, kind_right) = engine_u32_pair_func(texture_kind)
      (seed_left, seed_right) = engine_u32_pair_func(texture_seed)
      (rough_left, rough_right) = engine_u32_pair_func(roughness)
      (metal_left, metal_right) = engine_u32_pair_func(metallic)
      (reflection_left, reflection_right) = engine_positive_copy_func(reflection)
      (fuzz_left, fuzz_right) = engine_u32_pair_func(fuzz)
      (length_left, length_right) = engine_u32_pair_func(fur_length)
      (density_left, density_right) = engine_positive_copy_func(fur_density)
      (
        MaterialSpec{
          kind_left, seed_left, rough_left, metal_left, reflection_left,
          fuzz_left, length_left, density_left
        },
        MaterialSpec{
          kind_right, seed_right, rough_right, metal_right, reflection_right,
          fuzz_right, length_right, density_right
        }
      )

assert engine_material_spec_func:
  forall seed: U32
  forall shine: U32
  forall fiber: U32
  forall magic: U32
  MaterialSpec

def engine_material_spec_func(seed, shine, fiber, magic):
  match engine_u32_pair_func(seed) engine_u32_four_func(shine) engine_u32_pair_func(fiber) engine_u32_pair_func(magic):
    case (kind_seed, texture_seed)
         (rough_shine, (metal_shine, (reflection_shine, fuzz_shine)))
         (fuzz_fiber, length_fiber)
         (metal_magic, density_magic):
      MaterialSpec{
        U32.and(kind_seed, engine_u32_func(3n)),
        texture_seed,
        U32.sub(
          engine_u32_func(255n),
          EngineLight.light_channel_clamp_func(U32.div(rough_shine, engine_u32_func(4n)))
        ),
        EngineLight.light_channel_clamp_func(
          U32.add(
            U32.div(metal_shine, engine_u32_func(12n)),
            U32.div(metal_magic, engine_u32_func(8n))
          )
        ),
        PositiveChannel{
          U32.add(
            engine_u32_func(79n),
            U32.mod(reflection_shine, engine_u32_func(96n))
          )
        },
        U32.add(
          engine_u32_func(16n),
          U32.mod(U32.add(fuzz_shine, fuzz_fiber), engine_u32_func(80n))
        ),
        U32.add(
          engine_u32_func(20n),
          U32.mod(length_fiber, engine_u32_func(48n))
        ),
        PositiveChannel{
          U32.add(
            engine_u32_func(23n),
            U32.mod(density_magic, engine_u32_func(64n))
          )
        }
      }

assert engine_texture_func:
  forall kind: U32
  forall seed: U32
  Model3D.Texture

def engine_texture_func(kind, seed):
  match U32.to_nat(kind):
    case 0n:
      Model3D.SolidTexture{
        Model3D.Color{
          engine_u32_func(142n), engine_u32_func(30n), engine_u32_func(91n)
        }
      }
    case 1n+rest1:
      match rest1:
        case 0n:
          Model3D.CheckerTexture{
            Model3D.Color{
              engine_u32_func(116n), engine_u32_func(24n), engine_u32_func(72n)
            },
            Model3D.Color{
              engine_u32_func(190n), engine_u32_func(52n), engine_u32_func(112n)
            },
            engine_u32_func(32n)
          }
        case 1n+rest2:
          match rest2:
            case 0n:
              Model3D.FacetTexture{
                Model3D.Color{
                  engine_u32_func(105n), engine_u32_func(20n), engine_u32_func(61n)
                },
                Model3D.Color{
                  engine_u32_func(214n), engine_u32_func(63n), engine_u32_func(122n)
                },
                engine_u32_func(3n)
              }
            case 1n+rest3:
              Model3D.NoiseTexture{
                Model3D.Color{
                  engine_u32_func(116n), engine_u32_func(24n), engine_u32_func(46n)
                },
                Model3D.Color{
                  engine_u32_func(205n), engine_u32_func(52n), engine_u32_func(93n)
                },
                seed,
                engine_u32_func(29n)
              }

assert engine_material_func:
  forall spec: MaterialSpec
  Model3D.Material

def engine_material_func(spec):
  match spec:
    case MaterialSpec{texture_kind, texture_seed, roughness, metallic, reflection, fuzz, fur_length, fur_density}:
      Model3D.Material{
        engine_texture_func(texture_kind, texture_seed),
        roughness,
        metallic,
        engine_positive_value_func(reflection),
        fuzz,
        fur_length,
        engine_positive_value_func(fur_density)
      }

assert engine_surface_func:
  forall spec: MaterialSpec
  forall object_id: U32
  forall height: U32
  EngineLight.SurfaceSample

def engine_surface_func(spec, object_id, height):
  match engine_u32_four_func(object_id) engine_u32_pair_func(height):
    case (point_x, (point_z, (uv_seed, facet_id))) (point_y, distance_y):
      x = U32.mul(U32.mod(point_x, engine_u32_func(3n)), engine_u32_func(256n))
      z = U32.mul(U32.div(point_z, engine_u32_func(3n)), engine_u32_func(128n))
      EngineLight.light_surface_from_material_func(
        engine_material_func(spec),
        Model3D.Vec3{
          Model3D.ScalarPos{x}, Model3D.ScalarPos{point_y}, Model3D.ScalarPos{z}
        },
        Model3D.Vec3{
          Model3D.ScalarPos{engine_u32_func(32n)},
          Model3D.ScalarPos{engine_u32_func(250n)},
          Model3D.ScalarPos{engine_u32_func(48n)}
        },
        Model3D.Vec3{
          Model3D.ScalarPos{engine_u32_func(32n)},
          Model3D.ScalarPos{engine_u32_func(181n)},
          Model3D.ScalarNeg{engine_u32_func(181n)}
        },
        Model3D.Vec2{
          Model3D.ScalarPos{U32.mul(uv_seed, engine_u32_func(17n))},
          Model3D.ScalarPos{distance_y}
        },
        facet_id
      )

assert engine_visibility_func:
  forall shadowed: Bool
  EngineLight.Visibility

def engine_visibility_func(shadowed):
  match shadowed:
    case False{}:
      EngineLight.ClearVisibility{}
    case True{}:
      EngineLight.OccludedVisibility{engine_u32_func(176n)}

assert engine_light_rig_func:
  forall visibility: EngineLight.Visibility
  EngineLight.LightRig

def engine_light_rig_func(visibility):
  EngineLight.LightRig{
    Con{
      EngineLight.ResolvedLight{
        EngineLight.AmbientLight{
          Model3D.Color{
            engine_u32_func(120n), engine_u32_func(145n), engine_u32_func(176n)
          },
          engine_u32_func(44n)
        },
        EngineLight.ClearVisibility{},
        0
      },
      Con{
        EngineLight.ResolvedLight{
          EngineLight.DirectionalLight{
            Model3D.Vec3{
              Model3D.ScalarPos{engine_u32_func(181n)},
              Model3D.ScalarPos{engine_u32_func(181n)},
              Model3D.ScalarPos{engine_u32_func(64n)}
            },
            Model3D.Color{
              engine_u32_func(255n), engine_u32_func(232n), engine_u32_func(188n)
            },
            engine_u32_func(196n)
          },
          visibility,
          engine_u32_func(320n)
        },
        Con{
          EngineLight.ResolvedLight{
            EngineLight.PointLight{
              Model3D.Vec3{
                Model3D.ScalarNeg{engine_u32_func(768n)},
                Model3D.ScalarPos{engine_u32_func(1280n)},
                Model3D.ScalarNeg{engine_u32_func(512n)}
              },
              Model3D.Color{
                engine_u32_func(255n), engine_u32_func(92n), engine_u32_func(156n)
              },
              engine_u32_func(150n),
              engine_u32_func(4096n)
            },
            EngineLight.ClearVisibility{},
            engine_u32_func(512n)
          },
          Con{
            EngineLight.ResolvedLight{
              EngineLight.SpotLight{
                Model3D.Vec3{
                  Model3D.ScalarPos{engine_u32_func(1024n)},
                  Model3D.ScalarPos{engine_u32_func(1536n)},
                  Model3D.ScalarPos{engine_u32_func(512n)}
                },
                Model3D.Vec3{
                  Model3D.ScalarNeg{engine_u32_func(96n)},
                  Model3D.ScalarNeg{engine_u32_func(221n)},
                  Model3D.ScalarNeg{engine_u32_func(64n)}
                },
                Model3D.Color{
                  engine_u32_func(96n), engine_u32_func(164n), engine_u32_func(255n)
                },
                engine_u32_func(172n),
                engine_u32_func(4096n),
                engine_u32_func(176n),
                engine_u32_func(52n)
              },
              EngineLight.ClearVisibility{},
              engine_u32_func(640n)
            },
            Nil{}
          }
        }
      }
    },
    Model3D.Color{
      engine_u32_func(5n), engine_u32_func(8n), engine_u32_func(13n)
    },
    EngineLight.LinearFog{
      Model3D.Color{
        engine_u32_func(94n), engine_u32_func(139n), engine_u32_func(157n)
      },
      engine_u32_func(512n),
      engine_u32_func(3072n)
    },
    EngineLight.ShadowControl{
      engine_u32_func(2n), engine_u32_func(214n),
      engine_u32_func(42n), engine_u32_func(8n)
    }
  }

assert engine_appearance_finish_func:
  forall shade_spec: MaterialSpec
  forall report_spec: MaterialSpec
  forall object_id: U32
  forall height: U32
  forall shadowed: Bool
  EngineAppearance

def engine_appearance_finish_func(shade_spec, report_spec, object_id, height, shadowed):
  match engine_u32_pair_func(height):
    case (surface_height, fog_height):
      EngineAppearance{
        EngineLight.light_rig_shade_func(
          engine_light_rig_func(engine_visibility_func(shadowed)),
          engine_surface_func(shade_spec, object_id, surface_height)
        ),
        report_spec,
        engine_u32_func(42n),
        engine_u32_func(8n),
        EngineLight.light_channel_clamp_func(U32.div(fog_height, engine_u32_func(8n)))
      }

assert engine_appearance_func:
  forall input: EngineInput
  EngineAppearance

def engine_appearance_func(input):
  match input:
    case EngineInput{object_id, shine, fiber, magic, height, shadowed}:
      (material_id, surface_id) = engine_u32_pair_func(object_id)
      (shade_spec, report_spec) = engine_material_spec_copy_func(
        engine_material_spec_func(material_id, shine, fiber, magic)
      )
      engine_appearance_finish_func(
        shade_spec, report_spec, surface_id, height, shadowed
      )

assert engine_profile_func:
  forall input: EngineInput
  EngineProfile

def engine_profile_func(input):
  match input:
    case EngineInput{object_id, shine, fiber, magic, height, shadowed}:
      (report_id, appearance_id) = engine_u32_pair_func(object_id)
      EngineProfile{
        report_id,
        engine_appearance_func(
          EngineInput{appearance_id, shine, fiber, magic, height, shadowed}
        )
      }

assert engine_profiles_func:
  forall inputs: List<EngineInput>
  List<EngineProfile>

def engine_profiles_func(inputs):
  match inputs:
    case Nil{}:
      Nil{}
    case Con{input, tail}:
      Con{engine_profile_func(input), engine_profiles_func(tail)}

# Exact relational alignment is stronger than output cardinality alone: every
# output position is definitionally the profile of the corresponding input.
assert EngineProfilesContract:
  forall inputs: List<EngineInput>
  forall profiles: List<EngineProfile>
  Type

def EngineProfilesContract(inputs, profiles):
  match inputs profiles:
    case Nil{} Nil{}:
      Unit
    case Nil{} Con{profile, profile_tail}:
      Empty
    case Con{input, input_tail} Nil{}:
      Empty
    case Con{input, input_tail} Con{profile, profile_tail}:
      {profile == engine_profile_func(input) : EngineProfile}
      & EngineProfilesContract(input_tail, profile_tail)

assert engine_profiles_contract_theorem_func:
  forall inputs: List<EngineInput>
  EngineProfilesContract(inputs, engine_profiles_func(inputs))

def engine_profiles_contract_theorem_func(inputs):
  match inputs:
    case Nil{}:
      Unit{}
    case Con{input, tail}:
      ({==}, engine_profiles_contract_theorem_func(tail))

assert engine_profiles_count_theorem_func:
  forall inputs: List<EngineInput>
  { List.length(EngineProfile, engine_profiles_func(inputs)) == List.length(EngineInput, inputs) : Nat }

def engine_profiles_count_theorem_func(inputs):
  match inputs:
    case Nil{}:
      {==}
    case Con{input, tail}:
      %engine_profiles_count_theorem_func(tail) : {
        1n+List.length(EngineProfile, engine_profiles_func(tail)) == 1n+_
        : Nat
      }
      {==}

assert EngineProfilesContractClaim_func:
  Type

def EngineProfilesContractClaim_func():
  @inputs: List<EngineInput> ->
  EngineProfilesContract(inputs, engine_profiles_func(inputs))

assert EngineProfilesCountClaim_func:
  Type

def EngineProfilesCountClaim_func():
  @inputs: List<EngineInput> -> {
    List.length(EngineProfile, engine_profiles_func(inputs))
    == List.length(EngineInput, inputs)
    : Nat
  }
