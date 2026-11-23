import Base
import ../../compat/list.bend as List
import ../../compat/nat.bend as Nat

# Bend Landscape is a pure keyed, indefinitely extendable side-scrolling world.
# A browser keeps the returned Boundary and asks Core for the next ChunkStep.
# Numeric drawing is a projection of the richer constructor-level invariants.

# Types
# =====

type Claim<-A: Type, -Property: @-value: A -> Type>:
  Claim{value: A, -proof: Property(value)}

# Mathematical order is represented constructively: value <= limit means
# there is a non-negative slack whose sum with value is exactly limit.  These
# witnesses erase, while the bounded number remains live.
type NatAtMost<-value: Nat, -limit: Nat>:
  NatAtMost{-slack: Nat, -fills_limit: {Nat.add(value, slack) == limit : Nat}}

type NatFromOneToFive<-value: Nat>:
  NatFromOneToFive{
    -extra: Nat,
    -slack: Nat,
    -from_one: {value == 1n+extra : Nat},
    -fills_four: {Nat.add(extra, slack) == 4n : Nat}
  }

type NatFromFourToTwelve<-value: Nat>:
  NatFromFourToTwelve{
    -extra: Nat,
    -slack: Nat,
    -from_four: {value == Nat.add(4n, extra) : Nat},
    -fills_eight: {Nat.add(extra, slack) == 8n : Nat}
  }

type NatFromTenToThirty<-value: Nat>:
  NatFromTenToThirty{
    -extra: Nat,
    -slack: Nat,
    -from_ten: {value == Nat.add(10n, extra) : Nat},
    -fills_twenty: {Nat.add(extra, slack) == 20n : Nat}
  }

type NatFromOneToThree<-value: Nat>:
  NatFromOneToThree{
    -extra: Nat,
    -slack: Nat,
    -from_one: {value == 1n+extra : Nat},
    -fills_two: {Nat.add(extra, slack) == 2n : Nat}
  }

type TidePhase:
  TideLow{}
  TideRisingOne{}
  TideRisingTwo{}
  TideCrest{}
  TideFallingOne{}
  TideFallingTwo{}
  TideRest{}

type TerrainBand:
  TerrainShore{}
  TerrainDune{}
  TerrainMeadow{}
  TerrainRise{}
  TerrainHill{}
  TerrainDescent{}

type WindBand:
  WindCalm{}
  WindBreeze{}
  WindFresh{}
  WindStrong{}
  WindGale{}

type CloudPhase:
  CloudClear{}
  CloudForming{}
  CloudCharging{}
  CloudRainReady{}
  CloudRaining{}
  CloudDissipating{}

type RainBand:
  RainNone{}
  RainDrizzle{}
  RainSteady{}
  RainHeavy{}

type SunBand:
  SunDim{}
  SunSoft{}
  SunBright{}

type SandLayers:
  SandLayers{
    layers: Nat,
    -extra: Nat,
    -slack: Nat,
    -from_one: {layers == 1n+extra : Nat},
    -fills_four: {Nat.add(extra, slack) == 4n : Nat}
  }

type Boundary:
  Boundary{tide: TidePhase, terrain: TerrainBand, wind: WindBand, cloud: CloudPhase, rain: RainBand, sun: SunBand}

type BoundaryCopies:
  BoundaryCopies{left: Boundary, right: Boundary}

type WhaleColor:
  WhaleGrey{}
  WhaleSlateBlue{}
  WhaleOceanBlue{}
  WhaleWhiteMorph{}
  WhaleBlackMorph{}

type WhaleSize:
  WhaleJuvenile{}
  WhaleAdult{}
  WhaleGreat{}

type SpoutState:
  SpoutState{
    active: Bool,
    volume: Nat,
    -slack: Nat,
    -fills_limit: {Nat.add(volume, slack) == 110n : Nat}
  }

type WhaleEmergence:
  WhaleEmergence{
    percent: Nat,
    -extra: Nat,
    -slack: Nat,
    -from_ten: {percent == Nat.add(10n, extra) : Nat},
    -fills_twenty: {Nat.add(extra, slack) == 20n : Nat}
  }

type WhaleModel:
  WhaleModel{id: Nat, color: WhaleColor, size: WhaleSize, emergence: WhaleEmergence, spout: SpoutState, slot: U32, phase: U32}

type SeaRockShape:
  SeaRockRound{}
  SeaRockSharp{}
  SeaRockArch{}
  SeaRockCluster{}

type RockProtrusion:
  RockSubmerged{}
  RockLow{}
  RockMedium{}
  RockHigh{}

type SeaRock:
  SeaRock{id: Nat, shape: SeaRockShape, protrusion: RockProtrusion, slot: U32, size: U32, facet_seed: U32}

type FishSpecies:
  Sardine{}
  Anchovy{}
  Mackerel{}
  Tuna{}
  FlyingFish{}
  LanternFish{}
  ReefBass{}
  MoonJelly{}
  Manta{}
  Shark{}
  Seahorse{}
  RibbonEel{}

type FishBehavior:
  FishCruising{}
  FishFleeing{}
  FishDiving{}
  FishFeeding{}

type FishModel:
  FishModel{id: Nat, species: FishSpecies, behavior: FishBehavior, slot: U32, depth: U32, size: U32, heading: U32, pattern: U32}

type SchoolSize:
  SchoolSize{
    members: Nat,
    -extra: Nat,
    -slack: Nat,
    -from_four: {members == Nat.add(4n, extra) : Nat},
    -fills_eight: {Nat.add(extra, slack) == 8n : Nat}
  }

type SchoolMember:
  SchoolMember{id: Nat, offset_x: Nat, offset_y: Nat, offset_z: Nat, heading: Nat}

type SchoolMemberPayload:
  SchoolMemberPayload{id: Nat}

type SchoolImpulse:
  SchoolCurrent{dx: Nat, dz: Nat}
  SchoolFlee{distance: Nat}
  SchoolDive{depth: Nat}

type SchoolHistory:
  SchoolHistoryEnd{}
  SchoolHistoryStep{impulse: SchoolImpulse, tail: SchoolHistory}

type VerifiedSchoolMembers<-expected: Nat>:
  VerifiedSchoolMembers{
    members: List<SchoolMember>,
    -length_exact: {List.length(SchoolMember, members) == expected : Nat}
  }

type SchoolModel:
  SchoolModel{id: Nat, species: FishSpecies, size: SchoolSize, members: List<SchoolMember>, slot: U32, depth: U32, heading: U32, cohesion: U32, flee_radius: U32}

type TreeSpecies:
  CoastOak{}
  StonePine{}
  WeepingWillow{}
  FruitTree{}
  Baobab{}
  Mangrove{}
  SilverBirch{}
  Cypress{}

type FruitState:
  FruitAbsent{}
  FruitHanging{count: U32}
  FruitFalling{count: U32, fall_phase: U32}

type TreeModel:
  TreeModel{id: Nat, species: TreeSpecies, slot: U32, height: U32, crown: U32, branches: U32, wind_response: U32, sun_access: U32, proximity: U32, fruit: FruitState}

type HillShape:
  RollingHill{}
  RockyRise{}
  DuneHill{}
  LayeredCliff{}

type HillModel:
  HillModel{id: Nat, shape: HillShape, slot: U32, height: U32, width: U32, facets: U32}

type SkinTone:
  SkinPorcelain{}
  SkinLight{}
  SkinOlive{}
  SkinBrown{}
  SkinDeep{}

type BodyScale:
  BodySmall{}
  BodyMedium{}
  BodyTall{}

type Clothes:
  ClothesWalker{}
  ClothesWorker{}
  ClothesRaincoat{}
  ClothesGatherer{}

type Personality:
  Curious{}
  Industrious{}
  Social{}
  Cautious{}
  Wanderer{}

