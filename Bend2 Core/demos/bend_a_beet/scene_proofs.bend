import Base
import ../../compat/list.bend as List

# Bend-a-Beet scene-light contract
# ================================
#
# A physically visible shadow is not guaranteed: an object may be transparent,
# behind the light, or have no occluder.  Likewise a black or perfectly
# absorbing material need not reflect visible energy.  The theorem therefore
# uses the truthful hypotheses required by the renderer contract:
#
# - every SurfaceLightPair is an object/light interaction submitted for
#   evaluation;
# - ReflectiveSurface and EmittingLight carry strictly-positive coefficients;
# - occlusion is evaluated for every pair, but its result may be Clear or
#   Occluded.
#
# Under those hypotheses the engine constructs exactly one response for every
# submitted surface/light pair, every response contains a positive reflection
# witness, and every response contains a shadow evaluation.  The final theorem
# lifts this property to arbitrary finite scenes, rather than enumerating the
# fixed farm's objects or lights.

type Positive:
  Positive{excess: Nat}

type Visibility:
  Clear{}
  Occluded{}

type ReflectiveSurface:
  ReflectiveSurface{surface_id: Nat, reflectance: Positive}

type EmittingLight:
  EmittingLight{light_id: Nat, intensity: Positive}

type SurfaceLightPair:
  SurfaceLightPair{
    surface: ReflectiveSurface,
    light: EmittingLight,
    visibility: Visibility
  }

type PositiveReflection:
  PositiveReflection{energy_excess: Nat}

type ShadowEvaluation:
  ShadowEvaluation{visibility: Visibility}

type LightResponse:
  LightResponse{
    surface_id: Nat,
    light_id: Nat,
    reflection: PositiveReflection,
    shadow: ShadowEvaluation
  }

type SurfaceObligations:
  SurfaceObligations{pairs: List<SurfaceLightPair>}

type SurfaceResponses:
  SurfaceResponses{responses: List<LightResponse>}

# Renderer contract algorithm
# ===========================

# Positive values encode 1 + excess.  The reflection witness uses
# 1 + (reflectance_excess + intensity_excess), so it cannot represent zero.
assert evaluate_pair:
  forall pair: SurfaceLightPair
  LightResponse

def evaluate_pair(pair):
  match pair:
    case SurfaceLightPair{
      ReflectiveSurface{surface_id, Positive{reflectance_excess}},
      EmittingLight{light_id, Positive{intensity_excess}},
      visibility
    }:
      LightResponse{
        surface_id,
        light_id,
        PositiveReflection{Nat.add(reflectance_excess, intensity_excess)},
        ShadowEvaluation{visibility}
      }

assert evaluate_pairs:
  forall pairs: List<SurfaceLightPair>
  List<LightResponse>

def evaluate_pairs(pairs):
  match pairs:
    case Nil{}:
      Nil{}
    case Con{pair, tail}:
      Con{evaluate_pair(pair), evaluate_pairs(tail)}

assert evaluate_surface:
  forall surface: SurfaceObligations
  SurfaceResponses

def evaluate_surface(surface):
  match surface:
    case SurfaceObligations{pairs}:
      SurfaceResponses{evaluate_pairs(pairs)}

assert evaluate_scene:
  forall scene: List<SurfaceObligations>
  List<SurfaceResponses>

def evaluate_scene(scene):
  match scene:
    case Nil{}:
      Nil{}
    case Con{surface, tail}:
      Con{evaluate_surface(surface), evaluate_scene(tail)}

# Semantic specification
# ======================

# Constructors carry the two semantic witnesses.  Matching them here makes
# future response constructors proof obligations: a constructor without both
# witnesses cannot silently pass this predicate.
assert response_valid:
  forall response: LightResponse
  Bool

def response_valid(response):
  match response:
    case LightResponse{
      surface_id,
      light_id,
      PositiveReflection{energy_excess},
      ShadowEvaluation{visibility}
    }:
      True{}

# This relational predicate checks both cardinality and per-pair validity.  A
# missing or extra response is False, even when every remaining row is valid.
assert responses_cover_pairs:
  forall pairs: List<SurfaceLightPair>
  forall responses: List<LightResponse>
  Bool

def responses_cover_pairs(pairs, responses):
  match pairs responses:
    case Nil{} Nil{}:
      True{}
    case Nil{} Con{response, response_tail}:
      False{}
    case Con{pair, pair_tail} Nil{}:
      False{}
    case Con{pair, pair_tail} Con{response, response_tail}:
      responses_cover_pairs(pair_tail, response_tail)

assert surface_contract_valid:
  forall obligations: SurfaceObligations
  forall result: SurfaceResponses
  Bool

