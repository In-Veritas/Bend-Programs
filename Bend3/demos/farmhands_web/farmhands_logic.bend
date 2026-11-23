# Pure Farmhands rules. This module contains no IO, clock, HTTP, password, or
# filesystem operations. The web server supplies `now` (seconds); every
# transition below is deterministic and can be checked or proved
# independently.
#
# Ported to Bend 2.0.40: the old U32 truth values (0/1) are Base `Bool`s,
# and the twelve old `{a = b : U32}` proof defs are `law`s proven by the
# `def` of the same name (see the end of the file). `bend
# farmhands_logic.bend --check-only` prints ALL PROOFS CHECK, and `bend
# farmhands_logic.bend` runs `main`, the runtime audit (12 means every
# check passed).
import Base

type Player is Data:
  Player{name: String, coins: U32, unlocked: U32, turnip: U32, carrot: U32, radish: U32, tomato: U32}

type Plot is Data:
  Plot{owner: String, index: U32, crop: U32, planted_at: U32, steals: U32, thieves: List<&2, String>}

type Theft is Data:
  Theft{thief: String, owner: String, day: U32, plot: U32, planted_at: U32}

type Farm is Data:
  Farm{players: List<&2, Player>, plots: List<&2, Plot>, thefts: List<&2, Theft>}

type FarmAction is Data:
  FarmAction{farm: Farm, ok: Bool, note: String, amount: U32}

def plot_count() -> U32:
  12

def initial_unlocked() -> U32:
  4

def initial_coins() -> U32:
  24

def crop_yield() -> U32:
  12

def steal_amount() -> U32:
  3

def max_plot_steals() -> U32:
  3

def max_daily_steals() -> U32:
  2

def day_seconds() -> U32:
  86400

def crop_valid(+crop: U32) -> Bool:
  (crop > 0 : U32) && (crop < 5 : U32)

def crop_name(crop: U32) -> String:
  match crop:
    case 1:
      "turnip"
    case 2:
      "carrot"
    case 3:
      "radish"
    case 4:
      "tomato"
    case other:
      "empty"

# Short test timings: 15, 24, 36, and 48 seconds.
def crop_duration(crop: U32) -> U32:
  match crop:
    case 1:
      15
    case 2:
      24
    case 3:
      36
    case 4:
      48
    case other:
      0

def crop_cost(crop: U32) -> U32:
  match crop:
    case 1:
      1
    case 2:
      2
    case 3:
      3
    case 4:
      4
    case other:
      0

def crop_value(crop: U32) -> U32:
  match crop:
    case 1:
      2
    case 2:
      3
    case 3:
      4
    case 4:
      5
    case other:
      0

def unlock_cost(unlocked: U32) -> U32:
  (20 + unlocked * 5 : U32)

def current_day(now: U32) -> U32:
  (now / day_seconds() : U32)

def crop_elapsed(plot: Plot, now: U32) -> U32:
  Plot{owner, index, crop, planted_at, steals, thieves} = plot
  (now - planted_at : U32)

def crop_ready(plot: Plot, now: U32) -> Bool:
  Plot{owner, index, crop, planted_at, steals, thieves} = plot
  ((now - planted_at : U32) >= crop_duration(crop) : U32)

def crop_stage.pick(ready: Bool, two_thirds: Bool, third: Bool) -> U32:
  match ready:
    case True{}:
      4
    case False{}:
      match two_thirds:
        case True{}:
          3
        case False{}:
          match third:
            case True{}:
              2
            case False{}:
              1

# 1 seed, 2 sprout, 3 plant, 4 mature.
def crop_stage(plot: Plot, now: U32) -> U32:
  Plot{owner, index, crop, planted_at, steals, thieves} = plot
  +elapsed = (now - planted_at : U32)
  +duration = crop_duration(crop)
  crop_stage.pick((elapsed >= duration : U32), (elapsed * 3 >= duration * 2 : U32), (elapsed * 3 >= duration : U32))

def yield_remaining.pick(over: Bool, +steals: U32) -> U32:
  match over:
    case False{}:
      (crop_yield() - steals * steal_amount() : U32)
    case True{}:
      (crop_yield() - max_plot_steals() * steal_amount() : U32)

def yield_remaining(+steals: U32) -> U32:
  yield_remaining.pick((steals >= max_plot_steals() : U32), steals)

def steal_slot_open(steals: U32) -> Bool:
  (steals < max_plot_steals() : U32)

