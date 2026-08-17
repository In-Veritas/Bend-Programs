# Generated hub-private namespace from ../poker_web/web_poker.bend.
# Regenerate after changing the standalone source.

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

import ../../../bend-base/Base
import ../../Compat
import ../../../bend-base/IO/TCP
import ../../../bend-base/IO/HTTP
import ../../../bend-base/JSON

type Poker.Hands:
  Hands{seat0: List(U32), seat1: List(U32), seat2: List(U32), seat3: List(U32)}

type Poker.Four:
  Four{seat0: U32, seat1: U32, seat2: U32, seat3: U32}

type Poker.Game:
  Game{variant: U32, phase: U32, dealer: U32, turn: U32, pot: U32, current: U32, min_raise: U32, seed: U32, hand_number: U32, hands: Poker.Hands, board: List(U32), stacks: Poker.Four, bets: Poker.Four, states: Poker.Four, acted: U32, personas: Poker.Four, humans: U32, tokens: Poker.Four, winner: U32, note: String}

type Poker.Action:
  Action{game: Poker.Game, ok: U32, note: String}

type Poker.Routed:
  Routed{game: Poker.Game, response: HTTP.Response}

# ---------------------------------------------------------------- List

def Poker.list_nth(list: List(U32), index: U32) -> U32:
  match list:
    case List.Nil{}: 0
    case List.Cons{head, tail}:
      match index:
        case 0: head
        case more: Poker.list_nth(tail, more - 1)

def Poker.list_take_json(list: List(U32), wanted: U32, first: U32) -> String:
  match wanted:
    case 0: "]"
    case more:
      match list:
        case List.Nil{}: "]"
        case List.Cons{head, tail}:
          prefix : String = match first:
                              case 0: ","
                              case yes: ""
          String.flatten([prefix, String.from_u32(head), Poker.list_take_json(tail, more - 1, 0)])

def Poker.list_json(list: List(U32), wanted: U32) -> String:
  String.concat("[", Poker.list_take_json(list, wanted, 1))

# ---------------------------------------------------------------- Four

def Poker.four_get(four: Poker.Four, seat: U32) -> U32:
  match four:
    case Poker.Four.Four{seat0, seat1, seat2, seat3}:
      match seat % 4:
        case 0: seat0
        case 1: seat1
        case 2: seat2
        case other: seat3

def Poker.four_set(four: Poker.Four, seat: U32, value: U32) -> Poker.Four:
  match four:
    case Poker.Four.Four{seat0, seat1, seat2, seat3}:
      match seat % 4:
        case 0: Poker.Four.Four{value, seat1, seat2, seat3}
        case 1: Poker.Four.Four{seat0, value, seat2, seat3}
        case 2: Poker.Four.Four{seat0, seat1, value, seat3}
        case other: Poker.Four.Four{seat0, seat1, seat2, value}

def Poker.four_sum(four: Poker.Four) -> U32:
  match four:
    case Poker.Four.Four{seat0, seat1, seat2, seat3}: (seat0 + seat1) + (seat2 + seat3)

# ---------------------------------------------------------------- Hands and deck

def Poker.hands_get(hands: Poker.Hands, seat: U32) -> List(U32):
  match hands:
    case Poker.Hands.Hands{seat0, seat1, seat2, seat3}:
      match seat % 4:
        case 0: seat0
        case 1: seat1
        case 2: seat2
        case other: seat3

def Poker.hands_set(hands: Poker.Hands, seat: U32, cards: List(U32)) -> Poker.Hands:
  match hands:
    case Poker.Hands.Hands{seat0, seat1, seat2, seat3}:
      match seat % 4:
        case 0: Poker.Hands.Hands{cards, seat1, seat2, seat3}
        case 1: Poker.Hands.Hands{seat0, cards, seat2, seat3}
        case 2: Poker.Hands.Hands{seat0, seat1, cards, seat3}
        case other: Poker.Hands.Hands{seat0, seat1, seat2, cards}

def Poker.hands_add(hands: Poker.Hands, seat: U32, card: U32) -> Poker.Hands:
  Poker.hands_set(hands, seat, List.Cons{card, Poker.hands_get(hands, seat)})

def Poker.u32_multiplier(choice: U32) -> U32:
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

def Poker.u32_deck_card(seed: U32, index: U32) -> U32:
  ((index * Poker.u32_multiplier(seed)) + ((seed / 24) % 52)) % 52

def Poker.hands_deal_round(seed: U32, round: U32, seat: U32, hands: Poker.Hands) -> Poker.Hands:
  match seat == 4:
    case 0: Poker.hands_deal_round(seed, round, seat + 1, Poker.hands_add(hands, seat, Poker.u32_deck_card(seed, (round * 4) + seat)))
    case done: hands

