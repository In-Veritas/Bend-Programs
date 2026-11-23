import Base

def f(a: U32 & U32, b: U32 & U32) -> U32:
  match a b:
    case (x, y) (z, w):
      U32.add(x, w)

def main() -> U32:
  f((1, 2), (3, 4))
