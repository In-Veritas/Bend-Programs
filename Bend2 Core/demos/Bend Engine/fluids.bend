import Base
import ./model3d.bend as Model3D
import ./physics.bend as Physics
import ../../compat/list.bend as List

# Bend Engine deterministic fluids and water optics.
#
# Dynamic values use Physics' signed-magnitude Q10 scalars. Optical channels
# use U32 values clamped to 0..255. The particle layer preserves the complete
# identity/material/volume payload under arbitrary impulse histories; the wave
# layer models damped surface displacement; and the optical layer supplies
# refraction, Fresnel, absorption, caustic, and foam controls.

# Types
# =====

type FluidKind:
  WaterParcel{}
  AirBubble{}
  SuspendedMatter{}

type FluidPayload:
  FluidPayload{id: Nat, kind: FluidKind, volume: Nat}

type FluidDynamics:
  FluidDynamics{position: Physics.Vec3, velocity: Physics.Vec3}

type FluidParticle:
  FluidParticle{id: Nat, kind: FluidKind, volume: Nat, dynamics: FluidDynamics}

type FluidImpulse:
  FluidImpulse{delta_velocity: Physics.Vec3}

type ImpulseHistory:
  ImpulseHistoryEnd{}
  ImpulseHistoryFrame{impulse: FluidImpulse, tail: ImpulseHistory}

type WaveDynamics:
  WaveDynamics{
    height: Physics.Scalar,
    velocity: Physics.Scalar,
    damping: Physics.Scalar,
    foam: U32
  }

type WaveCell:
  WaveCell{id: Nat, dynamics: WaveDynamics}

type WaveImpulse:
  WaveImpulse{force: Physics.Scalar, foam: U32}

type WaveHistory:
  WaveHistoryEnd{}
  WaveHistoryFrame{impulse: WaveImpulse, tail: WaveHistory}

type WaveObservation:
  WaveObservation{id: Nat, height: Physics.Scalar, velocity: Physics.Scalar}

type Submersion:
  Dry{}
  Submerged{volume: U32}

type BuoyantBody:
  BuoyantBody{
    mass: U32,
    displaced_volume: U32,
    velocity: Physics.Vec3,
    drag: U32
  }

type FluidMedium:
  FluidMedium{density: U32, gravity: U32, viscosity: U32}

type BuoyancySample:
  BuoyancySample{upward_force: U32, weight: U32, drag: U32, rising: Bool}

type WaterMaterial:
  WaterMaterial{
    shallow_color: Model3D.Color,
    deep_color: Model3D.Color,
    clarity: U32,
    refraction_index: U32,
    fresnel: U32,
    absorption: U32,
    caustics: U32,
    roughness: U32
  }

type RefractionSample:
  RefractionSample{
    transmitted: U32,
    reflected: U32,
    distortion: U32,
    depth_fade: U32
  }

type SurfaceForcing:
  SurfaceForcing{
    bubble_wave: U32,
    bubble_foam: U32,
    fish_wave: U32,
    fish_caustic: U32,
    filter_wave: U32,
    filter_foam: U32,
    wind_wave: U32,
    wind_foam: U32
  }

type SurfaceResponse:
  SurfaceResponse{wave_energy: U32, foam: U32, caustic_energy: U32}

type ParticleCopies:
  ParticleCopies{first: FluidParticle, second: FluidParticle}

type FluidParticleInput:
  FluidParticleInput{particle: FluidParticle, impulse: FluidImpulse}

type FluidParticleClaim<-A: Type, -Property: @-value: A -> Type>:
  FluidParticleClaim{value: A, -proof: Property(value)}

# Constants
# =========

assert fluids_u32_func:
  forall value: Nat
  U32

def fluids_u32_func(value):
  U32.from_nat(value)

assert fluids_u32_pair_func:
  forall value: U32
  U32 & U32

def fluids_u32_pair_func(value):
  ((left, left_exact), (right, right_exact)) = U32.copy(value)
  (left, right)