def Poker.hands_deal_go(seed: U32, rounds: U32, round: U32, hands: Poker.Hands) -> Poker.Hands:
  match round == rounds:
    case 0: Poker.hands_deal_go(seed, rounds, round + 1, Poker.hands_deal_round(seed, round, 0, hands))
    case done: hands

def Poker.hands_deal(seed: U32, variant: U32) -> Poker.Hands:
  rounds = 2 + (variant * 2)
  Poker.hands_deal_go(seed, rounds, 0, Poker.Hands.Hands{List.Nil{}, List.Nil{}, List.Nil{}, List.Nil{}})

def Poker.list_board(seed: U32, variant: U32) -> List(U32):
  offset = 8 + (variant * 8)
  [Poker.u32_deck_card(seed, offset), Poker.u32_deck_card(seed, offset + 1), Poker.u32_deck_card(seed, offset + 2), Poker.u32_deck_card(seed, offset + 3), Poker.u32_deck_card(seed, offset + 4)]

# ---------------------------------------------------------------- Five-card evaluation

def Poker.list_rank_count(cards: List(U32), rank: U32) -> U32:
  match cards:
    case List.Nil{}: 0
    case List.Cons{card, tail}: ((card % 13) == rank) + Poker.list_rank_count(tail, rank)

def Poker.list_rank_mask(cards: List(U32)) -> U32:
  match cards:
    case List.Nil{}: 0
    case List.Cons{card, tail}: (1 << (card % 13)) .|. Poker.list_rank_mask(tail)

def Poker.list_flush(cards: List(U32)) -> U32:
  suit = Poker.list_nth(cards, 0) / 13
  ((Poker.list_nth(cards, 1) / 13) == suit) && (((Poker.list_nth(cards, 2) / 13) == suit) && (((Poker.list_nth(cards, 3) / 13) == suit) && ((Poker.list_nth(cards, 4) / 13) == suit)))

def Poker.u32_straight_high(mask: U32, count: U32) -> U32:
  match count == 4:
    case 0:
      high = count - 1
      run = (((((mask >> high) .&. 1) * ((mask >> (high - 1)) .&. 1)) * ((mask >> (high - 2)) .&. 1)) * ((mask >> (high - 3)) .&. 1)) * ((mask >> (high - 4)) .&. 1)
      match run:
        case 0: Poker.u32_straight_high(mask, count - 1)
        case yes: high + 1
    case wheel:
      ace = (mask >> 12) .&. 1
      low0 = mask .&. 1
      low1 = (mask >> 1) .&. 1
      low2 = (mask >> 2) .&. 1
      low3 = (mask >> 3) .&. 1
      ((((ace * low0) * low1) * low2) * low3) * 4

def Poker.list_rank_with_count(cards: List(U32), wanted: U32, skip: U32, count: U32) -> U32:
  match count:
    case 0: 0
    case more:
      rank = count - 1
      match Poker.list_rank_count(cards, rank) == wanted:
        case 0: Poker.list_rank_with_count(cards, wanted, skip, count - 1)
        case found:
          match skip:
            case 0: rank + 1
            case left: Poker.list_rank_with_count(cards, wanted, left - 1, count - 1)

def Poker.u32_pack(a: U32, b: U32, c: U32, d: U32, e: U32) -> U32:
  ab = (a * 14) + b
  abc = (ab * 14) + c
  abcd = (abc * 14) + d
  (abcd * 14) + e

def Poker.list_five_score(cards: List(U32)) -> U32:
  mask = Poker.list_rank_mask(cards)
  straight = Poker.u32_straight_high(mask, 13)
  flush = Poker.list_flush(cards)
  four = Poker.list_rank_with_count(cards, 4, 0, 13)
  three = Poker.list_rank_with_count(cards, 3, 0, 13)
  pair0 = Poker.list_rank_with_count(cards, 2, 0, 13)
  pair1 = Poker.list_rank_with_count(cards, 2, 1, 13)
  one0 = Poker.list_rank_with_count(cards, 1, 0, 13)
  one1 = Poker.list_rank_with_count(cards, 1, 1, 13)
  one2 = Poker.list_rank_with_count(cards, 1, 2, 13)
  one3 = Poker.list_rank_with_count(cards, 1, 3, 13)
  one4 = Poker.list_rank_with_count(cards, 1, 4, 13)
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
                                case 0: Poker.u32_pack(one0, one1, one2, one3, one4)
                                case pair: 1000000 + Poker.u32_pack(pair, one0, one1, one2, 0)
                            case second_pair: 2000000 + Poker.u32_pack(pair0, pair1, one0, 0, 0)
                        case trips: 3000000 + Poker.u32_pack(trips, one0, one1, 0, 0)
                    case run: 4000000 + Poker.u32_pack(run, 0, 0, 0, 0)
                case suited: 5000000 + Poker.u32_pack(one0, one1, one2, one3, one4)
            case full: 6000000 + Poker.u32_pack(three, pair0, 0, 0, 0)
        case quads: 7000000 + Poker.u32_pack(quads, one0, 0, 0, 0)
    case straight_flush: 8000000 + Poker.u32_pack(straight, 0, 0, 0, 0)

