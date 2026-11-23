import Base
import ./belote_proofs.bend as Conservation

# Pure deterministic classic Belote (latest Bend).  The complete report is
# computed before the browser starts: JavaScript only decodes and schedules it.
# `main_value()` is the report; `main` is an IO wrapper that forces it.

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

# Finite domains used by the closed validation layer: one constructor per
# seat, trick and play of the embedded trace.

type CheckSeat is Data:
  BSeat0{}
  BSeat1{}
  BSeat2{}
  BSeat3{}

type CheckTrick is Data:
  BTrick0{}
  BTrick1{}
  BTrick2{}
  BTrick3{}
  BTrick4{}
  BTrick5{}
  BTrick6{}
  BTrick7{}

type CheckPlay is Data:
  BPlay00{}
  BPlay01{}
  BPlay02{}
  BPlay03{}
  BPlay04{}
  BPlay05{}
  BPlay06{}
  BPlay07{}
  BPlay08{}
  BPlay09{}
  BPlay10{}
  BPlay11{}
  BPlay12{}
  BPlay13{}
  BPlay14{}
  BPlay15{}
  BPlay16{}
  BPlay17{}
  BPlay18{}
  BPlay19{}
  BPlay20{}
  BPlay21{}
  BPlay22{}
  BPlay23{}
  BPlay24{}
  BPlay25{}
  BPlay26{}
  BPlay27{}
  BPlay28{}
  BPlay29{}
  BPlay30{}
  BPlay31{}

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

# The play indices index .. index+fuel-1.
def play_indices_go(fuel: Nat, +index: Nat) -> +List<Nat>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+pred:
      Con{index, play_indices_go(pred, 1n+index)}

def play_steps_from_indices(indices: +List<Nat>) -> +List<Step>:
  match indices:
    case Nil{}:
      Nil{}
    case Con{index, tail}:
      Con{play_step(index), play_steps_from_indices(tail)}

# Mathematical theorem: converting any finite list of play indices to observer
# snapshots preserves its length. The proof is structural induction on the
# arbitrary input list, not enumeration of the embedded 32-play trace.
law play_steps_from_indices_length_theorem:
  for indices: +List<Nat>
  { List.length(&2, Step, play_steps_from_indices(indices)) == List.length(&2, Nat, indices) : Nat }

def play_steps_from_indices_length_theorem(indices):
  match indices:
    case Nil{}:
      {==}
    case Con{index, tail}:
      %play_steps_from_indices_length_theorem(tail) : {
        1n+List.length(&2, Step, play_steps_from_indices(tail)) == 1n+_
        : Nat
      }
      {==}

def play_steps() -> +List<Step>:
  play_steps_from_indices(play_indices_go(32n, 0n))

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
  List.append(&2, Step, List.append(&2, Step, bidding_steps(), play_steps()), outcome_steps())

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

# Closed trace validation computations
# ====================================

# These checks deliberately consume the same deal, play sequence, remaining
# hands, table builder, strength rules and scoring functions as the report.
# The finite check domains below force a separate certificate for every seat,
# trick and play rather than trusting a runtime Bool alone. They validate this
# trace; unlike the structural theorem above, they are not general proofs.

# Is `card` among deck positions index .. index+fuel-1?
def deck_seen_before(fuel: Nat, +index: Nat, +card: U32) -> Bool:
  match fuel:
    case 0n:
      False{}
    case 1n+pred:
      U32.is_eq(card, deck_card(index)) || deck_seen_before(pred, 1n+index, card)

# Deck position `index` holds a card in 0..31 not seen at an earlier position.
def deck_card_valid(+index: Nat) -> Bool:
  +card = deck_card(index)
  U32.is_lt(card, 32) && Bool.not(deck_seen_before(index, 0n, card))

def card_in_hand(cards: +List<U32>, +card: U32) -> Bool:
  match cards:
    case Nil{}:
      False{}
    case Con{head, tail}:
      U32.is_eq(head, card) || card_in_hand(tail, card)

# The actor's hand just before play `index`.
def current_hand(+index: Nat) -> +List<U32>:
  remaining_hand(U32.to_nat(play_actor(index)), index)

def play_owned(+index: Nat) -> Bool:
  card_in_hand(current_hand(index), play_card(index))

# The cards already on the table when play `index` is made.
def table_before(+index: Nat) -> +List<PlayedCard>:
  table_go(mod4(index), U32.to_nat((u32(div4(index)) * 4 : U32)))

