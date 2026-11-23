# Kmer-db-prefiltered sparse tANI graph construction.
#
# Canonical unique 25-mers discover candidate pairs before either LZ-ANI
# direction is parsed. Packed records are held in one compact random-access
# table, while only one reusable left and one temporary right LZ index exist
# during scoring; the old fixed 81,920-bucket index-per-record allocation is
# gone.
import Base
import ./common.bend as C
import ./packing.bend as P
import ./kmer_db.bend as K
import ./lz_ani_indexed.bend as LZ

type PackedWords is Data:
  PackedWordsNil{}
  PackedWordsCon{head: U32, tail: PackedWords}

type PlainRecord is Data:
  PlainRecord{index: U32, words: PackedWords, word_count: U32,
    bits: U32, width: U32}

type RecordSlot is Data:
  RecordSlotEmpty{}
  RecordSlotFull{record: PlainRecord}

type PairResult is Type:
  PairResult{left: PlainRecord, right: PlainRecord,
    left_reference: LZ.ReferenceIndex, rows: Array<C.Neighbors>}

type NeighborResult is Type:
  NeighborResult{records: Array<RecordSlot>, left: PlainRecord,
    left_reference: LZ.ReferenceIndex, rows: Array<C.Neighbors>}

type RowResult is Type:
  RowResult{records: Array<RecordSlot>, rows: Array<C.Neighbors>}

def ratio(+numerator: U32, +denominator: U32) -> U32:
  C.branch(U32, U32.is_eq(denominator, 0), \{
    True: 0
    False: U32.div(U32.mul(numerator, 10000), denominator)
  })

# Compact random-access record table
# ==================================

law words_from_array:
  for fuel: Nat
  for +index: U32
  for words: Array<U32>
  PackedWords

def words_from_array(fuel, index, words):
  match fuel:
    case Zero{}:
      PackedWordsNil{}
    case Succ{rest}:
      C.apply(Array<U32> & U32, PackedWords,
        \{Tuple: next => +word => (
          PackedWordsCon{word, words_from_array(rest, U32.add(index, 1), next)}
        )}, Array.get(U32, words, index))

law words_to_array:
  for words: PackedWords
  for +index: U32
  for values: Array<U32>
  Array<U32>

def words_to_array(words, index, values):
  match words:
    case PackedWordsNil{}:
      values
    case PackedWordsCon{+head, tail}:
      words_to_array(tail, U32.add(index, 1),
        Array.set(U32, values, index, head))

law record_sequence:
  for record: PlainRecord
  PlainRecord & P.Sequence

def record_sequence(record):
  match record:
    case PlainRecord{+index, +words, +word_count, +bits, +width}:
      (PlainRecord{index, words, word_count, bits, width},
       P.Sequence{words_to_array(words, 0, Array.new(U32,
         C.array_depth(31n, word_count, 1, 0n), 0)), bits, width})

law records_fill:
  for items: List<C.Record>
  for records: Array<RecordSlot>
  Array<RecordSlot>

def records_fill(items, records):
  match items:
    case Nil{}:
      records
    case Con{head, tail}:
      match head:
        case C.Record{+index, label, bases, +width, words, sketch}:
          match bases:
            case P.Sequence{packed, +bits, length}:
              +word_count = {U32.div(U32.add(U32.mul(width, bits), 31), 32)
                : U32}
              records_fill(tail, Array.set(RecordSlot, records, index,
                RecordSlotFull{PlainRecord{index,
                  words_from_array(C.to_nat(word_count), 0, packed),
                  word_count, bits, width}}))

law records_table:
  for items: List<C.Record>
  for +size: U32
  Array<RecordSlot>

def records_table(items, size):
  records_fill(items, Array.new(RecordSlot,
    C.array_depth(31n, size, 1, 0n), RecordSlotEmpty{}))

# One symmetric tANI edge
# ======================

law pair_second:
  for left: PlainRecord
  for right: PlainRecord
  for first: LZ.ScoreResult
  for second: LZ.ScoreResult
  for rows: Array<C.Neighbors>
  for +threshold: U32
  PairResult

def pair_second(left, right, first, second, rows, threshold):
  match left right:
    case PlainRecord{+left_index, left_words, +left_word_count, +left_bits,
      +left_width}
      PlainRecord{+right_index, right_words, +right_word_count, +right_bits,
        +right_width}:
      match first second:
        case LZ.ScoreResult{left_reference,
          LZ.Metrics{+left_matches, left_mismatches, left_components, left_ani,
            left_gani, left_coverage}}
          LZ.ScoreResult{right_reference,
          LZ.Metrics{+right_matches, right_mismatches, right_components,
            right_ani, right_gani, right_coverage}}:
          +score = {ratio(U32.add(left_matches, right_matches),
            U32.add(left_width, right_width)) : U32}
          updated = C.branch(Array<C.Neighbors>,
            U32.is_ge(score, threshold), \{
            True: C.sparse_add(rows, left_index, right_index, score)
            False: rows
          })
          PairResult{PlainRecord{left_index, left_words, left_word_count,
            left_bits, left_width}, PlainRecord{right_index, right_words,
            right_word_count, right_bits, right_width}, left_reference,
            updated}

