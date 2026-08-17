# Four-seat Texas Hold'em / Omaha poker for Bend3.
#
# Bend owns the deck, private cards, betting legality, AI decisions, streets,
# showdown evaluation, chips, dealer button, invitations, and table state.
# The browser renders JSON and estimates odds from only the cards visible to its
# authenticated seat.
#
# GET /                         browser client
# GET /state/<seat>/<token>    private view for one seat
# GET /claim/<seat>            turn an AI seat into an invited browser seat
# GET /action/<seat>/<token>/<0..3>/<amount>
#                               fold/check/call/raise-to
# GET /new/<seat>/<token>/<variant>  new Texas (0) or Omaha (1) hand
#
# no-halt
# skip-native

import ../../bend-base/Base
import ../Compat
import ../../bend-base/IO/TCP
import ../../bend-base/IO/HTTP
import ../../bend-base/JSON

type Hands:
  Hands{seat0: List(U32), seat1: List(U32), seat2: List(U32), seat3: List(U32)}

type Four:
  Four{seat0: U32, seat1: U32, seat2: U32, seat3: U32}

type Game:
  Game{variant: U32, phase: U32, dealer: U32, turn: U32, pot: U32, current: U32, min_raise: U32, seed: U32, hand_number: U32, hands: Hands, board: List(U32), stacks: Four, bets: Four, states: Four, acted: U32, personas: Four, humans: U32, tokens: Four, winner: U32, note: String}

type Action:
  Action{game: Game, ok: U32, note: String}

type Routed:
  Routed{game: Game, response: HTTP.Response}

# ---------------------------------------------------------------- List

def list_nth(list: List(U32), index: U32) -> U32:
  match list:
    case List.Nil{}: 0
    case List.Cons{head, tail}:
      match index:
        case 0: head
        case more: list_nth(tail, more - 1)

def list_take_json(list: List(U32), wanted: U32, first: U32) -> String:
  match wanted:
    case 0: "]"
    case more:
      match list:
        case List.Nil{}: "]"
        case List.Cons{head, tail}:
          prefix : String = match first:
                              case 0: ","
                              case yes: ""
          String.flatten([prefix, String.from_u32(head), list_take_json(tail, more - 1, 0)])

def list_json(list: List(U32), wanted: U32) -> String:
  String.concat("[", list_take_json(list, wanted, 1))

# ---------------------------------------------------------------- Four

def four_get(four: Four, seat: U32) -> U32:
  match four:
    case Four.Four{seat0, seat1, seat2, seat3}:
      match seat % 4:
        case 0: seat0
        case 1: seat1
        case 2: seat2
        case other: seat3

def four_set(four: Four, seat: U32, value: U32) -> Four:
  match four:
    case Four.Four{seat0, seat1, seat2, seat3}:
      match seat % 4:
        case 0: Four.Four{value, seat1, seat2, seat3}
        case 1: Four.Four{seat0, value, seat2, seat3}
        case 2: Four.Four{seat0, seat1, value, seat3}
        case other: Four.Four{seat0, seat1, seat2, value}

def four_sum(four: Four) -> U32:
  match four:
    case Four.Four{seat0, seat1, seat2, seat3}: (seat0 + seat1) + (seat2 + seat3)

# ---------------------------------------------------------------- Hands and deck

def hands_get(hands: Hands, seat: U32) -> List(U32):
  match hands:
    case Hands.Hands{seat0, seat1, seat2, seat3}:
      match seat % 4:
        case 0: seat0
        case 1: seat1
        case 2: seat2
        case other: seat3

def hands_set(hands: Hands, seat: U32, cards: List(U32)) -> Hands:
  match hands:
    case Hands.Hands{seat0, seat1, seat2, seat3}:
      match seat % 4:
        case 0: Hands.Hands{cards, seat1, seat2, seat3}
        case 1: Hands.Hands{seat0, cards, seat2, seat3}
        case 2: Hands.Hands{seat0, seat1, cards, seat3}
        case other: Hands.Hands{seat0, seat1, seat2, cards}

def hands_add(hands: Hands, seat: U32, card: U32) -> Hands:
  hands_set(hands, seat, List.Cons{card, hands_get(hands, seat)})

def u32_multiplier(choice: U32) -> U32:
  match choice % 24:
    case 0: 1
    case 1: 3
    case 2: 5
    case 3: 7
    case 4: 9
    case 5: 11
    case 6: 15
    case 7: 17
    case 8: 19
    case 9: 21
    case 10: 23
    case 11: 25
    case 12: 27
    case 13: 29
    case 14: 31
    case 15: 33
    case 16: 35
    case 17: 37
    case 18: 41
    case 19: 43
    case 20: 45
    case 21: 47
    case 22: 49
    case other: 51