type HumanAction:
  HumanStroll{}
  HumanDigRock{rock_id: Nat}
  HumanCutTree{tree_id: Nat}
  HumanHarvestTree{tree_id: Nat}
  HumanGather{partner_id: Nat}
  HumanShelter{tree_id: Nat}

type HumanModel:
  HumanModel{id: Nat, skin: SkinTone, body: BodyScale, clothes: Clothes, personality: Personality, action: HumanAction, slot: U32, phase: U32}

type HumanParty:
  HumanParty{
    people: List<HumanModel>,
    count: Nat,
    -extra: Nat,
    -slack: Nat,
    -length_exact: {List.length(HumanModel, people) == count : Nat},
    -from_one: {count == 1n+extra : Nat},
    -fills_two: {Nat.add(extra, slack) == 2n : Nat}
  }

type BirdSpecies:
  Gull{}
  Tern{}
  Heron{}
  Swift{}
  Kingfisher{}
  Cormorant{}
  SongThrush{}
  Kite{}

type BirdCall:
  CallChirp{}
  CallTrill{}
  CallCry{}
  CallWhistle{}
  CallSilent{}

type BirdAction:
  BirdFlying{}
  BirdPerchedTree{tree_id: Nat}
  BirdPerchedRock{rock_id: Nat}
  BirdSheltering{tree_id: Nat}

type BirdModel:
  BirdModel{id: Nat, species: BirdSpecies, call: BirdCall, action: BirdAction, slot: U32, altitude: U32, size: U32, color: U32, phase: U32}

type CloudShape:
  CloudPuff{}
  CloudLayer{}
  CloudTower{}
  CloudWisps{}

type CloudSize:
  CloudSmall{}
  CloudMedium{}
  CloudLarge{}
  CloudMerged{}

type CloudModel:
  CloudModel{id: Nat, shape: CloudShape, size: CloudSize, charge: CloudPhase, slot: U32, altitude: U32, opacity: U32, phase: U32}

type Weather:
  Weather{wind: WindBand, tide: TidePhase, cloud: CloudPhase, rain: RainBand, sun: SunBand, wind_force: U32, tide_y: U32, rain_amount: U32, light: U32}

type SeaSector:
  SeaSector{water_y: U32, sand: SandLayers, whales: List<WhaleModel>, rocks: List<SeaRock>, fish: List<FishModel>, schools: List<SchoolModel>}

type LandSector:
  LandSector{terrain: TerrainBand, trees: List<TreeModel>, hills: List<HillModel>, humans: HumanParty}

type SkySector:
  SkySector{birds: List<BirdModel>, clouds: List<CloudModel>}

type PlacementCertificate:
  PlacementCertificate{sea_lanes: U32, land_lanes: U32, sky_lanes: U32, minimum_spacing: U32}

type LandscapeChunk:
  LandscapeChunk{key: U32, index: U32, origin: U32, boundary: Boundary, sea: SeaSector, land: LandSector, sky: SkySector, weather: Weather, placements: PlacementCertificate}

type ChunkStep:
  ChunkStep{chunk: LandscapeChunk, next: Boundary}

type VerifiedChunks<-expected: Nat>:
  VerifiedChunks{chunks: List<LandscapeChunk>, next: Boundary, -length_exact: {List.length(LandscapeChunk, chunks) == expected : Nat}}

type LandscapeReport:
  LandscapeReport{title: String, key: U32, first: ChunkStep, proof_count: U32, certificate_count: U32}

# Constants
# =========

assert landscape_u32_func:
  forall value: Nat
  U32

def landscape_u32_func(value):
  U32.from_nat(value)

# Copies and finite transition systems
# ====================================

assert tide_copy:
  forall value: TidePhase
  TidePhase & TidePhase

def tide_copy(value):
  match value:
    case TideLow{}: (TideLow{}, TideLow{})
    case TideRisingOne{}: (TideRisingOne{}, TideRisingOne{})
    case TideRisingTwo{}: (TideRisingTwo{}, TideRisingTwo{})
    case TideCrest{}: (TideCrest{}, TideCrest{})
    case TideFallingOne{}: (TideFallingOne{}, TideFallingOne{})
    case TideFallingTwo{}: (TideFallingTwo{}, TideFallingTwo{})
    case TideRest{}: (TideRest{}, TideRest{})

assert terrain_copy:
  forall value: TerrainBand
  TerrainBand & TerrainBand

def terrain_copy(value):
  match value:
    case TerrainShore{}: (TerrainShore{}, TerrainShore{})
    case TerrainDune{}: (TerrainDune{}, TerrainDune{})
    case TerrainMeadow{}: (TerrainMeadow{}, TerrainMeadow{})
    case TerrainRise{}: (TerrainRise{}, TerrainRise{})
    case TerrainHill{}: (TerrainHill{}, TerrainHill{})
    case TerrainDescent{}: (TerrainDescent{}, TerrainDescent{})

assert wind_copy:
  forall value: WindBand
  WindBand & WindBand

def wind_copy(value):
  match value:
    case WindCalm{}: (WindCalm{}, WindCalm{})
    case WindBreeze{}: (WindBreeze{}, WindBreeze{})
    case WindFresh{}: (WindFresh{}, WindFresh{})
    case WindStrong{}: (WindStrong{}, WindStrong{})
    case WindGale{}: (WindGale{}, WindGale{})

assert cloud_copy:
  forall value: CloudPhase
  CloudPhase & CloudPhase

def cloud_copy(value):
  match value:
    case CloudClear{}: (CloudClear{}, CloudClear{})
    case CloudForming{}: (CloudForming{}, CloudForming{})
    case CloudCharging{}: (CloudCharging{}, CloudCharging{})
    case CloudRainReady{}: (CloudRainReady{}, CloudRainReady{})
    case CloudRaining{}: (CloudRaining{}, CloudRaining{})
    case CloudDissipating{}: (CloudDissipating{}, CloudDissipating{})

assert rain_copy:
  forall value: RainBand
  RainBand & RainBand

def rain_copy(value):
  match value:
    case RainNone{}: (RainNone{}, RainNone{})
    case RainDrizzle{}: (RainDrizzle{}, RainDrizzle{})
    case RainSteady{}: (RainSteady{}, RainSteady{})
    case RainHeavy{}: (RainHeavy{}, RainHeavy{})

assert sun_copy:
  forall value: SunBand
  SunBand & SunBand

def sun_copy(value):
  match value:
    case SunDim{}: (SunDim{}, SunDim{})
    case SunSoft{}: (SunSoft{}, SunSoft{})
    case SunBright{}: (SunBright{}, SunBright{})

assert boundary_copy:
  forall value: Boundary
  BoundaryCopies

def boundary_copy(value):
  match value:
    case Boundary{tide, terrain, wind, cloud, rain, sun}:
      (tide_a, tide_b) = tide_copy(tide)
      (terrain_a, terrain_b) = terrain_copy(terrain)
      (wind_a, wind_b) = wind_copy(wind)
      (cloud_a, cloud_b) = cloud_copy(cloud)
      (rain_a, rain_b) = rain_copy(rain)
      (sun_a, sun_b) = sun_copy(sun)
      BoundaryCopies{Boundary{tide_a, terrain_a, wind_a, cloud_a, rain_a, sun_a}, Boundary{tide_b, terrain_b, wind_b, cloud_b, rain_b, sun_b}}

assert tide_next_func:
  forall value: TidePhase
  TidePhase

def tide_next_func(value):
  match value:
    case TideLow{}: TideRisingOne{}
    case TideRisingOne{}: TideRisingTwo{}
    case TideRisingTwo{}: TideCrest{}
    case TideCrest{}: TideFallingOne{}
    case TideFallingOne{}: TideFallingTwo{}
    case TideFallingTwo{}: TideRest{}
    case TideRest{}: TideLow{}

