# Indexed Array-based LZ-ANI pair scorer.
#
# This is the scalable counterpart of lz_ani_numeric.bend. The numeric module
# remains the small specification oracle; this module stores every valid
# reference 11-mer and 7-mer in checked hash buckets and threads the affine
# arrays through candidate-only searches.
import Base
import ./packing.bend as P
import ./lz_ani_choice.bend as Choice

type Posting is Data:
  PostingNil{}
  PostingCon{key: U32, position: U32, tail: Posting}

type Kmer is Data:
  Kmer{value: U32, valid: Bool}

type Anchor is Data:
  Anchor{position: U32, length: U32, close: Bool}

type Counts is Data:
  Counts{matches: U32, mismatches: U32, components: U32}

type Metrics is Data:
  Metrics{matches: U32, mismatches: U32, components: U32,
    ani: U32, gani: U32, coverage: U32}

type Extension is Data:
  Extension{length: U32, matches: U32, mismatches: U32}

type Arrays is Type:
  Arrays{source: Array<U32>, target: Array<U32>}

type BasePostings is Type:
  BasePostings{bases: Array<U32>, postings: Array<Posting>}

type IndexedArrays is Type:
  IndexedArrays{bases: Array<U32>, long: Array<Posting>, short: Array<Posting>}

type ReferenceIndex is Type:
  ReferenceIndex{bases: Array<U32>, long: Array<Posting>, short: Array<Posting>,
    length: U32}

type PairState is Type:
  PairState{reference: Array<U32>, query: Array<U32>,
    long: Array<Posting>, short: Array<Posting>,
    reference_length: U32, query_length: U32}

type ParseResult is Type:
  ParseResult{state: PairState, counts: Counts}

type ScoreResult is Type:
  ScoreResult{index: ReferenceIndex, metrics: Metrics}

type Flags is Data:
  FlagsNil{}
  FlagsCon{flag: U32, tail: Flags}

def choose(-A: Type, condition: Bool, branches: Bool -> A) -> A:
  branches(condition)

def apply(-A: Type, -B: Type, body: A -> B, value: A) -> B:
  body(value)

def minimum(+left: U32, +right: U32) -> U32:
  choose(U32, U32.is_lt(left, right), \{True: left; False: right})

def subtract(+left: U32, +right: U32) -> U32:
  choose(U32, U32.is_lt(left, right), \{True: 0; False: U32.sub(left, right)})

law array_depth:
  for fuel: Nat
  for +size: U32
  for +capacity: U32
  for depth: Nat
  Nat

def array_depth(fuel, size, capacity, depth):
  match fuel:
    case Zero{}:
      depth
    case Succ{rest}:
      choose(Nat, U32.is_le(size, capacity), \{
        True: depth
        False: array_depth(rest, size, U32.mul(capacity, 2), Succ{depth})
      })

def hash30(+word: U32) -> U32:
  +a = {U32.xor(word, U32.shrn(word, 16n)) : U32}
  +b = {U32.mul(a, 2146121005) : U32}
  +c = {U32.xor(b, U32.shrn(b, 15n)) : U32}
  +d = {U32.mul(c, 2221713035) : U32}
  U32.xor(d, U32.shrn(d, 16n))

def complement(base: U32) -> U32:
  match base:
    case 0: 3
    case 1: 2
    case 2: 1
    case 3: 0
    case _: 4

# Packed sequence conversion
# ==========================

law sequence_fill:
  for fuel: Nat
  for cursor: P.Cursor
  for +index: U32
  for values: Array<U32>
  Array<U32>

def sequence_fill(fuel, cursor, index, values):
  match fuel:
    case Zero{}:
      values
    case Succ{rest}:
      apply(P.Cursor & U32, Array<U32>, \{Tuple: following => base => (
        sequence_fill(rest, following, U32.add(index, 1),
          Array.set(U32, values, index, base))
      )}, P.next(cursor))

law sequence_array:
  for sequence: P.Sequence
  for +length: U32
  Array<U32>

def sequence_array(sequence, length):
  sequence_fill(U32.to_nat(length), P.cursor(sequence), 0,
    Array.new(U32, array_depth(31n, length, 1, 0n), 4))

law copy_forward:
  for fuel: Nat
  for +index: U32
  for source: Array<U32>
  for target: Array<U32>
  Arrays

def copy_forward(fuel, index, source, target):
  match fuel:
    case Zero{}:
      Arrays{source, target}
    case Succ{rest}:
      apply(Array<U32> & U32, Arrays, \{Tuple: next => base => (
        copy_forward(rest, U32.add(index, 1), next,
          Array.set(U32, target, index, base))
      )}, Array.get(U32, source, index))

