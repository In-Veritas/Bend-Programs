# Vclust-style sparse candidate discovery for Bend's explicit fast mode.
#
# Each record contributes at most one present 15-mer MinHash value to each of
# 64 bins.  An inverted table maps (bin,value) to the records containing it.
# A pair can receive a non-zero fast score only if at least one such entry is
# equal, so the table is complete for the existing fast-score semantics while
# avoiding an unconditional n*n pair walk.  Hash collisions in the table are
# checked against both bin and value before a candidate count is incremented.
import Base
import ./common.bend as C
import ./packing.bend as P
import ./fast_score.bend as F

type Values is Data:
  ValuesNil{}
  ValuesCon{head: U32, tail: Values}

type FastRecord is Data:
  FastRecord{index: U32, width: U32, populated: U32,
    words: Values, sketch: Values}

type Posting is Data:
  PostingNil{}
  PostingCon{record: U32, bin: U32, value: U32, tail: Posting}

type Candidates is Data:
  CandidatesNil{}
  CandidatesCon{record: U32, tail: Candidates}

type FastDataset is Type:
  FastDataset{records: Array<FastRecord>, all_long: Bool}

type IndexState is Type:
  IndexState{records: Array<FastRecord>, buckets: Array<Posting>}

type GatherState is Type:
  GatherState{buckets: Array<Posting>, counts: Array<U32>,
    candidates: Candidates}

type EvaluateState is Type:
  EvaluateState{records: Array<FastRecord>, counts: Array<U32>,
    rows: Array<C.Neighbors>}

type BuildState is Type:
  BuildState{records: Array<FastRecord>, buckets: Array<Posting>,
    counts: Array<U32>, rows: Array<C.Neighbors>}

# Conversions
# ===========

law values_from_array:
  for fuel: Nat
  for +index: U32
  for values: Array<U32>
  Values

def values_from_array(fuel, index, values):
  match fuel:
    case Zero{}:
      ValuesNil{}
    case Succ{rest}:
      C.apply(Array<U32> & U32, Values,
        \{Tuple: next => value => (
          ValuesCon{value, values_from_array(rest, U32.add(index, 1), next)}
        )}, Array.get(U32, values, index))

law values_populated:
  for values: Values
  for +total: U32
  U32

def values_populated(values, total):
  match values:
    case ValuesNil{}:
      total
    case ValuesCon{+head, tail}:
      values_populated(tail, U32.add(total,
        C.select(U32.is_ne(head, 4294967295), 1, 0)))

law fast_record:
  for item: C.Record
  FastRecord

def fast_record(item):
  match item:
    case C.Record{index, label, bases, width, words, sketch}:
      +sketch_values = {values_from_array(64n, 0, sketch) : Values}
      FastRecord{index, width, values_populated(sketch_values, 0),
        values_from_array(256n, 0, words), sketch_values}

law records_fill:
  for items: List<C.Record>
  for records: Array<FastRecord>
  for +all_long: Bool
  FastDataset

law records_fill_item:
  for item: FastRecord
  for records: Array<FastRecord>
  for +all_long: Bool
  for continue: Array<FastRecord> -> Bool -> FastDataset
  FastDataset

def records_fill_item(item, records, all_long, continue):
  match item:
    case FastRecord{+index, +width, +populated, +words, +sketch}:
      next = Array.set(FastRecord, records, index,
        FastRecord{index, width, populated, words, sketch})
      continue(next, all_long && U32.is_ge(width, 15))

def records_fill(items, records, all_long):
  match items:
    case Nil{}:
      FastDataset{records, all_long}
    case Con{head, tail}:
      records_fill_item(fast_record(head), records, all_long,
        next_records => next_long =>
          records_fill(tail, next_records, next_long))

law records_table:
  for items: List<C.Record>
  for +size: U32
  FastDataset

def records_table(items, size):
  records_fill(items,
    Array.new(FastRecord, C.array_depth(31n, size, 1, 0n),
      FastRecord{0, 0, 0, ValuesNil{}, ValuesNil{}}), True{})

law records_all_long:
  for items: List<C.Record>
  List<C.Record> & Bool