def Poker.list_choose_score(cards: List(U32), chosen: List(U32), count: U32) -> U32:
  match count == 5:
    case 0:
      match cards:
        case List.Nil{}: 0
        case List.Cons{head, tail}:
          with_head = Poker.list_choose_score(tail, List.Cons{head, chosen}, count + 1)
          without = Poker.list_choose_score(tail, chosen, count)
          U32.max(with_head, without)
    case five: Poker.list_five_score(chosen)

def Poker.list_texas_score(hole: List(U32), board: List(U32)) -> U32:
  Poker.list_choose_score(List.concat(U32, hole, board), List.Nil{}, 0)

def Poker.list_omaha_board(hole: List(U32), board: List(U32), a: U32, b: U32, c: U32, d: U32, e: U32) -> U32:
  match e == 5:
    case 0:
      score = Poker.list_five_score([Poker.list_nth(hole, a), Poker.list_nth(hole, b), Poker.list_nth(board, c), Poker.list_nth(board, d), Poker.list_nth(board, e)])
      U32.max(score, Poker.list_omaha_board(hole, board, a, b, c, d, e + 1))
    case done: 0

def Poker.list_omaha_fourth(hole: List(U32), board: List(U32), a: U32, b: U32, c: U32, d: U32) -> U32:
  match d == 4:
    case 0: U32.max(Poker.list_omaha_board(hole, board, a, b, c, d, d + 1), Poker.list_omaha_fourth(hole, board, a, b, c, d + 1))
    case done: 0

def Poker.list_omaha_third(hole: List(U32), board: List(U32), a: U32, b: U32, c: U32) -> U32:
  match c == 3:
    case 0: U32.max(Poker.list_omaha_fourth(hole, board, a, b, c, c + 1), Poker.list_omaha_third(hole, board, a, b, c + 1))
    case done: 0

def Poker.list_omaha_second(hole: List(U32), board: List(U32), a: U32, b: U32) -> U32:
  match b == 4:
    case 0: U32.max(Poker.list_omaha_third(hole, board, a, b, 0), Poker.list_omaha_second(hole, board, a, b + 1))
    case done: 0

def Poker.list_omaha_first(hole: List(U32), board: List(U32), a: U32) -> U32:
  match a == 3:
    case 0: U32.max(Poker.list_omaha_second(hole, board, a, a + 1), Poker.list_omaha_first(hole, board, a + 1))
    case done: 0

def Poker.list_omaha_score(hole: List(U32), board: List(U32)) -> U32:
  Poker.list_omaha_first(hole, board, 0)

def Poker.game_seat_score(game: Poker.Game, seat: U32) -> U32:
  match game:
    case Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      match variant:
        case 0: Poker.list_texas_score(Poker.hands_get(hands, seat), board)
        case omaha: Poker.list_omaha_score(Poker.hands_get(hands, seat), board)

# ---------------------------------------------------------------- Personas and AI

def Poker.u32_persona_name(persona: U32) -> String:
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

def Poker.u32_persona_style(persona: U32) -> String:
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

def Poker.u32_persona_aggression(persona: U32) -> U32:
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

def Poker.u32_hole_power(hole: List(U32)) -> U32:
  a = Poker.list_nth(hole, 0) % 13
  b = Poker.list_nth(hole, 1) % 13
  pair = (a == b) * 45
  suited = ((Poker.list_nth(hole, 0) / 13) == (Poker.list_nth(hole, 1) / 13)) * 10
  ((pair + suited) + (a + b)) + 8

# ---------------------------------------------------------------- Betting state

def Poker.game_active_count(states: Poker.Four, seat: U32) -> U32:
  match seat == 4:
    case 0: (Poker.four_get(states, seat) != 1) + Poker.game_active_count(states, seat + 1)
    case done: 0

def Poker.game_live_mask(states: Poker.Four, seat: U32) -> U32:
  match seat == 4:
    case 0: (((Poker.four_get(states, seat) != 1) * (1 << seat)) .|. Poker.game_live_mask(states, seat + 1))
    case done: 0

def Poker.game_bets_equal(bets: Poker.Four, states: Poker.Four, current: U32, seat: U32) -> U32:
  match seat == 4:
    case 0:
      inactive = Poker.four_get(states, seat) > 0
      ((inactive || (Poker.four_get(bets, seat) == current)) && Poker.game_bets_equal(bets, states, current, seat + 1))
    case done: 1

