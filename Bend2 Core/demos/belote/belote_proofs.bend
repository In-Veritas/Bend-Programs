import Base

# Belote conservation proof kernel
# ================================
#
# This file proves a semantic property of a Belote card-state machine.  A card
# is an indivisible token with an identity and its rule-defined point value.
# Dealing, playing to the table, and collecting a trick are represented by
# moving one selected token to a different zone.  The selector and destination
# are arbitrary, as is the finite history.
#
# The central specification erases location while retaining the ordered list
# of card identities and values.  Correct settlement must leave that payload
# view unchanged.  The proof is deliberately layered:
#
#   reassign_payload_preservation_theorem
#     proves one arbitrary token reassignment preserves the payload;
#   history_payload_conservation_theorem
#     lifts the step lemma to every finite history;
#   history_card_count_conservation_theorem and
#   history_card_value_conservation_theorem
#     derive the observable conservation laws from the stronger payload fact.
#
# This is not an enumeration of the embedded 32-play trace.  It is induction
# over arbitrary card lists, arbitrary selectors, arbitrary zones, and
# arbitrary histories.  The theorem preserves the point mass printed on the
# cards; contract bonuses and penalties are separate scoring rules.
#
# Port note (bend2-core -> latest Bend): every `assert`+`def` pair is now a
# `law` (or a typed def) with the identical statement.  Bend2 Core was affine
# without contraction, so the old history proof built two explicit replicas of
# the event and the card state (`card_event_copy`, `card_list_copy` and their
# `*_replica_exact` / `*_copy_side` lemmas, plus `Equal.copy`) and transported
# the claim between them with `apply_event_congruence`.  In the latest Bend
# these types are `Data`, so a reusable `+` binder shares one value and the
# replica machinery (which proved nothing about Belote) is gone; the step
# lemma, the congruence lemma and every theorem statement are unchanged.
# Lists are `+List<T>` (`List<&2, T>`) so they can be shared, and Base's
# quantity-polymorphic `List.length(&2, T, xs)` replaces the compat module's
# `List.length(T, xs)` (an import alias `List` would shadow Base's List.*).

type CardZone is Data:
  Hand0{}
  Hand1{}
  Hand2{}
  Hand3{}
  Table{}

type Card is Data:
  Card{identity: Nat, value: Nat, zone: CardZone}

type CardPayload is Data:
  CardPayload{identity: Nat, value: Nat}

type CardEvent is Data:
  MoveCard{selector: Nat, destination: CardZone}

# Algorithm
# =========

# Reassign the token at a zero-based selector.  An out-of-range selector is a
# no-op.  Notice that the algorithm rebuilds the selected token with the same
# identity and value and changes only location.
def reassign_card(selector: Nat, cards: +List<Card>, destination: CardZone) -> +List<Card>:
  match selector cards:
    case 0n Nil{}:
      Nil{}
    case 0n Con{Card{identity, value, zone}, tail}:
      Con{Card{identity, value, destination}, tail}
    case 1n+pred Nil{}:
      Nil{}
    case 1n+pred Con{head, tail}:
      Con{head, reassign_card(pred, tail, destination)}

def apply_event(action: CardEvent, cards: +List<Card>) -> +List<Card>:
  match action:
    case MoveCard{selector, destination}:
      reassign_card(selector, cards, destination)

def play_history(history: +List<CardEvent>, cards: +List<Card>) -> +List<Card>:
  match history:
    case Nil{}:
      cards
    case Con{action, tail}:
      play_history(tail, apply_event(action, cards))

# Semantic specification
# ======================

# Location is the only part of a card that play may change.  Erasing zones
# therefore produces the canonical conservation view.
def card_payload(cards: +List<Card>) -> +List<CardPayload>:
  match cards:
    case Nil{}:
      Nil{}
    case Con{Card{identity, value, zone}, tail}:
      Con{CardPayload{identity, value}, card_payload(tail)}

def payload_value(payload: +List<CardPayload>) -> Nat:
  match payload:
    case Nil{}:
      0n
    case Con{CardPayload{identity, value}, tail}:
      Nat.add(value, payload_value(tail))

def card_count(cards: +List<Card>) -> Nat:
  List.length(&2, CardPayload, card_payload(cards))

def card_value(cards: +List<Card>) -> Nat:
  payload_value(card_payload(cards))

# Helper lemmas
# =============

# Erasing zones also preserves the number of tokens.  This helper connects
# the stronger payload equality to the familiar cardinality observation.
law payload_length_theorem:
  for cards: +List<Card>
  { List.length(&2, CardPayload, card_payload(cards)) == List.length(&2, Card, cards) : Nat }

def payload_length_theorem(cards):
  match cards:
    case Nil{}:
      {==}
    case Con{Card{identity, value, zone}, tail}:
      %payload_length_theorem(tail) : {
        1n+List.length(&2, CardPayload, card_payload(tail)) == 1n+_
        : Nat
      }
      {==}

# THE STEP LEMMA.  It is structural induction on both the selector and the
# arbitrary card state.  The selected case is definitional because only location
# changes.  The recursive case lifts the induction hypothesis through the
# unchanged CardPayload constructor.
law reassign_payload_preservation_theorem:
  for selector: Nat
  for cards: +List<Card>
  for destination: CardZone
  { card_payload(reassign_card(selector, cards, destination)) == card_payload(cards) : +List<CardPayload> }

