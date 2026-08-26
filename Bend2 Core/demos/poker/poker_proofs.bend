import Base
import ../../compat/list.bend as List

# Poker conservation proof kernel
# ================================
#
# This file proves a semantic property of a discrete-chip betting ledger.  A
# chip is an indivisible token with an identity and a value.  Betting, calling,
# folding, collecting a pot, and splitting a pot are all represented by moving
# one selected token to a different owner.  The selector and destination are
# arbitrary, as is the finite history.
#
# The central specification erases ownership while retaining the ordered list
# of chip identities and values.  Correct settlement must leave that payload
# view unchanged.  The proof is deliberately layered:
#
#   reassign_payload_preservation_theorem
#     proves one arbitrary token reassignment preserves the payload;
#   history_payload_conservation_theorem
#     lifts the step lemma to every finite history;
#   history_chip_count_conservation_theorem and
#   history_chip_value_conservation_theorem
#     derive the observable conservation laws from the stronger payload fact.
#
# This is not an enumeration of the embedded Texas/Omaha traces.  It is an
# induction over arbitrary token lists, arbitrary selectors, arbitrary owners,
# and arbitrary histories.  It also states the model boundary honestly: money
# represented outside this ledger (for example rake or external buy-ins) is not
# covered by the theorem.

type ChipOwner:
  Seat0{}
  Seat1{}
  Seat2{}
  Seat3{}
  Pot{}

type Chip:
  Chip{identity: Nat, value: Nat, owner: ChipOwner}

type ChipPayload:
  ChipPayload{identity: Nat, value: Nat}

type LedgerAction:
  ReassignChip{selector: Nat, destination: ChipOwner}

# Algorithm
# =========

# Reassign the token at a zero-based selector.  An out-of-range selector is a
# no-op.  Notice that the algorithm rebuilds the selected token with the same
# identity and value and changes only ownership.
assert reassign_chip:
  forall selector: Nat
  forall chips: List<Chip>
  forall destination: ChipOwner
  List<Chip>

def reassign_chip(selector, chips, destination):
  match selector:
    case 0n:
      match chips:
        case Nil{}:
          Nil{}
        case Con{Chip{identity, value, owner}, tail}:
          Con{Chip{identity, value, destination}, tail}
    case 1n+pred:
      match chips:
        case Nil{}:
          Nil{}
        case Con{head, tail}:
          Con{head, reassign_chip(pred, tail, destination)}

assert settle_action:
  forall action: LedgerAction
  forall chips: List<Chip>
  List<Chip>

def settle_action(action, chips):
  match action:
    case ReassignChip{selector, destination}:
      reassign_chip(selector, chips, destination)

assert settle_history:
  forall history: List<LedgerAction>
  forall chips: List<Chip>
  List<Chip>

def settle_history(history, chips):
  match history:
    case Nil{}:
      chips
    case Con{action, tail}:
      settle_history(tail, settle_action(action, chips))

# Semantic specification
# ======================

# Ownership is the only part of a chip that settlement may change.  Erasing
# owners therefore produces the canonical conservation view.
assert chip_payload:
  forall chips: List<Chip>
  List<ChipPayload>

def chip_payload(chips):
  match chips:
    case Nil{}:
      Nil{}
    case Con{Chip{identity, value, owner}, tail}:
      Con{ChipPayload{identity, value}, chip_payload(tail)}

assert payload_value:
  forall payload: List<ChipPayload>
  Nat

def payload_value(payload):
  match payload:
    case Nil{}:
      0n
    case Con{ChipPayload{identity, value}, tail}:
      Nat.add(value, payload_value(tail))

assert chip_count:
  forall chips: List<Chip>
  Nat

def chip_count(chips):
  List.length(ChipPayload, chip_payload(chips))

assert chip_value:
  forall chips: List<Chip>
  Nat

def chip_value(chips):
  payload_value(chip_payload(chips))

# Helper lemmas
# =============

