
import ../bend-base/Base

def main() -> IO(U32):
  do IO(U32):
    _ <- IO.write("You are not real\n")
    return 0