def Poker.u32_next_live(states: Poker.Four, seat: U32, fuel: U32) -> U32:
  next = (seat + 1) % 4
  match fuel:
    case 0: next
    case more:
      match Poker.four_get(states, next) == 0:
        case 0: Poker.u32_next_live(states, next, fuel - 1)
        case yes: next

def Poker.u32_next_not_folded(states: Poker.Four, seat: U32, fuel: U32) -> U32:
  next = (seat + 1) % 4
  match fuel:
    case 0: next
    case more:
      match Poker.four_get(states, next) != 1:
        case 0: Poker.u32_next_not_folded(states, next, fuel - 1)
        case yes: next

def Poker.four_pay(stacks: Poker.Four, bets: Poker.Four, seat: U32, wanted: U32) -> (Poker.Four & Poker.Four & U32):
  stack = Poker.four_get(stacks, seat)
  paid = U32.min(stack, wanted)
  new_stacks = Poker.four_set(stacks, seat, stack - paid)
  new_bets = Poker.four_set(bets, seat, Poker.four_get(bets, seat) + paid)
  (new_stacks, new_bets, paid)

def Poker.game_showdown(game: Poker.Game) -> Poker.Game:
  match game:
    case Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      live = Poker.game_live_mask(states, 0)
      score0 = Poker.game_seat_score(Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 0) * ((live .&. 1) > 0)
      score1 = Poker.game_seat_score(Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 1) * ((live .&. 2) > 0)
      score2 = Poker.game_seat_score(Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 2) * ((live .&. 4) > 0)
      score3 = Poker.game_seat_score(Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 3) * ((live .&. 8) > 0)
      best = U32.max(U32.max(score0, score1), U32.max(score2, score3))
      winners = (((score0 == best) * ((live .&. 1) > 0)) + ((score1 == best) * ((live .&. 2) > 0))) + (((score2 == best) * ((live .&. 4) > 0)) + ((score3 == best) * ((live .&. 8) > 0)))
      share = pot / winners
      next0 = Poker.four_get(stacks, 0) + (share * ((score0 == best) * ((live .&. 1) > 0)))
      next1 = Poker.four_get(stacks, 1) + (share * ((score1 == best) * ((live .&. 2) > 0)))
      next2 = Poker.four_get(stacks, 2) + (share * ((score2 == best) * ((live .&. 4) > 0)))
      next3 = Poker.four_get(stacks, 3) + (share * ((score3 == best) * ((live .&. 8) > 0)))
      winner_mask = (((score0 == best) * ((live .&. 1) > 0)) + (((score1 == best) * ((live .&. 2) > 0)) * 2)) + ((((score2 == best) * ((live .&. 4) > 0)) * 4) + (((score3 == best) * ((live .&. 8) > 0)) * 8))
      Poker.Game.Game{variant, 4, dealer, turn, 0, current, min_raise, seed, hand_number, hands, board, Poker.Four.Four{next0, next1, next2, next3}, bets, states, acted, personas, humans, tokens, winner_mask, "Showdown complete. The best five-card hand wins the pot."}

def Poker.game_fold_win(game: Poker.Game) -> Poker.Game:
  match game:
    case Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      seat = Poker.u32_next_not_folded(states, turn, 4)
      next_stacks = Poker.four_set(stacks, seat, Poker.four_get(stacks, seat) + pot)
      Poker.Game.Game{variant, 4, dealer, seat, 0, current, min_raise, seed, hand_number, hands, board, next_stacks, bets, states, acted, personas, humans, tokens, 1 << seat, "Everyone else folded. The last player wins the pot."}

def Poker.game_advance_street(game: Poker.Game) -> Poker.Game:
  match game:
    case Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      match phase == 3:
        case 0:
          first = Poker.u32_next_live(states, dealer, 4)
          label : String = match phase:
                            case 0: "The flop is dealt."
                            case 1: "The turn is dealt."
                            case other: "The river is dealt."
          Poker.Game.Game{variant, phase + 1, dealer, first, pot, 0, 20, seed, hand_number, hands, board, stacks, Poker.Four.Four{0, 0, 0, 0}, states, 0, personas, humans, tokens, 0, label}
        case river: Poker.game_showdown(Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note})

def Poker.game_after_action(game: Poker.Game) -> Poker.Game:
  match game:
    case Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      match Poker.game_active_count(states, 0) == 1:
        case 0:
          live = Poker.game_live_mask(states, 0)
          complete = ((acted .&. live) == live) && Poker.game_bets_equal(bets, states, current, 0)
          match complete:
            case 0:
              next = Poker.u32_next_live(states, turn, 4)
              Poker.Game.Game{variant, phase, dealer, next, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}
            case yes: Poker.game_advance_street(Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note})
        case one: Poker.game_fold_win(Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note})

