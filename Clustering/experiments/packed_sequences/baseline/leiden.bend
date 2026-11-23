# Leiden for the unweighted FASTA identity graph and the CPM objective.
# One multilevel iteration: local moving, constrained refinement, aggregation.
# Refinement uses seeded uniform selection; see README for variant details.
import Base
import ./lib/common.bend as C

# Types
# =====

type Graph is Type:
  Graph{size: U32, edges: Array<U32>, mass: Array<U32>}

type Stats is Type:
  Stats{edges: Array<U32>, mass: Array<U32>, count: Array<U32>}

# Graph
# =====

law random_next:
  for seed: U32
  U32

def random_next(seed):
  U32.add(U32.mul(seed, 1664525), 1013904223)

law shuffle:
  for fuel: Nat
  for +index: U32
  for seed: U32
  for order: Array<U32>
  Array<U32> & U32

def shuffle(fuel, index, seed, order):
  match fuel:
    case Zero{}:
      (order, seed)
    case Succ{rest}:
      +next_seed = {random_next(seed) : U32}
      +other = {U32.mod(next_seed, U32.add(index, 1)) : U32}
      C.apply(Array<U32> & U32, Array<U32> & U32,
        \{Tuple: next => first => (
          C.apply(Array<U32> & U32, Array<U32> & U32,
            \{Tuple: updated => second => (
              swapped = Array.set(U32, Array.set(U32, updated, other, first), index, second)
              shuffle(rest, U32.sub(index, 1), next_seed, swapped)
            )},
            Array.get(U32, next, other))
        )},
        Array.get(U32, order, index))

law graph_copy:
  for graph: Graph
  Graph & Graph

def graph_copy(graph):
  match graph:
    case Graph{raw, edges, mass}:
      +size = {raw : U32}
      C.apply(Array<U32> & Array<U32>, Graph & Graph,
        \{Tuple: e1 => e2 => (
          C.apply(Array<U32> & Array<U32>, Graph & Graph,
            \{Tuple: m1 => m2 => (
              (Graph{size, e1, m1}, Graph{size, e2, m2})
            )},
            Array.clone(U32, mass))
        )},
        Array.clone(U32, edges))

law array_add:
  for array: Array<U32>
  for +index: U32
  for value: U32
  Array<U32>

def array_add(array, index, value):
  C.apply(Array<U32> & U32, Array<U32>,
    \{Tuple: next => old => (
      Array.set(U32, next, index, U32.add(old, value))
    )},
    Array.get(U32, array, index))

law stats_add:
  for stats: Stats
  for +community: U32
  for edge: U32
  for mass: U32
  Stats

def stats_add(stats, community, edge, mass):
  match stats:
    case Stats{edges, masses, counts}:
      Stats{array_add(edges, community, edge),
        array_add(masses, community, mass), array_add(counts, community, 1)}

law stats_rows:
  for fuel: Nat
  for +index: U32
  for +node: U32
  for +size: U32
  for edges: Array<U32>
  for mass: Array<U32>
  for labels: Array<U32>
  for stats: Stats
  Stats

def stats_rows(fuel, index, node, size, edges, mass, labels, stats):
  match fuel:
    case Zero{}:
      stats
    case Succ{rest}:
      C.apply(Array<U32> & U32, Stats,
        \{Tuple: next_edges => edge => (
          C.apply(Array<U32> & U32, Stats,
            \{Tuple: next_mass => weight => (
              C.apply(Array<U32> & U32, Stats,
                \{Tuple: next_labels => community => (
                  next_stats = C.branch(Stats, U32.is_eq(index, node), \{
                    True: (
                      stats
                    )
                    False: (
                      stats_add(stats, community, edge, weight)
                    )
                  })
                  stats_rows(rest, U32.add(index, 1), node, size, next_edges, next_mass,
                    next_labels, next_stats)
                )},
                Array.get(U32, labels, index))
            )},
            Array.get(U32, mass, index))
        )},
        Array.get(U32, edges, U32.add(U32.mul(node, size), index)))

law node_stats:
  for graph: Graph
  for labels: Array<U32>
  for node: U32
  Stats

def node_stats(graph, labels, node):
  match graph:
    case Graph{raw, edges, mass}:
      +size = {raw : U32}
      initial = {Stats{C.array_new(size, 0), C.array_new(size, 0),
        C.array_new(size, 0)} : Stats}
      stats_rows(C.to_nat(size), 0, node, size, edges, mass, labels, initial)