def card_strength(+card: U32) -> U32:
  Bool.pick(U32, U32.is_eq(card_suit(card), 2), trump_strength(card), (card % 8 : U32))

def card_beats.go(candidate_trump: Bool, current_trump: Bool, same_suit: Bool, higher: Bool) -> Bool:
  match candidate_trump current_trump:
    case True{} False{}:
      True{}
    case True{} True{}:
      higher
    case False{} True{}:
      False{}
    case False{} False{}:
      same_suit && higher

# A trump beats any plain card; otherwise only a stronger card of the same suit.
def card_beats(+candidate: U32, +current: U32) -> Bool:
  +candidate_suit = card_suit(candidate)
  +current_suit = card_suit(current)
  card_beats.go(
    U32.is_eq(candidate_suit, 2),
    U32.is_eq(current_suit, 2),
    U32.is_eq(candidate_suit, current_suit),
    U32.is_gt(card_strength(candidate), card_strength(current)))

def played_card_beats(candidate: PlayedCard, current: PlayedCard) -> Bool:
  match candidate current:
    case PlayedCard{candidate_seat, candidate_card} PlayedCard{current_seat, current_card}:
      card_beats(candidate_card, current_card)

def winning_play_go(cards: +List<PlayedCard>, +winner: PlayedCard) -> PlayedCard:
  match cards:
    case Nil{}:
      winner
    case Con{+head, tail}:
      winning_play_go(tail, Bool.pick(PlayedCard, played_card_beats(head, winner), head, winner))

def winning_play(cards: +List<PlayedCard>) -> PlayedCard:
  match cards:
    case Nil{}:
      PlayedCard{0, 0}
    case Con{head, tail}:
      winning_play_go(tail, head)

def played_seat(played: PlayedCard) -> U32:
  match played:
    case PlayedCard{seat, card}:
      seat

def winning_seat(cards: +List<PlayedCard>) -> U32:
  played_seat(winning_play(cards))

def u32_max(+a: U32, +b: U32) -> U32:
  Bool.pick(U32, U32.is_gt(a, b), a, b)

def highest_trump_strength_go(cards: +List<PlayedCard>, +maximum: U32) -> U32:
  match cards:
    case Nil{}:
      maximum
    case Con{PlayedCard{seat, +card}, tail}:
      highest_trump_strength_go(tail, Bool.pick(U32, U32.is_eq(card_suit(card), 2), u32_max(trump_strength(card), maximum), maximum))

def hand_has_higher_trump(cards: +List<U32>, +strength: U32) -> Bool:
  match cards:
    case Nil{}:
      False{}
    case Con{+head, tail}:
      (U32.is_eq(card_suit(head), 2) && U32.is_gt(trump_strength(head), strength)) || hand_has_higher_trump(tail, strength)

def table_is_empty(cards: +List<PlayedCard>) -> Bool:
  match cards:
    case Nil{}: True{}
    case Con{head, tail}: False{}

def table_led_suit(cards: +List<PlayedCard>) -> U32:
  match cards:
    case Nil{}:
      0
    case Con{PlayedCard{seat, card}, tail}:
      card_suit(card)

def play_is_leading(+index: Nat) -> Bool:
  table_is_empty(table_before(index))

def play_led_suit(+index: Nat) -> U32:
  table_led_suit(table_before(index))

def play_has_led_suit(+index: Nat) -> Bool:
  has_suit(current_hand(index), play_led_suit(index))

def play_led_is_trump(+index: Nat) -> Bool:
  U32.is_eq(play_led_suit(index), 2)

def play_has_trump(+index: Nat) -> Bool:
  has_suit(current_hand(index), 2)

def play_highest_trump(+index: Nat) -> U32:
  highest_trump_strength_go(table_before(index), 0)

def play_has_higher_trump(+index: Nat) -> Bool:
  hand_has_higher_trump(current_hand(index), play_highest_trump(index))

def play_card_matches_led(+index: Nat) -> Bool:
  U32.is_eq(card_suit(play_card(index)), play_led_suit(index))

def play_card_is_trump(+index: Nat) -> Bool:
  U32.is_eq(card_suit(play_card(index)), 2)

def play_card_overtrumps(+index: Nat) -> Bool:
  U32.is_gt(trump_strength(play_card(index)), play_highest_trump(index))

def play_partner_winning(+index: Nat) -> Bool:
  partner = ((play_actor(index) + 2) % 4 : U32)
  U32.is_eq(winning_seat(table_before(index)), partner)

