# Shared FASTA IO, DNA/RNA normalization, exact alignment, and output.
import Base
import ./packing.bend as P
import ./fast_score.bend as F

def apply(-A: Type, -B: Type, body: A -> B, value: A) -> B:
  body(value)

def branch(-A: Type, condition: Bool, body: Bool -> A) -> A:
  body(condition)

# Types
# =====

type Record is Type:
  Record{index: U32, label: String, bases: P.Sequence, width: U32,
    words: Array<U32>, sketch: Array<U32>}

type Dataset is Type:
  Dataset{items: List<Record>, count: U32}

type Config is Type:
  Config{identity: U32, alphabet: U32, reverse: Bool, fast: Bool, lz: Bool,
    kmer_minimum: U32, kmer_identity: U32, resolution: U32, seed: U32,
    passes: Nat}

type Neighbors is Data:
  NeighborsNil{}
  NeighborsCon{target: U32, score: U32, tail: Neighbors}

type SparseGraph is Type:
  SparseGraph{size: U32, rows: Array<Neighbors>}

# Utilities
# =========

law minimum:
  for +a: U32
  for +b: U32
  U32

def minimum(a, b):
  branch(U32, U32.is_lt(a, b), \{
    True: (
      a
    )
    False: (
      b
    )
  })

law maximum:
  for +a: U32
  for +b: U32
  U32

def maximum(a, b):
  branch(U32, U32.is_gt(a, b), \{
    True: (
      a
    )
    False: (
      b
    )
  })

law subtract:
  for +a: U32
  for +b: U32
  U32

def subtract(a, b):
  branch(U32, U32.is_lt(a, b), \{
    True: (
      0
    )
    False: (
      U32.sub(a, b)
    )
  })

law to_nat:
  for value: U32
  Nat

def to_nat(value):
  U32.to_nat(value)

law select:
  for condition: Bool
  for yes: U32
  for no: U32
  U32

def select(condition, yes, no):
  branch(U32, condition, \{
    True: (
      yes
    )
    False: (
      no
    )
  })

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
      branch(Nat, U32.is_le(size, capacity), \{
        True: (
          depth
        )
        False: (
          array_depth(rest, size, U32.mul(capacity, 2), Succ{depth})
        )
      })

law array_new:
  for size: U32
  for value: U32
  Array<U32>

def array_new(size, value):
  Array.new(U32, array_depth(31n, size, 1, 0n), value)

law array_identity:
  for fuel: Nat
  for +index: U32
  for values: Array<U32>
  Array<U32>

def array_identity(fuel, index, values):
  match fuel:
    case Zero{}:
      values
    case Succ{rest}:
      next = Array.set(U32, values, index, index)
      array_identity(rest, U32.add(index, 1), next)

law labels_identity:
  for +size: U32
  Array<U32>

def labels_identity(size):
  array_identity(to_nat(size), 0, array_new(size, 0))

law list_reverse:
  for -A: Type
  for values: List<A>
  for result: List<A>
  List<A>

def list_reverse(A, values, result):
  match values:
    case Nil{}:
      result
    case Con{head, tail}:
      list_reverse(A, tail, Con{head, result})

law string_reverse:
  for value: String
  for result: String
  String

def string_reverse(value, result):
  match value:
    case SNil{}:
      result
    case SCon{head, tail}:
      string_reverse(tail, SCon{head, result})

law string_length:
  for value: String
  for length: U32
  U32

def string_length(value, length):
  match value:
    case SNil{}:
      length
    case SCon{head, tail}:
      string_length(tail, U32.add(length, 1))

law string_copy:
  for +text: String
  String & String

def string_copy(text):
  (text, text)

def record_copy(item: Record) -> Record & Record:
  match item:
    case Record{+index, +label, bases, +width, words, sketch}:
      apply(P.Sequence & P.Sequence, Record & Record,
        \{Tuple: left_bases => right_bases => (
          apply(Array<U32> & Array<U32>, Record & Record,
            \{Tuple: left_words => right_words => (
              apply(Array<U32> & Array<U32>, Record & Record,
                \{Tuple: left_sketch => right_sketch => (
                  (Record{index, label, left_bases, width, left_words, left_sketch},
                   Record{index, label, right_bases, width, right_words, right_sketch})
                )},
                Array.clone(U32, sketch))
            )},
            Array.clone(U32, words))
        )},
        P.copy(bases))

law records_copy_loop:
  for items: List<Record>
  for left: List<Record>
  for right: List<Record>
  List<Record> & List<Record>

def records_copy_loop(items, left, right):
  match items:
    case Nil{}:
      (list_reverse(Record, left, Nil{}), list_reverse(Record, right, Nil{}))
    case Con{head, tail}:
      apply(Record & Record, List<Record> & List<Record>,
        \{Tuple: h1 => h2 => (
          records_copy_loop(tail, Con{h1, left}, Con{h2, right})
        )},
        record_copy(head))

law records_copy:
  for items: List<Record>
  List<Record> & List<Record>

def records_copy(items):
  records_copy_loop(items, Nil{}, Nil{})

law record_precedes:
  for left: Record
  for right: Record
  Bool

def record_precedes(left, right):
  match left right:
    case Record{li, ll, lb, lw, lwords, lsketch} Record{ri, rl, rb, rw, rwords, rsketch}:
      +a = {lw : U32}
      +b = {rw : U32}
      U32.is_gt(a, b) || (U32.is_eq(a, b) && U32.is_lt(li, ri))

type RecordRuns is Type:
  RecordRunsNil{}
  RecordRunsCon{run: List<Record>, rest: RecordRuns}

law records_with_length:
  for items: List<Record>
  List<Record> & Nat

def records_with_length(items):
  match items:
    case Nil{}:
      (Nil{}, 0n)
    case Con{head, tail}:
      apply(List<Record> & Nat, List<Record> & Nat,
        \{Tuple: rest => length => (
          (Con{head, rest}, Succ{length})
        )},
        records_with_length(tail))

law records_merge_loop:
  for fuel: Nat
  for left: List<Record>
  for right: List<Record>
  List<Record>

def records_merge_loop(fuel, left, right):
  match fuel:
    case Zero{}:
      match left:
        case Nil{}:
          right
        case Con{head, tail}:
          Con{head, tail}
    case Succ{rest}:
      match left right:
        case Nil{} remaining:
          remaining
        case Con{head, tail} Nil{}:
          Con{head, tail}
        case Con{left_head, left_tail} Con{right_head, right_tail}:
          apply(Record & Record, List<Record>,
            \{Tuple: left_test => left_value => (
              apply(Record & Record, List<Record>,
                \{Tuple: right_test => right_value => (
                  branch(List<Record>, record_precedes(left_test, right_test), \{
                    True: (
                      Con{left_value,
                        records_merge_loop(rest, left_tail, Con{right_value, right_tail})}
                    )
                    False: (
                      Con{right_value,
                        records_merge_loop(rest, Con{left_value, left_tail}, right_tail)}
                    )
                  })
                )},
                record_copy(right_head))
            )},
            record_copy(left_head))

law records_merge_ready:
  for left: List<Record> & Nat
  for right: List<Record> & Nat
  List<Record>

def records_merge_ready(left, right):
  match left right:
    case Tuple{left_items, left_length} Tuple{right_items, right_length}:
      records_merge_loop(Nat.add(left_length, right_length), left_items, right_items)

law records_merge:
  for left: List<Record>
  for right: List<Record>
  List<Record>

def records_merge(left, right):
  records_merge_ready(records_with_length(left), records_with_length(right))

law records_carry:
  for runs: RecordRuns
  for run: List<Record>
  RecordRuns

def records_carry(runs, run):
  match runs:
    case RecordRunsNil{}:
      RecordRunsCon{run, RecordRunsNil{}}
    case RecordRunsCon{Nil{}, rest}:
      RecordRunsCon{run, rest}
    case RecordRunsCon{Con{head, tail}, rest}:
      RecordRunsCon{Nil{}, records_carry(rest, records_merge(Con{head, tail}, run))}

law records_to_runs:
  for items: List<Record>
  RecordRuns

def records_to_runs(items):
  match items:
    case Nil{}:
      RecordRunsNil{}
    case Con{head, tail}:
      records_carry(records_to_runs(tail), Con{head, Nil{}})

law records_collapse:
  for runs: RecordRuns
  List<Record>

