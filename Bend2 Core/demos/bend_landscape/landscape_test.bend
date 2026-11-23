import ./landscape_verification.bend as Verification

type LandscapeAudit:
  LandscapeAudit{-verification: Verification.LandscapeVerification, result: Bool}

assert landscape_audit_result:
  forall value: LandscapeAudit
  Bool

def landscape_audit_result(value):
  match value:
    case LandscapeAudit{verification, result}: result

assert main_value:
  Bool

def main_value():
  landscape_audit_result(LandscapeAudit{Verification.landscape_verification_func(), Verification.landscape_verification_self_check_func()})

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