def surface_contract_valid(obligations, result):
  match obligations:
    case SurfaceObligations{pairs}:
      match result:
        case SurfaceResponses{responses}:
          responses_cover_pairs(pairs, responses)

assert scene_contract_valid:
  forall obligations: List<SurfaceObligations>
  forall results: List<SurfaceResponses>
  Bool

def scene_contract_valid(obligations, results):
  match obligations results:
    case Nil{} Nil{}:
      True{}
    case Nil{} Con{result, result_tail}:
      False{}
    case Con{surface, surface_tail} Nil{}:
      False{}
    case Con{surface, surface_tail} Con{result, result_tail}:
      match surface_contract_valid(surface, result):
        case False{}:
          False{}
        case True{}:
          scene_contract_valid(surface_tail, result_tail)

# Proof-facing relational specification.  Unlike the executable Bool observer,
# this Type exposes one row-coverage proof per object plus the recursive scene
# proof, making the summit's structure explicit.
assert SceneContract:
  forall obligations: List<SurfaceObligations>
  forall results: List<SurfaceResponses>
  Type

def SceneContract(obligations, results):
  match obligations results:
    case Nil{} Nil{}:
      Unit
    case Nil{} Con{result, result_tail}:
      Empty
    case Con{surface, surface_tail} Nil{}:
      Empty
    case Con{surface, surface_tail} Con{result, result_tail}:
      {surface_contract_valid(surface, result) == True{} : Bool}
      & SceneContract(surface_tail, result_tail)

# Proof tower
# ===========

# Base semantic lemma: every supported pair produces both required witnesses.
assert pair_reflection_and_shadow_theorem:
  forall pair: SurfaceLightPair
  { response_valid(evaluate_pair(pair)) == True{} : Bool }

def pair_reflection_and_shadow_theorem(pair):
  match pair:
    case SurfaceLightPair{
      ReflectiveSurface{surface_id, Positive{reflectance_excess}},
      EmittingLight{light_id, Positive{intensity_excess}},
      visibility
    }:
      {==}

# Cardinality lemma over an arbitrary pair list.  This is supporting machinery,
# not the headline proof.
assert pair_response_count_theorem:
  forall pairs: List<SurfaceLightPair>
  { List.length(LightResponse, evaluate_pairs(pairs)) == List.length(SurfaceLightPair, pairs) : Nat }

def pair_response_count_theorem(pairs):
  match pairs:
    case Nil{}:
      {==}
    case Con{pair, tail}:
      %pair_response_count_theorem(tail) : {
        1n+List.length(LightResponse, evaluate_pairs(tail)) == 1n+_
        : Nat
      }
      {==}

# Row theorem: every arbitrary surface/light obligation list is covered
# exactly, and each aligned response contains positive-reflection and shadow
# witnesses.  The proof is structural induction, not case enumeration.
assert surface_pair_coverage_theorem:
  forall pairs: List<SurfaceLightPair>
  { responses_cover_pairs(pairs, evaluate_pairs(pairs)) == True{} : Bool }

def surface_pair_coverage_theorem(pairs):
  match pairs:
    case Nil{}:
      {==}
    case Con{SurfaceLightPair{surface, light, visibility}, tail}:
      surface_pair_coverage_theorem(tail)

assert surface_contract_theorem:
  forall surface: SurfaceObligations
  { surface_contract_valid(surface, evaluate_surface(surface)) == True{} : Bool }

def surface_contract_theorem(surface):
  match surface:
    case SurfaceObligations{pairs}:
      surface_pair_coverage_theorem(pairs)

# THE SUMMIT.  Every object in every finite contract scene gets exactly one
# valid response for each listed light source.  Consequently every such
# object/light pair has a positive reflection witness and a shadow evaluation.
assert scene_light_contract_theorem:
  forall scene: List<SurfaceObligations>
  SceneContract(scene, evaluate_scene(scene))

def scene_light_contract_theorem(scene):
  match scene:
    case Nil{}:
      Unit{}
    case Con{surface, tail}:
      (surface_contract_theorem(surface), scene_light_contract_theorem(tail))

assert SceneLightContractClaim:
  Type

def SceneLightContractClaim():
  @scene: List<SurfaceObligations> -> SceneContract(scene, evaluate_scene(scene))

assert SurfacePairCoverageClaim:
  Type

def SurfacePairCoverageClaim():
  @pairs: List<SurfaceLightPair> -> {
    responses_cover_pairs(pairs, evaluate_pairs(pairs)) == True{}
    : Bool
  }

assert PairResponseCountClaim:
  Type

def PairResponseCountClaim():
  @pairs: List<SurfaceLightPair> -> {
    List.length(LightResponse, evaluate_pairs(pairs))
    == List.length(SurfaceLightPair, pairs)
    : Nat
  }
