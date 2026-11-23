# Sparse Kmer-db-compatible candidate prefilter for the LZ-ANI graph.
#
# The default Vclust prefilter uses canonical, per-sample unique 25-mers and
# retains pairs sharing at least 20 values with ani-shorter >= 0.70.  This
# module implements those semantics without a dense pair matrix.  A 65,536
# bucket inverted index stores the full 50-bit key as two U32 words, so hash
# collisions are checked rather than treated as shared k-mers.
import Base
import ./common.bend as C
import ./packing.bend as P
import ./kmer_score.bend as KS

type Posting is Data:
  PostingNil{}
  PostingCon{record: U32, high: U32, low: U32, tail: Posting}

type Candidates is Data:
  CandidatesNil{}
  CandidatesCon{record: U32, tail: Candidates}

type InsertState is Type:
  InsertState{postings: Posting, counts: Array<U32>,
    candidates: Candidates, unique: U32}

type ScanState is Type:
  ScanState{buckets: Array<Posting>, counts: Array<U32>,
    candidates: Candidates, unique: U32}

type EvaluateState is Type:
  EvaluateState{kmer_counts: Array<U32>, counts: Array<U32>,
    rows: Array<C.Neighbors>}

type BuildState is Type:
  BuildState{buckets: Array<Posting>, kmer_counts: Array<U32>,
    counts: Array<U32>, rows: Array<C.Neighbors>}

def same_key(+left_high: U32, +left_low: U32, +right_high: U32,
             +right_low: U32) -> Bool:
  U32.is_eq(left_high, right_high) && U32.is_eq(left_low, right_low)

def key_less(+left_high: U32, +left_low: U32, +right_high: U32,
             +right_low: U32) -> Bool:
  U32.is_lt(left_high, right_high)
    || (U32.is_eq(left_high, right_high) && U32.is_lt(left_low, right_low))

def key_bucket(+high: U32, +low: U32) -> U32:
  U32.and(P.hash30(U32.xor(low, P.hash30(high))), 65535)

# Candidate counters
# ==================

law count_shared:
  for counts: Array<U32>
  for candidates: Candidates
  for +record: U32
  Array<U32> & Candidates

def count_shared(counts, candidates, record):
  C.apply(Array<U32> & U32, Array<U32> & Candidates,
    \{Tuple: next => +previous => (
      updated = Array.set(U32, next, record, U32.add(previous, 1))
      (updated, C.branch(Candidates, U32.is_eq(previous, 0), \{
        True: CandidatesCon{record, candidates}
        False: candidates
      }))
    )}, Array.get(U32, counts, record))

law insert_prepend:
  for result: InsertState
  for +record: U32
  for +high: U32
  for +low: U32
  InsertState

def insert_prepend(result, record, high, low):
  match result:
    case InsertState{postings, counts, candidates, unique}:
      InsertState{PostingCon{record, high, low, postings}, counts,
        candidates, unique}

# Postings belonging to the current record are newer than every older record.
# Thus the first identical (key,record) is encountered before any older copy
# of that key. Stopping there prevents repeated k-mers in one sample from
# incrementing pair counters more than once.
law insert_posting:
  for postings: Posting
  for +record: U32
  for +high: U32
  for +low: U32
  for counts: Array<U32>
  for candidates: Candidates
  for +unique: U32
  InsertState

def insert_posting(postings, record, high, low, counts, candidates, unique):
  match postings:
    case PostingNil{}:
      InsertState{PostingCon{record, high, low, PostingNil{}}, counts,
        candidates, U32.add(unique, 1)}
    case PostingCon{+other, +entry_high, +entry_low, tail}:
      +same = {same_key(high, low, entry_high, entry_low) : Bool}
      C.branch(InsertState, same && U32.is_eq(record, other), \{
        True: InsertState{
          PostingCon{other, entry_high, entry_low, tail}, counts,
          candidates, unique}
        False: C.branch(InsertState, same, \{
          False: insert_prepend(
            insert_posting(tail, record, high, low, counts, candidates,
              unique), other, entry_high, entry_low)
          True: C.apply(Array<U32> & Candidates, InsertState,
            \{Tuple: next_counts => next_candidates => (
              insert_prepend(
                insert_posting(tail, record, high, low, next_counts,
                  next_candidates, unique), other, entry_high, entry_low)
            )}, count_shared(counts, candidates, other))
        })
      })