law penalty:
  for resolution: U32
  for left: U32
  for right: U32
  Nat

def penalty(resolution, left, right):
  Nat.mul(C.to_nat(resolution), Nat.mul(C.to_nat(left), C.to_nat(right)))

law edge_score:
  for edge: U32
  Nat

def edge_score(edge):
  Nat.mul(C.to_nat(edge), C.to_nat(10000))

# Compare signed CPM gains by cross-addition of natural numbers. This avoids
# unsigned subtraction and keeps large aggregate mass products exact.
law score_better:
  for positive: Nat
  for negative: Nat
  for old_positive: Nat
  for old_negative: Nat
  Bool

def score_better(positive, negative, old_positive, old_negative):
  Nat.is_lt(Nat.add(old_positive, negative),
    Nat.add(positive, old_negative))

law best_community:
  for fuel: Nat
  for +index: U32
  for +node_mass: U32
  for +resolution: U32
  for edges: Array<U32>
  for mass: Array<U32>
  for +best: U32
  for +best_positive: Nat
  for +best_negative: Nat
  U32

def best_community(fuel, index, node_mass, resolution, edges, mass, best, best_positive, best_negative):
  match fuel:
    case Zero{}:
      best
    case Succ{rest}:
      C.apply(Array<U32> & U32, U32,
        \{Tuple: next_edges => edge => (
          C.apply(Array<U32> & U32, U32,
            \{Tuple: next_mass => weight => (
              +positive = {edge_score(edge) : Nat}
              +negative = {penalty(resolution, node_mass, weight) : Nat}
              C.branch(U32, score_better(positive, negative, best_positive, best_negative), \{
                True: (
                  best_community(rest, U32.add(index, 1), node_mass, resolution, next_edges,
                    next_mass, index, positive, negative)
                )
                False: (
                  best_community(rest, U32.add(index, 1), node_mass, resolution, next_edges,
                    next_mass, best, best_positive, best_negative)
                )
              })
            )},
            Array.get(U32, mass, index))
        )},
        Array.get(U32, edges, index))

law move_destination:
  for stats: Stats
  for +own: U32
  for +node_mass: U32
  for +size: U32
  for +resolution: U32
  U32

def move_destination(stats, own, node_mass, size, resolution):
  match stats:
    case Stats{edges, mass, counts}:
      C.apply(Array<U32> & U32, U32,
        \{Tuple: next_edges => own_edge => (
          C.apply(Array<U32> & U32, U32,
            \{Tuple: next_mass => own_mass => (
              best_community(C.to_nat(size), 0, node_mass, resolution, next_edges,
                next_mass, own, edge_score(own_edge),
                penalty(resolution, node_mass, own_mass))
            )},
            Array.get(U32, mass, own))
        )},
        Array.get(U32, edges, own))

law graph_node_mass:
  for graph: Graph
  for node: U32
  U32

def graph_node_mass(graph, node):
  match graph:
    case Graph{size, edges, mass}:
      C.labels_lookup(mass, node)

law move_sweep:
  for fuel: Nat
  for +index: U32
  for +size: U32
  for +resolution: U32
  for graph: Graph
  for order: Array<U32>
  for labels: Array<U32>
  for changed: U32
  (Graph & Array<U32>) & U32

def move_sweep(fuel, index, size, resolution, graph, order, labels, changed):
  match fuel:
    case Zero{}:
      ((graph, labels), changed)
    case Succ{rest}:
      C.apply(Array<U32> & U32, (Graph & Array<U32>) & U32,
        \{Tuple: next_order => raw_node => (
          +node = {raw_node : U32}
          C.apply(Array<U32> & U32, (Graph & Array<U32>) & U32,
            \{Tuple: next_labels => raw_own => (
              C.apply(Array<U32> & Array<U32>, (Graph & Array<U32>) & U32,
                \{Tuple: l1 => l2 => (
                  C.apply(Graph & Graph, (Graph & Array<U32>) & U32,
                    \{Tuple: g1 => g2 => (
                      C.apply(Graph & Graph, (Graph & Array<U32>) & U32,
                        \{Tuple: g3 => g4 => (
                          +own = {raw_own : U32}
                          node_mass = graph_node_mass(g1, node)
                          stats = node_stats(g3, l1, node)
                          +destination = {move_destination(stats, own, node_mass, size,
                            resolution) : U32}
                          updated = Array.set(U32, l2, node, destination)
                          moves = U32.add(changed, C.select(U32.is_eq(own, destination), 0, 1))
                          move_sweep(rest, U32.add(index, 1), size, resolution, g4, next_order,
                            updated, moves)
                        )},
                        graph_copy(g2))
                    )},
                    graph_copy(graph))
                )},
                Array.clone(U32, next_labels))
            )},
            Array.get(U32, labels, node))
        )},
        Array.get(U32, order, index))

