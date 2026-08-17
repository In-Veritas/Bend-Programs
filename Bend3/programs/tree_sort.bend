# tree sort: quicksort's tree-shaped twin. Every element is inserted into a
# binary search tree (each insert plays the pivot game: smaller goes left,
# bigger goes right), and the in-order walk reads the sorted list back off.
# inorder threads an accumulator, so the whole readback is one right fold
# with no appends.
#
# $ bun bend-ts/src/bend.ts tree_sort.bend --eval

import ../bend-base/Base

type Tree:
  Leaf{}
  Node{lft: Tree, val: U32, rgt: Tree}

def insert(n: U32, t: Tree) -> Tree:
  match t:
    case Tree.Leaf{}:
      Tree.Node{Tree.Leaf{}, n, Tree.Leaf{}}
    case Tree.Node{l, v, r}:
      nn = n
      vv = v
      match (nn <= vv):
        case 0:
          Tree.Node{l, vv, insert(nn, r)}
        case k:
          Tree.Node{insert(nn, l), vv, r}

def from_list(l: List(U32)) -> Tree:
  match l:
    case List.Nil{}:
      Tree.Leaf{}
    case List.Cons{h, t}:
      insert(h, from_list(t))

def inorder(t: Tree, acc: List(U32)) -> List(U32):
  match t:
    case Tree.Leaf{}:
      acc
    case Tree.Node{l, v, r}:
      inorder(l, List.Cons{v, inorder(r, acc)})

def tsort(xs: List(U32)) -> List(U32):
  inorder(from_list(xs), List.Nil{})

def main() -> List(U32):
  tsort([42, 7, 19, 3, 88, 1, 56, 24, 61, 10])
