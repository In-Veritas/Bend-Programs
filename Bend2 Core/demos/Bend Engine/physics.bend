import Base
import ../../compat/nat.bend as Nat

# Bend Engine deterministic rigid-body and ragdoll physics.
#
# Values use signed-magnitude Q10 fixed point: 1024 represents 1.0. The module
# is pure, strict-affine, and structurally recursive. It supplies force and
# torque accumulation, semi-implicit Euler
# integration, static contact response, symmetric two-body joint projection,
# and recursive articulated/ragdoll stepping.
#
# The verification audit keeps universally quantified mathematical theorems
# erased. Closed scenarios are called certificates and are never counted as
# mathematical proofs.

# Types
# =====

type Scalar:
  ScalarPos{magnitude: U32}
  ScalarNeg{magnitude: U32}

type Vec3:
  Vec3{x: Scalar, y: Scalar, z: Scalar}

type Pose:
  Pose{position: Vec3, orientation: Vec3}

type RigidBody:
  RigidBody{
    pose: Pose,
    linear_velocity: Vec3,
    angular_velocity: Vec3,
    force: Vec3,
    torque: Vec3,
    inverse_mass: Scalar,
    inverse_inertia: Scalar,
    linear_damping: Scalar,
    angular_damping: Scalar,
    radius: Scalar,
    restitution: Scalar,
    friction: Scalar
  }

type Contact:
  Contact{
    normal: Vec3,
    penetration: Scalar,
    restitution: Scalar,
    friction: Scalar
  }

type ContactResolution:
  ContactResolution{
    normal_speed: Scalar,
    normal: Vec3,
    corrected_position: Vec3,
    orientation: Vec3,
    velocity: Vec3,
    angular_velocity: Vec3,
    force: Vec3,
    torque: Vec3,
    inverse_mass: Scalar,
    inverse_inertia: Scalar,
    linear_damping: Scalar,
    angular_damping: Scalar,
    radius: Scalar,
    body_restitution: Scalar,
    body_friction: Scalar,
    contact_restitution: Scalar,
    contact_friction: Scalar
  }

type JointKind:
  BallJoint{}
  HingeX{}
  HingeY{}
  HingeZ{}
  FixedJoint{}
  ConeTwist{}

type Joint:
  Joint{
    kind: JointKind,
    parent_anchor: Vec3,
    child_anchor: Vec3,
    stiffness: Scalar,
    damping: Scalar,
    angular_limit: Scalar
  }

type JointCorrection:
  JointCorrection{
    parent_linear: Vec3,
    child_linear: Vec3,
    parent_angular: Vec3,
    child_angular: Vec3
  }

type JointCopies:
  JointCopies{solve: Joint, keep: Joint}

type JointProjection:
  JointProjection{incoming: Joint, body: RigidBody}

# A first-child / next-sibling tree avoids mutual recursion. Every node stores
# the joint connecting it to its parent; a root's incoming joint is ignored.
type Articulation:
  ArticulationEnd{}
  ArticulationNode{
    incoming: Joint,
    body: RigidBody,
    first_child: Articulation,
    next_sibling: Articulation
  }

# Optional report metadata. Verification never trusts this field: all topology
# theorems derive ArticulationShape directly from the live dynamics root.
type RagdollTopology:
  RagdollTopology{body_count: Nat, joint_count: Nat, joint_signature: Nat}

type RagdollDynamics:
  RagdollDynamics{root: Articulation, gravity: Vec3, constraint_iterations: Nat}

type Ragdoll:
  Ragdoll{topology: RagdollTopology, dynamics: RagdollDynamics}

type StepHistory:
  StepHistoryEnd{}
  StepHistoryFrame{dt: Scalar, tail: StepHistory}

# Construction through PinnedBody is the explicit zero-inverse-mass
# hypothesis. Its integration function intentionally leaves all state fixed.
type PinnedBody:
  PinnedBody{body: RigidBody}

type ConstraintStep:
  ConstraintStep{
    incoming: Joint,
    body: RigidBody,
    child_parent: Pose,
    sibling_parent: Pose
  }

type IntegrationStep:
  IntegrationStep{
    body: RigidBody,
    child_gravity: Vec3,
    sibling_gravity: Vec3,
    child_dt: Scalar,
    sibling_dt: Scalar
  }

type RagdollStepResources:
  RagdollStepResources{
    gravity_step: Vec3,
    gravity_keep: Vec3,
    iterations_step: Nat,
    iterations_keep: Nat
  }

type JointShape:
  BallShape{}
  HingeXShape{}
  HingeYShape{}
  HingeZShape{}
  FixedShape{}
  ConeTwistShape{}

type ArticulationShape:
  ShapeEnd{}
  ShapeNode{
    # Joint kind plus first-child/next-sibling constructors is the actual
    # articulated joint topology; numeric poses and material values are ignored.
    joint: JointShape,
    first_child: ArticulationShape,
    next_sibling: ArticulationShape
  }

type Claim<-A: Type, -Property: @-value: A -> Type>:
  Claim{value: A, -proof: Property(value)}

# Constants
# =========

assert u32_func:
  forall value: Nat
  U32

def u32_func(value):
  U32.from_nat(value)

assert scalar_zero_func:
  Scalar

def scalar_zero_func():
  ScalarPos{u32_func(0n)}

assert scalar_one_func:
  Scalar

def scalar_one_func():
  ScalarPos{u32_func(1024n)}

assert vec3_zero_func:
  Vec3

def vec3_zero_func():
  Vec3{scalar_zero_func(), scalar_zero_func(), scalar_zero_func()}

assert pose_origin_func:
  Pose

def pose_origin_func():
  Pose{vec3_zero_func(), vec3_zero_func()}

assert empty_joint_func:
  Joint

def empty_joint_func():
  Joint{
    FixedJoint{},
    vec3_zero_func(),
    vec3_zero_func(),
    scalar_one_func(),
    scalar_zero_func(),
    scalar_zero_func()
  }

# U32-Section
# ===========

assert u32_pair:
  forall value: U32
  U32 & U32

def u32_pair(value):
  ((left, left_exact), (right, right_exact)) = U32.copy(value)
  (left, right)

assert u32_saturating_sub:
  forall value: U32
  forall subtrahend: U32
  U32

def u32_saturating_sub(value, subtrahend):
  (test_value, keep_value) = u32_pair(value)
  (test_subtrahend, keep_subtrahend) = u32_pair(subtrahend)
  match U32.is_le(test_value, test_subtrahend):
    case True{}:
      u32_func(0n)
    case False{}:
      U32.sub(keep_value, keep_subtrahend)

# Scalar-Section
# ==============

assert scalar_copy:
  forall value: Scalar
  Scalar & Scalar

def scalar_copy(value):
  match value:
    case ScalarPos{magnitude}:
      (left, right) = u32_pair(magnitude)
      (ScalarPos{left}, ScalarPos{right})
    case ScalarNeg{magnitude}:
      (left, right) = u32_pair(magnitude)
      (ScalarNeg{left}, ScalarNeg{right})

assert scalar_triple:
  forall value: Scalar
  Scalar & (Scalar & Scalar)

def scalar_triple(value):
  (first, rest) = scalar_copy(value)
  (second, third) = scalar_copy(rest)
  (first, (second, third))

assert scalar_negate:
  forall value: Scalar
  Scalar

def scalar_negate(value):
  match value:
    case ScalarPos{magnitude}:
      ScalarNeg{magnitude}
    case ScalarNeg{magnitude}:
      ScalarPos{magnitude}

assert scalar_difference:
  forall value: Scalar
  forall negative: U32
  Scalar

def scalar_difference(value, negative):
  match value:
    case ScalarPos{positive}:
      (positive_test, positive_keep) = u32_pair(positive)
      (negative_test, negative_keep) = u32_pair(negative)
      match U32.cmp(positive_test, negative_test):
        case LT{}:
          ScalarNeg{U32.sub(negative_keep, positive_keep)}
        case EQ{}:
          scalar_zero_func()
        case GT{}:
          ScalarPos{U32.sub(positive_keep, negative_keep)}
    case ScalarNeg{extra_negative}:
      ScalarNeg{U32.add(extra_negative, negative)}

assert scalar_add:
  forall value: Scalar
  forall right: Scalar
  Scalar

