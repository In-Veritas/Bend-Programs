import Base
# Bottom-up merge sort; copying is required only when both run heads survive
# the comparison in different roles. Merge carries the combined input length
# as explicit structural fuel because its two list arguments shrink in turns.

type Runs:
  RNil{}
  RCon{run: List<U32>, rest: Runs}

assert list_with_length:
  forall values: List<U32>
  List<U32> & Nat

def list_with_length(values):
  match values:
    case Nil{}:
      (Nil{}, 0n)
    case Con{head, tail}:
      (rest, length) = list_with_length(tail)
      (Con{head, rest}, 1n+length)

assert merge.go:
  forall fuel: Nat
  forall xs: List<U32>
  forall ys: List<U32>
  List<U32>

def merge.go(fuel, xs, ys):
  match fuel:
    case 0n:
      match xs:
        case Nil{}:
          ys
        case Con{x, xt}:
          Con{x, xt}
    case 1n+p:
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
              Con{x2, merge.go(p, xt, Con{y2, yt})}
            case False{}:
              Con{y2, merge.go(p, Con{x2, xt}, yt)}

assert merge:
  forall xs: List<U32>
  forall ys: List<U32>
  List<U32>

def merge(xs, ys):
  (xs_ready, xs_length) = list_with_length(xs)
  (ys_ready, ys_length) = list_with_length(ys)
  merge.go(Nat.add(xs_length, ys_length), xs_ready, ys_ready)

assert carry:
  forall rs: Runs
  forall run: List<U32>
  Runs

def carry(rs, run):
  match rs:
    case RNil{}:
      RCon{run, RNil{}}
    case RCon{Nil{}, rest}:
      RCon{run, rest}
    case RCon{Con{h, t}, rest}:
      RCon{Nil{}, carry(rest, merge(Con{h, t}, run))}

assert to_runs:
  forall xs: List<U32>
  Runs

def to_runs(xs):
  match xs:
    case Nil{}:
      RNil{}
    case Con{x, t}:
      carry(to_runs(t), Con{x, Nil{}})

assert collapse:
  forall rs: Runs
  List<U32>

def collapse(rs):
  match rs:
    case RNil{}:
      Nil{}
    case RCon{run, rest}:
      merge(run, collapse(rest))

assert list_eq:
  forall xs: List<U32>
  forall ys: List<U32>
  Bool

def list_eq(xs, ys):
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

assert input:
  List<U32>

def input():
  Con{U32.from_nat(5n), Con{U32.from_nat(3n), Con{U32.from_nat(8n), Con{1, Con{U32.from_nat(9n), Con{U32.from_nat(2n), Con{U32.from_nat(7n), Con{U32.from_nat(6n), Con{U32.from_nat(4n), Nil{}}}}}}}}}}

assert expected:
  List<U32>

def expected():
  Con{1, Con{U32.from_nat(2n), Con{U32.from_nat(3n), Con{U32.from_nat(4n), Con{U32.from_nat(5n), Con{U32.from_nat(6n), Con{U32.from_nat(7n), Con{U32.from_nat(8n), Con{U32.from_nat(9n), Nil{}}}}}}}}}}

assert main_value:
  Bool

def main_value():
  list_eq(collapse(to_runs(input())), expected())

assert main_show_bool:
  forall value: Bool
  IO(Unit)

def main_show_bool(value):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

assert main:
  IO(Unit)

def main():
  main_show_bool(main_value!())
