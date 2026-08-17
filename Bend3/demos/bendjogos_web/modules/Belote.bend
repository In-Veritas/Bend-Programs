# Generated hub-private namespace from ../belote_web/web_belote.bend.
# Regenerate after changing the standalone source.

# Belote: a solo table with three Bend-controlled opponents.
#
# Bend owns the shuffled 32-card deck, two-round trump selection, legal plays,
# forced following/trumping/overtrumping, tricks, Belote/Rebelote bonus, contract
# resolution, and match score. The browser only renders state and submits the
# south player's decisions.
#
# GET /             browser client
# GET /state        current table as JSON
# GET /bid/<0..4>   pass (0) or choose clubs/diamonds/hearts/spades (1..4)
# GET /play/<0..31> play a card
# GET /auto          advance exactly one Bend-controlled seat
# GET /next         deal the next hand
# GET /new          reset the match with a fresh IO random seed
#
# no-halt
# skip-native

import ../../../bend-base/Base
import ../../Compat
import ../../../bend-base/IO/TCP
import ../../../bend-base/IO/HTTP
import ../../../bend-base/JSON

type Belote.Hands:
  Hands{south: U32, east: U32, north: U32, west: U32}

type Belote.Trick:
  Trick{count: U32, seat0: U32, card0: U32, seat1: U32, card1: U32, seat2: U32, card2: U32, seat3: U32, card3: U32}

type Belote.Winner:
  Winner{seat: U32, card: U32}

type Belote.Game:
  Game{phase: U32, dealer: U32, turn: U32, taker: U32, trump: U32, offered: U32, passes: U32, seed: U32, hands: Belote.Hands, trick: Belote.Trick, tricks: U32, points0: U32, points1: U32, score0: U32, score1: U32, hand: U32, belote: U32, note: String}

type Belote.Action:
  Action{game: Belote.Game, ok: U32, note: String}

type Belote.Routed:
  Routed{game: Belote.Game, response: HTTP.Response}

# ---------------------------------------------------------------- Card

def Belote.card_suit(card: U32) -> U32:
  card / 8

def Belote.card_rank(card: U32) -> U32:
  card % 8

def Belote.card_bit(card: U32) -> U32:
  1 << card

def Belote.card_trump_order(card: U32) -> U32:
  match Belote.card_rank(card):
    case 0: 0
    case 1: 1
    case 2: 6
    case 3: 7
    case 4: 2
    case 5: 3
    case 6: 4
    case rank: 5

def Belote.card_points(card: U32, trump: U32) -> U32:
  match Belote.card_suit(card) == trump:
    case 0:
      match Belote.card_rank(card):
        case 0: 0
        case 1: 0
        case 2: 0
        case 3: 2
        case 4: 3
        case 5: 4
        case 6: 10
        case rank: 11
    case atout:
      match Belote.card_rank(card):
        case 0: 0
        case 1: 0
        case 2: 14
        case 3: 20
        case 4: 3
        case 5: 4
        case 6: 10
        case rank: 11

def Belote.card_power(card: U32, lead: U32, trump: U32) -> U32:
  match Belote.card_suit(card) == trump:
    case 0:
      match Belote.card_suit(card) == lead:
        case 0: Belote.card_rank(card)
        case asked: 32 + Belote.card_rank(card)
    case atout:
      64 + Belote.card_trump_order(card)

def Belote.card_beats(card: U32, held: U32, lead: U32, trump: U32) -> U32:
  Belote.card_power(card, lead, trump) > Belote.card_power(held, lead, trump)

# ---------------------------------------------------------------- Hand

def Belote.hand_has(hand: U32, card: U32) -> U32:
  (hand .&. Belote.card_bit(card)) > 0

def Belote.hand_add(hand: U32, card: U32) -> U32:
  hand .|. Belote.card_bit(card)

def Belote.hand_remove(hand: U32, card: U32) -> U32:
  hand - Belote.card_bit(card)

def Belote.hand_has_suit_go(hand: U32, suit: U32, rank: U32) -> U32:
  match rank == 8:
    case 0:
      match Belote.hand_has(hand, (suit * 8) + rank):
        case 0: Belote.hand_has_suit_go(hand, suit, rank + 1)
        case found: 1
    case done:
      0

def Belote.hand_has_suit(hand: U32, suit: U32) -> U32:
  Belote.hand_has_suit_go(hand, suit, 0)

