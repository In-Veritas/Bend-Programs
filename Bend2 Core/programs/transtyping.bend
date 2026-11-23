import Base
# LeafTree<U32> to NodeTree<U32>. The worker returns the leftmost value beside
# the converted tree; a reusable `+value` binder pays (a reference count) when
# an ancestor needs both copies.

type NodeTree is Data:
  Leaf_{}
  Node_{left: NodeTree, right: NodeTree, value: U32}

type LeafTree is Data:
  Leaf{value: U32}
  Node{left: LeafTree, right: LeafTree}

# l is the converted left subtree with its leftmost value, r the right one's
def convert.node(l: NodeTree & U32, r: NodeTree & U32) -> NodeTree & U32:
  match l r:
    case Tuple{nl, +value} Tuple{nr, ignored}:
      (Node_{nl, nr, value}, value)

def convert(tree: LeafTree) -> NodeTree & U32:
  match tree:
    case Leaf{value}:
      (Leaf_{}, value)
    case Node{left, right}:
      convert.node(convert(left), convert(right))

def port.fst(r: NodeTree & U32) -> NodeTree:
  match r:
    case (result, value):
      result

def port(tree: LeafTree) -> NodeTree:
  port.fst(convert(tree))

def valid(tree: NodeTree) -> Bool:
  match tree:
    case Node_{Node_{Leaf_{}, Leaf_{}, a}, Leaf_{}, b}:
      Bool.and(U32.is_eq(a, 1), U32.is_eq(b, 1))
    case tree:
      False{}

def main() -> Bool:
  valid(port(Node{Node{Leaf{1}, Leaf{2}}, Leaf{3}}))
