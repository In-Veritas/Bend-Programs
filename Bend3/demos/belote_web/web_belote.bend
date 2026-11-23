# Belote: a solo table with three Bend-controlled opponents (Bend 2.0.40).
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
# GET /auto         advance exactly one Bend-controlled seat
# GET /next         deal the next hand
# GET /new          reset the match with a fresh IO random seed
#
# Build and run from the repository root (index.html is read relative to it):
#   bend Bend3/demos/belote_web/web_belote.bend -o Bend3/demos/belote_web/build/web_belote
#   ./Bend3/demos/belote_web/build/web_belote
#
# Hub interface: `Game`, `init() -> IO(Game)`, `game_empty(seed)`,
# `route(req, game)` and `route_at(prefix, req, game)`. `route` answers standalone-shaped paths ("/", "/state",
# "/bid/1", ...): a hub mounting Belote under "/belote" strips that prefix
# before calling it, or calls `route_at("/belote", ..)` (index.html detects the "/belote" prefix by itself).

import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat

type Hands is Data:
  Hands{south: U32, east: U32, north: U32, west: U32}

type Trick is Data:
  Trick{count: U32, seat0: U32, card0: U32, seat1: U32, card1: U32, seat2: U32, card2: U32, seat3: U32, card3: U32}

type Winner is Data:
  Winner{seat: U32, card: U32}

# phase: 0 first bidding round, 1 second round, 2 card play, 3 hand over,
# 4 match over. belote: 0 none, 1 team 0 (south/north), 2 team 1.
type Game is Data:
  Game{phase: U32, dealer: U32, turn: U32, taker: U32, trump: U32, offered: U32, passes: U32, seed: U32, hands: Hands, trick: Trick, tricks: U32, points0: U32, points1: U32, score0: U32, score1: U32, hand: U32, belote: U32, note: String}

type Action is Data:
  Action{game: Game, ok: U32, note: String}

# ---------------------------------------------------------------- Small helpers

def u(b: Bool) -> U32:
  Bool.to_u32(b)