# Affine Core has no implicit contraction.  The history induction needs one
# ledger replica for the recursive history and one for the first-step lemma,
# so these copiers construct both replicas and proofs relating them to the
# consumed source.  This cost is explicit data work even though the equality
# witnesses themselves erase.
assert chip_owner_copy:
  forall owner: ChipOwner
  Copy(ChipOwner, owner) & Copy(ChipOwner, owner)

def chip_owner_copy(owner):
  match owner:
    case Seat0{}:
      ((Seat0{}, {==}), (Seat0{}, {==}))
    case Seat1{}:
      ((Seat1{}, {==}), (Seat1{}, {==}))
    case Seat2{}:
      ((Seat2{}, {==}), (Seat2{}, {==}))
    case Seat3{}:
      ((Seat3{}, {==}), (Seat3{}, {==}))
    case Pot{}:
      ((Pot{}, {==}), (Pot{}, {==}))

assert chip_replica_exact:
  forall -identity: Nat
  forall -value: Nat
  forall -owner: ChipOwner
  forall -replica_identity: Nat
  forall -replica_value: Nat
  forall -replica_owner: ChipOwner
  forall identity_exact: {identity == replica_identity : Nat}
  forall value_exact: {value == replica_value : Nat}
  forall owner_exact: {owner == replica_owner : ChipOwner}
  { Chip{identity, value, owner} == Chip{replica_identity, replica_value, replica_owner} : Chip }

def chip_replica_exact(identity, value, owner, replica_identity, replica_value, replica_owner, identity_exact, value_exact, owner_exact):
  %identity_exact : {
    Chip{identity, value, owner} == Chip{_, replica_value, replica_owner}
    : Chip
  }
  %value_exact : {
    Chip{identity, value, owner} == Chip{identity, _, replica_owner}
    : Chip
  }
  %owner_exact : {
    Chip{identity, value, owner} == Chip{identity, value, _}
    : Chip
  }
  {==}

assert chip_copy_side:
  forall -identity: Nat
  forall -value: Nat
  forall -owner: ChipOwner
  forall replica_identity: Nat
  forall replica_value: Nat
  forall replica_owner: ChipOwner
  forall identity_exact: {identity == replica_identity : Nat}
  forall value_exact: {value == replica_value : Nat}
  forall owner_exact: {owner == replica_owner : ChipOwner}
  Copy(Chip, Chip{identity, value, owner})

def chip_copy_side(identity, value, owner, replica_identity, replica_value, replica_owner, identity_exact, value_exact, owner_exact):
  (
    Chip{replica_identity, replica_value, replica_owner},
    chip_replica_exact(
      identity,
      value,
      owner,
      replica_identity,
      replica_value,
      replica_owner,
      identity_exact,
      value_exact,
      owner_exact
    )
  )

assert chip_copy:
  forall chip: Chip
  Copy(Chip, chip) & Copy(Chip, chip)

def chip_copy(chip):
  match chip:
    case Chip{identity, value, owner}:
      ((i0, ei0), (i1, ei1)) = Nat.copy(identity)
      ((v0, ev0), (v1, ev1)) = Nat.copy(value)
      ((o0, eo0), (o1, eo1)) = chip_owner_copy(owner)
      (
        chip_copy_side(identity, value, owner, i0, v0, o0, ei0, ev0, eo0),
        chip_copy_side(identity, value, owner, i1, v1, o1, ei1, ev1, eo1)
      )

assert chip_list_replica_exact:
  forall -head: Chip
  forall -tail: List<Chip>
  forall -replica_head: Chip
  forall -replica_tail: List<Chip>
  forall head_exact: {head == replica_head : Chip}
  forall tail_exact: {tail == replica_tail : List<Chip>}
  {Con{head, tail} == Con{replica_head, replica_tail} : List<Chip>}

def chip_list_replica_exact(head, tail, replica_head, replica_tail, head_exact, tail_exact):
  %head_exact : {Con{head, tail} == Con{_, replica_tail} : List<Chip>}
  %tail_exact : {Con{head, tail} == Con{head, _} : List<Chip>}
  {==}

assert chip_list_copy_side:
  forall -head: Chip
  forall -tail: List<Chip>
  forall replica_head: Chip
  forall replica_tail: List<Chip>
  forall head_exact: {head == replica_head : Chip}
  forall tail_exact: {tail == replica_tail : List<Chip>}
  Copy(List<Chip>, Con{head, tail})

