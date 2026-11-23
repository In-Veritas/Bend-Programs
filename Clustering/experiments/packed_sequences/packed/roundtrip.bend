import Base
import ./lib/common.bend as C
def output(dataset: C.Dataset) -> IO(Unit):
  match dataset:
    case C.Dataset{items, size}:
      C.output(items, C.labels_identity(size))
def main() -> IO(Unit):
  do IO<Unit>:
    dataset: C.Dataset <- C.fasta_read(1)
    output(dataset)