def records_collapse(runs):
  match runs:
    case RecordRunsNil{}:
      Nil{}
    case RecordRunsCon{run, rest}:
      records_merge(run, records_collapse(rest))

law records_sort:
  for items: List<Record>
  List<Record>

def records_sort(items):
  records_collapse(records_to_runs(items))

law complement:
  for +code: U32
  U32

def complement(code):
  branch(U32, U32.is_eq(code, 65), \{
    True: (
      84
    )
    False: (
      branch(U32, U32.is_eq(code, 84), \{
        True: (
          65
        )
        False: (
          branch(U32, U32.is_eq(code, 67), \{
            True: (
              71
            )
            False: (
              branch(U32, U32.is_eq(code, 71), \{
                True: (
                  67
                )
                False: (
                  branch(U32, U32.is_eq(code, 82), \{
                    True: (
                      89
                    )
                    False: (
                      branch(U32, U32.is_eq(code, 89), \{
                        True: (
                          82
                        )
                        False: (
                          branch(U32, U32.is_eq(code, 75), \{
                            True: (
                              77
                            )
                            False: (
                              branch(U32, U32.is_eq(code, 77), \{
                                True: (
                                  75
                                )
                                False: (
                                  branch(U32, U32.is_eq(code, 66), \{
                                    True: (
                                      86
                                    )
                                    False: (
                                      branch(U32, U32.is_eq(code, 86), \{
                                        True: (
                                          66
                                        )
                                        False: (
                                          branch(U32, U32.is_eq(code, 68), \{
                                            True: (
                                              72
                                            )
                                            False: (
                                              branch(U32, U32.is_eq(code, 72), \{
                                                True: (
                                                  68
                                                )
                                                False: (
                                                  code
                                                )
                                              })
                                            )
                                          })
                                        )
                                      })
                                    )
                                  })
                                )
                              })
                            )
                          })
                        )
                      })
                    )
                  })
                )
              })
            )
          })
        )
      })
    )
  })

law reverse_complement:
  for text: String
  for result: String
  String

def reverse_complement(text, result):
  match text:
    case SNil{}:
      result
    case SCon{Chr{code}, tail}:
      head = {Chr{complement(code)} : Char}
      reverse_complement(tail, SCon{head, result})

type AlignmentCell is Data:
  AlignmentCell{edits: U32, matches: U32}

law alignment_minimum:
  for left: AlignmentCell
  for right: AlignmentCell
  AlignmentCell

def alignment_minimum(left, right):
  match left right:
    case AlignmentCell{+left_edits, +left_matches} AlignmentCell{+right_edits, +right_matches}:
      branch(AlignmentCell,
        U32.is_lt(left_edits, right_edits) ||
        (U32.is_eq(left_edits, right_edits) && U32.is_ge(left_matches, right_matches)), \{
        True: (
          AlignmentCell{left_edits, left_matches}
        )
        False: (
          AlignmentCell{right_edits, right_matches}
        )
      })

law alignment_indel:
  for cell: AlignmentCell
  AlignmentCell

def alignment_indel(cell):
  match cell:
    case AlignmentCell{edits, matches}:
      AlignmentCell{U32.add(edits, 1), matches}

law alignment_initial:
  for fuel: Nat
  for +index: U32
  for row: Array<AlignmentCell>
  Array<AlignmentCell>

def alignment_initial(fuel, index, row):
  match fuel:
    case Zero{}:
      row
    case Succ{rest}:
      next = Array.set(AlignmentCell, row, index, AlignmentCell{index, 0})
      alignment_initial(rest, U32.add(index, 1), next)

law alignment_diagonal:
  for base: U32
  for code: U32
  for diagonal: AlignmentCell
  AlignmentCell

def alignment_diagonal(base, code, diagonal):
  match diagonal:
    case AlignmentCell{edits, matches}:
      branch(AlignmentCell, U32.is_eq(base, code), \{
        True: (
          AlignmentCell{edits, U32.add(matches, 1)}
        )
        False: (
          AlignmentCell{U32.add(edits, 1), matches}
        )
      })

law alignment_columns:
  for text: String
  for +base: U32
  for +index: U32
  for diagonal: AlignmentCell
  for left: AlignmentCell
  for row: Array<AlignmentCell>
  Array<AlignmentCell>

def alignment_columns(text, base, index, diagonal, left, row):
  match text:
    case SNil{}:
      row
    case SCon{Chr{code}, tail}:
      apply(Array<AlignmentCell> & AlignmentCell, Array<AlignmentCell>,
        \{Tuple: next => above_raw => (
          +above = {above_raw : AlignmentCell}
          diagonal_cost = alignment_diagonal(base, code, diagonal)
          +cell = {alignment_minimum(diagonal_cost,
            alignment_indel(alignment_minimum(left, above))) : AlignmentCell}
          updated = Array.set(AlignmentCell, next, index, cell)
          alignment_columns(tail, base, U32.add(index, 1), above, cell, updated)
        )},
        Array.get(AlignmentCell, row, index))

law alignment_rows:
  for text: String
  for other: String
  for +index: U32
  for row: Array<AlignmentCell>
  Array<AlignmentCell>

def alignment_rows(text, other, index, row):
  match text:
    case SNil{}:
      row
    case SCon{Chr{code}, tail}:
      apply(String & String, Array<AlignmentCell>,
        \{Tuple: o1 => o2 => (
          +row_index = {index : U32}
          +left = {AlignmentCell{row_index, 0} : AlignmentCell}
          initialized = Array.set(AlignmentCell, row, 0, left)
          next = alignment_columns(o1, code, 1,
            AlignmentCell{U32.sub(row_index, 1), 0}, left, initialized)
          alignment_rows(tail, o2, U32.add(index, 1), next)
        )},
        string_copy(other))

law alignment_text:
  for left: String
  for right: String
  for +left_size: U32
  for +right_size: U32
  for shorter: Bool
  U32

law alignment_score:
  for cell: AlignmentCell
  for +left_size: U32
  for +right_size: U32
  for shorter: Bool
  U32

def alignment_score(cell, left_size, right_size, shorter):
  match cell:
    case AlignmentCell{edits, +matches}:
      branch(U32, shorter, \{
        True: (
          U32.div(U32.mul(matches, 10000), minimum(left_size, right_size))
        )
        False: (
          U32.div(U32.mul(matches, 10000), U32.add(matches, edits))
        )
      })

def alignment_text(left, right, left_size, right_size, shorter):
  row = alignment_initial(to_nat(U32.add(right_size, 1)), 0,
    Array.new(AlignmentCell, array_depth(31n, U32.add(right_size, 1), 1, 0n),
      AlignmentCell{0, 0}))
  result = alignment_rows(left, right, 1, row)
  apply(Array<AlignmentCell> & AlignmentCell, U32,
    \{Tuple: unused => cell => (
      alignment_score(cell, left_size, right_size, shorter)
    )},
    Array.get(AlignmentCell, result, right_size))

# Threshold-aware exact alignment
# -------------------------------
# Any alignment that can reach the requested identity has a bounded edit
# distance. Cells farther than that distance from the main diagonal cannot be
# part of a qualifying path, so they are represented by one saturated
# sentinel instead of being evaluated. A surviving result is the same
# minimum-edit / maximum-match result as alignment_text.

law alignment_edit_limit:
  for +left_size: U32
  for +right_size: U32
  for +threshold: U32
  for shorter: Bool
  U32

def alignment_edit_limit(left_size, right_size, threshold, shorter):
  +small = {minimum(left_size, right_size) : U32}
  +large = {maximum(left_size, right_size) : U32}
  branch(U32, shorter, \{
    True: (
      +required = {U32.div(U32.add(U32.mul(threshold, small), 9999), 10000)
        : U32}
      U32.add(U32.sub(large, small), U32.mul(subtract(small, required), 2))
    )
    False: (
      minimum(large,
        U32.div(U32.mul(small, U32.sub(10000, threshold)), threshold))
    )
  })

law alignment_bounded_indel:
  for cell: AlignmentCell
  for +sentinel: U32
  AlignmentCell

def alignment_bounded_indel(cell, sentinel):
  match cell:
    case AlignmentCell{+edits, +matches}:
      branch(AlignmentCell, U32.is_ge(edits, sentinel), \{
        True: AlignmentCell{sentinel, 0}
        False: AlignmentCell{U32.add(edits, 1), matches}
      })

