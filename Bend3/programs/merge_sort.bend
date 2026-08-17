# merge sort as counting in binary: a Runs value is a binary counter whose
# i-th digit, when set, holds a sorted run of exactly 2^i elements. Adding an
# element is incrementing the counter -- a carry merges two equal-sized runs,
# so every element takes part in at most log(n) merges: O(n log n), bottom-up,
# and fully structural (no split step, which the halt checker would reject).
# carry takes the shrinking Runs argument FIRST: halt compares call arguments
# lexicographically left to right.
#
# $ bun bend-ts/src/bend.ts merge_sort.bend --eval

import ../bend-base/Base

type Runs:
  Rnil{}
  Rcons{run: List(U32), rest: Runs}

# the classic merge: keeps whichever head is smaller, recurses on the rest
def merge(xs: List(U32), ys: List(U32)) -> List(U32):
  match xs, ys:
    case List.Nil{}, ys:
      ys
    case List.Cons{x, xt}, List.Nil{}:
      List.Cons{x, xt}
    case List.Cons{x, xt}, List.Cons{y, yt}:
      xx = x
      yy = y
      match xx <= yy:
        case 0:
          List.Cons{yy, merge(List.Cons{xx, xt}, yt)}
        case k:
          List.Cons{xx, merge(xt, List.Cons{yy, yt})}

# increment: drop the run into the first vacant digit, merging on carry
# (a vacant digit is Nil{} -- a run is never empty, so there is no clash)
def carry(rs: Runs, r: List(U32)) -> Runs:
  match rs:
    case Runs.Rnil{}:
      Runs.Rcons{r, Runs.Rnil{}}
    case Runs.Rcons{List.Nil{}, rest}:
      Runs.Rcons{r, rest}
    case Runs.Rcons{List.Cons{h, t}, rest}:
      Runs.Rcons{List.Nil{}, carry(rest, merge(List.Cons{h, t}, r))}

# count every element into the register, one singleton run at a time
def to_runs(xs: List(U32)) -> Runs:
  match xs:
    case List.Nil{}:
      Runs.Rnil{}
    case List.Cons{x, t}:
      carry(to_runs(t), List.Cons{x, List.Nil{}})

# cash out: fold the surviving digits into one sorted list
def collapse(rs: Runs) -> List(U32):
  match rs:
    case Runs.Rnil{}:
      List.Nil{}
    case Runs.Rcons{run, rest}:
      merge(run, collapse(rest))

def msort(xs: List(U32)) -> List(U32):
  collapse(to_runs(xs))

def main() -> List(U32):
  msort([5, 3, 8, 1, 9, 2, 7, 6, 4])