assert tide_advance_seven_func:
  forall value: TidePhase
  TidePhase

def tide_advance_seven_func(value):
  tide_next_func(tide_next_func(tide_next_func(tide_next_func(tide_next_func(tide_next_func(tide_next_func(value)))))))

assert tide_cycle_theorem_func:
  forall value: TidePhase
  {tide_advance_seven_func(value) == value : TidePhase}

def tide_cycle_theorem_func(value):
  match value:
    case TideLow{}: {==}
    case TideRisingOne{}: {==}
    case TideRisingTwo{}: {==}
    case TideCrest{}: {==}
    case TideFallingOne{}: {==}
    case TideFallingTwo{}: {==}
    case TideRest{}: {==}

assert tide_height_nat_func:
  forall value: TidePhase
  Nat

def tide_height_nat_func(value):
  match value:
    case TideLow{}: 170n
    case TideRisingOne{}: 182n
    case TideRisingTwo{}: 194n
    case TideCrest{}: 206n
    case TideFallingOne{}: 194n
    case TideFallingTwo{}: 182n
    case TideRest{}: 170n

assert tide_height_func:
  forall value: TidePhase
  U32

def tide_height_func(value):
  U32.from_nat(tide_height_nat_func(value))

assert landscape_u32_distance_func:
  forall left: U32
  forall right: U32
  U32

def landscape_u32_distance_func(left, right):
  ((left_test, left_test_exact), (left_live, left_live_exact)) = U32.copy(left)
  ((right_test, right_test_exact), (right_live, right_live_exact)) = U32.copy(right)
  match U32.is_le(left_test, right_test):
    case True{}: U32.sub(right_live, left_live)
    case False{}: U32.sub(left_live, right_live)

# Mathematical one-step bound over the complete tide state space.
assert tide_softness_theorem_func:
  forall value: TidePhase
  { U32.is_le(landscape_u32_distance_func(tide_height_func(value), tide_height_func(tide_next_func(value))), landscape_u32_func(12n)) == True{} : Bool }

def tide_softness_theorem_func(value):
  match value:
    case TideLow{}: {==}
    case TideRisingOne{}: {==}
    case TideRisingTwo{}: {==}
    case TideCrest{}: {==}
    case TideFallingOne{}: {==}
    case TideFallingTwo{}: {==}
    case TideRest{}: {==}

assert terrain_next_func:
  forall value: TerrainBand
  TerrainBand

def terrain_next_func(value):
  match value:
    case TerrainShore{}: TerrainDune{}
    case TerrainDune{}: TerrainMeadow{}
    case TerrainMeadow{}: TerrainRise{}
    case TerrainRise{}: TerrainHill{}
    case TerrainHill{}: TerrainDescent{}
    case TerrainDescent{}: TerrainShore{}

assert terrain_height_nat_func:
  forall value: TerrainBand
  Nat

def terrain_height_nat_func(value):
  match value:
    case TerrainShore{}: 220n
    case TerrainDune{}: 238n
    case TerrainMeadow{}: 256n
    case TerrainRise{}: 274n
    case TerrainHill{}: 292n
    case TerrainDescent{}: 256n

assert terrain_height_func:
  forall value: TerrainBand
  U32

def terrain_height_func(value):
  U32.from_nat(terrain_height_nat_func(value))

assert terrain_softness_theorem_func:
  forall value: TerrainBand
  { U32.is_le(landscape_u32_distance_func(terrain_height_func(value), terrain_height_func(terrain_next_func(value))), landscape_u32_func(36n)) == True{} : Bool }

def terrain_softness_theorem_func(value):
  match value:
    case TerrainShore{}: {==}
    case TerrainDune{}: {==}
    case TerrainMeadow{}: {==}
    case TerrainRise{}: {==}
    case TerrainHill{}: {==}
    case TerrainDescent{}: {==}

assert wind_next_func:
  forall value: WindBand
  WindBand

def wind_next_func(value):
  match value:
    case WindCalm{}: WindBreeze{}
    case WindBreeze{}: WindFresh{}
    case WindFresh{}: WindStrong{}
    case WindStrong{}: WindGale{}
    case WindGale{}: WindBreeze{}

assert wind_force_func:
  forall value: WindBand
  U32

def wind_force_func(value):
  match value:
    case WindCalm{}: landscape_u32_func(8n)
    case WindBreeze{}: landscape_u32_func(24n)
    case WindFresh{}: landscape_u32_func(42n)
    case WindStrong{}: landscape_u32_func(66n)
    case WindGale{}: landscape_u32_func(88n)

assert cloud_next_func:
  forall value: CloudPhase
  CloudPhase

def cloud_next_func(value):
  match value:
    case CloudClear{}: CloudForming{}
    case CloudForming{}: CloudCharging{}
    case CloudCharging{}: CloudRainReady{}
    case CloudRainReady{}: CloudRaining{}
    case CloudRaining{}: CloudDissipating{}
    case CloudDissipating{}: CloudClear{}

assert cloud_advance_six_func:
  forall value: CloudPhase
  CloudPhase

def cloud_advance_six_func(value):
  cloud_next_func(cloud_next_func(cloud_next_func(cloud_next_func(cloud_next_func(cloud_next_func(value))))))

assert cloud_cycle_theorem_func:
  forall value: CloudPhase
  {cloud_advance_six_func(value) == value : CloudPhase}

def cloud_cycle_theorem_func(value):
  match value:
    case CloudClear{}: {==}
    case CloudForming{}: {==}
    case CloudCharging{}: {==}
    case CloudRainReady{}: {==}
    case CloudRaining{}: {==}
    case CloudDissipating{}: {==}

assert cloud_rain_func:
  forall value: CloudPhase
  RainBand

def cloud_rain_func(value):
  match value:
    case CloudClear{}: RainNone{}
    case CloudForming{}: RainNone{}
    case CloudCharging{}: RainDrizzle{}
    case CloudRainReady{}: RainSteady{}
    case CloudRaining{}: RainHeavy{}
    case CloudDissipating{}: RainDrizzle{}

assert cloud_sun_func:
  forall value: CloudPhase
  SunBand

def cloud_sun_func(value):
  match value:
    case CloudClear{}: SunBright{}
    case CloudForming{}: SunBright{}
    case CloudCharging{}: SunSoft{}
    case CloudRainReady{}: SunDim{}
    case CloudRaining{}: SunDim{}
    case CloudDissipating{}: SunSoft{}

assert rain_amount_func:
  forall value: RainBand
  U32

def rain_amount_func(value):
  match value:
    case RainNone{}: landscape_u32_func(0n)
    case RainDrizzle{}: landscape_u32_func(26n)
    case RainSteady{}: landscape_u32_func(58n)
    case RainHeavy{}: landscape_u32_func(92n)

assert sun_light_func:
  forall value: SunBand
  U32

def sun_light_func(value):
  match value:
    case SunDim{}: landscape_u32_func(105n)
    case SunSoft{}: landscape_u32_func(178n)
    case SunBright{}: landscape_u32_func(245n)

assert boundary_next_func:
  forall value: Boundary
  Boundary

def boundary_next_func(value):
  match value:
    case Boundary{tide, terrain, wind, cloud, rain, sun}:
      (cloud_next_field, cloud_rest) = cloud_copy(cloud_next_func(cloud))
      (cloud_for_rain, cloud_for_sun) = cloud_copy(cloud_rest)
      Boundary{tide_next_func(tide), terrain_next_func(terrain), wind_next_func(wind), cloud_next_field, cloud_rain_func(cloud_for_rain), cloud_sun_func(cloud_for_sun)}

# Key selection
# =============