law fill_sentinel:
  for fuel: Nat
  for +index: U32
  for target: Array<U32>
  Array<U32>

def fill_sentinel(fuel, index, target):
  match fuel:
    case Zero{}:
      target
    case Succ{rest}:
      fill_sentinel(rest, U32.add(index, 1),
        Array.set(U32, target, index, 4))

law copy_reverse:
  for fuel: Nat
  for +index: U32
  for +length: U32
  for source: Array<U32>
  for target: Array<U32>
  Arrays

def copy_reverse(fuel, index, length, source, target):
  match fuel:
    case Zero{}:
      Arrays{source, target}
    case Succ{rest}:
      +source_index = {U32.sub(U32.sub(length, 1), index) : U32}
      apply(Array<U32> & U32, Arrays, \{Tuple: next => base => (
        copy_reverse(rest, U32.add(index, 1), length, next,
          Array.set(U32, target, U32.add(U32.add(length, 80), index),
            complement(base)))
      )}, Array.get(U32, source, source_index))

law reference_array_finish:
  for arrays: Arrays
  for +total: U32
  Array<U32>

def reference_array_finish(arrays, total):
  match arrays:
    case Arrays{source, target}:
      fill_sentinel(40n, U32.sub(total, 40), target)

law reference_array_reverse:
  for arrays: Arrays
  for +length: U32
  for +total: U32
  Array<U32>

def reference_array_reverse(arrays, length, total):
  match arrays:
    case Arrays{source, target}:
      reference_array_finish(
        copy_reverse(U32.to_nat(length), 0, length, source,
          fill_sentinel(80n, length, target)), total)

law reference_array:
  for sequence: P.Sequence
  for +length: U32
  Array<U32>

def reference_array(sequence, length):
  +total = {U32.add(U32.mul(length, 2), 120) : U32}
  source = sequence_array(sequence, length)
  reference_array_reverse(copy_forward(U32.to_nat(length), 0, source,
    Array.new(U32, array_depth(31n, total, 1, 0n), 4)), length, total)

# K-mer index construction
# =========================

law array_kmer:
  for fuel: Nat
  for bases: Array<U32>
  for +position: U32
  for +value: U32
  for +valid: Bool
  for +mask: U32
  Array<U32> & Kmer

def array_kmer(fuel, bases, position, value, valid, mask):
  match fuel:
    case Zero{}:
      (bases, Kmer{value, valid})
    case Succ{rest}:
      apply(Array<U32> & U32, Array<U32> & Kmer,
        \{Tuple: next => +base => (
          array_kmer(rest, next, U32.add(position, 1),
            U32.and(U32.or(U32.shln(value, 2n), U32.and(base, 3)), mask),
            valid && U32.is_lt(base, 4), mask)
        )}, Array.get(U32, bases, position))

law insert_posting:
  for buckets: Array<Posting>
  for +bucket: U32
  for +key: U32
  for +position: U32
  Array<Posting>

def insert_posting(buckets, bucket, key, position):
  apply(Array<Posting> & Posting, Array<Posting>,
    \{Tuple: next => postings => (
      Array.set(Posting, next, bucket, PostingCon{key, position, postings})
    )}, Array.get(Posting, buckets, bucket))

law index_long:
  for fuel: Nat
  for +position: U32
  for bases: Array<U32>
  for buckets: Array<Posting>
  BasePostings

def index_long(fuel, position, bases, buckets):
  match fuel:
    case Zero{}:
      BasePostings{bases, buckets}
    case Succ{rest}:
      apply(Array<U32> & Kmer, BasePostings,
        \{Tuple: next => \{Kmer: +value => valid => (
          updated = choose(Array<Posting>, valid, \{
            True: insert_posting(buckets, U32.and(hash30(value), 65535),
              value, position)
            False: buckets
          })
          index_long(rest, U32.add(position, 1), next, updated)
        )}}, array_kmer(11n, bases, position, 0, True{}, 4194303))

law index_short:
  for fuel: Nat
  for +position: U32
  for bases: Array<U32>
  for long: Array<Posting>
  for short: Array<Posting>
  IndexedArrays

def index_short(fuel, position, bases, long, short):
  match fuel:
    case Zero{}:
      IndexedArrays{bases, long, short}
    case Succ{rest}:
      apply(Array<U32> & Kmer, IndexedArrays,
        \{Tuple: next => \{Kmer: +value => valid => (
          updated = choose(Array<Posting>, valid, \{
            True: insert_posting(short, value, value, position)
            False: short
          })
          index_short(rest, U32.add(position, 1), next, long, updated)
        )}}, array_kmer(7n, bases, position, 0, True{}, 16383))

