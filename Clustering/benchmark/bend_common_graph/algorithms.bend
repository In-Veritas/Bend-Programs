# Clustering kernels over an already filtered sparse graph.
import Base
import ../../lib/common.bend as C
import ../../lib/packing.bend as P
import ../../single_linkage.bend as S
import ../../complete_linkage.bend as H
import ../../set_cover.bend as SC

type Search is Type:
  Search{rows: Array<C.Neighbors>, representatives: Array<U32>,
    center: U32, score: U32}

law neighbor_score:
  for neighbors: C.Neighbors
  for +target: U32
  C.Neighbors & U32

def neighbor_score(neighbors, target):
  match neighbors:
    case C.NeighborsNil{}: (C.NeighborsNil{}, 0)
    case C.NeighborsCon{raw_node, raw_score, tail}:
      +node = {raw_node : U32}
      +score = {raw_score : U32}
      C.branch(C.Neighbors & U32, U32.is_eq(node, target), \{
        True: (C.NeighborsCon{node, score, tail}, score)
        False: (
          C.apply(C.Neighbors & U32, C.Neighbors & U32,
            \{Tuple: rest => found => (
              (C.NeighborsCon{node, score, rest}, found)
            )}, neighbor_score(tail, target))
        )
      })

law graph_score:
  for rows: Array<C.Neighbors>
  for +node: U32
  for +target: U32
  Array<C.Neighbors> & U32

def graph_score(rows, node, target):
  C.apply(Array<C.Neighbors> & C.Neighbors,
    Array<C.Neighbors> & U32,
    \{Tuple: next => neighbors => (
      C.apply(C.Neighbors & U32, Array<C.Neighbors> & U32,
        \{Tuple: rebuilt => score => (
          (Array.set(C.Neighbors, next, node, rebuilt), score)
        )}, neighbor_score(neighbors, target))
    )}, Array.get(C.Neighbors, rows, node))

law centroid_find:
  for fuel: Nat
  for +position: U32
  for +node: U32
  for rows: Array<C.Neighbors>
  for representatives: Array<U32>
  for +sentinel: U32
  for +best: U32
  for +best_score: U32
  for +choose_best: Bool
  Search

def centroid_find(fuel, position, node, rows, representatives,
                  sentinel, best, best_score, choose_best):
  match fuel:
    case Zero{}: Search{rows, representatives, best, best_score}
    case Succ{rest}:
      C.apply(Array<U32> & U32, Search,
        \{Tuple: next_representatives => +center => (
          C.apply(Array<C.Neighbors> & U32, Search,
            \{Tuple: next_rows => +score => (
              C.branch(Search, U32.is_gt(score, 0) && Bool.not(choose_best), \{
                True: Search{next_rows, next_representatives, center, score}
                False: (
                  +better = {U32.is_gt(score, best_score) : Bool}
                  centroid_find(rest, U32.add(position, 1), node, next_rows,
                    next_representatives, sentinel,
                    C.select(better, center, best),
                    C.select(better, score, best_score), choose_best)
                )
              })
            )}, graph_score(rows, node, center))
        )}, Array.get(U32, representatives, position))

law centroid_use:
  for state: Search
  for +node: U32
  for +size: U32
  for +count: U32
  for labels: Array<U32>
  for continue: Array<C.Neighbors> -> Array<U32> -> U32 -> Array<U32> ->
    Array<U32>
  Array<U32>

def centroid_use(state, node, size, count, labels, continue):
  match state:
    case Search{next_rows, next_representatives, +center, score}:
      C.branch(Array<U32>, U32.is_eq(center, size), \{
        True: (
          updated_representatives =
            Array.set(U32, next_representatives, count, node)
          updated_labels = Array.set(U32, labels, node, node)
          continue(next_rows, updated_representatives,
            U32.add(count, 1), updated_labels)
        )
        False: (
          updated_labels = Array.set(U32, labels, node, center)
          continue(next_rows, next_representatives, count, updated_labels)
        )
      })

law centroid_nodes:
  for fuel: Nat
  for +node: U32
  for +size: U32
  for rows: Array<C.Neighbors>
  for representatives: Array<U32>
  for +count: U32
  for labels: Array<U32>
  for +choose_best: Bool
  Array<U32>

def centroid_nodes(fuel, node, size, rows, representatives, count, labels,
                   choose_best):
  match fuel:
    case Zero{}: labels
    case Succ{rest}:
      centroid_use(
        centroid_find(C.to_nat(count), 0, node, rows, representatives,
          size, size, 0, choose_best),
        node, size, count, labels,
        next_rows => next_representatives => next_count => next_labels =>
          centroid_nodes(rest, U32.add(node, 1), size, next_rows,
            next_representatives, next_count, next_labels, choose_best))

