# binary search: build one binary search tree, then probe it four times.
# The tree is bound with `+t`, so every probe reads the same shared tree
# (reference counted at runtime) instead of rebuilding it. member answers
# 1 when n is in the tree and 0 otherwise.
#
# A match may only inspect a parameter, so the comparisons are computed by
# the caller and the helpers match on the resulting Bool; the descents are
# passed as thunks (Unit -> ..), so only the chosen branch ever runs.
#
# $ bend binary_search.bend

# expect: [1, 0, 1, 0]

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

# found: stop with 1; otherwise go left when n < v, right when not
def look(found: Bool, lt: Bool, gl: Unit -> U32, gr: Unit -> U32) -> U32:
  match found lt:
    case True{} _:
      1
    case False{} True{}:
      gl(Unit{})
    case False{} False{}:
      gr(Unit{})

def member(+n: U32, +t: Tree) -> U32:
  match t:
    case Leaf{}:
      0
    case Node{l, v, r}:
      look(U32.is_eq(n, v), (n < v : U32), u => member(n, l), u => member(n, r))

def main() -> List<U32>:
  +t = from_list([8, 3, 10, 1, 6, 14, 4, 7, 13])
  [member(6, t), member(5, t), member(13, t), member(2, t)]
