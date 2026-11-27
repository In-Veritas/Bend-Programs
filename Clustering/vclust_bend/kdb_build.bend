# kmer-db build -multisample-fasta (console_build.cpp, loader_ex.cpp).
#
# The loader extracts samples (k-mers, filter, sortAndUnique) in parallel
# while the database adds the previously loaded samples one after another,
# in file order (CLoaderEx's loading threads feeding BuildConsole's
# addKmers loop). Here: the records are taken in chunks; the k-mers of a
# chunk are extracted by a parallel fork-join over its samples while the
# previous chunk is added to the database (one parallel call).
import Base
import ./pf_fasta.bend as F
import ./kdb_util.bend as K
import ./kdb_extract.bend as X
import ./kdb_db.bend as D

# A tree of records (for the parallel extraction) and of extracted samples.
type RT is Type:
  RTNil{}
  RTLeaf{r: F.Raw}
  RTNode{l: RT, r: RT}

type ET is Type:
  ETNil{}
  ETLeaf{s: X.Smp}
  ETNode{l: ET, r: ET}

def rt_leaf(empty: Bool, xs: F.Raws) -> RT & F.Raws:
  match empty xs:
    case True{} _:
      (RTNil{}, xs)
    case False{} F.RawNil{}:
      (RTNil{}, F.RawNil{})
    case False{} F.RawCon{h, t}:
      (RTLeaf{h}, t)

# a balanced tree of the next cnt records (cnt <= 2^d)
def rt_build(+d: Nat, +cnt: U32, xs: F.Raws) -> RT & F.Raws:
  match d:
    case 0n:
      rt_leaf(U32.is_eq(cnt, 0), xs)
    case 1n+p:
      +nl = U32.shrn((cnt + 1 : U32), 1n)
      K.apply(RT & F.Raws, RT & F.Raws, \{Tuple: l => rest => (
        K.apply(RT & F.Raws, RT & F.Raws, \{Tuple: r => rest2 => (
          (RTNode{l, r}, rest2)
        )}, rt_build(p, (cnt - nl : U32), rest))
      )}, rt_build(p, nl, xs))

def extract_all(t: RT, +c: X.Cfg) -> ET:
  match t:
    case RTNil{}:
      ETNil{}
    case RTLeaf{r}:
      ETLeaf{X.extract(c, r)}
    case RTNode{l, r}:
      a b = extract_all(l, c) extract_all(r, c)
      ETNode{a, b}

# the samples of a tree, added in order: sampleKmersCount and addKmers
type BS is Type:
  BS{db: D.DB, cnt: Array<U32>, +s: U32}

def bs_add(st: BS, smp: X.Smp) -> BS:
  BS{db, cnt, +s} = st
  X.Smp{+n, km} = smp
  BS{D.add_kmers(db, s, n, km), cnt[s] <- n, (s + 1 : U32)}

def add_all(t: ET, st: BS) -> BS:
  match t:
    case ETNil{}:
      st
    case ETLeaf{s}:
      bs_add(st, s)
    case ETNode{l, r}:
      add_all(r, add_all(l, st))

# The loader: the current chunk (extracted, waiting to be added), the rest.
type LD is Type:
  LD{st: BS, cur: ET, rest: F.Raws, +more: Bool}

def ld_chunk(+csz: U32, xs: F.Raws) -> RT & F.Raws:
  rt_build(F.depth(csz), csz, xs)

def ld_more(st: BS, cur: ET, rest: F.Raws) -> LD:
  match rest:
    case F.RawNil{}:
      LD{st, cur, F.RawNil{}, False{}}
    case F.RawCon{h, t}:
      LD{st, cur, F.RawCon{h, t}, True{}}

def ld_step(+c: X.Cfg, +csz: U32, st: BS, cur: ET, r: RT & F.Raws) -> LD:
  (t, rest) = r
  a b = extract_all(t, c) add_all(cur, st)
  ld_more(b, a, rest)

def ld_go(f: Nat, +c: X.Cfg, +csz: U32, st: LD) -> LD:
  match f st:
    case 0n _:
      st
    case 1n+q LD{bs, cur, rest, +more}:
      match more:
        case True{}:
          ld_go(q, c, csz, ld_step(c, csz, bs, cur, ld_chunk(csz, rest)))
        case False{}:
          LD{bs, cur, rest, False{}}

def ld_fin(st: LD) -> BS:
  LD{bs, cur, rest, more} = st
  add_all(cur, bs)

# build: the database and the per-sample k-mer counts; csz records per chunk
def build(+n: U32, +c: X.Cfg, +csz: U32, xs: F.Raws) -> BS:
  X.Cfg{+k, +himask, +lomask, +rhu, +rlu, +usef, +th, +kd4, +psh} = c
  ld_fin(ld_go(U32.to_nat((U32.div(n, csz) + 2 : U32)), c, csz,
    ld_more(BS{D.db_new(X.prefix_bits(k)), K.arr_new(n), 0}, ETNil{}, xs)))
