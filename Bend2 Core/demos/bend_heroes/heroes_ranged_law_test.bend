import Base
import ./heroes.bend as Heroes
import ./heroes_ranged_law.bend as Law

# Consume the universally quantified theorem functions themselves.  This keeps
# the executable test from weakening the result to a handful of closed values.
assert verified:
  forall -win:
    @separation: Law.RangedSeparation ->
    @mobility: Law.MeleeMobility ->
    @damage: Law.RangedDamage ->
    @ranged_stack: Heroes.Stack ->
    @-ranged_exact: {Law.stack_is_ranged(ranged_stack) == True{} : Bool} ->
    @melee_stack: Heroes.Stack ->
    @-melee_exact: {Law.stack_is_ranged(melee_stack) == False{} : Bool} ->
    @defender_health: Nat ->
    {
      Law.ranged_duel(
        separation,
        mobility,
        damage,
        ranged_stack,
        ranged_exact,
        melee_stack,
        melee_exact,
        defender_health
      )
      == Law.RangedVictory{ranged_stack, Law.lethal_volleys(defender_health)}
      : Law.DuelOutcome
    }
  forall -runtime_audit:
    @ranged: Bool ->
    @percent: U32 ->
    { Heroes.ranged_percent_func(ranged, percent) == percent : U32 }
  forall -flag_audit:
    @percent: U32 ->
    {
      Heroes.ranged_percent_func(True{}, percent)
      == Heroes.ranged_percent_func(False{}, percent)
      : U32
    }
  Bool

def verified(win, runtime_audit, roll_audit):
  True{}

assert show_bool:
  forall value: Bool
  IO(Unit)

def show_bool(value):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

assert main:
  IO(Unit)

def main():
  show_bool(verified(
    Law.ranged_duel_always_wins,
    Law.runtime_ranged_modifier_is_identity,
    Law.runtime_ranged_flag_is_irrelevant
  ))
