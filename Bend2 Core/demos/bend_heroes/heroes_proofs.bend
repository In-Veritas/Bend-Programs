import Base
import ./heroes.bend as Heroes

# Bend Heroes semantic proofs
# ===========================
#
# Every definition in this file returns equality evidence.  There are no
# shadow transition functions, executable specifications, copied game rules,
# or finite input/output tables.  Each theorem mentions the implementation it
# verifies directly and quantifies over the live data admitted by that rule.

# Ownership
# =========

assert owner_other_involution_theorem:
  forall owner: Heroes.Owner
  {Heroes.owner_other_func(Heroes.owner_other_func(owner)) == owner : Heroes.Owner}

def owner_other_involution_theorem(owner):
  match owner:
    case Heroes.Neutral{}: {==}
    case Heroes.Red{}: {==}
    case Heroes.Blue{}: {==}

# Resources
# =========

assert resources_add_gold_exact_theorem:
  forall gold: U32
  forall wood: U32
  forall ore: U32
  forall mercury: U32
  forall sulfur: U32
  forall crystal: U32
  forall gems: U32
  forall amount: U32
  {
    Heroes.resources_add_gold_func(
      Heroes.Resources{gold, wood, ore, mercury, sulfur, crystal, gems},
      amount
    )
    == Heroes.Resources{
      U32.add(gold, amount), wood, ore, mercury, sulfur, crystal, gems
    }
    : Heroes.Resources
  }

def resources_add_gold_exact_theorem(gold, wood, ore, mercury, sulfur, crystal, gems, amount):
  {==}

assert resources_add_wood_exact_theorem:
  forall gold: U32
  forall wood: U32
  forall ore: U32
  forall mercury: U32
  forall sulfur: U32
  forall crystal: U32
  forall gems: U32
  forall amount: U32
  {
    Heroes.resources_add_wood_func(
      Heroes.Resources{gold, wood, ore, mercury, sulfur, crystal, gems},
      amount
    )
    == Heroes.Resources{
      gold, U32.add(wood, amount), ore, mercury, sulfur, crystal, gems
    }
    : Heroes.Resources
  }

def resources_add_wood_exact_theorem(gold, wood, ore, mercury, sulfur, crystal, gems, amount):
  {==}

# Stack
# =====

assert empty_stack_damage_is_a_noop_theorem:
  forall damage: U32
  {
    Heroes.stack_damage_func(Heroes.EmptyStack{}, damage)
    == Heroes.StackDamage{Heroes.EmptyStack{}, 0}
    : Heroes.StackDamage
  }

def empty_stack_damage_is_a_noop_theorem(damage):
  {==}

# Terrain
# =======

assert grass_cell_rule_theorem:
  forall site: Heroes.Site
  {
    Heroes.terrain_cell_func(Heroes.Grass{}, site)
    == Heroes.Cell{Heroes.Grass{}, site, 100, True{}}
    : Heroes.Cell
  }

def grass_cell_rule_theorem(site):
  {==}

assert dirt_cell_rule_theorem:
  forall site: Heroes.Site
  {
    Heroes.terrain_cell_func(Heroes.Dirt{}, site)
    == Heroes.Cell{Heroes.Dirt{}, site, 100, True{}}
    : Heroes.Cell
  }

def dirt_cell_rule_theorem(site):
  {==}

assert rough_cell_rule_theorem:
  forall site: Heroes.Site
  {
    Heroes.terrain_cell_func(Heroes.Rough{}, site)
    == Heroes.Cell{Heroes.Rough{}, site, 125, True{}}
    : Heroes.Cell
  }

def rough_cell_rule_theorem(site):
  {==}

assert swamp_cell_rule_theorem:
  forall site: Heroes.Site
  {
    Heroes.terrain_cell_func(Heroes.Swamp{}, site)
    == Heroes.Cell{Heroes.Swamp{}, site, 175, True{}}
    : Heroes.Cell
  }

def swamp_cell_rule_theorem(site):
  {==}

assert water_cell_rule_theorem:
  forall site: Heroes.Site
  {
    Heroes.terrain_cell_func(Heroes.Water{}, site)
    == Heroes.Cell{Heroes.Water{}, site, 100, False{}}
    : Heroes.Cell
  }

def water_cell_rule_theorem(site):
  {==}

assert rock_cell_rule_theorem:
  forall site: Heroes.Site
  {
    Heroes.terrain_cell_func(Heroes.Rock{}, site)
    == Heroes.Cell{Heroes.Rock{}, site, 0, False{}}
    : Heroes.Cell
  }

def rock_cell_rule_theorem(site):
  {==}

# Movement
# ========

assert cardinal_movement_cost_is_exact_theorem:
  forall movement_cost: U32
  {
    Heroes.movement_direction_cost_func(False{}, movement_cost)
    == movement_cost
    : U32
  }

def cardinal_movement_cost_is_exact_theorem(movement_cost):
  {==}

assert diagonal_movement_cost_is_rounded_141_percent_theorem:
  forall movement_cost: U32
  {
    Heroes.movement_direction_cost_func(True{}, movement_cost)
    == U32.div(U32.add(U32.mul(movement_cost, 141), 50), 100)
    : U32
  }

def diagonal_movement_cost_is_rounded_141_percent_theorem(movement_cost):
  {==}

assert north_map_edge_blocks_without_changing_coordinates_theorem:
  forall x: U32
  {
    Heroes.coordinate_step_func(Heroes.North{}, x, 0)
    == Heroes.Coordinate{x, 0, False{}, False{}}
    : Heroes.Coordinate
  }

