# Complete linkage: merge the most similar pair of clusters, using the
# minimum pairwise identity between clusters and stable representative ties.
import Base
import ./lib/common.bend as C

type Candidate is Type:
  Candidate{score: U32, first: U32, other: U32}

law candidate_choose:
  for best: Candidate
  for +score: U32
  for left: U32
  for right: U32
  Candidate

def candidate_choose(best, score, left, right):
  match best:
    case Candidate{raw, first, other}:
      +previous = {raw : U32}
      C.branch(Candidate, U32.is_gt(score, previous), \{
        True: (
          Candidate{score, left, right}
        )
        False: (
          Candidate{previous, first, other}
        )
      })

law best_columns:
  for fuel: Nat
  for +column: U32
  for +row: U32
  for +size: U32
  for +live: U32
  for matrix: Array<U32>
  for active: Array<U32>
  for best: Candidate
  (Array<U32> & Array<U32>) & Candidate

def best_columns(fuel, column, row, size, live, matrix, active, best):
  match fuel:
    case Zero{}:
      ((matrix, active), best)
    case Succ{rest}:
      C.apply(Array<U32> & U32, (Array<U32> & Array<U32>) & Candidate,
        \{Tuple: next_matrix => score => (
          C.apply(Array<U32> & U32, (Array<U32> & Array<U32>) & Candidate,
            \{Tuple: next_active => target_live => (
              next_best = C.branch(Candidate, U32.is_eq(live, 1) && U32.is_eq(target_live, 1), \{
                True: (
                  candidate_choose(best, score, row, column)
                )
                False: (
                  best
                )
              })
              best_columns(rest, U32.add(column, 1), row, size, live, next_matrix,
                next_active, next_best)
            )},
            Array.get(U32, active, column))
        )},
        Array.get(U32, matrix, U32.add(U32.mul(row, size), column)))

law best_rows:
  for fuel: Nat
  for +row: U32
  for +size: U32
  for matrix: Array<U32>
  for active: Array<U32>
  for best: Candidate
  (Array<U32> & Array<U32>) & Candidate

def best_rows(fuel, row, size, matrix, active, best):
  match fuel:
    case Zero{}:
      ((matrix, active), best)
    case Succ{rest}:
      C.apply(Array<U32> & U32, (Array<U32> & Array<U32>) & Candidate,
        \{Tuple: next_active => live => (
          C.apply((Array<U32> & Array<U32>) & Candidate, (Array<U32> & Array<U32>) & Candidate,
            \{Tuple: \{Tuple: next_matrix => updated_active => next_best => (
              best_rows(rest, U32.add(row, 1), size, next_matrix, updated_active, next_best)
            )}},
            best_columns(
            C.to_nat(U32.sub(U32.sub(size, row), 1)), U32.add(row, 1), row, size, live, matrix,
            next_active, best))
        )},
        Array.get(U32, active, row))

law update_distances:
  for fuel: Nat
  for +index: U32
  for +size: U32
  for +left: U32
  for +right: U32
  for matrix: Array<U32>
  Array<U32>

def update_distances(fuel, index, size, left, right, matrix):
  match fuel:
    case Zero{}:
      matrix
    case Succ{rest}:
      C.apply(Array<U32> & U32, Array<U32>,
        \{Tuple: next => a => (
          C.apply(Array<U32> & U32, Array<U32>,
            \{Tuple: updated => b => (
              +score = {C.minimum(a, b) : U32}
              forward = Array.set(U32, updated, U32.add(U32.mul(left, size), index), score)
              backward = Array.set(U32, forward, U32.add(U32.mul(index, size), left), score)
              update_distances(rest, U32.add(index, 1), size, left, right, backward)
            )},
            Array.get(U32, next, U32.add(U32.mul(right, size), index)))
        )},
        Array.get(U32, matrix, U32.add(U32.mul(left, size), index)))

law merge_step:
  for best: Candidate
  for +size: U32
  for +threshold: U32
  for matrix: Array<U32>
  for active: Array<U32>
  for labels: Array<U32>
  for continue: Array<U32> -> Array<U32> -> Array<U32> -> Array<U32>
  Array<U32>

def merge_step(best, size, threshold, matrix, active, labels, continue):
  match best:
    case Candidate{score, raw_left, raw_right}:
      +left = {raw_left : U32}
      +right = {raw_right : U32}
      C.branch(Array<U32>, U32.is_lt(score, threshold), \{
        True: (
          labels
        )
        False: (
          updated = update_distances(C.to_nat(size), 0, size, left, right,
            matrix)
          inactive = Array.set(U32, active, right, 0)
          joined = C.labels_replace(C.to_nat(size), 0, labels, right, left)
          continue(updated, inactive, joined)
        )
      })

law merge:
  for fuel: Nat
  for +size: U32
  for +threshold: U32
  for matrix: Array<U32>
  for active: Array<U32>
  for labels: Array<U32>
  Array<U32>

def merge(fuel, size, threshold, matrix, active, labels):
  match fuel:
    case Zero{}:
      labels
    case Succ{rest}:
      C.apply((Array<U32> & Array<U32>) & Candidate, Array<U32>,
        \{Tuple: \{Tuple: next_matrix => next_active => best => (
          merge_step(best, size, threshold, next_matrix, next_active, labels,
            m => a => l => merge(rest, size, threshold, m, a, l))
        )}},
        best_rows(C.to_nat(size), 0,
        size, matrix, active, Candidate{0, 0, 0}))

law cluster:
  for matrix: Array<U32>
  for +size: U32
  for threshold: U32
  for resolution: U32
  for seed: U32
  for passes: Nat
  Result<String, Array<U32>>

def cluster(matrix, size, threshold, resolution, seed, passes):
  Done{merge(C.to_nat(size), size, threshold, matrix,
    C.array_new(size, 1), C.labels_identity(size))}

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