def scalar_add(value, right):
  match value right:
    case ScalarPos{left_positive} ScalarPos{right_positive}:
      ScalarPos{U32.add(left_positive, right_positive)}
    case ScalarPos{left_positive} ScalarNeg{right_negative}:
      scalar_difference(ScalarPos{left_positive}, right_negative)
    case ScalarNeg{left_negative} ScalarPos{right_positive}:
      scalar_difference(ScalarPos{right_positive}, left_negative)
    case ScalarNeg{left_negative} ScalarNeg{right_negative}:
      ScalarNeg{U32.add(left_negative, right_negative)}

assert scalar_sub:
  forall value: Scalar
  forall right: Scalar
  Scalar

def scalar_sub(value, right):
  scalar_add(value, scalar_negate(right))

# Q10 multiplication. U32.div is backend-intrinsified by Core.
assert scalar_mul:
  forall value: Scalar
  forall right: Scalar
  Scalar

def scalar_mul(value, right):
  match value right:
    case ScalarPos{left_magnitude} ScalarPos{right_magnitude}:
      ScalarPos{U32.div(U32.mul(left_magnitude, right_magnitude), u32_func(1024n))}
    case ScalarPos{left_magnitude} ScalarNeg{right_magnitude}:
      ScalarNeg{U32.div(U32.mul(left_magnitude, right_magnitude), u32_func(1024n))}
    case ScalarNeg{left_magnitude} ScalarPos{right_magnitude}:
      ScalarNeg{U32.div(U32.mul(left_magnitude, right_magnitude), u32_func(1024n))}
    case ScalarNeg{left_magnitude} ScalarNeg{right_magnitude}:
      ScalarPos{U32.div(U32.mul(left_magnitude, right_magnitude), u32_func(1024n))}

assert scalar_clamp_magnitude:
  forall value: Scalar
  forall limit: Scalar
  Scalar

def scalar_clamp_magnitude(value, limit):
  match value limit:
    case ScalarPos{magnitude} ScalarNeg{ignored_limit}:
      scalar_zero_func()
    case ScalarNeg{magnitude} ScalarNeg{ignored_limit}:
      scalar_zero_func()
    case ScalarPos{magnitude} ScalarPos{maximum}:
      (test_magnitude, keep_magnitude) = u32_pair(magnitude)
      (test_maximum, keep_maximum) = u32_pair(maximum)
      match U32.is_gt(test_magnitude, test_maximum):
        case True{}:
          ScalarPos{keep_maximum}
        case False{}:
          ScalarPos{keep_magnitude}
    case ScalarNeg{magnitude} ScalarPos{maximum}:
      (test_magnitude, keep_magnitude) = u32_pair(magnitude)
      (test_maximum, keep_maximum) = u32_pair(maximum)
      match U32.is_gt(test_magnitude, test_maximum):
        case True{}:
          ScalarNeg{keep_maximum}
        case False{}:
          ScalarNeg{keep_magnitude}

# Mathematical theorem for every signed Q10 value, by constructor induction.
assert scalar_negation_involution_theorem:
  forall value: Scalar
  { scalar_negate(scalar_negate(value)) == value : Scalar }

def scalar_negation_involution_theorem(value):
  match value:
    case ScalarPos{magnitude}:
      {==}
    case ScalarNeg{magnitude}:
      {==}

# Vec3-Section
# ============

assert vec3_copy:
  forall value: Vec3
  Vec3 & Vec3

def vec3_copy(value):
  match value:
    case Vec3{x, y, z}:
      (x_left, x_right) = scalar_copy(x)
      (y_left, y_right) = scalar_copy(y)
      (z_left, z_right) = scalar_copy(z)
      (Vec3{x_left, y_left, z_left}, Vec3{x_right, y_right, z_right})

assert vec3_triple:
  forall value: Vec3
  Vec3 & (Vec3 & Vec3)

def vec3_triple(value):
  (first, rest) = vec3_copy(value)
  (second, third) = vec3_copy(rest)
  (first, (second, third))

assert vec3_negate:
  forall value: Vec3
  Vec3

def vec3_negate(value):
  match value:
    case Vec3{x, y, z}:
      Vec3{scalar_negate(x), scalar_negate(y), scalar_negate(z)}

assert vec3_add:
  forall value: Vec3
  forall right: Vec3
  Vec3

def vec3_add(value, right):
  match value right:
    case Vec3{left_x, left_y, left_z} Vec3{right_x, right_y, right_z}:
      Vec3{
        scalar_add(left_x, right_x),
        scalar_add(left_y, right_y),
        scalar_add(left_z, right_z)
      }

assert vec3_sub:
  forall value: Vec3
  forall right: Vec3
  Vec3

def vec3_sub(value, right):
  vec3_add(value, vec3_negate(right))

assert vec3_scale:
  forall value: Vec3
  forall scale: Scalar
  Vec3

def vec3_scale(value, scale):
  match value:
    case Vec3{x, y, z}:
      (scale_x, scale_rest) = scalar_copy(scale)
      (scale_y, scale_z) = scalar_copy(scale_rest)
      Vec3{scalar_mul(x, scale_x), scalar_mul(y, scale_y), scalar_mul(z, scale_z)}

assert vec3_dot:
  forall value: Vec3
  forall right: Vec3
  Scalar

def vec3_dot(value, right):
  match value right:
    case Vec3{left_x, left_y, left_z} Vec3{right_x, right_y, right_z}:
      scalar_add(
        scalar_mul(left_x, right_x),
        scalar_add(scalar_mul(left_y, right_y), scalar_mul(left_z, right_z))
      )

assert vec3_cross:
  forall value: Vec3
  forall right: Vec3
  Vec3

def vec3_cross(value, right):
  match value right:
    case Vec3{left_x, left_y, left_z} Vec3{right_x, right_y, right_z}:
      (left_x_a, left_x_b) = scalar_copy(left_x)
      (left_y_a, left_y_b) = scalar_copy(left_y)
      (left_z_a, left_z_b) = scalar_copy(left_z)
      (right_x_a, right_x_b) = scalar_copy(right_x)
      (right_y_a, right_y_b) = scalar_copy(right_y)
      (right_z_a, right_z_b) = scalar_copy(right_z)
      Vec3{
        scalar_sub(scalar_mul(left_y_a, right_z_a), scalar_mul(left_z_a, right_y_a)),
        scalar_sub(scalar_mul(left_z_b, right_x_a), scalar_mul(left_x_a, right_z_b)),
        scalar_sub(scalar_mul(left_x_b, right_y_b), scalar_mul(left_y_b, right_x_b))
      }

# Mathematical theorem for every vector. Constructor induction covers the
# eight sign combinations while all three U32 magnitudes remain arbitrary.
assert vec3_negation_involution_theorem:
  forall value: Vec3
  { vec3_negate(vec3_negate(value)) == value : Vec3 }

def vec3_negation_involution_theorem(value):
  match value:
    case Vec3{ScalarPos{x_magnitude}, ScalarPos{y_magnitude}, ScalarPos{z_magnitude}}:
      {==}
    case Vec3{ScalarPos{x_magnitude}, ScalarPos{y_magnitude}, ScalarNeg{z_magnitude}}:
      {==}
    case Vec3{ScalarPos{x_magnitude}, ScalarNeg{y_magnitude}, ScalarPos{z_magnitude}}:
      {==}
    case Vec3{ScalarPos{x_magnitude}, ScalarNeg{y_magnitude}, ScalarNeg{z_magnitude}}:
      {==}
    case Vec3{ScalarNeg{x_magnitude}, ScalarPos{y_magnitude}, ScalarPos{z_magnitude}}:
      {==}
    case Vec3{ScalarNeg{x_magnitude}, ScalarPos{y_magnitude}, ScalarNeg{z_magnitude}}:
      {==}
    case Vec3{ScalarNeg{x_magnitude}, ScalarNeg{y_magnitude}, ScalarPos{z_magnitude}}:
      {==}
    case Vec3{ScalarNeg{x_magnitude}, ScalarNeg{y_magnitude}, ScalarNeg{z_magnitude}}:
      {==}

# Pose-Section
# ============

assert pose_copy:
  forall value: Pose
  Pose & Pose

def pose_copy(value):
  match value:
    case Pose{position, orientation}:
      (position_left, position_right) = vec3_copy(position)
      (orientation_left, orientation_right) = vec3_copy(orientation)
      (Pose{position_left, orientation_left}, Pose{position_right, orientation_right})

assert pose_position:
  forall value: Pose
  Vec3