def Poker.game_action_seat(game: Poker.Game, seat: U32, kind: U32, amount: U32) -> Poker.Action:
  match game:
    case Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      match (phase < 4) && ((turn == seat) && (Poker.four_get(states, seat) == 0)):
        case 0: Poker.Action.Action{game, 0, "It is not that seat's turn."}
        case yes:
          own_bet = Poker.four_get(bets, seat)
          stack = Poker.four_get(stacks, seat)
          call = current - own_bet
          match kind:
            case 0:
              next : Poker.Game = Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, Poker.four_set(states, seat, 1), acted .|. (1 << seat), personas, humans, tokens, winner, "Fold."}
              Poker.Action.Action{Poker.game_after_action(next), 1, ""}
            case 1:
              match call == 0:
                case 0: Poker.Action.Action{game, 0, "Check is unavailable while facing a bet."}
                case check:
                  next : Poker.Game = Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted .|. (1 << seat), personas, humans, tokens, winner, "Check."}
                  Poker.Action.Action{Poker.game_after_action(next), 1, ""}
            case 2:
              match call > stack:
                case 0:
                  paid = Poker.four_pay(stacks, bets, seat, call)
                  match paid:
                    case (next_stacks, next_bets, chips):
                      next_states : Poker.Four = match chips == stack:
                                                   case 0: states
                                                   case all: Poker.four_set(states, seat, 2)
                      next : Poker.Game = Poker.Game.Game{variant, phase, dealer, turn, pot + chips, current, min_raise, seed, hand_number, hands, board, next_stacks, next_bets, next_states, acted .|. (1 << seat), personas, humans, tokens, winner, "Call."}
                      Poker.Action.Action{Poker.game_after_action(next), 1, ""}
                case short:
                  paid = Poker.four_pay(stacks, bets, seat, stack)
                  match paid:
                    case (next_stacks, next_bets, chips):
                      next : Poker.Game = Poker.Game.Game{variant, phase, dealer, turn, pot + chips, current, min_raise, seed, hand_number, hands, board, next_stacks, next_bets, Poker.four_set(states, seat, 2), acted .|. (1 << seat), personas, humans, tokens, winner, "All-in call."}
                      Poker.Action.Action{Poker.game_after_action(next), 1, ""}
            case other:
              max_total = own_bet + stack
              min_total = current + min_raise
              match (amount >= min_total) && (amount <= max_total):
                case 0: Poker.Action.Action{game, 0, "Raise-to amount is outside the legal slider range."}
                case raise:
                  wanted = amount - own_bet
                  paid = Poker.four_pay(stacks, bets, seat, wanted)
                  match paid:
                    case (next_stacks, next_bets, chips):
                      next_states : Poker.Four = match chips == stack:
                                                   case 0: states
                                                   case all: Poker.four_set(states, seat, 2)
                      next : Poker.Game = Poker.Game.Game{variant, phase, dealer, turn, pot + chips, amount, amount - current, seed, hand_number, hands, board, next_stacks, next_bets, next_states, 1 << seat, personas, humans, tokens, winner, "Raise."}
                      Poker.Action.Action{Poker.game_after_action(next), 1, ""}

def Poker.game_ai_action(game: Poker.Game) -> Poker.Action:
  match game:
    case Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      stack = Poker.four_get(stacks, turn)
      call = current - Poker.four_get(bets, turn)
      persona = Poker.four_get(personas, turn)
      aggression = Poker.u32_persona_aggression(persona)
      strength = Poker.u32_hole_power(Poker.hands_get(hands, turn)) + (phase * 10)
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
      capped = U32.min(amount, Poker.four_get(bets, turn) + stack)
      Poker.game_action_seat(game, turn, kind, capped)

def Poker.game_auto(game: Poker.Game, fuel: U32) -> Poker.Game:
  match fuel:
    case 0: game
    case more:
      match game:
        case Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
          match (phase < 4) && (((humans >> turn) .&. 1) == 0):
            case 0: game
            case ai:
              match Poker.game_ai_action(game):
                case Poker.Action.Action{next, ok, action_note}:
                  match ok:
                    case 0: game
                    case yes: Poker.game_auto(next, more - 1)

# ---------------------------------------------------------------- New hands, authentication, actions

def Poker.game_next_seed(seed: U32) -> U32:
  (seed * 1664525) + 1013904223

def Poker.game_personas(seed: U32) -> Poker.Four:
  first = seed % 10
  Poker.Four.Four{first, (first + 3) % 10, (first + 6) % 10, (first + 9) % 10}