law alignment_bounded_diagonal:
  for +base: U32
  for +code: U32
  for cell: AlignmentCell
  for +sentinel: U32
  AlignmentCell

def alignment_bounded_diagonal(base, code, cell, sentinel):
  match cell:
    case AlignmentCell{+edits, +matches}:
      branch(AlignmentCell, U32.is_ge(edits, sentinel), \{
        True: AlignmentCell{sentinel, 0}
        False: (
          branch(AlignmentCell, U32.is_eq(base, code), \{
            True: AlignmentCell{edits, U32.add(matches, 1)}
            False: AlignmentCell{U32.add(edits, 1), matches}
          })
        )
      })

law alignment_banded_initial:
  for fuel: Nat
  for +index: U32
  for row: Array<AlignmentCell>
  Array<AlignmentCell>

def alignment_banded_initial(fuel, index, row):
  match fuel:
    case Zero{}:
      row
    case Succ{rest}:
      alignment_banded_initial(rest, U32.add(index, 1),
        Array.set(AlignmentCell, row, index, AlignmentCell{index, 0}))

law alignment_banded_columns:
  for fuel: Nat
  for cursor: P.Cursor
  for +base: U32
  for +index: U32
  for diagonal: AlignmentCell
  for left: AlignmentCell
  for row: Array<AlignmentCell>
  for +sentinel: U32
  P.Cursor & Array<AlignmentCell>

def alignment_banded_columns(fuel, cursor, base, index, diagonal, left, row,
                             sentinel):
  match fuel:
    case Zero{}:
      (cursor, row)
    case Succ{rest}:
      apply(P.Cursor & U32, P.Cursor & Array<AlignmentCell>,
        \{Tuple: following => +code => (
          apply(Array<AlignmentCell> & AlignmentCell,
            P.Cursor & Array<AlignmentCell>,
            \{Tuple: next => +above => (
              diagonal_cost = alignment_bounded_diagonal(base, code, diagonal,
                sentinel)
              +cell = {alignment_minimum(diagonal_cost,
                alignment_bounded_indel(alignment_minimum(left, above), sentinel))
                : AlignmentCell}
              alignment_banded_columns(rest, following, base,
                U32.add(index, 1), above, cell,
                Array.set(AlignmentCell, next, index, cell), sentinel)
            )},
            Array.get(AlignmentCell, row, index))
        )},
        P.next(cursor))

law alignment_banded_rows:
  for fuel: Nat
  for left: P.Cursor
  for right: Array<U32>
  for +right_bits: U32
  for +right_size: U32
  for +index: U32
  for row: Array<AlignmentCell>
  for +limit: U32
  for +sentinel: U32
  Array<AlignmentCell>

def alignment_banded_rows(fuel, left, right, right_bits, right_size, index,
                          row, limit, sentinel):
  match fuel:
    case Zero{}:
      row
    case Succ{rest}:
      apply(P.Cursor & U32, Array<AlignmentCell>, \{Tuple: next_left => +base => (
        +low = {maximum(1, subtract(index, limit)) : U32}
        +high = {minimum(right_size, U32.add(index, limit)) : U32}
        +boundary = {U32.sub(low, 1) : U32}
        apply(Array<AlignmentCell> & AlignmentCell, Array<AlignmentCell>,
          \{Tuple: before => +diagonal => (
            +left_cell = {branch(AlignmentCell, U32.is_eq(low, 1), \{
              True: AlignmentCell{index, 0}
              False: AlignmentCell{sentinel, 0}
            }) : AlignmentCell}
            prepared = Array.set(AlignmentCell, before, boundary, left_cell)
            apply(P.Cursor & Array<AlignmentCell>, Array<AlignmentCell>,
              \{Tuple: after_cursor => after_columns => (
                next_right = P.cursor_words(after_cursor)
                +past = {U32.add(high, 1) : U32}
                bounded = branch(Array<AlignmentCell>,
                  U32.is_le(past, right_size), \{
                    True: Array.set(AlignmentCell, after_columns, past,
                      AlignmentCell{sentinel, 0})
                    False: after_columns
                  })
                alignment_banded_rows(rest, next_left, next_right, right_bits,
                  right_size, U32.add(index, 1), bounded, limit, sentinel)
              )},
              alignment_banded_columns(
                to_nat(U32.add(U32.sub(high, low), 1)),
                P.cursor_at(right, right_bits, boundary),
                base, low, diagonal, left_cell, prepared, sentinel))
          )},
          Array.get(AlignmentCell, row, boundary))
      )}, P.next(left))

law alignment_banded:
  for left: P.Sequence
  for right: P.Sequence
  for +left_size: U32
  for +right_size: U32
  for +shorter: Bool
  for +threshold: U32
  U32

law alignment_banded_run:
  for left: P.Sequence
  for right: P.Sequence
  for +left_size: U32
  for +right_size: U32
  for shorter: Bool
  for +limit: U32
  for +sentinel: U32
  U32

law alignment_banded_score:
  for cell: AlignmentCell
  for +left_size: U32
  for +right_size: U32
  for shorter: Bool
  for +limit: U32
  U32

def alignment_banded_score(cell, left_size, right_size, shorter, limit):
  match cell:
    case AlignmentCell{+edits, +matches}:
      branch(U32, U32.is_gt(edits, limit), \{
        True: 0
        False: alignment_score(AlignmentCell{edits, matches},
          left_size, right_size, shorter)
      })

def alignment_banded_run(left, right, left_size, right_size, shorter, limit,
                         sentinel):
  match left right:
    case P.Sequence{left_words, left_bits, left_length}
         P.Sequence{right_words, right_bits, right_length}:
      +width = {U32.add(right_size, 1) : U32}
      row = alignment_banded_initial(
        to_nat(U32.add(minimum(right_size, limit), 1)), 0,
        Array.new(AlignmentCell, array_depth(31n, width, 1, 0n),
          AlignmentCell{sentinel, 0}))
      result = alignment_banded_rows(to_nat(left_size),
        P.Cursor{left_words, left_bits, 0, 0, 0}, right_words, right_bits,
        right_size, 1, row, limit, sentinel)
      apply(Array<AlignmentCell> & AlignmentCell, U32,
        \{Tuple: unused => cell => (
          alignment_banded_score(cell, left_size, right_size, shorter, limit)
        )},
        Array.get(AlignmentCell, result, right_size))

def alignment_banded(left, right, left_size, right_size, shorter, threshold):
  +limit = {alignment_edit_limit(left_size, right_size, threshold, shorter) : U32}
  +sentinel = {U32.add(limit, 1) : U32}
  branch(U32, U32.is_gt(subtract(maximum(left_size, right_size),
    minimum(left_size, right_size)), limit), \{
    True: 0
    False: (
      alignment_banded_run(left, right, left_size, right_size, shorter, limit,
        sentinel)
    )
  })

def sequence_copy(sequence: P.Sequence) -> P.Sequence & P.Sequence:
  P.copy(sequence)

def sequence_reverse(sequence: P.Sequence, +length: U32) -> P.Sequence:
  P.pack(reverse_complement(P.unpack(sequence), ""), length)

def sequence_text(sequence: P.Sequence) -> String:
  P.unpack(sequence)

def alignment_identity(left: P.Sequence, right: P.Sequence, left_size: U32,
                       right_size: U32, shorter: Bool) -> U32:
  alignment_text(P.unpack(left), P.unpack(right), left_size, right_size, shorter)

law alignment_identity_threshold:
  for left: P.Sequence
  for right: P.Sequence
  for +left_size: U32
  for +right_size: U32
  for shorter: Bool
  for +threshold: U32
  U32

def alignment_identity_threshold(left, right, left_size, right_size, shorter,
                                 threshold):
  alignment_banded(left, right, left_size, right_size, shorter, threshold)

law similarity_both:
  for left: P.Sequence
  for right: P.Sequence
  for +ln: U32
  for +rn: U32
  for +shorter: Bool
  U32

def similarity_both(left, right, ln, rn, shorter):
  apply(P.Sequence & P.Sequence, U32,
    \{Tuple: l1 => l2 => (
      apply(P.Sequence & P.Sequence, U32,
        \{Tuple: r1 => r2 => (
          forward = alignment_identity(l1, r1, ln, rn, shorter)
          backward = alignment_identity(l2, sequence_reverse(r2, rn),
            ln, rn, shorter)
          maximum(forward, backward)
        )},
        sequence_copy(right))
    )},
    sequence_copy(left))

