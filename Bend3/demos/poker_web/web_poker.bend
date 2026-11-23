# Four-seat Texas Hold'em / Omaha poker (Bend 2.0.40).
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
# Build and run from the repository root (index.html is read relative to it):
#   bend Bend3/demos/poker_web/web_poker.bend -o Bend3/demos/poker_web/build/web_poker
#   ./Bend3/demos/poker_web/build/web_poker
#
# Hub interface: `Game`, `init() -> IO(Game)`, `game_empty(seed)`,
# `route(req, game)` and `route_at(prefix, req, game)`. `route` answers standalone-shaped paths ("/",
# "/state/0/0", ...): a hub mounting Poker under "/poker" strips that prefix
# before calling it, or calls `route_at("/poker", ..)` (index.html detects the "/poker" mount by itself).

import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat

type Hands is Data:
  Hands{seat0: List<&2, U32>, seat1: List<&2, U32>, seat2: List<&2, U32>, seat3: List<&2, U32>}

type Four is Data:
  Four{seat0: U32, seat1: U32, seat2: U32, seat3: U32}

# phase: 0 preflop, 1 flop, 2 turn, 3 river, 4 hand over.
# states: 0 in the hand, 1 folded, 2 all-in. humans/acted/winner: seat bit masks.
type Game is Data:
  Game{variant: U32, phase: U32, dealer: U32, turn: U32, pot: U32, current: U32, min_raise: U32, seed: U32, hand_number: U32, hands: Hands, board: List<&2, U32>, stacks: Four, bets: Four, states: Four, acted: U32, personas: Four, humans: U32, tokens: Four, winner: U32, note: String}

type Action is Data:
  Action{game: Game, ok: U32, note: String}

type Paid is Data:
  Paid{stacks: Four, bets: Four, chips: U32}

type Claim is Data:
  Claim{game: Game, token: U32, ok: U32}

# ---------------------------------------------------------------- Small helpers

def u(b: Bool) -> U32:
  Bool.to_u32(b)

def bit(+seat: U32) -> U32:
  U32.shln(1, U32.to_nat(seat))

def has_bit(+mask: U32, +seat: U32) -> Bool:
  Bool.not(U32.is_zero((mask .&. bit(seat) : U32)))

def lcg(+seed: U32) -> U32:
  (seed * 1664525 + 1013904223 : U32)

# ---------------------------------------------------------------- List

def list_nth(list: List<&2, U32>, index: U32) -> U32:
  match list index:
    case Nil{} _: 0
    case Con{h, t} 0: h
    case Con{h, t} k: list_nth(t, (k - 1 : U32))

def list_show(list: List<&2, U32>) -> List<&2, String>:
  match list:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      U32.show(h) <> list_show(t)

def list_json(list: List<&2, U32>, wanted: U32) -> String:
  HTTP.json_array(list_show(List.take(&2, U32, list, U32.to_nat(wanted))))

# ---------------------------------------------------------------- Four

def four_get.go(s: U32, f: Four) -> U32:
  match s f:
    case 0 Four{a, b, c, d}: a
    case 1 Four{a, b, c, d}: b
    case 2 Four{a, b, c, d}: c
    case _ Four{a, b, c, d}: d

def four_get(+four: Four, +seat: U32) -> U32:
  four_get.go((seat % 4 : U32), four)

def four_set.go(s: U32, f: Four, x: U32) -> Four:
  match s f:
    case 0 Four{a, b, c, d}: Four{x, b, c, d}
    case 1 Four{a, b, c, d}: Four{a, x, c, d}
    case 2 Four{a, b, c, d}: Four{a, b, x, d}
    case _ Four{a, b, c, d}: Four{a, b, c, x}

def four_set(four: Four, +seat: U32, value: U32) -> Four:
  four_set.go((seat % 4 : U32), four, value)

def four_sum(four: Four) -> U32:
  Four{a, b, c, d} = four
  (a + b + c + d : U32)

def four_zero() -> Four:
  Four{0, 0, 0, 0}

# ---------------------------------------------------------------- Hands and deck

def hands_get.go(s: U32, h: Hands) -> List<&2, U32>:
  match s h:
    case 0 Hands{a, b, c, d}: a
    case 1 Hands{a, b, c, d}: b
    case 2 Hands{a, b, c, d}: c
    case _ Hands{a, b, c, d}: d

def hands_get(+hands: Hands, +seat: U32) -> List<&2, U32>:
  hands_get.go((seat % 4 : U32), hands)

def hands_set.go(s: U32, h: Hands, x: List<&2, U32>) -> Hands:
  match s h:
    case 0 Hands{a, b, c, d}: Hands{x, b, c, d}
    case 1 Hands{a, b, c, d}: Hands{a, x, c, d}
    case 2 Hands{a, b, c, d}: Hands{a, b, x, d}
    case _ Hands{a, b, c, d}: Hands{a, b, c, x}

def hands_set(hands: Hands, +seat: U32, cards: List<&2, U32>) -> Hands:
  hands_set.go((seat % 4 : U32), hands, cards)

def hands_add(+hands: Hands, +seat: U32, card: U32) -> Hands:
  hands_set(hands, seat, card <> hands_get(hands, seat))

# Multipliers coprime with 52, so each seed gives a permutation of the deck.
def multiplier_of(choice: U32) -> U32:
  match choice:
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
    case _: 51