assert fluids_u32_triple_func:
  forall value: U32
  U32 & (U32 & U32)

def fluids_u32_triple_func(value):
  (first, rest) = fluids_u32_pair_func(value)
  (second, third) = fluids_u32_pair_func(rest)
  (first, (second, third))

assert fluids_zero_vec3_func:
  Physics.Vec3

def fluids_zero_vec3_func():
  Physics.Vec3{
    Physics.ScalarPos{0},
    Physics.ScalarPos{0},
    Physics.ScalarPos{0}
  }

# FluidKind-Section
# =================

assert fluid_kind_copy:
  forall value: FluidKind
  FluidKind & FluidKind

def fluid_kind_copy(value):
  match value:
    case WaterParcel{}:
      (WaterParcel{}, WaterParcel{})
    case AirBubble{}:
      (AirBubble{}, AirBubble{})
    case SuspendedMatter{}:
      (SuspendedMatter{}, SuspendedMatter{})

# FluidImpulse-Section
# ====================

assert fluid_impulse_copy:
  forall value: FluidImpulse
  FluidImpulse & FluidImpulse

def fluid_impulse_copy(value):
  match value:
    case FluidImpulse{delta_velocity}:
      (left, right) = Physics.vec3_copy(delta_velocity)
      (FluidImpulse{left}, FluidImpulse{right})

assert fluid_impulse_apply:
  forall value: FluidImpulse
  forall velocity: Physics.Vec3
  Physics.Vec3

def fluid_impulse_apply(value, velocity):
  match value:
    case FluidImpulse{delta_velocity}:
      Physics.vec3_add(velocity, delta_velocity)

# FluidParticle-Section
# =====================

assert fluid_particle_payload:
  forall value: FluidParticle
  FluidPayload

def fluid_particle_payload(value):
  match value:
    case FluidParticle{id, kind, volume, dynamics}:
      FluidPayload{id, kind, volume}

assert fluid_particle_copy:
  forall value: FluidParticle
  ParticleCopies

def fluid_particle_copy(value):
  match value:
    case FluidParticle{id, kind, volume, FluidDynamics{position, velocity}}:
      ((id_left, id_left_exact), (id_right, id_right_exact)) = Nat.copy(id)
      ((volume_left, volume_left_exact), (volume_right, volume_right_exact)) = Nat.copy(volume)
      (kind_left, kind_right) = fluid_kind_copy(kind)
      (position_left, position_right) = Physics.vec3_copy(position)
      (velocity_left, velocity_right) = Physics.vec3_copy(velocity)
      ParticleCopies{
        FluidParticle{id_left, kind_left, volume_left, FluidDynamics{position_left, velocity_left}},
        FluidParticle{id_right, kind_right, volume_right, FluidDynamics{position_right, velocity_right}}
      }

assert fluid_dynamics_apply_impulse:
  forall value: FluidDynamics
  forall impulse: FluidImpulse
  FluidDynamics

def fluid_dynamics_apply_impulse(value, impulse):
  match value:
    case FluidDynamics{position, velocity}:
      (velocity_for_position, velocity_for_force) = Physics.vec3_copy(velocity)
      FluidDynamics{
        Physics.vec3_add(position, velocity_for_position),
        fluid_impulse_apply(impulse, velocity_for_force)
      }

assert fluid_particle_apply_impulse:
  forall value: FluidParticle
  forall impulse: FluidImpulse
  FluidParticle

def fluid_particle_apply_impulse(value, impulse):
  match value:
    case FluidParticle{id, kind, volume, dynamics}:
      FluidParticle{id, kind, volume, fluid_dynamics_apply_impulse(dynamics, impulse)}

assert fluid_particle_apply_impulse_payload_theorem:
  forall value: FluidParticle
  forall impulse: FluidImpulse
  { fluid_particle_payload(fluid_particle_apply_impulse(value, impulse)) == fluid_particle_payload(value) : FluidPayload }

