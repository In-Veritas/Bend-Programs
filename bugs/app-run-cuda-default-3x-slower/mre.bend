import Base

def pick(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# A 1024 x 1024 checkerboard of 8-px squares, built fresh every frame.
def board(+d: Nat, +x: U32, +y: U32, +n: U32) -> Image:
  match d:
    case 0n:
      Pix{pick(U32.is_eq(((x + y + n) .&. 1 : U32), 0), 16777215, 255)}
    case 1n+e:
      Qua{board(e, (x * 2 : U32), (y * 2 : U32), n),
        board(e, (x * 2 + 1 : U32), (y * 2 : U32), n),
        board(e, (x * 2 : U32), (y * 2 + 1 : U32), n),
        board(e, (x * 2 + 1 : U32), (y * 2 + 1 : U32), n)}

def view(n: U32) -> U32 & Image:
  +m = n
  (m, board(7n, 0, 0, m))

def tick(events: List<Event>, n: U32) -> IO(Maybe<U32>):
  do IO<Maybe<U32>>:
    IO.print("frame")
    return Some{(n + 1 : U32)}

def main() -> IO(Unit):
  App.run(~U32, ~App{view, tick}, "mre", 1024, 1024, 0)