law build_short:
  for arrays: BasePostings
  for +length: U32
  ReferenceIndex

def build_short(arrays, length):
  match arrays:
    case BasePostings{bases, long}:
      apply(IndexedArrays, ReferenceIndex,
        \{IndexedArrays: final_bases => final_long => short => (
          ReferenceIndex{final_bases, final_long, short, length}
        )},
        index_short(U32.to_nat(subtract(U32.add(length, 1), 7)), 0,
          bases, long,
          Array.new(Posting, 14n, PostingNil{})))

law build_index:
  for sequence: P.Sequence
  for +length: U32
  ReferenceIndex

def build_index(sequence, length):
  +total = {U32.add(U32.mul(length, 2), 120) : U32}
  bases = reference_array(sequence, length)
  build_short(index_long(U32.to_nat(subtract(U32.add(total, 1), 11)), 0,
    bases, Array.new(Posting, 16n, PostingNil{})), total)

# Pair-state reads and exact factors
# ==================================

law pair_from_query:
  for index: ReferenceIndex
  for query: P.Sequence
  for +query_length: U32
  PairState

def pair_from_query(index, query, query_length):
  match index:
    case ReferenceIndex{reference, long, short, +reference_length}:
      PairState{reference, sequence_array(query, query_length), long, short,
        reference_length, query_length}

law pair_get_reference:
  for state: PairState
  for +position: U32
  PairState & U32

def pair_get_reference(state, position):
  match state:
    case PairState{reference, query, long, short, +reference_length, +query_length}:
      apply(Array<U32> & U32, PairState & U32,
        \{Tuple: next => base => (
          (PairState{next, query, long, short, reference_length, query_length},
           base)
        )}, Array.get(U32, reference, position))

law pair_get_query:
  for state: PairState
  for +position: U32
  PairState & U32

def pair_get_query(state, position):
  match state:
    case PairState{reference, query, long, short, +reference_length, +query_length}:
      apply(Array<U32> & U32, PairState & U32,
        \{Tuple: next => base => (
          (PairState{reference, next, long, short, reference_length,
            query_length}, base)
        )}, Array.get(U32, query, position))

law pair_query_kmer:
  for fuel: Nat
  for state: PairState
  for +position: U32
  for +value: U32
  for +valid: Bool
  for +mask: U32
  PairState & Kmer

def pair_query_kmer(fuel, state, position, value, valid, mask):
  match fuel:
    case Zero{}:
      (state, Kmer{value, valid})
    case Succ{rest}:
      apply(PairState & U32, PairState & Kmer,
        \{Tuple: next => +base => (
          pair_query_kmer(rest, next, U32.add(position, 1),
            U32.and(U32.or(U32.shln(value, 2n), U32.and(base, 3)), mask),
            valid && U32.is_lt(base, 4), mask)
        )}, pair_get_query(state, position))

law pair_equal_len:
  for fuel: Nat
  for state: PairState
  for +reference_position: U32
  for +query_position: U32
  for +total: U32
  PairState & U32

def pair_equal_len(fuel, state, reference_position, query_position, total):
  match fuel:
    case Zero{}:
      (state, total)
    case Succ{rest}:
      apply(PairState & U32, PairState & U32,
        \{Tuple: after_ref => +ref_base => (
          apply(PairState & U32, PairState & U32,
            \{Tuple: after_query => +query_base => (
              choose(PairState & U32,
                U32.is_eq(ref_base, query_base) && U32.is_lt(ref_base, 4), \{
                  True: pair_equal_len(rest, after_query,
                    U32.add(reference_position, 1),
                    U32.add(query_position, 1), U32.add(total, 1))
                  False: (after_query, total)
                })
            )}, pair_get_query(after_ref, query_position))
        )}, pair_get_reference(state, reference_position))

def longer(candidate: Anchor, best: Anchor) -> Anchor:
  match candidate best:
    case Anchor{candidate_position, +candidate_length, candidate_close}
         Anchor{best_position, +best_length, best_close}:
      choose(Anchor, U32.is_gt(candidate_length, best_length), \{
        True: Anchor{candidate_position, candidate_length, candidate_close}
        False: Anchor{best_position, best_length, best_close}
      })

law search_long_postings:
  for postings: Posting
  for +key: U32
  for +query_position: U32
  for +available: U32
  for state: PairState
  for best: Anchor
  PairState & Anchor