def pose_position(value):
  match value:
    case Pose{position, orientation}:
      position

assert pose_apply_correction:
  forall value: Pose
  forall linear: Vec3
  forall angular: Vec3
  Pose

def pose_apply_correction(value, linear, angular):
  match value:
    case Pose{position, orientation}:
      Pose{vec3_add(position, linear), vec3_add(orientation, angular)}

# RigidBody-Section
# =================

assert rigid_body_force:
  forall value: RigidBody
  Vec3

def rigid_body_force(value):
  match value:
    case RigidBody{pose, linear_velocity, angular_velocity, force, torque, inverse_mass, inverse_inertia, linear_damping, angular_damping, radius, restitution, friction}:
      force

assert rigid_body_pose:
  forall value: RigidBody
  Pose

def rigid_body_pose(value):
  match value:
    case RigidBody{pose, linear_velocity, angular_velocity, force, torque, inverse_mass, inverse_inertia, linear_damping, angular_damping, radius, restitution, friction}:
      pose

assert rigid_body_apply_force:
  forall value: RigidBody
  forall applied_force: Vec3
  RigidBody

def rigid_body_apply_force(value, applied_force):
  match value:
    case RigidBody{pose, linear_velocity, angular_velocity, force, torque, inverse_mass, inverse_inertia, linear_damping, angular_damping, radius, restitution, friction}:
      RigidBody{
        pose,
        linear_velocity,
        angular_velocity,
        vec3_add(force, applied_force),
        torque,
        inverse_mass,
        inverse_inertia,
        linear_damping,
        angular_damping,
        radius,
        restitution,
        friction
      }

assert rigid_body_apply_force_at:
  forall value: RigidBody
  forall point: Vec3
  forall applied_force: Vec3
  RigidBody

def rigid_body_apply_force_at(value, point, applied_force):
  match value point applied_force:
    case RigidBody{Pose{position, orientation}, linear_velocity, angular_velocity, force, torque, inverse_mass, inverse_inertia, linear_damping, angular_damping, radius, restitution, friction} Vec3{point_x, point_y, point_z} Vec3{applied_x, applied_y, applied_z}:
      (force_linear, force_torque) = vec3_copy(Vec3{applied_x, applied_y, applied_z})
      (position_relative, position_keep) = vec3_copy(position)
      RigidBody{
        Pose{position_keep, orientation},
        linear_velocity,
        angular_velocity,
        vec3_add(force, force_linear),
        vec3_add(torque, vec3_cross(vec3_sub(Vec3{point_x, point_y, point_z}, position_relative), force_torque)),
        inverse_mass,
        inverse_inertia,
        linear_damping,
        angular_damping,
        radius,
        restitution,
        friction
      }

assert rigid_body_clear_loads:
  forall value: RigidBody
  RigidBody

def rigid_body_clear_loads(value):
  match value:
    case RigidBody{pose, linear_velocity, angular_velocity, force, torque, inverse_mass, inverse_inertia, linear_damping, angular_damping, radius, restitution, friction}:
      RigidBody{
        pose,
        linear_velocity,
        angular_velocity,
        vec3_zero_func(),
        vec3_zero_func(),
        inverse_mass,
        inverse_inertia,
        linear_damping,
        angular_damping,
        radius,
        restitution,
        friction
      }

assert rigid_body_integrate:
  forall value: RigidBody
  forall gravity: Vec3
  forall dt: Scalar
  RigidBody

def rigid_body_integrate(value, gravity, dt):
  match value:
    case RigidBody{Pose{position, orientation}, linear_velocity, angular_velocity, force, torque, inverse_mass, inverse_inertia, linear_damping, angular_damping, radius, restitution, friction}:
      (inverse_mass_step, inverse_mass_keep) = scalar_copy(inverse_mass)
      (inverse_inertia_step, inverse_inertia_keep) = scalar_copy(inverse_inertia)
      (linear_damping_step, linear_damping_keep) = scalar_copy(linear_damping)
      (angular_damping_step, angular_damping_keep) = scalar_copy(angular_damping)
      (dt_linear_accel, dt_rest) = scalar_copy(dt)
      (dt_linear_pose, dt_rest_two) = scalar_copy(dt_rest)
      (dt_angular_accel, dt_angular_pose) = scalar_copy(dt_rest_two)
      (linear_next_for_pose, linear_next_for_body) = vec3_copy(
        vec3_scale(
          vec3_add(linear_velocity, vec3_scale(vec3_add(gravity, vec3_scale(force, inverse_mass_step)), dt_linear_accel)),
          linear_damping_step
        )
      )
      (angular_next_for_pose, angular_next_for_body) = vec3_copy(
        vec3_scale(
          vec3_add(angular_velocity, vec3_scale(vec3_scale(torque, inverse_inertia_step), dt_angular_accel)),
          angular_damping_step
        )
      )
      RigidBody{
        Pose{
          vec3_add(position, vec3_scale(linear_next_for_pose, dt_linear_pose)),
          vec3_add(orientation, vec3_scale(angular_next_for_pose, dt_angular_pose))
        },
        linear_next_for_body,
        angular_next_for_body,
        vec3_zero_func(),
        vec3_zero_func(),
        inverse_mass_keep,
        inverse_inertia_keep,
        linear_damping_keep,
        angular_damping_keep,
        radius,
        restitution,
        friction
      }

assert rigid_body_apply_correction:
  forall value: RigidBody
  forall linear: Vec3
  forall angular: Vec3
  RigidBody

def rigid_body_apply_correction(value, linear, angular):
  match value:
    case RigidBody{pose, linear_velocity, angular_velocity, force, torque, inverse_mass, inverse_inertia, linear_damping, angular_damping, radius, restitution, friction}:
      RigidBody{
        pose_apply_correction(pose, linear, angular),
        linear_velocity,
        angular_velocity,
        force,
        torque,
        inverse_mass,
        inverse_inertia,
        linear_damping,
        angular_damping,
        radius,
        restitution,
        friction
      }

# Universal theorem over arbitrary bodies. Matching exposes the body fields;
# force and torque values need not be enumerated.
assert rigid_body_clear_loads_force_theorem:
  forall value: RigidBody
  { rigid_body_force(rigid_body_clear_loads(value)) == vec3_zero_func() : Vec3 }

def rigid_body_clear_loads_force_theorem(value):
  match value:
    case RigidBody{pose, linear_velocity, angular_velocity, force, torque, inverse_mass, inverse_inertia, linear_damping, angular_damping, radius, restitution, friction}:
      {==}

# PinnedBody-Section
# ==================

assert pinned_body_integrate:
  forall value: PinnedBody
  forall gravity: Vec3
  forall dt: Scalar
  PinnedBody

def pinned_body_integrate(value, gravity, dt):
  value

assert pinned_body_integration_invariant_theorem:
  forall value: PinnedBody
  forall gravity: Vec3
  forall dt: Scalar
  { pinned_body_integrate(value, gravity, dt) == value : PinnedBody }

def pinned_body_integration_invariant_theorem(value, gravity, dt):
  {==}

# ContactResolution-Section
# =========================

assert contact_resolution_finish:
  forall value: ContactResolution
  RigidBody

def contact_resolution_finish(value):
  match value:
    case ContactResolution{ScalarPos{separating_speed}, normal, corrected_position, orientation, velocity, angular_velocity, force, torque, inverse_mass, inverse_inertia, linear_damping, angular_damping, radius, body_restitution, body_friction, contact_restitution, contact_friction}:
      RigidBody{
        Pose{corrected_position, orientation},
        velocity,
        angular_velocity,
        force,
        torque,
        inverse_mass,
        inverse_inertia,
        linear_damping,
        angular_damping,
        radius,
        body_restitution,
        body_friction
      }
    case ContactResolution{ScalarNeg{approach_speed}, normal, corrected_position, orientation, velocity, angular_velocity, force, torque, inverse_mass, inverse_inertia, linear_damping, angular_damping, radius, body_restitution, body_friction, contact_restitution, contact_friction}:
      (approach_tangent, approach_rebound) = u32_pair(approach_speed)
      (normal_rebound, normal_tangent) = vec3_copy(normal)
      (velocity_tangent, velocity_discard) = vec3_copy(velocity)
      tangent = vec3_sub(
        velocity_tangent,
        vec3_scale(normal_tangent, ScalarNeg{approach_tangent})
      )
      tangent_scale = scalar_sub(scalar_one_func(), contact_friction)
      rebound = vec3_scale(
        normal_rebound,
        scalar_mul(ScalarPos{approach_rebound}, contact_restitution)
      )
      RigidBody{
        Pose{corrected_position, orientation},
        vec3_add(rebound, vec3_scale(tangent, tangent_scale)),
        angular_velocity,
        force,
        torque,
        inverse_mass,
        inverse_inertia,
        linear_damping,
        angular_damping,
        radius,
        body_restitution,
        body_friction
      }

