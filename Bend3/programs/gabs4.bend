# gabs4: how much do two texts resemble each other?
#
# Reads a reference file and a text file from the command line, splits both
# into lowercase words (apostrophes vanish, every other non-letter
# separates), and reports their vocabulary overlap as a percentage:
# 100 * shared distinct words / total distinct words (Jaccard). Identical
# texts score 100%; texts with no words in common score 0%.
#
# The old version needed --no-halt for a mutually recursive tokenizer
# (words/wgo/take/tk1/tk2) and a non-structural number printer. Bend now
# requires termination and forbids mutual recursion, so the tokenizer is one
# def, tok, that walks the text once; the per-character decision is made by
# step, which receives the rest of the walk as a closure. Numbers print with
# Base's U32.show.
#
# $ bend gabs4.bend -o gabs4
# $ ./gabs4 fixtures/reference.txt fixtures/other.txt

# run-args: fixtures/reference.txt fixtures/other.txt
# expect: the texts are 61% alike (19 of 31 distinct words shared)

import Base

# Words
# -----

# emit the word being built (kept reversed in acc), if there is one
def flush(acc: String, rest: List<&2, String>) -> List<&2, String>:
  match acc:
    case SNil{}:
      rest
    case SCon{c, cs}:
      String.reverse(SCon{c, cs}) <> rest

# one character u (already lowercased): a letter extends the word, an
# apostrophe vanishes, anything else ends the word. k continues the walk
# with the new accumulator.
def step(letter: Bool, apos: Bool, u: U32, acc: String,
  k: String -> List<&2, String>) -> List<&2, String>:
  match letter apos:
    case True{} _:
      k(SCon{Chr{u}, acc})
    case False{} True{}:
      k(acc)
    case False{} False{}:
      flush(acc, k(SNil{}))

def lower(+c: U32) -> U32:
  (c + 32 * Bool.to_u32((65 <= c : U32) && (c <= 90 : U32)) : U32)

def classify(+u: U32, acc: String, k: String -> List<&2, String>) -> List<&2, String>:
  step((97 <= u : U32) && (u <= 122 : U32), U32.is_eq(u, 39), u, acc, k)

def tok(s: String, acc: String) -> List<&2, String>:
  match s:
    case SNil{}:
      flush(acc, Nil{})
    case SCon{c, t}:
      classify(lower(Char.to_u32(c)), acc, a => tok(t, a))

def words(s: String) -> List<&2, String>:
  tok(s, SNil{})

# Vocabulary
# ----------

def has(xs: List<&2, String>, +x: String) -> Bool:
  List.contains(~String, ~String.eq, xs, x)

def keep(w: String, rest: List<&2, String>, seen: Bool) -> List<&2, String>:
  match seen:
    case True{}:
      rest
    case False{}:
      w <> rest

# drop repeated words (keeps the last occurrence)
def dedup(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +w <> +ws:
      keep(w, dedup(ws), has(ws, w))

# how many words of the first list appear in the second
def score(xs: List<&2, String>, +ws: List<&2, String>) -> U32:
  match xs:
    case Nil{}:
      0
    case v <> vs:
      (Bool.to_u32(has(ws, v)) + score(vs, ws) : U32)

def len(xs: List<&2, String>) -> U32:
  match xs:
    case Nil{}:
      0
    case v <> vs:
      (1 + len(vs) : U32)

# Jaccard: shared / (|a| + |b| - shared), as a percentage
def report(ta: String, tb: String) -> String:
  +wa = dedup(words(ta))
  +wb = dedup(words(tb))
  +i = score(wa, wb)
  +u = (len(wa) + len(wb) - i : U32)
  +pct = (i * 100 / (u + Bool.to_u32(U32.is_zero(u))) : U32)
  "the texts are " ++ U32.show(pct) ++ "% alike (" ++ U32.show(i) ++ " of "
    ++ U32.show(u) ++ " distinct words shared)"

# IO
# --

# close the file and unwrap what was read from it
def got(m: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  (f, r) = m
  do IO<String>:
    File.close(f)
    IO.pass(String, r)

def sized(m: File & Result<&1, &1, U32 & String, U32>) -> IO(String):
  (f, r) = m
  do IO<String>:
    n : U32 <- IO.pass(U32, r)
    m2 : File & Result<&1, &1, U32 & String, String> <- File.read(f, n)
    got(m2)

def read_file(path: String) -> IO(String):
  do IO<String>:
    f : File <- IO.try(File, File.open(path, "r"))
    m : File & Result<&1, &1, U32 & String, U32> <- File.size(f)
    sized(m)

def start(args: List<String>) -> IO(Unit):
  match args:
    case _ <> pa <> pb <> _:
      do IO<Unit>:
        ta : String <- read_file(pa)
        tb : String <- read_file(pb)
        IO.print(report(ta, tb))
    case _:
      IO.die(Unit, 1, "usage: gabs4 <reference.txt> <other.txt>")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    start(args)
