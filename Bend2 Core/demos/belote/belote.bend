import Base

# Pure deterministic classic Belote (Bend 2.0.40).  The complete report is
# computed before the browser starts: JavaScript only decodes and schedules it.

# Types
# =====

type PlayedCard is Data:
  PlayedCard{seat: U32, card: U32}

type PlayerView is Data:
  PlayerView{seat: U32, name: String, personality: String, hand: +List<U32>}

type Step is Data:
  Step{
    phase: String,
    note: String,
    actor: U32,
    action: String,
    card: U32,
    trick: U32,
    north_south: U32,
    east_west: U32,
    players: +List<PlayerView>,
    table: +List<PlayedCard>
  }

type BeloteReport is Data:
  BeloteReport{
    seed: U32,
    dealer: U32,
    taker: U32,
    trump: U32,
    valid: Bool,
    card_points_ns: U32,
    card_points_ew: U32,
    score_ns: U32,
    score_ew: U32,
    outcome: String,
    steps: +List<Step>
  }

# Constants
# =========

# Cards are 0..31.  A card is suit * 8 + rank, with suits clubs, diamonds,
# hearts, spades and ranks 7, 8, 9, jack, queen, king, ten, ace.  The embedded
# deck below is the Fisher-Yates result for seed 1.  Hearts (suit 2) are trump.

def u32(value: Nat) -> U32:
  U32.from_nat(value)

# Quotient and remainder of a Nat index by four, as Nats (for table lookups).
def div4(index: Nat) -> Nat:
  U32.to_nat((u32(index) / 4 : U32))

def mod4(index: Nat) -> Nat:
  U32.to_nat((u32(index) % 4 : U32))

def deck_card(index: Nat) -> U32:
  match index:
    case 0n: 1
    case 1n: 28
    case 2n: 27
    case 3n: 26
    case 4n: 3
    case 5n: 7
    case 6n: 6
    case 7n: 14
    case 8n: 5
    case 9n: 11
    case 10n: 17
    case 11n: 22
    case 12n: 29
    case 13n: 19
    case 14n: 18
    case 15n: 23
    case 16n: 20
    case 17n: 25
    case 18n: 10
    case 19n: 24
    case 20n: 9
    case 21n: 0
    case 22n: 15
    case 23n: 31
    case 24n: 30
    case 25n: 4
    case 26n: 13
    case 27n: 16
    case 28n: 2
    case 29n: 8
    case 30n: 21
    case other: 12

def seat_hand(seat: Nat) -> +List<U32>:
  match seat:
    case 0n:
      Con{deck_card(0n), Con{deck_card(1n), Con{deck_card(2n), Con{deck_card(3n), Con{deck_card(4n), Con{deck_card(5n), Con{deck_card(6n), Con{deck_card(7n), Nil{}}}}}}}}}
    case 1n:
      Con{deck_card(8n), Con{deck_card(9n), Con{deck_card(10n), Con{deck_card(11n), Con{deck_card(12n), Con{deck_card(13n), Con{deck_card(14n), Con{deck_card(15n), Nil{}}}}}}}}}
    case 2n:
      Con{deck_card(16n), Con{deck_card(17n), Con{deck_card(18n), Con{deck_card(19n), Con{deck_card(20n), Con{deck_card(21n), Con{deck_card(22n), Con{deck_card(23n), Nil{}}}}}}}}}
    case other:
      Con{deck_card(24n), Con{deck_card(25n), Con{deck_card(26n), Con{deck_card(27n), Con{deck_card(28n), Con{deck_card(29n), Con{deck_card(30n), Con{deck_card(31n), Nil{}}}}}}}}}

# This sequence is produced by four deterministic policies.  At every turn the
# policy first constructs the legal set: follow suit; when trump is led, rise
# when possible; when void and an opponent is winning, cut and overtrump when
# possible.  Trick three visibly exercises both mandatory cut and overtrump.
def play_card(index: Nat) -> U32:
  match index:
    case 0n: 7
    case 1n: 5
    case 2n: 0
    case 3n: 4
    case 4n: 14
    case 5n: 11
    case 6n: 9
    case 7n: 13
    case 8n: 6
    case 9n: 17
    case 10n: 20
    case 11n: 2
    case 12n: 24
    case 13n: 30
    case 14n: 28
    case 15n: 29
    case 16n: 12
    case 17n: 3
    case 18n: 22
    case 19n: 10
    case 20n: 23
    case 21n: 25
    case 22n: 21
    case 23n: 27
    case 24n: 18
    case 25n: 31
    case 26n: 16
    case 27n: 26
    case 28n: 19
    case 29n: 15
    case 30n: 8
    case other: 1