# Contact-Section
# ===============

# Resolves a body against a static surface. Approaching normal velocity is
# reflected by restitution while tangent velocity is attenuated by friction.
assert contact_resolve_static:
  forall value: Contact
  forall body: RigidBody
  RigidBody

def contact_resolve_static(value, body):
  match value:
    case Contact{normal, penetration, contact_restitution, contact_friction}:
      match body:
        case RigidBody{Pose{position, orientation}, linear_velocity, angular_velocity, force, torque, inverse_mass, inverse_inertia, linear_damping, angular_damping, radius, body_restitution, body_friction}:
          (normal_position, (normal_dot, normal_response)) = vec3_triple(normal)
          (velocity_dot, velocity_keep) = vec3_copy(linear_velocity)
          corrected_position = vec3_add(position, vec3_scale(normal_position, penetration))
          normal_speed = vec3_dot(velocity_dot, normal_dot)
          contact_resolution_finish(ContactResolution{
            normal_speed,
            normal_response,
            corrected_position,
            orientation,
            velocity_keep,
            angular_velocity,
            force,
            torque,
            inverse_mass,
            inverse_inertia,
            linear_damping,
            angular_damping,
            radius,
            body_restitution,
            body_friction,
            contact_restitution,
            contact_friction
          })

# JointKind-Section
# =================

assert joint_kind_copy:
  forall value: JointKind
  JointKind & JointKind

def joint_kind_copy(value):
  match value:
    case BallJoint{}:
      (BallJoint{}, BallJoint{})
    case HingeX{}:
      (HingeX{}, HingeX{})
    case HingeY{}:
      (HingeY{}, HingeY{})
    case HingeZ{}:
      (HingeZ{}, HingeZ{})
    case FixedJoint{}:
      (FixedJoint{}, FixedJoint{})
    case ConeTwist{}:
      (ConeTwist{}, ConeTwist{})

assert joint_kind_copy_right:
  forall value: JointKind
  JointKind

def joint_kind_copy_right(value):
  (left, right) = joint_kind_copy(value)
  right

assert joint_kind_copy_preservation_theorem:
  forall value: JointKind
  { joint_kind_copy_right(joint_kind_copy_right(value)) == value : JointKind }

def joint_kind_copy_preservation_theorem(value):
  match value:
    case BallJoint{}:
      {==}
    case HingeX{}:
      {==}
    case HingeY{}:
      {==}
    case HingeZ{}:
      {==}
    case FixedJoint{}:
      {==}
    case ConeTwist{}:
      {==}

assert joint_kind_shape:
  forall value: JointKind
  JointShape

def joint_kind_shape(value):
  match value:
    case BallJoint{}:
      BallShape{}
    case HingeX{}:
      HingeXShape{}
    case HingeY{}:
      HingeYShape{}
    case HingeZ{}:
      HingeZShape{}
    case FixedJoint{}:
      FixedShape{}
    case ConeTwist{}:
      ConeTwistShape{}

assert joint_kind_angular_error:
  forall value: JointKind
  forall relative_orientation: Vec3
  forall limit: Scalar
  Vec3

def joint_kind_angular_error(value, relative_orientation, limit):
  match value:
    case BallJoint{}:
      vec3_zero_func()
    case HingeX{}:
      match relative_orientation:
        case Vec3{x, y, z}:
          (limit_y, limit_z) = scalar_copy(limit)
          Vec3{scalar_zero_func(), scalar_clamp_magnitude(y, limit_y), scalar_clamp_magnitude(z, limit_z)}
    case HingeY{}:
      match relative_orientation:
        case Vec3{x, y, z}:
          (limit_x, limit_z) = scalar_copy(limit)
          Vec3{scalar_clamp_magnitude(x, limit_x), scalar_zero_func(), scalar_clamp_magnitude(z, limit_z)}
    case HingeZ{}:
      match relative_orientation:
        case Vec3{x, y, z}:
          (limit_x, limit_y) = scalar_copy(limit)
          Vec3{scalar_clamp_magnitude(x, limit_x), scalar_clamp_magnitude(y, limit_y), scalar_zero_func()}
    case FixedJoint{}:
      relative_orientation
    case ConeTwist{}:
      match relative_orientation:
        case Vec3{x, y, z}:
          (limit_x, limit_rest) = scalar_copy(limit)
          (limit_y, limit_z) = scalar_copy(limit_rest)
          Vec3{
            scalar_clamp_magnitude(x, limit_x),
            scalar_clamp_magnitude(y, limit_y),
            scalar_clamp_magnitude(z, limit_z)
          }

# Joint-Section
# =============

assert joint_correction:
  forall value: Joint
  forall parent_pose: Pose
  forall child_pose: Pose
  JointCorrection

def joint_correction(value, parent_pose, child_pose):
  match value:
    case Joint{kind, parent_anchor, child_anchor, stiffness, damping, angular_limit}:
      match parent_pose child_pose:
        case Pose{parent_position, parent_orientation} Pose{child_position, child_orientation}:
          (stiffness_linear, stiffness_angular) = scalar_copy(
            scalar_mul(stiffness, scalar_sub(scalar_one_func(), damping))
          )
          (parent_position_anchor, parent_position_keep) = vec3_copy(parent_position)
          (child_position_anchor, child_position_keep) = vec3_copy(child_position)
          (angular_parent_source, angular_child_source) = vec3_copy(
            vec3_scale(
              joint_kind_angular_error(
                kind,
                vec3_sub(child_orientation, parent_orientation),
                angular_limit
              ),
              stiffness_angular
            )
          )
          (linear_parent_source, linear_child_source) = vec3_copy(
            vec3_scale(
              vec3_sub(
                vec3_add(child_position_anchor, child_anchor),
                vec3_add(parent_position_anchor, parent_anchor)
              ),
              stiffness_linear
            )
          )
          JointCorrection{
            linear_parent_source,
            vec3_negate(linear_child_source),
            angular_parent_source,
            vec3_negate(angular_child_source)
          }

assert joint_solve_bodies:
  forall value: Joint
  forall parent: RigidBody
  forall child: RigidBody
  RigidBody & RigidBody

def joint_solve_bodies(value, parent, child):
  match parent child:
    case RigidBody{parent_pose, parent_linear_velocity, parent_angular_velocity, parent_force, parent_torque, parent_inverse_mass, parent_inverse_inertia, parent_linear_damping, parent_angular_damping, parent_radius, parent_restitution, parent_friction} RigidBody{child_pose, child_linear_velocity, child_angular_velocity, child_force, child_torque, child_inverse_mass, child_inverse_inertia, child_linear_damping, child_angular_damping, child_radius, child_restitution, child_friction}:
      (parent_pose_solve, parent_pose_keep) = pose_copy(parent_pose)
      (child_pose_solve, child_pose_keep) = pose_copy(child_pose)
      match joint_correction(value, parent_pose_solve, child_pose_solve):
        case JointCorrection{parent_linear, child_linear, parent_angular, child_angular}:
          (parent_mass_linear, parent_mass_keep) = scalar_copy(parent_inverse_mass)
          (child_mass_linear, child_mass_keep) = scalar_copy(child_inverse_mass)
          (parent_inertia_angular, parent_inertia_keep) = scalar_copy(parent_inverse_inertia)
          (child_inertia_angular, child_inertia_keep) = scalar_copy(child_inverse_inertia)
          (
            RigidBody{
              pose_apply_correction(
                parent_pose_keep,
                vec3_scale(parent_linear, parent_mass_linear),
                vec3_scale(parent_angular, parent_inertia_angular)
              ),
              parent_linear_velocity,
              parent_angular_velocity,
              parent_force,
              parent_torque,
              parent_mass_keep,
              parent_inertia_keep,
              parent_linear_damping,
              parent_angular_damping,
              parent_radius,
              parent_restitution,
              parent_friction
            },
            RigidBody{
              pose_apply_correction(
                child_pose_keep,
                vec3_scale(child_linear, child_mass_linear),
                vec3_scale(child_angular, child_inertia_angular)
              ),
              child_linear_velocity,
              child_angular_velocity,
              child_force,
              child_torque,
              child_mass_keep,
              child_inertia_keep,
              child_linear_damping,
              child_angular_damping,
              child_radius,
              child_restitution,
              child_friction
            }
          )