def north_map_edge_blocks_without_changing_coordinates_theorem(x):
  {==}

assert north_interior_step_changes_only_y_theorem:
  forall x: U32
  {
    Heroes.coordinate_step_func(Heroes.North{}, x, 1)
    == Heroes.Coordinate{x, 0, True{}, False{}}
    : Heroes.Coordinate
  }

def north_interior_step_changes_only_y_theorem(x):
  {==}

assert east_map_edge_blocks_without_changing_coordinates_theorem:
  forall y: U32
  {
    Heroes.coordinate_step_func(Heroes.East{}, 8, y)
    == Heroes.Coordinate{8, y, False{}, False{}}
    : Heroes.Coordinate
  }

def east_map_edge_blocks_without_changing_coordinates_theorem(y):
  {==}

assert east_interior_step_changes_only_x_theorem:
  forall y: U32
  {
    Heroes.coordinate_step_func(Heroes.East{}, 7, y)
    == Heroes.Coordinate{8, y, True{}, False{}}
    : Heroes.Coordinate
  }

def east_interior_step_changes_only_x_theorem(y):
  {==}

assert south_map_edge_blocks_without_changing_coordinates_theorem:
  forall x: U32
  {
    Heroes.coordinate_step_func(Heroes.South{}, x, 6)
    == Heroes.Coordinate{x, 6, False{}, False{}}
    : Heroes.Coordinate
  }

def south_map_edge_blocks_without_changing_coordinates_theorem(x):
  {==}

assert south_interior_step_changes_only_y_theorem:
  forall x: U32
  {
    Heroes.coordinate_step_func(Heroes.South{}, x, 5)
    == Heroes.Coordinate{x, 6, True{}, False{}}
    : Heroes.Coordinate
  }

def south_interior_step_changes_only_y_theorem(x):
  {==}

assert west_map_edge_blocks_without_changing_coordinates_theorem:
  forall y: U32
  {
    Heroes.coordinate_step_func(Heroes.West{}, 0, y)
    == Heroes.Coordinate{0, y, False{}, False{}}
    : Heroes.Coordinate
  }

def west_map_edge_blocks_without_changing_coordinates_theorem(y):
  {==}

assert west_interior_step_changes_only_x_theorem:
  forall y: U32
  {
    Heroes.coordinate_step_func(Heroes.West{}, 1, y)
    == Heroes.Coordinate{0, y, True{}, False{}}
    : Heroes.Coordinate
  }

def west_interior_step_changes_only_x_theorem(y):
  {==}

assert diagonal_steps_are_marked_even_when_blocked_theorem:
  forall x: U32
  {
    Heroes.coordinate_step_func(Heroes.NorthEast{}, x, 0)
    == Heroes.Coordinate{x, 0, False{}, True{}}
    : Heroes.Coordinate
  }

def diagonal_steps_are_marked_even_when_blocked_theorem(x):
  {==}

# Combat
# ======

assert ranged_attacks_currently_receive_no_modifier_theorem:
  forall ranged: Bool
  forall percent: U32
  {Heroes.ranged_percent_func(ranged, percent) == percent : U32}

def ranged_attacks_currently_receive_no_modifier_theorem(ranged, percent):
  match ranged:
    case False{}: {==}
    case True{}: {==}

assert empty_actor_cannot_attack_theorem:
  forall target: Heroes.Stack
  forall hero_attack: U32
  forall hero_defense: U32
  forall seed: U32
  {
    Heroes.attack_roll_func(
      Heroes.EmptyStack{}, target, hero_attack, hero_defense, seed
    )
    == Heroes.AttackRoll{0, seed, False{}}
    : Heroes.AttackRoll
  }

def empty_actor_cannot_attack_theorem(target, hero_attack, hero_defense, seed):
  match target:
    case Heroes.EmptyStack{}: {==}
    case Heroes.Troop{kind, count, first_unit_hp}: {==}

assert empty_target_cannot_be_attacked_theorem:
  forall kind: Heroes.CreatureKind
  forall count: U32
  forall first_unit_hp: U32
  forall hero_attack: U32
  forall hero_defense: U32
  forall seed: U32
  {
    Heroes.attack_roll_func(
      Heroes.Troop{kind, count, first_unit_hp},
      Heroes.EmptyStack{},
      hero_attack,
      hero_defense,
      seed
    )
    == Heroes.AttackRoll{0, seed, False{}}
    : Heroes.AttackRoll
  }

def empty_target_cannot_be_attacked_theorem(kind, count, first_unit_hp, hero_attack, hero_defense, seed):
  {==}

assert defend_adds_twenty_percent_of_total_pikeman_defense_theorem:
  forall actor_count: U32
  forall actor_first_hp: U32
  forall target_count: U32
  forall target_first_hp: U32
  forall hero_defense: U32
  forall seed: U32
  {
    Heroes.attack_roll_defend_func(
      Heroes.Troop{Heroes.Archer{}, actor_count, actor_first_hp},
      Heroes.Troop{Heroes.Pikeman{}, target_count, target_first_hp},
      0,
      hero_defense,
      seed
    )
    == Heroes.attack_roll_values_func(
      actor_count,
      6,
      2,
      3,
      5,
      0,
      U32.add(hero_defense, U32.div(U32.add(5, hero_defense), 5)),
      seed,
      True{}
    )
    : Heroes.AttackRoll
  }

def defend_adds_twenty_percent_of_total_pikeman_defense_theorem(actor_count, actor_first_hp, target_count, target_first_hp, hero_defense, seed):
  {==}

