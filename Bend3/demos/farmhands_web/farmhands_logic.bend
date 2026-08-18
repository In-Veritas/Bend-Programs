# Pure Farmhands rules. This module contains no IO, clock, HTTP, password, or
# filesystem operations. The web server supplies `now`; every transition below
# is deterministic and can be checked or proved independently.

import List
import String
import Char
import Result

type Player:
  Player{name: String, coins: U32, unlocked: U32, turnip: U32, carrot: U32, radish: U32, tomato: U32}

type Plot:
  Plot{owner: String, index: U32, crop: U32, planted_at: U32, steals: U32, thieves: List(String)}

type Theft:
  Theft{thief: String, owner: String, day: U32, plot: U32, planted_at: U32}

type Farm:
  Farm{players: List(Player), plots: List(Plot), thefts: List(Theft)}

type FarmAction:
  FarmAction{farm: Farm, ok: U32, note: String, amount: U32}

type PlayerFound:
  PlayerHere{player: Player}
  PlayerMissing{}

type PlotFound:
  PlotHere{plot: Plot}
  PlotMissing{}

def plot_count() -> U32: 12
def initial_unlocked() -> U32: 4
def initial_coins() -> U32: 24
def crop_yield() -> U32: 12
def steal_amount() -> U32: 3
def max_plot_steals() -> U32: 3
def max_daily_steals() -> U32: 2
def day_seconds() -> U32: 86400

def crop_valid(crop: U32) -> U32:
  (crop > 0) && (crop < 5)

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
  20 + (unlocked * 5)

def current_day(now: U32) -> U32:
  now / day_seconds()

def crop_elapsed(plot: Plot, now: U32) -> U32:
  match plot:
    case Plot{owner, index, crop, planted_at, steals, thieves}:
      now - planted_at

def crop_ready(plot: Plot, now: U32) -> U32:
  match plot:
    case Plot{owner, index, crop, planted_at, steals, thieves}:
      (now - planted_at) >= crop_duration(crop)

# 1 seed, 2 sprout, 3 plant, 4 mature.
def crop_stage(plot: Plot, now: U32) -> U32:
  match plot:
    case Plot{owner, index, crop, planted_at, steals, thieves}:
      elapsed = now - planted_at
      duration = crop_duration(crop)
      match elapsed >= duration:
        case 0:
          match (elapsed * 3) >= (duration * 2):
            case 0:
              match (elapsed * 3) >= duration:
                case 0:
                  1
                case yes:
                  2
            case yes:
              3
        case yes:
          4

def yield_remaining(steals: U32) -> U32:
  match steals >= max_plot_steals():
    case 0:
      crop_yield() - (steals * steal_amount())
    case yes:
      crop_yield() - (max_plot_steals() * steal_amount())

def steal_slot_open(steals: U32) -> U32:
  steals < max_plot_steals()

def daily_slot_open(count: U32) -> U32:
  count < max_daily_steals()

def player_new(name: String) -> Player:
  Player{name, initial_coins(), initial_unlocked(), 0, 0, 0, 0}

def no_strings() -> List(String):
  Nil{}

def player_push(player: Player, players: List(Player)) -> List(Player):
  Cons{player, players}

def plot_push(plot: Plot, plots: List(Plot)) -> List(Plot):
  Cons{plot, plots}

def string_push(value: String, values: List(String)) -> List(String):
  Cons{value, values}

def theft_push(theft: Theft, thefts: List(Theft)) -> List(Theft):
  Cons{theft, thefts}

def player_name(player: Player) -> String:
  match player:
    case Player{name, coins, unlocked, turnip, carrot, radish, tomato}:
      name

def player_find(players: List(Player), name: String) -> PlayerFound:
  match players:
    case Cons{head, tail}:
      match head:
        case Player{stored, coins, unlocked, turnip, carrot, radish, tomato}:
          match String::eq(stored, name):
            case 0:
              player_find(tail, name)
            case yes:
              PlayerHere{Player{stored, coins, unlocked, turnip, carrot, radish, tomato}}
    case Nil{}:
      PlayerMissing{}

def player_exists(players: List(Player), name: String) -> U32:
  match player_find(players, name):
    case PlayerHere{player}:
      1
    case PlayerMissing{}:
      0

def player_replace(players: List(Player), replacement: Player) -> List(Player):
  match players:
    case Cons{head, tail}:
      match head:
        case Player{stored, coins, unlocked, turnip, carrot, radish, tomato}:
          match String::eq(stored, player_name(replacement)):
            case 0:
              Cons{Player{stored, coins, unlocked, turnip, carrot, radish, tomato}, player_replace(tail, replacement)}
            case yes:
              Cons{replacement, tail}
    case Nil{}:
      Cons{replacement, Nil{}}

