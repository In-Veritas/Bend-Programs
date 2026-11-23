# Standalone instrumentation for the production global-identity prefilter.
# It parses a real FASTA through common.bend, visits every unordered pair, and
# reports which stage rejected the pair. It deliberately performs no alignment
# or clustering so timings describe candidate discovery only.
import Base
import ../lib/common.bend as C
import ../lib/packing.bend as P

type Stats is Data:
  Stats{pairs: U32, length_rejected: U32, word_rejected: U32, candidates: U32,
    sketch1: U32, sketch2: U32, sketch4: U32, sketch8: U32,
    sketch12: U32, sketch16: U32, sketch24: U32, sketch32: U32, q15: U32}

law stats_length_rejected:
  for stats: Stats
  Stats

def stats_length_rejected(stats):
  match stats:
    case Stats{pairs, length_rejected, word_rejected, candidates,
               sketch1, sketch2, sketch4, sketch8,
               sketch12, sketch16, sketch24, sketch32, q15}:
      Stats{U32.add(pairs, 1), U32.add(length_rejected, 1), word_rejected,
        candidates, sketch1, sketch2, sketch4, sketch8,
        sketch12, sketch16, sketch24, sketch32, q15}

law stats_word_result:
  for stats: Stats
  for candidate: Bool
  for left_bases: P.Sequence
  for right_bases: P.Sequence
  for left_sketch: Array<U32>
  for right_sketch: Array<U32>
  for +left_size: U32
  for +right_size: U32
  for +threshold: U32
  Stats

def stats_word_result(stats, candidate, left_bases, right_bases,
                      left_sketch, right_sketch,
                      left_size, right_size, threshold):
  match stats:
    case Stats{pairs, length_rejected, word_rejected, candidates,
               sketch1, sketch2, sketch4, sketch8,
               sketch12, sketch16, sketch24, sketch32, q15}:
      C.branch(Stats, candidate, \{
        True: (
          +matches = {C.sketch_common(64n, 0, left_sketch, right_sketch, 0) : U32}
          +q15_match = {C.branch(U32, U32.is_ge(matches, 8), \{
            True: C.select(C.q15_candidate(left_bases, right_bases,
              left_size, right_size, threshold), 1, 0)
            False: 0
          }) : U32}
          Stats{U32.add(pairs, 1), length_rejected, word_rejected,
            U32.add(candidates, 1),
            U32.add(sketch1, C.select(U32.is_ge(matches, 1), 1, 0)),
            U32.add(sketch2, C.select(U32.is_ge(matches, 2), 1, 0)),
            U32.add(sketch4, C.select(U32.is_ge(matches, 4), 1, 0)),
            U32.add(sketch8, C.select(U32.is_ge(matches, 8), 1, 0)),
            U32.add(sketch12, C.select(U32.is_ge(matches, 12), 1, 0)),
            U32.add(sketch16, C.select(U32.is_ge(matches, 16), 1, 0)),
            U32.add(sketch24, C.select(U32.is_ge(matches, 24), 1, 0)),
            U32.add(sketch32, C.select(U32.is_ge(matches, 32), 1, 0)),
            U32.add(q15, q15_match)}
        )
        False: (
          Stats{U32.add(pairs, 1), length_rejected,
            U32.add(word_rejected, 1), candidates,
            sketch1, sketch2, sketch4, sketch8,
            sketch12, sketch16, sketch24, sketch32, q15}
        )
      })

law scan_pair:
  for left: C.Record
  for right: C.Record
  for +threshold: U32
  for stats: Stats
  Stats

def scan_pair(left, right, threshold, stats):
  match left right:
    case C.Record{left_index, left_label, left_bases, +left_size, left_words, left_sketch} C.Record{right_index, right_label, right_bases, +right_size, right_words, right_sketch}:
      +longer = {C.maximum(left_size, right_size) : U32}
      +shorter = {C.minimum(left_size, right_size) : U32}
      +required_matches = {U32.div(
        U32.add(U32.mul(threshold, longer), 9999), 10000) : U32}
      C.branch(Stats, U32.is_gt(required_matches, shorter), \{
        True: (
          stats_length_rejected(stats)
        )
        False: (
          stats_word_result(stats,
            C.words_candidate(left_words, right_words, left_size, right_size,
              required_matches), left_bases, right_bases,
              left_sketch, right_sketch, left_size, right_size, threshold)
        )
      })

law scan_row:
  for items: List<C.Record>
  for query: C.Record
  for +threshold: U32
  for stats: Stats
  Stats

def scan_row(items, query, threshold, stats):
  match items:
    case Nil{}:
      stats
    case Con{head, tail}:
      C.apply(C.Record & C.Record, Stats,
        \{Tuple: query_pair => next_query => (
          C.apply(C.Record & C.Record, Stats,
            \{Tuple: head_pair => next_head => (
              next = scan_pair(query_pair, head_pair, threshold, stats)
              scan_row(tail, next_query, threshold, next)
            )},
            C.record_copy(head))
        )},
        C.record_copy(query))

law scan_rows:
  for fuel: Nat
  for items: List<C.Record>
  for +threshold: U32
  for stats: Stats
  Stats

def scan_rows(fuel, items, threshold, stats):
  match fuel items:
    case Zero{} remaining:
      stats
    case Succ{rest} Nil{}:
      stats
    case Succ{rest} Con{head, tail}:
      C.apply(List<C.Record> & List<C.Record>, Stats,
        \{Tuple: row_tail => next_items => (
          next = scan_row(row_tail, head, threshold, stats)
          scan_rows(rest, next_items, threshold, next)
        )},
        C.records_copy(tail))

law print_stats:
  for +records: U32
  for stats: Stats
  IO(Unit)

def print_stats(records, stats):
  match stats:
    case Stats{pairs, length_rejected, word_rejected, candidates,
               sketch1, sketch2, sketch4, sketch8,
               sketch12, sketch16, sketch24, sketch32, q15}:
      do IO<Unit>:
        a: Unit <- IO.print("records\t" ++ U32.show(records))
        b: Unit <- IO.print("pairs\t" ++ U32.show(pairs))
        c: Unit <- IO.print("length_rejected\t" ++ U32.show(length_rejected))
        d: Unit <- IO.print("word_rejected\t" ++ U32.show(word_rejected))
        e: Unit <- IO.print("candidates\t" ++ U32.show(candidates))
        f: Unit <- IO.print("sketch1\t" ++ U32.show(sketch1))
        g: Unit <- IO.print("sketch2\t" ++ U32.show(sketch2))
        h: Unit <- IO.print("sketch4\t" ++ U32.show(sketch4))
        i: Unit <- IO.print("sketch8\t" ++ U32.show(sketch8))
        j: Unit <- IO.print("sketch12\t" ++ U32.show(sketch12))
        k: Unit <- IO.print("sketch16\t" ++ U32.show(sketch16))
        l: Unit <- IO.print("sketch24\t" ++ U32.show(sketch24))
        m: Unit <- IO.print("sketch32\t" ++ U32.show(sketch32))
        IO.print("q15\t" ++ U32.show(q15))

law run_dataset:
  for dataset: C.Dataset
  for +threshold: U32
  IO(Unit)

def run_dataset(dataset, threshold):
  match dataset:
    case C.Dataset{items, +count}:
      print_stats(count,
        scan_rows(C.to_nat(count), items, threshold,
          Stats{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}))

law main:
  IO(Unit)

def main():
  do IO<Unit>:
    threshold: U32 <- C.env_number("CLUSTER_IDENTITY", "9500", 10000)
    dataset: C.Dataset <- C.fasta_read(1)
    run_dataset(dataset, threshold)
