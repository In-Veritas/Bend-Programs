import Base
import ./belote_proofs.bend as Conservation
import ../../compat/list.bend as List

# Pure deterministic classic Belote for Bend2 Core.  The complete report is
# computed before the browser starts: JavaScript only decodes and schedules it.

# Types
# =====

type PlayedCard:
  PlayedCard{seat: U32, card: U32}

type PlayerView:
  PlayerView{seat: U32, name: String, personality: String, hand: List<U32>}

type Step:
  Step{
    phase: String,
    note: String,
    actor: U32,
    action: String,
    card: U32,
    trick: U32,
    north_south: U32,
    east_west: U32,
    players: List<PlayerView>,
    table: List<PlayedCard>
  }

type CheckSeat:
  BSeat0{}
  BSeat1{}
  BSeat2{}
  BSeat3{}

type CheckTrick:
  BTrick0{}
  BTrick1{}
  BTrick2{}
  BTrick3{}
  BTrick4{}
  BTrick5{}
  BTrick6{}
  BTrick7{}

type CheckPlay:
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

# Belote-Func
# ===========

assert u32_func:
  forall value: Nat
  U32

def u32_func(value):
  U32.from_nat(value)

assert nat_pair_func:
  forall value: Nat
  Nat & Nat

def nat_pair_func(value):
  ((a, ea), (b, eb)) = Nat.copy(value)
  (a, b)

assert nat_four_func:
  forall value: Nat
  Nat & (Nat & (Nat & Nat))

def nat_four_func(value):
  (left, right) = nat_pair_func(value)
  (a, b) = nat_pair_func(left)
  (c, d) = nat_pair_func(right)
  (a, (b, (c, d)))

assert nat_eight_func:
  forall value: Nat
  Nat & (Nat & (Nat & (Nat & (Nat & (Nat & (Nat & Nat))))))

def nat_eight_func(value):
  (left, right) = nat_pair_func(value)
  (a, (b, (c, d))) = nat_four_func(left)
  (e, (f, (g, h))) = nat_four_func(right)
  (a, (b, (c, (d, (e, (f, (g, h)))))))

assert u32_pair_func:
  forall value: U32
  U32 & U32

def u32_pair_func(value):
  ((a, ea), (b, eb)) = U32.copy(value)
  (a, b)

assert played_card_pair_func:
  forall value: PlayedCard
  PlayedCard & PlayedCard

def played_card_pair_func(value):
  match value:
    case PlayedCard{seat, card}:
      (s0, s1) = u32_pair_func(seat)
      (c0, c1) = u32_pair_func(card)
      (PlayedCard{s0, c0}, PlayedCard{s1, c1})

assert deck_card_func:
  forall index: Nat
  U32

def deck_card_func(index):
  match index:
    case 0n: u32_func(1n)
    case 1n: u32_func(28n)
    case 2n: u32_func(27n)
    case 3n: u32_func(26n)
    case 4n: u32_func(3n)
    case 5n: u32_func(7n)
    case 6n: u32_func(6n)
    case 7n: u32_func(14n)
    case 8n: u32_func(5n)
    case 9n: u32_func(11n)
    case 10n: u32_func(17n)
    case 11n: u32_func(22n)
    case 12n: u32_func(29n)
    case 13n: u32_func(19n)
    case 14n: u32_func(18n)
    case 15n: u32_func(23n)
    case 16n: u32_func(20n)
    case 17n: u32_func(25n)
    case 18n: u32_func(10n)
    case 19n: u32_func(24n)
    case 20n: u32_func(9n)
    case 21n: u32_func(0n)
    case 22n: u32_func(15n)
    case 23n: u32_func(31n)
    case 24n: u32_func(30n)
    case 25n: u32_func(4n)
    case 26n: u32_func(13n)
    case 27n: u32_func(16n)
    case 28n: u32_func(2n)
    case 29n: u32_func(8n)
    case 30n: u32_func(21n)
    case other: u32_func(12n)

assert seat_hand_func:
  forall seat: Nat
  List<U32>

def seat_hand_func(seat):
  match seat:
    case 0n:
      Con{deck_card_func(0n), Con{deck_card_func(1n), Con{deck_card_func(2n), Con{deck_card_func(3n), Con{deck_card_func(4n), Con{deck_card_func(5n), Con{deck_card_func(6n), Con{deck_card_func(7n), Nil{}}}}}}}}}
    case 1n:
      Con{deck_card_func(8n), Con{deck_card_func(9n), Con{deck_card_func(10n), Con{deck_card_func(11n), Con{deck_card_func(12n), Con{deck_card_func(13n), Con{deck_card_func(14n), Con{deck_card_func(15n), Nil{}}}}}}}}}
    case 2n:
      Con{deck_card_func(16n), Con{deck_card_func(17n), Con{deck_card_func(18n), Con{deck_card_func(19n), Con{deck_card_func(20n), Con{deck_card_func(21n), Con{deck_card_func(22n), Con{deck_card_func(23n), Nil{}}}}}}}}}
    case other:
      Con{deck_card_func(24n), Con{deck_card_func(25n), Con{deck_card_func(26n), Con{deck_card_func(27n), Con{deck_card_func(28n), Con{deck_card_func(29n), Con{deck_card_func(30n), Con{deck_card_func(31n), Nil{}}}}}}}}}