def search_long_postings(postings, key, query_position, available, state, best):
  match postings:
    case PostingNil{}:
      (state, best)
    case PostingCon{+entry_key, +position, tail}:
      choose(PairState & Anchor, U32.is_eq(entry_key, key), \{
        False: search_long_postings(tail, key, query_position, available,
          state, best)
        True: apply(PairState & U32, PairState & Anchor,
          \{Tuple: next => length => (
            search_long_postings(tail, key, query_position, available, next,
              longer(Anchor{position, length, False{}}, best))
          )}, pair_equal_len(U32.to_nat(available), state, position,
            query_position, 0))
      })

law pair_long_bucket:
  for state: PairState
  for +bucket: U32
  PairState & Posting

def pair_long_bucket(state, bucket):
  match state:
    case PairState{reference, query, long, short, +reference_length, +query_length}:
      apply(Array<Posting> & Posting, PairState & Posting,
        \{Tuple: next => postings => (
          (PairState{reference, query, next, short, reference_length,
            query_length}, postings)
        )}, Array.get(Posting, long, bucket))

law pair_short_bucket:
  for state: PairState
  for +bucket: U32
  PairState & Posting

def pair_short_bucket(state, bucket):
  match state:
    case PairState{reference, query, long, short, +reference_length, +query_length}:
      apply(Array<Posting> & Posting, PairState & Posting,
        \{Tuple: next => postings => (
          (PairState{reference, query, long, next, reference_length,
            query_length}, postings)
        )}, Array.get(Posting, short, bucket))

law find_long_kmer:
  for kmer: Kmer
  for state: PairState
  for +query_position: U32
  for +available: U32
  PairState & Anchor

def find_long_kmer(kmer, state, query_position, available):
  match kmer:
    case Kmer{+value, valid}:
      choose(PairState & Anchor, valid, \{
        False: (state, Anchor{0, 0, False{}})
        True: apply(PairState & Posting, PairState & Anchor,
          \{Tuple: next => postings => (
            search_long_postings(postings, value, query_position, available,
              next, Anchor{0, 0, False{}})
          )}, pair_long_bucket(state, U32.and(hash30(value), 65535)))
      })

law find_long:
  for state: PairState
  for +query_position: U32
  for +available: U32
  PairState & Anchor

def find_long(state, query_position, available):
  apply(PairState & Kmer, PairState & Anchor,
    \{Tuple: next => kmer => find_long_kmer(kmer, next, query_position,
      available)},
    pair_query_kmer(11n, state, query_position, 0, True{}, 4194303))

def better_close(candidate: Anchor, best: Anchor, +predicted: U32) -> Anchor:
  match candidate best:
    case Anchor{+candidate_position, +candidate_length, candidate_close}
         Anchor{+best_position, +best_length, best_close}:
      +candidate_distance = {choose(U32,
        U32.is_lt(candidate_position, predicted),
        \{True: U32.sub(predicted, candidate_position)
          False: U32.sub(candidate_position, predicted)}) : U32}
      +best_distance = {choose(U32, U32.is_lt(best_position, predicted),
        \{True: U32.sub(predicted, best_position)
          False: U32.sub(best_position, predicted)}) : U32}
      choose(Anchor,
        U32.is_gt(candidate_length, best_length)
          || (U32.is_eq(candidate_length, best_length)
            && U32.is_lt(candidate_distance, best_distance)), \{
          True: Anchor{candidate_position, candidate_length, True{}}
          False: Anchor{best_position, best_length, best_close}
        })

law search_short_postings:
  for postings: Posting
  for +query_position: U32
  for +available: U32
  for +lower: U32
  for +upper: U32
  for +predicted: U32
  for state: PairState
  for best: Anchor
  PairState & Anchor

def search_short_postings(postings, query_position, available, lower, upper,
                          predicted, state, best):
  match postings:
    case PostingNil{}:
      (state, best)
    case PostingCon{key, +position, tail}:
      choose(PairState & Anchor,
        U32.is_ge(position, lower) && U32.is_lt(position, upper), \{
          False: search_short_postings(tail, query_position, available, lower,
            upper, predicted, state, best)
          True: apply(PairState & U32, PairState & Anchor,
            \{Tuple: next => +length => (
              next_best = choose(Anchor, U32.is_ge(length, 7), \{
                True: better_close(Anchor{position, length, True{}}, best,
                  predicted)
                False: best
              })
              search_short_postings(tail, query_position, available, lower,
                upper, predicted, next, next_best)
            )}, pair_equal_len(U32.to_nat(available), state, position,
              query_position, 0))
        })

law find_short_kmer:
  for kmer: Kmer
  for state: PairState
  for +query_position: U32
  for +available: U32
  for +predicted: U32
  for +literal_run: U32
  PairState & Anchor

