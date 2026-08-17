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

import ../../bend-base/Base
import ../Compat
import ../../bend-base/IO/TCP
import ../../bend-base/IO/HTTP
import ../../bend-base/JSON

type Hands:
  Hands{south: U32, east: U32, north: U32, west: U32}

type Trick:
  Trick{count: U32, seat0: U32, card0: U32, seat1: U32, card1: U32, seat2: U32, card2: U32, seat3: U32, card3: U32}

type Winner:
  Winner{seat: U32, card: U32}

type Game:
  Game{phase: U32, dealer: U32, turn: U32, taker: U32, trump: U32, offered: U32, passes: U32, seed: U32, hands: Hands, trick: Trick, tricks: U32, points0: U32, points1: U32, score0: U32, score1: U32, hand: U32, belote: U32, note: String}

type Action:
  Action{game: Game, ok: U32, note: String}

type Routed:
  Routed{game: Game, response: HTTP.Response}

# ---------------------------------------------------------------- Card

def card_suit(card: U32) -> U32:
  card / 8

def card_rank(card: U32) -> U32:
  card % 8

def card_bit(card: U32) -> U32:
  1 << card

def card_trump_order(card: U32) -> U32:
  match card_rank(card):
    case 0: 0
    case 1: 1
    case 2: 6
    case 3: 7
    case 4: 2
    case 5: 3
    case 6: 4
    case rank: 5

def card_points(card: U32, trump: U32) -> U32:
  match card_suit(card) == trump:
    case 0:
      match card_rank(card):
        case 0: 0
        case 1: 0
        case 2: 0
        case 3: 2
        case 4: 3
        case 5: 4
        case 6: 10
        case rank: 11
    case atout:
      match card_rank(card):
        case 0: 0
        case 1: 0
        case 2: 14
        case 3: 20
        case 4: 3
        case 5: 4
        case 6: 10
        case rank: 11

def card_power(card: U32, lead: U32, trump: U32) -> U32:
  match card_suit(card) == trump:
    case 0:
      match card_suit(card) == lead:
        case 0: card_rank(card)
        case asked: 32 + card_rank(card)
    case atout:
      64 + card_trump_order(card)

def card_beats(card: U32, held: U32, lead: U32, trump: U32) -> U32:
  card_power(card, lead, trump) > card_power(held, lead, trump)

# ---------------------------------------------------------------- Hand

def hand_has(hand: U32, card: U32) -> U32:
  (hand .&. card_bit(card)) > 0

def hand_add(hand: U32, card: U32) -> U32:
  hand .|. card_bit(card)

def hand_remove(hand: U32, card: U32) -> U32:
  hand - card_bit(card)

def hand_has_suit_go(hand: U32, suit: U32, rank: U32) -> U32:
  match rank == 8:
    case 0:
      match hand_has(hand, (suit * 8) + rank):
        case 0: hand_has_suit_go(hand, suit, rank + 1)
        case found: 1
    case done:
      0

def hand_has_suit(hand: U32, suit: U32) -> U32:
  hand_has_suit_go(hand, suit, 0)

def hand_count_go(hand: U32, card: U32) -> U32:
  match card == 32:
    case 0: hand_has(hand, card) + hand_count_go(hand, card + 1)
    case done: 0

def hand_count(hand: U32) -> U32:
  hand_count_go(hand, 0)

def hand_has_higher_go(hand: U32, trump: U32, top: U32, rank: U32) -> U32:
  match rank == 8:
    case 0:
      card = (trump * 8) + rank
      match hand_has(hand, card) && ((card_trump_order(card) + 1) > top):
        case 0: hand_has_higher_go(hand, trump, top, rank + 1)
        case found: 1
    case done:
      0

def hand_has_higher(hand: U32, trump: U32, top: U32) -> U32:
  hand_has_higher_go(hand, trump, top, 0)

def hand_bid_value_go(hand: U32, suit: U32, card: U32) -> U32:
  match card == 32:
    case 0:
      value = card_points(card, suit)
      bonus = (card_suit(card) == suit) * 4
      (hand_has(hand, card) * (value + bonus)) + hand_bid_value_go(hand, suit, card + 1)
    case done:
      0

