# igraph 0.10.10 PCG32, bounded integer sampling, and binary64 uniform draws.
import Base
import ./f64.bend as F
import ./cl_leiden_state.bend as S

def when(-A: Type, c: Bool, k: Bool -> A) -> A:
  k(c)

def draw(s: S.S) -> S.S & U32:
  S.pair(S.S, U32, S.S & U32, S.rh_get(s), s => +h =>
  S.pair(S.S, U32, S.S & U32, S.rl_get(s), s => +l =>
  S.pair(U32, U32, S.S & U32, F.mul32(l, 1284865837), +ph => +pl => (
  +nl = U32.add(pl, 2495175643)
  +nh = U32.add(U32.add(U32.add(U32.add(ph, U32.mul(h, 1284865837)),
    U32.mul(l, 1481765933)), 3661511115), F.b2u(U32.is_lt(nl, pl)))
  +xh = U32.xor(U32.shrn(h, 18n), h)
  +xl = U32.xor(U32.or(U32.shrn(l, 18n), U32.shln(h, 14n)), l)
  +xs = U32.or(U32.shrn(xl, 27n), U32.shln(xh, 5n))
  +rot = U32.shrn(h, 27n)
  +r = U32.or(F.shr(xs, rot), F.shl(xs, U32.and(U32.sub(0, rot), 31)))
  (S.rl_set(S.rh_set(s, nh), nl), r)))))

def integer_go(fuel: Nat, s: S.S, +range: U32, +threshold: U32) -> S.S & U32:
  match fuel:
    case 0n:
      (S.err_set(s, True{}), 0)
    case 1n+p:
      S.pair(S.S, U32, S.S & U32, draw(s), s => x =>
      S.pair(U32, U32, S.S & U32, F.mul32(x, range), +hi => +lo =>
      when(S.S & U32, U32.is_ge(lo, threshold), \{
        True: (s, hi)
        False: integer_go(p, s, range, threshold)
      })))

def integer(s: S.S, +range: U32) -> S.S & U32:
  when(S.S & U32, U32.is_le(range, 1), \{
    True: (s, 0)
    False: integer_go(128n, s, range, U32.mod(U32.sub(0, range), range))
  })

def uniform01(s: S.S) -> S.S & F.D:
  S.pair(S.S, U32, S.S & F.D, draw(s), s => +a =>
  S.pair(S.S, U32, S.S & F.D, draw(s), s => +b => (
  +h = U32.or(1072693248, U32.and(U32.shrn(a, 12n), 1048575))
  +l = U32.or(U32.shln(a, 20n), U32.shrn(b, 12n))
  (s, F.d_sub(F.D{h, l}, F.D{1072693248, 0})))))

def uniform_go(fuel: Nat, s: S.S, +hi: F.D) -> S.S & F.D:
  match fuel:
    case 0n:
      (S.err_set(s, True{}), F.D{0, 0})
    case 1n+p:
      S.pair(S.S, F.D, S.S & F.D, uniform01(s), s => r => (
      +v = F.d_mul(r, hi)
      when(S.S & F.D, F.d_eq(v, hi), \{
        True: uniform_go(p, s, hi)
        False: (s, v)
      })))

def uniform(s: S.S, +hi: F.D) -> S.S & F.D:
  when(S.S & F.D, F.d_eq(hi, F.D{0, 0}), \{
    True: (s, hi)
    False: uniform_go(128n, s, hi)
  })

def shuffle_go(fuel: Nat, s: S.S, +n: U32) -> S.S:
  match fuel:
    case 0n:
      s
    case 1n+p:
      +last = U32.sub(n, 1)
      S.pair(S.S, U32, S.S, integer(s, n), s => +k =>
      S.pair(S.S, U32, S.S, S.order_get(s, last), s => a =>
      S.pair(S.S, U32, S.S, S.order_get(s, k), s => b =>
        shuffle_go(p, S.order_set(S.order_set(s, last, b), k, a), last))))

def shuffle(s: S.S, +n: U32) -> S.S:
  shuffle_go(U32.to_nat(U32.sub(U32.max(n, 1), 1)), s, n)
