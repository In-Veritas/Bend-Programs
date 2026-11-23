import Base

# Reduced SoD tactical rules shared by Bend Heroes.
# The battlefield is an odd-column offset hex grid with 15 columns and 11 rows.

type Hex:
  Hex{column: U32, row: U32}

type HexResult:
  InvalidHex{}
  ValidHex{hex: Hex}

type AttackReach:
  IllegalAttack{}
  MeleeAttack{}
  RangedAttack{long_range_penalty: Bool}

type MoveReach:
  IllegalMove{}
  LegalMove{}

type RetaliationReach:
  NoRetaliation{}
  MayRetaliate{}

type SlotPosition:
  OffBattlefield{}
  AtHex{column: U32, row: U32}

type Formation:
  Formation{s0: SlotPosition, s1: SlotPosition, s2: SlotPosition, s3: SlotPosition, s4: SlotPosition, s5: SlotPosition, s6: SlotPosition}

type FormationSelection:
  FormationSelection{formation: Formation, selected: SlotPosition}

type FormationPair:
  FormationPair{left: Formation, right: Formation}

type Battlefield:
  Battlefield{friendly: Formation, enemy: Formation, obstacle_seed: U32}

type BattlefieldReach:
  BattlefieldReach{battlefield: Battlefield, reach: AttackReach}

type BattlefieldMove:
  BattlefieldMove{battlefield: Battlefield, moved: Bool}

type BattlefieldAiTarget:
  BattlefieldAiTarget{battlefield: Battlefield, target_index: U32}

type BattlefieldTargetCheck:
  BattlefieldTargetCheck{battlefield: Battlefield, blocked: Bool}

type BattlefieldPair:
  BattlefieldPair{left: Battlefield, right: Battlefield}

type PositionOccupied:
  PositionOccupied{position: SlotPosition, occupied: Bool}

type FormationOccupied:
  FormationOccupied{formation: Formation, occupied: Bool}

assert u32_pair:
  forall value: U32
  U32 & U32

def u32_pair(value):
  ((left, left_exact), (right, right_exact)) = U32.copy(value)
  (left, right)

assert u32_abs_diff:
  forall left: U32
  forall right: U32
  U32

def u32_abs_diff(left, right):
  (left_test, left_live) = u32_pair(left)
  (right_test, right_live) = u32_pair(right)
  match U32.is_le(left_test, right_test):
    case True{}:
      U32.sub(right_live, left_live)
    case False{}:
      U32.sub(left_live, right_live)

assert u32_max:
  forall left: U32
  forall right: U32
  U32

def u32_max(left, right):
  (left_test, left_live) = u32_pair(left)
  (right_test, right_live) = u32_pair(right)
  match U32.is_le(left_test, right_test):
    case True{}:
      right_live
    case False{}:
      left_live

assert slot_position_pair:
  forall position: SlotPosition
  SlotPosition & SlotPosition

def slot_position_pair(position):
  match position:
    case OffBattlefield{}:
      (OffBattlefield{}, OffBattlefield{})
    case AtHex{column, row}:
      (left_column, right_column) = u32_pair(column)
      (left_row, right_row) = u32_pair(row)
      (AtHex{left_column, left_row}, AtHex{right_column, right_row})

assert formation_select:
  forall formation: Formation
  forall slot: U32
  FormationSelection

def formation_select(formation, slot):
  match formation U32.to_nat(slot):
    case Formation{s0, s1, s2, s3, s4, s5, s6} 0n:
      (keep, selected) = slot_position_pair(s0)
      FormationSelection{Formation{keep, s1, s2, s3, s4, s5, s6}, selected}
    case Formation{s0, s1, s2, s3, s4, s5, s6} 1n:
      (keep, selected) = slot_position_pair(s1)
      FormationSelection{Formation{s0, keep, s2, s3, s4, s5, s6}, selected}
    case Formation{s0, s1, s2, s3, s4, s5, s6} 2n:
      (keep, selected) = slot_position_pair(s2)
      FormationSelection{Formation{s0, s1, keep, s3, s4, s5, s6}, selected}
    case Formation{s0, s1, s2, s3, s4, s5, s6} 3n:
      (keep, selected) = slot_position_pair(s3)
      FormationSelection{Formation{s0, s1, s2, keep, s4, s5, s6}, selected}
    case Formation{s0, s1, s2, s3, s4, s5, s6} 4n:
      (keep, selected) = slot_position_pair(s4)
      FormationSelection{Formation{s0, s1, s2, s3, keep, s5, s6}, selected}
    case Formation{s0, s1, s2, s3, s4, s5, s6} 5n:
      (keep, selected) = slot_position_pair(s5)
      FormationSelection{Formation{s0, s1, s2, s3, s4, keep, s6}, selected}
    case Formation{s0, s1, s2, s3, s4, s5, s6} other:
      (keep, selected) = slot_position_pair(s6)
      FormationSelection{Formation{s0, s1, s2, s3, s4, s5, keep}, selected}

