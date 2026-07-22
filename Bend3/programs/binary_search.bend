# binary search: build a search tree once, probe it many times. The tree is
# a shared value (+Tree), so main can hand the SAME tree to four searches --
# no rebuilding, no copies; each probe owns one node layer at a time (match
# on *t) and descends left or right, discarding the half it ruled out.
#
# $ bend binary_search.bend

List(t: Data) : Data {
  Cons{head: t, tail: List(t)}
  Nil{}
}

Tree : Data {
  Leaf{}
  Node{lft: Tree, val: U32, rgt: Tree}
}

insert : U32 -> Tree -> Tree
| n Leaf{}        = Node{Leaf{}, n, Leaf{}}
| n Node{l, v, r} = ! +nn +vv = &n &v;
  match *nn <= *vv:
    case 0:
      Node{l, *vv, insert(*nn, r)}
    case k:
      Node{insert(*nn, l), *vv, r}

from_list : List(U32) -> Tree
| Nil{}      = Leaf{}
| Cons{h, t} = insert(h, from_list(t))

# three-way descent: hit, or recurse into the surviving half
member : +U32 +> +Tree +> U32
| n t =
  match *t:
    case Leaf{}:
      0
    case Node{l, v, r}:
      ! +vv = &v;
      match *n == *vv:
        case 0:
          match *n < *vv:
            case 0:
              ! +rr = &r; member(n, rr)
            case k:
              ! +ll = &l; member(n, ll)
        case k:
          1

main : List(U32) =
  ! +t = &from_list([8, 3, 10, 1, 6, 14, 4, 7, 13]);
  [member(&6, t), member(&5, t), member(&13, t), member(&2, t)]
