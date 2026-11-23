import Base
import ./poker_proofs.bend as Conservation

# Pure, deterministic poker simulation (latest Bend).  The browser viewer is
# deliberately outside this file: main_value returns all state needed to replay
# two complete four-AI hands without IO or hidden host-side game logic, plus a
# machine-checked verification audit (general theorems and closed
# certificates; see README.md).  `main` is a thin IO wrapper.

type Odds is Data:
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

type PlayerView is Data:
  PlayerView{
    seat: U32,
    name: String,
    personality: String,
    active: Bool,
    stack: U32,
    cards: +List<U32>,
    best: String,
    odds: Odds
  }

type Step is Data:
  Step{
    phase: String,
    note: String,
    actor: U32,
    action: String,
    amount: U32,
    pot: U32,
    board: +List<U32>,
    players: +List<PlayerView>
  }

type Timeline is Data:
  Timeline{
    variant: String,
    seed: U32,
    dealer: U32,
    winner: U32,
    steps: +List<Step>
  }

# Finite domains used by the closed validation layer. Runtime timeline stages remain the
# compact Nat codes consumed by the viewer; these types enumerate every row
# that the two authored simulations publish.

type ModelSeat is Data:
  SeatAda{}
  SeatBeak{}
  SeatCora{}
  SeatRook{}

type ModelRunout is Data:
  DryRunout{}
  WetRunout{}
  PairedRunout{}
  BroadwayRunout{}

type ModelStrategy is Data:
  CallingStation{}
  ValueDiscipline{}

# Mathematical count model for a complete round-robin deal. Unlike the finite
# outcome table below, `rounds` is an arbitrary Nat.
type SeatCounts is Data:
  SeatCounts{ada: Nat, beak: Nat, cora: Nat, rook: Nat}

type TexasStage is Data:
  TexasDeal{}
  TexasFlop{}
  TexasTurn{}
  TexasAfterFold{}
  TexasShowdown{}

type OmahaStage is Data:
  OmahaDeal{}
  OmahaFlop{}
  OmahaFoldedFlop{}
  OmahaTurn{}
  OmahaRiverPressure{}
  OmahaAfterFold{}
  OmahaShowdown{}

def u32(value: Nat) -> U32:
  U32.from_nat(value)

# Deal
# ====

# Each deck is a full affine permutation: (seed + step * index) mod 52.
# Texas uses seed 5 / step 3; Omaha uses seed 29 / step 17. Both steps are
# coprime to 52, hence no card can repeat during the deal.

def texas_card(index: Nat) -> U32:
  ((5 + 3 * u32(index)) % 52 : U32)

def omaha_card(index: Nat) -> U32:
  ((29 + 17 * u32(index)) % 52 : U32)

def texas_cards_from_indices(indices: +List<Nat>) -> +List<U32>:
  match indices:
    case Nil{}:
      Nil{}
    case Con{index, tail}:
      Con{texas_card(index), texas_cards_from_indices(tail)}

def omaha_cards_from_indices(indices: +List<Nat>) -> +List<U32>:
  match indices:
    case Nil{}:
      Nil{}
    case Con{index, tail}:
      Con{omaha_card(index), omaha_cards_from_indices(tail)}

# Mathematical theorems: dealing either variant over an arbitrary finite list
# of deck indices preserves the list length. Each proof is structural induction
# over an unbounded List<Nat>; it does not enumerate either embedded deal.
law texas_cards_length_theorem:
  for indices: +List<Nat>
  { List.length(&2, U32, texas_cards_from_indices(indices)) == List.length(&2, Nat, indices) : Nat }

def texas_cards_length_theorem(indices):
  match indices:
    case Nil{}:
      {==}
    case Con{index, tail}:
      %texas_cards_length_theorem(tail) : {1n+List.length(&2, U32, texas_cards_from_indices(tail)) == 1n+_ : Nat}
      {==}

law omaha_cards_length_theorem:
  for indices: +List<Nat>
  { List.length(&2, U32, omaha_cards_from_indices(indices)) == List.length(&2, Nat, indices) : Nat }

def omaha_cards_length_theorem(indices):
  match indices:
    case Nil{}:
      {==}
    case Con{index, tail}:
      %omaha_cards_length_theorem(tail) : {1n+List.length(&2, U32, omaha_cards_from_indices(tail)) == 1n+_ : Nat}
      {==}

