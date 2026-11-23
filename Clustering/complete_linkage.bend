# Complete linkage over a sparse threshold graph. Missing edges are below the
# threshold, so a merged cluster keeps an edge only when both source clusters
# had that edge. Its score is their minimum, as in Clusty's sparse Heaptrix.
import Base
import ./lib/common.bend as C
import ./lib/vclust_index.bend as V
import ./lib/lz_ani_graph.bend as LZG

type Candidate is Type:
  Candidate{score: U32, first: U32, other: U32}

law candidate_choose:
  for best: Candidate
  for +raw_score: U32
  for +raw_left: U32
  for +raw_right: U32
  Candidate

def candidate_choose(best, raw_score, raw_left, raw_right):
  match best:
    case Candidate{raw_previous, raw_first, raw_other}:
      +left = {C.minimum(raw_left, raw_right) : U32}
      +right = {C.maximum(raw_left, raw_right) : U32}
      +score = {raw_score : U32}
      +previous = {raw_previous : U32}
      +first = {raw_first : U32}
      +other = {raw_other : U32}
      better = U32.is_gt(score, previous) ||
        (U32.is_eq(score, previous) &&
          (U32.is_lt(left, first) ||
            (U32.is_eq(left, first) && U32.is_lt(right, other))))
      C.branch(Candidate, better, \{
        True: (
          Candidate{score, left, right}
        )
        False: (
          Candidate{previous, first, other}
        )
      })

law row_best:
  for neighbors: C.Neighbors
  for +row: U32
  for best: Candidate
  C.Neighbors & Candidate

def row_best(neighbors, row, best):
  match neighbors:
    case C.NeighborsNil{}:
      (C.NeighborsNil{}, best)
    case C.NeighborsCon{raw_target, raw_score, tail}:
      +target = {raw_target : U32}
      +score = {raw_score : U32}
      C.apply(C.Neighbors & Candidate, C.Neighbors & Candidate,
        \{Tuple: rest => final => (
          (C.NeighborsCon{target, score, rest}, final)
        )},
        row_best(tail, row, candidate_choose(best, score, row, target)))

law best_rows:
  for fuel: Nat
  for +row: U32
  for +size: U32
  for rows: Array<C.Neighbors>
  for best: Candidate
  Array<C.Neighbors> & Candidate

def best_rows(fuel, row, size, rows, best):
  match fuel:
    case Zero{}:
      (rows, best)
    case Succ{rest}:
      C.apply(Array<C.Neighbors> & C.Neighbors,
        Array<C.Neighbors> & Candidate,
        \{Tuple: next_rows => neighbors => (
          C.apply(C.Neighbors & Candidate,
            Array<C.Neighbors> & Candidate,
            \{Tuple: rebuilt => next_best => (
              updated = Array.set(C.Neighbors, next_rows, row, rebuilt)
              best_rows(rest, U32.add(row, 1), size, updated, next_best)
            )},
            row_best(neighbors, row, best))
        )},
        Array.get(C.Neighbors, rows, row))

law remove_pair:
  for neighbors: C.Neighbors
  for +left: U32
  for +right: U32
  for left_score: U32
  for right_score: U32
  C.Neighbors & (U32 & U32)

def remove_pair(neighbors, left, right, left_score, right_score):
  match neighbors:
    case C.NeighborsNil{}:
      (C.NeighborsNil{}, (left_score, right_score))
    case C.NeighborsCon{raw_target, raw_score, tail}:
      +target = {raw_target : U32}
      +score = {raw_score : U32}
      next_left = C.select(U32.is_eq(target, left), score, left_score)
      next_right = C.select(U32.is_eq(target, right), score, right_score)
      keep = U32.is_ne(target, left) && U32.is_ne(target, right)
      C.apply(C.Neighbors & (U32 & U32), C.Neighbors & (U32 & U32),
        \{Tuple: rest => scores => (
          C.branch(C.Neighbors & (U32 & U32), keep, \{
            True: (
              (C.NeighborsCon{target, score, rest}, scores)
            )
            False: (
              (rest, scores)
            )
          })
        )},
        remove_pair(tail, left, right, next_left, next_right))

law merge_one:
  for +index: U32
  for +left: U32
  for +right: U32
  for neighbors: C.Neighbors
  for new_left: C.Neighbors
  C.Neighbors & C.Neighbors

def merge_one(index, left, right, neighbors, new_left):
  C.branch(C.Neighbors & C.Neighbors,
    U32.is_eq(index, left) || U32.is_eq(index, right), \{
    True: (
      (C.NeighborsNil{}, new_left)
    )
    False: (
      C.apply(C.Neighbors & (U32 & U32), C.Neighbors & C.Neighbors,
        \{Tuple: cleaned => \{Tuple: raw_a => raw_b => (
          +a = {raw_a : U32}
          +b = {raw_b : U32}
          C.branch(C.Neighbors & C.Neighbors,
            U32.is_gt(a, 0) && U32.is_gt(b, 0), \{
            True: (
              +score = {C.minimum(a, b) : U32}
              (C.NeighborsCon{left, score, cleaned},
                C.NeighborsCon{index, score, new_left})
            )
            False: (
              (cleaned, new_left)
            )
          })
        )}},
        remove_pair(neighbors, left, right, 0, 0))
    )
  })

