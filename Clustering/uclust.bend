# UCLUST-style length-ordered centroid clustering with exhaustive search.
# Choose the best qualifying centroid; ties use the original record index.
import Base
import ./lib/common.bend as C
import ./lib/vclust_index.bend as V
import ./lib/lz_ani_graph.bend as LZG

type IndexedChoice is Type:
  IndexedChoice{active: Array<U32>, center: U32, score: U32}

type IndexedState is Type:
  IndexedState{rows: Array<C.Neighbors>, active: Array<U32>,
    labels: Array<U32>}

# Search only the query's retained sparse row. `active[column]` identifies
# centroids created earlier in length order.
law indexed_find:
  for neighbors: C.Neighbors
  for active: Array<U32>
  for +size: U32
  for +best: U32
  for +best_score: U32
  IndexedChoice

def indexed_find(neighbors, active, size, best, best_score):
  match neighbors:
    case C.NeighborsNil{}:
      IndexedChoice{active, best, best_score}
    case C.NeighborsCon{+column, +score, tail}:
      C.apply(Array<U32> & U32, IndexedChoice,
        \{Tuple: next_active => +is_active => (
          +better = {U32.is_eq(is_active, 1) &&
            (U32.is_gt(score, best_score) ||
              (U32.is_eq(score, best_score) && U32.is_lt(column, best)))
            : Bool}
          C.branch(IndexedChoice, better, \{
            True: indexed_find(tail, next_active, size, column, score)
            False: indexed_find(tail, next_active, size, best, best_score)
          })
        )}, Array.get(U32, active, column))

law indexed_continue:
  for choice: IndexedChoice
  for rows: Array<C.Neighbors>
  for labels: Array<U32>
  for +index: U32
  for +size: U32
  for continue: Array<C.Neighbors> -> Array<U32> -> Array<U32> -> IndexedState
  IndexedState

def indexed_continue(choice, rows, labels, index, size, continue):
  match choice:
    case IndexedChoice{active, +center, score}:
      C.branch(IndexedState, U32.is_eq(center, size), \{
        True: continue(rows, Array.set(U32, active, index, 1),
          Array.set(U32, labels, index, index))
        False: continue(rows, active, Array.set(U32, labels, index, center))
      })

law indexed_greedy:
  for items: List<C.Record>
  for rows: Array<C.Neighbors>
  for active: Array<U32>
  for labels: Array<U32>
  for +size: U32
  IndexedState

def indexed_greedy(items, rows, active, labels, size):
  match items:
    case Nil{}:
      IndexedState{rows, active, labels}
    case Con{head, tail}:
      +index = {C.record_index(head) : U32}
      C.apply(Array<C.Neighbors> & C.Neighbors, IndexedState,
        \{Tuple: next_rows => neighbors => (
          indexed_continue(indexed_find(neighbors, active, size, size, 0),
            next_rows, labels, index, size,
            final_rows => final_active => final_labels =>
              indexed_greedy(tail, final_rows, final_active, final_labels,
                size))
        )}, Array.get(C.Neighbors, rows, index))

law indexed_labels:
  for state: IndexedState
  Array<U32>

def indexed_labels(state):
  match state:
    case IndexedState{rows, active, labels}:
      labels

law indexed_cluster:
  for items: List<C.Record>
  for +size: U32
  for +threshold: U32
  Array<U32>

law indexed_graph_cluster:
  for graph: C.SparseGraph
  for order: List<C.Record>
  for +size: U32
  Array<U32>

def indexed_graph_cluster(graph, order, size):
  match graph:
    case C.SparseGraph{raw_size, rows}:
      indexed_labels(indexed_greedy(C.records_sort(order), rows,
        C.array_new(size, 0), C.array_new(size, 0), size))

def indexed_cluster(items, size, threshold):
  C.apply(List<C.Record> & List<C.Record>, Array<U32>,
    \{Tuple: order => graph_items => (
      indexed_graph_cluster(
        V.sparse_build(graph_items, size, threshold, False{}, True{}),
        order, size)
    )}, C.records_copy(items))

law lz_cluster:
  for items: List<C.Record>
  for +size: U32
  for +threshold: U32
  for +kmer_minimum: U32
  for +kmer_identity: U32
  Array<U32>