def records_all_long(items):
  match items:
    case Nil{}:
      (Nil{}, True{})
    case Con{head, tail}:
      match head:
        case C.Record{index, label, bases, +width, words, sketch}:
          C.apply(List<C.Record> & Bool, List<C.Record> & Bool,
            \{Tuple: rest => long => (
              (Con{C.Record{index, label, bases, width, words, sketch}, rest},
               U32.is_ge(width, 15) && long)
            )}, records_all_long(tail))

# Inverted index
# ==============

law posting_bucket:
  for +bin: U32
  for +value: U32
  U32

def posting_bucket(bin, value):
  U32.and(P.hash30(U32.xor(value, U32.mul(bin, 2654435761))), 65535)

law index_sketch:
  for sketch: Values
  for +bin: U32
  for +record: U32
  for buckets: Array<Posting>
  Array<Posting>

def index_sketch(sketch, bin, record, buckets):
  match sketch:
    case ValuesNil{}:
      buckets
    case ValuesCon{+value, tail}:
      C.branch(Array<Posting>, U32.is_eq(value, 4294967295), \{
        True: index_sketch(tail, U32.add(bin, 1), record, buckets)
        False: (
          +bucket = {posting_bucket(bin, value) : U32}
          C.apply(Array<Posting> & Posting, Array<Posting>,
            \{Tuple: next => postings => (
              updated = Array.set(Posting, next, bucket,
                PostingCon{record, bin, value, postings})
              index_sketch(tail, U32.add(bin, 1), record, updated)
            )}, Array.get(Posting, buckets, bucket))
        )
      })

law index_records:
  for fuel: Nat
  for +index: U32
  for records: Array<FastRecord>
  for buckets: Array<Posting>
  IndexState

law index_record:
  for item: FastRecord
  for records: Array<FastRecord>
  for buckets: Array<Posting>
  for continue: Array<FastRecord> -> Array<Posting> -> IndexState
  IndexState

def index_record(item, records, buckets, continue):
  match item:
    case FastRecord{+record, +width, +populated, +words, +sketch}:
      updated = index_sketch(sketch, 0, record, buckets)
      continue(records, updated)

def index_records(fuel, index, records, buckets):
  match fuel:
    case Zero{}:
      IndexState{records, buckets}
    case Succ{rest}:
      C.apply(Array<FastRecord> & FastRecord, IndexState,
        \{Tuple: next_records => item => (
          index_record(item, next_records, buckets,
            final_records => final_buckets =>
              index_records(rest, U32.add(index, 1), final_records,
                final_buckets))
        )}, Array.get(FastRecord, records, index))

# Candidate collection
# ====================

law postings_gather:
  for postings: Posting
  for +query: U32
  for +bin: U32
  for +value: U32
  for counts: Array<U32>
  for candidates: Candidates
  Array<U32> & Candidates

def postings_gather(postings, query, bin, value, counts, candidates):
  match postings:
    case PostingNil{}:
      (counts, candidates)
    case PostingCon{+record, +entry_bin, +entry_value, tail}:
      +same = {U32.is_gt(record, query) && U32.is_eq(entry_bin, bin)
        && U32.is_eq(entry_value, value) : Bool}
      C.branch(Array<U32> & Candidates, same, \{
        False: postings_gather(tail, query, bin, value, counts, candidates)
        True: (
          C.apply(Array<U32> & U32, Array<U32> & Candidates,
            \{Tuple: next => +count => (
              updated = Array.set(U32, next, record, U32.add(count, 1))
              postings_gather(tail, query, bin, value, updated,
                C.branch(Candidates, U32.is_eq(count, 0), \{
                  True: CandidatesCon{record, candidates}
                  False: candidates
                }))
            )}, Array.get(U32, counts, record))
        )
      })

law gather_sketch:
  for sketch: Values
  for +bin: U32
  for +query: U32
  for buckets: Array<Posting>
  for counts: Array<U32>
  for candidates: Candidates
  GatherState