def fluid_particle_apply_impulse_payload_theorem(value, impulse):
  match value:
    case FluidParticle{id, kind, volume, dynamics}:
      {==}

# ImpulseHistory-Section
# ======================

assert impulse_history_run:
  forall value: ImpulseHistory
  forall particle: FluidParticle
  FluidParticle

def impulse_history_run(value, particle):
  match value:
    case ImpulseHistoryEnd{}:
      particle
    case ImpulseHistoryFrame{impulse, tail}:
      stepped = fluid_particle_apply_impulse(particle, impulse)
      result = impulse_history_run(tail, stepped)
      result

assert impulse_history_payload_theorem_func:
  forall value: ImpulseHistory
  forall particle: FluidParticle
  { fluid_particle_payload(impulse_history_run(value, particle)) == fluid_particle_payload(particle) : FluidPayload }

def impulse_history_payload_theorem_func(value, particle):
  match value particle:
    case ImpulseHistoryEnd{} FluidParticle{id, kind, volume, dynamics}:
      {==}
    case ImpulseHistoryFrame{impulse, tail} FluidParticle{id, kind, volume, dynamics}:
      proof = impulse_history_payload_theorem_func(tail, fluid_particle_apply_impulse(FluidParticle{id, kind, volume, dynamics}, impulse))
      proof

# WaveCell-Section
# ================

assert wave_cell_observe:
  forall value: WaveCell
  WaveObservation

def wave_cell_observe(value):
  match value:
    case WaveCell{id, dynamics}:
      match dynamics:
        case WaveDynamics{height, velocity, damping, foam}:
          WaveObservation{id, height, velocity}

assert wave_dynamics_step:
  forall value: WaveDynamics
  forall impulse: WaveImpulse
  WaveDynamics

def wave_dynamics_step(value, impulse):
  match value impulse:
    case WaveDynamics{height, velocity, damping, old_foam} WaveImpulse{force, new_foam}:
      (velocity_height_force, velocity_rest) = Physics.scalar_copy(velocity)
      (velocity_height_damping, velocity_keep_rest) = Physics.scalar_copy(velocity_rest)
      (velocity_keep_force, velocity_keep_damping) = Physics.scalar_copy(velocity_keep_rest)
      (force_height, force_keep) = Physics.scalar_copy(force)
      (damping_height, damping_rest) = Physics.scalar_copy(damping)
      (damping_keep, damping_final) = Physics.scalar_copy(damping_rest)
      accelerated_height = Physics.scalar_add(velocity_height_force, force_height)
      damped_height = Physics.scalar_sub(accelerated_height, Physics.scalar_mul(velocity_height_damping, damping_height))
      accelerated_keep = Physics.scalar_add(velocity_keep_force, force_keep)
      damped_keep = Physics.scalar_sub(accelerated_keep, Physics.scalar_mul(velocity_keep_damping, damping_keep))
      WaveDynamics{Physics.scalar_add(height, damped_height), damped_keep, damping_final, U32.add(old_foam, new_foam)}

assert wave_cell_step:
  forall value: WaveCell
  forall impulse: WaveImpulse
  WaveCell

def wave_cell_step(value, impulse):
  match value:
    case WaveCell{id, dynamics}:
      WaveCell{id, wave_dynamics_step(dynamics, impulse)}

assert wave_cell_id_func:
  forall value: WaveCell
  Nat

def wave_cell_id_func(value):
  match value:
    case WaveCell{id, dynamics}:
      id

assert wave_cell_step_id_theorem:
  forall value: WaveCell
  forall impulse: WaveImpulse
  { wave_cell_id_func(wave_cell_step(value, impulse)) == wave_cell_id_func(value) : Nat }

def wave_cell_step_id_theorem(value, impulse):
  match value:
    case WaveCell{id, dynamics}:
      {==}

# WaveHistory-Section
# ===================

assert wave_history_run:
  forall value: WaveHistory
  forall cell: WaveCell
  WaveCell

