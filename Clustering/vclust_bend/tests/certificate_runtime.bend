# Negative integration probes: actual production guard, deliberately bad data.
import Base
import ../cluster.bend as C
import ../cl_graph.bend as G

def refused(r: Result<&1, &1, String, List<&2, U32>>) -> Bool:
  match r:
    case Fail{error}: True{}
    case Done{bytes}: False{}

def invalid_labels() -> Bool:
  refused(C.cluster_checked(False{}, G.u32_array(2, 99), 1, 2, G.u32_array(2, 0),
    Array.new(List<&2, U32>, 1n, [65]), 2, False{}, Array.new(List<&2, G.Nb>, 1n, Nil{}), 0))

def invalid_clique() -> Bool:
  refused(C.cluster_checked(False{}, G.u32_array(2, 0), 1, 2, G.u32_array(2, 0),
    Array.new(List<&2, U32>, 1n, [65]), 2, False{}, Array.new(List<&2, G.Nb>, 1n, Nil{}), 1))

def main() -> Bool:
  Bool.and(invalid_labels(), invalid_clique())
