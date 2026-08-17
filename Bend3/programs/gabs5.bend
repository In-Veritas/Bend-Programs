# no-halt
type NodeTree<T>:
  Leaf_{}
  Node_{lft: NodeTree(T), rgt: NodeTree(T), val: T}

type LeafTree<T>:
  Leaf{val: T}
  Node{lft: LeafTree(T), rgt: LeafTree(T)}

def getval(-A: Data, t: LeafTree(A)) -> A:
  match t:
    case LeafTree.Leaf{val}:
      val
    case LeafTree.Node{lft, rgt}:
      getval(A, lft)

def node_to_nodetree(-A: Data, lft: +LeafTree(A), rgt: LeafTree(A)) -> NodeTree(A):
  NodeTree.Node_{leaftree_to_nodetree(A, lft), leaftree_to_nodetree(A, rgt), getval(A, lft)}

def leaftree_to_nodetree(-A: Data, t: LeafTree(A)) -> NodeTree(A):
  match t:
    case LeafTree.Leaf{val}:
      NodeTree.Leaf_{}
    case LeafTree.Node{lft, rgt}:
      node_to_nodetree(A, lft, rgt)

def main() -> NodeTree(U32):
  leaftree_to_nodetree(U32, LeafTree.Node{LeafTree.Node{LeafTree.Leaf{1}, LeafTree.Leaf{2}}, LeafTree.Leaf{3}})
