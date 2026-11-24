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

def read_got(r: File & Result<&1, &1, U32 & String, List<&2, U32>>, st: PT,
             k: File -> PT -> IO(PT)) -> IO(PT):
  (f, res) = r
  match res:
    case Fail{e}:
      do IO<PT>:
        File.close(f)
        return st
    case Done{xs}:
      match xs:
        case Nil{}:
          do IO<PT>:
            File.close(f)
            return st
        case Con{+h, t}:
          k(f, chunk_go(Con{h, t}, st))

def read_loop(fuel: Nat, f: File, st: PT) -> IO(PT):
  match fuel:
    case 0n:
      do IO<PT>:
        File.close(f)
        return st
    case 1n+p:
      do IO<PT>:
        r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 1048576)
        read_got(r, st, g => s2 => read_loop(p, g, s2))

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

def parsed_of(s: PS) -> Parsed:
  PS{mode, name, buf, wpos, sn, cur, segs, len, k, raws, names, count} = s
  Parsed{raws_reverse(raws, RawNil{}), names_reverse(names, Nil{}), count}

def parsed_fin(st: PT) -> Parsed:
  PT{s, tbl} = st
  parsed_of(final_m(get_mode(s)))

# Reads a FASTA file; k is the k-mer length (shorter segments are dropped).
def read_fasta(path: String, +k: U32) -> IO(Parsed):
  do IO<Parsed>:
    f : File <- IO.try(File, File.open(path, "r"))
    st : PT <- read_loop(U32.to_nat(4194304), f,
      PT{PS{0, Nil{}, [0 : U32^22n], 0, 0, 0, SegNil{}, 0, k, RawNil{}, Nil{}, 0}, table()})
    return parsed_fin(st)