assert attack_advantage_applies_five_percent_per_point_theorem:
  forall count: U32
  {
    Heroes.attack_roll_values_func(
      count, 10, 5, 5, 5, 0, 0, 17, False{}
    )
    == Heroes.AttackRoll{
      Heroes.u32_at_least_one_func(
        U32.div(U32.mul(U32.mul(count, 5), 125), 100)
      ),
      U32.add(U32.mul(17, 1664525), 1013904223),
      True{}
    }
    : Heroes.AttackRoll
  }

def attack_advantage_applies_five_percent_per_point_theorem(count):
  {==}

assert defense_advantage_applies_two_percent_per_point_theorem:
  forall count: U32
  {
    Heroes.attack_roll_values_func(
      count, 5, 5, 5, 10, 0, 0, 17, False{}
    )
    == Heroes.AttackRoll{
      Heroes.u32_at_least_one_func(
        U32.div(U32.mul(U32.mul(count, 5), 90), 100)
      ),
      U32.add(U32.mul(17, 1664525), 1013904223),
      True{}
    }
    : Heroes.AttackRoll
  }

def defense_advantage_applies_two_percent_per_point_theorem(count):
  {==}

assert attack_damage_bonus_is_capped_at_300_percent_theorem:
  forall count: U32
  {
    Heroes.attack_roll_values_func(
      count, 100, 5, 5, 0, 0, 0, 17, False{}
    )
    == Heroes.AttackRoll{
      Heroes.u32_at_least_one_func(
        U32.div(U32.mul(U32.mul(count, 5), 400), 100)
      ),
      U32.add(U32.mul(17, 1664525), 1013904223),
      True{}
    }
    : Heroes.AttackRoll
  }

def attack_damage_bonus_is_capped_at_300_percent_theorem(count):
  {==}

assert defense_damage_reduction_is_capped_at_70_percent_theorem:
  forall count: U32
  {
    Heroes.attack_roll_values_func(
      count, 0, 5, 5, 100, 0, 0, 17, False{}
    )
    == Heroes.AttackRoll{
      Heroes.u32_at_least_one_func(
        U32.div(U32.mul(U32.mul(count, 5), 30), 100)
      ),
      U32.add(U32.mul(17, 1664525), 1013904223),
      True{}
    }
    : Heroes.AttackRoll
  }

def defense_damage_reduction_is_capped_at_70_percent_theorem(count):
  {==}

# Hero
# ====

assert new_day_refreshes_movement_and_regenerates_one_mana_theorem:
  forall name: String
  forall x: U32
  forall y: U32
  forall movement: U32
  forall attack: U32
  forall defense: U32
  forall power: U32
  forall level: U32
  forall experience: U32
  forall army: Heroes.Army
  {
    Heroes.hero_new_day_func(
      Heroes.Hero{
        name,
        x,
        y,
        movement,
        attack,
        defense,
        power,
        1,
        0,
        level,
        experience,
        army
      }
    )
    == Heroes.Hero{
      name,
      x,
      y,
      1600,
      attack,
      defense,
      power,
      1,
      1,
      level,
      experience,
      army
    }
    : Heroes.Hero
  }

def new_day_refreshes_movement_and_regenerates_one_mana_theorem(name, x, y, movement, attack, defense, power, level, experience, army):
  {==}

assert hero_attack_artifact_changes_only_attack_theorem:
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
  forall army: Heroes.Army
  forall amount: U32
  {
    Heroes.hero_add_attack_func(
      Heroes.Hero{
        name,
        x,
        y,
        movement,
        attack,
        defense,
        power,
        knowledge,
        mana,
        level,
        experience,
        army
      },
      amount
    )
    == Heroes.Hero{
      name,
      x,
      y,
      movement,
      U32.add(attack, amount),
      defense,
      power,
      knowledge,
      mana,
      level,
      experience,
      army
    }
    : Heroes.Hero
  }

def hero_attack_artifact_changes_only_attack_theorem(name, x, y, movement, attack, defense, power, knowledge, mana, level, experience, army, amount):
  {==}

# Weekly growth
# =============

assert castle_weekly_growth_uses_canonical_base_rates_theorem:
  forall stock: Heroes.Stock
  forall dwellings: U32
  forall fort: U32
  {
    Heroes.stock_grow_faction_func(
      stock, Heroes.Castle{}, dwellings, fort
    )
    == Heroes.stock_grow_func(
      stock, dwellings, fort, 14, 9, 7, 4, 3, 2, 1
    )
    : Heroes.Stock
  }

def castle_weekly_growth_uses_canonical_base_rates_theorem(stock, dwellings, fort):
  {==}

assert necropolis_weekly_growth_uses_canonical_base_rates_theorem:
  forall stock: Heroes.Stock
  forall dwellings: U32
  forall fort: U32
  {
    Heroes.stock_grow_faction_func(
      stock, Heroes.Necropolis{}, dwellings, fort
    )
    == Heroes.stock_grow_func(
      stock, dwellings, fort, 12, 8, 7, 4, 3, 2, 1
    )
    : Heroes.Stock
  }

def necropolis_weekly_growth_uses_canonical_base_rates_theorem(stock, dwellings, fort):
  {==}

# Town
# ====

assert built_town_rejects_second_hall_construction_theorem:
  forall faction: Heroes.Faction
  forall hall: U32
  forall fort: U32
  forall dwellings: U32
  forall stock: Heroes.Stock
  forall resources: Heroes.Resources
  {
    Heroes.town_build_hall_values_func(
      faction, hall, fort, dwellings, True{}, stock, resources
    )
    == Heroes.TownAction{
      Heroes.Town{faction, hall, fort, dwellings, True{}, stock},
      resources,
      False{},
      "Only one building may be constructed in a town each day."
    }
    : Heroes.TownAction
  }

