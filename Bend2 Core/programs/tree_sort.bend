import Base
# Tree sort with explicit copies for keys retained after comparison.

type Tree:
  Leaf{}
  Node{left: Tree, value: U32, right: Tree}

def insert(tree: Tree, n: U32) -> Tree:
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

def from_list(xs: List<U32>) -> Tree:
  match xs:
    case Nil{}:
      Leaf{}
    case Con{h, t}:
      insert(from_list(t), h)

def inorder(tree: Tree, acc: List<U32>) -> List<U32>:
  match tree:
    case Leaf{}:
      acc
    case Node{left, value, right}:
      inorder(left, Con{value, inorder(right, acc)})

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
  Con{U32.from_nat(42n), Con{U32.from_nat(7n), Con{U32.from_nat(19n), Con{U32.from_nat(3n), Con{U32.from_nat(88n), Con{U32.one(), Con{U32.from_nat(56n), Con{U32.from_nat(24n), Con{U32.from_nat(61n), Con{U32.from_nat(10n), Nil{}}}}}}}}}}}

def expected() -> List<U32>:
  Con{U32.one(), Con{U32.from_nat(3n), Con{U32.from_nat(7n), Con{U32.from_nat(10n), Con{U32.from_nat(19n), Con{U32.from_nat(24n), Con{U32.from_nat(42n), Con{U32.from_nat(56n), Con{U32.from_nat(61n), Con{U32.from_nat(88n), Nil{}}}}}}}}}}}

def main() -> Bool:
  list_eq(inorder(from_list(input()), Nil{}), expected())
