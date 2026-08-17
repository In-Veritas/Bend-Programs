# insertion sort: the two-line classic. insert walks a sorted list and drops
# the new element at its place; isort folds insert over the input. The
# comparison is a computed match: `n <= h` becomes a 0/nonzero switch, and the
# halt checker certifies the recursion right through it (t shrinks each step).
#
# $ bun bend-ts/src/bend.ts insertion_sort.bend --eval

import ../bend-base/Base

def insert(n: U32, l: List(U32)) -> List(U32):
  match l:
    case List.Nil{}:
      List.Cons{n, List.Nil{}}
    case List.Cons{h, t}:
      nn = n
      hh = h
      match (nn <= hh):
        case 0:
          List.Cons{hh, insert(nn, t)}
        case k:
          List.Cons{nn, List.Cons{hh, t}}

def isort(l: List(U32)) -> List(U32):
  match l:
    case List.Nil{}:
      List.Nil{}
    case List.Cons{h, t}:
      insert(h, isort(t))

def main() -> List(U32):
  isort([4, 2, 7, 1, 9, 3, 8, 5, 6])
