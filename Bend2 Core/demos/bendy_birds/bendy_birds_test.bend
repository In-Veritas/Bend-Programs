import ./bendy_birds_verification.bend as Verification

# Types
# =====

type BendyBirdsAudit:
  BendyBirdsAudit{-verification: Verification.BendyBirdsVerification, result: Bool}

# Constants
# =========

# BendyBirdsAudit-Section
# =======================

assert bendy_birds_audit_result:
  forall value: BendyBirdsAudit
  Bool

def bendy_birds_audit_result(value):
  match value:
    case BendyBirdsAudit{verification, result}:
      result

# Func-Section
# ============

assert main_value:
  Bool

def main_value():
  bendy_birds_audit_result(BendyBirdsAudit{Verification.bendy_birds_verification_func(), Verification.bendy_birds_verification_self_check_func()})

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
