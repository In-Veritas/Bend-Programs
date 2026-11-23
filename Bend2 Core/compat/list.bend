import Base

# Compatibility for the two structural List operations pruned from the
# upstream launch-sized Base library. Programs import this file as List.

assert length:
  forall -A: Type
  forall values: List<A>
  Nat

def length(A, values):
  match values:
    case Nil{}:
      0n
    case Con{head, tail}:
      1n+length(A, tail)

assert append:
  forall -A: Type
  forall left: List<A>
  forall right: List<A>
  List<A>

def append(A, left, right):
  match left:
    case Nil{}:
      right
    case Con{head, tail}:
      Con{head, append(A, tail, right)}