law move_nodes:
  for fuel: Nat
  for +size: U32
  for +resolution: U32
  for seed: U32
  for graph: Graph
  for labels: Array<U32>
  Result<String, (Graph & Array<U32>) & U32>

def move_nodes(fuel, size, resolution, seed, graph, labels):
  match fuel:
    case Zero{}:
      Fail{"Leiden local moves exceeded CLUSTER_PASSES"}
    case Succ{rest}:
      C.apply(Array<U32> & U32, Result<String, (Graph & Array<U32>) & U32>,
        \{Tuple: order => next_seed => (
          C.apply((Graph & Array<U32>) & U32, Result<String, (Graph & Array<U32>) & U32>,
            \{Tuple: \{Tuple: next_graph => next_labels => changed => (
              C.branch(Result<String, (Graph & Array<U32>) & U32>, U32.is_eq(changed, 0), \{
                True: (
                  Done{((next_graph, next_labels), next_seed)}
                )
                False: (
                  move_nodes(rest, size, resolution, next_seed, next_graph, next_labels)
                )
              })
            )}},
            move_sweep(C.to_nat(size), 0,
            size, resolution, graph, order, labels, 0))
        )},
        shuffle(C.to_nat(size), U32.sub(size, 1), seed,
        C.labels_identity(size)))

law boundary_columns:
  for fuel: Nat
  for +index: U32
  for +row: U32
  for +size: U32
  for +parent: U32
  for +community: U32
  for edges: Array<U32>
  for parents: Array<U32>
  for refined: Array<U32>
  for total: U32
  (Array<U32> & Array<U32> & Array<U32>) & U32

def boundary_columns(fuel, index, row, size, parent, community, edges, parents, refined, total):
  match fuel:
    case Zero{}:
      ((edges, parents, refined), total)
    case Succ{rest}:
      C.apply(Array<U32> & U32, (Array<U32> & Array<U32> & Array<U32>) & U32,
        \{Tuple: next_edges => edge => (
          C.apply(Array<U32> & U32, (Array<U32> & Array<U32> & Array<U32>) & U32,
            \{Tuple: next_parents => other_parent => (
              C.apply(Array<U32> & U32, (Array<U32> & Array<U32> & Array<U32>) & U32,
                \{Tuple: next_refined => other_community => (
                  included = U32.is_eq(parent, other_parent) &&
                    U32.is_ne(community, other_community)
                  boundary_columns(rest, U32.add(index, 1), row, size, parent, community,
                    next_edges, next_parents, next_refined,
                    U32.add(total, C.select(included, edge, 0)))
                )},
                Array.get(U32, refined, index))
            )},
            Array.get(U32, parents, index))
        )},
        Array.get(U32, edges, U32.add(U32.mul(row, size), index)))

law boundary_rows:
  for fuel: Nat
  for +row: U32
  for +size: U32
  for edges: Array<U32>
  for parents: Array<U32>
  for refined: Array<U32>
  for boundary: Array<U32>
  Array<U32>

def boundary_rows(fuel, row, size, edges, parents, refined, boundary):
  match fuel:
    case Zero{}:
      boundary
    case Succ{rest}:
      C.apply(Array<U32> & U32, Array<U32>,
        \{Tuple: next_parents => parent => (
          C.apply(Array<U32> & U32, Array<U32>,
            \{Tuple: next_refined => raw_community => (
              +community = {raw_community : U32}
              C.apply((Array<U32> & Array<U32> & Array<U32>) & U32, Array<U32>,
                \{Tuple: \{Tuple: next_edges => \{Tuple: updated_parents => updated_refined => total => (
                  next_boundary = array_add(boundary, community, total)
                  boundary_rows(rest, U32.add(row, 1), size, next_edges, updated_parents,
                    updated_refined, next_boundary)
                )}}},

                boundary_columns(C.to_nat(size), 0, row, size, parent, community,
                edges, next_parents, next_refined, 0))
            )},
            Array.get(U32, refined, row))
        )},
        Array.get(U32, parents, row))

law boundaries:
  for graph: Graph
  for parents: Array<U32>
  for refined: Array<U32>
  Array<U32>

