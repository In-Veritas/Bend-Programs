import Base
import ../../pf_fasta.bend as F
import ../../kdb_extract.bend as X
import ../../kdb_db.bend as D

def add_smp(db: D.DB, +s: U32, smp: X.Smp) -> D.DB:
  X.Smp{+n, km} = smp
  D.add_kmers(db, s, n, km)

def build_go(xs: F.Raws, +c: X.Cfg, +s: U32, db: D.DB) -> D.DB:
  match xs:
    case F.RawNil{}:
      db
    case F.RawCon{h, t}:
      build_go(t, c, (s + 1 : U32), add_smp(db, s, X.extract(c, h)))

def show(r: D.DB & U32) -> String:
  (db, +np) = r
  "patterns " ++ U32.show(np)

def go(p: F.Parsed) -> String:
  F.Parsed{raws, names, +n} = p
  show(D.db_npat(build_go(raws, X.cfg_of(25, "1"), 0, D.db_new(X.prefix_bits(25)))))

def arg1(xs: List<String>) -> String:
  match xs:
    case Con{a, Con{b, t}}:
      b
    case _:
      ""

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    p : F.Parsed <- F.read_fasta(arg1(args), 25)
    IO.print(go(p))

