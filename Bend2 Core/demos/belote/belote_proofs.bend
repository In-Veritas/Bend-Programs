import Base
import ../../compat/list.bend as List

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

type CardZone:
  Hand0{}
  Hand1{}
  Hand2{}
  Hand3{}
  Table{}

type Card:
  Card{identity: Nat, value: Nat, zone: CardZone}

type CardPayload:
  CardPayload{identity: Nat, value: Nat}

type CardEvent:
  MoveCard{selector: Nat, destination: CardZone}

# Algorithm
# =========

# Reassign the token at a zero-based selector.  An out-of-range selector is a
# no-op.  Notice that the algorithm rebuilds the selected token with the same
# identity and value and changes only location.
assert reassign_card:
  forall selector: Nat
  forall cards: List<Card>
  forall destination: CardZone
  List<Card>

def reassign_card(selector, cards, destination):
  match selector:
    case 0n:
      match cards:
        case Nil{}:
          Nil{}
        case Con{Card{identity, value, zone}, tail}:
          Con{Card{identity, value, destination}, tail}
    case 1n+pred:
      match cards:
        case Nil{}:
          Nil{}
        case Con{head, tail}:
          Con{head, reassign_card(pred, tail, destination)}

assert apply_event:
  forall action: CardEvent
  forall cards: List<Card>
  List<Card>

def apply_event(action, cards):
  match action:
    case MoveCard{selector, destination}:
      reassign_card(selector, cards, destination)

assert play_history:
  forall history: List<CardEvent>
  forall cards: List<Card>
  List<Card>

def play_history(history, cards):
  match history:
    case Nil{}:
      cards
    case Con{action, tail}:
      play_history(tail, apply_event(action, cards))

# Semantic specification
# ======================

# Location is the only part of a card that play may change.  Erasing zones
# therefore produces the canonical conservation view.
assert card_payload:
  forall cards: List<Card>
  List<CardPayload>

def card_payload(cards):
  match cards:
    case Nil{}:
      Nil{}
    case Con{Card{identity, value, zone}, tail}:
      Con{CardPayload{identity, value}, card_payload(tail)}

assert payload_value:
  forall payload: List<CardPayload>
  Nat

def payload_value(payload):
  match payload:
    case Nil{}:
      0n
    case Con{CardPayload{identity, value}, tail}:
      Nat.add(value, payload_value(tail))

assert card_count:
  forall cards: List<Card>
  Nat

def card_count(cards):
  List.length(CardPayload, card_payload(cards))

assert card_value:
  forall cards: List<Card>
  Nat

def card_value(cards):
  payload_value(card_payload(cards))

# Helper lemmas
# =============

# Affine Core has no implicit contraction.  The history induction needs one
# card-state replica for the recursive history and one for the first-step lemma,
# so these copiers construct both replicas and proofs relating them to the
# consumed source.  This cost is explicit data work even though the equality
# witnesses themselves erase.
assert card_zone_copy:
  forall zone: CardZone
  Copy(CardZone, zone) & Copy(CardZone, zone)

def card_zone_copy(zone):
  match zone:
    case Hand0{}:
      ((Hand0{}, {==}), (Hand0{}, {==}))
    case Hand1{}:
      ((Hand1{}, {==}), (Hand1{}, {==}))
    case Hand2{}:
      ((Hand2{}, {==}), (Hand2{}, {==}))
    case Hand3{}:
      ((Hand3{}, {==}), (Hand3{}, {==}))
    case Table{}:
      ((Table{}, {==}), (Table{}, {==}))

assert card_replica_exact:
  forall -identity: Nat
  forall -value: Nat
  forall -zone: CardZone
  forall -replica_identity: Nat
  forall -replica_value: Nat
  forall -replica_zone: CardZone
  forall identity_exact: {identity == replica_identity : Nat}
  forall value_exact: {value == replica_value : Nat}
  forall zone_exact: {zone == replica_zone : CardZone}
  { Card{identity, value, zone} == Card{replica_identity, replica_value, replica_zone} : Card }

def card_replica_exact(identity, value, zone, replica_identity, replica_value, replica_zone, identity_exact, value_exact, zone_exact):
  %identity_exact : {
    Card{identity, value, zone} == Card{_, replica_value, replica_zone}
    : Card
  }
  %value_exact : {
    Card{identity, value, zone} == Card{identity, _, replica_zone}
    : Card
  }
  %zone_exact : {
    Card{identity, value, zone} == Card{identity, value, _}
    : Card
  }
  {==}

