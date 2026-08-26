import ./fluids_verification.bend as Verification

# Types
# =====

type FluidsTestAudit:
  FluidsTestAudit{-verification: Verification.FluidsVerification, result: Bool}

# Constants
# =========

# FluidsTestAudit-Section
# =======================

assert fluids_test_audit_result:
  forall value: FluidsTestAudit
  Bool

def fluids_test_audit_result(value):
  match value:
    case FluidsTestAudit{verification, result}:
      result

# Func-Section
# ============

assert main_value:
  Bool

def main_value():
  fluids_test_audit_result(
    FluidsTestAudit{
      Verification.fluids_verification_func(),
      Verification.fluids_verification_self_check_func()
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