def u32_deck_card(seed: U32, index: U32) -> U32:
  ((index * u32_multiplier(seed)) + ((seed / 24) % 52)) % 52

def hands_deal_round(seed: U32, round: U32, seat: U32, hands: Hands) -> Hands:
  match seat == 4:
    case 0: hands_deal_round(seed, round, seat + 1, hands_add(hands, seat, u32_deck_card(seed, (round * 4) + seat)))
    case done: hands

def hands_deal_go(seed: U32, rounds: U32, round: U32, hands: Hands) -> Hands:
  match round == rounds:
    case 0: hands_deal_go(seed, rounds, round + 1, hands_deal_round(seed, round, 0, hands))
    case done: hands

def hands_deal(seed: U32, variant: U32) -> Hands:
  rounds = 2 + (variant * 2)
  hands_deal_go(seed, rounds, 0, Hands.Hands{List.Nil{}, List.Nil{}, List.Nil{}, List.Nil{}})

def list_board(seed: U32, variant: U32) -> List(U32):
  offset = 8 + (variant * 8)
  [u32_deck_card(seed, offset), u32_deck_card(seed, offset + 1), u32_deck_card(seed, offset + 2), u32_deck_card(seed, offset + 3), u32_deck_card(seed, offset + 4)]

# ---------------------------------------------------------------- Five-card evaluation

def list_rank_count(cards: List(U32), rank: U32) -> U32:
  match cards:
    case List.Nil{}: 0
    case List.Cons{card, tail}: ((card % 13) == rank) + list_rank_count(tail, rank)

def list_rank_mask(cards: List(U32)) -> U32:
  match cards:
    case List.Nil{}: 0
    case List.Cons{card, tail}: (1 << (card % 13)) .|. list_rank_mask(tail)

def list_flush(cards: List(U32)) -> U32:
  suit = list_nth(cards, 0) / 13
  ((list_nth(cards, 1) / 13) == suit) && (((list_nth(cards, 2) / 13) == suit) && (((list_nth(cards, 3) / 13) == suit) && ((list_nth(cards, 4) / 13) == suit)))

def u32_straight_high(mask: U32, count: U32) -> U32:
  match count == 4:
    case 0:
      high = count - 1
      run = (((((mask >> high) .&. 1) * ((mask >> (high - 1)) .&. 1)) * ((mask >> (high - 2)) .&. 1)) * ((mask >> (high - 3)) .&. 1)) * ((mask >> (high - 4)) .&. 1)
      match run:
        case 0: u32_straight_high(mask, count - 1)
        case yes: high + 1
    case wheel:
      ace = (mask >> 12) .&. 1
      low0 = mask .&. 1
      low1 = (mask >> 1) .&. 1
      low2 = (mask >> 2) .&. 1
      low3 = (mask >> 3) .&. 1
      ((((ace * low0) * low1) * low2) * low3) * 4

def list_rank_with_count(cards: List(U32), wanted: U32, skip: U32, count: U32) -> U32:
  match count:
    case 0: 0
    case more:
      rank = count - 1
      match list_rank_count(cards, rank) == wanted:
        case 0: list_rank_with_count(cards, wanted, skip, count - 1)
        case found:
          match skip:
            case 0: rank + 1
            case left: list_rank_with_count(cards, wanted, left - 1, count - 1)

def u32_pack(a: U32, b: U32, c: U32, d: U32, e: U32) -> U32:
  ab = (a * 14) + b
  abc = (ab * 14) + c
  abcd = (abc * 14) + d
  (abcd * 14) + e