def put_if(c: Bool, h: String, rest: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      h <> rest
    case False{}:
      rest

def lcg(+seed: U32) -> U32:
  (seed * 1664525 + 1013904223 : U32)

# ---------------------------------------------------------------- Card

def card_suit(+card: U32) -> U32:
  (card / 8 : U32)

def card_rank(+card: U32) -> U32:
  (card % 8 : U32)

def card_bit(card: U32) -> U32:
  U32.shln(1, U32.to_nat(card))

def rank_trump_order(rank: U32) -> U32:
  match rank:
    case 0: 0
    case 1: 1
    case 2: 6
    case 3: 7
    case 4: 2
    case 5: 3
    case 6: 4
    case _: 5

def card_trump_order(+card: U32) -> U32:
  rank_trump_order(card_rank(card))

def rank_points_plain(rank: U32) -> U32:
  match rank:
    case 0: 0
    case 1: 0
    case 2: 0
    case 3: 2
    case 4: 3
    case 5: 4
    case 6: 10
    case _: 11

def rank_points_trump(rank: U32) -> U32:
  match rank:
    case 0: 0
    case 1: 0
    case 2: 14
    case 3: 20
    case 4: 3
    case 5: 4
    case 6: 10
    case _: 11

def rank_points(atout: Bool, rank: U32) -> U32:
  match atout:
    case True{}:
      rank_points_trump(rank)
    case False{}:
      rank_points_plain(rank)

def card_points(+card: U32, +trump: U32) -> U32:
  rank_points(U32.is_eq(card_suit(card), trump), card_rank(card))

def power_pick(atout: Bool, asked: Bool, +card: U32) -> U32:
  match atout asked:
    case True{} _:
      (64 + card_trump_order(card) : U32)
    case False{} True{}:
      (32 + card_rank(card) : U32)
    case False{} False{}:
      card_rank(card)

def card_power(+card: U32, +lead: U32, +trump: U32) -> U32:
  power_pick(U32.is_eq(card_suit(card), trump), U32.is_eq(card_suit(card), lead), card)

def card_beats(+card: U32, +held: U32, +lead: U32, +trump: U32) -> Bool:
  (card_power(card, lead, trump) > card_power(held, lead, trump) : U32)

# ---------------------------------------------------------------- Hand (a 32-bit card set)

def hand_has(+hand: U32, +card: U32) -> Bool:
  Bool.not(U32.is_zero((hand .&. card_bit(card) : U32)))

def hand_add(+hand: U32, +card: U32) -> U32:
  (hand .|. card_bit(card) : U32)

def hand_remove(+hand: U32, +card: U32) -> U32:
  (hand .&. U32.not(card_bit(card)) : U32)

def hand_has_suit(+hand: U32, +suit: U32) -> Bool:
  Bool.not(U32.is_zero((hand .&. U32.shln(255, U32.to_nat((suit * 8 : U32))) : U32)))

def hand_count(hand: U32) -> U32:
  U32.from_nat(U32.popcount(hand))

# Does the hand hold a trump ranked above `top` (a trump order plus one)?
def hand_has_higher_go(fuel: Nat, +hand: U32, +trump: U32, +top: U32, +rank: U32) -> Bool:
  match fuel:
    case 0n:
      False{}
    case 1n+f:
      +card = (trump * 8 + rank : U32)
      +here = hand_has(hand, card) && (card_trump_order(card) + 1 > top : U32)
      here || hand_has_higher_go(f, hand, trump, top, (rank + 1 : U32))

def hand_has_higher(+hand: U32, +trump: U32, +top: U32) -> Bool:
  hand_has_higher_go(8n, hand, trump, top, 0)

def hand_bid_value_go(fuel: Nat, +hand: U32, +suit: U32, +card: U32) -> U32:
  match fuel:
    case 0n:
      0
    case 1n+f:
      +value = (card_points(card, suit) + u(U32.is_eq(card_suit(card), suit)) * 4 : U32)
      (u(hand_has(hand, card)) * value + hand_bid_value_go(f, hand, suit, (card + 1 : U32)) : U32)

def hand_bid_value(+hand: U32, +suit: U32) -> U32:
  hand_bid_value_go(32n, hand, suit, 0)

def hand_cards_go(fuel: Nat, +hand: U32, +card: U32) -> List<&2, String>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+f:
      put_if(hand_has(hand, card), U32.show(card), hand_cards_go(f, hand, (card + 1 : U32)))

def hand_json(+hand: U32) -> String:
  HTTP.json_array(hand_cards_go(32n, hand, 0))

# ---------------------------------------------------------------- Hands

def hands_empty() -> Hands:
  Hands{0, 0, 0, 0}

def hands_get.go(s: U32, h: Hands) -> U32:
  match s h:
    case 0 Hands{a, b, c, d}: a
    case 1 Hands{a, b, c, d}: b
    case 2 Hands{a, b, c, d}: c
    case _ Hands{a, b, c, d}: d

def hands_get(+hands: Hands, +seat: U32) -> U32:
  hands_get.go((seat % 4 : U32), hands)

def hands_set.go(s: U32, h: Hands, x: U32) -> Hands:
  match s h:
    case 0 Hands{a, b, c, d}: Hands{x, b, c, d}
    case 1 Hands{a, b, c, d}: Hands{a, x, c, d}
    case 2 Hands{a, b, c, d}: Hands{a, b, x, d}
    case _ Hands{a, b, c, d}: Hands{a, b, c, x}

def hands_set(hands: Hands, +seat: U32, hand: U32) -> Hands:
  hands_set.go((seat % 4 : U32), hands, hand)

def hands_add(+hands: Hands, +seat: U32, +card: U32) -> Hands:
  hands_set(hands, seat, hand_add(hands_get(hands, seat), card))

def hands_remove(+hands: Hands, +seat: U32, +card: U32) -> Hands:
  hands_set(hands, seat, hand_remove(hands_get(hands, seat), card))

# ---------------------------------------------------------------- Deal

def next_seat(+seat: U32) -> U32:
  ((seat + 1) % 4 : U32)

# An odd affine permutation of the 32 card indices: no duplicates.
def deal_card(+seed: U32, +index: U32) -> U32:
  +mult = ((seed % 16) * 2 + 1 : U32)
  +off = ((seed / 16) % 32 : U32)
  ((index * mult + off) % 32 : U32)

def hands_first_go(fuel: Nat, +seed: U32, +lead: U32, +index: U32, +hands: Hands) -> Hands:
  match fuel:
    case 0n:
      hands
    case 1n+f:
      +seat = ((lead + index % 4) % 4 : U32)
      hands_first_go(f, seed, lead, (index + 1 : U32), hands_add(hands, seat, deal_card(seed, index)))

# Five cards each (deck indices 0..19), dealt from the seat after the dealer.
def hands_first(+seed: U32, +dealer: U32) -> Hands:
  hands_first_go(20n, seed, next_seat(dealer), 0, hands_empty())

# The wanted-th seat (0-based) in order lead, lead+1, ... that is not the taker.
def skip_taker(+lead: U32, +taker: U32, +wanted: U32) -> U32:
  +pos = ((taker + 4 - lead) % 4 : U32)
  +idx = Bool.pick(U32, (wanted < pos : U32), wanted, (wanted + 1 : U32))
  ((lead + idx) % 4 : U32)

# Deck indices 21..31: two more rounds to everyone, then one card to each of
# the three non-takers (the taker already received the turned card, index 20).
def hands_rest_go(fuel: Nat, +seed: U32, +lead: U32, +taker: U32, +index: U32, +hands: Hands) -> Hands:
  match fuel:
    case 0n:
      hands
    case 1n+f:
      +seat = Bool.pick(U32, (index < 8 : U32), ((lead + index % 4) % 4 : U32), skip_taker(lead, taker, (index - 8 : U32)))
      hands_rest_go(f, seed, lead, taker, (index + 1 : U32), hands_add(hands, seat, deal_card(seed, (21 + index : U32))))

def hands_complete(+seed: U32, +dealer: U32, +taker: U32, +hands: Hands) -> Hands:
  hands_rest_go(11n, seed, next_seat(dealer), taker, 0, hands_add(hands, taker, deal_card(seed, 20)))

# ---------------------------------------------------------------- Trick

def trick_empty() -> Trick:
  Trick{0, 0, 0, 0, 0, 0, 0, 0, 0}

def trick_count(t: Trick) -> U32:
  Trick{count, s0, c0, s1, c1, s2, c2, s3, c3} = t
  count

def trick_lead(t: Trick) -> U32:
  Trick{count, s0, c0, s1, c1, s2, c2, s3, c3} = t
  card_suit(c0)

def trick_add.go(n: U32, t: Trick, s: U32, c: U32) -> Trick:
  match n t:
    case 0 Trick{count, s0, c0, s1, c1, s2, c2, s3, c3}: Trick{1, s, c, 0, 0, 0, 0, 0, 0}
    case 1 Trick{count, s0, c0, s1, c1, s2, c2, s3, c3}: Trick{2, s0, c0, s, c, 0, 0, 0, 0}
    case 2 Trick{count, s0, c0, s1, c1, s2, c2, s3, c3}: Trick{3, s0, c0, s1, c1, s, c, 0, 0}
    case _ Trick{count, s0, c0, s1, c1, s2, c2, s3, c3}: Trick{4, s0, c0, s1, c1, s2, c2, s, c}

def trick_add(+trick: Trick, seat: U32, card: U32) -> Trick:
  trick_add.go(trick_count(trick), trick, seat, card)

def winner_seat(w: Winner) -> U32:
  Winner{s, c} = w
  s

def winner_pick(beats: Bool, w: Winner, seat: U32, card: U32) -> Winner:
  match beats:
    case True{}:
      Winner{seat, card}
    case False{}:
      w

def winner_choose(+w: Winner, +seat: U32, +card: U32, +lead: U32, +trump: U32) -> Winner:
  Winner{held_seat, +held_card} = w
  winner_pick(card_beats(card, held_card, lead, trump), w, seat, card)

def winner_maybe(present: Bool, +w: Winner, +seat: U32, +card: U32, +lead: U32, +trump: U32) -> Winner:
  match present:
    case True{}:
      winner_choose(w, seat, card, lead, trump)
    case False{}:
      w

def trick_winner(+trick: Trick, +trump: U32) -> Winner:
  Trick{+count, s0, +c0, s1, c1, s2, c2, s3, c3} = trick
  +lead = card_suit(c0)
  +w1 = winner_maybe((count > 1 : U32), Winner{s0, c0}, s1, c1, lead, trump)
  +w2 = winner_maybe((count > 2 : U32), w1, s2, c2, lead, trump)
  winner_maybe((count > 3 : U32), w2, s3, c3, lead, trump)

def top_step(present: Bool, +top: U32, +card: U32, +trump: U32) -> U32:
  Bool.pick(U32, present && U32.is_eq(card_suit(card), trump), U32.max(top, (card_trump_order(card) + 1 : U32)), top)

# The highest trump order (plus one) on the table, 0 without trumps.
def trick_top_trump(+trick: Trick, +trump: U32) -> U32:
  Trick{+count, s0, c0, s1, c1, s2, c2, s3, c3} = trick
  +t0 = top_step((count > 0 : U32), 0, c0, trump)
  +t1 = top_step((count > 1 : U32), t0, c1, trump)
  +t2 = top_step((count > 2 : U32), t1, c2, trump)
  top_step((count > 3 : U32), t2, c3, trump)

def points_if(present: Bool, +card: U32, +trump: U32) -> U32:
  (u(present) * card_points(card, trump) : U32)

def trick_points(+trick: Trick, +trump: U32) -> U32:
  Trick{+count, s0, c0, s1, c1, s2, c2, s3, c3} = trick
  (points_if((count > 0 : U32), c0, trump) + points_if((count > 1 : U32), c1, trump) + points_if((count > 2 : U32), c2, trump) + points_if((count > 3 : U32), c3, trump) : U32)

def played_json(seat: U32, card: U32) -> String:
  "{\"seat\":" ++ U32.show(seat) ++ ",\"card\":" ++ U32.show(card) ++ "}"

def trick_json(+trick: Trick) -> String:
  Trick{+count, s0, c0, s1, c1, s2, c2, s3, c3} = trick
  HTTP.json_array(
    put_if((count > 0 : U32), played_json(s0, c0),
    put_if((count > 1 : U32), played_json(s1, c1),
    put_if((count > 2 : U32), played_json(s2, c2),
    put_if((count > 3 : U32), played_json(s3, c3), Nil{})))))

# ---------------------------------------------------------------- Legality

def card_overtrump_ok(+hand: U32, +card: U32, +trick: Trick, +trump: U32) -> Bool:
  +top = trick_top_trump(trick, trump)
  Bool.not(hand_has_higher(hand, trump, top)) || (card_trump_order(card) + 1 > top : U32)

# The same rule gates the human and the AI: own the card; lead anything;
# follow the led suit (rising in trumps when trumps are led); when void,
# cut (and overtrump) unless the partner is master; else discard freely.
def card_legal(+hand: U32, +seat: U32, +card: U32, +trick: Trick, +trump: U32) -> Bool:
  +lead = trick_lead(trick)
  +ot = card_overtrump_ok(hand, card, trick, trump)
  +follow = U32.is_eq(card_suit(card), lead) && (Bool.not(U32.is_eq(lead, trump)) || ot)
  +partner = U32.is_eq(winner_seat(trick_winner(trick, trump)), ((seat + 2) % 4 : U32))
  +cut = partner || Bool.not(hand_has_suit(hand, trump)) || (U32.is_eq(card_suit(card), trump) && ot)
  hand_has(hand, card) && (U32.is_zero(trick_count(trick)) || Bool.pick(Bool, hand_has_suit(hand, lead), follow, cut))

def hand_first_legal_go(fuel: Nat, +hand: U32, +seat: U32, +trick: Trick, +trump: U32, +card: U32) -> U32:
  match fuel:
    case 0n:
      32
    case 1n+f:
      Bool.pick(U32, card_legal(hand, seat, card, trick, trump), card, hand_first_legal_go(f, hand, seat, trick, trump, (card + 1 : U32)))

# The first legal card, or 32 when there is none.
def hand_first_legal(+hand: U32, +seat: U32, +trick: Trick, +trump: U32) -> U32:
  hand_first_legal_go(32n, hand, seat, trick, trump, 0)

# ---------------------------------------------------------------- Bidding and scoring

def hand_pair(+hand: U32, +queen: U32, +king: U32) -> Bool:
  hand_has(hand, queen) && hand_has(hand, king)

# Which team holds the trump king and queen together: 0 none, 1, or 2.
def hands_belote(+hands: Hands, +trump: U32) -> U32:
  +queen = (trump * 8 + 4 : U32)
  +king = (trump * 8 + 5 : U32)
  +team0 = hand_pair(hands_get(hands, 0), queen, king) || hand_pair(hands_get(hands, 2), queen, king)
  +team1 = hand_pair(hands_get(hands, 1), queen, king) || hand_pair(hands_get(hands, 3), queen, king)
  Bool.pick(U32, team0, 1, (u(team1) * 2 : U32))

def game_deal(+seed: U32, +dealer: U32, score0: U32, score1: U32, hand: U32) -> Game:
  Game{0, dealer, next_seat(dealer), 4, 4, card_suit(deal_card(seed, 20)), 0, seed, hands_first(seed, dealer), trick_empty(), 0, 0, 0, score0, score1, hand, 0, "Five cards each. The turned suit is offered first."}

def game_accept(+game: Game, +seat: U32, +trump: U32) -> Game:
  Game{phase, +dealer, turn, taker, old_trump, offered, passes, +seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note} = game
  +full = hands_complete(seed, dealer, seat, hands)
  +bonus = hands_belote(full, trump)
  +message = Bool.pick(String, U32.is_zero(bonus), "Trump accepted. The remaining cards are dealt.", "Trump accepted. Belote/Rebelote is present for a 20-point bonus.")
  Game{2, dealer, next_seat(dealer), seat, trump, offered, 0, seed, full, trick_empty(), 0, 0, 0, score0, score1, hand, bonus, message}

def game_pass.go(more: Bool, first: Bool, +game: Game) -> Game:
  match more first game:
    case True{} _ Game{phase, dealer, +turn, taker, trump, offered, +passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      Game{phase, dealer, next_seat(turn), taker, trump, offered, (passes + 1 : U32), seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, "Pass."}
    case False{} True{} Game{phase, +dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      Game{1, dealer, next_seat(dealer), taker, trump, offered, 0, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, "Everyone passed. Choose any other suit."}
    case False{} False{} Game{phase, +dealer, turn, taker, trump, offered, passes, +seed, hands, trick, tricks, points0, points1, score0, score1, +hand, belote, note}:
      game_deal(lcg(seed), next_seat(dealer), score0, score1, (hand + 1 : U32))

def game_phase(g: Game) -> U32:
  Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note} = g
  phase

def game_turn(g: Game) -> U32:
  Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note} = g
  turn

def game_passes(g: Game) -> U32:
  Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note} = g
  passes