assert landscape_u32_twelve_func:
  forall value: U32
  U32 & (U32 & (U32 & (U32 & (U32 & (U32 & (U32 & (U32 & (U32 & (U32 & (U32 & U32))))))))))

def landscape_u32_twelve_func(value):
  ((a, a_exact), (r1, r1_exact)) = U32.copy(value)
  ((b, b_exact), (r2, r2_exact)) = U32.copy(r1)
  ((c, c_exact), (r3, r3_exact)) = U32.copy(r2)
  ((d, d_exact), (r4, r4_exact)) = U32.copy(r3)
  ((e, e_exact), (r5, r5_exact)) = U32.copy(r4)
  ((f, f_exact), (r6, r6_exact)) = U32.copy(r5)
  ((g, g_exact), (r7, r7_exact)) = U32.copy(r6)
  ((h, h_exact), (r8, r8_exact)) = U32.copy(r7)
  ((i, i_exact), (r9, r9_exact)) = U32.copy(r8)
  ((j, j_exact), (r10, r10_exact)) = U32.copy(r9)
  ((k, k_exact), (l, l_exact)) = U32.copy(r10)
  (a, (b, (c, (d, (e, (f, (g, (h, (i, (j, (k, l)))))))))))

assert landscape_mix_func:
  forall key: U32
  forall index: U32
  U32

def landscape_mix_func(key, index):
  U32.add(U32.add(U32.mul(key, landscape_u32_func(61n)), U32.mul(index, landscape_u32_func(37n))), landscape_u32_func(17n))

assert whale_color_func:
  forall value: U32
  WhaleColor

def whale_color_func(value):
  ((test5, test5_exact), (rest5, rest5_exact)) = U32.copy(U32.mod(value, landscape_u32_func(16n)))
  match U32.is_le(test5, landscape_u32_func(5n)):
    case True{}: WhaleGrey{}
    case False{}:
      ((test9, test9_exact), (rest9, rest9_exact)) = U32.copy(rest5)
      match U32.is_le(test9, landscape_u32_func(9n)):
        case True{}: WhaleSlateBlue{}
        case False{}:
          ((test13, test13_exact), (rest13, rest13_exact)) = U32.copy(rest9)
          match U32.is_le(test13, landscape_u32_func(13n)):
            case True{}: WhaleOceanBlue{}
            case False{}:
              match U32.is_eq(rest13, landscape_u32_func(14n)):
                case True{}: WhaleWhiteMorph{}
                case False{}: WhaleBlackMorph{}

assert whale_size_func:
  forall value: U32
  WhaleSize

def whale_size_func(value):
  match U32.to_nat(U32.mod(value, landscape_u32_func(3n))):
    case 0n: WhaleJuvenile{}
    case 1n: WhaleAdult{}
    case other: WhaleGreat{}

assert whale_emergence_func:
  forall value: U32
  WhaleEmergence

def whale_emergence_func(value):
  match U32.to_nat(U32.mod(value, landscape_u32_func(5n))):
    case 0n: WhaleEmergence{10n, 0n, 20n, {==}, {==}}
    case 1n: WhaleEmergence{15n, 5n, 15n, {==}, {==}}
    case 2n: WhaleEmergence{20n, 10n, 10n, {==}, {==}}
    case 3n: WhaleEmergence{25n, 15n, 5n, {==}, {==}}
    case other: WhaleEmergence{30n, 20n, 0n, {==}, {==}}

assert whale_emergence_percent_func:
  forall value: WhaleEmergence
  Nat

def whale_emergence_percent_func(value):
  match value:
    case WhaleEmergence{percent, extra, slack, from_ten, fills_twenty}: percent

assert whale_emergence_physical_theorem_func:
  forall value: WhaleEmergence
  NatFromTenToThirty<whale_emergence_percent_func(value)>

def whale_emergence_physical_theorem_func(value):
  match value:
    case WhaleEmergence{percent, extra, slack, from_ten, fills_twenty}:
      NatFromTenToThirty{extra, slack, from_ten, fills_twenty}

assert whale_spout_func:
  forall value: U32
  SpoutState

def whale_spout_func(value):
  match U32.to_nat(U32.mod(value, landscape_u32_func(5n))):
    case 0n: SpoutState{True{}, 110n, 0n, {==}}
    case 1n: SpoutState{True{}, 75n, 35n, {==}}
    case 2n: SpoutState{True{}, 40n, 70n, {==}}
    case other: SpoutState{False{}, 0n, 110n, {==}}

assert whale_spout_volume_func:
  forall value: SpoutState
  Nat

def whale_spout_volume_func(value):
  match value:
    case SpoutState{active, volume, slack, fills_limit}: volume

assert whale_spout_physical_theorem_func:
  forall value: SpoutState
  NatAtMost<whale_spout_volume_func(value), 110n>

def whale_spout_physical_theorem_func(value):
  match value:
    case SpoutState{active, volume, slack, fills_limit}:
      NatAtMost{slack, fills_limit}

assert sand_layers_func:
  forall value: U32
  SandLayers

def sand_layers_func(value):
  match U32.to_nat(U32.mod(value, landscape_u32_func(5n))):
    case 0n: SandLayers{1n, 0n, 4n, {==}, {==}}
    case 1n: SandLayers{2n, 1n, 3n, {==}, {==}}
    case 2n: SandLayers{3n, 2n, 2n, {==}, {==}}
    case 3n: SandLayers{4n, 3n, 1n, {==}, {==}}
    case other: SandLayers{5n, 4n, 0n, {==}, {==}}

assert sand_layer_count_func:
  forall value: SandLayers
  Nat

def sand_layer_count_func(value):
  match value:
    case SandLayers{layers, extra, slack, from_one, fills_four}: layers

assert SandLayerCountClaim_func:
  forall value: SandLayers
  Type

def SandLayerCountClaim_func(value):
  NatFromOneToFive<sand_layer_count_func(value)>

assert sand_layer_count_theorem_func:
  forall value: SandLayers
  SandLayerCountClaim_func(value)

def sand_layer_count_theorem_func(value):
  match value:
    case SandLayers{layers, extra, slack, from_one, fills_four}:
      NatFromOneToFive{extra, slack, from_one, fills_four}

assert school_member_count_func:
  forall value: SchoolSize
  Nat

def school_member_count_func(value):
  match value:
    case SchoolSize{members, extra, slack, from_four, fills_eight}: members

assert school_size_bounded_theorem_func:
  forall value: SchoolSize
  NatFromFourToTwelve<school_member_count_func(value)>

def school_size_bounded_theorem_func(value):
  match value:
    case SchoolSize{members, extra, slack, from_four, fills_eight}:
      NatFromFourToTwelve{extra, slack, from_four, fills_eight}

assert human_party_count_func:
  forall value: HumanParty
  Nat

def human_party_count_func(value):
  match value:
    case HumanParty{people, count, extra, slack, length_exact, from_one, fills_two}: count

assert HumanPartyCountClaim_func:
  forall value: HumanParty
  Type

def HumanPartyCountClaim_func(value):
  NatFromOneToThree<human_party_count_func(value)>

assert human_party_count_theorem_func:
  forall value: HumanParty
  HumanPartyCountClaim_func(value)

def human_party_count_theorem_func(value):
  match value:
    case HumanParty{people, count, extra, slack, length_exact, from_one, fills_two}:
      NatFromOneToThree{extra, slack, from_one, fills_two}

# Entity generators
# =================

assert fish_species_func:
  forall value: U32
  FishSpecies

