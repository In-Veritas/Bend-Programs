# gabs1: prints a line through the IO monad
# expect: You are not real

import Base

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("You are not real")
