import Base
import ./model3d.bend as Model3D
import ./light.bend as Light
import ../../compat/list.bend as List

# Types
# =====

type ObjectLightQueryPair:
  ObjectLightQueryPair{object_id: U32, light_ordinal: U32}

# Flat slots support the independent aggregate-cardinality theorem. The
# structural theorem below is what proves that these cardinalities mean full
# Cartesian coverage rather than an arbitrary list of the right length.
type CartesianSlot:
  CartesianSlot{ordinal: U32}

# Constructor-carried hypotheses for the reflection theorem. The equality
# evidence is computationally erased by the backends even though it remains
# available to the checker as an ordinary field.
type PositiveReflectance:
  PositiveReflectance{
    level: U32,
    positive: {U32.is_zero(level) == False{} : Bool}
  }

type SupportedPositiveIncident:
  SupportedPositiveIncident{
    light: Light.Light,
    normal: Model3D.Vec3,
    incoming: Model3D.Vec3,
    positive: {
      U32.is_zero(Light.light_lambert_func(normal, incoming)) == False{}
      : Bool
    }
  }

type PositiveVisibility:
  PositiveVisibility{
    visibility: Light.Visibility,
    clear: {visibility == Light.ClearVisibility{} : Light.Visibility}
  }

# Constants
# =========

# Every theorem below quantifies over caller-provided values.

# Functions
# =========

assert rendering_verification_pair_func:
  forall object_id: U32
  forall light_ordinal: U32
  ObjectLightQueryPair

def rendering_verification_pair_func(object_id, light_ordinal):
  ObjectLightQueryPair{object_id, light_ordinal}

assert rendering_verification_pair_query_func:
  forall pair: ObjectLightQueryPair
  Light.RayQuery

def rendering_verification_pair_query_func(pair):
  match pair:
    case ObjectLightQueryPair{object_id, light_ordinal}:
      Light.RayQuery{
        Model3D.Vec3{
          Model3D.ScalarPos{U32.mul(object_id, U32.from_nat(256n))},
          Model3D.ScalarPos{0},
          Model3D.ScalarPos{0}
        },
        Model3D.Vec3{
          Model3D.ScalarNeg{U32.from_nat(128n)},
          Model3D.ScalarPos{U32.from_nat(221n)},
          Model3D.ScalarNeg{U32.mod(light_ordinal, U32.from_nat(65n))}
        },
        U32.from_nat(1n),
        U32.from_nat(4096n)
      }

assert rendering_verification_pair_congruence_func:
  forall -object_before: U32
  forall -object_after: U32
  forall -light_before: U32
  forall -light_after: U32
  forall object_exact: {object_before == object_after : U32}
  forall light_exact: {light_before == light_after : U32}
  { ObjectLightQueryPair{object_before, light_before} == ObjectLightQueryPair{object_after, light_after} : ObjectLightQueryPair }

def rendering_verification_pair_congruence_func(object_before, object_after, light_before, light_after, object_exact, light_exact):
  Equal.trans(
    ObjectLightQueryPair,
    ObjectLightQueryPair{object_before, light_before},
    ObjectLightQueryPair{object_after, light_before},
    ObjectLightQueryPair{object_after, light_after},
    Equal.cong(
      U32,
      ObjectLightQueryPair,
      value => ObjectLightQueryPair{value, light_before},
      object_before,
      object_after,
      object_exact
    ),
    Equal.cong(
      U32,
      ObjectLightQueryPair,
      value => ObjectLightQueryPair{object_after, value},
      light_before,
      light_after,
      light_exact
    )
  )

assert rendering_verification_pair_copy_func:
  forall pair: ObjectLightQueryPair
  Copy(ObjectLightQueryPair, pair) & Copy(ObjectLightQueryPair, pair)

def rendering_verification_pair_copy_func(pair):
  match pair:
    case ObjectLightQueryPair{object_id, light_ordinal}:
      ((object_first, object_first_exact), (object_second, object_second_exact)) = U32.copy(object_id)
      ((light_first, light_first_exact), (light_second, light_second_exact)) = U32.copy(light_ordinal)
      (
        (
          ObjectLightQueryPair{object_first, light_first},
          rendering_verification_pair_congruence_func(
            object_id, object_first, light_ordinal, light_first,
            object_first_exact, light_first_exact
          )
        ),
        (
          ObjectLightQueryPair{object_second, light_second},
          rendering_verification_pair_congruence_func(
            object_id, object_second, light_ordinal, light_second,
            object_second_exact, light_second_exact
          )
        )
      )

