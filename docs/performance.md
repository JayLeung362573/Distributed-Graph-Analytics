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

## Medium Graph Result

The medium graph has:

- 10,000 vertices
- 120,000 directed edges
- 20 PageRank iterations

The 2-process run achieved the best runtime in the current benchmark.

The 4-process run was slower because the extra communication and synchronization overhead outweighed the additional parallelism.

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