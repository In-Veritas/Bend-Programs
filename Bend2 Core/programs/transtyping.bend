import Base
# LeafTree<U32> to NodeTree<U32>. The worker returns the leftmost value beside
# the converted tree; U32.copy pays explicitly when an ancestor needs both.

type NodeTree:
  Leaf_{}
  Node_{left: NodeTree, right: NodeTree, value: U32}

type LeafTree:
  Leaf{value: U32}
  Node{left: LeafTree, right: LeafTree}

assert convert:
  forall tree: LeafTree
  NodeTree & U32

def convert(tree):
  match tree:
    case Leaf{value}:
      (Leaf_{}, value)
    case Node{left, right}:
      (nl, value) = convert(left)
      (nr, ignored) = convert(right)
      ((v1, ev1), (v2, ev2)) = U32.copy(value)
      (Node_{nl, nr, v1}, v2)

assert port:
  forall tree: LeafTree
  NodeTree

def port(tree):
  (result, value) = convert(tree)
  result

assert valid:
  forall tree: NodeTree
  Bool

def valid(tree):
  match tree:
    case Node_{Node_{Leaf_{}, Leaf_{}, a}, Leaf_{}, b}:
      Bool.and(U32.is_eq(a, 1), U32.is_eq(b, 1))
    case tree:
      False{}

assert main_value:
  Bool

def main_value():
  valid(port(Node{Node{Leaf{1}, Leaf{U32.from_nat(2n)}}, Leaf{U32.from_nat(3n)}}))

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
