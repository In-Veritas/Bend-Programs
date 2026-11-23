# Compatibility helpers for Gabriel's demos, ported to Bend 2.0.40.
# Import it from a demo folder as:
#
#   import ../Compat.bend as Compat
#
# Old Bend3 merged imports into one global book, so the demos called
# these as String.from_u32 / String.to_u32 / String.eq_u32. In Bend
# 2.0.40 an import is a namespace: they are Compat.from_u32,
# Compat.to_u32 and Compat.eq_u32. URL parameters keep the old
# fallback-to-zero parse.
import Base

# U32 -> decimal String (old String.from_u32).
def from_u32(n: U32) -> String:
  U32.show(n)

# Decimal String -> U32, 0 when it does not parse (old String.to_u32).
def to_u32(s: String) -> U32:
  Maybe.default(&2, U32, U32.read(s), 0)

# String equality as 1/0 (old String.eq_u32). New code should prefer
# Compat.eq / String.eq, which answer a Bool to match on.
def eq_u32(a: String, b: String) -> U32:
  Bool.to_u32(String.eq(a, b))

def eq(a: String, b: String) -> Bool:
  String.eq(a, b)

# A Bool as 1/0, and a U32 as a Bool (non-zero is True), for code that
# used U32 as its boolean.
def b2u(b: Bool) -> U32:
  Bool.to_u32(b)

def u2b(n: U32) -> Bool:
  Bool.not(U32.is_zero(n))

# The old String.length answered a U32; Base's answers a Nat.
def length(s: String) -> U32:
  U32.from_nat(String.length(s))

# Old String.flatten(list) is Base's String.concat(list); old
# String.concat(a, b) is a ++ b (String.append).
def flatten(xs: List<&2, String>) -> String:
  String.concat(xs)

def concat(a: String, b: String) -> String:
  a ++ b