# This sequence is produced by four deterministic policies.  At every turn the
# policy first constructs the legal set: follow suit; when trump is led, rise
# when possible; when void and an opponent is winning, cut and overtrump when
# possible.  Trick three visibly exercises both mandatory cut and overtrump.
assert play_card_func:
  forall index: Nat
  U32

def play_card_func(index):
  match index:
    case 0n: u32_func(7n)
    case 1n: u32_func(5n)
    case 2n: u32_func(0n)
    case 3n: u32_func(4n)
    case 4n: u32_func(14n)
    case 5n: u32_func(11n)
    case 6n: u32_func(9n)
    case 7n: u32_func(13n)
    case 8n: u32_func(6n)
    case 9n: u32_func(17n)
    case 10n: u32_func(20n)
    case 11n: u32_func(2n)
    case 12n: u32_func(24n)
    case 13n: u32_func(30n)
    case 14n: u32_func(28n)
    case 15n: u32_func(29n)
    case 16n: u32_func(12n)
    case 17n: u32_func(3n)
    case 18n: u32_func(22n)
    case 19n: u32_func(10n)
    case 20n: u32_func(23n)
    case 21n: u32_func(25n)
    case 22n: u32_func(21n)
    case 23n: u32_func(27n)
    case 24n: u32_func(18n)
    case 25n: u32_func(31n)
    case 26n: u32_func(16n)
    case 27n: u32_func(26n)
    case 28n: u32_func(19n)
    case 29n: u32_func(15n)
    case 30n: u32_func(8n)
    case other: u32_func(1n)

assert play_actor_func:
  forall index: Nat
  U32

def play_actor_func(index):
  match index:
    case 0n: u32_func(0n)
    case 1n: u32_func(1n)
    case 2n: u32_func(2n)
    case 3n: u32_func(3n)
    case 4n: u32_func(0n)
    case 5n: u32_func(1n)
    case 6n: u32_func(2n)
    case 7n: u32_func(3n)
    case 8n: u32_func(0n)
    case 9n: u32_func(1n)
    case 10n: u32_func(2n)
    case 11n: u32_func(3n)
    case 12n: u32_func(2n)
    case 13n: u32_func(3n)
    case 14n: u32_func(0n)
    case 15n: u32_func(1n)
    case 16n: u32_func(3n)
    case 17n: u32_func(0n)
    case 18n: u32_func(1n)
    case 19n: u32_func(2n)
    case 20n: u32_func(1n)
    case 21n: u32_func(2n)
    case 22n: u32_func(3n)
    case 23n: u32_func(0n)
    case 24n: u32_func(1n)
    case 25n: u32_func(2n)
    case 26n: u32_func(3n)
    case 27n: u32_func(0n)
    case 28n: u32_func(1n)
    case 29n: u32_func(2n)
    case 30n: u32_func(3n)
    case other: u32_func(0n)

assert player_name_func:
  forall seat: Nat
  String

def player_name_func(seat):
  match seat:
    case 0n: "Luc Ledger"
    case 1n: "Mireille Coeur"
    case 2n: "Noe Calcul"
    case other: "Solange Patience"

assert player_personality_func:
  forall seat: Nat
  String

def player_personality_func(seat):
  match seat:
    case 0n: "measured opening leader"
    case 1n: "bold trump collector and taker"
    case 2n: "precise overtrumping defender"
    case other: "patient counterplayer"

assert is_played_before_func:
  forall fuel: Nat
  forall index: Nat
  forall card: U32
  Bool

def is_played_before_func(fuel, index, card):
  match fuel:
    case 0n:
      False{}
    case 1n+pred:
      ((i0, ei0), (i1, ei1)) = Nat.copy(index)
      ((c0, ec0), (c1, ec1)) = U32.copy(card)
      match U32.is_eq(c0, play_card_func(i0)):
        case False{}:
          result = is_played_before_func(pred, 1n+i1, c1)
          result
        case True{}:
          True{}

assert remaining_decide_func:
  forall seen: Bool
  forall card: U32
  forall rest: List<U32>
  List<U32>

def remaining_decide_func(seen, card, rest):
  match seen:
    case False{}:
      Con{card, rest}
    case True{}:
      rest

assert remaining_cards_func:
  forall cards: List<U32>
  forall count: Nat
  List<U32>

def remaining_cards_func(cards, count):
  match cards:
    case Nil{}:
      Nil{}
    case Con{head, tail}:
      ((n0, en0), (n1, en1)) = Nat.copy(count)
      ((c0, ec0), (c1, ec1)) = U32.copy(head)
      seen = is_played_before_func(n0, 0n, c0)
      rest = remaining_cards_func(tail, n1)
      remaining_decide_func(seen, c1, rest)

assert remaining_hand_func:
  forall seat: Nat
  forall count: Nat
  List<U32>

def remaining_hand_func(seat, count):
  hand = seat_hand_func(seat)
  result = remaining_cards_func(hand, count)
  result

assert player_func:
  forall seat: Nat
  forall count: Nat
  PlayerView

def player_func(seat, count):
  (s0, (s1, (s2, s3))) = nat_four_func(seat)
  PlayerView{u32_func(s0), player_name_func(s1), player_personality_func(s2), remaining_hand_func(s3, count)}

assert players_func:
  forall count: Nat
  List<PlayerView>

def players_func(count):
  (n0, (n1, (n2, n3))) = nat_four_func(count)
  Con{player_func(0n, n0), Con{player_func(1n, n1), Con{player_func(2n, n2), Con{player_func(3n, n3), Nil{}}}}}

