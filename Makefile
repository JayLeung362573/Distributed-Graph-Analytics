MPICXX ?= mpic++
CXXFLAGS ?= -O3 -std=c++17 -Wall -Wextra
CPPFLAGS ?= -I.

.PHONY: all clean

all: page_rank_parallel triangle_counting_parallel

page_rank_parallel: src/page_rank_parallel.cpp core/*.h
	$(MPICXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ src/page_rank_parallel.cpp

triangle_counting_parallel: src/triangle_counting_parallel.cpp core/*.h
	$(MPICXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ src/triangle_counting_parallel.cpp

clean:
	rm -f page_rank_parallel triangle_counting_parallel
