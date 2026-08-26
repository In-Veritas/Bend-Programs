import Base

# Heroes of Might and Magic III logic kernel for Bend2 Core.
# The browser passes the complete immutable Game value back to
# heroes_browser_step_func with one numeric command.  This file owns all
# movement, economy, recruitment, combat, progression, calendar and victory
# transitions; JavaScript only renders returned constructors.

# Types
# =====

type Owner:
  Neutral{}
  Red{}
  Blue{}

type Faction:
  Castle{}
  Necropolis{}

type Direction:
  North{}
  NorthEast{}
  East{}
  SouthEast{}
  South{}
  SouthWest{}
  West{}
  NorthWest{}

type Terrain:
  Grass{}
  Dirt{}
  Rough{}
  Swamp{}
  Water{}
  Rock{}

type Site:
  EmptySite{}
  RedTownSite{}
  BlueTownSite{}
  GoldPileSite{}
  WoodPileSite{}
  ShrineSite{}
  ArtifactSite{}
  SawmillSite{}
  GoldMineSite{}
  GuardianSite{}

type Cell:
  Cell{terrain: Terrain, site: Site, movement_cost: U32, passable: Bool}

type Resources:
  Resources{gold: U32, wood: U32, ore: U32, mercury: U32, sulfur: U32, crystal: U32, gems: U32}

type Payment:
  Payment{resources: Resources, paid: Bool}

type CreatureKind:
  Pikeman{}
  Archer{}
  Griffin{}
  Swordsman{}
  Monk{}
  Cavalier{}
  Angel{}
  Skeleton{}
  WalkingDead{}
  Wight{}
  Vampire{}
  Lich{}
  BlackKnight{}
  BoneDragon{}

type CreatureStats:
  CreatureStats{attack: U32, defense: U32, damage_min: U32, damage_max: U32, hit_points: U32, speed: U32, growth: U32, cost: U32, ranged: Bool}

type CreatureBundle:
  CreatureBundle{kind: CreatureKind, stats: CreatureStats}

type Stack:
  EmptyStack{}
  Troop{kind: CreatureKind, count: U32, first_unit_hp: U32}

type StackPair:
  StackPair{left: Stack, right: Stack}

type StackCheck:
  StackCheck{stack: Stack, empty: Bool}

type StackDamage:
  StackDamage{stack: Stack, kills: U32}

type Army:
  Army{s0: Stack, s1: Stack, s2: Stack, s3: Stack, s4: Stack, s5: Stack, s6: Stack}

type ArmySelection:
  ArmySelection{army: Army, selected: Stack}

type ArmyDamage:
  ArmyDamage{army: Army, kills: U32}

type ArmyCheck:
  ArmyCheck{army: Army, empty: Bool}

type Stock:
  Stock{t1: U32, t2: U32, t3: U32, t4: U32, t5: U32, t6: U32, t7: U32}

type StockSelection:
  StockSelection{stock: Stock, available: U32}

type StockTake:
  StockTake{stock: Stock, taken: Bool}

type Hero:
  Hero{name: String, x: U32, y: U32, movement: U32, attack: U32, defense: U32, power: U32, knowledge: U32, mana: U32, level: U32, experience: U32, army: Army}

type HeroMove:
  HeroMove{hero: Hero, x: U32, y: U32, moved: Bool}

type Coordinate:
  Coordinate{x: U32, y: U32, valid: Bool, diagonal: Bool}

type HeroCheck:
  HeroCheck{hero: Hero, valid: Bool}

type Town:
  Town{faction: Faction, hall: U32, fort: U32, dwellings: U32, built_today: Bool, stock: Stock}

type TownAction:
  TownAction{town: Town, resources: Resources, accepted: Bool, notice: String}

type Kingdom:
  Kingdom{resources: Resources, hero: Hero, town: Town}

type World:
  World{gold_pile: Bool, wood_pile: Bool, shrine: Bool, artifact: Bool, sawmill: Owner, gold_mine: Owner, guardian: Army}

type BattleSource:
  GuardianBattle{}
  EnemyTownBattle{}

type Battle:
  Battle{attacker: Owner, source: BattleSource, enemy: Army, round: U32}

type Phase:
  Adventure{}
  Combat{battle: Battle}
  Victory{winner: Owner}

type Game:
  Game{scenario: U32, day: U32, active: Owner, red: Kingdom, blue: Kingdom, world: World, phase: Phase, seed: U32, turn: U32, notice: String}

type RngStep:
  RngStep{value: U32, next: U32}

type AttackRoll:
  AttackRoll{damage: U32, next_seed: U32, valid: Bool}

type CombatTurn:
  CombatTurn{player: Army, enemy: Army, mana: U32, next_seed: U32, dealt: U32, received: U32, valid: Bool}

type BattleOutcome:
  BattleContinues{battle: Battle}
  BattleWon{attacker: Owner, source: BattleSource}
  BattleEnded{attacker: Owner, source: BattleSource, enemy: Army}

type KingdomBattle:
  KingdomBattle{kingdom: Kingdom, outcome: BattleOutcome, next_seed: U32, notice: String}

type MoveResult:
  MoveResult{kingdom: Kingdom, world: World, phase: Phase, notice: String}

type WorldIncome:
  WorldIncome{world: World, red_gold: U32, red_wood: U32, blue_gold: U32, blue_wood: U32}

type TownDay:
  TownDay{town: Town, income: U32}

# Constants
# =========

assert heroes_u32_func:
  forall value: Nat
  U32

def heroes_u32_func(value):
  U32.from_nat(value)

assert heroes_zero_stats_func:
  CreatureStats

def heroes_zero_stats_func():
  CreatureStats{0, 0, 0, 0, 1, 0, 0, 0, False{}}

# U32-Section
# ===========

assert u32_pair_func:
  forall value: U32
  U32 & U32

def u32_pair_func(value):
  ((left, left_exact), (right, right_exact)) = U32.copy(value)
  (left, right)

assert u32_min_func:
  forall +left: +U32
  forall +right: +U32
  U32

def u32_min_func(left, right):
  match U32.is_le(left, right):
    case True{}: left
    case False{}: right

assert u32_nonzero_func:
  forall value: U32
  Bool

def u32_nonzero_func(value):
  U32.is_ne(value, 0)

assert u32_at_least_one_func:
  forall +value: +U32
  U32

def u32_at_least_one_func(value):
  match U32.is_eq(value, 0):
    case True{}: 1
    case False{}: value

assert u32_coord_func:
  forall +x: +U32
  forall +y: +U32
  forall expected_x: U32
  forall expected_y: U32
  Bool

def u32_coord_func(x, y, expected_x, expected_y):
  Bool.and(U32.is_eq(x, expected_x), U32.is_eq(y, expected_y))

# Owner-Section
# =============

assert owner_pair_func:
  forall owner: Owner
  Owner & Owner

def owner_pair_func(owner):
  match owner:
    case Neutral{}: (Neutral{}, Neutral{})
    case Red{}: (Red{}, Red{})
    case Blue{}: (Blue{}, Blue{})

assert owner_other_func:
  forall owner: Owner
  Owner

def owner_other_func(owner):
  match owner:
    case Neutral{}: Neutral{}
    case Red{}: Blue{}
    case Blue{}: Red{}

# Faction-Section
# ===============

assert faction_pair_func:
  forall faction: Faction
  Faction & Faction

def faction_pair_func(faction):
  match faction:
    case Castle{}: (Castle{}, Castle{})
    case Necropolis{}: (Necropolis{}, Necropolis{})

# Resources-Section
# =================

assert resources_add_gold_func:
  forall resources: Resources
  forall amount: U32
  Resources

def resources_add_gold_func(resources, amount):
  match resources:
    case Resources{gold, wood, ore, mercury, sulfur, crystal, gems}:
      Resources{U32.add(gold, amount), wood, ore, mercury, sulfur, crystal, gems}

assert resources_add_wood_func:
  forall resources: Resources
  forall amount: U32
  Resources

def resources_add_wood_func(resources, amount):
  match resources:
    case Resources{gold, wood, ore, mercury, sulfur, crystal, gems}:
      Resources{gold, U32.add(wood, amount), ore, mercury, sulfur, crystal, gems}

assert resources_pay_values_func:
  forall +gold: +U32
  forall +wood: +U32
  forall +ore: +U32
  forall mercury: U32
  forall sulfur: U32
  forall crystal: U32
  forall gems: U32
  forall +gold_cost: +U32
  forall +wood_cost: +U32
  forall +ore_cost: +U32
  Payment

def resources_pay_values_func(gold, wood, ore, mercury, sulfur, crystal, gems, gold_cost, wood_cost, ore_cost):
  affordable = Bool.and(U32.is_le(gold_cost, gold), Bool.and(U32.is_le(wood_cost, wood), U32.is_le(ore_cost, ore)))
  match affordable:
    case False{}:
      Payment{Resources{gold, wood, ore, mercury, sulfur, crystal, gems}, False{}}
    case True{}:
      Payment{Resources{U32.sub(gold, gold_cost), U32.sub(wood, wood_cost), U32.sub(ore, ore_cost), mercury, sulfur, crystal, gems}, True{}}

assert resources_pay_func:
  forall resources: Resources
  forall gold_cost: U32
  forall wood_cost: U32
  forall ore_cost: U32
  Payment

def resources_pay_func(resources, gold_cost, wood_cost, ore_cost):
  match resources:
    case Resources{gold, wood, ore, mercury, sulfur, crystal, gems}:
      resources_pay_values_func(gold, wood, ore, mercury, sulfur, crystal, gems, gold_cost, wood_cost, ore_cost)

# CreatureKind-Section
# ====================

assert creature_kind_pair_func:
  forall kind: CreatureKind
  CreatureKind & CreatureKind

def creature_kind_pair_func(kind):
  match kind:
    case Pikeman{}: (Pikeman{}, Pikeman{})
    case Archer{}: (Archer{}, Archer{})
    case Griffin{}: (Griffin{}, Griffin{})
    case Swordsman{}: (Swordsman{}, Swordsman{})
    case Monk{}: (Monk{}, Monk{})
    case Cavalier{}: (Cavalier{}, Cavalier{})
    case Angel{}: (Angel{}, Angel{})
    case Skeleton{}: (Skeleton{}, Skeleton{})
    case WalkingDead{}: (WalkingDead{}, WalkingDead{})
    case Wight{}: (Wight{}, Wight{})
    case Vampire{}: (Vampire{}, Vampire{})
    case Lich{}: (Lich{}, Lich{})
    case BlackKnight{}: (BlackKnight{}, BlackKnight{})
    case BoneDragon{}: (BoneDragon{}, BoneDragon{})

assert creature_kind_stats_func:
  forall kind: CreatureKind
  CreatureBundle

def creature_kind_stats_func(kind):
  match kind:
    case Pikeman{}: CreatureBundle{Pikeman{}, CreatureStats{4, 5, 1, 3, 10, 4, 14, 60, False{}}}
    case Archer{}: CreatureBundle{Archer{}, CreatureStats{6, 3, 2, 3, 10, 4, 9, 100, True{}}}
    case Griffin{}: CreatureBundle{Griffin{}, CreatureStats{8, 8, 3, 6, 25, 6, 7, 200, False{}}}
    case Swordsman{}: CreatureBundle{Swordsman{}, CreatureStats{10, 12, 6, 9, 35, 5, 4, 300, False{}}}
    case Monk{}: CreatureBundle{Monk{}, CreatureStats{12, 7, 10, 12, 30, 5, 3, 400, True{}}}
    case Cavalier{}: CreatureBundle{Cavalier{}, CreatureStats{15, 15, 15, 25, 100, 7, 2, 1000, False{}}}
    case Angel{}: CreatureBundle{Angel{}, CreatureStats{20, 20, 50, 50, 200, 12, 1, 3000, False{}}}
    case Skeleton{}: CreatureBundle{Skeleton{}, CreatureStats{5, 4, 1, 3, 6, 4, 12, 60, False{}}}
    case WalkingDead{}: CreatureBundle{WalkingDead{}, CreatureStats{5, 5, 2, 3, 15, 3, 8, 100, False{}}}
    case Wight{}: CreatureBundle{Wight{}, CreatureStats{7, 7, 3, 5, 18, 5, 7, 200, False{}}}
    case Vampire{}: CreatureBundle{Vampire{}, CreatureStats{10, 9, 5, 8, 30, 6, 4, 360, False{}}}
    case Lich{}: CreatureBundle{Lich{}, CreatureStats{13, 10, 11, 13, 30, 6, 3, 500, True{}}}
    case BlackKnight{}: CreatureBundle{BlackKnight{}, CreatureStats{16, 16, 15, 30, 120, 7, 2, 1200, False{}}}
    case BoneDragon{}: CreatureBundle{BoneDragon{}, CreatureStats{17, 15, 25, 50, 150, 9, 1, 1800, False{}}}

assert creature_tier_func:
  forall faction: Faction
  forall tier: U32
  CreatureBundle

