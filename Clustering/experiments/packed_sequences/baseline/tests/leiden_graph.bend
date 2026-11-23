import Base
import ../lib/common.bend as C
import ../leiden.bend as L

law read_cells:
  for text: String
  for +index: U32
  for array: Array<U32>
  for +scale: U32
  Array<U32>

def read_cells(text, index, array, scale):
  match text:
    case SNil{}:
      array
    case SCon{Chr{code}, tail}:
      next = Array.set(U32, array, index, U32.mul((U32.sub(code, 48)), scale))
      read_cells(tail, U32.add(index, 1), next, scale)


law print_cells:
  for fuel: Nat
  for +index: U32
  for array: Array<U32>
  IO(Unit)

def print_cells(fuel, index, array):
  match fuel:
    case Zero{}:
      IO.pure(Unit, Unit{})
    case Succ{rest}:
      C.apply(Array<U32> & U32, IO(Unit),
        \{Tuple: next => value => (
          do IO<Unit>:
            printed: Unit <- IO.print(U32.show(value))
            print_cells(rest, U32.add(index, 1), next)
        )},
        Array.get(U32, array, index))

law print_aggregate:
  for result: L.Graph & Array<U32>
  IO(Unit)

def print_aggregate(result):
  match result:
    case Tuple{L.Graph{raw_size, edges, mass}, parents}:
      +size = {raw_size : U32}
      do IO<Unit>:
        edge_output: Unit <- print_cells(C.to_nat(U32.mul(size, size)), 0, edges)
        mass_output: Unit <- print_cells(C.to_nat(size), 0, mass)
        print_cells(C.to_nat(size), 0, parents)


law run_aggregate:
  for +size: U32
  for graph_text: String
  IO(Unit)

def run_aggregate(size, graph_text):
  do IO<Unit>:
    new_size: U32 <- C.env_number("GRAPH_NEW_SIZE", "1", 64)
    labels_text: String <- C.env("GRAPH_LABELS", "")
    parents_text: String <- C.env("GRAPH_PARENTS", "")
    print_aggregate(L.aggregate(
      L.Graph{size,
        read_cells(graph_text, 0, C.array_new(U32.mul(size, size), 0), 1),
        C.array_new(size, 1)},
      read_cells(labels_text, 0, C.array_new(size, 0), 1),
      read_cells(parents_text, 0, C.array_new(size, 0), 1), new_size))


law run_cluster:
  for +size: U32
  for graph_text: String
  IO(Unit)

def run_cluster(size, graph_text):
  matrix = read_cells(graph_text, 0, C.array_new(U32.mul(size, size), 0), 10000)
  do IO<Unit>:
    resolution: U32 <- C.env_number("CLUSTER_RESOLUTION", "5000", 10000)
    seed: U32 <- C.env_number("CLUSTER_SEED", "1", 4294967295)
    labels: Array<U32> <- C.result_unwrap(Array<U32>,
      L.cluster(matrix, size, 5000, resolution, seed, 100n))
    print_cells(C.to_nat(size), 0, labels)


law main:
  IO(Unit)

def main():
  do IO<Unit>:
    size: U32 <- C.env_number("GRAPH_SIZE", "0", 64)
    graph_text: String <- C.env("GRAPH_EDGES", "")
    mode: String <- C.env("GRAPH_MODE", "cluster")
    C.branch(IO(Unit), String.eq(mode, "aggregate"), \{
      True: (
        run_aggregate(size, graph_text)
      )
      False: (
        run_cluster(size, graph_text)
      )
    })