law similarity:
  for left: Record
  for right: Record
  for reverse: Bool
  for shorter: Bool
  U32

def similarity(left, right, reverse, shorter):
  match left right:
    case Record{li, ll, ls, lw, lwords, lsketch} Record{ri, rl, rs, rw, rwords, rsketch}:
      branch(U32, reverse, \{
        True: (
          similarity_both(ls, rs, lw, rw, shorter)
        )
        False: (
          alignment_identity(ls, rs, lw, rw, shorter)
        )
      })

# Sparse candidate filtering
# ==========================

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
      apply(Array<U32> & U32, U32,
        \{Tuple: next_left => a => (
          apply(Array<U32> & U32, U32,
            \{Tuple: next_right => b => (
              words_common(rest, U32.add(index, 1), next_left, next_right,
                U32.add(total, minimum(a, b)))
            )},
            Array.get(U32, right, index))
        )},
        Array.get(U32, left, index))

law sketch_common:
  for fuel: Nat
  for +index: U32
  for left: Array<U32>
  for right: Array<U32>
  for +total: U32
  U32

def sketch_common(fuel, index, left, right, total):
  match fuel:
    case Zero{}:
      total
    case Succ{rest}:
      apply(Array<U32> & U32, U32,
        \{Tuple: next_left => +a => (
          apply(Array<U32> & U32, U32,
            \{Tuple: next_right => +b => (
              present = U32.is_ne(a, 4294967295) && U32.is_ne(b, 4294967295)
              same = present && U32.is_eq(a, b)
              sketch_common(rest, U32.add(index, 1), next_left, next_right,
                U32.add(total, select(same, 1, 0)))
            )},
            Array.get(U32, right, index))
        )},
        Array.get(U32, left, index))

law sketch_populated:
  for fuel: Nat
  for +index: U32
  for values: Array<U32>
  for +total: U32
  U32

def sketch_populated(fuel, index, values, total):
  match fuel:
    case Zero{}:
      total
    case Succ{rest}:
      apply(Array<U32> & U32, U32, \{Tuple: next => +value => (
        sketch_populated(rest, U32.add(index, 1), next,
          U32.add(total, select(U32.is_ne(value, 4294967295), 1, 0)))
      )}, Array.get(U32, values, index))

# Approximate VSEARCH/VClust-style gate. For low-complexity sequences fewer
# than eight bins may be populated, so all populated bins must agree instead
# of rejecting identical repeats. Sequences shorter than one 15-mer bypass it.
law fast_sketch_candidate:
  for left: Array<U32>
  for right: Array<U32>
  for +left_size: U32
  for +right_size: U32
  Bool

def fast_sketch_candidate(left, right, left_size, right_size):
  branch(Bool, U32.is_lt(minimum(left_size, right_size), 15), \{
    True: True{}
    False: (
      apply(Array<U32> & Array<U32>, Bool, \{Tuple: left_count => left_common => (
        apply(Array<U32> & Array<U32>, Bool,
          \{Tuple: right_count => right_common => (
            +populated = {minimum(
              sketch_populated(64n, 0, left_count, 0),
              sketch_populated(64n, 0, right_count, 0)) : U32}
            +required = {minimum(8, populated) : U32}
            U32.is_ge(sketch_common(64n, 0, left_common, right_common, 0),
              required)
          )},
          Array.clone(U32, right))
      )},
      Array.clone(U32, left))
    )
  })

law fast_score_counts:
  for +common: U32
  for +populated: U32
  for +threshold: U32
  U32

def fast_score_counts(common, populated, threshold):
  # Re-export the pure, independently kernel-checkable score through the
  # historical common-module API.
  F.score(common, populated, threshold)

law fast_sketch_score:
  for left: Array<U32>
  for right: Array<U32>
  for +threshold: U32
  U32

def fast_sketch_score(left, right, threshold):
  apply(Array<U32> & Array<U32>, U32, \{Tuple: left_count => left_common => (
    apply(Array<U32> & Array<U32>, U32,
      \{Tuple: right_count => right_common => (
        +populated = {minimum(
          sketch_populated(64n, 0, left_count, 0),
          sketch_populated(64n, 0, right_count, 0)) : U32}
        +common = {sketch_common(64n, 0, left_common, right_common, 0) : U32}
        fast_score_counts(common, populated, threshold)
      )},
      Array.clone(U32, right))
  )},
  Array.clone(U32, left))

# With m exact matches, the unmatched input symbols split those matches into
# at most len_a + len_b - 2*m + 1 runs. Every run loses at most two 3-mers.
# Hash collisions can only increase the intersection, so this filter has false
# positives but no false negatives for a qualifying alignment.
law words_candidate:
  for left: Array<U32>
  for right: Array<U32>
  for +left_size: U32
  for +right_size: U32
  for +required_matches: U32
  Bool

def words_candidate(left, right, left_size, right_size, required_matches):
  interruptions = subtract(U32.add(left_size, right_size),
    U32.mul(required_matches, 2))
  +required_words = {subtract(required_matches,
    U32.mul(2, U32.add(interruptions, 1))) : U32}
  branch(Bool, U32.is_eq(required_words, 0), \{
    True: (
      True{}
    )
    False: (
      U32.is_ge(words_common(256n, 0, left, right, 0), required_words)
    )
  })

law global_word_filter:
  for left: Array<U32>
  for right: Array<U32>
  for +left_size: U32
  for +right_size: U32
  for +threshold: U32
  Bool

def global_word_filter(left, right, left_size, right_size, threshold):
  +longer = {maximum(left_size, right_size) : U32}
  +shorter = {minimum(left_size, right_size) : U32}
  +required_matches = {U32.div(
    U32.add(U32.mul(threshold, longer), 9999), 10000) : U32}
  branch(Bool, U32.is_gt(required_matches, shorter), \{
    True: (
      False{}
    )
    False: (
      words_candidate(left, right, left_size, right_size, required_matches)
    )
  })

# If edit distance is d, at most 15*d q-grams from the shorter sequence can be
# disrupted. Global identity >= threshold implies
# d <= shorter * (1-threshold) / threshold. Hash collisions only increase the
# observed intersection, so this 15-mer filter remains conservative.
law q15_candidate:
  for left: P.Sequence
  for right: P.Sequence
  for +left_size: U32
  for +right_size: U32
  for +threshold: U32
  Bool

def q15_candidate(left, right, left_size, right_size, threshold):
  +shorter = {minimum(left_size, right_size) : U32}
  +max_edits = {U32.div(U32.mul(shorter, U32.sub(10000, threshold)), threshold)
    : U32}
  +required_words = {subtract(subtract(shorter, 14), U32.mul(15, max_edits))
    : U32}
  branch(Bool, U32.is_eq(required_words, 0), \{
    True: (
      True{}
    )
    False: (
      a = P.signature15(left, left_size)
      b = P.signature15(right, right_size)
      U32.is_ge(words_common(65536n, 0, a, b, 0), required_words)
    )
  })

law filtered_alignment:
  for left: P.Sequence
  for right: P.Sequence
  for left_words: Array<U32>
  for right_words: Array<U32>
  for +left_size: U32
  for +right_size: U32
  for +threshold: U32
  U32

def filtered_alignment(left, right, left_words, right_words,
                       left_size, right_size, threshold):
  branch(U32, global_word_filter(left_words, right_words,
    left_size, right_size, threshold), \{
    True: (
      alignment_identity_threshold(left, right, left_size, right_size, False{},
        threshold)
    )
    False: (
      0
    )
  })

law fast_alignment_after_sketch:
  for left: P.Sequence
  for right: P.Sequence
  for +left_size: U32
  for +right_size: U32
  for +threshold: U32
  U32

def fast_alignment_after_sketch(left, right, left_size, right_size, threshold):
  apply(P.Sequence & P.Sequence, U32, \{Tuple: left_q15 => left_alignment => (
    apply(P.Sequence & P.Sequence, U32,
      \{Tuple: right_q15 => right_alignment => (
        branch(U32,
          q15_candidate(left_q15, right_q15, left_size, right_size, threshold),
          \{
            True: alignment_identity_threshold(left_alignment, right_alignment,
              left_size, right_size, False{}, threshold)
            False: 0
          })
      )},
      P.copy(right))
  )}, P.copy(left))

law filtered_alignment_mode:
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