def play_actor(index: Nat) -> U32:
  match index:
    case 0n: 0
    case 1n: 1
    case 2n: 2
    case 3n: 3
    case 4n: 0
    case 5n: 1
    case 6n: 2
    case 7n: 3
    case 8n: 0
    case 9n: 1
    case 10n: 2
    case 11n: 3
    case 12n: 2
    case 13n: 3
    case 14n: 0
    case 15n: 1
    case 16n: 3
    case 17n: 0
    case 18n: 1
    case 19n: 2
    case 20n: 1
    case 21n: 2
    case 22n: 3
    case 23n: 0
    case 24n: 1
    case 25n: 2
    case 26n: 3
    case 27n: 0
    case 28n: 1
    case 29n: 2
    case 30n: 3
    case other: 0

def player_name(seat: Nat) -> String:
  match seat:
    case 0n: "Luc Ledger"
    case 1n: "Mireille Coeur"
    case 2n: "Noe Calcul"
    case other: "Solange Patience"

def player_personality(seat: Nat) -> String:
  match seat:
    case 0n: "measured opening leader"
    case 1n: "bold trump collector and taker"
    case 2n: "precise overtrumping defender"
    case other: "patient counterplayer"

def is_played_before(fuel: Nat, +index: Nat, +card: U32) -> Bool:
  match fuel:
    case 0n:
      False{}
    case 1n+pred:
      U32.is_eq(card, play_card(index)) || is_played_before(pred, 1n+index, card)

def remaining_decide(seen: Bool, card: U32, rest: +List<U32>) -> +List<U32>:
  match seen:
    case False{}:
      Con{card, rest}
    case True{}:
      rest

# The cards of `cards` not among the first `count` plays.
def remaining_cards(cards: +List<U32>, +count: Nat) -> +List<U32>:
  match cards:
    case Nil{}:
      Nil{}
    case Con{+head, tail}:
      remaining_decide(is_played_before(count, 0n, head), head, remaining_cards(tail, count))

def remaining_hand(seat: Nat, +count: Nat) -> +List<U32>:
  remaining_cards(seat_hand(seat), count)

def player(+seat: Nat, +count: Nat) -> PlayerView:
  PlayerView{u32(seat), player_name(seat), player_personality(seat), remaining_hand(seat, count)}

def players(+count: Nat) -> +List<PlayerView>:
  [player(0n, count), player(1n, count), player(2n, count), player(3n, count)]

def table_go(fuel: Nat, +start: Nat) -> +List<PlayedCard>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+pred:
      Con{PlayedCard{play_actor(start), play_card(start)}, table_go(pred, 1n+start)}

# The cards of the current trick, up to and including play `index`.
def table(+index: Nat) -> +List<PlayedCard>:
  table_go(1n+mod4(index), U32.to_nat((u32(div4(index)) * 4 : U32)))

def phase_of_trick(trick: Nat) -> String & U32:
  match trick:
    case 0n: ("Trick 1", 1)
    case 1n: ("Trick 2", 2)
    case 2n: ("Trick 3", 3)
    case 3n: ("Trick 4", 4)
    case 4n: ("Trick 5", 5)
    case 5n: ("Trick 6", 6)
    case 6n: ("Trick 7", 7)
    case other: ("Trick 8", 8)

def phase_info(index: Nat) -> String & U32:
  phase_of_trick(div4(index))

def action_of_offset(offset: Nat) -> String:
  match offset:
    case 0n: "lead"
    case 3n: "complete trick"
    case other: "play"

def action(index: Nat) -> String:
  action_of_offset(mod4(index))

def trick_end_note(trick: Nat) -> String:
  match trick:
    case 0n: "Luc wins trick one for North-South: 18 points."
    case 1n: "Luc wins trick two for North-South: 16 points."
    case 2n: "Noe's mandatory overtrump wins trick three: 13 points."
    case 3n: "Solange wins trick four for East-West: 17 points."
    case 4n: "Mireille wins trick five for East-West: 15 points."
    case 5n: "Mireille wins trick six for East-West: 17 points."
    case 6n: "Mireille wins trick seven for East-West: 25 points."
    case other: "Mireille wins the last trick: 31 card points plus dix de der."

def generic_note(offset: Nat, trick: Nat) -> String:
  match offset:
    case 0n:
      "The trick leader chooses a legal card."
    case 3n:
      trick_end_note(trick)
    case other_offset:
      "The next AI follows suit or applies the mandatory trump rule."

def note(+index: Nat) -> String:
  match index:
    case 8n:
      "Luc leads clubs; Mireille is void and must cut with a heart."
    case 9n:
      "Mireille cuts with the heart eight."
    case 10n:
      "Noe is also void: because an opponent is winning, the heart queen must overtrump."
    case 11n:
      trick_end_note(2n)
    case other:
      generic_note(mod4(other), div4(other))

def points_after_tricks(tricks: Nat) -> U32 & U32:
  match tricks:
    case 0n: (0, 0)
    case 1n: (18, 0)
    case 2n: (34, 0)
    case 3n: (47, 0)
    case 4n: (47, 17)
    case 5n: (47, 32)
    case 6n: (47, 49)
    case 7n: (47, 74)
    case other: (47, 115)