def boundaries(graph, parents, refined):
  match graph:
    case Graph{raw, edges, mass}:
      +size = {raw : U32}
      boundary_rows(C.to_nat(size), 0, size, edges, parents, refined,
        C.array_new(size, 0))

law well_connected:
  for edge: U32
  for resolution: U32
  for left: U32
  for right: U32
  Bool

def well_connected(edge, resolution, left, right):
  Bool.not(Nat.is_lt(edge_score(edge), penalty(resolution, left, right)))

law eligible_node:
  for stats: Stats
  for +parent: U32
  for +node_mass: U32
  for resolution: U32
  Bool & U32

def eligible_node(stats, parent, node_mass, resolution):
  match stats:
    case Stats{edges, mass, count}:
      C.apply(Array<U32> & U32, Bool & U32,
        \{Tuple: unused_edges => edge => (
          C.apply(Array<U32> & U32, Bool & U32,
            \{Tuple: unused_mass => raw_mass => (
              +other_mass = {raw_mass : U32}
              (well_connected(edge, resolution, node_mass, other_mass),
                U32.add(node_mass, other_mass))
            )},
            Array.get(U32, mass, parent))
        )},
        Array.get(U32, edges, parent))

law refine_candidates:
  for fuel: Nat
  for +index: U32
  for +node: U32
  for +node_mass: U32
  for +parent: U32
  for +parent_mass: U32
  for +resolution: U32
  for edges: Array<U32>
  for mass: Array<U32>
  for counts: Array<U32>
  for boundary: Array<U32>
  for parents: Array<U32>
  for +chosen: U32
  for +seen: U32
  for seed: U32
  U32 & U32

def refine_candidates(fuel, index, node, node_mass, parent, parent_mass, resolution, edges, mass, counts, boundary, parents, chosen, seen, seed):
  match fuel:
    case Zero{}:
      (chosen, seed)
    case Succ{rest}:
      C.apply(Array<U32> & U32, U32 & U32,
        \{Tuple: next_edges => edge => (
          C.apply(Array<U32> & U32, U32 & U32,
            \{Tuple: next_mass => raw_weight => (
              C.apply(Array<U32> & U32, U32 & U32,
                \{Tuple: next_counts => count => (
                  C.apply(Array<U32> & U32, U32 & U32,
                    \{Tuple: next_boundary => cut => (
                      C.apply(Array<U32> & U32, U32 & U32,
                        \{Tuple: next_parents => candidate_parent => (
                          +weight = {raw_weight : U32}
                          valid = U32.is_ne(index, node) && U32.is_gt(count, 0) &&
                            U32.is_eq(candidate_parent, parent) &&
                            well_connected(edge, resolution, node_mass, weight) &&
                            well_connected(cut, resolution, weight, C.subtract(parent_mass, weight))
                          C.branch(U32 & U32, valid, \{
                            True: (
                              +next_seed = {random_next(seed) : U32}
                              destination = C.select(U32.is_eq(U32.mod(next_seed, U32.add(seen, 1)), 0),
                                index, chosen)
                              refine_candidates(rest, U32.add(index, 1), node, node_mass, parent,
                                parent_mass, resolution, next_edges, next_mass, next_counts,
                                next_boundary, next_parents, destination, U32.add(seen, 1), next_seed)
                            )
                            False: (
                              refine_candidates(rest, U32.add(index, 1), node, node_mass, parent,
                                parent_mass, resolution, next_edges, next_mass, next_counts,
                                next_boundary, next_parents, chosen, seen, seed)
                            )
                          })
                        )},
                        Array.get(U32, parents, index))
                    )},
                    Array.get(U32, boundary, index))
                )},
                Array.get(U32, counts, index))
            )},
            Array.get(U32, mass, index))
        )},
        Array.get(U32, edges, index))

law refine_choice:
  for stats: Stats
  for +node: U32
  for node_mass: U32
  for parent: U32
  for parent_mass: U32
  for resolution: U32
  for +size: U32
  for boundary: Array<U32>
  for parents: Array<U32>
  for seed: U32
  U32 & U32

def refine_choice(stats, node, node_mass, parent, parent_mass, resolution, size, boundary, parents, seed):
  match stats:
    case Stats{edges, mass, counts}:
      C.apply(Array<U32> & U32, U32 & U32,
        \{Tuple: next_counts => own_count => (
          C.branch(U32 & U32, U32.is_eq(own_count, 0), \{
            True: (
              refine_candidates(C.to_nat(size), 0, node, node_mass, parent,
                parent_mass, resolution, edges, mass, next_counts, boundary,
                parents, node, 0, seed)
            )
            False: (
              (node, seed)
            )
          })
        )},
        Array.get(U32, counts, node))

