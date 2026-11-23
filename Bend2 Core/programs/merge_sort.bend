import Base
# Bottom-up merge sort. `merge` alternately rebuilds one list while shrinking
# the other, so it counts down a Nat fuel (the total length) instead of the
# `#[halts]` license Bend2 Core needed. Run heads are reusable `+U32` values.

type Runs is Data:
  RNil{}
  RCon{run: List<&2, U32>, rest: Runs}

def branch(c: Bool, t: Unit -> List<&2, U32>, f: Unit -> List<&2, U32>) -> List<&2, U32>:
  match c:
    case True{}:
      t(Unit{})
    case False{}:
      f(Unit{})

# fuel >= length(xs) + length(ys) is enough: each step emits one head
def merge.go(+fuel: Nat, xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      List.append(&2, U32, xs, ys)
    case 1n+f:
      match xs ys:
        case Nil{} ys:
          ys
        case Con{x, xt} Nil{}:
          Con{x, xt}
        case Con{+x, +xt} Con{+y, +yt}:
          branch(U32.is_le(x, y),
            u => Con{x, merge.go(f, xt, Con{y, yt})},
            u => Con{y, merge.go(f, Con{x, xt}, yt)})

def merge(+xs: List<&2, U32>, +ys: List<&2, U32>) -> List<&2, U32>:
  merge.go(Nat.add(List.length(&2, U32, xs), List.length(&2, U32, ys)), xs, ys)

def carry(rs: Runs, run: List<&2, U32>) -> Runs:
  match rs:
    case RNil{}:
      RCon{run, RNil{}}
    case RCon{Nil{}, rest}:
      RCon{run, rest}
    case RCon{Con{h, t}, rest}:
      RCon{Nil{}, carry(rest, merge(Con{h, t}, run))}

def to_runs(xs: List<&2, U32>) -> Runs:
  match xs:
    case Nil{}:
      RNil{}
    case Con{x, t}:
      carry(to_runs(t), Con{x, Nil{}})

def collapse(rs: Runs) -> List<&2, U32>:
  match rs:
    case RNil{}:
      Nil{}
    case RCon{run, rest}:
      merge(run, collapse(rest))

def list_eq(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      Bool.and(U32.is_eq(x, y), list_eq(xt, yt))
    case xs ys:
      False{}

def input() -> List<&2, U32>:
  Con{5, Con{3, Con{8, Con{1, Con{9, Con{2, Con{7, Con{6, Con{4, Nil{}}}}}}}}}}

def expected() -> List<&2, U32>:
  Con{1, Con{2, Con{3, Con{4, Con{5, Con{6, Con{7, Con{8, Con{9, Nil{}}}}}}}}}}

def main_value() -> Bool:
  list_eq(collapse(to_runs(input())), expected())

# The executable entry prints the pure self-check, so `bend FILE`, a native
# build and the JS build all report True{} through the same IO path.
def main_show_bool(value: Bool) -> IO(Unit):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

def main() -> IO(Unit):
  main_show_bool(main_value())