def hand_bid_value(hand: U32, suit: U32) -> U32:
  hand_bid_value_go(hand, suit, 0)

def hand_json_go(hand: U32, card: U32, first: U32) -> String:
  match card == 32:
    case 0:
      match hand_has(hand, card):
        case 0: hand_json_go(hand, card + 1, first)
        case found:
          match first:
            case 0: String.flatten([",", String.from_u32(card), hand_json_go(hand, card + 1, 0)])
            case yes: String.flatten([String.from_u32(card), hand_json_go(hand, card + 1, 0)])
    case done:
      "]"

def hand_json(hand: U32) -> String:
  String.concat("[", hand_json_go(hand, 0, 1))

# ---------------------------------------------------------------- Hands

def hands_empty() -> Hands:
  Hands.Hands{0, 0, 0, 0}

def hands_get(hands: Hands, seat: U32) -> U32:
  match hands:
    case Hands.Hands{south, east, north, west}:
      match seat % 4:
        case 0: south
        case 1: east
        case 2: north
        case other: west

def hands_set(hands: Hands, seat: U32, hand: U32) -> Hands:
  match hands:
    case Hands.Hands{south, east, north, west}:
      match seat % 4:
        case 0: Hands.Hands{hand, east, north, west}
        case 1: Hands.Hands{south, hand, north, west}
        case 2: Hands.Hands{south, east, hand, west}
        case other: Hands.Hands{south, east, north, hand}

def hands_add(hands: Hands, seat: U32, card: U32) -> Hands:
  hands_set(hands, seat, hand_add(hands_get(hands, seat), card))

def hands_remove(hands: Hands, seat: U32, card: U32) -> Hands:
  hands_set(hands, seat, hand_remove(hands_get(hands, seat), card))

# ---------------------------------------------------------------- Deal

def u32_next_seat(seat: U32) -> U32:
  (seat + 1) % 4

def u32_deal_card(seed: U32, index: U32) -> U32:
  multiplier = ((seed % 16) * 2) + 1
  offset = (seed / 16) % 32
  ((index * multiplier) + offset) % 32

def hands_first_go(seed: U32, lead: U32, index: U32, hands: Hands) -> Hands:
  match index == 20:
    case 0:
      seat = (lead + (index % 4)) % 4
      hands_first_go(seed, lead, index + 1, hands_add(hands, seat, u32_deal_card(seed, index)))
    case done:
      hands

def hands_first(seed: U32, dealer: U32) -> Hands:
  hands_first_go(seed, u32_next_seat(dealer), 0, hands_empty())

def u32_skip_taker(lead: U32, taker: U32, wanted: U32, scan: U32) -> U32:
  seat = (lead + scan) % 4
  match seat == taker:
    case 0:
      match wanted:
        case 0: seat
        case left: u32_skip_taker(lead, taker, left - 1, scan + 1)
    case skip:
      u32_skip_taker(lead, taker, wanted, scan + 1)

def hands_rest_go(seed: U32, lead: U32, taker: U32, index: U32, hands: Hands) -> Hands:
  match index == 11:
    case 0:
      seat : U32 = match index < 8:
                        case 0: u32_skip_taker(lead, taker, index - 8, 0)
                        case first_two: (lead + (index % 4)) % 4
      hands_rest_go(seed, lead, taker, index + 1, hands_add(hands, seat, u32_deal_card(seed, 21 + index)))
    case done:
      hands

def hands_complete(seed: U32, dealer: U32, taker: U32, hands: Hands) -> Hands:
  with_turn = hands_add(hands, taker, u32_deal_card(seed, 20))
  hands_rest_go(seed, u32_next_seat(dealer), taker, 0, with_turn)

# ---------------------------------------------------------------- Trick

def trick_empty() -> Trick:
  Trick.Trick{0, 0, 0, 0, 0, 0, 0, 0, 0}

def trick_lead(trick: Trick) -> U32:
  match trick:
    case Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
      card_suit(card0)

def trick_add(trick: Trick, seat: U32, card: U32) -> Trick:
  match trick:
    case Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
      match count:
        case 0: Trick.Trick{1, seat, card, 0, 0, 0, 0, 0, 0}
        case 1: Trick.Trick{2, seat0, card0, seat, card, 0, 0, 0, 0}
        case 2: Trick.Trick{3, seat0, card0, seat1, card1, seat, card, 0, 0}
        case other: Trick.Trick{4, seat0, card0, seat1, card1, seat2, card2, seat, card}