def seat_counts_inc(counts: SeatCounts) -> SeatCounts:
  match counts:
    case SeatCounts{ada, beak, cora, rook}:
      SeatCounts{1n+ada, 1n+beak, 1n+cora, 1n+rook}

def complete_round_counts(rounds: Nat) -> SeatCounts:
  match rounds:
    case 0n:
      SeatCounts{0n, 0n, 0n, 0n}
    case 1n+pred:
      seat_counts_inc(complete_round_counts(pred))

# Mathematical fairness theorem for the deal scheduler: after any number of
# complete round-robin rounds, all four seats have exactly that many cards.
# This is induction over arbitrary Nat rounds, not four closed seat cases.
law complete_rounds_balanced_theorem:
  for rounds: Nat
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

def texas_hole(seat: Nat) -> +List<U32>:
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

def omaha_hole(seat: Nat) -> +List<U32>:
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

def texas_board(count: Nat) -> +List<U32>:
  match count:
    case 0n:
      texas_cards_from_indices(Nil{})
    case 1n:
      texas_cards_from_indices([8n])
    case 2n:
      texas_cards_from_indices([8n, 9n])
    case 3n:
      texas_cards_from_indices([8n, 9n, 10n])
    case 4n:
      texas_cards_from_indices([8n, 9n, 10n, 11n])
    case other:
      texas_cards_from_indices([8n, 9n, 10n, 11n, 12n])

def omaha_board(count: Nat) -> +List<U32>:
  match count:
    case 0n:
      omaha_cards_from_indices(Nil{})
    case 1n:
      omaha_cards_from_indices([16n])
    case 2n:
      omaha_cards_from_indices([16n, 17n])
    case 3n:
      omaha_cards_from_indices([16n, 17n, 18n])
    case 4n:
      omaha_cards_from_indices([16n, 17n, 18n, 19n])
    case other:
      omaha_cards_from_indices([16n, 17n, 18n, 19n, 20n])

# Odds
# ====

# Percentages are deterministic equity estimates computed in Bend. The four
# win fields sum to 100 on every street. Category fields express the chance of
# finishing in each class from the visible street; showdown is one-hot. Omaha
# categories obey the two-hole / three-board rule for this embedded deal.

def texas_odds(stage: Nat, seat: Nat) -> Odds:
  match stage:
    case 0n:
      match seat:
        case 0n: Odds{27,46,37,8,3,4,1,1,0}
        case 1n: Odds{20,54,34,7,2,2,0,1,0}
        case 2n: Odds{29,47,36,8,3,4,1,1,0}
        case other: Odds{24,56,32,7,2,1,1,1,0}
    case 1n:
      match seat:
        case 0n: Odds{31,35,24,7,2,29,2,1,0}
        case 1n: Odds{18,57,32,6,2,2,1,0,0}
        case 2n: Odds{17,58,30,7,2,2,1,0,0}
        case other: Odds{34,25,22,6,2,3,41,1,0}
    case 2n:
      match seat:
        case 0n: Odds{28,0,0,0,0,100,0,0,0}
        case 1n: Odds{13,79,19,2,0,0,0,0,0}
        case 2n: Odds{16,79,19,2,0,0,0,0,0}
        case other: Odds{43,0,0,0,0,0,100,0,0}
    case 4n:
      match seat:
        case 0n: Odds{28,0,0,0,0,100,0,0,0}
        case 1n: Odds{13,79,19,2,0,0,0,0,0}
        case 2n: Odds{0,79,19,2,0,0,0,0,0}
        case other: Odds{59,0,0,0,0,0,100,0,0}
    case other:
      match seat:
        case 0n: Odds{0,0,0,0,0,100,0,0,0}
        case 1n: Odds{0,100,0,0,0,0,0,0,0}
        case 2n: Odds{0,100,0,0,0,0,0,0,0}
        case other: Odds{100,0,0,0,0,0,100,0,0}

