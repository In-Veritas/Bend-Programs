#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <inttypes.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  char *id;
  uint64_t length;
} Object;

typedef struct {
  Object *data;
  size_t len;
  size_t cap;
} Objects;

typedef struct {
  uint32_t a;
  uint32_t b;
  double score;
} Edge;

typedef struct {
  Edge *data;
  size_t len;
  size_t cap;
} Edges;

typedef struct {
  uint32_t node;
  double score;
} Adj;

typedef struct {
  size_t count;
  size_t edge_count;
  size_t *offset;
  Adj *adj;
  Edge *edges;
} Graph;

typedef struct {
  uint32_t *data;
  size_t len;
  size_t cap;
} Members;

typedef struct {
  uint32_t node;
  size_t degree;
} DegreeOrder;

typedef enum {
  ALG_SINGLE,
  ALG_COMPLETE,
  ALG_UCLUST,
  ALG_CDHIT,
  ALG_SET_COVER,
  ALG_LEIDEN,
} Algorithm;

typedef struct {
  const char *input;
  const char *ids;
  const char *output;
  const char *metric;
  Algorithm algorithm;
  double threshold;
  double resolution;
  uint32_t seed;
  uint32_t passes;
  uint32_t threads;
} Options;

static void fail(const char *message) {
  fprintf(stderr, "cluster_graph: %s\n", message);
  exit(1);
}

static void fail_path(const char *operation, const char *path) {
  fprintf(stderr, "cluster_graph: %s '%s': %s\n", operation, path,
          strerror(errno));
  exit(1);
}

static void *checked_malloc(size_t size) {
  void *value = malloc(size == 0 ? 1 : size);
  if (value == NULL) {
    fail("out of memory");
  }
  return value;
}

static void *checked_calloc(size_t count, size_t size) {
  if (size != 0 && count > SIZE_MAX / size) {
    fail("allocation size overflow");
  }
  void *value = calloc(count == 0 ? 1 : count, size);
  if (value == NULL) {
    fail("out of memory");
  }
  return value;
}

static void *checked_realloc(void *old, size_t size) {
  void *value = realloc(old, size == 0 ? 1 : size);
  if (value == NULL) {
    fail("out of memory");
  }
  return value;
}

static char *checked_strdup(const char *text) {
  char *copy = strdup(text);
  if (copy == NULL) {
    fail("out of memory");
  }
  return copy;
}

static void trim_line(char *line) {
  size_t len = strlen(line);
  while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r')) {
    line[--len] = '\0';
  }
}

static size_t split_tabs(char *line, char **fields, size_t capacity) {
  size_t count = 0;
  char *start = line;
  for (char *cursor = line;; cursor++) {
    if (*cursor == '\t' || *cursor == '\0') {
      if (count >= capacity) {
        fail("too many TSV columns");
      }
      fields[count++] = start;
      if (*cursor == '\0') {
        return count;
      }
      *cursor = '\0';
      start = cursor + 1;
    }
  }
}

static uint32_t parse_u32(const char *text, const char *name) {
  char *end = NULL;
  errno = 0;
  unsigned long value = strtoul(text, &end, 10);
  if (errno != 0 || end == text || *end != '\0' || value > UINT32_MAX) {
    fprintf(stderr, "cluster_graph: invalid %s: '%s'\n", name, text);
    exit(1);
  }
  return (uint32_t)value;
}

static uint64_t parse_u64(const char *text, const char *name) {
  char *end = NULL;
  errno = 0;
  unsigned long long value = strtoull(text, &end, 10);
  if (errno != 0 || end == text || *end != '\0') {
    fprintf(stderr, "cluster_graph: invalid %s: '%s'\n", name, text);
    exit(1);
  }
  return (uint64_t)value;
}

static double parse_double(const char *text, const char *name) {
  char *end = NULL;
  errno = 0;
  double value = strtod(text, &end);
  if (errno != 0 || end == text || *end != '\0' || !isfinite(value)) {
    fprintf(stderr, "cluster_graph: invalid %s: '%s'\n", name, text);
    exit(1);
  }
  return value;
}

static void objects_push(Objects *objects, Object object) {
  if (objects->len == objects->cap) {
    objects->cap = objects->cap == 0 ? 64 : objects->cap * 2;
    objects->data = checked_realloc(objects->data,
                                    objects->cap * sizeof(*objects->data));
  }
  objects->data[objects->len++] = object;
}