# Lead freely; otherwise follow the led suit whenever the hand holds it.
def play_follows_suit(+index: Nat) -> Bool:
  play_is_leading(index) || Bool.not(play_has_led_suit(index)) || play_card_matches_led(index)

# A trump play must rise above the table's highest trump whenever it can.
def play_rises(+index: Nat) -> Bool:
  Bool.not(play_has_higher_trump(index)) || play_card_overtrumps(index)

# The mandatory trump obligations, as a Boolean formula of the same case
# split as the Bend2 Core nested matches:
# - leading: free;
# - holding the led suit: when trump is led, rise if possible;
# - void in the led suit: free if the partner is winning or the hand has no
#   trump; otherwise cut with a trump, overtrumping if possible.
def play_trump_rule(+index: Nat) -> Bool:
  leading = play_is_leading(index)
  +has_led = play_has_led_suit(index)
  following = has_led && (Bool.not(play_led_is_trump(index)) || play_rises(index))
  void = Bool.not(has_led) && (play_partner_winning(index) || Bool.not(play_has_trump(index)) || (play_card_is_trump(index) && play_rises(index)))
  leading || following || void

def play_legal(+index: Nat) -> Bool:
  play_owned(index) && play_follows_suit(index) && play_trump_rule(index)

def trick_table(+trick: Nat) -> +List<PlayedCard>:
  table_go(4n, U32.to_nat((u32(trick) * 4 : U32)))

def trick_winner(+trick: Nat) -> U32:
  winning_seat(trick_table(trick))

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

# Finite check domains
# ====================

def check_seat_index(seat: CheckSeat) -> Nat:
  match seat:
    case BSeat0{}: 0n
    case BSeat1{}: 1n
    case BSeat2{}: 2n
    case BSeat3{}: 3n

def check_trick_index(trick: CheckTrick) -> Nat:
  match trick:
    case BTrick0{}: 0n
    case BTrick1{}: 1n
    case BTrick2{}: 2n
    case BTrick3{}: 3n
    case BTrick4{}: 4n
    case BTrick5{}: 5n
    case BTrick6{}: 6n
    case BTrick7{}: 7n

def check_play_index(play: CheckPlay) -> Nat:
  match play:
    case BPlay00{}: 0n
    case BPlay01{}: 1n
    case BPlay02{}: 2n
    case BPlay03{}: 3n
    case BPlay04{}: 4n
    case BPlay05{}: 5n
    case BPlay06{}: 6n
    case BPlay07{}: 7n
    case BPlay08{}: 8n
    case BPlay09{}: 9n
    case BPlay10{}: 10n
    case BPlay11{}: 11n
    case BPlay12{}: 12n
    case BPlay13{}: 13n
    case BPlay14{}: 14n
    case BPlay15{}: 15n
    case BPlay16{}: 16n
    case BPlay17{}: 17n
    case BPlay18{}: 18n
    case BPlay19{}: 19n
    case BPlay20{}: 20n
    case BPlay21{}: 21n
    case BPlay22{}: 22n
    case BPlay23{}: 23n
    case BPlay24{}: 24n
    case BPlay25{}: 25n
    case BPlay26{}: 26n
    case BPlay27{}: 27n
    case BPlay28{}: 28n
    case BPlay29{}: 29n
    case BPlay30{}: 30n
    case BPlay31{}: 31n

def trick_expected_points(trick: CheckTrick) -> U32:
  match trick:
    case BTrick0{}: 18
    case BTrick1{}: 16
    case BTrick2{}: 13
    case BTrick3{}: 17
    case BTrick4{}: 15
    case BTrick5{}: 17
    case BTrick6{}: 25
    case BTrick7{}: 41

def trick_expected_winner(trick: CheckTrick) -> U32:
  match trick:
    case BTrick0{}: 0
    case BTrick1{}: 0
    case BTrick2{}: 2
    case BTrick3{}: 3
    case BTrick4{}: 1
    case BTrick5{}: 1
    case BTrick6{}: 1
    case BTrick7{}: 1

# Closed certificates (119 = 32 + 4 + 32 + 32 + 8 + 8 + 3)
# ==========================================================

# 32: every deck position holds an in-range card not seen earlier.
law deck_cards_certificate:
  for play: CheckPlay
  {deck_card_valid(check_play_index(play)) == True{} : Bool}