assert table_go_func:
  forall fuel: Nat
  forall start: Nat
  List<PlayedCard>

def table_go_func(fuel, start):
  match fuel:
    case 0n:
      Nil{}
    case 1n+pred:
      (s0, (s1, (s2, s3))) = nat_four_func(start)
      tail = table_go_func(pred, 1n+s3)
      Con{PlayedCard{play_actor_func(s0), play_card_func(s1)}, tail}

assert table_func:
  forall index: Nat
  List<PlayedCard>

def table_func(index):
  ((a, ea), (b, eb)) = U32.copy(u32_func(index))
  completed = U32.div(a, u32_func(4n))
  offset = U32.mod(b, u32_func(4n))
  start = U32.mul(completed, u32_func(4n))
  table = table_go_func(1n+U32.to_nat(offset), U32.to_nat(start))
  table

assert phase_info_func:
  forall index: Nat
  String & U32

def phase_info_func(index):
  match U32.to_nat(U32.div(u32_func(index), u32_func(4n))):
    case 0n: ("Trick 1", u32_func(1n))
    case 1n: ("Trick 2", u32_func(2n))
    case 2n: ("Trick 3", u32_func(3n))
    case 3n: ("Trick 4", u32_func(4n))
    case 4n: ("Trick 5", u32_func(5n))
    case 5n: ("Trick 6", u32_func(6n))
    case 6n: ("Trick 7", u32_func(7n))
    case other: ("Trick 8", u32_func(8n))

assert action_func:
  forall index: Nat
  String

def action_func(index):
  match U32.to_nat(U32.mod(u32_func(index), u32_func(4n))):
    case 0n: "lead"
    case 3n: "complete trick"
    case other: "play"

assert trick_end_note_func:
  forall trick: Nat
  String

def trick_end_note_func(trick):
  match trick:
    case 0n: "Luc wins trick one for North-South: 18 points."
    case 1n: "Luc wins trick two for North-South: 16 points."
    case 2n: "Noe's mandatory overtrump wins trick three: 13 points."
    case 3n: "Solange wins trick four for East-West: 17 points."
    case 4n: "Mireille wins trick five for East-West: 15 points."
    case 5n: "Mireille wins trick six for East-West: 17 points."
    case 6n: "Mireille wins trick seven for East-West: 25 points."
    case other: "Mireille wins the last trick: 31 card points plus dix de der."

assert note_func:
  forall index: Nat
  String

def note_func(index):
  match index:
    case 8n:
      "Luc leads clubs; Mireille is void and must cut with a heart."
    case 9n:
      "Mireille cuts with the heart eight."
    case 10n:
      "Noe is also void: because an opponent is winning, the heart queen must overtrump."
    case 11n:
      trick_end_note_func(2n)
    case other:
      ((a, ea), (b, eb)) = Nat.copy(other)
      match U32.to_nat(U32.mod(u32_func(a), u32_func(4n))):
        case 0n:
          "The trick leader chooses a legal card."
        case 3n:
          trick = U32.div(u32_func(b), u32_func(4n))
          trick_end_note_func(U32.to_nat(trick))
        case other_offset:
          "The next AI follows suit or applies the mandatory trump rule."

assert points_func:
  forall count: Nat
  U32 & U32

def points_func(count):
  match U32.to_nat(U32.div(u32_func(count), u32_func(4n))):
    case 0n: (u32_func(0n), u32_func(0n))
    case 1n: (u32_func(18n), u32_func(0n))
    case 2n: (u32_func(34n), u32_func(0n))
    case 3n: (u32_func(47n), u32_func(0n))
    case 4n: (u32_func(47n), u32_func(17n))
    case 5n: (u32_func(47n), u32_func(32n))
    case 6n: (u32_func(47n), u32_func(49n))
    case 7n: (u32_func(47n), u32_func(74n))
    case other: (u32_func(47n), u32_func(115n))

assert play_step_func:
  forall index: Nat
  Step

def play_step_func(index):
  (i0, (i1, (i2, (i3, (i4, (i5, (i6, i7))))))) = nat_eight_func(index)
  (phase, trick) = phase_info_func(i0)
  (ns, ew) = points_func(1n+i5)
  Step{
    phase,
    note_func(i1),
    play_actor_func(i2),
    action_func(i3),
    play_card_func(i4),
    trick,
    ns,
    ew,
    players_func(1n+i6),
    table_func(i7)
  }

assert play_indices_go_func:
  forall fuel: Nat
  forall index: Nat
  List<Nat>

def play_indices_go_func(fuel, index):
  match fuel:
    case 0n:
      Nil{}
    case 1n+pred:
      (i0, i1) = nat_pair_func(index)
      Con{i0, play_indices_go_func(pred, 1n+i1)}

assert play_steps_from_indices_func:
  forall indices: List<Nat>
  List<Step>

def play_steps_from_indices_func(indices):
  match indices:
    case Nil{}:
      Nil{}
    case Con{index, tail}:
      Con{play_step_func(index), play_steps_from_indices_func(tail)}

# Mathematical theorem: converting any finite list of play indices to observer
# snapshots preserves its length. The proof is structural induction on the
# arbitrary input list, not enumeration of the embedded 32-play trace.
assert play_steps_from_indices_length_theorem_func:
  forall indices: List<Nat>
  { List.length(Step, play_steps_from_indices_func(indices)) == List.length(Nat, indices) : Nat }