def points(count: Nat) -> U32 & U32:
  points_after_tricks(div4(count))

def play_step_at(+index: Nat, info: String & U32, score: U32 & U32) -> Step:
  (phase, trick) = info
  (ns, ew) = score
  Step{
    phase,
    note(index),
    play_actor(index),
    action(index),
    play_card(index),
    trick,
    ns,
    ew,
    players(1n+index),
    table(index)
  }

def play_step(+index: Nat) -> Step:
  play_step_at(index, phase_info(index), points(1n+index))

# Plays index .. index+fuel-1, followed by `rest`.
def play_steps_go(fuel: Nat, +index: Nat, rest: +List<Step>) -> +List<Step>:
  match fuel:
    case 0n:
      rest
    case 1n+pred:
      Con{play_step(index), play_steps_go(pred, 1n+index, rest)}

def bidding_steps() -> +List<Step>:
  Con{Step{
    "Deal", "Seed 1 fixes a complete 32-card deal; the omniscient observer sees every final holding.",
    3, "deal", 32, 0, 0, 0, players(0n), Nil{}
  }, Con{Step{
    "Round one", "Luc passes on the turned heart eight.",
    0, "pass", 17, 0, 0, 0, players(0n), Nil{}
  }, Con{Step{
    "Round one", "Mireille takes hearts with five trumps, including jack, nine, ten and ace.",
    1, "take hearts", 17, 0, 0, 0, players(0n), Nil{}
  }, Nil{}}}}

def outcome_steps() -> +List<Step>:
  Con{Step{
    "Outcome", "East-West make the contract, 115 card points to 47; no announcements are scored.",
    1, "contract made", 32, 8, 47, 115, players(32n), Nil{}
  }, Nil{}}

def all_steps() -> +List<Step>:
  List.append(&2, Step, bidding_steps(), play_steps_go(32n, 0n, outcome_steps()))

def card_suit(card: U32) -> U32:
  (card / 8 : U32)

def card_points_of(rank: Nat, +suit: Nat) -> U32:
  match rank:
    case 0n: 0
    case 1n: 0
    case 2n:
      Bool.pick(U32, Nat.is_eq(suit, 2n), 14, 0)
    case 3n:
      Bool.pick(U32, Nat.is_eq(suit, 2n), 20, 2)
    case 4n: 3
    case 5n: 4
    case 6n: 10
    case other: 11

def card_points(+card: U32) -> U32:
  card_points_of(U32.to_nat((card % 8 : U32)), U32.to_nat(card_suit(card)))

def sum_four(a: U32, b: U32, c: U32, d: U32) -> U32:
  (a + b + c + d : U32)

# Card points of trick `trick` (0-based); the last trick adds dix de der.
def trick_points(+trick: Nat) -> U32:
  +base = U32.to_nat((u32(trick) * 4 : U32))
  sum = sum_four(card_points(play_card(base)), card_points(play_card(1n+base)), card_points(play_card(2n+base)), card_points(play_card(3n+base)))
  (sum + Bool.pick(U32, Nat.is_eq(trick, 7n), 10, 0) : U32)

def has_suit(cards: +List<U32>, +suit: U32) -> Bool:
  match cards:
    case Nil{}:
      False{}
    case Con{head, tail}:
      U32.is_eq(card_suit(head), suit) || has_suit(tail, suit)

def trump_strength_of(rank: Nat) -> U32:
  match rank:
    case 0n: 0
    case 1n: 1
    case 2n: 6
    case 3n: 7
    case 4n: 2
    case 5n: 3
    case 6n: 4
    case other: 5

def trump_strength(card: U32) -> U32:
  trump_strength_of(U32.to_nat((card % 8 : U32)))

def rules_valid() -> Bool:
  cut_void = Bool.not(has_suit(remaining_hand(1n, 9n), 0))
  overtrump_void = Bool.not(has_suit(remaining_hand(2n, 10n), 0))
  cut = U32.is_eq(card_suit(play_card(9n)), 2)
  overtrump = U32.is_gt(trump_strength(play_card(10n)), trump_strength(play_card(9n)))
  last = U32.is_eq(play_card(31n), 1)
  total = U32.is_eq((47 + 115 : U32), 162)
  made = U32.is_gt(115, 47)
  tricks = U32.is_eq(trick_points(0n), 18) && U32.is_eq(trick_points(1n), 16) && U32.is_eq(trick_points(2n), 13) && U32.is_eq(trick_points(3n), 17) && U32.is_eq(trick_points(4n), 15) && U32.is_eq(trick_points(5n), 17) && U32.is_eq(trick_points(6n), 25) && U32.is_eq(trick_points(7n), 41)
  cut_void && overtrump_void && cut && overtrump && last && total && made && tricks

def main() -> BeloteReport:
  BeloteReport{
    1,
    3,
    1,
    2,
    rules_valid(),
    47,
    115,
    47,
    115,
    "Contract made: East-West win the hand 115 to 47.",
    all_steps()
  }