def find_short_kmer(kmer, state, query_position, available, predicted,
                    literal_run):
  match kmer:
    case Kmer{+value, valid}:
      choose(PairState & Anchor, valid, \{
        False: (state, Anchor{0, 0, True{}})
        True: apply(PairState & Posting, PairState & Anchor,
          \{Tuple: next => postings => (
            search_short_postings(postings, query_position, available,
              subtract(predicted, literal_run), U32.add(predicted, 40),
              predicted, next, Anchor{0, 0, True{}})
          )}, pair_short_bucket(state, value))
      })

law find_short:
  for state: PairState
  for +query_position: U32
  for +available: U32
  for +predicted: U32
  for +literal_run: U32
  PairState & Anchor

def find_short(state, query_position, available, predicted, literal_run):
  apply(PairState & Kmer, PairState & Anchor,
    \{Tuple: next => kmer => find_short_kmer(kmer, next, query_position,
      available, predicted, literal_run)},
    pair_query_kmer(7n, state, query_position, 0, True{}, 16383))

# Parser numeric operations
# =========================

def select_predicted(long: Anchor, close: Anchor, +reference_length: U32,
                     +literal_run: U32) -> Anchor:
  match long close:
    case Anchor{+long_position, +long_length, long_close}
         Anchor{close_position, +close_length, close_flag}:
      +has_long = {U32.is_ne(long_position, 0)
        && U32.is_ge(long_length, 11) : Bool}
      +has_close = {U32.is_ge(close_length, 7) : Bool}
      choose(Anchor, has_long, \{
        False: choose(Anchor, has_close, \{
          True: Anchor{close_position, close_length, True{}}
          False: Anchor{0, 0, False{}}
        })
        True: choose(Anchor, has_close, \{
          False: Anchor{long_position, long_length, False{}}
          True: choose(Anchor, Choice.anchor_preferred(long_length,
            close_length, reference_length, literal_run), \{
              True: Anchor{long_position, long_length, False{}}
              False: Anchor{close_position, close_length, True{}}
            })
        })
      })

def distance(+left: U32, +right: U32) -> U32:
  choose(U32, U32.is_lt(left, right), \{
    True: U32.sub(right, left)
    False: U32.sub(left, right)
  })

def classify_selected(anchor: Anchor, +predicted: U32) -> Anchor:
  match anchor:
    case Anchor{+position, length, close}:
      Anchor{position, length,
        U32.is_le(distance(position, predicted), 40)}

law find_anchor_predicted:
  for first: PairState & Anchor
  for +query_position: U32
  for +available: U32
  for +predicted: U32
  for +literal_run: U32
  for +reference_length: U32
  PairState & Anchor

def find_anchor_predicted(first, query_position, available, predicted,
                          literal_run, reference_length):
  match first:
    case Tuple{state, long}:
      apply(PairState & Anchor, PairState & Anchor,
        \{Tuple: next => close => (next, classify_selected(
          select_predicted(long, close, reference_length, literal_run),
          predicted))},
        find_short(state, query_position, available, predicted, literal_run))

law find_anchor:
  for state: PairState
  for +query_position: U32
  for +available: U32
  for +has_prediction: Bool
  for +predicted: U32
  for +literal_run: U32
  for +reference_length: U32
  PairState & Anchor

def find_anchor(state, query_position, available, has_prediction, predicted,
                literal_run, reference_length):
  choose(PairState & Anchor, has_prediction, \{
    True: find_anchor_predicted(find_long(state, query_position, available),
      query_position, available, predicted, literal_run, reference_length)
    False: apply(PairState & Anchor, PairState & Anchor,
      \{Tuple: next => \{Anchor: position => +length => close => (
        (next, choose(Anchor, U32.is_ge(length, 11), \{
          True: Anchor{position, length, False{}}
          False: Anchor{0, 0, False{}}
        }))
      )}}, find_long(state, query_position, available))
  })

law pair_count_equal:
  for fuel: Nat
  for state: PairState
  for +reference_position: U32
  for +query_position: U32
  for +total: U32
  PairState & U32

def pair_count_equal(fuel, state, reference_position, query_position, total):
  match fuel:
    case Zero{}:
      (state, total)
    case Succ{rest}:
      apply(PairState & U32, PairState & U32,
        \{Tuple: after_ref => +ref_base => (
          apply(PairState & U32, PairState & U32,
            \{Tuple: after_query => +query_base => (
              pair_count_equal(rest, after_query,
                U32.add(reference_position, 1), U32.add(query_position, 1),
                U32.add(total, choose(U32,
                  U32.is_eq(ref_base, query_base) && U32.is_lt(ref_base, 4),
                  \{True: 1; False: 0})))
            )}, pair_get_query(after_ref, query_position))
        )}, pair_get_reference(state, reference_position))