def creature_tier_func(faction, tier):
  match faction U32.to_nat(tier):
    case Castle{} 0n: creature_kind_stats_func(Pikeman{})
    case Castle{} 1n: creature_kind_stats_func(Pikeman{})
    case Castle{} 2n: creature_kind_stats_func(Archer{})
    case Castle{} 3n: creature_kind_stats_func(Griffin{})
    case Castle{} 4n: creature_kind_stats_func(Swordsman{})
    case Castle{} 5n: creature_kind_stats_func(Monk{})
    case Castle{} 6n: creature_kind_stats_func(Cavalier{})
    case Castle{} other: creature_kind_stats_func(Angel{})
    case Necropolis{} 0n: creature_kind_stats_func(Skeleton{})
    case Necropolis{} 1n: creature_kind_stats_func(Skeleton{})
    case Necropolis{} 2n: creature_kind_stats_func(WalkingDead{})
    case Necropolis{} 3n: creature_kind_stats_func(Wight{})
    case Necropolis{} 4n: creature_kind_stats_func(Vampire{})
    case Necropolis{} 5n: creature_kind_stats_func(Lich{})
    case Necropolis{} 6n: creature_kind_stats_func(BlackKnight{})
    case Necropolis{} other: creature_kind_stats_func(BoneDragon{})

# Stack-Section
# =============

assert stack_pair_func:
  forall stack: Stack
  StackPair

def stack_pair_func(stack):
  match stack:
    case EmptyStack{}:
      StackPair{EmptyStack{}, EmptyStack{}}
    case Troop{kind, count, first_unit_hp}:
      (left_kind, right_kind) = creature_kind_pair_func(kind)
      (left_count, right_count) = u32_pair_func(count)
      (left_hp, right_hp) = u32_pair_func(first_unit_hp)
      StackPair{Troop{left_kind, left_count, left_hp}, Troop{right_kind, right_count, right_hp}}

assert stack_check_func:
  forall stack: Stack
  StackCheck

def stack_check_func(stack):
  match stack:
    case EmptyStack{}: StackCheck{EmptyStack{}, True{}}
    case Troop{kind, count, first_unit_hp}: StackCheck{Troop{kind, count, first_unit_hp}, False{}}

assert stack_damage_values_func:
  forall kind: CreatureKind
  forall +count: +U32
  forall +first_unit_hp: +U32
  forall +hit_points: +U32
  forall +damage: +U32
  StackDamage

def stack_damage_values_func(kind, count, first_unit_hp, hit_points, damage):
  total_health = U32.add(U32.mul(U32.sub(count, 1), hit_points), first_unit_hp)
  (total_test, total_live) = u32_pair_func(total_health)
  match U32.is_le(total_test, damage):
    case True{}: StackDamage{EmptyStack{}, count}
    case False{}:
      remaining_health = U32.sub(total_live, damage)
      (remaining_for_count, remaining_for_hp) = u32_pair_func(remaining_health)
      next_count = U32.div(U32.add(remaining_for_count, U32.sub(hit_points, 1)), hit_points)
      (next_count_for_kills, next_count_output) = u32_pair_func(next_count)
      remainder = U32.mod(remaining_for_hp, hit_points)
      (remainder_test, remainder_output) = u32_pair_func(remainder)
      kills = U32.sub(count, next_count_for_kills)
      match U32.is_eq(remainder_test, 0):
        case True{}: StackDamage{Troop{kind, next_count_output, hit_points}, kills}
        case False{}: StackDamage{Troop{kind, next_count_output, remainder_output}, kills}

assert stack_damage_func:
  forall stack: Stack
  forall damage: U32
  StackDamage

def stack_damage_func(stack, damage):
  match stack:
    case EmptyStack{}:
      StackDamage{EmptyStack{}, 0}
    case Troop{kind, count, first_unit_hp}:
      match creature_kind_stats_func(kind):
        case CreatureBundle{kept_kind, CreatureStats{attack, defense, damage_min, damage_max, hit_points, speed, growth, cost, ranged}}:
          stack_damage_values_func(kept_kind, count, first_unit_hp, hit_points, damage)

assert stack_heal_func:
  forall stack: Stack
  Stack

def stack_heal_func(stack):
  match stack:
    case EmptyStack{}: EmptyStack{}
    case Troop{kind, count, first_unit_hp}:
      match creature_kind_stats_func(kind):
        case CreatureBundle{kept_kind, CreatureStats{attack, defense, damage_min, damage_max, hit_points, speed, growth, cost, ranged}}:
          Troop{kept_kind, count, hit_points}

# Army-Section
# ============

assert army_empty_func:
  Army

def army_empty_func():
  Army{EmptyStack{}, EmptyStack{}, EmptyStack{}, EmptyStack{}, EmptyStack{}, EmptyStack{}, EmptyStack{}}

assert army_select_func:
  forall army: Army
  forall index: U32
  ArmySelection

def army_select_func(army, index):
  match army U32.to_nat(index):
    case Army{a, b, c, d, e, f, g} 0n:
      match stack_pair_func(a):
        case StackPair{kept, selected}: ArmySelection{Army{kept, b, c, d, e, f, g}, selected}
    case Army{a, b, c, d, e, f, g} 1n:
      match stack_pair_func(b):
        case StackPair{kept, selected}: ArmySelection{Army{a, kept, c, d, e, f, g}, selected}
    case Army{a, b, c, d, e, f, g} 2n:
      match stack_pair_func(c):
        case StackPair{kept, selected}: ArmySelection{Army{a, b, kept, d, e, f, g}, selected}
    case Army{a, b, c, d, e, f, g} 3n:
      match stack_pair_func(d):
        case StackPair{kept, selected}: ArmySelection{Army{a, b, c, kept, e, f, g}, selected}
    case Army{a, b, c, d, e, f, g} 4n:
      match stack_pair_func(e):
        case StackPair{kept, selected}: ArmySelection{Army{a, b, c, d, kept, f, g}, selected}
    case Army{a, b, c, d, e, f, g} 5n:
      match stack_pair_func(f):
        case StackPair{kept, selected}: ArmySelection{Army{a, b, c, d, e, kept, g}, selected}
    case Army{a, b, c, d, e, f, g} other:
      match stack_pair_func(g):
        case StackPair{kept, selected}: ArmySelection{Army{a, b, c, d, e, f, kept}, selected}

assert army_damage_func:
  forall army: Army
  forall index: U32
  forall damage: U32
  ArmyDamage

def army_damage_func(army, index, damage):
  match army U32.to_nat(index):
    case Army{a, b, c, d, e, f, g} 0n:
      match stack_damage_func(a, damage):
        case StackDamage{stack, kills}: ArmyDamage{Army{stack, b, c, d, e, f, g}, kills}
    case Army{a, b, c, d, e, f, g} 1n:
      match stack_damage_func(b, damage):
        case StackDamage{stack, kills}: ArmyDamage{Army{a, stack, c, d, e, f, g}, kills}
    case Army{a, b, c, d, e, f, g} 2n:
      match stack_damage_func(c, damage):
        case StackDamage{stack, kills}: ArmyDamage{Army{a, b, stack, d, e, f, g}, kills}
    case Army{a, b, c, d, e, f, g} 3n:
      match stack_damage_func(d, damage):
        case StackDamage{stack, kills}: ArmyDamage{Army{a, b, c, stack, e, f, g}, kills}
    case Army{a, b, c, d, e, f, g} 4n:
      match stack_damage_func(e, damage):
        case StackDamage{stack, kills}: ArmyDamage{Army{a, b, c, d, stack, f, g}, kills}
    case Army{a, b, c, d, e, f, g} 5n:
      match stack_damage_func(f, damage):
        case StackDamage{stack, kills}: ArmyDamage{Army{a, b, c, d, e, stack, g}, kills}
    case Army{a, b, c, d, e, f, g} other:
      match stack_damage_func(g, damage):
        case StackDamage{stack, kills}: ArmyDamage{Army{a, b, c, d, e, f, stack}, kills}

assert army_check_func:
  forall army: Army
  ArmyCheck

def army_check_func(army):
  match army:
    case Army{a, b, c, d, e, f, g}:
      StackCheck{a_keep, a_empty} = stack_check_func(a)
      StackCheck{b_keep, b_empty} = stack_check_func(b)
      StackCheck{c_keep, c_empty} = stack_check_func(c)
      StackCheck{d_keep, d_empty} = stack_check_func(d)
      StackCheck{e_keep, e_empty} = stack_check_func(e)
      StackCheck{f_keep, f_empty} = stack_check_func(f)
      StackCheck{g_keep, g_empty} = stack_check_func(g)
      empty = Bool.and(a_empty, Bool.and(b_empty, Bool.and(c_empty, Bool.and(d_empty, Bool.and(e_empty, Bool.and(f_empty, g_empty))))))
      ArmyCheck{Army{a_keep, b_keep, c_keep, d_keep, e_keep, f_keep, g_keep}, empty}

assert army_heal_func:
  forall army: Army
  Army

def army_heal_func(army):
  match army:
    case Army{a, b, c, d, e, f, g}:
      Army{
        stack_heal_func(a),
        stack_heal_func(b),
        stack_heal_func(c),
        stack_heal_func(d),
        stack_heal_func(e),
        stack_heal_func(f),
        stack_heal_func(g)
      }

assert army_add_ready_nat_func:
  forall tier: Nat
  forall army: Army
  forall kind: CreatureKind
  forall amount: U32
  forall hit_points: U32
  Army

def army_add_ready_nat_func(tier, army, kind, amount, hit_points):
  match tier army:
    case 1n Army{EmptyStack{}, b, c, d, e, f, g}: Army{Troop{kind, amount, hit_points}, b, c, d, e, f, g}
    case 1n Army{Troop{old_kind, count, old_hp}, b, c, d, e, f, g}: Army{Troop{old_kind, U32.add(count, amount), hit_points}, b, c, d, e, f, g}
    case 2n Army{a, EmptyStack{}, c, d, e, f, g}: Army{a, Troop{kind, amount, hit_points}, c, d, e, f, g}
    case 2n Army{a, Troop{old_kind, count, old_hp}, c, d, e, f, g}: Army{a, Troop{old_kind, U32.add(count, amount), hit_points}, c, d, e, f, g}
    case 3n Army{a, b, EmptyStack{}, d, e, f, g}: Army{a, b, Troop{kind, amount, hit_points}, d, e, f, g}
    case 3n Army{a, b, Troop{old_kind, count, old_hp}, d, e, f, g}: Army{a, b, Troop{old_kind, U32.add(count, amount), hit_points}, d, e, f, g}
    case 4n Army{a, b, c, EmptyStack{}, e, f, g}: Army{a, b, c, Troop{kind, amount, hit_points}, e, f, g}
    case 4n Army{a, b, c, Troop{old_kind, count, old_hp}, e, f, g}: Army{a, b, c, Troop{old_kind, U32.add(count, amount), hit_points}, e, f, g}
    case 5n Army{a, b, c, d, EmptyStack{}, f, g}: Army{a, b, c, d, Troop{kind, amount, hit_points}, f, g}
    case 5n Army{a, b, c, d, Troop{old_kind, count, old_hp}, f, g}: Army{a, b, c, d, Troop{old_kind, U32.add(count, amount), hit_points}, f, g}
    case 6n Army{a, b, c, d, e, EmptyStack{}, g}: Army{a, b, c, d, e, Troop{kind, amount, hit_points}, g}
    case 6n Army{a, b, c, d, e, Troop{old_kind, count, old_hp}, g}: Army{a, b, c, d, e, Troop{old_kind, U32.add(count, amount), hit_points}, g}
    case other Army{a, b, c, d, e, f, EmptyStack{}}: Army{a, b, c, d, e, f, Troop{kind, amount, hit_points}}
    case other Army{a, b, c, d, e, f, Troop{old_kind, count, old_hp}}: Army{a, b, c, d, e, f, Troop{old_kind, U32.add(count, amount), hit_points}}

assert army_add_nat_func:
  forall tier: Nat
  forall army: Army
  forall kind: CreatureKind
  forall amount: U32
  Army

def army_add_nat_func(tier, army, kind, amount):
  match creature_kind_stats_func(kind):
    case CreatureBundle{kept_kind, CreatureStats{attack, defense, damage_min, damage_max, hit_points, speed, growth, cost, ranged}}:
      army_add_ready_nat_func(tier, army, kept_kind, amount, hit_points)

assert army_add_func:
  forall army: Army
  forall tier: U32
  forall kind: CreatureKind
  forall amount: U32
  Army

def army_add_func(army, tier, kind, amount):
  army_add_nat_func(U32.to_nat(tier), army, kind, amount)

# Stock-Section
# =============

assert stock_select_nat_func:
  forall tier: Nat
  forall stock: Stock
  StockSelection

