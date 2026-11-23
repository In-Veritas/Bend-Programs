import ./physics.bend as Physics

# Types
# =====

type PhysicsVerification:
  PhysicsVerification{
    -scalar_negation_involutive:
      @value: Physics.Scalar -> {
        Physics.scalar_negate(Physics.scalar_negate(value)) == value
        : Physics.Scalar
      },
    -vector_negation_involutive:
      @value: Physics.Vec3 -> {
        Physics.vec3_negate(Physics.vec3_negate(value)) == value
        : Physics.Vec3
      },
    -clearing_loads_zeros_force:
      @body: Physics.RigidBody -> {
        Physics.rigid_body_force(Physics.rigid_body_clear_loads(body)) == Physics.vec3_zero_func()
        : Physics.Vec3
      },
    -clearing_articulation_preserves_body_count:
      @tree: Physics.Articulation -> {
        Physics.articulation_body_count(Physics.articulation_clear_loads(tree))
        == Physics.articulation_body_count(tree)
        : Nat
      },
    -joint_kind_copy_preserves_kind:
      @kind: Physics.JointKind -> {
        Physics.joint_kind_copy_right(Physics.joint_kind_copy_right(kind)) == kind
        : Physics.JointKind
      },
    -pinned_integration_is_invariant:
      @body: Physics.PinnedBody -> @gravity: Physics.Vec3 -> @dt: Physics.Scalar -> {
        Physics.pinned_body_integrate(body, gravity, dt) == body
        : Physics.PinnedBody
      },
    -pinned_history_is_invariant:
      @history: Physics.StepHistory -> @body: Physics.PinnedBody -> {
        Physics.pinned_body_steps_func(history, body) == body
        : Physics.PinnedBody
      },
    -integration_preserves_actual_shape:
      @tree: Physics.Articulation -> @gravity: Physics.Vec3 -> @dt: Physics.Scalar ->
      Physics.Claim<Physics.Articulation, output => {
        Physics.articulation_shape(output) == Physics.articulation_shape(tree)
        : Physics.ArticulationShape
      }>,
    -parent_constraint_preserves_actual_shape:
      @tree: Physics.Articulation -> @parent_pose: Physics.Pose ->
      Physics.Claim<Physics.Articulation, output => {
        Physics.articulation_shape(output) == Physics.articulation_shape(tree)
        : Physics.ArticulationShape
      }>,
    -constraint_iterations_preserve_actual_shape:
      @iterations: Nat -> @tree: Physics.Articulation ->
      Physics.Claim<Physics.Articulation, output => {
        Physics.articulation_shape(output) == Physics.articulation_shape(tree)
        : Physics.ArticulationShape
      }>,
    -ragdoll_step_preserves_actual_shape:
      @ragdoll: Physics.Ragdoll -> @dt: Physics.Scalar ->
      Physics.Claim<Physics.Ragdoll, output => {
        Physics.ragdoll_actual_shape(output) == Physics.ragdoll_actual_shape(ragdoll)
        : Physics.ArticulationShape
      }>,
    -ragdoll_history_preserves_actual_shape:
      @history: Physics.StepHistory -> @ragdoll: Physics.Ragdoll ->
      Physics.Claim<Physics.Ragdoll, output => {
        Physics.ragdoll_actual_shape(output) == Physics.ragdoll_actual_shape(ragdoll)
        : Physics.ArticulationShape
      }>,
    certified_scenarios: U32,
    general_theorems: U32
  }

# Constants
# =========

# Func-Section
# ============

assert physics_verification_func:
  PhysicsVerification

def physics_verification_func():
  PhysicsVerification{
    Physics.scalar_negation_involution_theorem,
    Physics.vec3_negation_involution_theorem,
    Physics.rigid_body_clear_loads_force_theorem,
    Physics.articulation_clear_loads_count_theorem,
    Physics.joint_kind_copy_preservation_theorem,
    Physics.pinned_body_integration_invariant_theorem,
    Physics.pinned_body_history_invariant_theorem_func,
    Physics.articulation_integrate_shape_claim_func,
    Physics.articulation_constrain_relative_shape_claim_func,
    Physics.constraint_iterations_shape_claim_func,
    Physics.ragdoll_step_shape_claim_func,
    Physics.ragdoll_steps_shape_claim_func,
    U32.from_nat(3n),
    U32.from_nat(12n)
  }

assert physics_self_check_func:
  Bool

def physics_self_check_func():
  Physics.physics_self_check_func()
