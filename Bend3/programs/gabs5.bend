# LeafTree -> NodeTree: values live only in the leaves of a LeafTree; each
# Node of the resulting NodeTree carries the leftmost value of its left
# subtree, and leaves become empty Leaf_ markers. The old node_to_nodetree
# helper is inlined into the Node case: Bend forbids mutual recursion, and
# matching Node{+lft, rgt} makes lft reusable for both the recursive call and
# getval.
# expect: Node_{Node_{Leaf_{}, Leaf_{}, 1}, Leaf_{}, 1}

import Base

type NodeTree<-T: Data> is Data:
  Leaf_{}
  Node_{lft: NodeTree<T>, rgt: NodeTree<T>, val: T}

type LeafTree<-T: Data> is Data:
  Leaf{val: T}
  Node{lft: LeafTree<T>, rgt: LeafTree<T>}

def getval(-A: Data, t: LeafTree<A>) -> A:
  match t:
    case Leaf{val}:
      val
    case Node{lft, rgt}:
      getval(A, lft)

def leaftree_to_nodetree(-A: Data, t: LeafTree<A>) -> NodeTree<A>:
  match t:
    case Leaf{val}:
      Leaf_{}
    case Node{+lft, rgt}:
      Node_{leaftree_to_nodetree(A, lft), leaftree_to_nodetree(A, rgt), getval(A, lft)}

def main() -> NodeTree<U32>:
  leaftree_to_nodetree(U32, Node{Node{Leaf{1}, Leaf{2}}, Leaf{3}})