def Poker.game_deal(seed: U32, variant: U32, dealer: U32, hand_number: U32, stacks: Poker.Four, humans: U32, tokens: Poker.Four) -> Poker.Game:
  small = (dealer + 1) % 4
  big = (dealer + 2) % 4
  paid_small = Poker.four_pay(stacks, Poker.Four.Four{0, 0, 0, 0}, small, 10)
  match paid_small:
    case (stacks1, bets1, chips1):
      paid_big = Poker.four_pay(stacks1, bets1, big, 20)
      match paid_big:
        case (stacks2, bets2, chips2):
          raw : Poker.Game = Poker.Game.Game{variant, 0, dealer, (dealer + 3) % 4, chips1 + chips2, 20, 20, seed, hand_number, Poker.hands_deal(seed, variant), Poker.list_board(seed, variant), stacks2, bets2, Poker.Four.Four{0, 0, 0, 0}, 0, Poker.game_personas(seed), humans, tokens, 0, "Blinds posted. Poker.Action begins before the flop."}
          Poker.game_auto(raw, 96)

def Poker.game_empty(seed: U32) -> Poker.Game:
  Poker.game_deal(seed, 0, 3, 1, Poker.Four.Four{1000, 1000, 1000, 1000}, 1, Poker.Four.Four{0, 0, 0, 0})

def Poker.game_authorized(game: Poker.Game, seat: U32, token: U32) -> U32:
  match game:
    case Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      match seat:
        case 0: token == 0
        case other: (((humans >> seat) .&. 1) == 1) && (Poker.four_get(tokens, seat) == token)

def Poker.game_new(game: Poker.Game, seat: U32, token: U32, variant: U32) -> Poker.Action:
  match Poker.game_authorized(game, seat, token):
    case 0: Poker.Action.Action{game, 0, "That seat token is not authorized."}
    case yes:
      match game:
        case Poker.Game.Game{old_variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
          next_seed = Poker.game_next_seed(seed + hand_number)
          next_variant = variant % 2
          reset_stacks : Poker.Four = match (Poker.four_sum(stacks) < 80) || (phase < 4):
                                                                      case 0: stacks
                                                                      case reset: Poker.Four.Four{1000, 1000, 1000, 1000}
          Poker.Action.Action{Poker.game_deal(next_seed, next_variant, (dealer + 1) % 4, hand_number + 1, reset_stacks, humans, tokens), 1, ""}

def Poker.game_claim(game: Poker.Game, seat: U32) -> (Poker.Game & U32 & U32):
  match game:
    case Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      match (seat > 0) && ((seat < 4) && (((humans >> seat) .&. 1) == 0)):
        case 0: (game, 0, 0)
        case yes:
          token = Poker.game_next_seed((seed + (seat * 2654435761)) + hand_number)
          next : Poker.Game = Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans .|. (1 << seat), Poker.four_set(tokens, seat, token), winner, "A browser player joined the table."}
          (next, token, 1)

def Poker.game_action(game: Poker.Game, seat: U32, token: U32, kind: U32, amount: U32) -> Poker.Action:
  match Poker.game_authorized(game, seat, token):
    case 0: Poker.Action.Action{game, 0, "That seat token is not authorized."}
    case yes:
      match ((Poker.game_humans(game) >> seat) .&. 1) == 1:
        case 0: Poker.Action.Action{game, 0, "That seat is controlled by Bend AI."}
        case human:
          match Poker.game_action_seat(game, seat, kind, amount):
            case Poker.Action.Action{next, ok, note}:
              match ok:
                case 0: Poker.Action.Action{next, ok, note}
                case yes: Poker.Action.Action{Poker.game_auto(next, 96), 1, ""}

def Poker.game_humans(game: Poker.Game) -> U32:
  match game:
    case Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}: humans

# Pure regression probe.
def Poker.test() -> U32:
  texas = Poker.game_empty(123456789)
  match texas:
    case Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      deal_ok = (List.length(U32, Poker.hands_get(hands, 0)) == 2) && ((List.length(U32, Poker.hands_get(hands, 1)) == 2) && (List.length(U32, board) == 5))
      unique = (Poker.list_nth(Poker.hands_get(hands, 0), 0) != Poker.list_nth(Poker.hands_get(hands, 1), 0)) && (Poker.list_nth(board, 0) != Poker.list_nth(board, 1))
      personas_ok = (Poker.four_get(personas, 0) != Poker.four_get(personas, 1)) && (Poker.four_get(personas, 1) != Poker.four_get(personas, 2))
      sample_royal = Poker.list_five_score([8, 9, 10, 11, 12])
      sample_pair = Poker.list_five_score([0, 13, 2, 4, 6])
      deal_ok && (unique && (personas_ok && (((sample_royal / 1000000) == 8) && ((sample_pair / 1000000) == 1))))