assert card_copy_side:
  forall -identity: Nat
  forall -value: Nat
  forall -zone: CardZone
  forall replica_identity: Nat
  forall replica_value: Nat
  forall replica_zone: CardZone
  forall identity_exact: {identity == replica_identity : Nat}
  forall value_exact: {value == replica_value : Nat}
  forall zone_exact: {zone == replica_zone : CardZone}
  Copy(Card, Card{identity, value, zone})

def card_copy_side(identity, value, zone, replica_identity, replica_value, replica_zone, identity_exact, value_exact, zone_exact):
  (
    Card{replica_identity, replica_value, replica_zone},
    card_replica_exact(
      identity,
      value,
      zone,
      replica_identity,
      replica_value,
      replica_zone,
      identity_exact,
      value_exact,
      zone_exact
    )
  )

assert card_copy:
  forall card: Card
  Copy(Card, card) & Copy(Card, card)

def card_copy(card):
  match card:
    case Card{identity, value, zone}:
      ((i0, ei0), (i1, ei1)) = Nat.copy(identity)
      ((v0, ev0), (v1, ev1)) = Nat.copy(value)
      ((o0, eo0), (o1, eo1)) = card_zone_copy(zone)
      (
        card_copy_side(identity, value, zone, i0, v0, o0, ei0, ev0, eo0),
        card_copy_side(identity, value, zone, i1, v1, o1, ei1, ev1, eo1)
      )

assert card_list_replica_exact:
  forall -head: Card
  forall -tail: List<Card>
  forall -replica_head: Card
  forall -replica_tail: List<Card>
  forall head_exact: {head == replica_head : Card}
  forall tail_exact: {tail == replica_tail : List<Card>}
  {Con{head, tail} == Con{replica_head, replica_tail} : List<Card>}

def card_list_replica_exact(head, tail, replica_head, replica_tail, head_exact, tail_exact):
  %head_exact : {Con{head, tail} == Con{_, replica_tail} : List<Card>}
  %tail_exact : {Con{head, tail} == Con{head, _} : List<Card>}
  {==}

assert card_list_copy_side:
  forall -head: Card
  forall -tail: List<Card>
  forall replica_head: Card
  forall replica_tail: List<Card>
  forall head_exact: {head == replica_head : Card}
  forall tail_exact: {tail == replica_tail : List<Card>}
  Copy(List<Card>, Con{head, tail})

def card_list_copy_side(head, tail, replica_head, replica_tail, head_exact, tail_exact):
  (
    Con{replica_head, replica_tail},
    card_list_replica_exact(
      head,
      tail,
      replica_head,
      replica_tail,
      head_exact,
      tail_exact
    )
  )

assert card_list_copy:
  forall cards: List<Card>
  Copy(List<Card>, cards) & Copy(List<Card>, cards)

def card_list_copy(cards):
  match cards:
    case Nil{}:
      ((Nil{}, {==}), (Nil{}, {==}))
    case Con{head, tail}:
      ((h0, eh0), (h1, eh1)) = card_copy(head)
      ((t0, et0), (t1, et1)) = card_list_copy(tail)
      (
        card_list_copy_side(head, tail, h0, t0, eh0, et0),
        card_list_copy_side(head, tail, h1, t1, eh1, et1)
      )

assert card_event_replica_exact:
  forall -selector: Nat
  forall -destination: CardZone
  forall -replica_selector: Nat
  forall -replica_destination: CardZone
  forall selector_exact: {selector == replica_selector : Nat}
  forall destination_exact: {destination == replica_destination : CardZone}
  { MoveCard{selector, destination} == MoveCard{replica_selector, replica_destination} : CardEvent }

def card_event_replica_exact(selector, destination, replica_selector, replica_destination, selector_exact, destination_exact):
  %selector_exact : {
    MoveCard{selector, destination} == MoveCard{_, replica_destination}
    : CardEvent
  }
  %destination_exact : {
    MoveCard{selector, destination} == MoveCard{selector, _}
    : CardEvent
  }
  {==}

assert card_event_copy_side:
  forall -selector: Nat
  forall -destination: CardZone
  forall replica_selector: Nat
  forall replica_destination: CardZone
  forall selector_exact: {selector == replica_selector : Nat}
  forall destination_exact: {destination == replica_destination : CardZone}
  Copy(CardEvent, MoveCard{selector, destination})

def card_event_copy_side(selector, destination, replica_selector, replica_destination, selector_exact, destination_exact):
  (
    MoveCard{replica_selector, replica_destination},
    card_event_replica_exact(
      selector,
      destination,
      replica_selector,
      replica_destination,
      selector_exact,
      destination_exact
    )
  )

assert card_event_copy:
  forall action: CardEvent
  Copy(CardEvent, action) & Copy(CardEvent, action)