def game_offered(g: Game) -> U32:
  Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note} = g
  offered

def with_note(g: Game, msg: String) -> Game:
  Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note} = g
  Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, msg}

def game_pass(+game: Game) -> Game:
  game_pass.go(Bool.not(U32.is_eq((game_passes(game) + 1 : U32), 4)), U32.is_zero(game_phase(game)), game)

def game_bid_valid(+phase: U32, +offered: U32, +suit: U32) -> Bool:
  Bool.pick(Bool, U32.is_zero(phase), U32.is_eq(suit, offered), (suit < 4 : U32) && Bool.not(U32.is_eq(suit, offered)))

def game_bid_suit(valid: Bool, +game: Game, +seat: U32, +suit: U32) -> Game:
  match valid:
    case True{}:
      game_accept(game, seat, suit)
    case False{}:
      with_note(game, "That suit is not available in this bidding round.")

# choice 0 passes; 1..4 takes suit choice-1.
def game_bid_choice(choice: U32, +game: Game, +seat: U32) -> Game:
  match choice:
    case 0:
      game_pass(game)
    case selected:
      +suit = (selected - 1 : U32)
      game_bid_suit(game_bid_valid(game_phase(game), game_offered(game), suit), game, seat, suit)

def hand_best_suit_go(fuel: Nat, +hand: U32, +offered: U32, +phase: U32, +suit: U32, +best: U32, +value: U32) -> U32:
  match fuel:
    case 0n:
      best
    case 1n+f:
      +allowed = U32.is_zero(phase) || Bool.not(U32.is_eq(suit, offered))
      +strength = (hand_bid_value(hand, suit) * u(allowed) : U32)
      +better = (strength > value : U32)
      hand_best_suit_go(f, hand, offered, phase, (suit + 1 : U32), Bool.pick(U32, better, suit, best), Bool.pick(U32, better, strength, value))

