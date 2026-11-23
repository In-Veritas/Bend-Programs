import Base
# Binary search. As in Bend3, one tree is shared by four probes: the Tree is
# Data, so a `+tree` binder replaces the structural Tree.copy that Bend2 Core
# needed. Comparisons are computed values, so the branches live in their own
# defs (Bend matches only parameters) and run only the chosen thunk.

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

# LT: search left, EQ: found, GT: search right
def member.cmp(c: Cmp, l: Unit -> Bool, r: Unit -> Bool) -> Bool:
  match c:
    case LT{}:
      l(Unit{})
    case EQ{}:
      True{}
    case GT{}:
      r(Unit{})

def member(tree: Tree, +n: U32) -> Bool:
  match tree:
    case Leaf{}:
      False{}
    case Node{left, value, right}:
      member.cmp(U32.cmp(n, value), u => member(left, n), u => member(right, n))

def input() -> List<&2, U32>:
  Con{8, Con{3, Con{10, Con{1, Con{6, Con{14, Con{4, Con{7, Con{13, Nil{}}}}}}}}}}

def probes(+tree: Tree) -> Bool:
  a = member(tree, 6)
  b = Bool.not(member(tree, 5))
  c = member(tree, 13)
  d = Bool.not(member(tree, 2))
  Bool.and(Bool.and(a, b), Bool.and(c, d))

def main_value() -> Bool:
  probes(from_list(input()))

# The executable entry prints the pure self-check, so `bend FILE`, a native
# build and the JS build all report True{} through the same IO path.
def main_show_bool(value: Bool) -> IO(Unit):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

def main() -> IO(Unit):
  main_show_bool(main_value())