assert formation_place:
  forall formation: Formation
  forall slot: U32
  forall position: SlotPosition
  Formation

def formation_place(formation, slot, position):
  match formation U32.to_nat(slot):
    case Formation{s0, s1, s2, s3, s4, s5, s6} 0n: Formation{position, s1, s2, s3, s4, s5, s6}
    case Formation{s0, s1, s2, s3, s4, s5, s6} 1n: Formation{s0, position, s2, s3, s4, s5, s6}
    case Formation{s0, s1, s2, s3, s4, s5, s6} 2n: Formation{s0, s1, position, s3, s4, s5, s6}
    case Formation{s0, s1, s2, s3, s4, s5, s6} 3n: Formation{s0, s1, s2, position, s4, s5, s6}
    case Formation{s0, s1, s2, s3, s4, s5, s6} 4n: Formation{s0, s1, s2, s3, position, s5, s6}
    case Formation{s0, s1, s2, s3, s4, s5, s6} 5n: Formation{s0, s1, s2, s3, s4, position, s6}
    case Formation{s0, s1, s2, s3, s4, s5, s6} other: Formation{s0, s1, s2, s3, s4, s5, position}

assert formation_pair:
  forall formation: Formation
  FormationPair

def formation_pair(formation):
  match formation:
    case Formation{s0, s1, s2, s3, s4, s5, s6}:
      (l0, r0) = slot_position_pair(s0)
      (l1, r1) = slot_position_pair(s1)
      (l2, r2) = slot_position_pair(s2)
      (l3, r3) = slot_position_pair(s3)
      (l4, r4) = slot_position_pair(s4)
      (l5, r5) = slot_position_pair(s5)
      (l6, r6) = slot_position_pair(s6)
      FormationPair{Formation{l0, l1, l2, l3, l4, l5, l6}, Formation{r0, r1, r2, r3, r4, r5, r6}}

assert attacker_formation:
  Formation

def attacker_formation():
  Formation{AtHex{1, 2}, AtHex{1, 3}, AtHex{1, 4}, AtHex{1, 5}, AtHex{1, 6}, AtHex{1, 7}, AtHex{1, 8}}

assert defender_formation:
  Formation

def defender_formation():
  Formation{AtHex{13, 2}, AtHex{13, 3}, AtHex{13, 4}, AtHex{13, 5}, AtHex{13, 6}, AtHex{13, 7}, AtHex{13, 8}}

assert battlefield_new:
  forall seed: U32
  Battlefield

def battlefield_new(seed):
  Battlefield{attacker_formation(), defender_formation(), seed}

assert battlefield_pair:
  forall battlefield: Battlefield
  BattlefieldPair

def battlefield_pair(battlefield):
  match battlefield:
    case Battlefield{friendly, enemy, obstacle_seed}:
      FormationPair{friendly_left, friendly_right} = formation_pair(friendly)
      FormationPair{enemy_left, enemy_right} = formation_pair(enemy)
      (seed_left, seed_right) = u32_pair(obstacle_seed)
      BattlefieldPair{
        Battlefield{friendly_left, enemy_left, seed_left},
        Battlefield{friendly_right, enemy_right, seed_right}
      }

assert battlefield_flip:
  forall battlefield: Battlefield
  Battlefield

def battlefield_flip(battlefield):
  match battlefield:
    case Battlefield{friendly, enemy, obstacle_seed}:
      Battlefield{enemy, friendly, obstacle_seed}