def fish_species_func(value):
  match U32.to_nat(U32.mod(value, landscape_u32_func(12n))):
    case 0n: Sardine{}
    case 1n: Anchovy{}
    case 2n: Mackerel{}
    case 3n: Tuna{}
    case 4n: FlyingFish{}
    case 5n: LanternFish{}
    case 6n: ReefBass{}
    case 7n: MoonJelly{}
    case 8n: Manta{}
    case 9n: Shark{}
    case 10n: Seahorse{}
    case other: RibbonEel{}

assert tree_species_func:
  forall value: U32
  TreeSpecies

def tree_species_func(value):
  match U32.to_nat(U32.mod(value, landscape_u32_func(8n))):
    case 0n: CoastOak{}
    case 1n: StonePine{}
    case 2n: WeepingWillow{}
    case 3n: FruitTree{}
    case 4n: Baobab{}
    case 5n: Mangrove{}
    case 6n: SilverBirch{}
    case other: Cypress{}

assert bird_species_func:
  forall value: U32
  BirdSpecies

def bird_species_func(value):
  match U32.to_nat(U32.mod(value, landscape_u32_func(8n))):
    case 0n: Gull{}
    case 1n: Tern{}
    case 2n: Heron{}
    case 3n: Swift{}
    case 4n: Kingfisher{}
    case 5n: Cormorant{}
    case 6n: SongThrush{}
    case other: Kite{}

assert landscape_whales_func:
  forall seed: U32
  List<WhaleModel>

def landscape_whales_func(seed):
  (s0, (s1, (s2, (s3, (s4, (s5, (s6, (s7, (s8, (s9, (s10, s11))))))))))) = landscape_u32_twelve_func(seed)
  Con{WhaleModel{0n, whale_color_func(s0), whale_size_func(s1), whale_emergence_func(s2), whale_spout_func(s3), U32.add(landscape_u32_func(130n), U32.mod(s4, landscape_u32_func(220n))), U32.mod(s5, landscape_u32_func(360n))},
  Con{WhaleModel{1n, whale_color_func(s6), whale_size_func(s7), whale_emergence_func(s8), whale_spout_func(s9), U32.add(landscape_u32_func(520n), U32.mod(s10, landscape_u32_func(180n))), U32.mod(s11, landscape_u32_func(360n))}, Nil{}}}

assert landscape_sea_rocks_func:
  forall seed: U32
  List<SeaRock>

def landscape_sea_rocks_func(seed):
  (s0, (s1, (s2, (s3, (s4, (s5, (s6, (s7, (s8, (s9, (s10, s11))))))))))) = landscape_u32_twelve_func(seed)
  Con{SeaRock{0n, SeaRockRound{}, RockLow{}, U32.add(landscape_u32_func(60n), U32.mod(s0, landscape_u32_func(120n))), U32.add(landscape_u32_func(55n), U32.mod(s1, landscape_u32_func(90n))), s2},
  Con{SeaRock{1n, SeaRockSharp{}, RockMedium{}, U32.add(landscape_u32_func(380n), U32.mod(s3, landscape_u32_func(100n))), U32.add(landscape_u32_func(70n), U32.mod(s4, landscape_u32_func(100n))), s5},
  Con{SeaRock{2n, SeaRockCluster{}, RockHigh{}, U32.add(landscape_u32_func(720n), U32.mod(s6, landscape_u32_func(80n))), U32.add(landscape_u32_func(80n), U32.mod(s7, landscape_u32_func(120n))), U32.add(U32.add(s8, s9), U32.add(s10, s11))}, Nil{}}}}

assert landscape_fish_func:
  forall seed: U32
  List<FishModel>

def landscape_fish_func(seed):
  (s0, (s1, (s2, (s3, (s4, (s5, (s6, (s7, (s8, (s9, (s10, s11))))))))))) = landscape_u32_twelve_func(seed)
  Con{FishModel{0n, fish_species_func(s0), FishCruising{}, landscape_u32_func(110n), landscape_u32_func(90n), landscape_u32_func(44n), s1, landscape_u32_func(1n)},
  Con{FishModel{1n, fish_species_func(s2), FishFleeing{}, landscape_u32_func(270n), landscape_u32_func(130n), landscape_u32_func(58n), s3, landscape_u32_func(2n)},
  Con{FishModel{2n, fish_species_func(s4), FishDiving{}, landscape_u32_func(450n), landscape_u32_func(170n), landscape_u32_func(70n), s5, landscape_u32_func(3n)},
  Con{FishModel{3n, fish_species_func(s6), FishFeeding{}, landscape_u32_func(640n), landscape_u32_func(115n), landscape_u32_func(50n), s7, landscape_u32_func(4n)},
  Con{FishModel{4n, fish_species_func(s8), FishFleeing{}, landscape_u32_func(790n), landscape_u32_func(155n), landscape_u32_func(62n), U32.add(U32.add(s9, s10), s11), landscape_u32_func(5n)}, Nil{}}}}}}

assert landscape_nat_six_func:
  forall value: Nat
  Nat & (Nat & (Nat & (Nat & (Nat & Nat))))

def landscape_nat_six_func(value):
  ((a, a_exact), (r1, r1_exact)) = Nat.copy(value)
  ((b, b_exact), (r2, r2_exact)) = Nat.copy(r1)
  ((c, c_exact), (r3, r3_exact)) = Nat.copy(r2)
  ((d, d_exact), (r4, r4_exact)) = Nat.copy(r3)
  ((e, e_exact), (f, f_exact)) = Nat.copy(r4)
  (a, (b, (c, (d, (e, f)))))

# School membership is generated together with its exact cardinality proof.
# The recursion is over arbitrary fuel, so this is not a finite size table.
assert landscape_school_members_claim_func:
  forall fuel: Nat
  forall id: Nat
  VerifiedSchoolMembers<fuel>

def landscape_school_members_claim_func(fuel, id):
  match fuel:
    case 0n:
      VerifiedSchoolMembers{Nil{}, {==}}
    case 1n+pred:
      (i0, (i1, (i2, (i3, (i4, i5))))) = landscape_nat_six_func(id)
      match landscape_school_members_claim_func(pred, 1n+i5):
        case VerifiedSchoolMembers{tail, tail_exact}:
          VerifiedSchoolMembers{
            Con{SchoolMember{i0, Nat.mul(i1, 13n), Nat.mod(Nat.mul(i2, 7n), 5n), Nat.mod(Nat.mul(i3, 11n), 9n), Nat.mul(i4, 17n)}, tail},
            Equal.cong(Nat, Nat, count => 1n+count, List.length(SchoolMember, tail), pred, tail_exact)
          }

assert landscape_school_member_payload_func:
  forall value: SchoolMember
  SchoolMemberPayload

def landscape_school_member_payload_func(value):
  match value:
    case SchoolMember{id, offset_x, offset_y, offset_z, heading}:
      SchoolMemberPayload{id}

assert landscape_school_payload_func:
  forall values: List<SchoolMember>
  List<SchoolMemberPayload>

def landscape_school_payload_func(values):
  match values:
    case Nil{}: Nil{}
    case Con{head, tail}:
      Con{landscape_school_member_payload_func(head), landscape_school_payload_func(tail)}

assert landscape_school_impulse_copy_func:
  forall value: SchoolImpulse
  SchoolImpulse & SchoolImpulse

def landscape_school_impulse_copy_func(value):
  match value:
    case SchoolCurrent{dx, dz}:
      ((dx_left, dx_left_exact), (dx_right, dx_right_exact)) = Nat.copy(dx)
      ((dz_left, dz_left_exact), (dz_right, dz_right_exact)) = Nat.copy(dz)
      (SchoolCurrent{dx_left, dz_left}, SchoolCurrent{dx_right, dz_right})
    case SchoolFlee{distance}:
      ((left, left_exact), (right, right_exact)) = Nat.copy(distance)
      (SchoolFlee{left}, SchoolFlee{right})
    case SchoolDive{depth}:
      ((left, left_exact), (right, right_exact)) = Nat.copy(depth)
      (SchoolDive{left}, SchoolDive{right})