def chip_list_copy_side(head, tail, replica_head, replica_tail, head_exact, tail_exact):
  (
    Con{replica_head, replica_tail},
    chip_list_replica_exact(
      head,
      tail,
      replica_head,
      replica_tail,
      head_exact,
      tail_exact
    )
  )

assert chip_list_copy:
  forall chips: List<Chip>
  Copy(List<Chip>, chips) & Copy(List<Chip>, chips)

def chip_list_copy(chips):
  match chips:
    case Nil{}:
      ((Nil{}, {==}), (Nil{}, {==}))
    case Con{head, tail}:
      ((h0, eh0), (h1, eh1)) = chip_copy(head)
      ((t0, et0), (t1, et1)) = chip_list_copy(tail)
      (
        chip_list_copy_side(head, tail, h0, t0, eh0, et0),
        chip_list_copy_side(head, tail, h1, t1, eh1, et1)
      )

assert ledger_action_replica_exact:
  forall -selector: Nat
  forall -destination: ChipOwner
  forall -replica_selector: Nat
  forall -replica_destination: ChipOwner
  forall selector_exact: {selector == replica_selector : Nat}
  forall destination_exact: {destination == replica_destination : ChipOwner}
  { ReassignChip{selector, destination} == ReassignChip{replica_selector, replica_destination} : LedgerAction }

def ledger_action_replica_exact(selector, destination, replica_selector, replica_destination, selector_exact, destination_exact):
  %selector_exact : {
    ReassignChip{selector, destination} == ReassignChip{_, replica_destination}
    : LedgerAction
  }
  %destination_exact : {
    ReassignChip{selector, destination} == ReassignChip{selector, _}
    : LedgerAction
  }
  {==}

assert ledger_action_copy_side:
  forall -selector: Nat
  forall -destination: ChipOwner
  forall replica_selector: Nat
  forall replica_destination: ChipOwner
  forall selector_exact: {selector == replica_selector : Nat}
  forall destination_exact: {destination == replica_destination : ChipOwner}
  Copy(LedgerAction, ReassignChip{selector, destination})

def ledger_action_copy_side(selector, destination, replica_selector, replica_destination, selector_exact, destination_exact):
  (
    ReassignChip{replica_selector, replica_destination},
    ledger_action_replica_exact(
      selector,
      destination,
      replica_selector,
      replica_destination,
      selector_exact,
      destination_exact
    )
  )

assert ledger_action_copy:
  forall action: LedgerAction
  Copy(LedgerAction, action) & Copy(LedgerAction, action)

def ledger_action_copy(action):
  match action:
    case ReassignChip{selector, destination}:
      ((s0, es0), (s1, es1)) = Nat.copy(selector)
      ((d0, ed0), (d1, ed1)) = chip_owner_copy(destination)
      (
        ledger_action_copy_side(selector, destination, s0, d0, es0, ed0),
        ledger_action_copy_side(selector, destination, s1, d1, es1, ed1)
      )

# Erasing owners also preserves the number of tokens.  This helper connects
# the stronger payload equality to the familiar cardinality observation.
assert payload_length_theorem:
  forall chips: List<Chip>
  { List.length(ChipPayload, chip_payload(chips)) == List.length(Chip, chips) : Nat }

def payload_length_theorem(chips):
  match chips:
    case Nil{}:
      {==}
    case Con{Chip{identity, value, owner}, tail}:
      %payload_length_theorem(tail) : {
        1n+List.length(ChipPayload, chip_payload(tail)) == 1n+_
        : Nat
      }
      {==}

# THE STEP LEMMA.  It is structural induction on both the selector and the
# arbitrary ledger.  The selected case is definitional because only ownership
# changes.  The recursive case lifts the induction hypothesis through the
# unchanged ChipPayload constructor.
assert reassign_payload_preservation_theorem:
  forall selector: Nat
  forall chips: List<Chip>
  forall destination: ChipOwner
  { chip_payload(reassign_chip(selector, chips, destination)) == chip_payload(chips) : List<ChipPayload> }

