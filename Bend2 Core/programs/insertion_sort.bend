import Base
# Insertion sort. Keys are reusable `+U32` values (Bend reference-counts the
# second use that Bend2 Core paid for with U32.copy). A comparison is a
# computed value, so the branch on it lives in its own def; the recursive
# insertion is passed as a thunk so it only runs when the key moves on.

def insert.if(n: U32, h: U32, t: List<&2, U32>, rest: Unit -> List<&2, U32>, le: Bool) -> List<&2, U32>:
  match le:
    case True{}:
      Con{n, Con{h, t}}
    case False{}:
      Con{h, rest(Unit{})}

def insert(+xs: List<&2, U32>, +n: U32) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Con{n, Nil{}}
    case Con{h, t}:
      insert.if(n, h, t, u => insert(t, n), U32.is_le(n, h))

def isort(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      insert(isort(t), h)

def list_eq(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      Bool.and(U32.is_eq(x, y), list_eq(xt, yt))
    case xs ys:
      False{}

def input() -> List<&2, U32>:
  Con{4, Con{2, Con{7, Con{1, Con{9, Con{3, Con{8, Con{5, Con{6, Nil{}}}}}}}}}}

def expected() -> List<&2, U32>:
  Con{1, Con{2, Con{3, Con{4, Con{5, Con{6, Con{7, Con{8, Con{9, Nil{}}}}}}}}}}

def main() -> Bool:
  list_eq(isort(input()), expected())