def daily_slot_open(count: U32) -> Bool:
  (count < max_daily_steals() : U32)

def player_new(name: String) -> Player:
  Player{name, initial_coins(), initial_unlocked(), 0, 0, 0, 0}

def no_strings() -> List<&2, String>:
  Nil{}

def string_push(value: String, values: List<&2, String>) -> List<&2, String>:
  value <> values

def theft_push(theft: Theft, thefts: List<&2, Theft>) -> List<&2, Theft>:
  theft <> thefts

def player_name(player: Player) -> String:
  Player{name, coins, unlocked, turnip, carrot, radish, tomato} = player
  name

def player_is(+player: Player, name: String) -> Bool:
  String.eq(player_name(player), name)

def player_find.pick(hit: Bool, +head: Player, rest: Maybe<&2, Player>) -> Maybe<&2, Player>:
  match hit:
    case True{}:
      Some{head}
    case False{}:
      rest

def player_find(players: List<&2, Player>, +name: String) -> Maybe<&2, Player>:
  match players:
    case Nil{}:
      None{}
    case +head <> tail:
      player_find.pick(player_is(head, name), head, player_find(tail, name))

def player_exists(players: List<&2, Player>, name: String) -> Bool:
  Maybe.is_some(&2, Player, player_find(players, name))

def player_replace.pick(hit: Bool, +head: Player, +replacement: Player, tail: List<&2, Player>, rest: List<&2, Player>) -> List<&2, Player>:
  match hit:
    case True{}:
      replacement <> tail
    case False{}:
      head <> rest

def player_replace(players: List<&2, Player>, +replacement: Player) -> List<&2, Player>:
  match players:
    case Nil{}:
      [replacement]
    case +head <> +tail:
      player_replace.pick(player_is(head, player_name(replacement)), head, replacement, tail, player_replace(tail, replacement))

def player_add_crop(player: Player, crop: U32, +amount: U32, +coin_gain: U32) -> Player:
  Player{name, coins, unlocked, turnip, carrot, radish, tomato} = player
  match crop:
    case 1:
      Player{name, (coins + coin_gain : U32), unlocked, (turnip + amount : U32), carrot, radish, tomato}
    case 2:
      Player{name, (coins + coin_gain : U32), unlocked, turnip, (carrot + amount : U32), radish, tomato}
    case 3:
      Player{name, (coins + coin_gain : U32), unlocked, turnip, carrot, (radish + amount : U32), tomato}
    case 4:
      Player{name, (coins + coin_gain : U32), unlocked, turnip, carrot, radish, (tomato + amount : U32)}
    case other:
      Player{name, coins, unlocked, turnip, carrot, radish, tomato}

def player_spend(player: Player, amount: U32) -> Player:
  Player{name, coins, unlocked, turnip, carrot, radish, tomato} = player
  Player{name, (coins - amount : U32), unlocked, turnip, carrot, radish, tomato}

def player_unlock(player: Player) -> Player:
  Player{name, coins, +unlocked, turnip, carrot, radish, tomato} = player
  Player{name, (coins - unlock_cost(unlocked) : U32), (unlocked + 1 : U32), turnip, carrot, radish, tomato}

def plot_is(+plot: Plot, owner: String, index: U32) -> Bool:
  Plot{stored, at, crop, planted_at, steals, thieves} = plot
  String.eq(stored, owner) && U32.is_eq(at, index)

def plot_find.pick(hit: Bool, +head: Plot, rest: Maybe<&2, Plot>) -> Maybe<&2, Plot>:
  match hit:
    case True{}:
      Some{head}
    case False{}:
      rest

def plot_find(plots: List<&2, Plot>, +owner: String, +index: U32) -> Maybe<&2, Plot>:
  match plots:
    case Nil{}:
      None{}
    case +head <> tail:
      plot_find.pick(plot_is(head, owner, index), head, plot_find(tail, owner, index))

def plot_exists(plots: List<&2, Plot>, owner: String, index: U32) -> Bool:
  Maybe.is_some(&2, Plot, plot_find(plots, owner, index))

def plot_replace.pick(hit: Bool, +head: Plot, +replacement: Plot, tail: List<&2, Plot>, rest: List<&2, Plot>) -> List<&2, Plot>:
  match hit:
    case True{}:
      replacement <> tail
    case False{}:
      head <> rest

def plot_replace_go(plots: List<&2, Plot>, +owner: String, +index: U32, +replacement: Plot) -> List<&2, Plot>:
  match plots:
    case Nil{}:
      [replacement]
    case +head <> +tail:
      plot_replace.pick(plot_is(head, owner, index), head, replacement, tail, plot_replace_go(tail, owner, index, replacement))