def wave_history_run(value, cell):
  match value:
    case WaveHistoryEnd{}:
      cell
    case WaveHistoryFrame{impulse, tail}:
      stepped = wave_cell_step(cell, impulse)
      result = wave_history_run(tail, stepped)
      result

assert wave_history_id_theorem_func:
  forall value: WaveHistory
  forall cell: WaveCell
  { wave_cell_id_func(wave_history_run(value, cell)) == wave_cell_id_func(cell) : Nat }

def wave_history_id_theorem_func(value, cell):
  match value cell:
    case WaveHistoryEnd{} WaveCell{id, dynamics}:
      {==}
    case WaveHistoryFrame{impulse, tail} WaveCell{id, dynamics}:
      proof = wave_history_id_theorem_func(tail, wave_cell_step(WaveCell{id, dynamics}, impulse))
      proof

# WaterMaterial-Section
# =====================

assert water_material_copy:
  forall value: WaterMaterial
  WaterMaterial & WaterMaterial

def water_material_copy(value):
  match value:
    case WaterMaterial{shallow, deep, clarity, ior, fresnel, absorption, caustics, roughness}:
      (shallow_left, shallow_right) = Model3D.model3d_color_copy_func(shallow)
      (deep_left, deep_right) = Model3D.model3d_color_copy_func(deep)
      ((clarity_left, clarity_left_exact), (clarity_right, clarity_right_exact)) = U32.copy(clarity)
      ((ior_left, ior_left_exact), (ior_right, ior_right_exact)) = U32.copy(ior)
      ((fresnel_left, fresnel_left_exact), (fresnel_right, fresnel_right_exact)) = U32.copy(fresnel)
      ((absorption_left, absorption_left_exact), (absorption_right, absorption_right_exact)) = U32.copy(absorption)
      ((caustics_left, caustics_left_exact), (caustics_right, caustics_right_exact)) = U32.copy(caustics)
      ((roughness_left, roughness_left_exact), (roughness_right, roughness_right_exact)) = U32.copy(roughness)
      (
        WaterMaterial{shallow_left, deep_left, clarity_left, ior_left, fresnel_left, absorption_left, caustics_left, roughness_left},
        WaterMaterial{shallow_right, deep_right, clarity_right, ior_right, fresnel_right, absorption_right, caustics_right, roughness_right}
      )

assert water_material_refraction_sample:
  forall value: WaterMaterial
  forall incidence: U32
  forall depth: U32
  RefractionSample

def water_material_refraction_sample(value, incidence, depth):
  match value:
    case WaterMaterial{shallow, deep, clarity, ior, fresnel, absorption, caustics, roughness}:
      (incidence_reflect, (incidence_refract, incidence_distort)) = fluids_u32_triple_func(incidence)
      (clarity_transmit, (clarity_depth, clarity_distort)) = fluids_u32_triple_func(clarity)
      (ior_divisor, ior_distort) = fluids_u32_pair_func(ior)
      RefractionSample{
        U32.div(U32.mul(clarity_transmit, incidence_refract), fluids_u32_func(255n)),
        U32.div(U32.mul(fresnel, U32.sub(fluids_u32_func(255n), incidence_reflect)), fluids_u32_func(255n)),
        U32.div(U32.mul(incidence_distort, ior_distort), U32.add(ior_divisor, fluids_u32_func(1n))),
        U32.div(U32.mul(depth, U32.sub(fluids_u32_func(255n), clarity_depth)), fluids_u32_func(255n))
      }

# BuoyantBody-Section
# ===================

assert buoyancy_sample_make_func:
  forall lift: U32
  forall weight: U32
  forall drag: U32
  BuoyancySample

def buoyancy_sample_make_func(lift, weight, drag):
  (lift_keep, lift_test) = fluids_u32_pair_func(lift)
  (weight_keep, weight_test) = fluids_u32_pair_func(weight)
  BuoyancySample{lift_keep, weight_keep, drag, U32.is_gt(lift_test, weight_test)}

assert buoyant_body_sample:
  forall value: BuoyantBody
  forall submersion: Submersion
  forall medium: FluidMedium
  BuoyancySample

