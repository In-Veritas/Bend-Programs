import Base
import ./landscape.bend as Landscape
import ./landscape_proofs.bend as Proofs

# This audit intentionally combines finite-state physical invariants with a
# structural induction over arbitrary scrolling lengths. Closed visual fixtures
# are not accepted as substitutes for these quantified fields.

# Types
# =====

type LandscapeVerification:
  LandscapeVerification{
    -every_arbitrary_tide_horizon_is_a_bounded_exact_transition_history:
      @fuel: Nat -> @phase: Landscape.TidePhase -> Proofs.VerifiedTideHistory<fuel>,
    -every_arbitrary_terrain_horizon_is_a_bounded_exact_transition_history:
      @fuel: Nat -> @band: Landscape.TerrainBand -> Proofs.VerifiedTerrainHistory<fuel>,
    -every_arbitrary_cloud_horizon_carries_exact_rain_and_sun_transitions:
      @fuel: Nat -> @phase: Landscape.CloudPhase -> Proofs.VerifiedCloudHistory<fuel>,
    -sand_carries_a_constructive_one_to_five_witness:
      @layers: Landscape.SandLayers -> Landscape.SandLayerCountClaim_func(layers),
    -every_whale_emergence_carries_a_constructive_thirty_percent_cap:
      @emergence: Landscape.WhaleEmergence -> Landscape.NatFromTenToThirty<Landscape.whale_emergence_percent_func(emergence)>,
    -every_whale_spout_carries_a_constructive_volume_cap:
      @spout: Landscape.SpoutState -> Landscape.NatAtMost<Landscape.whale_spout_volume_func(spout), 110n>,
    -every_school_size_carries_constructive_lower_and_upper_witnesses:
      @size: Landscape.SchoolSize -> Landscape.NatFromFourToTwelve<Landscape.school_member_count_func(size)>,
    -every_human_party_carries_constructive_lower_and_upper_witnesses:
      @party: Landscape.HumanParty -> Landscape.HumanPartyCountClaim_func(party),
    -every_arbitrary_school_member_generator_has_its_requested_length:
      @fuel: Nat -> @id: Nat -> Landscape.VerifiedSchoolMembers<fuel>,
    -every_arbitrary_school_step_preserves_ordered_member_identity:
      @members: List<Landscape.SchoolMember> -> @impulse: Landscape.SchoolImpulse ->
      Landscape.Claim<List<Landscape.SchoolMember>, output => {
        Landscape.landscape_school_payload_func(output)
        == Landscape.landscape_school_payload_func(members)
        : List<Landscape.SchoolMemberPayload>
      }>,
    -every_arbitrary_school_history_preserves_ordered_member_identity:
      @history: Landscape.SchoolHistory -> @members: List<Landscape.SchoolMember> ->
      Landscape.Claim<List<Landscape.SchoolMember>, output => {
        Landscape.landscape_school_payload_func(output)
        == Landscape.landscape_school_payload_func(members)
        : List<Landscape.SchoolMemberPayload>
      }>,
    -every_arbitrary_scrolling_prefix_has_exact_chunk_count:
      @fuel: Nat -> @key: U32 -> @index: U32 -> @boundary: Landscape.Boundary ->
      Landscape.VerifiedChunks<fuel>,
    general_theorems: U32,
    certificates: U32
  }

# Func-Section
# ============

assert landscape_verification_func:
  LandscapeVerification

def landscape_verification_func():
  LandscapeVerification{
    Proofs.tide_history_claim_func,
    Proofs.terrain_history_claim_func,
    Proofs.cloud_history_claim_func,
    Landscape.sand_layer_count_theorem_func,
    Landscape.whale_emergence_physical_theorem_func,
    Landscape.whale_spout_physical_theorem_func,
    Landscape.school_size_bounded_theorem_func,
    Landscape.human_party_count_theorem_func,
    Landscape.landscape_school_members_claim_func,
    Landscape.landscape_school_step_claim_func,
    Landscape.landscape_school_history_claim_func,
    Landscape.landscape_verified_chunks_func,
    U32.from_nat(12n),
    U32.from_nat(6n)
  }

assert landscape_verification_self_check_func:
  Bool

def landscape_verification_self_check_func():
  Landscape.landscape_self_check_func()
