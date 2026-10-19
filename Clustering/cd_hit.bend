# CD-HIT-style greedy clustering: stable length order, first qualifying
# centroid, conservative hashed 3-mer filtering, and shorter-length identity.
import Base
import ./lib/common.bend as C

law words_count:
  for text: String
  for +rolling: U32
  for +seen: U32
  for counts: Array<U32>
  Array<U32>

def words_count(text, rolling, seen, counts):
  match text:
    case SNil{}:
      counts
    case SCon{Chr{code}, tail}:
      +word = {U32.mod(U32.add(U32.mul(rolling, 32), U32.mod(code, 32)), 32768) : U32}
      +bucket = {U32.mod(word, 4096) : U32}
      C.apply(Array<U32> & U32, Array<U32>,
        \{Tuple: next => previous => (
          updated = Array.set(U32, next, bucket, U32.add(previous, C.select(U32.is_ge(seen, 2), 1, 0)))
          words_count(tail, word, U32.add(seen, 1), updated)
        )},
        Array.get(U32, counts, bucket))

law words_common:
  for fuel: Nat
  for +index: U32
  for left: Array<U32>
  for right: Array<U32>
  for total: U32
  U32

def words_common(fuel, index, left, right, total):
  match fuel:
    case Zero{}:
      total
    case Succ{rest}:
      C.apply(Array<U32> & U32, U32,
        \{Tuple: next_left => a => (
          C.apply(Array<U32> & U32, U32,
            \{Tuple: next_right => b => (
              words_common(rest, U32.add(index, 1), next_left, next_right,
                U32.add(total, C.minimum(a, b)))
            )},
            Array.get(U32, right, index))
        )},
        Array.get(U32, left, index))

# With m exact matches there are at most len_a + len_b - 2*m interruptions.
# Each interruption splits a match run; each run loses at most two 3-mers.
# Hash collisions increase the intersection and cannot create false rejects.
law word_filter:
  for left: String
  for right: String
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
      a = words_count(left, 0, 0, Array.new(U32, 12n, 0))
      b = words_count(right, 0, 0, Array.new(U32, 12n, 0))
      U32.is_ge(words_common(4096n, 0, a, b, 0), required_words)
    )
  })

law filtered_alignment:
  for left: String
  for right: String
  for +left_size: U32
  for +right_size: U32
  for threshold: U32
  U32

def filtered_alignment(left, right, left_size, right_size, threshold):
  C.apply(String & String, U32,
    \{Tuple: l1 => l2 => (
      C.apply(String & String, U32,
        \{Tuple: r1 => r2 => (
          C.branch(U32, word_filter(l1, r1, left_size, right_size, threshold), \{
            True: (
              C.alignment_identity(l2, r2, left_size, right_size, True{})
            )
            False: (
              0
            )
          })
        )},
        C.string_copy(right))
    )},
    C.string_copy(left))

law filtered_both:
  for left: String
  for right: String
  for +left_size: U32
  for +right_size: U32
  for +threshold: U32
  U32

def filtered_both(left, right, left_size, right_size, threshold):
  C.apply(String & String, U32,
    \{Tuple: l1 => l2 => (
      C.apply(String & String, U32,
        \{Tuple: r1 => r2 => (
          forward = filtered_alignment(l1, r1, left_size, right_size, threshold)
          backward = filtered_alignment(l2, C.reverse_complement(r2, ""),
            left_size, right_size, threshold)
          C.maximum(forward, backward)
        )},
        C.string_copy(right))
    )},
    C.string_copy(left))

law score_pair:
  for left: C.Record
  for right: C.Record
  for reverse: Bool
  for threshold: U32
  U32

def score_pair(left, right, reverse, threshold):
  match left right:
    case C.Record{li, ll, ls, lw} C.Record{ri, rl, rs, rw}:
      C.branch(U32, reverse, \{
        True: (
          filtered_both(ls, rs, lw, rw, threshold)
        )
        False: (
          filtered_alignment(ls, rs, lw, rw, threshold)
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
              C.branch(U32, U32.is_ge(score, threshold), \{
                True: (
                  index
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