def buoyant_body_sample(value, submersion, medium):
  match value submersion medium:
    case BuoyantBody{mass, displaced, velocity, body_drag} Dry{} FluidMedium{density, gravity, viscosity}:
      BuoyancySample{0, U32.mul(mass, gravity), 0, False{}}
    case BuoyantBody{mass, displaced, velocity, body_drag} Submerged{submerged} FluidMedium{density, gravity, viscosity}:
      (gravity_lift, gravity_weight) = fluids_u32_pair_func(gravity)
      (density_lift, density_drag) = fluids_u32_pair_func(density)
      (submerged_lift, submerged_drag) = fluids_u32_pair_func(submerged)
      lift = U32.div(U32.mul(U32.mul(submerged_lift, density_lift), gravity_lift), fluids_u32_func(1024n))
      weight = U32.mul(mass, gravity_weight)
      drag = U32.div(U32.mul(U32.mul(body_drag, viscosity), submerged_drag), fluids_u32_func(1024n))
      buoyancy_sample_make_func(lift, weight, drag)

assert buoyancy_sample_force_func:
  forall value: BuoyancySample
  U32

def buoyancy_sample_force_func(value):
  match value:
    case BuoyancySample{force, weight, drag, rising}:
      force

assert buoyant_body_dry_force_theorem:
  forall value: BuoyantBody
  forall medium: FluidMedium
  { buoyancy_sample_force_func(buoyant_body_sample(value, Dry{}, medium)) == 0 : U32 }

def buoyant_body_dry_force_theorem(value, medium):
  match value medium:
    case BuoyantBody{mass, displaced, velocity, body_drag} FluidMedium{density, gravity, viscosity}:
      {==}

# SurfaceForcing-Section
# ======================

assert surface_forcing_resolve:
  forall value: SurfaceForcing
  forall material: WaterMaterial
  SurfaceResponse

def surface_forcing_resolve(value, material):
  match value material:
    case SurfaceForcing{bubble_wave, bubble_foam, fish_wave, fish_caustic, filter_wave, filter_foam, wind_wave, wind_foam} WaterMaterial{shallow, deep, clarity, ior, fresnel, absorption, caustics, roughness}:
      SurfaceResponse{
        U32.add(U32.add(bubble_wave, fish_wave), U32.add(filter_wave, wind_wave)),
        U32.add(bubble_foam, U32.add(filter_foam, wind_foam)),
        U32.div(U32.mul(fish_caustic, caustics), fluids_u32_func(255n))
      }

assert surface_response_wave_func:
  forall value: SurfaceResponse
  U32

def surface_response_wave_func(value):
  match value:
    case SurfaceResponse{wave, foam, caustic}:
      wave

assert surface_forcing_sum_func:
  forall value: SurfaceForcing
  U32

def surface_forcing_sum_func(value):
  match value:
    case SurfaceForcing{bubble_wave, bubble_foam, fish_wave, fish_caustic, filter_wave, filter_foam, wind_wave, wind_foam}:
      U32.add(U32.add(bubble_wave, fish_wave), U32.add(filter_wave, wind_wave))

assert surface_forcing_wave_superposition_theorem:
  forall value: SurfaceForcing
  forall material: WaterMaterial
  { surface_response_wave_func(surface_forcing_resolve(value, material)) == surface_forcing_sum_func(value) : U32 }

def surface_forcing_wave_superposition_theorem(value, material):
  match value material:
    case SurfaceForcing{bubble_wave, bubble_foam, fish_wave, fish_caustic, filter_wave, filter_foam, wind_wave, wind_foam} WaterMaterial{shallow, deep, clarity, ior, fresnel, absorption, caustics, roughness}:
      {==}

# Func-Section
# ============

assert fluids_particles_payload_func:
  forall values: List<FluidParticle>
  List<FluidPayload>

def fluids_particles_payload_func(values):
  match values:
    case Nil{}:
      Nil{}
    case Con{head, tail}:
      Con{fluid_particle_payload(head), fluids_particles_payload_func(tail)}

