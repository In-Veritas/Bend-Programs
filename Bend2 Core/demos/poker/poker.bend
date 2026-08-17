import Base

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

type PokerReport:
  PokerReport{texas: Timeline, omaha: Timeline}

# U32-Helpers
# ===========

def u32_pair(value: U32) -> U32 & U32:
  ((a, ea), (b, eb)) = U32.copy(value)
  (a, b)

def u32_quad(value: U32) -> U32 & (U32 & (U32 & U32)):
  (a, rest) = u32_pair(value)
  (b, more) = u32_pair(rest)
  (c, d) = u32_pair(more)
  (a, (b, (c, d)))

def nat_pair(value: Nat) -> Nat & Nat:
  ((a, ea), (b, eb)) = Nat.copy(value)
  (a, b)

def nat_quad(value: Nat) -> Nat & (Nat & (Nat & Nat)):
  (a, rest) = nat_pair(value)
  (b, more) = nat_pair(rest)
  (c, d) = nat_pair(more)
  (a, (b, (c, d)))

def nat_eight(value: Nat) -> Nat & (Nat & (Nat & (Nat & (Nat & (Nat & (Nat & Nat)))))):
  (left, right) = nat_pair(value)
  (a, (b, (c, d))) = nat_quad(left)
  (e, (f, (g, h))) = nat_quad(right)
  (a, (b, (c, (d, (e, (f, (g, h)))))))

def u32(value: Nat) -> U32:
  U32.from_nat(value)

# List-Helpers
# ============

def cards0() -> List<U32>:
  Nil{}

def cards1(a: Nat) -> List<U32>:
  Con{u32(a), Nil{}}

def cards2(a: Nat, b: Nat) -> List<U32>:
  Con{u32(a), Con{u32(b), Nil{}}}

def cards3(a: Nat, b: Nat, c: Nat) -> List<U32>:
  Con{u32(a), Con{u32(b), Con{u32(c), Nil{}}}}

def cards4(a: Nat, b: Nat, c: Nat, d: Nat) -> List<U32>:
  Con{u32(a), Con{u32(b), Con{u32(c), Con{u32(d), Nil{}}}}}

def cards5(a: Nat, b: Nat, c: Nat, d: Nat, e: Nat) -> List<U32>:
  Con{u32(a), Con{u32(b), Con{u32(c), Con{u32(d), Con{u32(e), Nil{}}}}}}

# Deal
# ====

# Each deck is a full affine permutation: (seed + step * index) mod 52.
# Texas uses seed 5 / step 3; Omaha uses seed 29 / step 17. Both steps are
# coprime to 52, hence no card can repeat during the deal.

def texas_card(index: Nat) -> U32:
  U32.mod(U32.add(u32(5n), U32.mul(u32(3n), u32(index))), u32(52n))

def omaha_card(index: Nat) -> U32:
  U32.mod(U32.add(u32(29n), U32.mul(u32(17n), u32(index))), u32(52n))

def texas_hole(seat: Nat) -> List<U32>:
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

def omaha_hole(seat: Nat) -> List<U32>:
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

def texas_board(count: Nat) -> List<U32>:
  match count:
    case 0n:
      Nil{}
    case 1n:
      Con{texas_card(8n), Nil{}}
    case 2n:
      Con{texas_card(8n), Con{texas_card(9n), Nil{}}}
    case 3n:
      Con{texas_card(8n), Con{texas_card(9n), Con{texas_card(10n), Nil{}}}}
    case 4n:
      Con{texas_card(8n), Con{texas_card(9n), Con{texas_card(10n), Con{texas_card(11n), Nil{}}}}}
    case other:
      Con{texas_card(8n), Con{texas_card(9n), Con{texas_card(10n), Con{texas_card(11n), Con{texas_card(12n), Nil{}}}}}}