def player_add_crop(player: Player, crop: U32, amount: U32, coin_gain: U32) -> Player:
  match player:
    case Player{name, coins, unlocked, turnip, carrot, radish, tomato}:
      match crop:
        case 1:
          Player{name, coins + coin_gain, unlocked, turnip + amount, carrot, radish, tomato}
        case 2:
          Player{name, coins + coin_gain, unlocked, turnip, carrot + amount, radish, tomato}
        case 3:
          Player{name, coins + coin_gain, unlocked, turnip, carrot, radish + amount, tomato}
        case 4:
          Player{name, coins + coin_gain, unlocked, turnip, carrot, radish, tomato + amount}
        case other:
          Player{name, coins, unlocked, turnip, carrot, radish, tomato}

def player_spend(player: Player, amount: U32) -> Player:
  match player:
    case Player{name, coins, unlocked, turnip, carrot, radish, tomato}:
      Player{name, coins - amount, unlocked, turnip, carrot, radish, tomato}

def player_unlock(player: Player) -> Player:
  match player:
    case Player{name, coins, unlocked, turnip, carrot, radish, tomato}:
      Player{name, coins - unlock_cost(unlocked), unlocked + 1, turnip, carrot, radish, tomato}

def plot_find(plots: List(Plot), owner: String, index: U32) -> PlotFound:
  match plots:
    case Cons{head, tail}:
      match head:
        case Plot{stored, at, crop, planted_at, steals, thieves}:
          match String::eq(stored, owner) && (at == index):
            case 0:
              plot_find(tail, owner, index)
            case yes:
              PlotHere{Plot{stored, at, crop, planted_at, steals, thieves}}
    case Nil{}:
      PlotMissing{}

def plot_exists(plots: List(Plot), owner: String, index: U32) -> U32:
  match plot_find(plots, owner, index):
    case PlotHere{plot}:
      1
    case PlotMissing{}:
      0

def plot_replace_go(plots: List(Plot), owner: String, index: U32, replacement: Plot) -> List(Plot):
  match plots:
    case Cons{head, tail}:
      match head:
        case Plot{stored, at, crop, planted_at, steals, thieves}:
          match String::eq(stored, owner) && (at == index):
            case 0:
              Cons{Plot{stored, at, crop, planted_at, steals, thieves}, plot_replace_go(tail, owner, index, replacement)}
            case yes:
              Cons{replacement, tail}
    case Nil{}:
      Cons{replacement, Nil{}}

def plot_replace(plots: List(Plot), replacement: Plot) -> List(Plot):
  match replacement:
    case Plot{owner, index, crop, planted_at, steals, thieves}:
      plot_replace_go(plots, owner, index, Plot{owner, index, crop, planted_at, steals, thieves})

def plot_remove(plots: List(Plot), owner: String, index: U32) -> List(Plot):
  match plots:
    case Cons{head, tail}:
      match head:
        case Plot{stored, at, crop, planted_at, steals, thieves}:
          match String::eq(stored, owner) && (at == index):
            case 0:
              Cons{Plot{stored, at, crop, planted_at, steals, thieves}, plot_remove(tail, owner, index)}
            case yes:
              tail
    case Nil{}:
      Nil{}

def string_member(values: List(String), value: String) -> U32:
  match values:
    case Cons{head, tail}:
      match String::eq(head, value):
        case 0:
          string_member(tail, value)
        case yes:
          1
    case Nil{}:
      0

def theft_count(thefts: List(Theft), thief: String, owner: String, day: U32) -> U32:
  match thefts:
    case Cons{head, tail}:
      match head:
        case Theft{stored_thief, stored_owner, stored_day, plot, planted_at}:
          same = String::eq(stored_thief, thief) && (String::eq(stored_owner, owner) && (stored_day == day))
          same + theft_count(tail, thief, owner, day)
    case Nil{}:
      0

def farm_error(farm: Farm, note: String) -> FarmAction:
  FarmAction{farm, 0, note, 0}

def farm_ok(farm: Farm, note: String, amount: U32) -> FarmAction:
  FarmAction{farm, 1, note, amount}

def farm_new() -> Farm:
  Farm{Nil{}, Nil{}, Nil{}}

def farm_add_player(farm: Farm, name: String) -> Farm:
  match farm:
    case Farm{players, plots, thefts}:
      match player_exists(players, name):
        case 0:
          Farm{player_push(player_new(name), players), plots, thefts}
        case yes:
          Farm{players, plots, thefts}

