import ./bendio_verification.bend as Verification

# Types
# =====

type BendioAudit:
  BendioAudit{-verification: Verification.BendioVerification, result: Bool}

# Constants
# =========

# BendioAudit-Section
# ===================

assert bendio_audit_result:
  forall value: BendioAudit
  Bool

def bendio_audit_result(value):
  match value:
    case BendioAudit{verification, result}:
      result

# Func-Section
# ============

assert main_value:
  Bool

def main_value():
  bendio_audit_result(BendioAudit{Verification.bendio_verification_func(), Verification.bendio_verification_self_check_func()})

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