# The strongest allowed suit. The fallback is a suit that is always allowed
# in round two, so a forced AI take can never pick the forbidden turned suit.
def hand_best_suit(+hand: U32, +offered: U32, +phase: U32) -> U32:
  hand_best_suit_go(4n, hand, offered, phase, 0, Bool.pick(U32, U32.is_zero(phase), offered, next_seat(offered)), 0)

def game_bid_ai(+game: Game) -> Game:
  Game{+phase, dealer, +turn, taker, trump, +offered, +passes, seed, +hands, trick, tricks, points0, points1, score0, score1, hand, belote, note} = game
  +cards = hands_get(hands, turn)
  +first = U32.is_zero(phase)
  +suit = Bool.pick(U32, first, offered, hand_best_suit(cards, offered, 1))
  +strength = hand_bid_value(cards, suit)
  +must_take = U32.is_eq(phase, 1) && U32.is_eq(passes, 3)
  +threshold = Bool.pick(U32, first, 30, 27)
  +choice = Bool.pick(U32, (strength >= threshold : U32) || must_take, (suit + 1 : U32), 0)
  game_bid_choice(choice, game, turn)

# ---------------------------------------------------------------- Play

def game_finish(+game: Game) -> Game:
  Game{phase, dealer, turn, +taker, trump, offered, passes, seed, hands, trick, tricks, +points0, +points1, score0, score1, hand, +belote, note} = game
  +team1 = U32.is_eq((taker % 2 : U32), 1)
  +made = Bool.pick(Bool, team1, (points1 > points0 : U32), (points0 > points1 : U32))
  +bonus0 = (u(U32.is_eq(belote, 1)) * 20 : U32)
  +bonus1 = (u(U32.is_eq(belote, 2)) * 20 : U32)
  +award0 = Bool.pick(U32, made, (points0 + bonus0 : U32), Bool.pick(U32, team1, (162 + bonus0 : U32), bonus0))
  +award1 = Bool.pick(U32, made, (points1 + bonus1 : U32), Bool.pick(U32, team1, bonus1, (162 + bonus1 : U32)))
  +total0 = (score0 + award0 : U32)
  +total1 = (score1 + award1 : U32)
  +end_phase = Bool.pick(U32, (total0 >= 501 : U32) || (total1 >= 501 : U32), 4, 3)
  +result = Bool.pick(String, made, "Contract made: both teams bank their card points.", "Contract failed: the defenders score the 162 card points.")
  Game{end_phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, total0, total1, hand, belote, result}