# ---------------------------------------------------------------- JSON

def Poker.u32_phase_cards(phase: U32) -> U32:
  match phase:
    case 0: 0
    case 1: 3
    case 2: 4
    case other: 5

def Poker.game_hole_json(hands: Poker.Hands, seat: U32, viewer: U32, authorized: U32, showdown: U32) -> String:
  match showdown || (authorized && (seat == viewer)):
    case 0: "[]"
    case reveal: Poker.list_json(Poker.hands_get(hands, seat), 4)

def Poker.game_seat_json(game: Poker.Game, seat: U32, viewer: U32, authorized: U32) -> String:
  match game:
    case Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      persona = Poker.four_get(personas, seat)
      String.flatten([
        "{\"seat\":", String.from_u32(seat), ",\"name\":", JSON.quoted(Poker.u32_persona_name(persona), ""),
        ",\"style\":", JSON.quoted(Poker.u32_persona_style(persona), ""), ",\"aggression\":", String.from_u32(Poker.u32_persona_aggression(persona)),
        ",\"human\":", String.from_u32((humans >> seat) .&. 1), ",\"stack\":", String.from_u32(Poker.four_get(stacks, seat)),
        ",\"bet\":", String.from_u32(Poker.four_get(bets, seat)), ",\"state\":", String.from_u32(Poker.four_get(states, seat)),
        ",\"dealer\":", String.from_u32(seat == dealer), ",\"winner\":", String.from_u32((winner >> seat) .&. 1),
        ",\"cards\":", Poker.game_hole_json(hands, seat, viewer, authorized, phase == 4), "}"
      ])

def Poker.game_json(game: Poker.Game, ok: U32, action_note: String, viewer: U32, token: U32) -> String:
  match game:
    case Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      authorized = Poker.game_authorized(Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, viewer, token)
      shown_note : String = match String.length(action_note):
                              case 0: note
                              case present: action_note
      max_raise = Poker.four_get(bets, viewer) + Poker.four_get(stacks, viewer)
      String.flatten([
        "{\"ok\":", String.from_u32(ok), ",\"authorized\":", String.from_u32(authorized), ",\"note\":", JSON.quoted(shown_note, ""),
        ",\"variant\":", String.from_u32(variant), ",\"phase\":", String.from_u32(phase), ",\"dealer\":", String.from_u32(dealer),
        ",\"turn\":", String.from_u32(turn), ",\"pot\":", String.from_u32(pot), ",\"currentBet\":", String.from_u32(current),
        ",\"minRaise\":", String.from_u32(min_raise), ",\"maxRaise\":", String.from_u32(max_raise), ",\"handNumber\":", String.from_u32(hand_number),
        ",\"viewer\":", String.from_u32(viewer), ",\"seatToken\":", String.from_u32(token), ",\"board\":", Poker.list_json(board, Poker.u32_phase_cards(phase)),
        ",\"players\":[", Poker.game_seat_json(Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 0, viewer, authorized),
        ",", Poker.game_seat_json(Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 1, viewer, authorized),
        ",", Poker.game_seat_json(Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 2, viewer, authorized),
        ",", Poker.game_seat_json(Poker.Game.Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}, 3, viewer, authorized), "]}"
      ])

def Poker.game_response(game: Poker.Game, ok: U32, note: String, viewer: U32, token: U32) -> HTTP.Response:
  HTTP.Response.Response{200,
    [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"}, HTTP.Header.Header{"Cache-Control", "no-store"}],
    Bytes.from_string(Poker.game_json(game, ok, note, viewer, token))}

def Poker.action_routed(action: Poker.Action, viewer: U32, token: U32) -> Poker.Routed:
  match action:
    case Poker.Action.Action{game, ok, note}: Poker.Routed.Routed{game, Poker.game_response(game, ok, note, viewer, token)}

def Poker.game_routed(game: Poker.Game, viewer: U32, token: U32) -> Poker.Routed:
  Poker.Routed.Routed{game, Poker.game_response(game, 1, "", viewer, token)}

# ---------------------------------------------------------------- HTTP routes

def Poker.result_index(result: Result((U32 & String), String), game: Poker.Game) -> IO(Poker.Routed):
  match result:
    case Result.Done{html}: IO.pure(Poker.Routed, Poker.Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}: IO.pure(Poker.Routed, Poker.Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "Poker page not found -- run from the repository root\n")})

def Poker.game_index(game: Poker.Game) -> IO(Poker.Routed):
  do IO(Poker.Routed):
    result <- IO.read_text("gabriel_demos/poker_web/index.html")
    Poker.result_index(result, game)