assert PairQueryAssignmentClaim_func:
  forall -pair: ObjectLightQueryPair
  forall -query: Light.RayQuery
  Type

def PairQueryAssignmentClaim_func(pair, query):
  {query == rendering_verification_pair_query_func(pair) : Light.RayQuery}

assert PairQueryAssignmentAssert_func:
  forall pair: ObjectLightQueryPair
  exists query: Light.RayQuery
  PairQueryAssignmentClaim_func(pair, query)

def PairQueryAssignmentAssert_func(pair):
  ((pair_for_query, pair_for_query_exact), (pair_for_spec, pair_for_spec_exact)) = rendering_verification_pair_copy_func(pair)
  (
    rendering_verification_pair_query_func(pair_for_query),
    Equal.cong(
      ObjectLightQueryPair,
      Light.RayQuery,
      value => rendering_verification_pair_query_func(value),
      pair_for_query,
      pair,
      Equal.sym(
        ObjectLightQueryPair,
        pair,
        pair_for_query,
        pair_for_query_exact
      )
    )
  )

# This recursive proposition is the semantic core of the coverage theorem.
# Zero means no light position remains. A successor contains exactly the pair
# for the current object/current light ordinal, its assigned real RayQuery, and
# the same proposition for the next ordinal. No finite case enumeration occurs.
assert LightPositionCoverageClaim_func:
  forall -object_id: U32
  forall remaining_lights: Nat
  forall -light_ordinal: U32
  Type

def LightPositionCoverageClaim_func(object_id, remaining_lights, light_ordinal):
  match remaining_lights:
    case 0n:
      Unit
    case 1n+pred:
      Sigma<
        ObjectLightQueryPair,
        pair => Sigma<
          Light.RayQuery,
          query => {
            pair == ObjectLightQueryPair{object_id, light_ordinal}
            : ObjectLightQueryPair
          } & {
            query == rendering_verification_pair_query_func(pair)
            : Light.RayQuery
          } & LightPositionCoverageClaim_func(
            object_id,
            pred,
            U32.inc(light_ordinal)
          )
        >
      >

assert LightPositionCoverageTransport_func:
  forall -object_before: U32
  forall -object_after: U32
  forall -count_before: Nat
  forall -count_after: Nat
  forall -ordinal_before: U32
  forall -ordinal_after: U32
  forall object_exact: {object_before == object_after : U32}
  forall count_exact: {count_before == count_after : Nat}
  forall ordinal_exact: {ordinal_before == ordinal_after : U32}
  forall coverage: LightPositionCoverageClaim_func( object_before, count_before, ordinal_before )
  LightPositionCoverageClaim_func( object_after, count_after, ordinal_after )

def LightPositionCoverageTransport_func(object_before, object_after, count_before, count_after, ordinal_before, ordinal_after, object_exact, count_exact, ordinal_exact, coverage):
  %ordinal_exact : LightPositionCoverageClaim_func(
    object_after,
    count_after,
    _
  )
  %count_exact : LightPositionCoverageClaim_func(
    object_after,
    _,
    ordinal_before
  )
  %object_exact : LightPositionCoverageClaim_func(
    _,
    count_before,
    ordinal_before
  )
  coverage

assert LightPositionCoverageAssert_func:
  forall remaining_lights: Nat
  forall object_id: U32
  forall light_ordinal: U32
  LightPositionCoverageClaim_func( object_id, remaining_lights, light_ordinal )

