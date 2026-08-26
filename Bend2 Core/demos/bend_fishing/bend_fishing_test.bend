import ./bend_fishing_verification.bend as Verification

# Types
# =====

type BendFishingAudit:
  BendFishingAudit{-verification: Verification.BendFishingVerification, result: Bool}

# Constants
# =========

# BendFishingAudit-Section
# ========================

assert bend_fishing_audit_result:
  forall value: BendFishingAudit
  Bool

def bend_fishing_audit_result(value):
  match value:
    case BendFishingAudit{verification, result}:
      result

# Func-Section
# ============

assert main_value:
  Bool

def main_value():
  bend_fishing_audit_result(BendFishingAudit{Verification.bend_fishing_verification_func(), Verification.bend_fishing_verification_self_check_func()})

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