def deck_card(+seed: U32, +index: U32) -> U32:
  ((index * multiplier_of((seed % 24 : U32)) + (seed / 24) % 52) % 52 : U32)

def hands_deal_round(fuel: Nat, +seed: U32, +round: U32, +seat: U32, +hands: Hands) -> Hands:
  match fuel:
    case 0n:
      hands
    case 1n+f:
      hands_deal_round(f, seed, round, (seat + 1 : U32), hands_add(hands, seat, deck_card(seed, (round * 4 + seat : U32))))

def hands_deal_go(fuel: Nat, +seed: U32, +round: U32, +hands: Hands) -> Hands:
  match fuel:
    case 0n:
      hands
    case 1n+f:
      hands_deal_go(f, seed, (round + 1 : U32), hands_deal_round(4n, seed, round, 0, hands))

# Two hole cards each (Texas) or four (Omaha), one per seat per round.
def hands_deal(+seed: U32, +variant: U32) -> Hands:
  hands_deal_go(U32.to_nat((2 + variant * 2 : U32)), seed, 0, Hands{Nil{}, Nil{}, Nil{}, Nil{}})

def list_board(+seed: U32, +variant: U32) -> List<&2, U32>:
  +offset = (8 + variant * 8 : U32)
  [deck_card(seed, offset), deck_card(seed, (offset + 1 : U32)), deck_card(seed, (offset + 2 : U32)), deck_card(seed, (offset + 3 : U32)), deck_card(seed, (offset + 4 : U32))]

# ---------------------------------------------------------------- Five-card evaluation

def list_rank_count(cards: List<&2, U32>, +rank: U32) -> U32:
  match cards:
    case Nil{}:
      0
    case Con{card, tail}:
      (u(U32.is_eq((card % 13 : U32), rank)) + list_rank_count(tail, rank) : U32)

def list_rank_mask(cards: List<&2, U32>) -> U32:
  match cards:
    case Nil{}:
      0
    case Con{card, tail}:
      (bit((card % 13 : U32)) .|. list_rank_mask(tail) : U32)

def list_flush(+cards: List<&2, U32>) -> Bool:
  +suit = (list_nth(cards, 0) / 13 : U32)
  U32.is_eq((list_nth(cards, 1) / 13 : U32), suit) && U32.is_eq((list_nth(cards, 2) / 13 : U32), suit) && U32.is_eq((list_nth(cards, 3) / 13 : U32), suit) && U32.is_eq((list_nth(cards, 4) / 13 : U32), suit)

def mask_at(+mask: U32, +rank: U32) -> U32:
  (U32.shrn(mask, U32.to_nat(rank)) .&. 1 : U32)

# The straight's top rank plus one (5 for the wheel A-2-3-4-5), 0 for none.
# count runs 13 down to 5 (the run of five ranks ending at count - 1).
def straight_go(fuel: Nat, +mask: U32, +count: U32) -> U32:
  match fuel:
    case 0n:
      (mask_at(mask, 12) * mask_at(mask, 0) * mask_at(mask, 1) * mask_at(mask, 2) * mask_at(mask, 3) * 4 : U32)
    case 1n+f:
      +high = (count - 1 : U32)
      +run = (mask_at(mask, high) * mask_at(mask, (high - 1 : U32)) * mask_at(mask, (high - 2 : U32)) * mask_at(mask, (high - 3 : U32)) * mask_at(mask, (high - 4 : U32)) : U32)
      Bool.pick(U32, U32.is_zero(run), straight_go(f, mask, (count - 1 : U32)), (high + 1 : U32))

def straight_high(+mask: U32) -> U32:
  straight_go(9n, mask, 13)

# The (skip)-th highest rank (plus one) appearing exactly `wanted` times.
def rank_with_count_go(fuel: Nat, +cards: List<&2, U32>, +wanted: U32, +skip: U32, +count: U32) -> U32:
  match fuel:
    case 0n:
      0
    case 1n+f:
      +rank = (count - 1 : U32)
      +found = U32.is_eq(list_rank_count(cards, rank), wanted)
      +rest = rank_with_count_go(f, cards, wanted, Bool.pick(U32, found, (skip - 1 : U32), skip), rank)
      Bool.pick(U32, found && U32.is_zero(skip), (rank + 1 : U32), rest)

def rank_with_count(+cards: List<&2, U32>, +wanted: U32, +skip: U32) -> U32:
  rank_with_count_go(13n, cards, wanted, skip, 13)

def pack(+a: U32, +b: U32, +c: U32, +d: U32, +e: U32) -> U32:
  ((((a * 14 + b) * 14 + c) * 14 + d) * 14 + e : U32)

