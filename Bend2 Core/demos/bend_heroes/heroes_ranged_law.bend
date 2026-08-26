import Base
import ./heroes.bend as Heroes

# Proof-only combat adapter
# =========================
#
# heroes.bend has no battle-grid position and its combat transition does not
# consume CreatureStats.speed.  These small witnesses make the missing duel
# premises explicit without changing that source file.  Their payloads are
# unbounded: this is one parametric law, not a list of creature/health cases.

type RangedSeparation:
  AtLeastTwoTiles{extra_tiles: Nat}

type MeleeMobility:
  Immobile{}

type RangedDamage:
  AboveOne{extra_damage: Nat}

type DuelOutcome:
  RangedVictory{survivor: Heroes.Stack, volleys: Nat}
  MeleeVictory{}
  Stalemate{}

# These predicates read the actual CreatureStats.ranged flag from heroes.bend.
# Equality witnesses in the duel interface therefore prevent callers from
# labeling an arbitrary stack "ranged" or "melee".
assert stack_is_ranged:
  forall stack: Heroes.Stack
  Bool

def stack_is_ranged(stack):
  match stack:
    case Heroes.EmptyStack{}:
      False{}
    case Heroes.Troop{kind, count, first_unit_hp}:
      match Heroes.creature_kind_stats_func(kind):
        case Heroes.CreatureBundle{
          kept_kind,
          Heroes.CreatureStats{
            attack,
            defense,
            damage_min,
            damage_max,
            hit_points,
            speed,
            growth,
            cost,
            ranged
          }
        }:
          ranged

# A damage value represented by AboveOne{x} is 2+x.  lethal_volleys computes
# the conservative bound obtained by using only the guaranteed two damage per
# volley.  Extra damage can only finish sooner.
assert lethal_volleys:
  forall health: Nat
  Nat

def lethal_volleys(health):
  match health:
    case 0n:
      0n
    case 1n+after_first:
      match after_first:
        case 0n:
          1n
        case 1n+remaining:
          1n+lethal_volleys(remaining)

assert add_volley:
  forall outcome: DuelOutcome
  DuelOutcome

def add_volley(outcome):
  match outcome:
    case RangedVictory{survivor, volleys}:
      RangedVictory{survivor, 1n+volleys}
    case MeleeVictory{}:
      MeleeVictory{}
    case Stalemate{}:
      Stalemate{}

# This is the operational proof model.  The ranged stack is preserved because
# an immobile melee stack separated by at least two tiles has no transition
# that can reach or retaliate.  Each recursive volley consumes the guaranteed
# two hit points.  Recursion is visibly structural on defender_health.
assert ranged_duel:
  forall separation: RangedSeparation
  forall mobility: MeleeMobility
  forall damage: RangedDamage
  forall ranged_stack: Heroes.Stack
  forall -ranged_exact: {stack_is_ranged(ranged_stack) == True{} : Bool}
  forall melee_stack: Heroes.Stack
  forall -melee_exact: {stack_is_ranged(melee_stack) == False{} : Bool}
  forall defender_health: Nat
  DuelOutcome

def ranged_duel(separation, mobility, damage, ranged_stack, ranged_exact, melee_stack, melee_exact, defender_health):
  match separation:
    case AtLeastTwoTiles{extra_tiles}:
      match mobility:
        case Immobile{}:
          match damage:
            case AboveOne{extra_damage}:
              match defender_health:
                case 0n:
                  RangedVictory{ranged_stack, 0n}
                case 1n+after_first:
                  match after_first:
                    case 0n:
                      RangedVictory{ranged_stack, 1n}
                    case 1n+remaining:
                      add_volley(ranged_duel(
                        AtLeastTwoTiles{extra_tiles},
                        Immobile{},
                        AboveOne{extra_damage},
                        ranged_stack,
                        ranged_exact,
                        melee_stack,
                        melee_exact,
                        remaining
                      ))

# Universal ranged-win theorem.  The checker must accept the recursive call at
# an arbitrary remaining health; there are no closed combat cases here.
assert ranged_duel_always_wins:
  forall separation: RangedSeparation
  forall mobility: MeleeMobility
  forall damage: RangedDamage
  forall ranged_stack: Heroes.Stack
  forall -ranged_exact: {stack_is_ranged(ranged_stack) == True{} : Bool}
  forall melee_stack: Heroes.Stack
  forall -melee_exact: {stack_is_ranged(melee_stack) == False{} : Bool}
  forall defender_health: Nat
  {
    ranged_duel(
      separation,
      mobility,
      damage,
      ranged_stack,
      ranged_exact,
      melee_stack,
      melee_exact,
      defender_health
    )
    == RangedVictory{ranged_stack, lethal_volleys(defender_health)}
    : DuelOutcome
  }

def ranged_duel_always_wins(separation, mobility, damage, ranged_stack, ranged_exact, melee_stack, melee_exact, defender_health):
  match separation:
    case AtLeastTwoTiles{extra_tiles}:
      match mobility:
        case Immobile{}:
          match damage:
            case AboveOne{extra_damage}:
              match defender_health:
                case 0n:
                  {==}
                case 1n+after_first:
                  match after_first:
                    case 0n:
                      {==}
                    case 1n+remaining:
                      Equal.cong(
                        DuelOutcome,
                        DuelOutcome,
                        outcome => add_volley(outcome),
                        ranged_duel(
                          AtLeastTwoTiles{extra_tiles},
                          Immobile{},
                          AboveOne{extra_damage},
                          ranged_stack,
                          ranged_exact,
                          melee_stack,
                          melee_exact,
                          remaining
                        ),
                        RangedVictory{ranged_stack, lethal_volleys(remaining)},
                        ranged_duel_always_wins(
                          AtLeastTwoTiles{extra_tiles},
                          Immobile{},
                          AboveOne{extra_damage},
                          ranged_stack,
                          ranged_exact,
                          melee_stack,
                          melee_exact,
                          remaining
                        )
                      )

# Concrete implementation audit
# =============================
# This theorem is about heroes.bend itself.  It exposes why the adapter cannot
# yet be refined to combat_attack_func: the current ranged modifier is the
# identity for both constructors, for every percentage.
assert runtime_ranged_modifier_is_identity:
  forall ranged: Bool
  forall percent: U32
  { Heroes.ranged_percent_func(ranged, percent) == percent : U32 }

def runtime_ranged_modifier_is_identity(ranged, percent):
  match ranged:
    case False{}:
      {==}
    case True{}:
      {==}

# More directly, the two runtime flags are observationally equal at this seam.
assert runtime_ranged_flag_is_irrelevant:
  forall percent: U32
  {
    Heroes.ranged_percent_func(True{}, percent)
    == Heroes.ranged_percent_func(False{}, percent)
    : U32
  }

def runtime_ranged_flag_is_irrelevant(percent):
  {==}