def winner_choose(winner: Winner, seat: U32, card: U32, lead: U32, trump: U32) -> Winner:
  match winner:
    case Winner.Winner{held_seat, held_card}:
      match card_beats(card, held_card, lead, trump):
        case 0: Winner.Winner{held_seat, held_card}
        case beats: Winner.Winner{seat, card}

def trick_winner(trick: Trick, trump: U32) -> Winner:
  match trick:
    case Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
      lead = card_suit(card0)
      first : Winner = Winner.Winner{seat0, card0}
      second : Winner = match count > 1:
                                                  case 0: first
                                                  case yes: winner_choose(first, seat1, card1, lead, trump)
      third : Winner = match count > 2:
                                                 case 0: second
                                                 case yes: winner_choose(second, seat2, card2, lead, trump)
      match count > 3:
        case 0: third
        case yes: winner_choose(third, seat3, card3, lead, trump)

def trick_top_trump(trick: Trick, trump: U32) -> U32:
  match trick:
    case Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
      top0 : U32 = match (count > 0) && (card_suit(card0) == trump):
                         case 0: 0
                         case yes: card_trump_order(card0) + 1
      top1 : U32 = match (count > 1) && (card_suit(card1) == trump):
                         case 0: top0
                         case yes: U32.max(top0, card_trump_order(card1) + 1)
      top2 : U32 = match (count > 2) && (card_suit(card2) == trump):
                         case 0: top1
                         case yes: U32.max(top1, card_trump_order(card2) + 1)
      match (count > 3) && (card_suit(card3) == trump):
        case 0: top2
        case yes: U32.max(top2, card_trump_order(card3) + 1)

def trick_points(trick: Trick, trump: U32) -> U32:
  match trick:
    case Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
      p0 : U32 = match count > 0:
                       case 0: 0
                       case yes: card_points(card0, trump)
      p1 : U32 = match count > 1:
                       case 0: 0
                       case yes: card_points(card1, trump)
      p2 : U32 = match count > 2:
                       case 0: 0
                       case yes: card_points(card2, trump)
      p3 : U32 = match count > 3:
                       case 0: 0
                       case yes: card_points(card3, trump)
      (p0 + p1) + (p2 + p3)

def trick_json(trick: Trick) -> String:
  match trick:
    case Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
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

def card_overtrump_ok(hand: U32, card: U32, trick: Trick, trump: U32) -> U32:
  top = trick_top_trump(trick, trump)
  match hand_has_higher(hand, trump, top):
    case 0: 1
    case higher: (card_trump_order(card) + 1) > top

def card_legal(hand: U32, seat: U32, card: U32, trick: Trick, trump: U32) -> U32:
  match hand_has(hand, card):
    case 0: 0
    case owned:
      match trick:
        case Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
          match count:
            case 0: 1
            case played:
              lead = card_suit(card0)
              match hand_has_suit(hand, lead):
                case 0:
                  match trick_winner(Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}, trump):
                    case Winner.Winner{winning_seat, winning_card}:
                      match winning_seat == ((seat + 2) % 4):
                        case 0:
                          match hand_has_suit(hand, trump):
                            case 0: 1
                            case must_cut:
                              match card_suit(card) == trump:
                                case 0: 0
                                case atout: card_overtrump_ok(hand, card, Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}, trump)
                        case partner_winning: 1
                case follows:
                  match card_suit(card) == lead:
                    case 0: 0
                    case yes:
                      match lead == trump:
                        case 0: 1
                        case atout: card_overtrump_ok(hand, card, Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}, trump)

def hand_first_legal_go(hand: U32, seat: U32, trick: Trick, trump: U32, card: U32) -> U32:
  match card == 32:
    case 0:
      match card_legal(hand, seat, card, trick, trump):
        case 0: hand_first_legal_go(hand, seat, trick, trump, card + 1)
        case legal: card
    case none: 32

def hand_first_legal(hand: U32, seat: U32, trick: Trick, trump: U32) -> U32:
  hand_first_legal_go(hand, seat, trick, trump, 0)