def deck_cards_certificate(play):
  match play:
    case BPlay00{}: {==}
    case BPlay01{}: {==}
    case BPlay02{}: {==}
    case BPlay03{}: {==}
    case BPlay04{}: {==}
    case BPlay05{}: {==}
    case BPlay06{}: {==}
    case BPlay07{}: {==}
    case BPlay08{}: {==}
    case BPlay09{}: {==}
    case BPlay10{}: {==}
    case BPlay11{}: {==}
    case BPlay12{}: {==}
    case BPlay13{}: {==}
    case BPlay14{}: {==}
    case BPlay15{}: {==}
    case BPlay16{}: {==}
    case BPlay17{}: {==}
    case BPlay18{}: {==}
    case BPlay19{}: {==}
    case BPlay20{}: {==}
    case BPlay21{}: {==}
    case BPlay22{}: {==}
    case BPlay23{}: {==}
    case BPlay24{}: {==}
    case BPlay25{}: {==}
    case BPlay26{}: {==}
    case BPlay27{}: {==}
    case BPlay28{}: {==}
    case BPlay29{}: {==}
    case BPlay30{}: {==}
    case BPlay31{}: {==}

# 4: every seat is dealt eight cards.
law hand_size_certificate:
  for seat: CheckSeat
  {List.length(&2, U32, seat_hand(check_seat_index(seat))) == 8n : Nat}

def hand_size_certificate(seat):
  match seat:
    case BSeat0{}: {==}
    case BSeat1{}: {==}
    case BSeat2{}: {==}
    case BSeat3{}: {==}

# 32: every played card is still in its actor's hand.
law play_owned_certificate:
  for play: CheckPlay
  {play_owned(check_play_index(play)) == True{} : Bool}

def play_owned_certificate(play):
  match play:
    case BPlay00{}: {==}
    case BPlay01{}: {==}
    case BPlay02{}: {==}
    case BPlay03{}: {==}
    case BPlay04{}: {==}
    case BPlay05{}: {==}
    case BPlay06{}: {==}
    case BPlay07{}: {==}
    case BPlay08{}: {==}
    case BPlay09{}: {==}
    case BPlay10{}: {==}
    case BPlay11{}: {==}
    case BPlay12{}: {==}
    case BPlay13{}: {==}
    case BPlay14{}: {==}
    case BPlay15{}: {==}
    case BPlay16{}: {==}
    case BPlay17{}: {==}
    case BPlay18{}: {==}
    case BPlay19{}: {==}
    case BPlay20{}: {==}
    case BPlay21{}: {==}
    case BPlay22{}: {==}
    case BPlay23{}: {==}
    case BPlay24{}: {==}
    case BPlay25{}: {==}
    case BPlay26{}: {==}
    case BPlay27{}: {==}
    case BPlay28{}: {==}
    case BPlay29{}: {==}
    case BPlay30{}: {==}
    case BPlay31{}: {==}

# 32: every play satisfies the ownership, follow-suit and trump obligations.
law play_legal_certificate:
  for play: CheckPlay
  {play_legal(check_play_index(play)) == True{} : Bool}

def play_legal_certificate(play):
  match play:
    case BPlay00{}: {==}
    case BPlay01{}: {==}
    case BPlay02{}: {==}
    case BPlay03{}: {==}
    case BPlay04{}: {==}
    case BPlay05{}: {==}
    case BPlay06{}: {==}
    case BPlay07{}: {==}
    case BPlay08{}: {==}
    case BPlay09{}: {==}
    case BPlay10{}: {==}
    case BPlay11{}: {==}
    case BPlay12{}: {==}
    case BPlay13{}: {==}
    case BPlay14{}: {==}
    case BPlay15{}: {==}
    case BPlay16{}: {==}
    case BPlay17{}: {==}
    case BPlay18{}: {==}
    case BPlay19{}: {==}
    case BPlay20{}: {==}
    case BPlay21{}: {==}
    case BPlay22{}: {==}
    case BPlay23{}: {==}
    case BPlay24{}: {==}
    case BPlay25{}: {==}
    case BPlay26{}: {==}
    case BPlay27{}: {==}
    case BPlay28{}: {==}
    case BPlay29{}: {==}
    case BPlay30{}: {==}
    case BPlay31{}: {==}

# 8: every trick's card points (with dix de der on the last) match the timeline.
law trick_points_certificate:
  for trick: CheckTrick
  {trick_points(check_trick_index(trick)) == trick_expected_points(trick) : U32}

def trick_points_certificate(trick):
  match trick:
    case BTrick0{}: {==}
    case BTrick1{}: {==}
    case BTrick2{}: {==}
    case BTrick3{}: {==}
    case BTrick4{}: {==}
    case BTrick5{}: {==}
    case BTrick6{}: {==}
    case BTrick7{}: {==}

