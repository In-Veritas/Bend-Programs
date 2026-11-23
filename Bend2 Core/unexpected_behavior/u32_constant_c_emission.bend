import Base

# Base exposes these two definitions, and the evaluator plus JavaScript
# backend accept both. C emission tries to open U32's machine-word structure.

assert main:
  IO(Unit)

def main():
  IO.print(U32.show(U32.add(U32.zero(), U32.one())))