static Objects objects_read(const char *path) {
  FILE *file = fopen(path, "r");
  if (file == NULL) {
    fail_path("cannot open", path);
  }
  Objects objects = {0};
  char *line = NULL;
  size_t capacity = 0;
  ssize_t size = getline(&line, &capacity, file);
  if (size < 0) {
    fail("empty ids TSV");
  }
  trim_line(line);
  char *header[16];
  size_t header_count = split_tabs(line, header, 16);
  size_t id_column = SIZE_MAX;
  size_t length_column = SIZE_MAX;
  for (size_t index = 0; index < header_count; index++) {
    if (strcmp(header[index], "id") == 0) {
      id_column = index;
    } else if (strcmp(header[index], "seq_len") == 0) {
      length_column = index;
    }
  }
  if (id_column == SIZE_MAX || length_column == SIZE_MAX) {
    fail("ids TSV must contain id and seq_len columns");
  }
  while ((size = getline(&line, &capacity, file)) >= 0) {
    trim_line(line);
    if (line[0] == '\0') {
      continue;
    }
    char *fields[16];
    size_t count = split_tabs(line, fields, 16);
    if (id_column >= count || length_column >= count) {
      fail("short row in ids TSV");
    }
    Object object = {
      .id = checked_strdup(fields[id_column]),
      .length = parse_u64(fields[length_column], "sequence length"),
    };
    objects_push(&objects, object);
  }
  if (ferror(file)) {
    fail_path("cannot read", path);
  }
  free(line);
  fclose(file);
  if (objects.len > UINT32_MAX) {
    fail("more than UINT32_MAX objects are not supported");
  }
  return objects;
}

static void edges_push(Edges *edges, Edge edge) {
  if (edges->len == edges->cap) {
    edges->cap = edges->cap == 0 ? 1024 : edges->cap * 2;
    edges->data = checked_realloc(edges->data,
                                  edges->cap * sizeof(*edges->data));
  }
  edges->data[edges->len++] = edge;
}

static int edge_pair_compare(const void *left_value, const void *right_value) {
  const Edge *left = left_value;
  const Edge *right = right_value;
  if (left->a != right->a) {
    return left->a < right->a ? -1 : 1;
  }
  if (left->b != right->b) {
    return left->b < right->b ? -1 : 1;
  }
  return 0;
}

static Edges edges_read(const char *path, const char *metric,
                        double threshold, size_t object_count) {
  FILE *file = fopen(path, "r");
  if (file == NULL) {
    fail_path("cannot open", path);
  }
  Edges edges = {0};
  char *line = NULL;
  size_t capacity = 0;
  ssize_t size = getline(&line, &capacity, file);
  if (size < 0) {
    fail("empty ANI TSV");
  }
  trim_line(line);
  char *header[64];
  size_t header_count = split_tabs(line, header, 64);
  size_t query_column = SIZE_MAX;
  size_t reference_column = SIZE_MAX;
  size_t metric_column = SIZE_MAX;
  for (size_t index = 0; index < header_count; index++) {
    if (strcmp(header[index], "qidx") == 0) {
      query_column = index;
    } else if (strcmp(header[index], "ridx") == 0) {
      reference_column = index;
    } else if (strcmp(header[index], metric) == 0) {
      metric_column = index;
    }
  }
  if (query_column == SIZE_MAX || reference_column == SIZE_MAX ||
      metric_column == SIZE_MAX) {
    fail("ANI TSV is missing qidx, ridx, or the selected metric column");
  }
  while ((size = getline(&line, &capacity, file)) >= 0) {
    trim_line(line);
    if (line[0] == '\0') {
      continue;
    }
    char *fields[64];
    size_t count = split_tabs(line, fields, 64);
    if (query_column >= count || reference_column >= count ||
        metric_column >= count) {
      fail("short row in ANI TSV");
    }
    uint32_t a = parse_u32(fields[query_column], "qidx");
    uint32_t b = parse_u32(fields[reference_column], "ridx");
    double score = parse_double(fields[metric_column], metric);
    if ((size_t)a >= object_count || (size_t)b >= object_count) {
      fail("ANI row references an object outside the ids TSV");
    }
    if (a == b || score + 1e-12 < threshold) {
      continue;
    }
    if (b < a) {
      uint32_t swap = a;
      a = b;
      b = swap;
    }
    edges_push(&edges, (Edge){.a = a, .b = b, .score = score});
  }
  if (ferror(file)) {
    fail_path("cannot read", path);
  }
  free(line);
  fclose(file);

  qsort(edges.data, edges.len, sizeof(*edges.data), edge_pair_compare);
  size_t write = 0;
  for (size_t read = 0; read < edges.len; read++) {
    if (write > 0 && edges.data[write - 1].a == edges.data[read].a &&
        edges.data[write - 1].b == edges.data[read].b) {
      if (edges.data[read].score > edges.data[write - 1].score) {
        edges.data[write - 1].score = edges.data[read].score;
      }
    } else {
      edges.data[write++] = edges.data[read];
    }
  }
  edges.len = write;
  return edges;
}