assert joint_copy:
  forall value: Joint
  Joint & Joint

def joint_copy(value):
  match value:
    case Joint{kind, parent_anchor, child_anchor, stiffness, damping, angular_limit}:
      (kind_left, kind_right) = joint_kind_copy(kind)
      (parent_left, parent_right) = vec3_copy(parent_anchor)
      (child_left, child_right) = vec3_copy(child_anchor)
      (stiffness_left, stiffness_right) = scalar_copy(stiffness)
      (damping_left, damping_right) = scalar_copy(damping)
      (limit_left, limit_right) = scalar_copy(angular_limit)
      (
        Joint{kind_left, parent_left, child_left, stiffness_left, damping_left, limit_left},
        Joint{kind_right, parent_right, child_right, stiffness_right, damping_right, limit_right}
      )

assert joint_shape:
  forall value: Joint
  JointShape

def joint_shape(value):
  match value:
    case Joint{kind, parent_anchor, child_anchor, stiffness, damping, angular_limit}:
      joint_kind_shape(kind)

# JointCopies-Section
# ===================

assert joint_copies_keep_shape:
  forall value: JointCopies
  JointShape

def joint_copies_keep_shape(value):
  match value:
    case JointCopies{solve, keep}:
      joint_shape(keep)

# JointProjection-Section
# =======================

assert joint_projection_shape:
  forall value: JointProjection
  JointShape

def joint_projection_shape(value):
  match value:
    case JointProjection{incoming, body}:
      joint_shape(incoming)

# Articulation-Section
# ====================

assert articulation_body_count:
  forall value: Articulation
  Nat

def articulation_body_count(value):
  match value:
    case ArticulationEnd{}:
      0n
    case ArticulationNode{incoming, body, first_child, next_sibling}:
      1n+Nat.add(articulation_body_count(first_child), articulation_body_count(next_sibling))

assert articulation_shape:
  forall value: Articulation
  ArticulationShape

def articulation_shape(value):
  match value:
    case ArticulationEnd{}:
      ShapeEnd{}
    case ArticulationNode{incoming, body, first_child, next_sibling}:
      ShapeNode{
        joint_shape(incoming),
        articulation_shape(first_child),
        articulation_shape(next_sibling)
      }

assert articulation_integrate:
  forall value: Articulation
  forall gravity: Vec3
  forall dt: Scalar
  Articulation

def articulation_integrate(value, gravity, dt):
  match value:
    case ArticulationEnd{}:
      ArticulationEnd{}
    case ArticulationNode{incoming, body, first_child, next_sibling}:
      (gravity_body, (gravity_child, gravity_sibling)) = vec3_triple(gravity)
      (dt_body, (dt_child, dt_sibling)) = scalar_triple(dt)
      ArticulationNode{
        incoming,
        rigid_body_integrate(body, gravity_body, dt_body),
        articulation_integrate(first_child, gravity_child, dt_child),
        articulation_integrate(next_sibling, gravity_sibling, dt_sibling)
      }

assert articulation_clear_loads:
  forall value: Articulation
  Articulation

def articulation_clear_loads(value):
  match value:
    case ArticulationEnd{}:
      ArticulationEnd{}
    case ArticulationNode{incoming, body, first_child, next_sibling}:
      ArticulationNode{
        incoming,
        rigid_body_clear_loads(body),
        articulation_clear_loads(first_child),
        articulation_clear_loads(next_sibling)
      }

# Structural theorem: clearing accumulated loads maps arbitrary articulation
# trees without adding or removing bodies. Both induction hypotheses are used.
assert articulation_clear_loads_count_theorem:
  forall value: Articulation
  { articulation_body_count(articulation_clear_loads(value)) == articulation_body_count(value) : Nat }

def articulation_clear_loads_count_theorem(value):
  match value:
    case ArticulationEnd{}:
      {==}
    case ArticulationNode{incoming, body, first_child, next_sibling}:
      Equal.trans(
        Nat,
        1n+Nat.add(
          articulation_body_count(articulation_clear_loads(first_child)),
          articulation_body_count(articulation_clear_loads(next_sibling))
        ),
        1n+Nat.add(
          articulation_body_count(first_child),
          articulation_body_count(articulation_clear_loads(next_sibling))
        ),
        1n+Nat.add(articulation_body_count(first_child), articulation_body_count(next_sibling)),
        Equal.cong(
          Nat,
          Nat,
          child_count => 1n+Nat.add(
            child_count,
            articulation_body_count(articulation_clear_loads(next_sibling))
          ),
          articulation_body_count(articulation_clear_loads(first_child)),
          articulation_body_count(first_child),
          articulation_clear_loads_count_theorem(first_child)
        ),
        Equal.cong(
          Nat,
          Nat,
          sibling_count => 1n+Nat.add(articulation_body_count(first_child), sibling_count),
          articulation_body_count(articulation_clear_loads(next_sibling)),
          articulation_body_count(next_sibling),
          articulation_clear_loads_count_theorem(next_sibling)
        )
      )

# Ragdoll-Section
# ===============

assert ragdoll_topology:
  forall value: Ragdoll
  RagdollTopology

def ragdoll_topology(value):
  match value:
    case Ragdoll{topology, dynamics}:
      topology

assert ragdoll_actual_shape:
  forall value: Ragdoll
  ArticulationShape

def ragdoll_actual_shape(value):
  match value:
    case Ragdoll{topology, RagdollDynamics{root, gravity, constraint_iterations}}:
      articulation_shape(root)

# ConstraintStep-Section
# ======================

assert constraint_step_shape:
  forall value: ConstraintStep
  JointShape

def constraint_step_shape(value):
  match value:
    case ConstraintStep{incoming, body, child_parent, sibling_parent}:
      joint_shape(incoming)

# Func-Section
# ============

assert rigid_body_pose_pair_func:
  forall body: RigidBody
  Pose & RigidBody

def rigid_body_pose_pair_func(body):
  match body:
    case RigidBody{pose, linear_velocity, angular_velocity, force, torque, inverse_mass, inverse_inertia, linear_damping, angular_damping, radius, restitution, friction}:
      (pose_read, pose_keep) = pose_copy(pose)
      (
        pose_read,
        RigidBody{
          pose_keep,
          linear_velocity,
          angular_velocity,
          force,
          torque,
          inverse_mass,
          inverse_inertia,
          linear_damping,
          angular_damping,
          radius,
          restitution,
          friction
        }
      )

assert articulation_shape_congruence_func:
  forall joint_after: JointShape
  forall joint_before: JointShape
  forall child_after: ArticulationShape
  forall child_before: ArticulationShape
  forall sibling_after: ArticulationShape
  forall sibling_before: ArticulationShape
  forall joint_equal: {joint_after == joint_before : JointShape}
  forall child_equal: {child_after == child_before : ArticulationShape}
  forall sibling_equal: {sibling_after == sibling_before : ArticulationShape}
  { ShapeNode{joint_after, child_after, sibling_after} == ShapeNode{joint_before, child_before, sibling_before} : ArticulationShape }

def articulation_shape_congruence_func(joint_after, joint_before, child_after, child_before, sibling_after, sibling_before, joint_equal, child_equal, sibling_equal):
  Equal.trans(
    ArticulationShape,
    ShapeNode{joint_after, child_after, sibling_after},
    ShapeNode{joint_before, child_after, sibling_after},
    ShapeNode{joint_before, child_before, sibling_before},
    Equal.cong(
      JointShape,
      ArticulationShape,
      joint => ShapeNode{joint, child_after, sibling_after},
      joint_after,
      joint_before,
      joint_equal
    ),
    Equal.trans(
      ArticulationShape,
      ShapeNode{joint_before, child_after, sibling_after},
      ShapeNode{joint_before, child_before, sibling_after},
      ShapeNode{joint_before, child_before, sibling_before},
      Equal.cong(
        ArticulationShape,
        ArticulationShape,
        child => ShapeNode{joint_before, child, sibling_after},
        child_after,
        child_before,
        child_equal
      ),
      Equal.cong(
        ArticulationShape,
        ArticulationShape,
        sibling => ShapeNode{joint_before, child_before, sibling},
        sibling_after,
        sibling_before,
        sibling_equal
      )
    )
  )