def play_steps_from_indices_length_theorem_func(indices):
  match indices:
    case Nil{}:
      {==}
    case Con{index, tail}:
      %play_steps_from_indices_length_theorem_func(tail) : {
        1n+List.length(Step, play_steps_from_indices_func(tail)) == 1n+_
        : Nat
      }
      {==}

assert play_steps_func:
  List<Step>

def play_steps_func():
  steps = play_steps_from_indices_func(play_indices_go_func(32n, 0n))
  steps

assert bidding_steps_func:
  List<Step>

def bidding_steps_func():
  Con{Step{
    "Deal", "Seed 1 fixes a complete 32-card deal; the omniscient observer sees every final holding.",
    u32_func(3n), "deal", u32_func(32n), u32_func(0n), u32_func(0n), u32_func(0n), players_func(0n), Nil{}
  }, Con{Step{
    "Round one", "Luc passes on the turned heart eight.",
    u32_func(0n), "pass", u32_func(17n), u32_func(0n), u32_func(0n), u32_func(0n), players_func(0n), Nil{}
  }, Con{Step{
    "Round one", "Mireille takes hearts with five trumps, including jack, nine, ten and ace.",
    u32_func(1n), "take hearts", u32_func(17n), u32_func(0n), u32_func(0n), u32_func(0n), players_func(0n), Nil{}
  }, Nil{}}}}

assert outcome_steps_func:
  List<Step>

def outcome_steps_func():
  Con{Step{
    "Outcome", "East-West make the contract, 115 card points to 47; no announcements are scored.",
    u32_func(1n), "contract made", u32_func(32n), u32_func(8n), u32_func(47n), u32_func(115n), players_func(32n), Nil{}
  }, Nil{}}

assert all_steps_func:
  List<Step>

def all_steps_func():
  before = List.append(Step, bidding_steps_func(), play_steps_func())
  all = List.append(Step, before, outcome_steps_func())
  all

assert card_suit_func:
  forall card: U32
  U32

def card_suit_func(card):
  U32.div(card, u32_func(8n))

assert card_points_func:
  forall card: U32
  U32

def card_points_func(card):
  ((rank_card, er), (suit_card, es)) = U32.copy(card)
  match U32.to_nat(U32.mod(rank_card, u32_func(8n))):
    case 0n:
      u32_func(0n)
    case 1n:
      u32_func(0n)
    case 2n:
      match U32.to_nat(card_suit_func(suit_card)):
        case 2n: u32_func(14n)
        case other: u32_func(0n)
    case 3n:
      match U32.to_nat(card_suit_func(suit_card)):
        case 2n: u32_func(20n)
        case other: u32_func(2n)
    case 4n:
      u32_func(3n)
    case 5n:
      u32_func(4n)
    case 6n:
      u32_func(10n)
    case other:
      u32_func(11n)

assert sum_four_func:
  forall a: U32
  forall b: U32
  forall c: U32
  forall d: U32
  U32

def sum_four_func(a, b, c, d):
  U32.add(U32.add(a, b), U32.add(c, d))

assert trick_points_func:
  forall trick: Nat
  U32

def trick_points_func(trick):
  match trick:
    case 0n:
      sum_four_func(card_points_func(play_card_func(0n)), card_points_func(play_card_func(1n)), card_points_func(play_card_func(2n)), card_points_func(play_card_func(3n)))
    case 1n:
      sum_four_func(card_points_func(play_card_func(4n)), card_points_func(play_card_func(5n)), card_points_func(play_card_func(6n)), card_points_func(play_card_func(7n)))
    case 2n:
      sum_four_func(card_points_func(play_card_func(8n)), card_points_func(play_card_func(9n)), card_points_func(play_card_func(10n)), card_points_func(play_card_func(11n)))
    case 3n:
      sum_four_func(card_points_func(play_card_func(12n)), card_points_func(play_card_func(13n)), card_points_func(play_card_func(14n)), card_points_func(play_card_func(15n)))
    case 4n:
      sum_four_func(card_points_func(play_card_func(16n)), card_points_func(play_card_func(17n)), card_points_func(play_card_func(18n)), card_points_func(play_card_func(19n)))
    case 5n:
      sum_four_func(card_points_func(play_card_func(20n)), card_points_func(play_card_func(21n)), card_points_func(play_card_func(22n)), card_points_func(play_card_func(23n)))
    case 6n:
      sum_four_func(card_points_func(play_card_func(24n)), card_points_func(play_card_func(25n)), card_points_func(play_card_func(26n)), card_points_func(play_card_func(27n)))
    case other:
      U32.add(sum_four_func(card_points_func(play_card_func(28n)), card_points_func(play_card_func(29n)), card_points_func(play_card_func(30n)), card_points_func(play_card_func(31n))), u32_func(10n))

assert has_suit_func:
  forall cards: List<U32>
  forall suit: U32
  Bool

def has_suit_func(cards, suit):
  match cards:
    case Nil{}:
      False{}
    case Con{head, tail}:
      ((s0, es0), (s1, es1)) = U32.copy(suit)
      match U32.is_eq(card_suit_func(head), s0):
        case False{}:
          result = has_suit_func(tail, s1)
          result
        case True{}:
          True{}

assert trump_strength_func:
  forall card: U32
  U32

