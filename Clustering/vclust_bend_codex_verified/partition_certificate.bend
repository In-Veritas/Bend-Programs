# A checked clustering has one bounded label per input position.
# The decision runs on the actual labels. Its proof fields erase at runtime.
# No unsafe definitions, foreign functions, or assumed axioms are used.
import Base

def Holds(b: Bool) -> Data:
  match b:
    case True{}: Unit
    case False{}: Empty

type Decision<-P: Data> is Data:
  Accept{-proof: P}
  Reject{}

def decide(b: Bool) -> Decision<Holds(b)>:
  match b:
    case True{}: Accept{Unit{}}
    case False{}: Reject{}

def and_left(a: Bool, b: Bool, p: Holds(Bool.and(a, b))) -> Holds(a):
  match a b:
    case True{} True{}: Unit{}
    case True{} False{}: Unit{}
    case False{} True{}: p
    case False{} False{}: p

def and_right(a: Bool, b: Bool, p: Holds(Bool.and(a, b))) -> Holds(b):
  match a b:
    case True{} True{}: Unit{}
    case True{} False{}: p
    case False{} True{}: Unit{}
    case False{} False{}: p

def length(xs: List<&2, U32>) -> Nat:
  match xs:
    case Nil{}: 0n
    case Con{x, rest}: 1n+length(rest)

# Structural specification: the only inhabited cases have equal lengths.
# Each present label is strictly below the declared number of clusters.
def Partition(n: Nat, +bound: U32, xs: List<&2, U32>) -> Data:
  match n xs:
    case 0n Nil{}: Unit
    case 0n Con{x, rest}: Empty
    case 1n+p Nil{}: Empty
    case 1n+p Con{x, rest}:
      Sigma<&2, &2, Holds(U32.is_lt(x, bound)), _ => Partition(p, bound, rest)>

def check(n: Nat, +bound: U32, xs: List<&2, U32>) -> Bool:
  match n xs:
    case 0n Nil{}: True{}
    case 0n Con{x, rest}: False{}
    case 1n+p Nil{}: False{}
    case 1n+p Con{x, rest}:
      Bool.and(U32.is_lt(x, bound), check(p, bound, rest))

def sound(+n: Nat, +bound: U32, +xs: List<&2, U32>, +ok: Holds(check(n, bound, xs))) -> Partition(n, bound, xs):
  match n xs:
    case 0n Nil{}: Unit{}
    case 0n Con{x, rest}: ok
    case 1n+p Nil{}: ok
    case 1n+p Con{+x, +rest}:
      (and_left(U32.is_lt(x, bound), check(p, bound, rest), ok),
       sound(p, bound, rest, and_right(U32.is_lt(x, bound), check(p, bound, rest), ok)))

type Certified<-n: Nat, -bound: U32, -xs: List<&2, U32>> is Data:
  Certified{-proof: Partition(n, bound, xs)}

def finish(-n: Nat, -bound: U32, -xs: List<&2, U32>, result: Decision<Holds(check(n, bound, xs))>) -> Maybe<&2, Certified<n, bound, xs>>:
  match result:
    case Reject{}: None{}
    case Accept{proof}: Some{Certified{sound(n, bound, xs, proof)}}

def certify(+n: Nat, +bound: U32, +xs: List<&2, U32>) -> Maybe<&2, Certified<n, bound, xs>>:
  finish(n, bound, xs, decide(check(n, bound, xs)))

def accepted(-n: Nat, -bound: U32, -xs: List<&2, U32>, result: Maybe<&2, Certified<n, bound, xs>>) -> Bool:
  match result:
    case None{}: False{}
    case Some{proof}: True{}

def valid(+n: Nat, +bound: U32, +xs: List<&2, U32>) -> Bool:
  accepted(n, bound, xs, certify(n, bound, xs))

# Semantic theorem, for arbitrary input sizes and labels, not a test fixture.
# The length of any certified partition is exactly the number of inputs.
law partition_length:
  for +n: Nat
  for +bound: U32
  for +xs: List<&2, U32>
  for proof: Partition(n, bound, xs)
  {length(xs) == n : Nat}

def partition_length(n, bound, xs, proof):
  match n xs:
    case 0n Nil{}: {==}
    case 0n Con{x, rest}:
      match proof:
    case 1n+p Nil{}:
      match proof:
    case 1n+p Con{x, +rest}:
      (head, tail) = proof
      %partition_length(p, bound, rest, tail) : {1n+length(rest) == 1n+_ : Nat}
      {==}

def preserves_empty() -> {valid(0n, 0, Nil{}) == True{} : Bool}: {==}
def rejects_missing() -> {valid(3n, 2, [0, 1]) == False{} : Bool}: {==}
def rejects_extra() -> {valid(1n, 2, [0, 1]) == False{} : Bool}: {==}
def rejects_bad_label() -> {valid(2n, 2, [0, 2]) == False{} : Bool}: {==}
def rejects_unassigned() -> {valid(2n, 2, [0, 4294967295]) == False{} : Bool}: {==}
