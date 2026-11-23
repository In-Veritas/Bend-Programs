# Sequence set-cover clustering: repeatedly remove the closed neighborhood
# of the uncovered node with greatest residual degree (ties by input index).
import Base
import ./lib/common.bend as C

law count_neighbors:
  for fuel: Nat
  for +index: U32
  for +row: U32
  for +size: U32
  for +threshold: U32
  for matrix: Array<U32>
  for labels: Array<U32>
  for count: U32
  (Array<U32> & Array<U32>) & U32

def count_neighbors(fuel, index, row, size, threshold, matrix, labels, count):
  match fuel:
    case Zero{}:
      ((matrix, labels), count)
    case Succ{rest}:
      C.apply(Array<U32> & U32, (Array<U32> & Array<U32>) & U32,
        \{Tuple: next_matrix => score => (
          C.apply(Array<U32> & U32, (Array<U32> & Array<U32>) & U32,
            \{Tuple: next_labels => label => (
              added = C.select(U32.is_eq(label, size) && U32.is_ge(score, threshold), 1, 0)
              count_neighbors(rest, U32.add(index, 1), row, size, threshold, next_matrix,
                next_labels, U32.add(count, added))
            )},
            Array.get(U32, labels, index))
        )},
        Array.get(U32, matrix, U32.add(U32.mul(row, size), index)))

law choose_center:
  for fuel: Nat
  for +index: U32
  for +size: U32
  for +threshold: U32
  for matrix: Array<U32>
  for labels: Array<U32>
  for +best: U32
  for +maximum: U32
  Pair(Pair(Array<U32>, Array<U32>), Pair(U32, U32))

def choose_center(fuel, index, size, threshold, matrix, labels, best, maximum):
  match fuel:
    case Zero{}:
      ((matrix, labels), (best, maximum))
    case Succ{rest}:
      C.apply(Array<U32> & U32, Pair(Pair(Array<U32>, Array<U32>), Pair(U32, U32)),
        \{Tuple: next_labels => label => (
          C.apply((Array<U32> & Array<U32>) & U32, Pair(Pair(Array<U32>, Array<U32>), Pair(U32, U32)),
            \{Tuple: \{Tuple: next_matrix => updated => raw_count => (
              +count = {C.select(U32.is_eq(label, size), raw_count, 0) : U32}
              chosen = C.select(U32.is_gt(count, maximum), index, best)
              choose_center(rest, U32.add(index, 1), size, threshold, next_matrix,
                updated, chosen, C.maximum(maximum, count))
            )}},
            count_neighbors(C.to_nat(size),
            0, index, size, threshold, matrix, next_labels, 0))
        )},
        Array.get(U32, labels, index))

law assign_neighbors:
  for fuel: Nat
  for +index: U32
  for +center: U32
  for +size: U32
  for +threshold: U32
  for matrix: Array<U32>
  for labels: Array<U32>
  Array<U32> & Array<U32>

def assign_neighbors(fuel, index, center, size, threshold, matrix, labels):
  match fuel:
    case Zero{}:
      (matrix, labels)
    case Succ{rest}:
      C.apply(Array<U32> & U32, Array<U32> & Array<U32>,
        \{Tuple: next_matrix => score => (
          C.apply(Array<U32> & U32, Array<U32> & Array<U32>,
            \{Tuple: next_labels => raw => (
              +label = {raw : U32}
              chosen = C.select(U32.is_eq(label, size) && U32.is_ge(score, threshold),
                center, label)
              updated = Array.set(U32, next_labels, index, chosen)
              assign_neighbors(rest, U32.add(index, 1), center, size, threshold,
                next_matrix, updated)
            )},
            Array.get(U32, labels, index))
        )},
        Array.get(U32, matrix, U32.add(U32.mul(center, size), index)))

law cover_step:
  for +count: U32
  for center: U32
  for +size: U32
  for threshold: U32
  for matrix: Array<U32>
  for labels: Array<U32>
  for continue: Array<U32> -> Array<U32> -> Array<U32>
  Array<U32>

def cover_step(count, center, size, threshold, matrix, labels, continue):
  C.apply(Bool, Array<U32>, \{
      True: (
        labels
      )
      False: (
        C.apply(Array<U32> & Array<U32>, Array<U32>,
          \{Tuple: next_matrix => next_labels => (
            continue(next_matrix, next_labels)
          )},
          assign_neighbors(C.to_nat(size), 0,
          center, size, threshold, matrix, labels))
      )
  }, U32.is_eq(count, 0))

law cover:
  for fuel: Nat
  for +size: U32
  for +threshold: U32
  for matrix: Array<U32>
  for labels: Array<U32>
  Array<U32>

def cover(fuel, size, threshold, matrix, labels):
  match fuel:
    case Zero{}:
      labels
    case Succ{rest}:
      C.apply(Pair(Pair(Array<U32>, Array<U32>), Pair(U32, U32)), Array<U32>,
        \{Tuple: \{Tuple: next_matrix => next_labels => \{Tuple: center => count => (
          cover_step(count, center, size, threshold, next_matrix, next_labels,
            m => l => cover(rest, size, threshold, m, l))
        )}}},
        choose_center(
        C.to_nat(size), 0, size, threshold, matrix, labels, 0, 0))

law cluster:
  for matrix: Array<U32>
  for +size: U32
  for threshold: U32
  for resolution: U32
  for seed: U32
  for passes: Nat
  Result<String, Array<U32>>

def cluster(matrix, size, threshold, resolution, seed, passes):
  Done{cover(C.to_nat(size), size, threshold, matrix,
    C.array_new(size, size))}

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