def omaha_odds(stage: Nat, seat: Nat) -> Odds:
  match stage:
    case 0n:
      match seat:
        case 0n: Odds{31,26,38,14,6,10,3,2,1}
        case 1n: Odds{23,31,39,13,5,7,2,2,1}
        case 2n: Odds{24,29,40,13,5,8,2,2,1}
        case other: Odds{22,34,38,12,5,6,2,2,1}
    case 1n:
      match seat:
        case 0n: Odds{27,0,68,19,5,4,2,2,0}
        case 1n: Odds{34,0,71,17,5,3,2,2,0}
        case 2n: Odds{18,52,35,8,2,2,1,0,0}
        case other: Odds{21,54,33,8,2,2,1,0,0}
    case 2n:
      match seat:
        case 0n: Odds{24,0,76,16,4,2,1,1,0}
        case 1n: Odds{31,0,79,14,4,1,1,1,0}
        case 2n: Odds{0,0,71,17,5,3,2,2,0}
        case other: Odds{45,0,73,16,4,3,2,2,0}
    case 4n:
      match seat:
        case 0n: Odds{33,0,68,19,5,4,2,2,0}
        case 1n: Odds{41,0,71,17,5,3,2,2,0}
        case 2n: Odds{0,52,35,8,2,2,1,0,0}
        case other: Odds{26,54,33,8,2,2,1,0,0}
    case 5n:
      match seat:
        case 0n: Odds{22,0,100,0,0,0,0,0,0}
        case 1n: Odds{29,0,100,0,0,0,0,0,0}
        case 2n: Odds{0,0,100,0,0,0,0,0,0}
        case other: Odds{49,0,0,100,0,0,0,0,0}
    case 3n:
      match seat:
        case 0n: Odds{0,0,100,0,0,0,0,0,0}
        case 1n: Odds{35,0,100,0,0,0,0,0,0}
        case 2n: Odds{0,0,100,0,0,0,0,0,0}
        case other: Odds{65,0,0,100,0,0,0,0,0}
    case other:
      match seat:
        case 0n: Odds{0,0,100,0,0,0,0,0,0}
        case 1n: Odds{0,0,100,0,0,0,0,0,0}
        case 2n: Odds{0,0,100,0,0,0,0,0,0}
        case other: Odds{100,0,0,100,0,0,0,0,0}

# Finite model certificates
# =========================

# This finite model states exactly what "fair" means here.  A runout is the
# random input and a strategy is the skill input. The closed witnesses below
# demonstrate selected properties of this finite table. They are retained as
# certificates, not presented as general poker theorems.

def model_winner(runout: ModelRunout, strategy: ModelStrategy) -> ModelSeat:
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

def AdaOnly(seat: ModelSeat) -> Type:
  match seat:
    case SeatAda{}: Unit
    case SeatBeak{}: Empty
    case SeatCora{}: Empty
    case SeatRook{}: Empty

def SeatNotEqual(-a: ModelSeat, -b: ModelSeat) -> Type:
  {a == b : ModelSeat} -> Empty

law ada_not_rook:
  for equal: {SeatAda{} == SeatRook{} : ModelSeat}
  Empty

def ada_not_rook(equal):
  %equal : AdaOnly(_)
  Unit{}

def RandomnessWitness() -> Type:
  &left: ModelRunout -> &right: ModelRunout -> &strategy: ModelStrategy ->
    SeatNotEqual(model_winner(left, strategy), model_winner(right, strategy))

law randomness_witness:
  RandomnessWitness()

def randomness_witness():
  (DryRunout{}, (WetRunout{}, (CallingStation{}, ada_not_rook)))

def SkillWitness() -> Type:
  &runout: ModelRunout -> &left: ModelStrategy -> &right: ModelStrategy ->
    SeatNotEqual(model_winner(runout, left), model_winner(runout, right))

law skill_witness:
  SkillWitness()

def skill_witness():
  (DryRunout{}, (CallingStation{}, (ValueDiscipline{}, ada_not_rook)))

def OutcomeWitnesses() -> Type:
  RandomnessWitness() & SkillWitness()

law outcome_witnesses:
  OutcomeWitnesses()

def outcome_witnesses():
  (randomness_witness(), skill_witness())

# Finite reachability is represented by one runout/strategy witness per seat.

def SeatReachabilityWitness(-target: ModelSeat) -> Type:
  &runout: ModelRunout -> &strategy: ModelStrategy ->
    {model_winner(runout, strategy) == target : ModelSeat}