law gap_split_right:
  for first: PairState & U32
  for +query_start: U32
  for +anchor_end: U32
  for +gap_length: U32
  for +scan_length: U32
  for +split: U32
  PairState & U32

def gap_split_right(first, query_start, anchor_end, gap_length, scan_length,
                    split):
  match first:
    case Tuple{state, +left_matches}:
      +right_length = {U32.sub(scan_length, split) : U32}
      apply(PairState & U32, PairState & U32,
        \{Tuple: next => right_matches => (
          (next, U32.add(left_matches, right_matches))
        )}, pair_count_equal(U32.to_nat(right_length), state,
          subtract(anchor_end, right_length),
          U32.add(query_start, U32.sub(gap_length, right_length)), 0))

law gap_split:
  for state: PairState
  for +query_start: U32
  for +predicted: U32
  for +anchor_end: U32
  for +gap_length: U32
  for +scan_length: U32
  for +split: U32
  PairState & U32

def gap_split(state, query_start, predicted, anchor_end, gap_length,
              scan_length, split):
  gap_split_right(pair_count_equal(U32.to_nat(split), state,
    subtract(predicted, gap_length), query_start, 0), query_start, anchor_end,
    gap_length, scan_length, split)

law best_gap:
  for fuel: Nat
  for state: PairState
  for +query_start: U32
  for +predicted: U32
  for +anchor_end: U32
  for +gap_length: U32
  for +scan_length: U32
  for +split: U32
  for +best: U32
  PairState & U32

def best_gap(fuel, state, query_start, predicted, anchor_end, gap_length,
             scan_length, split, best):
  match fuel:
    case Zero{}:
      (state, best)
    case Succ{rest}:
      apply(PairState & U32, PairState & U32,
        \{Tuple: next => +candidate => (
          best_gap(rest, next, query_start, predicted, anchor_end, gap_length,
            scan_length, U32.add(split, 1),
            choose(U32, U32.is_ge(candidate, best),
              \{True: candidate; False: best}))
        )}, gap_split(state, query_start, predicted, anchor_end, gap_length,
          scan_length, split))

def flags_take(fuel: Nat, flags: Flags) -> Flags:
  match fuel flags:
    case Zero{} remaining:
      FlagsNil{}
    case Succ{rest} FlagsNil{}:
      FlagsNil{}
    case Succ{rest} FlagsCon{flag, tail}:
      FlagsCon{flag, flags_take(rest, tail)}

def flags_sum(flags: Flags, +total: U32) -> U32:
  match flags:
    case FlagsNil{}:
      total
    case FlagsCon{flag, tail}:
      flags_sum(tail, U32.add(total, flag))

law extension_loop:
  for fuel: Nat
  for state: PairState
  for +reference_position: U32
  for +query_position: U32
  for window: Flags
  for +length: U32
  for +run: U32
  for +matches: U32
  for +mismatches: U32
  for +good_length: U32
  for +good_matches: U32
  for +good_mismatches: U32
  PairState & Extension

def extension_loop(fuel, state, reference_position, query_position, window,
                   length, run, matches, mismatches, good_length,
                   good_matches, good_mismatches):
  match fuel:
    case Zero{}:
      (state, Extension{good_length, good_matches, good_mismatches})
    case Succ{rest}:
      apply(PairState & U32, PairState & Extension,
        \{Tuple: after_ref => +ref_base => (
          apply(PairState & U32, PairState & Extension,
            \{Tuple: after_query => +query_base => (
              +is_match = {U32.is_eq(ref_base, query_base)
                && U32.is_lt(ref_base, 4) : Bool}
              +flag = {choose(U32, is_match, \{True: 0; False: 1}) : U32}
              +next_window = {flags_take(15n, FlagsCon{flag, window}) : Flags}
              +next_length = {U32.add(length, 1) : U32}
              +next_run = {choose(U32, is_match,
                \{True: U32.add(run, 1); False: 0}) : U32}
              +next_matches = {U32.add(matches,
                choose(U32, is_match, \{True: 1; False: 0})) : U32}
              +next_mismatches = {U32.add(mismatches, flag) : U32}
              choose(PairState & Extension,
                U32.is_gt(flags_sum(next_window, 0), 7), \{
                  True: (after_query,
                    Extension{good_length, good_matches, good_mismatches})
                  False: choose(PairState & Extension,
                    U32.is_ge(next_run, 3), \{
                      True: extension_loop(rest, after_query,
                        U32.add(reference_position, 1),
                        U32.add(query_position, 1), next_window, next_length,
                        next_run, next_matches, next_mismatches, next_length,
                        next_matches, next_mismatches)
                      False: extension_loop(rest, after_query,
                        U32.add(reference_position, 1),
                        U32.add(query_position, 1), next_window, next_length,
                        next_run, next_matches, next_mismatches, good_length,
                        good_matches, good_mismatches)
                    })
                })
            )}, pair_get_query(after_ref, query_position))
        )}, pair_get_reference(state, reference_position))

