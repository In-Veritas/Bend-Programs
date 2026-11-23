# Shared FASTA IO, DNA/RNA normalization, exact alignment, and output.
import Base
import ./packing.bend as P
import ./alignment.bend as A

def apply(-A: Type, -B: Type, body: A -> B, value: A) -> B:
  body(value)

def branch(-A: Type, condition: Bool, body: Bool -> A) -> A:
  body(condition)

# Types
# =====

type Record is Type:
  Record{index: U32, label: String, bases: P.Sequence, width: U32}

type Dataset is Type:
  Dataset{items: List<Record>, count: U32}

type Config is Type:
  Config{identity: U32, alphabet: U32, reverse: Bool,
    resolution: U32, seed: U32, passes: Nat}

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
    case Record{+index, +label, bases, +width}:
      apply(P.Sequence & P.Sequence, Record & Record,
        \{Tuple: a => b => (Record{index, label, a, width}, Record{index, label, b, width})},
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
    case Record{li, ll, lb, lw} Record{ri, rl, rb, rw}:
      +a = {lw : U32}
      +b = {rw : U32}
      U32.is_gt(a, b) || (U32.is_eq(a, b) && U32.is_lt(li, ri))

law record_insert:
  for items: List<Record>
  for item: Record
  for prefix: List<Record>
  List<Record>

def record_insert(items, item, prefix):
  match items:
    case Nil{}:
      list_reverse(Record, prefix, Con{item, Nil{}})
    case Con{head, tail}:
      apply(Record & Record, List<Record>,
        \{Tuple: h1 => h2 => (
          apply(Record & Record, List<Record>,
            \{Tuple: i1 => i2 => (
              branch(List<Record>, record_precedes(i1, h1), \{
                True: (
                  list_reverse(Record, prefix, Con{i2, Con{h2, tail}})
                )
                False: (
                  record_insert(tail, i2, Con{h2, prefix})
                )
              })
            )},
            record_copy(item))
        )},
        record_copy(head))

law records_sort_loop:
  for items: List<Record>
  for sorted: List<Record>
  List<Record>

def records_sort_loop(items, sorted):
  match items:
    case Nil{}:
      sorted
    case Con{head, tail}:
      next = record_insert(sorted, head, Nil{})
      records_sort_loop(tail, next)

law records_sort:
  for items: List<Record>
  List<Record>

def records_sort(items):
  records_sort_loop(items, Nil{})

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

# A DP cell packs edit cost in the high 16 bits and 65535 - exact matches
# in the low 16 bits. Unsigned minimum therefore resolves both criteria.
# The 30000-residue limit keeps additions within the packed representation.
def sequence_copy(sequence: P.Sequence) -> P.Sequence & P.Sequence:
  P.copy(sequence)

def sequence_reverse(sequence: P.Sequence, +length: U32) -> P.Sequence:
  P.pack(reverse_complement(P.unpack(sequence), ""), length)

def sequence_text(sequence: P.Sequence) -> String:
  P.unpack(sequence)

def alignment_identity(left: P.Sequence, right: P.Sequence, left_size: U32,
                       right_size: U32, shorter: Bool) -> U32:
  A.identity(left, right, left_size, right_size, shorter)

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
    case Record{li, ll, ls, lw} Record{ri, rl, rs, rw}:
      branch(U32, reverse, \{
        True: (
          similarity_both(ls, rs, lw, rw, shorter)
        )
        False: (
          alignment_identity(ls, rs, lw, rw, shorter)
        )
      })
# Fasta
# =====

type Parser is Type:
  Parser{items: List<Record>, label: String, bases: String,
    width: U32, count: U32, active: Bool}

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
          branch(Result<String, String & U32>, U32.is_ge(width, 30000), \{
            True: (
              Fail{"sequence exceeds the 30000-residue limit"}
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
              branch(Result<String, Parser>, U32.is_ge(size, 2048), \{
                True: (
                  Fail{"input exceeds the 2048-record limit"}
                )
                False: (
                  item = {Record{size, label, P.pack(string_reverse(bases, ""), length), length}
                    : Record}
                  Done{Parser{Con{item, items}, "", "", 0, U32.add(size, 1), False{}}}
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

law file_read_step:
  for read: File & Result<(U32 & String), String>
  for continue: File -> IO(Result<String, String>)
  IO(Result<String, String>)

def file_read_step(read, continue):
  match read:
    case Tuple{handle, result}:
      match result:
        case Fail{error}:
          apply(U32 & String, IO(Result<String, String>),
            \{Tuple: code => message => (
              do IO<Result<String, String>>:
                closed: Unit <- File.close(handle)
                return Fail{message}
            )},
            error)
        case Done{text}:
          match text:
            case SNil{}:
              do IO<Result<String, String>>:
                closed: Unit <- File.close(handle)
                return Done{""}
            case SCon{head, tail}:
              do IO<Result<String, String>>:
                remaining: Result<String, String> <- continue(handle)
                return Result.bind(&1, &1, String, String, String, remaining,
                  suffix => Done{SCon{head, tail} ++ suffix})

law file_read_all:
  for fuel: Nat
  for file: File
  IO(Result<String, String>)

def file_read_all(fuel, file):
  match fuel:
    case Zero{}:
      do IO<Result<String, String>>:
        closed: Unit <- File.close(file)
        return Fail{"input exceeds 64 MiB"}
    case Succ{rest}:
      do IO<Result<String, String>>:
        read: File & Result<(U32 & String), String> <- File.read(file, 65536)
        file_read_step(read, handle => file_read_all(rest, handle))

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
  for +alphabet: U32
  IO(Dataset)

def fasta_read(alphabet):
  do IO<Dataset>:
    path: String <- IO.try(String, IO.get_env("CLUSTER_INPUT"))
    handle: File <- IO.try(File, File.open(path, "r"))
    result: Result<String, String> <- file_read_all(1025n, handle)
    text: String <- result_unwrap(String, result)
    branch(IO(Dataset), U32.is_eq(alphabet, 1), \{
      True: result_unwrap(Dataset, fasta_parse(text, alphabet))
      False: IO.die(Dataset, 2, "packed experiment supports DNA/RNA only")
    })

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
  for +resolution: U32
  for seed: U32
  for +passes: U32
  IO(Config)

def config_validate(identity, alphabet, reverse, resolution, seed, passes):
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
              branch(IO(Config), U32.is_eq(reverse, 1) && U32.is_eq(alphabet, 0), \{
                True: (
                  IO.die(Config, 2, "reverse complements require the DNA/RNA alphabet")
                )
                False: (
                  IO.pure(Config, Config{identity, alphabet, U32.is_eq(reverse, 1),
                    resolution, seed, to_nat(passes)})
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
    resolution: U32 <- env_number("CLUSTER_RESOLUTION", "5000", 10000)
    seed: U32 <- env_number("CLUSTER_SEED", "1", 4294967295)
    passes: U32 <- env_number("CLUSTER_PASSES", "100", 100000)
    config_validate(identity, alphabet, reverse, resolution, seed, passes)

law record_index:
  for item: Record
  U32

def record_index(item):
  match item:
    case Record{index, label, bases, width}:
      index

law matrix_row:
  for items: List<Record>
  for query: Record
  for matrix: Array<U32>
  for +size: U32
  for +index: U32
  for +reverse: Bool
  Array<U32>

def matrix_row(items, query, matrix, size, index, reverse):
  match items:
    case Nil{}:
      matrix
    case Con{head, tail}:
      apply(Record & Record, Array<U32>,
        \{Tuple: h1 => h2 => (
          apply(Record & Record, Array<U32>,
            \{Tuple: q1 => q2 => (
              +target = {record_index(h1) : U32}
              +score = {similarity(q1, h2, reverse, False{}) : U32}
              next = Array.set(U32, matrix, U32.add(U32.mul(index, size), target), score)
              updated = Array.set(U32, next, U32.add(U32.mul(target, size), index), score)
              matrix_row(tail, q2, updated, size, index, reverse)
            )},
            record_copy(query))
        )},
        record_copy(head))

law matrix_rows:
  for fuel: Nat
  for items: List<Record>
  for matrix: Array<U32>
  for +size: U32
  for +reverse: Bool
  Array<U32>

def matrix_rows(fuel, items, matrix, size, reverse):
  match fuel items:
    case Zero{} remaining:
      matrix
    case Succ{rest} Nil{}:
      matrix
    case Succ{rest} Con{head, tail}:
      apply(Record & Record, Array<U32>,
        \{Tuple: h1 => h2 => (
          apply(List<Record> & List<Record>, Array<U32>,
            \{Tuple: t1 => t2 => (
              +index = {record_index(h1) : U32}
              diagonal = Array.set(U32, matrix, U32.add(U32.mul(index, size), index), 10000)
              next = matrix_row(t1, h2, diagonal, size, index, reverse)
              matrix_rows(rest, t2, next, size, reverse)
            )},
            records_copy(tail))
        )},
        record_copy(head))

law matrix_build:
  for items: List<Record>
  for +size: U32
  for reverse: Bool
  Array<U32>

def matrix_build(items, size, reverse):
  matrix_rows(to_nat(size), items, array_new(U32.mul(size, size), 0), size, reverse)

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
    case Con{Record{index, label, bases, width}, tail}:
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
    case Con{Record{raw_index, label, bases, width}, tail}:
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