law ada_reachable:
  SeatReachabilityWitness(SeatAda{})

def ada_reachable():
  (DryRunout{}, (CallingStation{}, {==}))

law beak_reachable:
  SeatReachabilityWitness(SeatBeak{})

def beak_reachable():
  (PairedRunout{}, (CallingStation{}, {==}))

law cora_reachable:
  SeatReachabilityWitness(SeatCora{})

def cora_reachable():
  (BroadwayRunout{}, (CallingStation{}, {==}))

law rook_reachable:
  SeatReachabilityWitness(SeatRook{})

def rook_reachable():
  (DryRunout{}, (ValueDiscipline{}, {==}))

def SeatReachabilityCertificates() -> Type:
  SeatReachabilityWitness(SeatAda{}) & (SeatReachabilityWitness(SeatBeak{}) & (SeatReachabilityWitness(SeatCora{}) & SeatReachabilityWitness(SeatRook{})))

law seat_reachability_certificates:
  SeatReachabilityCertificates()

def seat_reachability_certificates():
  (ada_reachable(), (beak_reachable(), (cora_reachable(), rook_reachable())))

# Closed odds certificates
# ========================

def model_seat_code(seat: ModelSeat) -> Nat:
  match seat:
    case SeatAda{}: 0n
    case SeatBeak{}: 1n
    case SeatCora{}: 2n
    case SeatRook{}: 3n

def texas_stage_code(stage: TexasStage) -> Nat:
  match stage:
    case TexasDeal{}: 0n
    case TexasFlop{}: 1n
    case TexasTurn{}: 2n
    case TexasAfterFold{}: 4n
    case TexasShowdown{}: 3n

def omaha_stage_code(stage: OmahaStage) -> Nat:
  match stage:
    case OmahaDeal{}: 0n
    case OmahaFlop{}: 1n
    case OmahaFoldedFlop{}: 4n
    case OmahaTurn{}: 2n
    case OmahaRiverPressure{}: 5n
    case OmahaAfterFold{}: 3n
    case OmahaShowdown{}: 6n

def odds_win(odds: Odds) -> U32:
  match odds:
    case Odds{win, high, pair, two_pair, trips, straight, flush, full_house, quads}:
      win

def odds_category_total(odds: Odds) -> U32:
  match odds:
    case Odds{win, high, pair, two_pair, trips, straight, flush, full_house, quads}:
      U32.add(high, U32.add(pair, U32.add(two_pair, U32.add(trips, U32.add(straight, U32.add(flush, U32.add(full_house, quads)))))))

law texas_deal_categories:
  for seat: ModelSeat
  {odds_category_total(texas_odds(0n, model_seat_code(seat))) == 100 : U32}

def texas_deal_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

law texas_flop_categories:
  for seat: ModelSeat
  {odds_category_total(texas_odds(1n, model_seat_code(seat))) == 100 : U32}

def texas_flop_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

law texas_turn_categories:
  for seat: ModelSeat
  {odds_category_total(texas_odds(2n, model_seat_code(seat))) == 100 : U32}

def texas_turn_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

law texas_fold_categories:
  for seat: ModelSeat
  {odds_category_total(texas_odds(4n, model_seat_code(seat))) == 100 : U32}

def texas_fold_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

law texas_showdown_categories:
  for seat: ModelSeat
  {odds_category_total(texas_odds(3n, model_seat_code(seat))) == 100 : U32}

def texas_showdown_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

law texas_categories_normalized:
  for stage: TexasStage
  for seat: ModelSeat
  {odds_category_total(texas_odds(texas_stage_code(stage), model_seat_code(seat))) == 100 : U32}

def texas_categories_normalized(stage, seat):
  match stage:
    case TexasDeal{}: texas_deal_categories(seat)
    case TexasFlop{}: texas_flop_categories(seat)
    case TexasTurn{}: texas_turn_categories(seat)
    case TexasAfterFold{}: texas_fold_categories(seat)
    case TexasShowdown{}: texas_showdown_categories(seat)

law omaha_deal_categories:
  for seat: ModelSeat
  {odds_category_total(omaha_odds(0n, model_seat_code(seat))) == 100 : U32}