def gather_sketch(sketch, bin, query, buckets, counts, candidates):
  match sketch:
    case ValuesNil{}:
      GatherState{buckets, counts, candidates}
    case ValuesCon{+value, tail}:
      C.branch(GatherState, U32.is_eq(value, 4294967295), \{
        True: gather_sketch(tail, U32.add(bin, 1), query,
          buckets, counts, candidates)
        False: (
          +bucket = {posting_bucket(bin, value) : U32}
          C.apply(Array<Posting> & Posting, GatherState,
            \{Tuple: next_buckets => postings => (
              C.apply(Array<U32> & Candidates, GatherState,
                \{Tuple: next_counts => next_candidates => (
                  gather_sketch(tail, U32.add(bin, 1), query,
                    next_buckets, next_counts, next_candidates)
                )}, postings_gather(postings, query, bin, value,
                  counts, candidates))
            )}, Array.get(Posting, buckets, bucket))
        )
      })

# Exact preservation of the existing fast-mode score
# ==================================================

law values_common:
  for left: Values
  for right: Values
  for +total: U32
  U32

def values_common(left, right, total):
  match left right:
    case ValuesNil{} remaining:
      total
    case ValuesCon{head, tail} ValuesNil{}:
      total
    case ValuesCon{+left_head, left_tail} ValuesCon{+right_head, right_tail}:
      values_common(left_tail, right_tail,
        U32.add(total, C.minimum(left_head, right_head)))

law values_word_candidate:
  for left: Values
  for right: Values
  for +left_size: U32
  for +right_size: U32
  for +required_matches: U32
  Bool

def values_word_candidate(left, right, left_size, right_size, required_matches):
  interruptions = C.subtract(U32.add(left_size, right_size),
    U32.mul(required_matches, 2))
  +required_words = {C.subtract(required_matches,
    U32.mul(2, U32.add(interruptions, 1))) : U32}
  C.branch(Bool, U32.is_eq(required_words, 0), \{
    True: True{}
    False: U32.is_ge(values_common(left, right, 0), required_words)
  })

law values_global_filter:
  for left: FastRecord
  for right: FastRecord
  for +threshold: U32
  for +shorter_mode: Bool
  Bool

def values_global_filter(left, right, threshold, shorter_mode):
  match left right:
    case FastRecord{li, +left_size, lp, +left_words, ls} FastRecord{ri, +right_size, rp, +right_words, rs}:
      +longer = {C.maximum(left_size, right_size) : U32}
      +shorter = {C.minimum(left_size, right_size) : U32}
      +normalizer = {C.branch(U32, shorter_mode, \{
        True: shorter
        False: longer
      }) : U32}
      +required = {U32.div(U32.add(U32.mul(threshold, normalizer), 9999), 10000)
        : U32}
      C.branch(Bool, U32.is_gt(required, shorter), \{
        True: False{}
        False: values_word_candidate(left_words, right_words,
          left_size, right_size, required)
      })

law indexed_score:
  for +common: U32
  for +populated: U32
  for +threshold: U32
  U32

def indexed_score(common, populated, threshold):
  F.indexed_score(common, populated, threshold)

# Universal certificate: the inverted implementation deliberately delegates
# its final decision to the original fast score, so this equality is checked
# for every possible counter/threshold rather than for a finite fixture.
law indexed_score_agrees:
  for +common: U32
  for +populated: U32
  for +threshold: U32
  {indexed_score(common, populated, threshold)
    == F.score(common, populated, threshold) : U32}

def indexed_score_agrees(common, populated, threshold):
  {==}

# A pair with no shared sketch entry cannot pass the fast-score relation.
# This is the reason the inverted traversal may omit zero-common pairs.
law zero_common_is_rejected:
  for +populated: U32
  for +threshold: U32
  {indexed_score(0, populated, threshold) == 0 : U32}

def zero_common_is_rejected(populated, threshold):
  {==}

law candidate_evaluate:
  for candidates: Candidates
  for +query: FastRecord
  for records: Array<FastRecord>
  for counts: Array<U32>
  for rows: Array<C.Neighbors>
  for +threshold: U32
  for +shorter_mode: Bool
  EvaluateState

