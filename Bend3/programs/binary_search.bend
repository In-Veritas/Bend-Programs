import ../bend-base/Base

type Tree:
  Leaf{}
  Node{lft: Tree, val: U32, rgt: Tree}

def insert(n: U32, t: Tree) -> Tree:
  match t:
    case Tree.Leaf{}:
      Tree.Node{Tree.Leaf{}, n, Tree.Leaf{}}
    case Tree.Node{l, v, r}:
      nn = n
      vv = v
      match (nn <= vv):
        case 0:
          Tree.Node{l, vv, insert(nn, r)}
        case k:
          Tree.Node{insert(nn, l), vv, r}

def from_list(l: List(U32)) -> Tree:
  match l:
    case List.Nil{}:
      Tree.Leaf{}
    case List.Cons{h, t}:
      insert(h, from_list(t))

def member_go(n: U32, t: Tree) -> U32:
  match t:
    case Tree.Leaf{}:
      0
    case Tree.Node{l, v, r}:
      vv = v
      match (n == vv):
        case 0:
          match (n < vv):
            case 0:
              rr = r
              member_go(n, rr)
            case k:
              ll = l
              member_go(n, ll)
        case k:
          1

def member(n: +U32, t: +Tree) -> U32:
  member_go(n, t)

def main() -> List(U32):
  t = from_list([8, 3, 10, 1, 6, 14, 4, 7, 13])
  six = 6
  five = 5
  thirteen = 13
  two = 2
  [member(six, t), member(five, t), member(thirteen, t), member(two, t)]
