# Reads a file in 1 MiB chunks with File.read_bytes and walks every byte
# (sums them), the cheapest possible consumer: the time is the input path.
import Base

def walk(bs: List<&2, U32>, +acc: U32) -> U32:
  match bs:
    case Nil{}:
      acc
    case Con{h, t}:
      walk(t, U32.add(acc, h))

def got(r: File & Result<&1, &1, U32 & String, List<&2, U32>>, +acc: U32, k: File -> U32 -> IO(U32)) -> IO(U32):
  (f, res) = r
  match res:
    case Fail{e}:
      IO.pure(U32, acc)
    case Done{bs}:
      match bs:
        case Nil{}:
          IO.pure(U32, acc)
        case Con{h, t}:
          k(f, walk(h <> t, acc))

def loop(n: Nat, f: File, +acc: U32) -> IO(U32):
  match n:
    case 0n:
      IO.pure(U32, acc)
    case 1n+p:
      do IO<U32>:
        r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 1048576)
        got(r, acc, g => a => loop(p, g, a))

def path_of(xs: List<&1, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{h, t}:
      match t:
        case Nil{}:
          ""
        case Con{p, u}:
          p

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    f : File <- IO.try(File, File.open(path_of(args), "r"))
    s : U32 <- loop(U32.to_nat(100000), f, 0)
    IO.print(U32.show(s))