def plot_replace(plots: List<&2, Plot>, +replacement: Plot) -> List<&2, Plot>:
  Plot{owner, index, crop, planted_at, steals, thieves} = replacement
  plot_replace_go(plots, owner, index, replacement)

def plot_remove.pick(hit: Bool, +head: Plot, tail: List<&2, Plot>, rest: List<&2, Plot>) -> List<&2, Plot>:
  match hit:
    case True{}:
      tail
    case False{}:
      head <> rest

def plot_remove(plots: List<&2, Plot>, +owner: String, +index: U32) -> List<&2, Plot>:
  match plots:
    case Nil{}:
      Nil{}
    case +head <> +tail:
      plot_remove.pick(plot_is(head, owner, index), head, tail, plot_remove(tail, owner, index))

def string_member(values: List<&2, String>, +value: String) -> Bool:
  match values:
    case Nil{}:
      False{}
    case head <> tail:
      String.eq(head, value) || string_member(tail, value)

def theft_count(thefts: List<&2, Theft>, +thief: String, +owner: String, +day: U32) -> U32:
  match thefts:
    case Nil{}:
      0
    case head <> tail:
      Theft{stored_thief, stored_owner, stored_day, plot, planted_at} = head
      +same = String.eq(stored_thief, thief) && String.eq(stored_owner, owner) && U32.is_eq(stored_day, day)
      (Bool.to_u32(same) + theft_count(tail, thief, owner, day) : U32)

def farm_error(farm: Farm, note: String) -> FarmAction:
  FarmAction{farm, False{}, note, 0}

def farm_ok(farm: Farm, note: String, amount: U32) -> FarmAction:
  FarmAction{farm, True{}, note, amount}

def farm_new() -> Farm:
  Farm{Nil{}, Nil{}, Nil{}}

def farm_add_player.pick(exists: Bool, players: List<&2, Player>, name: String) -> List<&2, Player>:
  match exists:
    case True{}:
      players
    case False{}:
      player_new(name) <> players

def farm_add_player(farm: Farm, +name: String) -> Farm:
  Farm{+players, plots, thefts} = farm
  Farm{farm_add_player.pick(player_exists(players, name), players, name), plots, thefts}

def farm_plant.pay(enough: Bool, +farm: Farm, +actor: Player, +index: U32, +crop: U32, +now: U32) -> FarmAction:
  match enough:
    case False{}:
      farm_error(farm, "Not enough coins for that seed.")
    case True{}:
      Farm{players, plots, thefts} = farm
      +updated = player_spend(actor, crop_cost(crop))
      farm_ok(Farm{player_replace(players, updated), Plot{player_name(actor), index, crop, now, 0, no_strings()} <> plots, thefts}, "Seed planted.", 0)

def farm_plant.valid(valid: Bool, +farm: Farm, +actor: Player, +index: U32, +crop: U32, +now: U32) -> FarmAction:
  match valid:
    case False{}:
      farm_error(farm, "Choose an empty plot and a valid seed.")
    case True{}:
      Player{name, coins, unlocked, turnip, carrot, radish, tomato} = actor
      farm_plant.pay((coins >= crop_cost(crop) : U32), farm, actor, index, crop, now)

def farm_plant.open(open: Bool, +farm: Farm, +actor: Player, +index: U32, +crop: U32, +now: U32) -> FarmAction:
  match open:
    case False{}:
      farm_error(farm, "That plot is still locked.")
    case True{}:
      Farm{players, +plots, thefts} = farm
      farm_plant.valid(crop_valid(crop) && Bool.not(plot_exists(plots, player_name(actor), index)), farm, actor, index, crop, now)

def farm_plant_checked(+farm: Farm, +actor: Player, +index: U32, +crop: U32, +now: U32) -> FarmAction:
  Player{name, coins, unlocked, turnip, carrot, radish, tomato} = actor
  farm_plant.open((index < unlocked : U32) && (index < plot_count() : U32), farm, actor, index, crop, now)

def farm_plant.found(found: Maybe<&2, Player>, +farm: Farm, +index: U32, +crop: U32, +now: U32) -> FarmAction:
  match found:
    case None{}:
      farm_error(farm, "Sign in before planting.")
    case Some{player}:
      farm_plant_checked(farm, player, index, crop, now)