def list_five_score(cards: List(U32)) -> U32:
  mask = list_rank_mask(cards)
  straight = u32_straight_high(mask, 13)
  flush = list_flush(cards)
  four = list_rank_with_count(cards, 4, 0, 13)
  three = list_rank_with_count(cards, 3, 0, 13)
  pair0 = list_rank_with_count(cards, 2, 0, 13)
  pair1 = list_rank_with_count(cards, 2, 1, 13)
  one0 = list_rank_with_count(cards, 1, 0, 13)
  one1 = list_rank_with_count(cards, 1, 1, 13)
  one2 = list_rank_with_count(cards, 1, 2, 13)
  one3 = list_rank_with_count(cards, 1, 3, 13)
  one4 = list_rank_with_count(cards, 1, 4, 13)
  match straight * flush:
    case 0:
      match four:
        case 0:
          match three * pair0:
            case 0:
              match flush:
                case 0:
                  match straight:
                    case 0:
                      match three:
                        case 0:
                          match pair1:
                            case 0:
                              match pair0:
                                case 0: u32_pack(one0, one1, one2, one3, one4)
                                case pair: 1000000 + u32_pack(pair, one0, one1, one2, 0)
                            case second_pair: 2000000 + u32_pack(pair0, pair1, one0, 0, 0)
                        case trips: 3000000 + u32_pack(trips, one0, one1, 0, 0)
                    case run: 4000000 + u32_pack(run, 0, 0, 0, 0)
                case suited: 5000000 + u32_pack(one0, one1, one2, one3, one4)
            case full: 6000000 + u32_pack(three, pair0, 0, 0, 0)
        case quads: 7000000 + u32_pack(quads, one0, 0, 0, 0)
    case straight_flush: 8000000 + u32_pack(straight, 0, 0, 0, 0)

def list_choose_score(cards: List(U32), chosen: List(U32), count: U32) -> U32:
  match count == 5:
    case 0:
      match cards:
        case List.Nil{}: 0
        case List.Cons{head, tail}:
          with_head = list_choose_score(tail, List.Cons{head, chosen}, count + 1)
          without = list_choose_score(tail, chosen, count)
          U32.max(with_head, without)
    case five: list_five_score(chosen)

def list_texas_score(hole: List(U32), board: List(U32)) -> U32:
  list_choose_score(List.concat(U32, hole, board), List.Nil{}, 0)

def list_omaha_board(hole: List(U32), board: List(U32), a: U32, b: U32, c: U32, d: U32, e: U32) -> U32:
  match e == 5:
    case 0:
      score = list_five_score([list_nth(hole, a), list_nth(hole, b), list_nth(board, c), list_nth(board, d), list_nth(board, e)])
      U32.max(score, list_omaha_board(hole, board, a, b, c, d, e + 1))
    case done: 0

def list_omaha_fourth(hole: List(U32), board: List(U32), a: U32, b: U32, c: U32, d: U32) -> U32:
  match d == 4:
    case 0: U32.max(list_omaha_board(hole, board, a, b, c, d, d + 1), list_omaha_fourth(hole, board, a, b, c, d + 1))
    case done: 0

def list_omaha_third(hole: List(U32), board: List(U32), a: U32, b: U32, c: U32) -> U32:
  match c == 3:
    case 0: U32.max(list_omaha_fourth(hole, board, a, b, c, c + 1), list_omaha_third(hole, board, a, b, c + 1))
    case done: 0

def list_omaha_second(hole: List(U32), board: List(U32), a: U32, b: U32) -> U32:
  match b == 4:
    case 0: U32.max(list_omaha_third(hole, board, a, b, 0), list_omaha_second(hole, board, a, b + 1))
    case done: 0

def list_omaha_first(hole: List(U32), board: List(U32), a: U32) -> U32:
  match a == 3:
    case 0: U32.max(list_omaha_second(hole, board, a, a + 1), list_omaha_first(hole, board, a + 1))
    case done: 0

def list_omaha_score(hole: List(U32), board: List(U32)) -> U32:
  list_omaha_first(hole, board, 0)

def game_seat_score(game: Game, seat: U32) -> U32:
  match game:
    case Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      match variant:
        case 0: list_texas_score(hands_get(hands, seat), board)
        case omaha: list_omaha_score(hands_get(hands, seat), board)

# ---------------------------------------------------------------- Personas and AI

def u32_persona_name(persona: U32) -> String:
  match persona % 10:
    case 0: "Ada All-In"
    case 1: "Bluffalo Bill"
    case 2: "Callie Station"
    case 3: "Doctor Draw"
    case 4: "Mina Maxbet"
    case 5: "Nash Sparrow"
    case 6: "Oma Holmes"
    case 7: "River Rook"
    case 8: "Texas Tern"
    case other: "Vera Variance"

def u32_persona_style(persona: U32) -> String:
  match persona % 10:
    case 0: "fearless"
    case 1: "tricky"
    case 2: "calling-station"
    case 3: "draw-chaser"
    case 4: "aggressive"
    case 5: "balanced"
    case 6: "analytical"
    case 7: "patient"
    case 8: "tight"
    case other: "unpredictable"