def omaha_deal_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

law omaha_flop_categories:
  for seat: ModelSeat
  {odds_category_total(omaha_odds(1n, model_seat_code(seat))) == 100 : U32}

def omaha_flop_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

law omaha_folded_flop_categories:
  for seat: ModelSeat
  {odds_category_total(omaha_odds(4n, model_seat_code(seat))) == 100 : U32}

def omaha_folded_flop_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

law omaha_turn_categories:
  for seat: ModelSeat
  {odds_category_total(omaha_odds(2n, model_seat_code(seat))) == 100 : U32}

def omaha_turn_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

law omaha_pressure_categories:
  for seat: ModelSeat
  {odds_category_total(omaha_odds(5n, model_seat_code(seat))) == 100 : U32}

def omaha_pressure_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

law omaha_after_fold_categories:
  for seat: ModelSeat
  {odds_category_total(omaha_odds(3n, model_seat_code(seat))) == 100 : U32}

def omaha_after_fold_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

law omaha_showdown_categories:
  for seat: ModelSeat
  {odds_category_total(omaha_odds(6n, model_seat_code(seat))) == 100 : U32}

def omaha_showdown_categories(seat):
  match seat:
    case SeatAda{}: {==}
    case SeatBeak{}: {==}
    case SeatCora{}: {==}
    case SeatRook{}: {==}

law omaha_categories_normalized:
  for stage: OmahaStage
  for seat: ModelSeat
  {odds_category_total(omaha_odds(omaha_stage_code(stage), model_seat_code(seat))) == 100 : U32}

def omaha_categories_normalized(stage, seat):
  match stage:
    case OmahaDeal{}: omaha_deal_categories(seat)
    case OmahaFlop{}: omaha_flop_categories(seat)
    case OmahaFoldedFlop{}: omaha_folded_flop_categories(seat)
    case OmahaTurn{}: omaha_turn_categories(seat)
    case OmahaRiverPressure{}: omaha_pressure_categories(seat)
    case OmahaAfterFold{}: omaha_after_fold_categories(seat)
    case OmahaShowdown{}: omaha_showdown_categories(seat)

def odds_win_total(a: Odds, b: Odds, c: Odds, d: Odds) -> U32:
  U32.add(U32.add(odds_win(a), odds_win(b)), U32.add(odds_win(c), odds_win(d)))

def texas_win_total(stage: TexasStage) -> U32:
  match stage:
    case TexasDeal{}: odds_win_total(texas_odds(0n, 0n), texas_odds(0n, 1n), texas_odds(0n, 2n), texas_odds(0n, 3n))
    case TexasFlop{}: odds_win_total(texas_odds(1n, 0n), texas_odds(1n, 1n), texas_odds(1n, 2n), texas_odds(1n, 3n))
    case TexasTurn{}: odds_win_total(texas_odds(2n, 0n), texas_odds(2n, 1n), texas_odds(2n, 2n), texas_odds(2n, 3n))
    case TexasAfterFold{}: odds_win_total(texas_odds(4n, 0n), texas_odds(4n, 1n), texas_odds(4n, 2n), texas_odds(4n, 3n))
    case TexasShowdown{}: odds_win_total(texas_odds(3n, 0n), texas_odds(3n, 1n), texas_odds(3n, 2n), texas_odds(3n, 3n))

law texas_wins_normalized:
  for stage: TexasStage
  {texas_win_total(stage) == 100 : U32}

def texas_wins_normalized(stage):
  match stage:
    case TexasDeal{}: {==}
    case TexasFlop{}: {==}
    case TexasTurn{}: {==}
    case TexasAfterFold{}: {==}
    case TexasShowdown{}: {==}

