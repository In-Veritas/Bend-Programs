# FASTA reader for the Kmer-db-compatible prefilter.
#
# Reproduces Kmer-db 2.3.1 GenomeInputFile::extractSubsequences on a
# multi-FASTA file: a record starts at every '>', its name is the header up
# to the first space (a '\r' just before the '\n' is dropped), '\n' and '\r'
# are removed from the sequence, and every other byte is a symbol. A, C, G,
# T/U (either case) are bases; anything else breaks k-mers (Kmer-db skips
# every k-mer covering it).
#
# The sequence of a record is stored as maximal runs of valid bases
# ("segments"), 2-bit packed 16 per U32 word, each segment starting on a word
# boundary. Segments shorter than k are dropped, since they hold no k-mer.
import Base

# A packed segment: first word, number of bases.
type Seg is Data:
  SegNil{}
  SegCon{+word: U32, +len: U32, tail: Seg}

type Raw is Type:
  Raw{+len: U32, codes: Array<U32>, segs: Seg}

type Raws is Type:
  RawNil{}
  RawCon{head: Raw, tail: Raws}

# Parser state.
#   mode: 0 before the first header, 1 in the name, 2 in the rest of the
#         header, 3 in the sequence
#   name: reversed bytes of the current name
#   buf : packing buffer (cap words), wpos: words used by closed segments
#   sw  : first word of the open segment, sn: its bases, cur: partial word
#   segs: closed segments (reversed), len: bytes of sequence so far
type PS is Type:
  PS{+mode: U32, name: List<&2, U32>, buf: Array<U32>, +wpos: U32,
     +sn: U32, +cur: U32, segs: Seg, +len: U32, +k: U32,
     raws: Raws, names: List<&2, List<&2, U32>>, +count: U32}

