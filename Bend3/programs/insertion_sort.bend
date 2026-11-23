# insertion sort: the two-line classic. insert walks a sorted list and drops
# the new element at its place; isort folds insert over the input. A match
# may only inspect a parameter, so the comparison `n <= h` is computed in
# insert and handed to place, which matches on the resulting Bool. The
# recursive call insert(n, t) is passed in as a thunk (Unit -> List, the idiom
# Base's List.any uses), so it only runs when n belongs further down, and t
# shrinks each step, so termination is structural.
#
# $ bend insertion_sort.bend

# expect: [1, 2, 3, 4, 5, 6, 7, 8, 9]

import Base

# n goes before h when n <= h; otherwise h stays first, followed by r(), the
# result of inserting n into the tail t
def place(n: U32, h: U32, t: List<&2, U32>, r: Unit -> List<&2, U32>, le: Bool) -> List<&2, U32>:
  match le:
    case True{}:
      n <> h <> t
    case False{}:
      h <> r(Unit{})

def insert(+n: U32, +l: List<&2, U32>) -> List<&2, U32>:
  match l:
    case Nil{}:
      [n]
    case h <> t:
      place(n, h, t, u => insert(n, t), (n <= h : U32))

def isort(l: List<&2, U32>) -> List<&2, U32>:
  match l:
    case Nil{}:
      Nil{}
    case h <> t:
      insert(h, isort(t))

def main() -> List<&2, U32>:
  isort([4, 2, 7, 1, 9, 3, 8, 5, 6])