def game_trick_done(last: Bool, +game: Game) -> Game:
  match last:
    case True{}:
      game_finish(game)
    case False{}:
      game

def game_collect(+game: Game, +table: Trick) -> Game:
  Game{phase, dealer, turn, taker, +trump, offered, passes, seed, hands, trick, +tricks, points0, points1, score0, score1, hand, belote, note} = game
  +winning = winner_seat(trick_winner(table, trump))
  +last = U32.is_eq(tricks, 7)
  +value = (trick_points(table, trump) + u(last) * 10 : U32)
  +p0 = (points0 + value * u(U32.is_zero((winning % 2 : U32))) : U32)
  +p1 = (points1 + value * (winning % 2) : U32)
  game_trick_done(last, Game{phase, dealer, winning, taker, trump, offered, passes, seed, hands, trick_empty(), (tricks + 1 : U32), p0, p1, score0, score1, hand, belote, "Trick collected."})

def game_play_table(complete: Bool, +game: Game, +table: Trick) -> Game:
  match complete game:
    case False{} Game{phase, dealer, turn, taker, trump, offered, passes, seed, hands, trick, tricks, points0, points1, score0, score1, hand, belote, note}:
      Game{phase, dealer, next_seat(turn), taker, trump, offered, passes, seed, hands, table, tricks, points0, points1, score0, score1, hand, belote, "Card played."}
    case True{} g:
      game_collect(g, table)