def omaha_board(count: Nat) -> List<U32>:
  match count:
    case 0n:
      Nil{}
    case 1n:
      Con{omaha_card(16n), Nil{}}
    case 2n:
      Con{omaha_card(16n), Con{omaha_card(17n), Nil{}}}
    case 3n:
      Con{omaha_card(16n), Con{omaha_card(17n), Con{omaha_card(18n), Nil{}}}}
    case 4n:
      Con{omaha_card(16n), Con{omaha_card(17n), Con{omaha_card(18n), Con{omaha_card(19n), Nil{}}}}}
    case other:
      Con{omaha_card(16n), Con{omaha_card(17n), Con{omaha_card(18n), Con{omaha_card(19n), Con{omaha_card(20n), Nil{}}}}}}

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

def omaha_odds(stage: Nat, seat: Nat) -> Odds:
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
        case 1n: Odds{u32(31n),u32(0n),u32(78n),u32(14n),u32(4n),u32(1n),u32(1n),u32(1n),u32(0n)}
        case 2n: Odds{u32(19n),u32(0n),u32(71n),u32(17n),u32(5n),u32(3n),u32(2n),u32(2n),u32(0n)}
        case other: Odds{u32(26n),u32(0n),u32(73n),u32(16n),u32(4n),u32(3n),u32(2n),u32(2n),u32(0n)}
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
    case other:
      match seat:
        case 0n: Odds{u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case 1n: Odds{u32(35n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case 2n: Odds{u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}
        case other: Odds{u32(65n),u32(0n),u32(0n),u32(100n),u32(0n),u32(0n),u32(0n),u32(0n),u32(0n)}

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

def texas_player(stage: U32, seat: Nat, stack: Nat) -> PlayerView:
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

def omaha_player(stage: U32, seat: Nat, stack: Nat) -> PlayerView:
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

def texas_players(stage: Nat, a: Nat, b: Nat, c: Nat, d: Nat) -> List<PlayerView>:
  (s0, (s1, (s2, s3))) = u32_quad(u32(stage))
  Con{texas_player(s0, 0n, a), Con{texas_player(s1, 1n, b), Con{texas_player(s2, 2n, c), Con{texas_player(s3, 3n, d), Nil{}}}}}

def omaha_players(stage: Nat, a: Nat, b: Nat, c: Nat, d: Nat) -> List<PlayerView>:
  (s0, (s1, (s2, s3))) = u32_quad(u32(stage))
  Con{omaha_player(s0, 0n, a), Con{omaha_player(s1, 1n, b), Con{omaha_player(s2, 2n, c), Con{omaha_player(s3, 3n, d), Nil{}}}}}

# Steps
# =====

def texas_step(stage: Nat, board: Nat, phase: String, note: String, actor: Nat, action: String, amount: Nat, pot: Nat, a: Nat, b: Nat, c: Nat, d: Nat) -> Step:
  Step{phase, note, u32(actor), action, u32(amount), u32(pot), texas_board(board), texas_players(stage, a, b, c, d)}

def omaha_step(stage: Nat, board: Nat, phase: String, note: String, actor: Nat, action: String, amount: Nat, pot: Nat, a: Nat, b: Nat, c: Nat, d: Nat) -> Step:
  Step{phase, note, u32(actor), action, u32(amount), u32(pot), omaha_board(board), omaha_players(stage, a, b, c, d)}

# Timelines
# =========

def texas_steps() -> List<Step>:
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

def omaha_steps() -> List<Step>:
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
  Con{omaha_step(3n,5n,"Showdown","River Rook wins 1470 with sevens and fours.",3n,"win",1470n,0n,660n,490n,890n,1960n), Nil{}}}}}}}}}}}}}}}}}}}}}}}}}}}

def texas_timeline() -> Timeline:
  Timeline{"Texas Hold'em", u32(5n), u32(0n), u32(3n), texas_steps()}

def omaha_timeline() -> Timeline:
  Timeline{"Omaha", u32(29n), u32(0n), u32(3n), omaha_steps()}

def main() -> PokerReport:
  PokerReport{texas_timeline(), omaha_timeline()}
