# Distributed Graph Analytics

![CI](https://github.com/JayLeung362573/Distributed-Graph-Analytics/actions/workflows/ci.yml/badge.svg)

A benchmark-driven C++17 and MPI graph analytics engine implementing
distributed PageRank and Triangle Counting. The project supports
selectable edge-aware and equal-vertex partitioning, multiple MPI
communication strategies, correctness validation across process counts,
and reproducible Docker-based benchmarks.

The evaluation measures both runtime scaling and per-rank workload
balance. Results show that Triangle Counting benefits more consistently
from additional MPI processes, while iterative PageRank is more
sensitive to communication overhead. On a deliberately degree-skewed
graph, edge-aware partitioning reduces the measured maximum-to-minimum
edge workload ratio from 20.60x to 1.00x.

## Benchmark Snapshot

The table below summarizes the median runtime from three benchmark runs. Speedup is calculated relative to the single-process runtime for the same graph and algorithm.

| Dataset | Algorithm | 1 Process | Best Parallel Run | Speedup | Main Observation |
|---|---|---:|---:|---:|---|
| Medium: 10k vertices, 120k edges | PageRank | 2.011 ms | 1.477 ms with 2 processes | 1.36x | Modest improvement; repeated communication limits scaling |
| Medium: 10k vertices, 120k edges | Triangle Counting | 11.591 ms | 2.979 ms with 4 processes | 3.89x | Clear scaling from heavier local computation |
| Large: 100k vertices, 1M edges | PageRank | 21.349 ms | 12.836 ms with 2 processes | 1.66x | Two processes help, while four-process runs are more variable |
| Large: 100k vertices, 1M edges | Triangle Counting | 99.736 ms | 34.784 ms with 4 processes | 2.87x | Consistent scaling across increasing process counts |

These results show that scalability depends on the algorithm's computation-to-communication ratio. Triangle Counting benefits more consistently from additional MPI processes, while iterative PageRank is more sensitive to communication and synchronization overhead.

![Large-graph MPI runtime scaling](docs/images/large_graph_runtime_scaling.png)

The chart reports the median runtime from three runs on the
100k-vertex, 1M-edge graph. Triangle Counting scales consistently
from 1 to 4 processes, while PageRank performs best with 2 processes
and becomes more variable at 4 processes because it requires repeated
communication during every iteration.

### Partitioning Snapshot

A separate benchmark compares edge-aware and equal-vertex partitioning
on a deliberately degree-skewed synthetic graph with 10,000 vertices,
118,000 directed edges, and 4 MPI processes.

| Partition Strategy | Rank Workloads | Maximum / Average | Maximum / Minimum |
|---|---|---:|---:|
| Edge-aware | 29,500 / 29,500 / 29,500 / 29,500 | 1.00x | 1.00x |
| Equal-vertex | 103,000 / 5,000 / 5,000 / 5,000 | 3.49x | 20.60x |

![Partition workload balance](docs/images/partition_workload_balance.png)

On this constructed dataset, equal vertex counts do not produce equal
computational work because the high-degree vertices are concentrated at
the beginning of the vertex range. Edge-aware partitioning instead
assigns each rank the same number of outgoing edges.

This benchmark demonstrates improved workload balance rather than a
20.60x runtime speedup. End-to-end runtime also depends on MPI
communication, synchronization, memory access, and algorithm-specific
processing costs.

Detailed measurements and interpretation are available in [docs/performance.md](docs/performance.md).

## Features

- Distributed PageRank and Triangle Counting implemented in C++17 with MPI
- Selectable edge-aware and equal-vertex graph partitioning
- Shared partitioning utilities used by both distributed algorithms
- Multiple MPI communication strategies for combining partial results
- Numeric correctness tests across 1 and 4 MPI processes
- Correctness validation for both partitioning strategies
- Runtime benchmarks across 1, 2, and 4 MPI processes
- Degree-skewed workload benchmark with per-rank edge measurements
- Reproducible graph generators, CSV results, and visualization scripts
- Docker-based OpenMPI build, test, and benchmark environment
- GitHub Actions continuous integration

## Repository Structure

```text
.
├── core/                         # Graph data structures and shared utilities
├── data/                         # Small and medium benchmark graph inputs
├── src/
│   ├── page_rank_parallel.cpp     # MPI PageRank implementation
│   └── triangle_counting_parallel.cpp
├── Dockerfile                     # Ubuntu + OpenMPI build environment
├── Makefile                       # Builds both MPI executables
└── README.md
```

## Algorithms

### PageRank

PageRank is computed iteratively. Each MPI rank owns a contiguous range of vertices, selected using an edge-aware partitioning method so that each process receives a similar amount of outgoing-edge work.

During each iteration:

1. Each rank processes the outgoing edges for its assigned vertices.
2. Local PageRank contributions are accumulated.
3. MPI communication combines partial contributions across processes.
4. Each rank updates the PageRank values for its local vertex block.

The implementation reports each rank's processed edge count and communication time, then rank 0 reports the final PageRank sum and total runtime.

### Triangle Counting

Triangle Counting also uses edge-aware vertex partitioning. Each rank counts triangles involving the vertices in its local range, then the local counts are combined with MPI communication. The final unique triangle count is reported by rank 0.

## Graph Input Format

The programs currently read graph input through the shared `Graph::readGraphFromBinary<int>()` loader. In other words, the input path passed to `--inputFile` should point to a graph file or graph directory in the binary format expected by the project’s `core/graph.h` implementation.

Example input paths used in this project:

```bash
data/small_graph
data/medium_graph
```

## Build and Run

Requirements:

- C++17 compiler
- OpenMPI
- `make`

Build both MPI executables:

```bash
make
```

This produces:

```text
page_rank_parallel
triangle_counting_parallel
```

Run correctness tests:

```bash
make test
```

Run the default medium-graph benchmark:

```bash
make benchmark
```

Generate the large benchmark graph locally:

```bash
make generate-large
```

Run the large-graph benchmark:

```bash
make benchmark-large
```

Clean build outputs:

```bash
make clean
```

## Manual Execution

You can also run each algorithm manually with `mpirun`.

Run PageRank:

```bash
mpirun -np 4 ./page_rank_parallel --inputFile data/small_graph --nIterations 20 --strategy 2
```

Run Triangle Counting:

```bash
mpirun -np 4 ./triangle_counting_parallel --inputFile data/small_graph --strategy 2
```

Useful arguments:

| Argument | Used By | Meaning |
|---|---|---|
| `--inputFile` | PageRank, Triangle Counting | Path to the binary graph input |
| `--strategy` | PageRank, Triangle Counting | MPI communication strategy |
| `--nIterations` | PageRank | Number of PageRank iterations |

## Run with Docker

Build the Docker image:

```bash
docker build -t distributed-graph-analytics .
```

Open a shell inside the container:

```bash
docker run --rm -it distributed-graph-analytics
```

Inside Docker, build and test:

```bash
make
make test
make benchmark
```

To run the large-graph benchmark inside Docker, mount the local project directory so Docker can access the locally generated `data/large_graph.csr` and `data/large_graph.csc` files:

```bash
docker run --rm -it -v "$PWD":/app -w /app distributed-graph-analytics bash
```

Then inside Docker:

```bash
make clean
make
make benchmark-large
```
## Correctness Testing

Correctness is currently checked by comparing the algorithm results across different MPI process counts.

For the small graph:

- PageRank should preserve the total PageRank sum.
- Triangle Counting should report the expected number of unique triangles.

Example expected outputs:

```text
PageRank sum: 6.000000
Unique triangles: 2
```

A future improvement is to make the correctness test parse only the algorithm result fields instead of diffing complete output. That would avoid false failures caused by timing differences, rank print order, or communication-time noise.

## Benchmark Methodology

The project benchmarks the same graph input across different MPI process counts. The goal is not only to find speedup, but also to identify where communication overhead outweighs the benefit of parallel execution.

Measured values include:

- Total runtime
- Number of processed edges per rank
- Communication time per rank
- Final algorithm result

A larger 100k-vertex / 1M-edge benchmark is documented in [docs/performance.md](docs/performance.md). On that input, Triangle Counting shows clearer scaling, while PageRank benefits from 2 processes but remains sensitive to communication overhead.

For a deeper explanation of the benchmark results and scaling behavior, see [docs/performance.md](docs/performance.md).

## Small Graph Benchmark

A small directed graph with 6 vertices and 9 edges is stored as `data/small_graph.csr` and `data/small_graph.csc`.

| Algorithm | Processes | Result | Runtime |
|---|---:|---:|---:|
| PageRank | 1 | Sum = 6.000000 | 0.000046s |
| PageRank | 4 | Sum = 6.000000 | 0.000146s |
| Triangle Counting | 1 | Unique triangles = 2 | 0.000041s |
| Triangle Counting | 4 | Unique triangles = 2 | 0.000108s |

The 4-process run is slower on this graph because the graph is too small for MPI parallelism to pay off. Communication and synchronization overhead dominate the small amount of computation.

## Medium Graph Benchmark Summary

Dataset:

- 10,000 vertices
- 120,000 directed edges
- 20 PageRank iterations

The current benchmark shows different scaling behavior for the two algorithms:

- PageRank achieved its best median runtime with 2 processes. The improvement is modest because each iteration requires communication, and the total runtime is small enough to remain sensitive to measurement noise.
- Triangle Counting scaled more clearly, with 4 processes reducing the median runtime from 11.591 ms to 2.979 ms because more of its work can be performed locally before the final reduction.

This result shows that MPI performance depends on the algorithm's computation-to-communication ratio. More details are available in [docs/performance.md](docs/performance.md).

## Performance Interpretation

These results show an important distributed-systems tradeoff: more processes do not automatically mean faster execution. MPI programs only scale when the computation saved by distributing work is larger than the communication and synchronization overhead introduced by coordination.

Current interpretation:

- Small graph: single-process execution is faster because there is too little work to amortize MPI startup and communication overhead.
- Medium PageRank: 2 processes achieve the best median runtime, while 4 processes do not provide additional improvement.
- Medium Triangle Counting: 4 processes achieve the best runtime and show clear scaling.
- Large PageRank: 2 processes consistently outperform 1 process, while 4-process runtime is more variable.
- Large Triangle Counting: 4 processes consistently provide the fastest runtime.

This makes the project useful as a systems benchmark: it demonstrates implementation, measurement, and honest analysis of scaling behavior.

## Future Improvements

- Add larger benchmark graphs, such as 100k vertices / 1M edges.
- Add a separate `docs/performance.md` with deeper scaling analysis.
- Improve correctness tests by parsing numeric result fields with tolerance.
- Record benchmark hardware and environment details.
- Add charts for runtime, speedup, and communication overhead.

## Resume Summary

Possible resume bullets:

- Implemented MPI-based PageRank and Triangle Counting in C++, using edge-aware partitioning to distribute graph workloads across processes.
- Benchmarked distributed execution across 1–4 MPI processes and analyzed cases where communication overhead outweighed parallel speedup.
- Built reproducible local and Docker workflows for compiling and running distributed graph analytics experiments.
