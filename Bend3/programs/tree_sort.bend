# tree sort: quicksort's tree-shaped twin. Every element is inserted into a
# binary search tree (each insert plays the pivot game: smaller goes left,
# bigger goes right), and the in-order walk reads the sorted list back off.
# inorder threads an accumulator, so the whole readback is one right fold
# with no appends.
#
# $ bend tree_sort.bend

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

inorder : Tree -> List(U32) -> List(U32)
| Leaf{}        acc = acc
| Node{l, v, r} acc = inorder(l, Cons{v, inorder(r, acc)})

tsort : List(U32) -> List(U32)
= λxs. inorder(from_list(xs), Nil{})

main : List(U32) = tsort([42, 7, 19, 3, 88, 1, 56, 24, 61, 10])