def filtered_alignment_mode(left, right, left_words, right_words,
                            left_sketch, right_sketch, left_size, right_size,
                            threshold, fast):
  branch(U32, global_word_filter(left_words, right_words,
    left_size, right_size, threshold), \{
    True: (
      branch(U32, fast, \{
        True: (
          branch(U32, U32.is_lt(minimum(left_size, right_size), 15), \{
            True: alignment_identity_threshold(left, right, left_size,
              right_size, False{}, threshold)
            False: fast_sketch_score(left_sketch, right_sketch, threshold)
          })
        )
        False: alignment_identity_threshold(left, right, left_size, right_size,
          False{}, threshold)
      })
    )
    False: 0
  })

law filtered_both:
  for left: P.Sequence
  for right: P.Sequence
  for left_words: Array<U32>
  for right_words: Array<U32>
  for +left_size: U32
  for +right_size: U32
  for +threshold: U32
  U32

def filtered_both(left, right, left_words, right_words,
                  left_size, right_size, threshold):
  apply(P.Sequence & P.Sequence, U32,
    \{Tuple: l1 => l2 => (
      apply(P.Sequence & P.Sequence, U32,
        \{Tuple: r1 => r2 => (
          apply(Array<U32> & Array<U32>, U32,
            \{Tuple: lw1 => lw2 => (
              reversed = sequence_reverse(r2, right_size)
              apply(P.Sequence & P.Sequence, U32,
                \{Tuple: reverse_for_words => reverse_for_alignment => (
                  reverse_words = P.signature(reverse_for_words, right_size)
                  forward = filtered_alignment(l1, r1, lw1, right_words,
                    left_size, right_size, threshold)
                  backward = filtered_alignment(l2, reverse_for_alignment,
                    lw2, reverse_words, left_size, right_size, threshold)
                  maximum(forward, backward)
                )},
                P.copy(reversed))
            )},
            Array.clone(U32, left_words))
        )},
        sequence_copy(right))
    )},
    sequence_copy(left))

law filtered_both_mode:
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

def filtered_both_mode(left, right, left_words, right_words,
                       left_sketch, right_sketch, left_size, right_size,
                       threshold, fast):
  apply(P.Sequence & P.Sequence, U32,
    \{Tuple: l1 => l2 => (
      apply(P.Sequence & P.Sequence, U32,
        \{Tuple: r1 => r2 => (
          apply(Array<U32> & Array<U32>, U32,
            \{Tuple: lw1 => lw2 => (
              apply(Array<U32> & Array<U32>, U32,
                \{Tuple: lk1 => lk2 => (
                  reversed = sequence_reverse(r2, right_size)
                  apply(P.Sequence & P.Sequence, U32,
                    \{Tuple: reverse_for_words => reverse_remaining => (
                      apply(P.Sequence & P.Sequence, U32,
                        \{Tuple: reverse_for_sketch => reverse_for_alignment => (
                          reverse_words = P.signature(reverse_for_words, right_size)
                          reverse_sketch = P.sketch(reverse_for_sketch, right_size)
                          forward = filtered_alignment_mode(l1, r1, lw1,
                            right_words, lk1, right_sketch, left_size,
                            right_size, threshold, fast)
                          backward = filtered_alignment_mode(l2,
                            reverse_for_alignment, lw2, reverse_words, lk2,
                            reverse_sketch, left_size, right_size, threshold,
                            fast)
                          maximum(forward, backward)
                        )},
                        P.copy(reverse_remaining))
                    )},
                    P.copy(reversed))
                )},
                Array.clone(U32, left_sketch))
            )},
            Array.clone(U32, left_words))
        )},
        sequence_copy(right))
    )},
    sequence_copy(left))

law filtered_similarity:
  for left: Record
  for right: Record
  for reverse: Bool
  for threshold: U32
  U32

def filtered_similarity(left, right, reverse, threshold):
  match left right:
    case Record{li, ll, ls, lw, lwords, lsketch} Record{ri, rl, rs, rw, rwords, rsketch}:
      branch(U32, reverse, \{
        True: (
          filtered_both(ls, rs, lwords, rwords, lw, rw, threshold)
        )
        False: (
          filtered_alignment(ls, rs, lwords, rwords, lw, rw, threshold)
        )
      })

law filtered_similarity_mode:
  for left: Record
  for right: Record
  for reverse: Bool
  for +threshold: U32
  for +fast: Bool
  U32

def filtered_similarity_mode(left, right, reverse, threshold, fast):
  match left right:
    case Record{li, ll, ls, lw, lwords, lsketch} Record{ri, rl, rs, rw, rwords, rsketch}:
      branch(U32, reverse, \{
        True: filtered_both_mode(ls, rs, lwords, rwords, lsketch, rsketch,
          lw, rw, threshold, fast)
        False: filtered_alignment_mode(ls, rs, lwords, rwords, lsketch,
          rsketch, lw, rw, threshold, fast)
      })
# Fasta
# =====

type Parser is Type:
  Parser{items: List<Record>, label: String, bases: String,
    width: U32, count: U32, active: Bool}

type Stream is Type:
  Stream{state: Parser, line: String, number: U32}

law lines_split:
  for text: String
  for line: String
  for lines: List<String>
  List<String>

def lines_split(text, line, lines):
  match text:
    case SNil{}:
      list_reverse(String, Con{string_reverse(line, ""), lines}, Nil{})
    case SCon{Chr{raw}, tail}:
      +code = {raw : U32}
      branch(List<String>, U32.is_eq(code, 10), \{
        True: (
          lines_split(tail, "", Con{string_reverse(line, ""), lines})
        )
        False: (
          branch(List<String>, U32.is_eq(code, 13), \{
            True: (
              lines_split(tail, line, lines)
            )
            False: (
              lines_split(tail, SCon{Chr{code}, line}, lines)
            )
          })
        )
      })

law trim_left:
  for text: String
  String

def trim_left(text):
  match text:
    case SNil{}:
      ""
    case SCon{Chr{raw}, tail}:
      +code = {raw : U32}
      branch(String, U32.is_eq(code, 32) || U32.is_eq(code, 9), \{
        True: (
          trim_left(tail)
        )
        False: (
          SCon{Chr{code}, tail}
        )
      })

law header_clean_loop:
  for text: String
  for result: String
  Result<String, String>

def header_clean_loop(text, result):
  match text:
    case SNil{}:
      Done{string_reverse(result, "")}
    case SCon{Chr{raw}, tail}:
      +code = {raw : U32}
      branch(Result<String, String>, U32.is_eq(code, 9), \{
        True: (
          header_clean_loop(tail, SCon{' ', result})
        )
        False: (
          branch(Result<String, String>, U32.is_lt(code, 32) || U32.is_eq(code, 127), \{
            True: (
              Fail{"control character in FASTA header"}
            )
            False: (
              header_clean_loop(tail, SCon{Chr{code}, result})
            )
          })
        )
      })

law header_clean:
  for text: String
  Result<String, String>

def header_clean(text):
  header_clean_loop(text, "")

law header_validate:
  for text: String
  Result<String, String>

def header_validate(text):
  match text:
    case SNil{}:
      Fail{"empty FASTA header"}
    case SCon{head, tail}:
      header_clean(SCon{head, tail})

law uppercase:
  for +code: U32
  U32

def uppercase(code):
  branch(U32, U32.is_ge(code, 97) && U32.is_le(code, 122), \{
    True: (
      U32.sub(code, 32)
    )
    False: (
      code
    )
  })

law dna_valid:
  for +code: U32
  Bool

def dna_valid(code):
  U32.is_eq(code, 65) || U32.is_eq(code, 67) ||
  U32.is_eq(code, 71) || U32.is_eq(code, 84) ||
  U32.is_eq(code, 85) || U32.is_eq(code, 82) ||
  U32.is_eq(code, 89) || U32.is_eq(code, 83) ||
  U32.is_eq(code, 87) || U32.is_eq(code, 75) ||
  U32.is_eq(code, 77) || U32.is_eq(code, 66) ||
  U32.is_eq(code, 68) || U32.is_eq(code, 72) ||
  U32.is_eq(code, 86) || U32.is_eq(code, 78)

law base_valid:
  for +code: U32
  for alphabet: U32
  Bool

def base_valid(code, alphabet):
  branch(Bool, U32.is_eq(alphabet, 1), \{
    True: (
      dna_valid(code)
    )
    False: (
      (U32.is_ge(code, 65) && U32.is_le(code, 90)) || U32.is_eq(code, 42)
    )
  })