def u32_persona_aggression(persona: U32) -> U32:
  match persona % 10:
    case 0: 92
    case 1: 72
    case 2: 25
    case 3: 48
    case 4: 84
    case 5: 58
    case 6: 52
    case 7: 35
    case 8: 30
    case other: 64

def u32_hole_power(hole: List(U32)) -> U32:
  a = list_nth(hole, 0) % 13
  b = list_nth(hole, 1) % 13
  pair = (a == b) * 45
  suited = ((list_nth(hole, 0) / 13) == (list_nth(hole, 1) / 13)) * 10
  ((pair + suited) + (a + b)) + 8

# ---------------------------------------------------------------- Betting state

def game_active_count(states: Four, seat: U32) -> U32:
  match seat == 4:
    case 0: (four_get(states, seat) != 1) + game_active_count(states, seat + 1)
    case done: 0

def game_live_mask(states: Four, seat: U32) -> U32:
  match seat == 4:
    case 0: (((four_get(states, seat) != 1) * (1 << seat)) .|. game_live_mask(states, seat + 1))
    case done: 0

def game_bets_equal(bets: Four, states: Four, current: U32, seat: U32) -> U32:
  match seat == 4:
    case 0:
      inactive = four_get(states, seat) > 0
      ((inactive || (four_get(bets, seat) == current)) && game_bets_equal(bets, states, current, seat + 1))
    case done: 1

def u32_next_live(states: Four, seat: U32, fuel: U32) -> U32:
  next = (seat + 1) % 4
  match fuel:
    case 0: next
    case more:
      match four_get(states, next) == 0:
        case 0: u32_next_live(states, next, fuel - 1)
        case yes: next

def u32_next_not_folded(states: Four, seat: U32, fuel: U32) -> U32:
  next = (seat + 1) % 4
  match fuel:
    case 0: next
    case more:
      match four_get(states, next) != 1:
        case 0: u32_next_not_folded(states, next, fuel - 1)
        case yes: next

def four_pay(stacks: Four, bets: Four, seat: U32, wanted: U32) -> (Four & Four & U32):
  stack = four_get(stacks, seat)
  paid = U32.min(stack, wanted)
  new_stacks = four_set(stacks, seat, stack - paid)
  new_bets = four_set(bets, seat, four_get(bets, seat) + paid)
  (new_stacks, new_bets, paid)

def game_showdown(game: Game) -> Game:
  match game:
    case Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      live = game_live_mask(states, 0)
      score0 = game_seat_score(Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 0) * ((live .&. 1) > 0)
      score1 = game_seat_score(Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 1) * ((live .&. 2) > 0)
      score2 = game_seat_score(Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 2) * ((live .&. 4) > 0)
      score3 = game_seat_score(Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 3) * ((live .&. 8) > 0)
      best = U32.max(U32.max(score0, score1), U32.max(score2, score3))
      winners = (((score0 == best) * ((live .&. 1) > 0)) + ((score1 == best) * ((live .&. 2) > 0))) + (((score2 == best) * ((live .&. 4) > 0)) + ((score3 == best) * ((live .&. 8) > 0)))
      share = pot / winners
      next0 = four_get(stacks, 0) + (share * ((score0 == best) * ((live .&. 1) > 0)))
      next1 = four_get(stacks, 1) + (share * ((score1 == best) * ((live .&. 2) > 0)))
      next2 = four_get(stacks, 2) + (share * ((score2 == best) * ((live .&. 4) > 0)))
      next3 = four_get(stacks, 3) + (share * ((score3 == best) * ((live .&. 8) > 0)))
      winner_mask = (((score0 == best) * ((live .&. 1) > 0)) + (((score1 == best) * ((live .&. 2) > 0)) * 2)) + ((((score2 == best) * ((live .&. 4) > 0)) * 4) + (((score3 == best) * ((live .&. 8) > 0)) * 8))
      Game.Game{variant, 4, dealer, turn, 0, current, min_raise, seed, hand_number, hands, board, Four.Four{next0, next1, next2, next3}, bets, states, acted, personas, humans, tokens, winner_mask, "Showdown complete. The best five-card hand wins the pot."}

def game_fold_win(game: Game) -> Game:
  match game:
    case Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      seat = u32_next_not_folded(states, turn, 4)
      next_stacks = four_set(stacks, seat, four_get(stacks, seat) + pot)
      Game.Game{variant, 4, dealer, seat, 0, current, min_raise, seed, hand_number, hands, board, next_stacks, bets, states, acted, personas, humans, tokens, 1 << seat, "Everyone else folded. The last player wins the pot."}