def game_play_seat(+game: Game, +seat: U32, +card: U32) -> Game:
  Game{phase, dealer, turn, taker, trump, offered, passes, seed, +hands, +trick, tricks, points0, points1, score0, score1, hand, belote, note} = game
  +table = trick_add(trick, seat, card)
  +moved : Game = Game{phase, dealer, seat, taker, trump, offered, passes, seed, hands_remove(hands, seat, card), trick, tricks, points0, points1, score0, score1, hand, belote, note}
  game_play_table(U32.is_eq(trick_count(table), 4), moved, table)

def game_play_found(none: Bool, +game: Game, +seat: U32, +card: U32) -> Game:
  match none:
    case True{}:
      with_note(game, "No legal AI card was found.")
    case False{}:
      game_play_seat(game, seat, card)

def game_play_ai(+game: Game) -> Game:
  Game{phase, dealer, +turn, taker, +trump, offered, passes, seed, +hands, +trick, tricks, points0, points1, score0, score1, hand, belote, note} = game
  +card = hand_first_legal(hands_get(hands, turn), turn, trick, trump)
  game_play_found(U32.is_eq(card, 32), game, turn, card)

def game_empty(+seed: U32) -> Game:
  game_deal(seed, 3, 0, 0, 1)

def game_error(game: Game, note: String) -> Action:
  Action{game, 0, note}

def game_ok(game: Game) -> Action:
  Action{game, 1, ""}

def game_bid.go(mine: Bool, +game: Game, +choice: U32) -> Action:
  match mine:
    case True{}:
      game_ok(game_bid_choice(choice, game, 0))
    case False{}:
      game_error(game, "It is not your bidding turn.")