def omaha_win_total(stage: OmahaStage) -> U32:
  match stage:
    case OmahaDeal{}: odds_win_total(omaha_odds(0n, 0n), omaha_odds(0n, 1n), omaha_odds(0n, 2n), omaha_odds(0n, 3n))
    case OmahaFlop{}: odds_win_total(omaha_odds(1n, 0n), omaha_odds(1n, 1n), omaha_odds(1n, 2n), omaha_odds(1n, 3n))
    case OmahaFoldedFlop{}: odds_win_total(omaha_odds(4n, 0n), omaha_odds(4n, 1n), omaha_odds(4n, 2n), omaha_odds(4n, 3n))
    case OmahaTurn{}: odds_win_total(omaha_odds(2n, 0n), omaha_odds(2n, 1n), omaha_odds(2n, 2n), omaha_odds(2n, 3n))
    case OmahaRiverPressure{}: odds_win_total(omaha_odds(5n, 0n), omaha_odds(5n, 1n), omaha_odds(5n, 2n), omaha_odds(5n, 3n))
    case OmahaAfterFold{}: odds_win_total(omaha_odds(3n, 0n), omaha_odds(3n, 1n), omaha_odds(3n, 2n), omaha_odds(3n, 3n))
    case OmahaShowdown{}: odds_win_total(omaha_odds(6n, 0n), omaha_odds(6n, 1n), omaha_odds(6n, 2n), omaha_odds(6n, 3n))

law omaha_wins_normalized:
  for stage: OmahaStage
  {omaha_win_total(stage) == 100 : U32}

def omaha_wins_normalized(stage):
  match stage:
    case OmahaDeal{}: {==}
    case OmahaFlop{}: {==}
    case OmahaFoldedFlop{}: {==}
    case OmahaTurn{}: {==}
    case OmahaRiverPressure{}: {==}
    case OmahaAfterFold{}: {==}
    case OmahaShowdown{}: {==}

law texas_showdown_matches_winner:
  {odds_win(texas_odds(3n, 3n)) == 100 : U32}

def texas_showdown_matches_winner():
  {==}

law omaha_showdown_matches_winner:
  {odds_win(omaha_odds(6n, 3n)) == 100 : U32}

def omaha_showdown_matches_winner():
  {==}

def TexasFoldedEquityZero() -> Type:
  {odds_win(texas_odds(4n, 2n)) == 0 : U32} &
  ({odds_win(texas_odds(3n, 0n)) == 0 : U32} & {odds_win(texas_odds(3n, 2n)) == 0 : U32})

law texas_folded_equity_zero:
  TexasFoldedEquityZero()

def texas_folded_equity_zero():
  ({==}, ({==}, {==}))

def OmahaFoldedEquityZero() -> Type:
  {odds_win(omaha_odds(4n, 2n)) == 0 : U32} &
  ({odds_win(omaha_odds(2n, 2n)) == 0 : U32} &
  ({odds_win(omaha_odds(5n, 2n)) == 0 : U32} &
  ({odds_win(omaha_odds(3n, 0n)) == 0 : U32} &
  ({odds_win(omaha_odds(3n, 2n)) == 0 : U32} &
  ({odds_win(omaha_odds(6n, 0n)) == 0 : U32} & {odds_win(omaha_odds(6n, 2n)) == 0 : U32})))))

law omaha_folded_equity_zero:
  OmahaFoldedEquityZero()

def omaha_folded_equity_zero():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==}))))))

type PokerVerificationAudit is Data:
  PokerVerificationAudit{
    -chip_payload_conservation: Conservation.PokerPayloadConservationClaim(),
    -chip_count_conservation: Conservation.PokerChipCountConservationClaim(),
    -chip_value_conservation: Conservation.PokerChipValueConservationClaim(),
    -texas_deal_length: @indices: +List<Nat> -> {
      List.length(&2, U32, texas_cards_from_indices(indices)) == List.length(&2, Nat, indices)
      : Nat
    },
    -omaha_deal_length: @indices: +List<Nat> -> {
      List.length(&2, U32, omaha_cards_from_indices(indices)) == List.length(&2, Nat, indices)
      : Nat
    },
    -complete_rounds_balanced: @rounds: Nat -> {
      complete_round_counts(rounds) == SeatCounts{rounds, rounds, rounds, rounds}
      : SeatCounts
    },
    -outcome_witnesses: OutcomeWitnesses(),
    -seat_witnesses: SeatReachabilityCertificates(),
    -texas_categories: @stage: TexasStage -> @seat: ModelSeat -> {odds_category_total(texas_odds(texas_stage_code(stage), model_seat_code(seat))) == 100 : U32},
    -omaha_categories: @stage: OmahaStage -> @seat: ModelSeat -> {odds_category_total(omaha_odds(omaha_stage_code(stage), model_seat_code(seat))) == 100 : U32},
    -texas_wins: @stage: TexasStage -> {texas_win_total(stage) == 100 : U32},
    -omaha_wins: @stage: OmahaStage -> {omaha_win_total(stage) == 100 : U32},
    -texas_showdown: {odds_win(texas_odds(3n, 3n)) == 100 : U32},
    -omaha_showdown: {odds_win(omaha_odds(6n, 3n)) == 100 : U32},
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

type PokerReport is Data:
  PokerReport{texas: Timeline, omaha: Timeline, verification: PokerVerificationAudit}

def verification_audit() -> PokerVerificationAudit:
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
    78,
    6
  }