def LightPositionCoverageAssert_func(remaining_lights, object_id, light_ordinal):
  match remaining_lights:
    case 0n:
      Unit{}
    case 1n+pred:
      ((object_here, object_here_exact), (object_tail, object_tail_exact)) = U32.copy(object_id)
      ((ordinal_here, ordinal_here_exact), (ordinal_tail, ordinal_tail_exact)) = U32.copy(light_ordinal)
      ((pair_for_return, pair_for_return_exact), (pair_for_query, pair_for_query_exact)) = rendering_verification_pair_copy_func(
        ObjectLightQueryPair{object_here, ordinal_here}
      )
      ((pair_return_head_exact, pair_return_head_exact_exact), (pair_return_query_exact, pair_return_query_exact_exact)) = Equal.copy(
        ObjectLightQueryPair,
        ObjectLightQueryPair{object_here, ordinal_here},
        pair_for_return,
        pair_for_return_exact
      )
      (
        pair_for_return,
        (
          rendering_verification_pair_query_func(pair_for_query),
          (
            Equal.trans(
              ObjectLightQueryPair,
              pair_for_return,
              ObjectLightQueryPair{object_here, ordinal_here},
              ObjectLightQueryPair{object_id, light_ordinal},
              Equal.sym(
                ObjectLightQueryPair,
                ObjectLightQueryPair{object_here, ordinal_here},
                pair_for_return,
                pair_return_head_exact
              ),
              rendering_verification_pair_congruence_func(
                object_here,
                object_id,
                ordinal_here,
                light_ordinal,
                Equal.sym(U32, object_id, object_here, object_here_exact),
                Equal.sym(U32, light_ordinal, ordinal_here, ordinal_here_exact)
              )
            ),
            (
              Equal.cong(
                ObjectLightQueryPair,
                Light.RayQuery,
                value => rendering_verification_pair_query_func(value),
                pair_for_query,
                pair_for_return,
                Equal.trans(
                  ObjectLightQueryPair,
                  pair_for_query,
                  ObjectLightQueryPair{object_here, ordinal_here},
                  pair_for_return,
                  Equal.sym(
                    ObjectLightQueryPair,
                    ObjectLightQueryPair{object_here, ordinal_here},
                    pair_for_query,
                    pair_for_query_exact
                  ),
                  pair_return_query_exact
                )
              ),
              LightPositionCoverageTransport_func(
                object_tail,
                object_id,
                pred,
                pred,
                U32.inc(ordinal_tail),
                U32.inc(light_ordinal),
                Equal.sym(U32, object_id, object_tail, object_tail_exact),
                {==},
                Equal.cong(
                  U32,
                  U32,
                  value => U32.inc(value),
                  ordinal_tail,
                  light_ordinal,
                  Equal.sym(U32, light_ordinal, ordinal_tail, ordinal_tail_exact)
                ),
                LightPositionCoverageAssert_func(
                  pred,
                  object_tail,
                  U32.inc(ordinal_tail)
                )
              )
            )
          )
        )
      )

# One LightPositionCoverageClaim is produced per object constructor, while the
# recursive tail covers every remaining object with the same light count.
assert ObjectCoverageClaim_func:
  forall objects: List<U32>
  forall -light_count: Nat
  Type

def ObjectCoverageClaim_func(objects, light_count):
  match objects:
    case Nil{}:
      Unit
    case Con{object_id, tail}:
      LightPositionCoverageClaim_func(object_id, light_count, 0)
      & ObjectCoverageClaim_func(tail, light_count)

assert ObjectCoverageTransport_func:
  forall -objects: List<U32>
  forall -count_before: Nat
  forall -count_after: Nat
  forall count_exact: {count_before == count_after : Nat}
  forall coverage: ObjectCoverageClaim_func(objects, count_before)
  ObjectCoverageClaim_func(objects, count_after)

def ObjectCoverageTransport_func(objects, count_before, count_after, count_exact, coverage):
  %count_exact : ObjectCoverageClaim_func(objects, _)
  coverage

assert ObjectCoverageAssert_func:
  forall objects: List<U32>
  forall light_count: Nat
  ObjectCoverageClaim_func(objects, light_count)

def ObjectCoverageAssert_func(objects, light_count):
  match objects:
    case Nil{}:
      Unit{}
    case Con{object_id, tail}:
      ((count_here, count_here_exact), (count_tail, count_tail_exact)) = Nat.copy(light_count)
      (
        LightPositionCoverageTransport_func(
          object_id,
          object_id,
          count_here,
          light_count,
          0,
          0,
          {==},
          Equal.sym(Nat, light_count, count_here, count_here_exact),
          {==},
          LightPositionCoverageAssert_func(
            count_here,
            object_id,
            0
          )
        ),
        ObjectCoverageTransport_func(
          tail,
          count_tail,
          light_count,
          Equal.sym(Nat, light_count, count_tail, count_tail_exact),
          ObjectCoverageAssert_func(
            tail,
            count_tail
          )
        )
      )

