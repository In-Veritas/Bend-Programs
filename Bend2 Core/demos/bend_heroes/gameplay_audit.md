# Bend Heroes gameplay audit

This log tracks application bugs and unwanted gameplay behavior found while
implementing the reduced Castle/Necropolis/Inferno game. It is deliberately
separate from `unexpected_behavior/`: none of the entries below is attributable
to the Bend parser, checker, compiler, runtime, or backend.

## Fixed on 2026-08-26

| ID | Finding | Resolution |
| --- | --- | --- |
| BH-001 | `ranged` was modeled as a Boolean passed through an observationally irrelevant function, so it was not a spatial capability. | Replaced it with numeric `range` and `shots`; attack legality now uses real hex distance. |
| BH-002 | Combat had no battlefield and resolved arbitrary selected-stack exchanges. | Added a Core-owned odd-column 15 × 11 hex grid, formations, deterministic obstacles, movement, occupancy, and attack reach. |
| BH-003 | Every attack, including distant shots and Magic Arrow, caused a retaliation. | Retaliation is now melee-only; ranged attacks and spells do not trigger it. |
| BH-004 | A destroyed stack left an invisible occupied hex behind. | Army and formation are synchronized after every action; empty stacks become `OffBattlefield`. |
| BH-005 | Inferno existed only in the creature catalogue, while scenario factories, garrisons, labels, flags, and town art remained Castle/Necropolis-specific. | Added selectable three-faction scenarios, coherent rival garrisons, generic side text, and distinct procedural Inferno presentation. |
| BH-006 | The opponent had no tactical turn and only attacked when the player selected Defend. | Every valid attack, spell, or move now receives a deterministic enemy AI response. |
| BH-007 | Tactical AI repeatedly proposed impossible distant melee attacks. | It now checks numeric reach and chooses movement when the selected stack cannot attack. |
| BH-008 | AI movement assumed all attackers advanced left-to-right, ignored the immediate obstacle/occupancy target, and could oscillate indefinitely. | Planning is bidirectional, checks candidate hexes, tries neighboring rows, and targets the strongest current threat; strategic AI invests at home before following its objective route. |
| BH-009 | Necropolis' reduced starting force consistently lost the full AI-driven scenario while Castle and Inferno completed it. | Rebalanced its retained base army; automated full-scenario traces now reach victory for all three factions. |
| BH-010 | Castle visuals and faction names were hard-coded onto the Red/Blue map sites after faction selection was added. | Map towns now derive faction, materials, flag side, roster, and labels from the current Core kingdoms. |

## Deliberate reduced-scope behavior

- A battle action is an exchange followed by one enemy AI response; the full
  per-stack speed queue, Wait, morale, and luck loop is not implemented.
- `shots` and retaliation capacity are catalogue data used for capability, but
  per-battle decrementing counters are not yet stored.
- Ground movement validates distance, endpoint occupancy, and endpoint
  obstacle. It does not run a full 165-node path search around intervening
  blockers; flying stacks may ignore endpoint obstacles.
- The ranged-engagement penalty for an adjacent hostile stack, double-wide
  creatures, siege engines, and status effects are not implemented.
- The route AI is deterministic and scenario-aware rather than a general map
  searcher. The tactical AI uses bounded local fallback, not exhaustive search.
- One representative hero per faction, one direct-damage spell, and one
  artifact are retained. Campaigns, audio, and networking are intentionally
  excluded by the selected scope.

## Bend implementation issues

No reproducible Bend parser, checker, compiler, Base/runtime, JavaScript, or C
backend defect has been found during this pass. Affine binder-order errors
encountered while authoring were rejected by the checker and fixed in source;
they are language constraints, not unexpected behavior.