# 8: every trick winner computed from the rules matches the timeline.
law trick_winner_certificate:
  for trick: CheckTrick
  {trick_winner(check_trick_index(trick)) == trick_expected_winner(trick) : U32}

def trick_winner_certificate(trick):
  match trick:
    case BTrick0{}: {==}
    case BTrick1{}: {==}
    case BTrick2{}: {==}
    case BTrick3{}: {==}
    case BTrick4{}: {==}
    case BTrick5{}: {==}
    case BTrick6{}: {==}
    case BTrick7{}: {==}

# 3 closed facts: the score total, the report length, the runtime self-check.
law score_total_certificate:
  {(47 + 115 : U32) == 162 : U32}

def score_total_certificate():
  {==}

law report_length_certificate:
  {List.length(&2, Step, all_steps()) == 36n : Nat}

def report_length_certificate():
  {==}

law rules_valid_certificate:
  {rules_valid() == True{} : Bool}

def rules_valid_certificate():
  {==}

# Report
# ======

# The erased fields hold the theorems and certificates themselves: building
# this record makes the checker demand every one of them, while the compiled
# value keeps only the human-readable audit text and counts.
type BeloteVerificationAudit is Data:
  BeloteVerificationAudit{
    -card_payload_conservation: Conservation.BelotePayloadConservationClaim(),
    -card_count_conservation: Conservation.BeloteCardCountConservationClaim(),
    -card_point_conservation: Conservation.BeloteCardPointConservationClaim(),
    -step_mapping_length: @indices: +List<Nat> -> {
      List.length(&2, Step, play_steps_from_indices(indices)) == List.length(&2, Nat, indices)
      : Nat
    },
    -deck_cards: @play: CheckPlay -> {deck_card_valid(check_play_index(play)) == True{} : Bool},
    -hand_sizes: @seat: CheckSeat -> {List.length(&2, U32, seat_hand(check_seat_index(seat))) == 8n : Nat},
    -owned_cards: @play: CheckPlay -> {play_owned(check_play_index(play)) == True{} : Bool},
    -legal_plays: @play: CheckPlay -> {play_legal(check_play_index(play)) == True{} : Bool},
    -trick_points: @trick: CheckTrick -> {trick_points(check_trick_index(trick)) == trick_expected_points(trick) : U32},
    -trick_winners: @trick: CheckTrick -> {trick_winner(check_trick_index(trick)) == trick_expected_winner(trick) : U32},
    -score_total: {(47 + 115 : U32) == 162 : U32},
    -report_length: {List.length(&2, Step, all_steps()) == 36n : Nat},
    -rules_valid: {rules_valid() == True{} : Bool},
    title: String,
    scope: String,
    deck: String,
    legality: String,
    scoring: String,
    limitation: String,
    certified_cases: U32,
    general_theorems: U32
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
    steps: +List<Step>,
    verification: BeloteVerificationAudit
  }

def verification_audit() -> BeloteVerificationAudit:
  BeloteVerificationAudit{
    Conservation.history_payload_conservation_theorem,
    Conservation.history_card_count_conservation_theorem,
    Conservation.history_card_value_conservation_theorem,
    play_steps_from_indices_length_theorem,
    deck_cards_certificate,
    hand_size_certificate,
    play_owned_certificate,
    play_legal_certificate,
    trick_points_certificate,
    trick_winner_certificate,
    score_total_certificate(),
    report_length_certificate(),
    rules_valid_certificate(),
    "Machine-checked Belote conservation proof and trace audit",
    "A multi-lemma semantic proof covers every finite card-movement history; one smaller mapping lemma and closed certificates cover the observer trace.",
    "Certificates check that the deal is an in-range permutation and every hand has eight cards.",
    "Certificates check ownership, follow-suit, cut, trump-rise, partner and overtrump decisions in all 32 plays.",
    "Certificates check all trick winners and points, the 162-point total, and all 36 snapshots.",
    "The semantic summit preserves every card identity and printed point value through arbitrary deals, plays, and trick collections. Contract bonuses are outside that invariant; the 119 trace certificates do not generalize to every deal.",
    119,
    4
  }

def main_value() -> BeloteReport:
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
    all_steps(),
    verification_audit()
  }

# The executable entry forces the checked report and reports readiness; the
# viewer consumes main_value() through the generated ES module (build.sh).
def main_accept_value(value: BeloteReport) -> IO(Unit):
  IO.print("Ready{}")

def main() -> IO(Unit):
  main_accept_value(main_value())
