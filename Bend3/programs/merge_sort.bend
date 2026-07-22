# merge sort as counting in binary: a Runs value is a binary counter whose
# i-th digit, when set, holds a sorted run of exactly 2^i elements. Adding an
# element is incrementing the counter -- a carry merges two equal-sized runs,
# so every element takes part in at most log(n) merges: O(n log n), bottom-up,
# and fully structural (no split step, which the halt checker would reject).
# carry takes the shrinking Runs argument FIRST: halt compares call arguments
# lexicographically left to right.
#
# $ bend merge_sort.bend

List(t: Data) : Data {
  Cons{head: t, tail: List(t)}
  Nil{}
}

Runs : Data {
  Rnil{}
  Rcons{run: List(U32), rest: Runs}
}

# the classic merge: keeps whichever head is smaller, recurses on the rest
merge : List(U32) -> List(U32) -> List(U32)
| Nil{}        ys           = ys
| Cons{x, xt}  Nil{}        = Cons{x, xt}
| Cons{x, xt}  Cons{y, yt}  = ! +xx +yy = &x &y;
  match *xx <= *yy:
    case 0:
      Cons{*yy, merge(Cons{*xx, xt}, yt)}
    case k:
      Cons{*xx, merge(xt, Cons{*yy, yt})}

# increment: drop the run into the first vacant digit, merging on carry
# (a vacant digit is Nil{} -- a run is never empty, so there is no clash)
carry : Runs -> List(U32) -> Runs
| Rnil{}                  r = Rcons{r, Rnil{}}
| Rcons{Nil{}, rest}      r = Rcons{r, rest}
| Rcons{Cons{h, t}, rest} r = Rcons{Nil{}, carry(rest, merge(Cons{h, t}, r))}

# count every element into the register, one singleton run at a time
to_runs : List(U32) -> Runs
| Nil{}      = Rnil{}
| Cons{x, t} = carry(to_runs(t), Cons{x, Nil{}})

# cash out: fold the surviving digits into one sorted list
collapse : Runs -> List(U32)
| Rnil{}           = Nil{}
| Rcons{run, rest} = merge(run, collapse(rest))

msort : List(U32) -> List(U32)
= λxs. collapse(to_runs(xs))

main : List(U32) = msort([5, 3, 8, 1, 9, 2, 7, 6, 4])