def reassign_payload_preservation_theorem(selector, chips, destination):
  match selector:
    case 0n:
      match chips:
        case Nil{}:
          {==}
        case Con{Chip{identity, value, owner}, tail}:
          {==}
    case 1n+pred:
      match chips:
        case Nil{}:
          {==}
        case Con{Chip{identity, value, owner}, tail}:
          Equal.cong(
            List<ChipPayload>,
            List<ChipPayload>,
            rest => Con{ChipPayload{identity, value}, rest},
            chip_payload(reassign_chip(pred, tail, destination)),
            chip_payload(tail),
            reassign_payload_preservation_theorem(pred, tail, destination)
          )

# Package the step lemma for the public action type.  Keeping this separate is
# important: adding a new action constructor forces an explicit proof here.
assert action_payload_preservation_theorem:
  forall action: LedgerAction
  forall chips: List<Chip>
  { chip_payload(settle_action(action, chips)) == chip_payload(chips) : List<ChipPayload> }

def action_payload_preservation_theorem(action, chips):
  match action:
    case ReassignChip{selector, destination}:
      reassign_payload_preservation_theorem(selector, chips, destination)

# Congruence in both inputs of the transition function.  This small transport
# lemma lets the affine history proof execute two explicit replicas while its
# proposition continues to speak about the original action and ledger.
assert settle_action_congruence:
  forall -left_action: LedgerAction
  forall -right_action: LedgerAction
  forall -left_chips: List<Chip>
  forall -right_chips: List<Chip>
  forall action_exact: {left_action == right_action : LedgerAction}
  forall chips_exact: {left_chips == right_chips : List<Chip>}
  { settle_action(left_action, left_chips) == settle_action(right_action, right_chips) : List<Chip> }

def settle_action_congruence(left_action, right_action, left_chips, right_chips, action_exact, chips_exact):
  Equal.trans(
    List<Chip>,
    settle_action(left_action, left_chips),
    settle_action(right_action, left_chips),
    settle_action(right_action, right_chips),
    Equal.cong(
      LedgerAction,
      List<Chip>,
      action => settle_action(action, left_chips),
      left_action,
      right_action,
      action_exact
    ),
    Equal.cong(
      List<Chip>,
      List<Chip>,
      state => settle_action(right_action, state),
      left_chips,
      right_chips,
      chips_exact
    )
  )

# THE SUMMIT.  Every finite settlement history preserves the entire ordered
# identity/value payload.  The induction step composes preservation of the
# tail history with preservation of its first action.
assert history_payload_conservation_theorem:
  forall history: List<LedgerAction>
  forall chips: List<Chip>
  { chip_payload(settle_history(history, chips)) == chip_payload(chips) : List<ChipPayload> }