law candidate_compare:
  for query: FastRecord
  for other: FastRecord
  for +common: U32
  for records: Array<FastRecord>
  for counts: Array<U32>
  for rows: Array<C.Neighbors>
  for +threshold: U32
  for +shorter_mode: Bool
  for continue: FastRecord -> Array<FastRecord> -> Array<U32> ->
    Array<C.Neighbors> -> EvaluateState
  EvaluateState

def candidate_compare(query, other, common, records, counts, rows,
                      threshold, shorter_mode, continue):
  match query other:
    case FastRecord{+query_index, +query_width, +query_populated,
      +query_words, +query_sketch}
      FastRecord{+other_index, +other_width, +other_populated,
        +other_words, +other_sketch}:
      +populated = {C.minimum(query_populated, other_populated) : U32}
      +score = {indexed_score(common, populated, threshold) : U32}
      +accepted = {U32.is_ge(score, threshold)
        && values_global_filter(
          FastRecord{query_index, query_width, query_populated,
            query_words, query_sketch},
          FastRecord{other_index, other_width, other_populated,
            other_words, other_sketch}, threshold, shorter_mode) : Bool}
      updated = C.branch(Array<C.Neighbors>, accepted, \{
        True: C.sparse_add(rows, query_index, other_index, score)
        False: rows
      })
      continue(
        FastRecord{query_index, query_width, query_populated,
          query_words, query_sketch}, records, counts, updated)

def candidate_evaluate(candidates, query, records, counts, rows, threshold,
                       shorter_mode):
  match candidates:
    case CandidatesNil{}:
      EvaluateState{records, counts, rows}
    case CandidatesCon{+target, tail}:
      C.apply(Array<U32> & U32,
        EvaluateState,
        \{Tuple: next_counts => +common => (
          reset = Array.set(U32, next_counts, target, 0)
          C.apply(Array<FastRecord> & FastRecord,
            EvaluateState,
            \{Tuple: next_records => +other => (
              candidate_compare(query, other, common, next_records,
                reset, rows, threshold, shorter_mode,
                next_query => final_records => final_counts => final_rows =>
                  candidate_evaluate(tail, next_query, final_records,
                    final_counts, final_rows, threshold, shorter_mode))
            )}, Array.get(FastRecord, records, target))
        )}, Array.get(U32, counts, target))

law build_rows:
  for fuel: Nat
  for +index: U32
  for records: Array<FastRecord>
  for buckets: Array<Posting>
  for counts: Array<U32>
  for rows: Array<C.Neighbors>
  for +threshold: U32
  for +shorter_mode: Bool
  BuildState

law build_gathered:
  for +query: FastRecord
  for gathered: GatherState
  for records: Array<FastRecord>
  for rows: Array<C.Neighbors>
  for +threshold: U32
  for +shorter_mode: Bool
  for continue: Array<FastRecord> -> Array<Posting> -> Array<U32> ->
    Array<C.Neighbors> -> BuildState
  BuildState

law build_evaluated:
  for buckets: Array<Posting>
  for evaluated: EvaluateState
  for continue: Array<FastRecord> -> Array<Posting> -> Array<U32> ->
    Array<C.Neighbors> -> BuildState
  BuildState

def build_evaluated(buckets, evaluated, continue):
  match evaluated:
    case EvaluateState{records, counts, rows}:
      continue(records, buckets, counts, rows)

def build_gathered(query, gathered, records, rows, threshold, shorter_mode,
                   continue):
  match gathered:
    case GatherState{next_buckets, next_counts, candidates}:
      build_evaluated(next_buckets,
        candidate_evaluate(candidates, query, records, next_counts,
          rows, threshold, shorter_mode), continue)

law build_row:
  for query: FastRecord
  for records: Array<FastRecord>
  for buckets: Array<Posting>
  for counts: Array<U32>
  for rows: Array<C.Neighbors>
  for +threshold: U32
  for +shorter_mode: Bool
  for continue: Array<FastRecord> -> Array<Posting> -> Array<U32> ->
    Array<C.Neighbors> -> BuildState
  BuildState

