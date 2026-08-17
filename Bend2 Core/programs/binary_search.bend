import Base
# Binary search. Bend3 shares one tree among four probes; Bend2 Core has no
# shared +Tree, so Tree.copy explicitly rebuilds four certified copies.

type Tree:
  Leaf{}
  Node{left: Tree, value: U32, right: Tree}

def insert(tree: Tree, n: U32) -> Tree:
  match tree:
    case Leaf{}:
      Node{Leaf{}, n, Leaf{}}
    case Node{left, value, right}:
      ((n1, en1), (n2, en2)) = U32.copy(n)
      ((v1, ev1), (v2, ev2)) = U32.copy(value)
      match U32.is_le(n1, v1):
        case True{}:
          Node{insert(left, n2), v2, right}
        case False{}:
          Node{left, v2, insert(right, n2)}

def from_list(xs: List<U32>) -> Tree:
  match xs:
    case Nil{}:
      Leaf{}
    case Con{h, t}:
      insert(from_list(t), h)

def Tree.copy(tree: Tree) -> Tree & Tree:
  match tree:
    case Leaf{}:
      (Leaf{}, Leaf{})
    case Node{left, value, right}:
      (l1, l2) = Tree.copy(left)
      (r1, r2) = Tree.copy(right)
      ((v1, ev1), (v2, ev2)) = U32.copy(value)
      (Node{l1, v1, r1}, Node{l2, v2, r2})

def member(tree: Tree, n: U32) -> Bool:
  match tree:
    case Leaf{}:
      False{}
    case Node{left, value, right}:
      ((n1, en1), (n2, en2)) = U32.copy(n)
      ((v1, ev1), (v2, ev2)) = U32.copy(value)
      match U32.is_eq(n1, v1):
        case True{}:
          True{}
        case False{}:
          ((n3, en3), (n4, en4)) = U32.copy(n2)
          match U32.is_lt(n3, v2):
            case True{}:
              member(left, n4)
            case False{}:
              member(right, n4)

def input() -> List<U32>:
  Con{U32.from_nat(8n), Con{U32.from_nat(3n), Con{U32.from_nat(10n), Con{U32.one(), Con{U32.from_nat(6n), Con{U32.from_nat(14n), Con{U32.from_nat(4n), Con{U32.from_nat(7n), Con{U32.from_nat(13n), Nil{}}}}}}}}}}

def main() -> Bool:
  match Tree.copy(from_list(input())):
    case (ta, tb):
      match Tree.copy(ta):
        case (t1, t2):
          match Tree.copy(tb):
            case (t3, t4):
              a = member(t1, U32.from_nat(6n))
              b = Bool.not(member(t2, U32.from_nat(5n)))
              c = member(t3, U32.from_nat(13n))
              d = Bool.not(member(t4, U32.from_nat(2n)))
              Bool.and(Bool.and(a, b), Bool.and(c, d))