assert slot_position_occupied:
  forall position: SlotPosition
  forall column: U32
  forall row: U32
  PositionOccupied

def slot_position_occupied(position, column, row):
  match position:
    case OffBattlefield{}:
      PositionOccupied{OffBattlefield{}, False{}}
    case AtHex{old_column, old_row}:
      (old_column_test, old_column_keep) = u32_pair(old_column)
      (old_row_test, old_row_keep) = u32_pair(old_row)
      PositionOccupied{
        AtHex{old_column_keep, old_row_keep},
        Bool.and(U32.is_eq(old_column_test, column), U32.is_eq(old_row_test, row))
      }

assert formation_occupied_values:
  forall formation: Formation
  forall c0: U32
  forall r0: U32
  forall c1: U32
  forall r1: U32
  forall c2: U32
  forall r2: U32
  forall c3: U32
  forall r3: U32
  forall c4: U32
  forall r4: U32
  forall c5: U32
  forall r5: U32
  forall c6: U32
  forall r6: U32
  FormationOccupied

def formation_occupied_values(formation, c0, r0, c1, r1, c2, r2, c3, r3, c4, r4, c5, r5, c6, r6):
  match formation:
    case Formation{s0, s1, s2, s3, s4, s5, s6}:
      PositionOccupied{p0, o0} = slot_position_occupied(s0, c0, r0)
      PositionOccupied{p1, o1} = slot_position_occupied(s1, c1, r1)
      PositionOccupied{p2, o2} = slot_position_occupied(s2, c2, r2)
      PositionOccupied{p3, o3} = slot_position_occupied(s3, c3, r3)
      PositionOccupied{p4, o4} = slot_position_occupied(s4, c4, r4)
      PositionOccupied{p5, o5} = slot_position_occupied(s5, c5, r5)
      PositionOccupied{p6, o6} = slot_position_occupied(s6, c6, r6)
      FormationOccupied{
        Formation{p0, p1, p2, p3, p4, p5, p6},
        Bool.or(o0, Bool.or(o1, Bool.or(o2, Bool.or(o3, Bool.or(o4, Bool.or(o5, o6))))))
      }

assert formation_occupied:
  forall formation: Formation
  forall column: U32
  forall row: U32
  FormationOccupied

def formation_occupied(formation, column, row):
  (c0, column1) = u32_pair(column)
  (c1, column2) = u32_pair(column1)
  (c2, column3) = u32_pair(column2)
  (c3, column4) = u32_pair(column3)
  (c4, column5) = u32_pair(column4)
  (c5, c6) = u32_pair(column5)
  (r0, row1) = u32_pair(row)
  (r1, row2) = u32_pair(row1)
  (r2, row3) = u32_pair(row2)
  (r3, row4) = u32_pair(row3)
  (r4, row5) = u32_pair(row4)
  (r5, r6) = u32_pair(row5)
  formation_occupied_values(formation, c0, r0, c1, r1, c2, r2, c3, r3, c4, r4, c5, r5, c6, r6)

assert hex_valid:
  forall column: U32
  forall row: U32
  Bool

def hex_valid(column, row):
  Bool.and(U32.is_lt(column, 15), U32.is_lt(row, 11))

assert hex_make:
  forall column: U32
  forall row: U32
  HexResult

def hex_make(column, row):
  (column_test, column_live) = u32_pair(column)
  (row_test, row_live) = u32_pair(row)
  match hex_valid(column_test, row_test):
    case False{}:
      InvalidHex{}
    case True{}:
      ValidHex{Hex{column_live, row_live}}

assert hex_index:
  forall column: U32
  forall row: U32
  U32

def hex_index(column, row):
  U32.add(U32.mul(row, 15), column)

assert hex_from_index:
  forall index: U32
  HexResult

def hex_from_index(index):
  (for_column, for_row) = u32_pair(index)
  hex_make(U32.mod(for_column, 15), U32.div(for_row, 15))

# For odd-column offset coordinates, doubled vertical coordinates avoid signed
# arithmetic: distance = max(dx, (dx + abs(y2a-y2b))/2).
assert hex_distance_values:
  forall left_column: U32
  forall left_row: U32
  forall right_column: U32
  forall right_row: U32
  U32