def trump_strength_func(card):
  match U32.to_nat(U32.mod(card, u32_func(8n))):
    case 0n: u32_func(0n)
    case 1n: u32_func(1n)
    case 2n: u32_func(6n)
    case 3n: u32_func(7n)
    case 4n: u32_func(2n)
    case 5n: u32_func(3n)
    case 6n: u32_func(4n)
    case other: u32_func(5n)

# Closed trace validation computations
# ====================================

# These checks deliberately consume the same deal, play sequence, remaining
# hands, table builder, strength rules and scoring functions as the report.
# The finite check domains below force a separate certificate for every seat,
# trick and play rather than trusting a runtime Bool alone. They validate this
# trace; unlike the structural theorem above, they are not general proofs.

assert deck_seen_before_func:
  forall fuel: Nat
  forall index: Nat
  forall card: U32
  Bool

def deck_seen_before_func(fuel, index, card):
  match fuel:
    case 0n:
      False{}
    case 1n+pred:
      (i0, i1) = nat_pair_func(index)
      (c0, c1) = u32_pair_func(card)
      match U32.is_eq(c0, deck_card_func(i0)):
        case False{}:
          deck_seen_before_func(pred, 1n+i1, c1)
        case True{}:
          True{}

assert deck_card_valid_func:
  forall index: Nat
  Bool

def deck_card_valid_func(index):
  (i0, i1) = nat_pair_func(index)
  (c0, c1) = u32_pair_func(deck_card_func(i0))
  in_range = U32.is_lt(c0, u32_func(32n))
  fresh = Bool.not(deck_seen_before_func(i1, 0n, c1))
  Bool.and(in_range, fresh)

assert card_in_hand_func:
  forall cards: List<U32>
  forall card: U32
  Bool

def card_in_hand_func(cards, card):
  match cards:
    case Nil{}:
      False{}
    case Con{head, tail}:
      (c0, c1) = u32_pair_func(card)
      match U32.is_eq(head, c0):
        case False{}:
          card_in_hand_func(tail, c1)
        case True{}:
          True{}

assert current_hand_func:
  forall index: Nat
  List<U32>

def current_hand_func(index):
  (i0, i1) = nat_pair_func(index)
  seat = U32.to_nat(play_actor_func(i0))
  remaining_hand_func(seat, i1)

assert play_owned_func:
  forall index: Nat
  Bool

def play_owned_func(index):
  (i0, i1) = nat_pair_func(index)
  card_in_hand_func(current_hand_func(i0), play_card_func(i1))

assert table_before_func:
  forall index: Nat
  List<PlayedCard>

def table_before_func(index):
  (i0, i1) = nat_pair_func(index)
  completed = U32.div(u32_func(i0), u32_func(4n))
  offset = U32.mod(u32_func(i1), u32_func(4n))
  start = U32.mul(completed, u32_func(4n))
  table_go_func(U32.to_nat(offset), U32.to_nat(start))

assert card_strength_func:
  forall card: U32
  U32

def card_strength_func(card):
  (c0, c1) = u32_pair_func(card)
  match U32.is_eq(card_suit_func(c0), u32_func(2n)):
    case False{}:
      U32.mod(c1, u32_func(8n))
    case True{}:
      trump_strength_func(c1)

assert card_beats_func:
  forall candidate: U32
  forall current: U32
  Bool

def card_beats_func(candidate, current):
  (candidate_suit_card, candidate_strength_card) = u32_pair_func(candidate)
  (current_suit_card, current_strength_card) = u32_pair_func(current)
  (candidate_suit_test, candidate_suit_keep) = u32_pair_func(card_suit_func(candidate_suit_card))
  (current_suit_test, current_suit_keep) = u32_pair_func(card_suit_func(current_suit_card))
  match U32.is_eq(candidate_suit_test, u32_func(2n)):
    case False{}:
      match U32.is_eq(current_suit_test, u32_func(2n)):
        case False{}:
          match U32.is_eq(candidate_suit_keep, current_suit_keep):
            case False{}: False{}
            case True{}: U32.is_gt(card_strength_func(candidate_strength_card), card_strength_func(current_strength_card))
        case True{}:
          False{}
    case True{}:
      match U32.is_eq(current_suit_test, u32_func(2n)):
        case False{}:
          True{}
        case True{}:
          U32.is_gt(card_strength_func(candidate_strength_card), card_strength_func(current_strength_card))

assert played_card_beats_func:
  forall candidate: PlayedCard
  forall current: PlayedCard
  Bool

def played_card_beats_func(candidate, current):
  match candidate:
    case PlayedCard{candidate_seat, candidate_card}:
      match current:
        case PlayedCard{current_seat, current_card}:
          card_beats_func(candidate_card, current_card)

assert winning_play_go_func:
  forall cards: List<PlayedCard>
  forall winner: PlayedCard
  PlayedCard

def winning_play_go_func(cards, winner):
  match cards:
    case Nil{}:
      winner
    case Con{head, tail}:
      (head_test, head_keep) = played_card_pair_func(head)
      (winner_test, winner_keep) = played_card_pair_func(winner)
      match played_card_beats_func(head_test, winner_test):
        case False{}:
          winning_play_go_func(tail, winner_keep)
        case True{}:
          winning_play_go_func(tail, head_keep)

assert winning_play_func:
  forall cards: List<PlayedCard>
  PlayedCard

def winning_play_func(cards):
  match cards:
    case Nil{}:
      PlayedCard{u32_func(0n), u32_func(0n)}
    case Con{head, tail}:
      winning_play_go_func(tail, head)

assert winning_seat_func:
  forall cards: List<PlayedCard>
  U32

