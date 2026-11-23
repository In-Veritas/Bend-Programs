# tree sort: quicksort's tree-shaped twin. Every element is inserted into a
# binary search tree (each insert plays the pivot game: smaller goes left,
# bigger goes right), and the in-order walk reads the sorted list back off.
# inorder threads an accumulator, so the whole readback is one right fold
# with no appends.
#
# A match may only inspect a parameter, so insert computes `n <= v` and hands
# the Bool to branch. Both possible descents arrive as thunks (Unit -> Tree,
# the idiom Base's List.any uses), so only the chosen side is ever rebuilt.
#
# $ bend tree_sort.bend

# expect: [1, 3, 7, 10, 19, 24, 42, 56, 61, 88]

import Base

type Tree is Data:
  Leaf{}
  Node{lft: Tree, val: U32, rgt: Tree}

def branch(l: Tree, v: U32, r: Tree, il: Unit -> Tree, ir: Unit -> Tree, le: Bool) -> Tree:
  match le:
    case True{}:
      Node{il(Unit{}), v, r}
    case False{}:
      Node{l, v, ir(Unit{})}

def insert(+n: U32, t: Tree) -> Tree:
  match t:
    case Leaf{}:
      Node{Leaf{}, n, Leaf{}}
    case Node{+l, +v, +r}:
      branch(l, v, r, u => insert(n, l), u => insert(n, r), (n <= v : U32))

def from_list(l: List<U32>) -> Tree:
  match l:
    case Nil{}:
      Leaf{}
    case h <> t:
      insert(h, from_list(t))

def inorder(t: Tree, acc: List<U32>) -> List<U32>:
  match t:
    case Leaf{}:
      acc
    case Node{l, v, r}:
      inorder(l, v <> inorder(r, acc))

def tsort(xs: List<U32>) -> List<U32>:
  inorder(from_list(xs), Nil{})

def main() -> List<U32>:
  tsort([42, 7, 19, 3, 88, 1, 56, 24, 61, 10])