law refine_node:
  for graph: Graph
  for parents: Array<U32>
  for refined: Array<U32>
  for +node: U32
  for +size: U32
  for +resolution: U32
  for seed: U32
  Array<U32> & U32

def refine_node(graph, parents, refined, node, size, resolution, seed):
  C.apply(Graph & Graph, Array<U32> & U32,
    \{Tuple: g1 => g2 => (
      C.apply(Graph & Graph, Array<U32> & U32,
        \{Tuple: g3 => g4 => (
          C.apply(Graph & Graph, Array<U32> & U32,
            \{Tuple: g5 => g6 => (
              C.apply(Array<U32> & Array<U32>, Array<U32> & U32,
                \{Tuple: p1 => p2 => (
                  C.apply(Array<U32> & Array<U32>, Array<U32> & U32,
                    \{Tuple: p3 => p4 => (
                      C.apply(Array<U32> & Array<U32>, Array<U32> & U32,
                        \{Tuple: p5 => p6 => (
                          C.apply(Array<U32> & Array<U32>, Array<U32> & U32,
                            \{Tuple: r1 => r2 => (
                              C.apply(Array<U32> & Array<U32>, Array<U32> & U32,
                                \{Tuple: r3 => r4 => (
                                  +node_mass = {graph_node_mass(g1, node) : U32}
                                  +parent = {C.labels_lookup(p1, node) : U32}
                                  parent_stats = node_stats(g3, p3, node)
                                  C.apply(Bool & U32, Array<U32> & U32,
                                    \{Tuple: eligible => parent_mass => (
                                      stats = node_stats(g5, r1, node)
                                      boundary = boundaries(g6, p5, r3)
                                      result = C.branch(U32 & U32, eligible, \{
                                        True: (
                                          refine_choice(stats, node, node_mass, parent, parent_mass, resolution,
                                            size, boundary, p6, seed)
                                        )
                                        False: (
                                          (node, seed)
                                        )
                                      })
                                      C.apply(U32 & U32, Array<U32> & U32,
                                        \{Tuple: chosen => next_seed => (
                                          (Array.set(U32, r4, node, chosen), next_seed)
                                        )},
                                        result)
                                    )},
                                    eligible_node(parent_stats, parent,
                                    node_mass, resolution))
                                )},
                                Array.clone(U32, r2))
                            )},
                            Array.clone(U32, refined))
                        )},
                        Array.clone(U32, p4))
                    )},
                    Array.clone(U32, p2))
                )},
                Array.clone(U32, parents))
            )},
            graph_copy(g4))
        )},
        graph_copy(g2))
    )},
    graph_copy(graph))

law refine_sweep:
  for fuel: Nat
  for +index: U32
  for +size: U32
  for +resolution: U32
  for seed: U32
  for graph: Graph
  for parents: Array<U32>
  for order: Array<U32>
  for refined: Array<U32>
  Array<U32> & U32

def refine_sweep(fuel, index, size, resolution, seed, graph, parents, order, refined):
  match fuel:
    case Zero{}:
      (refined, seed)
    case Succ{rest}:
      C.apply(Array<U32> & U32, Array<U32> & U32,
        \{Tuple: next_order => raw_node => (
          C.apply(Graph & Graph, Array<U32> & U32,
            \{Tuple: g1 => g2 => (
              C.apply(Array<U32> & Array<U32>, Array<U32> & U32,
                \{Tuple: p1 => p2 => (
                  +node = {raw_node : U32}
                  C.apply(Array<U32> & Array<U32>, Array<U32> & U32,
                    \{Tuple: r1 => r2 => (
                      own = C.labels_lookup(r1, node)
                      result = C.branch(Array<U32> & U32, U32.is_eq(own, node), \{
                        True: (
                          refine_node(g1, p1, r2, node, size, resolution, seed)
                        )
                        False: (
                          (r2, seed)
                        )
                      })
                      C.apply(Array<U32> & U32, Array<U32> & U32,
                        \{Tuple: next_refined => next_seed => (
                          refine_sweep(rest, U32.add(index, 1), size, resolution, next_seed, g2, p2,
                            next_order, next_refined)
                        )},
                        result)
                    )},
                    Array.clone(U32, refined))
                )},
                Array.clone(U32, parents))
            )},
            graph_copy(graph))
        )},
        Array.get(U32, order, index))