def card_event_copy(action):
  match action:
    case MoveCard{selector, destination}:
      ((s0, es0), (s1, es1)) = Nat.copy(selector)
      ((d0, ed0), (d1, ed1)) = card_zone_copy(destination)
      (
        card_event_copy_side(selector, destination, s0, d0, es0, ed0),
        card_event_copy_side(selector, destination, s1, d1, es1, ed1)
      )

# Erasing zones also preserves the number of tokens.  This helper connects
# the stronger payload equality to the familiar cardinality observation.
assert payload_length_theorem:
  forall cards: List<Card>
  { List.length(CardPayload, card_payload(cards)) == List.length(Card, cards) : Nat }

def payload_length_theorem(cards):
  match cards:
    case Nil{}:
      {==}
    case Con{Card{identity, value, zone}, tail}:
      %payload_length_theorem(tail) : {
        1n+List.length(CardPayload, card_payload(tail)) == 1n+_
        : Nat
      }
      {==}

# THE STEP LEMMA.  It is structural induction on both the selector and the
# arbitrary card state.  The selected case is definitional because only location
# changes.  The recursive case lifts the induction hypothesis through the
# unchanged CardPayload constructor.
assert reassign_payload_preservation_theorem:
  forall selector: Nat
  forall cards: List<Card>
  forall destination: CardZone
  { card_payload(reassign_card(selector, cards, destination)) == card_payload(cards) : List<CardPayload> }

def reassign_payload_preservation_theorem(selector, cards, destination):
  match selector:
    case 0n:
      match cards:
        case Nil{}:
          {==}
        case Con{Card{identity, value, zone}, tail}:
          {==}
    case 1n+pred:
      match cards:
        case Nil{}:
          {==}
        case Con{Card{identity, value, zone}, tail}:
          Equal.cong(
            List<CardPayload>,
            List<CardPayload>,
            rest => Con{CardPayload{identity, value}, rest},
            card_payload(reassign_card(pred, tail, destination)),
            card_payload(tail),
            reassign_payload_preservation_theorem(pred, tail, destination)
          )

# Package the step lemma for the public action type.  Keeping this separate is
# important: adding a new action constructor forces an explicit proof here.
assert action_payload_preservation_theorem:
  forall action: CardEvent
  forall cards: List<Card>
  { card_payload(apply_event(action, cards)) == card_payload(cards) : List<CardPayload> }

def action_payload_preservation_theorem(action, cards):
  match action:
    case MoveCard{selector, destination}:
      reassign_payload_preservation_theorem(selector, cards, destination)

# Congruence in both inputs of the transition function.  This small transport
# lemma lets the affine history proof execute two explicit replicas while its
# proposition continues to speak about the original event and card state.
assert apply_event_congruence:
  forall -left_action: CardEvent
  forall -right_action: CardEvent
  forall -left_cards: List<Card>
  forall -right_cards: List<Card>
  forall action_exact: {left_action == right_action : CardEvent}
  forall cards_exact: {left_cards == right_cards : List<Card>}
  { apply_event(left_action, left_cards) == apply_event(right_action, right_cards) : List<Card> }

def apply_event_congruence(left_action, right_action, left_cards, right_cards, action_exact, cards_exact):
  Equal.trans(
    List<Card>,
    apply_event(left_action, left_cards),
    apply_event(right_action, left_cards),
    apply_event(right_action, right_cards),
    Equal.cong(
      CardEvent,
      List<Card>,
      action => apply_event(action, left_cards),
      left_action,
      right_action,
      action_exact
    ),
    Equal.cong(
      List<Card>,
      List<Card>,
      state => apply_event(right_action, state),
      left_cards,
      right_cards,
      cards_exact
    )
  )

# THE SUMMIT.  Every finite settlement history preserves the entire ordered
# identity/value payload.  The induction step composes preservation of the
# tail history with preservation of its first action.
assert history_payload_conservation_theorem:
  forall history: List<CardEvent>
  forall cards: List<Card>
  { card_payload(play_history(history, cards)) == card_payload(cards) : List<CardPayload> }

