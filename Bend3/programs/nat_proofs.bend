# nat_proofs: refl, rewrite and induction over Nat. add is defined by
# recursion on its first argument, so add(n, 0n) == n is not true by
# computation alone: the proof goes by induction on n, rewriting the step
# case with the induction hypothesis. Base's Nat is used (0n, 1n+k), with
# our own add instead of Nat.add.
#
# $ bend nat_proofs.bend     # prints {==}

# expect: {==}

import Base

def add(n: Nat, m: Nat) -> Nat:
  match n:
    case 0n:
      m
    case 1n+k:
      1n+add(k, m)

# LAW: zero is a right identity of add
law add_n_Z:
  for n: Nat
  {add(n, 0n) == n : Nat}

# n is LONE here - no sharing at all
def add_n_Z(n):
  match n:
    case 0n:
      {==}
    case 1n+k:
      %add_n_Z(k) : {1n+add(k, 0n) == 1n+_ : Nat}
      {==}

def main() -> {add(1n, 0n) == 1n : Nat}:
  add_n_Z(1n)