def farm_plant_checked(farm: Farm, actor: Player, index: U32, crop: U32, now: U32) -> FarmAction:
  match farm:
    case Farm{players, plots, thefts}:
      match actor:
        case Player{name, coins, unlocked, turnip, carrot, radish, tomato}:
          match (index < unlocked) && (index < plot_count()):
            case 0:
              farm_error(Farm{players, plots, thefts}, "That plot is still locked.")
            case open:
              match crop_valid(crop) && (plot_exists(plots, name, index) == 0):
                case 0:
                  farm_error(Farm{players, plots, thefts}, "Choose an empty plot and a valid seed.")
                case valid:
                  cost = crop_cost(crop)
                  match coins >= cost:
                    case 0:
                      farm_error(Farm{players, plots, thefts}, "Not enough coins for that seed.")
                    case enough:
                      updated = player_spend(Player{name, coins, unlocked, turnip, carrot, radish, tomato}, cost)
                      farm_ok(
                        Farm{player_replace(players, updated), plot_push(Plot{name, index, crop, now, 0, no_strings()}, plots), thefts},
                        "Seed planted.",
                        0
                      )

def farm_plant(farm: Farm, actor: String, index: U32, crop: U32, now: U32) -> FarmAction:
  match farm:
    case Farm{players, plots, thefts}:
      match player_find(players, actor):
        case PlayerHere{player}:
          farm_plant_checked(Farm{players, plots, thefts}, player, index, crop, now)
        case PlayerMissing{}:
          farm_error(Farm{players, plots, thefts}, "Sign in before planting.")

def farm_harvest_plot(farm: Farm, actor: Player, plot: Plot, now: U32) -> FarmAction:
  match farm:
    case Farm{players, plots, thefts}:
      match plot:
        case Plot{owner, index, crop, planted_at, steals, thieves}:
          match actor:
            case Player{name, coins, unlocked, turnip, carrot, radish, tomato}:
              match String::eq(name, owner) && crop_ready(Plot{owner, index, crop, planted_at, steals, thieves}, now):
                case 0:
                  farm_error(Farm{players, plots, thefts}, "Only the owner can harvest a mature crop.")
                case ready:
                  amount = yield_remaining(steals)
                  gain = amount * crop_value(crop)
                  updated = player_add_crop(Player{name, coins, unlocked, turnip, carrot, radish, tomato}, crop, amount, gain)
                  farm_ok(Farm{player_replace(players, updated), plot_remove(plots, owner, index), thefts}, "Crop harvested.", amount)

def farm_harvest(farm: Farm, actor: String, index: U32, now: U32) -> FarmAction:
  match farm:
    case Farm{players, plots, thefts}:
      match player_find(players, actor):
        case PlayerMissing{}:
          farm_error(Farm{players, plots, thefts}, "There is no crop to harvest there.")
        case PlayerHere{player}:
          match plot_find(plots, actor, index):
            case PlotHere{plot}:
              farm_harvest_plot(Farm{players, plots, thefts}, player, plot, now)
            case PlotMissing{}:
              farm_error(Farm{players, plots, thefts}, "There is no crop to harvest there.")

def farm_steal_commit(farm: Farm, thief: Player, plot: Plot, now: U32) -> FarmAction:
  match farm:
    case Farm{players, plots, thefts}:
      match thief:
        case Player{name, coins, unlocked, turnip, carrot, radish, tomato}:
          match plot:
            case Plot{owner, index, crop, planted_at, steals, thieves}:
              day = current_day(now)
              daily = theft_count(thefts, name, owner, day)
              permitted = (String::eq(name, owner) == 0) && (
                crop_ready(Plot{owner, index, crop, planted_at, steals, thieves}, now) && (
                steal_slot_open(steals) && ((string_member(thieves, name) == 0) && daily_slot_open(daily))))
              match permitted:
                case 0:
                  farm_error(Farm{players, plots, thefts}, "Steal denied: mature crops only, once per crop, at most three thieves and two crops per owner each day.")
                case yes:
                  updated_player = player_add_crop(Player{name, coins, unlocked, turnip, carrot, radish, tomato}, crop, steal_amount(), 0)
                  farm_ok(
                    Farm{
                      player_replace(players, updated_player),
                      plot_replace(plots, Plot{owner, index, crop, planted_at, steals + 1, string_push(name, thieves)}),
                      theft_push(Theft{name, owner, day, index, planted_at}, thefts)
                    },
                    "You stole one quarter of the crop.",
                    steal_amount()
                  )

