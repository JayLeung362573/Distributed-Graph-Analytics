# Performance Analysis

This document explains the benchmark results for the distributed PageRank and Triangle Counting implementations.

## Goal

The goal of this benchmark is to measure when MPI-based parallelism improves runtime and when communication overhead dominates.

This project does not assume that more processes always make the program faster. Instead, it compares different process counts and analyzes the tradeoff between computation and communication.

## Benchmark Variables

The main variables are:

- Graph size
- Number of vertices
- Number of edges
- Number of MPI processes
- Number of PageRank iterations
- Communication strategy
- Per-rank edge workload
- Per-rank communication time

## Small Graph Result

The small graph has only 6 vertices and 9 edges.

On this graph, 4 MPI processes are slower than 1 process.

This is expected because each process receives very little computation. The overhead of starting MPI processes, synchronizing ranks, and communicating partial results is larger than the computation saved by parallel execution.

## Medium Graph Benchmark Results

Dataset:

- 10,000 vertices
- 120,000 directed edges
- 20 PageRank iterations

### PageRank

| Processes | Runtime | Result |
|---:|---:|---:|
| 1 | 0.002027s | Sum = 9999.979492 |
| 2 | 0.008469s | Sum = 10000.008789 |
| 4 | 0.012153s | Sum = 9999.993164 |

For this medium graph, PageRank becomes slower as more MPI processes are added. This suggests that the communication cost of combining PageRank contributions dominates the computation saved by distributing the vertices.

The PageRank sums are close to the number of vertices, with small differences caused by floating-point accumulation order across MPI processes.

### Triangle Counting

| Processes | Runtime | Result |
|---:|---:|---:|
| 1 | 0.013904s | Unique triangles = 581 |
| 2 | 0.006126s | Unique triangles = 581 |
| 4 | 0.003344s | Unique triangles = 581 |

Triangle Counting scales better on this graph. Unlike PageRank, it performs more local computation before the final reduction, so the communication overhead is smaller relative to the amount of work being distributed.

## Interpretation

The benchmark shows that MPI scalability depends on the algorithm.

PageRank requires repeated communication across iterations, so it is more sensitive to communication overhead. Triangle Counting performs heavier local edge-neighborhood computation and only needs to combine counts at the end, so it benefits more from parallel execution on this graph.


## Why More Processes Can Be Slower

Adding more MPI processes introduces costs:

- More ranks need to synchronize.
- Partial PageRank values need to be communicated.
- Each rank performs less computation.
- Communication becomes a larger percentage of total runtime.
- Small and medium graphs may not provide enough work to amortize MPI overhead.

This means that parallel performance depends on the ratio between computation and communication.

## Edge-Aware Partitioning

The implementation partitions vertices based on outgoing edge counts rather than simply assigning the same number of vertices to each rank.

This is useful because graph workloads are often skewed. Some vertices may have many more edges than others.

Assigning equal vertex counts can create load imbalance. Edge-aware partitioning attempts to give each process a similar amount of edge-processing work.

## Current Interpretation

The current benchmark suggests:

- Small graph: single-process execution is faster.
- Medium graph: 2 processes provide useful speedup.
- Medium graph with 4 processes: MPI overhead dominates.

This result does not mean the MPI implementation is ineffective. It means the current graphs are not large enough to consistently benefit from higher process counts.

## Next Benchmark Target

A stronger benchmark should include larger graphs, such as:

- 100k vertices / 1M edges
- 1M vertices / 5M+ edges, if the machine can handle it

Larger graphs should increase computation per rank and make MPI overhead easier to amortize.