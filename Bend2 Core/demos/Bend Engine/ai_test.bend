import Base
import ./ai.bend as AI
import ./ai_verification.bend as Verification

# Focused generated-backend entry for Bend Engine AI.  The three closed checks
# below are certificates/examples only; mathematical claims are supplied by
# the erased universally quantified verification audit.

# Types
# =====

type TestAudit:
  TestAudit{
    -verification: Verification.VerificationAudit,
    result: Bool
  }

# Constants
# =========

# TestAudit-Section
# =================

assert test_audit_result:
  forall value: TestAudit
  Bool

def test_audit_result(value):
  match value:
    case TestAudit{verification, result}:
      result

# Func-Section
# ============

assert gather_certificate_func:
  Bool

def gather_certificate_func():
  match AI.planner_decide_func(
    AI.GatherGoal{},
    AI.Observation{False{}, True{}, False{}, False{}}
  ):
    case AI.WaitDecision{observation}:
      False{}
    case AI.PatrolDecision{observation}:
      False{}
    case AI.GatherDecision{enemy_visible, danger}:
      True{}
    case AI.WoundedFleeDecision{enemy_visible, resource_visible, danger}:
      False{}
    case AI.DangerFleeDecision{enemy_visible, resource_visible}:
      False{}
    case AI.EngageDecision{resource_visible, danger}:
      False{}

assert danger_priority_certificate_func:
  Bool

def danger_priority_certificate_func():
  match AI.planner_decide_func(
    AI.GuardGoal{},
    AI.Observation{True{}, True{}, False{}, True{}}
  ):
    case AI.WaitDecision{observation}:
      False{}
    case AI.PatrolDecision{observation}:
      False{}
    case AI.GatherDecision{enemy_visible, danger}:
      False{}
    case AI.WoundedFleeDecision{enemy_visible, resource_visible, danger}:
      False{}
    case AI.DangerFleeDecision{enemy_visible, resource_visible}:
      True{}
    case AI.EngageDecision{resource_visible, danger}:
      False{}

assert history_certificate_func:
  Bool

def history_certificate_func():
  AI.ai_reference_check_func()

assert main_value:
  Bool

def main_value():
  test_audit_result(
    TestAudit{
      Verification.verification_audit_func(),
      Bool.and(
        Verification.ai_semantic_verification_func(),
        Bool.and(
          gather_certificate_func(),
          Bool.and(
            danger_priority_certificate_func(),
            history_certificate_func()
          )
        )
      )
    }
  )

assert main_show_bool:
  forall value: Bool
  IO(Unit)

def main_show_bool(value):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

assert main:
  IO(Unit)

def main():
  main_show_bool(main_value!())
