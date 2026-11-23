import Base
import ../lib/packing.bend as P
import ../lib/lz_ani_indexed.bend as LZ

law string_length:
  for text: String
  for +total: U32
  U32

def string_length(text, total):
  match text:
    case SNil{}:
      total
    case SCon{head, tail}:
      string_length(tail, U32.add(total, 1))

law print_result:
  for result: LZ.ScoreResult
  IO(Unit)

def print_result(result):
  match result:
    case LZ.ScoreResult{index,
      LZ.Metrics{matches, mismatches, components, ani, gani, coverage}}:
      IO.print(U32.show(matches) ++ "\t" ++ U32.show(mismatches) ++ "\t"
        ++ U32.show(components) ++ "\t" ++ U32.show(ani) ++ "\t"
        ++ U32.show(gani) ++ "\t" ++ U32.show(coverage))

law run:
  for +reference: String
  for +query: String
  IO(Unit)

def run(reference, query):
  +reference_length = {string_length(reference, 0) : U32}
  +query_length = {string_length(query, 0) : U32}
  print_result(LZ.score(LZ.build_index(P.pack(reference, reference_length),
    reference_length), P.pack(query, query_length), query_length))

law main:
  IO(Unit)

def main():
  do IO<Unit>:
    reference: String <- IO.try(String, IO.get_env("LZ_REFERENCE"))
    query: String <- IO.try(String, IO.get_env("LZ_QUERY"))
    run(reference, query)
