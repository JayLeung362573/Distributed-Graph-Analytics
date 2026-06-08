MPICXX ?= mpic++
CXXFLAGS ?= -O3 -std=c++17 -Wall -Wextra
CPPFLAGS ?= -I.

.PHONY: all clean test benchmark benchmark-large generate-large

all: page_rank_parallel triangle_counting_parallel

page_rank_parallel: src/page_rank_parallel.cpp core/*.h
	$(MPICXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ src/page_rank_parallel.cpp

triangle_counting_parallel: src/triangle_counting_parallel.cpp core/*.h
	$(MPICXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ src/triangle_counting_parallel.cpp

test: all
	./tests/run_correctness.sh

benchmark: all
	./tests/run_benchmark.sh

generate-large:
	python3 scripts/generate_large_graph.py

benchmark-large: all
	./tests/run_benchmark.sh data/large_graph

clean:
	rm -f page_rank_parallel triangle_counting_parallel