def build_row(query, records, buckets, counts, rows, threshold, shorter_mode,
              continue):
  match query:
    case FastRecord{+query_index, +query_width, +query_populated,
      +query_words, +query_sketch}:
      +saved = {FastRecord{query_index, query_width, query_populated,
        query_words, query_sketch} : FastRecord}
      build_gathered(saved,
        gather_sketch(query_sketch, 0, query_index, buckets, counts,
          CandidatesNil{}), records, rows, threshold, shorter_mode, continue)

def build_rows(fuel, index, records, buckets, counts, rows, threshold,
               shorter_mode):
  match fuel:
    case Zero{}:
      BuildState{records, buckets, counts, rows}
    case Succ{rest}:
      C.apply(Array<FastRecord> & FastRecord, BuildState,
        \{Tuple: next_records => +query => (
          build_row(query, next_records, buckets, counts, rows, threshold,
            shorter_mode,
            final_records => final_buckets => final_counts => final_rows =>
              build_rows(rest, U32.add(index, 1), final_records,
                final_buckets, final_counts, final_rows, threshold,
                shorter_mode))
        )}, Array.get(FastRecord, records, index))

law indexed_graph:
  for dataset: FastDataset
  for +size: U32
  for +threshold: U32
  for +shorter_mode: Bool
  C.SparseGraph

law indexed_graph_built:
  for built: BuildState
  for +size: U32
  C.SparseGraph

def indexed_graph_built(built, size):
  match built:
    case BuildState{final_records, final_buckets, final_counts, rows}:
      C.SparseGraph{size, rows}

law indexed_graph_indexed:
  for indexed: IndexState
  for +size: U32
  for +threshold: U32
  for +shorter_mode: Bool
  C.SparseGraph

def indexed_graph_indexed(indexed, size, threshold, shorter_mode):
  match indexed:
    case IndexState{next_records, buckets}:
      indexed_graph_built(
        build_rows(C.to_nat(size), 0, next_records, buckets,
          C.array_new(size, 0),
          Array.new(C.Neighbors, C.array_depth(31n, size, 1, 0n),
            C.NeighborsNil{}), threshold, shorter_mode), size)

def indexed_graph(dataset, size, threshold, shorter_mode):
  match dataset:
    case FastDataset{records, all_long}:
      indexed_graph_indexed(index_records(C.to_nat(size), 0, records,
        Array.new(Posting, 16n, PostingNil{})), size, threshold, shorter_mode)

law sparse_build:
  for items: List<C.Record>
  for +size: U32
  for +threshold: U32
  for +reverse: Bool
  for +fast: Bool
  C.SparseGraph

law sparse_choose:
  for dataset: FastDataset
  for fallback: List<C.Record>
  for +size: U32
  for +threshold: U32
  C.SparseGraph

def sparse_choose(dataset, fallback, size, threshold):
  match dataset:
    case FastDataset{records, +all_long}:
      C.branch(C.SparseGraph, all_long, \{
        True: indexed_graph(FastDataset{records, all_long}, size, threshold,
          False{})
        False: C.sparse_build(fallback, size, threshold, False{}, True{})
      })

law sparse_fast:
  for indexed_items: List<C.Record>
  for fallback: List<C.Record>
  for +size: U32
  for +threshold: U32
  C.SparseGraph

def sparse_fast(indexed_items, fallback, size, threshold):
  sparse_choose(records_table(indexed_items, size), fallback, size, threshold)

# CD-HIT uses the same indexed sketch score but its conservative word gate is
# normalized by the shorter sequence. Callers use this entry only after
# establishing that every record has at least one 15-mer.
law sparse_build_shorter_long:
  for items: List<C.Record>
  for +size: U32
  for +threshold: U32
  C.SparseGraph

def sparse_build_shorter_long(items, size, threshold):
  indexed_graph(records_table(items, size), size, threshold, True{})

def sparse_build(items, size, threshold, reverse, fast):
  C.branch(C.SparseGraph, fast && Bool.not(reverse), \{
    False: C.sparse_build(items, size, threshold, reverse, fast)
    True: C.apply(List<C.Record> & List<C.Record>, C.SparseGraph,
      \{Tuple: indexed_items => fallback => (
        sparse_fast(indexed_items, fallback, size, threshold)
      )}, C.records_copy(items))
  })
