# Independent certificate for complete-linkage's pairwise threshold contract.
# Rows come from the filtered input graph, before the clustering algorithm runs.
import Base
import ./partition_certificate.bend as P

type Vertex is Data:
  Vertex{id: U32, label: U32, adjacent: List<&2, U32>}

def contains(+x: U32, xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: False{}
    case Con{h, t}: Bool.or(U32.is_eq(x, h), contains(x, t))

def pair_ok(a: Vertex, b: Vertex) -> Bool:
  match a b:
    case Vertex{+i, c, ns} Vertex{+j, d, ms}:
      Bool.or(U32.is_eq(i, j), Bool.or(U32.is_ne(c, d), contains(j, ns)))

def Row(+a: Vertex, xs: List<&2, Vertex>) -> Data:
  match xs:
    case Nil{}: Unit
    case Con{b, t}:
      Sigma<&2, &2, P.Holds(pair_ok(a, b)), _ => Row(a, t)>

def Clique(xs: List<&2, Vertex>) -> Data:
  match xs:
    case Nil{}: Unit
    case Con{a, t}:
      Sigma<&2, &2, Row(a, t), _ => Clique(t)>

def check_row(+a: Vertex, xs: List<&2, Vertex>) -> Bool:
  match xs:
    case Nil{}: True{}
    case Con{b, t}: Bool.and(pair_ok(a, b), check_row(a, t))

def check(xs: List<&2, Vertex>) -> Bool:
  match xs:
    case Nil{}: True{}
    case Con{a, +t}: Bool.and(check_row(a, t), check(t))

def row_sound(+a: Vertex, +xs: List<&2, Vertex>, +ok: P.Holds(check_row(a, xs))) -> Row(a, xs):
  match xs:
    case Nil{}: Unit{}
    case Con{+b, +t}:
      (P.and_left(pair_ok(a, b), check_row(a, t), ok),
       row_sound(a, t, P.and_right(pair_ok(a, b), check_row(a, t), ok)))

law sound:
  for +xs: List<&2, Vertex>
  for +ok: P.Holds(check(xs))
  Clique(xs)

def sound(xs, ok):
  match xs:
    case Nil{}: Unit{}
    case Con{+a, +t}:
      (row_sound(a, t, P.and_left(check_row(a, t), check(t), ok)),
       sound(t, P.and_right(check_row(a, t), check(t), ok)))

type Certified<-xs: List<&2, Vertex>> is Data:
  Certified{-proof: Clique(xs)}

def finish(-xs: List<&2, Vertex>, result: P.Decision<P.Holds(check(xs))>) -> Maybe<&2, Certified<xs>>:
  match result:
    case P.Reject{}: None{}
    case P.Accept{proof}: Some{Certified{sound(xs, proof)}}

def certify(+xs: List<&2, Vertex>) -> Maybe<&2, Certified<xs>>:
  finish(xs, P.decide(check(xs)))

# A path is connected but is not a clique: this is an intentionally rejected
# complete-linkage result, rather than a successful fixture only.
def rejects_chaining() -> {check([Vertex{0, 0, [1]}, Vertex{1, 0, [0, 2]}, Vertex{2, 0, [1]}]) == False{} : Bool}:
  {==}

def accepts_split() -> {check([Vertex{0, 0, [1]}, Vertex{1, 0, [0, 2]}, Vertex{2, 1, [1]}]) == True{} : Bool}:
  {==}