law refine:
  for graph: Graph
  for parents: Array<U32>
  for +size: U32
  for resolution: U32
  for seed: U32
  Array<U32> & U32

def refine(graph, parents, size, resolution, seed):
  C.apply(Array<U32> & U32, Array<U32> & U32,
    \{Tuple: order => next_seed => (
      refine_sweep(C.to_nat(size), 0, size, resolution, next_seed, graph,
        parents, order, C.labels_identity(size))
    )},
    shuffle(C.to_nat(size), U32.sub(size, 1), seed,
    C.labels_identity(size)))

law compact:
  for fuel: Nat
  for +index: U32
  for +sentinel: U32
  for labels: Array<U32>
  for mapping: Array<U32>
  for +count: U32
  Array<U32> & U32

def compact(fuel, index, sentinel, labels, mapping, count):
  match fuel:
    case Zero{}:
      (labels, count)
    case Succ{rest}:
      C.apply(Array<U32> & U32, Array<U32> & U32,
        \{Tuple: next_labels => raw_old => (
          +old = {raw_old : U32}
          C.apply(Array<U32> & U32, Array<U32> & U32,
            \{Tuple: next_mapping => raw_known => (
              +known = {raw_known : U32}
              +assigned = {C.select(U32.is_eq(known, sentinel), count, known) : U32}
              new_count = U32.add(count, C.select(U32.is_eq(known, sentinel), 1, 0))
              updated_mapping = Array.set(U32, next_mapping, old, assigned)
              updated_labels = Array.set(U32, next_labels, index, assigned)
              compact(rest, U32.add(index, 1), sentinel, updated_labels, updated_mapping,
                new_count)
            )},
            Array.get(U32, mapping, old))
        )},
        Array.get(U32, labels, index))

law compact_labels:
  for labels: Array<U32>
  for +size: U32
  for +limit: U32
  Array<U32> & U32

def compact_labels(labels, size, limit):
  compact(C.to_nat(size), 0, limit, labels, C.array_new(limit, limit), 0)

law aggregate_columns:
  for fuel: Nat
  for +index: U32
  for +row: U32
  for +old_size: U32
  for +new_size: U32
  for +community: U32
  for edges: Array<U32>
  for refined: Array<U32>
  for result: Array<U32>
  Array<U32> & Array<U32> & Array<U32>

def aggregate_columns(fuel, index, row, old_size, new_size, community, edges, refined, result):
  match fuel:
    case Zero{}:
      (edges, refined, result)
    case Succ{rest}:
      C.apply(Array<U32> & U32, Array<U32> & Array<U32> & Array<U32>,
        \{Tuple: next_edges => edge => (
          C.apply(Array<U32> & U32, Array<U32> & Array<U32> & Array<U32>,
            \{Tuple: next_refined => target => (
              updated = array_add(result, U32.add(U32.mul(community, new_size), target), edge)
              aggregate_columns(rest, U32.add(index, 1), row, old_size, new_size, community,
                next_edges, next_refined, updated)
            )},
            Array.get(U32, refined, index))
        )},
        Array.get(U32, edges, U32.add(U32.mul(row, old_size), index)))

law aggregate_rows:
  for fuel: Nat
  for +row: U32
  for +old_size: U32
  for +new_size: U32
  for edges: Array<U32>
  for mass: Array<U32>
  for refined: Array<U32>
  for parents: Array<U32>
  for new_edges: Array<U32>
  for new_mass: Array<U32>
  for new_parents: Array<U32>
  Graph & Array<U32>

def aggregate_rows(fuel, row, old_size, new_size, edges, mass, refined, parents, new_edges, new_mass, new_parents):
  match fuel:
    case Zero{}:
      C.apply(Array<U32> & U32, Graph & Array<U32>,
        \{Tuple: compact_parents => count => (
          (Graph{new_size, new_edges, new_mass}, compact_parents)
        )},
        compact_labels(new_parents, new_size,
        old_size))
    case Succ{rest}:
      C.apply(Array<U32> & U32, Graph & Array<U32>,
        \{Tuple: next_mass => weight => (
          C.apply(Array<U32> & U32, Graph & Array<U32>,
            \{Tuple: next_refined => raw_community => (
              C.apply(Array<U32> & U32, Graph & Array<U32>,
                \{Tuple: next_parents => parent => (
                  +community = {raw_community : U32}
                  C.apply(Array<U32> & Array<U32> & Array<U32>, Graph & Array<U32>,
                    \{Tuple: next_edges => \{Tuple: updated_refined => updated_edges => (
                      updated_mass = array_add(new_mass, community, weight)
                      updated_parents = Array.set(U32, new_parents, community, parent)
                      aggregate_rows(rest, U32.add(row, 1), old_size, new_size, next_edges,
                        next_mass, updated_refined, next_parents, updated_edges,
                        updated_mass, updated_parents)
                    )}},
                    aggregate_columns(
                    C.to_nat(old_size), 0, row, old_size, new_size, community, edges,
                    next_refined, new_edges))
                )},
                Array.get(U32, parents, row))
            )},
            Array.get(U32, refined, row))
        )},
        Array.get(U32, mass, row))

