# Streaming byte parsers for the Vclust `align` stage.
#
# FASTA: CSeqReservoir::load_multifasta semantics (refresh getline: lines
# split at '\n', one trailing '\r' removed, empty lines skipped, the record
# name is the header after '>' up to the first ' ', a record with an empty
# header line is dropped, symbols other than ACGTacgt are N). The caller
# limits the input to the bytes up to the last '\n' (getline drops a final
# unterminated line).
#
# Kmer-db filter: CFilter::load_filter semantics (first line: names after
# the first comma-separated field; every following line longer than two
# bytes is a row; entries "j:value" with exactly one ':'; kept when
# value >= threshold, compared exactly at 10^-9 resolution).
import Base
import ./align_num.bend as N
import ./align_lz.bend as L

def when(-A: Type, c: Bool, k: Bool -> A) -> A:
  k(c)

def rev(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{+x, rest}:
      rev(rest, x <> acc)

# FASTA
# =====

type Rec is Data:
  Rec{name: List<&2, U32>, seq: L.Seq}

# sequence under construction
type SB is Data:
  SB{len: U32, word: U32, wn: U32, words: List<&2, U32>, nrs: L.NRun,
    nstart: U32, nlen: U32}

def sb_new() -> SB:
  SB{0, 0, 0, Nil{}, L.NRNil{}, 0, 0}

# 0..3 for ACGT/acgt, 4 (N) otherwise
def code_of(+c: U32) -> U32:
  +lc = U32.or(c, 32)
  N.u32_if(U32.is_eq(lc, 97), 0, N.u32_if(U32.is_eq(lc, 99), 1,
    N.u32_if(U32.is_eq(lc, 103), 2, N.u32_if(U32.is_eq(lc, 116), 3, 4))))

def nr_push(c: Bool, +pos: U32, +len: U32, nrs: L.NRun) -> L.NRun:
  match c:
    case True{}:
      L.NRCon{pos, len, nrs}
    case False{}:
      nrs

def w_push(c: Bool, +w: U32, ws: List<&2, U32>) -> List<&2, U32>:
  match c:
    case True{}:
      w <> ws
    case False{}:
      ws

def sb_push(+code: U32, s: SB) -> SB:
  match s:
    case SB{+len, +word, +wn, words, nrs, +nstart, +nlen}:
      +isn = U32.is_eq(code, 4)
      +word2 = N.u32_if(isn, word, U32.or(word, U32.shln(code, U32.to_nat((wn + wn : U32)))))
      +full = U32.is_eq(wn, 15)
      +ext = isn && U32.is_gt(nlen, 0) && U32.is_eq((nstart + nlen : U32), len)
      +newrun = isn && Bool.not(ext)
      SB{(len + 1 : U32), N.u32_if(full, 0, word2), N.u32_if(full, 0, (wn + 1 : U32)),
        w_push(full, word2, words), nr_push(newrun && U32.is_gt(nlen, 0), nstart, nlen, nrs),
        N.u32_if(newrun, len, nstart),
        N.u32_if(newrun, 1, N.u32_if(ext, (nlen + 1 : U32), nlen))}

def ws_build(xs: List<&2, U32>) -> L.Ws:
  match xs:
    case Nil{}:
      L.WsNil{}
    case Con{+a, Nil{}}:
      L.Ws4{a, 0, 0, 0, L.WsNil{}}
    case Con{+a, Con{+b, Nil{}}}:
      L.Ws4{a, b, 0, 0, L.WsNil{}}
    case Con{+a, Con{+b, Con{+c, Nil{}}}}:
      L.Ws4{a, b, c, 0, L.WsNil{}}
    case Con{+a, Con{+b, Con{+c, Con{+d, rest}}}}:
      L.Ws4{a, b, c, d, ws_build(rest)}

def sb_finish(s: SB) -> L.Seq:
  match s:
    case SB{+len, +word, +wn, words, nrs, +nstart, +nlen}:
      L.Seq{len, ws_build(rev(w_push(U32.is_gt(wn, 0), word, words), Nil{})),
        nr_push(U32.is_gt(nlen, 0), nstart, nlen, nrs)}

# header under construction: name bytes (reversed), seen ' ', any byte
type HD is Data:
  HD{hname: List<&2, U32>, hsp: Bool, hany: Bool}

def hd_char(+x: U32, h: HD) -> HD:
  match h:
    case HD{hname, hsp, hany}:
      match hsp:
        case True{}:
          HD{hname, True{}, True{}}
        case False{}:
          HD{w_push(U32.is_ne(x, 32), x, hname), U32.is_eq(x, 32), True{}}

def hd_cr(cr: Bool, h: HD) -> HD:
  match cr:
    case True{}:
      hd_char(13, h)
    case False{}:
      h

def sb_cr(cr: Bool, sb: SB) -> SB:
  match cr:
    case True{}:
      sb_push(4, sb)
    case False{}:
      sb

# mode: 0 line start, 1 header, 2 sequence line; cr: a '\r' is pending
type FS is Data:
  FS{left: U32, mode: U32, cr: Bool, hd: HD, have: Bool, name: List<&2, U32>,
    sb: SB, recs: List<&2, Rec>}

def fs_new(+limit: U32) -> FS:
  FS{limit, 0, False{}, HD{Nil{}, False{}, False{}}, False{}, Nil{}, sb_new(), Nil{}}

def fs_close(have: Bool, +name: List<&2, U32>, +sb: SB, recs: List<&2, Rec>) -> List<&2, Rec>:
  match have:
    case True{}:
      Rec{name, sb_finish(sb)} <> recs
    case False{}:
      recs

def sb_byte(iscr: Bool, +c: U32, sb: SB) -> SB:
  match iscr:
    case True{}:
      sb
    case False{}:
      sb_push(code_of(c), sb)

def hd_byte(iscr: Bool, +c: U32, hd: HD) -> HD:
  match iscr:
    case True{}:
      hd
    case False{}:
      hd_char(c, hd)

# a byte on a sequence line (or the first byte of one)
def fs_seq(nl: Bool, +cr: Bool, +c: U32, +left: U32, +hd: HD, +have: Bool,
           +name: List<&2, U32>, +sb: SB, +recs: List<&2, Rec>) -> FS:
  match nl:
    case True{}:
      FS{left, 0, False{}, hd, have, name, sb, recs}
    case False{}:
      FS{left, 2, U32.is_eq(c, 13), hd, have, name,
        sb_byte(U32.is_eq(c, 13), c, sb_cr(cr, sb)), recs}

def fs_hdr(nl: Bool, +cr: Bool, +c: U32, +left: U32, hd: HD, +recs: List<&2, Rec>) -> FS:
  match nl hd:
    case True{} HD{+hname, hsp, +hany}:
      FS{left, 0, False{}, HD{Nil{}, False{}, False{}}, hany, rev(hname, Nil{}), sb_new(), recs}
    case False{} HD{+hname, +hsp, +hany}:
      FS{left, 1, U32.is_eq(c, 13), hd_byte(U32.is_eq(c, 13), c, hd_cr(cr, HD{hname, hsp, hany})),
        False{}, Nil{}, sb_new(), recs}

def fs_start(nl: Bool, gt: Bool, +c: U32, +left: U32, +hd: HD, +have: Bool,
             +name: List<&2, U32>, +sb: SB, +recs: List<&2, Rec>) -> FS:
  match nl gt:
    case True{} _:
      FS{left, 0, False{}, hd, have, name, sb, recs}
    case False{} True{}:
      FS{left, 1, False{}, HD{Nil{}, False{}, False{}}, False{}, Nil{}, sb_new(),
        fs_close(have, name, sb, recs)}
    case False{} False{}:
      fs_seq(False{}, False{}, c, left, hd, have, name, sb, recs)

def fs_mode(m0: Bool, m1: Bool, +c: U32, +left: U32, +cr: Bool, +hd: HD, +have: Bool,
            +name: List<&2, U32>, +sb: SB, +recs: List<&2, Rec>) -> FS:
  match m0 m1:
    case True{} _:
      fs_start(U32.is_eq(c, 10), U32.is_eq(c, 62), c, left, hd, have, name, sb, recs)
    case False{} True{}:
      fs_hdr(U32.is_eq(c, 10), cr, c, left, hd, recs)
    case False{} False{}:
      fs_seq(U32.is_eq(c, 10), cr, c, left, hd, have, name, sb, recs)

def fs_live(live: Bool, +c: U32, +s: FS) -> FS:
  match live s:
    case False{} _:
      s
    case True{} FS{+left, +mode, +cr, +hd, +have, +name, +sb, +recs}:
      fs_mode(U32.is_eq(mode, 0), U32.is_eq(mode, 1), c, (left - 1 : U32), cr, hd, have, name, sb, recs)

def fs_byte(+c: U32, +s: FS) -> FS:
  match s:
    case FS{+left, mode, cr, hd, have, name, sb, recs}:
      fs_live(U32.is_gt(left, 0), c, s)

def fs_feed(bytes: List<&2, U32>, +s: FS) -> FS:
  match bytes:
    case Nil{}:
      s
    case Con{+c, rest}:
      fs_feed(rest, fs_byte(c, s))

def recs_rev(xs: List<&2, Rec>, acc: List<&2, Rec>) -> List<&2, Rec>:
  match xs:
    case Nil{}:
      acc
    case Con{+x, rest}:
      recs_rev(rest, x <> acc)

# the records in file order
def fs_done(s: FS) -> List<&2, Rec>:
  match s:
    case FS{left, mode, cr, hd, +have, +name, +sb, +recs}:
      recs_rev(fs_close(have, name, sb, recs), Nil{})

# Kmer-db filter
# ==============

type P2 is Data:
  P2{i: U32, j: U32}

type NL is Data:
  NLNil{}
  NLCon{name: List<&2, U32>, tail: NL}

# hdr: still on the first line; names (reversed, the first field dropped);
# row: index of the current row line; per entry: colons, id value, id has a
# digit, id parse stopped, value bytes (reversed)
type FL is Data:
  FL{hdr: Bool, nf: U32, cur: List<&2, U32>, names: NL, row: U32, llen: U32,
    first: Bool, colons: U32, idv: U32, idd: Bool, ids: Bool, vb: List<&2, U32>,
    thr: U32, pairs: List<&2, P2>}

def fl_new(+thr: U32) -> FL:
  FL{True{}, 0, Nil{}, NLNil{}, 0, 0, True{}, 0, 0, False{}, False{}, Nil{}, thr, Nil{}}

def nl_push(c: Bool, +x: List<&2, U32>, xs: NL) -> NL:
  match c:
    case True{}:
      NLCon{x, xs}
    case False{}:
      xs

def is_empty(+xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{h, t}:
      False{}

def keep_pair(m: Maybe<&2, U32>, +thr: U32, +row: U32, +idv: U32, ps: List<&2, P2>) -> List<&2, P2>:
  match m:
    case None{}:
      ps
    case Some{+v}:
      when(List<&2, P2>, U32.is_ge(v, thr), \{
        True: P2{row, (idv - 1 : U32)} <> ps
        False: ps
      })

def entry(ok: Bool, +vb: List<&2, U32>, +thr: U32, +row: U32, +idv: U32, ps: List<&2, P2>) -> List<&2, P2>:
  match ok:
    case True{}:
      keep_pair(N.dec_ceil9(rev(vb, Nil{})), thr, row, idv, ps)
    case False{}:
      ps

def fl_hdr(+c: U32, +nf: U32, +cur: List<&2, U32>, +names: NL, +row: U32, +thr: U32) -> FL:
  when(FL, U32.is_eq(c, 10), \{
    True: FL{False{}, (nf + N.b2u(Bool.not(is_empty(cur))) : U32), Nil{},
      nl_push(U32.is_gt(nf, 0) && Bool.not(is_empty(cur)), rev(cur, Nil{}), names),
      row, 0, True{}, 0, 0, False{}, False{}, Nil{}, thr, Nil{}}
    False: when(FL, U32.is_eq(c, 44), \{
      True: FL{True{}, (nf + 1 : U32), Nil{}, nl_push(U32.is_gt(nf, 0), rev(cur, Nil{}), names),
        row, 0, True{}, 0, 0, False{}, False{}, Nil{}, thr, Nil{}}
      False: FL{True{}, nf, w_push(U32.is_ne(c, 13), c, cur), names, row, 0, True{}, 0, 0,
        False{}, False{}, Nil{}, thr, Nil{}}
    })
  })

def fl_row(+c: U32, +nf: U32, +names: NL, +row: U32, +llen: U32, +first: Bool, +colons: U32,
           +idv: U32, +idd: Bool, +ids: Bool, +vb: List<&2, U32>, +thr: U32, +ps: List<&2, P2>) -> FL:
  +ok = U32.is_eq(colons, 1) && idd && Bool.not(is_empty(vb))
  +part = U32.is_gt(colons, 0) || idd || ids || Bool.not(is_empty(vb))
  when(FL, U32.is_eq(c, 10), \{
    True: FL{False{}, nf, Nil{}, names, (row + N.b2u(U32.is_gt(llen, 2)) : U32), 0, True{}, 0, 0,
      False{}, False{}, Nil{}, thr, entry(Bool.not(first) && part && ok, vb, thr, row, idv, ps)}
    False: when(FL, U32.is_eq(c, 13), \{
      True: FL{False{}, nf, Nil{}, names, row, llen, first, colons, idv, idd, ids, vb, thr, ps}
      False: when(FL, U32.is_eq(c, 44), \{
        True: FL{False{}, nf, Nil{}, names, row, (llen + 1 : U32), False{}, 0, 0, False{}, False{},
          Nil{}, thr, entry(Bool.not(first) && ok, vb, thr, row, idv, ps)}
        False: when(FL, U32.is_eq(c, 58), \{
          True: FL{False{}, nf, Nil{}, names, row, (llen + 1 : U32), first, (colons + 1 : U32),
            idv, idd, ids, vb, thr, ps}
          False: (
            +inid = U32.is_eq(colons, 0)
            +dig = N.is_digit(c) && Bool.not(ids)
            FL{False{}, nf, Nil{}, names, row, (llen + 1 : U32), first, colons,
              N.u32_if(inid && dig, (idv * 10 + c - 48 : U32), idv), idd || (inid && dig),
              ids || (inid && Bool.not(N.is_digit(c))),
              w_push(U32.is_eq(colons, 1), c, vb), thr, ps})
        })
      })
    })
  })

def fl_byte(+c: U32, s: FL) -> FL:
  match s:
    case FL{hdr, +nf, +cur, +names, +row, +llen, +first, +colons, +idv, +idd, +ids, +vb, +thr, +ps}:
      match hdr:
        case True{}:
          fl_hdr(c, nf, cur, names, row, thr)
        case False{}:
          fl_row(c, nf, names, row, llen, first, colons, idv, idd, ids, vb, thr, ps)

def fl_feed(bytes: List<&2, U32>, +s: FL) -> FL:
  match bytes:
    case Nil{}:
      s
    case Con{+c, rest}:
      fl_feed(rest, fl_byte(c, s))

def nl_rev(xs: NL, acc: NL) -> NL:
  match xs:
    case NLNil{}:
      acc
    case NLCon{+x, rest}:
      nl_rev(rest, NLCon{x, acc})

# finish (a final line without '\n' still counts, as getline returns it)
def fl_done(s: FL) -> FL:
  fl_byte(10, s)