def Belote.hand_count_go(hand: U32, card: U32) -> U32:
  match card == 32:
    case 0: Belote.hand_has(hand, card) + Belote.hand_count_go(hand, card + 1)
    case done: 0

def Belote.hand_count(hand: U32) -> U32:
  Belote.hand_count_go(hand, 0)

def Belote.hand_has_higher_go(hand: U32, trump: U32, top: U32, rank: U32) -> U32:
  match rank == 8:
    case 0:
      card = (trump * 8) + rank
      match Belote.hand_has(hand, card) && ((Belote.card_trump_order(card) + 1) > top):
        case 0: Belote.hand_has_higher_go(hand, trump, top, rank + 1)
        case found: 1
    case done:
      0

def Belote.hand_has_higher(hand: U32, trump: U32, top: U32) -> U32:
  Belote.hand_has_higher_go(hand, trump, top, 0)

def Belote.hand_bid_value_go(hand: U32, suit: U32, card: U32) -> U32:
  match card == 32:
    case 0:
      value = Belote.card_points(card, suit)
      bonus = (Belote.card_suit(card) == suit) * 4
      (Belote.hand_has(hand, card) * (value + bonus)) + Belote.hand_bid_value_go(hand, suit, card + 1)
    case done:
      0

def Belote.hand_bid_value(hand: U32, suit: U32) -> U32:
  Belote.hand_bid_value_go(hand, suit, 0)

def Belote.hand_json_go(hand: U32, card: U32, first: U32) -> String:
  match card == 32:
    case 0:
      match Belote.hand_has(hand, card):
        case 0: Belote.hand_json_go(hand, card + 1, first)
        case found:
          match first:
            case 0: String.flatten([",", String.from_u32(card), Belote.hand_json_go(hand, card + 1, 0)])
            case yes: String.flatten([String.from_u32(card), Belote.hand_json_go(hand, card + 1, 0)])
    case done:
      "]"

def Belote.hand_json(hand: U32) -> String:
  String.concat("[", Belote.hand_json_go(hand, 0, 1))

# ---------------------------------------------------------------- Hands

def Belote.hands_empty() -> Belote.Hands:
  Belote.Hands.Hands{0, 0, 0, 0}

def Belote.hands_get(hands: Belote.Hands, seat: U32) -> U32:
  match hands:
    case Belote.Hands.Hands{south, east, north, west}:
      match seat % 4:
        case 0: south
        case 1: east
        case 2: north
        case other: west

def Belote.hands_set(hands: Belote.Hands, seat: U32, hand: U32) -> Belote.Hands:
  match hands:
    case Belote.Hands.Hands{south, east, north, west}:
      match seat % 4:
        case 0: Belote.Hands.Hands{hand, east, north, west}
        case 1: Belote.Hands.Hands{south, hand, north, west}
        case 2: Belote.Hands.Hands{south, east, hand, west}
        case other: Belote.Hands.Hands{south, east, north, hand}

def Belote.hands_add(hands: Belote.Hands, seat: U32, card: U32) -> Belote.Hands:
  Belote.hands_set(hands, seat, Belote.hand_add(Belote.hands_get(hands, seat), card))

def Belote.hands_remove(hands: Belote.Hands, seat: U32, card: U32) -> Belote.Hands:
  Belote.hands_set(hands, seat, Belote.hand_remove(Belote.hands_get(hands, seat), card))

# ---------------------------------------------------------------- Deal

def Belote.u32_next_seat(seat: U32) -> U32:
  (seat + 1) % 4

def Belote.u32_deal_card(seed: U32, index: U32) -> U32:
  multiplier = ((seed % 16) * 2) + 1
  offset = (seed / 16) % 32
  ((index * multiplier) + offset) % 32

def Belote.hands_first_go(seed: U32, lead: U32, index: U32, hands: Belote.Hands) -> Belote.Hands:
  match index == 20:
    case 0:
      seat = (lead + (index % 4)) % 4
      Belote.hands_first_go(seed, lead, index + 1, Belote.hands_add(hands, seat, Belote.u32_deal_card(seed, index)))
    case done:
      hands

def Belote.hands_first(seed: U32, dealer: U32) -> Belote.Hands:
  Belote.hands_first_go(seed, Belote.u32_next_seat(dealer), 0, Belote.hands_empty())