assert joint_copy_shape_claim_func:
  forall value: Joint
  Claim<JointCopies, copies => { joint_copies_keep_shape(copies) == joint_shape(value) : JointShape }>

def joint_copy_shape_claim_func(value):
  match value:
    case Joint{BallJoint{}, parent_anchor, child_anchor, stiffness, damping, angular_limit}:
      (parent_left, parent_right) = vec3_copy(parent_anchor)
      (child_left, child_right) = vec3_copy(child_anchor)
      (stiffness_left, stiffness_right) = scalar_copy(stiffness)
      (damping_left, damping_right) = scalar_copy(damping)
      (limit_left, limit_right) = scalar_copy(angular_limit)
      Claim{
        JointCopies{
          Joint{BallJoint{}, parent_left, child_left, stiffness_left, damping_left, limit_left},
          Joint{BallJoint{}, parent_right, child_right, stiffness_right, damping_right, limit_right}
        },
        {==}
      }
    case Joint{HingeX{}, parent_anchor, child_anchor, stiffness, damping, angular_limit}:
      (parent_left, parent_right) = vec3_copy(parent_anchor)
      (child_left, child_right) = vec3_copy(child_anchor)
      (stiffness_left, stiffness_right) = scalar_copy(stiffness)
      (damping_left, damping_right) = scalar_copy(damping)
      (limit_left, limit_right) = scalar_copy(angular_limit)
      Claim{
        JointCopies{
          Joint{HingeX{}, parent_left, child_left, stiffness_left, damping_left, limit_left},
          Joint{HingeX{}, parent_right, child_right, stiffness_right, damping_right, limit_right}
        },
        {==}
      }
    case Joint{HingeY{}, parent_anchor, child_anchor, stiffness, damping, angular_limit}:
      (parent_left, parent_right) = vec3_copy(parent_anchor)
      (child_left, child_right) = vec3_copy(child_anchor)
      (stiffness_left, stiffness_right) = scalar_copy(stiffness)
      (damping_left, damping_right) = scalar_copy(damping)
      (limit_left, limit_right) = scalar_copy(angular_limit)
      Claim{
        JointCopies{
          Joint{HingeY{}, parent_left, child_left, stiffness_left, damping_left, limit_left},
          Joint{HingeY{}, parent_right, child_right, stiffness_right, damping_right, limit_right}
        },
        {==}
      }
    case Joint{HingeZ{}, parent_anchor, child_anchor, stiffness, damping, angular_limit}:
      (parent_left, parent_right) = vec3_copy(parent_anchor)
      (child_left, child_right) = vec3_copy(child_anchor)
      (stiffness_left, stiffness_right) = scalar_copy(stiffness)
      (damping_left, damping_right) = scalar_copy(damping)
      (limit_left, limit_right) = scalar_copy(angular_limit)
      Claim{
        JointCopies{
          Joint{HingeZ{}, parent_left, child_left, stiffness_left, damping_left, limit_left},
          Joint{HingeZ{}, parent_right, child_right, stiffness_right, damping_right, limit_right}
        },
        {==}
      }
    case Joint{FixedJoint{}, parent_anchor, child_anchor, stiffness, damping, angular_limit}:
      (parent_left, parent_right) = vec3_copy(parent_anchor)
      (child_left, child_right) = vec3_copy(child_anchor)
      (stiffness_left, stiffness_right) = scalar_copy(stiffness)
      (damping_left, damping_right) = scalar_copy(damping)
      (limit_left, limit_right) = scalar_copy(angular_limit)
      Claim{
        JointCopies{
          Joint{FixedJoint{}, parent_left, child_left, stiffness_left, damping_left, limit_left},
          Joint{FixedJoint{}, parent_right, child_right, stiffness_right, damping_right, limit_right}
        },
        {==}
      }
    case Joint{ConeTwist{}, parent_anchor, child_anchor, stiffness, damping, angular_limit}:
      (parent_left, parent_right) = vec3_copy(parent_anchor)
      (child_left, child_right) = vec3_copy(child_anchor)
      (stiffness_left, stiffness_right) = scalar_copy(stiffness)
      (damping_left, damping_right) = scalar_copy(damping)
      (limit_left, limit_right) = scalar_copy(angular_limit)
      Claim{
        JointCopies{
          Joint{ConeTwist{}, parent_left, child_left, stiffness_left, damping_left, limit_left},
          Joint{ConeTwist{}, parent_right, child_right, stiffness_right, damping_right, limit_right}
        },
        {==}
      }

assert joint_project_body_func:
  forall parent_pose: Pose
  forall incoming: Joint
  forall body: RigidBody
  Joint & RigidBody

def joint_project_body_func(parent_pose, incoming, body):
  match parent_pose incoming body:
    case parent Joint{kind, parent_anchor, child_anchor, stiffness, damping, angular_limit} RigidBody{child_pose, linear_velocity, angular_velocity, force, torque, inverse_mass, inverse_inertia, linear_damping, angular_damping, radius, restitution, friction}:
      (incoming_solve, incoming_keep) = joint_copy(
        Joint{kind, parent_anchor, child_anchor, stiffness, damping, angular_limit}
      )
      (child_pose_solve, child_pose_keep) = pose_copy(child_pose)
      match joint_correction(incoming_solve, parent, child_pose_solve):
        case JointCorrection{parent_linear, child_linear, parent_angular, child_angular}:
          (inverse_mass_apply, inverse_mass_keep) = scalar_copy(inverse_mass)
          (inverse_inertia_apply, inverse_inertia_keep) = scalar_copy(inverse_inertia)
          (
            incoming_keep,
            RigidBody{
              pose_apply_correction(
                child_pose_keep,
                vec3_scale(child_linear, inverse_mass_apply),
                vec3_scale(child_angular, inverse_inertia_apply)
              ),
              linear_velocity,
              angular_velocity,
              force,
              torque,
              inverse_mass_keep,
              inverse_inertia_keep,
              linear_damping,
              angular_damping,
              radius,
              restitution,
              friction
            }
          )

assert joint_project_body_shape_claim_func:
  forall parent_pose: Pose
  forall incoming: Joint
  forall body: RigidBody
  Claim<JointProjection, projection => { joint_projection_shape(projection) == joint_shape(incoming) : JointShape }>

def joint_project_body_shape_claim_func(parent_pose, incoming, body):
  match parent_pose incoming body:
    case parent joint RigidBody{child_pose, linear_velocity, angular_velocity, force, torque, inverse_mass, inverse_inertia, linear_damping, angular_damping, radius, restitution, friction}:
      match joint_copy_shape_claim_func(joint):
        case Claim{JointCopies{incoming_solve, incoming_keep}, joint_shape_equal}:
          (child_pose_solve, child_pose_keep) = pose_copy(child_pose)
          match joint_correction(incoming_solve, parent, child_pose_solve):
            case JointCorrection{parent_linear, child_linear, parent_angular, child_angular}:
              (inverse_mass_apply, inverse_mass_keep) = scalar_copy(inverse_mass)
              (inverse_inertia_apply, inverse_inertia_keep) = scalar_copy(inverse_inertia)
              Claim{
                JointProjection{
                  incoming_keep,
                  RigidBody{
                    pose_apply_correction(
                      child_pose_keep,
                      vec3_scale(child_linear, inverse_mass_apply),
                      vec3_scale(child_angular, inverse_inertia_apply)
                    ),
                    linear_velocity,
                    angular_velocity,
                    force,
                    torque,
                    inverse_mass_keep,
                    inverse_inertia_keep,
                    linear_damping,
                    angular_damping,
                    radius,
                    restitution,
                    friction
                  }
                },
                joint_shape_equal
              }

assert articulation_constraint_step_shape_claim_func:
  forall parent_pose: Pose
  forall incoming: Joint
  forall body: RigidBody
  Claim<ConstraintStep, step => { constraint_step_shape(step) == joint_shape(incoming) : JointShape }>

