import Base

# A Data record of 100 U32 fields: 100 machine words once unboxed.
type Big is Data:
  Big{f0: U32, f1: U32, f2: U32, f3: U32, f4: U32, f5: U32, f6: U32, f7: U32, f8: U32, f9: U32, f10: U32, f11: U32, f12: U32, f13: U32, f14: U32, f15: U32, f16: U32, f17: U32, f18: U32, f19: U32, f20: U32, f21: U32, f22: U32, f23: U32, f24: U32, f25: U32, f26: U32, f27: U32, f28: U32, f29: U32, f30: U32, f31: U32, f32: U32, f33: U32, f34: U32, f35: U32, f36: U32, f37: U32, f38: U32, f39: U32, f40: U32, f41: U32, f42: U32, f43: U32, f44: U32, f45: U32, f46: U32, f47: U32, f48: U32, f49: U32, f50: U32, f51: U32, f52: U32, f53: U32, f54: U32, f55: U32, f56: U32, f57: U32, f58: U32, f59: U32, f60: U32, f61: U32, f62: U32, f63: U32, f64: U32, f65: U32, f66: U32, f67: U32, f68: U32, f69: U32, f70: U32, f71: U32, f72: U32, f73: U32, f74: U32, f75: U32, f76: U32, f77: U32, f78: U32, f79: U32, f80: U32, f81: U32, f82: U32, f83: U32, f84: U32, f85: U32, f86: U32, f87: U32, f88: U32, f89: U32, f90: U32, f91: U32, f92: U32, f93: U32, f94: U32, f95: U32, f96: U32, f97: U32, f98: U32, f99: U32}

# Three of them: 300 words, so the record itself is boxed.
type Trio is Data:
  Trio{a: Big, b: Big, c: Big}

def bump(b: Big) -> Big:
  Big{f0, f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13, f14, f15, f16, f17, f18, f19, f20, f21, f22, f23, f24, f25, f26, f27, f28, f29, f30, f31, f32, f33, f34, f35, f36, f37, f38, f39, f40, f41, f42, f43, f44, f45, f46, f47, f48, f49, f50, f51, f52, f53, f54, f55, f56, f57, f58, f59, f60, f61, f62, f63, f64, f65, f66, f67, f68, f69, f70, f71, f72, f73, f74, f75, f76, f77, f78, f79, f80, f81, f82, f83, f84, f85, f86, f87, f88, f89, f90, f91, f92, f93, f94, f95, f96, f97, f98, f99} = b
  Big{(f0 + 1 : U32), f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13, f14, f15, f16, f17, f18, f19, f20, f21, f22, f23, f24, f25, f26, f27, f28, f29, f30, f31, f32, f33, f34, f35, f36, f37, f38, f39, f40, f41, f42, f43, f44, f45, f46, f47, f48, f49, f50, f51, f52, f53, f54, f55, f56, f57, f58, f59, f60, f61, f62, f63, f64, f65, f66, f67, f68, f69, f70, f71, f72, f73, f74, f75, f76, f77, f78, f79, f80, f81, f82, f83, f84, f85, f86, f87, f88, f89, f90, f91, f92, f93, f94, f95, f96, f97, f98, f99}

def step(b: Big) -> IO(Big & U32):
  IO.pure(Big & U32, (bump(b), 7))

def put(r: Big & U32, b: Big, c: Big) -> Trio & U32:
  (g, k) = r
  (Trio{g, b, c}, k)

def go(t: Trio) -> IO(Trio & U32):
  Trio{a, b, c} = t
  IO.bind(Big & U32, Trio & U32, step(a), r => IO.pure(Trio & U32, put(r, b, c)))

def main() -> IO(Unit):
  +z = {Big{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0} : Big}
  IO.bind(Trio & U32, Unit, go(Trio{z, z, z}), r => IO.print("done"))
