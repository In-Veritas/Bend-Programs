import Base
# Tree sort. Keys retained after a comparison are reusable `+U32` values (Bend
# reference-counts what Bend2 Core paid for with U32.copy). A comparison is a
# computed value, so `branch` matches it as a parameter and runs only the
# chosen thunk.

type Tree is Data:
  Leaf{}
  Node{left: Tree, value: U32, right: Tree}

def branch(c: Bool, t: Unit -> Tree, f: Unit -> Tree) -> Tree:
  match c:
    case True{}:
      t(Unit{})
    case False{}:
      f(Unit{})

def insert(+tree: Tree, +n: U32) -> Tree:
  match tree:
    case Leaf{}:
      Node{Leaf{}, n, Leaf{}}
    case Node{left, value, right}:
      branch(U32.is_le(n, value),
        u => Node{insert(left, n), value, right},
        u => Node{left, value, insert(right, n)})

def from_list(xs: List<&2, U32>) -> Tree:
  match xs:
    case Nil{}:
      Leaf{}
    case Con{h, t}:
      insert(from_list(t), h)

def inorder(tree: Tree, acc: List<&2, U32>) -> List<&2, U32>:
  match tree:
    case Leaf{}:
      acc
    case Node{left, value, right}:
      inorder(left, Con{value, inorder(right, acc)})

def list_eq(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      Bool.and(U32.is_eq(x, y), list_eq(xt, yt))
    case xs ys:
      False{}

def input() -> List<&2, U32>:
  Con{42, Con{7, Con{19, Con{3, Con{88, Con{1, Con{56, Con{24, Con{61, Con{10, Nil{}}}}}}}}}}}

def expected() -> List<&2, U32>:
  Con{1, Con{3, Con{7, Con{10, Con{19, Con{24, Con{42, Con{56, Con{61, Con{88, Nil{}}}}}}}}}}}

def main() -> Bool:
  list_eq(inorder(from_list(input()), Nil{}), expected())
