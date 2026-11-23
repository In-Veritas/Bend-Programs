import Base

def f(n: Nat, xs: List<U32>) -> U32:
  match n xs:
    case 0n _:
      0
    case _ []:
      1
    case 1n+k x <> rest:
      x

def main() -> U32:
  f(1n, [7])
