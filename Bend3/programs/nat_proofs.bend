type Nat:
  Z{}
  S{p: Nat}

def add(n: Nat, m: Nat) -> Nat:
  match n:
    case Nat.Z{}:
      m
    case Nat.S{k}:
      Nat.S{add(k, m)}

# n is LONE here - no sharing at all. Does it check?
def add_n_Z(n: Nat) -> {add(n, Nat.Z{}) == n : Nat}:
  match n:
    case Nat.Z{}:
      {==}
    case Nat.S{k}:
      %add_n_Z(k); {==}

def main() -> {add(Nat.S{Nat.Z{}}, Nat.Z{}) == Nat.S{Nat.Z{}} : Nat}:
  add_n_Z(Nat.S{Nat.Z{}})
