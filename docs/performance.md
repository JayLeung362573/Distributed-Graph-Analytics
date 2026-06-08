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
- Each process count was run 3 times because millisecond-level MPI benchmarks can vary between runs.

### PageRank

| Processes | Run 1 | Run 2 | Run 3 | Result |
|---:|---:|---:|---:|---:|
| 1 | 0.002011s | 0.001969s | 0.002046s | Sum = 9999.979492 |
| 2 | 0.001795s | 0.001477s | 0.001409s | Sum = 10000.008789 |
| 4 | 0.001452s | 0.001577s | 0.001597s | Sum = 9999.993164 |

PageRank shows small runtime differences on this medium graph. Because all measurements are around 1–2 milliseconds, the result is sensitive to measurement noise and runtime scheduling. The PageRank sums remain close to the number of vertices, with small differences caused by floating-point accumulation order across MPI processes.

### Triangle Counting

| Processes | Run 1 | Run 2 | Run 3 | Result |
|---:|---:|---:|---:|---:|
| 1 | 0.011759s | 0.011591s | 0.011589s | Unique triangles = 581 |
| 2 | 0.005820s | 0.005938s | 0.005784s | Unique triangles = 581 |
| 4 | 0.003190s | 0.002958s | 0.002979s | Unique triangles = 581 |

Triangle Counting scales more clearly on this graph. The 4-process run is consistently faster than the 1-process run because the algorithm performs more local edge-neighborhood computation before combining counts.

## Interpretation

The benchmark shows that MPI scalability depends on the algorithm and the computation-to-communication ratio.

PageRank requires repeated communication across iterations, and the measured runtimes are very small on the current medium graph. This makes the benchmark sensitive to timing noise. Triangle Counting performs heavier local computation and only needs to combine counts at the end, so it benefits more clearly from parallel execution on this graph.

This is an important result: the project does not simply claim that MPI is always faster. It measures when distributed execution helps, when communication overhead matters, and when the benchmark is too small to make strong scaling claims.


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