def articulation_constraint_step_shape_claim_func(parent_pose, incoming, body):
  match pose_copy(parent_pose):
    case (parent_for_node, parent_for_sibling):
      match joint_project_body_shape_claim_func(parent_for_node, incoming, body):
        case Claim{JointProjection{incoming_keep, corrected_body}, joint_shape_equal}:
          (child_parent, body_keep) = rigid_body_pose_pair_func(corrected_body)
          Claim{
            ConstraintStep{incoming_keep, body_keep, child_parent, parent_for_sibling},
            joint_shape_equal
          }

assert articulation_constraint_step_func:
  forall parent_pose: Pose
  forall incoming: Joint
  forall body: RigidBody
  ConstraintStep

def articulation_constraint_step_func(parent_pose, incoming, body):
  (parent_for_node, parent_for_sibling) = pose_copy(parent_pose)
  (incoming_keep, corrected_body) = joint_project_body_func(parent_for_node, incoming, body)
  (child_parent, body_keep) = rigid_body_pose_pair_func(corrected_body)
  ConstraintStep{incoming_keep, body_keep, child_parent, parent_for_sibling}

assert articulation_integration_step_func:
  forall body: RigidBody
  forall gravity: Vec3
  forall dt: Scalar
  IntegrationStep

def articulation_integration_step_func(body, gravity, dt):
  (gravity_body, (gravity_child, gravity_sibling)) = vec3_triple(gravity)
  (dt_body, (dt_child, dt_sibling)) = scalar_triple(dt)
  IntegrationStep{
    rigid_body_integrate(body, gravity_body, dt_body),
    gravity_child,
    gravity_sibling,
    dt_child,
    dt_sibling
  }

assert articulation_integrate_shape_claim_func:
  forall tree: Articulation
  forall gravity: Vec3
  forall dt: Scalar
  Claim<Articulation, output => { articulation_shape(output) == articulation_shape(tree) : ArticulationShape }>

def articulation_integrate_shape_claim_func(tree, gravity, dt):
  match tree:
    case ArticulationEnd{}:
      Claim{ArticulationEnd{}, {==}}
    case ArticulationNode{incoming, body, first_child, next_sibling}:
      match articulation_integration_step_func(body, gravity, dt):
        case IntegrationStep{body_output, child_gravity, sibling_gravity, child_dt, sibling_dt}:
          match articulation_integrate_shape_claim_func(first_child, child_gravity, child_dt):
            case Claim{child_output, child_equal}:
              match articulation_integrate_shape_claim_func(next_sibling, sibling_gravity, sibling_dt):
                case Claim{sibling_output, sibling_equal}:
                  Claim{
                    ArticulationNode{incoming, body_output, child_output, sibling_output},
                    articulation_shape_congruence_func(
                      joint_shape(incoming),
                      joint_shape(incoming),
                      articulation_shape(child_output),
                      articulation_shape(first_child),
                      articulation_shape(sibling_output),
                      articulation_shape(next_sibling),
                      {==},
                      child_equal,
                      sibling_equal
                    )
                  }

# Structural recursion is on the first live argument. Both recursive calls use
# direct constructor subterms, so every finite articulated tree is covered.
assert articulation_constrain_relative_func:
  forall tree: Articulation
  forall parent_pose: Pose
  Articulation

def articulation_constrain_relative_func(tree, parent_pose):
  match tree:
    case ArticulationEnd{}:
      ArticulationEnd{}
    case ArticulationNode{incoming, body, first_child, next_sibling}:
      match articulation_constraint_step_func(parent_pose, incoming, body):
        case ConstraintStep{incoming_keep, body_keep, child_parent, sibling_parent}:
          ArticulationNode{
            incoming_keep,
            body_keep,
            articulation_constrain_relative_func(first_child, child_parent),
            articulation_constrain_relative_func(next_sibling, sibling_parent)
          }

assert articulation_constrain_relative_shape_claim_func:
  forall tree: Articulation
  forall parent_pose: Pose
  Claim<Articulation, output => { articulation_shape(output) == articulation_shape(tree) : ArticulationShape }>

def articulation_constrain_relative_shape_claim_func(tree, parent_pose):
  match tree:
    case ArticulationEnd{}:
      Claim{ArticulationEnd{}, {==}}
    case ArticulationNode{incoming, body, first_child, next_sibling}:
      match articulation_constraint_step_shape_claim_func(parent_pose, incoming, body):
        case Claim{ConstraintStep{incoming_keep, body_keep, child_parent, sibling_parent}, joint_equal}:
          match articulation_constrain_relative_shape_claim_func(first_child, child_parent):
            case Claim{child_output, child_equal}:
              match articulation_constrain_relative_shape_claim_func(next_sibling, sibling_parent):
                case Claim{sibling_output, sibling_equal}:
                  Claim{
                    ArticulationNode{incoming_keep, body_keep, child_output, sibling_output},
                    articulation_shape_congruence_func(
                      joint_shape(incoming_keep),
                      joint_shape(incoming),
                      articulation_shape(child_output),
                      articulation_shape(first_child),
                      articulation_shape(sibling_output),
                      articulation_shape(next_sibling),
                      joint_equal,
                      child_equal,
                      sibling_equal
                    )
                  }

assert articulation_constrain_descendants_func:
  forall tree: Articulation
  Articulation

def articulation_constrain_descendants_func(tree):
  match tree:
    case ArticulationEnd{}:
      ArticulationEnd{}
    case ArticulationNode{incoming, body, first_child, next_sibling}:
      (root_pose, body_keep) = rigid_body_pose_pair_func(body)
      ArticulationNode{
        incoming,
        body_keep,
        articulation_constrain_relative_func(first_child, root_pose),
        articulation_constrain_descendants_func(next_sibling)
      }

assert articulation_constrain_descendants_shape_claim_func:
  forall tree: Articulation
  Claim<Articulation, output => { articulation_shape(output) == articulation_shape(tree) : ArticulationShape }>

def articulation_constrain_descendants_shape_claim_func(tree):
  match tree:
    case ArticulationEnd{}:
      Claim{ArticulationEnd{}, {==}}
    case ArticulationNode{incoming, body, first_child, next_sibling}:
      match rigid_body_pose_pair_func(body):
        case (root_pose, body_keep):
          match articulation_constrain_relative_shape_claim_func(first_child, root_pose):
            case Claim{child_output, child_equal}:
              match articulation_constrain_descendants_shape_claim_func(next_sibling):
                case Claim{sibling_output, sibling_equal}:
                  Claim{
                    ArticulationNode{incoming, body_keep, child_output, sibling_output},
                    articulation_shape_congruence_func(
                      joint_shape(incoming),
                      joint_shape(incoming),
                      articulation_shape(child_output),
                      articulation_shape(first_child),
                      articulation_shape(sibling_output),
                      articulation_shape(next_sibling),
                      {==},
                      child_equal,
                      sibling_equal
                    )
                  }

assert constraint_iterations_func:
  forall fuel: Nat
  forall tree: Articulation
  Articulation

def constraint_iterations_func(fuel, tree):
  match fuel:
    case 0n:
      tree
    case 1n+rest:
      constraint_iterations_func(rest, articulation_constrain_descendants_func(tree))

assert constraint_iterations_shape_claim_func:
  forall fuel: Nat
  forall tree: Articulation
  Claim<Articulation, output => { articulation_shape(output) == articulation_shape(tree) : ArticulationShape }>

def constraint_iterations_shape_claim_func(fuel, tree):
  match fuel:
    case 0n:
      Claim{tree, {==}}
    case 1n+rest:
      match articulation_constrain_descendants_shape_claim_func(tree):
        case Claim{step_output, step_equal}:
          match constraint_iterations_shape_claim_func(rest, step_output):
            case Claim{final_output, final_equal}:
              Claim{
                final_output,
                Equal.trans(
                  ArticulationShape,
                  articulation_shape(final_output),
                  articulation_shape(step_output),
                  articulation_shape(tree),
                  final_equal,
                  step_equal
                )
              }

assert ragdoll_step_resources_func:
  forall gravity: Vec3
  forall iterations: Nat
  RagdollStepResources

def ragdoll_step_resources_func(gravity, iterations):
  (gravity_step, gravity_keep) = vec3_copy(gravity)
  ((iterations_step, iterations_step_exact), (iterations_keep, iterations_keep_exact)) = Nat.copy(iterations)
  RagdollStepResources{gravity_step, gravity_keep, iterations_step, iterations_keep}

assert ragdoll_step_shape_claim_func:
  forall value: Ragdoll
  forall dt: Scalar
  Claim<Ragdoll, output => { ragdoll_actual_shape(output) == ragdoll_actual_shape(value) : ArticulationShape }>