def Belote.u32_skip_taker(lead: U32, taker: U32, wanted: U32, scan: U32) -> U32:
  seat = (lead + scan) % 4
  match seat == taker:
    case 0:
      match wanted:
        case 0: seat
        case left: Belote.u32_skip_taker(lead, taker, left - 1, scan + 1)
    case skip:
      Belote.u32_skip_taker(lead, taker, wanted, scan + 1)

def Belote.hands_rest_go(seed: U32, lead: U32, taker: U32, index: U32, hands: Belote.Hands) -> Belote.Hands:
  match index == 11:
    case 0:
      seat : U32 = match index < 8:
                        case 0: Belote.u32_skip_taker(lead, taker, index - 8, 0)
                        case first_two: (lead + (index % 4)) % 4
      Belote.hands_rest_go(seed, lead, taker, index + 1, Belote.hands_add(hands, seat, Belote.u32_deal_card(seed, 21 + index)))
    case done:
      hands

def Belote.hands_complete(seed: U32, dealer: U32, taker: U32, hands: Belote.Hands) -> Belote.Hands:
  with_turn = Belote.hands_add(hands, taker, Belote.u32_deal_card(seed, 20))
  Belote.hands_rest_go(seed, Belote.u32_next_seat(dealer), taker, 0, with_turn)

# ---------------------------------------------------------------- Trick

def Belote.trick_empty() -> Belote.Trick:
  Belote.Trick.Trick{0, 0, 0, 0, 0, 0, 0, 0, 0}

def Belote.trick_lead(trick: Belote.Trick) -> U32:
  match trick:
    case Belote.Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
      Belote.card_suit(card0)

def Belote.trick_add(trick: Belote.Trick, seat: U32, card: U32) -> Belote.Trick:
  match trick:
    case Belote.Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
      match count:
        case 0: Belote.Trick.Trick{1, seat, card, 0, 0, 0, 0, 0, 0}
        case 1: Belote.Trick.Trick{2, seat0, card0, seat, card, 0, 0, 0, 0}
        case 2: Belote.Trick.Trick{3, seat0, card0, seat1, card1, seat, card, 0, 0}
        case other: Belote.Trick.Trick{4, seat0, card0, seat1, card1, seat2, card2, seat, card}

def Belote.winner_choose(winner: Belote.Winner, seat: U32, card: U32, lead: U32, trump: U32) -> Belote.Winner:
  match winner:
    case Belote.Winner.Winner{held_seat, held_card}:
      match Belote.card_beats(card, held_card, lead, trump):
        case 0: Belote.Winner.Winner{held_seat, held_card}
        case beats: Belote.Winner.Winner{seat, card}

def Belote.trick_winner(trick: Belote.Trick, trump: U32) -> Belote.Winner:
  match trick:
    case Belote.Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
      lead = Belote.card_suit(card0)
      first : Belote.Winner = Belote.Winner.Winner{seat0, card0}
      second : Belote.Winner = match count > 1:
                                                  case 0: first
                                                  case yes: Belote.winner_choose(first, seat1, card1, lead, trump)
      third : Belote.Winner = match count > 2:
                                                 case 0: second
                                                 case yes: Belote.winner_choose(second, seat2, card2, lead, trump)
      match count > 3:
        case 0: third
        case yes: Belote.winner_choose(third, seat3, card3, lead, trump)

def Belote.trick_top_trump(trick: Belote.Trick, trump: U32) -> U32:
  match trick:
    case Belote.Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
      top0 : U32 = match (count > 0) && (Belote.card_suit(card0) == trump):
                         case 0: 0
                         case yes: Belote.card_trump_order(card0) + 1
      top1 : U32 = match (count > 1) && (Belote.card_suit(card1) == trump):
                         case 0: top0
                         case yes: U32.max(top0, Belote.card_trump_order(card1) + 1)
      top2 : U32 = match (count > 2) && (Belote.card_suit(card2) == trump):
                         case 0: top1
                         case yes: U32.max(top1, Belote.card_trump_order(card2) + 1)
      match (count > 3) && (Belote.card_suit(card3) == trump):
        case 0: top2
        case yes: U32.max(top2, Belote.card_trump_order(card3) + 1)