def sel(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def shl(x: U32, s: U32) -> U32:
  U32.shln(x, U32.to_nat(s))

def shr(x: U32, s: U32) -> U32:
  U32.shrn(x, U32.to_nat(s))

# Depth d of the smallest array of 2^d slots holding n words (n >= 1).
def depth_go(fuel: Nat, +n: U32, +d: U32, done: Bool) -> U32:
  match fuel done:
    case _ True{}:
      d
    case 0n False{}:
      d
    case 1n+p False{}:
      +d2 = (d + 1 : U32)
      depth_go(p, n, d2, U32.is_ge(shl(1, d2), n))

def depth(+n: U32) -> Nat:
  U32.to_nat(depth_go(31n, n, 0, U32.is_ge(1, n)))

# Copy n words from src[i..] to dst[j..].
def copy_go(n: Nat, +i: U32, +j: U32, dst: Array<U32>, r: Array<U32> & U32) -> Array<U32> & Array<U32>:
  match n:
    case 0n:
      (src, _v) = r
      (src, dst)
    case 1n+p:
      (src, +v) = r
      copy_go(p, (i + 1 : U32), (j + 1 : U32), dst[j] <- v, src[(i + 1 : U32)])

def copy(+n: U32, +i: U32, +j: U32, src: Array<U32>, dst: Array<U32>) -> Array<U32> & Array<U32>:
  copy_go(U32.to_nat(n), i, j, dst, src[i])

# Byte classes: 0..3 bases, 4 invalid symbol, 5 newline / CR, 6 '>'.
def class_of(+b: U32) -> U32:
  +u = U32.and(b, 223)
  sel(U32.is_eq(b, 62), 6, sel(U32.is_eq(b, 10) || U32.is_eq(b, 13), 5,
    sel(U32.is_eq(u, 65), 0, sel(U32.is_eq(u, 67), 1, sel(U32.is_eq(u, 71), 2,
      sel(U32.is_eq(u, 84) || U32.is_eq(u, 85), 3, 4))))))

def table_go(n: Nat, +i: U32, t: Array<U32>) -> Array<U32>:
  match n:
    case 0n:
      t
    case 1n+p:
      table_go(p, (i + 1 : U32), t[i] <- class_of(i))

def table() -> Array<U32>:
  table_go(256n, 0, [0 : U32*256n])

# Close the open segment: flush its partial word, keep it when it holds at
# least k bases, otherwise give its words back.
def seg_keep(keep: Bool, +mode: U32, name: List<&2, U32>, b2: Array<U32>, +wpos: U32, +sn: U32,
             segs: Seg, +len: U32, +k: U32, raws: Raws, names: List<&2, List<&2, U32>>, +count: U32) -> PS:
  match keep:
    case True{}:
      +nw = U32.shrn((sn + 15 : U32), 4n)
      PS{mode, name, b2, (wpos + nw : U32), 0, 0, SegCon{wpos, sn, segs}, len, k, raws, names, count}
    case False{}:
      PS{mode, name, b2, wpos, 0, 0, segs, len, k, raws, names, count}

def seg_close(s: PS) -> PS:
  PS{mode, name, buf, +wpos, +sn, +cur, segs, len, +k, raws, names, count} = s
  +r = U32.and(sn, 15)
  +full = U32.shrn(sn, 4n)
  +word = shr(cur, U32.mul((16 - r : U32), 2))
  b2 = buf[(wpos + full : U32)] <- sel(U32.is_eq(r, 0), 0, word)
  seg_keep(U32.is_ge(sn, k), mode, name, b2, wpos, sn, segs, len, k, raws, names, count)

def seg_reverse(s: Seg, acc: Seg) -> Seg:
  match s:
    case SegNil{}:
      acc
    case SegCon{+w, +l, t}:
      seg_reverse(t, SegCon{w, l, acc})

def bytes_reverse(s: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case Nil{}:
      acc
    case Con{+h, t}:
      bytes_reverse(t, Con{h, acc})

def finish_copy(+mode: U32, name: List<&2, U32>, +wpos: U32, segs: Seg, +len: U32, +k: U32,
                raws: Raws, names: List<&2, List<&2, U32>>, +count: U32,
                r: Array<U32> & Array<U32>) -> PS:
  (buf, codes) = r
  PS{mode, Nil{}, buf, 0, 0, 0, SegNil{}, 0, k,
     RawCon{Raw{len, codes, seg_reverse(segs, SegNil{})}, raws},
     Con{bytes_reverse(name, Nil{}), names}, (count + 1 : U32)}

# End of a record (at the next '>' or at the end of the input).
def finish_closed(s: PS) -> PS:
  PS{mode, name, buf, +wpos, sn, cur, segs, len, k, raws, names, count} = s
  +w = U32.max(wpos, 1)
  finish_copy(mode, name, wpos, segs, len, k, raws, names, count,
    copy(wpos, 0, 0, buf, Array.new(U32, depth(w), 0)))

def finish(s: PS) -> PS:
  finish_closed(seg_close(s))

def push_full(full: Bool, +c2: U32, +mode: U32, name: List<&2, U32>, buf: Array<U32>, +wpos: U32, +sn: U32,
              segs: Seg, +len: U32, +k: U32, raws: Raws, names: List<&2, List<&2, U32>>, +count: U32) -> PS:
  match full:
    case True{}:
      +at = (wpos + U32.shrn(sn, 4n) : U32)
      PS{mode, name, buf[at] <- c2, wpos, (sn + 1 : U32), 0, segs, (len + 1 : U32), k, raws, names, count}
    case False{}:
      PS{mode, name, buf, wpos, (sn + 1 : U32), c2, segs, (len + 1 : U32), k, raws, names, count}

def push_base(+c: U32, s: PS) -> PS:
  PS{mode, name, buf, +wpos, +sn, +cur, segs, +len, k, raws, names, count} = s
  +c2 = U32.or(U32.shrn(cur, 2n), U32.shln(c, 30n))
  push_full(U32.is_eq(U32.and(sn, 15), 15), c2, mode, name, buf, wpos, sn, segs, len, k, raws, names, count)

def bump_len(s: PS) -> PS:
  PS{mode, name, buf, wpos, sn, cur, segs, +len, k, raws, names, count} = s
  PS{mode, name, buf, wpos, sn, cur, segs, (len + 1 : U32), k, raws, names, count}

def set_mode(+m: U32, s: PS) -> PS:
  PS{mode, name, buf, wpos, sn, cur, segs, len, k, raws, names, count} = s
  PS{m, name, buf, wpos, sn, cur, segs, len, k, raws, names, count}

def name_push(+b: U32, s: PS) -> PS:
  PS{mode, name, buf, wpos, sn, cur, segs, len, k, raws, names, count} = s
  PS{mode, Con{b, name}, buf, wpos, sn, cur, segs, len, k, raws, names, count}

def drop_cr_if(cr: Bool, +h: U32, t: List<&2, U32>) -> List<&2, U32>:
  match cr:
    case True{}:
      t
    case False{}:
      Con{h, t}

def drop_cr(name: List<&2, U32>) -> List<&2, U32>:
  match name:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      drop_cr_if(U32.is_eq(h, 13), h, t)

def name_end(s: PS) -> PS:
  PS{mode, name, buf, wpos, sn, cur, segs, len, k, raws, names, count} = s
  PS{3, drop_cr(name), buf, wpos, sn, cur, segs, len, k, raws, names, count}

def get_mode(s: PS) -> PS & U32:
  PS{+mode, name, buf, wpos, sn, cur, segs, len, k, raws, names, count} = s
  (PS{mode, name, buf, wpos, sn, cur, segs, len, k, raws, names, count}, mode)

# One byte of class c (byte value b) in the current mode.
def step_seq(lt4: Bool, is4: Bool, is6: Bool, +c: U32, s: PS) -> PS:
  match lt4 is4 is6:
    case True{} _ _:
      push_base(c, s)
    case False{} True{} _:
      bump_len(seg_close(s))
    case False{} False{} True{}:
      set_mode(1, finish(s))
    case False{} False{} False{}:
      s

def step_name(nl: Bool, sp: Bool, +b: U32, s: PS) -> PS:
  match nl sp:
    case True{} _:
      name_end(s)
    case False{} True{}:
      set_mode(2, s)
    case False{} False{}:
      name_push(b, s)

def step_if(c: Bool, +m: U32, s: PS) -> PS:
  match c:
    case True{}:
      set_mode(m, s)
    case False{}:
      s

def step_mode(m3: Bool, m1: Bool, m2: Bool, +b: U32, +c: U32, s: PS) -> PS:
  match m3 m1 m2:
    case True{} _ _:
      step_seq(U32.is_lt(c, 4), U32.is_eq(c, 4), U32.is_eq(c, 6), c, s)
    case False{} True{} _:
      step_name(U32.is_eq(b, 10), U32.is_eq(b, 32), b, s)
    case False{} False{} True{}:
      step_if(U32.is_eq(b, 10), 3, s)
    case False{} False{} False{}:
      step_if(U32.is_eq(c, 6), 1, s)

def step_at(+b: U32, r: PS & U32, t: Array<U32> & U32) -> PS & Array<U32>:
  (s, +m) = r
  (tbl, +c) = t
  (step_mode(U32.is_eq(m, 3), U32.is_eq(m, 1), U32.is_eq(m, 2), b, c, s), tbl)

type PT is Type:
  PT{s: PS, tbl: Array<U32>}

def chunk_pair(r: PS & Array<U32>) -> PT:
  (s, t) = r
  PT{s, t}

def chunk_go(xs: List<&2, U32>, st: PT) -> PT:
  match xs:
    case Nil{}:
      st
    case Con{+b, rest}:
      PT{s, tbl} = st
      chunk_go(rest, chunk_pair(step_at(b, get_mode(s), tbl[b])))

# Reading
# =======

def final_if(open: Bool, s: PS) -> PS:
  match open:
    case True{}:
      finish(s)
    case False{}:
      s

def final_m(r: PS & U32) -> PS:
  (s, +m) = r
  final_if(U32.is_ne(m, 0), s)

def raws_reverse(xs: Raws, acc: Raws) -> Raws:
  match xs:
    case RawNil{}:
      acc
    case RawCon{h, t}:
      raws_reverse(t, RawCon{h, acc})

def names_reverse(xs: List<&2, List<&2, U32>>, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      names_reverse(t, Con{h, acc})

# The parsed file: records in file order, their names, their count.
type Parsed is Type:
  Parsed{raws: Raws, names: List<&2, List<&2, U32>>, +count: U32}

# Parallel reading
# ================
#
# The file is read in batches of 1 MiB chunks; the chunks of a batch are
# parsed by fork-join. A split point is a '>' right after a '\n': there the
# sequential parser is in mode 0 or 3 with no open record beyond the one the
# '>' closes, so parsing from a split point with a fresh state, and closing
# the last record (final_m) at the next split point, gives the records the
# sequential parse gives (a fresh state and the state after `finish` differ
# only in buffer words that are written before they are read). A chunk is
# cut at its first and last split points (p >= 1, so the '\n' is inside the
# chunk): its body [p, q) is parsed in parallel; head [0, p) and tail
# [q, end) join the neighbouring chunks' pieces, parsed in order.

def ps_fresh(+k: U32, +nbytes: U32) -> PT:
  # words of a record: <= bytes / 16 + one partial word per kept segment
  # (segments are separated by at least one byte): < bytes / 2 + 2
  PT{PS{0, Nil{}, Array.new(U32, depth(U32.add(U32.shrn(nbytes, 1n), 64)), 0), 0, 0, 0, SegNil{}, 0, k,
     RawNil{}, Nil{}, 0}, table()}

# records of a piece, in reverse order (raws, names) and their count
type Pc is Type:
  Pc{raws: Raws, names: List<&2, List<&2, U32>>, +count: U32}

def pc_of(s: PS) -> Pc:
  PS{mode, name, buf, wpos, sn, cur, segs, len, k, raws, names, +count} = s
  Pc{raws, names, count}

def pc_fin(st: PT) -> Pc:
  PT{s, tbl} = st
  pc_of(final_m(get_mode(s)))

# feed n bytes of xs
def feed(n: Nat, xs: List<&2, U32>, st: PT) -> PT:
  match n xs:
    case 0n _:
      st
    case _ Nil{}:
      st
    case 1n+p Con{+b, rest}:
      PT{s, tbl} = st
      feed(p, rest, chunk_pair(step_at(b, get_mode(s), tbl[b])))

def piece(+k: U32, +n: U32, xs: List<&2, U32>) -> Pc:
  pc_fin(feed(U32.to_nat(n), xs, ps_fresh(k, n)))

# first and last split points (0 when none) and the length
type SP is Data:
  SP{+first: U32, +last: U32, +len: U32}

def splits(xs: List<&2, U32>, +prev: U32, +i: U32, +f: U32, +l: U32) -> SP:
  match xs:
    case Nil{}:
      SP{f, l, i}
    case Con{+b, t}:
      +hit = U32.is_eq(b, 62) && U32.is_eq(prev, 10) && U32.is_gt(i, 0)
      splits(t, b, (i + 1 : U32), sel(hit && U32.is_eq(f, 0), i, f), sel(hit, i, l))

def take(n: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match n xs:
    case 0n _:
      Nil{}
    case _ Nil{}:
      Nil{}
    case 1n+p Con{+h, t}:
      Con{h, take(p, t)}

def drop(n: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match n xs:
    case 0n _:
      xs
    case _ Nil{}:
      Nil{}
    case 1n+p Con{h, t}:
      drop(p, t)

# A parsed chunk: has a split point, head bytes, tail bytes, body records.
type CR is Type:
  CR{+has: Bool, +head: List<&2, U32>, +tail: List<&2, U32>, body: Pc}

def sel_list(c: Bool, +a: List<&2, U32>, +b: List<&2, U32>) -> List<&2, U32>:
  match c:
    case True{}:
      a
    case False{}:
      b

def chunk_sp(+k: U32, +xs: List<&2, U32>, +sp: SP) -> CR:
  SP{+f, +l, +n} = sp
  +rest = drop(U32.to_nat(f), xs)
  CR{U32.is_gt(f, 0), sel_list(U32.is_gt(f, 0), take(U32.to_nat(f), xs), xs), drop(U32.to_nat((l - f : U32)), rest),
     piece(k, (l - f : U32), rest)}

def chunk_task(+k: U32, +xs: List<&2, U32>) -> CR:
  chunk_sp(k, xs, splits(xs, 0, 0, 0, 0))

type CT is Type:
  CTNil{}
  CTLeaf{xs: List<&2, U32>}
  CTNode{l: CT, r: CT}

type CO is Type:
  CONil{}
  COLeaf{r: CR}
  CONode{l: CO, r: CO}

def ap(-A: Type, -B: Type, body: A -> B, value: A) -> B:
  body(value)

def ct_tree(+d: Nat, xs: List<&2, List<&2, U32>>) -> CT & List<&2, List<&2, U32>>:
  match d:
    case 0n:
      match xs:
        case Nil{}:
          (CTNil{}, Nil{})
        case Con{h, t}:
          (CTLeaf{h}, t)
    case 1n+p:
      ap(CT & List<&2, List<&2, U32>>, CT & List<&2, List<&2, U32>>, \{Tuple: l => rest => (
        ap(CT & List<&2, List<&2, U32>>, CT & List<&2, List<&2, U32>>, \{Tuple: r => rest2 => (
          (CTNode{l, r}, rest2)
        )}, ct_tree(p, rest))
      )}, ct_tree(p, xs))

def co_join(a: CO, b: CO) -> CO:
  CONode{a, b}

def par_chunks(ct: CT, +k: U32) -> CO:
  match ct:
    case CTNil{}:
      CONil{}
    case CTLeaf{+xs}:
      COLeaf{chunk_task(k, xs)}
    case CTNode{l, r}:
      a b = par_chunks(l, k) par_chunks(r, k)
      co_join(a, b)

# carry: the open piece (bytes in order); done: pieces in reverse order
type FA is Type:
  FA{+carry: List<&2, U32>, done: PL}

type PL is Type:
  PLNil{}
  PLCon{h: Pc, t: PL}

def app(xs: List<&2, U32>, +ys: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      ys
    case Con{+h, t}:
      Con{h, app(t, ys)}

def blen(xs: List<&2, U32>, +n: U32) -> U32:
  match xs:
    case Nil{}:
      n
    case Con{h, t}:
      blen(t, (n + 1 : U32))

def piece_all(+k: U32, +xs: List<&2, U32>) -> Pc:
  piece(k, blen(xs, 0), xs)

def fa_has(has: Bool, +k: U32, +head: List<&2, U32>, +tail: List<&2, U32>, body: Pc, fa: FA) -> FA:
  match has:
    case True{}:
      FA{+carry, done} = fa
      FA{tail, PLCon{body, PLCon{piece_all(k, app(carry, head)), done}}}
    case False{}:
      FA{+carry, done} = fa
      FA{app(carry, head), done}

def fa_add(+k: U32, r: CR, fa: FA) -> FA:
  CR{+has, +head, +tail, body} = r
  fa_has(has, k, head, tail, body, fa)

def co_fold(co: CO, +k: U32, fa: FA) -> FA:
  match co:
    case CONil{}:
      fa
    case COLeaf{r}:
      fa_add(k, r, fa)
    case CONode{l, r}:
      co_fold(r, k, co_fold(l, k, fa))

def cl_rev(xs: List<&2, List<&2, U32>>, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      cl_rev(t, Con{h, acc})

def batch_tree(r: CT & List<&2, List<&2, U32>>, +k: U32, fa: FA) -> FA:
  (ct, rest) = r
  co_fold(par_chunks(ct, k), k, fa)

# chunks in reverse order, at most 32
def fa_batch(cs: List<&2, List<&2, U32>>, +k: U32, fa: FA) -> FA:
  batch_tree(ct_tree(5n, cl_rev(cs, Nil{})), k, fa)

type RB is Type:
  RB{f: File, cs: List<&2, List<&2, U32>>, +eof: Bool}

def rb_res(r: File & Result<&1, &1, U32 & String, List<&2, U32>>, cs: List<&2, List<&2, U32>>,
           k: File -> List<&2, List<&2, U32>> -> IO(RB)) -> IO(RB):
  (f, res) = r
  match res:
    case Fail{e}:
      IO.pure(RB, RB{f, cs, True{}})
    case Done{bs}:
      match bs:
        case Nil{}:
          IO.pure(RB, RB{f, cs, True{}})
        case Con{h, t}:
          k(f, Con{Con{h, t}, cs})

def rb_loop(n: Nat, f: File, cs: List<&2, List<&2, U32>>) -> IO(RB):
  match n:
    case 0n:
      IO.pure(RB, RB{f, cs, False{}})
    case 1n+p:
      do IO<RB>:
        r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 1048576)
        rb_res(r, cs, g => c2 => rb_loop(p, g, c2))

def fa_res(b: RB, +k: U32, fa: FA, kk: File -> FA -> IO(FA)) -> IO(FA):
  RB{f, cs, eof} = b
  match eof:
    case True{}:
      do IO<FA>:
        File.close(f)
        return fa_batch(cs, k, fa)
    case False{}:
      kk(f, fa_batch(cs, k, fa))

def fa_loop(n: Nat, f: File, +k: U32, fa: FA) -> IO(FA):
  match n:
    case 0n:
      do IO<FA>:
        File.close(f)
        return fa
    case 1n+p:
      do IO<FA>:
        b : RB <- rb_loop(12n, f, Nil{})
        fa_res(b, k, fa, g => a2 => fa_loop(p, g, k, a2))

# done lists the pieces last first, and each piece's records last first:
# reversing every piece onto the accumulator, from the last piece to the
# first, gives the records in file order.
def raws_onto(xs: Raws, acc: Raws) -> Raws:
  match xs:
    case RawNil{}:
      acc
    case RawCon{h, t}:
      raws_onto(t, RawCon{h, acc})

def names_onto(xs: List<&2, List<&2, U32>>, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      names_onto(t, Con{h, acc})

def pl_go(xs: PL, rs: Raws, ns: List<&2, List<&2, U32>>, +n: U32) -> Parsed:
  match xs:
    case PLNil{}:
      Parsed{rs, ns, n}
    case PLCon{h, t}:
      Pc{r, m, +c} = h
      pl_go(t, raws_onto(r, rs), names_onto(m, ns), (n + c : U32))

def fa_parsed(+k: U32, fa: FA) -> Parsed:
  FA{+carry, done} = fa
  pl_go(PLCon{piece_all(k, carry), done}, RawNil{}, Nil{}, 0)

# Reads a FASTA file; k is the k-mer length (shorter segments are dropped).
def read_fasta(path: String, +k: U32) -> IO(Parsed):
  do IO<Parsed>:
    f : File <- IO.try(File, File.open(path, "r"))
    fa : FA <- fa_loop(U32.to_nat(4194304), f, k, FA{Nil{}, PLNil{}})
    return fa_parsed(k, fa)
