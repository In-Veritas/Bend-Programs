import Base
import ./graphics3d.bend as Graphics

# Small backend-facing contract test for the standalone graphics module.

def fixed_arithmetic_test() -> Bool:
  Bool.and(
    Graphics.fixed_is_equal(
      Graphics.fixed_add(Graphics.fixed_from_nat(3n), Graphics.fixed_neg(Graphics.fixed_from_nat(1n))),
      Graphics.fixed_from_nat(2n)
    ),
    Bool.and(
      Graphics.fixed_is_equal(Graphics.fixed_from_raw(True{}, 0n), Graphics.fixed_zero()),
      Bool.and(
        Graphics.fixed_is_ge(Graphics.FixedMinus{U32.zero()}, Graphics.fixed_zero()),
        Graphics.fixed_is_equal(Graphics.fixed_from_q10(False{}, U32.from_nat(1024n)), Graphics.fixed_from_nat(1n))
      )
    )
  )

def farm_bounds_test() -> Bool:
  match Graphics.farm_tile_position(U32.from_nat(0n)) Graphics.farm_tile_position(U32.from_nat(23n)):
    case Graphics.Vec3{first_x, first_y, first_z} Graphics.Vec3{last_x, last_y, last_z}:
      Bool.and(
        Graphics.fixed_is_equal(first_x, Graphics.fixed_neg(Graphics.fixed_from_nat(3n))),
        Bool.and(
          Graphics.fixed_is_equal(first_z, Graphics.fixed_neg(Graphics.fixed_from_nat(7n))),
          Bool.and(
            Graphics.fixed_is_equal(last_x, Graphics.fixed_from_nat(3n)),
            Graphics.fixed_is_equal(last_z, Graphics.fixed_from_nat(7n))
          )
        )
      )

def projection_test() -> Bool:
  match Graphics.camera_project(Graphics.camera_default(), Graphics.farm_tile_position(U32.from_nat(0n))):
    case Graphics.ProjectedPoint{screen, depth, visible}:
      visible

def beet_test() -> Bool:
  match Graphics.beet_procedural(
    U32.from_nat(24n),
    Graphics.farm_tile_position(U32.from_nat(0n)),
    Graphics.fixed_from_nat(1n),
    Graphics.fixed_from_raw(False{}, 20n),
    Graphics.fixed_zero(),
    Graphics.fixed_from_raw(False{}, 64n),
    Graphics.fixed_from_raw(False{}, 32n),
    False{},
    U32.from_nat(77n),
    U32.from_nat(512n)
  ):
    case Graphics.RenderTile{geometry}:
      False{}
    case Graphics.RenderBeet{geometry}:
      True{}

# Merely referencing this fully erased value requires Core to validate every
# theorem in Graphics.GraphicsProofSuite; runtime backends retain only True{}.
def proof_suite_test(-proofs: Graphics.GraphicsProofSuite()) -> Bool:
  True{}

def main() -> Bool:
  Bool.and(
    fixed_arithmetic_test(),
    Bool.and(
      farm_bounds_test(),
      Bool.and(
        projection_test(),
        Bool.and(
          beet_test(),
          Bool.and(
            Nat.is_eq(List.length(Graphics.RenderPrimitive, Graphics.farm_grid()), 24n),
            proof_suite_test(Graphics.graphics_proof_suite())
          )
        )
      )
    )
  )
