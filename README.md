# Distributed-Graph-Analytics
A high-performance parallel graph analytics engine designed for large-scale network processing. This project implements fundamental graph algorithms using C++ and MPI, focusing on distributed memory architectures and efficient data representation.

## Correctness Test

## Small Graph PageRank Benchmark

A small directed graph with 6 vertices and 9 edges is generated under `data/small_graph`.

PageRank correctness is verified by comparing the total PageRank sum across different process counts.

Triangle counting correctness is verified by comparing the total and unique triangle counts.

| Algorithm | Processes | Result | Runtime |
|---|---:|---:|---:|
| PageRank | 1 | Sum = 6.000000 | 0.000046s |
| PageRank | 4 | Sum = 6.000000 | 0.000146s |
| Triangle Counting | 1 | Unique triangles = 2 | 0.000041s |
| Triangle Counting | 4 | Unique triangles = 2 | 0.000108s |

## Medium Graph PageRank Benchmark

Dataset:
- 10,000 vertices
- 120,000 directed edges
- 20 PageRank iterations

| Processes | Runtime | Approx. Speedup | Notes |
|---|---:|---:|---|
| 1 | 0.002408s | 1.00× | Baseline |
| 2 | 0.001704s | 1.41× | Best result on this dataset |
| 4 | 0.003216s | 0.75× | Slower due to MPI communication overhead |

The edge-aware partitioning strategy distributed work evenly across processes. With 4 processes, each rank processed approximately 600k edge operations over 20 iterations.

For this medium graph, 2 processes improved runtime, while 4 processes introduced enough synchronization and communication overhead to outweigh the benefit of parallelism.