def stock_select_nat_func(tier, stock):
  match tier stock:
    case 1n Stock{a, b, c, d, e, f, g}:
      (kept, available) = u32_pair_func(a)
      StockSelection{Stock{kept, b, c, d, e, f, g}, available}
    case 2n Stock{a, b, c, d, e, f, g}:
      (kept, available) = u32_pair_func(b)
      StockSelection{Stock{a, kept, c, d, e, f, g}, available}
    case 3n Stock{a, b, c, d, e, f, g}:
      (kept, available) = u32_pair_func(c)
      StockSelection{Stock{a, b, kept, d, e, f, g}, available}
    case 4n Stock{a, b, c, d, e, f, g}:
      (kept, available) = u32_pair_func(d)
      StockSelection{Stock{a, b, c, kept, e, f, g}, available}
    case 5n Stock{a, b, c, d, e, f, g}:
      (kept, available) = u32_pair_func(e)
      StockSelection{Stock{a, b, c, d, kept, f, g}, available}
    case 6n Stock{a, b, c, d, e, f, g}:
      (kept, available) = u32_pair_func(f)
      StockSelection{Stock{a, b, c, d, e, kept, g}, available}
    case other Stock{a, b, c, d, e, f, g}:
      (kept, available) = u32_pair_func(g)
      StockSelection{Stock{a, b, c, d, e, f, kept}, available}

assert stock_select_func:
  forall stock: Stock
  forall tier: U32
  StockSelection

def stock_select_func(stock, tier):
  stock_select_nat_func(U32.to_nat(tier), stock)

assert stock_sub_nat_func:
  forall tier: Nat
  forall stock: Stock
  forall amount: U32
  Stock

def stock_sub_nat_func(tier, stock, amount):
  match tier stock:
    case 1n Stock{a, b, c, d, e, f, g}: Stock{U32.sub(a, amount), b, c, d, e, f, g}
    case 2n Stock{a, b, c, d, e, f, g}: Stock{a, U32.sub(b, amount), c, d, e, f, g}
    case 3n Stock{a, b, c, d, e, f, g}: Stock{a, b, U32.sub(c, amount), d, e, f, g}
    case 4n Stock{a, b, c, d, e, f, g}: Stock{a, b, c, U32.sub(d, amount), e, f, g}
    case 5n Stock{a, b, c, d, e, f, g}: Stock{a, b, c, d, U32.sub(e, amount), f, g}
    case 6n Stock{a, b, c, d, e, f, g}: Stock{a, b, c, d, e, U32.sub(f, amount), g}
    case other Stock{a, b, c, d, e, f, g}: Stock{a, b, c, d, e, f, U32.sub(g, amount)}

assert stock_sub_func:
  forall stock: Stock
  forall tier: U32
  forall amount: U32
  Stock

def stock_sub_func(stock, tier, amount):
  stock_sub_nat_func(U32.to_nat(tier), stock, amount)

assert stock_growth_value_func:
  forall +mask: +U32
  forall bit: U32
  forall base: U32
  forall +fort: +U32
  U32

def stock_growth_value_func(mask, bit, base, fort):
  match U32.is_ne(U32.and(mask, bit), 0):
    case False{}: 0
    case True{}:
      U32.div(U32.mul(base, U32.add(100, U32.mul(fort, 50))), 100)

assert stock_grow_func:
  forall stock: Stock
  forall +mask: +U32
  forall +fort: +U32
  forall growth1: U32
  forall growth2: U32
  forall growth3: U32
  forall growth4: U32
  forall growth5: U32
  forall growth6: U32
  forall growth7: U32
  Stock

def stock_grow_func(stock, mask, fort, growth1, growth2, growth3, growth4, growth5, growth6, growth7):
  match stock:
    case Stock{a, b, c, d, e, f, g}:
      Stock{
        U32.add(a, stock_growth_value_func(mask, 1, growth1, fort)),
        U32.add(b, stock_growth_value_func(mask, 2, growth2, fort)),
        U32.add(c, stock_growth_value_func(mask, 4, growth3, fort)),
        U32.add(d, stock_growth_value_func(mask, 8, growth4, fort)),
        U32.add(e, stock_growth_value_func(mask, 16, growth5, fort)),
        U32.add(f, stock_growth_value_func(mask, 32, growth6, fort)),
        U32.add(g, stock_growth_value_func(mask, 64, growth7, fort))
      }

assert stock_grow_faction_func:
  forall stock: Stock
  forall faction: Faction
  forall mask: U32
  forall fort: U32
  Stock

def stock_grow_faction_func(stock, faction, mask, fort):
  match faction:
    case Castle{}: stock_grow_func(stock, mask, fort, 14, 9, 7, 4, 3, 2, 1)
    case Necropolis{}: stock_grow_func(stock, mask, fort, 12, 8, 7, 4, 3, 2, 1)

# Cell-Section
# ============

assert site_at_func:
  forall +x: +U32
  forall +y: +U32
  Site

def site_at_func(x, y):
  match u32_coord_func(x, y, 1, 5):
    case True{}: RedTownSite{}
    case False{}:
      match u32_coord_func(x, y, 7, 1):
        case True{}: BlueTownSite{}
        case False{}:
          match u32_coord_func(x, y, 2, 5):
            case True{}: GoldPileSite{}
            case False{}:
              match u32_coord_func(x, y, 2, 4):
                case True{}: WoodPileSite{}
                case False{}:
                  match u32_coord_func(x, y, 2, 2):
                    case True{}: ShrineSite{}
                    case False{}:
                      match u32_coord_func(x, y, 5, 3):
                        case True{}: ArtifactSite{}
                        case False{}:
                          match u32_coord_func(x, y, 3, 5):
                            case True{}: SawmillSite{}
                            case False{}:
                              match u32_coord_func(x, y, 6, 2):
                                case True{}: GoldMineSite{}
                                case False{}:
                                  match u32_coord_func(x, y, 4, 3):
                                    case True{}: GuardianSite{}
                                    case False{}: EmptySite{}

assert terrain_at_func:
  forall +x: +U32
  forall +y: +U32
  Terrain

def terrain_at_func(x, y):
  match U32.is_eq(x, 4):
    case True{}:
      match Bool.or(U32.is_eq(y, 3), U32.is_eq(y, 5)):
        case True{}: Grass{}
        case False{}: Water{}
    case False{}:
      match U32.is_le(5, x):
        case True{}: Dirt{}
        case False{}:
          match Bool.and(U32.is_eq(x, 3), U32.is_le(y, 2)):
            case True{}: Rough{}
            case False{}: Grass{}

assert terrain_cell_func:
  forall terrain: Terrain
  forall site: Site
  Cell

def terrain_cell_func(terrain, site):
  match terrain:
    case Grass{}: Cell{Grass{}, site, 100, True{}}
    case Dirt{}: Cell{Dirt{}, site, 100, True{}}
    case Rough{}: Cell{Rough{}, site, 125, True{}}
    case Swamp{}: Cell{Swamp{}, site, 175, True{}}
    case Water{}: Cell{Water{}, site, 100, False{}}
    case Rock{}: Cell{Rock{}, site, 0, False{}}

assert heroes_cell_func:
  forall +x: +U32
  forall +y: +U32
  Cell

def heroes_cell_func(x, y):
  terrain_cell_func(terrain_at_func(x, y), site_at_func(x, y))

# Hero-Section
# ============

assert hero_set_army_func:
  forall hero: Hero
  forall army: Army
  Hero

def hero_set_army_func(hero, army):
  match hero:
    case Hero{name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, old_army}:
      Hero{name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army}

assert hero_new_day_func:
  forall hero: Hero
  Hero

def hero_new_day_func(hero):
  match hero:
    case Hero{name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army}:
      (knowledge_limit, knowledge_keep) = u32_pair_func(knowledge)
      maximum = U32.mul(knowledge_limit, 10)
      Hero{name, x, y, 1600, attack, defense, power, knowledge_keep, u32_min_func(maximum, U32.inc(mana)), level, experience, army}

assert hero_gain_values_func:
  forall name: String
  forall x: U32
  forall y: U32
  forall movement: U32
  forall +attack: +U32
  forall defense: U32
  forall +power: +U32
  forall knowledge: U32
  forall mana: U32
  forall +level: +U32
  forall +experience: +U32
  forall army: Army
  forall reward: U32
  Hero

assert hero_level_from_experience_func:
  forall +experience: +U32
  U32

def hero_level_from_experience_func(experience):
  match U32.is_lt(experience, 1000):
    case True{}: 1
    case False{}:
      match U32.is_lt(experience, 2000):
        case True{}: 2
        case False{}:
          match U32.is_lt(experience, 3200):
            case True{}: 3
            case False{}:
              match U32.is_lt(experience, 4600):
                case True{}: 4
                case False{}:
                  match U32.is_lt(experience, 6200):
                    case True{}: 5
                    case False{}:
                      match U32.is_lt(experience, 8000):
                        case True{}: 6
                        case False{}:
                          match U32.is_lt(experience, 10000):
                            case True{}: 7
                            case False{}:
                              match U32.is_lt(experience, 12200):
                                case True{}: 8
                                case False{}:
                                  match U32.is_lt(experience, 14700):
                                    case True{}: 9
                                    case False{}: 10

def hero_gain_values_func(name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army, reward):
  next_experience = U32.add(experience, reward)
  (experience_level, experience_output) = u32_pair_func(next_experience)
  next_level = hero_level_from_experience_func(experience_level)
  (level_test, level_live) = u32_pair_func(next_level)
  match U32.is_lt(level, level_test):
    case False{}: Hero{name, x, y, movement, attack, defense, power, knowledge, mana, level, experience_output, army}
    case True{}:
      (level_parity, level_output) = u32_pair_func(level_live)
      match U32.is_eq(U32.mod(level_parity, 2), 0):
        case True{}: Hero{name, x, y, movement, U32.inc(attack), defense, power, knowledge, mana, level_output, experience_output, army}
        case False{}: Hero{name, x, y, movement, attack, defense, U32.inc(power), knowledge, mana, level_output, experience_output, army}

assert hero_gain_func:
  forall hero: Hero
  forall reward: U32
  Hero

def hero_gain_func(hero, reward):
  match hero:
    case Hero{name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army}:
      hero_gain_values_func(name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army, reward)

assert hero_add_attack_func:
  forall hero: Hero
  forall amount: U32
  Hero

def hero_add_attack_func(hero, amount):
  match hero:
    case Hero{name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army}:
      Hero{name, x, y, movement, U32.add(attack, amount), defense, power, knowledge, mana, level, experience, army}

assert hero_add_power_func:
  forall hero: Hero
  forall amount: U32
  Hero

def hero_add_power_func(hero, amount):
  match hero:
    case Hero{name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army}:
      Hero{name, x, y, movement, attack, defense, U32.add(power, amount), knowledge, mana, level, experience, army}

assert hero_home_check_func:
  forall faction: Faction
  forall hero: Hero
  HeroCheck

def hero_home_check_func(faction, hero):
  match faction hero:
    case Castle{} Hero{name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army}:
      (x_test, x_keep) = u32_pair_func(x)
      (y_test, y_keep) = u32_pair_func(y)
      valid = Bool.and(U32.is_eq(x_test, 1), U32.is_eq(y_test, 5))
      HeroCheck{Hero{name, x_keep, y_keep, movement, attack, defense, power, knowledge, mana, level, experience, army}, valid}
    case Necropolis{} Hero{name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army}:
      (x_test, x_keep) = u32_pair_func(x)
      (y_test, y_keep) = u32_pair_func(y)
      valid = Bool.and(U32.is_eq(x_test, 7), U32.is_eq(y_test, 1))
      HeroCheck{Hero{name, x_keep, y_keep, movement, attack, defense, power, knowledge, mana, level, experience, army}, valid}

# Town-Section
# ============

assert town_hall_income_func:
  forall hall: U32
  U32

def town_hall_income_func(hall):
  match U32.to_nat(hall):
    case 0n: 500
    case 1n: 1000
    case 2n: 2000
    case other: 4000

assert town_hall_cost_func:
  forall hall: U32
  U32

def town_hall_cost_func(hall):
  match U32.to_nat(hall):
    case 0n: 2500
    case 1n: 5000
    case other: 10000

assert town_build_hall_values_func:
  forall faction: Faction
  forall +hall: +U32
  forall fort: U32
  forall dwellings: U32
  forall built_today: Bool
  forall stock: Stock
  forall resources: Resources
  TownAction

def town_build_hall_values_func(faction, hall, fort, dwellings, built_today, stock, resources):
  match built_today:
    case True{}: TownAction{Town{faction, hall, fort, dwellings, True{}, stock}, resources, False{}, "Only one building may be constructed in a town each day."}
    case False{}:
      match U32.is_le(3, hall):
        case True{}: TownAction{Town{faction, hall, fort, dwellings, False{}, stock}, resources, False{}, "The Capitol is already complete."}
        case False{}:
          match resources_pay_func(resources, town_hall_cost_func(hall), 5, 5):
            case Payment{remaining, False{}}: TownAction{Town{faction, hall, fort, dwellings, False{}, stock}, remaining, False{}, "The kingdom lacks resources for the next hall."}
            case Payment{remaining, True{}}: TownAction{Town{faction, U32.inc(hall), fort, dwellings, True{}, stock}, remaining, True{}, "The hall line advanced and daily gold income increased."}

assert town_build_hall_func:
  forall town: Town
  forall resources: Resources
  TownAction

def town_build_hall_func(town, resources):
  match town:
    case Town{faction, hall, fort, dwellings, built_today, stock}:
      town_build_hall_values_func(faction, hall, fort, dwellings, built_today, stock, resources)

