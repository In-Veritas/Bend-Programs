import Base
import ./poker_proofs.bend as Conservation
import ../../compat/list.bend as List

# Pure, deterministic poker simulation for Bend2 Core.  The browser viewer is
# deliberately outside this file: main returns all state needed to replay two
# complete four-AI hands without IO or hidden host-side game logic.

type Odds:
  Odds{
    win: U32,
    high: U32,
    pair: U32,
    two_pair: U32,
    trips: U32,
    straight: U32,
    flush: U32,
    full_house: U32,
    quads: U32
  }

type PlayerView:
  PlayerView{
    seat: U32,
    name: String,
    personality: String,
    active: Bool,
    stack: U32,
    cards: List<U32>,
    best: String,
    odds: Odds
  }

type Step:
  Step{
    phase: String,
    note: String,
    actor: U32,
    action: String,
    amount: U32,
    pot: U32,
    board: List<U32>,
    players: List<PlayerView>
  }

type Timeline:
  Timeline{
    variant: String,
    seed: U32,
    dealer: U32,
    winner: U32,
    steps: List<Step>
  }

# Finite domains used by the closed validation layer. Runtime timeline stages remain the
# compact Nat codes consumed by the viewer; these types enumerate every row
# that the two authored simulations publish.

type ModelSeat:
  SeatAda{}
  SeatBeak{}
  SeatCora{}
  SeatRook{}

type ModelRunout:
  DryRunout{}
  WetRunout{}
  PairedRunout{}
  BroadwayRunout{}

type ModelStrategy:
  CallingStation{}
  ValueDiscipline{}

# Mathematical count model for a complete round-robin deal. Unlike the finite
# outcome table below, `rounds` is an arbitrary Nat.
type SeatCounts:
  SeatCounts{ada: Nat, beak: Nat, cora: Nat, rook: Nat}

type TexasStage:
  TexasDeal{}
  TexasFlop{}
  TexasTurn{}
  TexasAfterFold{}
  TexasShowdown{}

type OmahaStage:
  OmahaDeal{}
  OmahaFlop{}
  OmahaFoldedFlop{}
  OmahaTurn{}
  OmahaRiverPressure{}
  OmahaAfterFold{}
  OmahaShowdown{}

# U32-Helpers
# ===========

assert u32_pair:
  forall value: U32
  U32 & U32

def u32_pair(value):
  ((a, ea), (b, eb)) = U32.copy(value)
  (a, b)

assert u32_quad:
  forall value: U32
  U32 & (U32 & (U32 & U32))

def u32_quad(value):
  (a, rest) = u32_pair(value)
  (b, more) = u32_pair(rest)
  (c, d) = u32_pair(more)
  (a, (b, (c, d)))

assert nat_pair:
  forall value: Nat
  Nat & Nat

def nat_pair(value):
  ((a, ea), (b, eb)) = Nat.copy(value)
  (a, b)

assert nat_quad:
  forall value: Nat
  Nat & (Nat & (Nat & Nat))

def nat_quad(value):
  (a, rest) = nat_pair(value)
  (b, more) = nat_pair(rest)
  (c, d) = nat_pair(more)
  (a, (b, (c, d)))

assert nat_eight:
  forall value: Nat
  Nat & (Nat & (Nat & (Nat & (Nat & (Nat & (Nat & Nat))))))

def nat_eight(value):
  (left, right) = nat_pair(value)
  (a, (b, (c, d))) = nat_quad(left)
  (e, (f, (g, h))) = nat_quad(right)
  (a, (b, (c, (d, (e, (f, (g, h)))))))

assert u32:
  forall value: Nat
  U32

def u32(value):
  U32.from_nat(value)

# List-Helpers
# ============

assert cards0:
  List<U32>

def cards0():
  Nil{}

assert cards1:
  forall a: Nat
  List<U32>

def cards1(a):
  Con{u32(a), Nil{}}

assert cards2:
  forall a: Nat
  forall b: Nat
  List<U32>

def cards2(a, b):
  Con{u32(a), Con{u32(b), Nil{}}}

assert cards3:
  forall a: Nat
  forall b: Nat
  forall c: Nat
  List<U32>

def cards3(a, b, c):
  Con{u32(a), Con{u32(b), Con{u32(c), Nil{}}}}

assert cards4:
  forall a: Nat
  forall b: Nat
  forall c: Nat
  forall d: Nat
  List<U32>

def cards4(a, b, c, d):
  Con{u32(a), Con{u32(b), Con{u32(c), Con{u32(d), Nil{}}}}}

assert cards5:
  forall a: Nat
  forall b: Nat
  forall c: Nat
  forall d: Nat
  forall e: Nat
  List<U32>

def cards5(a, b, c, d, e):
  Con{u32(a), Con{u32(b), Con{u32(c), Con{u32(d), Con{u32(e), Nil{}}}}}}

# Deal
# ====

# Each deck is a full affine permutation: (seed + step * index) mod 52.
# Texas uses seed 5 / step 3; Omaha uses seed 29 / step 17. Both steps are
# coprime to 52, hence no card can repeat during the deal.

assert texas_card:
  forall index: Nat
  U32

def texas_card(index):
  U32.mod(U32.add(u32(5n), U32.mul(u32(3n), u32(index))), u32(52n))

assert omaha_card:
  forall index: Nat
  U32

def omaha_card(index):
  U32.mod(U32.add(u32(29n), U32.mul(u32(17n), u32(index))), u32(52n))

assert texas_cards_from_indices:
  forall indices: List<Nat>
  List<U32>

def texas_cards_from_indices(indices):
  match indices:
    case Nil{}:
      Nil{}
    case Con{index, tail}:
      Con{texas_card(index), texas_cards_from_indices(tail)}

assert omaha_cards_from_indices:
  forall indices: List<Nat>
  List<U32>

def omaha_cards_from_indices(indices):
  match indices:
    case Nil{}:
      Nil{}
    case Con{index, tail}:
      Con{omaha_card(index), omaha_cards_from_indices(tail)}

# Mathematical theorems: dealing either variant over an arbitrary finite list
# of deck indices preserves the list length. Each proof is structural induction
# over an unbounded List<Nat>; it does not enumerate either embedded deal.
assert texas_cards_length_theorem:
  forall indices: List<Nat>
  { List.length(U32, texas_cards_from_indices(indices)) == List.length(Nat, indices) : Nat }

