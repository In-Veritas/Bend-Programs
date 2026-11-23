# UCLUST-style length-ordered centroid clustering with exhaustive search.
# Choose the best qualifying centroid; ties use the original record index.
import Base
import ./lib/common.bend as C

law score_pair:
  for left: C.Record
  for right: C.Record
  for reverse: Bool
  for threshold: U32
  U32

def score_pair(left, right, reverse, threshold):
  C.similarity(left, right, reverse, False{})

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
  for +best: U32
  for +best_score: U32
  U32

def find_centroid(centroids, query, threshold, reverse, best, best_score):
  match centroids:
    case Nil{}:
      best
    case Con{head, tail}:
      C.apply(C.Record & C.Record, U32,
        \{Tuple: h1 => h2 => (
          C.apply(C.Record & C.Record, U32,
            \{Tuple: q1 => q2 => (
              +index = {C.record_index(h1) : U32}
              +score = {score_pair(q1, h2, reverse, threshold) : U32}
              C.branch(U32, U32.is_ge(score, threshold) && (U32.is_gt(score, best_score) || (U32.is_eq(score, best_score) && U32.is_lt(index, best))), \{
                True: (
                  find_centroid(tail, q2, threshold, reverse, index, score)
                )
                False: (
                  find_centroid(tail, q2, threshold, reverse, best, best_score)
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
  Array<U32>

def greedy(items, centroids, labels, size, threshold, reverse):
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
                  +center = {find_centroid(c1, q2, threshold, reverse, size, 0) : U32}
                  C.branch(Array<U32>, U32.is_eq(center, size), \{
                    True: (
                      greedy(tail, append_centroid(c2, h2), Array.set(U32, labels, index, index),
                        size, threshold, reverse)
                    )
                    False: (
                      greedy(tail, c2, Array.set(U32, labels, index, center), size, threshold,
                        reverse)
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
  for reverse: Bool
  Array<U32>

def cluster(items, size, threshold, reverse):
  greedy(C.records_sort(items), Nil{}, C.array_new(size, 0), size,
    threshold, reverse)

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
          labels = cluster(input, size, threshold, reverse)
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