def Belote.trick_points(trick: Belote.Trick, trump: U32) -> U32:
  match trick:
    case Belote.Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
      p0 : U32 = match count > 0:
                       case 0: 0
                       case yes: Belote.card_points(card0, trump)
      p1 : U32 = match count > 1:
                       case 0: 0
                       case yes: Belote.card_points(card1, trump)
      p2 : U32 = match count > 2:
                       case 0: 0
                       case yes: Belote.card_points(card2, trump)
      p3 : U32 = match count > 3:
                       case 0: 0
                       case yes: Belote.card_points(card3, trump)
      (p0 + p1) + (p2 + p3)

def Belote.trick_json(trick: Belote.Trick) -> String:
  match trick:
    case Belote.Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
      a : String = match count > 0:
                           case 0: ""
                           case yes: String.flatten(["{\"seat\":", String.from_u32(seat0), ",\"card\":", String.from_u32(card0), "}"])
      b : String = match count > 1:
                           case 0: ""
                           case yes: String.flatten([",{\"seat\":", String.from_u32(seat1), ",\"card\":", String.from_u32(card1), "}"])
      c : String = match count > 2:
                           case 0: ""
                           case yes: String.flatten([",{\"seat\":", String.from_u32(seat2), ",\"card\":", String.from_u32(card2), "}"])
      d : String = match count > 3:
                           case 0: ""
                           case yes: String.flatten([",{\"seat\":", String.from_u32(seat3), ",\"card\":", String.from_u32(card3), "}"])
      String.flatten(["[", a, b, c, d, "]"])

# ---------------------------------------------------------------- Legality

def Belote.card_overtrump_ok(hand: U32, card: U32, trick: Belote.Trick, trump: U32) -> U32:
  top = Belote.trick_top_trump(trick, trump)
  match Belote.hand_has_higher(hand, trump, top):
    case 0: 1
    case higher: (Belote.card_trump_order(card) + 1) > top

def Belote.card_legal(hand: U32, seat: U32, card: U32, trick: Belote.Trick, trump: U32) -> U32:
  match Belote.hand_has(hand, card):
    case 0: 0
    case owned:
      match trick:
        case Belote.Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
          match count:
            case 0: 1
            case played:
              lead = Belote.card_suit(card0)
              match Belote.hand_has_suit(hand, lead):
                case 0:
                  match Belote.trick_winner(Belote.Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}, trump):
                    case Belote.Winner.Winner{winning_seat, winning_card}:
                      match winning_seat == ((seat + 2) % 4):
                        case 0:
                          match Belote.hand_has_suit(hand, trump):
                            case 0: 1
                            case must_cut:
                              match Belote.card_suit(card) == trump:
                                case 0: 0
                                case atout: Belote.card_overtrump_ok(hand, card, Belote.Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}, trump)
                        case partner_winning: 1
                case follows:
                  match Belote.card_suit(card) == lead:
                    case 0: 0
                    case yes:
                      match lead == trump:
                        case 0: 1
                        case atout: Belote.card_overtrump_ok(hand, card, Belote.Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}, trump)

def Belote.hand_first_legal_go(hand: U32, seat: U32, trick: Belote.Trick, trump: U32, card: U32) -> U32:
  match card == 32:
    case 0:
      match Belote.card_legal(hand, seat, card, trick, trump):
        case 0: Belote.hand_first_legal_go(hand, seat, trick, trump, card + 1)
        case legal: card
    case none: 32

def Belote.hand_first_legal(hand: U32, seat: U32, trick: Belote.Trick, trump: U32) -> U32:
  Belote.hand_first_legal_go(hand, seat, trick, trump, 0)

# ---------------------------------------------------------------- Bidding and scoring

def Belote.hands_belote(hands: Belote.Hands, trump: U32) -> U32:
  queen = (trump * 8) + 4
  king = (trump * 8) + 5
  team0 = (Belote.hand_has(Belote.hands_get(hands, 0), queen) && Belote.hand_has(Belote.hands_get(hands, 0), king)) || (Belote.hand_has(Belote.hands_get(hands, 2), queen) && Belote.hand_has(Belote.hands_get(hands, 2), king))
  team1 = (Belote.hand_has(Belote.hands_get(hands, 1), queen) && Belote.hand_has(Belote.hands_get(hands, 1), king)) || (Belote.hand_has(Belote.hands_get(hands, 3), queen) && Belote.hand_has(Belote.hands_get(hands, 3), king))
  match team0:
    case 0: team1 * 2
    case yes: 1