# ---------------------------------------------------------------- Bidding and scoring

def hands_belote(hands: Hands, trump: U32) -> U32:
  queen = (trump * 8) + 4
  king = (trump * 8) + 5
  team0 = (hand_has(hands_get(hands, 0), queen) && hand_has(hands_get(hands, 0), king)) || (hand_has(hands_get(hands, 2), queen) && hand_has(hands_get(hands, 2), king))
  team1 = (hand_has(hands_get(hands, 1), queen) && hand_has(hands_get(hands, 1), king)) || (hand_has(hands_get(hands, 3), queen) && hand_has(hands_get(hands, 3), king))
  match team0:
    case 0: team1 * 2
    case yes: 1

def game_deal(seed: U32, dealer: U32, score0: U32, score1: U32, hand: U32) -> Game:
  offered = card_suit(u32_deal_card(seed, 20))
  Game.Game{0, dealer, u32_next_seat(dealer), 4, 4, offered, 0, seed, hands_first(seed, dealer), trick_empty(), 0, 0, 0, score0, score1, hand, 0, "Five cards each. The turned suit is offered first."}

def game_accept(game: Game, seat: U32, trump: U32) -> Game:
  match game:
    case Game.Game{phase, dealer, turn, taker, old_trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      full = hands_complete(seed, dealer, seat, hands)
      bonus = hands_belote(full, trump)
      message : String = match bonus:
                               case 0: "Trump accepted. The remaining cards are dealt."
                               case team: "Trump accepted. Belote/Rebelote is present for a 20-point bonus."
      Game.Game{2, dealer, u32_next_seat(dealer), seat, trump, offered, 0, seed, full, trick_empty(), 0, 0, 0, score0, score1, hand, bonus, message}

def game_pass(game: Game) -> Game:
  match game:
    case Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      passed = passes + 1
      match passed == 4:
        case 0:
          Game.Game{phase, dealer, u32_next_seat(turn), taker, trump, offered, passed, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, "Pass."}
        case all:
          match phase:
            case 0:
              Game.Game{1, dealer, u32_next_seat(dealer), taker, trump, offered, 0, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, "Everyone passed. Choose any other suit."}
            case second:
              game_deal((seed * 1664525) + 1013904223, u32_next_seat(dealer), score0, score1, hand + 1)

def game_bid_choice(game: Game, seat: U32, choice: U32) -> Game:
  match game:
    case Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      match choice:
        case 0: game_pass(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note})
        case selected:
          suit = selected - 1
          valid : U32 = match phase:
                                case 0: suit == offered
                                case second: (suit < 4) && ((suit == offered) == 0)
          match valid:
            case 0: Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, "That suit is not available in this bidding round."}
            case yes: game_accept(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, seat, suit)

def hand_best_suit_go(hand: U32, offered: U32, phase: U32, suit: U32, best: U32, value: U32) -> U32:
  match suit == 4:
    case 0:
      allowed = (phase == 0) || ((suit == offered) == 0)
      strength = hand_bid_value(hand, suit) * allowed
      match strength > value:
        case 0: hand_best_suit_go(hand, offered, phase, suit + 1, best, value)
        case stronger: hand_best_suit_go(hand, offered, phase, suit + 1, suit, strength)
    case done: best

def hand_best_suit(hand: U32, offered: U32, phase: U32) -> U32:
  hand_best_suit_go(hand, offered, phase, 0, offered, 0)

def game_bid_ai(game: Game) -> Game:
  match game:
    case Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      cards = hands_get(hands, turn)
      suit : U32 = match phase:
                           case 0: offered
                           case second: hand_best_suit(cards, offered, 1)
      strength = hand_bid_value(cards, suit)
      must_take = (phase == 1) && (passes == 3)
      threshold : U32 = match phase:
                                case 0: 30
                                case second: 27
      choice : U32 = match (strength >= threshold) || must_take:
                             case 0: 0
                             case take: suit + 1
      game_bid_choice(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, turn, choice)

# ---------------------------------------------------------------- Play

def game_finish(game: Game) -> Game:
  match game:
    case Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
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
      Game.Game{end_phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, total0, total1, hand, belote, result}