def reassign_payload_preservation_theorem(selector, cards, destination):
  match selector cards:
    case 0n Nil{}:
      {==}
    case 0n Con{Card{identity, value, zone}, tail}:
      {==}
    case 1n+pred Nil{}:
      {==}
    case 1n+pred Con{Card{identity, value, zone}, tail}:
      Equal.cong(
        +List<CardPayload>,
        +List<CardPayload>,
        rest => Con{CardPayload{identity, value}, rest},
        card_payload(reassign_card(pred, tail, destination)),
        card_payload(tail),
        reassign_payload_preservation_theorem(pred, tail, destination)
      )

# Package the step lemma for the public action type.  Keeping this separate is
# important: adding a new action constructor forces an explicit proof here.
law action_payload_preservation_theorem:
  for action: CardEvent
  for cards: +List<Card>
  { card_payload(apply_event(action, cards)) == card_payload(cards) : +List<CardPayload> }

def action_payload_preservation_theorem(action, cards):
  match action:
    case MoveCard{selector, destination}:
      reassign_payload_preservation_theorem(selector, cards, destination)

# Congruence in both inputs of the transition function.  The history proof no
# longer needs it (it shares one `+` value instead of two replicas), but it is
# kept as a public transport law about the transition function.
law apply_event_congruence:
  for -left_action: CardEvent
  for -right_action: CardEvent
  for -left_cards: +List<Card>
  for -right_cards: +List<Card>
  for action_exact: {left_action == right_action : CardEvent}
  for cards_exact: {left_cards == right_cards : +List<Card>}
  { apply_event(left_action, left_cards) == apply_event(right_action, right_cards) : +List<Card> }

def apply_event_congruence(left_action, right_action, left_cards, right_cards, action_exact, cards_exact):
  Equal.trans(
    +List<Card>,
    apply_event(left_action, left_cards),
    apply_event(right_action, left_cards),
    apply_event(right_action, right_cards),
    Equal.cong(
      CardEvent,
      +List<Card>,
      action => apply_event(action, left_cards),
      left_action,
      right_action,
      action_exact
    ),
    Equal.cong(
      +List<Card>,
      +List<Card>,
      state => apply_event(right_action, state),
      left_cards,
      right_cards,
      cards_exact
    )
  )

# THE SUMMIT.  Every finite settlement history preserves the entire ordered
# identity/value payload.  The induction step composes preservation of the
# tail history (the induction hypothesis, at the state after the first event)
# with preservation of its first event (the step lemma).
law history_payload_conservation_theorem:
  for history: +List<CardEvent>
  for +cards: +List<Card>
  { card_payload(play_history(history, cards)) == card_payload(cards) : +List<CardPayload> }

def history_payload_conservation_theorem(history, cards):
  match history:
    case Nil{}:
      {==}
    case Con{+action, tail}:
      Equal.trans(
        +List<CardPayload>,
        card_payload(play_history(tail, apply_event(action, cards))),
        card_payload(apply_event(action, cards)),
        card_payload(cards),
        history_payload_conservation_theorem(tail, apply_event(action, cards)),
        action_payload_preservation_theorem(action, cards)
      )

# Observable corollary 1: no arbitrary sequence of deals, plays, and trick
# collections can mint or destroy a card token.
law history_card_count_conservation_theorem:
  for history: +List<CardEvent>
  for +cards: +List<Card>
  { card_count(play_history(history, cards)) == card_count(cards) : Nat }

def history_card_count_conservation_theorem(history, cards):
  Equal.cong(
    +List<CardPayload>,
    Nat,
    payload => List.length(&2, CardPayload, payload),
    card_payload(play_history(history, cards)),
    card_payload(cards),
    history_payload_conservation_theorem(history, cards)
  )

# Observable corollary 2: because each surviving token retains its value, the
# total printed point value represented by the card state is conserved as well.
law history_card_value_conservation_theorem:
  for history: +List<CardEvent>
  for +cards: +List<Card>
  { card_value(play_history(history, cards)) == card_value(cards) : Nat }

def history_card_value_conservation_theorem(history, cards):
  Equal.cong(
    +List<CardPayload>,
    Nat,
    payload_value,
    card_payload(play_history(history, cards)),
    card_payload(cards),
    history_payload_conservation_theorem(history, cards)
  )

# Named public propositions make the theorem boundary visible to importers.
def BelotePayloadConservationClaim() -> Type:
  @history: +List<CardEvent> -> @+cards: +List<Card> -> {
    card_payload(play_history(history, cards)) == card_payload(cards)
    : +List<CardPayload>
  }

def BeloteCardCountConservationClaim() -> Type:
  @history: +List<CardEvent> -> @+cards: +List<Card> -> {
    card_count(play_history(history, cards)) == card_count(cards)
    : Nat
  }

def BeloteCardPointConservationClaim() -> Type:
  @history: +List<CardEvent> -> @+cards: +List<Card> -> {
    card_value(play_history(history, cards)) == card_value(cards)
    : Nat
  }