def lz_cluster(items, size, threshold, kmer_minimum, kmer_identity):
  C.apply(List<C.Record> & List<C.Record>, Array<U32>,
    \{Tuple: order => graph_items => (
      indexed_graph_cluster(LZG.sparse_build(graph_items, size, threshold,
        kmer_minimum, kmer_identity), order, size)
    )}, C.records_copy(items))

law score_pair:
  for left: C.Record
  for right: C.Record
  for reverse: Bool
  for threshold: U32
  for fast: Bool
  U32

def score_pair(left, right, reverse, threshold, fast):
  C.filtered_similarity_mode(left, right, reverse, threshold, fast)

law append_centroid:
  for centroids: List<C.Record>
  for item: C.Record
  List<C.Record>

def append_centroid(centroids, item):
  match centroids:
    case Nil{}:
      Con{item, Nil{}}
    case Con{head, tail}:
      Con{head, append_centroid(tail, item)}

law find_centroid:
  for centroids: List<C.Record>
  for query: C.Record
  for +threshold: U32
  for +reverse: Bool
  for +fast: Bool
  for +best: U32
  for +best_score: U32
  U32

def find_centroid(centroids, query, threshold, reverse, fast, best, best_score):
  match centroids:
    case Nil{}:
      best
    case Con{head, tail}:
      C.apply(C.Record & C.Record, U32,
        \{Tuple: h1 => h2 => (
          C.apply(C.Record & C.Record, U32,
            \{Tuple: q1 => q2 => (
              +index = {C.record_index(h1) : U32}
              +score = {score_pair(q1, h2, reverse, threshold, fast) : U32}
              C.branch(U32, U32.is_ge(score, threshold) && (U32.is_gt(score, best_score) || (U32.is_eq(score, best_score) && U32.is_lt(index, best))), \{
                True: (
                  find_centroid(tail, q2, threshold, reverse, fast, index, score)
                )
                False: (
                  find_centroid(tail, q2, threshold, reverse, fast, best, best_score)
                )
              })
            )},
            C.record_copy(query))
        )},
        C.record_copy(head))

law greedy:
  for items: List<C.Record>
  for centroids: List<C.Record>
  for labels: Array<U32>
  for +size: U32
  for +threshold: U32
  for +reverse: Bool
  for +fast: Bool
  Array<U32>

def greedy(items, centroids, labels, size, threshold, reverse, fast):
  match items:
    case Nil{}:
      labels
    case Con{head, tail}:
      C.apply(C.Record & C.Record, Array<U32>,
        \{Tuple: h1 => h2 => (
          C.apply(C.Record & C.Record, Array<U32>,
            \{Tuple: q1 => q2 => (
              C.apply(List<C.Record> & List<C.Record>, Array<U32>,
                \{Tuple: c1 => c2 => (
                  +index = {C.record_index(q1) : U32}
                  +center = {find_centroid(c1, q2, threshold, reverse, fast,
                    size, 0) : U32}
                  C.branch(Array<U32>, U32.is_eq(center, size), \{
                    True: (
                      greedy(tail, append_centroid(c2, h2), Array.set(U32, labels, index, index),
                        size, threshold, reverse, fast)
                    )
                    False: (
                      greedy(tail, c2, Array.set(U32, labels, index, center), size, threshold,
                        reverse, fast)
                    )
                  })
                )},
                C.records_copy(centroids))
            )},
            C.record_copy(h1))
        )},
        C.record_copy(head))

law cluster:
  for items: List<C.Record>
  for +size: U32
  for threshold: U32
  for +reverse: Bool
  for +fast: Bool
  for +lz: Bool
  for +kmer_minimum: U32
  for +kmer_identity: U32
  Array<U32>

def cluster(items, size, threshold, reverse, fast, lz, kmer_minimum,
            kmer_identity):
  C.branch(Array<U32>, lz, \{
    True: lz_cluster(items, size, threshold, kmer_minimum, kmer_identity)
    False: C.branch(Array<U32>, fast && Bool.not(reverse), \{
      True: indexed_cluster(items, size, threshold)
      False: greedy(C.records_sort(items), Nil{}, C.array_new(size, 0), size,
        threshold, reverse, fast)
    })
  })

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
          labels = cluster(input, size, threshold, reverse, fast, lz,
            kmer_minimum, kmer_identity)
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