def built_town_rejects_second_hall_construction_theorem(faction, hall, fort, dwellings, stock, resources):
  {==}

assert built_town_rejects_second_fort_construction_theorem:
  forall faction: Heroes.Faction
  forall hall: U32
  forall fort: U32
  forall dwellings: U32
  forall stock: Heroes.Stock
  forall resources: Heroes.Resources
  {
    Heroes.town_build_fort_values_func(
      faction, hall, fort, dwellings, True{}, stock, resources
    )
    == Heroes.TownAction{
      Heroes.Town{faction, hall, fort, dwellings, True{}, stock},
      resources,
      False{},
      "Only one building may be constructed in a town each day."
    }
    : Heroes.TownAction
  }

def built_town_rejects_second_fort_construction_theorem(faction, hall, fort, dwellings, stock, resources):
  {==}

assert built_town_rejects_second_dwelling_construction_theorem:
  forall faction: Heroes.Faction
  forall hall: U32
  forall fort: U32
  forall dwellings: U32
  forall stock: Heroes.Stock
  forall resources: Heroes.Resources
  forall tier: U32
  {
    Heroes.town_build_dwelling_values_func(
      faction, hall, fort, dwellings, True{}, stock, resources, tier
    )
    == Heroes.TownAction{
      Heroes.Town{faction, hall, fort, dwellings, True{}, stock},
      resources,
      False{},
      "Only one building may be constructed in a town each day."
    }
    : Heroes.TownAction
  }

def built_town_rejects_second_dwelling_construction_theorem(faction, hall, fort, dwellings, stock, resources, tier):
  {==}

assert completed_capitol_rejects_further_hall_construction_theorem:
  forall faction: Heroes.Faction
  forall fort: U32
  forall dwellings: U32
  forall stock: Heroes.Stock
  forall resources: Heroes.Resources
  {
    Heroes.town_build_hall_values_func(
      faction, 3, fort, dwellings, False{}, stock, resources
    )
    == Heroes.TownAction{
      Heroes.Town{faction, 3, fort, dwellings, False{}, stock},
      resources,
      False{},
      "The Capitol is already complete."
    }
    : Heroes.TownAction
  }

def completed_capitol_rejects_further_hall_construction_theorem(faction, fort, dwellings, stock, resources):
  {==}

assert completed_castle_rejects_further_fort_construction_theorem:
  forall faction: Heroes.Faction
  forall hall: U32
  forall dwellings: U32
  forall stock: Heroes.Stock
  forall resources: Heroes.Resources
  {
    Heroes.town_build_fort_values_func(
      faction, hall, 2, dwellings, False{}, stock, resources
    )
    == Heroes.TownAction{
      Heroes.Town{faction, hall, 2, dwellings, False{}, stock},
      resources,
      False{},
      "The Castle fortification is already complete."
    }
    : Heroes.TownAction
  }

def completed_castle_rejects_further_fort_construction_theorem(faction, hall, dwellings, stock, resources):
  {==}

# Recruitment
# ===========

assert castle_recruitment_requires_the_hero_at_castle_theorem:
  forall resources: Heroes.Resources
  forall name: String
  forall movement: U32
  forall attack: U32
  forall defense: U32
  forall power: U32
  forall knowledge: U32
  forall mana: U32
  forall level: U32
  forall experience: U32
  forall army: Heroes.Army
  forall hall: U32
  forall fort: U32
  forall dwellings: U32
  forall built_today: Bool
  forall stock: Heroes.Stock
  forall tier: U32
  forall amount: U32
  {
    Heroes.kingdom_recruit_func(
      Heroes.Kingdom{
        resources,
        Heroes.Hero{
          name,
          0,
          0,
          movement,
          attack,
          defense,
          power,
          knowledge,
          mana,
          level,
          experience,
          army
        },
        Heroes.Town{
          Heroes.Castle{}, hall, fort, dwellings, built_today, stock
        }
      },
      tier,
      amount
    )
    == (
      Heroes.Kingdom{
        resources,
        Heroes.Hero{
          name,
          0,
          0,
          movement,
          attack,
          defense,
          power,
          knowledge,
          mana,
          level,
          experience,
          army
        },
        Heroes.Town{
          Heroes.Castle{}, hall, fort, dwellings, built_today, stock
        }
      },
      "The active hero must be visiting the Castle to recruit into this army."
    )
    : Heroes.Kingdom & String
  }

def castle_recruitment_requires_the_hero_at_castle_theorem(resources, name, movement, attack, defense, power, knowledge, mana, level, experience, army, hall, fort, dwellings, built_today, stock, tier, amount):
  {==}

