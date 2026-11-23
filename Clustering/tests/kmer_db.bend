# Executable oracle seam for the sparse Kmer-db-compatible prefilter.
import Base
import ../lib/common.bend as C
import ../lib/kmer_db.bend as K

law emit_neighbors:
  for neighbors: C.Neighbors
  for +row: U32
  IO(Unit)

def emit_neighbors(neighbors, row):
  match neighbors:
    case C.NeighborsNil{}:
      IO.pure(Unit, Unit{})
    case C.NeighborsCon{+target, +score, tail}:
      do IO<Unit>:
        line: Unit <- IO.print(U32.show(row) ++ "\t" ++ U32.show(target)
          ++ "\t" ++ U32.show(score))
        emit_neighbors(tail, row)

law emit_rows:
  for fuel: Nat
  for +row: U32
  for rows: Array<C.Neighbors>
  IO(Unit)

def emit_rows(fuel, row, rows):
  match fuel:
    case Zero{}:
      IO.pure(Unit, Unit{})
    case Succ{rest}:
      C.apply(Array<C.Neighbors> & C.Neighbors, IO(Unit),
        \{Tuple: next => neighbors => (
          do IO<Unit>:
            emitted: Unit <- emit_neighbors(neighbors, row)
            emit_rows(rest, U32.add(row, 1), next)
        )}, Array.get(C.Neighbors, rows, row))

law run_graph:
  for graph: C.SparseGraph
  IO(Unit)

def run_graph(graph):
  match graph:
    case C.SparseGraph{+size, rows}:
      do IO<Unit>:
        header: Unit <- IO.print("left\tright\tcommon_kmers")
        emit_rows(C.to_nat(size), 0, rows)

law run_dataset:
  for dataset: C.Dataset
  IO(Unit)

def run_dataset(dataset):
  match dataset:
    case C.Dataset{items, +size}:
      run_graph(K.sparse_build(items, size, 20, 7000))

law main:
  IO(Unit)

def main():
  do IO<Unit>:
    dataset: C.Dataset <- C.fasta_read(1)
    run_dataset(dataset)
