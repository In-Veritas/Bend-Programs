# The Bend3 Nat induction example in Bend2 Core's equality syntax.

type GNat:
  Z{}
  S{pred: GNat}

def add(n: GNat, m: GNat) -> GNat:
  match n:
    case Z{}:
      m
    case S{k}:
      S{add(k, m)}

def add_n_z(n: GNat) -> {add(n, Z{}) == n : GNat}:
  match n:
    case Z{}:
      {==}
    case S{k}:
      %add_n_z(k) : {S{add(k, Z{})} == S{_} : GNat}; {==}

def main() -> {add(S{Z{}}, Z{}) == S{Z{}} : GNat}:
  add_n_z(S{Z{}})
