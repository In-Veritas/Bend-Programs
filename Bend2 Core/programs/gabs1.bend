import Base

# The current Core runtime executes standard IO on both generated backends.
assert main:
  IO(Unit)

def main():
  IO.write("You are not real\n")
