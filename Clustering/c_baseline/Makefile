CC ?= clang
CFLAGS ?= -O3 -std=c11 -Wall -Wextra -Wpedantic
LDFLAGS ?=

.PHONY: all clean test

all: cluster_graph

cluster_graph: cluster_graph.c
	$(CC) $(CFLAGS) $< -o $@ $(LDFLAGS) -lm

test: cluster_graph
	python3 tests/test_cluster_graph.py

clean:
	rm -f cluster_graph