def game_bid(+game: Game, +choice: U32) -> Action:
  game_bid.go((game_phase(game) <= 1 : U32) && U32.is_zero(game_turn(game)), game, choice)

def game_play.go(mine: Bool, legal: Bool, +game: Game, +card: U32) -> Action:
  match mine legal:
    case False{} _:
      game_error(game, "Wait for your turn to play.")
    case True{} False{}:
      game_error(game, "That card is not legal: follow suit, cut, and overtrump when required.")
    case True{} True{}:
      game_ok(game_play_seat(game, 0, card))

def game_play(+game: Game, +card: U32) -> Action:
  Game{+phase, dealer, +turn, taker, +trump, offered, passes, seed, +hands, +trick, tricks, points0, points1, score0, score1, hand, belote, note} = game
  +mine = U32.is_eq(phase, 2) && U32.is_zero(turn)
  game_play.go(mine, (card < 32 : U32) && card_legal(hands_get(hands, 0), 0, card, trick, trump), game, card)

def game_step.go(bid: Bool, play: Bool, +game: Game) -> Action:
  match bid play:
    case True{} _:
      game_ok(game_bid_ai(game))
    case False{} True{}:
      game_ok(game_play_ai(game))
    case False{} False{}:
      game_error(game, "The table is waiting for your decision.")

# One Bend-controlled seat bids or plays.
def game_step(+game: Game) -> Action:
  +phase = game_phase(game)
  +ai = Bool.not(U32.is_zero(game_turn(game)))
  game_step.go((phase <= 1 : U32) && ai, U32.is_eq(phase, 2) && ai, game)

def game_next.go(ready: Bool, +game: Game) -> Action:
  match ready game:
    case False{} g:
      game_error(g, "Finish this hand first.")
    case True{} Game{phase, +dealer, turn, taker, trump, offered, passes, +seed, hands, trick, tricks, points0, points1, score0, score1, +hand, belote, note}:
      game_ok(game_deal(lcg(seed), next_seat(dealer), score0, score1, (hand + 1 : U32)))

def game_next(+game: Game) -> Action:
  game_next.go(U32.is_eq(game_phase(game), 3), game)

# Pure smoke probe (probe.bend prints it): must be 1.
def test() -> U32:
  +first = hands_first(123456789, 3)
  +full = hands_complete(123456789, 3, 0, first)
  +c5 = U32.is_eq(hand_count(hands_get(first, 0)), 5) && U32.is_eq(hand_count(hands_get(first, 1)), 5) && U32.is_eq(hand_count(hands_get(first, 2)), 5) && U32.is_eq(hand_count(hands_get(first, 3)), 5)
  +c8 = U32.is_eq(hand_count(hands_get(full, 0)), 8) && U32.is_eq(hand_count(hands_get(full, 1)), 8) && U32.is_eq(hand_count(hands_get(full, 2)), 8) && U32.is_eq(hand_count(hands_get(full, 3)), 8)
  +all = U32.is_eq((hands_get(full, 0) .|. hands_get(full, 1) .|. hands_get(full, 2) .|. hands_get(full, 3) : U32), 4294967295)
  +ranks = U32.is_eq(card_points(19, 2), 20) && U32.is_eq(card_points(18, 2), 14) && U32.is_eq(card_points(7, 2), 11)
  u(c5 && c8 && all && ranks)

# ---------------------------------------------------------------- JSON and HTTP

def game_json(+game: Game, +ok: U32, +action_note: String) -> String:
  Game{phase, dealer, turn, taker, trump, offered, passes, +seed, +hands, trick, tricks, points0, points1, score0, score1, hand, belote, note} = game
  +shown = Bool.pick(String, String.is_empty(action_note), note, action_note)
  "{\"ok\":" ++ U32.show(ok) ++ ",\"note\":" ++ HTTP.quoted(shown)
    ++ ",\"phase\":" ++ U32.show(phase) ++ ",\"dealer\":" ++ U32.show(dealer)
    ++ ",\"turn\":" ++ U32.show(turn) ++ ",\"taker\":" ++ U32.show(taker)
    ++ ",\"trump\":" ++ U32.show(trump) ++ ",\"offered\":" ++ U32.show(offered)
    ++ ",\"seed\":" ++ U32.show(seed)
    ++ ",\"turned\":" ++ U32.show(deal_card(seed, 20))
    ++ ",\"passes\":" ++ U32.show(passes) ++ ",\"handNumber\":" ++ U32.show(hand)
    ++ ",\"hand\":" ++ hand_json(hands_get(hands, 0))
    ++ ",\"counts\":[" ++ U32.show(hand_count(hands_get(hands, 0))) ++ "," ++ U32.show(hand_count(hands_get(hands, 1))) ++ "," ++ U32.show(hand_count(hands_get(hands, 2))) ++ "," ++ U32.show(hand_count(hands_get(hands, 3))) ++ "]"
    ++ ",\"trick\":" ++ trick_json(trick) ++ ",\"tricks\":" ++ U32.show(tricks)
    ++ ",\"points\":[" ++ U32.show(points0) ++ "," ++ U32.show(points1) ++ "]"
    ++ ",\"scores\":[" ++ U32.show(score0) ++ "," ++ U32.show(score1) ++ "]"
    ++ ",\"beloteTeam\":" ++ U32.show(belote) ++ "}"