def game_play_seat(game: Game, seat: U32, card: U32) -> Game:
  match game:
    case Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      reduced = hands_remove(hands, seat, card)
      table = trick_add(trick, seat, card)
      match table:
        case Trick.Trick{count, seat0, card0, seat1, card1, seat2, card2, seat3, card3}:
          match count == 4:
            case 0:
              Game.Game{phase, dealer, u32_next_seat(seat), taker, trump, offered, passes, seed, reduced, table, tricks, points0, points1, score0, score1, hand, belote, "Card played."}
            case complete:
              match trick_winner(table, trump):
                case Winner.Winner{winning_seat, winning_card}:
                  last = tricks == 7
                  value = trick_points(table, trump) + (last * 10)
                  p0 = points0 + (value * ((winning_seat % 2) == 0))
                  p1 = points1 + (value * (winning_seat % 2))
                  next : Game = Game.Game{phase, dealer, winning_seat, taker, trump, offered, passes, seed, reduced, trick_empty(), tricks + 1, p0, p1, score0, score1, hand, belote, "Trick collected."}
                  match last:
                    case 0: next
                    case final: game_finish(next)

def game_play_ai(game: Game) -> Game:
  match game:
    case Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      card = hand_first_legal(hands_get(hands, turn), turn, trick, trump)
      match card == 32:
        case 0: game_play_seat(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, turn, card)
        case none: Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, "No legal AI card was found."}

def game_auto(game: Game, fuel: U32) -> Game:
  match fuel:
    case 0: game
    case more:
      match game:
        case Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
          match (phase <= 1) && (turn != 0):
            case 0:
              match (phase == 2) && (turn != 0):
                case 0: Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}
                case ai_turn: game_auto(game_play_ai(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}), more - 1)
            case ai_bid: game_auto(game_bid_ai(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}), more - 1)

def game_empty(seed: U32) -> Game:
  game_deal(seed, 3, 0, 0, 1)

def game_error(game: Game, note: String) -> Action:
  Action.Action{game, 0, note}

def game_ok(game: Game) -> Action:
  Action.Action{game, 1, ""}

def game_bid(game: Game, choice: U32) -> Action:
  match game:
    case Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      match (phase <= 1) && (turn == 0):
        case 0: game_error(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, "It is not your bidding turn.")
        case yes:
          next = game_bid_choice(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, 0, choice)
          game_ok(next)

def game_play(game: Game, card: U32) -> Action:
  match game:
    case Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      match (phase == 2) && (turn == 0):
        case 0: game_error(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, "Wait for your turn to play.")
        case yes:
          match (card < 32) && card_legal(hands_get(hands, 0), 0, card, trick, trump):
            case 0: game_error(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, "That card is not legal: follow suit, cut, and overtrump when required.")
            case legal:
              next = game_play_seat(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, 0, card)
              game_ok(next)

def game_step(game: Game) -> Action:
  match game:
    case Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      match (phase <= 1) && (turn != 0):
        case 0:
          match (phase == 2) && (turn != 0):
            case 0: game_error(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, "The table is waiting for your decision.")
            case play: game_ok(game_play_ai(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}))
        case bid: game_ok(game_bid_ai(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}))

def game_next(game: Game) -> Action:
  match game:
    case Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      match phase == 3:
        case 0: game_error(Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}, "Finish this hand first.")
        case ready: game_ok(game_deal((seed * 1664525) + 1013904223, u32_next_seat(dealer), score0, score1, hand + 1))

# Pure smoke probe used by the README verification command.
def test() -> U32:
  first = hands_first(123456789, 3)
  full = hands_complete(123456789, 3, 0, first)
  first_counts = ((hand_count(hands_get(first, 0)) == 5) && (hand_count(hands_get(first, 1)) == 5)) && ((hand_count(hands_get(first, 2)) == 5) && (hand_count(hands_get(first, 3)) == 5))
  full_counts = ((hand_count(hands_get(full, 0)) == 8) && (hand_count(hands_get(full, 1)) == 8)) && ((hand_count(hands_get(full, 2)) == 8) && (hand_count(hands_get(full, 3)) == 8))
  disjoint = (((hands_get(full, 0) .&. hands_get(full, 1)) == 0) && ((hands_get(full, 0) .&. hands_get(full, 2)) == 0)) && ((hands_get(full, 1) .&. hands_get(full, 3)) == 0)
  ranks = (card_points(19, 2) == 20) && ((card_points(18, 2) == 14) && (card_points(7, 2) == 11))
  first_counts && (full_counts && (disjoint && ranks))