def game_advance_street(game: Game) -> Game:
  match game:
    case Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      match phase == 3:
        case 0:
          first = u32_next_live(states, dealer, 4)
          label : String = match phase:
                            case 0: "The flop is dealt."
                            case 1: "The turn is dealt."
                            case other: "The river is dealt."
          Game.Game{variant, phase + 1, dealer, first, pot, 0, 20, seed, hand_number, hands, board, stacks, Four.Four{0, 0, 0, 0}, states, 0, personas, humans, tokens, 0, label}
        case river: game_showdown(Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note})

def game_after_action(game: Game) -> Game:
  match game:
    case Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      match game_active_count(states, 0) == 1:
        case 0:
          live = game_live_mask(states, 0)
          complete = ((acted .&. live) == live) && game_bets_equal(bets, states, current, 0)
          match complete:
            case 0:
              next = u32_next_live(states, turn, 4)
              Game.Game{variant, phase, dealer, next, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}
            case yes: game_advance_street(Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note})
        case one: game_fold_win(Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note})

def game_action_seat(game: Game, seat: U32, kind: U32, amount: U32) -> Action:
  match game:
    case Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      match (phase < 4) && ((turn == seat) && (four_get(states, seat) == 0)):
        case 0: Action.Action{game, 0, "It is not that seat's turn."}
        case yes:
          own_bet = four_get(bets, seat)
          stack = four_get(stacks, seat)
          call = current - own_bet
          match kind:
            case 0:
              next : Game = Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, four_set(states, seat, 1), acted .|. (1 << seat), personas, humans, tokens, winner, "Fold."}
              Action.Action{game_after_action(next), 1, ""}
            case 1:
              match call == 0:
                case 0: Action.Action{game, 0, "Check is unavailable while facing a bet."}
                case check:
                  next : Game = Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted .|. (1 << seat), personas, humans, tokens, winner, "Check."}
                  Action.Action{game_after_action(next), 1, ""}
            case 2:
              match call > stack:
                case 0:
                  paid = four_pay(stacks, bets, seat, call)
                  match paid:
                    case (next_stacks, next_bets, chips):
                      next_states : Four = match chips == stack:
                                                   case 0: states
                                                   case all: four_set(states, seat, 2)
                      next : Game = Game.Game{variant, phase, dealer, turn, pot + chips, current, min_raise, seed, hand_number, hands, board, next_stacks, next_bets, next_states, acted .|. (1 << seat), personas, humans, tokens, winner, "Call."}
                      Action.Action{game_after_action(next), 1, ""}
                case short:
                  paid = four_pay(stacks, bets, seat, stack)
                  match paid:
                    case (next_stacks, next_bets, chips):
                      next : Game = Game.Game{variant, phase, dealer, turn, pot + chips, current, min_raise, seed, hand_number, hands, board, next_stacks, next_bets, four_set(states, seat, 2), acted .|. (1 << seat), personas, humans, tokens, winner, "All-in call."}
                      Action.Action{game_after_action(next), 1, ""}
            case other:
              max_total = own_bet + stack
              min_total = current + min_raise
              match (amount >= min_total) && (amount <= max_total):
                case 0: Action.Action{game, 0, "Raise-to amount is outside the legal slider range."}
                case raise:
                  wanted = amount - own_bet
                  paid = four_pay(stacks, bets, seat, wanted)
                  match paid:
                    case (next_stacks, next_bets, chips):
                      next_states : Four = match chips == stack:
                                                   case 0: states
                                                   case all: four_set(states, seat, 2)
                      next : Game = Game.Game{variant, phase, dealer, turn, pot + chips, amount, amount - current, seed, hand_number, hands, board, next_stacks, next_bets, next_states, 1 << seat, personas, humans, tokens, winner, "Raise."}
                      Action.Action{game_after_action(next), 1, ""}

def game_ai_action(game: Game) -> Action:
  match game:
    case Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      stack = four_get(stacks, turn)
      call = current - four_get(bets, turn)
      persona = four_get(personas, turn)
      aggression = u32_persona_aggression(persona)
      strength = u32_hole_power(hands_get(hands, turn)) + (phase * 10)
      whim = ((seed + (hand_number * 17)) + ((turn * 31) + (acted * 7))) % 100
      can_raise = stack > (call + min_raise)
      kind : U32 = match call:
                         case 0:
                           match can_raise && (whim < (aggression / 3)):
                             case 0: 1
                             case yes: 3
                         case facing:
                           match (strength + (aggression / 2)) < (25 + (call / 3)):
                             case 0:
                               match can_raise && (whim < (aggression / 5)):
                                 case 0: 2
                                 case yes: 3
                             case weak: 0
      amount = (current + min_raise) + (((aggression + whim) % 4) * 10)
      capped = U32.min(amount, four_get(bets, turn) + stack)
      game_action_seat(game, turn, kind, capped)

