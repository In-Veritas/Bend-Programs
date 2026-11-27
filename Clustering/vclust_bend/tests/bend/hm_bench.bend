import Base
import ../../kdb_hash.bend as H

def loop(n: Nat, +i: U32, h: H.HM) -> H.HM:
  match n:
    case 0n:
      h
    case 1n+p:
      loop(p, (i + 1 : U32), H.add(U32.and((i * 2654435761 : U32), 4194303), 1, 4294967295, h))

def fin(h: H.HM) -> U32:
  H.HM{+f, +c, a} = h
  f

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    +x : U32 = fin(loop(U32.to_nat(20000000), 0, H.hm_new(4294967295)))
    t1 : Nat <- IO.now()
    IO.print(U32.show(x) ++ " ms " ++ Nat.show(Nat.sub(t1, t0)))