law scan_inserted:
  for result: InsertState
  for buckets: Array<Posting>
  for +bucket: U32
  ScanState

def scan_inserted(result, buckets, bucket):
  match result:
    case InsertState{postings, counts, candidates, unique}:
      ScanState{Array.set(Posting, buckets, bucket, postings), counts,
        candidates, unique}

law scan_insert:
  for buckets: Array<Posting>
  for counts: Array<U32>
  for candidates: Candidates
  for +unique: U32
  for +record: U32
  for +high: U32
  for +low: U32
  ScanState

def scan_insert(buckets, counts, candidates, unique, record, high, low):
  +bucket = {key_bucket(high, low) : U32}
  C.apply(Array<Posting> & Posting, ScanState,
    \{Tuple: next => postings => (
      scan_inserted(insert_posting(postings, record, high, low, counts,
        candidates, unique), next, bucket)
    )}, Array.get(Posting, buckets, bucket))

# Canonical 25-mers
# ==================

law scan_sequence:
  for fuel: Nat
  for cursor: P.Cursor
  for +record: U32
  for +forward_high: U32
  for +forward_low: U32
  for +reverse_high: U32
  for +reverse_low: U32
  for +valid: U32
  for buckets: Array<Posting>
  for counts: Array<U32>
  for candidates: Candidates
  for +unique: U32
  ScanState

def scan_sequence(fuel, cursor, record, forward_high, forward_low,
                  reverse_high, reverse_low, valid, buckets, counts,
                  candidates, unique):
  match fuel:
    case Zero{}:
      ScanState{buckets, counts, candidates, unique}
    case Succ{rest}:
      C.apply(P.Cursor & U32, ScanState,
        \{Tuple: following => +base => (
          C.branch(ScanState, U32.is_gt(base, 3), \{
            True: scan_sequence(rest, following, record, 0, 0, 0, 0, 0,
              buckets, counts, candidates, unique)
            False: (
              +next_forward_high = {U32.and(U32.or(
                U32.shln(forward_high, 2n), U32.shrn(forward_low, 30n)),
                262143) : U32}
              +next_forward_low = {U32.or(U32.shln(forward_low, 2n), base)
                : U32}
              +next_reverse_high = {U32.or(U32.shrn(reverse_high, 2n),
                U32.shln(U32.sub(3, base), 16n)) : U32}
              +next_reverse_low = {U32.or(U32.shrn(reverse_low, 2n),
                U32.shln(reverse_high, 30n)) : U32}
              +next_valid = {U32.add(valid, 1) : U32}
              +forward_is_canonical = {key_less(next_forward_high,
                next_forward_low, next_reverse_high, next_reverse_low) : Bool}
              +key_high = {C.branch(U32, forward_is_canonical, \{
                True: next_forward_high
                False: next_reverse_high
              }) : U32}
              +key_low = {C.branch(U32, forward_is_canonical, \{
                True: next_forward_low
                False: next_reverse_low
              }) : U32}
              C.branch(ScanState, U32.is_ge(next_valid, 25), \{
                False: scan_sequence(rest, following, record,
                  next_forward_high, next_forward_low, next_reverse_high,
                  next_reverse_low, next_valid, buckets, counts, candidates,
                  unique)
                True: C.apply(ScanState, ScanState,
                  \{ScanState: next_buckets => next_counts =>
                    next_candidates => next_unique => (
                    scan_sequence(rest, following, record, next_forward_high,
                      next_forward_low, next_reverse_high, next_reverse_low,
                      next_valid, next_buckets, next_counts, next_candidates,
                      next_unique)
                  )}, scan_insert(buckets, counts, candidates, unique, record,
                    key_high, key_low))
              })
            )
          })
        )}, P.next(cursor))