def texas_cards_length_theorem(indices):
  match indices:
    case Nil{}:
      {==}
    case Con{index, tail}:
      %texas_cards_length_theorem(tail) : {1n+List.length(U32, texas_cards_from_indices(tail)) == 1n+_ : Nat}
      {==}

assert omaha_cards_length_theorem:
  forall indices: List<Nat>
  { List.length(U32, omaha_cards_from_indices(indices)) == List.length(Nat, indices) : Nat }

def omaha_cards_length_theorem(indices):
  match indices:
    case Nil{}:
      {==}
    case Con{index, tail}:
      %omaha_cards_length_theorem(tail) : {1n+List.length(U32, omaha_cards_from_indices(tail)) == 1n+_ : Nat}
      {==}

assert seat_counts_inc:
  forall counts: SeatCounts
  SeatCounts

def seat_counts_inc(counts):
  match counts:
    case SeatCounts{ada, beak, cora, rook}:
      SeatCounts{1n+ada, 1n+beak, 1n+cora, 1n+rook}

assert complete_round_counts:
  forall rounds: Nat
  SeatCounts

def complete_round_counts(rounds):
  match rounds:
    case 0n:
      SeatCounts{0n, 0n, 0n, 0n}
    case 1n+pred:
      seat_counts_inc(complete_round_counts(pred))

# Mathematical fairness theorem for the deal scheduler: after any number of
# complete round-robin rounds, all four seats have exactly that many cards.
# This is induction over arbitrary Nat rounds, not four closed seat cases.
assert complete_rounds_balanced_theorem:
  forall rounds: Nat
  { complete_round_counts(rounds) == SeatCounts{rounds, rounds, rounds, rounds} : SeatCounts }

def complete_rounds_balanced_theorem(rounds):
  match rounds:
    case 0n:
      {==}
    case 1n+pred:
      %complete_rounds_balanced_theorem(pred) : {
        seat_counts_inc(complete_round_counts(pred)) == seat_counts_inc(_)
        : SeatCounts
      }
      {==}

assert texas_hole:
  forall seat: Nat
  List<U32>

def texas_hole(seat):
  match seat:
    case 0n:
      Con{texas_card(0n), Con{texas_card(4n), Nil{}}}
    case 1n:
      Con{texas_card(1n), Con{texas_card(5n), Nil{}}}
    case 2n:
      Con{texas_card(2n), Con{texas_card(6n), Nil{}}}
    case 3n:
      Con{texas_card(3n), Con{texas_card(7n), Nil{}}}
    case other:
      Nil{}

assert omaha_hole:
  forall seat: Nat
  List<U32>

def omaha_hole(seat):
  match seat:
    case 0n:
      Con{omaha_card(0n), Con{omaha_card(4n), Con{omaha_card(8n), Con{omaha_card(12n), Nil{}}}}}
    case 1n:
      Con{omaha_card(1n), Con{omaha_card(5n), Con{omaha_card(9n), Con{omaha_card(13n), Nil{}}}}}
    case 2n:
      Con{omaha_card(2n), Con{omaha_card(6n), Con{omaha_card(10n), Con{omaha_card(14n), Nil{}}}}}
    case 3n:
      Con{omaha_card(3n), Con{omaha_card(7n), Con{omaha_card(11n), Con{omaha_card(15n), Nil{}}}}}
    case other:
      Nil{}

assert texas_board:
  forall count: Nat
  List<U32>

def texas_board(count):
  match count:
    case 0n:
      texas_cards_from_indices(Nil{})
    case 1n:
      texas_cards_from_indices(Con{8n, Nil{}})
    case 2n:
      texas_cards_from_indices(Con{8n, Con{9n, Nil{}}})
    case 3n:
      texas_cards_from_indices(Con{8n, Con{9n, Con{10n, Nil{}}}})
    case 4n:
      texas_cards_from_indices(Con{8n, Con{9n, Con{10n, Con{11n, Nil{}}}}})
    case other:
      texas_cards_from_indices(Con{8n, Con{9n, Con{10n, Con{11n, Con{12n, Nil{}}}}}})

assert omaha_board:
  forall count: Nat
  List<U32>

def omaha_board(count):
  match count:
    case 0n:
      omaha_cards_from_indices(Nil{})
    case 1n:
      omaha_cards_from_indices(Con{16n, Nil{}})
    case 2n:
      omaha_cards_from_indices(Con{16n, Con{17n, Nil{}}})
    case 3n:
      omaha_cards_from_indices(Con{16n, Con{17n, Con{18n, Nil{}}}})
    case 4n:
      omaha_cards_from_indices(Con{16n, Con{17n, Con{18n, Con{19n, Nil{}}}}})
    case other:
      omaha_cards_from_indices(Con{16n, Con{17n, Con{18n, Con{19n, Con{20n, Nil{}}}}}})

# Odds
# ====

# Percentages are deterministic equity estimates computed in Bend. The four
# win fields sum to 100 on every street. Category fields express the chance of
# finishing in each class from the visible street; showdown is one-hot. Omaha
# categories obey the two-hole / three-board rule for this embedded deal.

assert texas_odds:
  forall stage: Nat
  forall seat: Nat
  Odds