def hex_distance_values(left_column, left_row, right_column, right_row):
  (left_column_dx, left_column_tail) = u32_pair(left_column)
  (left_column_parity, left_column_offset) = u32_pair(left_column_tail)
  (right_column_dx, right_column_tail) = u32_pair(right_column)
  (right_column_parity, right_column_offset) = u32_pair(right_column_tail)
  dx = u32_abs_diff(left_column_dx, right_column_dx)
  (dx_for_max, dx_for_sum) = u32_pair(dx)
  left_y2 = U32.sub(
    U32.add(U32.add(U32.mul(left_row, 2), U32.mod(left_column_parity, 2)), 14),
    left_column_offset
  )
  right_y2 = U32.sub(
    U32.add(U32.add(U32.mul(right_row, 2), U32.mod(right_column_parity, 2)), 14),
    right_column_offset
  )
  dy2 = u32_abs_diff(left_y2, right_y2)
  u32_max(dx_for_max, U32.div(U32.add(dx_for_sum, dy2), 2))

assert hex_distance:
  forall left: Hex
  forall right: Hex
  U32

def hex_distance(left, right):
  match left right:
    case Hex{left_column, left_row} Hex{right_column, right_row}:
      hex_distance_values(left_column, left_row, right_column, right_row)

# Deployment columns 0-1 and 13-14 are always clear. Interior obstacles are
# deterministic from the battle seed so replays and multiplayer stay stable.
assert battlefield_obstacle:
  forall column: U32
  forall row: U32
  forall seed: U32
  Bool

def battlefield_obstacle(column, row, seed):
  (column_low, column_tail) = u32_pair(column)
  (column_high, column_hash) = u32_pair(column_tail)
  match Bool.and(U32.is_le(2, column_low), U32.is_le(column_high, 12)):
    case False{}:
      False{}
    case True{}:
      hash = U32.add(U32.add(U32.mul(column_hash, 37), U32.mul(row, 61)), seed)
      U32.is_eq(U32.mod(hash, 17), 0)

# range=1 is melee. A larger numeric range is a real spatial capability.
# Ranged attacks need ammunition and an unblocked shooter. Beyond ten hexes the
# caller applies the standard half-damage penalty.
assert attack_reach_decide:
  forall melee: Bool
  forall ranged_ready: Bool
  forall within_range: Bool
  forall long_range: Bool
  AttackReach

def attack_reach_decide(melee, ranged_ready, within_range, long_range):
  match melee:
    case True{}:
      MeleeAttack{}
    case False{}:
      match ranged_ready:
        case False{}:
          IllegalAttack{}
        case True{}:
          match within_range:
            case False{}:
              IllegalAttack{}
            case True{}:
              RangedAttack{long_range}

assert attack_reach:
  forall distance: U32
  forall blocked: Bool
  forall shots: U32
  forall range: U32
  AttackReach

def attack_reach(distance, blocked, shots, range):
  (distance_melee, distance_tail) = u32_pair(distance)
  (distance_ranged, distance_long) = u32_pair(distance_tail)
  attack_reach_decide(
    U32.is_le(distance_melee, 1),
    Bool.and(Bool.not(blocked), Bool.not(U32.is_eq(shots, 0))),
    U32.is_le(distance_ranged, range),
    U32.is_lt(10, distance_long)
  )

assert battlefield_attack_reach:
  forall battlefield: Battlefield
  forall own_slot: U32
  forall target_slot: U32
  forall blocked: Bool
  forall shots: U32
  forall range: U32
  BattlefieldReach

def battlefield_attack_reach(battlefield, own_slot, target_slot, blocked, shots, range):
  match battlefield:
    case Battlefield{friendly, enemy, obstacle_seed}:
      match formation_select(friendly, own_slot):
        case FormationSelection{friendly_keep, OffBattlefield{}}:
          BattlefieldReach{Battlefield{friendly_keep, enemy, obstacle_seed}, IllegalAttack{}}
        case FormationSelection{friendly_keep, AtHex{own_column, own_row}}:
          match formation_select(enemy, target_slot):
            case FormationSelection{enemy_keep, OffBattlefield{}}:
              BattlefieldReach{Battlefield{friendly_keep, enemy_keep, obstacle_seed}, IllegalAttack{}}
            case FormationSelection{enemy_keep, AtHex{target_column, target_row}}:
              BattlefieldReach{
                Battlefield{friendly_keep, enemy_keep, obstacle_seed},
                attack_reach(
                  hex_distance_values(own_column, own_row, target_column, target_row),
                  blocked,
                  shots,
                  range
                )
              }

