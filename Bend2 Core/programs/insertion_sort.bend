import Base
# Insertion sort with explicit U32 copies at the comparison/rebuild boundary.

assert insert:
  forall xs: List<U32>
  forall n: U32
  List<U32>

def insert(xs, n):
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

assert isort:
  forall xs: List<U32>
  List<U32>

def isort(xs):
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      insert(isort(t), h)

assert list_eq:
  forall xs: List<U32>
  forall ys: List<U32>
  Bool

def list_eq(xs, ys):
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

assert input:
  List<U32>

def input():
  Con{U32.from_nat(4n), Con{U32.from_nat(2n), Con{U32.from_nat(7n), Con{1, Con{U32.from_nat(9n), Con{U32.from_nat(3n), Con{U32.from_nat(8n), Con{U32.from_nat(5n), Con{U32.from_nat(6n), Nil{}}}}}}}}}}

assert expected:
  List<U32>

def expected():
  Con{1, Con{U32.from_nat(2n), Con{U32.from_nat(3n), Con{U32.from_nat(4n), Con{U32.from_nat(5n), Con{U32.from_nat(6n), Con{U32.from_nat(7n), Con{U32.from_nat(8n), Con{U32.from_nat(9n), Nil{}}}}}}}}}}

assert main_value:
  Bool

def main_value():
  list_eq(isort(input()), expected())

assert main_show_bool:
  forall value: Bool
  IO(Unit)

def main_show_bool(value):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

assert main:
  IO(Unit)

def main():
  main_show_bool(main_value!())