assert landscape_school_member_step_func:
  forall value: SchoolMember
  forall impulse: SchoolImpulse
  SchoolMember

def landscape_school_member_step_func(value, impulse):
  match value impulse:
    case SchoolMember{id, x, y, z, heading} SchoolCurrent{dx, dz}:
      SchoolMember{id, Nat.add(x, dx), y, Nat.add(z, dz), heading}
    case SchoolMember{id, x, y, z, heading} SchoolFlee{distance}:
      SchoolMember{id, Nat.add(x, distance), y, z, heading}
    case SchoolMember{id, x, y, z, heading} SchoolDive{depth}:
      SchoolMember{id, x, Nat.add(y, depth), z, heading}

assert landscape_school_member_step_payload_theorem_func:
  forall value: SchoolMember
  forall impulse: SchoolImpulse
  { landscape_school_member_payload_func(landscape_school_member_step_func(value, impulse)) == landscape_school_member_payload_func(value) : SchoolMemberPayload }

def landscape_school_member_step_payload_theorem_func(value, impulse):
  match value impulse:
    case SchoolMember{id, x, y, z, heading} SchoolCurrent{dx, dz}: {==}
    case SchoolMember{id, x, y, z, heading} SchoolFlee{distance}: {==}
    case SchoolMember{id, x, y, z, heading} SchoolDive{depth}: {==}

# THE SCHOOL STEP LEMMA. It structurally transforms an arbitrary membership
# list while congruence preserves its complete ordered identity payload.
assert landscape_school_step_claim_func:
  forall values: List<SchoolMember>
  forall impulse: SchoolImpulse
  Claim<List<SchoolMember>, output => { landscape_school_payload_func(output) == landscape_school_payload_func(values) : List<SchoolMemberPayload> }>

def landscape_school_step_claim_func(values, impulse):
  match values:
    case Nil{}:
      Claim{Nil{}, {==}}
    case Con{SchoolMember{id, x, y, z, heading}, tail}:
      (head_impulse, tail_impulse) = landscape_school_impulse_copy_func(impulse)
      match landscape_school_step_claim_func(tail, tail_impulse):
        case Claim{tail_output, tail_proof}:
          Claim{
            Con{landscape_school_member_step_func(SchoolMember{id, x, y, z, heading}, head_impulse), tail_output},
            Equal.trans(
              List<SchoolMemberPayload>,
              Con{landscape_school_member_payload_func(landscape_school_member_step_func(SchoolMember{id, x, y, z, heading}, head_impulse)), landscape_school_payload_func(tail_output)},
              Con{SchoolMemberPayload{id}, landscape_school_payload_func(tail_output)},
              Con{SchoolMemberPayload{id}, landscape_school_payload_func(tail)},
              Equal.cong(
                SchoolMemberPayload,
                List<SchoolMemberPayload>,
                head => Con{head, landscape_school_payload_func(tail_output)},
                landscape_school_member_payload_func(landscape_school_member_step_func(SchoolMember{id, x, y, z, heading}, head_impulse)),
                SchoolMemberPayload{id},
                landscape_school_member_step_payload_theorem_func(SchoolMember{id, x, y, z, heading}, head_impulse)
              ),
              Equal.cong(
                List<SchoolMemberPayload>,
                List<SchoolMemberPayload>,
                rest => Con{SchoolMemberPayload{id}, rest},
                landscape_school_payload_func(tail_output),
                landscape_school_payload_func(tail),
                tail_proof
              )
            )
          }

assert landscape_school_history_claim_func:
  forall history: SchoolHistory
  forall values: List<SchoolMember>
  Claim<List<SchoolMember>, output => { landscape_school_payload_func(output) == landscape_school_payload_func(values) : List<SchoolMemberPayload> }>

def landscape_school_history_claim_func(history, values):
  match history:
    case SchoolHistoryEnd{}:
      Claim{values, {==}}
    case SchoolHistoryStep{impulse, tail}:
      match landscape_school_step_claim_func(values, impulse):
        case Claim{stepped, step_proof}:
          match landscape_school_history_claim_func(tail, stepped):
            case Claim{output, history_proof}:
              Claim{
                output,
                Equal.trans(
                  List<SchoolMemberPayload>,
                  landscape_school_payload_func(output),
                  landscape_school_payload_func(stepped),
                  landscape_school_payload_func(values),
                  history_proof,
                  step_proof
                )
              }

assert landscape_schools_func:
  forall seed: U32
  List<SchoolModel>

def landscape_schools_func(seed):
  ((a, a_exact), (b, b_exact)) = U32.copy(seed)
  match landscape_school_members_claim_func(12n, 0n):
    case VerifiedSchoolMembers{twelve, twelve_exact}:
      match landscape_school_members_claim_func(8n, 0n):
        case VerifiedSchoolMembers{eight, eight_exact}:
          Con{SchoolModel{0n, Sardine{}, SchoolSize{12n, 8n, 0n, {==}, {==}}, twelve, landscape_u32_func(240n), landscape_u32_func(120n), a, landscape_u32_func(235n), landscape_u32_func(180n)},
          Con{SchoolModel{1n, Mackerel{}, SchoolSize{8n, 4n, 4n, {==}, {==}}, eight, landscape_u32_func(610n), landscape_u32_func(180n), b, landscape_u32_func(220n), landscape_u32_func(230n)}, Nil{}}}

assert fruit_state_func:
  forall seed: U32
  forall wind: WindBand
  FruitState

def fruit_state_func(seed, wind):
  match wind:
    case WindGale{}:
      ((seed_count, seed_count_exact), (seed_phase, seed_phase_exact)) = U32.copy(seed)
      FruitFalling{U32.add(landscape_u32_func(2n), U32.mod(seed_count, landscape_u32_func(7n))), U32.mod(seed_phase, landscape_u32_func(120n))}
    case WindStrong{}:
      ((seed_count, seed_count_exact), (seed_phase, seed_phase_exact)) = U32.copy(seed)
      FruitFalling{U32.add(landscape_u32_func(1n), U32.mod(seed_count, landscape_u32_func(5n))), U32.mod(seed_phase, landscape_u32_func(90n))}
    case other: FruitHanging{U32.add(landscape_u32_func(3n), U32.mod(seed, landscape_u32_func(9n)))}

assert landscape_trees_func:
  forall seed: U32
  forall wind: WindBand
  List<TreeModel>

def landscape_trees_func(seed, wind):
  (s0, (s1, (s2, (s3, (s4, (s5, (s6, (s7, (s8, (s9, (s10, s11))))))))))) = landscape_u32_twelve_func(seed)
  (wind_a, wind_b) = wind_copy(wind)
  Con{TreeModel{0n, tree_species_func(s0), landscape_u32_func(80n), landscape_u32_func(210n), landscape_u32_func(150n), landscape_u32_func(18n), landscape_u32_func(44n), landscape_u32_func(235n), landscape_u32_func(90n), fruit_state_func(s1, wind_a)},
  Con{TreeModel{1n, tree_species_func(s2), landscape_u32_func(245n), landscape_u32_func(270n), landscape_u32_func(180n), landscape_u32_func(26n), landscape_u32_func(72n), landscape_u32_func(185n), landscape_u32_func(120n), FruitAbsent{}},
  Con{TreeModel{2n, tree_species_func(s3), landscape_u32_func(420n), landscape_u32_func(235n), landscape_u32_func(200n), landscape_u32_func(34n), landscape_u32_func(96n), landscape_u32_func(210n), landscape_u32_func(140n), fruit_state_func(s4, wind_b)},
  Con{TreeModel{3n, tree_species_func(s5), landscape_u32_func(610n), landscape_u32_func(310n), landscape_u32_func(230n), landscape_u32_func(30n), landscape_u32_func(58n), landscape_u32_func(160n), landscape_u32_func(170n), FruitAbsent{}},
  Con{TreeModel{4n, tree_species_func(s6), landscape_u32_func(790n), U32.add(landscape_u32_func(190n), U32.mod(s7, landscape_u32_func(120n))), U32.add(landscape_u32_func(130n), U32.mod(s8, landscape_u32_func(100n))), U32.add(landscape_u32_func(15n), U32.mod(s9, landscape_u32_func(25n))), U32.mod(s10, landscape_u32_func(110n)), U32.add(landscape_u32_func(120n), U32.mod(s11, landscape_u32_func(130n))), landscape_u32_func(200n), FruitAbsent{}}, Nil{}}}}}}