assert town_build_fort_values_func:
  forall faction: Faction
  forall hall: U32
  forall +fort: +U32
  forall dwellings: U32
  forall built_today: Bool
  forall stock: Stock
  forall resources: Resources
  TownAction

def town_build_fort_values_func(faction, hall, fort, dwellings, built_today, stock, resources):
  match built_today:
    case True{}: TownAction{Town{faction, hall, fort, dwellings, True{}, stock}, resources, False{}, "Only one building may be constructed in a town each day."}
    case False{}:
      match U32.is_le(2, fort):
        case True{}: TownAction{Town{faction, hall, fort, dwellings, False{}, stock}, resources, False{}, "The Castle fortification is already complete."}
        case False{}:
          match resources_pay_func(resources, U32.mul(U32.inc(fort), 2500), 5, 5):
            case Payment{remaining, False{}}: TownAction{Town{faction, hall, fort, dwellings, False{}, stock}, remaining, False{}, "The kingdom lacks resources for fortification."}
            case Payment{remaining, True{}}: TownAction{Town{faction, hall, U32.inc(fort), dwellings, True{}, stock}, remaining, True{}, "Fortification advanced; weekly creature growth will improve."}

assert town_build_fort_func:
  forall town: Town
  forall resources: Resources
  TownAction

def town_build_fort_func(town, resources):
  match town:
    case Town{faction, hall, fort, dwellings, built_today, stock}:
      town_build_fort_values_func(faction, hall, fort, dwellings, built_today, stock, resources)

assert town_tier_bit_func:
  forall tier: U32
  U32

def town_tier_bit_func(tier):
  match U32.to_nat(tier):
    case 1n: 1
    case 2n: 2
    case 3n: 4
    case 4n: 8
    case 5n: 16
    case 6n: 32
    case other: 64

assert town_previous_bit_func:
  forall tier: U32
  U32

def town_previous_bit_func(tier):
  match U32.to_nat(tier):
    case 1n: 0
    case 2n: 1
    case 3n: 2
    case 4n: 4
    case 5n: 8
    case 6n: 16
    case other: 32

assert town_build_dwelling_values_func:
  forall faction: Faction
  forall hall: U32
  forall fort: U32
  forall +dwellings: +U32
  forall built_today: Bool
  forall stock: Stock
  forall resources: Resources
  forall +tier: +U32
  TownAction

def town_build_dwelling_values_func(faction, hall, fort, dwellings, built_today, stock, resources, tier):
  match built_today:
    case True{}: TownAction{Town{faction, hall, fort, dwellings, True{}, stock}, resources, False{}, "Only one building may be constructed in a town each day."}
    case False{}:
      bit = town_tier_bit_func(tier)
      previous = town_previous_bit_func(tier)
      (bit_test, bit_live) = u32_pair_func(bit)
      (previous_zero, previous_test) = u32_pair_func(previous)
      missing_target = U32.is_eq(U32.and(dwellings, bit_test), 0)
      prerequisite = Bool.or(U32.is_eq(previous_zero, 0), U32.is_ne(U32.and(dwellings, previous_test), 0))
      valid_tier = Bool.and(U32.is_le(1, tier), U32.is_le(tier, 7))
      match Bool.and(valid_tier, Bool.and(missing_target, prerequisite)):
        case False{}: TownAction{Town{faction, hall, fort, dwellings, False{}, stock}, resources, False{}, "That dwelling is built already, unavailable, or missing its lower-tier prerequisite."}
        case True{}:
          gold_cost = U32.mul(500, U32.mul(tier, tier))
          material_cost = U32.mul(2, tier)
          (wood_cost, ore_cost) = u32_pair_func(material_cost)
          match resources_pay_func(resources, gold_cost, wood_cost, ore_cost):
            case Payment{remaining, False{}}: TownAction{Town{faction, hall, fort, dwellings, False{}, stock}, remaining, False{}, "The kingdom lacks resources for that creature dwelling."}
            case Payment{remaining, True{}}: TownAction{Town{faction, hall, fort, U32.or(dwellings, bit_live), True{}, stock}, remaining, True{}, "A new creature dwelling was completed."}

assert town_build_dwelling_func:
  forall town: Town
  forall resources: Resources
  forall tier: U32
  TownAction

def town_build_dwelling_func(town, resources, tier):
  match town:
    case Town{faction, hall, fort, dwellings, built_today, stock}:
      town_build_dwelling_values_func(faction, hall, fort, dwellings, built_today, stock, resources, tier)

assert town_new_day_func:
  forall week_start: Bool
  forall town: Town
  TownDay

def town_new_day_func(week_start, town):
  match week_start town:
    case False{} Town{faction, hall, fort, dwellings, built_today, stock}:
      (hall_income, hall_keep) = u32_pair_func(hall)
      income = town_hall_income_func(hall_income)
      TownDay{Town{faction, hall_keep, fort, dwellings, False{}, stock}, income}
    case True{} Town{faction, hall, fort, dwellings, built_today, stock}:
      (hall_income, hall_keep) = u32_pair_func(hall)
      (fort_growth, fort_keep) = u32_pair_func(fort)
      (dwellings_growth, dwellings_keep) = u32_pair_func(dwellings)
      income = town_hall_income_func(hall_income)
      (growth_faction, output_faction) = faction_pair_func(faction)
      grown = stock_grow_faction_func(stock, growth_faction, dwellings_growth, fort_growth)
      TownDay{Town{output_faction, hall_keep, fort_keep, dwellings_keep, False{}, grown}, income}

# Kingdom-Section
# ===============

assert kingdom_build_hall_func:
  forall kingdom: Kingdom
  Kingdom & String

def kingdom_build_hall_func(kingdom):
  match kingdom:
    case Kingdom{resources, hero, town}:
      match town_build_hall_func(town, resources):
        case TownAction{next_town, next_resources, accepted, notice}:
          (Kingdom{next_resources, hero, next_town}, notice)

assert kingdom_build_fort_func:
  forall kingdom: Kingdom
  Kingdom & String

def kingdom_build_fort_func(kingdom):
  match kingdom:
    case Kingdom{resources, hero, town}:
      match town_build_fort_func(town, resources):
        case TownAction{next_town, next_resources, accepted, notice}:
          (Kingdom{next_resources, hero, next_town}, notice)

assert kingdom_build_dwelling_func:
  forall kingdom: Kingdom
  forall tier: U32
  Kingdom & String

def kingdom_build_dwelling_func(kingdom, tier):
  match kingdom:
    case Kingdom{resources, hero, town}:
      match town_build_dwelling_func(town, resources, tier):
        case TownAction{next_town, next_resources, accepted, notice}:
          (Kingdom{next_resources, hero, next_town}, notice)

assert kingdom_recruit_values_func:
  forall resources: Resources
  forall hero: Hero
  forall faction: Faction
  forall hall: U32
  forall fort: U32
  forall dwellings: U32
  forall built_today: Bool
  forall stock: Stock
  forall +tier: +U32
  forall +amount: +U32
  Kingdom & String

def kingdom_recruit_values_func(resources, hero, faction, hall, fort, dwellings, built_today, stock, tier, amount):
  match hero:
    case Hero{name, x, y, movement, hero_attack, hero_defense, power, knowledge, mana, level, experience, army}:
      match stock_select_func(stock, tier):
        case StockSelection{kept_stock, available}:
          match creature_tier_func(faction, tier):
            case CreatureBundle{kind, CreatureStats{attack, defense, damage_min, damage_max, hit_points, speed, growth, cost, ranged}}:
              valid_tier = Bool.and(U32.is_le(1, tier), U32.is_le(tier, 7))
              enough_stock = Bool.and(valid_tier, Bool.and(U32.is_ne(amount, 0), U32.is_le(amount, available)))
              match enough_stock:
                case False{}:
                  (Kingdom{resources, Hero{name, x, y, movement, hero_attack, hero_defense, power, knowledge, mana, level, experience, army}, Town{Castle{}, hall, fort, dwellings, built_today, kept_stock}}, "The requested creatures are not available.")
                case True{}:
                  match resources_pay_func(resources, U32.mul(cost, amount), 0, 0):
                    case Payment{remaining, False{}}:
                      (Kingdom{remaining, Hero{name, x, y, movement, hero_attack, hero_defense, power, knowledge, mana, level, experience, army}, Town{Castle{}, hall, fort, dwellings, built_today, kept_stock}}, "The kingdom lacks gold for that recruitment.")
                    case Payment{remaining, True{}}:
                      next_army = army_add_func(army, tier, kind, amount)
                      next_stock = stock_sub_func(kept_stock, tier, amount)
                      (Kingdom{remaining, Hero{name, x, y, movement, hero_attack, hero_defense, power, knowledge, mana, level, experience, next_army}, Town{Castle{}, hall, fort, dwellings, built_today, next_stock}}, "Creatures joined the active hero's army.")

assert kingdom_recruit_necropolis_values_func:
  forall resources: Resources
  forall hero: Hero
  forall hall: U32
  forall fort: U32
  forall dwellings: U32
  forall built_today: Bool
  forall stock: Stock
  forall +tier: +U32
  forall +amount: +U32
  Kingdom & String

def kingdom_recruit_necropolis_values_func(resources, hero, hall, fort, dwellings, built_today, stock, tier, amount):
  match hero:
    case Hero{name, x, y, movement, hero_attack, hero_defense, power, knowledge, mana, level, experience, army}:
      match stock_select_func(stock, tier):
        case StockSelection{kept_stock, available}:
          match creature_tier_func(Necropolis{}, tier):
            case CreatureBundle{kind, CreatureStats{attack, defense, damage_min, damage_max, hit_points, speed, growth, cost, ranged}}:
              valid_tier = Bool.and(U32.is_le(1, tier), U32.is_le(tier, 7))
              enough_stock = Bool.and(valid_tier, Bool.and(U32.is_ne(amount, 0), U32.is_le(amount, available)))
              match enough_stock:
                case False{}:
                  (Kingdom{resources, Hero{name, x, y, movement, hero_attack, hero_defense, power, knowledge, mana, level, experience, army}, Town{Necropolis{}, hall, fort, dwellings, built_today, kept_stock}}, "The requested creatures are not available.")
                case True{}:
                  match resources_pay_func(resources, U32.mul(cost, amount), 0, 0):
                    case Payment{remaining, False{}}:
                      (Kingdom{remaining, Hero{name, x, y, movement, hero_attack, hero_defense, power, knowledge, mana, level, experience, army}, Town{Necropolis{}, hall, fort, dwellings, built_today, kept_stock}}, "The kingdom lacks gold for that recruitment.")
                    case Payment{remaining, True{}}:
                      next_army = army_add_func(army, tier, kind, amount)
                      next_stock = stock_sub_func(kept_stock, tier, amount)
                      (Kingdom{remaining, Hero{name, x, y, movement, hero_attack, hero_defense, power, knowledge, mana, level, experience, next_army}, Town{Necropolis{}, hall, fort, dwellings, built_today, next_stock}}, "Creatures joined the active hero's army.")

assert kingdom_recruit_func:
  forall kingdom: Kingdom
  forall tier: U32
  forall amount: U32
  Kingdom & String

def kingdom_recruit_func(kingdom, tier, amount):
  match kingdom:
    case Kingdom{resources, hero, Town{Castle{}, hall, fort, dwellings, built_today, stock}}:
      match hero_home_check_func(Castle{}, hero):
        case HeroCheck{kept_hero, False{}}:
          (Kingdom{resources, kept_hero, Town{Castle{}, hall, fort, dwellings, built_today, stock}}, "The active hero must be visiting the Castle to recruit into this army.")
        case HeroCheck{kept_hero, True{}}:
          kingdom_recruit_values_func(resources, kept_hero, Castle{}, hall, fort, dwellings, built_today, stock, tier, amount)
    case Kingdom{resources, hero, Town{Necropolis{}, hall, fort, dwellings, built_today, stock}}:
      match hero_home_check_func(Necropolis{}, hero):
        case HeroCheck{kept_hero, False{}}:
          (Kingdom{resources, kept_hero, Town{Necropolis{}, hall, fort, dwellings, built_today, stock}}, "The active hero must be visiting the Necropolis to recruit into this army.")
        case HeroCheck{kept_hero, True{}}:
          kingdom_recruit_necropolis_values_func(resources, kept_hero, hall, fort, dwellings, built_today, stock, tier, amount)

assert kingdom_new_day_func:
  forall kingdom: Kingdom
  forall mine_gold: U32
  forall mine_wood: U32
  forall week_start: Bool
  Kingdom

def kingdom_new_day_func(kingdom, mine_gold, mine_wood, week_start):
  match kingdom:
    case Kingdom{resources, hero, town}:
      match town_new_day_func(week_start, town):
        case TownDay{next_town, income}:
          with_mines = resources_add_gold_func(resources, U32.add(income, mine_gold))
          next_resources = resources_add_wood_func(with_mines, mine_wood)
          Kingdom{next_resources, hero_new_day_func(hero), next_town}

assert kingdom_add_gold_func:
  forall kingdom: Kingdom
  forall amount: U32
  Kingdom

def kingdom_add_gold_func(kingdom, amount):
  match kingdom:
    case Kingdom{resources, hero, town}:
      Kingdom{resources_add_gold_func(resources, amount), hero, town}