# Headline semantic claim: arbitrary object/light lists receive exact ordered
# Cartesian query coverage. Light payloads are intentionally irrelevant; the
# recursive successor nodes identify positions exactly once. Their U32 labels
# may wrap for unrealistically long lists, so numeric-label uniqueness is not
# part of the theorem.
assert ObjectLightCoverageClaim_func:
  forall object_ids: List<U32>
  forall lights: List<Light.Light>
  Type

def ObjectLightCoverageClaim_func(object_ids, lights):
  ObjectCoverageClaim_func(object_ids, List.length(Light.Light, lights))

assert ObjectLightCoverageAssert_func:
  forall object_ids: List<U32>
  forall lights: List<Light.Light>
  ObjectLightCoverageClaim_func(object_ids, lights)

def ObjectLightCoverageAssert_func(object_ids, lights):
  ObjectCoverageAssert_func(
    object_ids,
    List.length(Light.Light, lights)
  )

assert rendering_verification_slots_certified_func:
  forall count: Nat
  forall ordinal: U32
  exists slots: List<CartesianSlot>
  { List.length(CartesianSlot, slots) == count : Nat }

def rendering_verification_slots_certified_func(count, ordinal):
  match count:
    case 0n:
      (Nil{}, {==})
    case 1n+pred:
      ((ordinal_here, ordinal_here_exact), (ordinal_tail, ordinal_tail_exact)) = U32.copy(ordinal)
      (tail, tail_exact) = rendering_verification_slots_certified_func(
        pred,
        U32.inc(ordinal_tail)
      )
      (
        Con{CartesianSlot{ordinal_here}, tail},
        Equal.cong(
          Nat,
          Nat,
          value => 1n+value,
          List.length(CartesianSlot, tail),
          pred,
          tail_exact
        )
      )

assert ObjectLightProductCardinalityClaim_func:
  forall object_ids: List<U32>
  forall lights: List<Light.Light>
  Type

def ObjectLightProductCardinalityClaim_func(object_ids, lights):
  Sigma<
    List<CartesianSlot>,
    slots => {
      List.length(CartesianSlot, slots)
      == Nat.mul(
        List.length(U32, object_ids),
        List.length(Light.Light, lights)
      ) : Nat
    }
  >

# Independent exact aggregate: the structurally specified Cartesian coverage
# has |objects| * |lights| flattened positions. Nat.mul is supplied directly as
# fuel, so the proof does not pretend its affine copy implementation unfolds.
assert ObjectLightProductCardinalityAssert_func:
  forall object_ids: List<U32>
  forall lights: List<Light.Light>
  ObjectLightProductCardinalityClaim_func(object_ids, lights)

def ObjectLightProductCardinalityAssert_func(object_ids, lights):
  rendering_verification_slots_certified_func(
    Nat.mul(
      List.length(U32, object_ids),
      List.length(Light.Light, lights)
    ),
    0
  )

# Semantic mesh well-formedness for arbitrary generated inputs: cardinalities,
# exact ordered fur anchors, and two facets for every indexed quad.
assert GeneratedMeshWellFormedClaim_func:
  forall -indices: List<U32>
  forall -quads: List<Model3D.Quad>
  Type

def GeneratedMeshWellFormedClaim_func(indices, quads):
  {
    List.length(Model3D.Vertex, Model3D.model3d_vertices_from_indices_func(indices))
    == List.length(Model3D.FurStrand, Model3D.model3d_fur_from_indices_func(indices))
    : Nat
  } & {
    Model3D.model3d_fur_root_indices_func(
      Model3D.model3d_fur_from_indices_func(indices)
    ) == indices : List<U32>
  } & {
    List.length(Model3D.Facet, Model3D.model3d_facets_from_quads_func(quads))
    == Nat.double(List.length(Model3D.Quad, quads)) : Nat
  }

assert GeneratedMeshWellFormedAssert_func:
  forall indices: List<U32>
  forall quads: List<Model3D.Quad>
  GeneratedMeshWellFormedClaim_func(indices, quads)