law base_normalize:
  for +code: U32
  for alphabet: U32
  Char

def base_normalize(code, alphabet):
  branch(Char, U32.is_eq(alphabet, 1) && U32.is_eq(code, 85), \{
    True: (
      'T'
    )
    False: (
      Chr{code}
    )
  })

law sequence_line:
  for text: String
  for bases: String
  for +width: U32
  for +alphabet: U32
  Result<String, String & U32>

def sequence_line(text, bases, width, alphabet):
  match text:
    case SNil{}:
      Done{(bases, width)}
    case SCon{Chr{raw}, tail}:
      +code = {raw : U32}
      branch(Result<String, String & U32>, U32.is_eq(code, 32) || U32.is_eq(code, 9), \{
        True: (
          sequence_line(tail, bases, width, alphabet)
        )
        False: (
          branch(Result<String, String & U32>, U32.is_ge(width, 300000), \{
            True: (
              Fail{"sequence exceeds the 300000-residue limit"}
            )
            False: (
              +upper = {uppercase(code) : U32}
              branch(Result<String, String & U32>, base_valid(upper, alphabet), \{
                True: (
                  base = base_normalize(upper, alphabet)
                  sequence_line(tail, SCon{base, bases}, U32.add(width, 1), alphabet)
                )
                False: (
                  Fail{"invalid sequence symbol (expected ungapped IUPAC DNA/RNA)"}
                )
              })
            )
          })
        )
      })

law parser_flush:
  for state: Parser
  Result<String, Parser>

def parser_flush(state):
  match state:
    case Parser{items, label, bases, width, count, active}:
      +length = {width : U32}
      +size = {count : U32}
      branch(Result<String, Parser>, active, \{
        True: (
          branch(Result<String, Parser>, U32.is_eq(length, 0), \{
            True: (
              Fail{"FASTA record has no sequence"}
            )
            False: (
              branch(Result<String, Parser>, U32.is_ge(size, 16384), \{
                True: (
                  Fail{"input exceeds the 16384-record limit"}
                )
                False: (
                  packed = P.pack(string_reverse(bases, ""), length)
                  apply(P.Sequence & P.Sequence, Result<String, Parser>,
                    \{Tuple: for_words => remaining => (
                      apply(P.Sequence & P.Sequence, Result<String, Parser>,
                        \{Tuple: for_sketch => for_record => (
                          words = P.signature(for_words, length)
                          sketch = P.sketch(for_sketch, length)
                          item = {Record{size, label, for_record, length, words, sketch}
                            : Record}
                          Done{Parser{Con{item, items}, "", "", 0,
                            U32.add(size, 1), False{}}}
                        )},
                        P.copy(remaining))
                    )},
                    P.copy(packed))
                )
              })
            )
          })
        )
        False: (
          Done{Parser{items, label, bases, length, size, False{}}}
        )
      })

law parser_header:
  for state: Parser
  for label: String
  Parser

def parser_header(state, label):
  match state:
    case Parser{items, old_label, bases, width, count, active}:
      Parser{items, label, "", 0, count, True{}}

law parser_sequence_finish:
  for parsed: String & U32
  for items: List<Record>
  for label: String
  for count: U32
  Parser

def parser_sequence_finish(parsed, items, label, count):
  match parsed:
    case Tuple{next, length}:
      Parser{items, label, next, length, count, True{}}

law parser_sequence:
  for state: Parser
  for text: String
  for alphabet: U32
  Result<String, Parser>

def parser_sequence(state, text, alphabet):
  match state:
    case Parser{items, label, bases, width, count, active}:
      branch(Result<String, Parser>, active, \{
        True: (
          do Result<&1, &1, String, Parser>:
            parsed: String & U32 <- sequence_line(text, bases, width, alphabet)
            return parser_sequence_finish(parsed, items, label, count)
        )
        False: (
          Fail{"sequence encountered before a FASTA header"}
        )
      })

law parser_line:
  for line: String
  for state: Parser
  for alphabet: U32
  Result<String, Parser>

def parser_line(line, state, alphabet):
  match line:
    case SNil{}:
      Done{state}
    case SCon{Chr{raw}, tail}:
      +code = {raw : U32}
      branch(Result<String, Parser>, U32.is_eq(code, 62), \{
        True: (
          do Result<&1, &1, String, Parser>:
            label: String <- header_validate(trim_left(tail))
            flushed: Parser <- parser_flush(state)
            return parser_header(flushed, label)
        )
        False: (
          branch(Result<String, Parser>, U32.is_eq(code, 59), \{
            True: (
              Done{state}
            )
            False: (
              parser_sequence(state, SCon{Chr{code}, tail}, alphabet)
            )
          })
        )
      })

law parser_error:
  for value: Result<String, Parser>
  for line: U32
  Result<String, Parser>

def parser_error(value, line):
  match value:
    case Fail{error}:
      Fail{"FASTA line " ++ U32.show(line) ++ ": " ++ error}
    case Done{state}:
      Done{state}

law parser_lines:
  for lines: List<String>
  for state: Parser
  for +line: U32
  for +alphabet: U32
  Result<String, Parser>

def parser_lines(lines, state, line, alphabet):
  match lines:
    case Nil{}:
      parser_error(parser_flush(state), line)
    case Con{head, tail}:
      apply(Result<String, Parser>, Result<String, Parser>, \{
        Fail: message => Fail{message}
        Done: next => parser_lines(tail, next, U32.add(line, 1), alphabet)
      }, parser_error(parser_line(trim_left(head), state, alphabet), line))

law parser_dataset:
  for state: Parser
  Dataset

def parser_dataset(state):
  match state:
    case Parser{items, label, bases, width, count, active}:
      Dataset{list_reverse(Record, items, Nil{}), count}

law fasta_parse:
  for text: String
  for alphabet: U32
  Result<String, Dataset>

def fasta_parse(text, alphabet):
  do Result<&1, &1, String, Dataset>:
    state: Parser <- parser_lines(lines_split(text, "", Nil{}),
      Parser{Nil{}, "", "", 0, 0, False{}}, 1, alphabet)
    return parser_dataset(state)

# Incremental FASTA parsing keeps only one 64 KiB file chunk and the current
# record in linked Strings. Completed sequences are immediately packed.
law stream_chunk:
  for text: String
  for line: String
  for state: Parser
  for +number: U32
  for +alphabet: U32
  Result<String, Stream>

def stream_chunk(text, line, state, number, alphabet):
  match text:
    case SNil{}:
      Done{Stream{state, line, number}}
    case SCon{Chr{raw}, tail}:
      +code = {raw : U32}
      branch(Result<String, Stream>, U32.is_eq(code, 10), \{
        True: (
          apply(Result<String, Parser>, Result<String, Stream>, \{
            Fail: message => Fail{message}
            Done: next => stream_chunk(tail, "", next,
              U32.add(number, 1), alphabet)
          }, parser_error(parser_line(trim_left(string_reverse(line, "")),
               state, alphabet), number))
        )
        False: (
          branch(Result<String, Stream>, U32.is_eq(code, 13), \{
            True: (
              stream_chunk(tail, line, state, number, alphabet)
            )
            False: (
              stream_chunk(tail, SCon{Chr{code}, line}, state, number, alphabet)
            )
          })
        )
      })

law stream_finish:
  for stream: Stream
  for alphabet: U32
  Result<String, Dataset>

def stream_finish(stream, alphabet):
  match stream:
    case Stream{state, line, +number}:
      do Result<&1, &1, String, Dataset>:
        parsed: Parser <- parser_error(
          parser_line(trim_left(string_reverse(line, "")), state, alphabet), number)
        flushed: Parser <- parser_error(parser_flush(parsed), number)
        return parser_dataset(flushed)

law stream_close_error:
  for file: File
  for message: String
  IO(Result<String, Dataset>)

def stream_close_error(file, message):
  do IO<Result<String, Dataset>>:
    closed: Unit <- File.close(file)
    return Fail{message}

law stream_continue:
  for result: Result<String, Stream>
  for file: File
  for continue: File -> Stream -> IO(Result<String, Dataset>)
  IO(Result<String, Dataset>)

def stream_continue(result, file, continue):
  match result:
    case Fail{message}:
      stream_close_error(file, message)
    case Done{next}:
      continue(file, next)

law file_parse_read:
  for read: File & Result<(U32 & String), String>
  for stream: Stream
  for +alphabet: U32
  for continue: File -> Stream -> IO(Result<String, Dataset>)
  IO(Result<String, Dataset>)