assert kingdom_add_wood_func:
  forall kingdom: Kingdom
  forall amount: U32
  Kingdom

def kingdom_add_wood_func(kingdom, amount):
  match kingdom:
    case Kingdom{resources, hero, town}:
      Kingdom{resources_add_wood_func(resources, amount), hero, town}

assert kingdom_add_attack_func:
  forall kingdom: Kingdom
  forall amount: U32
  Kingdom

def kingdom_add_attack_func(kingdom, amount):
  match kingdom:
    case Kingdom{resources, hero, town}:
      Kingdom{resources, hero_add_attack_func(hero, amount), town}

assert kingdom_add_power_func:
  forall kingdom: Kingdom
  forall amount: U32
  Kingdom

def kingdom_add_power_func(kingdom, amount):
  match kingdom:
    case Kingdom{resources, hero, town}:
      Kingdom{resources, hero_add_power_func(hero, amount), town}

# Movement
# ========

assert coordinate_step_func:
  forall direction: Direction
  forall +x: +U32
  forall +y: +U32
  Coordinate

def coordinate_step_func(direction, x, y):
  match direction:
    case North{}:
      match U32.is_eq(y, 0):
        case True{}: Coordinate{x, y, False{}, False{}}
        case False{}: Coordinate{x, U32.sub(y, 1), True{}, False{}}
    case NorthEast{}:
      match U32.is_eq(y, 0):
        case True{}: Coordinate{x, y, False{}, True{}}
        case False{}:
          match U32.is_le(8, x):
            case True{}: Coordinate{x, y, False{}, True{}}
            case False{}: Coordinate{U32.inc(x), U32.sub(y, 1), True{}, True{}}
    case East{}:
      match U32.is_le(8, x):
        case True{}: Coordinate{x, y, False{}, False{}}
        case False{}: Coordinate{U32.inc(x), y, True{}, False{}}
    case SouthEast{}:
      match U32.is_le(6, y):
        case True{}: Coordinate{x, y, False{}, True{}}
        case False{}:
          match U32.is_le(8, x):
            case True{}: Coordinate{x, y, False{}, True{}}
            case False{}: Coordinate{U32.inc(x), U32.inc(y), True{}, True{}}
    case South{}:
      match U32.is_le(6, y):
        case True{}: Coordinate{x, y, False{}, False{}}
        case False{}: Coordinate{x, U32.inc(y), True{}, False{}}
    case SouthWest{}:
      match U32.is_le(6, y):
        case True{}: Coordinate{x, y, False{}, True{}}
        case False{}:
          match U32.is_eq(x, 0):
            case True{}: Coordinate{x, y, False{}, True{}}
            case False{}: Coordinate{U32.sub(x, 1), U32.inc(y), True{}, True{}}
    case West{}:
      match U32.is_eq(x, 0):
        case True{}: Coordinate{x, y, False{}, False{}}
        case False{}: Coordinate{U32.sub(x, 1), y, True{}, False{}}
    case NorthWest{}:
      match U32.is_eq(y, 0):
        case True{}: Coordinate{x, y, False{}, True{}}
        case False{}:
          match U32.is_eq(x, 0):
            case True{}: Coordinate{x, y, False{}, True{}}
            case False{}: Coordinate{U32.sub(x, 1), U32.sub(y, 1), True{}, True{}}

assert movement_direction_cost_func:
  forall diagonal: Bool
  forall movement_cost: U32
  U32

def movement_direction_cost_func(diagonal, movement_cost):
  match diagonal:
    case False{}: movement_cost
    case True{}: U32.div(U32.add(U32.mul(movement_cost, 141), 50), 100)

assert hero_attempt_enter_func:
  forall name: String
  forall old_x: U32
  forall old_y: U32
  forall +movement: +U32
  forall attack: U32
  forall defense: U32
  forall power: U32
  forall knowledge: U32
  forall mana: U32
  forall level: U32
  forall experience: U32
  forall army: Army
  forall +next_x: +U32
  forall +next_y: +U32
  forall diagonal: Bool
  HeroMove

def hero_attempt_enter_func(name, old_x, old_y, movement, attack, defense, power, knowledge, mana, level, experience, army, next_x, next_y, diagonal):
  match heroes_cell_func(next_x, next_y):
    case Cell{terrain, site, movement_cost, False{}}:
      HeroMove{Hero{name, old_x, old_y, movement, attack, defense, power, knowledge, mana, level, experience, army}, next_x, next_y, False{}}
    case Cell{terrain, site, movement_cost, True{}}:
      adjusted_cost = movement_direction_cost_func(diagonal, movement_cost)
      (cost_test, cost_live) = u32_pair_func(adjusted_cost)
      match U32.is_le(cost_test, movement):
        case False{}:
          HeroMove{Hero{name, old_x, old_y, movement, attack, defense, power, knowledge, mana, level, experience, army}, next_x, next_y, False{}}
        case True{}:
          (hero_x, visit_x) = u32_pair_func(next_x)
          (hero_y, visit_y) = u32_pair_func(next_y)
          next_movement = U32.sub(movement, cost_live)
          HeroMove{Hero{name, hero_x, hero_y, next_movement, attack, defense, power, knowledge, mana, level, experience, army}, visit_x, visit_y, True{}}

assert hero_move_func:
  forall direction: Direction
  forall hero: Hero
  HeroMove

def hero_move_func(direction, hero):
  match hero:
    case Hero{name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army}:
      (step_x, old_x) = u32_pair_func(x)
      (step_y, old_y) = u32_pair_func(y)
      match coordinate_step_func(direction, step_x, step_y):
        case Coordinate{next_x, next_y, False{}, diagonal}:
          HeroMove{Hero{name, old_x, old_y, movement, attack, defense, power, knowledge, mana, level, experience, army}, next_x, next_y, False{}}
        case Coordinate{next_x, next_y, True{}, diagonal}:
          hero_attempt_enter_func(name, old_x, old_y, movement, attack, defense, power, knowledge, mana, level, experience, army, next_x, next_y, diagonal)

# Scenario-Armies
# ===============

assert guardian_army_func:
  Army

def guardian_army_func():
  Army{Troop{Griffin{}, 10, 25}, EmptyStack{}, EmptyStack{}, EmptyStack{}, EmptyStack{}, EmptyStack{}, EmptyStack{}}

assert castle_garrison_func:
  Army

def castle_garrison_func():
  Army{Troop{Pikeman{}, 24, 10}, Troop{Archer{}, 10, 10}, Troop{Griffin{}, 5, 25}, EmptyStack{}, EmptyStack{}, EmptyStack{}, EmptyStack{}}

assert necropolis_garrison_func:
  Army

def necropolis_garrison_func():
  Army{Troop{Skeleton{}, 30, 6}, Troop{WalkingDead{}, 12, 15}, Troop{Wight{}, 7, 18}, EmptyStack{}, EmptyStack{}, EmptyStack{}, EmptyStack{}}

# Visit
# =====

assert kingdom_visit_site_func:
  forall site: Site
  forall world: World
  forall kingdom: Kingdom
  forall owner: Owner
  MoveResult

def kingdom_visit_site_func(site, world, kingdom, owner):
  match site world:
    case EmptySite{} World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian}:
      MoveResult{kingdom, World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian}, Adventure{}, "The hero crossed one adventure-map tile."}
    case GoldPileSite{} World{False{}, wood, shrine, artifact, sawmill, gold_mine, guardian}:
      MoveResult{kingdom, World{False{}, wood, shrine, artifact, sawmill, gold_mine, guardian}, Adventure{}, "The empty treasure site has already been searched."}
    case GoldPileSite{} World{True{}, wood, shrine, artifact, sawmill, gold_mine, guardian}:
      MoveResult{kingdom_add_gold_func(kingdom, 1000), World{False{}, wood, shrine, artifact, sawmill, gold_mine, guardian}, Adventure{}, "A treasure chest added 1000 gold to the kingdom."}
    case WoodPileSite{} World{gold, False{}, shrine, artifact, sawmill, gold_mine, guardian}:
      MoveResult{kingdom, World{gold, False{}, shrine, artifact, sawmill, gold_mine, guardian}, Adventure{}, "The loose resource pile is empty."}
    case WoodPileSite{} World{gold, True{}, shrine, artifact, sawmill, gold_mine, guardian}:
      MoveResult{kingdom_add_wood_func(kingdom, 5), World{gold, False{}, shrine, artifact, sawmill, gold_mine, guardian}, Adventure{}, "Five wood were collected."}
    case ShrineSite{} World{gold, wood, False{}, artifact, sawmill, gold_mine, guardian}:
      MoveResult{kingdom, World{gold, wood, False{}, artifact, sawmill, gold_mine, guardian}, Adventure{}, "The Shrine of Magic has already granted its lesson."}
    case ShrineSite{} World{gold, wood, True{}, artifact, sawmill, gold_mine, guardian}:
      MoveResult{kingdom_add_power_func(kingdom, 1), World{gold, wood, False{}, artifact, sawmill, gold_mine, guardian}, Adventure{}, "The shrine increased the hero's Spell Power."}
    case ArtifactSite{} World{gold, wood, shrine, False{}, sawmill, gold_mine, guardian}:
      MoveResult{kingdom, World{gold, wood, shrine, False{}, sawmill, gold_mine, guardian}, Adventure{}, "Only an empty artifact pedestal remains."}
    case ArtifactSite{} World{gold, wood, shrine, True{}, sawmill, gold_mine, guardian}:
      MoveResult{kingdom_add_attack_func(kingdom, 2), World{gold, wood, shrine, False{}, sawmill, gold_mine, guardian}, Adventure{}, "The Sword of Judgment increased the hero's Attack by 2."}
    case SawmillSite{} World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian}:
      MoveResult{kingdom, World{gold, wood, shrine, artifact, owner, gold_mine, guardian}, Adventure{}, "The Sawmill was flagged and will yield 2 wood each day."}
    case GoldMineSite{} World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian}:
      MoveResult{kingdom, World{gold, wood, shrine, artifact, sawmill, owner, guardian}, Adventure{}, "The Gold Mine was flagged and will yield 1000 gold each day."}
    case GuardianSite{} World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian}:
      match army_check_func(guardian):
        case ArmyCheck{kept_guardian, True{}}:
          MoveResult{kingdom, World{gold, wood, shrine, artifact, sawmill, gold_mine, kept_guardian}, Adventure{}, "The guarded bridge is now clear."}
        case ArmyCheck{kept_guardian, False{}}:
          MoveResult{kingdom, World{gold, wood, shrine, artifact, sawmill, gold_mine, army_empty_func()}, Combat{Battle{owner, GuardianBattle{}, kept_guardian, 1}}, "Ten Griffins block the bridge. Combat begins."}
    case RedTownSite{} World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian}:
      match owner:
        case Neutral{}: MoveResult{kingdom, World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian}, Adventure{}, "The town gate is closed."}
        case Red{}: MoveResult{kingdom, World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian}, Adventure{}, "The hero returned to the Castle."}
        case Blue{}: MoveResult{kingdom, World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian}, Combat{Battle{Blue{}, EnemyTownBattle{}, castle_garrison_func(), 1}}, "The Necropolis hero attacks the Castle garrison."}
    case BlueTownSite{} World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian}:
      match owner:
        case Neutral{}: MoveResult{kingdom, World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian}, Adventure{}, "The town gate is closed."}
        case Red{}: MoveResult{kingdom, World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian}, Combat{Battle{Red{}, EnemyTownBattle{}, necropolis_garrison_func(), 1}}, "The Castle hero attacks the Necropolis garrison."}
        case Blue{}: MoveResult{kingdom, World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian}, Adventure{}, "The hero returned to the Necropolis."}

assert kingdom_visit_func:
  forall +x: +U32
  forall +y: +U32
  forall world: World
  forall kingdom: Kingdom
  forall owner: Owner
  MoveResult

def kingdom_visit_func(x, y, world, kingdom, owner):
  match heroes_cell_func(x, y):
    case Cell{terrain, site, movement_cost, passable}:
      kingdom_visit_site_func(site, world, kingdom, owner)

assert kingdom_move_func:
  forall kingdom: Kingdom
  forall direction: Direction
  forall world: World
  forall owner: Owner
  MoveResult

def kingdom_move_func(kingdom, direction, world, owner):
  match kingdom:
    case Kingdom{resources, hero, town}:
      match hero_move_func(direction, hero):
        case HeroMove{next_hero, x, y, False{}}:
          MoveResult{Kingdom{resources, next_hero, town}, world, Adventure{}, "That move is outside the map, impassable, or beyond today's movement points."}
        case HeroMove{next_hero, x, y, True{}}:
          kingdom_visit_func(x, y, world, Kingdom{resources, next_hero, town}, owner)

# World-Section
# =============

assert world_income_func:
  forall world: World
  WorldIncome

