# Compatibility helpers for Gabriel's demos across the 2026 Bend3 Base split.
# Old Base exposed permissive String/U32 conversions; current Base keeps the
# checked parser on U32. Demo URL parameters preserve the old fallback-to-zero
# behavior explicitly here.

import ../bend-base/Base

def String.from_u32(n: U32) -> String:
  U32.show(n)

def String.to_u32(s: String) -> U32:
  match U32.read(s):
    case Result.Done{n}:
      n
    case Result.Fail{e}:
      0

def String.eq_u32(a: String, b: String) -> U32:
  Bool.to_u32(String.eq(a, b))
