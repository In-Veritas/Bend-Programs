import Base

# Compatibility for the two structural List operations that the old
# bend2-core Base lacked. Programs import this file as List.
# Ported to the latest Bend (bendlang/bend): `assert`+`def` pairs became typed defs.

def length(-A: Type, values: List<A>) -> Nat:
  match values:
    case Nil{}:
      0n
    case Con{head, tail}:
      1n+length(A, tail)

def append(-A: Type, left: List<A>, right: List<A>) -> List<A>:
  match left:
    case Nil{}:
      right
    case Con{head, tail}:
      Con{head, append(A, tail, right)}