def world_income_func(world):
  match world:
    case World{gold, wood, shrine, artifact, Red{}, Red{}, guardian}:
      WorldIncome{World{gold, wood, shrine, artifact, Red{}, Red{}, guardian}, 1000, 2, 0, 0}
    case World{gold, wood, shrine, artifact, Red{}, Blue{}, guardian}:
      WorldIncome{World{gold, wood, shrine, artifact, Red{}, Blue{}, guardian}, 0, 2, 1000, 0}
    case World{gold, wood, shrine, artifact, Red{}, Neutral{}, guardian}:
      WorldIncome{World{gold, wood, shrine, artifact, Red{}, Neutral{}, guardian}, 0, 2, 0, 0}
    case World{gold, wood, shrine, artifact, Blue{}, Red{}, guardian}:
      WorldIncome{World{gold, wood, shrine, artifact, Blue{}, Red{}, guardian}, 1000, 0, 0, 2}
    case World{gold, wood, shrine, artifact, Blue{}, Blue{}, guardian}:
      WorldIncome{World{gold, wood, shrine, artifact, Blue{}, Blue{}, guardian}, 0, 0, 1000, 2}
    case World{gold, wood, shrine, artifact, Blue{}, Neutral{}, guardian}:
      WorldIncome{World{gold, wood, shrine, artifact, Blue{}, Neutral{}, guardian}, 0, 0, 0, 2}
    case World{gold, wood, shrine, artifact, Neutral{}, Red{}, guardian}:
      WorldIncome{World{gold, wood, shrine, artifact, Neutral{}, Red{}, guardian}, 1000, 0, 0, 0}
    case World{gold, wood, shrine, artifact, Neutral{}, Blue{}, guardian}:
      WorldIncome{World{gold, wood, shrine, artifact, Neutral{}, Blue{}, guardian}, 0, 0, 1000, 0}
    case World{gold, wood, shrine, artifact, Neutral{}, Neutral{}, guardian}:
      WorldIncome{World{gold, wood, shrine, artifact, Neutral{}, Neutral{}, guardian}, 0, 0, 0, 0}

# Combat
# ======

assert rng_step_func:
  forall seed: U32
  forall +bound: +U32
  RngStep

def rng_step_func(seed, bound):
  next = U32.add(U32.mul(seed, 1664525), 1013904223)
  (value_seed, next_seed) = u32_pair_func(next)
  match U32.is_eq(bound, 0):
    case True{}: RngStep{0, next_seed}
    case False{}: RngStep{U32.mod(value_seed, bound), next_seed}

assert damage_percent_func:
  forall +attack: +U32
  forall +defense: +U32
  U32

def damage_percent_func(attack, defense):
  match U32.is_lt(defense, attack):
    case True{}:
      bonus = u32_min_func(300, U32.mul(U32.sub(attack, defense), 5))
      U32.add(100, bonus)
    case False{}:
      reduction = u32_min_func(70, U32.mul(U32.sub(defense, attack), 2))
      U32.sub(100, reduction)

assert ranged_percent_func:
  forall ranged: Bool
  forall percent: U32
  U32

def ranged_percent_func(ranged, percent):
  match ranged:
    case False{}: percent
    case True{}: percent

assert attack_roll_values_func:
  forall +count: +U32
  forall creature_attack: U32
  forall +damage_min: +U32
  forall +damage_max: +U32
  forall creature_defense: U32
  forall hero_attack: U32
  forall hero_defense: U32
  forall seed: U32
  forall ranged: Bool
  AttackRoll

def attack_roll_values_func(count, creature_attack, damage_min, damage_max, creature_defense, hero_attack, hero_defense, seed, ranged):
  span = U32.inc(U32.sub(damage_max, damage_min))
  match rng_step_func(seed, span):
    case RngStep{roll, next_seed}:
      rolled_damage = U32.add(damage_min, roll)
      base_damage = U32.mul(count, rolled_damage)
      percent = damage_percent_func(U32.add(creature_attack, hero_attack), U32.add(creature_defense, hero_defense))
      final_percent = ranged_percent_func(ranged, percent)
      AttackRoll{u32_at_least_one_func(U32.div(U32.mul(base_damage, final_percent), 100)), next_seed, True{}}

assert attack_roll_func:
  forall actor: Stack
  forall target: Stack
  forall hero_attack: U32
  forall hero_defense: U32
  forall seed: U32
  AttackRoll

def attack_roll_func(actor, target, hero_attack, hero_defense, seed):
  match actor target:
    case EmptyStack{} EmptyStack{}: AttackRoll{0, seed, False{}}
    case EmptyStack{} Troop{target_kind, target_count, target_first_hp}: AttackRoll{0, seed, False{}}
    case Troop{actor_kind, actor_count, actor_first_hp} EmptyStack{}: AttackRoll{0, seed, False{}}
    case Troop{actor_kind, actor_count, actor_first_hp} Troop{target_kind, target_count, target_first_hp}:
      match creature_kind_stats_func(actor_kind):
        case CreatureBundle{actor_keep, CreatureStats{creature_attack, actor_defense, damage_min, damage_max, actor_hp, actor_speed, actor_growth, actor_cost, ranged}}:
          match creature_kind_stats_func(target_kind):
            case CreatureBundle{target_keep, CreatureStats{target_attack, creature_defense, target_min, target_max, target_hp, target_speed, target_growth, target_cost, target_ranged}}:
              attack_roll_values_func(actor_count, creature_attack, damage_min, damage_max, creature_defense, hero_attack, hero_defense, seed, ranged)

assert attack_roll_defend_func:
  forall actor: Stack
  forall target: Stack
  forall hero_attack: U32
  forall +hero_defense: +U32
  forall seed: U32
  AttackRoll

def attack_roll_defend_func(actor, target, hero_attack, hero_defense, seed):
  match actor target:
    case EmptyStack{} EmptyStack{}: AttackRoll{0, seed, False{}}
    case EmptyStack{} Troop{target_kind, target_count, target_first_hp}: AttackRoll{0, seed, False{}}
    case Troop{actor_kind, actor_count, actor_first_hp} EmptyStack{}: AttackRoll{0, seed, False{}}
    case Troop{actor_kind, actor_count, actor_first_hp} Troop{target_kind, target_count, target_first_hp}:
      match creature_kind_stats_func(actor_kind):
        case CreatureBundle{actor_keep, CreatureStats{creature_attack, actor_defense, damage_min, damage_max, actor_hp, actor_speed, actor_growth, actor_cost, ranged}}:
          match creature_kind_stats_func(target_kind):
            case CreatureBundle{target_keep, CreatureStats{target_attack, creature_defense, target_min, target_max, target_hp, target_speed, target_growth, target_cost, target_ranged}}:
              (defense_for_bonus, defense_for_roll) = u32_pair_func(creature_defense)
              defend_bonus = U32.div(U32.add(defense_for_bonus, hero_defense), 5)
              attack_roll_values_func(actor_count, creature_attack, damage_min, damage_max, defense_for_roll, hero_attack, U32.add(hero_defense, defend_bonus), seed, ranged)

assert combat_attack_func:
  forall player: Army
  forall enemy: Army
  forall +own_slot: +U32
  forall +target_slot: +U32
  forall hero_attack: U32
  forall hero_defense: U32
  forall mana: U32
  forall seed: U32
  CombatTurn

def combat_attack_func(player, enemy, own_slot, target_slot, hero_attack, hero_defense, mana, seed):
  match army_select_func(player, own_slot):
    case ArmySelection{player_keep, actor}:
      match army_select_func(enemy, target_slot):
        case ArmySelection{enemy_keep, target}:
          match attack_roll_func(actor, target, hero_attack, 0, seed):
            case AttackRoll{damage, next_seed, False{}}:
              CombatTurn{player_keep, enemy_keep, mana, next_seed, 0, 0, False{}}
            case AttackRoll{damage, next_seed, True{}}:
              (damage_apply, damage_output) = u32_pair_func(damage)
              match army_damage_func(enemy_keep, target_slot, damage_apply):
                case ArmyDamage{enemy_hit, kills}:
                  match army_select_func(enemy_hit, target_slot):
                    case ArmySelection{enemy_after, retaliator}:
                      match army_select_func(player_keep, own_slot):
                        case ArmySelection{player_after, defender}:
                          match attack_roll_func(retaliator, defender, 0, hero_defense, next_seed):
                            case AttackRoll{response, final_seed, response_valid}:
                              (response_apply, response_output) = u32_pair_func(response)
                              match army_damage_func(player_after, own_slot, response_apply):
                                case ArmyDamage{player_hit, losses}:
                                  CombatTurn{player_hit, enemy_after, mana, final_seed, damage_output, response_output, True{}}

assert combat_defend_func:
  forall player: Army
  forall enemy: Army
  forall +own_slot: +U32
  forall +target_slot: +U32
  forall hero_defense: U32
  forall mana: U32
  forall seed: U32
  CombatTurn

def combat_defend_func(player, enemy, own_slot, target_slot, hero_defense, mana, seed):
  match army_select_func(enemy, target_slot):
    case ArmySelection{enemy_keep, attacker}:
      match army_select_func(player, own_slot):
        case ArmySelection{player_keep, defender}:
          match attack_roll_defend_func(attacker, defender, 0, hero_defense, seed):
            case AttackRoll{response, next_seed, False{}}:
              CombatTurn{player_keep, enemy_keep, mana, next_seed, 0, 0, False{}}
            case AttackRoll{response, next_seed, True{}}:
              (response_apply, response_output) = u32_pair_func(response)
              match army_damage_func(player_keep, own_slot, response_apply):
                case ArmyDamage{player_hit, losses}:
                  CombatTurn{player_hit, enemy_keep, mana, next_seed, 0, response_output, True{}}

assert combat_spell_func:
  forall player: Army
  forall enemy: Army
  forall +own_slot: +U32
  forall +target_slot: +U32
  forall +power: +U32
  forall hero_defense: U32
  forall +mana: +U32
  forall seed: U32
  CombatTurn

def combat_spell_func(player, enemy, own_slot, target_slot, power, hero_defense, mana, seed):
  match U32.is_le(5, mana):
    case False{}: CombatTurn{player, enemy, mana, seed, 0, 0, False{}}
    case True{}:
      match army_select_func(enemy, target_slot):
        case ArmySelection{enemy_keep, target}:
          match stack_check_func(target):
            case StackCheck{target_keep, True{}}:
              CombatTurn{player, enemy_keep, mana, seed, 0, 0, False{}}
            case StackCheck{target_keep, False{}}:
              spell_damage = U32.add(10, U32.mul(power, 10))
              (damage_apply, damage_output) = u32_pair_func(spell_damage)
              match army_damage_func(enemy_keep, target_slot, damage_apply):
                case ArmyDamage{enemy_hit, kills}:
                  match army_select_func(enemy_hit, target_slot):
                    case ArmySelection{enemy_after, retaliator}:
                      match army_select_func(player, own_slot):
                        case ArmySelection{player_keep, defender}:
                          match attack_roll_func(retaliator, defender, 0, hero_defense, seed):
                            case AttackRoll{response, next_seed, response_valid}:
                              (response_apply, response_output) = u32_pair_func(response)
                              match army_damage_func(player_keep, own_slot, response_apply):
                                case ArmyDamage{player_hit, losses}:
                                  CombatTurn{player_hit, enemy_after, U32.sub(mana, 5), next_seed, damage_output, response_output, True{}}

assert hero_rebuild_func:
  forall name: String
  forall x: U32
  forall y: U32
  forall movement: U32
  forall attack: U32
  forall defense: U32
  forall power: U32
  forall knowledge: U32
  forall mana: U32
  forall level: U32
  forall experience: U32
  forall army: Army
  Hero

def hero_rebuild_func(name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army):
  Hero{name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army}

assert kingdom_defeat_func:
  forall attacker: Owner
  forall resources: Resources
  forall name: String
  forall x: U32
  forall y: U32
  forall attack: U32
  forall defense: U32
  forall power: U32
  forall knowledge: U32
  forall mana: U32
  forall level: U32
  forall experience: U32
  forall player: Army
  forall town: Town
  forall source: BattleSource
  forall enemy: Army
  forall seed: U32
  KingdomBattle

def kingdom_defeat_func(attacker, resources, name, x, y, attack, defense, power, knowledge, mana, level, experience, player, town, source, enemy, seed):
  match attacker:
    case Neutral{}:
      KingdomBattle{Kingdom{resources, hero_rebuild_func(name, x, y, 0, attack, defense, power, knowledge, mana, level, experience, player), town}, BattleEnded{Neutral{}, source, enemy}, seed, "Defeat: the hero's army was destroyed."}
    case Red{}:
      KingdomBattle{Kingdom{resources, hero_rebuild_func(name, 1, 5, 0, attack, defense, power, knowledge, mana, level, experience, player), town}, BattleEnded{Red{}, source, enemy}, seed, "Defeat: the hero escaped to the Castle without an army."}
    case Blue{}:
      KingdomBattle{Kingdom{resources, hero_rebuild_func(name, 7, 1, 0, attack, defense, power, knowledge, mana, level, experience, player), town}, BattleEnded{Blue{}, source, enemy}, seed, "Defeat: the hero escaped to the Necropolis without an army."}

assert kingdom_finish_combat_func:
  forall resources: Resources
  forall name: String
  forall x: U32
  forall y: U32
  forall movement: U32
  forall attack: U32
  forall defense: U32
  forall power: U32
  forall knowledge: U32
  forall level: U32
  forall experience: U32
  forall town: Town
  forall attacker: Owner
  forall source: BattleSource
  forall round: U32
  forall turn: CombatTurn
  KingdomBattle