def file_parse_read(read, stream, alphabet, continue):
  match read:
    case Tuple{handle, result}:
      match result:
        case Fail{error}:
          apply(U32 & String, IO(Result<String, Dataset>),
            \{Tuple: code => message => stream_close_error(handle, message)}, error)
        case Done{text}:
          match text:
            case SNil{}:
              do IO<Result<String, Dataset>>:
                closed: Unit <- File.close(handle)
                return stream_finish(stream, alphabet)
            case SCon{head, tail}:
              match stream:
                case Stream{state, line, number}:
                  stream_continue(
                    stream_chunk(SCon{head, tail}, line, state, number, alphabet),
                    handle, continue)

law file_parse:
  for fuel: Nat
  for file: File
  for stream: Stream
  for +alphabet: U32
  IO(Result<String, Dataset>)

def file_parse(fuel, file, stream, alphabet):
  match fuel:
    case Zero{}:
      stream_close_error(file, "input exceeds 256 MiB")
    case Succ{rest}:
      do IO<Result<String, Dataset>>:
        read: File & Result<(U32 & String), String> <- File.read(file, 65536)
        file_parse_read(read, stream, alphabet,
          handle => next => file_parse(rest, handle, next, alphabet))

law result_unwrap:
  for -A: Type
  for value: Result<String, A>
  IO(A)

def result_unwrap(A, value):
  match value:
    case Fail{message}:
      IO.die(A, 2, message)
    case Done{value}:
      IO.pure(A, value)

law fasta_read:
  for alphabet: U32
  IO(Dataset)

def fasta_read(alphabet):
  do IO<Dataset>:
    path: String <- IO.try(String, IO.get_env("CLUSTER_INPUT"))
    handle: File <- IO.try(File, File.open(path, "r"))
    result: Result<String, Dataset> <- file_parse(4097n, handle,
      Stream{Parser{Nil{}, "", "", 0, 0, False{}}, "", 1}, alphabet)
    result_unwrap(Dataset, result)

law env_default:
  for value: Result<(U32 & String), String>
  for fallback: String
  IO(String)

def env_default(value, fallback):
  match value:
    case Fail{error}:
      apply(U32 & String, IO(String),
        \{Tuple: code => message => (
          branch(IO(String), U32.is_eq(code, 2), \{
            True: (
              IO.pure(String, fallback)
            )
            False: (
              IO.die(String, 2, message)
            )
          })
        )},
        error)
    case Done{text}:
      IO.pure(String, text)

law env:
  for name: String
  for fallback: String
  IO(String)

def env(name, fallback):
  do IO<String>:
    value: Result<(U32 & String), String> <- IO.get_env(name)
    env_default(value, fallback)

law decimal_parse:
  for text: String
  for +value: U32
  for +limit: U32
  for seen: Bool
  Result<String, U32>

def decimal_parse(text, value, limit, seen):
  match text:
    case SNil{}:
      branch(Result<String, U32>, seen, \{
        True: (
          Done{value}
        )
        False: (
          Fail{"empty integer setting"}
        )
      })
    case SCon{Chr{raw}, tail}:
      +code = {raw : U32}
      branch(Result<String, U32>, U32.is_lt(code, 48) || U32.is_gt(code, 57), \{
        True: (
          Fail{"settings must contain decimal digits only"}
        )
        False: (
          +digit = {U32.sub(code, 48) : U32}
          branch(Result<String, U32>, U32.is_gt(value, U32.div(limit, 10)) || (U32.is_eq(value, U32.div(limit, 10)) && U32.is_gt(digit, U32.mod(limit, 10))), \{
            True: (
              Fail{"integer setting out of range"}
            )
            False: (
              decimal_parse(tail, U32.add(U32.mul(value, 10), digit), limit, True{})
            )
          })
        )
      })

law env_number:
  for name: String
  for fallback: String
  for limit: U32
  IO(U32)

def env_number(name, fallback, limit):
  do IO<U32>:
    text: String <- env(name, fallback)
    result_unwrap(U32, decimal_parse(text, 0, limit, False{}))

law config_validate:
  for +identity: U32
  for +alphabet: U32
  for +reverse: U32
  for +fast: U32
  for +lz: U32
  for +kmer_minimum: U32
  for +kmer_identity: U32
  for +resolution: U32
  for seed: U32
  for +passes: U32
  IO(Config)

def config_validate(identity, alphabet, reverse, fast, lz, kmer_minimum,
                    kmer_identity, resolution, seed, passes):
  branch(IO(Config), U32.is_eq(identity, 0), \{
    True: (
      IO.die(Config, 2, "identity must be in 1..10000 basis points")
    )
    False: (
      branch(IO(Config), U32.is_eq(resolution, 0), \{
        True: (
          IO.die(Config, 2, "Leiden resolution must be positive")
        )
        False: (
          branch(IO(Config), U32.is_eq(passes, 0), \{
            True: (
              IO.die(Config, 2, "iteration limit must be positive")
            )
            False: (
              branch(IO(Config), U32.is_eq(fast, 1) && U32.is_eq(lz, 1), \{
                True: (
                  IO.die(Config, 2,
                    "CLUSTER_FAST and CLUSTER_LZ_ANI are mutually exclusive")
                )
                False: (
                  branch(IO(Config), U32.is_eq(reverse, 1) && U32.is_eq(alphabet, 0), \{
                    True: (
                      IO.die(Config, 2,
                        "reverse complements require the DNA/RNA alphabet")
                    )
                    False: (
                      IO.pure(Config, Config{identity, alphabet,
                        U32.is_eq(reverse, 1), U32.is_eq(fast, 1),
                        U32.is_eq(lz, 1), kmer_minimum, kmer_identity,
                        resolution, seed, to_nat(passes)})
                    )
                  })
                )
              })
            )
          })
        )
      })
    )
  })

law config_read:
  IO(Config)

def config_read():
  do IO<Config>:
    identity: U32 <- env_number("CLUSTER_IDENTITY", "9000", 10000)
    alphabet: U32 <- env_number("CLUSTER_DNA", "1", 1)
    reverse: U32 <- env_number("CLUSTER_REVERSE", "0", 1)
    fast: U32 <- env_number("CLUSTER_FAST", "0", 1)
    lz: U32 <- env_number("CLUSTER_LZ_ANI", "0", 1)
    kmer_minimum: U32 <- env_number("CLUSTER_KMER_MINIMUM", "20", 4294967295)
    kmer_identity: U32 <- env_number("CLUSTER_KMER_IDENTITY", "7000", 10000)
    resolution: U32 <- env_number("CLUSTER_RESOLUTION", "5000", 10000)
    seed: U32 <- env_number("CLUSTER_SEED", "1", 4294967295)
    passes: U32 <- env_number("CLUSTER_PASSES", "100", 100000)
    config_validate(identity, alphabet, reverse, fast, lz, kmer_minimum,
      kmer_identity, resolution, seed, passes)

law record_index:
  for item: Record
  U32

def record_index(item):
  match item:
    case Record{index, label, bases, width, words, sketch}:
      index

law sparse_add:
  for rows: Array<Neighbors>
  for +left: U32
  for +right: U32
  for +score: U32
  Array<Neighbors>

def sparse_add(rows, left, right, score):
  apply(Array<Neighbors> & Neighbors, Array<Neighbors>,
    \{Tuple: next => left_row => (
      first = Array.set(Neighbors, next, left,
        NeighborsCon{right, score, left_row})
      apply(Array<Neighbors> & Neighbors, Array<Neighbors>,
        \{Tuple: updated => right_row => (
          Array.set(Neighbors, updated, right,
            NeighborsCon{left, score, right_row})
        )},
        Array.get(Neighbors, first, right))
    )},
    Array.get(Neighbors, rows, left))

law sparse_row:
  for fuel: Nat
  for items: List<Record>
  for query: Record
  for rows: Array<Neighbors>
  for +index: U32
  for +threshold: U32
  for +reverse: Bool
  for +fast: Bool
  Array<Neighbors>

law sparse_pair:
  for head_meta: Record
  for head_score: Record
  for tail: List<Record>
  for query_score: Record
  for query_next: Record
  for rows: Array<Neighbors>
  for +index: U32
  for +threshold: U32
  for +reverse: Bool
  for +fast: Bool
  for continue: List<Record> -> Record -> Array<Neighbors> -> Array<Neighbors>
  Array<Neighbors>