def Belote.game_deal(seed: U32, dealer: U32, score0: U32, score1: U32, hand: U32) -> Belote.Game:
  offered = Belote.card_suit(Belote.u32_deal_card(seed, 20))
  Belote.Game.Game{0, dealer, Belote.u32_next_seat(dealer), 4, 4, offered, 0, seed, Belote.hands_first(seed, dealer), Belote.trick_empty(), 0, 0, 0, score0, score1, hand, 0, "Five cards each. The turned suit is offered first."}

def Belote.game_accept(game: Belote.Game, seat: U32, trump: U32) -> Belote.Game:
  match game:
    case Belote.Game.Game{phase, dealer, turn, taker, old_trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      full = Belote.hands_complete(seed, dealer, seat, hands)
      bonus = Belote.hands_belote(full, trump)
      message : String = match bonus:
                               case 0: "Trump accepted. The remaining cards are dealt."
                               case team: "Trump accepted. Belote/Rebelote is present for a 20-point bonus."
      Belote.Game.Game{2, dealer, Belote.u32_next_seat(dealer), seat, trump, offered, 0, seed, full, Belote.trick_empty(), 0, 0, 0, score0, score1, hand, bonus, message}

def Belote.game_pass(game: Belote.Game) -> Belote.Game:
  match game:
    case Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      passed = passes + 1
      match passed == 4:
        case 0:
          Belote.Game.Game{phase, dealer, Belote.u32_next_seat(turn), taker, trump, offered, passed, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, "Pass."}
        case all:
          match phase:
            case 0:
              Belote.Game.Game{1, dealer, Belote.u32_next_seat(dealer), taker, trump, offered, 0, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, "Everyone passed. Choose any other suit."}
            case second:
              Belote.game_deal((seed * 1664525) + 1013904223, Belote.u32_next_seat(dealer), score0, score1, hand + 1)

def Belote.game_bid_choice(game: Belote.Game, seat: U32, choice: U32) -> Belote.Game:
  match game:
    case Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      match choice:
        case 0: Belote.game_pass(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note})
        case selected:
          suit = selected - 1
          valid : U32 = match phase:
                                case 0: suit == offered
                                case second: (suit < 4) && ((suit == offered) == 0)
          match valid:
            case 0: Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, "That suit is not available in this bidding round."}
            case yes: Belote.game_accept(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, seat, suit)

def Belote.hand_best_suit_go(hand: U32, offered: U32, phase: U32, suit: U32, best: U32, value: U32) -> U32:
  match suit == 4:
    case 0:
      allowed = (phase == 0) || ((suit == offered) == 0)
      strength = Belote.hand_bid_value(hand, suit) * allowed
      match strength > value:
        case 0: Belote.hand_best_suit_go(hand, offered, phase, suit + 1, best, value)
        case stronger: Belote.hand_best_suit_go(hand, offered, phase, suit + 1, suit, strength)
    case done: best

def Belote.hand_best_suit(hand: U32, offered: U32, phase: U32) -> U32:
  Belote.hand_best_suit_go(hand, offered, phase, 0, offered, 0)

def Belote.game_bid_ai(game: Belote.Game) -> Belote.Game:
  match game:
    case Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      cards = Belote.hands_get(hands, turn)
      suit : U32 = match phase:
                           case 0: offered
                           case second: Belote.hand_best_suit(cards, offered, 1)
      strength = Belote.hand_bid_value(cards, suit)
      must_take = (phase == 1) && (passes == 3)
      threshold : U32 = match phase:
                                case 0: 30
                                case second: 27
      choice : U32 = match (strength >= threshold) || must_take:
                             case 0: 0
                             case take: suit + 1
      Belote.game_bid_choice(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, turn, choice)

# ---------------------------------------------------------------- Play

def Belote.game_finish(game: Belote.Game) -> Belote.Game:
  match game:
    case Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      taking_team = taker % 2
      made : U32 = match taking_team:
                           case 0: points0 > points1
                           case team1: points1 > points0
      bonus0 = (belote == 1) * 20
      bonus1 = (belote == 2) * 20
      award0 : U32 = match made:
                             case 0:
                               match taking_team:
                                             case 0: bonus0
                                             case team1: 162 + bonus0
                             case success: points0 + bonus0
      award1 : U32 = match made:
                             case 0:
                               match taking_team:
                                             case 0: 162 + bonus1
                                             case team1: bonus1
                             case success: points1 + bonus1
      total0 = score0 + award0
      total1 = score1 + award1
      end_phase : U32 = match (total0 >= 501) || (total1 >= 501):
                                 case 0: 3
                                 case won: 4
      result : String = match made:
                              case 0: "Contract failed: the defenders score the 162 card points."
                              case success: "Contract made: both teams bank their card points."
      Belote.Game.Game{end_phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, total0, total1, hand, belote, result}