assert necropolis_recruitment_requires_the_hero_at_necropolis_theorem:
  forall resources: Heroes.Resources
  forall name: String
  forall movement: U32
  forall attack: U32
  forall defense: U32
  forall power: U32
  forall knowledge: U32
  forall mana: U32
  forall level: U32
  forall experience: U32
  forall army: Heroes.Army
  forall hall: U32
  forall fort: U32
  forall dwellings: U32
  forall built_today: Bool
  forall stock: Heroes.Stock
  forall tier: U32
  forall amount: U32
  {
    Heroes.kingdom_recruit_func(
      Heroes.Kingdom{
        resources,
        Heroes.Hero{
          name,
          0,
          0,
          movement,
          attack,
          defense,
          power,
          knowledge,
          mana,
          level,
          experience,
          army
        },
        Heroes.Town{
          Heroes.Necropolis{}, hall, fort, dwellings, built_today, stock
        }
      },
      tier,
      amount
    )
    == (
      Heroes.Kingdom{
        resources,
        Heroes.Hero{
          name,
          0,
          0,
          movement,
          attack,
          defense,
          power,
          knowledge,
          mana,
          level,
          experience,
          army
        },
        Heroes.Town{
          Heroes.Necropolis{}, hall, fort, dwellings, built_today, stock
        }
      },
      "The active hero must be visiting the Necropolis to recruit into this army."
    )
    : Heroes.Kingdom & String
  }

def necropolis_recruitment_requires_the_hero_at_necropolis_theorem(resources, name, movement, attack, defense, power, knowledge, mana, level, experience, army, hall, fort, dwellings, built_today, stock, tier, amount):
  {==}

# Adventure sites
# ===============

assert exhausted_gold_pile_is_persistent_theorem:
  forall wood: Bool
  forall shrine: Bool
  forall artifact: Bool
  forall sawmill: Heroes.Owner
  forall gold_mine: Heroes.Owner
  forall guardian: Heroes.Army
  forall kingdom: Heroes.Kingdom
  forall owner: Heroes.Owner
  {
    Heroes.kingdom_visit_site_func(
      Heroes.GoldPileSite{},
      Heroes.World{
        False{}, wood, shrine, artifact, sawmill, gold_mine, guardian
      },
      kingdom,
      owner
    )
    == Heroes.MoveResult{
      kingdom,
      Heroes.World{
        False{}, wood, shrine, artifact, sawmill, gold_mine, guardian
      },
      Heroes.Adventure{},
      "The empty treasure site has already been searched."
    }
    : Heroes.MoveResult
  }

def exhausted_gold_pile_is_persistent_theorem(wood, shrine, artifact, sawmill, gold_mine, guardian, kingdom, owner):
  {==}

assert gold_pile_is_consumed_once_and_awards_1000_theorem:
  forall wood: Bool
  forall shrine: Bool
  forall artifact: Bool
  forall sawmill: Heroes.Owner
  forall gold_mine: Heroes.Owner
  forall guardian: Heroes.Army
  forall kingdom: Heroes.Kingdom
  forall owner: Heroes.Owner
  {
    Heroes.kingdom_visit_site_func(
      Heroes.GoldPileSite{},
      Heroes.World{
        True{}, wood, shrine, artifact, sawmill, gold_mine, guardian
      },
      kingdom,
      owner
    )
    == Heroes.MoveResult{
      Heroes.kingdom_add_gold_func(kingdom, 1000),
      Heroes.World{
        False{}, wood, shrine, artifact, sawmill, gold_mine, guardian
      },
      Heroes.Adventure{},
      "A treasure chest added 1000 gold to the kingdom."
    }
    : Heroes.MoveResult
  }

def gold_pile_is_consumed_once_and_awards_1000_theorem(wood, shrine, artifact, sawmill, gold_mine, guardian, kingdom, owner):
  {==}

assert artifact_is_consumed_once_and_awards_two_attack_theorem:
  forall gold: Bool
  forall wood: Bool
  forall shrine: Bool
  forall sawmill: Heroes.Owner
  forall gold_mine: Heroes.Owner
  forall guardian: Heroes.Army
  forall kingdom: Heroes.Kingdom
  forall owner: Heroes.Owner
  {
    Heroes.kingdom_visit_site_func(
      Heroes.ArtifactSite{},
      Heroes.World{
        gold, wood, shrine, True{}, sawmill, gold_mine, guardian
      },
      kingdom,
      owner
    )
    == Heroes.MoveResult{
      Heroes.kingdom_add_attack_func(kingdom, 2),
      Heroes.World{
        gold, wood, shrine, False{}, sawmill, gold_mine, guardian
      },
      Heroes.Adventure{},
      "The Sword of Judgment increased the hero's Attack by 2."
    }
    : Heroes.MoveResult
  }

def artifact_is_consumed_once_and_awards_two_attack_theorem(gold, wood, shrine, sawmill, gold_mine, guardian, kingdom, owner):
  {==}

assert sawmill_capture_changes_only_sawmill_owner_theorem:
  forall gold: Bool
  forall wood: Bool
  forall shrine: Bool
  forall artifact: Bool
  forall old_sawmill: Heroes.Owner
  forall gold_mine: Heroes.Owner
  forall guardian: Heroes.Army
  forall kingdom: Heroes.Kingdom
  forall owner: Heroes.Owner
  {
    Heroes.kingdom_visit_site_func(
      Heroes.SawmillSite{},
      Heroes.World{
        gold, wood, shrine, artifact, old_sawmill, gold_mine, guardian
      },
      kingdom,
      owner
    )
    == Heroes.MoveResult{
      kingdom,
      Heroes.World{
        gold, wood, shrine, artifact, owner, gold_mine, guardian
      },
      Heroes.Adventure{},
      "The Sawmill was flagged and will yield 2 wood each day."
    }
    : Heroes.MoveResult
  }

def sawmill_capture_changes_only_sawmill_owner_theorem(gold, wood, shrine, artifact, old_sawmill, gold_mine, guardian, kingdom, owner):
  {==}