def winning_seat_func(cards):
  match winning_play_func(cards):
    case PlayedCard{seat, card}:
      seat

assert u32_max_func:
  forall a: U32
  forall b: U32
  U32

def u32_max_func(a, b):
  (a0, a1) = u32_pair_func(a)
  (b0, b1) = u32_pair_func(b)
  match U32.is_gt(a0, b0):
    case False{}: b1
    case True{}: a1

assert highest_trump_strength_go_func:
  forall cards: List<PlayedCard>
  forall maximum: U32
  U32

def highest_trump_strength_go_func(cards, maximum):
  match cards:
    case Nil{}:
      maximum
    case Con{PlayedCard{seat, card}, tail}:
      (c0, c1) = u32_pair_func(card)
      match U32.is_eq(card_suit_func(c0), u32_func(2n)):
        case False{}:
          highest_trump_strength_go_func(tail, maximum)
        case True{}:
          highest_trump_strength_go_func(tail, u32_max_func(trump_strength_func(c1), maximum))

assert hand_has_higher_trump_func:
  forall cards: List<U32>
  forall strength: U32
  Bool

def hand_has_higher_trump_func(cards, strength):
  match cards:
    case Nil{}:
      False{}
    case Con{head, tail}:
      (c0, c1) = u32_pair_func(head)
      (s0, s1) = u32_pair_func(strength)
      match U32.is_eq(card_suit_func(c0), u32_func(2n)):
        case False{}:
          hand_has_higher_trump_func(tail, s1)
        case True{}:
          match U32.is_gt(trump_strength_func(c1), s0):
            case False{}: hand_has_higher_trump_func(tail, s1)
            case True{}: True{}

assert play_is_leading_func:
  forall index: Nat
  Bool

def play_is_leading_func(index):
  match table_before_func(index):
    case Nil{}: True{}
    case Con{head, tail}: False{}

assert play_led_suit_func:
  forall index: Nat
  U32

def play_led_suit_func(index):
  match table_before_func(index):
    case Nil{}:
      u32_func(0n)
    case Con{PlayedCard{seat, card}, tail}:
      card_suit_func(card)

assert play_has_led_suit_func:
  forall index: Nat
  Bool

def play_has_led_suit_func(index):
  (i0, i1) = nat_pair_func(index)
  has_suit_func(current_hand_func(i0), play_led_suit_func(i1))

assert play_led_is_trump_func:
  forall index: Nat
  Bool

def play_led_is_trump_func(index):
  U32.is_eq(play_led_suit_func(index), u32_func(2n))

assert play_has_trump_func:
  forall index: Nat
  Bool

def play_has_trump_func(index):
  has_suit_func(current_hand_func(index), u32_func(2n))

assert play_highest_trump_func:
  forall index: Nat
  U32

def play_highest_trump_func(index):
  highest_trump_strength_go_func(table_before_func(index), u32_func(0n))

assert play_has_higher_trump_func:
  forall index: Nat
  Bool

def play_has_higher_trump_func(index):
  (i0, i1) = nat_pair_func(index)
  hand_has_higher_trump_func(current_hand_func(i0), play_highest_trump_func(i1))

assert play_card_matches_led_func:
  forall index: Nat
  Bool

def play_card_matches_led_func(index):
  (i0, i1) = nat_pair_func(index)
  U32.is_eq(card_suit_func(play_card_func(i0)), play_led_suit_func(i1))

assert play_card_is_trump_func:
  forall index: Nat
  Bool

def play_card_is_trump_func(index):
  U32.is_eq(card_suit_func(play_card_func(index)), u32_func(2n))

assert play_card_overtrumps_func:
  forall index: Nat
  Bool

def play_card_overtrumps_func(index):
  (i0, i1) = nat_pair_func(index)
  U32.is_gt(trump_strength_func(play_card_func(i0)), play_highest_trump_func(i1))

assert play_partner_winning_func:
  forall index: Nat
  Bool

def play_partner_winning_func(index):
  (i0, i1) = nat_pair_func(index)
  partner = U32.mod(U32.add(play_actor_func(i0), u32_func(2n)), u32_func(4n))
  U32.is_eq(winning_seat_func(table_before_func(i1)), partner)

assert play_follows_suit_func:
  forall index: Nat
  Bool

def play_follows_suit_func(index):
  (i0, i1) = nat_pair_func(index)
  match play_is_leading_func(i0):
    case False{}:
      (i2, i3) = nat_pair_func(i1)
      match play_has_led_suit_func(i2):
        case False{}: True{}
        case True{}: play_card_matches_led_func(i3)
    case True{}:
      True{}

assert play_trump_rule_func:
  forall index: Nat
  Bool

def play_trump_rule_func(index):
  (i0, i1) = nat_pair_func(index)
  match play_is_leading_func(i0):
    case True{}:
      True{}
    case False{}:
      (i2, i3) = nat_pair_func(i1)
      match play_has_led_suit_func(i2):
        case True{}:
          (i4, i5) = nat_pair_func(i3)
          match play_led_is_trump_func(i4):
            case False{}:
              True{}
            case True{}:
              (i6, i7) = nat_pair_func(i5)
              match play_has_higher_trump_func(i6):
                case False{}: True{}
                case True{}: play_card_overtrumps_func(i7)
        case False{}:
          (i4, i5) = nat_pair_func(i3)
          match play_partner_winning_func(i4):
            case True{}:
              True{}
            case False{}:
              (i6, i7) = nat_pair_func(i5)
              match play_has_trump_func(i6):
                case False{}:
                  True{}
                case True{}:
                  (i8, i9) = nat_pair_func(i7)
                  match play_card_is_trump_func(i8):
                    case False{}:
                      False{}
                    case True{}:
                      (i10, i11) = nat_pair_func(i9)
                      match play_has_higher_trump_func(i10):
                        case False{}: True{}
                        case True{}: play_card_overtrumps_func(i11)