def game_auto(game: Game, fuel: U32) -> Game:
  match fuel:
    case 0: game
    case more:
      match game:
        case Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
          match (phase < 4) && (((humans >> turn) .&. 1) == 0):
            case 0: game
            case ai:
              match game_ai_action(game):
                case Action.Action{next, ok, action_note}:
                  match ok:
                    case 0: game
                    case yes: game_auto(next, more - 1)

# ---------------------------------------------------------------- New hands, authentication, actions

def game_next_seed(seed: U32) -> U32:
  (seed * 1664525) + 1013904223

def game_personas(seed: U32) -> Four:
  first = seed % 10
  Four.Four{first, (first + 3) % 10, (first + 6) % 10, (first + 9) % 10}

def game_deal(seed: U32, variant: U32, dealer: U32, hand_number: U32, stacks: Four, humans: U32, tokens: Four) -> Game:
  small = (dealer + 1) % 4
  big = (dealer + 2) % 4
  paid_small = four_pay(stacks, Four.Four{0, 0, 0, 0}, small, 10)
  match paid_small:
    case (stacks1, bets1, chips1):
      paid_big = four_pay(stacks1, bets1, big, 20)
      match paid_big:
        case (stacks2, bets2, chips2):
          raw : Game = Game.Game{variant, 0, dealer, (dealer + 3) % 4, chips1 + chips2, 20, 20, seed, hand_number, hands_deal(seed, variant), list_board(seed, variant), stacks2, bets2, Four.Four{0, 0, 0, 0}, 0, game_personas(seed), humans, tokens, 0, "Blinds posted. Action begins before the flop."}
          game_auto(raw, 96)

def game_empty(seed: U32) -> Game:
  game_deal(seed, 0, 3, 1, Four.Four{1000, 1000, 1000, 1000}, 1, Four.Four{0, 0, 0, 0})

def game_authorized(game: Game, seat: U32, token: U32) -> U32:
  match game:
    case Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      match seat:
        case 0: token == 0
        case other: (((humans >> seat) .&. 1) == 1) && (four_get(tokens, seat) == token)

def game_new(game: Game, seat: U32, token: U32, variant: U32) -> Action:
  match game_authorized(game, seat, token):
    case 0: Action.Action{game, 0, "That seat token is not authorized."}
    case yes:
      match game:
        case Game.Game{old_variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
          next_seed = game_next_seed(seed + hand_number)
          next_variant = variant % 2
          reset_stacks : Four = match (four_sum(stacks) < 80) || (phase < 4):
                                                                      case 0: stacks
                                                                      case reset: Four.Four{1000, 1000, 1000, 1000}
          Action.Action{game_deal(next_seed, next_variant, (dealer + 1) % 4, hand_number + 1, reset_stacks, humans, tokens), 1, ""}

def game_claim(game: Game, seat: U32) -> (Game & U32 & U32):
  match game:
    case Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      match (seat > 0) && ((seat < 4) && (((humans >> seat) .&. 1) == 0)):
        case 0: (game, 0, 0)
        case yes:
          token = game_next_seed((seed + (seat * 2654435761)) + hand_number)
          next : Game = Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans .|. (1 << seat), four_set(tokens, seat, token), winner, "A browser player joined the table."}
          (next, token, 1)

def game_action(game: Game, seat: U32, token: U32, kind: U32, amount: U32) -> Action:
  match game_authorized(game, seat, token):
    case 0: Action.Action{game, 0, "That seat token is not authorized."}
    case yes:
      match ((game_humans(game) >> seat) .&. 1) == 1:
        case 0: Action.Action{game, 0, "That seat is controlled by Bend AI."}
        case human:
          match game_action_seat(game, seat, kind, amount):
            case Action.Action{next, ok, note}:
              match ok:
                case 0: Action.Action{next, ok, note}
                case yes: Action.Action{game_auto(next, 96), 1, ""}

def game_humans(game: Game) -> U32:
  match game:
    case Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}: humans

