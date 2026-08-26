import Base
# Tree sort with explicit copies for keys retained after comparison.

type Tree:
  Leaf{}
  Node{left: Tree, value: U32, right: Tree}

assert insert:
  forall tree: Tree
  forall n: U32
  Tree

def insert(tree, n):
  match tree:
    case Leaf{}:
      Node{Leaf{}, n, Leaf{}}
    case Node{left, value, right}:
      ((n1, en1), (n2, en2)) = U32.copy(n)
      ((v1, ev1), (v2, ev2)) = U32.copy(value)
      match U32.is_le(n1, v1):
        case True{}:
          Node{insert(left, n2), v2, right}
        case False{}:
          Node{left, v2, insert(right, n2)}

assert from_list:
  forall xs: List<U32>
  Tree

def from_list(xs):
  match xs:
    case Nil{}:
      Leaf{}
    case Con{h, t}:
      insert(from_list(t), h)

assert inorder:
  forall tree: Tree
  forall acc: List<U32>
  List<U32>

def inorder(tree, acc):
  match tree:
    case Leaf{}:
      acc
    case Node{left, value, right}:
      inorder(left, Con{value, inorder(right, acc)})

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
  Con{U32.from_nat(42n), Con{U32.from_nat(7n), Con{U32.from_nat(19n), Con{U32.from_nat(3n), Con{U32.from_nat(88n), Con{1, Con{U32.from_nat(56n), Con{U32.from_nat(24n), Con{U32.from_nat(61n), Con{U32.from_nat(10n), Nil{}}}}}}}}}}}

assert expected:
  List<U32>

def expected():
  Con{1, Con{U32.from_nat(3n), Con{U32.from_nat(7n), Con{U32.from_nat(10n), Con{U32.from_nat(19n), Con{U32.from_nat(24n), Con{U32.from_nat(42n), Con{U32.from_nat(56n), Con{U32.from_nat(61n), Con{U32.from_nat(88n), Nil{}}}}}}}}}}}

assert main_value:
  Bool

def main_value():
  list_eq(inorder(from_list(input()), Nil{}), expected())

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
