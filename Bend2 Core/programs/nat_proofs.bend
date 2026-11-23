import Base
# The Bend3 Nat induction example, as Bend laws over a hand-rolled unary
# GNat. Each `law` states a claim for every input; the `def` of the same name
# proves it by case analysis (refl), the recursive call (the induction
# hypothesis), and `%e : P` rewrites. `bend nat_proofs.bend` prints ALL
# PROOFS CHECK only when every law holds; main then instantiates add_n_z.

type GNat is Data:
  Z{}
  S{pred: GNat}

def add(n: GNat, m: GNat) -> GNat:
  match n:
    case Z{}:
      m
    case S{k}:
      S{add(k, m)}

# LAW: zero is a right identity
law add_n_z:
  for n: GNat
  {add(n, Z{}) == n : GNat}

def add_n_z(n):
  match n:
    case Z{}:
      {==}
    case S{k}:
      %add_n_z(k) : {S{add(k, Z{})} == S{_} : GNat}
      {==}

# LAW: a successor on the right can be pulled out
law add_n_s:
  for n: GNat
  for m: GNat
  {add(n, S{m}) == S{add(n, m)} : GNat}

def add_n_s(n, m):
  match n:
    case Z{}:
      {==}
    case S{k}:
      %add_n_s(k, m) : {S{add(k, S{m})} == S{_} : GNat}
      {==}

# LAW: addition is associative
law add_assoc:
  for a: GNat
  for b: GNat
  for c: GNat
  {add(add(a, b), c) == add(a, add(b, c)) : GNat}

def add_assoc(a, b, c):
  match a:
    case Z{}:
      {==}
    case S{k}:
      %add_assoc(k, b, c) : {S{add(add(k, b), c)} == S{_} : GNat}
      {==}

# LAW: addition is commutative (induction on n, using the two lemmas above)
law add_comm:
  for +n: GNat
  for +m: GNat
  {add(n, m) == add(m, n) : GNat}

def add_comm(n, m):
  match n:
    case Z{}:
      Equal.sym(GNat, add(m, Z{}), m, add_n_z(m))
    case S{k}:
      %Equal.sym(GNat, add(m, S{k}), S{add(m, k)}, add_n_s(m, k)) : {S{add(k, m)} == _ : GNat}
      %add_comm(k, m) : {S{add(k, m)} == S{_} : GNat}
      {==}

def main() -> {add(S{Z{}}, Z{}) == S{Z{}} : GNat}:
  add_n_z(S{Z{}})