law aggregate:
  for graph: Graph
  for refined: Array<U32>
  for parents: Array<U32>
  for +new_size: U32
  Graph & Array<U32>

def aggregate(graph, refined, parents, new_size):
  match graph:
    case Graph{raw_size, edges, mass}:
      +old_size = {raw_size : U32}
      aggregate_rows(C.to_nat(old_size), 0, old_size, new_size, edges, mass,
        refined, parents, C.array_new(U32.mul(new_size, new_size), 0),
        C.array_new(new_size, 0), C.array_new(new_size, 0))

law canonical_minima:
  for fuel: Nat
  for +index: U32
  for labels: Array<U32>
  for minima: Array<U32>
  Array<U32> & Array<U32>

def canonical_minima(fuel, index, labels, minima):
  match fuel:
    case Zero{}:
      (labels, minima)
    case Succ{rest}:
      C.apply(Array<U32> & U32, Array<U32> & Array<U32>,
        \{Tuple: next_labels => raw_label => (
          +label = {raw_label : U32}
          C.apply(Array<U32> & U32, Array<U32> & Array<U32>,
            \{Tuple: next_minima => old => (
              updated = Array.set(U32, next_minima, label, C.minimum(old, index))
              canonical_minima(rest, U32.add(index, 1), next_labels, updated)
            )},
            Array.get(U32, minima, label))
        )},
        Array.get(U32, labels, index))

law canonicalize:
  for labels: Array<U32>
  for +size: U32
  Array<U32>

def canonicalize(labels, size):
  C.apply(Array<U32> & Array<U32>, Array<U32>,
    \{Tuple: next => minima => (
      C.labels_compose(C.to_nat(size), 0, next, minima)
    )},
    canonical_minima(C.to_nat(size), 0, labels,
    C.array_new(size, size)))

law level_refine:
  for graph: Graph
  for parents: Array<U32>
  for +size: U32
  for +original_size: U32
  for resolution: U32
  for seed: U32
  for mapping: Array<U32>
  for continue: U32 -> U32 -> Graph -> Array<U32> -> Array<U32> -> Result<String, Array<U32>>
  Result<String, Array<U32>>

def level_refine(graph, parents, size, original_size, resolution, seed, mapping, continue):
  C.apply(Graph & Graph, Result<String, Array<U32>>,
    \{Tuple: g1 => g2 => (
      C.apply(Array<U32> & Array<U32>, Result<String, Array<U32>>,
        \{Tuple: p1 => p2 => (
          C.apply(Array<U32> & U32, Result<String, Array<U32>>,
            \{Tuple: refined => next_seed => (
              C.apply(Array<U32> & U32, Result<String, Array<U32>>,
                \{Tuple: compacted => raw_size => (
                  C.apply(Array<U32> & Array<U32>, Result<String, Array<U32>>,
                    \{Tuple: r1 => r2 => (
                      +new_size = {raw_size : U32}
                      C.apply(Bool, Result<String, Array<U32>>, \{
                          True: (
                            Fail{"Leiden refinement did not contract; try another seed"}
                          )
                          False: (
                            C.apply(Graph & Array<U32>, Result<String, Array<U32>>,
                              \{Tuple: next_graph => next_parents => (
                                next_mapping = C.labels_compose(C.to_nat(original_size), 0, mapping, r2)
                                continue(new_size, next_seed, next_graph, next_parents, next_mapping)
                              )},
                              aggregate(g2, r1, p2, new_size))
                          )
                      }, U32.is_ge(new_size, size))
                    )},
                    Array.clone(U32, compacted))
                )},
                compact_labels(refined, size, size))
            )},
            refine(g1, p1, size, resolution, seed))
        )},
        Array.clone(U32, parents))
    )},
    graph_copy(graph))