# ---------------------------------------------------------------- JSON and HTTP

def game_json(game: Game, ok: U32, action_note: String) -> String:
  match game:
    case Game.Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      shown_note : String = match String.length(action_note):
                                      case 0: note
                                      case present: action_note
      String.flatten([
        "{\"ok\":", String.from_u32(ok), ",\"note\":", JSON.quoted(shown_note, ""),
        ",\"phase\":", String.from_u32(phase), ",\"dealer\":", String.from_u32(dealer),
        ",\"turn\":", String.from_u32(turn), ",\"taker\":", String.from_u32(taker),
        ",\"trump\":", String.from_u32(trump), ",\"offered\":", String.from_u32(offered),
        ",\"seed\":", String.from_u32(seed),
        ",\"turned\":", String.from_u32(u32_deal_card(seed, 20)),
        ",\"passes\":", String.from_u32(passes), ",\"handNumber\":", String.from_u32(hand),
        ",\"hand\":", hand_json(hands_get(hands, 0)),
        ",\"counts\":[", String.from_u32(hand_count(hands_get(hands, 0))), ",", String.from_u32(hand_count(hands_get(hands, 1))), ",", String.from_u32(hand_count(hands_get(hands, 2))), ",", String.from_u32(hand_count(hands_get(hands, 3))), "]",
        ",\"trick\":", trick_json(trick), ",\"tricks\":", String.from_u32(tricks),
        ",\"points\":[", String.from_u32(points0), ",", String.from_u32(points1), "]",
        ",\"scores\":[", String.from_u32(score0), ",", String.from_u32(score1), "]",
        ",\"beloteTeam\":", String.from_u32(belote), "}"
      ])

def game_response(game: Game, ok: U32, note: String) -> HTTP.Response:
  HTTP.Response.Response{200,
    [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"}, HTTP.Header.Header{"Cache-Control", "no-store"}],
    Bytes.from_string(game_json(game, ok, note))}

def action_routed(action: Action) -> Routed:
  match action:
    case Action.Action{game, ok, note}: Routed.Routed{game, game_response(game, ok, note)}

def game_routed(game: Game) -> Routed:
  Routed.Routed{game, game_response(game, 1, "")}

def result_index(result: Result((U32 & String), String), game: Game) -> IO(Routed):
  match result:
    case Result.Done{html}: IO.pure(Routed, Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}: IO.pure(Routed, Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "Belote page not found -- run from the repository root\n")})

def game_index(game: Game) -> IO(Routed):
  do IO(Routed):
    result <- IO.read_text("gabriel_demos/belote_web/index.html")
    result_index(result, game)

def list_action(name: String, args: List(String), game: Game) -> IO(Routed):
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
                        case 0: IO.pure(Routed, Routed.Routed{game, HTTP.not_found()})
                        case reset:
                          do IO(Routed):
                            seed <- IO.rand_word()
                            return game_routed(game_empty(seed))
                    case next: IO.pure(Routed, action_routed(game_next(game)))
                case auto: IO.pure(Routed, action_routed(game_step(game)))
            case play:
              match args:
                case List.Cons{card, rest}: IO.pure(Routed, action_routed(game_play(game, String.to_u32(card))))
                case List.Nil{}: IO.pure(Routed, Routed.Routed{game, HTTP.not_found()})
        case bid:
          match args:
            case List.Cons{choice, rest}: IO.pure(Routed, action_routed(game_bid(game, String.to_u32(choice))))
            case List.Nil{}: IO.pure(Routed, Routed.Routed{game, HTTP.not_found()})
    case state: IO.pure(Routed, game_routed(game))

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
        printed <- IO.write("Bend3 Belote listening on 0.0.0.0:8091\nopen http://<server-lan-ip>:8091\n")
        u32_serve(server, game_empty(seed))
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def main() -> IO(U32):
  do IO(U32):
    seed <- IO.rand_word()
    result <- TCP.listen(8091)
    result_main(result, seed)
