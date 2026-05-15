# Distributed-Graph-Analytics
A high-performance parallel graph analytics engine designed for large-scale network processing. This project implements fundamental graph algorithms using C++ and MPI, focusing on distributed memory architectures and efficient data representation.

## Correctness Test

A small directed graph with 6 vertices and 9 edges is generated under `data/small_graph`.

PageRank correctness is verified by comparing the total PageRank sum across different process counts.

Triangle counting correctness is verified by comparing the total and unique triangle counts.

| Algorithm | Processes | Result | Runtime |
|---|---:|---:|---:|
| PageRank | 1 | Sum = 6.000000 | 0.000046s |
| PageRank | 4 | Sum = 6.000000 | 0.000146s |
| Triangle Counting | 1 | Unique triangles = 2 | 0.000041s |
| Triangle Counting | 4 | Unique triangles = 2 | 0.000108s |