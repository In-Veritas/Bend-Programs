# insertion sort: the two-line classic. insert walks a sorted list and drops
# the new element at its place; isort folds insert over the input. The
# comparison is a computed match: `n <= h` becomes a 0/nonzero switch, and the
# halt checker certifies the recursion right through it (t shrinks each step).
#
# $ bend insertion_sort.bend

List(t: Data) : Data {
  Cons{head: t, tail: List(t)}
  Nil{}
}

insert : U32 -> List(U32) -> List(U32)
| n Nil{}      = Cons{n, Nil{}}
| n Cons{h, t} = ! +nn +hh = &n &h;
  match *nn <= *hh:
    case 0:
      Cons{*hh, insert(*nn, t)}
    case k:
      Cons{*nn, Cons{*hh, t}}

isort : List(U32) -> List(U32)
| Nil{}      = Nil{}
| Cons{h, t} = insert(h, isort(t))

main : List(U32) = isort([4, 2, 7, 1, 9, 3, 8, 5, 6])