law pair_materialized:
  for left: PlainRecord
  for left_reference: LZ.ReferenceIndex
  for right_query: P.Sequence
  for left_query: P.Sequence
  for right: PlainRecord
  for right_for_index: P.Sequence
  for rows: Array<C.Neighbors>
  for +threshold: U32
  PairResult

def pair_materialized(left, left_reference, right_query, left_query, right,
                      right_for_index, rows, threshold):
  match left right:
    case PlainRecord{+left_index, left_words, +left_word_count, +left_bits,
      +left_width}
      PlainRecord{+right_index, right_words, +right_word_count, +right_bits,
        +right_width}:
      pair_second(PlainRecord{left_index, left_words, left_word_count,
        left_bits, left_width}, PlainRecord{right_index, right_words,
        right_word_count, right_bits, right_width},
        LZ.score(left_reference, right_query, right_width),
        LZ.score(LZ.build_index(right_for_index, right_width), left_query,
          left_width), rows, threshold)

law pair_right_copy:
  for left: PlainRecord
  for left_reference: LZ.ReferenceIndex
  for saved_right: PlainRecord
  for right_query: P.Sequence
  for rows: Array<C.Neighbors>
  for +threshold: U32
  PairResult

def pair_right_copy(left, left_reference, saved_right, right_query,
                    rows, threshold):
  C.apply(PlainRecord & P.Sequence, PairResult,
    \{Tuple: final_left => left_query => (
      C.apply(PlainRecord & P.Sequence, PairResult,
        \{Tuple: final_right => right_for_index => (
          pair_materialized(final_left, left_reference, right_query,
            left_query, final_right, right_for_index, rows, threshold)
        )}, record_sequence(saved_right))
    )}, record_sequence(left))

law pair_one:
  for left: PlainRecord
  for right: PlainRecord
  for left_reference: LZ.ReferenceIndex
  for rows: Array<C.Neighbors>
  for +threshold: U32
  PairResult

def pair_one(left, right, left_reference, rows, threshold):
  C.apply(PlainRecord & P.Sequence, PairResult,
    \{Tuple: saved_right => right_query => (
      pair_right_copy(left, left_reference, saved_right, right_query, rows,
        threshold)
    )}, record_sequence(right))

# Candidate-only traversal
# ========================

law neighbor_paired:
  for result: PairResult
  for records: Array<RecordSlot>
  for +target: U32
  NeighborResult

def neighbor_paired(result, records, target):
  match result:
    case PairResult{left, right, left_reference, rows}:
      NeighborResult{Array.set(RecordSlot, records, target,
        RecordSlotFull{right}), left, left_reference, rows}

law score_neighbor:
  for slot: RecordSlot
  for records: Array<RecordSlot>
  for left: PlainRecord
  for left_reference: LZ.ReferenceIndex
  for rows: Array<C.Neighbors>
  for +target: U32
  for +threshold: U32
  NeighborResult

def score_neighbor(slot, records, left, left_reference, rows, target,
                   threshold):
  match slot:
    case RecordSlotEmpty{}:
      NeighborResult{records, left, left_reference, rows}
    case RecordSlotFull{right}:
      neighbor_paired(pair_one(left, right, left_reference, rows, threshold),
        records, target)

law score_neighbors:
  for neighbors: C.Neighbors
  for +left_index: U32
  for records: Array<RecordSlot>
  for left: PlainRecord
  for left_reference: LZ.ReferenceIndex
  for rows: Array<C.Neighbors>
  for +threshold: U32
  NeighborResult

def score_neighbors(neighbors, left_index, records, left, left_reference,
                    rows, threshold):
  match neighbors:
    case C.NeighborsNil{}:
      NeighborResult{records, left, left_reference, rows}
    case C.NeighborsCon{+target, score, tail}:
      C.branch(NeighborResult, U32.is_gt(target, left_index), \{
        False: score_neighbors(tail, left_index, records, left,
          left_reference, rows, threshold)
        True: C.apply(Array<RecordSlot> & RecordSlot, NeighborResult,
          \{Tuple: next => slot => (
            C.apply(NeighborResult, NeighborResult,
              \{NeighborResult: final_records => final_left =>
                final_reference => final_rows => (
                score_neighbors(tail, left_index, final_records, final_left,
                  final_reference, final_rows, threshold)
              )}, score_neighbor(slot, next, left, left_reference, rows,
                target, threshold))
          )}, Array.get(RecordSlot, records, target))
      })