def kingdom_finish_combat_func(resources, name, x, y, movement, attack, defense, power, knowledge, level, experience, town, attacker, source, round, turn):
  match turn:
    case CombatTurn{player, enemy, mana, next_seed, dealt, received, False{}}:
      KingdomBattle{
        Kingdom{resources, hero_rebuild_func(name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, player), town},
        BattleContinues{Battle{attacker, source, enemy, round}},
        next_seed,
        "Choose occupied army slots; the rejected combat command changed nothing."
      }
    case CombatTurn{player, enemy, mana, next_seed, dealt, received, True{}}:
      match army_check_func(enemy):
        case ArmyCheck{enemy_keep, True{}}:
          KingdomBattle{
            Kingdom{
              resources_add_gold_func(resources, 1500),
              hero_gain_func(hero_rebuild_func(name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army_heal_func(player)), 1200),
              town
            },
            BattleWon{attacker, source},
            next_seed,
            "Victory: the enemy army fell; 1200 experience and 1500 gold were awarded."
          }
        case ArmyCheck{enemy_keep, False{}}:
          match army_check_func(player):
            case ArmyCheck{player_keep, True{}}:
              kingdom_defeat_func(attacker, resources, name, x, y, attack, defense, power, knowledge, mana, level, experience, player_keep, town, source, enemy_keep, next_seed)
            case ArmyCheck{player_keep, False{}}:
              KingdomBattle{
                Kingdom{resources, hero_rebuild_func(name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, player_keep), town},
                BattleContinues{Battle{attacker, source, enemy_keep, U32.inc(round)}},
                next_seed,
                "The exchange resolved using Core's attack/defense damage formula."
              }

assert kingdom_retreat_func:
  forall attacker: Owner
  forall resources: Resources
  forall name: String
  forall attack: U32
  forall defense: U32
  forall power: U32
  forall knowledge: U32
  forall mana: U32
  forall level: U32
  forall experience: U32
  forall town: Town
  forall source: BattleSource
  forall enemy: Army
  forall seed: U32
  KingdomBattle

def kingdom_retreat_func(attacker, resources, name, attack, defense, power, knowledge, mana, level, experience, town, source, enemy, seed):
  match attacker:
    case Neutral{}:
      KingdomBattle{Kingdom{resources, Hero{name, 0, 0, 0, attack, defense, power, knowledge, mana, level, experience, army_empty_func()}, town}, BattleEnded{Neutral{}, source, enemy}, seed, "The hero retreated and lost the whole army."}
    case Red{}:
      KingdomBattle{Kingdom{resources, Hero{name, 1, 5, 0, attack, defense, power, knowledge, mana, level, experience, army_empty_func()}, town}, BattleEnded{Red{}, source, enemy}, seed, "The hero retreated to the Castle and lost the whole army."}
    case Blue{}:
      KingdomBattle{Kingdom{resources, Hero{name, 7, 1, 0, attack, defense, power, knowledge, mana, level, experience, army_empty_func()}, town}, BattleEnded{Blue{}, source, enemy}, seed, "The hero retreated to the Necropolis and lost the whole army."}

assert kingdom_combat_attack_case_func:
  forall resources: Resources
  forall name: String
  forall x: U32
  forall y: U32
  forall movement: U32
  forall +attack: +U32
  forall +defense: +U32
  forall power: U32
  forall knowledge: U32
  forall mana: U32
  forall level: U32
  forall experience: U32
  forall army: Army
  forall town: Town
  forall attacker: Owner
  forall source: BattleSource
  forall enemy: Army
  forall round: U32
  forall own_slot: U32
  forall target_slot: U32
  forall seed: U32
  KingdomBattle

def kingdom_combat_attack_case_func(resources, name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army, town, attacker, source, enemy, round, own_slot, target_slot, seed):
  kingdom_finish_combat_func(resources, name, x, y, movement, attack, defense, power, knowledge, level, experience, town, attacker, source, round, combat_attack_func(army, enemy, own_slot, target_slot, attack, defense, mana, seed))

assert kingdom_combat_defend_case_func:
  forall resources: Resources
  forall name: String
  forall x: U32
  forall y: U32
  forall movement: U32
  forall attack: U32
  forall +defense: +U32
  forall power: U32
  forall knowledge: U32
  forall mana: U32
  forall level: U32
  forall experience: U32
  forall army: Army
  forall town: Town
  forall attacker: Owner
  forall source: BattleSource
  forall enemy: Army
  forall round: U32
  forall own_slot: U32
  forall target_slot: U32
  forall seed: U32
  KingdomBattle

def kingdom_combat_defend_case_func(resources, name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army, town, attacker, source, enemy, round, own_slot, target_slot, seed):
  kingdom_finish_combat_func(resources, name, x, y, movement, attack, defense, power, knowledge, level, experience, town, attacker, source, round, combat_defend_func(army, enemy, own_slot, target_slot, defense, mana, seed))

assert kingdom_combat_spell_case_func:
  forall resources: Resources
  forall name: String
  forall x: U32
  forall y: U32
  forall movement: U32
  forall attack: U32
  forall +defense: +U32
  forall +power: +U32
  forall knowledge: U32
  forall mana: U32
  forall level: U32
  forall experience: U32
  forall army: Army
  forall town: Town
  forall attacker: Owner
  forall source: BattleSource
  forall enemy: Army
  forall round: U32
  forall own_slot: U32
  forall target_slot: U32
  forall seed: U32
  KingdomBattle

def kingdom_combat_spell_case_func(resources, name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army, town, attacker, source, enemy, round, own_slot, target_slot, seed):
  kingdom_finish_combat_func(resources, name, x, y, movement, attack, defense, power, knowledge, level, experience, town, attacker, source, round, combat_spell_func(army, enemy, own_slot, target_slot, power, defense, mana, seed))

assert kingdom_battle_command_func:
  forall kingdom: Kingdom
  forall battle: Battle
  forall command: U32
  forall own_slot: U32
  forall target_slot: U32
  forall seed: U32
  KingdomBattle

def kingdom_battle_command_func(kingdom, battle, command, own_slot, target_slot, seed):
  match kingdom battle:
    case Kingdom{resources, Hero{name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army}, town} Battle{attacker, source, enemy, round}:
      match U32.to_nat(command):
        case 20n:
          kingdom_combat_attack_case_func(resources, name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army, town, attacker, source, enemy, round, own_slot, target_slot, seed)
        case 21n:
          kingdom_combat_defend_case_func(resources, name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army, town, attacker, source, enemy, round, own_slot, target_slot, seed)
        case 22n:
          kingdom_combat_spell_case_func(resources, name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army, town, attacker, source, enemy, round, own_slot, target_slot, seed)
        case 23n:
          kingdom_retreat_func(attacker, resources, name, attack, defense, power, knowledge, mana, level, experience, town, source, enemy, seed)
        case other:
          KingdomBattle{Kingdom{resources, Hero{name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army}, town}, BattleContinues{Battle{attacker, source, enemy, round}}, seed, "That command is not available during combat."}

assert world_restore_battle_func:
  forall world: World
  forall source: BattleSource
  forall enemy: Army
  World

def world_restore_battle_func(world, source, enemy):
  match world source:
    case World{gold, wood, shrine, artifact, sawmill, gold_mine, old_guardian} GuardianBattle{}:
      World{gold, wood, shrine, artifact, sawmill, gold_mine, enemy}
    case World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian} EnemyTownBattle{}:
      World{gold, wood, shrine, artifact, sawmill, gold_mine, guardian}

# Game
# ====

assert bool_pair_func:
  forall value: Bool
  Bool & Bool

def bool_pair_func(value):
  match value:
    case False{}: (False{}, False{})
    case True{}: (True{}, True{})

assert red_army_func:
  Army

def red_army_func():
  Army{Troop{Pikeman{}, 30, 10}, Troop{Archer{}, 12, 10}, EmptyStack{}, EmptyStack{}, EmptyStack{}, EmptyStack{}, EmptyStack{}}

assert blue_army_func:
  Army

def blue_army_func():
  Army{Troop{Skeleton{}, 40, 6}, EmptyStack{}, Troop{Wight{}, 9, 18}, EmptyStack{}, EmptyStack{}, EmptyStack{}, EmptyStack{}}

assert initial_resources_func:
  Resources

def initial_resources_func():
  Resources{10000, 20, 20, 5, 5, 5, 5}

assert red_kingdom_func:
  Kingdom

def red_kingdom_func():
  Kingdom{
    initial_resources_func(),
    Hero{"Catherine", 1, 5, 1600, 3, 3, 1, 1, 10, 1, 0, red_army_func()},
    Town{Castle{}, 1, 0, 3, False{}, Stock{14, 9, 0, 0, 0, 0, 0}}
  }

assert blue_kingdom_func:
  Kingdom

def blue_kingdom_func():
  Kingdom{
    initial_resources_func(),
    Hero{"Sandro", 7, 1, 1600, 2, 2, 2, 2, 20, 1, 0, blue_army_func()},
    Town{Necropolis{}, 1, 0, 7, False{}, Stock{12, 8, 7, 0, 0, 0, 0}}
  }

assert heroes_initial_func:
  forall seed: U32
  Game

def heroes_initial_func(seed):
  Game{
    3,
    1,
    Red{},
    red_kingdom_func(),
    blue_kingdom_func(),
    World{True{}, True{}, True{}, True{}, Neutral{}, Neutral{}, guardian_army_func()},
    Adventure{},
    seed,
    0,
    "Red begins Month 1, Week 1, Day 1 at the Castle."
  }

assert game_notice_func:
  forall game: Game
  forall notice: String
  Game

def game_notice_func(game, notice):
  match game:
    case Game{scenario, day, active, red, blue, world, phase, seed, turn, old_notice}:
      Game{scenario, day, active, red, blue, world, phase, seed, turn, notice}

assert game_move_func:
  forall game: Game
  forall direction: Direction
  Game

def game_move_func(game, direction):
  match game:
    case Game{scenario, day, Red{}, red, blue, world, Adventure{}, seed, turn, notice}:
      match kingdom_move_func(red, direction, world, Red{}):
        case MoveResult{next_red, next_world, next_phase, next_notice}:
          Game{scenario, day, Red{}, next_red, blue, next_world, next_phase, seed, U32.inc(turn), next_notice}
    case Game{scenario, day, Blue{}, red, blue, world, Adventure{}, seed, turn, notice}:
      match kingdom_move_func(blue, direction, world, Blue{}):
        case MoveResult{next_blue, next_world, next_phase, next_notice}:
          Game{scenario, day, Blue{}, red, next_blue, next_world, next_phase, seed, U32.inc(turn), next_notice}
    case Game{scenario, day, Neutral{}, red, blue, world, Adventure{}, seed, turn, notice}:
      Game{scenario, day, Neutral{}, red, blue, world, Adventure{}, seed, turn, "No player owns the current turn."}
    case Game{scenario, day, active, red, blue, world, Combat{battle}, seed, turn, notice}:
      Game{scenario, day, active, red, blue, world, Combat{battle}, seed, turn, "Adventure movement is suspended until combat ends."}
    case Game{scenario, day, active, red, blue, world, Victory{winner}, seed, turn, notice}:
      Game{scenario, day, active, red, blue, world, Victory{winner}, seed, turn, "The scenario is over; begin a new game to continue."}

assert game_build_hall_func:
  forall game: Game
  Game

def game_build_hall_func(game):
  match game:
    case Game{scenario, day, Red{}, red, blue, world, Adventure{}, seed, turn, notice}:
      match kingdom_build_hall_func(red):
        case (next_red, next_notice): Game{scenario, day, Red{}, next_red, blue, world, Adventure{}, seed, U32.inc(turn), next_notice}
    case Game{scenario, day, Blue{}, red, blue, world, Adventure{}, seed, turn, notice}:
      match kingdom_build_hall_func(blue):
        case (next_blue, next_notice): Game{scenario, day, Blue{}, red, next_blue, world, Adventure{}, seed, U32.inc(turn), next_notice}
    case Game{scenario, day, Neutral{}, red, blue, world, phase, seed, turn, notice}:
      Game{scenario, day, Neutral{}, red, blue, world, phase, seed, turn, "No player may build during this turn."}
    case Game{scenario, day, active, red, blue, world, Combat{battle}, seed, turn, notice}:
      Game{scenario, day, active, red, blue, world, Combat{battle}, seed, turn, "Town construction is unavailable during combat."}
    case Game{scenario, day, active, red, blue, world, Victory{winner}, seed, turn, notice}:
      Game{scenario, day, active, red, blue, world, Victory{winner}, seed, turn, "The scenario is already complete."}

assert game_build_fort_func:
  forall game: Game
  Game

