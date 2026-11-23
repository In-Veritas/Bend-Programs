import Base
# gabs1: print a line through the IO monad, ported from Bend3. Bend2 Core had
# no print effect, so this program was unsupported there; Bend 2 runs it.

def main() -> IO(Unit):
  do IO<Unit>:
    IO.write("You are not real\n")