law extension_backward_loop:
  for fuel: Nat
  for state: PairState
  for +reference_position: U32
  for +query_position: U32
  for window: Flags
  for +length: U32
  for +run: U32
  for +matches: U32
  for +mismatches: U32
  for +good_length: U32
  for +good_matches: U32
  for +good_mismatches: U32
  PairState & Extension

def extension_backward_loop(fuel, state, reference_position, query_position,
                            window, length, run, matches, mismatches,
                            good_length, good_matches, good_mismatches):
  match fuel:
    case Zero{}:
      (state, Extension{good_length, good_matches, good_mismatches})
    case Succ{rest}:
      choose(PairState & Extension,
        U32.is_eq(reference_position, 0) || U32.is_eq(query_position, 0), \{
          True: (state, Extension{good_length, good_matches, good_mismatches})
          False: (
            +ref_at = {U32.sub(reference_position, 1) : U32}
            +query_at = {U32.sub(query_position, 1) : U32}
            apply(PairState & U32, PairState & Extension,
              \{Tuple: after_ref => +ref_base => (
                apply(PairState & U32, PairState & Extension,
                  \{Tuple: after_query => +query_base => (
                    +is_match = {U32.is_eq(ref_base, query_base)
                      && U32.is_lt(ref_base, 4) : Bool}
                    +flag = {choose(U32, is_match,
                      \{True: 0; False: 1}) : U32}
                    +next_window = {flags_take(15n,
                      FlagsCon{flag, window}) : Flags}
                    +next_length = {U32.add(length, 1) : U32}
                    +next_run = {choose(U32, is_match,
                      \{True: U32.add(run, 1); False: 0}) : U32}
                    +next_matches = {U32.add(matches,
                      choose(U32, is_match, \{True: 1; False: 0})) : U32}
                    +next_mismatches = {U32.add(mismatches, flag) : U32}
                    choose(PairState & Extension,
                      U32.is_gt(flags_sum(next_window, 0), 7), \{
                        True: (after_query, Extension{good_length,
                          good_matches, good_mismatches})
                        False: choose(PairState & Extension,
                          U32.is_ge(next_run, 3), \{
                            True: extension_backward_loop(rest, after_query,
                              ref_at, query_at, next_window, next_length,
                              next_run, next_matches, next_mismatches,
                              next_length, next_matches, next_mismatches)
                            False: extension_backward_loop(rest, after_query,
                              ref_at, query_at, next_window, next_length,
                              next_run, next_matches, next_mismatches,
                              good_length, good_matches, good_mismatches)
                          })
                      })
                  )}, pair_get_query(after_ref, query_at))
              )}, pair_get_reference(state, ref_at))
          )
        })

def finish_region(+region_matches: U32, +region_mismatches: U32,
                  counts: Counts) -> Counts:
  match counts:
    case Counts{matches, mismatches, components}:
      choose(Counts,
        U32.is_ge(U32.add(region_matches, region_mismatches), 35), \{
          True: Counts{U32.add(matches, region_matches),
            U32.add(mismatches, region_mismatches),
            U32.add(components, 1)}
          False: Counts{matches, mismatches, components}
        })

law parse_loop:
  for fuel: Nat
  for state: PairState
  for +query_position: U32
  for +has_prediction: Bool
  for +predicted: U32
  for +literal_run: U32
  for +region_matches: U32
  for +region_mismatches: U32
  for counts: Counts
  ParseResult

