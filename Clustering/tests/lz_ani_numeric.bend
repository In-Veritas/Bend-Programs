import Base
import ../lib/lz_ani_numeric.bend as LZ

law main:
  IO(Unit)

law print_metrics:
  for metrics: LZ.Metrics
  IO(Unit)

def print_metrics(metrics):
  match metrics:
    case LZ.Metrics{matches, mismatches, components, ani, gani, coverage}:
      IO.print(U32.show(matches) ++ "\t" ++ U32.show(mismatches) ++ "\t"
        ++ U32.show(components) ++ "\t" ++ U32.show(ani) ++ "\t"
        ++ U32.show(gani) ++ "\t" ++ U32.show(coverage))

def main():
  do IO<Unit>:
    reference: String <- IO.try(String, IO.get_env("LZ_REFERENCE"))
    query: String <- IO.try(String, IO.get_env("LZ_QUERY"))
    print_metrics(LZ.score(LZ.from_string(reference), LZ.from_string(query)))