law centroid_cluster:
  for graph: C.SparseGraph
  for +size: U32
  for +choose_best: Bool
  Result<String, Array<U32>>

def centroid_cluster(graph, size, choose_best):
  match graph:
    case C.SparseGraph{raw_size, rows}:
      Done{centroid_nodes(C.to_nat(size), 0, size, rows,
        C.array_new(size, 0), 0, C.array_new(size, 0), choose_best)}

law degree:
  for neighbors: C.Neighbors
  for +count: U32
  C.Neighbors & U32

def degree(neighbors, count):
  match neighbors:
    case C.NeighborsNil{}: (C.NeighborsNil{}, count)
    case C.NeighborsCon{node, score, tail}:
      C.apply(C.Neighbors & U32, C.Neighbors & U32,
        \{Tuple: rest => total => (
          (C.NeighborsCon{node, score, rest}, total)
        )}, degree(tail, U32.add(count, 1)))

law degree_items:
  for fuel: Nat
  for +node: U32
  for rows: Array<C.Neighbors>
  Array<C.Neighbors> & List<C.Record>

def degree_items(fuel, node, rows):
  match fuel:
    case Zero{}: (rows, Nil{})
    case Succ{rest}:
      C.apply(Array<C.Neighbors> & C.Neighbors,
        Array<C.Neighbors> & List<C.Record>,
        \{Tuple: next_rows => neighbors => (
          C.apply(C.Neighbors & U32,
            Array<C.Neighbors> & List<C.Record>,
            \{Tuple: rebuilt => count => (
              updated = Array.set(C.Neighbors, next_rows, node, rebuilt)
              C.apply(Array<C.Neighbors> & List<C.Record>,
                Array<C.Neighbors> & List<C.Record>,
                \{Tuple: final_rows => items => (
                  empty = {Array.new(U32, 0n, 0) : Array<U32>}
                  (final_rows, Con{C.Record{node, "",
                    P.Sequence{empty, 2, 0}, count,
                    Array.new(U32, 0n, 0), Array.new(U32, 0n, 0)}, items})
                )}, degree_items(rest, U32.add(node, 1), updated))
            )}, degree(neighbors, 0))
        )}, Array.get(C.Neighbors, rows, node))

law cover_sorted:
  for items: List<C.Record>
  for rows: Array<C.Neighbors>
  for labels: Array<U32>
  for +size: U32
  Array<U32>

def cover_sorted(items, rows, labels, size):
  match items:
    case Nil{}: labels
    case Con{C.Record{raw_node, label, bases, width, words, sketch}, tail}:
      +node = {raw_node : U32}
      C.apply(Array<U32> & U32, Array<U32>,
        \{Tuple: next_labels => current => (
          C.branch(Array<U32>, U32.is_eq(current, size), \{
            True: (
              C.apply(Array<C.Neighbors> & Array<U32>, Array<U32>,
                \{Tuple: next_rows => assigned => (
                  cover_sorted(tail, next_rows, assigned, size)
                )}, SC.assign_center(rows, next_labels, node, size))
            )
            False: cover_sorted(tail, rows, next_labels, size)
          })
        )}, Array.get(U32, labels, node))

law set_cover_cluster:
  for graph: C.SparseGraph
  for +size: U32
  Result<String, Array<U32>>

def set_cover_cluster(graph, size):
  match graph:
    case C.SparseGraph{raw_size, rows}:
      C.apply(Array<C.Neighbors> & List<C.Record>,
        Result<String, Array<U32>>,
        \{Tuple: next_rows => items => (
          Done{cover_sorted(C.records_sort(items), next_rows,
            C.array_new(size, size), size)}
        )}, degree_items(C.to_nat(size), 0, rows))

law cluster:
  for +algorithm: U32
  for graph: C.SparseGraph
  for +size: U32
  for +threshold: U32
  Result<String, Array<U32>>

def cluster(algorithm, graph, size, threshold):
  match algorithm:
    case 0: S.cluster(graph, size, threshold, 0, 0, 1n)
    case 1: H.cluster(graph, size, threshold, 0, 0, 1n)
    case 2: centroid_cluster(graph, size, True{})
    case 3: centroid_cluster(graph, size, False{})
    case _: set_cover_cluster(graph, size)