law candidate_evaluate:
  for candidates: Candidates
  for +record: U32
  for +record_kmers: U32
  for kmer_counts: Array<U32>
  for counts: Array<U32>
  for rows: Array<C.Neighbors>
  for +minimum_common: U32
  for +minimum_identity: U32
  EvaluateState

def candidate_evaluate(candidates, record, record_kmers, kmer_counts, counts,
                       rows, minimum_common, minimum_identity):
  match candidates:
    case CandidatesNil{}:
      EvaluateState{kmer_counts, counts, rows}
    case CandidatesCon{+target, tail}:
      C.apply(Array<U32> & U32, EvaluateState,
        \{Tuple: next_counts => +common => (
          reset = Array.set(U32, next_counts, target, 0)
          C.apply(Array<U32> & U32, EvaluateState,
            \{Tuple: next_kmer_counts => +target_kmers => (
              +accepted = {KS.candidate_accept(common, target_kmers,
                record_kmers, minimum_common, minimum_identity) : Bool}
              updated = C.branch(Array<C.Neighbors>, accepted, \{
                True: C.sparse_add(rows, target, record, common)
                False: rows
              })
              candidate_evaluate(tail, record, record_kmers,
                next_kmer_counts, reset, updated, minimum_common,
                minimum_identity)
            )}, Array.get(U32, kmer_counts, target))
        )}, Array.get(U32, counts, target))

law build_scanned:
  for scanned: ScanState
  for +record: U32
  for kmer_counts: Array<U32>
  for rows: Array<C.Neighbors>
  for +minimum_common: U32
  for +minimum_identity: U32
  for continue: Array<Posting> -> Array<U32> -> Array<U32> ->
    Array<C.Neighbors> -> BuildState
  BuildState

def build_scanned(scanned, record, kmer_counts, rows, minimum_common,
                  minimum_identity, continue):
  match scanned:
    case ScanState{buckets, counts, candidates, +unique}:
      updated_counts = Array.set(U32, kmer_counts, record, unique)
      C.apply(EvaluateState, BuildState,
        \{EvaluateState: final_kmers => final_counts => final_rows => (
          continue(buckets, final_kmers, final_counts, final_rows)
        )}, candidate_evaluate(candidates, record, unique, updated_counts,
          counts, rows, minimum_common, minimum_identity))

law build_records:
  for items: List<C.Record>
  for buckets: Array<Posting>
  for kmer_counts: Array<U32>
  for counts: Array<U32>
  for rows: Array<C.Neighbors>
  for +minimum_common: U32
  for +minimum_identity: U32
  BuildState

def build_records(items, buckets, kmer_counts, counts, rows, minimum_common,
                  minimum_identity):
  match items:
    case Nil{}:
      BuildState{buckets, kmer_counts, counts, rows}
    case Con{head, tail}:
      match head:
        case C.Record{+index, label, bases, +width, words, sketch}:
          build_scanned(scan_sequence(C.to_nat(width), P.cursor(bases), index,
            0, 0, 0, 0, 0, buckets, counts, CandidatesNil{}, 0), index,
            kmer_counts, rows, minimum_common, minimum_identity,
            next_buckets => next_kmers => next_counts => next_rows =>
              build_records(tail, next_buckets, next_kmers, next_counts,
                next_rows, minimum_common, minimum_identity))

law sparse_graph_built:
  for built: BuildState
  for +size: U32
  C.SparseGraph

def sparse_graph_built(built, size):
  match built:
    case BuildState{buckets, kmer_counts, counts, rows}:
      C.SparseGraph{size, rows}

law sparse_build:
  for items: List<C.Record>
  for +size: U32
  for +minimum_common: U32
  for +minimum_identity: U32
  C.SparseGraph

def sparse_build(items, size, minimum_common, minimum_identity):
  sparse_graph_built(build_records(items,
    Array.new(Posting, 16n, PostingNil{}), C.array_new(size, 0),
    C.array_new(size, 0),
    Array.new(C.Neighbors, C.array_depth(31n, size, 1, 0n),
      C.NeighborsNil{}), minimum_common, minimum_identity), size)