# Pure regression probe.
def test() -> U32:
  texas = game_empty(123456789)
  match texas:
    case Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      deal_ok = (List.length(U32, hands_get(hands, 0)) == 2) && ((List.length(U32, hands_get(hands, 1)) == 2) && (List.length(U32, board) == 5))
      unique = (list_nth(hands_get(hands, 0), 0) != list_nth(hands_get(hands, 1), 0)) && (list_nth(board, 0) != list_nth(board, 1))
      personas_ok = (four_get(personas, 0) != four_get(personas, 1)) && (four_get(personas, 1) != four_get(personas, 2))
      sample_royal = list_five_score([8, 9, 10, 11, 12])
      sample_pair = list_five_score([0, 13, 2, 4, 6])
      deal_ok && (unique && (personas_ok && (((sample_royal / 1000000) == 8) && ((sample_pair / 1000000) == 1))))

# ---------------------------------------------------------------- JSON

def u32_phase_cards(phase: U32) -> U32:
  match phase:
    case 0: 0
    case 1: 3
    case 2: 4
    case other: 5

def game_hole_json(hands: Hands, seat: U32, viewer: U32, authorized: U32, showdown: U32) -> String:
  match showdown || (authorized && (seat == viewer)):
    case 0: "[]"
    case reveal: list_json(hands_get(hands, seat), 4)

def game_seat_json(game: Game, seat: U32, viewer: U32, authorized: U32) -> String:
  match game:
    case Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      persona = four_get(personas, seat)
      String.flatten([
        "{\"seat\":", String.from_u32(seat), ",\"name\":", JSON.quoted(u32_persona_name(persona), ""),
        ",\"style\":", JSON.quoted(u32_persona_style(persona), ""), ",\"aggression\":", String.from_u32(u32_persona_aggression(persona)),
        ",\"human\":", String.from_u32((humans >> seat) .&. 1), ",\"stack\":", String.from_u32(four_get(stacks, seat)),
        ",\"bet\":", String.from_u32(four_get(bets, seat)), ",\"state\":", String.from_u32(four_get(states, seat)),
        ",\"dealer\":", String.from_u32(seat == dealer), ",\"winner\":", String.from_u32((winner >> seat) .&. 1),
        ",\"cards\":", game_hole_json(hands, seat, viewer, authorized, phase == 4), "}"
      ])

def game_json(game: Game, ok: U32, action_note: String, viewer: U32, token: U32) -> String:
  match game:
    case Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      authorized = game_authorized(Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, viewer, token)
      shown_note : String = match String.length(action_note):
                              case 0: note
                              case present: action_note
      max_raise = four_get(bets, viewer) + four_get(stacks, viewer)
      String.flatten([
        "{\"ok\":", String.from_u32(ok), ",\"authorized\":", String.from_u32(authorized), ",\"note\":", JSON.quoted(shown_note, ""),
        ",\"variant\":", String.from_u32(variant), ",\"phase\":", String.from_u32(phase), ",\"dealer\":", String.from_u32(dealer),
        ",\"turn\":", String.from_u32(turn), ",\"pot\":", String.from_u32(pot), ",\"currentBet\":", String.from_u32(current),
        ",\"minRaise\":", String.from_u32(min_raise), ",\"maxRaise\":", String.from_u32(max_raise), ",\"handNumber\":", String.from_u32(hand_number),
        ",\"viewer\":", String.from_u32(viewer), ",\"seatToken\":", String.from_u32(token), ",\"board\":", list_json(board, u32_phase_cards(phase)),
        ",\"players\":[", game_seat_json(Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 0, viewer, authorized),
        ",", game_seat_json(Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 1, viewer, authorized),
        ",", game_seat_json(Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 2, viewer, authorized),
        ",", game_seat_json(Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 3, viewer, authorized), "]}"
      ])

def game_response(game: Game, ok: U32, note: String, viewer: U32, token: U32) -> HTTP.Response:
  HTTP.Response.Response{200,
    [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"}, HTTP.Header.Header{"Cache-Control", "no-store"}],
    Bytes.from_string(game_json(game, ok, note, viewer, token))}

def action_routed(action: Action, viewer: U32, token: U32) -> Routed:
  match action:
    case Action.Action{game, ok, note}: Routed.Routed{game, game_response(game, ok, note, viewer, token)}

def game_routed(game: Game, viewer: U32, token: U32) -> Routed:
  Routed.Routed{game, game_response(game, 1, "", viewer, token)}

# ---------------------------------------------------------------- HTTP routes

def result_index(result: Result((U32 & String), String), game: Game) -> IO(Routed):
  match result:
    case Result.Done{html}: IO.pure(Routed, Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}: IO.pure(Routed, Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "Poker page not found -- run from the repository root\n")})