static int adjacency_compare(const void *left_value, const void *right_value) {
  const Adj *left = left_value;
  const Adj *right = right_value;
  if (left->node == right->node) {
    return 0;
  }
  return left->node < right->node ? -1 : 1;
}

static Graph graph_build(size_t count, Edges edges) {
  Graph graph = {
    .count = count,
    .edge_count = edges.len,
    .offset = checked_calloc(count + 1, sizeof(*graph.offset)),
    .adj = NULL,
    .edges = edges.data,
  };
  for (size_t index = 0; index < edges.len; index++) {
    graph.offset[edges.data[index].a + 1]++;
    graph.offset[edges.data[index].b + 1]++;
  }
  for (size_t index = 1; index <= count; index++) {
    graph.offset[index] += graph.offset[index - 1];
  }
  if (edges.len > SIZE_MAX / (2 * sizeof(*graph.adj))) {
    fail("adjacency size overflow");
  }
  graph.adj = checked_malloc(edges.len * 2 * sizeof(*graph.adj));
  size_t *cursor = checked_malloc(count * sizeof(*cursor));
  memcpy(cursor, graph.offset, count * sizeof(*cursor));
  for (size_t index = 0; index < edges.len; index++) {
    Edge edge = edges.data[index];
    graph.adj[cursor[edge.a]++] = (Adj){edge.b, edge.score};
    graph.adj[cursor[edge.b]++] = (Adj){edge.a, edge.score};
  }
  free(cursor);
  for (size_t node = 0; node < count; node++) {
    qsort(graph.adj + graph.offset[node],
          graph.offset[node + 1] - graph.offset[node],
          sizeof(*graph.adj), adjacency_compare);
  }
  return graph;
}

