# Sequence set-cover clustering over a sparse threshold graph. Repeatedly
# remove the closed neighborhood of the uncovered node with greatest residual
# degree; ties use the smallest input index.
import Base
import ./lib/common.bend as C
import ./lib/vclust_index.bend as V
import ./lib/lz_ani_graph.bend as LZG

law count_row:
  for neighbors: C.Neighbors
  for labels: Array<U32>
  for +sentinel: U32
  for count: U32
  (C.Neighbors & Array<U32>) & U32

def count_row(neighbors, labels, sentinel, count):
  match neighbors:
    case C.NeighborsNil{}:
      ((C.NeighborsNil{}, labels), count)
    case C.NeighborsCon{raw_target, score, tail}:
      +target = {raw_target : U32}
      C.apply(Array<U32> & U32, (C.Neighbors & Array<U32>) & U32,
        \{Tuple: next_labels => label => (
          C.apply((C.Neighbors & Array<U32>) & U32,
            (C.Neighbors & Array<U32>) & U32,
            \{Tuple: \{Tuple: rest => final_labels => total => (
              ((C.NeighborsCon{target, score, rest}, final_labels), total)
            )}},
            count_row(tail, next_labels, sentinel,
              U32.add(count, C.select(U32.is_eq(label, sentinel), 1, 0))))
        )},
        Array.get(U32, labels, target))

law choose_center:
  for fuel: Nat
  for +index: U32
  for +size: U32
  for rows: Array<C.Neighbors>
  for labels: Array<U32>
  for +best: U32
  for +maximum: U32
  Pair(Pair(Array<C.Neighbors>, Array<U32>), Pair(U32, U32))

def choose_center(fuel, index, size, rows, labels, best, maximum):
  match fuel:
    case Zero{}:
      ((rows, labels), (best, maximum))
    case Succ{rest}:
      C.apply(Array<U32> & U32,
        Pair(Pair(Array<C.Neighbors>, Array<U32>), Pair(U32, U32)),
        \{Tuple: next_labels => label => (
          C.apply(Array<C.Neighbors> & C.Neighbors,
            Pair(Pair(Array<C.Neighbors>, Array<U32>), Pair(U32, U32)),
            \{Tuple: next_rows => neighbors => (
              counted = C.branch((C.Neighbors & Array<U32>) & U32,
                U32.is_eq(label, size), \{
                True: (
                  count_row(neighbors, next_labels, size, 1)
                )
                False: (
                  ((neighbors, next_labels), 0)
                )
              })
              C.apply((C.Neighbors & Array<U32>) & U32,
                Pair(Pair(Array<C.Neighbors>, Array<U32>), Pair(U32, U32)),
                \{Tuple: \{Tuple: rebuilt => updated_labels => raw_count => (
                  +count = {raw_count : U32}
                  updated_rows = Array.set(C.Neighbors, next_rows, index, rebuilt)
                  chosen = C.select(U32.is_gt(count, maximum), index, best)
                  choose_center(rest, U32.add(index, 1), size, updated_rows,
                    updated_labels, chosen, C.maximum(maximum, count))
                )}},
                counted)
            )},
            Array.get(C.Neighbors, rows, index))
        )},
        Array.get(U32, labels, index))

law assign_row:
  for neighbors: C.Neighbors
  for labels: Array<U32>
  for +center: U32
  for +sentinel: U32
  C.Neighbors & Array<U32>

def assign_row(neighbors, labels, center, sentinel):
  match neighbors:
    case C.NeighborsNil{}:
      (C.NeighborsNil{}, labels)
    case C.NeighborsCon{raw_target, score, tail}:
      +target = {raw_target : U32}
      C.apply(Array<U32> & U32, C.Neighbors & Array<U32>,
        \{Tuple: next_labels => raw_label => (
          +label = {raw_label : U32}
          updated = Array.set(U32, next_labels, target,
            C.select(U32.is_eq(label, sentinel), center, label))
          C.apply(C.Neighbors & Array<U32>, C.Neighbors & Array<U32>,
            \{Tuple: rest => final_labels => (
              (C.NeighborsCon{target, score, rest}, final_labels)
            )},
            assign_row(tail, updated, center, sentinel))
        )},
        Array.get(U32, labels, target))

law assign_center:
  for rows: Array<C.Neighbors>
  for labels: Array<U32>
  for +center: U32
  for +size: U32
  Array<C.Neighbors> & Array<U32>

def assign_center(rows, labels, center, size):
  marked = Array.set(U32, labels, center, center)
  C.apply(Array<C.Neighbors> & C.Neighbors,
    Array<C.Neighbors> & Array<U32>,
    \{Tuple: next_rows => neighbors => (
      C.apply(C.Neighbors & Array<U32>,
        Array<C.Neighbors> & Array<U32>,
        \{Tuple: rebuilt => updated_labels => (
          (Array.set(C.Neighbors, next_rows, center, rebuilt), updated_labels)
        )},
        assign_row(neighbors, marked, center, size))
    )},
    Array.get(C.Neighbors, rows, center))

law cover_step:
  for +count: U32
  for center: U32
  for +size: U32
  for rows: Array<C.Neighbors>
  for labels: Array<U32>
  for continue: Array<C.Neighbors> -> Array<U32> -> Array<U32>
  Array<U32>

def cover_step(count, center, size, rows, labels, continue):
  C.branch(Array<U32>, U32.is_eq(count, 0), \{
    True: (
      labels
    )
    False: (
      C.apply(Array<C.Neighbors> & Array<U32>, Array<U32>,
        \{Tuple: next_rows => next_labels => (
          continue(next_rows, next_labels)
        )},
        assign_center(rows, labels, center, size))
    )
  })

law cover:
  for fuel: Nat
  for +size: U32
  for rows: Array<C.Neighbors>
  for labels: Array<U32>
  Array<U32>

def cover(fuel, size, rows, labels):
  match fuel:
    case Zero{}:
      labels
    case Succ{rest}:
      C.apply(Pair(Pair(Array<C.Neighbors>, Array<U32>), Pair(U32, U32)),
        Array<U32>,
        \{Tuple: \{Tuple: next_rows => next_labels => \{Tuple: center => count => (
          cover_step(count, center, size, next_rows, next_labels,
            r => l => cover(rest, size, r, l))
        )}}},
        choose_center(C.to_nat(size), 0, size, rows, labels, 0, 0))

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
      Done{cover(C.to_nat(size), size, rows, C.array_new(size, size))}

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
