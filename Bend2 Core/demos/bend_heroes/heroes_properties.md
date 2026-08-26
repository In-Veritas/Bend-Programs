# Heroes of Might and Magic III — Replication Guide

A systems-level description of *Heroes of Might and Magic III* (HoMM3), written for a team that wants to re-implement the game as a software project. It covers what the game is, every major system and its rules, the key formulas, the content inventory (factions, creatures, heroes, spells, artifacts, map objects), and where to find machine-readable canonical data for the exact numbers.

> **Scope note.** "The game" here means *HoMM3: The Shadow of Death* (SoD) — the complete edition of the original trilogy (Restoration of Erathia 1999 + Armageddon's Blade + Shadow of Death, all by New World Computing / 3DO). This is the version the community treats as the baseline and the one all modern re-implementations target. Fan expansions (HotA, WoG) are noted where relevant but are out of baseline scope.

---

## 1. Game identity

| Property | Value |
|---|---|
| Title | Heroes of Might and Magic III: The Restoration of Erathia |
| Developer / Publisher | New World Computing / The 3DO Company |
| Release | February 1999 (RoE); expansions Armageddon's Blade (Sep 1999), The Shadow of Death (Mar 2000) |
| Genre | Turn-based strategy with RPG elements ("adventure-strategy") |
| Perspective | 2D top-down tile-based adventure map; side-view hex-grid battles |
| Original platform | Windows (DirectDraw, fixed 800×600, 8-bit palettized sprites) |
| Players | 1–8; human and/or AI; hot-seat, LAN/TCP-IP, and single player vs AI |
| Setting | The continent of Antagarich in the Might & Magic universe; high fantasy |
| Modern derivatives | HD Edition (Ubisoft, RoE content only), **HotA** (Horn of the Abyss — de-facto standard fan expansion), **VCMI** (open-source engine re-implementation), WoG (In the Wake of Gods) |

**One-paragraph description.** HoMM3 is a turn-based strategy game in which each player controls a fantasy kingdom: heroes ride around a tile-based adventure map collecting resources and artifacts, capturing mines and towns, and fighting battles; towns are built up over time to produce stronger creatures and unlock spells; heroes gain experience, skills, and armies; and combat between armies plays out on a separate hexagonal battlefield in tactical turn-based rounds. The player who eliminates all rivals (or completes the map's special victory condition) wins. Its enduring appeal comes from tight interlocking economies (time, gold, movement points, army strength), enormous content variety, and deterministic, legible rules — which also makes it very replicable.

---

## 2. Core game loop

1. **Strategic layer (adventure map, one turn = one day).** Each player, in sequence, moves each of their heroes (limited by daily movement points), picks up resources, visits objects, captures mines and towns, and queues one construction per town.
2. **Economic layer (towns).** Towns generate daily gold, unlock creature dwellings, and accumulate weekly creature growth. Players spend resources to build structures and recruit creatures into hero armies or garrisons.
3. **Tactical layer (combat).** When armies meet, the game switches to a hex battlefield. Stacks act in speed order across rounds; heroes cast one spell per round from the sidelines. Combat resolves to the death, retreat, or surrender, then play returns to the map.
4. **Progression layer (heroes).** Heroes accumulate experience from battles, level up primary/secondary skills, learn spells, and equip artifacts — becoming force multipliers for the armies they carry.

The loop's tension: creatures accumulate weekly, gold accumulates daily, but map objects are finite and enemies grow too — so tempo (how fast you expand and how efficiently you spend movement points) is the core skill.

---

## 3. Game structure

### 3.1 Calendar and turns

- Time advances in **days**. 7 days = 1 **week**; 4 weeks = 1 **month**. Displayed as "Month: 1, Week: 2, Day: 3".
- Turn order: players act sequentially in color order (Red, Blue, Tan, Green, Orange, Purple, Teal, Pink).
- **Start of each week:** creature dwellings (town and map) replenish their available-recruit pool by their growth rate. A random "Week of the ..." flavor event may apply (e.g., a *Week of the [creature]* adds +5 to that creature's dwelling growth and spawns extra wandering stacks; a *Month of the [creature]* doubles that creature's map population; a *Month of the Plague* halves populations).
- **Start of each day:** income is credited (town halls, mines, silos, artifacts), movement and spell points regenerate, one new building becomes possible per town (the one-building-per-town-per-day rule resets), map events with timers fire.

### 3.2 Players, difficulty, start

- Up to 8 players; teams/alliances supported (allied players share victory and can't attack each other; scenario-defined).
- Each player starts with a main town, one hero, and a scenario-defined starting bonus choice (artifact / gold / resource).
- Difficulty levels (chess-piece icons Pawn → King): **Easy, Normal, Hard, Expert, Impossible.** Difficulty sets human starting resources (from generous at Easy down to zero at Impossible) and AI behavior/handicaps.
- A player may control at most **8 heroes** on the map simultaneously.

### 3.3 Victory and loss conditions

Default victory: **defeat all enemy players** (capture all towns and heroes). Maps may instead define one special victory condition:

- Acquire a specific artifact (or bring it to a town)
- Accumulate N creatures or N resources
- Upgrade a specific town (to a hall/castle level)
- Build the Grail structure in a town
- Defeat a specific hero or monster
- Capture a specific town
- Flag all creature dwellings or all mines
- (Optionally "standard victory also applies" flag)

Loss conditions: lose all towns and heroes (a player who loses their last town has **7 days** to capture another before being eliminated); or map-defined — lose a specific town, lose a specific hero, or time expiry.

---

## 4. The adventure map

### 4.1 Structure

- Square grid of tiles. Sizes: **S 36×36, M 72×72, L 108×108, XL 144×144** (HotA adds H 180×180 and G 252x252). Optional second layer: **underground**, same dimensions, linked by Subterranean Gates.
- Each tile holds: terrain type, optional road, optional river, and possibly (part of) an object. Objects are multi-tile sprites with a **passability mask** and a designated **visitable "action" tile**.
- **Shroud/fog:** unexplored tiles are black; once revealed by a hero/town's scouting radius they stay revealed permanently (no re-fogging — except the Necropolis "Cover of Darkness" building and similar effects, which re-hide areas for enemies).

### 4.2 Terrain types

| Terrain | Movement cost per tile | Native faction |
|---|---|---|
| Grass | 100 | Castle, Rampart, Conflux |
| Dirt | 100 | Necropolis |
| Lava | 100 | Inferno |
| Subterranean | 100 | Dungeon |
| Rough | 125 | Stronghold |
| Sand | 150 | (none / neutrals) |
| Snow | 150 | Tower |
| Swamp | 175 | Fortress |
| Water | 100 (boat only) | — |
| Rock | impassable (underground filler) | — |

- Diagonal moves cost ×1.41 (rounded: 141 on cost-100 terrain).
- **Native terrain rule:** an army composed entirely of creatures native to the terrain ignores its movement penalty, and in battle on native terrain every native creature gets +1 Attack, +1 Defense, +1 Speed.
- **Roads** override terrain cost: dirt road 75, gravel road 65, cobblestone road 50.
- **Rivers** are decorative for movement (crossed normally) but change battlefield visuals.
- **Magical battleground overlays** (placed as map decor, affect combat on those tiles): Cursed Ground (no spells above level 1, morale/luck forced neutral), Magic Plains (all spells cast at expert), Holy Ground (+1 morale good / −1 evil), Evil Fog (inverse), Clover Field (+2 luck to neutrals), Fiery Fields / Rocklands / Magic Clouds / Lucid Pools (boost Fire/Earth/Air/Water magic to expert), Favorable Winds (water; +movement).

### 4.3 Hero movement

- Each hero has a daily pool of **movement points (MP)**. Land base MP is a function of the *slowest creature* in the army: from **1500** (speed ≤ 3) up to **2000** (speed ≥ 11).
- Sea movement has a separate base (1500) modified by the Navigation skill (+50% per level).
- Modifiers: Logistics skill (+10/20/30% land), Pathfinding (reduces terrain penalties), artifacts (gloves/boots/necklaces), stables/rally flag visits (one-week bonuses), Fly and Water Walk spells (cross obstacles at a cost multiplier), Dimension Door and Town Portal spells (teleportation).
- Movement is spent per tile entered; a hero with any MP remaining may engage any adjacent interaction. Unused MP does not carry over.
- Pathfinding for the UI: A* over tile costs with penalty/road/diagonal rules; the game shows the path with day-markers (green = reachable today).

### 4.4 Map object catalogue (by role)

This is the content backbone — the original ships ~120 object types. Grouped by function:

**Economy**
- **Mines** (flaggable, daily income): Sawmill +2 wood, Ore Pit +2 ore, Alchemist's Lab +1 mercury, Sulfur Dune +1 sulfur, Crystal Cavern +1 crystal, Gem Pond +1 gem, Gold Mine +1000 gold, Abandoned Mine (fight Troglodytes, then random resource).
- Loose **resource piles**, **Treasure Chests** (choose gold or experience), Campfire, Sea Chest, Flotsam, Shipwreck Survivor (artifact), Wagon, Lean-To, Corpse, Mystical Garden, Windmill (weekly resource), Water Wheel (weekly gold).

**Army**
- **External creature dwellings** (flaggable; weekly stock of one creature type, recruited for cost; ~40 types matching town dwellings plus neutral ones like Golem Factory / Elemental Conflux).
- **Creature banks** (guarded treasure vaults; fixed guard/reward tables): Cyclops Stockpile, Dwarven Treasury, Griffin Conservatory, Imp Cache, Medusa Stores, Naga Bank, Dragon Fly Hive, Crypt, Derelict Ship, Shipwreck, **Dragon Utopia** (endgame: dragons guarding relic artifacts and gold).
- Refugee Camp (weekly random creature for hire), Hill Fort (upgrade creatures away from towns), Freelancer-style trade via Trading Post / Black Market (artifacts for gold).

**Hero stat boosters (one-time per hero)**
- Learning Stone (+exp), Tree of Knowledge (+1 level, may cost resources), Arena (+2 Attack or Defense, choice), Marletto Tower (+1 Def), Mercenary Camp (+1 Att), Star Axis (+1 Power), Garden of Revelation (+1 Know), School of War / School of Magic (pay for +1 of a pair), Library of Enlightenment (+2 all — requires hero level), Witch Hut (random secondary skill), Scholar (random skill/stat/spell), Shrine of Magic Incantation/Gesture/Thought (teaches a level 1/2/3 spell), University (buy Basic secondary skills).

**Weekly buff sites (until next battle or for one week)**
- Fountain of Fortune, Faerie Ring, Idol of Fortune, Mermaids (luck); Rally Flag, Oasis, Watering Hole, Temple, Buoy (morale); Stables (+MP, upgrades Cavaliers); Fountain of Youth, Magic Well, Mana Vortex-style refills (spell points).

**Navigation and topology**
- **Monoliths / Portals** (one-way and two-way, color-coded pairs), **Subterranean Gate** (surface↔underground), **Whirlpool** (water teleport; costs part of the weakest stack), Shipyard (buy boats: 1000 gold + 10 wood), Lighthouse (flaggable, +sea MP), Sirens (exp for creature sacrifice), Cartographer (buy map reveal), Eye/Hut of the Magi (reveal linked area), Cover of Darkness (re-fog), Obelisk (reveals a piece of the Grail puzzle map).

**Gating and quests**
- **Keymaster's Tents** + matching **Border Guards / Border Gates** (8 colors) — pass only with the key.
- **Quest Guard** and **Seer's Hut** — quest system: bring artifact/creatures/resources, reach level/stats, defeat a hero/monster, or be a specific hero/player; rewards: exp, gold, artifacts, creatures, stats, spells.
- **Pandora's Box** (scripted bundle of rewards and/or penalties, may be guarded), **Event** (invisible scripted trigger tile), **Prison** (frees a predefined hero into your service).

**Wandering monsters**
- Neutral creature stacks sit on tiles and guard passage/objects. Properties: type, quantity (displayed as a fuzzy size band: "few / several / pack / lots / horde / throng / swarm / zounds / legion"), disposition (compliant → hostile), and growth (+10% per week if not set to static). Depending on relative army strength and Diplomacy skill, they may **join** you, **flee**, or **fight**.

**The Grail**
- Visiting all Obelisks reveals the full puzzle map; digging (a full-day action) at the indicated tile yields the **Grail** artifact; delivering it to a town constructs that faction's unique Grail building: **+5000 gold/day, +50% creature growth in that town**, plus a faction-specific effect (e.g., Tower's *Skyship* reveals the entire map, Conflux's *Aurora Borealis* makes every spell available in its guild).

---

## 5. Resources and economy

Seven resources; all stockpiled kingdom-wide (not per town):

| Resource | Role | Main source |
|---|---|---|
| **Gold** | Universal: buildings, recruitment, heroes | Town halls (500/1000/2000/4000 per day), gold mines (+1000), chests |
| **Wood, Ore** | Basic construction | Sawmill / Ore Pit (+2/day each) |
| **Mercury, Sulfur, Crystal, Gems** | "Rare" resources: high-tier dwellings, mage guilds, and tier-7 creature costs (each faction's top unit consumes one rare type — e.g., Black Dragons sulfur, Titans gems, Archangels gems, Gold Dragons crystal, Devils mercury) | +1/day mines |

- **Marketplace** converts resources at unfavorable rates that improve with the number of marketplaces owned; also enables player-to-player trade. **Artifact Merchants** (some towns) buy/sell artifacts.
- **Resource Silo** (town building): +1/day of the faction's key rare resource (wood+ore for some factions).
- Typical costs to internalize the scale: a tier-7 dwelling ≈ 10k–15k gold + 10–20 rare; a Capitol 10000 gold; a tier-7 creature 2000–5000 gold each; a hero 2500 gold.

---

## 6. Towns and factions

Nine factions (8 in RoE, Conflux added by Armageddon's Blade). Each faction has: a themed town screen, 2 hero classes, 7 creature tiers each with an upgrade (14 units), a native terrain, unique buildings, and a distinct musical theme.

### 6.1 Faction overview

| Town | Alignment | Native terrain | Hero classes (Might / Magic) | Theme |
|---|---|---|---|---|
| **Castle** | Good | Grass | Knight / Cleric | Human kingdom, knights and angels |
| **Rampart** | Good | Grass | Ranger / Druid | Elven forest, nature |
| **Tower** | Good | Snow | Alchemist / Wizard | Wizard academy, constructs |
| **Inferno** | Evil | Lava | Demoniac / Heretic | Demons, hellfire |
| **Necropolis** | Evil | Dirt | Death Knight / Necromancer | Undead |
| **Dungeon** | Evil | Subterranean | Overlord / Warlock | Underground tyrants |
| **Stronghold** | Neutral | Rough | Barbarian / Battle Mage | Orcish horde |
| **Fortress** | Neutral | Swamp | Beastmaster / Witch | Swamp beasts |
| **Conflux** (AB) | Good | Grass | Planeswalker / Elementalist | Elementals |

*(HotA adds Cove (pirates), Factory (western/steampunk), and — in progress — more; out of baseline scope but the standard for competitive play.)*

### 6.2 Creature lines (base → upgrade, tiers 1–7)

| Tier | Castle | Rampart | Tower |
|---|---|---|---|
| 1 | Pikeman → Halberdier | Centaur → Centaur Captain | Gremlin → Master Gremlin |
| 2 | Archer → Marksman | Dwarf → Battle Dwarf | Stone Gargoyle → Obsidian Gargoyle |
| 3 | Griffin → Royal Griffin | Wood Elf → Grand Elf | Stone Golem → Iron Golem |
| 4 | Swordsman → Crusader | Pegasus → Silver Pegasus | Mage → Arch Mage |
| 5 | Monk → Zealot | Dendroid Guard → Dendroid Soldier | Genie → Master Genie |
| 6 | Cavalier → Champion | Unicorn → War Unicorn | Naga → Naga Queen |
| 7 | Angel → Archangel | Green Dragon → Gold Dragon | Giant → Titan |

| Tier | Inferno | Necropolis | Dungeon |
|---|---|---|---|
| 1 | Imp → Familiar | Skeleton → Skeleton Warrior | Troglodyte → Infernal Troglodyte |
| 2 | Gog → Magog | Walking Dead → Zombie | Harpy → Harpy Hag |
| 3 | Hell Hound → Cerberus | Wight → Wraith | Beholder → Evil Eye |
| 4 | Demon → Horned Demon | Vampire → Vampire Lord | Medusa → Medusa Queen |
| 5 | Pit Fiend → Pit Lord | Lich → Power Lich | Minotaur → Minotaur King |
| 6 | Efreeti → Efreet Sultan | Black Knight → Dread Knight | Manticore → Scorpicore |
| 7 | Devil → Arch Devil | Bone Dragon → Ghost Dragon | Red Dragon → Black Dragon |

| Tier | Stronghold | Fortress | Conflux |
|---|---|---|---|
| 1 | Goblin → Hobgoblin | Gnoll → Gnoll Marauder | Pixie → Sprite |
| 2 | Wolf Rider → Wolf Raider | Lizardman → Lizard Warrior | Air Elemental → Storm Elemental |
| 3 | Orc → Orc Chieftain | Serpent Fly → Dragon Fly | Water Elemental → Ice Elemental |
| 4 | Ogre → Ogre Mage | Basilisk → Greater Basilisk | Fire Elemental → Energy Elemental |
| 5 | Roc → Thunderbird | Gorgon → Mighty Gorgon | Earth Elemental → Magma Elemental |
| 6 | Cyclops → Cyclops King | Wyvern → Wyvern Monarch | Psychic Elemental → Magic Elemental |
| 7 | Behemoth → Ancient Behemoth | Hydra → Chaos Hydra | Firebird → Phoenix |

**Neutral creatures** (no town): Peasant, Halfling, Rogue, Boar, Mummy, Nomad, Troll, Gold Golem, Diamond Golem; AB adds Sharpshooter, Enchanter, Faerie Dragon, Rust Dragon, Crystal Dragon, Azure Dragon (the strongest unit in the game). War machines (Ballista, First Aid Tent, Ammo Cart, Catapult) are implemented as special creature-like entities.

### 6.3 Town buildings

Common to all factions (each building has resource costs and prerequisites forming a small tech tree):

- **Hall line** (daily gold): Village Hall 500 → Town Hall 1000 → City Hall 2000 → **Capitol 4000** (only one Capitol per player; requires Castle).
- **Fort line** (enables walls in sieges, boosts growth): Fort → **Citadel** (+50% creature growth; adds keep arrow tower and moat) → **Castle** (+100% total growth; adds two more arrow towers, stronger walls).
- **Mage Guild** levels 1–5 (Castle caps at 4; Stronghold and Fortress cap at 3). Each level stocks a random selection of spells of that level (faction-weighted); visiting heroes with a spellbook learn all of them.
- **Tavern**: hire heroes (2500 gold; two on offer, pool refreshes weekly), hosts the Thieves' Guild intelligence screen, +1 morale to garrison during siege.
- **Marketplace**, **Resource Silo**, **Blacksmith** (sells that faction's war machine: Ballista / First Aid Tent / Ammo Cart).
- **Creature dwellings** tiers 1–7, each with an upgraded version (prerequisites chain roughly up the tiers); some factions have **horde buildings** (+growth for one tier).
- **Shipyard** (coastal towns: Castle, Necropolis, Fortress, Conflux — where the map allows).
- **Grail building** (see §4.4).

Faction-specific specials (a representative sample — full list must come from data files): Castle *Stables* (+MP to visiting heroes), *Brotherhood of the Sword* (siege morale +2); Rampart *Treasury* (+10% interest on gold weekly), *Mystic Pond* (weekly random resource); Tower *Library* (+1 extra spell per guild level), *Wall of Knowledge* (+1 Knowledge); Inferno *Castle Gate* (teleport between owned Infernos), *Order of Fire* (+1 Power); Necropolis *Necromancy Amplifier* (+10% Necromancy kingdom-wide each), *Skeleton Transformer* (convert creatures to Skeletons), *Cover of Darkness*; Dungeon *Portal of Summoning* (recruit from flagged external dwellings), *Mana Vortex* (first visitor each week gets double mana), *Academy of Battle Scholars* (+1000 exp); Stronghold *Freelancer's Guild* (sell creatures for resources), *Hall of Valhalla* (+1 Attack), *Escape Tunnel*; Fortress *Cage of Warlords* (+1 Defense), *Glyphs of Fear*, *Blood Obelisk*; Conflux *Magic University* (buy any magic-school skills).

**Rules:** one new building per town per day; a town with a visiting + garrison hero holds two full armies; capturing a town transfers all buildings intact; razing is not possible (only Grail building is unique).

### 6.4 Creature stat schema

Every creature is defined by this record (this is your data model):

```
name, faction, tier (1-7), upgraded (bool)
attack, defense, damage_min, damage_max, hit_points, speed
shots (ranged only), spell_charges (casters like Genie/Faerie Dragon)
growth_per_week, cost (gold + optional rare resource)
size (1 or 2 hexes wide)
flags: flying, ranged, undead, unliving, dragon, no_melee_penalty,
       double_attack, no_enemy_retaliation, unlimited_retaliations,
       breath_attack (2-hex), attack_all_around, three_headed_attack,
       jousting, immune_to_magic (full/levels/school/mind/fire...),
       regenerating, life_drain, rebirth, ...
special_abilities: curse/blind/petrify/paralyze/poison/aging/disease
       (with % chance), death_stare, spell_cast (which/level), hates(X),
       morale_aura, luck_aura, mana_drain, spell_cost_reduction, ...
ai_value, fight_value  (balance weights used by AI and map generator)
sound_set, animation_set (idle, move, attack up/straight/down, hit,
       death, cast; projectile sprite for shooters)
```

**Sample of real values (Castle, SoD)** — to calibrate magnitudes; pull the full 150-creature table from VCMI's config or the wiki rather than transcribing by hand:

| Creature | Att | Def | Dmg | HP | Spd | Growth | Cost | Notes |
|---|---|---|---|---|---|---|---|---|
| Pikeman | 4 | 5 | 1–3 | 10 | 4 | 14 | 60 | immune to jousting |
| Halberdier | 6 | 5 | 2–3 | 10 | 5 | 14 | 75 | immune to jousting |
| Archer | 6 | 3 | 2–3 | 10 | 4 | 9 | 100 | ranged, 12 shots |
| Marksman | 6 | 3 | 2–3 | 10 | 6 | 9 | 150 | ranged ×2 shot, 24 shots |
| Griffin | 8 | 8 | 3–6 | 25 | 6 | 7 | 200 | flying, 2 retaliations |
| Royal Griffin | 9 | 9 | 3–6 | 25 | 9 | 7 | 240 | flying, unlimited retaliations |
| Swordsman | 10 | 12 | 6–9 | 35 | 5 | 4 | 300 | |
| Crusader | 12 | 12 | 7–10 | 35 | 6 | 4 | 400 | double attack |
| Monk | 12 | 7 | 10–12 | 30 | 5 | 3 | 400 | ranged |
| Zealot | 12 | 10 | 10–12 | 30 | 7 | 3 | 450 | ranged, no melee penalty |
| Cavalier | 15 | 15 | 15–25 | 100 | 7 | 2 | 1000 | jousting (+5% dmg/hex charged) |
| Champion | 16 | 16 | 20–25 | 100 | 9 | 2 | 1200 | jousting |
| Angel | 20 | 20 | 50 | 200 | 12 | 1 | 3000 | flying, +1 morale, hates Devils |
| Archangel | 30 | 30 | 50 | 250 | 18 | 1 | 5000 | flying, +1 morale, resurrects allies 1×/battle |

**Notable ability patterns across the roster** (each is a mechanic you must implement): double-hex "breath" attacks that also hit the tile behind (dragons); attack-adjacent-all (Hydra, Psychic Elemental); no enemy retaliation (Vampire Lord, Naga, Sprite, Devil); return-after-strike (Harpy); binding roots (Dendroid); % on-hit status: curse (Black Knight), blind (Unicorn), petrify (Medusa, Basilisk), paralyze (Scorpicore), poison (Wyvern Monarch), aging (Ghost Dragon), disease (Zombie); **Death Stare** instant-kill (Mighty Gorgon); life drain (Vampire Lord); HP regeneration (Troll, Wight); demon summoning from corpses (Pit Lord); ranged area attack (Magog fireball, Lich death cloud); wall-attack (Cyclops); defense-ignoring (Behemoth 40%, Ancient 80%); spell casters in the stack (Master Genie random buff, Ogre Mage bloodlust, Faerie Dragon random offense); spell immunities (Black Dragon total, Titan mind-immunity, Efreet fire, Golems % damage-spell reduction, Dwarf/Unicorn % resist aura); mutual **hatred** (+50% damage): Angel↔Devil, Titan↔Black Dragon, Genie↔Efreet; undead (always neutral morale, immune to mind/poison/bless-type rules, hit by Destroy Undead/Death Ripple inversely); "unliving" constructs (golems, gargoyles, elementals — morale-immune like undead but not raisable).

---

## 7. Heroes

### 7.1 Hero model

```
id, name, portrait, class (18 classes = 9 factions × might/magic),
sex, biography, specialty (one of: +% to a creature, a spell, a skill,
     +350 gold/day, a resource, or a stat pattern),
primary: attack, defense, spell_power, knowledge
secondary_skills: up to 8, each at Basic/Advanced/Expert
level, experience, spellbook (set of learned spells), mana (max = knowledge × 10)
artifacts: 14 equipment slots (head, neck, shoulders, right hand, left hand,
     torso, 2× ring, feet, 4-5× misc) + war machine slots + spellbook slot
     + backpack (up to 64 items)
army: 7 creature-stack slots
movement_points (daily), patrol/AI hints (map editor)
```

- ~**144 regular heroes** (8 per class) plus campaign-unlocked specials (Gelu, Mutare, Dracon, …) ≈ 156 in SoD. Each has a fixed class, specialty, starting skills, starting army range, and (for casters) a starting spell.
- Primary stats do what they say: hero **Attack** adds to every stack's attack; **Defense** likewise; **Spell Power** scales spell magnitude/duration; **Knowledge** ×10 = max spell points. Regeneration: 1 mana/day (more with Mysticism or a Magic Well/Mana Vortex).

### 7.2 Leveling

- Experience from battle = total HP of enemies destroyed (+ Learning skill bonus). Also from chests, Learning Stones, Pandora's Boxes, Trees of Knowledge.
- Thresholds: L2 = 1000, L3 = 2000, L4 = 3200, L5 = 4600, L6 = 6200, L7 = 8000, L8 = 10000, L9 = 12200, L10 = 14700 … after L12 each increment is ×1.2 the previous (levels are uncapped in practice — implement with 64-bit exp).
- On level-up: +1 to one primary stat (class-specific probability table — e.g., Knights favor Attack/Defense, Warlocks favor Spell Power) and a choice of **two secondary skills** (typically one new at Basic vs one existing upgraded; class-specific probability weights; Wisdom and a magic school are force-offered at intervals — every 6 levels for might classes, more often for magic classes — if not yet owned).

### 7.3 The 28 secondary skills

Each at Basic / Advanced / Expert:

| Skill | Effect (B/A/E) |
|---|---|
| Air / Earth / Fire / Water Magic | Casts that school's spells at reduced cost & stronger/mass effect |
| Wisdom | Allows learning level 3 / 4 / 5 spells |
| Archery | +10/25/50% ranged damage |
| Offense | +10/20/30% melee damage |
| Armorer | −5/10/15% damage taken |
| Artillery | Control ballista; ×2 chance/damage tiers |
| Ballistics | Control catapult; better wall-hit odds |
| Diplomacy | Join-chance for neutrals; −20/40/60% surrender cost |
| Eagle Eye | 40/50/60% chance to learn observed enemy spells (levels 2/3/4) |
| Estates | +125/250/500 gold/day |
| First Aid | Control first-aid tent; heal 50/75/100 HP |
| Intelligence | +25/50/100% max mana |
| Leadership | +1/2/3 morale |
| Learning | +5/10/15% experience gained |
| Logistics | +10/20/30% land movement |
| Luck | +1/2/3 luck |
| Mysticism | +1/2/3 mana regen per day *(HotA: ×2/3/4)* |
| Navigation | +50/100/150% sea movement |
| Necromancy | Raise 10/20/30% of killed enemies as Skeletons after victory |
| Pathfinding | Reduce terrain penalty by 25/50/75% (to floor of 100) |
| Resistance | 5/10/20% chance to resist enemy spells |
| Scholar | Heroes exchange level ≤2/3/4 spells when meeting |
| Scouting | +1/2/3 tile view radius |
| Sorcery | +5/10/15% spell damage |
| Tactics | Pre-battle repositioning within 3/5/7 hex columns |

### 7.4 Hero interactions

- Two friendly heroes meeting can freely exchange creatures, artifacts, and (with Scholar) spells.
- A defeated hero's retreat options: **Retreat** (flee: lose whole army, hero returns to the tavern pool, rehireable at 2500 gold) or **Surrender** (pay gold proportional to army value, reduced by Diplomacy: keep the army, hero to tavern pool). Defeated with no escape = hero lost (artifacts go to victor).
- Heroes can garrison inside towns (visiting slot + garrison slot) and defend sieges with the town's walls.

---

## 8. Magic system

### 8.1 Structure

- **Four schools:** Air, Earth, Fire, Water. Every spell belongs to ≥1 school (a few belong to all, e.g., Magic Arrow). Spells have **levels 1–5**.
- **~70 spells total**: ~60 combat + 10 adventure-map spells (Summon Boat, Scuttle Boat, Visions, View Air, View Earth, Disguise, Fly, Water Walk, Dimension Door, Town Portal).
- Heroes need a **spellbook** (500 gold at a mage guild if not innate), learn spells by visiting guilds/shrines/scholars, and need **Wisdom** for spells of level 3+.
- Casting costs **spell points**; school skill reduces the cost and upgrades the effect — most buffs/debuffs gain **mass (all units)** versions at Expert school level.
- One spell per hero per combat round; some creatures also cast. Adventure spells cost movement in addition to mana (Dimension Door, Fly).

### 8.2 Combat spell list by school (SoD)

- **Air (L1→L5):** Haste, Magic Arrow · Disrupting Ray, Fortune, Lightning Bolt, Precision, Protection from Air · Air Shield, Destroy Undead, Hypnotize · Chain Lightning, Counterstrike · Magic Mirror, Summon Air Elemental; adventure: View Air, Disguise, Dimension Door, Fly.
- **Earth (L1→L5):** Magic Arrow, Shield, Slow, Stone Skin · Death Ripple, Quicksand, Visions* · Anti-Magic, Earthquake, Force Field, Protection from Earth · Meteor Shower, Resurrection, Sorrow · Implosion, Summon Earth Elemental; adventure: View Earth, Town Portal.
- **Fire (L1→L5):** Bloodlust, Curse, Magic Arrow, Protection from Fire · Blind, Fire Wall · Fireball, Land Mine, Misfortune · Armageddon, Berserk, Fire Shield, Frenzy, Slayer · Inferno, Sacrifice, Summon Fire Elemental.
- **Water (L1→L5):** Bless, Cure, Dispel, Magic Arrow, Protection from Water, Summon Boat*, Scuttle Boat* · Ice Bolt, Remove Obstacle, Weakness, Visions* · Forgetfulness, Frost Ring, Mirth, Teleport, Water Walk* · Clone, Prayer · Summon Water Elemental.
- Special: **Titan's Lightning Bolt** (castable free via the Titan's Thunder combination artifact).

*(Starred = adventure spells; exact school/level assignments should be lifted from data files — a few placements above are from memory and worth verifying.)*

### 8.3 Spell mechanics to implement

- Damage spells scale as `base + coefficient × SpellPower` (e.g., Magic Arrow 10 + 10×SP; Lightning Bolt 25 + 25×SP; Implosion 100 + 75×SP; Armageddon hits *everything* including your own non-immune stacks). School skill tiers add flat bonuses; Sorcery multiplies.
- Buff/debuff durations = SpellPower rounds (artifacts extend).
- Immunity/interaction web: undead vs mind spells and Bless/Curse; elemental vulnerabilities (e.g., Air Elementals take double from Meteor Shower, Water Elementals from fire spells); Golems' % damage-spell reduction; creature and artifact-granted immunities (Orb of Vulnerability negates all); Resistance skill and resist auras roll per cast.
- Spells that place battlefield objects: Quicksand, Land Mine, Fire Wall, Force Field (block hexes / trigger damage).
- Unusual control flow: Berserk (stack attacks nearest), Hypnotize (steal control), Blind/Paralyze (skip turns, break on damage), Clone (copy stack, dies on any hit), Sacrifice (consume own stack to resurrect another), Counterstrike/retaliation modifiers.

---

## 9. Combat system

### 9.1 Battlefield

- **Hex grid, 15 columns × 11 rows** (165 hexes), attacker on the left, defender on the right. Stacks occupy 1 hex (small) or 2 horizontally adjacent hexes (large/wide creatures).
- Terrain-appropriate backdrop and 0–N impassable **obstacles** (randomly placed from per-terrain sets; none on the two deployment columns). Native-terrain stat bonuses and magical-overlay effects apply.
- Heroes stand off-grid at the sides; they can't be attacked; each may cast one spell per round and provides passive stat/skill/artifact effects.

### 9.2 Turn structure

1. **Tactics phase** (if one side's hero out-Tactics the other): rearrange stacks within the first columns.
2. Combat proceeds in **rounds**. Within a round every stack acts once, ordered by **speed descending** (ties: attacker first, alternating). A stack may: move, move+attack (melee), shoot (if ranged and not blocked), **Wait** (act later in the round, in reverse speed order), **Defend** (+20% ~ +30% Defense until next turn), or use a special (no-move abilities).
3. **Morale** may grant an acting stack an immediate extra action (good) or freeze it (bad). **Luck** may double an attack's damage.
4. Battle ends when one side has no stacks, retreats, or surrenders.

### 9.3 The damage formula (the heart of the game)

For an attacking stack of `N` creatures with per-creature damage roll `D` (each creature rolls, or in practice: for N ≤ 10 sum N rolls, for N > 10 scale 10 rolls by N/10):

```
A = attacker creature Attack + hero Attack (+ buffs like Bloodlust/Frenzy)
Dfn = defender creature Defense + hero Defense (+ Stone Skin, − Behemoth reduction)

if A > Dfn:  bonus  = 0.05 × (A − Dfn)   capped at +3.00  (i.e. max ×4)
if Dfn > A:  reduction = 0.025 × (Dfn − A) capped at 0.70  (i.e. min ×0.3)

damage = N × D
       × (1 + bonus + offense/archery bonus + specialty + luck(+1.0 if lucky) ...)
       × (1 − reduction) × (1 − armorer) × (1 − shield/air-shield)
       × range_penalty(0.5 if target beyond 10 hexes)
       × wall_penalty(0.5 shooting over intact walls)
       × melee_penalty(0.5 for most shooters in melee)
       × jousting/hate/other multipliers
```

Increases are additive within their group, then reduction multipliers apply multiplicatively. Kills are computed by subtracting damage from the top creature's remaining HP through the stack; stack tracks `count` + `first_unit_hp`.

### 9.4 Retaliation, ranged, movement

- Each stack retaliates against **one** melee attack per round (before its counterattack is spent). Exceptions: unlimited retaliations (Royal Griffin), extra (Griffin ×2), attacker prevents retaliation (Vampire Lord, Naga…), attacker strikes twice (retaliation happens between the strikes for double-attackers).
- Ranged stacks have finite **shots** (replenished only by Ammo Cart); a shooter adjacent to an enemy must melee (with penalty) unless flagged otherwise; a shooter with an adjacent enemy cannot shoot at all (it may still melee).
- Flying stacks ignore obstacles/walls when moving; movement range = speed in hexes (pathfound around obstacles for walkers).

### 9.5 Morale and luck

- Range −3…+3, shown on unit cards. Sources: Leadership/Luck skills, artifacts, army composition (all troops from one faction: +1; each additional faction mixed in: cumulative penalty; any undead in a living army: −1), visited map buffs, terrain overlays, siege Tavern, creature auras (Angel, Bone Dragon…).
- **Good morale:** chance ≈ morale × 1/24 per action to act again. **Bad morale:** similar scale chance to freeze (lose the action). Undead/unliving/war machines: always neutral.
- **Good luck:** chance ≈ luck × 1/24 to deal double damage. (In SoD negative luck has no effect — display only; HotA implements half-damage unlucky strikes.)

### 9.6 Sieges

Attacking a town with a Fort+ triggers siege mode:

- Defender's side is wrapped by a **wall** with 4 destructible sections, a **drawbridge/gate** (opens for defender movement, destructible), and **arrow towers**: keep tower (Citadel) plus upper/lower towers (Castle) — each fires each round at the attacker (damage scales with town level; Cyclopes can also target walls).
- A **moat** in front (terrain-flavored: e.g., Fortress moat is wider/poisonous) stops movement and deals damage per turn spent in it.
- The attacker's **Catapult** automatically bombards wall sections each round (Ballistics skill lets the player aim it and improves hit/damage); Earthquake spell damages walls; walls have 2–3 HP states (intact → damaged → breached).
- Shooting over intact walls incurs the 0.5 penalty; walkers can only enter through breaches or the broken gate; flyers ignore walls.
- Defender wins by wiping the attackers; garrison + visiting hero + town troops merge for defense.

### 9.7 War machines

| Machine | Behavior |
|---|---|
| **Ballista** | Auto-shoots each round (hero Attack scales damage); Artillery skill gives control/double shot |
| **Ammo Cart** | Removes shot limits for own shooters |
| **First Aid Tent** | Heals top creature of a stack (First Aid skill for control/amount) |
| **Catapult** | Sieges only, always present, cannot be lost |

All are targetable/destructible (except Catapult), occupy fixed battlefield positions, purchased in Blacksmiths or found.

---

## 10. Artifacts

- ~**140+ artifacts** in SoD across 4 rarity classes: **Treasure, Minor, Major, Relic**, plus 12 **combination artifacts** (SoD): assembling all listed components lets you combine them into a super-artifact (Angelic Alliance, Cloak of the Undead King, Elixir of Life, Armor of the Damned, Statue of Legion, Power of the Dragon Father, Titan's Thunder, Admiral's Hat, Bow of the Sharpshooter, Wizard's Well, Ring of the Magi, Cornucopia).
- Slot model per §7.1; only equipped artifacts grant effects (backpack is inert). Effect taxonomy: ± primary stats, +morale/luck, +movement (land/sea), +spell effects/duration/immunities, school mastery, mana bonuses, income (Endless Bag/Sack/Purse of Gold), creature growth (Statue of Legion parts), necromancy %, scouting radius, ban enemy spellcasting levels (Orb of Inhibition, Recanter's Cloak), all-spell access (Spellbinder's Hat), etc. A few are **cursed** (Shackles of War: no retreat/surrender for either side).
- Sources: map pickups (usually guarded), Seer's Hut rewards, creature banks/Utopias, Black Market/Artifact Merchants, defeated heroes, Events/Pandora's Boxes.

---

## 11. Necromancy, Diplomacy, and other kingdom-level mechanics

- **Necromancy** (the signature Necropolis engine): after each victory, raise skeletons equal to skill% of enemies killed (count-based, modest HP caps apply); Amplifiers (+10% each, all owned Necropolis towns, kingdom-wide) and artifacts stack; the Cloak of the Undead King upgrades raised type (Skeletons → Zombies → Wights → Liches).
- **Diplomacy** join offers: when your army greatly outpowers a wandering stack, it may offer to join free or for gold; Diplomacy skill widens the threshold. (Competitive rules and HotA nerf this heavily — make it configurable.)
- **Thieves' Guild** screen: ranked kingdom intelligence (armies, wealth, towns, best hero) with precision that improves with the number of taverns/guilds you own.
- **Kingdom Overview** screen: all towns/heroes/income at a glance.
- **Grail dig**: requires a hero with full (unspent) daily MP on the exact tile; consumes the whole day.

---

## 12. Content pipeline: maps, campaigns, random maps

- **Map editor** ships with the game. A map (`.h3m`) defines: size/underground flag, players (allowed factions, human/AI, main town, heroes), teams, victory/loss conditions, tile grid (terrain/road/river sprite indices, mirroring flags), object list with per-object properties (guards, contents, quests, messages), global events, rumors, and per-player scripted timed events. No scripting language in the original (WoG added one; VCMI has its own).
- **Campaigns** (`.h3c`): sequences of scenarios with narrative bridges (video/voiceover), hero/artifact carryover between scenarios, and per-scenario starting bonus choices. RoE/AB/SoD ship ~20 campaigns total telling the Erathia storyline (Queen Catherine, Roland, Gelu, Sandro the necromancer prequels…).
- **Random Map Generator** (added in AB): template-driven — a template defines zones (size, faction/terrain, richness, monster strength) and connections (roads, guards, portals); the generator fills zones with towns/mines/objects and balances mirrored player zones. Competitive play lives on RMG templates (e.g., Jebus Cross, 8XM8 in HotA).

---

## 13. UI specification

The game has **three primary full-screen interfaces** — adventure, town, and combat — plus a set of secondary screens and modal dialogs. All are fixed **800×600**; every screen is a full-screen replacement (there is no windowing), and dialogs are modal boxes drawn over a dimmed parent. Pixel figures below marked ≈ are close approximations for layout proportions; exact art metrics should be measured from the original or taken from VCMI's layout code.

### 13.0 Shared UI language (applies everywhere)

- **Chrome:** carved wood + stone frames, parchment dialog interiors, gold ornament accents. Buttons are beveled stone/wood with 4 states: normal, hover (subtle), pressed (inset), disabled (grayed). Selection is shown by a **gold frame**; invalid choices by a red overlay or grayed art.
- **Right-click = inspect, everywhere.** Press-and-hold right mouse button on *any* entity (creature, building, resource, skill icon, spell, map object, button) shows an info popup that disappears on release. Right-clicking a dialog element with Ctrl or on specific screens can show extended info. This universal hold-to-peek is a signature of the game — implement it as a global UI service, not per-screen.
- **Tooltips:** hovering over map objects/buttons prints a one-line name/hint in a dedicated **status bar** strip (adventure: bottom bar; combat: the combat log area; town: bottom strip) rather than floating tooltips.
- **Text:** bitmap serif-style fonts; body text white with 1px dark drop shadow, headers gold, disabled gray. Numbers in fixed-width plaques where they must align (resource bar, stack counts).
- **Dialogs:** parchment panel, title, body text, icon row (e.g., resource costs as icon+number pairs), and gem-shaped **OK / Cancel** buttons bottom-center. Yes/no, message-with-components (e.g., "you find:" + artifact icon), selection dialogs (pick one of two, used for level-ups and starting bonuses) are the recurring templates.
- **Audio feedback:** every button click, page flip, build, recruit, and error has a distinct sound; errors also print a status-bar message ("Cannot build — already built today").

### 13.1 Main menu and setup screens

- **Main menu:** full-screen painted background with an animated flame/emblem; vertical stack of large buttons: New Game, Load Game, High Score, Credits, Quit. New Game → submenu: Single Scenario, Campaign, Multiplayer, Tutorial.
- **Scenario picker:** left = scrollable map list (columns: player count, size badge S/M/L/XL, version icon, name, victory-condition icon); right = selected map summary (description, win/loss conditions, difficulty picker with 5 chess-piece buttons). Below: **player setup rows** — one per map-defined player: colored flag, human/computer toggle, faction picker (allowed factions or random), starting bonus picker, handicap. Multiplayer adds name entry and turn-order.
- **Campaign picker:** campaign artwork grid → per-campaign scenario map with unlock progression → pre-mission briefing screen with narrated text, map thumbnail, and starting-bonus choice (one of three).

### 13.2 Adventure screen

The main interface, where most of the game is played.

```
┌────────────────────────────────────────────┬──────────────┐
│                                            │   minimap    │
│                                            │  (≈144×144)  │
│                                            ├──────┬───────┤
│         MAP VIEWPORT                       │ hero │ town  │
│   scrollable, 32×32 px tiles,              │ list │ list  │
│   ≈18 × 17 tiles visible,                  │(port-│(icons)│
│   framed by decorative border              │raits)│       │
│                                            ├──────┴───────┤
│                                            │ button grid  │
│                                            ├──────────────┤
│                                            │ status window│
├────────────────────────────────────────────┴──────────────┤
│ resource bar: 7 resource icons+counts · date "M:W:D"      │
└───────────────────────────────────────────────────────────┘
```

**Right sidebar (≈192 px wide), top to bottom:**
- **Minimap:** terrain-colored overview with fog; player-colored dots for towns/heroes; viewport rectangle; click/drag to scroll the main view. Surface/underground toggle swaps which layer it shows.
- **Hero list / town list:** two adjacent vertical lists with scroll arrows. Hero entries = portrait + two thin vertical gauges: **green = movement points remaining, blue = spell points**. Town entries = town-type icon (variant shows fort built / hall level). Single click selects (centers map), double click opens the hero/town screen. The selected entry gets a gold frame.
- **Button grid** (≈2 columns): Kingdom Overview · Surface/Underground switch · Quest Log · Sleep/Wake hero (a sleeping hero is skipped by "next hero") · Move hero (follow the plotted path) · Cast Spell (adventure spellbook) · Adventure Options (view world, view puzzle, dig for Grail, scenario info) · System Options (save/load/quit, autosave, speed sliders) · **Next Hero** · **End Turn** (large, bottom).
- **Status window:** a small info panel that cycles on click between: selected hero summary (portrait, primary stats, morale/luck), kingdom summary (gold + per-day income, number of towns/heroes), and the date. During other players' turns the whole sidebar is replaced by an "enemy turn" hourglass animation cycling through player flags.

**Bottom resource bar (full width, ≈32 px):** seven resource icon+amount pairs, current date, and a rollover status text area.

**Map viewport rendering (layer order):** terrain tiles → river overlays → road overlays → static objects (multi-tile sprites, painter's order by Y) → animated objects (water, flags, mines cycle ~6–10 fps) → heroes/boats (with player-flag tint) → fog-of-war mask → path arrows and selection glow. Objects are anchored by their bottom-right tile; passability and the "action tile" come from the object's mask (§4.1).

**Interaction model:**
- Left-click empty reachable tile / object with selected hero: **first click plots the path** — a chain of arrow sprites; arrowheads are **green for tiles reachable today**, dimmed/numbered beyond (day markers); **second click executes** movement, tile by tile, consuming MP; the hero walk animation plays and events trigger per tile entered.
- Clicking an interactable adjacent object (or ending the path on its action tile) triggers its dialog/effect. Spacebar re-triggers the object the hero stands on.
- **Cursor communicates the pending action** (this is essential UX): plain arrow (nothing), galloping horse (move; the number of "turns to reach" shown as a small numeral variant), sword (attack enemy hero/wandering stack), castle gate (enter town), two horses (meet/exchange with own hero), question/interact glyph (visit object), rowboat (board boat), anchor (disembark), hourglass (busy/AI).
- Scrolling: mouse at screen edge, arrow keys, or click-drag on minimap. Keyboard shortcuts throughout (E = end turn, N/Enter = next hero, C = center, digits, etc.).
- Right-click-hold on any map object: info popup (name, and for stacks a fuzzy size band, for mines owner, etc. — detail depends on Visions/scouting).

### 13.3 Town screen

A full-screen **painted townscape**: a landscape backdrop unique to the faction, on which each constructed building appears as a layered sprite (with a build-in animation the day it's constructed). The screen is essentially an illustrated menu.

- **Building hotspots:** every built structure is a polygonal clickable region. Hover = subtle highlight outline + building name in the status strip. Click = open that building's function (see dialogs below). Right-click-hold = building description popup. Unbuilt structures are simply absent from the painting.
- **Bottom panel (≈full-width strip):**
  - Left: **town icon + name**, small icons showing hall level and fort level (clicking them jumps to the Hall / Fort dialogs), and up/down arrows to cycle between your towns without leaving the screen.
  - Two **army rows**: garrison army (7 slots) and visiting hero row — hero portrait at the left of each row, then 7 creature slots with count plaques. Click a creature then a destination slot to move/merge; **Shift+click to split** a stack (slider dialog); click the two portraits to swap garrison/visiting hero wholesale. Right-click a creature = full creature card.
  - Exit button (bottom-right).
- **Key dialogs launched from buildings:**
  - **Hall (build menu):** a grid of all faction buildings (rows roughly by category/tier). Each cell: icon + name, tinted by state — *built* (gold check), *buildable now* (normal), *prerequisites unmet* (grayed, red frame), *resources missing* (normal but marked), *forbidden by map* (crossed out). Clicking a cell opens a confirm dialog: description, effect, resource-cost icon row, prerequisite list with met/unmet ticks, Build/Cancel. Building consumes resources and locks the town's build action for the day.
  - **Dwelling (recruit) dialog:** creature animation on a pedestal, its stat block, cost per unit, available count ("Available: 14"), a **slider + numeric entry + Max button**, live total-cost readout (gold + rare resources), Recruit/Cancel. Recruited units go to garrison (or a dialog asks where, if full).
  - **Mage Guild:** interior artwork of the guild tower with one shelf per built level; each known spell is a scroll icon (right-click = spell description). A visiting hero with a spellbook learns all displayed spells automatically on entering the town; a hero without one is offered a spellbook for 500 gold here.
  - **Tavern:** innkeeper artwork, a weekly **rumor** text, two hireable heroes (portrait + right-click for full sheet), Hire button (2500 gold, disabled if 8 heroes on map or a visiting hero slot is occupied), and a button to the Thieves' Guild screen.
  - **Marketplace:** two icon grids — "give" (your resources) and "receive" — with the current exchange rate shown as icon×N : icon×M, a quantity slider, and a trade button; tabs/buttons switch to player-to-player gift mode (and, where built, Artifact Merchants buy/sell artifacts).
  - **Fort dialog:** shows the 7 dwellings with their creature, current weekly growth (base + castle/horde bonuses itemized), and stocked availability.
  - Blacksmith (buy this faction's war machine), Shipyard (buy boat), special-building dialogs (one-off UIs: e.g., Skeleton Transformer's convert slider, University's 4-skill offer).

### 13.4 Hero screen

Opened by double-clicking a hero (or from the town's visiting slot).

```
┌───────────┬──────────────────────────────────────────────┐
│ portrait  │ name · class · level                         │
├───────────┼───────┬───────┬───────┬───────┬──────────────┤
│ specialty │ ATT   │ DEF   │ POW   │ KNOW  │ morale/luck  │
│ icon+text │ icon+n│ icon+n│ icon+n│ icon+n│ indicators   │
├───────────┴───────┴───────┴───────┴───────┴──────────────┤
│ experience plaque · spell points plaque                  │
├──────────────────────────────────────────────────────────┤
│ secondary skills: up to 8 icon tiles, "Basic Archery" …  │
├───────────────────────┬──────────────────────────────────┤
│ artifact paper-doll   │  misc slots ×5                   │
│ (head/neck/shoulders/ │  backpack: scrollable strip      │
│ weapon/shield/torso/  │  (up to 64 items)                │
│ ring/ring/feet + war  │                                  │
│ machines + spellbook) │                                  │
├───────────────────────┴──────────────────────────────────┤
│ army: 7 creature slots with counts                       │
│ [dismiss] [quest log] [formation] [split] [exit]         │
└──────────────────────────────────────────────────────────┘
```

- Artifacts drag-or-click between doll slots and backpack; invalid slots refuse with a sound. Right-click any artifact/skill/stat = description popup (stats explain what they do — the game is self-documenting via right-click).
- Combination artifacts show an "assemble?" prompt when all components are equipped.
- **Hero-meeting screen** (two own heroes on adjacent tiles): both paper-dolls and both armies side by side, free drag of creatures and artifacts between them; Scholar skill auto-trades spells on opening.

### 13.5 Combat screen

```
┌──────────────────────────────────────────────────────────┐
│  (attacking hero      BATTLEFIELD        (defending hero │
│   portrait, top-left)  15×11 hex grid,    portrait,      │
│                        terrain backdrop,  top-right)     │
│                        obstacles, stacks                 │
│                        with count plaques                │
├──────────────────────────────────────────────────────────┤
│ [opts][surrender][flee][auto] · combat log · [wait][def] │
└──────────────────────────────────────────────────────────┘
```

- **Battlefield:** hex cells ≈45 px wide; grid outline togglable in options; reachable hexes for the active stack can be shaded (option "show movement range"). The **active stack** stands on a highlighted hex; hovering a reachable hex shows the move cursor, hovering an enemy shows an attack cursor.
- **Stacks:** one animated creature sprite represents the whole stack (they do not render N bodies), with a small **count plaque** at its feet; plaque color encodes side and status — friendly vs enemy base color, tinted **green when only buffs are active, red when only debuffs, purple when both** (right-click the stack to see the exact effect icons and remaining durations on its creature card).
- **Attack targeting (critical detail):** hovering an adjacent-reachable enemy shows a **sword cursor whose angle depends on which sector of the hex the mouse is in** — that sector chooses the hex your stack will attack *from*; click commits move+attack from that side. Wide (2-hex) creatures have extra approach positions. Ranged: arrow cursor over any enemy; a **broken-arrow cursor** warns of the 50% penalty (distance/wall); blocked shooters show the melee sword instead. Spell targeting replaces the cursor with a wand over legal targets.
- **Hero panels:** each hero's portrait at their side; clicking your portrait opens hero combat options (cast spell → spellbook, surrender, retreat). One spell per round — after casting, the book icon is disabled.
- **Bottom bar:** button cluster (system/options, Surrender, Retreat, Auto-combat toggle) — a two-line scrollable **combat log** describing every action ("Marksmen do 48 damage; 3 Griffins perish") — and **Wait** / **Defend** buttons for the active stack. Hotkeys: W wait, D defend, Space defend, A auto.
- **Animations:** mover walks/flies hex-to-hex; attacker plays directional attack animation (up/straight/down variants), defender plays hit or death; projectiles fly for shooters; spells have full-screen or targeted effect animations. All speeds are user-adjustable (1–3); an "instant" replication mode is worth supporting for AI-vs-AI and testing.
- **Turn-order awareness:** the original shows no queue — the HD mod/HotA add a **creature turn-order ribbon** along the top edge; include it, it is now considered essential.
- **Start/end flow:** battle opens with a terrain-appropriate intro pan + music sting → optional Tactics phase (rearrange within your columns; confirm) → rounds. Ends with a **results popup**: victory/defeat artwork, both sides' casualty lists (creature icons + numbers lost), experience gained; then any capture dialogs (artifacts looted, Necromancy raise dialog). Siege variant renders the wall column, towers, moat, and gate as targetable battlefield entities on the defender's side, and the attacker's catapult in the back row.

### 13.6 Spellbook

An open book filling most of the screen: four **school bookmark tabs** on the left edge (Air/Earth/Fire/Water) plus an "all" tab, and a combat/adventure toggle (the book auto-filters: only combat spells in battle, only adventure spells on the map). Spells render as framed icons with name and **mana cost (shown adjusted for the hero's skills)**; unlearnable/uncastable spells are grayed (no mana, banned by Orb/Cursed Ground). Page-corner arrows flip pages with an animation; right-click a spell = full rules text. Clicking a spell in combat enters targeting mode; on the adventure map it casts immediately or enters map-targeting (Dimension Door destination, Town Portal town picker).

### 13.7 Secondary screens

- **Kingdom Overview:** tabbed table — all towns (row: icon, name, hall/fort, garrison summary, income) and all heroes (row: portrait, stats, army, artifacts); totals for income and mines owned by resource.
- **Thieves' Guild:** parchment "league table": rows = ranked categories (number of towns, number of heroes, gold, wood & ore, rare resources, obelisks found, artifacts, army strength, income, best hero), columns = player flags placed by rank; precision of revealed info scales with taverns owned; enemy best-hero portraits revealed at higher tiers.
- **Quest Log:** list of active quests (from Seer's Huts/Quest Guards) with giver location and requirement text.
- **Puzzle map (Grail):** the world map hidden behind a grid of jigsaw pieces; each visited Obelisk permanently removes one piece; the exposed art marks the dig site with an X when enough is revealed.
- **World view:** zoomed-out whole-map render with icon overlays; filter buttons to show only towns/mines/heroes/artifacts (View Air/View Earth spells open this with extra reveals).
- **Options dialogs:** system (save/load/restart/quit, autosave toggle), adventure options (map scroll speed, hero path options, music/SFX volume), combat options (animation speed, grid, movement shading, mouse shadow).
- **Save/Load:** simple list of save slots with name entry; autosave slot written every turn.

### 13.8 Screen-flow summary (state machine)

```
MainMenu → ScenarioSetup → ADVENTURE ⇄ Town ⇄ (recruit/build/… dialogs)
                              ⇅  ⇅
                           Hero  secondary screens (kingdom/quests/…)
                              ⇓
                           COMBAT (modal; returns to ADVENTURE with results)
```

Only the adventure screen owns the world state camera; town/hero/secondary screens are modal over it; combat suspends the adventure turn entirely and returns a battle result. Implementing each screen as a state with its own input map (plus the two global services: right-click inspector and status-bar tooltips) reproduces the original's feel faithfully.

---

## 14. Audio-visual identity

- **Graphics:** 8-bit palettized sprites; adventure map tiles 32×32 px; multi-frame animated objects; creature combat animations of ~10 action types each; painted town screens with layered build-state composites; portrait art for every hero. Original assets are in proprietary archives — a clean-room project needs a full art replacement (this is most of the asset budget: ~150 creatures × ~10 animations × 2 facings, 9 townscapes with ~15 building overlays each, ~120 map object sprite sets, ~160 hero portraits ×2 sizes, UI chrome).
- **Audio:** the celebrated orchestral/operatic soundtrack by Paul Romero, Rob King & Steve Baca — one theme per terrain (adventure), one per town, combat themes, stingers for events; SFX per creature (move/attack/hit/death) plus UI and spell sounds.
- **Video:** brief FMV cutscenes for campaign bridges and win/lose.

---

## 15. Multiplayer and AI

- **Modes:** hot-seat (same PC), LAN/direct TCP-IP (original used a lobby; modern play uses HD mod/HotA online lobby), play-by-email-style is not native. Turns are strictly sequential in the original (HotA/HD add simultaneous-turns until players meet, plus chess-clock turn timers — highly recommended for a modern replication).
- **AI layers to replicate:**
  - *Adventure AI*: object valuation (uses per-object and per-creature `ai_value`), expansion/army-consolidation heuristics, hero role assignment (main vs scout/chain), threat assessment, difficulty-based resource cheats.
  - *Combat AI*: target selection by expected damage/kill value, spell selection, siege behavior; also drives "quick combat".
  - *Wandering monster logic*: join/flee/fight thresholds.

---

## 16. Technical notes for a replication project

### 16.1 Original file formats (for reference / asset interop)

| Format | Contents |
|---|---|
| `.lod` | Asset archives (zlib-compressed entries) |
| `.def` | Animated sprite sets (frame groups per action, palette, offsets) |
| `.pcx` (custom) | Still images (not ZSoft PCX) |
| `.h3m` | Maps (gzip-compressed binary; fully community-documented) |
| `.h3c` | Campaigns |
| `.snd` / `.vid` | Audio / video archives |
| `.GM1…` saves | Gzip-compressed game state |

All are reverse-engineered and documented by the community (see §18).

### 16.2 Architecture advice (learned from VCMI and the modding scene)

- **Everything is data.** Creatures, heroes, spells, artifacts, buildings, objects, terrains, and even battle formulas' coefficients should live in data files (VCMI uses JSON) — the game code is a rules engine over them. This also gives you moddability, HoMM3's second life.
- **Determinism matters:** seedable RNG with explicit streams (combat rolls, morale/luck, map gen, AI) enables replays, multiplayer sync, and testing.
- **Model time as (day, player, phase)** with a serializable game state; the whole game state must round-trip through save files.
- **Separate the three loops** (adventure / town / combat) behind one game-state store; combat is a pure sub-state machine you can unit-test with scripted battles.
- **MVP slicing that works:** (1) map rendering + hero movement + resources; (2) one town's economy + recruitment; (3) combat core with 2–3 abilities + damage formula; (4) hero progression + a dozen spells; (5) AI + save/load; (6) content breadth (all factions/objects) last — breadth is data entry once the engine is right.

### 16.3 Legal note

The HoMM3 IP (name, lore, art, music, maps) belongs to Ubisoft. A replication project must either (a) be an engine for owners of the original assets (the VCMI approach — it requires the user's own HoMM3 data files), or (b) replace every asset and name (the fheroes2-style approach for HoMM2, or "spiritual successor" route à la *Songs of Conquest*). Mechanics and rules themselves are not copyrightable, but assets, text, and trademarks are.

---

## 17. Complete systems checklist (the "properties" inventory)

Use as a project work-breakdown; ✅-able top-level features:

**World:** square-grid 2-layer maps · 10 terrains + roads + rivers · movement-point economy · shroud/permanent reveal · 8 players · calendar (day/week/month) with weekly growth & random week events · win/loss condition set · difficulty levels
**Economy:** 7 resources · daily income pipeline · marketplace/trading · town hall/fort/mage-guild/dwelling tech trees per faction · one-build-per-day · Capitol uniqueness
**Factions:** 9 towns · 14 creatures each + ~20 neutrals · 18 hero classes · faction special buildings · Grail buildings
**Heroes:** 4 primary stats · 28 secondary skills ×3 ranks · level curve + class-weighted level-ups · specialties · 19 artifact slots + backpack · 7 army slots · tavern hiring pool · hero meeting/trade · retreat/surrender/prison
**Creatures:** full stat schema (§6.4) · ~30 distinct special-ability mechanics · upgrades · growth/horde/castle bonuses · external dwellings · creature banks · wandering-monster disposition
**Magic:** 4 schools ×5 levels · ~70 spells · spellbook/guild learning · Wisdom gates · mana economy · mass-at-expert upgrades · immunities/resistances · battlefield-object spells · adventure spells
**Combat:** 15×11 hex battlefield · speed-ordered rounds with wait/defend · retaliation rules · ranged/shots/penalties · damage formula with A/D scaling · morale & luck rolls · obstacles · native terrain & overlays · sieges (walls/towers/moat/catapult) · war machines · tactics phase · auto-combat · surrender math
**Meta:** map editor + .h3m compatibility (optional but beloved) · campaigns with carryover · random map generator with templates · thieves' guild / kingdom overview · puzzle map & grail dig · quest system (seer huts/quest guards) · timed events · rumors
**Platform:** save/load · hot-seat + network multiplayer · adventure & combat AI · options/speed settings · right-click info popups everywhere · localization-ready text system · original-asset interop (optional)

---

## 18. Canonical data sources (get exact numbers here, not from memory)

1. **VCMI project (github.com/vcmi/vcmi)** — open-source engine re-implementation; its `config/` JSON tree is a complete machine-readable database of every creature, hero, spell, artifact, building, and object with SoD-accurate values, plus battle-formula implementations you can read as executable documentation.
2. **Heroes 3 wiki (heroes.thelazy.net)** — the community-maintained reference; per-creature/spell/skill pages with exact stats, probabilities, and mechanics minutiae (including original-bug notes).
3. **HotA documentation** — current-day balance reference and clarified/fixed rules (useful to decide which "bugs" to keep as canon).
4. **h3m format documentation** (community specs, e.g. the homm3tools ecosystem) — byte-level map format if you want map compatibility.
5. **The original game + map editor** (sold on GOG as HoMM3 Complete) — ground truth for behavior, UI, and feel; indispensable for playtesting parity.

*Values in this document are from the author's knowledge of SoD and are correct in shape and mostly in number, but any figure you build against should be cross-checked with sources 1–2. Places where the memory-sourced value is most worth double-checking are marked in-line.*