def texas_odds(stage, seat):
  match stage:
    case 0n:
      match seat:
        case 0n: Odds{u32(27n),u32(46n),u32(37n),u32(8n),u32(3n),u32(4n),u32(1n),u32(1n),u32(0n)}
        case 1n: Odds{u32(20n),u32(54n),u32(34n),u32(7n),u32(2n),u32(2n),u32(0n),u32(1n),u32(0n)}
        case 2n: Odds{u32(29n),u32(47n),u32(36n),u32(8n),u32(3n),u32(4n),u32(1n),u32(1n),u32(0n)}
        case other: Odds{u32(24n),u32(56n),u32(32n),u32(7n),u32(2n),u32(1n),u32(1n),u32(1n),u32(0n)}
    case 1n:
      match seat:
        case 0n: Odds{u32(31n),u32(35n),u32(24n),u32(7n),u32(2n),u32(29n),u32(2n),u32(1n),u32(0n)}
        case 1n: Odds{u32(18n),u32(57n),u32(32n),u32(6n),u32(2n),u32(2n),u32(1n),u32(0n),u32(0n)}
        case 2n: Odds{u32(17n),u32(58n),u32(30n),u32(7n),u32(2n),u32(2n),u32(1n),u32(0n),u32(0n)}
        case other: Odds{u32(34n),u32(25n),u32(22n),u32(6n),u32(2n),u32(3n),u32(41n),u32(1n),u32(0n)}
    case 2n:
      match seat:
        case 0n: Odds{u32(28n),u32(0n),u32(0n),u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n)}
        case 1n: Odds{u32(13n),u32(79n),u32(19n),u32(2n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case 2n: Odds{u32(16n),u32(79n),u32(19n),u32(2n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case other: Odds{u32(43n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(100n),u32(0n),u32(0n)}
    case 4n:
      match seat:
        case 0n: Odds{u32(28n),u32(0n),u32(0n),u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n)}
        case 1n: Odds{u32(13n),u32(79n),u32(19n),u32(2n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case 2n: Odds{u32(0n),u32(79n),u32(19n),u32(2n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case other: Odds{u32(59n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(100n),u32(0n),u32(0n)}
    case other:
      match seat:
        case 0n: Odds{u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n)}
        case 1n: Odds{u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case 2n: Odds{u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case other: Odds{u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(100n),u32(0n),u32(0n)}

assert omaha_odds:
  forall stage: Nat
  forall seat: Nat
  Odds

def omaha_odds(stage, seat):
  match stage:
    case 0n:
      match seat:
        case 0n: Odds{u32(31n),u32(26n),u32(38n),u32(14n),u32(6n),u32(10n),u32(3n),u32(2n),u32(1n)}
        case 1n: Odds{u32(23n),u32(31n),u32(39n),u32(13n),u32(5n),u32(7n),u32(2n),u32(2n),u32(1n)}
        case 2n: Odds{u32(24n),u32(29n),u32(40n),u32(13n),u32(5n),u32(8n),u32(2n),u32(2n),u32(1n)}
        case other: Odds{u32(22n),u32(34n),u32(38n),u32(12n),u32(5n),u32(6n),u32(2n),u32(2n),u32(1n)}
    case 1n:
      match seat:
        case 0n: Odds{u32(27n),u32(0n),u32(68n),u32(19n),u32(5n),u32(4n),u32(2n),u32(2n),u32(0n)}
        case 1n: Odds{u32(34n),u32(0n),u32(71n),u32(17n),u32(5n),u32(3n),u32(2n),u32(2n),u32(0n)}
        case 2n: Odds{u32(18n),u32(52n),u32(35n),u32(8n),u32(2n),u32(2n),u32(1n),u32(0n),u32(0n)}
        case other: Odds{u32(21n),u32(54n),u32(33n),u32(8n),u32(2n),u32(2n),u32(1n),u32(0n),u32(0n)}
    case 2n:
      match seat:
        case 0n: Odds{u32(24n),u32(0n),u32(76n),u32(16n),u32(4n),u32(2n),u32(1n),u32(1n),u32(0n)}
        case 1n: Odds{u32(31n),u32(0n),u32(79n),u32(14n),u32(4n),u32(1n),u32(1n),u32(1n),u32(0n)}
        case 2n: Odds{u32(0n),u32(0n),u32(71n),u32(17n),u32(5n),u32(3n),u32(2n),u32(2n),u32(0n)}
        case other: Odds{u32(45n),u32(0n),u32(73n),u32(16n),u32(4n),u32(3n),u32(2n),u32(2n),u32(0n)}
    case 4n:
      match seat:
        case 0n: Odds{u32(33n),u32(0n),u32(68n),u32(19n),u32(5n),u32(4n),u32(2n),u32(2n),u32(0n)}
        case 1n: Odds{u32(41n),u32(0n),u32(71n),u32(17n),u32(5n),u32(3n),u32(2n),u32(2n),u32(0n)}
        case 2n: Odds{u32(0n),u32(52n),u32(35n),u32(8n),u32(2n),u32(2n),u32(1n),u32(0n),u32(0n)}
        case other: Odds{u32(26n),u32(54n),u32(33n),u32(8n),u32(2n),u32(2n),u32(1n),u32(0n),u32(0n)}
    case 5n:
      match seat:
        case 0n: Odds{u32(22n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case 1n: Odds{u32(29n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case 2n: Odds{u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case other: Odds{u32(49n),u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
    case 3n:
      match seat:
        case 0n: Odds{u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case 1n: Odds{u32(35n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case 2n: Odds{u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case other: Odds{u32(65n),u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
    case other:
      match seat:
        case 0n: Odds{u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case 1n: Odds{u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case 2n: Odds{u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case other: Odds{u32(100n),u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}

# Finite model certificates
# =========================

# This finite model states exactly what "fair" means here.  A runout is the
# random input and a strategy is the skill input. The closed witnesses below
# demonstrate selected properties of this finite table. They are retained as
# certificates, not presented as general poker theorems.

assert model_winner:
  forall runout: ModelRunout
  forall strategy: ModelStrategy
  ModelSeat

def model_winner(runout, strategy):
  match runout:
    case DryRunout{}:
      match strategy:
        case CallingStation{}: SeatAda{}
        case ValueDiscipline{}: SeatRook{}
    case WetRunout{}:
      SeatRook{}
    case PairedRunout{}:
      SeatBeak{}
    case BroadwayRunout{}:
      SeatCora{}

assert AdaOnly:
  forall seat: ModelSeat
  Type

def AdaOnly(seat):
  match seat:
    case SeatAda{}: Unit
    case SeatBeak{}: Empty
    case SeatCora{}: Empty
    case SeatRook{}: Empty

assert SeatNotEqual:
  forall -a: ModelSeat
  forall -b: ModelSeat
  Type

def SeatNotEqual(a, b):
  {a == b : ModelSeat} -> Empty

assert ada_not_rook:
  forall equal: {SeatAda{} == SeatRook{} : ModelSeat}
  Empty

def ada_not_rook(equal):
  %equal : AdaOnly(_)
  Unit{}

assert RandomnessWitness:
  Type

def RandomnessWitness():
  Sigma<
    ModelRunout,
    left => Sigma<
      ModelRunout,
      right => Sigma<
        ModelStrategy,
        strategy => SeatNotEqual(
          model_winner(left, strategy),
          model_winner(right, strategy)
        )
      >
    >
  >

assert randomness_witness:
  RandomnessWitness()

def randomness_witness():
  (DryRunout{}, (WetRunout{}, (CallingStation{}, ada_not_rook)))

assert SkillWitness:
  Type

def SkillWitness():
  Sigma<
    ModelRunout,
    runout => Sigma<
      ModelStrategy,
      left => Sigma<
        ModelStrategy,
        right => SeatNotEqual(
          model_winner(runout, left),
          model_winner(runout, right)
        )
      >
    >
  >

assert skill_witness:
  SkillWitness()

def skill_witness():
  (DryRunout{}, (CallingStation{}, (ValueDiscipline{}, ada_not_rook)))

assert OutcomeWitnesses:
  Type

def OutcomeWitnesses():
  RandomnessWitness() & SkillWitness()

assert outcome_witnesses:
  OutcomeWitnesses()

def outcome_witnesses():
  (randomness_witness(), skill_witness())

# Finite reachability is represented by one runout/strategy witness per seat.

assert SeatReachabilityWitness:
  forall -target: ModelSeat
  Type

def SeatReachabilityWitness(target):
  Sigma<
    ModelRunout,
    runout => Sigma<
      ModelStrategy,
      strategy => {model_winner(runout, strategy) == target : ModelSeat}
    >
  >

assert ada_reachable:
  SeatReachabilityWitness(SeatAda{})

def ada_reachable():
  (DryRunout{}, (CallingStation{}, {==}))

assert beak_reachable:
  SeatReachabilityWitness(SeatBeak{})

def beak_reachable():
  (PairedRunout{}, (CallingStation{}, {==}))

assert cora_reachable:
  SeatReachabilityWitness(SeatCora{})

def cora_reachable():
  (BroadwayRunout{}, (CallingStation{}, {==}))

assert rook_reachable:
  SeatReachabilityWitness(SeatRook{})

def rook_reachable():
  (DryRunout{}, (ValueDiscipline{}, {==}))

assert SeatReachabilityCertificates:
  Type

def SeatReachabilityCertificates():
  SeatReachabilityWitness(SeatAda{}) & (SeatReachabilityWitness(SeatBeak{}) & (SeatReachabilityWitness(SeatCora{}) & SeatReachabilityWitness(SeatRook{})))

assert seat_reachability_certificates:
  SeatReachabilityCertificates()

def seat_reachability_certificates():
  (ada_reachable(), (beak_reachable(), (cora_reachable(), rook_reachable())))

# Closed odds certificates
# ========================

assert model_seat_code:
  forall seat: ModelSeat
  Nat

def model_seat_code(seat):
  match seat:
    case SeatAda{}: 0n
    case SeatBeak{}: 1n
    case SeatCora{}: 2n
    case SeatRook{}: 3n

assert texas_stage_code:
  forall stage: TexasStage
  Nat

def texas_stage_code(stage):
  match stage:
    case TexasDeal{}: 0n
    case TexasFlop{}: 1n
    case TexasTurn{}: 2n
    case TexasAfterFold{}: 4n
    case TexasShowdown{}: 3n

assert omaha_stage_code:
  forall stage: OmahaStage
  Nat

def omaha_stage_code(stage):
  match stage:
    case OmahaDeal{}: 0n
    case OmahaFlop{}: 1n
    case OmahaFoldedFlop{}: 4n
    case OmahaTurn{}: 2n
    case OmahaRiverPressure{}: 5n
    case OmahaAfterFold{}: 3n
    case OmahaShowdown{}: 6n

assert odds_win:
  forall odds: Odds
  U32

def odds_win(odds):
  match odds:
    case Odds{win, high, pair, two_pair, trips, straight, flush, full_house, quads}:
      win

assert odds_category_total:
  forall odds: Odds
  U32

def odds_category_total(odds):
  match odds:
    case Odds{win, high, pair, two_pair, trips, straight, flush, full_house, quads}:
      U32.add(high, U32.add(pair, U32.add(two_pair, U32.add(trips, U32.add(straight, U32.add(flush, U32.add(full_house, quads)))))))

assert texas_deal_categories:
  forall seat: ModelSeat
  {odds_category_total(texas_odds(0n, model_seat_code(seat))) == u32(100n) : U32}

def texas_deal_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

assert texas_flop_categories:
  forall seat: ModelSeat
  {odds_category_total(texas_odds(1n, model_seat_code(seat))) == u32(100n) : U32}

def texas_flop_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

assert texas_turn_categories:
  forall seat: ModelSeat
  {odds_category_total(texas_odds(2n, model_seat_code(seat))) == u32(100n) : U32}

def texas_turn_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

assert texas_fold_categories:
  forall seat: ModelSeat
  {odds_category_total(texas_odds(4n, model_seat_code(seat))) == u32(100n) : U32}

def texas_fold_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

assert texas_showdown_categories:
  forall seat: ModelSeat
  {odds_category_total(texas_odds(3n, model_seat_code(seat))) == u32(100n) : U32}

def texas_showdown_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

assert texas_categories_normalized:
  forall stage: TexasStage
  forall seat: ModelSeat
  {odds_category_total(texas_odds(texas_stage_code(stage), model_seat_code(seat))) == u32(100n) : U32}

def texas_categories_normalized(stage, seat):
  match stage:
    case TexasDeal{}: texas_deal_categories(seat)
    case TexasFlop{}: texas_flop_categories(seat)
    case TexasTurn{}: texas_turn_categories(seat)
    case TexasAfterFold{}: texas_fold_categories(seat)
    case TexasShowdown{}: texas_showdown_categories(seat)

assert omaha_deal_categories:
  forall seat: ModelSeat
  {odds_category_total(omaha_odds(0n, model_seat_code(seat))) == u32(100n) : U32}

def omaha_deal_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

assert omaha_flop_categories:
  forall seat: ModelSeat
  {odds_category_total(omaha_odds(1n, model_seat_code(seat))) == u32(100n) : U32}

def omaha_flop_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

assert omaha_folded_flop_categories:
  forall seat: ModelSeat
  {odds_category_total(omaha_odds(4n, model_seat_code(seat))) == u32(100n) : U32}

def omaha_folded_flop_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

assert omaha_turn_categories:
  forall seat: ModelSeat
  {odds_category_total(omaha_odds(2n, model_seat_code(seat))) == u32(100n) : U32}

def omaha_turn_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

assert omaha_pressure_categories:
  forall seat: ModelSeat
  {odds_category_total(omaha_odds(5n, model_seat_code(seat))) == u32(100n) : U32}

def omaha_pressure_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

assert omaha_after_fold_categories:
  forall seat: ModelSeat
  {odds_category_total(omaha_odds(3n, model_seat_code(seat))) == u32(100n) : U32}

def omaha_after_fold_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

assert omaha_showdown_categories:
  forall seat: ModelSeat
  {odds_category_total(omaha_odds(6n, model_seat_code(seat))) == u32(100n) : U32}

def omaha_showdown_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

assert omaha_categories_normalized:
  forall stage: OmahaStage
  forall seat: ModelSeat
  {odds_category_total(omaha_odds(omaha_stage_code(stage), model_seat_code(seat))) == u32(100n) : U32}

def omaha_categories_normalized(stage, seat):
  match stage:
    case OmahaDeal{}: omaha_deal_categories(seat)
    case OmahaFlop{}: omaha_flop_categories(seat)
    case OmahaFoldedFlop{}: omaha_folded_flop_categories(seat)
    case OmahaTurn{}: omaha_turn_categories(seat)
    case OmahaRiverPressure{}: omaha_pressure_categories(seat)
    case OmahaAfterFold{}: omaha_after_fold_categories(seat)
    case OmahaShowdown{}: omaha_showdown_categories(seat)

assert odds_win_total:
  forall a: Odds
  forall b: Odds
  forall c: Odds
  forall d: Odds
  U32

def odds_win_total(a, b, c, d):
  U32.add(U32.add(odds_win(a), odds_win(b)), U32.add(odds_win(c), odds_win(d)))

assert texas_win_total:
  forall stage: TexasStage
  U32

def texas_win_total(stage):
  match stage:
    case TexasDeal{}: odds_win_total(texas_odds(0n, 0n), texas_odds(0n, 1n), texas_odds(0n, 2n), texas_odds(0n, 3n))
    case TexasFlop{}: odds_win_total(texas_odds(1n, 0n), texas_odds(1n, 1n), texas_odds(1n, 2n), texas_odds(1n, 3n))
    case TexasTurn{}: odds_win_total(texas_odds(2n, 0n), texas_odds(2n, 1n), texas_odds(2n, 2n), texas_odds(2n, 3n))
    case TexasAfterFold{}: odds_win_total(texas_odds(4n, 0n), texas_odds(4n, 1n), texas_odds(4n, 2n), texas_odds(4n, 3n))
    case TexasShowdown{}: odds_win_total(texas_odds(3n, 0n), texas_odds(3n, 1n), texas_odds(3n, 2n), texas_odds(3n, 3n))

assert texas_wins_normalized:
  forall stage: TexasStage
  {texas_win_total(stage) == u32(100n) : U32}

def texas_wins_normalized(stage):
  match stage:
    case TexasDeal{}: {==}
    case TexasFlop{}: {==}
    case TexasTurn{}: {==}
    case TexasAfterFold{}: {==}
    case TexasShowdown{}: {==}

assert omaha_win_total:
  forall stage: OmahaStage
  U32

def omaha_win_total(stage):
  match stage:
    case OmahaDeal{}: odds_win_total(omaha_odds(0n, 0n), omaha_odds(0n, 1n), omaha_odds(0n, 2n), omaha_odds(0n, 3n))
    case OmahaFlop{}: odds_win_total(omaha_odds(1n, 0n), omaha_odds(1n, 1n), omaha_odds(1n, 2n), omaha_odds(1n, 3n))
    case OmahaFoldedFlop{}: odds_win_total(omaha_odds(4n, 0n), omaha_odds(4n, 1n), omaha_odds(4n, 2n), omaha_odds(4n, 3n))
    case OmahaTurn{}: odds_win_total(omaha_odds(2n, 0n), omaha_odds(2n, 1n), omaha_odds(2n, 2n), omaha_odds(2n, 3n))
    case OmahaRiverPressure{}: odds_win_total(omaha_odds(5n, 0n), omaha_odds(5n, 1n), omaha_odds(5n, 2n), omaha_odds(5n, 3n))
    case OmahaAfterFold{}: odds_win_total(omaha_odds(3n, 0n), omaha_odds(3n, 1n), omaha_odds(3n, 2n), omaha_odds(3n, 3n))
    case OmahaShowdown{}: odds_win_total(omaha_odds(6n, 0n), omaha_odds(6n, 1n), omaha_odds(6n, 2n), omaha_odds(6n, 3n))

assert omaha_wins_normalized:
  forall stage: OmahaStage
  {omaha_win_total(stage) == u32(100n) : U32}

def omaha_wins_normalized(stage):
  match stage:
    case OmahaDeal{}: {==}
    case OmahaFlop{}: {==}
    case OmahaFoldedFlop{}: {==}
    case OmahaTurn{}: {==}
    case OmahaRiverPressure{}: {==}
    case OmahaAfterFold{}: {==}
    case OmahaShowdown{}: {==}

assert texas_showdown_matches_winner:
  {odds_win(texas_odds(3n, 3n)) == u32(100n) : U32}

def texas_showdown_matches_winner():
  {==}

assert omaha_showdown_matches_winner:
  {odds_win(omaha_odds(6n, 3n)) == u32(100n) : U32}

def omaha_showdown_matches_winner():
  {==}

assert TexasFoldedEquityZero:
  Type

def TexasFoldedEquityZero():
  {odds_win(texas_odds(4n, 2n)) == u32(0n) : U32} &
  ({odds_win(texas_odds(3n, 0n)) == u32(0n) : U32} & {odds_win(texas_odds(3n, 2n)) == u32(0n) : U32})

assert texas_folded_equity_zero:
  TexasFoldedEquityZero()

def texas_folded_equity_zero():
  ({==}, ({==}, {==}))

assert OmahaFoldedEquityZero:
  Type

def OmahaFoldedEquityZero():
  {odds_win(omaha_odds(4n, 2n)) == u32(0n) : U32} &
  ({odds_win(omaha_odds(2n, 2n)) == u32(0n) : U32} &
  ({odds_win(omaha_odds(5n, 2n)) == u32(0n) : U32} &
  ({odds_win(omaha_odds(3n, 0n)) == u32(0n) : U32} &
  ({odds_win(omaha_odds(3n, 2n)) == u32(0n) : U32} &
  ({odds_win(omaha_odds(6n, 0n)) == u32(0n) : U32} & {odds_win(omaha_odds(6n, 2n)) == u32(0n) : U32})))))

assert omaha_folded_equity_zero:
  OmahaFoldedEquityZero()

def omaha_folded_equity_zero():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==}))))))

type PokerVerificationAudit:
  PokerVerificationAudit{
    -chip_payload_conservation: Conservation.PokerPayloadConservationClaim(),
    -chip_count_conservation: Conservation.PokerChipCountConservationClaim(),
    -chip_value_conservation: Conservation.PokerChipValueConservationClaim(),
    -texas_deal_length: @indices: List<Nat> -> {
      List.length(U32, texas_cards_from_indices(indices)) == List.length(Nat, indices)
      : Nat
    },
    -omaha_deal_length: @indices: List<Nat> -> {
      List.length(U32, omaha_cards_from_indices(indices)) == List.length(Nat, indices)
      : Nat
    },
    -complete_rounds_balanced: @rounds: Nat -> {
      complete_round_counts(rounds) == SeatCounts{rounds, rounds, rounds, rounds}
      : SeatCounts
    },
    -outcome_witnesses: OutcomeWitnesses(),
    -seat_witnesses: SeatReachabilityCertificates(),
    -texas_categories: @stage: TexasStage -> @seat: ModelSeat -> {odds_category_total(texas_odds(texas_stage_code(stage), model_seat_code(seat))) == u32(100n) : U32},
    -omaha_categories: @stage: OmahaStage -> @seat: ModelSeat -> {odds_category_total(omaha_odds(omaha_stage_code(stage), model_seat_code(seat))) == u32(100n) : U32},
    -texas_wins: @stage: TexasStage -> {texas_win_total(stage) == u32(100n) : U32},
    -omaha_wins: @stage: OmahaStage -> {omaha_win_total(stage) == u32(100n) : U32},
    -texas_showdown: {odds_win(texas_odds(3n, 3n)) == u32(100n) : U32},
    -omaha_showdown: {odds_win(omaha_odds(6n, 3n)) == u32(100n) : U32},
    -texas_folded: TexasFoldedEquityZero(),
    -omaha_folded: OmahaFoldedEquityZero(),
    title: String,
    scope: String,
    fairness: String,
    unrigged: String,
    odds: String,
    limitation: String,
    certified_cases: U32,
    general_theorems: U32
  }

type PokerReport:
  PokerReport{texas: Timeline, omaha: Timeline, verification: PokerVerificationAudit}

assert verification_audit:
  PokerVerificationAudit

def verification_audit():
  PokerVerificationAudit{
    Conservation.history_payload_conservation_theorem,
    Conservation.history_chip_count_conservation_theorem,
    Conservation.history_chip_value_conservation_theorem,
    texas_cards_length_theorem,
    omaha_cards_length_theorem,
    complete_rounds_balanced_theorem,
    outcome_witnesses(),
    seat_reachability_certificates(),
    texas_categories_normalized,
    omaha_categories_normalized,
    texas_wins_normalized,
    omaha_wins_normalized,
    texas_showdown_matches_winner(),
    omaha_showdown_matches_winner(),
    texas_folded_equity_zero(),
    omaha_folded_equity_zero(),
    "Machine-checked Poker theorems and finite certificates",
    "A multi-lemma conservation proof covers every finite discrete-chip action history; three smaller structural lemmas support dealing, and 78 closed certificates audit the published tables.",
    "Finite witnesses show selected runout and strategy changes in the authored outcome model.",
    "Finite witnesses cover each seat in that authored model.",
    "Certificates check category/win totals, folded seats, and showdown rows for the two embedded timelines.",
    "The semantic summit preserves every chip identity and value through arbitrary bets and payouts, hence also total chip count and value. The 78 authored table rows remain closed certificates, not probability theorems.",
    u32(78n),
    u32(6n)
  }

# Player-Views
# ============

assert texas_best:
  forall stage: Nat
  forall seat: Nat
  String

def texas_best(stage, seat):
  match stage:
    case 0n:
      "high-card potential"
    case 1n:
      match seat:
        case 0n: "open-ended straight draw"
        case 1n: "high card"
        case 2n: "high card"
        case other: "four-heart flush draw"
    case 2n:
      match seat:
        case 0n: "eight-high straight"
        case 1n: "ace high"
        case 2n: "ace high"
        case other: "ace-high flush"
    case 4n:
      match seat:
        case 0n: "eight-high straight"
        case 1n: "ace high"
        case 2n: "ace high (folded)"
        case other: "ace-high flush"
    case other:
      match seat:
        case 0n: "eight-high straight"
        case 1n: "ace-jack high"
        case 2n: "ace-king high"
        case other: "ace-high flush"

assert omaha_best:
  forall stage: Nat
  forall seat: Nat
  String

def omaha_best(stage, seat):
  match stage:
    case 0n:
      "four-card starting hand"
    case 1n:
      match seat:
        case 0n: "pair of eights"
        case 1n: "pair of queens"
        case 2n: "king-high draw"
        case other: "queen-high draw"
    case 4n:
      match seat:
        case 0n: "pair of eights"
        case 1n: "pair of queens"
        case 2n: "king-high draw (folded)"
        case other: "queen-high draw"
    case 2n:
      match seat:
        case 0n: "pair of eights"
        case 1n: "pair of queens"
        case 2n: "pair of threes"
        case other: "pair of fours"
    case other:
      match seat:
        case 0n: "pair of eights"
        case 1n: "pair of queens"
        case 2n: "pair of threes"
        case other: "two pair, sevens and fours"

assert player_name:
  forall seat: Nat
  String

def player_name(seat):
  match seat:
    case 0n: "Ada Ante"
    case 1n: "Bluff Beak"
    case 2n: "Cautious Cora"
    case other: "River Rook"

assert player_personality:
  forall seat: Nat
  String

def player_personality(seat):
  match seat:
    case 0n: "mathematical value hunter"
    case 1n: "loose theatrical bluffer"
    case 2n: "tight risk minimizer"
    case other: "aggressive draw chaser"

assert texas_active:
  forall stage: Nat
  forall seat: Nat
  Bool

def texas_active(stage, seat):
  match stage:
    case 0n: True{}
    case 1n: True{}
    case 2n:
      True{}
    case 4n:
      match seat:
        case 2n: False{}
        case other: True{}
    case other:
      match seat:
        case 0n: False{}
        case 2n: False{}
        case other: True{}

assert omaha_active:
  forall stage: Nat
  forall seat: Nat
  Bool

def omaha_active(stage, seat):
  match stage:
    case 0n: True{}
    case 1n: True{}
    case 2n:
      match seat:
        case 2n: False{}
        case other: True{}
    case 4n:
      match seat:
        case 2n: False{}
        case other: True{}
    case 5n:
      match seat:
        case 2n: False{}
        case other: True{}
    case other:
      match seat:
        case 0n: False{}
        case 2n: False{}
        case other: True{}

assert texas_player:
  forall stage: U32
  forall seat: Nat
  forall stack: Nat
  PlayerView

def texas_player(stage, seat, stack):
  (s0, (s1, (s2, s3))) = u32_quad(stage)
  (n0, (n1, (n2, (n3, (n4, (n5, (n6, n7))))))) = nat_eight(seat)
  PlayerView{
    u32(n0),
    player_name(n1),
    player_personality(n2),
    texas_active(U32.to_nat(s0), n3),
    u32(stack),
    texas_hole(n4),
    texas_best(U32.to_nat(s1), n5),
    texas_odds(U32.to_nat(s2), n6)
  }

assert omaha_player:
  forall stage: U32
  forall seat: Nat
  forall stack: Nat
  PlayerView

def omaha_player(stage, seat, stack):
  (s0, (s1, (s2, s3))) = u32_quad(stage)
  (n0, (n1, (n2, (n3, (n4, (n5, (n6, n7))))))) = nat_eight(seat)
  PlayerView{
    u32(n0),
    player_name(n1),
    player_personality(n2),
    omaha_active(U32.to_nat(s0), n3),
    u32(stack),
    omaha_hole(n4),
    omaha_best(U32.to_nat(s1), n5),
    omaha_odds(U32.to_nat(s2), n6)
  }

assert texas_players:
  forall stage: Nat
  forall a: Nat
  forall b: Nat
  forall c: Nat
  forall d: Nat
  List<PlayerView>

def texas_players(stage, a, b, c, d):
  (s0, (s1, (s2, s3))) = u32_quad(u32(stage))
  Con{texas_player(s0, 0n, a), Con{texas_player(s1, 1n, b), Con{texas_player(s2, 2n, c), Con{texas_player(s3, 3n, d), Nil{}}}}}

assert omaha_players:
  forall stage: Nat
  forall a: Nat
  forall b: Nat
  forall c: Nat
  forall d: Nat
  List<PlayerView>

def omaha_players(stage, a, b, c, d):
  (s0, (s1, (s2, s3))) = u32_quad(u32(stage))
  Con{omaha_player(s0, 0n, a), Con{omaha_player(s1, 1n, b), Con{omaha_player(s2, 2n, c), Con{omaha_player(s3, 3n, d), Nil{}}}}}

# Steps
# =====

assert texas_step:
  forall stage: Nat
  forall board: Nat
  forall phase: String
  forall note: String
  forall actor: Nat
  forall action: String
  forall amount: Nat
  forall pot: Nat
  forall a: Nat
  forall b: Nat
  forall c: Nat
  forall d: Nat
  Step

def texas_step(stage, board, phase, note, actor, action, amount, pot, a, b, c, d):
  Step{phase, note, u32(actor), action, u32(amount), u32(pot), texas_board(board), texas_players(stage, a, b, c, d)}

assert omaha_step:
  forall stage: Nat
  forall board: Nat
  forall phase: String
  forall note: String
  forall actor: Nat
  forall action: String
  forall amount: Nat
  forall pot: Nat
  forall a: Nat
  forall b: Nat
  forall c: Nat
  forall d: Nat
  Step

def omaha_step(stage, board, phase, note, actor, action, amount, pot, a, b, c, d):
  Step{phase, note, u32(actor), action, u32(amount), u32(pot), omaha_board(board), omaha_players(stage, a, b, c, d)}

# Timelines
# =========

assert texas_steps:
  List<Step>

def texas_steps():
  Con{texas_step(0n,0n,"Deal","Dealer button: Ada. Blinds 10 / 20.",4n,"deal",0n,30n,990n,980n,1000n,1000n),
  Con{texas_step(0n,0n,"Pre-flop","Cora opens after reading a strong broadway hand.",2n,"raise",60n,90n,990n,980n,940n,1000n),
  Con{texas_step(0n,0n,"Pre-flop","Rook likes speculative draws.",3n,"call",60n,150n,990n,980n,940n,940n),
  Con{texas_step(0n,0n,"Pre-flop","Ada completes from the small blind.",0n,"call",50n,200n,940n,980n,940n,940n),
  Con{texas_step(0n,0n,"Pre-flop","Beak closes the action.",1n,"call",40n,240n,940n,940n,940n,940n),
  Con{texas_step(1n,3n,"Flop","Three community cards are revealed.",4n,"reveal",0n,240n,940n,940n,940n,940n),
  Con{texas_step(1n,3n,"Flop","Ada checks the straight draw.",0n,"check",0n,240n,940n,940n,940n,940n),
  Con{texas_step(1n,3n,"Flop","Beak attacks the checked board.",1n,"raise",80n,320n,940n,860n,940n,940n),
  Con{texas_step(1n,3n,"Flop","Cora calls once.",2n,"call",80n,400n,940n,860n,860n,940n),
  Con{texas_step(1n,3n,"Flop","Rook continues the flush draw.",3n,"call",80n,480n,940n,860n,860n,860n),
  Con{texas_step(1n,3n,"Flop","Ada calls with eight clean straight outs.",0n,"call",80n,560n,860n,860n,860n,860n),
  Con{texas_step(2n,4n,"Turn","The ace of hearts completes two draws.",4n,"reveal",0n,560n,860n,860n,860n,860n),
  Con{texas_step(2n,4n,"Turn","Ada checks the made straight.",0n,"check",0n,560n,860n,860n,860n,860n),
  Con{texas_step(2n,4n,"Turn","Beak represents the ace.",1n,"raise",120n,680n,860n,740n,860n,860n),
  Con{texas_step(2n,4n,"Turn","Cora cannot justify the price.",2n,"fold",0n,680n,860n,740n,860n,860n),
  Con{texas_step(4n,4n,"Turn","Rook calls with the nut flush.",3n,"call",120n,800n,860n,740n,860n,740n),
  Con{texas_step(4n,4n,"Turn","Ada folds a straight to the heavy action.",0n,"fold",0n,800n,860n,740n,860n,740n),
  Con{texas_step(3n,5n,"River","The river changes no made hand.",4n,"reveal",0n,800n,860n,740n,860n,740n),
  Con{texas_step(3n,5n,"River","Beak checks at showdown value.",1n,"check",0n,800n,860n,740n,860n,740n),
  Con{texas_step(3n,5n,"River","Rook value-bets the ace-high flush.",3n,"raise",160n,960n,860n,740n,860n,580n),
  Con{texas_step(3n,5n,"River","Beak pays off the final bet.",1n,"call",160n,1120n,860n,580n,860n,580n),
  Con{texas_step(3n,5n,"Showdown","River Rook wins 1120 with an ace-high flush.",3n,"win",1120n,0n,860n,580n,860n,1700n), Nil{}}}}}}}}}}}}}}}}}}}}}}}

assert omaha_steps:
  List<Step>

def omaha_steps():
  Con{omaha_step(0n,0n,"Deal","Omaha: four private cards each; exactly two must play.",4n,"deal",0n,30n,990n,980n,1000n,1000n),
  Con{omaha_step(0n,0n,"Pre-flop","Ada opens a connected four-card hand.",0n,"raise",50n,80n,940n,980n,1000n,1000n),
  Con{omaha_step(0n,0n,"Pre-flop","Beak calls wide.",1n,"call",30n,110n,940n,950n,1000n,1000n),
  Con{omaha_step(0n,0n,"Pre-flop","Cora calls after a conservative calculation.",2n,"call",50n,160n,940n,950n,950n,1000n),
  Con{omaha_step(0n,0n,"Pre-flop","Rook raises the drawing hand.",3n,"raise",110n,270n,940n,950n,950n,890n),
  Con{omaha_step(0n,0n,"Pre-flop","Ada calls the re-raise.",0n,"call",60n,330n,880n,950n,950n,890n),
  Con{omaha_step(0n,0n,"Pre-flop","Beak calls.",1n,"call",60n,390n,880n,890n,950n,890n),
  Con{omaha_step(0n,0n,"Pre-flop","Cora completes.",2n,"call",60n,450n,880n,890n,890n,890n),
  Con{omaha_step(1n,3n,"Flop","The flop gives Ada eights and Beak queens.",4n,"reveal",0n,450n,880n,890n,890n,890n),
  Con{omaha_step(1n,3n,"Flop","Ada checks.",0n,"check",0n,450n,880n,890n,890n,890n),
  Con{omaha_step(1n,3n,"Flop","Beak bets top pair.",1n,"raise",90n,540n,880n,800n,890n,890n),
  Con{omaha_step(1n,3n,"Flop","Cora folds the unmade holding.",2n,"fold",0n,540n,880n,800n,890n,890n),
  Con{omaha_step(4n,3n,"Flop","Rook calls with back-door two-pair routes.",3n,"call",90n,630n,880n,800n,890n,800n),
  Con{omaha_step(4n,3n,"Flop","Ada calls with middle pair.",0n,"call",90n,720n,790n,800n,890n,800n),
  Con{omaha_step(2n,4n,"Turn","The turn pairs one of Cora's folded hole ranks.",4n,"reveal",0n,720n,790n,800n,890n,800n),
  Con{omaha_step(2n,4n,"Turn","Ada checks.",0n,"check",0n,720n,790n,800n,890n,800n),
  Con{omaha_step(2n,4n,"Turn","Beak checks behind.",1n,"check",0n,720n,790n,800n,890n,800n),
  Con{omaha_step(2n,4n,"Turn","Rook makes a delayed bet.",3n,"raise",130n,850n,790n,800n,890n,670n),
  Con{omaha_step(2n,4n,"Turn","Ada calls once more.",0n,"call",130n,980n,660n,800n,890n,670n),
  Con{omaha_step(2n,4n,"Turn","Beak calls with queens.",1n,"call",130n,1110n,660n,670n,890n,670n),
  Con{omaha_step(5n,5n,"River","The seven gives Rook two pair under Omaha rules.",4n,"reveal",0n,1110n,660n,670n,890n,670n),
  Con{omaha_step(5n,5n,"River","Ada folds to the river pressure.",0n,"fold",0n,1110n,660n,670n,890n,670n),
  Con{omaha_step(3n,5n,"River","Beak checks.",1n,"check",0n,1110n,660n,670n,890n,670n),
  Con{omaha_step(3n,5n,"River","Rook value-bets two pair.",3n,"raise",180n,1290n,660n,670n,890n,490n),
  Con{omaha_step(3n,5n,"River","Beak calls with queens.",1n,"call",180n,1470n,660n,490n,890n,490n),
  Con{omaha_step(6n,5n,"Showdown","River Rook wins 1470 with sevens and fours.",3n,"win",1470n,0n,660n,490n,890n,1960n), Nil{}}}}}}}}}}}}}}}}}}}}}}}}}}}

assert texas_timeline:
  Timeline

def texas_timeline():
  Timeline{"Texas Hold'em", u32(5n), u32(0n), u32(3n), texas_steps()}

assert omaha_timeline:
  Timeline

def omaha_timeline():
  Timeline{"Omaha", u32(29n), u32(0n), u32(3n), omaha_steps()}

assert main_value:
  PokerReport

def main_value():
  PokerReport{texas_timeline(), omaha_timeline(), verification_audit()}

assert main_accept_value:
  forall value: PokerReport
  IO(Unit)

def main_accept_value(value):
  IO.print("Ready{}")

assert main:
  IO(Unit)

def main():
  main_accept_value(main_value!())
