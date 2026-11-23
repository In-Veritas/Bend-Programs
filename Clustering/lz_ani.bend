# Streaming all-to-all LZ-ANI table. Each reference index is built once, query
# rows are emitted immediately, and no pair matrix is retained.
import Base
import ./lib/common.bend as C
import ./lib/lz_ani_indexed.bend as LZ

law emit_score:
  for result: LZ.ScoreResult
  for +query_index: U32
  for +reference_index: U32
  IO(LZ.ReferenceIndex)

def emit_score(result, query_index, reference_index):
  match result:
    case LZ.ScoreResult{index,
      LZ.Metrics{matches, mismatches, components, ani, gani, coverage}}:
      do IO<LZ.ReferenceIndex>:
        printed: Unit <- IO.print(U32.show(query_index) ++ "\t"
          ++ U32.show(reference_index) ++ "\t" ++ U32.show(matches) ++ "\t"
          ++ U32.show(mismatches) ++ "\t" ++ U32.show(components) ++ "\t"
          ++ U32.show(ani) ++ "\t" ++ U32.show(gani) ++ "\t"
          ++ U32.show(coverage))
        return index

law score_row:
  for items: List<C.Record>
  for index: LZ.ReferenceIndex
  for +reference_index: U32
  IO(Unit)

def score_row(items, index, reference_index):
  match items:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{head, tail}:
      match head:
        case C.Record{+query_index, label, bases, +width, words, sketch}:
          C.branch(IO(Unit), U32.is_eq(query_index, reference_index), \{
            True: score_row(tail, index, reference_index)
            False: do IO<Unit>:
              next: LZ.ReferenceIndex <- emit_score(
                LZ.score(index, bases, width), query_index, reference_index)
              score_row(tail, next, reference_index)
          })

law run_reference:
  for reference: C.Record
  for queries: List<C.Record>
  IO(Unit)

def run_reference(reference, queries):
  match reference:
    case C.Record{+index, label, bases, +width, words, sketch}:
      score_row(queries, LZ.build_index(bases, width), index)

law run_rows:
  for rows: List<C.Record>
  for all: List<C.Record>
  IO(Unit)

def run_rows(rows, all):
  match rows:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{head, tail}:
      C.apply(List<C.Record> & List<C.Record>, IO(Unit),
        \{Tuple: queries => next_all => (
          do IO<Unit>:
            row: Unit <- run_reference(head, queries)
            run_rows(tail, next_all)
        )}, C.records_copy(all))

law run_dataset:
  for dataset: C.Dataset
  IO(Unit)

def run_dataset(dataset):
  match dataset:
    case C.Dataset{items, count}:
      C.apply(List<C.Record> & List<C.Record>, IO(Unit),
        \{Tuple: rows => all => (
          do IO<Unit>:
            header: Unit <- IO.print(
              "qidx\tridx\tnt_match\tnt_mismatch\tnum_alns\tani\tgani\tqcov")
            run_rows(rows, all)
        )}, C.records_copy(items))

law main:
  IO(Unit)

def main():
  do IO<Unit>:
    dataset: C.Dataset <- C.fasta_read(1)
    run_dataset(dataset)
