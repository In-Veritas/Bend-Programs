# merge sort as counting in binary: a Runs value is a binary counter whose
# i-th digit, when set, holds a sorted run of exactly 2^i elements. Adding an
# element is incrementing the counter -- a carry merges two equal-sized runs,
# so every element takes part in at most log(n) merges: O(n log n), bottom-up,
# and fully structural (no split step, which the termination check would
# reject). carry takes the shrinking Runs argument FIRST: termination reads
# call arguments left to right.
#
# $ bend merge_sort.bend

# expect: [1, 2, 3, 4, 5, 6, 7, 8, 9]

import Base

type Runs is Data:
  Rnil{}
  Rcons{run: +List<U32>, rest: Runs}

# keeps whichever head is smaller; the two possible recursions arrive as
# thunks, so only the chosen one runs
def pick(x: U32, y: U32, kx: Unit -> +List<U32>, ky: Unit -> +List<U32>, le: Bool) -> +List<U32>:
  match le:
    case True{}:
      x <> kx(Unit{})
    case False{}:
      y <> ky(Unit{})

# the classic merge. In merge(xs, yt) the first argument is passed unchanged
# and the second shrinks; in merge(xt, ys) the first shrinks.
def merge(+xs: +List<U32>, +ys: +List<U32>) -> +List<U32>:
  match xs ys:
    case Nil{} _:
      ys
    case _ Nil{}:
      xs
    case x <> xt  y <> yt:
      pick(x, y, u => merge(xt, ys), u => merge(xs, yt), (x <= y : U32))

# increment: drop the run into the first vacant digit, merging on carry
# (a vacant digit is Nil{} -- a run is never empty, so there is no clash)
def carry(rs: Runs, r: +List<U32>) -> Runs:
  match rs:
    case Rnil{}:
      Rcons{r, Rnil{}}
    case Rcons{Nil{}, rest}:
      Rcons{r, rest}
    case Rcons{h <> t, rest}:
      Rcons{Nil{}, carry(rest, merge(h <> t, r))}

# count every element into the register, one singleton run at a time
def to_runs(xs: +List<U32>) -> Runs:
  match xs:
    case Nil{}:
      Rnil{}
    case x <> t:
      carry(to_runs(t), [x])

# cash out: fold the surviving digits into one sorted list
def collapse(rs: Runs) -> +List<U32>:
  match rs:
    case Rnil{}:
      Nil{}
    case Rcons{run, rest}:
      merge(run, collapse(rest))

def msort(xs: +List<U32>) -> +List<U32>:
  collapse(to_runs(xs))

def main() -> +List<U32>:
  msort([5, 3, 8, 1, 9, 2, 7, 6, 4])
