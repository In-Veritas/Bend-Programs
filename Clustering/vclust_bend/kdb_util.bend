# Small shared helpers of the Kmer-db port (prefilter): U32 selection and
# shifts, 4-word records in an Array<U32>, prefix sums, decimal output of
# the distance values (Kmer-db's Double2PChar with 6 decimals, see pf_num).
import Base
import ./pf_fasta.bend as F
import ./pf_num.bend as N

def sel(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def b2u(c: Bool) -> U32:
  sel(c, 1, 0)

def shl(x: U32, s: U32) -> U32:
  U32.shln(x, U32.to_nat(s))

def shr(x: U32, s: U32) -> U32:
  U32.shrn(x, U32.to_nat(s))


# Arrays
# ======

def arr_new(+n: U32) -> Array<U32>:
  Array.new(U32, F.depth(U32.max(n, 1)), 0)

def bump_at(+i: U32, +d: U32, r: Array<U32> & U32) -> Array<U32>:
  (a, +v) = r
  a[i] <- (v + d : U32)

def bump(+i: U32, +d: U32, a: Array<U32>) -> Array<U32>:
  bump_at(i, d, a[i])


# prefix sums in place: a[i] = a[0] + .. + a[i]
type PF is Type:
  PF{a: Array<U32>, +i: U32, +acc: U32}

def pf_r(+i: U32, +acc: U32, r: Array<U32> & U32) -> PF:
  (a, +v) = r
  +s = (acc + v : U32)
  PF{a[i] <- s, (i + 1 : U32), s}

def pf_step(st: PF) -> PF:
  PF{a, +i, +acc} = st
  pf_r(i, acc, a[i])

def pf_go(n: Nat, st: PF) -> PF:
  match n:
    case 0n:
      st
    case 1n+p:
      pf_go(p, pf_step(st))

def pf_fin(st: PF) -> Array<U32>:
  PF{a, i, acc} = st
  a

def prefix(+n: U32, a: Array<U32>) -> Array<U32>:
  pf_fin(pf_go(U32.to_nat(n), PF{a, 0, 0}))


type R4A is Type:
  R4A{a: Array<U32>, +x0: U32, +x1: U32, +x2: U32, +x3: U32}

def rg4(+x0: U32, +x1: U32, +x2: U32, r: Array<U32> & U32) -> R4A:
  (a, +x3) = r
  R4A{a, x0, x1, x2, x3}

def rg3(+o: U32, +x0: U32, +x1: U32, r: Array<U32> & U32) -> R4A:
  (a, +x2) = r
  rg4(x0, x1, x2, a[(o + 3 : U32)])

def rg2(+o: U32, +x0: U32, r: Array<U32> & U32) -> R4A:
  (a, +x1) = r
  rg3(o, x0, x1, a[(o + 2 : U32)])

def rg1(+o: U32, r: Array<U32> & U32) -> R4A:
  (a, +x0) = r
  rg2(o, x0, a[(o + 1 : U32)])

# record at slot i (4 words)
def rec_get(a: Array<U32>, +i: U32) -> R4A:
  +o = U32.shln(i, 2n)
  rg1(o, a[o])

def rec_put(a: Array<U32>, +i: U32, +x0: U32, +x1: U32, +x2: U32, +x3: U32) -> Array<U32>:
  +o = U32.shln(i, 2n)
  a1 = a[o] <- x0
  a2 = a1[(o + 1 : U32)] <- x1
  a3 = a2[(o + 2 : U32)] <- x2
  a3[(o + 3 : U32)] <- x3

type IS is Type:
  IS{a: Array<U32>, +j: U32, +go: Bool}

def is_swap(sw: Bool, +j: U32, +a0: U32, +a1: U32, +a2: U32, +a3: U32, b: R4A) -> IS:
  match sw:
    case True{}:
      R4A{arr, +b0, +b1, +b2, +b3} = b
      IS{rec_put(rec_put(arr, (j - 1 : U32), b0, b1, b2, b3), j, a0, a1, a2, a3), (j - 1 : U32), True{}}
    case False{}:
      R4A{arr, b0, b1, b2, b3} = b
      IS{arr, j, False{}}

def is_cmp(+j: U32, +a0: U32, +a1: U32, +a2: U32, +a3: U32, b: R4A) -> IS:
  R4A{arr, +b0, +b1, +b2, +b3} = b
  is_swap(U32.is_gt(a0, b0) || (U32.is_eq(a0, b0) && U32.is_gt(a1, b1)), j, a0, a1, a2, a3,
    R4A{arr, b0, b1, b2, b3})

def is_b(+j: U32, a: R4A) -> IS:
  R4A{arr, +a0, +a1, +a2, +a3} = a
  is_cmp(j, a0, a1, a2, a3, rec_get(arr, j))

def is_step(st: IS) -> IS:
  IS{a, +j, +go} = st
  match go:
    case True{}:
      is_b(j, rec_get(a, (j - 1 : U32)))
    case False{}:
      IS{a, j, False{}}

def ins_go(n: Nat, st: IS) -> IS:
  match n:
    case 0n:
      st
    case 1n+p:
      ins_go(p, is_step(st))

def is_fin(st: IS) -> Array<U32>:
  IS{a, j, go} = st
  a

# insertion sort of the records [lo, lo + n + 1): insert i = lo+1 ..
def rs_go(n: Nat, +i: U32, +lo: U32, a: Array<U32>) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      rs_go(p, (i + 1 : U32), lo, is_fin(ins_go(U32.to_nat((i - lo : U32)), IS{a, i, True{}})))


def put_digits(fuel: Nat, +v: U32, xs: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      xs
    case 1n+p:
      put_digits(p, U32.div(v, 10), Con{(U32.mod(v, 10) + 48 : U32), xs})

def ndigits(+v: U32) -> U32:
  (1 + b2u(U32.is_ge(v, 10)) + b2u(U32.is_ge(v, 100)) + b2u(U32.is_ge(v, 1000)) + b2u(U32.is_ge(v, 10000))
     + b2u(U32.is_ge(v, 100000)) + b2u(U32.is_ge(v, 1000000)) + b2u(U32.is_ge(v, 10000000))
     + b2u(U32.is_ge(v, 100000000)) + b2u(U32.is_ge(v, 1000000000)) : U32)

# "<v>" before xs
def put_num(+v: U32, xs: List<&2, U32>) -> List<&2, U32>:
  put_digits(U32.to_nat(ndigits(v)), v, xs)

# "<j>:<x/1e6 with 6 decimals>," before xs
def put_entry(+j: U32, +x: U32, xs: List<&2, U32>) -> List<&2, U32>:
  +one = U32.is_ge(x, 1000000)
  +frac = put_digits(6n, sel(one, 0, x), Con{44, xs})
  put_num(j, Con{58, Con{sel(one, 49, 48), Con{46, frac}}})

# Without --max-seqs a kept entry is its output text; with it, the words
# a, c, m, x (for the per-row selection that follows).
def fr_keep(ok: Bool, raw: Bool, +a: U32, +c: U32, +mn: U32, +x: U32, row: List<&2, U32>) -> List<&2, U32>:
  match ok raw:
    case True{} False{}:
      put_entry((a + 1 : U32), x, row)
    case True{} True{}:
      Con{a, Con{c, Con{mn, Con{x, row}}}}
    case False{} _:
      row


def apply(-A: Type, -B: Type, body: A -> B, value: A) -> B:
  body(value)

# 0xFFFFFFFF stands for -1 (no parent / no node)
def none() -> U32:
  4294967295

def get_r(r: Array<U32> & U32) -> U32:
  (a, +v) = r
  v

def when(-A: Type, c: Bool, k: Bool -> A) -> A:
  k(c)