assert landscape_hills_func:
  forall seed: U32
  List<HillModel>

def landscape_hills_func(seed):
  (s0, (s1, (s2, (s3, (s4, (s5, (s6, (s7, (s8, (s9, (s10, s11))))))))))) = landscape_u32_twelve_func(seed)
  Con{HillModel{0n, RollingHill{}, landscape_u32_func(160n), U32.add(landscape_u32_func(80n), U32.mod(s0, landscape_u32_func(70n))), landscape_u32_func(260n), U32.add(landscape_u32_func(24n), U32.mod(s1, landscape_u32_func(40n)))},
  Con{HillModel{1n, RockyRise{}, landscape_u32_func(500n), U32.add(landscape_u32_func(100n), U32.mod(s2, landscape_u32_func(90n))), landscape_u32_func(220n), U32.add(landscape_u32_func(35n), U32.mod(s3, landscape_u32_func(60n)))},
  Con{HillModel{2n, LayeredCliff{}, landscape_u32_func(760n), U32.add(landscape_u32_func(90n), U32.mod(s4, landscape_u32_func(100n))), U32.add(landscape_u32_func(180n), U32.mod(s5, landscape_u32_func(120n))), U32.add(landscape_u32_func(42n), U32.mod(U32.add(U32.add(s6, s7), U32.add(U32.add(s8, s9), U32.add(s10, s11))), landscape_u32_func(80n)))}, Nil{}}}}

assert landscape_humans_dispatch_func:
  forall choice: Nat
  forall seed: U32
  HumanParty

def landscape_humans_dispatch_func(choice, seed):
  match choice:
    case 0n:
      HumanParty{
        Con{HumanModel{0n, SkinOlive{}, BodyMedium{}, ClothesWalker{}, Wanderer{}, HumanStroll{}, landscape_u32_func(340n), seed}, Nil{}},
        1n, 0n, 2n, {==}, {==}, {==}
      }
    case 1n:
      ((seed_first, seed_first_exact), (seed_second, seed_second_exact)) = U32.copy(seed)
      HumanParty{
        Con{HumanModel{0n, SkinBrown{}, BodyTall{}, ClothesWorker{}, Industrious{}, HumanCutTree{2n}, landscape_u32_func(300n), seed_first}, Con{HumanModel{1n, SkinLight{}, BodySmall{}, ClothesGatherer{}, Social{}, HumanGather{0n}, landscape_u32_func(430n), U32.add(seed_second, landscape_u32_func(41n))}, Nil{}}},
        2n, 1n, 1n, {==}, {==}, {==}
      }
    case other:
      (seed_first, (seed_second, (seed_third, (seed_spare_a, (seed_spare_b, (seed_spare_c, (seed_spare_d, (seed_spare_e, (seed_spare_f, (seed_spare_g, (seed_spare_h, seed_spare_i))))))))))) = landscape_u32_twelve_func(seed)
      HumanParty{
        Con{HumanModel{0n, SkinDeep{}, BodyMedium{}, ClothesWorker{}, Industrious{}, HumanDigRock{1n}, landscape_u32_func(260n), seed_first}, Con{HumanModel{1n, SkinPorcelain{}, BodyTall{}, ClothesGatherer{}, Curious{}, HumanHarvestTree{0n}, landscape_u32_func(470n), U32.add(seed_second, landscape_u32_func(29n))}, Con{HumanModel{2n, SkinOlive{}, BodySmall{}, ClothesRaincoat{}, Cautious{}, HumanShelter{3n}, landscape_u32_func(690n), U32.add(seed_third, landscape_u32_func(73n))}, Nil{}}}},
        3n, 2n, 0n, {==}, {==}, {==}
      }

assert landscape_humans_func:
  forall seed: U32
  HumanParty

def landscape_humans_func(seed):
  ((seed_test, seed_test_exact), (seed_live, seed_live_exact)) = U32.copy(seed)
  landscape_humans_dispatch_func(U32.to_nat(U32.mod(seed_test, landscape_u32_func(3n))), seed_live)

assert landscape_birds_func:
  forall seed: U32
  forall rain: RainBand
  List<BirdModel>

def landscape_birds_func(seed, rain):
  match rain:
    case RainHeavy{}:
      (s0, (s1, (s2, (s3, (s4, (s5, (s6, (s7, (s8, (s9, (s10, s11))))))))))) = landscape_u32_twelve_func(seed)
      Con{BirdModel{0n, bird_species_func(s0), CallSilent{}, BirdSheltering{1n}, landscape_u32_func(180n), landscape_u32_func(330n), landscape_u32_func(34n), s1, s2}, Con{BirdModel{1n, bird_species_func(s3), CallCry{}, BirdPerchedTree{3n}, landscape_u32_func(600n), landscape_u32_func(350n), landscape_u32_func(40n), s4, s5}, Nil{}}}
    case other:
      (s0, (s1, (s2, (s3, (s4, (s5, (s6, (s7, (s8, (s9, (s10, s11))))))))))) = landscape_u32_twelve_func(seed)
      Con{BirdModel{0n, bird_species_func(s0), CallCry{}, BirdFlying{}, landscape_u32_func(100n), landscape_u32_func(520n), landscape_u32_func(34n), s1, s2}, Con{BirdModel{1n, bird_species_func(s3), CallTrill{}, BirdPerchedTree{1n}, landscape_u32_func(330n), landscape_u32_func(390n), landscape_u32_func(28n), s4, s5}, Con{BirdModel{2n, bird_species_func(s6), CallWhistle{}, BirdFlying{}, landscape_u32_func(560n), landscape_u32_func(610n), landscape_u32_func(31n), s7, s8}, Con{BirdModel{3n, bird_species_func(s9), CallChirp{}, BirdPerchedRock{2n}, landscape_u32_func(790n), landscape_u32_func(430n), landscape_u32_func(38n), s10, s11}, Nil{}}}}}

assert landscape_clouds_func:
  forall seed: U32
  forall phase: CloudPhase
  List<CloudModel>

def landscape_clouds_func(seed, phase):
  (s0, (s1, (s2, (s3, (s4, (s5, (s6, (s7, (s8, (s9, (s10, s11))))))))))) = landscape_u32_twelve_func(seed)
  (phase_a, phase_b) = cloud_copy(phase)
  Con{CloudModel{0n, CloudPuff{}, CloudMedium{}, phase_a, U32.add(landscape_u32_func(120n), U32.mod(s0, landscape_u32_func(180n))), landscape_u32_func(640n), U32.add(landscape_u32_func(120n), U32.mod(s1, landscape_u32_func(100n))), s2},
  Con{CloudModel{1n, CloudLayer{}, CloudLarge{}, phase_b, U32.add(landscape_u32_func(430n), U32.mod(s3, landscape_u32_func(160n))), landscape_u32_func(700n), U32.add(landscape_u32_func(140n), U32.mod(s4, landscape_u32_func(95n))), s5},
  Con{CloudModel{2n, CloudTower{}, CloudMerged{}, CloudCharging{}, U32.add(landscape_u32_func(710n), U32.mod(s6, landscape_u32_func(100n))), U32.add(landscape_u32_func(660n), U32.mod(s7, landscape_u32_func(90n))), U32.add(landscape_u32_func(155n), U32.mod(s8, landscape_u32_func(85n))), U32.add(U32.add(s9, s10), s11)}, Nil{}}}}

