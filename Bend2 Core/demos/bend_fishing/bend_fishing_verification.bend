import Base
import ./bend_fishing.bend as Fishing
import ../bend_engine/physics.bend as Physics
import ../bend_engine/fluids.bend as Fluids

# Types
# =====

type BendFishingVerification:
  BendFishingVerification{
    -swim_step_preserves_identity_species_size:
      @fish: Fishing.Fish -> @event: Fishing.SwimEvent -> {
        Fishing.fish_payload(Fishing.fish_step(fish, event)) == Fishing.fish_payload(fish)
        : Fishing.FishPayload
      },
    -arbitrary_swim_history_preserves_identity_species_size:
      @history: Fishing.SwimHistory -> @fish: Fishing.Fish -> {
        Fishing.fish_payload(Fishing.swim_history_run(history, fish)) == Fishing.fish_payload(fish)
        : Fishing.FishPayload
      },
    -school_step_preserves_every_fish_alignment:
      @fishes: List<Fishing.Fish> -> @event: Fishing.SwimEvent ->
      Physics.Claim<List<Fishing.Fish>, output => {
        Fishing.fishing_fishes_payload_func(output)
        == Fishing.fishing_fishes_payload_func(fishes)
        : List<Fishing.FishPayload>
      }>,
    -fishing_frames_have_constructive_length_proof:
      @fuel: Nat -> @index: U32 -> @seed: U32 -> Fishing.VerifiedFishingFrames<fuel>,
    -bite_cued_session_frames_have_constructive_length_proof:
      @fuel: Nat -> @index: U32 -> @bite_start: U32 -> @bite_end: U32 -> @seed: U32 ->
      Fishing.VerifiedFishingFrames<fuel>,
    -reel_animation_has_constructive_length_proof:
      @fuel: Nat -> @index: U32 -> @caught: Bool -> @cast_x: U32 -> @cast_z: U32 ->
      Fishing.VerifiedReelFrames<fuel>,
    -fluid_particle_history_conserves_payload:
      @history: Fluids.ImpulseHistory -> @particle: Fluids.FluidParticle -> {
        Fluids.fluid_particle_payload(Fluids.impulse_history_run(history, particle))
        == Fluids.fluid_particle_payload(particle)
        : Fluids.FluidPayload
      },
    -water_surface_forces_superpose:
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

assert bend_fishing_verification_func:
  BendFishingVerification

def bend_fishing_verification_func():
  BendFishingVerification{
    Fishing.fish_step_payload_theorem,
    Fishing.swim_history_payload_theorem_func,
    Fishing.fishing_fishes_step_claim_func,
    Fishing.fishing_verified_frames_func,
    Fishing.fishing_verified_session_frames_func,
    Fishing.fishing_verified_reel_frames_func,
    Fluids.impulse_history_payload_theorem_func,
    Fluids.surface_forcing_wave_superposition_theorem,
    U32.from_nat(8n),
    U32.from_nat(5n)
  }

assert bend_fishing_verification_self_check_func:
  Bool

def bend_fishing_verification_self_check_func():
  Fishing.fishing_self_check_func()
