import Base

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
#
# Port note (bend2-core c5d69a1 -> latest Bend): every `assert` became a `law`
# with the same statement and its proof a `def` of the same name.  The ledger
# types are `Data`, so a ledger reused by the history induction is a `+` binder
# (a reference-counted share).  The old affine-Core replica machinery
# (`chip_owner_copy`, `chip_copy`, `chip_list_copy`, `ledger_action_copy`, their
# `*_replica_exact` / `*_copy_side` lemmas and `Equal.copy`) only existed to
# copy a ledger under proof, and is gone with it; no statement was weakened.
# Lists are `+List<..>` (Base `List<&2, ..>`), so lengths use Base's
# `List.length(&2, A, xs)`.

type ChipOwner is Data:
  Seat0{}
  Seat1{}
  Seat2{}
  Seat3{}
  Pot{}

type Chip is Data:
  Chip{identity: Nat, value: Nat, owner: ChipOwner}

type ChipPayload is Data:
  ChipPayload{identity: Nat, value: Nat}

type LedgerAction is Data:
  ReassignChip{selector: Nat, destination: ChipOwner}

# Algorithm
# =========

# Reassign the token at a zero-based selector.  An out-of-range selector is a
# no-op.  Notice that the algorithm rebuilds the selected token with the same
# identity and value and changes only ownership.
def reassign_chip(selector: Nat, chips: +List<Chip>, destination: ChipOwner) -> +List<Chip>:
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

def settle_action(action: LedgerAction, chips: +List<Chip>) -> +List<Chip>:
  match action:
    case ReassignChip{selector, destination}:
      reassign_chip(selector, chips, destination)

def settle_history(history: +List<LedgerAction>, chips: +List<Chip>) -> +List<Chip>:
  match history:
    case Nil{}:
      chips
    case Con{action, tail}:
      settle_history(tail, settle_action(action, chips))

# Semantic specification
# ======================

# Ownership is the only part of a chip that settlement may change.  Erasing
# owners therefore produces the canonical conservation view.
def chip_payload(chips: +List<Chip>) -> +List<ChipPayload>:
  match chips:
    case Nil{}:
      Nil{}
    case Con{Chip{identity, value, owner}, tail}:
      Con{ChipPayload{identity, value}, chip_payload(tail)}

def payload_value(payload: +List<ChipPayload>) -> Nat:
  match payload:
    case Nil{}:
      0n
    case Con{ChipPayload{identity, value}, tail}:
      Nat.add(value, payload_value(tail))

def chip_count(chips: +List<Chip>) -> Nat:
  List.length(&2, ChipPayload, chip_payload(chips))

def chip_value(chips: +List<Chip>) -> Nat:
  payload_value(chip_payload(chips))

# Helper lemmas
# =============

# Erasing owners also preserves the number of tokens.  This helper connects
# the stronger payload equality to the familiar cardinality observation.
law payload_length_theorem:
  for chips: +List<Chip>
  { List.length(&2, ChipPayload, chip_payload(chips)) == List.length(&2, Chip, chips) : Nat }

def payload_length_theorem(chips):
  match chips:
    case Nil{}:
      {==}
    case Con{Chip{identity, value, owner}, tail}:
      %payload_length_theorem(tail) : {
        1n+List.length(&2, ChipPayload, chip_payload(tail)) == 1n+_
        : Nat
      }
      {==}

# THE STEP LEMMA.  It is structural induction on both the selector and the
# arbitrary ledger.  The selected case is definitional because only ownership
# changes.  The recursive case lifts the induction hypothesis through the
# unchanged ChipPayload constructor.
law reassign_payload_preservation_theorem:
  for selector: Nat
  for chips: +List<Chip>
  for destination: ChipOwner
  { chip_payload(reassign_chip(selector, chips, destination)) == chip_payload(chips) : +List<ChipPayload> }

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
            +List<ChipPayload>,
            +List<ChipPayload>,
            rest => Con{ChipPayload{identity, value}, rest},
            chip_payload(reassign_chip(pred, tail, destination)),
            chip_payload(tail),
            reassign_payload_preservation_theorem(pred, tail, destination)
          )