# Category * 1000000 plus packed tie-breakers.
def list_five_score(+cards: List<&2, U32>) -> U32:
  +straight = straight_high(list_rank_mask(cards))
  +flush = list_flush(cards)
  +four = rank_with_count(cards, 4, 0)
  +three = rank_with_count(cards, 3, 0)
  +pair0 = rank_with_count(cards, 2, 0)
  +pair1 = rank_with_count(cards, 2, 1)
  +one0 = rank_with_count(cards, 1, 0)
  +one1 = rank_with_count(cards, 1, 1)
  +one2 = rank_with_count(cards, 1, 2)
  +one3 = rank_with_count(cards, 1, 3)
  +one4 = rank_with_count(cards, 1, 4)
  +has_straight = Bool.not(U32.is_zero(straight))
  Bool.pick(U32, has_straight && flush, (8000000 + pack(straight, 0, 0, 0, 0) : U32),
  Bool.pick(U32, Bool.not(U32.is_zero(four)), (7000000 + pack(four, one0, 0, 0, 0) : U32),
  Bool.pick(U32, Bool.not(U32.is_zero(three)) && Bool.not(U32.is_zero(pair0)), (6000000 + pack(three, pair0, 0, 0, 0) : U32),
  Bool.pick(U32, flush, (5000000 + pack(one0, one1, one2, one3, one4) : U32),
  Bool.pick(U32, has_straight, (4000000 + pack(straight, 0, 0, 0, 0) : U32),
  Bool.pick(U32, Bool.not(U32.is_zero(three)), (3000000 + pack(three, one0, one1, 0, 0) : U32),
  Bool.pick(U32, Bool.not(U32.is_zero(pair1)), (2000000 + pack(pair0, pair1, one0, 0, 0) : U32),
  Bool.pick(U32, Bool.not(U32.is_zero(pair0)), (1000000 + pack(pair0, one0, one1, one2, 0) : U32),
  pack(one0, one1, one2, one3, one4)))))))))

# The best five-card subset of `cards` (need = cards still to choose).
def list_choose_score(cards: List<&2, U32>, +need: Nat, +chosen: List<&2, U32>) -> U32:
  match cards need:
    case _ 0n:
      list_five_score(chosen)
    case Nil{} 1n+n:
      0
    case Con{+h, +t} 1n+n:
      U32.max(list_choose_score(t, n, h <> chosen), list_choose_score(t, 1n+n, chosen))

def list_texas_score(hole: List<&2, U32>, board: List<&2, U32>) -> U32:
  list_choose_score(List.append(&2, U32, hole, board), 5n, Nil{})

# Every two-card subset of a list, each as a list.
def pairs_with(+h: U32, t: List<&2, U32>) -> List<&2, List<&2, U32>>:
  match t:
    case Nil{}:
      Nil{}
    case Con{x, rest}:
      [h, x] <> pairs_with(h, rest)

def list_pairs(xs: List<&2, U32>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, +t}:
      List.append(&2, List<&2, U32>, pairs_with(h, t), list_pairs(t))

def prefix_all(+h: U32, xs: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{x, rest}:
      (h <> x) <> prefix_all(h, rest)

def list_triples(xs: List<&2, U32>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, +t}:
      List.append(&2, List<&2, U32>, prefix_all(h, list_pairs(t)), list_triples(t))

def best_with(+two: List<&2, U32>, threes: List<&2, List<&2, U32>>) -> U32:
  match threes:
    case Nil{}:
      0
    case Con{three, rest}:
      U32.max(list_five_score(List.append(&2, U32, two, three)), best_with(two, rest))

def best_over(twos: List<&2, List<&2, U32>>, +threes: List<&2, List<&2, U32>>) -> U32:
  match twos:
    case Nil{}:
      0
    case Con{two, rest}:
      U32.max(best_with(two, threes), best_over(rest, threes))

# Omaha: exactly two hole cards and exactly three board cards.
def list_omaha_score(hole: List<&2, U32>, board: List<&2, U32>) -> U32:
  best_over(list_pairs(hole), list_triples(board))

def seat_score(variant: U32, hole: List<&2, U32>, board: List<&2, U32>) -> U32:
  match variant:
    case 0: list_texas_score(hole, board)
    case _: list_omaha_score(hole, board)

def game_seat_score(+game: Game, +seat: U32) -> U32:
  Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, +hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note} = game
  seat_score(variant, hands_get(hands, seat), board)

# ---------------------------------------------------------------- Personas and AI

def persona_name(p: U32) -> String:
  match p:
    case 0: "Ada All-In"
    case 1: "Bluffalo Bill"
    case 2: "Callie Station"
    case 3: "Doctor Draw"
    case 4: "Mina Maxbet"
    case 5: "Nash Sparrow"
    case 6: "Oma Holmes"
    case 7: "River Rook"
    case 8: "Texas Tern"
    case _: "Vera Variance"

def persona_style(p: U32) -> String:
  match p:
    case 0: "fearless"
    case 1: "tricky"
    case 2: "calling-station"
    case 3: "draw-chaser"
    case 4: "aggressive"
    case 5: "balanced"
    case 6: "analytical"
    case 7: "patient"
    case 8: "tight"
    case _: "unpredictable"

def persona_aggression(p: U32) -> U32:
  match p:
    case 0: 92
    case 1: 72
    case 2: 25
    case 3: 48
    case 4: 84
    case 5: 58
    case 6: 52
    case 7: 35
    case 8: 30
    case _: 64

def hole_power(+hole: List<&2, U32>) -> U32:
  +a = (list_nth(hole, 0) % 13 : U32)
  +b = (list_nth(hole, 1) % 13 : U32)
  +pair = (u(U32.is_eq(a, b)) * 45 : U32)
  +suited = (u(U32.is_eq((list_nth(hole, 0) / 13 : U32), (list_nth(hole, 1) / 13 : U32))) * 10 : U32)
  (pair + suited + a + b + 8 : U32)

# ---------------------------------------------------------------- Betting state

def state_is(+states: Four, +seat: U32, +value: U32) -> Bool:
  U32.is_eq(four_get(states, seat), value)

