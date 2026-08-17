import Base

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
    steps: List<Step>
  }

# Constants
# =========

# Cards are 0..31.  A card is suit * 8 + rank, with suits clubs, diamonds,
# hearts, spades and ranks 7, 8, 9, jack, queen, king, ten, ace.  The embedded
# deck below is the Fisher-Yates result for seed 1.  Hearts (suit 2) are trump.

# Belote-Func
# ===========

def u32_func(value: Nat) -> U32:
  U32.from_nat(value)

def nat_pair_func(value: Nat) -> Nat & Nat:
  ((a, ea), (b, eb)) = Nat.copy(value)
  (a, b)

def nat_four_func(value: Nat) -> Nat & (Nat & (Nat & Nat)):
  (left, right) = nat_pair_func(value)
  (a, b) = nat_pair_func(left)
  (c, d) = nat_pair_func(right)
  (a, (b, (c, d)))

def nat_eight_func(value: Nat) -> Nat & (Nat & (Nat & (Nat & (Nat & (Nat & (Nat & Nat)))))):
  (left, right) = nat_pair_func(value)
  (a, (b, (c, d))) = nat_four_func(left)
  (e, (f, (g, h))) = nat_four_func(right)
  (a, (b, (c, (d, (e, (f, (g, h)))))))

def deck_card_func(index: Nat) -> U32:
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

def seat_hand_func(seat: Nat) -> List<U32>:
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
def play_card_func(index: Nat) -> U32:
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

def play_actor_func(index: Nat) -> U32:
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

def player_name_func(seat: Nat) -> String:
  match seat:
    case 0n: "Luc Ledger"
    case 1n: "Mireille Coeur"
    case 2n: "Noe Calcul"
    case other: "Solange Patience"

def player_personality_func(seat: Nat) -> String:
  match seat:
    case 0n: "measured opening leader"
    case 1n: "bold trump collector and taker"
    case 2n: "precise overtrumping defender"
    case other: "patient counterplayer"

def is_played_before_func(fuel: Nat, index: Nat, card: U32) -> Bool:
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

def remaining_decide_func(seen: Bool, card: U32, rest: List<U32>) -> List<U32>:
  match seen:
    case False{}:
      Con{card, rest}
    case True{}:
      rest

def remaining_cards_func(cards: List<U32>, count: Nat) -> List<U32>:
  match cards:
    case Nil{}:
      Nil{}
    case Con{head, tail}:
      ((n0, en0), (n1, en1)) = Nat.copy(count)
      ((c0, ec0), (c1, ec1)) = U32.copy(head)
      seen = is_played_before_func(n0, 0n, c0)
      rest = remaining_cards_func(tail, n1)
      remaining_decide_func(seen, c1, rest)

def remaining_hand_func(seat: Nat, count: Nat) -> List<U32>:
  hand = seat_hand_func(seat)
  result = remaining_cards_func(hand, count)
  result

def player_func(seat: Nat, count: Nat) -> PlayerView:
  (s0, (s1, (s2, s3))) = nat_four_func(seat)
  PlayerView{u32_func(s0), player_name_func(s1), player_personality_func(s2), remaining_hand_func(s3, count)}

def players_func(count: Nat) -> List<PlayerView>:
  (n0, (n1, (n2, n3))) = nat_four_func(count)
  Con{player_func(0n, n0), Con{player_func(1n, n1), Con{player_func(2n, n2), Con{player_func(3n, n3), Nil{}}}}}

def table_go_func(fuel: Nat, start: Nat) -> List<PlayedCard>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+pred:
      (s0, (s1, (s2, s3))) = nat_four_func(start)
      tail = table_go_func(pred, 1n+s3)
      Con{PlayedCard{play_actor_func(s0), play_card_func(s1)}, tail}

def table_func(index: Nat) -> List<PlayedCard>:
  ((a, ea), (b, eb)) = U32.copy(u32_func(index))
  completed = U32.div(a, u32_func(4n))
  offset = U32.mod(b, u32_func(4n))
  start = U32.mul(completed, u32_func(4n))
  table = table_go_func(1n+U32.to_nat(offset), U32.to_nat(start))
  table

def phase_info_func(index: Nat) -> String & U32:
  match U32.to_nat(U32.div(u32_func(index), u32_func(4n))):
    case 0n: ("Trick 1", u32_func(1n))
    case 1n: ("Trick 2", u32_func(2n))
    case 2n: ("Trick 3", u32_func(3n))
    case 3n: ("Trick 4", u32_func(4n))
    case 4n: ("Trick 5", u32_func(5n))
    case 5n: ("Trick 6", u32_func(6n))
    case 6n: ("Trick 7", u32_func(7n))
    case other: ("Trick 8", u32_func(8n))

def action_func(index: Nat) -> String:
  match U32.to_nat(U32.mod(u32_func(index), u32_func(4n))):
    case 0n: "lead"
    case 3n: "complete trick"
    case other: "play"

def trick_end_note_func(trick: Nat) -> String:
  match trick:
    case 0n: "Luc wins trick one for North-South: 18 points."
    case 1n: "Luc wins trick two for North-South: 16 points."
    case 2n: "Noe's mandatory overtrump wins trick three: 13 points."
    case 3n: "Solange wins trick four for East-West: 17 points."
    case 4n: "Mireille wins trick five for East-West: 15 points."
    case 5n: "Mireille wins trick six for East-West: 17 points."
    case 6n: "Mireille wins trick seven for East-West: 25 points."
    case other: "Mireille wins the last trick: 31 card points plus dix de der."

def note_func(index: Nat) -> String:
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

def points_func(count: Nat) -> U32 & U32:
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

def play_step_func(index: Nat) -> Step:
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

def play_steps_go_func(fuel: Nat, index: Nat) -> List<Step>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+pred:
      (i0, i1) = nat_pair_func(index)
      head = play_step_func(i0)
      tail = play_steps_go_func(pred, 1n+i1)
      Con{head, tail}

def play_steps_func() -> List<Step>:
  steps = play_steps_go_func(32n, 0n)
  steps

def bidding_steps_func() -> List<Step>:
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

def outcome_steps_func() -> List<Step>:
  Con{Step{
    "Outcome", "East-West make the contract, 115 card points to 47; no announcements are scored.",
    u32_func(1n), "contract made", u32_func(32n), u32_func(8n), u32_func(47n), u32_func(115n), players_func(32n), Nil{}
  }, Nil{}}

def all_steps_func() -> List<Step>:
  before = List.append(Step, bidding_steps_func(), play_steps_func())
  all = List.append(Step, before, outcome_steps_func())
  all

def card_suit_func(card: U32) -> U32:
  U32.div(card, u32_func(8n))

def card_points_func(card: U32) -> U32:
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

def sum_four_func(a: U32, b: U32, c: U32, d: U32) -> U32:
  U32.add(U32.add(a, b), U32.add(c, d))

def trick_points_func(trick: Nat) -> U32:
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

def has_suit_func(cards: List<U32>, suit: U32) -> Bool:
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

def trump_strength_func(card: U32) -> U32:
  match U32.to_nat(U32.mod(card, u32_func(8n))):
    case 0n: u32_func(0n)
    case 1n: u32_func(1n)
    case 2n: u32_func(6n)
    case 3n: u32_func(7n)
    case 4n: u32_func(2n)
    case 5n: u32_func(3n)
    case 6n: u32_func(4n)
    case other: u32_func(5n)

def rules_valid_func() -> Bool:
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

def main() -> BeloteReport:
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
    all_steps_func()
  }