def Belote.game_play_seat(game: Belote.Game, seat: U32, card: U32) -> Belote.Game:
  match game:
    case Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      reduced = Belote.hands_remove(hands, seat, card)
      table = Belote.trick_add(trick, seat, card)
      match table:
        case Belote.Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
          match count == 4:
            case 0:
              Belote.Game.Game{phase, dealer, Belote.u32_next_seat(seat), taker, trump, offered, passes, seed, reduced, table, tricks, points0, points1, score0, score1, hand, belote, "Card played."}
            case complete:
              match Belote.trick_winner(table, trump):
                case Belote.Winner.Winner{winning_seat, winning_card}:
                  last = tricks == 7
                  value = Belote.trick_points(table, trump) + (last * 10)
                  p0 = points0 + (value * ((winning_seat % 2) == 0))
                  p1 = points1 + (value * (winning_seat % 2))
                  next : Belote.Game = Belote.Game.Game{phase, dealer, winning_seat, taker, trump, offered, passes, seed, reduced, Belote.trick_empty(), tricks + 1, p0, p1, score0, score1, hand, belote, "Belote.Trick collected."}
                  match last:
                    case 0: next
                    case final: Belote.game_finish(next)

def Belote.game_play_ai(game: Belote.Game) -> Belote.Game:
  match game:
    case Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      card = Belote.hand_first_legal(Belote.hands_get(hands, turn), turn, trick, trump)
      match card == 32:
        case 0: Belote.game_play_seat(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, turn, card)
        case none: Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, "No legal AI card was found."}

def Belote.game_auto(game: Belote.Game, fuel: U32) -> Belote.Game:
  match fuel:
    case 0: game
    case more:
      match game:
        case Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
          match (phase <= 1) && (turn != 0):
            case 0:
              match (phase == 2) && (turn != 0):
                case 0: Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}
                case ai_turn: Belote.game_auto(Belote.game_play_ai(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}), more - 1)
            case ai_bid: Belote.game_auto(Belote.game_bid_ai(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}), more - 1)

def Belote.game_empty(seed: U32) -> Belote.Game:
  Belote.game_deal(seed, 3, 0, 0, 1)

def Belote.game_error(game: Belote.Game, note: String) -> Belote.Action:
  Belote.Action.Action{game, 0, note}

def Belote.game_ok(game: Belote.Game) -> Belote.Action:
  Belote.Action.Action{game, 1, ""}

def Belote.game_bid(game: Belote.Game, choice: U32) -> Belote.Action:
  match game:
    case Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      match (phase <= 1) && (turn == 0):
        case 0: Belote.game_error(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, "It is not your bidding turn.")
        case yes:
          next = Belote.game_bid_choice(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, 0, choice)
          Belote.game_ok(next)

def Belote.game_play(game: Belote.Game, card: U32) -> Belote.Action:
  match game:
    case Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      match (phase == 2) && (turn == 0):
        case 0: Belote.game_error(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, "Wait for your turn to play.")
        case yes:
          match (card < 32) && Belote.card_legal(Belote.hands_get(hands, 0), 0, card, trick, trump):
            case 0: Belote.game_error(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, "That card is not legal: follow suit, cut, and overtrump when required.")
            case legal:
              next = Belote.game_play_seat(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, 0, card)
              Belote.game_ok(next)

def Belote.game_step(game: Belote.Game) -> Belote.Action:
  match game:
    case Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      match (phase <= 1) && (turn != 0):
        case 0:
          match (phase == 2) && (turn != 0):
            case 0: Belote.game_error(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, "The table is waiting for your decision.")
            case play: Belote.game_ok(Belote.game_play_ai(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}))
        case bid: Belote.game_ok(Belote.game_bid_ai(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}))

def Belote.game_next(game: Belote.Game) -> Belote.Action:
  match game:
    case Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      match phase == 3:
        case 0: Belote.game_error(Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, "Finish this hand first.")
        case ready: Belote.game_ok(Belote.game_deal((seed * 1664525) + 1013904223, Belote.u32_next_seat(dealer), score0, score1, hand + 1))

