import ./physics_verification.bend as Verification

# Types
# =====

type TestAudit:
  TestAudit{
    -verification: Verification.PhysicsVerification,
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

assert main_value:
  Bool

def main_value():
  test_audit_result(
    TestAudit{
      Verification.physics_verification_func(),
      Verification.physics_self_check_func()
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