static int graph_score(const Graph *graph, uint32_t a, uint32_t b,
                       double *score) {
  if (a == b) {
    *score = 1.0;
    return 1;
  }
  size_t low = graph->offset[a];
  size_t high = graph->offset[a + 1];
  while (low < high) {
    size_t middle = low + (high - low) / 2;
    uint32_t node = graph->adj[middle].node;
    if (node < b) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  if (low < graph->offset[a + 1] && graph->adj[low].node == b) {
    *score = graph->adj[low].score;
    return 1;
  }
  return 0;
}

static uint32_t dsu_find(uint32_t *parent, uint32_t value) {
  uint32_t root = value;
  while (parent[root] != root) {
    root = parent[root];
  }
  while (parent[value] != value) {
    uint32_t next = parent[value];
    parent[value] = root;
    value = next;
  }
  return root;
}

static uint32_t *dsu_new(size_t count) {
  uint32_t *parent = checked_malloc(count * sizeof(*parent));
  for (size_t index = 0; index < count; index++) {
    parent[index] = (uint32_t)index;
  }
  return parent;
}

static void dsu_union(uint32_t *parent, uint32_t *size, uint32_t a,
                      uint32_t b) {
  a = dsu_find(parent, a);
  b = dsu_find(parent, b);
  if (a == b) {
    return;
  }
  if (size[a] < size[b] || (size[a] == size[b] && b < a)) {
    uint32_t swap = a;
    a = b;
    b = swap;
  }
  parent[b] = a;
  size[a] += size[b];
}

static uint32_t *cluster_single(const Graph *graph) {
  uint32_t *parent = dsu_new(graph->count);
  uint32_t *size = checked_malloc(graph->count * sizeof(*size));
  for (size_t node = 0; node < graph->count; node++) {
    size[node] = 1;
  }
  for (size_t index = 0; index < graph->edge_count; index++) {
    dsu_union(parent, size, graph->edges[index].a, graph->edges[index].b);
  }
  free(size);
  for (size_t node = 0; node < graph->count; node++) {
    parent[node] = dsu_find(parent, (uint32_t)node);
  }
  return parent;
}

static void members_push(Members *members, uint32_t value) {
  if (members->len == members->cap) {
    members->cap = members->cap == 0 ? 2 : members->cap * 2;
    members->data = checked_realloc(members->data,
                                    members->cap * sizeof(*members->data));
  }
  members->data[members->len++] = value;
}

static int complete_similarity(const Graph *graph, const Members *left,
                               const Members *right, double *similarity) {
  double minimum = 1.0;
  for (size_t a = 0; a < left->len; a++) {
    for (size_t b = 0; b < right->len; b++) {
      double score = 0.0;
      if (!graph_score(graph, left->data[a], right->data[b], &score)) {
        return 0;
      }
      if (score < minimum) {
        minimum = score;
      }
    }
  }
  *similarity = minimum;
  return 1;
}

static uint32_t *cluster_complete(const Graph *graph) {
  if (graph->count > (size_t)UINT32_MAX / 2 + 1) {
    fail("too many objects for complete linkage");
  }
  size_t capacity = graph->count == 0 ? 1 : graph->count * 2 - 1;
  Members *members = checked_calloc(capacity, sizeof(*members));
  uint32_t *node_cluster = checked_malloc(graph->count * sizeof(*node_cluster));
  for (size_t node = 0; node < graph->count; node++) {
    members_push(&members[node], (uint32_t)node);
    node_cluster[node] = (uint32_t)node;
  }
  uint32_t next_cluster = (uint32_t)graph->count;
  while ((size_t)next_cluster < capacity) {
    uint32_t best_left = UINT32_MAX;
    uint32_t best_right = UINT32_MAX;
    double best_similarity = -1.0;
    for (size_t edge = 0; edge < graph->edge_count; edge++) {
      uint32_t left = node_cluster[graph->edges[edge].a];
      uint32_t right = node_cluster[graph->edges[edge].b];
      if (left == right) {
        continue;
      }
      if (right < left) {
        uint32_t swap = left;
        left = right;
        right = swap;
      }
      double similarity = 0.0;
      if (!complete_similarity(graph, &members[left], &members[right],
                               &similarity)) {
        continue;
      }
      if (similarity > best_similarity + 1e-12 ||
          (fabs(similarity - best_similarity) <= 1e-12 &&
           (left < best_left || (left == best_left && right < best_right)))) {
        best_left = left;
        best_right = right;
        best_similarity = similarity;
      }
    }
    if (best_left == UINT32_MAX) {
      break;
    }
    Members *merged = &members[next_cluster];
    for (size_t index = 0; index < members[best_left].len; index++) {
      uint32_t node = members[best_left].data[index];
      members_push(merged, node);
      node_cluster[node] = next_cluster;
    }
    for (size_t index = 0; index < members[best_right].len; index++) {
      uint32_t node = members[best_right].data[index];
      members_push(merged, node);
      node_cluster[node] = next_cluster;
    }
    next_cluster++;
  }
  for (size_t cluster = 0; cluster < capacity; cluster++) {
    free(members[cluster].data);
  }
  free(members);
  return node_cluster;
}

static const Objects *sort_objects_context;

static int object_length_desc(const void *left_value, const void *right_value) {
  uint32_t left = *(const uint32_t *)left_value;
  uint32_t right = *(const uint32_t *)right_value;
  uint64_t left_length = sort_objects_context->data[left].length;
  uint64_t right_length = sort_objects_context->data[right].length;
  if (left_length != right_length) {
    return left_length > right_length ? -1 : 1;
  }
  return left < right ? -1 : left != right;
}

static uint32_t *length_order(const Objects *objects) {
  uint32_t *order = checked_malloc(objects->len * sizeof(*order));
  for (size_t index = 0; index < objects->len; index++) {
    order[index] = (uint32_t)index;
  }
  sort_objects_context = objects;
  qsort(order, objects->len, sizeof(*order), object_length_desc);
  return order;
}

static uint32_t *cluster_centroids(const Graph *graph, const Objects *objects,
                                   int choose_best) {
  uint32_t *assignment = checked_malloc(graph->count * sizeof(*assignment));
  uint32_t *representatives = checked_malloc(graph->count * sizeof(*representatives));
  uint32_t *order = length_order(objects);
  size_t representative_count = 0;

  for (size_t position = 0; position < graph->count; position++) {
    uint32_t node = order[position];
    uint32_t selected = UINT32_MAX;
    double selected_score = -1.0;
    for (size_t index = 0; index < representative_count; index++) {
      double score = 0.0;
      if (!graph_score(graph, node, representatives[index], &score)) {
        continue;
      }
      if (!choose_best) {
        selected = representatives[index];
        break;
      }
      if (score > selected_score + 1e-12) {
        selected = representatives[index];
        selected_score = score;
      }
    }
    if (selected == UINT32_MAX) {
      selected = node;
      representatives[representative_count++] = node;
    }
    assignment[node] = selected;
  }
  free(order);
  free(representatives);
  return assignment;
}

static int degree_order_compare(const void *left_value, const void *right_value) {
  const DegreeOrder *left = left_value;
  const DegreeOrder *right = right_value;
  if (left->degree != right->degree) {
    return left->degree > right->degree ? -1 : 1;
  }
  return left->node < right->node ? -1 : left->node != right->node;
}

static uint32_t *cluster_set_cover(const Graph *graph) {
  uint32_t *assignment = checked_malloc(graph->count * sizeof(*assignment));
  DegreeOrder *order = checked_malloc(graph->count * sizeof(*order));
  for (size_t node = 0; node < graph->count; node++) {
    assignment[node] = UINT32_MAX;
    order[node] = (DegreeOrder){
      .node = (uint32_t)node,
      .degree = graph->offset[node + 1] - graph->offset[node],
    };
  }
  qsort(order, graph->count, sizeof(*order), degree_order_compare);
  for (size_t position = 0; position < graph->count; position++) {
    uint32_t seed = order[position].node;
    if (assignment[seed] != UINT32_MAX) {
      continue;
    }
    assignment[seed] = seed;
    for (size_t edge = graph->offset[seed]; edge < graph->offset[seed + 1];
         edge++) {
      uint32_t neighbor = graph->adj[edge].node;
      if (assignment[neighbor] == UINT32_MAX) {
        assignment[neighbor] = seed;
      }
    }
  }
  free(order);
  return assignment;
}

static uint32_t random_step(uint32_t *state) {
  uint32_t value = *state;
  value ^= value << 13;
  value ^= value >> 17;
  value ^= value << 5;
  *state = value == 0 ? 0x9e3779b9u : value;
  return *state;
}

static double weight_to_community(const Graph *graph, const uint32_t *community,
                                  uint32_t node, uint32_t target) {
  double weight = 0.0;
  for (size_t edge = graph->offset[node]; edge < graph->offset[node + 1];
       edge++) {
    if (community[graph->adj[edge].node] == target) {
      weight += graph->adj[edge].score;
    }
  }
  return weight;
}

static void leiden_refine_connected(const Graph *graph, uint32_t *community) {
  unsigned char *seen = checked_calloc(graph->count, 1);
  uint32_t *queue = checked_malloc(graph->count * sizeof(*queue));
  uint32_t *refined = checked_malloc(graph->count * sizeof(*refined));
  uint32_t next = 0;
  for (size_t start = 0; start < graph->count; start++) {
    if (seen[start]) {
      continue;
    }
    uint32_t original = community[start];
    size_t head = 0;
    size_t tail = 0;
    queue[tail++] = (uint32_t)start;
    seen[start] = 1;
    while (head < tail) {
      uint32_t node = queue[head++];
      refined[node] = next;
      for (size_t edge = graph->offset[node]; edge < graph->offset[node + 1];
           edge++) {
        uint32_t neighbor = graph->adj[edge].node;
        if (!seen[neighbor] && community[neighbor] == original) {
          seen[neighbor] = 1;
          queue[tail++] = neighbor;
        }
      }
    }
    next++;
  }
  memcpy(community, refined, graph->count * sizeof(*community));
  free(refined);
  free(queue);
  free(seen);
}

static uint32_t *cluster_leiden(const Graph *graph, double resolution,
                                uint32_t passes, uint32_t seed) {
  uint32_t *community = checked_malloc(graph->count * sizeof(*community));
  uint32_t *sizes = checked_malloc(graph->count * sizeof(*sizes));
  uint32_t *order = checked_malloc(graph->count * sizeof(*order));
  for (size_t node = 0; node < graph->count; node++) {
    community[node] = (uint32_t)node;
    sizes[node] = 1;
    order[node] = (uint32_t)node;
  }
  uint32_t state = seed == 0 ? 1 : seed;
  for (uint32_t pass = 0; pass < passes; pass++) {
    for (size_t index = graph->count; index > 1; index--) {
      size_t swap = random_step(&state) % index;
      uint32_t value = order[index - 1];
      order[index - 1] = order[swap];
      order[swap] = value;
    }
    int changed = 0;
    for (size_t position = 0; position < graph->count; position++) {
      uint32_t node = order[position];
      uint32_t old = community[node];
      double old_weight = weight_to_community(graph, community, node, old);
      double old_term = old_weight - resolution * (sizes[old] - 1);
      uint32_t best = old;
      double best_gain = 1e-12;
      for (size_t edge = graph->offset[node]; edge < graph->offset[node + 1];
           edge++) {
        uint32_t candidate = community[graph->adj[edge].node];
        if (candidate == old) {
          continue;
        }
        int repeated = 0;
        for (size_t prior = graph->offset[node]; prior < edge; prior++) {
          if (community[graph->adj[prior].node] == candidate) {
            repeated = 1;
            break;
          }
        }
        if (repeated) {
          continue;
        }
        double new_weight = weight_to_community(graph, community, node,
                                                candidate);
        double gain = new_weight - resolution * sizes[candidate] - old_term;
        if (gain > best_gain ||
            (fabs(gain - best_gain) <= 1e-12 && candidate < best)) {
          best = candidate;
          best_gain = gain;
        }
      }
      if (best != old) {
        sizes[old]--;
        sizes[best]++;
        community[node] = best;
        changed = 1;
      }
    }
    leiden_refine_connected(graph, community);
    memset(sizes, 0, graph->count * sizeof(*sizes));
    for (size_t node = 0; node < graph->count; node++) {
      sizes[community[node]]++;
    }
    if (!changed) {
      break;
    }
  }
  free(order);
  free(sizes);
  return community;
}

static size_t normalize_labels(uint32_t *labels, size_t count) {
  size_t limit = count == 0 ? 1 : count * 2;
  uint32_t *normalized = checked_malloc(limit * sizeof(*normalized));
  for (size_t index = 0; index < limit; index++) {
    normalized[index] = UINT32_MAX;
  }
  uint32_t next = 0;
  for (size_t node = 0; node < count; node++) {
    uint32_t key = labels[node];
    if ((size_t)key >= limit) {
      fail("internal cluster label is out of range");
    }
    if (normalized[key] == UINT32_MAX) {
      normalized[key] = next++;
    }
    labels[node] = normalized[key];
  }
  free(normalized);
  return next;
}

static void clusters_write(const char *path, const Objects *objects,
                           const uint32_t *labels) {
  FILE *file = fopen(path, "w");
  if (file == NULL) {
    fail_path("cannot create", path);
  }
  if (fprintf(file, "object\tcluster\n") < 0) {
    fail_path("cannot write", path);
  }
  for (size_t index = 0; index < objects->len; index++) {
    if (fprintf(file, "%s\t%" PRIu32 "\n", objects->data[index].id,
                labels[index]) < 0) {
      fail_path("cannot write", path);
    }
  }
  if (fclose(file) != 0) {
    fail_path("cannot close", path);
  }
}

static const char *algorithm_name(Algorithm algorithm) {
  switch (algorithm) {
    case ALG_SINGLE: return "single";
    case ALG_COMPLETE: return "complete";
    case ALG_UCLUST: return "uclust";
    case ALG_CDHIT: return "cd-hit";
    case ALG_SET_COVER: return "set-cover";
    case ALG_LEIDEN: return "leiden";
  }
  return "unknown";
}

static Algorithm algorithm_parse(const char *name) {
  if (strcmp(name, "single") == 0) return ALG_SINGLE;
  if (strcmp(name, "complete") == 0) return ALG_COMPLETE;
  if (strcmp(name, "uclust") == 0) return ALG_UCLUST;
  if (strcmp(name, "cd-hit") == 0) return ALG_CDHIT;
  if (strcmp(name, "set-cover") == 0) return ALG_SET_COVER;
  if (strcmp(name, "leiden") == 0) return ALG_LEIDEN;
  fail("unknown algorithm");
  return ALG_SINGLE;
}

static void usage(FILE *file) {
  fprintf(file,
    "usage: cluster_graph --input ANI.tsv --ids ANI.ids.tsv --output OUT.tsv\n"
    "                     --algorithm NAME [--metric ani|tani|gani]\n"
    "                     [--threshold 0.95] [--threads N]\n"
    "                     [--resolution 0.7] [--passes 20] [--seed 42]\n");
}

static Options options_parse(int argc, char **argv) {
  Options options = {
    .metric = "ani",
    .algorithm = ALG_SINGLE,
    .threshold = 0.95,
    .resolution = 0.7,
    .seed = 42,
    .passes = 20,
    .threads = 1,
  };
  for (int index = 1; index < argc; index++) {
    const char *name = argv[index];
    if (strcmp(name, "--help") == 0 || strcmp(name, "-h") == 0) {
      usage(stdout);
      exit(0);
    }
    if (index + 1 >= argc) {
      fail("missing option value");
    }
    const char *value = argv[++index];
    if (strcmp(name, "--input") == 0) {
      options.input = value;
    } else if (strcmp(name, "--ids") == 0) {
      options.ids = value;
    } else if (strcmp(name, "--output") == 0) {
      options.output = value;
    } else if (strcmp(name, "--algorithm") == 0) {
      options.algorithm = algorithm_parse(value);
    } else if (strcmp(name, "--metric") == 0) {
      if (strcmp(value, "ani") != 0 && strcmp(value, "tani") != 0 &&
          strcmp(value, "gani") != 0) {
        fail("metric must be ani, tani, or gani");
      }
      options.metric = value;
    } else if (strcmp(name, "--threshold") == 0) {
      options.threshold = parse_double(value, "threshold");
    } else if (strcmp(name, "--resolution") == 0) {
      options.resolution = parse_double(value, "resolution");
    } else if (strcmp(name, "--passes") == 0) {
      options.passes = parse_u32(value, "passes");
    } else if (strcmp(name, "--seed") == 0) {
      options.seed = parse_u32(value, "seed");
    } else if (strcmp(name, "--threads") == 0) {
      options.threads = parse_u32(value, "threads");
    } else {
      fprintf(stderr, "cluster_graph: unknown option '%s'\n", name);
      exit(1);
    }
  }
  if (options.input == NULL || options.ids == NULL || options.output == NULL) {
    usage(stderr);
    fail("--input, --ids, and --output are required");
  }
  if (options.threshold < 0.0 || options.threshold > 1.0) {
    fail("threshold must be in 0..1");
  }
  if (options.resolution < 0.0 || options.passes == 0 || options.threads == 0) {
    fail("resolution must be nonnegative; passes and threads must be positive");
  }
  return options;
}

int main(int argc, char **argv) {
  Options options = options_parse(argc, argv);
  Objects objects = objects_read(options.ids);
  Edges edges = edges_read(options.input, options.metric, options.threshold,
                           objects.len);
  Graph graph = graph_build(objects.len, edges);
  uint32_t *labels = NULL;
  switch (options.algorithm) {
    case ALG_SINGLE:
      labels = cluster_single(&graph);
      break;
    case ALG_COMPLETE:
      labels = cluster_complete(&graph);
      break;
    case ALG_UCLUST:
      labels = cluster_centroids(&graph, &objects, 1);
      break;
    case ALG_CDHIT:
      labels = cluster_centroids(&graph, &objects, 0);
      break;
    case ALG_SET_COVER:
      labels = cluster_set_cover(&graph);
      break;
    case ALG_LEIDEN:
      labels = cluster_leiden(&graph, options.resolution, options.passes,
                              options.seed);
      break;
  }
  size_t clusters = normalize_labels(labels, objects.len);
  clusters_write(options.output, &objects, labels);
  fprintf(stderr,
          "algorithm=%s objects=%zu edges=%zu clusters=%zu "
          "requested_threads=%" PRIu32 " effective_threads=1\n",
          algorithm_name(options.algorithm), objects.len, graph.edge_count,
          clusters, options.threads);

  free(labels);
  free(graph.edges);
  free(graph.adj);
  free(graph.offset);
  for (size_t index = 0; index < objects.len; index++) {
    free(objects.data[index].id);
  }
  free(objects.data);
  return 0;
}
