# Single linkage: threshold edges form disjoint-set connected components.
# Roots always decrease, so the smallest input index represents a component.
import Base
import ./lib/common.bend as C

law find_root:
  for fuel: Nat
  for parents: Array<U32>
  for +node: U32
  Array<U32> & U32

def find_root(fuel, parents, node):
  match fuel:
    case Zero{}:
      (parents, node)
    case Succ{rest}:
      C.apply(Array<U32> & U32, Array<U32> & U32,
        \{Tuple: next => raw_parent => (
          +parent = {raw_parent : U32}
          C.branch(Array<U32> & U32, U32.is_eq(parent, node), \{
            True: (
              (next, node)
            )
            False: (
              find_root(rest, next, parent)
            )
          })
        )},
        Array.get(U32, parents, node))

law union:
  for parents: Array<U32>
  for +size: U32
  for left: U32
  for right: U32
  Array<U32>

def union(parents, size, left, right):
  C.apply(Array<U32> & U32, Array<U32>,
    \{Tuple: next => raw_left => (
      C.apply(Array<U32> & U32, Array<U32>,
        \{Tuple: updated => raw_right => (
          +a = {raw_left : U32}
          +b = {raw_right : U32}
          Array.set(U32, updated, C.maximum(a, b), C.minimum(a, b))
        )},
        find_root(C.to_nat(size), next, right))
    )},
    find_root(C.to_nat(size), parents, left))

law scan_columns:
  for fuel: Nat
  for +column: U32
  for +row: U32
  for +size: U32
  for +threshold: U32
  for matrix: Array<U32>
  for parents: Array<U32>
  Array<U32> & Array<U32>

def scan_columns(fuel, column, row, size, threshold, matrix, parents):
  match fuel:
    case Zero{}:
      (matrix, parents)
    case Succ{rest}:
      C.apply(Array<U32> & U32, Array<U32> & Array<U32>,
        \{Tuple: next => score => (
          updated = C.branch(Array<U32>, U32.is_ge(score, threshold), \{
            True: (
              union(parents, size, row, column)
            )
            False: (
              parents
            )
          })
          scan_columns(rest, U32.add(column, 1), row, size, threshold, next, updated)
        )},
        Array.get(U32, matrix, U32.add(U32.mul(row, size), column)))

law scan_rows:
  for fuel: Nat
  for +row: U32
  for +size: U32
  for +threshold: U32
  for matrix: Array<U32>
  for parents: Array<U32>
  Array<U32>

def scan_rows(fuel, row, size, threshold, matrix, parents):
  match fuel:
    case Zero{}:
      parents
    case Succ{rest}:
      C.apply(Array<U32> & Array<U32>, Array<U32>,
        \{Tuple: next => updated => (
          scan_rows(rest, U32.add(row, 1), size, threshold, next, updated)
        )},
        scan_columns(C.to_nat(U32.sub(U32.sub(size, row), 1)), U32.add(row, 1),
        row, size, threshold, matrix, parents))

law flatten:
  for fuel: Nat
  for +index: U32
  for +size: U32
  for parents: Array<U32>
  for labels: Array<U32>
  Array<U32>

def flatten(fuel, index, size, parents, labels):
  match fuel:
    case Zero{}:
      labels
    case Succ{rest}:
      C.apply(Array<U32> & U32, Array<U32>,
        \{Tuple: next => root => (
          updated = Array.set(U32, labels, index, root)
          flatten(rest, U32.add(index, 1), size, next, updated)
        )},
        find_root(C.to_nat(size), parents, index))

law cluster:
  for matrix: Array<U32>
  for +size: U32
  for threshold: U32
  for resolution: U32
  for seed: U32
  for passes: Nat
  Result<String, Array<U32>>

def cluster(matrix, size, threshold, resolution, seed, passes):
  parents = scan_rows(C.to_nat(size), 0, size, threshold, matrix,
    C.labels_identity(size))
  Done{flatten(C.to_nat(size), 0, size, parents, C.array_new(size, 0))}

law run_dataset:
  for dataset: C.Dataset
  for +threshold: U32
  for reverse: Bool
  for resolution: U32
  for seed: U32
  for passes: Nat
  IO(Unit)

def run_dataset(dataset, threshold, reverse, resolution, seed, passes):
  match dataset:
    case C.Dataset{items, raw_size}:
      +size = {raw_size : U32}
      C.apply(List<C.Record> & List<C.Record>, IO(Unit),
        \{Tuple: input => output => (
          matrix = C.matrix_build(input, size, reverse)
          do IO<Unit>:
            labels: Array<U32> <- C.result_unwrap(Array<U32>,
              cluster(matrix, size, threshold, resolution, seed, passes))
            C.output(output, labels)
        )},
        C.records_copy(items))

law run_config:
  for config: C.Config
  IO(Unit)

def run_config(config):
  match config:
    case C.Config{identity, alphabet, reverse, resolution, seed, passes}:
      do IO<Unit>:
        dataset: C.Dataset <- C.fasta_read(alphabet)
        run_dataset(dataset, identity, reverse, resolution, seed, passes)

law main:
  IO(Unit)

def main():
  do IO<Unit>:
    config: C.Config <- C.config_read()
    run_config(config)