# Package the step lemma for the public action type.  Keeping this separate is
# important: adding a new action constructor forces an explicit proof here.
law action_payload_preservation_theorem:
  for action: LedgerAction
  for chips: +List<Chip>
  { chip_payload(settle_action(action, chips)) == chip_payload(chips) : +List<ChipPayload> }

def action_payload_preservation_theorem(action, chips):
  match action:
    case ReassignChip{selector, destination}:
      reassign_payload_preservation_theorem(selector, chips, destination)

# Congruence in both inputs of the transition function: equal actions applied
# to equal ledgers settle to equal ledgers.  (The old affine proof used it to
# move between explicit ledger replicas; it remains a public transport lemma.)
law settle_action_congruence:
  for -left_action: LedgerAction
  for -right_action: LedgerAction
  for -left_chips: +List<Chip>
  for -right_chips: +List<Chip>
  for action_exact: {left_action == right_action : LedgerAction}
  for chips_exact: {left_chips == right_chips : +List<Chip>}
  { settle_action(left_action, left_chips) == settle_action(right_action, right_chips) : +List<Chip> }

def settle_action_congruence(left_action, right_action, left_chips, right_chips, action_exact, chips_exact):
  %action_exact : {settle_action(left_action, left_chips) == settle_action(_, right_chips) : +List<Chip>}
  %chips_exact : {settle_action(left_action, left_chips) == settle_action(left_action, _) : +List<Chip>}
  {==}

# THE SUMMIT.  Every finite settlement history preserves the entire ordered
# identity/value payload.  The induction step composes preservation of the
# tail history (the induction hypothesis, on the ledger after the first
# action) with preservation of its first action (the step lemma).
law history_payload_conservation_theorem:
  for history: +List<LedgerAction>
  for +chips: +List<Chip>
  { chip_payload(settle_history(history, chips)) == chip_payload(chips) : +List<ChipPayload> }

def history_payload_conservation_theorem(history, chips):
  match history:
    case Nil{}:
      {==}
    case Con{+action, tail}:
      Equal.trans(
        +List<ChipPayload>,
        chip_payload(settle_history(tail, settle_action(action, chips))),
        chip_payload(settle_action(action, chips)),
        chip_payload(chips),
        history_payload_conservation_theorem(tail, settle_action(action, chips)),
        action_payload_preservation_theorem(action, chips)
      )

# Observable corollary 1: no arbitrary sequence of bets and payouts can mint
# or destroy a discrete chip token.
law history_chip_count_conservation_theorem:
  for history: +List<LedgerAction>
  for +chips: +List<Chip>
  { chip_count(settle_history(history, chips)) == chip_count(chips) : Nat }

def history_chip_count_conservation_theorem(history, chips):
  Equal.cong(
    +List<ChipPayload>,
    Nat,
    payload => List.length(&2, ChipPayload, payload),
    chip_payload(settle_history(history, chips)),
    chip_payload(chips),
    history_payload_conservation_theorem(history, chips)
  )

# Observable corollary 2: because each surviving token retains its value, the
# total chips represented by the ledger are conserved as well.
law history_chip_value_conservation_theorem:
  for history: +List<LedgerAction>
  for +chips: +List<Chip>
  { chip_value(settle_history(history, chips)) == chip_value(chips) : Nat }

def history_chip_value_conservation_theorem(history, chips):
  Equal.cong(
    +List<ChipPayload>,
    Nat,
    payload => payload_value(payload),
    chip_payload(settle_history(history, chips)),
    chip_payload(chips),
    history_payload_conservation_theorem(history, chips)
  )

# Named public propositions make the theorem boundary visible to importers.
# `@+chips` records that the proofs share the ledger (a `+` binder); it does
# not restrict which ledgers the claim speaks about.
def PokerPayloadConservationClaim() -> Type:
  @history: +List<LedgerAction> -> @+chips: +List<Chip> -> {
    chip_payload(settle_history(history, chips)) == chip_payload(chips)
    : +List<ChipPayload>
  }

def PokerChipCountConservationClaim() -> Type:
  @history: +List<LedgerAction> -> @+chips: +List<Chip> -> {
    chip_count(settle_history(history, chips)) == chip_count(chips)
    : Nat
  }

def PokerChipValueConservationClaim() -> Type:
  @history: +List<LedgerAction> -> @+chips: +List<Chip> -> {
    chip_value(settle_history(history, chips)) == chip_value(chips)
    : Nat
  }
