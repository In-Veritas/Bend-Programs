import Base
# gabs4: how much do two texts resemble each other? Ported from Bend3; Bend2
# Core lacked argv and file effects, so it was unsupported there.
#
# Reads a reference file and a text file named on the command line, splits
# both into lowercase words (apostrophes vanish, every other non-letter
# separates), and reports their vocabulary overlap as a percentage:
# 100 * shared distinct words / total distinct words (Jaccard). Identical
# texts score 100%; texts with no words in common score 0%.
#
# The Bend3 tokenizer was five mutually recursive defs (needing --no-halt);
# Bend forbids mutual recursion, so here one structural pass over the text
# threads a Tok state, and each character's class is computed by a helper.
#
#   bend gabs4.bend fixtures/reference.txt fixtures/other.txt

type CharClass is Data:
  Letter{code: U32}
  Apostrophe{}
  Separator{}

# the word being read (reversed) and the words already read (reversed)
type Tok is Data:
  Tok{cur: String, out: List<&2, String>}

# character classes
def lower(+c: U32) -> U32:
  Bool.pick(U32, Bool.and(U32.is_le(65, c), U32.is_le(c, 90)), U32.add(c, 32), c)

def is_letter(+c: U32) -> Bool:
  Bool.and(U32.is_le(97, c), U32.is_le(c, 122))

def class_of(+u: U32) -> CharClass:
  Bool.pick(CharClass, is_letter(u), Letter{u},
    Bool.pick(CharClass, U32.is_eq(u, 39), Apostrophe{}, Separator{}))

def classify(c: Char) -> CharClass:
  match c:
    case Chr{code}:
      class_of(lower(code))

# end the current word, if there is one
def flush(cur: String, out: List<&2, String>) -> Tok:
  match cur:
    case SNil{}:
      Tok{SNil{}, out}
    case SCon{h, t}:
      Tok{SNil{}, Con{String.reverse(SCon{h, t}), out}}

def step(k: CharClass, st: Tok) -> Tok:
  match k st:
    case Letter{u} Tok{cur, out}:
      Tok{SCon{Chr{u}, cur}, out}
    case Apostrophe{} st:
      st
    case Separator{} Tok{cur, out}:
      flush(cur, out)

def tokenize(s: String, st: Tok) -> Tok:
  match s:
    case SNil{}:
      st
    case SCon{c, t}:
      tokenize(t, step(classify(c), st))

def finish.out(st: Tok) -> List<&2, String>:
  match st:
    case Tok{cur, out}:
      List.reverse(&2, String, out)

def finish(st: Tok) -> List<&2, String>:
  match st:
    case Tok{cur, out}:
      finish.out(flush(cur, out))

def words(s: String) -> List<&2, String>:
  finish(tokenize(s, Tok{SNil{}, Nil{}}))

# membership of a word in a word list
def has(ws: List<&2, String>, +x: String) -> Bool:
  match ws:
    case Nil{}:
      False{}
    case Con{w, rest}:
      Bool.or(String.eq(w, x), has(rest, x))

# drop repeated words (keeps the last occurrence)
def dedup.put(seen: Bool, w: String, rest: List<&2, String>) -> List<&2, String>:
  match seen:
    case True{}:
      rest
    case False{}:
      Con{w, rest}

def dedup(ws: List<&2, String>) -> List<&2, String>:
  match ws:
    case Nil{}:
      Nil{}
    case Con{+w, +rest}:
      dedup.put(has(rest, w), w, dedup(rest))

# how many words of the first list appear in the second
def score(a: List<&2, String>, +ws: List<&2, String>) -> U32:
  match a:
    case Nil{}:
      0
    case Con{v, vs}:
      U32.add(Bool.to_u32(has(ws, v)), score(vs, ws))

# Jaccard: shared / (|a| + |b| - shared), as a percentage
def report.go(+i: U32, +u: U32) -> String:
  pct = U32.div(U32.mul(i, 100), U32.add(u, Bool.to_u32(U32.is_zero(u))))
  "the texts are " ++ U32.show(pct) ++ "% alike (" ++ U32.show(i) ++ " of " ++ U32.show(u) ++ " distinct words shared)\n"

def report.sets(+wa: List<&2, String>, +wb: List<&2, String>) -> String:
  +i = score(wa, wb)
  la = U32.from_nat(List.length(&2, String, wa))
  lb = U32.from_nat(List.length(&2, String, wb))
  report.go(i, U32.sub(U32.add(la, lb), i))

def report(ta: String, tb: String) -> String:
  report.sets(dedup(words(ta)), dedup(words(tb)))

# a whole text file, closed after reading
def read_done(m: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  (f, r) = m
  do IO<String>:
    File.close(f)
    IO.pass(String, r)

def read_text(path: String) -> IO(String):
  do IO<String>:
    f : File <- IO.try(File, File.open(path, "r"))
    m : File & Result<&1, &1, U32 & String, String> <- File.read(f, 16777216)
    read_done(m)

def start(args: List<String>) -> IO(U32):
  match args:
    case Con{program, Con{pa, Con{pb, rest}}}:
      do IO<U32>:
        ta : String <- read_text(pa)
        tb : String <- read_text(pb)
        IO.write(report(ta, tb))
        return 0
    case other:
      do IO<U32>:
        IO.print_err("usage: gabs4 <reference.txt> <other.txt>")
        IO.exit(1)
        return 1

def main() -> IO(U32):
  do IO<U32>:
    args : List<String> <- IO.args()
    start(args)