def parse_loop(fuel, state, query_position, has_prediction, predicted,
               literal_run, region_matches, region_mismatches, counts):
  match fuel:
    case Zero{}:
      ParseResult{state,
        finish_region(region_matches, region_mismatches, counts)}
    case Succ{rest}:
      match state:
        case PairState{reference, query, long, short, +reference_length,
                       +query_length}:
          +available = {subtract(query_length, query_position) : U32}
          choose(ParseResult, U32.is_eq(available, 0), \{
            True: ParseResult{
              PairState{reference, query, long, short, reference_length,
                query_length},
              finish_region(region_matches, region_mismatches, counts)}
            False: apply(PairState & Anchor, ParseResult,
              \{Tuple: found_state =>
                \{Anchor: +position => +length => +close => (
                  choose(ParseResult, U32.is_eq(length, 0), \{
                    True: parse_loop(rest, found_state,
                      U32.add(query_position, 1),
                      has_prediction && U32.is_lt(literal_run, 40),
                      U32.add(predicted, 1), U32.add(literal_run, 1),
                      region_matches, region_mismatches, counts)
                    False: apply(PairState & Extension, ParseResult,
                      \{Tuple: extended_state =>
                        \{Extension: +extension_length => +extension_matches =>
                          +extension_mismatches => (
                            +consumed = {U32.add(length, extension_length) : U32}
                            +next_position = {U32.add(
                              U32.add(position, length), extension_length) : U32}
                            choose(ParseResult, close, \{
                              True: (
                                +left_start = {subtract(predicted,
                                  literal_run) : U32}
                                +anchor_end = {U32.add(position, length) : U32}
                                +scan_length = {choose(U32,
                                  U32.is_lt(anchor_end, left_start), \{
                                    True: literal_run
                                    False: minimum(U32.sub(anchor_end,
                                      left_start), literal_run)
                                  }) : U32}
                                apply(PairState & U32, ParseResult,
                                  \{Tuple: next => +gap_matches => (
                                    parse_loop(rest, next,
                                      U32.add(query_position, consumed), True{},
                                      next_position, 0,
                                      U32.add(U32.add(U32.add(region_matches,
                                        length), gap_matches), extension_matches),
                                      U32.add(U32.add(region_mismatches,
                                        U32.sub(literal_run, gap_matches)),
                                        extension_mismatches), counts)
                                  )}, best_gap(Succ{U32.to_nat(scan_length)},
                                    extended_state,
                                    subtract(query_position, literal_run),
                                    predicted, anchor_end, literal_run,
                                    scan_length, 0, 0))
                              )
                              False: (
                                +region_span = {U32.add(region_matches,
                                  region_mismatches) : U32}
                                +pending = {choose(U32,
                                  U32.is_lt(region_span, 35), \{
                                    True: U32.add(region_span, literal_run)
                                    False: literal_run
                                  }) : U32}
                                apply(PairState & Extension, ParseResult,
                                  \{Tuple: backward_state =>
                                    \{Extension: backward_length =>
                                      +backward_matches =>
                                      +backward_mismatches => (
                                        parse_loop(rest, backward_state,
                                          U32.add(query_position, consumed),
                                          True{}, next_position, 0,
                                          U32.add(U32.add(backward_matches,
                                            length), extension_matches),
                                          U32.add(backward_mismatches,
                                            extension_mismatches),
                                          finish_region(region_matches,
                                            region_mismatches, counts))
                                      )}},
                                  extension_backward_loop(U32.to_nat(pending),
                                    extended_state, position, query_position,
                                    FlagsNil{}, 0, 3, 0, 0, 0, 0, 0))
                              )
                            })
                          )}},
                      extension_loop(
                        U32.to_nat(U32.sub(available, length)), found_state,
                        U32.add(position, length),
                        U32.add(query_position, length), FlagsNil{}, 0, 3,
                        0, 0, 0, 0, 0))
                  })
                )}},
              find_anchor(PairState{reference, query, long, short,
                reference_length, query_length}, query_position, available,
                has_prediction, predicted, literal_run, reference_length))
          })

def ratio(+numerator: U32, +denominator: U32) -> U32:
  choose(U32, U32.is_eq(denominator, 0), \{
    True: 0
    False: U32.div(U32.mul(numerator, 10000), denominator)
  })

def metrics(counts: Counts, +query_length: U32) -> Metrics:
  match counts:
    case Counts{+matches, +mismatches, +components}:
      Metrics{matches, mismatches, components,
        ratio(matches, U32.add(matches, mismatches)),
        ratio(matches, query_length),
        ratio(U32.add(matches, mismatches), query_length)}

law score_finish:
  for result: ParseResult
  for +query_length: U32
  ScoreResult

def score_finish(result, query_length):
  match result:
    case ParseResult{PairState{reference, query, long, short, +reference_length,
                               raw_query_length}, counts}:
      ScoreResult{ReferenceIndex{reference, long, short, reference_length},
        metrics(counts, query_length)}

law score:
  for index: ReferenceIndex
  for query: P.Sequence
  for +query_length: U32
  ScoreResult

def score(index, query, query_length):
  score_finish(parse_loop(U32.to_nat(query_length),
    pair_from_query(index, query, query_length), 0, False{}, 0, 0, 0, 0,
    Counts{0, 0, 0}), query_length)
