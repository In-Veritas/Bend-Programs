#[halts]
import Base
# Bottom-up merge sort; copying is required only when both run heads survive
# the comparison in different roles. `#[halts]` is needed because `merge`
# alternately rebuilds one argument while structurally shrinking the other.

type Runs:
  RNil{}
  RCon{run: List<U32>, rest: Runs}

def merge(xs: List<U32>, ys: List<U32>) -> List<U32>:
  match xs ys:
    case Nil{} ys:
      ys
    case Con{x, xt} Nil{}:
      Con{x, xt}
    case Con{x, xt} Con{y, yt}:
      ((x1, ex1), (x2, ex2)) = U32.copy(x)
      ((y1, ey1), (y2, ey2)) = U32.copy(y)
      match U32.is_le(x1, y1):
        case True{}:
          Con{x2, merge(xt, Con{y2, yt})}
        case False{}:
          Con{y2, merge(Con{x2, xt}, yt)}

def carry(rs: Runs, run: List<U32>) -> Runs:
  match rs:
    case RNil{}:
      RCon{run, RNil{}}
    case RCon{Nil{}, rest}:
      RCon{run, rest}
    case RCon{Con{h, t}, rest}:
      RCon{Nil{}, carry(rest, merge(Con{h, t}, run))}

def to_runs(xs: List<U32>) -> Runs:
  match xs:
    case Nil{}:
      RNil{}
    case Con{x, t}:
      carry(to_runs(t), Con{x, Nil{}})

def collapse(rs: Runs) -> List<U32>:
  match rs:
    case RNil{}:
      Nil{}
    case RCon{run, rest}:
      merge(run, collapse(rest))

def list_eq(xs: List<U32>, ys: List<U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      match U32.is_eq(x, y):
        case True{}:
          list_eq(xt, yt)
        case False{}:
          False{}
    case xs ys:
      False{}

def input() -> List<U32>:
  Con{U32.from_nat(5n), Con{U32.from_nat(3n), Con{U32.from_nat(8n), Con{U32.one(), Con{U32.from_nat(9n), Con{U32.from_nat(2n), Con{U32.from_nat(7n), Con{U32.from_nat(6n), Con{U32.from_nat(4n), Nil{}}}}}}}}}}

def expected() -> List<U32>:
  Con{U32.one(), Con{U32.from_nat(2n), Con{U32.from_nat(3n), Con{U32.from_nat(4n), Con{U32.from_nat(5n), Con{U32.from_nat(6n), Con{U32.from_nat(7n), Con{U32.from_nat(8n), Con{U32.from_nat(9n), Nil{}}}}}}}}}}

def main() -> Bool:
  list_eq(collapse(to_runs(input())), expected())
