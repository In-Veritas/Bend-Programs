import Base
import ./bend_aquarium.bend as Aquarium
import ../bend_engine/fluids.bend as Fluids
import ../../compat/list.bend as List

# Types
# =====

type BendAquariumVerification:
  BendAquariumVerification{
    -tank_step_preserves_actual_equipment_topology:
      @state: Aquarium.TankState -> @event: Aquarium.TankEvent -> {
        Aquarium.aquarium_tank_payload_func(Aquarium.tank_state_step(state, event))
        == Aquarium.aquarium_tank_payload_func(state)
        : Aquarium.TankPayload
      },
    -arbitrary_tank_history_preserves_actual_equipment_topology:
      @history: Aquarium.TankHistory -> @state: Aquarium.TankState -> {
        Aquarium.aquarium_tank_payload_func(Aquarium.aquarium_tank_history_run_func(history, state))
        == Aquarium.aquarium_tank_payload_func(state)
        : Aquarium.TankPayload
      },
    -arbitrary_tank_history_obeys_every_event_law:
      @history: Aquarium.TankHistory -> Aquarium.AquariumHistoryPhysicsClaim_func(history),
    -aquarium_frames_have_constructive_length_proof:
      @fuel: Nat -> @index: U32 -> @seed: U32 -> Aquarium.VerifiedAquariumFrames<fuel>,
    -every_arbitrary_reef_gets_exactly_one_motion_law_per_coral:
      @corals: List<Aquarium.CoralModel> -> {
        List.length(Aquarium.CoralMotionProfile, Aquarium.aquarium_coral_motion_profiles_func(corals))
        == List.length(Aquarium.CoralModel, corals)
        : Nat
      },
    -arbitrary_fluid_particle_history_conserves_identity_material_volume:
      @history: Fluids.ImpulseHistory -> @particle: Fluids.FluidParticle -> {
        Fluids.fluid_particle_payload(Fluids.impulse_history_run(history, particle))
        == Fluids.fluid_particle_payload(particle)
        : Fluids.FluidPayload
      },
    -arbitrary_wave_history_preserves_cell_identity:
      @history: Fluids.WaveHistory -> @cell: Fluids.WaveCell -> {
        Fluids.wave_cell_id_func(Fluids.wave_history_run(history, cell))
        == Fluids.wave_cell_id_func(cell)
        : Nat
      },
    -bubble_fish_filter_wind_forces_superpose:
      @forcing: Fluids.SurfaceForcing -> @material: Fluids.WaterMaterial -> {
        Fluids.surface_response_wave_func(Fluids.surface_forcing_resolve(forcing, material))
        == Fluids.surface_forcing_sum_func(forcing)
        : U32
      },
    general_theorems: U32,
    certificates: U32
  }

# Constants
# =========

# Func-Section
# ============

assert bend_aquarium_verification_func:
  BendAquariumVerification

def bend_aquarium_verification_func():
  BendAquariumVerification{
    Aquarium.aquarium_tank_step_payload_theorem_func,
    Aquarium.aquarium_tank_history_payload_theorem_func,
    Aquarium.tank_history_physics_theorem_func,
    Aquarium.aquarium_verified_frames_func,
    Aquarium.aquarium_coral_motion_cardinality_theorem_func,
    Fluids.impulse_history_payload_theorem_func,
    Fluids.wave_history_id_theorem_func,
    Fluids.surface_forcing_wave_superposition_theorem,
    U32.from_nat(8n),
    U32.from_nat(5n)
  }

assert bend_aquarium_verification_self_check_func:
  Bool

def bend_aquarium_verification_self_check_func():
  Aquarium.aquarium_self_check_func()