# Chunk construction and proof-carrying scrolling
# ===============================================

assert landscape_chunk_boundary_func:
  forall value: LandscapeChunk
  Boundary

def landscape_chunk_boundary_func(value):
  match value:
    case LandscapeChunk{key, index, origin, boundary, sea, land, sky, weather, placements}: boundary

assert landscape_step_chunk_boundary_func:
  forall value: ChunkStep
  Boundary

def landscape_step_chunk_boundary_func(value):
  match value:
    case ChunkStep{chunk, next}: landscape_chunk_boundary_func(chunk)

assert landscape_chunk_from_boundary_func:
  forall key: U32
  forall index: U32
  forall boundary: Boundary
  LandscapeChunk

def landscape_chunk_from_boundary_func(key, index, boundary):
  match boundary:
    case Boundary{tide, terrain, wind, cloud, rain, sun}:
      (tide_boundary, tide_rest) = tide_copy(tide)
      (tide_water, tide_rest_two) = tide_copy(tide_rest)
      (tide_weather_field, tide_weather_height) = tide_copy(tide_rest_two)
      (terrain_boundary, terrain_land) = terrain_copy(terrain)
      (wind_boundary, wind_rest) = wind_copy(wind)
      (wind_tree, wind_rest_two) = wind_copy(wind_rest)
      (wind_weather_field, wind_weather_force) = wind_copy(wind_rest_two)
      (cloud_boundary, cloud_rest) = cloud_copy(cloud)
      (cloud_models, cloud_weather_field) = cloud_copy(cloud_rest)
      (rain_boundary, rain_rest) = rain_copy(rain)
      (rain_birds, rain_rest_two) = rain_copy(rain_rest)
      (rain_weather_field, rain_weather_amount) = rain_copy(rain_rest_two)
      (sun_boundary, sun_rest) = sun_copy(sun)
      (sun_weather_field, sun_weather_light) = sun_copy(sun_rest)
      ((index_mix, index_mix_exact), (index_rest, index_rest_exact)) = U32.copy(index)
      ((index_field, index_field_exact), (index_origin, index_origin_exact)) = U32.copy(index_rest)
      (mix_whale, (mix_rock, (mix_fish, (mix_school, (mix_tree, (mix_hill, (mix_human, (mix_bird, (mix_cloud, (mix_sand, (mix_output, mix_spare))))))))))) = landscape_u32_twelve_func(landscape_mix_func(key, index_mix))
      LandscapeChunk{
        mix_output,
        index_field,
        U32.mul(index_origin, landscape_u32_func(900n)),
        Boundary{tide_boundary, terrain_boundary, wind_boundary, cloud_boundary, rain_boundary, sun_boundary},
        SeaSector{tide_height_func(tide_water), sand_layers_func(mix_sand), landscape_whales_func(mix_whale), landscape_sea_rocks_func(mix_rock), landscape_fish_func(mix_fish), landscape_schools_func(mix_school)},
        LandSector{terrain_land, landscape_trees_func(mix_tree, wind_tree), landscape_hills_func(mix_hill), landscape_humans_func(mix_human)},
        SkySector{landscape_birds_func(mix_bird, rain_birds), landscape_clouds_func(mix_cloud, cloud_models)},
        Weather{wind_weather_field, tide_weather_field, cloud_weather_field, rain_weather_field, sun_weather_field, wind_force_func(wind_weather_force), tide_height_func(tide_weather_height), rain_amount_func(rain_weather_amount), sun_light_func(sun_weather_light)},
        PlacementCertificate{landscape_u32_func(12n), landscape_u32_func(11n), landscape_u32_func(8n), landscape_u32_func(54n)}
      }

assert landscape_step_func:
  forall key: U32
  forall index: U32
  forall boundary: Boundary
  ChunkStep

def landscape_step_func(key, index, boundary):
  match boundary_copy(boundary):
    case BoundaryCopies{for_chunk, for_next}:
      ChunkStep{landscape_chunk_from_boundary_func(key, index, for_chunk), boundary_next_func(for_next)}

assert landscape_next_chunk_func:
  forall key: U32
  forall index: U32
  forall boundary: Boundary
  ChunkStep

def landscape_next_chunk_func(key, index, boundary):
  landscape_step_func(key, index, boundary)

assert landscape_verified_chunks_func:
  forall fuel: Nat
  forall key: U32
  forall index: U32
  forall boundary: Boundary
  VerifiedChunks<fuel>

def landscape_verified_chunks_func(fuel, key, index, boundary):
  match fuel:
    case 0n: VerifiedChunks{Nil{}, boundary, {==}}
    case 1n+pred:
      ((key_head, key_head_exact), (key_tail, key_tail_exact)) = U32.copy(key)
      ((index_head, index_head_exact), (index_tail, index_tail_exact)) = U32.copy(index)
      match landscape_step_func(key_head, index_head, boundary):
        case ChunkStep{chunk, next_boundary}:
          match boundary_copy(next_boundary):
            case BoundaryCopies{next_for_tail, next_output}:
              match landscape_verified_chunks_func(pred, key_tail, U32.inc(index_tail), next_for_tail):
                case VerifiedChunks{tail, final_boundary, tail_exact}:
                  VerifiedChunks{Con{chunk, tail}, final_boundary, Equal.cong(Nat, Nat, length => 1n+length, List.length(LandscapeChunk, tail), pred, tail_exact)}

assert landscape_initial_tide_func:
  forall key: U32
  TidePhase

def landscape_initial_tide_func(key):
  match U32.to_nat(U32.mod(key, landscape_u32_func(7n))):
    case 0n: TideLow{}
    case 1n: TideRisingOne{}
    case 2n: TideRisingTwo{}
    case 3n: TideCrest{}
    case 4n: TideFallingOne{}
    case 5n: TideFallingTwo{}
    case other: TideRest{}

assert landscape_initial_boundary_func:
  forall key: U32
  Boundary

def landscape_initial_boundary_func(key):
  Boundary{landscape_initial_tide_func(key), TerrainShore{}, WindBreeze{}, CloudForming{}, RainNone{}, SunBright{}}

assert landscape_default_step_func:
  forall key: U32
  ChunkStep

def landscape_default_step_func(key):
  ((key_step, key_step_exact), (key_boundary, key_boundary_exact)) = U32.copy(key)
  landscape_next_chunk_func(key_step, 0, landscape_initial_boundary_func(key_boundary))

assert landscape_self_check_func:
  Bool

def landscape_self_check_func():
  match landscape_verified_chunks_func(9n, landscape_u32_func(731n), 0, landscape_initial_boundary_func(landscape_u32_func(731n))):
    case VerifiedChunks{chunks, next, length_exact}: Nat.is_eq(List.length(LandscapeChunk, chunks), 9n)

assert main_value:
  LandscapeReport

def main_value():
  ((key_output, key_output_exact), (key_step, key_step_exact)) = U32.copy(landscape_u32_func(731n))
  LandscapeReport{"Bend Landscape", key_output, landscape_default_step_func(key_step), landscape_u32_func(12n), landscape_u32_func(6n)}

assert main_accept_value:
  forall value: LandscapeReport
  IO(Unit)

def main_accept_value(value):
  IO.print("Ready{}")

assert main:
  IO(Unit)

def main():
  main_accept_value(main_value!())
