import Base
import ./graphics3d.bend as Graphics
import ../../compat/list.bend as List
import ../../compat/nat.bend as Nat

# Small backend-facing contract test for the standalone graphics module.

assert fixed_arithmetic_test:
  Bool

def fixed_arithmetic_test():
  Bool.and(
    Graphics.fixed_is_equal(
      Graphics.fixed_add(Graphics.fixed_from_nat(3n), Graphics.fixed_neg(Graphics.fixed_from_nat(1n))),
      Graphics.fixed_from_nat(2n)
    ),
    Bool.and(
      Graphics.fixed_is_equal(Graphics.fixed_from_raw(True{}, 0n), Graphics.fixed_zero()),
      Bool.and(
        Graphics.fixed_is_ge(Graphics.FixedMinus{0}, Graphics.fixed_zero()),
        Graphics.fixed_is_equal(Graphics.fixed_from_q10(False{}, U32.from_nat(1024n)), Graphics.fixed_from_nat(1n))
      )
    )
  )

assert farm_bounds_test:
  Bool

def farm_bounds_test():
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

assert projection_test:
  Bool

def projection_test():
  match Graphics.camera_project(Graphics.camera_default(), Graphics.farm_tile_position(U32.from_nat(0n))):
    case Graphics.ProjectedPoint{screen, depth, visible}:
      visible

assert beet_test:
  Bool

def beet_test():
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

# Referencing this audit requires Core to validate the quantified theorem and
# all closed certificates; runtime backends retain only True{}.
assert verification_test:
  forall -audit: Graphics.GraphicsVerificationAudit
  Bool

def verification_test(audit):
  True{}

assert main_value:
  Bool

def main_value():
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
            verification_test(Graphics.graphics_verification())
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
