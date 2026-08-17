# gabs4: how much do two texts resemble each other?
import ../bend-base/Base
#
# Reads a reference file and a text file from the command line, splits both
# into lowercase words (apostrophes vanish, every other non-letter
# separates), and reports their vocabulary overlap as a percentage:
# 100 * shared distinct words / total distinct words (Jaccard). Identical
# texts score 100%; texts with no words in common score 0%.
#
# Word lists get their own concrete Words type (not List<List(Char)>): the
# comparison duplicates words and word lists, and the C backend derives
# structural dup only for variables whose declared type is concrete.
#
# Needs --no-halt (# no-halt): udec recurses on n / 10, which is not a
# structural descent, and words/wgo/take/tk1/tk2 are mutually recursive
# (--no-halt widens def scoping to the whole book, admitting that).
#
# $ bend programas_gabriel/ported/gabs4.bend --no-halt --compile > gabs4.c
# $ clang -O3 -Wno-unused-function -DPAR_BACKEND=0 gabs4.c -lpthread -o gabs4
# $ ./gabs4 fixtures/reference.txt fixtures/other.txt

# no-halt
# run-args: fixtures/reference.txt fixtures/other.txt



type Words:
  WCons{head: List(Char), tail: Words}
  WNil{}

# print every string of a list
def puts(s: List(List(Char))) -> IO(U32):
  match s:
    case List.Cons{h, t}:
      do IO(U32):
        _ <- IO.write(h)
        puts(t)
    case List.Nil{}:
      IO.pure(U32, 0)

def ord(c: Char) -> U32:
  match c:
    case Char.Char{c}:
      c

# number printing (from the calc demo)
def udec(n: U32, k: List(Char)) -> List(Char):
  match n:
    case 0:
      k
    case m:
      udec(m / 10, List.Cons{Char.Char{48 + (m % 10)}, k})

def unum(n: U32, k: List(Char)) -> List(Char):
  match n:
    case 0:
      List.Cons{'0', k}
    case m:
      udec(m, k)

# character classes
def lower(c: U32) -> U32:
  c + (32 * ((65 <= c) && (c <= 90)))

def isl(c: U32) -> U32:
  (97 <= c) && (c <= 122)

def streq(a: List(Char), b: List(Char)) -> U32:
  match a, b:
    case List.Cons{Char.Char{x}, s}, List.Cons{Char.Char{y}, t}:
      (x == y) && streq(s, t)
    case List.Nil{}, List.Nil{}:
      1
    case p, q:
      0

# reverse-prepend
def rev(s: List(Char), k: List(Char)) -> List(Char):
  match s:
    case List.Cons{c, t}:
      rev(t, List.Cons{c, k})
    case List.Nil{}:
      k

# tokenizer: words is the between-words state, take the inside-a-word state
# (acc holds the current word reversed)
def words(s: List(Char)) -> Words:
  match s:
    case List.Cons{c, t}:
      u = lower(ord(c))
      wgo(isl(u), u, t)
    case List.Nil{}:
      Words.WNil{}

def wgo(e: U32, c: U32, t: List(Char)) -> Words:
  match e:
    case 0:
      words(t)
    case k:
      take(t, List.Cons{Char.Char{c}, List.Nil{}})

def take(s: List(Char), acc: List(Char)) -> Words:
  match s:
    case List.Cons{c, t}:
      u = lower(ord(c))
      tk1(isl(u), u, t, acc)
    case List.Nil{}:
      Words.WCons{rev(acc, List.Nil{}), Words.WNil{}}

def tk1(e: U32, u: U32, t: List(Char), acc: List(Char)) -> Words:
  match e:
    case 0:
      tk2(u == 39, t, acc)
    case k:
      take(t, List.Cons{Char.Char{u}, acc})

def tk2(e: U32, t: List(Char), acc: List(Char)) -> Words:
  match e:
    case 0:
      Words.WCons{rev(acc, List.Nil{}), words(t)}
    case k:
      take(t, acc)

# membership of a word in a word list
def has(l: Words, x: List(Char)) -> U32:
  match l:
    case Words.WCons{w, ws}:
      hgo(streq(w, x), ws, x)
    case Words.WNil{}:
      0

def hgo(e: U32, ws: Words, x: List(Char)) -> U32:
  match e:
    case 0:
      has(ws, x)
    case k:
      1

# drop repeated words (keeps the last occurrence)
def dedup(l: Words) -> Words:
  match l:
    case Words.WCons{w, ws}:
      ww = w
      wss = ws
      dgo(has(wss, ww), ww, wss)
    case Words.WNil{}:
      Words.WNil{}

def dgo(e: U32, w: List(Char), ws: Words) -> Words:
  match e:
    case 0:
      Words.WCons{w, dedup(ws)}
    case k:
      dedup(ws)

# how many words of the first list appear in the second
def score(a: Words, ws: Words) -> U32:
  match a:
    case Words.WCons{v, vs}:
      has(ws, v) + score(vs, ws)
    case Words.WNil{}:
      0

def len(l: Words) -> U32:
  match l:
    case Words.WCons{v, vs}:
      1 + len(vs)
    case Words.WNil{}:
      0

# Jaccard: shared / (|a| + |b| - shared), as a percentage
def report(ta: List(Char), tb: List(Char)) -> IO(U32):
  wa = dedup(words(ta))
  wb = dedup(words(tb))
  i = score(wa, wb)
  u = (len(wa) + len(wb)) - i
  do IO(U32):
    _ <- puts(["the texts are ", unum((i * 100) / (u + (u == 0)), List.Nil{}), "% alike (", unum(i, List.Nil{}), " of ", unum(u, List.Nil{}), " distinct words shared)\n"])
    return 0

def next(pb: List(Char), ta: List(Char)) -> IO(U32):
  do IO(U32):
    tb <- IO.try(String, IO.read_text(pb))
    report(ta, tb)

def start(a: List(List(Char))) -> IO(U32):
  match a:
    case List.Cons{pa, List.Cons{pb, rest}}:
      do IO(U32):
        ta <- IO.try(String, IO.read_text(pa))
        next(pb, ta)
    case other:
      do IO(U32):
        _ <- IO.write("usage: gabs4 <reference.txt> <other.txt>\n")
        return 1

def main() -> IO(U32):
  do IO(U32):
    a <- IO.args()
    start(a)