assert fluid_particle_input_payload_func:
  forall value: FluidParticleInput
  FluidPayload

def fluid_particle_input_payload_func(value):
  match value:
    case FluidParticleInput{particle, impulse}:
      fluid_particle_payload(particle)

assert fluid_particle_input_step_func:
  forall value: FluidParticleInput
  FluidParticle

def fluid_particle_input_step_func(value):
  match value:
    case FluidParticleInput{particle, impulse}:
      fluid_particle_apply_impulse(particle, impulse)

assert fluids_particle_inputs_payload_func:
  forall values: List<FluidParticleInput>
  List<FluidPayload>

def fluids_particle_inputs_payload_func(values):
  match values:
    case Nil{}:
      Nil{}
    case Con{head, tail}:
      Con{fluid_particle_input_payload_func(head), fluids_particle_inputs_payload_func(tail)}

assert fluids_particle_inputs_step_func:
  forall values: List<FluidParticleInput>
  List<FluidParticle>

def fluids_particle_inputs_step_func(values):
  match values:
    case Nil{}:
      Nil{}
    case Con{head, tail}:
      Con{fluid_particle_input_step_func(head), fluids_particle_inputs_step_func(tail)}

assert fluids_particle_inputs_step_payload_theorem_func:
  forall values: List<FluidParticleInput>
  { fluids_particles_payload_func(fluids_particle_inputs_step_func(values)) == fluids_particle_inputs_payload_func(values) : List<FluidPayload> }

def fluids_particle_inputs_step_payload_theorem_func(values):
  match values:
    case Nil{}:
      {==}
    case Con{FluidParticleInput{FluidParticle{id, kind, volume, dynamics}, impulse}, tail}:
      tail_proof = fluids_particle_inputs_step_payload_theorem_func(tail)
      Equal.cong(
        List<FluidPayload>,
        List<FluidPayload>,
        rest => Con{FluidPayload{id, kind, volume}, rest},
        fluids_particles_payload_func(fluids_particle_inputs_step_func(tail)),
        fluids_particle_inputs_payload_func(tail),
        tail_proof
      )

assert fluids_particle_inputs_count_theorem_func:
  forall values: List<FluidParticleInput>
  { List.length(FluidParticle, fluids_particle_inputs_step_func(values)) == List.length(FluidParticleInput, values) : Nat }

def fluids_particle_inputs_count_theorem_func(values):
  match values:
    case Nil{}:
      {==}
    case Con{head, tail}:
      tail_proof = fluids_particle_inputs_count_theorem_func(tail)
      Equal.cong(
        Nat,
        Nat,
        length => 1n+length,
        List.length(FluidParticle, fluids_particle_inputs_step_func(tail)),
        List.length(FluidParticleInput, tail),
        tail_proof
      )

assert fluids_default_water_func:
  WaterMaterial

def fluids_default_water_func():
  WaterMaterial{
    Model3D.Color{fluids_u32_func(52n), fluids_u32_func(174n), fluids_u32_func(214n)},
    Model3D.Color{fluids_u32_func(3n), fluids_u32_func(45n), fluids_u32_func(88n)},
    fluids_u32_func(184n),
    fluids_u32_func(341n),
    fluids_u32_func(96n),
    fluids_u32_func(70n),
    fluids_u32_func(220n),
    fluids_u32_func(18n)
  }

assert fluids_self_check_func:
  Bool

def fluids_self_check_func():
  match buoyant_body_sample(
    BuoyantBody{fluids_u32_func(2n), fluids_u32_func(8n), fluids_zero_vec3_func(), fluids_u32_func(32n)},
    Submerged{fluids_u32_func(8n)},
    FluidMedium{fluids_u32_func(1024n), fluids_u32_func(10n), fluids_u32_func(24n)}
  ):
    case BuoyancySample{force, weight, drag, rising}:
      Bool.and(U32.is_gt(force, weight), rising)