assert gold_mine_capture_changes_only_gold_mine_owner_theorem:
  forall gold: Bool
  forall wood: Bool
  forall shrine: Bool
  forall artifact: Bool
  forall sawmill: Heroes.Owner
  forall old_gold_mine: Heroes.Owner
  forall guardian: Heroes.Army
  forall kingdom: Heroes.Kingdom
  forall owner: Heroes.Owner
  {
    Heroes.kingdom_visit_site_func(
      Heroes.GoldMineSite{},
      Heroes.World{
        gold, wood, shrine, artifact, sawmill, old_gold_mine, guardian
      },
      kingdom,
      owner
    )
    == Heroes.MoveResult{
      kingdom,
      Heroes.World{
        gold, wood, shrine, artifact, sawmill, owner, guardian
      },
      Heroes.Adventure{},
      "The Gold Mine was flagged and will yield 1000 gold each day."
    }
    : Heroes.MoveResult
  }

def gold_mine_capture_changes_only_gold_mine_owner_theorem(gold, wood, shrine, artifact, sawmill, old_gold_mine, guardian, kingdom, owner):
  {==}

# Mine income
# ===========

assert red_sawmill_pays_two_wood_to_red_theorem:
  forall gold: Bool
  forall wood: Bool
  forall shrine: Bool
  forall artifact: Bool
  forall guardian: Heroes.Army
  {
    Heroes.world_income_func(
      Heroes.World{
        gold,
        wood,
        shrine,
        artifact,
        Heroes.Red{},
        Heroes.Neutral{},
        guardian
      }
    )
    == Heroes.WorldIncome{
      Heroes.World{
        gold,
        wood,
        shrine,
        artifact,
        Heroes.Red{},
        Heroes.Neutral{},
        guardian
      },
      0,
      2,
      0,
      0
    }
    : Heroes.WorldIncome
  }

def red_sawmill_pays_two_wood_to_red_theorem(gold, wood, shrine, artifact, guardian):
  {==}

assert blue_sawmill_pays_two_wood_to_blue_theorem:
  forall gold: Bool
  forall wood: Bool
  forall shrine: Bool
  forall artifact: Bool
  forall guardian: Heroes.Army
  {
    Heroes.world_income_func(
      Heroes.World{
        gold,
        wood,
        shrine,
        artifact,
        Heroes.Blue{},
        Heroes.Neutral{},
        guardian
      }
    )
    == Heroes.WorldIncome{
      Heroes.World{
        gold,
        wood,
        shrine,
        artifact,
        Heroes.Blue{},
        Heroes.Neutral{},
        guardian
      },
      0,
      0,
      0,
      2
    }
    : Heroes.WorldIncome
  }

def blue_sawmill_pays_two_wood_to_blue_theorem(gold, wood, shrine, artifact, guardian):
  {==}

assert red_gold_mine_pays_1000_gold_to_red_theorem:
  forall gold: Bool
  forall wood: Bool
  forall shrine: Bool
  forall artifact: Bool
  forall guardian: Heroes.Army
  {
    Heroes.world_income_func(
      Heroes.World{
        gold,
        wood,
        shrine,
        artifact,
        Heroes.Neutral{},
        Heroes.Red{},
        guardian
      }
    )
    == Heroes.WorldIncome{
      Heroes.World{
        gold,
        wood,
        shrine,
        artifact,
        Heroes.Neutral{},
        Heroes.Red{},
        guardian
      },
      1000,
      0,
      0,
      0
    }
    : Heroes.WorldIncome
  }

def red_gold_mine_pays_1000_gold_to_red_theorem(gold, wood, shrine, artifact, guardian):
  {==}

assert blue_gold_mine_pays_1000_gold_to_blue_theorem:
  forall gold: Bool
  forall wood: Bool
  forall shrine: Bool
  forall artifact: Bool
  forall guardian: Heroes.Army
  {
    Heroes.world_income_func(
      Heroes.World{
        gold,
        wood,
        shrine,
        artifact,
        Heroes.Neutral{},
        Heroes.Blue{},
        guardian
      }
    )
    == Heroes.WorldIncome{
      Heroes.World{
        gold,
        wood,
        shrine,
        artifact,
        Heroes.Neutral{},
        Heroes.Blue{},
        guardian
      },
      0,
      0,
      1000,
      0
    }
    : Heroes.WorldIncome
  }

def blue_gold_mine_pays_1000_gold_to_blue_theorem(gold, wood, shrine, artifact, guardian):
  {==}

# Combat outcomes
# ===============

assert rejected_combat_turn_preserves_battle_state_theorem:
  forall resources: Heroes.Resources
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
  forall town: Heroes.Town
  forall attacker: Heroes.Owner
  forall source: Heroes.BattleSource
  forall round: U32
  forall player: Heroes.Army
  forall enemy: Heroes.Army
  forall mana: U32
  forall next_seed: U32
  forall dealt: U32
  forall received: U32
  {
    Heroes.kingdom_finish_combat_func(
      resources,
      name,
      x,
      y,
      movement,
      attack,
      defense,
      power,
      knowledge,
      level,
      experience,
      town,
      attacker,
      source,
      round,
      Heroes.CombatTurn{
        player, enemy, mana, next_seed, dealt, received, False{}
      }
    )
    == Heroes.KingdomBattle{
      Heroes.Kingdom{
        resources,
        Heroes.hero_rebuild_func(
          name,
          x,
          y,
          movement,
          attack,
          defense,
          power,
          knowledge,
          mana,
          level,
          experience,
          player
        ),
        town
      },
      Heroes.BattleContinues{
        Heroes.Battle{attacker, source, enemy, round}
      },
      next_seed,
      "Choose occupied army slots; the rejected combat command changed nothing."
    }
    : Heroes.KingdomBattle
  }