def game_build_fort_func(game):
  match game:
    case Game{scenario, day, Red{}, red, blue, world, Adventure{}, seed, turn, notice}:
      match kingdom_build_fort_func(red):
        case (next_red, next_notice): Game{scenario, day, Red{}, next_red, blue, world, Adventure{}, seed, U32.inc(turn), next_notice}
    case Game{scenario, day, Blue{}, red, blue, world, Adventure{}, seed, turn, notice}:
      match kingdom_build_fort_func(blue):
        case (next_blue, next_notice): Game{scenario, day, Blue{}, red, next_blue, world, Adventure{}, seed, U32.inc(turn), next_notice}
    case Game{scenario, day, Neutral{}, red, blue, world, phase, seed, turn, notice}:
      Game{scenario, day, Neutral{}, red, blue, world, phase, seed, turn, "No player may build during this turn."}
    case Game{scenario, day, active, red, blue, world, Combat{battle}, seed, turn, notice}:
      Game{scenario, day, active, red, blue, world, Combat{battle}, seed, turn, "Town construction is unavailable during combat."}
    case Game{scenario, day, active, red, blue, world, Victory{winner}, seed, turn, notice}:
      Game{scenario, day, active, red, blue, world, Victory{winner}, seed, turn, "The scenario is already complete."}

assert game_build_dwelling_func:
  forall game: Game
  forall tier: U32
  Game

def game_build_dwelling_func(game, tier):
  match game:
    case Game{scenario, day, Red{}, red, blue, world, Adventure{}, seed, turn, notice}:
      match kingdom_build_dwelling_func(red, tier):
        case (next_red, next_notice): Game{scenario, day, Red{}, next_red, blue, world, Adventure{}, seed, U32.inc(turn), next_notice}
    case Game{scenario, day, Blue{}, red, blue, world, Adventure{}, seed, turn, notice}:
      match kingdom_build_dwelling_func(blue, tier):
        case (next_blue, next_notice): Game{scenario, day, Blue{}, red, next_blue, world, Adventure{}, seed, U32.inc(turn), next_notice}
    case Game{scenario, day, Neutral{}, red, blue, world, phase, seed, turn, notice}:
      Game{scenario, day, Neutral{}, red, blue, world, phase, seed, turn, "No player may build during this turn."}
    case Game{scenario, day, active, red, blue, world, Combat{battle}, seed, turn, notice}:
      Game{scenario, day, active, red, blue, world, Combat{battle}, seed, turn, "Town construction is unavailable during combat."}
    case Game{scenario, day, active, red, blue, world, Victory{winner}, seed, turn, notice}:
      Game{scenario, day, active, red, blue, world, Victory{winner}, seed, turn, "The scenario is already complete."}

assert game_recruit_func:
  forall game: Game
  forall tier: U32
  forall amount: U32
  Game

def game_recruit_func(game, tier, amount):
  match game:
    case Game{scenario, day, Red{}, red, blue, world, Adventure{}, seed, turn, notice}:
      match kingdom_recruit_func(red, tier, amount):
        case (next_red, next_notice): Game{scenario, day, Red{}, next_red, blue, world, Adventure{}, seed, U32.inc(turn), next_notice}
    case Game{scenario, day, Blue{}, red, blue, world, Adventure{}, seed, turn, notice}:
      match kingdom_recruit_func(blue, tier, amount):
        case (next_blue, next_notice): Game{scenario, day, Blue{}, red, next_blue, world, Adventure{}, seed, U32.inc(turn), next_notice}
    case Game{scenario, day, Neutral{}, red, blue, world, phase, seed, turn, notice}:
      Game{scenario, day, Neutral{}, red, blue, world, phase, seed, turn, "No player may recruit during this turn."}
    case Game{scenario, day, active, red, blue, world, Combat{battle}, seed, turn, notice}:
      Game{scenario, day, active, red, blue, world, Combat{battle}, seed, turn, "Recruitment is unavailable during combat."}
    case Game{scenario, day, active, red, blue, world, Victory{winner}, seed, turn, notice}:
      Game{scenario, day, active, red, blue, world, Victory{winner}, seed, turn, "The scenario is already complete."}

assert game_end_day_values_func:
  forall scenario: U32
  forall +day: +U32
  forall red: Kingdom
  forall blue: Kingdom
  forall world: World
  forall seed: U32
  forall turn: U32
  Game

def game_end_day_values_func(scenario, day, red, blue, world, seed, turn):
  match world_income_func(world):
    case WorldIncome{next_world, red_gold, red_wood, blue_gold, blue_wood}:
      next_day = U32.inc(day)
      (week_day, output_day) = u32_pair_func(next_day)
      week_start = U32.is_eq(U32.mod(U32.sub(week_day, 1), 7), 0)
      (red_week, blue_week) = bool_pair_func(week_start)
      next_red = kingdom_new_day_func(red, red_gold, red_wood, red_week)
      next_blue = kingdom_new_day_func(blue, blue_gold, blue_wood, blue_week)
      Game{scenario, output_day, Red{}, next_red, next_blue, next_world, Adventure{}, seed, U32.inc(turn), "A new day began: income was credited, movement and mana refreshed, and weekly growth applied when due."}

assert game_end_turn_func:
  forall game: Game
  Game

def game_end_turn_func(game):
  match game:
    case Game{scenario, day, Red{}, red, blue, world, Adventure{}, seed, turn, notice}:
      Game{scenario, day, Blue{}, red, blue, world, Adventure{}, seed, U32.inc(turn), "Red ended the turn. Blue may now act."}
    case Game{scenario, day, Blue{}, red, blue, world, Adventure{}, seed, turn, notice}:
      game_end_day_values_func(scenario, day, red, blue, world, seed, turn)
    case Game{scenario, day, Neutral{}, red, blue, world, phase, seed, turn, notice}:
      Game{scenario, day, Neutral{}, red, blue, world, phase, seed, turn, "No active player can end this turn."}
    case Game{scenario, day, active, red, blue, world, Combat{battle}, seed, turn, notice}:
      Game{scenario, day, active, red, blue, world, Combat{battle}, seed, turn, "Combat must be resolved before ending the adventure turn."}
    case Game{scenario, day, active, red, blue, world, Victory{winner}, seed, turn, notice}:
      Game{scenario, day, active, red, blue, world, Victory{winner}, seed, turn, "The scenario is already complete."}

assert game_red_battle_result_func:
  forall scenario: U32
  forall day: U32
  forall blue: Kingdom
  forall world: World
  forall turn: U32
  forall result: KingdomBattle
  Game

def game_red_battle_result_func(scenario, day, blue, world, turn, result):
  match result:
    case KingdomBattle{red, BattleContinues{battle}, next_seed, notice}:
      Game{scenario, day, Red{}, red, blue, world, Combat{battle}, next_seed, U32.inc(turn), notice}
    case KingdomBattle{red, BattleWon{attacker, GuardianBattle{}}, next_seed, notice}:
      Game{scenario, day, Red{}, red, blue, world, Adventure{}, next_seed, U32.inc(turn), notice}
    case KingdomBattle{red, BattleWon{attacker, EnemyTownBattle{}}, next_seed, notice}:
      Game{scenario, day, Red{}, red, blue, world, Victory{Red{}}, next_seed, U32.inc(turn), "Red captured the Necropolis and won the scenario."}
    case KingdomBattle{red, BattleEnded{attacker, GuardianBattle{}, enemy}, next_seed, notice}:
      Game{scenario, day, Red{}, red, blue, world_restore_battle_func(world, GuardianBattle{}, enemy), Adventure{}, next_seed, U32.inc(turn), notice}
    case KingdomBattle{red, BattleEnded{attacker, EnemyTownBattle{}, enemy}, next_seed, notice}:
      Game{scenario, day, Red{}, red, blue, world, Adventure{}, next_seed, U32.inc(turn), notice}

assert game_blue_battle_result_func:
  forall scenario: U32
  forall day: U32
  forall red: Kingdom
  forall world: World
  forall turn: U32
  forall result: KingdomBattle
  Game

def game_blue_battle_result_func(scenario, day, red, world, turn, result):
  match result:
    case KingdomBattle{blue, BattleContinues{battle}, next_seed, notice}:
      Game{scenario, day, Blue{}, red, blue, world, Combat{battle}, next_seed, U32.inc(turn), notice}
    case KingdomBattle{blue, BattleWon{attacker, GuardianBattle{}}, next_seed, notice}:
      Game{scenario, day, Blue{}, red, blue, world, Adventure{}, next_seed, U32.inc(turn), notice}
    case KingdomBattle{blue, BattleWon{attacker, EnemyTownBattle{}}, next_seed, notice}:
      Game{scenario, day, Blue{}, red, blue, world, Victory{Blue{}}, next_seed, U32.inc(turn), "Blue captured the Castle and won the scenario."}
    case KingdomBattle{blue, BattleEnded{attacker, GuardianBattle{}, enemy}, next_seed, notice}:
      Game{scenario, day, Blue{}, red, blue, world_restore_battle_func(world, GuardianBattle{}, enemy), Adventure{}, next_seed, U32.inc(turn), notice}
    case KingdomBattle{blue, BattleEnded{attacker, EnemyTownBattle{}, enemy}, next_seed, notice}:
      Game{scenario, day, Blue{}, red, blue, world, Adventure{}, next_seed, U32.inc(turn), notice}

assert game_combat_func:
  forall game: Game
  forall command: U32
  forall own_slot: U32
  forall target_slot: U32
  Game

def game_combat_func(game, command, own_slot, target_slot):
  match game:
    case Game{scenario, day, Red{}, red, blue, world, Combat{battle}, seed, turn, notice}:
      game_red_battle_result_func(scenario, day, blue, world, turn, kingdom_battle_command_func(red, battle, command, own_slot, target_slot, seed))
    case Game{scenario, day, Blue{}, red, blue, world, Combat{battle}, seed, turn, notice}:
      game_blue_battle_result_func(scenario, day, red, world, turn, kingdom_battle_command_func(blue, battle, command, own_slot, target_slot, seed))
    case Game{scenario, day, Neutral{}, red, blue, world, phase, seed, turn, notice}:
      Game{scenario, day, Neutral{}, red, blue, world, phase, seed, turn, "No player controls this battle."}
    case Game{scenario, day, active, red, blue, world, Adventure{}, seed, turn, notice}:
      Game{scenario, day, active, red, blue, world, Adventure{}, seed, turn, "Combat commands are only legal while a battle is active."}
    case Game{scenario, day, active, red, blue, world, Victory{winner}, seed, turn, notice}:
      Game{scenario, day, active, red, blue, world, Victory{winner}, seed, turn, "The scenario is already complete."}

assert heroes_step_nat_func:
  forall command: Nat
  forall game: Game
  forall arg0: U32
  forall arg1: U32
  Game

def heroes_step_nat_func(command, game, arg0, arg1):
  match command:
    case 0n: game_move_func(game, North{})
    case 1n: game_move_func(game, East{})
    case 2n: game_move_func(game, South{})
    case 3n: game_move_func(game, West{})
    case 4n: game_end_turn_func(game)
    case 5n: game_build_hall_func(game)
    case 6n: game_build_fort_func(game)
    case 7n: game_build_dwelling_func(game, arg0)
    case 8n: game_recruit_func(game, arg0, arg1)
    case 9n: game_move_func(game, NorthEast{})
    case 10n: game_move_func(game, SouthEast{})
    case 11n: game_move_func(game, SouthWest{})
    case 12n: game_move_func(game, NorthWest{})
    case 20n: game_combat_func(game, 20, arg0, arg1)
    case 21n: game_combat_func(game, 21, arg0, arg1)
    case 22n: game_combat_func(game, 22, arg0, arg1)
    case 23n: game_combat_func(game, 23, arg0, arg1)
    case other: game_notice_func(game, "Unknown command; the state was preserved.")

assert heroes_browser_step_func:
  forall game: Game
  forall command: U32
  forall arg0: U32
  forall arg1: U32
  Game

def heroes_browser_step_func(game, command, arg0, arg1):
  heroes_step_nat_func(U32.to_nat(command), game, arg0, arg1)

assert heroes_damage_probe_func:
  forall damage: U32
  StackDamage

def heroes_damage_probe_func(damage):
  stack_damage_func(Troop{Pikeman{}, 3, 10}, damage)

# Verification
# ============

assert heroes_self_check_func:
  Bool

def heroes_self_check_func():
  match heroes_initial_func(17):
    case Game{scenario, day, Red{}, red, blue, world, Adventure{}, seed, turn, notice}:
      match heroes_cell_func(4, 3):
        case Cell{Grass{}, GuardianSite{}, cost, True{}}:
          Bool.and(U32.is_eq(cost, 100), Bool.and(U32.is_eq(scenario, 3), Bool.and(U32.is_eq(day, 1), U32.is_eq(seed, 17))))
        case Cell{terrain, site, cost, passable}: False{}
    case Game{scenario, day, active, red, blue, world, phase, seed, turn, notice}: False{}

assert main_value:
  Game

def main_value():
  heroes_initial_func(1337)

assert main_show_bool_func:
  forall value: Bool
  IO(Unit)

def main_show_bool_func(value):
  match value:
    case False{}: IO.print("False{}")
    case True{}: IO.print("True{}")

assert main_accept_value_func:
  forall game: Game
  IO(Unit)

def main_accept_value_func(game):
  main_show_bool_func(heroes_self_check_func())

assert main:
  IO(Unit)

def main():
  main_accept_value_func(main_value!())
