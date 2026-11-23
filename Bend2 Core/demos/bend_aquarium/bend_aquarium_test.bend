import ./bend_aquarium_verification.bend as Verification

# Types
# =====

type BendAquariumAudit:
  BendAquariumAudit{-verification: Verification.BendAquariumVerification, result: Bool}

# Constants
# =========

# BendAquariumAudit-Section
# =========================

assert bend_aquarium_audit_result:
  forall value: BendAquariumAudit
  Bool

def bend_aquarium_audit_result(value):
  match value:
    case BendAquariumAudit{verification, result}:
      result

# Func-Section
# ============

assert main_value:
  Bool

def main_value():
  bend_aquarium_audit_result(BendAquariumAudit{Verification.bend_aquarium_verification_func(), Verification.bend_aquarium_verification_self_check_func()})

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