def ragdoll_step_shape_claim_func(value, dt):
  match value:
    case Ragdoll{topology, RagdollDynamics{root, gravity, constraint_iterations}}:
      match ragdoll_step_resources_func(gravity, constraint_iterations):
        case RagdollStepResources{gravity_step, gravity_keep, iterations_step, iterations_keep}:
          match articulation_integrate_shape_claim_func(root, gravity_step, dt):
            case Claim{integrated_root, integration_equal}:
              match constraint_iterations_shape_claim_func(iterations_step, integrated_root):
                case Claim{constrained_root, constraint_equal}:
                  Claim{
                    Ragdoll{
                      topology,
                      RagdollDynamics{constrained_root, gravity_keep, iterations_keep}
                    },
                    Equal.trans(
                      ArticulationShape,
                      articulation_shape(constrained_root),
                      articulation_shape(integrated_root),
                      articulation_shape(root),
                      constraint_equal,
                      integration_equal
                    )
                  }

assert ragdoll_step_func:
  forall value: Ragdoll
  forall dt: Scalar
  Ragdoll

def ragdoll_step_func(value, dt):
  match ragdoll_step_shape_claim_func(value, dt):
    case Claim{output, proof}:
      output

assert pinned_body_steps_func:
  forall history: StepHistory
  forall body: PinnedBody
  PinnedBody

def pinned_body_steps_func(history, body):
  match history:
    case StepHistoryEnd{}:
      body
    case StepHistoryFrame{dt, tail}:
      pinned_body_steps_func(tail, pinned_body_integrate(body, vec3_zero_func(), dt))

assert pinned_body_history_invariant_theorem_func:
  forall history: StepHistory
  forall body: PinnedBody
  { pinned_body_steps_func(history, body) == body : PinnedBody }

def pinned_body_history_invariant_theorem_func(history, body):
  match history:
    case StepHistoryEnd{}:
      {==}
    case StepHistoryFrame{dt, tail}:
      %pinned_body_history_invariant_theorem_func(tail, body) : {
        pinned_body_steps_func(
          tail,
          pinned_body_integrate(body, vec3_zero_func(), dt)
        ) == _
        : PinnedBody
      }
      {==}

assert ragdoll_steps_shape_claim_func:
  forall history: StepHistory
  forall value: Ragdoll
  Claim<Ragdoll, output => { ragdoll_actual_shape(output) == ragdoll_actual_shape(value) : ArticulationShape }>

def ragdoll_steps_shape_claim_func(history, value):
  match history:
    case StepHistoryEnd{}:
      Claim{value, {==}}
    case StepHistoryFrame{dt, tail}:
      match ragdoll_step_shape_claim_func(value, dt):
        case Claim{step_output, step_equal}:
          match ragdoll_steps_shape_claim_func(tail, step_output):
            case Claim{history_output, history_equal}:
              Claim{
                history_output,
                Equal.trans(
                  ArticulationShape,
                  ragdoll_actual_shape(history_output),
                  ragdoll_actual_shape(step_output),
                  ragdoll_actual_shape(value),
                  history_equal,
                  step_equal
                )
              }

assert ragdoll_steps_func:
  forall history: StepHistory
  forall value: Ragdoll
  Ragdoll

def ragdoll_steps_func(history, value):
  match ragdoll_steps_shape_claim_func(history, value):
    case Claim{output, proof}:
      output

assert sample_body_func:
  forall position: Vec3
  forall velocity: Vec3
  RigidBody

def sample_body_func(position, velocity):
  RigidBody{
    Pose{position, vec3_zero_func()},
    velocity,
    vec3_zero_func(),
    vec3_zero_func(),
    vec3_zero_func(),
    scalar_one_func(),
    scalar_one_func(),
    ScalarPos{u32_func(1000n)},
    ScalarPos{u32_func(992n)},
    ScalarPos{u32_func(512n)},
    ScalarPos{u32_func(512n)},
    ScalarPos{u32_func(256n)}
  }

assert sample_shoulder_joint_func:
  Joint

def sample_shoulder_joint_func():
  Joint{
    BallJoint{},
    Vec3{ScalarPos{u32_func(512n)}, scalar_zero_func(), scalar_zero_func()},
    Vec3{ScalarNeg{u32_func(512n)}, scalar_zero_func(), scalar_zero_func()},
    ScalarPos{u32_func(768n)},
    ScalarPos{u32_func(128n)},
    ScalarPos{u32_func(384n)}
  }

assert sample_head_joint_func:
  Joint

def sample_head_joint_func():
  Joint{
    ConeTwist{},
    Vec3{scalar_zero_func(), ScalarPos{u32_func(768n)}, scalar_zero_func()},
    Vec3{scalar_zero_func(), ScalarNeg{u32_func(256n)}, scalar_zero_func()},
    ScalarPos{u32_func(900n)},
    ScalarPos{u32_func(192n)},
    ScalarPos{u32_func(256n)}
  }

assert sample_ragdoll_func:
  Ragdoll

def sample_ragdoll_func():
  Ragdoll{
    RagdollTopology{3n, 2n, 11n},
    RagdollDynamics{
      ArticulationNode{
        empty_joint_func(),
        sample_body_func(vec3_zero_func(), vec3_zero_func()),
        ArticulationNode{
          sample_head_joint_func(),
          sample_body_func(
            Vec3{scalar_zero_func(), ScalarPos{u32_func(1024n)}, scalar_zero_func()},
            vec3_zero_func()
          ),
          ArticulationEnd{},
          ArticulationNode{
            sample_shoulder_joint_func(),
            sample_body_func(
              Vec3{ScalarPos{u32_func(1024n)}, scalar_zero_func(), scalar_zero_func()},
              vec3_zero_func()
            ),
            ArticulationEnd{},
            ArticulationEnd{}
          }
        },
        ArticulationEnd{}
      },
      Vec3{scalar_zero_func(), ScalarNeg{u32_func(1024n)}, scalar_zero_func()},
      4n
    }
  }

assert contact_certificate_func:
  Bool

def contact_certificate_func():
  match contact_resolve_static(
    Contact{
      Vec3{scalar_zero_func(), scalar_one_func(), scalar_zero_func()},
      ScalarPos{u32_func(64n)},
      ScalarPos{u32_func(512n)},
      ScalarPos{u32_func(256n)}
    },
    sample_body_func(
      Vec3{scalar_zero_func(), ScalarNeg{u32_func(64n)}, scalar_zero_func()},
      Vec3{ScalarPos{u32_func(128n)}, ScalarNeg{u32_func(1024n)}, scalar_zero_func()}
    )
  ):
    case RigidBody{Pose{Vec3{_, ScalarPos{position_y}, _}, _}, Vec3{_, ScalarPos{velocity_y}, _}, _, _, _, _, _, _, _, _, _, _}:
      Bool.and(U32.is_eq(position_y, u32_func(0n)), U32.is_eq(velocity_y, u32_func(512n)))
    case _:
      False{}

assert ragdoll_certificate_func:
  Bool

def ragdoll_certificate_func():
  match ragdoll_step_func(sample_ragdoll_func(), ScalarPos{u32_func(16n)}):
    case Ragdoll{topology, RagdollDynamics{root, gravity, constraint_iterations}}:
      Nat.is_eq(articulation_body_count(root), 3n)

assert joint_preservation_certificate_func:
  Bool

def joint_preservation_certificate_func():
  match ragdoll_step_func(sample_ragdoll_func(), ScalarPos{u32_func(16n)}):
    case Ragdoll{
      topology,
      RagdollDynamics{
        ArticulationNode{
          root_joint,
          root_body,
          ArticulationNode{
            Joint{ConeTwist{}, head_parent, head_child, head_stiffness, head_damping, head_limit},
            head_body,
            head_children,
            ArticulationNode{
              Joint{BallJoint{}, shoulder_parent, shoulder_child, shoulder_stiffness, shoulder_damping, shoulder_limit},
              shoulder_body,
              shoulder_children,
              shoulder_siblings
            }
          },
          root_siblings
        },
        gravity,
        iterations
      }
    }:
      True{}
    case _:
      False{}

assert physics_self_check_func:
  Bool

def physics_self_check_func():
  Bool.and(
    contact_certificate_func(),
    Bool.and(ragdoll_certificate_func(), joint_preservation_certificate_func())
  )
