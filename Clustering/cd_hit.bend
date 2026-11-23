# CD-HIT-style greedy clustering: stable length order, first qualifying
# centroid, conservative hashed 3-mer filtering, and shorter-length identity.
import Base
import ./lib/common.bend as C
import ./lib/packing.bend as P
import ./lib/vclust_index.bend as V
import ./lib/lz_ani_graph.bend as LZG

type IndexedChoice is Type:
  IndexedChoice{active: Array<U32>, center: U32, rank: U32}

type IndexedState is Type:
  IndexedState{rows: Array<C.Neighbors>, active: Array<U32>,
    labels: Array<U32>, next_rank: U32}

law indexed_find:
  for neighbors: C.Neighbors
  for active: Array<U32>
  for +size: U32
  for +best: U32
  for +best_rank: U32
  IndexedChoice

def indexed_find(neighbors, active, size, best, best_rank):
  match neighbors:
    case C.NeighborsNil{}:
      IndexedChoice{active, best, best_rank}
    case C.NeighborsCon{+column, score, tail}:
      C.apply(Array<U32> & U32, IndexedChoice,
        \{Tuple: next_active => +rank => (
          C.branch(IndexedChoice,
            U32.is_ne(rank, 0) && U32.is_lt(rank, best_rank), \{
              True: indexed_find(tail, next_active, size, column, rank)
              False: indexed_find(tail, next_active, size, best, best_rank)
            })
        )}, Array.get(U32, active, column))

law indexed_continue:
  for choice: IndexedChoice
  for rows: Array<C.Neighbors>
  for labels: Array<U32>
  for +index: U32
  for +size: U32
  for +next_rank: U32
  for continue: Array<C.Neighbors> -> Array<U32> -> Array<U32> -> U32 ->
    IndexedState
  IndexedState

def indexed_continue(choice, rows, labels, index, size, next_rank, continue):
  match choice:
    case IndexedChoice{active, +center, rank}:
      C.branch(IndexedState, U32.is_eq(center, size), \{
        True: continue(rows, Array.set(U32, active, index, next_rank),
          Array.set(U32, labels, index, index), U32.add(next_rank, 1))
        False: continue(rows, active, Array.set(U32, labels, index, center),
          next_rank)
      })

law indexed_greedy:
  for items: List<C.Record>
  for rows: Array<C.Neighbors>
  for active: Array<U32>
  for labels: Array<U32>
  for +size: U32
  for +next_rank: U32
  IndexedState

def indexed_greedy(items, rows, active, labels, size, next_rank):
  match items:
    case Nil{}:
      IndexedState{rows, active, labels, next_rank}
    case Con{head, tail}:
      +index = {C.record_index(head) : U32}
      C.apply(Array<C.Neighbors> & C.Neighbors, IndexedState,
        \{Tuple: next_rows => neighbors => (
          indexed_continue(indexed_find(neighbors, active, size, size,
            4294967295), next_rows, labels, index, size, next_rank,
            final_rows => final_active => final_labels => final_rank =>
              indexed_greedy(tail, final_rows, final_active, final_labels,
                size, final_rank))
        )}, Array.get(C.Neighbors, rows, index))

law indexed_labels:
  for state: IndexedState
  Array<U32>

def indexed_labels(state):
  match state:
    case IndexedState{rows, active, labels, next_rank}:
      labels

law indexed_graph_cluster:
  for graph: C.SparseGraph
  for order: List<C.Record>
  for +size: U32
  Array<U32>

def indexed_graph_cluster(graph, order, size):
  match graph:
    case C.SparseGraph{raw_size, rows}:
      indexed_labels(indexed_greedy(C.records_sort(order), rows,
        C.array_new(size, 0), C.array_new(size, 0), size, 1))

law indexed_cluster:
  for items: List<C.Record>
  for +size: U32
  for +threshold: U32
  Array<U32>