def done(game: Game, r: HTTP.Response) -> IO(Game & HTTP.Response):
  IO.pure(Game & HTTP.Response, (game, r))

def respond(a: Action) -> IO(Game & HTTP.Response):
  Action{+game, ok, note} = a
  done(game, HTTP.json(game_json(game, ok, note)))

def game_index(game: Game) -> IO(Game & HTTP.Response):
  do IO<Game & HTTP.Response>:
    r : HTTP.Response <- HTTP.file("Bend3/demos/belote_web/index.html")
    return (game, r)

def game_new() -> IO(Game & HTTP.Response):
  do IO<Game & HTTP.Response>:
    seed : U32 <- IO.try(U32, IO.random_u32())
    respond(game_ok(game_empty(seed)))

# 1 state, 2 bid, 3 play, 4 auto, 5 next, 6 new, 0 unknown.
def route_code(+name: String) -> U32:
  Bool.pick(U32, String.eq(name, "state"), 1,
  Bool.pick(U32, String.eq(name, "bid"), 2,
  Bool.pick(U32, String.eq(name, "play"), 3,
  Bool.pick(U32, String.eq(name, "auto"), 4,
  Bool.pick(U32, String.eq(name, "next"), 5,
  Bool.pick(U32, String.eq(name, "new"), 6, 0))))))

def route_arg(code: U32, arg: String, +game: Game) -> IO(Game & HTTP.Response):
  match code:
    case 2:
      respond(game_bid(game, Compat.to_u32(arg)))
    case 3:
      respond(game_play(game, Compat.to_u32(arg)))
    case _:
      done(game, HTTP.not_found())

def route_name(code: U32, args: List<&2, String>, +game: Game) -> IO(Game & HTTP.Response):
  match code args:
    case 1 _:
      respond(game_ok(game))
    case 4 _:
      respond(game_step(game))
    case 5 _:
      respond(game_next(game))
    case 6 _:
      game_new()
    case c Nil{}:
      done(game, HTTP.not_found())
    case c a <> rest:
      route_arg(c, a, game)

def route.go(get: Bool, segs: List<&2, String>, +game: Game) -> IO(Game & HTTP.Response):
  match get segs:
    case False{} _:
      done(game, HTTP.method_not_allowed())
    case True{} Nil{}:
      game_index(game)
    case True{} +name <> args:
      route_name(route_code(name), args, game)

# The whole Belote surface for one request (standalone-shaped path).
def route(req: HTTP.Request, game: Game) -> IO(Game & HTTP.Response):
  HTTP.Request{+method, +target, headers, body} = req
  route.go(String.eq(method, "GET"), HTTP.segments(target), game)

# The same surface mounted under `prefix` (e.g. "/belote" in a hub): the prefix
# is stripped from the target, so "/belote/state" is answered as "/state" and
# "/belote" as the page. Targets without the prefix are routed unchanged.
def route_at(+prefix: String, req: HTTP.Request, game: Game) -> IO(Game & HTTP.Response):
  HTTP.Request{method, +target, headers, body} = req
  +inner = Bool.pick(String, String.starts_with(target, prefix), String.drop(target, String.length(prefix)), target)
  route(HTTP.Request{method, inner, headers, body}, game)

# ---------------------------------------------------------------- Server

def init() -> IO(Game):
  do IO<Game>:
    seed : U32 <- IO.try(U32, IO.random_u32())
    return game_empty(seed)

def main() -> IO(Unit):
  do IO<Unit>:
    game : Game <- init()
    IO.print("Bend Belote listening on 0.0.0.0:8091\nopen http://<server-lan-ip>:8091")
    HTTP.serve(~Game, ~route, "0.0.0.0", 8091, game)