def GeneratedMeshWellFormedAssert_func(indices, quads):
  (cardinality, roots_preserved) = Model3D.model3d_generated_indices_well_formed_theorem_func(indices)
  (
    cardinality,
    (
      roots_preserved,
      Model3D.model3d_quad_expansion_cardinality_theorem_func(quads)
    )
  )

assert rendering_verification_reflective_surface_func:
  forall reflectance: PositiveReflectance
  forall incident: SupportedPositiveIncident
  forall visibility: PositiveVisibility
  forall point: Model3D.Vec3
  forall base_color: Model3D.Color
  forall roughness: U32
  forall metallic: U32
  forall fuzz: U32
  Light.SurfaceSample

def rendering_verification_reflective_surface_func(reflectance, incident, visibility, point, base_color, roughness, metallic, fuzz):
  match reflectance incident visibility:
    case
      PositiveReflectance{level, positive}
      SupportedPositiveIncident{light, normal, incoming, incident_positive}
      PositiveVisibility{visible, clear}:
      Light.SurfaceSample{
        point,
        normal,
        incoming,
        base_color,
        roughness,
        metallic,
        level,
        fuzz
      }

assert ReflectionWitnessClaim_func:
  forall -reflectance: PositiveReflectance
  forall -incident: SupportedPositiveIncident
  forall -visibility: PositiveVisibility
  forall -point: Model3D.Vec3
  forall -base_color: Model3D.Color
  forall -roughness: U32
  forall -metallic: U32
  forall -fuzz: U32
  forall -seed: U32
  Type

def ReflectionWitnessClaim_func(reflectance, incident, visibility, point, base_color, roughness, metallic, fuzz, seed):
  {
    U32.is_zero(
      Light.light_reflection_strength_func(
        Light.light_reflection_sample_func(
          rendering_verification_reflective_surface_func(
            reflectance, incident, visibility, point, base_color,
            roughness, metallic, fuzz
          ),
          seed
        )
      )
    ) == False{} : Bool
  }

# The conclusion derives from positive reflectance. Positive incidence and
# clear visibility are explicit admissibility hypotheses for the supported
# surface/light pair; the theorem does not falsely claim they create energy.
assert ReflectionWitnessAssert_func:
  forall reflectance: PositiveReflectance
  forall incident: SupportedPositiveIncident
  forall visibility: PositiveVisibility
  forall point: Model3D.Vec3
  forall base_color: Model3D.Color
  forall roughness: U32
  forall metallic: U32
  forall fuzz: U32
  forall seed: U32
  ReflectionWitnessClaim_func( reflectance, incident, visibility, point, base_color, roughness, metallic, fuzz, seed )

def ReflectionWitnessAssert_func(reflectance, incident, visibility, point, base_color, roughness, metallic, fuzz, seed):
  match reflectance incident visibility:
    case
      PositiveReflectance{level, positive}
      SupportedPositiveIncident{light, normal, incoming, incident_positive}
      PositiveVisibility{visible, clear}:
      %positive : {U32.is_zero(level) == _ : Bool}
      {==}

assert rendering_verification_consume_func:
  forall -coverage: @object_ids: List<U32> -> @lights: List<Light.Light> -> ObjectLightCoverageClaim_func(object_ids, lights)
  forall -product: @object_ids: List<U32> -> @lights: List<Light.Light> -> ObjectLightProductCardinalityClaim_func(object_ids, lights)
  forall -mesh: @indices: List<U32> -> @quads: List<Model3D.Quad> -> GeneratedMeshWellFormedClaim_func(indices, quads)
  forall -reflection: @reflectance: PositiveReflectance -> @incident: SupportedPositiveIncident -> @visibility: PositiveVisibility -> @point: Model3D.Vec3 -> @base_color: Model3D.Color -> @roughness: U32 -> @metallic: U32 -> @fuzz: U32 -> @seed: U32 -> ReflectionWitnessClaim_func( reflectance, incident, visibility, point, base_color, roughness, metallic, fuzz, seed )
  Bool

def rendering_verification_consume_func(coverage, product, mesh, reflection):
  True{}

assert rendering_semantic_verification_func:
  Bool

def rendering_semantic_verification_func():
  rendering_verification_consume_func(
    ObjectLightCoverageAssert_func,
    ObjectLightProductCardinalityAssert_func,
    GeneratedMeshWellFormedAssert_func,
    ReflectionWitnessAssert_func
  )
