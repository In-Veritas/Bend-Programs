NodeTree(t: Data) : Data{
    Leaf_{}
    Node_{lft:NodeTree(t), rgt: NodeTree(t), val: t}
}

LeafTree(t: Data) : Data{
    Leaf{val: t}
    Node{lft: LeafTree(t), rgt: LeafTree(t)}
}

getval : ∀-a:Data. LeafTree(a) -> a 
| a Leaf{val} = val
| a Node{lft, rgt} = getval(a, lft)

leaftree_to_nodetree : ∀-a:Data. LeafTree(a) +> NodeTree(a)
| a Leaf{val} = Leaf_{}
| a Node{lft, rgt} = Node_{leaftree_to_nodetree(a, lft), leaftree_to_nodetree(a, rgt), getval(a, lft)}

main : NodeTree(U32) =
  leaftree_to_nodetree(U32, Node{Node{Leaf{1}, Leaf{2}}, Leaf{3}})