def indexed_cluster(items, size, threshold):
  C.apply(List<C.Record> & List<C.Record>, Array<U32>,
    \{Tuple: order => graph_items => (
      indexed_graph_cluster(
        V.sparse_build_shorter_long(graph_items, size, threshold), order,
        size)
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

# With m exact matches there are at most len_a + len_b - 2*m interruptions.
# Each interruption splits a match run; each run loses at most two 3-mers.
# Hash collisions increase the intersection and cannot create false rejects.
law word_filter:
  for left: Array<U32>
  for right: Array<U32>
  for +left_size: U32
  for +right_size: U32
  for +threshold: U32
  Bool

def word_filter(left, right, left_size, right_size, threshold):
  +required_matches = {U32.div((U32.add(U32.mul(threshold, C.minimum(left_size, right_size)), 9999)), 10000) : U32}
  interruptions = U32.sub(U32.add(left_size, right_size), U32.mul(required_matches, 2))
  +required_words = {C.subtract(required_matches, U32.mul(2, (U32.add(interruptions, 1))))
    : U32}
  C.branch(Bool, U32.is_eq(required_words, 0), \{
    True: (
      True{}
    )
    False: (
      U32.is_ge(C.words_common(256n, 0, left, right, 0), required_words)
    )
  })

law filtered_alignment:
  for left: P.Sequence
  for right: P.Sequence
  for left_words: Array<U32>
  for right_words: Array<U32>
  for left_sketch: Array<U32>
  for right_sketch: Array<U32>
  for +left_size: U32
  for +right_size: U32
  for +threshold: U32
  for fast: Bool
  U32

def filtered_alignment(left, right, left_words, right_words, left_sketch,
                       right_sketch, left_size, right_size, threshold, fast):
  C.branch(U32, word_filter(left_words, right_words,
    left_size, right_size, threshold), \{
    True: (
      C.branch(U32, fast, \{
        True: (
          C.branch(U32, U32.is_lt(C.minimum(left_size, right_size), 15), \{
            True: C.alignment_identity_threshold(left, right, left_size,
              right_size, True{}, threshold)
            False: C.fast_sketch_score(left_sketch, right_sketch, threshold)
          })
        )
        False: C.alignment_identity_threshold(left, right, left_size,
          right_size, True{}, threshold)
      })
    )
    False: (
      0
    )
  })

law filtered_both:
  for left: P.Sequence
  for right: P.Sequence
  for left_words: Array<U32>
  for right_words: Array<U32>
  for left_sketch: Array<U32>
  for right_sketch: Array<U32>
  for +left_size: U32
  for +right_size: U32
  for +threshold: U32
  for +fast: Bool
  U32

def filtered_both(left, right, left_words, right_words, left_sketch,
                  right_sketch, left_size, right_size, threshold, fast):
  C.apply(P.Sequence & P.Sequence, U32,
    \{Tuple: l1 => l2 => (
      C.apply(P.Sequence & P.Sequence, U32,
        \{Tuple: r1 => r2 => (
          C.apply(Array<U32> & Array<U32>, U32,
            \{Tuple: lw1 => lw2 => (
              C.apply(Array<U32> & Array<U32>, U32,
                \{Tuple: lk1 => lk2 => (
                  reversed = C.sequence_reverse(r2, right_size)
                  C.apply(P.Sequence & P.Sequence, U32,
                    \{Tuple: reverse_for_words => reverse_remaining => (
                      C.apply(P.Sequence & P.Sequence, U32,
                        \{Tuple: reverse_for_sketch => reverse_for_alignment => (
                          reverse_words = P.signature(reverse_for_words,
                            right_size)
                          reverse_sketch = P.sketch(reverse_for_sketch,
                            right_size)
                          forward = filtered_alignment(l1, r1, lw1,
                            right_words, lk1, right_sketch, left_size,
                            right_size, threshold, fast)
                          backward = filtered_alignment(l2,
                            reverse_for_alignment, lw2, reverse_words, lk2,
                            reverse_sketch, left_size, right_size, threshold,
                            fast)
                          C.maximum(forward, backward)
                        )},
                        P.copy(reverse_remaining))
                    )},
                    P.copy(reversed))
                )},
                Array.clone(U32, left_sketch))
            )},
            Array.clone(U32, left_words))
        )},
        C.sequence_copy(right))
    )},
    C.sequence_copy(left))

law score_pair:
  for left: C.Record
  for right: C.Record
  for reverse: Bool
  for threshold: U32
  for fast: Bool
  U32

def score_pair(left, right, reverse, threshold, fast):
  match left right:
    case C.Record{li, ll, ls, lw, lwords, lsketch} C.Record{ri, rl, rs, rw, rwords, rsketch}:
      C.branch(U32, reverse, \{
        True: (
          filtered_both(ls, rs, lwords, rwords, lsketch, rsketch, lw, rw,
            threshold, fast)
        )
        False: (
          filtered_alignment(ls, rs, lwords, rwords, lsketch, rsketch, lw, rw,
            threshold, fast)
        )
      })

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
              C.branch(U32, U32.is_ge(score, threshold), \{
                True: (
                  index
                )
                False: (
                  find_centroid(tail, q2, threshold, reverse, fast, best,
                    best_score)
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

law indexed_choose:
  for items: List<C.Record>
  for +all_long: Bool
  for +size: U32
  for +threshold: U32
  Array<U32>

def indexed_choose(items, all_long, size, threshold):
  C.branch(Array<U32>, all_long, \{
    True: indexed_cluster(items, size, threshold)
    False: greedy(C.records_sort(items), Nil{}, C.array_new(size, 0), size,
      threshold, False{}, True{})
  })

def cluster(items, size, threshold, reverse, fast, lz, kmer_minimum,
            kmer_identity):
  C.branch(Array<U32>, lz, \{
    True: lz_cluster(items, size, threshold, kmer_minimum, kmer_identity)
    False: C.branch(Array<U32>, fast && Bool.not(reverse), \{
      True: C.apply(List<C.Record> & Bool, Array<U32>,
        \{Tuple: indexed_items => all_long => (
          indexed_choose(indexed_items, all_long, size, threshold)
        )}, V.records_all_long(items))
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