assert play_legal_func:
  forall index: Nat
  Bool

def play_legal_func(index):
  (i0, (i1, (i2, i3))) = nat_four_func(index)
  Bool.and(play_owned_func(i0), Bool.and(play_follows_suit_func(i1), play_trump_rule_func(i2)))

assert trick_table_func:
  forall trick: Nat
  List<PlayedCard>

def trick_table_func(trick):
  start = U32.mul(u32_func(trick), u32_func(4n))
  table_go_func(4n, U32.to_nat(start))

assert trick_winner_func:
  forall trick: Nat
  U32

def trick_winner_func(trick):
  winning_seat_func(trick_table_func(trick))

assert rules_valid_func:
  Bool

def rules_valid_func():
  cut_void = Bool.not(has_suit_func(remaining_hand_func(1n, 9n), u32_func(0n)))
  overtrump_void = Bool.not(has_suit_func(remaining_hand_func(2n, 10n), u32_func(0n)))
  cut = U32.is_eq(card_suit_func(play_card_func(9n)), u32_func(2n))
  overtrump = U32.is_gt(trump_strength_func(play_card_func(10n)), trump_strength_func(play_card_func(9n)))
  last = U32.is_eq(play_card_func(31n), u32_func(1n))
  total = U32.is_eq(U32.add(u32_func(47n), u32_func(115n)), u32_func(162n))
  made = U32.is_gt(u32_func(115n), u32_func(47n))
  tricks = Bool.and(
    U32.is_eq(trick_points_func(0n), u32_func(18n)),
    Bool.and(U32.is_eq(trick_points_func(1n), u32_func(16n)),
    Bool.and(U32.is_eq(trick_points_func(2n), u32_func(13n)),
    Bool.and(U32.is_eq(trick_points_func(3n), u32_func(17n)),
    Bool.and(U32.is_eq(trick_points_func(4n), u32_func(15n)),
    Bool.and(U32.is_eq(trick_points_func(5n), u32_func(17n)),
    Bool.and(U32.is_eq(trick_points_func(6n), u32_func(25n)),
             U32.is_eq(trick_points_func(7n), u32_func(41n)))))))))
  Bool.and(cut_void, Bool.and(overtrump_void, Bool.and(cut, Bool.and(overtrump, Bool.and(last, Bool.and(total, Bool.and(made, tricks)))))))

assert check_seat_index_func:
  forall seat: CheckSeat
  Nat

def check_seat_index_func(seat):
  match seat:
    case BSeat0{}: 0n
    case BSeat1{}: 1n
    case BSeat2{}: 2n
    case BSeat3{}: 3n

assert check_trick_index_func:
  forall trick: CheckTrick
  Nat

def check_trick_index_func(trick):
  match trick:
    case BTrick0{}: 0n
    case BTrick1{}: 1n
    case BTrick2{}: 2n
    case BTrick3{}: 3n
    case BTrick4{}: 4n
    case BTrick5{}: 5n
    case BTrick6{}: 6n
    case BTrick7{}: 7n

assert check_play_index_func:
  forall play: CheckPlay
  Nat

def check_play_index_func(play):
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

assert trick_expected_points_func:
  forall trick: CheckTrick
  U32

def trick_expected_points_func(trick):
  match trick:
    case BTrick0{}: u32_func(18n)
    case BTrick1{}: u32_func(16n)
    case BTrick2{}: u32_func(13n)
    case BTrick3{}: u32_func(17n)
    case BTrick4{}: u32_func(15n)
    case BTrick5{}: u32_func(17n)
    case BTrick6{}: u32_func(25n)
    case BTrick7{}: u32_func(41n)

assert trick_expected_winner_func:
  forall trick: CheckTrick
  U32

def trick_expected_winner_func(trick):
  match trick:
    case BTrick0{}: u32_func(0n)
    case BTrick1{}: u32_func(0n)
    case BTrick2{}: u32_func(2n)
    case BTrick3{}: u32_func(3n)
    case BTrick4{}: u32_func(1n)
    case BTrick5{}: u32_func(1n)
    case BTrick6{}: u32_func(1n)
    case BTrick7{}: u32_func(1n)

assert deck_cards_certificate_func:
  forall play: CheckPlay
  {deck_card_valid_func(check_play_index_func(play)) == True{} : Bool}

def deck_cards_certificate_func(play):
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

assert hand_size_certificate_func:
  forall seat: CheckSeat
  {List.length(U32, seat_hand_func(check_seat_index_func(seat))) == 8n : Nat}

def hand_size_certificate_func(seat):
  match seat:
    case BSeat0{}: {==}
    case BSeat1{}: {==}
    case BSeat2{}: {==}
    case BSeat3{}: {==}

assert play_owned_certificate_func:
  forall play: CheckPlay
  {play_owned_func(check_play_index_func(play)) == True{} : Bool}

def play_owned_certificate_func(play):
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

