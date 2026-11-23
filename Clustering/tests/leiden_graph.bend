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

law read_graph:
  for text: String
  for +index: U32
  for +size: U32
  for rows: Array<C.Neighbors>
  for +scale: U32
  Array<C.Neighbors>

def read_graph(text, index, size, rows, scale):
  match text:
    case SNil{}:
      rows
    case SCon{Chr{code}, tail}:
      +value = {U32.mul(U32.sub(code, 48), scale) : U32}
      updated = C.branch(Array<C.Neighbors>, U32.is_gt(value, 0), \{
        True: (
          L.row_weight_add(rows, U32.div(index, size), U32.mod(index, size), value)
        )
        False: (
          rows
        )
      })
      read_graph(tail, U32.add(index, 1), size, updated, scale)

law row_lookup:
  for neighbors: C.Neighbors
  for +target: U32
  C.Neighbors & U32

def row_lookup(neighbors, target):
  match neighbors:
    case C.NeighborsNil{}:
      (C.NeighborsNil{}, 0)
    case C.NeighborsCon{raw_other, raw_weight, tail}:
      +other = {raw_other : U32}
      +weight = {raw_weight : U32}
      C.branch(C.Neighbors & U32, U32.is_eq(other, target), \{
        True: (
          (C.NeighborsCon{other, weight, tail}, weight)
        )
        False: (
          C.apply(C.Neighbors & U32, C.Neighbors & U32,
            \{Tuple: rest => found => (
              (C.NeighborsCon{other, weight, rest}, found)
            )},
            row_lookup(tail, target))
        )
      })

law print_graph:
  for fuel: Nat
  for +index: U32
  for +size: U32
  for rows: Array<C.Neighbors>
  IO(Unit)

def print_graph(fuel, index, size, rows):
  match fuel:
    case Zero{}:
      IO.pure(Unit, Unit{})
    case Succ{rest}:
      +source = {U32.div(index, size) : U32}
      +target = {U32.mod(index, size) : U32}
      C.apply(Array<C.Neighbors> & C.Neighbors, IO(Unit),
        \{Tuple: next_rows => neighbors => (
          C.apply(C.Neighbors & U32, IO(Unit),
            \{Tuple: rebuilt => value => (
              updated = Array.set(C.Neighbors, next_rows, source, rebuilt)
              do IO<Unit>:
                printed: Unit <- IO.print(U32.show(value))
                print_graph(rest, U32.add(index, 1), size, updated)
            )},
            row_lookup(neighbors, target))
        )},
        Array.get(C.Neighbors, rows, source))


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
    case Tuple{L.Graph{raw_size, rows, mass}, parents}:
      +size = {raw_size : U32}
      do IO<Unit>:
        edge_output: Unit <- print_graph(C.to_nat(U32.mul(size, size)), 0, size, rows)
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
        read_graph(graph_text, 0, size,
          Array.new(C.Neighbors, C.array_depth(31n, size, 1, 0n), C.NeighborsNil{}), 1),
        C.array_new(size, 1)},
      read_cells(labels_text, 0, C.array_new(size, 0), 1),
      read_cells(parents_text, 0, C.array_new(size, 0), 1), new_size))


law run_cluster:
  for +size: U32
  for graph_text: String
  IO(Unit)

def run_cluster(size, graph_text):
  rows = read_graph(graph_text, 0, size,
    Array.new(C.Neighbors, C.array_depth(31n, size, 1, 0n), C.NeighborsNil{}), 10000)
  do IO<Unit>:
    resolution: U32 <- C.env_number("CLUSTER_RESOLUTION", "5000", 10000)
    seed: U32 <- C.env_number("CLUSTER_SEED", "1", 4294967295)
    labels: Array<U32> <- C.result_unwrap(Array<U32>,
      L.cluster(C.SparseGraph{size, rows}, size, 5000, resolution, seed, 100n))
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