# Seats that have not folded.
def not_folded_count(+states: Four) -> U32:
  (u(Bool.not(state_is(states, 0, 1))) + u(Bool.not(state_is(states, 1, 1))) + u(Bool.not(state_is(states, 2, 1))) + u(Bool.not(state_is(states, 3, 1))) : U32)

def live_mask(+states: Four) -> U32:
  (u(Bool.not(state_is(states, 0, 1))) + u(Bool.not(state_is(states, 1, 1))) * 2 + u(Bool.not(state_is(states, 2, 1))) * 4 + u(Bool.not(state_is(states, 3, 1))) * 8 : U32)

# Seats that can still act (neither folded nor all-in).
def acting_mask(+states: Four) -> U32:
  (u(state_is(states, 0, 0)) + u(state_is(states, 1, 0)) * 2 + u(state_is(states, 2, 0)) * 4 + u(state_is(states, 3, 0)) * 8 : U32)

def bet_settled(+bets: Four, +states: Four, +current: U32, +seat: U32) -> Bool:
  Bool.not(state_is(states, seat, 0)) || U32.is_eq(four_get(bets, seat), current)

def bets_equal(+bets: Four, +states: Four, +current: U32) -> Bool:
  bet_settled(bets, states, current, 0) && bet_settled(bets, states, current, 1) && bet_settled(bets, states, current, 2) && bet_settled(bets, states, current, 3)

# The next seat after `seat` whose state is (or, with want False, is not)
# `value`, scanning at most `fuel` seats.
def next_seat_where(fuel: Nat, +states: Four, +seat: U32, +value: U32, +want: Bool) -> U32:
  match fuel:
    case 0n:
      ((seat + 1) % 4 : U32)
    case 1n+f:
      +next = ((seat + 1) % 4 : U32)
      Bool.pick(U32, Bool.xor(state_is(states, next, value), Bool.not(want)), next, next_seat_where(f, states, next, value, want))

def next_live(+states: Four, +seat: U32) -> U32:
  next_seat_where(4n, states, seat, 0, True{})

def next_not_folded(+states: Four, +seat: U32) -> U32:
  next_seat_where(4n, states, seat, 1, False{})

def four_pay(+stacks: Four, +bets: Four, +seat: U32, +wanted: U32) -> Paid:
  +stack = four_get(stacks, seat)
  +paid = U32.min(stack, wanted)
  Paid{four_set(stacks, seat, (stack - paid : U32)), four_set(bets, seat, (four_get(bets, seat) + paid : U32)), paid}

def win_if(+score: U32, +best: U32, +live: U32, +seat: U32) -> U32:
  u(U32.is_eq(score, best) && has_bit(live, seat))

def game_showdown(+game: Game) -> Game:
  Game{variant, phase, dealer, turn, +pot, current, min_raise, seed, hand_number, hands, board, +stacks, bets, +states, acted, personas, humans, tokens, winner, note} = game
  +live = live_mask(states)
  +s0 = (game_seat_score(game, 0) * u(has_bit(live, 0)) : U32)
  +s1 = (game_seat_score(game, 1) * u(has_bit(live, 1)) : U32)
  +s2 = (game_seat_score(game, 2) * u(has_bit(live, 2)) : U32)
  +s3 = (game_seat_score(game, 3) * u(has_bit(live, 3)) : U32)
  +best = U32.max(U32.max(s0, s1), U32.max(s2, s3))
  +w0 = win_if(s0, best, live, 0)
  +w1 = win_if(s1, best, live, 1)
  +w2 = win_if(s2, best, live, 2)
  +w3 = win_if(s3, best, live, 3)
  +share = (pot / U32.max((w0 + w1 + w2 + w3 : U32), 1) : U32)
  +paid : Four = Four{(four_get(stacks, 0) + share * w0 : U32), (four_get(stacks, 1) + share * w1 : U32), (four_get(stacks, 2) + share * w2 : U32), (four_get(stacks, 3) + share * w3 : U32)}
  Game{variant, 4, dealer, turn, 0, current, min_raise, seed, hand_number, hands, board, paid, bets, states, acted, personas, humans, tokens, (w0 + w1 * 2 + w2 * 4 + w3 * 8 : U32), "Showdown complete. The best five-card hand wins the pot."}

def game_fold_win(+game: Game) -> Game:
  Game{variant, phase, dealer, turn, +pot, current, min_raise, seed, hand_number, hands, board, +stacks, bets, +states, acted, personas, humans, tokens, winner, note} = game
  +seat = next_not_folded(states, turn)
  Game{variant, 4, dealer, seat, 0, current, min_raise, seed, hand_number, hands, board, four_set(stacks, seat, (four_get(stacks, seat) + pot : U32)), bets, states, acted, personas, humans, tokens, bit(seat), "Everyone else folded. The last player wins the pot."}

def street_label(phase: U32) -> String:
  match phase:
    case 0: "The flop is dealt."
    case 1: "The turn is dealt."
    case _: "The river is dealt."

# After the river, or when nobody can act any more (everyone left is all-in),
# go to showdown; otherwise deal the next street.
def game_advance_street.go(showdown: Bool, +game: Game) -> Game:
  match showdown game:
    case True{} g:
      game_showdown(g)
    case False{} Game{variant, +phase, +dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, +states, acted, personas, humans, tokens, winner, note}:
      Game{variant, (phase + 1 : U32), dealer, next_live(states, dealer), pot, 0, 20, seed, hand_number, hands, board, stacks, four_zero(), states, 0, personas, humans, tokens, 0, street_label(phase)}