law score_row_finished:
  for result: NeighborResult
  for +left_index: U32
  RowResult

def score_row_finished(result, left_index):
  match result:
    case NeighborResult{records, left, left_reference, rows}:
      RowResult{Array.set(RecordSlot, records, left_index,
        RecordSlotFull{left}), rows}

law score_row_record:
  for record: PlainRecord
  for for_index: P.Sequence
  for records: Array<RecordSlot>
  for neighbors: C.Neighbors
  for +left_index: U32
  for rows: Array<C.Neighbors>
  for +threshold: U32
  RowResult

def score_row_record(record, for_index, records, neighbors, left_index, rows,
                     threshold):
  match record:
    case PlainRecord{+index, words, +word_count, +bits, +width}:
      score_row_finished(score_neighbors(neighbors, left_index, records,
        PlainRecord{index, words, word_count, bits, width},
        LZ.build_index(for_index, width), rows, threshold), left_index)

law score_row_slot:
  for slot: RecordSlot
  for records: Array<RecordSlot>
  for neighbors: C.Neighbors
  for +left_index: U32
  for rows: Array<C.Neighbors>
  for +threshold: U32
  RowResult

def score_row_slot(slot, records, neighbors, left_index, rows, threshold):
  match slot:
    case RecordSlotEmpty{}:
      RowResult{records, rows}
    case RecordSlotFull{left}:
      C.apply(PlainRecord & P.Sequence, RowResult,
        \{Tuple: saved => for_index => (
          score_row_record(saved, for_index, records, neighbors, left_index,
            rows, threshold)
        )}, record_sequence(left))

law score_row:
  for neighbors: C.Neighbors
  for records: Array<RecordSlot>
  for +left_index: U32
  for rows: Array<C.Neighbors>
  for +threshold: U32
  RowResult

def score_row(neighbors, records, left_index, rows, threshold):
  match neighbors:
    case C.NeighborsNil{}:
      RowResult{records, rows}
    case C.NeighborsCon{target, score, tail}:
      C.apply(Array<RecordSlot> & RecordSlot, RowResult,
        \{Tuple: next => slot => (
          score_row_slot(slot, next, C.NeighborsCon{target, score, tail},
            left_index, rows, threshold)
        )}, Array.get(RecordSlot, records, left_index))

law score_rows:
  for fuel: Nat
  for +left_index: U32
  for candidate_rows: Array<C.Neighbors>
  for records: Array<RecordSlot>
  for rows: Array<C.Neighbors>
  for +threshold: U32
  Array<C.Neighbors>

def score_rows(fuel, left_index, candidate_rows, records, rows, threshold):
  match fuel:
    case Zero{}:
      rows
    case Succ{rest}:
      C.apply(Array<C.Neighbors> & C.Neighbors, Array<C.Neighbors>,
        \{Tuple: next_candidates => neighbors => (
          C.apply(RowResult, Array<C.Neighbors>,
            \{RowResult: final_records => final_rows => (
              score_rows(rest, U32.add(left_index, 1), next_candidates,
                final_records, final_rows, threshold)
            )}, score_row(neighbors, records, left_index, rows, threshold))
        )}, Array.get(C.Neighbors, candidate_rows, left_index))

law score_candidates:
  for candidates: C.SparseGraph
  for items: List<C.Record>
  for +size: U32
  for +threshold: U32
  C.SparseGraph

def score_candidates(candidates, items, size, threshold):
  match candidates:
    case C.SparseGraph{candidate_size, candidate_rows}:
      C.SparseGraph{size, score_rows(C.to_nat(size), 0, candidate_rows,
        records_table(items, size),
        Array.new(C.Neighbors, C.array_depth(31n, size, 1, 0n),
          C.NeighborsNil{}), threshold)}

law sparse_build:
  for items: List<C.Record>
  for +size: U32
  for +threshold: U32
  for +minimum_common: U32
  for +minimum_identity: U32
  C.SparseGraph

def sparse_build(items, size, threshold, minimum_common, minimum_identity):
  C.apply(List<C.Record> & List<C.Record>, C.SparseGraph,
    \{Tuple: for_prefilter => for_scoring => (
      score_candidates(K.sparse_build(for_prefilter, size, minimum_common,
        minimum_identity), for_scoring, size, threshold)
    )}, C.records_copy(items))