assert play_legal_certificate_func:
  forall play: CheckPlay
  {play_legal_func(check_play_index_func(play)) == True{} : Bool}

def play_legal_certificate_func(play):
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

assert trick_points_certificate_func:
  forall trick: CheckTrick
  {trick_points_func(check_trick_index_func(trick)) == trick_expected_points_func(trick) : U32}

def trick_points_certificate_func(trick):
  match trick:
    case BTrick0{}: {==}
    case BTrick1{}: {==}
    case BTrick2{}: {==}
    case BTrick3{}: {==}
    case BTrick4{}: {==}
    case BTrick5{}: {==}
    case BTrick6{}: {==}
    case BTrick7{}: {==}

assert trick_winner_certificate_func:
  forall trick: CheckTrick
  {trick_winner_func(check_trick_index_func(trick)) == trick_expected_winner_func(trick) : U32}

def trick_winner_certificate_func(trick):
  match trick:
    case BTrick0{}: {==}
    case BTrick1{}: {==}
    case BTrick2{}: {==}
    case BTrick3{}: {==}
    case BTrick4{}: {==}
    case BTrick5{}: {==}
    case BTrick6{}: {==}
    case BTrick7{}: {==}

assert score_total_certificate_func:
  {U32.add(u32_func(47n), u32_func(115n)) == u32_func(162n) : U32}

def score_total_certificate_func():
  {==}

assert report_length_certificate_func:
  {List.length(Step, all_steps_func()) == 36n : Nat}

def report_length_certificate_func():
  {==}

assert rules_valid_certificate_func:
  {rules_valid_func() == True{} : Bool}

def rules_valid_certificate_func():
  {==}

type BeloteVerificationAudit:
  BeloteVerificationAudit{
    -card_payload_conservation: Conservation.BelotePayloadConservationClaim(),
    -card_count_conservation: Conservation.BeloteCardCountConservationClaim(),
    -card_point_conservation: Conservation.BeloteCardPointConservationClaim(),
    -step_mapping_length: @indices: List<Nat> -> {
      List.length(Step, play_steps_from_indices_func(indices)) == List.length(Nat, indices)
      : Nat
    },
    -deck_cards: @play: CheckPlay -> {deck_card_valid_func(check_play_index_func(play)) == True{} : Bool},
    -hand_sizes: @seat: CheckSeat -> {List.length(U32, seat_hand_func(check_seat_index_func(seat))) == 8n : Nat},
    -owned_cards: @play: CheckPlay -> {play_owned_func(check_play_index_func(play)) == True{} : Bool},
    -legal_plays: @play: CheckPlay -> {play_legal_func(check_play_index_func(play)) == True{} : Bool},
    -trick_points: @trick: CheckTrick -> {trick_points_func(check_trick_index_func(trick)) == trick_expected_points_func(trick) : U32},
    -trick_winners: @trick: CheckTrick -> {trick_winner_func(check_trick_index_func(trick)) == trick_expected_winner_func(trick) : U32},
    -score_total: {U32.add(u32_func(47n), u32_func(115n)) == u32_func(162n) : U32},
    -report_length: {List.length(Step, all_steps_func()) == 36n : Nat},
    -rules_valid: {rules_valid_func() == True{} : Bool},
    title: String,
    scope: String,
    deck: String,
    legality: String,
    scoring: String,
    limitation: String,
    certified_cases: U32,
    general_theorems: U32
  }

type BeloteReport:
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
    steps: List<Step>,
    verification: BeloteVerificationAudit
  }

assert verification_audit_func:
  BeloteVerificationAudit

def verification_audit_func():
  BeloteVerificationAudit{
    Conservation.history_payload_conservation_theorem,
    Conservation.history_card_count_conservation_theorem,
    Conservation.history_card_value_conservation_theorem,
    play_steps_from_indices_length_theorem_func,
    deck_cards_certificate_func,
    hand_size_certificate_func,
    play_owned_certificate_func,
    play_legal_certificate_func,
    trick_points_certificate_func,
    trick_winner_certificate_func,
    score_total_certificate_func(),
    report_length_certificate_func(),
    rules_valid_certificate_func(),
    "Machine-checked Belote conservation proof and trace audit",
    "A multi-lemma semantic proof covers every finite card-movement history; one smaller mapping lemma and closed certificates cover the observer trace.",
    "Certificates check that the deal is an in-range permutation and every hand has eight cards.",
    "Certificates check ownership, follow-suit, cut, trump-rise, partner and overtrump decisions in all 32 plays.",
    "Certificates check all trick winners and points, the 162-point total, and all 36 snapshots.",
    "The semantic summit preserves every card identity and printed point value through arbitrary deals, plays, and trick collections. Contract bonuses are outside that invariant; the 119 trace certificates do not generalize to every deal.",
    u32_func(119n),
    u32_func(4n)
  }

assert main_value:
  BeloteReport

def main_value():
  BeloteReport{
    u32_func(1n),
    u32_func(3n),
    u32_func(1n),
    u32_func(2n),
    rules_valid_func(),
    u32_func(47n),
    u32_func(115n),
    u32_func(47n),
    u32_func(115n),
    "Contract made: East-West win the hand 115 to 47.",
    all_steps_func(),
    verification_audit_func()
  }

assert main_accept_value:
  forall value: BeloteReport
  IO(Unit)

def main_accept_value(value):
  IO.print("Ready{}")

assert main:
  IO(Unit)

def main():
  main_accept_value(main_value!())