def game_advance_street(+game: Game) -> Game:
  Game{variant, +phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, +states, acted, personas, humans, tokens, winner, note} = game
  game_advance_street.go(U32.is_eq(phase, 3) || (U32.from_nat(U32.popcount(acting_mask(states))) < 2 : U32), game)

def game_after_action.go(one_left: Bool, complete: Bool, +game: Game) -> Game:
  match one_left complete game:
    case True{} _ g:
      game_fold_win(g)
    case False{} True{} g:
      game_advance_street(g)
    case False{} False{} Game{variant, phase, dealer, +turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, +states, acted, personas, humans, tokens, winner, note}:
      Game{variant, phase, dealer, next_live(states, turn), pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}

# A betting round is complete once every seat that can still act has acted
# and matched the current bet.
def game_after_action(+game: Game) -> Game:
  Game{variant, phase, dealer, turn, pot, +current, min_raise, seed, hand_number, hands, board, stacks, +bets, +states, +acted, personas, humans, tokens, winner, note} = game
  +acting = acting_mask(states)
  +complete = U32.is_eq((acted .&. acting : U32), acting) && bets_equal(bets, states, current)
  game_after_action.go(U32.is_eq(not_folded_count(states), 1), complete, game)

def action_fail(game: Game, note: String) -> Action:
  Action{game, 0, note}

def action_next(game: Game) -> Action:
  Action{game_after_action(game), 1, ""}

def act_fold(+game: Game, +seat: U32) -> Action:
  Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note} = game
  action_next(Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, four_set(states, seat, 1), (acted .|. bit(seat) : U32), personas, humans, tokens, winner, "Fold."})

def act_check(facing: Bool, +game: Game, +seat: U32) -> Action:
  match facing game:
    case True{} g:
      action_fail(g, "Check is unavailable while facing a bet.")
    case False{} Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      action_next(Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, (acted .|. bit(seat) : U32), personas, humans, tokens, winner, "Check."})

# Pays `wanted` (capped by the stack); all-in when the stack is emptied.
# raise_to = 0 keeps the current bet (a call), otherwise it is the new bet.
def act_pay(paid: Paid, +game: Game, +seat: U32, +stack: U32, +raise_to: U32, label: String) -> Action:
  Paid{next_stacks, next_bets, +chips} = paid
  Game{variant, phase, dealer, turn, +pot, +current, +min_raise, seed, hand_number, hands, board, stacks, bets, +states, +acted, personas, humans, tokens, winner, note} = game
  +raised = Bool.not(U32.is_zero(raise_to))
  +next_states = Bool.pick(Four, U32.is_eq(chips, stack), four_set(states, seat, 2), states)
  +next_current = Bool.pick(U32, raised, raise_to, current)
  +next_min = Bool.pick(U32, raised, (raise_to - current : U32), min_raise)
  +next_acted = Bool.pick(U32, raised, bit(seat), (acted .|. bit(seat) : U32))
  action_next(Game{variant, phase, dealer, turn, (pot + chips : U32), next_current, next_min, seed, hand_number, hands, board, next_stacks, next_bets, next_states, next_acted, personas, humans, tokens, winner, label})

def act_call(short: Bool, +game: Game, +seat: U32, +stack: U32, +call: U32, +stacks: Four, +bets: Four) -> Action:
  match short:
    case True{}:
      act_pay(four_pay(stacks, bets, seat, stack), game, seat, stack, 0, "All-in call.")
    case False{}:
      act_pay(four_pay(stacks, bets, seat, call), game, seat, stack, 0, "Call.")

def act_raise(legal: Bool, +game: Game, +seat: U32, +stack: U32, +own_bet: U32, +amount: U32, +stacks: Four, +bets: Four) -> Action:
  match legal:
    case True{}:
      act_pay(four_pay(stacks, bets, seat, (amount - own_bet : U32)), game, seat, stack, amount, "Raise.")
    case False{}:
      action_fail(game, "Raise-to amount is outside the legal slider range.")

def act_dispatch(kind: U32, +game: Game, +seat: U32, +amount: U32, +own_bet: U32, +stack: U32, +call: U32, +min_total: U32, +stacks: Four, +bets: Four) -> Action:
  match kind:
    case 0: act_fold(game, seat)
    case 1: act_check(Bool.not(U32.is_zero(call)), game, seat)
    case 2: act_call((call > stack : U32), game, seat, stack, call, stacks, bets)
    case _: act_raise((amount >= min_total : U32) && (amount <= own_bet + stack : U32), game, seat, stack, own_bet, amount, stacks, bets)

# kind: 0 fold, 1 check, 2 call, 3 (or more) raise to `amount`.
def act_kind(+kind: U32, +game: Game, +seat: U32, +amount: U32) -> Action:
  Game{variant, phase, dealer, turn, pot, +current, +min_raise, seed, hand_number, hands, board, +stacks, +bets, states, acted, personas, humans, tokens, winner, note} = game
  +own_bet = four_get(bets, seat)
  +stack = four_get(stacks, seat)
  act_dispatch(kind, game, seat, amount, own_bet, stack, (current - own_bet : U32), (current + min_raise : U32), stacks, bets)

