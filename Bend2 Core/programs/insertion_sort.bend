import Base
# Insertion sort with explicit U32 copies at the comparison/rebuild boundary.

def insert(xs: List<U32>, n: U32) -> List<U32>:
  match xs:
    case Nil{}:
      Con{n, Nil{}}
    case Con{h, t}:
      ((n1, en1), (n2, en2)) = U32.copy(n)
      ((h1, eh1), (h2, eh2)) = U32.copy(h)
      match U32.is_le(n1, h1):
        case True{}:
          Con{n2, Con{h2, t}}
        case False{}:
          Con{h2, insert(t, n2)}

def isort(xs: List<U32>) -> List<U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      insert(isort(t), h)

def list_eq(xs: List<U32>, ys: List<U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      match U32.is_eq(x, y):
        case True{}:
          list_eq(xt, yt)
        case False{}:
          False{}
    case xs ys:
      False{}

def input() -> List<U32>:
  Con{U32.from_nat(4n), Con{U32.from_nat(2n), Con{U32.from_nat(7n), Con{U32.one(), Con{U32.from_nat(9n), Con{U32.from_nat(3n), Con{U32.from_nat(8n), Con{U32.from_nat(5n), Con{U32.from_nat(6n), Nil{}}}}}}}}}}

def expected() -> List<U32>:
  Con{U32.one(), Con{U32.from_nat(2n), Con{U32.from_nat(3n), Con{U32.from_nat(4n), Con{U32.from_nat(5n), Con{U32.from_nat(6n), Con{U32.from_nat(7n), Con{U32.from_nat(8n), Con{U32.from_nat(9n), Nil{}}}}}}}}}}

def main() -> Bool:
  list_eq(isort(input()), expected())
