import Base
import ./lib/common.bend as C
def print_cells(fuel: Nat, +index: U32, values: Array<U32>) -> IO(Unit):
  match fuel:
    case Zero{}: IO.pure(Unit, Unit{})
    case Succ{rest}:
      C.apply(Array<U32> & U32, IO(Unit), \{Tuple: next => value => (
        do IO<Unit>:
          printed: Unit <- IO.print(U32.show(value))
          print_cells(rest, U32.add(index, 1), next)
      )}, Array.get(U32, values, index))
def output(dataset: C.Dataset, reverse: Bool) -> IO(Unit):
  match dataset:
    case C.Dataset{items, +size}:
      print_cells(C.to_nat(U32.mul(size, size)), 0, C.matrix_build(items, size, reverse))
def main() -> IO(Unit):
  do IO<Unit>:
    dataset: C.Dataset <- C.fasta_read(1)
    reverse: U32 <- C.env_number("CLUSTER_REVERSE", "0", 1)
    output(dataset, U32.is_eq(reverse, 1))