def game_action_seat.go(valid: Bool, +game: Game, +seat: U32, +kind: U32, +amount: U32) -> Action:
  match valid:
    case True{}:
      act_kind(kind, game, seat, amount)
    case False{}:
      action_fail(game, "It is not that seat's turn.")

def game_action_seat(+game: Game, +seat: U32, +kind: U32, +amount: U32) -> Action:
  Game{variant, +phase, dealer, +turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, +states, acted, personas, humans, tokens, winner, note} = game
  game_action_seat.go((phase < 4 : U32) && U32.is_eq(turn, seat) && state_is(states, seat, 0), game, seat, kind, amount)

def game_ai_action(+game: Game) -> Action:
  Game{variant, +phase, dealer, +turn, pot, +current, +min_raise, +seed, +hand_number, +hands, board, +stacks, +bets, states, +acted, +personas, humans, tokens, winner, note} = game
  +stack = four_get(stacks, turn)
  +call = (current - four_get(bets, turn) : U32)
  +aggression = persona_aggression(four_get(personas, turn))
  +strength = (hole_power(hands_get(hands, turn)) + phase * 10 : U32)
  +whim = ((seed + hand_number * 17 + turn * 31 + acted * 7) % 100 : U32)
  +can_raise = (stack > call + min_raise : U32)
  +open_kind = Bool.pick(U32, can_raise && (whim < aggression / 3 : U32), 3, 1)
  +weak = (strength + aggression / 2 < 25 + call / 3 : U32)
  +facing_kind = Bool.pick(U32, weak, 0, Bool.pick(U32, can_raise && (whim < aggression / 5 : U32), 3, 2))
  +kind = Bool.pick(U32, U32.is_zero(call), open_kind, facing_kind)
  +amount = (current + min_raise + ((aggression + whim) % 4) * 10 : U32)
  game_action_seat(game, turn, kind, U32.min(amount, (four_get(bets, turn) + stack : U32)))

def game_auto.acted(a: Action, +game: Game, rest: Game -> Game) -> Game:
  Action{next, ok, note} = a
  match ok:
    case 0: game
    case _: rest(next)

def game_auto.step(ai: Bool, +game: Game, rest: Game -> Game) -> Game:
  match ai:
    case True{}:
      game_auto.acted(game_ai_action(game), game, rest)
    case False{}:
      game

def game_is_ai_turn(+game: Game) -> Bool:
  Game{variant, phase, dealer, +turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, +humans, tokens, winner, note} = game
  (phase < 4 : U32) && Bool.not(has_bit(humans, turn))

# Plays every Bend AI turn until a browser seat must act (at most fuel turns).
def game_auto(fuel: Nat, +game: Game) -> Game:
  match fuel:
    case 0n:
      game
    case 1n+f:
      game_auto.step(game_is_ai_turn(game), game, g => game_auto(f, g))

# ---------------------------------------------------------------- New hands, authentication, actions

def game_personas(+seed: U32) -> Four:
  +first = (seed % 10 : U32)
  Four{first, ((first + 3) % 10 : U32), ((first + 6) % 10 : U32), ((first + 9) % 10 : U32)}

def game_deal.big(paid: Paid, +seed: U32, +variant: U32, +dealer: U32, hand_number: U32, humans: U32, tokens: Four, +small: U32) -> Game:
  Paid{stacks, bets, +chips} = paid
  +raw : Game = Game{variant, 0, dealer, ((dealer + 3) % 4 : U32), (small + chips : U32), 20, 20, seed, hand_number, hands_deal(seed, variant), list_board(seed, variant), stacks, bets, four_zero(), 0, game_personas(seed), humans, tokens, 0, "Blinds posted. Action begins before the flop."}
  game_auto(96n, raw)

def game_deal.small(paid: Paid, +seed: U32, +variant: U32, +dealer: U32, hand_number: U32, humans: U32, tokens: Four) -> Game:
  Paid{stacks, bets, +chips} = paid
  game_deal.big(four_pay(stacks, bets, ((dealer + 2) % 4 : U32), 20), seed, variant, dealer, hand_number, humans, tokens, chips)

def game_deal(+seed: U32, +variant: U32, +dealer: U32, hand_number: U32, stacks: Four, humans: U32, tokens: Four) -> Game:
  game_deal.small(four_pay(stacks, four_zero(), ((dealer + 1) % 4 : U32), 10), seed, variant, dealer, hand_number, humans, tokens)

def game_empty(+seed: U32) -> Game:
  game_deal(seed, 0, 3, 1, Four{1000, 1000, 1000, 1000}, 1, four_zero())

# Seat 0 is the first browser (token 0); invited seats need their token.
def game_authorized(+game: Game, +seat: U32, +token: U32) -> Bool:
  Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, +humans, +tokens, winner, note} = game
  Bool.pick(Bool, U32.is_zero(seat), U32.is_zero(token), has_bit(humans, seat) && U32.is_eq(four_get(tokens, seat), token))