assert move_reach_decide:
  forall within_speed: Bool
  forall occupied: Bool
  forall terrain_clear: Bool
  MoveReach

def move_reach_decide(within_speed, occupied, terrain_clear):
  match within_speed:
    case False{}:
      IllegalMove{}
    case True{}:
      match occupied:
        case True{}:
          IllegalMove{}
        case False{}:
          match terrain_clear:
            case False{}: IllegalMove{}
            case True{}: LegalMove{}

assert move_reach:
  forall distance: U32
  forall speed: U32
  forall occupied: Bool
  forall obstacle: Bool
  forall flying: Bool
  MoveReach

def move_reach(distance, speed, occupied, obstacle, flying):
  move_reach_decide(
    U32.is_le(distance, speed),
    occupied,
    Bool.or(Bool.not(obstacle), flying)
  )

assert battlefield_move_from:
  forall friendly: Formation
  forall enemy: Formation
  forall obstacle_seed: U32
  forall slot: U32
  forall own_column: U32
  forall own_row: U32
  forall target_column: U32
  forall target_row: U32
  forall speed: U32
  forall flying: Bool
  BattlefieldMove

def battlefield_move_from(friendly, enemy, obstacle_seed, slot, own_column, own_row, target_column, target_row, speed, flying):
  (valid_column, column1) = u32_pair(target_column)
  (friendly_column, column2) = u32_pair(column1)
  (enemy_column, column3) = u32_pair(column2)
  (obstacle_column, column4) = u32_pair(column3)
  (distance_column, output_column) = u32_pair(column4)
  (valid_row, row1) = u32_pair(target_row)
  (friendly_row, row2) = u32_pair(row1)
  (enemy_row, row3) = u32_pair(row2)
  (obstacle_row, row4) = u32_pair(row3)
  (distance_row, output_row) = u32_pair(row4)
  (seed_test, seed_keep) = u32_pair(obstacle_seed)
  match hex_valid(valid_column, valid_row):
    case False{}:
      BattlefieldMove{Battlefield{friendly, enemy, seed_keep}, False{}}
    case True{}:
      match formation_occupied(friendly, friendly_column, friendly_row):
        case FormationOccupied{friendly_keep, friendly_occupied}:
          match formation_occupied(enemy, enemy_column, enemy_row):
            case FormationOccupied{enemy_keep, enemy_occupied}:
              match move_reach(
                hex_distance_values(own_column, own_row, distance_column, distance_row),
                speed,
                Bool.or(friendly_occupied, enemy_occupied),
                battlefield_obstacle(obstacle_column, obstacle_row, seed_test),
                flying
              ):
                case IllegalMove{}:
                  BattlefieldMove{Battlefield{friendly_keep, enemy_keep, seed_keep}, False{}}
                case LegalMove{}:
                  BattlefieldMove{
                    Battlefield{formation_place(friendly_keep, slot, AtHex{output_column, output_row}), enemy_keep, seed_keep},
                    True{}
                  }

assert battlefield_move_friendly:
  forall battlefield: Battlefield
  forall slot: U32
  forall target_column: U32
  forall target_row: U32
  forall speed: U32
  forall flying: Bool
  BattlefieldMove

def battlefield_move_friendly(battlefield, slot, target_column, target_row, speed, flying):
  match battlefield:
    case Battlefield{friendly, enemy, obstacle_seed}:
      (slot_select, slot_place) = u32_pair(slot)
      match formation_select(friendly, slot_select):
        case FormationSelection{friendly_keep, OffBattlefield{}}:
          BattlefieldMove{Battlefield{friendly_keep, enemy, obstacle_seed}, False{}}
        case FormationSelection{friendly_keep, AtHex{own_column, own_row}}:
          battlefield_move_from(
            friendly_keep,
            enemy,
            obstacle_seed,
            slot_place,
            own_column,
            own_row,
            target_column,
            target_row,
            speed,
            flying
          )