# Pure smoke probe used by the README verification command.
def Belote.test() -> U32:
  first = Belote.hands_first(123456789, 3)
  full = Belote.hands_complete(123456789, 3, 0, first)
  first_counts = ((Belote.hand_count(Belote.hands_get(first, 0)) == 5) && (Belote.hand_count(Belote.hands_get(first, 1)) == 5)) && ((Belote.hand_count(Belote.hands_get(first, 2)) == 5) && (Belote.hand_count(Belote.hands_get(first, 3)) == 5))
  full_counts = ((Belote.hand_count(Belote.hands_get(full, 0)) == 8) && (Belote.hand_count(Belote.hands_get(full, 1)) == 8)) && ((Belote.hand_count(Belote.hands_get(full, 2)) == 8) && (Belote.hand_count(Belote.hands_get(full, 3)) == 8))
  disjoint = (((Belote.hands_get(full, 0) .&. Belote.hands_get(full, 1)) == 0) && ((Belote.hands_get(full, 0) .&. Belote.hands_get(full, 2)) == 0)) && ((Belote.hands_get(full, 1) .&. Belote.hands_get(full, 3)) == 0)
  ranks = (Belote.card_points(19, 2) == 20) && ((Belote.card_points(18, 2) == 14) && (Belote.card_points(7, 2) == 11))
  first_counts && (full_counts && (disjoint && ranks))

# ---------------------------------------------------------------- JSON and HTTP

def Belote.game_json(game: Belote.Game, ok: U32, action_note: String) -> String:
  match game:
    case Belote.Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      shown_note : String = match String.length(action_note):
                                      case 0: note
                                      case present: action_note
      String.flatten([
        "{\"ok\":", String.from_u32(ok), ",\"note\":", JSON.quoted(shown_note, ""),
        ",\"phase\":", String.from_u32(phase), ",\"dealer\":", String.from_u32(dealer),
        ",\"turn\":", String.from_u32(turn), ",\"taker\":", String.from_u32(taker),
        ",\"trump\":", String.from_u32(trump), ",\"offered\":", String.from_u32(offered),
        ",\"seed\":", String.from_u32(seed),
        ",\"turned\":", String.from_u32(Belote.u32_deal_card(seed, 20)),
        ",\"passes\":", String.from_u32(passes), ",\"handNumber\":", String.from_u32(hand),
        ",\"hand\":", Belote.hand_json(Belote.hands_get(hands, 0)),
        ",\"counts\":[", String.from_u32(Belote.hand_count(Belote.hands_get(hands, 0))), ",", String.from_u32(Belote.hand_count(Belote.hands_get(hands, 1))), ",", String.from_u32(Belote.hand_count(Belote.hands_get(hands, 2))), ",", String.from_u32(Belote.hand_count(Belote.hands_get(hands, 3))), "]",
        ",\"trick\":", Belote.trick_json(trick), ",\"tricks\":", String.from_u32(tricks),
        ",\"points\":[", String.from_u32(points0), ",", String.from_u32(points1), "]",
        ",\"scores\":[", String.from_u32(score0), ",", String.from_u32(score1), "]",
        ",\"beloteTeam\":", String.from_u32(belote), "}"
      ])

def Belote.game_response(game: Belote.Game, ok: U32, note: String) -> HTTP.Response:
  HTTP.Response.Response{200,
    [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"}, HTTP.Header.Header{"Cache-Control", "no-store"}],
    Bytes.from_string(Belote.game_json(game, ok, note))}

def Belote.action_routed(action: Belote.Action) -> Belote.Routed:
  match action:
    case Belote.Action.Action{game, ok, note}: Belote.Routed.Routed{game, Belote.game_response(game, ok, note)}

def Belote.game_routed(game: Belote.Game) -> Belote.Routed:
  Belote.Routed.Routed{game, Belote.game_response(game, 1, "")}

def Belote.result_index(result: Result((U32 & String), String), game: Belote.Game) -> IO(Belote.Routed):
  match result:
    case Result.Done{html}: IO.pure(Belote.Routed, Belote.Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}: IO.pure(Belote.Routed, Belote.Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "Belote page not found -- run from the repository root\n")})

def Belote.game_index(game: Belote.Game) -> IO(Belote.Routed):
  do IO(Belote.Routed):
    result <- IO.read_text("gabriel_demos/belote_web/index.html")
    Belote.result_index(result, game)