def history_payload_conservation_theorem(history, chips):
  match history:
    case Nil{}:
      {==}
    case Con{action, tail}:
      ((history_action, history_action_exact), (step_action, step_action_exact)) = ledger_action_copy(action)
      ((history_chips, history_chips_exact), (step_chips, step_chips_exact)) = chip_list_copy(chips)
      ((history_action_exact0, history_action_exact0_copy), (history_action_exact1, history_action_exact1_copy)) = Equal.copy(
        LedgerAction,
        action,
        history_action,
        history_action_exact
      )
      ((history_chips_exact0, history_chips_exact0_copy), (history_chips_exact1, history_chips_exact1_copy)) = Equal.copy(
        List<Chip>,
        chips,
        history_chips,
        history_chips_exact
      )
      ((step_chips_exact0, step_chips_exact0_copy), (step_chips_exact1, step_chips_exact1_copy)) = Equal.copy(
        List<Chip>,
        chips,
        step_chips,
        step_chips_exact
      )
      original_to_history = settle_action_congruence(
        action,
        history_action,
        chips,
        history_chips,
        history_action_exact0,
        history_chips_exact0
      )
      history_to_step = settle_action_congruence(
        history_action,
        step_action,
        history_chips,
        step_chips,
        Equal.trans(
          LedgerAction,
          history_action,
          action,
          step_action,
          Equal.sym(
            LedgerAction,
            action,
            history_action,
            history_action_exact1
          ),
          step_action_exact
        ),
        Equal.trans(
          List<Chip>,
          history_chips,
          chips,
          step_chips,
          Equal.sym(
            List<Chip>,
            chips,
            history_chips,
            history_chips_exact1
          ),
          step_chips_exact0
        )
      )
      Equal.trans(
        List<ChipPayload>,
        chip_payload(settle_history(tail, settle_action(action, chips))),
        chip_payload(settle_history(tail, settle_action(history_action, history_chips))),
        chip_payload(chips),
        Equal.cong(
          List<Chip>,
          List<ChipPayload>,
          next => chip_payload(settle_history(tail, next)),
          settle_action(action, chips),
          settle_action(history_action, history_chips),
          original_to_history
        ),
        Equal.trans(
          List<ChipPayload>,
          chip_payload(settle_history(tail, settle_action(history_action, history_chips))),
          chip_payload(settle_action(history_action, history_chips)),
          chip_payload(chips),
          history_payload_conservation_theorem(
            tail,
            settle_action(history_action, history_chips)
          ),
          Equal.trans(
            List<ChipPayload>,
            chip_payload(settle_action(history_action, history_chips)),
            chip_payload(settle_action(step_action, step_chips)),
            chip_payload(chips),
            Equal.cong(
              List<Chip>,
              List<ChipPayload>,
              chip_payload,
              settle_action(history_action, history_chips),
              settle_action(step_action, step_chips),
              history_to_step
            ),
            Equal.trans(
              List<ChipPayload>,
              chip_payload(settle_action(step_action, step_chips)),
              chip_payload(step_chips),
              chip_payload(chips),
              action_payload_preservation_theorem(step_action, step_chips),
              Equal.cong(
                List<Chip>,
                List<ChipPayload>,
                chip_payload,
                step_chips,
                chips,
                Equal.sym(
                  List<Chip>,
                  chips,
                  step_chips,
                  step_chips_exact1
                )
              )
            )
          )
        )
      )

# Observable corollary 1: no arbitrary sequence of bets and payouts can mint
# or destroy a discrete chip token.
assert history_chip_count_conservation_theorem:
  forall history: List<LedgerAction>
  forall chips: List<Chip>
  { chip_count(settle_history(history, chips)) == chip_count(chips) : Nat }

def history_chip_count_conservation_theorem(history, chips):
  Equal.cong(
    List<ChipPayload>,
    Nat,
    payload => List.length(ChipPayload, payload),
    chip_payload(settle_history(history, chips)),
    chip_payload(chips),
    history_payload_conservation_theorem(history, chips)
  )

# Observable corollary 2: because each surviving token retains its value, the
# total chips represented by the ledger are conserved as well.
assert history_chip_value_conservation_theorem:
  forall history: List<LedgerAction>
  forall chips: List<Chip>
  { chip_value(settle_history(history, chips)) == chip_value(chips) : Nat }

def history_chip_value_conservation_theorem(history, chips):
  Equal.cong(
    List<ChipPayload>,
    Nat,
    payload_value,
    chip_payload(settle_history(history, chips)),
    chip_payload(chips),
    history_payload_conservation_theorem(history, chips)
  )

# Named public propositions make the theorem boundary visible to importers.
assert PokerPayloadConservationClaim:
  Type

def PokerPayloadConservationClaim():
  @history: List<LedgerAction> -> @chips: List<Chip> -> {
    chip_payload(settle_history(history, chips)) == chip_payload(chips)
    : List<ChipPayload>
  }

assert PokerChipCountConservationClaim:
  Type

def PokerChipCountConservationClaim():
  @history: List<LedgerAction> -> @chips: List<Chip> -> {
    chip_count(settle_history(history, chips)) == chip_count(chips)
    : Nat
  }

assert PokerChipValueConservationClaim:
  Type

def PokerChipValueConservationClaim():
  @history: List<LedgerAction> -> @chips: List<Chip> -> {
    chip_value(settle_history(history, chips)) == chip_value(chips)
    : Nat
  }