law merge_rows:
  for fuel: Nat
  for +index: U32
  for +left: U32
  for +right: U32
  for rows: Array<C.Neighbors>
  for new_left: C.Neighbors
  Array<C.Neighbors>

def merge_rows(fuel, index, left, right, rows, new_left):
  match fuel:
    case Zero{}:
      Array.set(C.Neighbors, rows, left, new_left)
    case Succ{rest}:
      C.apply(Array<C.Neighbors> & C.Neighbors, Array<C.Neighbors>,
        \{Tuple: next_rows => neighbors => (
          C.apply(C.Neighbors & C.Neighbors, Array<C.Neighbors>,
            \{Tuple: rebuilt => next_left => (
              updated = Array.set(C.Neighbors, next_rows, index, rebuilt)
              merge_rows(rest, U32.add(index, 1), left, right, updated, next_left)
            )},
            merge_one(index, left, right, neighbors, new_left))
        )},
        Array.get(C.Neighbors, rows, index))

law merge_step:
  for best: Candidate
  for +size: U32
  for +threshold: U32
  for rows: Array<C.Neighbors>
  for labels: Array<U32>
  for continue: Array<C.Neighbors> -> Array<U32> -> Array<U32>
  Array<U32>

def merge_step(best, size, threshold, rows, labels, continue):
  match best:
    case Candidate{score, raw_left, raw_right}:
      +left = {raw_left : U32}
      +right = {raw_right : U32}
      C.branch(Array<U32>, U32.is_lt(score, threshold), \{
        True: (
          labels
        )
        False: (
          updated = merge_rows(C.to_nat(size), 0, left, right, rows,
            C.NeighborsNil{})
          joined = C.labels_replace(C.to_nat(size), 0, labels, right, left)
          continue(updated, joined)
        )
      })

law merge:
  for fuel: Nat
  for +size: U32
  for +threshold: U32
  for rows: Array<C.Neighbors>
  for labels: Array<U32>
  Array<U32>

def merge(fuel, size, threshold, rows, labels):
  match fuel:
    case Zero{}:
      labels
    case Succ{rest}:
      C.apply(Array<C.Neighbors> & Candidate, Array<U32>,
        \{Tuple: next_rows => best => (
          merge_step(best, size, threshold, next_rows, labels,
            r => l => merge(rest, size, threshold, r, l))
        )},
        best_rows(C.to_nat(size), 0, size, rows,
        Candidate{0, size, size}))

law cluster:
  for graph: C.SparseGraph
  for +size: U32
  for threshold: U32
  for resolution: U32
  for seed: U32
  for passes: Nat
  Result<String, Array<U32>>

def cluster(graph, size, threshold, resolution, seed, passes):
  match graph:
    case C.SparseGraph{raw_size, rows}:
      Done{merge(C.to_nat(size), size, threshold, rows, C.labels_identity(size))}

law run_dataset:
  for dataset: C.Dataset
  for +threshold: U32
  for reverse: Bool
  for fast: Bool
  for lz: Bool
  for kmer_minimum: U32
  for kmer_identity: U32
  for resolution: U32
  for seed: U32
  for passes: Nat
  IO(Unit)

def run_dataset(dataset, threshold, reverse, fast, lz, kmer_minimum,
                kmer_identity, resolution, seed, passes):
  match dataset:
    case C.Dataset{items, raw_size}:
      +size = {raw_size : U32}
      C.apply(List<C.Record> & List<C.Record>, IO(Unit),
        \{Tuple: input => output => (
          graph = C.branch(C.SparseGraph, lz, \{
            True: LZG.sparse_build(input, size, threshold, kmer_minimum,
              kmer_identity)
            False: V.sparse_build(input, size, threshold, reverse, fast)
          })
          do IO<Unit>:
            labels: Array<U32> <- C.result_unwrap(Array<U32>,
              cluster(graph, size, threshold, resolution, seed, passes))
            C.output(output, labels)
        )},
        C.records_copy(items))

law run_config:
  for config: C.Config
  IO(Unit)

def run_config(config):
  match config:
    case C.Config{identity, alphabet, reverse, fast, lz, kmer_minimum,
                  kmer_identity, resolution, seed, passes}:
      do IO<Unit>:
        dataset: C.Dataset <- C.fasta_read(alphabet)
        run_dataset(dataset, identity, reverse, fast, lz, kmer_minimum,
          kmer_identity, resolution, seed, passes)

law main:
  IO(Unit)

def main():
  do IO<Unit>:
    config: C.Config <- C.config_read()
    run_config(config)