def farm_plant(+farm: Farm, actor: String, +index: U32, +crop: U32, +now: U32) -> FarmAction:
  Farm{players, plots, thefts} = farm
  farm_plant.found(player_find(players, actor), farm, index, crop, now)

def farm_harvest_plot.ready(ready: Bool, +farm: Farm, +actor: Player, +plot: Plot) -> FarmAction:
  match ready:
    case False{}:
      farm_error(farm, "Only the owner can harvest a mature crop.")
    case True{}:
      Farm{players, plots, thefts} = farm
      Plot{+owner, +index, +crop, planted_at, +steals, thieves} = plot
      +amount = yield_remaining(steals)
      +gain = (amount * crop_value(crop) : U32)
      +updated = player_add_crop(actor, crop, amount, gain)
      farm_ok(Farm{player_replace(players, updated), plot_remove(plots, owner, index), thefts}, "Crop harvested.", amount)

def farm_harvest_plot(+farm: Farm, +actor: Player, +plot: Plot, +now: U32) -> FarmAction:
  Plot{owner, index, crop, planted_at, steals, thieves} = plot
  farm_harvest_plot.ready(String.eq(player_name(actor), owner) && crop_ready(plot, now), farm, actor, plot)

def farm_harvest.plot(found: Maybe<&2, Plot>, +farm: Farm, +actor: Player, +now: U32) -> FarmAction:
  match found:
    case None{}:
      farm_error(farm, "There is no crop to harvest there.")
    case Some{plot}:
      farm_harvest_plot(farm, actor, plot, now)

def farm_harvest.player(found: Maybe<&2, Player>, +farm: Farm, +actor: String, +index: U32, +now: U32) -> FarmAction:
  match found:
    case None{}:
      farm_error(farm, "There is no crop to harvest there.")
    case Some{player}:
      Farm{players, plots, thefts} = farm
      farm_harvest.plot(plot_find(plots, actor, index), farm, player, now)

def farm_harvest(+farm: Farm, +actor: String, +index: U32, +now: U32) -> FarmAction:
  Farm{players, plots, thefts} = farm
  farm_harvest.player(player_find(players, actor), farm, actor, index, now)

def farm_steal_commit.permitted(permitted: Bool, +farm: Farm, +thief: Player, +plot: Plot, +now: U32) -> FarmAction:
  match permitted:
    case False{}:
      farm_error(farm, "Steal denied: mature crops only, once per crop, at most three thieves and two crops per owner each day.")
    case True{}:
      Farm{players, plots, thefts} = farm
      Plot{+owner, +index, +crop, +planted_at, +steals, thieves} = plot
      +name = player_name(thief)
      +updated_player = player_add_crop(thief, crop, steal_amount(), 0)
      farm_ok(
        Farm{
          player_replace(players, updated_player),
          plot_replace(plots, Plot{owner, index, crop, planted_at, (steals + 1 : U32), string_push(name, thieves)}),
          theft_push(Theft{name, owner, current_day(now), index, planted_at}, thefts)
        },
        "You stole one quarter of the crop.",
        steal_amount())

def farm_steal_commit(+farm: Farm, +thief: Player, +plot: Plot, +now: U32) -> FarmAction:
  Farm{players, plots, thefts} = farm
  Plot{+owner, index, crop, planted_at, steals, thieves} = plot
  +name = player_name(thief)
  +daily = theft_count(thefts, name, owner, current_day(now))
  +permitted = Bool.not(String.eq(name, owner)) && crop_ready(plot, now) && steal_slot_open(steals) && Bool.not(string_member(thieves, name)) && daily_slot_open(daily)
  farm_steal_commit.permitted(permitted, farm, thief, plot, now)

def farm_steal.plot(found: Maybe<&2, Plot>, +farm: Farm, +thief: Player, +now: U32) -> FarmAction:
  match found:
    case None{}:
      farm_error(farm, "That crop does not exist.")
    case Some{plot}:
      farm_steal_commit(farm, thief, plot, now)

def farm_steal.player(found: Maybe<&2, Player>, +farm: Farm, +owner: String, +index: U32, +now: U32) -> FarmAction:
  match found:
    case None{}:
      farm_error(farm, "That crop does not exist.")
    case Some{player}:
      Farm{players, plots, thefts} = farm
      farm_steal.plot(plot_find(plots, owner, index), farm, player, now)

def farm_steal(+farm: Farm, actor: String, +owner: String, +index: U32, +now: U32) -> FarmAction:
  Farm{players, plots, thefts} = farm
  farm_steal.player(player_find(players, actor), farm, owner, index, now)

