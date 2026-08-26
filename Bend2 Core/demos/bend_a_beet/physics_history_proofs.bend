import Base
import ./physics.bend as Physics

# End-to-end motion-history proofs for Bend-a-Beet
# =================================================
#
# The rendering tip may move under wind, pulling, recovery, or fracture, but a
# physical update must never move the planted root or change which beet is
# being updated.  Fracture is also irreversible in this model.  Both claims are
# proved for arbitrary command histories; the individual command cases are the
# local transition lemma, not the final theorem.

type MotionState:
  Active{}
  Fractured{}

type TrackedBeet:
  TrackedBeet{
    identity: Nat,
    root: Physics.Vec3,
    tip: Physics.Vec3,
    integrity: Nat,
    state: MotionState
  }

type MotionCommand:
  Wind{next_tip: Physics.Vec3}
  Pull{next_tip: Physics.Vec3}
  Recover{next_tip: Physics.Vec3}
  Fracture{next_tip: Physics.Vec3}

type AnchorPayload:
  AnchorPayload{identity: Nat, root: Physics.Vec3}

assert anchor_payload:
  forall body: TrackedBeet
  AnchorPayload

def anchor_payload(body):
  match body:
    case TrackedBeet{identity, root, tip, integrity, state}:
      AnchorPayload{identity, root}

assert motion_state:
  forall body: TrackedBeet
  MotionState

def motion_state(body):
  match body:
    case TrackedBeet{identity, root, tip, integrity, state}:
      state

# A fractured body is absorbing.  Active transitions may update the tip and
# integrity, but the identity and root fields are copied verbatim.
assert apply_motion:
  forall command: MotionCommand
  forall body: TrackedBeet
  TrackedBeet

def apply_motion(command, body):
  match command body:
    case Wind{next_tip} TrackedBeet{identity, root, tip, integrity, Fractured{}}:
      TrackedBeet{identity, root, tip, integrity, Fractured{}}
    case Pull{next_tip} TrackedBeet{identity, root, tip, integrity, Fractured{}}:
      TrackedBeet{identity, root, tip, integrity, Fractured{}}
    case Recover{next_tip} TrackedBeet{identity, root, tip, integrity, Fractured{}}:
      TrackedBeet{identity, root, tip, integrity, Fractured{}}
    case Fracture{next_tip} TrackedBeet{identity, root, tip, integrity, Fractured{}}:
      TrackedBeet{identity, root, tip, integrity, Fractured{}}
    case Wind{next_tip} TrackedBeet{identity, root, tip, integrity, Active{}}:
      TrackedBeet{identity, root, next_tip, integrity, Active{}}
    case Pull{next_tip} TrackedBeet{identity, root, tip, integrity, Active{}}:
      TrackedBeet{identity, root, next_tip, integrity, Active{}}
    case Recover{next_tip} TrackedBeet{identity, root, tip, integrity, Active{}}:
      TrackedBeet{identity, root, next_tip, 1n+integrity, Active{}}
    case Fracture{next_tip} TrackedBeet{identity, root, tip, integrity, Active{}}:
      TrackedBeet{identity, root, next_tip, 0n, Fractured{}}

assert simulate_motion:
  forall history: List<MotionCommand>
  forall body: TrackedBeet
  TrackedBeet

def simulate_motion(history, body):
  match history:
    case Nil{}:
      body
    case Con{command, tail}:
      simulate_motion(tail, apply_motion(command, body))

# Local transition lemma.  Its eight constructor combinations are required to
# cover the transition relation, but the theorem below quantifies over
# histories of unbounded length.
assert motion_step_anchor_theorem:
  forall command: MotionCommand
  forall body: TrackedBeet
  { anchor_payload(apply_motion(command, body)) == anchor_payload(body) : AnchorPayload }

def motion_step_anchor_theorem(command, body):
  match command body:
    case Wind{next_tip} TrackedBeet{identity, root, tip, integrity, Fractured{}}:
      {==}
    case Pull{next_tip} TrackedBeet{identity, root, tip, integrity, Fractured{}}:
      {==}
    case Recover{next_tip} TrackedBeet{identity, root, tip, integrity, Fractured{}}:
      {==}
    case Fracture{next_tip} TrackedBeet{identity, root, tip, integrity, Fractured{}}:
      {==}
    case Wind{next_tip} TrackedBeet{identity, root, tip, integrity, Active{}}:
      {==}
    case Pull{next_tip} TrackedBeet{identity, root, tip, integrity, Active{}}:
      {==}
    case Recover{next_tip} TrackedBeet{identity, root, tip, integrity, Active{}}:
      {==}
    case Fracture{next_tip} TrackedBeet{identity, root, tip, integrity, Active{}}:
      {==}

# THE SUMMIT: arbitrary finite force/pull/recovery/fracture histories preserve
# the beet identity and planted root.  Destructing each head command exposes
# the invariant-preserving transition, and the induction hypothesis covers the
# unbounded suffix.
assert motion_history_anchor_theorem:
  forall history: List<MotionCommand>
  forall body: TrackedBeet
  { anchor_payload(simulate_motion(history, body)) == anchor_payload(body) : AnchorPayload }