assert battlefield_ai_target:
  forall battlefield: Battlefield
  forall own_slot: U32
  forall target_slot: U32
  forall speed: U32
  BattlefieldAiTarget

assert battlefield_ai_column:
  forall own_column: U32
  forall target_column: U32
  forall speed: U32
  U32

def battlefield_ai_column(own_column, target_column, speed):
  (own_test, own_live) = u32_pair(own_column)
  (target_test, target_live) = u32_pair(target_column)
  match U32.is_le(own_test, target_test):
    case True{}:
      desired_column = U32.sub(target_live, 1)
      maximum_column = U32.add(own_live, speed)
      (desired_test, desired_output) = u32_pair(desired_column)
      (maximum_test, maximum_output) = u32_pair(maximum_column)
      match U32.is_le(desired_test, maximum_test):
        case True{}: desired_output
        case False{}: maximum_output
    case False{}:
      desired_column = U32.inc(target_live)
      minimum_column = U32.sub(own_live, speed)
      (desired_test, desired_output) = u32_pair(desired_column)
      (minimum_test, minimum_output) = u32_pair(minimum_column)
      match U32.is_le(minimum_test, desired_test):
        case True{}: desired_output
        case False{}: minimum_output

assert battlefield_ai_row:
  forall own_column: U32
  forall own_row: U32
  forall target_column: U32
  forall target_row: U32
  forall speed: U32
  U32

def battlefield_ai_row(own_column, own_row, target_column, target_row, speed):
  match U32.is_le(u32_abs_diff(own_column, target_column), speed):
    case True{}: target_row
    case False{}: own_row

assert battlefield_ai_avoid_obstacle:
  forall own_column: U32
  forall target_column: U32
  forall +candidate: +U32
  forall row: U32
  forall seed: U32
  U32

def battlefield_ai_avoid_obstacle(own_column, target_column, candidate, row, seed):
  match battlefield_obstacle(candidate, row, seed):
    case False{}: candidate
    case True{}:
      match U32.is_le(own_column, target_column):
        case True{}: U32.sub(candidate, 1)
        case False{}: U32.inc(candidate)

assert battlefield_ai_validate_target:
  forall friendly: Formation
  forall enemy: Formation
  forall obstacle_seed: U32
  forall candidate_column: U32
  forall candidate_row: U32
  BattlefieldAiTarget

assert battlefield_target_check:
  forall battlefield: Battlefield
  forall column: U32
  forall row: U32
  BattlefieldTargetCheck

def battlefield_target_check(battlefield, column, row):
  match battlefield:
    case Battlefield{friendly, enemy, obstacle_seed}:
      (valid_column, column1) = u32_pair(column)
      (friendly_column, column2) = u32_pair(column1)
      (enemy_column, obstacle_column) = u32_pair(column2)
      (valid_row, row1) = u32_pair(row)
      (friendly_row, row2) = u32_pair(row1)
      (enemy_row, obstacle_row) = u32_pair(row2)
      (seed_test, seed_output) = u32_pair(obstacle_seed)
      match formation_occupied(friendly, friendly_column, friendly_row):
        case FormationOccupied{friendly_keep, friendly_occupied}:
          match formation_occupied(enemy, enemy_column, enemy_row):
            case FormationOccupied{enemy_keep, enemy_occupied}:
              BattlefieldTargetCheck{
                Battlefield{friendly_keep, enemy_keep, seed_output},
                Bool.or(Bool.not(hex_valid(valid_column, valid_row)), Bool.or(friendly_occupied, Bool.or(enemy_occupied, battlefield_obstacle(obstacle_column, obstacle_row, seed_test))))
              }