def farm_steal(farm: Farm, actor: String, owner: String, index: U32, now: U32) -> FarmAction:
  match farm:
    case Farm{players, plots, thefts}:
      match player_find(players, actor):
        case PlayerMissing{}:
          farm_error(Farm{players, plots, thefts}, "That crop does not exist.")
        case PlayerHere{player}:
          match plot_find(plots, owner, index):
            case PlotHere{plot}:
              farm_steal_commit(Farm{players, plots, thefts}, player, plot, now)
            case PlotMissing{}:
              farm_error(Farm{players, plots, thefts}, "That crop does not exist.")

def farm_unlock(farm: Farm, actor: String) -> FarmAction:
  match farm:
    case Farm{players, plots, thefts}:
      match player_find(players, actor):
        case PlayerMissing{}:
          farm_error(Farm{players, plots, thefts}, "Sign in before unlocking land.")
        case PlayerHere{player}:
          match player:
            case Player{name, coins, unlocked, turnip, carrot, radish, tomato}:
              match (unlocked < plot_count()) && (coins >= unlock_cost(unlocked)):
                case 0:
                  farm_error(Farm{players, plots, thefts}, "Maximum land reached or not enough coins.")
                case yes:
                  farm_ok(
                    Farm{player_replace(players, player_unlock(Player{name, coins, unlocked, turnip, carrot, radish, tomato})), plots, thefts},
                    "One new plot unlocked.",
                    unlocked + 1
                  )

# Proofs
# ======

def InitialPlotsFour() -> Type:
  {initial_unlocked() = 4 : U32}

def initial_plots_four() -> InitialPlotsFour():
  {=}

def TheftIsQuarter() -> Type:
  {(steal_amount() * 4) = crop_yield() : U32}

def theft_is_quarter() -> TheftIsQuarter():
  {=}

def OwnerWholeYield() -> Type:
  {yield_remaining(0) = 12 : U32}

def owner_whole_yield() -> OwnerWholeYield():
  {=}

def OwnerAfterOne() -> Type:
  {yield_remaining(1) = 9 : U32}

def owner_after_one() -> OwnerAfterOne():
  {=}

def OwnerAfterTwo() -> Type:
  {yield_remaining(2) = 6 : U32}

def owner_after_two() -> OwnerAfterTwo():
  {=}

def OwnerKeepsQuarter() -> Type:
  {yield_remaining(3) = 3 : U32}

def owner_keeps_quarter() -> OwnerKeepsQuarter():
  {=}

def ExtraStealCannotReduceReserve() -> Type:
  {yield_remaining(99) = 3 : U32}

def extra_steal_cannot_reduce_reserve() -> ExtraStealCannotReduceReserve():
  {=}

def ThreeStealsClosePlot() -> Type:
  {steal_slot_open(3) = 0 : U32}

def three_steals_close_plot() -> ThreeStealsClosePlot():
  {=}

def TwoDailyStealsCloseOwner() -> Type:
  {daily_slot_open(2) = 0 : U32}

def two_daily_steals_close_owner() -> TwoDailyStealsCloseOwner():
  {=}

def proof_visitors() -> List(String):
  string_push("visitor", no_strings())

def SameThiefDetected() -> Type:
  {string_member(proof_visitors(), "visitor") = 1 : U32}

def same_thief_detected() -> SameThiefDetected():
  {=}

def OtherThiefNotDetected() -> Type:
  {string_member(proof_visitors(), "other") = 0 : U32}

def other_thief_not_detected() -> OtherThiefNotDetected():
  {=}

def proof_thefts() -> List(Theft):
  theft_push(
    Theft{"visitor", "owner", 7, 0, 100},
    theft_push(Theft{"visitor", "owner", 7, 1, 200}, Nil{})
  )

def TwoTheftsCountExactly() -> Type:
  {
    theft_count(proof_thefts(), "visitor", "owner", 7) = 2 : U32
  }

def two_thefts_count_exactly() -> TwoTheftsCountExactly():
  {=}

def proof_audit() -> U32:
  %initial_plots_four()
  %theft_is_quarter()
  %owner_whole_yield()
  %owner_after_one()
  %owner_after_two()
  %owner_keeps_quarter()
  %extra_steal_cannot_reduce_reserve()
  %three_steals_close_plot()
  %two_daily_steals_close_owner()
  %same_thief_detected()
  %other_thief_not_detected()
  %two_thefts_count_exactly()
  1

def test() -> U32:
  proof_audit()