def game_index(game: Game) -> IO(Routed):
  do IO(Routed):
    result <- IO.read_text("gabriel_demos/poker_web/index.html")
    result_index(result, game)

def list_action(name: String, args: List(String), game: Game) -> IO(Routed):
  match String.eq_u32(name, "state"):
    case 0:
      match String.eq_u32(name, "claim"):
        case 0:
          match String.eq_u32(name, "action"):
            case 0:
              match String.eq_u32(name, "new"):
                case 0: IO.pure(Routed, Routed.Routed{game, HTTP.not_found()})
                case fresh:
                  match args:
                    case List.Cons{seat, List.Cons{token, List.Cons{variant, rest}}}: IO.pure(Routed, action_routed(game_new(game, String.to_u32(seat), String.to_u32(token), String.to_u32(variant)), String.to_u32(seat), String.to_u32(token)))
                    case other: IO.pure(Routed, Routed.Routed{game, HTTP.not_found()})
            case act:
              match args:
                case List.Cons{seat, List.Cons{token, List.Cons{kind, List.Cons{amount, rest}}}}: IO.pure(Routed, action_routed(game_action(game, String.to_u32(seat), String.to_u32(token), String.to_u32(kind), String.to_u32(amount)), String.to_u32(seat), String.to_u32(token)))
                case other: IO.pure(Routed, Routed.Routed{game, HTTP.not_found()})
        case claim:
          match args:
            case List.Cons{seat_text, rest}:
              seat = String.to_u32(seat_text)
              match game_claim(game, seat):
                case (next, token, ok): IO.pure(Routed, Routed.Routed{next, game_response(next, ok, "", seat, token)})
            case other: IO.pure(Routed, Routed.Routed{game, HTTP.not_found()})
    case state:
      match args:
        case List.Cons{seat, List.Cons{token, rest}}: IO.pure(Routed, game_routed(game, String.to_u32(seat), String.to_u32(token)))
        case other: IO.pure(Routed, game_routed(game, 0, 0))

def list_route(parts: List(String), game: Game) -> IO(Routed):
  match parts:
    case List.Cons{root, List.Cons{"", rest}}: game_index(game)
    case List.Cons{root, List.Cons{name, args}}: list_action(name, args, game)
    case other: game_index(game)

def request_route(request: HTTP.Request, game: Game) -> IO(Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0: IO.pure(Routed, Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")})
        case get: list_route(String.split('/', path), game)

# ---------------------------------------------------------------- Server

def routed_send(routed: Routed, server: TCP, conn: HTTP) -> IO(U32):
  match routed:
    case Routed.Routed{game, response}:
      do IO(U32):
        sent <- HTTP.send_response(conn, HTTP.with_connection(0, response))
        closed <- HTTP.close(conn)
        u32_serve(server, game)

def inbound_serve(inbound: HTTP.Inbound, server: TCP, conn: HTTP, game: Game) -> IO(U32):
  match inbound:
    case HTTP.Inbound.Got{http11, request, rest}:
      do IO(U32):
        routed <- request_route(request, game)
        routed_send(routed, server, conn)
    case HTTP.Inbound.Closed{}:
      do IO(U32):
        closed <- HTTP.close(conn)
        u32_serve(server, game)
    case HTTP.Inbound.Bad{code, error}: routed_send(Routed.Routed{game, HTTP.reply_error(code, error)}, server, conn)

def result_accept(result: Result((U32 & String), TCP), server: TCP, game: Game) -> IO(U32):
  match result:
    case Result.Done{fd}:
      do IO(U32):
        inbound <- HTTP.recv_request(HTTP.Plain{fd}, List.Nil{})
        inbound_serve(inbound, server, HTTP.Plain{fd}, game)
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["accept failed: ", error, "\n"]))
        return 1

def u32_serve(server: TCP, game: Game) -> IO(U32):
  do IO(U32):
    result <- TCP.accept(server)
    result_accept(result, server, game)

def result_main(result: Result((U32 & String), TCP), seed: U32) -> IO(U32):
  match result:
    case Result.Done{server}:
      do IO(U32):
        printed <- IO.write("Bend3 Poker listening on 0.0.0.0:8092\nopen http://<server-lan-ip>:8092\n")
        u32_serve(server, game_empty(seed))
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def main() -> IO(U32):
  do IO(U32):
    seed <- IO.rand_word()
    result <- TCP.listen(8092)
    result_main(result, seed)