law level_moved:
  for result: (Graph & Array<U32>) & U32
  for +size: U32
  for +original_size: U32
  for resolution: U32
  for mapping: Array<U32>
  for continue: U32 -> U32 -> Graph -> Array<U32> -> Array<U32> -> Result<String, Array<U32>>
  Result<String, Array<U32>>

def level_moved(result, size, original_size, resolution, mapping, continue):
  match result:
    case Tuple{Tuple{graph, parents}, seed}:
      C.apply(Array<U32> & U32, Result<String, Array<U32>>,
        \{Tuple: compacted => count => (
          C.branch(Result<String, Array<U32>>, U32.is_eq(count, size), \{
            True: (
              Done{C.labels_compose(C.to_nat(original_size), 0, mapping, compacted)}
            )
            False: (
              level_refine(graph, compacted, size, original_size, resolution, seed,
                mapping, continue)
            )
          })
        )},
        compact_labels(parents, size, size))

law levels:
  for fuel: Nat
  for +size: U32
  for +original_size: U32
  for +resolution: U32
  for seed: U32
  for +passes: Nat
  for graph: Graph
  for parents: Array<U32>
  for mapping: Array<U32>
  Result<String, Array<U32>>

def levels(fuel, size, original_size, resolution, seed, passes, graph, parents, mapping):
  match fuel:
    case Zero{}:
      Fail{"Leiden aggregation exhausted its structural bound"}
    case Succ{rest}:
      do Result<&1, &1, String, Array<U32>>:
        result: (Graph & Array<U32>) & U32 <- move_nodes(passes, size,
          resolution, seed, graph, parents)
        level_moved(result, size, original_size, resolution, mapping,
          n => s => g => p => m => levels(rest, n, original_size,
            resolution, s, passes, g, p, m))

law graph_threshold:
  for fuel: Nat
  for +index: U32
  for +size: U32
  for +threshold: U32
  for matrix: Array<U32>
  Array<U32>

def graph_threshold(fuel, index, size, threshold, matrix):
  match fuel:
    case Zero{}:
      matrix
    case Succ{rest}:
      C.apply(Array<U32> & U32, Array<U32>,
        \{Tuple: next => value => (
          off_diagonal = U32.is_ne(U32.div(index, size), U32.mod(index, size))
          edge = C.select(off_diagonal && U32.is_ge(value, threshold), 1, 0)
          updated = Array.set(U32, next, index, edge)
          graph_threshold(rest, U32.add(index, 1), size, threshold, updated)
        )},
        Array.get(U32, matrix, index))

law cluster:
  for matrix: Array<U32>
  for +size: U32
  for threshold: U32
  for resolution: U32
  for seed: U32
  for passes: Nat
  Result<String, Array<U32>>

def cluster(matrix, size, threshold, resolution, seed, passes):
  edges = graph_threshold(C.to_nat(U32.mul(size, size)), 0, size, threshold, matrix)
  graph = {Graph{size, edges, C.array_new(size, 1)} : Graph}
  do Result<&1, &1, String, Array<U32>>:
    labels: Array<U32> <- levels(Succ{C.to_nat(size)}, size, size, resolution,
      seed, passes, graph, C.labels_identity(size), C.labels_identity(size))
    return canonicalize(labels, size)

law run_dataset:
  for dataset: C.Dataset
  for +threshold: U32
  for reverse: Bool
  for resolution: U32
  for seed: U32
  for passes: Nat
  IO(Unit)

def run_dataset(dataset, threshold, reverse, resolution, seed, passes):
  match dataset:
    case C.Dataset{items, raw_size}:
      +size = {raw_size : U32}
      C.apply(List<C.Record> & List<C.Record>, IO(Unit),
        \{Tuple: input => output => (
          matrix = C.matrix_build(input, size, reverse)
          do IO<Unit>:
            labels: Array<U32> <- C.result_unwrap(Array<U32>,
              cluster(matrix, size, threshold, resolution, seed, passes))
            C.output(output, labels)
        )},
        C.records_copy(items))

law run_config:
  for config: C.Config
  IO(Unit)

def run_config(config):
  match config:
    case C.Config{identity, alphabet, reverse, resolution, seed, passes}:
      do IO<Unit>:
        dataset: C.Dataset <- C.fasta_read(alphabet)
        run_dataset(dataset, identity, reverse, resolution, seed, passes)

law main:
  IO(Unit)

def main():
  do IO<Unit>:
    config: C.Config <- C.config_read()
    run_config(config)