def history_payload_conservation_theorem(history, cards):
  match history:
    case Nil{}:
      {==}
    case Con{action, tail}:
      ((history_action, history_action_exact), (step_action, step_action_exact)) = card_event_copy(action)
      ((history_cards, history_cards_exact), (step_cards, step_cards_exact)) = card_list_copy(cards)
      ((history_action_exact0, history_action_exact0_copy), (history_action_exact1, history_action_exact1_copy)) = Equal.copy(
        CardEvent,
        action,
        history_action,
        history_action_exact
      )
      ((history_cards_exact0, history_cards_exact0_copy), (history_cards_exact1, history_cards_exact1_copy)) = Equal.copy(
        List<Card>,
        cards,
        history_cards,
        history_cards_exact
      )
      ((step_cards_exact0, step_cards_exact0_copy), (step_cards_exact1, step_cards_exact1_copy)) = Equal.copy(
        List<Card>,
        cards,
        step_cards,
        step_cards_exact
      )
      original_to_history = apply_event_congruence(
        action,
        history_action,
        cards,
        history_cards,
        history_action_exact0,
        history_cards_exact0
      )
      history_to_step = apply_event_congruence(
        history_action,
        step_action,
        history_cards,
        step_cards,
        Equal.trans(
          CardEvent,
          history_action,
          action,
          step_action,
          Equal.sym(
            CardEvent,
            action,
            history_action,
            history_action_exact1
          ),
          step_action_exact
        ),
        Equal.trans(
          List<Card>,
          history_cards,
          cards,
          step_cards,
          Equal.sym(
            List<Card>,
            cards,
            history_cards,
            history_cards_exact1
          ),
          step_cards_exact0
        )
      )
      Equal.trans(
        List<CardPayload>,
        card_payload(play_history(tail, apply_event(action, cards))),
        card_payload(play_history(tail, apply_event(history_action, history_cards))),
        card_payload(cards),
        Equal.cong(
          List<Card>,
          List<CardPayload>,
          next => card_payload(play_history(tail, next)),
          apply_event(action, cards),
          apply_event(history_action, history_cards),
          original_to_history
        ),
        Equal.trans(
          List<CardPayload>,
          card_payload(play_history(tail, apply_event(history_action, history_cards))),
          card_payload(apply_event(history_action, history_cards)),
          card_payload(cards),
          history_payload_conservation_theorem(
            tail,
            apply_event(history_action, history_cards)
          ),
          Equal.trans(
            List<CardPayload>,
            card_payload(apply_event(history_action, history_cards)),
            card_payload(apply_event(step_action, step_cards)),
            card_payload(cards),
            Equal.cong(
              List<Card>,
              List<CardPayload>,
              card_payload,
              apply_event(history_action, history_cards),
              apply_event(step_action, step_cards),
              history_to_step
            ),
            Equal.trans(
              List<CardPayload>,
              card_payload(apply_event(step_action, step_cards)),
              card_payload(step_cards),
              card_payload(cards),
              action_payload_preservation_theorem(step_action, step_cards),
              Equal.cong(
                List<Card>,
                List<CardPayload>,
                card_payload,
                step_cards,
                cards,
                Equal.sym(
                  List<Card>,
                  cards,
                  step_cards,
                  step_cards_exact1
                )
              )
            )
          )
        )
      )

# Observable corollary 1: no arbitrary sequence of deals, plays, and trick
# collections can mint or destroy a card token.
assert history_card_count_conservation_theorem:
  forall history: List<CardEvent>
  forall cards: List<Card>
  { card_count(play_history(history, cards)) == card_count(cards) : Nat }

def history_card_count_conservation_theorem(history, cards):
  Equal.cong(
    List<CardPayload>,
    Nat,
    payload => List.length(CardPayload, payload),
    card_payload(play_history(history, cards)),
    card_payload(cards),
    history_payload_conservation_theorem(history, cards)
  )

# Observable corollary 2: because each surviving token retains its value, the
# total printed point value represented by the card state is conserved as well.
assert history_card_value_conservation_theorem:
  forall history: List<CardEvent>
  forall cards: List<Card>
  { card_value(play_history(history, cards)) == card_value(cards) : Nat }

def history_card_value_conservation_theorem(history, cards):
  Equal.cong(
    List<CardPayload>,
    Nat,
    payload_value,
    card_payload(play_history(history, cards)),
    card_payload(cards),
    history_payload_conservation_theorem(history, cards)
  )

# Named public propositions make the theorem boundary visible to importers.
assert BelotePayloadConservationClaim:
  Type

def BelotePayloadConservationClaim():
  @history: List<CardEvent> -> @cards: List<Card> -> {
    card_payload(play_history(history, cards)) == card_payload(cards)
    : List<CardPayload>
  }

assert BeloteCardCountConservationClaim:
  Type

def BeloteCardCountConservationClaim():
  @history: List<CardEvent> -> @cards: List<Card> -> {
    card_count(play_history(history, cards)) == card_count(cards)
    : Nat
  }

assert BeloteCardPointConservationClaim:
  Type

def BeloteCardPointConservationClaim():
  @history: List<CardEvent> -> @cards: List<Card> -> {
    card_value(play_history(history, cards)) == card_value(cards)
    : Nat
  }