def battlefield_ai_validate_target(friendly, enemy, obstacle_seed, candidate_column, candidate_row):
  (primary_column, column_tail) = u32_pair(candidate_column)
  (upper_column, column_tail2) = u32_pair(column_tail)
  (lower_column, output_column) = u32_pair(column_tail2)
  (primary_row, row_tail) = u32_pair(candidate_row)
  (upper_row_source, lower_row_source) = u32_pair(row_tail)
  match battlefield_target_check(Battlefield{friendly, enemy, obstacle_seed}, primary_column, primary_row):
    case BattlefieldTargetCheck{primary_battlefield, False{}}:
      BattlefieldAiTarget{primary_battlefield, hex_index(upper_column, upper_row_source)}
    case BattlefieldTargetCheck{primary_battlefield, True{}}:
      upper_row = U32.inc(upper_row_source)
      (upper_row_check, upper_row_output) = u32_pair(upper_row)
      match battlefield_target_check(primary_battlefield, upper_column, upper_row_check):
        case BattlefieldTargetCheck{upper_battlefield, False{}}:
          BattlefieldAiTarget{upper_battlefield, hex_index(lower_column, upper_row_output)}
        case BattlefieldTargetCheck{upper_battlefield, True{}}:
          lower_row = U32.sub(lower_row_source, 1)
          (lower_row_check, lower_row_output) = u32_pair(lower_row)
          match battlefield_target_check(upper_battlefield, lower_column, lower_row_check):
            case BattlefieldTargetCheck{lower_battlefield, lower_blocked}:
              BattlefieldAiTarget{lower_battlefield, hex_index(output_column, lower_row_output)}

def battlefield_ai_target(battlefield, own_slot, target_slot, speed):
  match battlefield:
    case Battlefield{friendly, enemy, obstacle_seed}:
      match formation_select(friendly, own_slot):
        case FormationSelection{friendly_keep, OffBattlefield{}}:
          BattlefieldAiTarget{Battlefield{friendly_keep, enemy, obstacle_seed}, 0}
        case FormationSelection{friendly_keep, AtHex{own_column, own_row}}:
          match formation_select(enemy, target_slot):
            case FormationSelection{enemy_keep, OffBattlefield{}}:
              BattlefieldAiTarget{Battlefield{friendly_keep, enemy_keep, obstacle_seed}, 0}
            case FormationSelection{enemy_keep, AtHex{target_column, target_row}}:
              (own_column_plan, own_column_row) = u32_pair(own_column)
              (target_column_plan, target_column_row) = u32_pair(target_column)
              (speed_column, speed_row) = u32_pair(speed)
              candidate_column = battlefield_ai_column(own_column_plan, target_column_plan, speed_column)
              candidate_row = battlefield_ai_row(own_column_row, own_row, target_column_row, target_row, speed_row)
              battlefield_ai_validate_target(friendly_keep, enemy_keep, obstacle_seed, candidate_column, candidate_row)

assert retaliation_reach_decide:
  forall attack: AttackReach
  forall has_retaliation: Bool
  forall attacker_prevents: Bool
  RetaliationReach

def retaliation_reach_decide(attack, has_retaliation, attacker_prevents):
  match attack:
    case IllegalAttack{}:
      NoRetaliation{}
    case RangedAttack{long_range_penalty}:
      NoRetaliation{}
    case MeleeAttack{}:
      match has_retaliation:
        case False{}:
          NoRetaliation{}
        case True{}:
          match attacker_prevents:
            case True{}: NoRetaliation{}
            case False{}: MayRetaliate{}

assert retaliation_reach:
  forall attack: AttackReach
  forall retaliations: U32
  forall attacker_prevents: Bool
  RetaliationReach

def retaliation_reach(attack, retaliations, attacker_prevents):
  retaliation_reach_decide(
    attack,
    Bool.not(U32.is_eq(retaliations, 0)),
    attacker_prevents
  )

assert battlefield_self_check:
  Bool

def battlefield_self_check():
  match hex_make(14, 10):
    case InvalidHex{}:
      False{}
    case ValidHex{right_bottom}:
      match hex_make(0, 0):
        case InvalidHex{}:
          False{}
        case ValidHex{left_top}:
          match attack_reach(hex_distance(left_top, right_bottom), False{}, 12, 15):
            case RangedAttack{long_range_penalty}:
              long_range_penalty
            case IllegalAttack{}:
              False{}
            case MeleeAttack{}:
              False{}