def rejected_combat_turn_preserves_battle_state_theorem(resources, name, x, y, movement, attack, defense, power, knowledge, level, experience, town, attacker, source, round, player, enemy, mana, next_seed, dealt, received):
  {==}

assert defeating_the_last_enemy_stack_awards_and_heals_theorem:
  forall resources: Heroes.Resources
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
  forall town: Heroes.Town
  forall attacker: Heroes.Owner
  forall source: Heroes.BattleSource
  forall round: U32
  forall player: Heroes.Army
  forall mana: U32
  forall next_seed: U32
  forall dealt: U32
  forall received: U32
  {
    Heroes.kingdom_finish_combat_func(
      resources,
      name,
      x,
      y,
      movement,
      attack,
      defense,
      power,
      knowledge,
      level,
      experience,
      town,
      attacker,
      source,
      round,
      Heroes.CombatTurn{
        player,
        Heroes.Army{
          Heroes.EmptyStack{},
          Heroes.EmptyStack{},
          Heroes.EmptyStack{},
          Heroes.EmptyStack{},
          Heroes.EmptyStack{},
          Heroes.EmptyStack{},
          Heroes.EmptyStack{}
        },
        mana,
        next_seed,
        dealt,
        received,
        True{}
      }
    )
    == Heroes.KingdomBattle{
      Heroes.Kingdom{
        Heroes.resources_add_gold_func(resources, 1500),
        Heroes.hero_gain_func(
          Heroes.hero_rebuild_func(
            name,
            x,
            y,
            movement,
            attack,
            defense,
            power,
            knowledge,
            mana,
            level,
            experience,
            Heroes.army_heal_func(player)
          ),
          1200
        ),
        town
      },
      Heroes.BattleWon{attacker, source},
      next_seed,
      "Victory: the enemy army fell; 1200 experience and 1500 gold were awarded."
    }
    : Heroes.KingdomBattle
  }

def defeating_the_last_enemy_stack_awards_and_heals_theorem(resources, name, x, y, movement, attack, defense, power, knowledge, level, experience, town, attacker, source, round, player, mana, next_seed, dealt, received):
  {==}

assert red_retreat_returns_home_and_clears_the_army_theorem:
  forall resources: Heroes.Resources
  forall name: String
  forall attack: U32
  forall defense: U32
  forall power: U32
  forall knowledge: U32
  forall mana: U32
  forall level: U32
  forall experience: U32
  forall town: Heroes.Town
  forall source: Heroes.BattleSource
  forall enemy: Heroes.Army
  forall seed: U32
  {
    Heroes.kingdom_retreat_func(
      Heroes.Red{},
      resources,
      name,
      attack,
      defense,
      power,
      knowledge,
      mana,
      level,
      experience,
      town,
      source,
      enemy,
      seed
    )
    == Heroes.KingdomBattle{
      Heroes.Kingdom{
        resources,
        Heroes.Hero{
          name,
          1,
          5,
          0,
          attack,
          defense,
          power,
          knowledge,
          mana,
          level,
          experience,
          Heroes.army_empty_func()
        },
        town
      },
      Heroes.BattleEnded{Heroes.Red{}, source, enemy},
      seed,
      "The hero retreated to the Castle and lost the whole army."
    }
    : Heroes.KingdomBattle
  }

def red_retreat_returns_home_and_clears_the_army_theorem(resources, name, attack, defense, power, knowledge, mana, level, experience, town, source, enemy, seed):
  {==}

assert blue_retreat_returns_home_and_clears_the_army_theorem:
  forall resources: Heroes.Resources
  forall name: String
  forall attack: U32
  forall defense: U32
  forall power: U32
  forall knowledge: U32
  forall mana: U32
  forall level: U32
  forall experience: U32
  forall town: Heroes.Town
  forall source: Heroes.BattleSource
  forall enemy: Heroes.Army
  forall seed: U32
  {
    Heroes.kingdom_retreat_func(
      Heroes.Blue{},
      resources,
      name,
      attack,
      defense,
      power,
      knowledge,
      mana,
      level,
      experience,
      town,
      source,
      enemy,
      seed
    )
    == Heroes.KingdomBattle{
      Heroes.Kingdom{
        resources,
        Heroes.Hero{
          name,
          7,
          1,
          0,
          attack,
          defense,
          power,
          knowledge,
          mana,
          level,
          experience,
          Heroes.army_empty_func()
        },
        town
      },
      Heroes.BattleEnded{Heroes.Blue{}, source, enemy},
      seed,
      "The hero retreated to the Necropolis and lost the whole army."
    }
    : Heroes.KingdomBattle
  }

def blue_retreat_returns_home_and_clears_the_army_theorem(resources, name, attack, defense, power, knowledge, mana, level, experience, town, source, enemy, seed):
  {==}

assert guardian_retreat_restores_the_surviving_guardians_theorem:
  forall gold: Bool
  forall wood: Bool
  forall shrine: Bool
  forall artifact: Bool
  forall sawmill: Heroes.Owner
  forall gold_mine: Heroes.Owner
  forall old_guardian: Heroes.Army
  forall enemy: Heroes.Army
  {
    Heroes.world_restore_battle_func(
      Heroes.World{
        gold,
        wood,
        shrine,
        artifact,
        sawmill,
        gold_mine,
        old_guardian
      },
      Heroes.GuardianBattle{},
      enemy
    )
    == Heroes.World{
      gold, wood, shrine, artifact, sawmill, gold_mine, enemy
    }
    : Heroes.World
  }

