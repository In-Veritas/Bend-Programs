import Base
# LeafTree<U32> to NodeTree<U32>. The worker returns the leftmost value beside
# the converted tree; U32.copy pays explicitly when an ancestor needs both.

type NodeTree:
  Leaf_{}
  Node_{left: NodeTree, right: NodeTree, value: U32}

type LeafTree:
  Leaf{value: U32}
  Node{left: LeafTree, right: LeafTree}

def convert(tree: LeafTree) -> NodeTree & U32:
  match tree:
    case Leaf{value}:
      (Leaf_{}, value)
    case Node{left, right}:
      (nl, value) = convert(left)
      (nr, ignored) = convert(right)
      ((v1, ev1), (v2, ev2)) = U32.copy(value)
      (Node_{nl, nr, v1}, v2)

def port(tree: LeafTree) -> NodeTree:
  (result, value) = convert(tree)
  result

def valid(tree: NodeTree) -> Bool:
  match tree:
    case Node_{Node_{Leaf_{}, Leaf_{}, a}, Leaf_{}, b}:
      Bool.and(U32.is_eq(a, U32.one()), U32.is_eq(b, U32.one()))
    case tree:
      False{}

def main() -> Bool:
  valid(port(Node{Node{Leaf{U32.one()}, Leaf{U32.from_nat(2n)}}, Leaf{U32.from_nat(3n)}}))
