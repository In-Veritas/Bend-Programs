import Base

# Latest-Bend port of u32_constant_c_emission.bend. Base no longer defines
# U32.zero / U32.one (U32 literals replaced them), so the constants are user
# defs, one a literal and one via U32.from_nat. All lanes print 1.
def zero() -> U32:
  0

def one() -> U32:
  U32.from_nat(1n)

def main() -> IO(Unit):
  IO.print(U32.show(U32.add(zero(), one())))