def game_new.go(ok: Bool, +game: Game, +variant: U32) -> Action:
  match ok game:
    case False{} g:
      action_fail(g, "That seat token is not authorized.")
    case True{} Game{old_variant, +phase, +dealer, turn, pot, current, min_raise, +seed, +hand_number, hands, board, +stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      +reset = Bool.pick(Four, (four_sum(stacks) < 80 : U32) || (phase < 4 : U32), Four{1000, 1000, 1000, 1000}, stacks)
      Action{game_deal(lcg((seed + hand_number : U32)), (variant % 2 : U32), ((dealer + 1) % 4 : U32), (hand_number + 1 : U32), reset, humans, tokens), 1, ""}

def game_new(+game: Game, +seat: U32, +token: U32, +variant: U32) -> Action:
  game_new.go(game_authorized(game, seat, token), game, variant)

def game_claim.go(open: Bool, +game: Game, +seat: U32) -> Claim:
  match open game:
    case False{} g:
      Claim{g, 0, 0}
    case True{} Game{variant, phase, dealer, turn, pot, current, min_raise, +seed, +hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note}:
      +token = lcg((seed + seat * 2654435761 + hand_number : U32))
      Claim{Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, (humans .|. bit(seat) : U32), four_set(tokens, seat, token), winner, "A browser player joined the table."}, token, 1}

def game_humans(g: Game) -> U32:
  Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, board, stacks, bets, states, acted, personas, humans, tokens, winner, note} = g
  humans

def game_claim(+game: Game, +seat: U32) -> Claim:
  game_claim.go((seat > 0 : U32) && (seat < 4 : U32) && Bool.not(has_bit(game_humans(game), seat)), game, seat)

def game_action.done(a: Action) -> Action:
  Action{next, ok, note} = a
  match ok:
    case 0: Action{next, ok, note}
    case _: Action{game_auto(96n, next), 1, ""}

def game_action.go(authorized: Bool, human: Bool, +game: Game, +seat: U32, +kind: U32, +amount: U32) -> Action:
  match authorized human:
    case False{} _:
      action_fail(game, "That seat token is not authorized.")
    case True{} False{}:
      action_fail(game, "That seat is controlled by Bend AI.")
    case True{} True{}:
      game_action.done(game_action_seat(game, seat, kind, amount))

def game_action(+game: Game, +seat: U32, +token: U32, +kind: U32, +amount: U32) -> Action:
  game_action.go(game_authorized(game, seat, token), has_bit(game_humans(game), seat), game, seat, kind, amount)

# Pure regression probe (probe.bend prints it): must be 1.
def test.go(game: Game) -> U32:
  Game{variant, phase, dealer, turn, pot, current, min_raise, seed, hand_number, +hands, +board, stacks, bets, states, acted, +personas, humans, tokens, winner, note} = game
  +deal_ok = U32.is_eq(U32.from_nat(List.length(&2, U32, hands_get(hands, 0))), 2) && U32.is_eq(U32.from_nat(List.length(&2, U32, hands_get(hands, 1))), 2) && U32.is_eq(U32.from_nat(List.length(&2, U32, board)), 5)
  +unique = Bool.not(U32.is_eq(list_nth(hands_get(hands, 0), 0), list_nth(hands_get(hands, 1), 0))) && Bool.not(U32.is_eq(list_nth(board, 0), list_nth(board, 1)))
  +personas_ok = Bool.not(U32.is_eq(four_get(personas, 0), four_get(personas, 1))) && Bool.not(U32.is_eq(four_get(personas, 1), four_get(personas, 2)))
  +royal = U32.is_eq((list_five_score([8, 9, 10, 11, 12]) / 1000000 : U32), 8)
  +pair = U32.is_eq((list_five_score([0, 13, 2, 4, 6]) / 1000000 : U32), 1)
  +wheel = U32.is_eq(list_five_score([12, 13, 27, 41, 3]), (4000000 + pack(4, 0, 0, 0, 0) : U32))
  +omaha = U32.is_eq((list_omaha_score([0, 1, 28, 30], [13, 15, 17, 19, 21]) / 1000000 : U32), 2)
  +texas = U32.is_eq((list_texas_score([0, 1], [13, 15, 17, 19, 21]) / 1000000 : U32), 5)
  u(deal_ok && unique && personas_ok && royal && pair && wheel && omaha && texas)

def test() -> U32:
  test.go(game_empty(123456789))

# ---------------------------------------------------------------- JSON

def phase_cards(phase: U32) -> U32:
  match phase:
    case 0: 0
    case 1: 3
    case 2: 4
    case _: 5

# Private cards: a seat's holes are sent only to that seat's authenticated
# viewer, or to everyone once the hand is over.
def game_hole_json(+hands: Hands, +seat: U32, +viewer: U32, +authorized: Bool, +showdown: Bool) -> String:
  Bool.pick(String, showdown || (authorized && U32.is_eq(seat, viewer)), list_json(hands_get(hands, seat), 4), "[]")

def game_seat_json(+game: Game, +seat: U32, +viewer: U32, +authorized: Bool) -> String:
  Game{variant, +phase, +dealer, turn, pot, current, min_raise, seed, hand_number, +hands, board, +stacks, +bets, +states, acted, +personas, +humans, tokens, +winner, note} = game
  +persona = four_get(personas, seat)
  "{\"seat\":" ++ U32.show(seat) ++ ",\"name\":" ++ HTTP.quoted(persona_name(persona))
    ++ ",\"style\":" ++ HTTP.quoted(persona_style(persona)) ++ ",\"aggression\":" ++ U32.show(persona_aggression(persona))
    ++ ",\"human\":" ++ U32.show(u(has_bit(humans, seat))) ++ ",\"stack\":" ++ U32.show(four_get(stacks, seat))
    ++ ",\"bet\":" ++ U32.show(four_get(bets, seat)) ++ ",\"state\":" ++ U32.show(four_get(states, seat))
    ++ ",\"dealer\":" ++ U32.show(u(U32.is_eq(seat, dealer))) ++ ",\"winner\":" ++ U32.show(u(has_bit(winner, seat)))
    ++ ",\"cards\":" ++ game_hole_json(hands, seat, viewer, authorized, U32.is_eq(phase, 4)) ++ "}"