def motion_history_anchor_theorem(history, body):
  match history body:
    case Nil{} TrackedBeet{identity, root, tip, integrity, state}:
      {==}
    case Con{Wind{next_tip}, tail} TrackedBeet{identity, root, tip, integrity, Active{}}:
      motion_history_anchor_theorem(
        tail,
        TrackedBeet{identity, root, next_tip, integrity, Active{}}
      )
    case Con{Wind{next_tip}, tail} TrackedBeet{identity, root, tip, integrity, Fractured{}}:
      motion_history_anchor_theorem(
        tail,
        TrackedBeet{identity, root, tip, integrity, Fractured{}}
      )
    case Con{Pull{next_tip}, tail} TrackedBeet{identity, root, tip, integrity, Active{}}:
      motion_history_anchor_theorem(
        tail,
        TrackedBeet{identity, root, next_tip, integrity, Active{}}
      )
    case Con{Pull{next_tip}, tail} TrackedBeet{identity, root, tip, integrity, Fractured{}}:
      motion_history_anchor_theorem(
        tail,
        TrackedBeet{identity, root, tip, integrity, Fractured{}}
      )
    case Con{Recover{next_tip}, tail} TrackedBeet{identity, root, tip, integrity, Active{}}:
      motion_history_anchor_theorem(
        tail,
        TrackedBeet{identity, root, next_tip, 1n+integrity, Active{}}
      )
    case Con{Recover{next_tip}, tail} TrackedBeet{identity, root, tip, integrity, Fractured{}}:
      motion_history_anchor_theorem(
        tail,
        TrackedBeet{identity, root, tip, integrity, Fractured{}}
      )
    case Con{Fracture{next_tip}, tail} TrackedBeet{identity, root, tip, integrity, Active{}}:
      motion_history_anchor_theorem(
        tail,
        TrackedBeet{identity, root, next_tip, 0n, Fractured{}}
      )
    case Con{Fracture{next_tip}, tail} TrackedBeet{identity, root, tip, integrity, Fractured{}}:
      motion_history_anchor_theorem(
        tail,
        TrackedBeet{identity, root, tip, integrity, Fractured{}}
      )

# Second semantic theorem: after fracture, no future motion command can return
# the body to Active.  The canonical lemma is induction over an arbitrary
# history; the transport wrapper below accepts an equality witness for callers
# that hold the same state under an abstract name.
assert fractured_history_absorbing_canonical_theorem:
  forall history: List<MotionCommand>
  forall identity: Nat
  forall root: Physics.Vec3
  forall tip: Physics.Vec3
  forall integrity: Nat
  { motion_state( simulate_motion( history, TrackedBeet{identity, root, tip, integrity, Fractured{}} ) ) == Fractured{} : MotionState }

def fractured_history_absorbing_canonical_theorem(history, identity, root, tip, integrity):
  match history:
    case Nil{}:
      {==}
    case Con{Wind{next_tip}, tail}:
      fractured_history_absorbing_canonical_theorem(
        tail,
        identity,
        root,
        tip,
        integrity
      )
    case Con{Pull{next_tip}, tail}:
      fractured_history_absorbing_canonical_theorem(
        tail,
        identity,
        root,
        tip,
        integrity
      )
    case Con{Recover{next_tip}, tail}:
      fractured_history_absorbing_canonical_theorem(
        tail,
        identity,
        root,
        tip,
        integrity
      )
    case Con{Fracture{next_tip}, tail}:
      fractured_history_absorbing_canonical_theorem(
        tail,
        identity,
        root,
        tip,
        integrity
      )

assert fractured_history_absorbing_theorem:
  forall body: TrackedBeet
  forall history: List<MotionCommand>
  forall identity: Nat
  forall root: Physics.Vec3
  forall tip: Physics.Vec3
  forall integrity: Nat
  forall initial: { body == TrackedBeet{identity, root, tip, integrity, Fractured{}} : TrackedBeet }
  {motion_state(simulate_motion(history, body)) == Fractured{} : MotionState}

def fractured_history_absorbing_theorem(body, history, identity, root, tip, integrity, initial):
  %Equal.sym(
    TrackedBeet,
    body,
    TrackedBeet{identity, root, tip, integrity, Fractured{}},
    initial
  ) : {
    motion_state(simulate_motion(history, _)) == Fractured{}
    : MotionState
  }
  fractured_history_absorbing_canonical_theorem(
    history,
    identity,
    root,
    tip,
    integrity
  )

assert MotionHistoryAnchorClaim:
  Type

def MotionHistoryAnchorClaim():
  @history: List<MotionCommand> -> @body: TrackedBeet -> {
    anchor_payload(simulate_motion(history, body)) == anchor_payload(body)
    : AnchorPayload
  }

assert FracturedHistoryAbsorbingClaim:
  Type

def FracturedHistoryAbsorbingClaim():
  @history: List<MotionCommand> ->
  @identity: Nat ->
  @root: Physics.Vec3 ->
  @tip: Physics.Vec3 ->
  @integrity: Nat -> {
    motion_state(
      simulate_motion(
        history,
        TrackedBeet{identity, root, tip, integrity, Fractured{}}
      )
    ) == Fractured{}
    : MotionState
  }

assert fractured_history_absorbing_claim_theorem:
  forall history: List<MotionCommand>
  forall identity: Nat
  forall root: Physics.Vec3
  forall tip: Physics.Vec3
  forall integrity: Nat
  { motion_state( simulate_motion( history, TrackedBeet{identity, root, tip, integrity, Fractured{}} ) ) == Fractured{} : MotionState }

def fractured_history_absorbing_claim_theorem(history, identity, root, tip, integrity):
  fractured_history_absorbing_canonical_theorem(
    history,
    identity,
    root,
    tip,
    integrity
  )
