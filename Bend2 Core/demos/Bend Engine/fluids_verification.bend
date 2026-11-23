import Base
import ./fluids.bend as Fluids
import ../../compat/list.bend as List

# Types
# =====

type FluidsVerification:
  FluidsVerification{
    -particle_step_preserves_payload:
      @particle: Fluids.FluidParticle -> @impulse: Fluids.FluidImpulse -> {
        Fluids.fluid_particle_payload(Fluids.fluid_particle_apply_impulse(particle, impulse))
        == Fluids.fluid_particle_payload(particle)
        : Fluids.FluidPayload
      },
    -arbitrary_particle_history_preserves_payload:
      @history: Fluids.ImpulseHistory -> @particle: Fluids.FluidParticle -> {
        Fluids.fluid_particle_payload(Fluids.impulse_history_run(history, particle))
        == Fluids.fluid_particle_payload(particle)
        : Fluids.FluidPayload
      },
    -arbitrary_particle_field_step_preserves_payload:
      @inputs: List<Fluids.FluidParticleInput> -> {
        Fluids.fluids_particles_payload_func(Fluids.fluids_particle_inputs_step_func(inputs))
        == Fluids.fluids_particle_inputs_payload_func(inputs)
        : List<Fluids.FluidPayload>
      },
    -arbitrary_particle_field_step_preserves_count:
      @inputs: List<Fluids.FluidParticleInput> -> {
        List.length(Fluids.FluidParticle, Fluids.fluids_particle_inputs_step_func(inputs))
        == List.length(Fluids.FluidParticleInput, inputs)
        : Nat
      },
    -wave_step_preserves_cell_identity:
      @cell: Fluids.WaveCell -> @impulse: Fluids.WaveImpulse -> {
        Fluids.wave_cell_id_func(Fluids.wave_cell_step(cell, impulse))
        == Fluids.wave_cell_id_func(cell)
        : Nat
      },
    -arbitrary_wave_history_preserves_cell_identity:
      @history: Fluids.WaveHistory -> @cell: Fluids.WaveCell -> {
        Fluids.wave_cell_id_func(Fluids.wave_history_run(history, cell))
        == Fluids.wave_cell_id_func(cell)
        : Nat
      },
    -dry_body_has_zero_buoyancy:
      @body: Fluids.BuoyantBody -> @medium: Fluids.FluidMedium -> {
        Fluids.buoyancy_sample_force_func(Fluids.buoyant_body_sample(body, Fluids.Dry{}, medium))
        == 0
        : U32
      },
    -surface_forces_superpose:
      @forcing: Fluids.SurfaceForcing -> @material: Fluids.WaterMaterial -> {
        Fluids.surface_response_wave_func(Fluids.surface_forcing_resolve(forcing, material))
        == Fluids.surface_forcing_sum_func(forcing)
        : U32
      },
    general_theorems: U32
  }

# Constants
# =========

# Func-Section
# ============

assert fluids_verification_func:
  FluidsVerification

def fluids_verification_func():
  FluidsVerification{
    Fluids.fluid_particle_apply_impulse_payload_theorem,
    Fluids.impulse_history_payload_theorem_func,
    Fluids.fluids_particle_inputs_step_payload_theorem_func,
    Fluids.fluids_particle_inputs_count_theorem_func,
    Fluids.wave_cell_step_id_theorem,
    Fluids.wave_history_id_theorem_func,
    Fluids.buoyant_body_dry_force_theorem,
    Fluids.surface_forcing_wave_superposition_theorem,
    U32.from_nat(8n)
  }

assert fluids_verification_self_check_func:
  Bool

def fluids_verification_self_check_func():
  Fluids.fluids_self_check_func()