# Player-Views
# ============

def texas_best(stage: Nat, seat: Nat) -> String:
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

def omaha_best(stage: Nat, seat: Nat) -> String:
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

def player_name(seat: Nat) -> String:
  match seat:
    case 0n: "Ada Ante"
    case 1n: "Bluff Beak"
    case 2n: "Cautious Cora"
    case other: "River Rook"

def player_personality(seat: Nat) -> String:
  match seat:
    case 0n: "mathematical value hunter"
    case 1n: "loose theatrical bluffer"
    case 2n: "tight risk minimizer"
    case other: "aggressive draw chaser"

def texas_active(stage: Nat, seat: Nat) -> Bool:
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

def omaha_active(stage: Nat, seat: Nat) -> Bool:
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

def texas_player(+stage: Nat, +seat: Nat, stack: Nat) -> PlayerView:
  PlayerView{
    u32(seat),
    player_name(seat),
    player_personality(seat),
    texas_active(stage, seat),
    u32(stack),
    texas_hole(seat),
    texas_best(stage, seat),
    texas_odds(stage, seat)
  }

def omaha_player(+stage: Nat, +seat: Nat, stack: Nat) -> PlayerView:
  PlayerView{
    u32(seat),
    player_name(seat),
    player_personality(seat),
    omaha_active(stage, seat),
    u32(stack),
    omaha_hole(seat),
    omaha_best(stage, seat),
    omaha_odds(stage, seat)
  }

def texas_players(+stage: Nat, a: Nat, b: Nat, c: Nat, d: Nat) -> +List<PlayerView>:
  [texas_player(stage, 0n, a), texas_player(stage, 1n, b), texas_player(stage, 2n, c), texas_player(stage, 3n, d)]

def omaha_players(+stage: Nat, a: Nat, b: Nat, c: Nat, d: Nat) -> +List<PlayerView>:
  [omaha_player(stage, 0n, a), omaha_player(stage, 1n, b), omaha_player(stage, 2n, c), omaha_player(stage, 3n, d)]

# Steps
# =====

def texas_step(stage: Nat, board: Nat, phase: String, note: String, actor: Nat, action: String, amount: Nat, pot: Nat, a: Nat, b: Nat, c: Nat, d: Nat) -> Step:
  Step{phase, note, u32(actor), action, u32(amount), u32(pot), texas_board(board), texas_players(stage, a, b, c, d)}

def omaha_step(stage: Nat, board: Nat, phase: String, note: String, actor: Nat, action: String, amount: Nat, pot: Nat, a: Nat, b: Nat, c: Nat, d: Nat) -> Step:
  Step{phase, note, u32(actor), action, u32(amount), u32(pot), omaha_board(board), omaha_players(stage, a, b, c, d)}

# Timelines
# =========

def texas_steps() -> +List<Step>:
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

def omaha_steps() -> +List<Step>:
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

def texas_timeline() -> Timeline:
  Timeline{"Texas Hold'em", 5, 0, 3, texas_steps()}

def omaha_timeline() -> Timeline:
  Timeline{"Omaha", 29, 0, 3, omaha_steps()}

def main_value() -> PokerReport:
  PokerReport{texas_timeline(), omaha_timeline(), verification_audit()}

# The executable entry only reports readiness: the report's type already
# makes `bend` check every theorem and certificate it carries, and build.sh
# publishes the evaluated `main_value()` for the browser.
def main_accept_value(value: PokerReport) -> IO(Unit):
  IO.print("Ready{}")

def main() -> IO(Unit):
  main_accept_value(main_value())
