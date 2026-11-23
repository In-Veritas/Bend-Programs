# Bend common-graph benchmark executable. Algorithms: 0 single, 1 complete,
# 2 UCLUST, 3 CD-HIT, 4 set-cover.
import Base
import ../../lib/common.bend as C
import ./graph_io.bend as G
import ./algorithms.bend as A

law main:
  IO(Unit)

law run:
  for +size: U32
  for +algorithm: U32
  for +threshold: U32
  IO(Unit)

def run(size, algorithm, threshold):
  do IO<Unit>:
    graph: C.SparseGraph <- G.read_graph(size)
    labels: Array<U32> <- C.result_unwrap(Array<U32>,
      A.cluster(algorithm, graph, size, threshold))
    G.output(size, labels)

def main():
  do IO<Unit>:
    size: U32 <- C.env_number("CLUSTER_GRAPH_SIZE", "0", 1000000)
    algorithm: U32 <- C.env_number("CLUSTER_GRAPH_ALGORITHM", "0", 4)
    threshold: U32 <- C.env_number("CLUSTER_GRAPH_THRESHOLD", "950000", 1000000)
    run(size, algorithm, threshold)