def Poker.list_action(name: String, args: List(String), game: Poker.Game) -> IO(Poker.Routed):
  match String.eq_u32(name, "state"):
    case 0:
      match String.eq_u32(name, "claim"):
        case 0:
          match String.eq_u32(name, "action"):
            case 0:
              match String.eq_u32(name, "new"):
                case 0: IO.pure(Poker.Routed, Poker.Routed.Routed{game, HTTP.not_found()})
                case fresh:
                  match args:
                    case List.Cons{seat, List.Cons{token, List.Cons{variant, rest}}}: IO.pure(Poker.Routed, Poker.action_routed(Poker.game_new(game, String.to_u32(seat), String.to_u32(token), String.to_u32(variant)), String.to_u32(seat), String.to_u32(token)))
                    case other: IO.pure(Poker.Routed, Poker.Routed.Routed{game, HTTP.not_found()})
            case act:
              match args:
                case List.Cons{seat, List.Cons{token, List.Cons{kind, List.Cons{amount, rest}}}}: IO.pure(Poker.Routed, Poker.action_routed(Poker.game_action(game, String.to_u32(seat), String.to_u32(token), String.to_u32(kind), String.to_u32(amount)), String.to_u32(seat), String.to_u32(token)))
                case other: IO.pure(Poker.Routed, Poker.Routed.Routed{game, HTTP.not_found()})
        case claim:
          match args:
            case List.Cons{seat_text, rest}:
              seat = String.to_u32(seat_text)
              match Poker.game_claim(game, seat):
                case (next, token, ok): IO.pure(Poker.Routed, Poker.Routed.Routed{next, Poker.game_response(next, ok, "", seat, token)})
            case other: IO.pure(Poker.Routed, Poker.Routed.Routed{game, HTTP.not_found()})
    case state:
      match args:
        case List.Cons{seat, List.Cons{token, rest}}: IO.pure(Poker.Routed, Poker.game_routed(game, String.to_u32(seat), String.to_u32(token)))
        case other: IO.pure(Poker.Routed, Poker.game_routed(game, 0, 0))

def Poker.list_route(parts: List(String), game: Poker.Game) -> IO(Poker.Routed):
  match parts:
    case List.Cons{root, List.Cons{"", rest}}: Poker.game_index(game)
    case List.Cons{root, List.Cons{name, args}}: Poker.list_action(name, args, game)
    case other: Poker.game_index(game)

def Poker.request_route(request: HTTP.Request, game: Poker.Game) -> IO(Poker.Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0: IO.pure(Poker.Routed, Poker.Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")})
        case get: Poker.list_route(String.split('/', path), game)

# ---------------------------------------------------------------- Server

def Poker.routed_send(routed: Poker.Routed, server: TCP, conn: HTTP) -> IO(U32):
  match routed:
    case Poker.Routed.Routed{game, response}:
      do IO(U32):
        sent <- HTTP.send_response(conn, HTTP.with_connection(0, response))
        closed <- HTTP.close(conn)
        Poker.u32_serve(server, game)

def Poker.inbound_serve(inbound: HTTP.Inbound, server: TCP, conn: HTTP, game: Poker.Game) -> IO(U32):
  match inbound:
    case HTTP.Inbound.Got{http11, request, rest}:
      do IO(U32):
        routed <- Poker.request_route(request, game)
        Poker.routed_send(routed, server, conn)
    case HTTP.Inbound.Closed{}:
      do IO(U32):
        closed <- HTTP.close(conn)
        Poker.u32_serve(server, game)
    case HTTP.Inbound.Bad{code, error}: Poker.routed_send(Poker.Routed.Routed{game, HTTP.reply_error(code, error)}, server, conn)

def Poker.result_accept(result: Result((U32 & String), TCP), server: TCP, game: Poker.Game) -> IO(U32):
  match result:
    case Result.Done{fd}:
      do IO(U32):
        inbound <- HTTP.recv_request(HTTP.Plain{fd}, List.Nil{})
        Poker.inbound_serve(inbound, server, HTTP.Plain{fd}, game)
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["accept failed: ", error, "\n"]))
        return 1

def Poker.u32_serve(server: TCP, game: Poker.Game) -> IO(U32):
  do IO(U32):
    result <- TCP.accept(server)
    Poker.result_accept(result, server, game)

def Poker.result_main(result: Result((U32 & String), TCP), seed: U32) -> IO(U32):
  match result:
    case Result.Done{server}:
      do IO(U32):
        printed <- IO.write("Bend3 Poker listening on 0.0.0.0:8092\nopen http://<server-lan-ip>:8092\n")
        Poker.u32_serve(server, Poker.game_empty(seed))
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def Poker.main() -> IO(U32):
  do IO(U32):
    seed <- IO.rand_word()
    result <- TCP.listen(8092)
    Poker.result_main(result, seed)