def farm_unlock.allowed(ok: Bool, +farm: Farm, +player: Player) -> FarmAction:
  match ok:
    case False{}:
      farm_error(farm, "Maximum land reached or not enough coins.")
    case True{}:
      Farm{players, plots, thefts} = farm
      Player{name, coins, unlocked, turnip, carrot, radish, tomato} = player
      farm_ok(Farm{player_replace(players, player_unlock(player)), plots, thefts}, "One new plot unlocked.", (unlocked + 1 : U32))

def farm_unlock.found(found: Maybe<&2, Player>, +farm: Farm) -> FarmAction:
  match found:
    case None{}:
      farm_error(farm, "Sign in before unlocking land.")
    case Some{+player}:
      Player{name, +coins, +unlocked, turnip, carrot, radish, tomato} = player
      farm_unlock.allowed((unlocked < plot_count() : U32) && (coins >= unlock_cost(unlocked) : U32), farm, player)

def farm_unlock(+farm: Farm, actor: String) -> FarmAction:
  Farm{players, plots, thefts} = farm
  farm_unlock.found(player_find(players, actor), farm)

# Proofs
# ======
# Each old `def X() -> {a = b : U32}: {=}` is now a law with its proof.
# The old 0/1 truth results are Bool: `= 0` is `== False{}`, `= 1` is
# `== True{}`.

law initial_plots_four:
  {initial_unlocked() == 4 : U32}

def initial_plots_four():
  {==}

law theft_is_quarter:
  {(steal_amount() * 4 : U32) == crop_yield() : U32}

def theft_is_quarter():
  {==}

law owner_whole_yield:
  {yield_remaining(0) == 12 : U32}

def owner_whole_yield():
  {==}

law owner_after_one:
  {yield_remaining(1) == 9 : U32}

def owner_after_one():
  {==}

law owner_after_two:
  {yield_remaining(2) == 6 : U32}

def owner_after_two():
  {==}

law owner_keeps_quarter:
  {yield_remaining(3) == 3 : U32}

def owner_keeps_quarter():
  {==}

law extra_steal_cannot_reduce_reserve:
  {yield_remaining(99) == 3 : U32}

def extra_steal_cannot_reduce_reserve():
  {==}

law three_steals_close_plot:
  {steal_slot_open(3) == False{} : Bool}

def three_steals_close_plot():
  {==}

law two_daily_steals_close_owner:
  {daily_slot_open(2) == False{} : Bool}

def two_daily_steals_close_owner():
  {==}

def proof_visitors() -> List<&2, String>:
  string_push("visitor", no_strings())

law same_thief_detected:
  {string_member(proof_visitors(), "visitor") == True{} : Bool}

def same_thief_detected():
  {==}

law other_thief_not_detected:
  {string_member(proof_visitors(), "other") == False{} : Bool}

def other_thief_not_detected():
  {==}

def proof_thefts() -> List<&2, Theft>:
  theft_push(Theft{"visitor", "owner", 7, 0, 100}, theft_push(Theft{"visitor", "owner", 7, 1, 200}, Nil{}))

law two_thefts_count_exactly:
  {theft_count(proof_thefts(), "visitor", "owner", 7) == 2 : U32}

def two_thefts_count_exactly():
  {==}

# Runtime audit of the same twelve facts (the laws above are the proofs;
# this re-evaluates them on the compiled lanes): answers 12.
def count_true(xs: List<&2, Bool>) -> U32:
  match xs:
    case Nil{}:
      0
    case b <> t:
      (Bool.to_u32(b) + count_true(t) : U32)

def proof_audit() -> U32:
  count_true([
    U32.is_eq(initial_unlocked(), 4),
    U32.is_eq((steal_amount() * 4 : U32), crop_yield()),
    U32.is_eq(yield_remaining(0), 12),
    U32.is_eq(yield_remaining(1), 9),
    U32.is_eq(yield_remaining(2), 6),
    U32.is_eq(yield_remaining(3), 3),
    U32.is_eq(yield_remaining(99), 3),
    Bool.not(steal_slot_open(3)),
    Bool.not(daily_slot_open(2)),
    string_member(proof_visitors(), "visitor"),
    Bool.not(string_member(proof_visitors(), "other")),
    U32.is_eq(theft_count(proof_thefts(), "visitor", "owner", 7), 2)])

def test() -> U32:
  proof_audit()

def main() -> U32:
  test()