def guardian_retreat_restores_the_surviving_guardians_theorem(gold, wood, shrine, artifact, sawmill, gold_mine, old_guardian, enemy):
  {==}

assert town_battle_does_not_modify_bridge_guardians_theorem:
  forall gold: Bool
  forall wood: Bool
  forall shrine: Bool
  forall artifact: Bool
  forall sawmill: Heroes.Owner
  forall gold_mine: Heroes.Owner
  forall guardian: Heroes.Army
  forall enemy: Heroes.Army
  {
    Heroes.world_restore_battle_func(
      Heroes.World{
        gold, wood, shrine, artifact, sawmill, gold_mine, guardian
      },
      Heroes.EnemyTownBattle{},
      enemy
    )
    == Heroes.World{
      gold, wood, shrine, artifact, sawmill, gold_mine, guardian
    }
    : Heroes.World
  }

def town_battle_does_not_modify_bridge_guardians_theorem(gold, wood, shrine, artifact, sawmill, gold_mine, guardian, enemy):
  {==}

# Game transitions
# ================

assert red_end_turn_passes_control_to_blue_without_advancing_day_theorem:
  forall scenario: U32
  forall day: U32
  forall red: Heroes.Kingdom
  forall blue: Heroes.Kingdom
  forall world: Heroes.World
  forall seed: U32
  forall turn: U32
  forall notice: String
  {
    Heroes.game_end_turn_func(
      Heroes.Game{
        scenario,
        day,
        Heroes.Red{},
        red,
        blue,
        world,
        Heroes.Adventure{},
        seed,
        turn,
        notice
      }
    )
    == Heroes.Game{
      scenario,
      day,
      Heroes.Blue{},
      red,
      blue,
      world,
      Heroes.Adventure{},
      seed,
      U32.inc(turn),
      "Red ended the turn. Blue may now act."
    }
    : Heroes.Game
  }

def red_end_turn_passes_control_to_blue_without_advancing_day_theorem(scenario, day, red, blue, world, seed, turn, notice):
  {==}

assert blue_end_turn_runs_the_new_day_transition_theorem:
  forall scenario: U32
  forall day: U32
  forall red: Heroes.Kingdom
  forall blue: Heroes.Kingdom
  forall world: Heroes.World
  forall seed: U32
  forall turn: U32
  forall notice: String
  {
    Heroes.game_end_turn_func(
      Heroes.Game{
        scenario,
        day,
        Heroes.Blue{},
        red,
        blue,
        world,
        Heroes.Adventure{},
        seed,
        turn,
        notice
      }
    )
    == Heroes.game_end_day_values_func(
      scenario, day, red, blue, world, seed, turn
    )
    : Heroes.Game
  }

def blue_end_turn_runs_the_new_day_transition_theorem(scenario, day, red, blue, world, seed, turn, notice):
  {==}

assert adventure_movement_is_suspended_during_combat_theorem:
  forall scenario: U32
  forall day: U32
  forall active: Heroes.Owner
  forall red: Heroes.Kingdom
  forall blue: Heroes.Kingdom
  forall world: Heroes.World
  forall battle: Heroes.Battle
  forall seed: U32
  forall turn: U32
  forall notice: String
  forall direction: Heroes.Direction
  {
    Heroes.game_move_func(
      Heroes.Game{
        scenario,
        day,
        active,
        red,
        blue,
        world,
        Heroes.Combat{battle},
        seed,
        turn,
        notice
      },
      direction
    )
    == Heroes.Game{
      scenario,
      day,
      active,
      red,
      blue,
      world,
      Heroes.Combat{battle},
      seed,
      turn,
      "Adventure movement is suspended until combat ends."
    }
    : Heroes.Game
  }

def adventure_movement_is_suspended_during_combat_theorem(scenario, day, active, red, blue, world, battle, seed, turn, notice, direction):
  match active:
    case Heroes.Neutral{}: {==}
    case Heroes.Red{}: {==}
    case Heroes.Blue{}: {==}

assert red_enemy_town_victory_ends_the_scenario_theorem:
  forall scenario: U32
  forall day: U32
  forall blue: Heroes.Kingdom
  forall world: Heroes.World
  forall turn: U32
  forall red: Heroes.Kingdom
  forall next_seed: U32
  forall notice: String
  {
    Heroes.game_red_battle_result_func(
      scenario,
      day,
      blue,
      world,
      turn,
      Heroes.KingdomBattle{
        red,
        Heroes.BattleWon{Heroes.Red{}, Heroes.EnemyTownBattle{}},
        next_seed,
        notice
      }
    )
    == Heroes.Game{
      scenario,
      day,
      Heroes.Red{},
      red,
      blue,
      world,
      Heroes.Victory{Heroes.Red{}},
      next_seed,
      U32.inc(turn),
      "Red captured the Necropolis and won the scenario."
    }
    : Heroes.Game
  }

def red_enemy_town_victory_ends_the_scenario_theorem(scenario, day, blue, world, turn, red, next_seed, notice):
  {==}

assert unknown_commands_preserve_game_values_theorem:
  forall extra: Nat
  forall game: Heroes.Game
  forall arg0: U32
  forall arg1: U32
  {
    Heroes.heroes_step_nat_func(24n+extra, game, arg0, arg1)
    == Heroes.game_notice_func(
      game, "Unknown command; the state was preserved."
    )
    : Heroes.Game
  }

def unknown_commands_preserve_game_values_theorem(extra, game, arg0, arg1):
  {==}