def sparse_pair(head_meta, head_score, tail, query_score, query_next,
                rows, index, threshold, reverse, fast, continue):
  match head_meta query_score:
    case Record{+target, head_label, head_bases, +head_size, head_words, head_sketch} Record{query_index, query_label, query_bases, +query_size, query_words, query_sketch}:
      +required_matches = {U32.div(
        U32.add(U32.mul(threshold, query_size), 9999), 10000) : U32}
      branch(Array<Neighbors>, U32.is_gt(required_matches, head_size), \{
        True: (
          rows
        )
        False: (
          +score = {filtered_similarity_mode(
            Record{query_index, query_label, query_bases, query_size,
              query_words, query_sketch},
            head_score, reverse, threshold, fast) : U32}
          updated = branch(Array<Neighbors>, U32.is_ge(score, threshold), \{
            True: (
              sparse_add(rows, index, target, score)
            )
            False: (
              rows
            )
          })
          continue(tail, query_next, updated)
        )
      })

def sparse_row(fuel, items, query, rows, index, threshold, reverse, fast):
  match fuel items:
    case Zero{} remaining:
      rows
    case Succ{row_rest} Nil{}:
      rows
    case Succ{row_rest} Con{head, tail}:
      apply(Record & Record, Array<Neighbors>,
        \{Tuple: h1 => h2 => (
          apply(Record & Record, Array<Neighbors>,
            \{Tuple: q1 => q2 => (
              sparse_pair(h1, h2, tail, q1, q2,
                rows, index, threshold, reverse, fast,
                remaining => next_query => next_rows =>
                  sparse_row(row_rest, remaining, next_query, next_rows,
                    index, threshold, reverse, fast))
            )},
            record_copy(query))
        )},
        record_copy(head))

law sparse_rows:
  for fuel: Nat
  for items: List<Record>
  for rows: Array<Neighbors>
  for +threshold: U32
  for +reverse: Bool
  for +fast: Bool
  Array<Neighbors>

def sparse_rows(fuel, items, rows, threshold, reverse, fast):
  match fuel items:
    case Zero{} remaining:
      rows
    case Succ{+rest} Nil{}:
      rows
    case Succ{+rest} Con{head, tail}:
      apply(Record & Record, Array<Neighbors>,
        \{Tuple: h1 => h2 => (
          apply(List<Record> & List<Record>, Array<Neighbors>,
            \{Tuple: t1 => t2 => (
              +index = {record_index(h1) : U32}
              next = sparse_row(rest, t1, h2, rows, index, threshold, reverse,
                fast)
              sparse_rows(rest, t2, next, threshold, reverse, fast)
            )},
            records_copy(tail))
        )},
        record_copy(head))

law sparse_build:
  for items: List<Record>
  for +size: U32
  for +threshold: U32
  for +reverse: Bool
  for +fast: Bool
  SparseGraph

def sparse_build(items, size, threshold, reverse, fast):
  rows = Array.new(Neighbors, array_depth(31n, size, 1, 0n), NeighborsNil{})
  SparseGraph{size,
    sparse_rows(to_nat(size), records_sort(items), rows, threshold, reverse,
      fast)}

law labels_replace:
  for fuel: Nat
  for +index: U32
  for labels: Array<U32>
  for +old: U32
  for +new: U32
  Array<U32>

def labels_replace(fuel, index, labels, old, new):
  match fuel:
    case Zero{}:
      labels
    case Succ{rest}:
      apply(Array<U32> & U32, Array<U32>,
        \{Tuple: next => raw => (
          +value = {raw : U32}
          updated = Array.set(U32, next, index, select(U32.is_eq(value, old), new, value))
          labels_replace(rest, U32.add(index, 1), updated, old, new)
        )},
        Array.get(U32, labels, index))

law labels_lookup:
  for labels: Array<U32>
  for index: U32
  U32

def labels_lookup(labels, index):
  apply(Array<U32> & U32, U32,
    \{Tuple: unused => value => (
      value
    )},
    Array.get(U32, labels, index))

law labels_compose:
  for fuel: Nat
  for +index: U32
  for labels: Array<U32>
  for mapping: Array<U32>
  Array<U32>

def labels_compose(fuel, index, labels, mapping):
  match fuel:
    case Zero{}:
      labels
    case Succ{rest}:
      apply(Array<U32> & U32, Array<U32>,
        \{Tuple: next => old => (
          apply(Array<U32> & U32, Array<U32>,
            \{Tuple: map => value => (
              updated = Array.set(U32, next, index, value)
              labels_compose(rest, U32.add(index, 1), updated, map)
            )},
            Array.get(U32, mapping, old))
        )},
        Array.get(U32, labels, index))

law output_rows:
  for items: List<Record>
  for labels: Array<U32>
  IO(Unit)

def output_rows(items, labels):
  match items:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{Record{index, label, bases, width, words, sketch}, tail}:
      +number = {index : U32}
      apply(Array<U32> & U32, IO(Unit),
        \{Tuple: next => representative => (
          row = U32.show(number) ++ "\t" ++ U32.show(representative) ++ "\t"
            ++ U32.show(width) ++ "\t" ++ label
          do IO<Unit>:
            printed: Unit <- IO.print(row)
            output_rows(tail, next)
        )},
        Array.get(U32, labels, number))

law fasta_wrap:
  for bases: String
  for +column: U32
  for result: String
  String

def fasta_wrap(bases, column, result):
  match bases:
    case SNil{}:
      string_reverse(result, "")
    case SCon{head, tail}:
      branch(String, U32.is_eq(column, 80), \{
        True: (
          fasta_wrap(tail, 1, SCon{head, SCon{'\n', result}})
        )
        False: (
          fasta_wrap(tail, U32.add(column, 1), SCon{head, result})
        )
      })

law file_write_checked:
  for result: File & Result<(U32 & String), Unit>
  IO(File)

def file_write_checked(result):
  match result:
    case Tuple{file, status}:
      match status:
        case Done{unit}:
          IO.pure(File, file)
        case Fail{error}:
          apply(U32 & String, IO(File),
            \{Tuple: code => message => (
              do IO<File>:
                closed: Unit <- File.close(file)
                IO.die(File, 2, message)
            )},
            error)

law representatives_write:
  for items: List<Record>
  for labels: Array<U32>
  for file: File
  IO(Unit)

def representatives_write(items, labels, file):
  match items:
    case Nil{}:
      File.close(file)
    case Con{Record{raw_index, label, bases, width, words, sketch}, tail}:
      +index = {raw_index : U32}
      apply(Array<U32> & U32, IO(Unit),
        \{Tuple: next_labels => center => (
          branch(IO(Unit), U32.is_eq(index, center), \{
            True: (
              do IO<Unit>:
                result: File & Result<(U32 & String), Unit> <- File.write(file,
                  ">" ++ label ++ "\n" ++ fasta_wrap(P.unpack(bases), 0, "") ++ "\n")
                next_file: File <- file_write_checked(result)
                representatives_write(tail, next_labels, next_file)
            )
            False: (
              representatives_write(tail, next_labels, file)
            )
          })
        )},
        Array.get(U32, labels, index))

law output_table:
  for items: List<Record>
  for labels: Array<U32>
  IO(Unit)

def output_table(items, labels):
  do IO<Unit>:
    header: Unit <- IO.print("record_index\tcluster_representative\tlength\theader")
    output_rows(items, labels)

law output_files:
  for path: String
  for items: List<Record>
  for labels: Array<U32>
  IO(Unit)

def output_files(path, items, labels):
  match path:
    case SNil{}:
      output_table(items, labels)
    case SCon{head, tail}:
      apply(List<Record> & List<Record>, IO(Unit),
        \{Tuple: i1 => i2 => (
          apply(Array<U32> & Array<U32>, IO(Unit),
            \{Tuple: l1 => l2 => (
              do IO<Unit>:
                file: File <- IO.try(File, File.open(SCon{head, tail}, "w"))
                written: Unit <- representatives_write(i1, l1, file)
                output_table(i2, l2)
            )},
            Array.clone(U32, labels))
        )},
        records_copy(items))

law output:
  for items: List<Record>
  for labels: Array<U32>
  IO(Unit)

def output(items, labels):
  do IO<Unit>:
    path: String <- env("CLUSTER_REPRESENTATIVES", "")
    output_files(path, items, labels)
