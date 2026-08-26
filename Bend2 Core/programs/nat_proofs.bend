import Base
# The Bend3 Nat induction example in Bend2 Core's equality syntax.

type GNat:
  Z{}
  S{pred: GNat}

assert add:
  forall n: GNat
  forall m: GNat
  GNat

def add(n, m):
  match n:
    case Z{}:
      m
    case S{k}:
      S{add(k, m)}

assert add_n_z:
  forall n: GNat
  {add(n, Z{}) == n : GNat}

def add_n_z(n):
  match n:
    case Z{}:
      {==}
    case S{k}:
      %add_n_z(k) : {S{add(k, Z{})} == S{_} : GNat}; {==}

assert main_value:
  {add(S{Z{}}, Z{}) == S{Z{}} : GNat}

def main_value():
  add_n_z(S{Z{}})

assert main_accept_proof:
  forall -value: {add(S{Z{}}, Z{}) == S{Z{}} : GNat}
  IO(Unit)

def main_accept_proof(value):
  IO.print("-")

assert main:
  IO(Unit)

def main():
  main_accept_proof(main_value())