def game_json(+game: Game, +ok: U32, +action_note: String, +viewer: U32, +token: U32) -> String:
  Game{variant, +phase, dealer, turn, pot, current, min_raise, seed, hand_number, hands, +board, +stacks, +bets, states, acted, personas, humans, tokens, winner, +note} = game
  +authorized = game_authorized(game, viewer, token)
  +shown = Bool.pick(String, String.is_empty(action_note), note, action_note)
  "{\"ok\":" ++ U32.show(ok) ++ ",\"authorized\":" ++ U32.show(u(authorized)) ++ ",\"note\":" ++ HTTP.quoted(shown)
    ++ ",\"variant\":" ++ U32.show(variant) ++ ",\"phase\":" ++ U32.show(phase) ++ ",\"dealer\":" ++ U32.show(dealer)
    ++ ",\"turn\":" ++ U32.show(turn) ++ ",\"pot\":" ++ U32.show(pot) ++ ",\"currentBet\":" ++ U32.show(current)
    ++ ",\"minRaise\":" ++ U32.show(min_raise) ++ ",\"maxRaise\":" ++ U32.show((four_get(bets, viewer) + four_get(stacks, viewer) : U32)) ++ ",\"handNumber\":" ++ U32.show(hand_number)
    ++ ",\"viewer\":" ++ U32.show(viewer) ++ ",\"seatToken\":" ++ U32.show(token) ++ ",\"board\":" ++ list_json(board, phase_cards(phase))
    ++ ",\"players\":[" ++ game_seat_json(game, 0, viewer, authorized)
    ++ "," ++ game_seat_json(game, 1, viewer, authorized)
    ++ "," ++ game_seat_json(game, 2, viewer, authorized)
    ++ "," ++ game_seat_json(game, 3, viewer, authorized) ++ "]}"

# ---------------------------------------------------------------- HTTP routes

def done(game: Game, r: HTTP.Response) -> IO(Game & HTTP.Response):
  IO.pure(Game & HTTP.Response, (game, r))

def respond(a: Action, +viewer: U32, +token: U32) -> IO(Game & HTTP.Response):
  Action{+game, ok, note} = a
  done(game, HTTP.json(game_json(game, ok, note, viewer, token)))

def respond_claim(c: Claim, +seat: U32) -> IO(Game & HTTP.Response):
  Claim{+game, +token, ok} = c
  done(game, HTTP.json(game_json(game, ok, "", seat, token)))

def game_index(game: Game) -> IO(Game & HTTP.Response):
  do IO<Game & HTTP.Response>:
    r : HTTP.Response <- HTTP.file("Bend3/demos/poker_web/index.html")
    return (game, r)

def num(s: String) -> U32:
  Compat.to_u32(s)

# 1 state, 2 claim, 3 action, 4 new, 0 unknown.
def route_code(+name: String) -> U32:
  Bool.pick(U32, String.eq(name, "state"), 1,
  Bool.pick(U32, String.eq(name, "claim"), 2,
  Bool.pick(U32, String.eq(name, "action"), 3,
  Bool.pick(U32, String.eq(name, "new"), 4, 0))))

def route_name(code: U32, args: List<&2, String>, +game: Game) -> IO(Game & HTTP.Response):
  match code args:
    case 1 Con{+seat, Con{+token, rest}}:
      respond(Action{game, 1, ""}, num(seat), num(token))
    case 1 _:
      respond(Action{game, 1, ""}, 0, 0)
    case 2 Con{+seat, rest}:
      respond_claim(game_claim(game, num(seat)), num(seat))
    case 3 Con{+seat, Con{+token, Con{kind, Con{amount, rest}}}}:
      respond(game_action(game, num(seat), num(token), num(kind), num(amount)), num(seat), num(token))
    case 4 Con{+seat, Con{+token, Con{variant, rest}}}:
      respond(game_new(game, num(seat), num(token), num(variant)), num(seat), num(token))
    case _ _:
      done(game, HTTP.not_found())

def route.go(get: Bool, segs: List<&2, String>, +game: Game) -> IO(Game & HTTP.Response):
  match get segs:
    case False{} _:
      done(game, HTTP.method_not_allowed())
    case True{} Nil{}:
      game_index(game)
    case True{} +name <> args:
      route_name(route_code(name), args, game)

# The whole Poker surface for one request (standalone-shaped path).
def route(req: HTTP.Request, game: Game) -> IO(Game & HTTP.Response):
  HTTP.Request{+method, +target, headers, body} = req
  route.go(String.eq(method, "GET"), HTTP.segments(target), game)

# The same surface mounted under `prefix` (e.g. "/poker" in a hub): the prefix
# is stripped from the target, so "/poker/state" is answered as "/state" and
# "/poker" as the page. Targets without the prefix are routed unchanged.
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
    IO.print("Bend Poker listening on 0.0.0.0:8092\nopen http://<server-lan-ip>:8092")
    HTTP.serve(~Game, ~route, "0.0.0.0", 8092, game)