def Belote.list_action(name: String, args: List(String), game: Belote.Game) -> IO(Belote.Routed):
  match String.eq_u32(name, "state"):
    case 0:
      match String.eq_u32(name, "bid"):
        case 0:
          match String.eq_u32(name, "play"):
            case 0:
              match String.eq_u32(name, "auto"):
                case 0:
                  match String.eq_u32(name, "next"):
                    case 0:
                      match String.eq_u32(name, "new"):
                        case 0: IO.pure(Belote.Routed, Belote.Routed.Routed{game, HTTP.not_found()})
                        case reset:
                          do IO(Belote.Routed):
                            seed <- IO.rand_word()
                            return Belote.game_routed(Belote.game_empty(seed))
                    case next: IO.pure(Belote.Routed, Belote.action_routed(Belote.game_next(game)))
                case auto: IO.pure(Belote.Routed, Belote.action_routed(Belote.game_step(game)))
            case play:
              match args:
                case List.Cons{card, rest}: IO.pure(Belote.Routed, Belote.action_routed(Belote.game_play(game, String.to_u32(card))))
                case List.Nil{}: IO.pure(Belote.Routed, Belote.Routed.Routed{game, HTTP.not_found()})
        case bid:
          match args:
            case List.Cons{choice, rest}: IO.pure(Belote.Routed, Belote.action_routed(Belote.game_bid(game, String.to_u32(choice))))
            case List.Nil{}: IO.pure(Belote.Routed, Belote.Routed.Routed{game, HTTP.not_found()})
    case state: IO.pure(Belote.Routed, Belote.game_routed(game))

def Belote.list_route(parts: List(String), game: Belote.Game) -> IO(Belote.Routed):
  match parts:
    case List.Cons{root, List.Cons{"", rest}}: Belote.game_index(game)
    case List.Cons{root, List.Cons{name, args}}: Belote.list_action(name, args, game)
    case other: Belote.game_index(game)

def Belote.request_route(request: HTTP.Request, game: Belote.Game) -> IO(Belote.Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0: IO.pure(Belote.Routed, Belote.Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")})
        case get: Belote.list_route(String.split('/', path), game)

# ---------------------------------------------------------------- Server

def Belote.routed_send(routed: Belote.Routed, server: TCP, conn: HTTP) -> IO(U32):
  match routed:
    case Belote.Routed.Routed{game, response}:
      do IO(U32):
        sent <- HTTP.send_response(conn, HTTP.with_connection(0, response))
        closed <- HTTP.close(conn)
        Belote.u32_serve(server, game)

def Belote.inbound_serve(inbound: HTTP.Inbound, server: TCP, conn: HTTP, game: Belote.Game) -> IO(U32):
  match inbound:
    case HTTP.Inbound.Got{http11, request, rest}:
      do IO(U32):
        routed <- Belote.request_route(request, game)
        Belote.routed_send(routed, server, conn)
    case HTTP.Inbound.Closed{}:
      do IO(U32):
        closed <- HTTP.close(conn)
        Belote.u32_serve(server, game)
    case HTTP.Inbound.Bad{code, error}: Belote.routed_send(Belote.Routed.Routed{game, HTTP.reply_error(code, error)}, server, conn)

def Belote.result_accept(result: Result((U32 & String), TCP), server: TCP, game: Belote.Game) -> IO(U32):
  match result:
    case Result.Done{fd}:
      do IO(U32):
        inbound <- HTTP.recv_request(HTTP.Plain{fd}, List.Nil{})
        Belote.inbound_serve(inbound, server, HTTP.Plain{fd}, game)
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["accept failed: ", error, "\n"]))
        return 1

def Belote.u32_serve(server: TCP, game: Belote.Game) -> IO(U32):
  do IO(U32):
    result <- TCP.accept(server)
    Belote.result_accept(result, server, game)

def Belote.result_main(result: Result((U32 & String), TCP), seed: U32) -> IO(U32):
  match result:
    case Result.Done{server}:
      do IO(U32):
        printed <- IO.write("Bend3 Belote listening on 0.0.0.0:8091\nopen http://<server-lan-ip>:8091\n")
        Belote.u32_serve(server, Belote.game_empty(seed))
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def Belote.main() -> IO(U32):
  do IO(U32):
    seed <- IO.rand_word()
    result <- TCP.listen(8091)
    Belote.result_main(result, seed)
