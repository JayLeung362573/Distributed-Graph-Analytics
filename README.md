# Distributed Graph Analytics

![CI](https://github.com/JayLeung362573/Distributed-Graph-Analytics/actions/workflows/ci.yml/badge.svg)

A C++/MPI graph analytics project that implements distributed-memory versions of PageRank and Triangle Counting. The project focuses on partitioning graph workloads across MPI processes, comparing communication strategies, validating correctness across process counts, and interpreting when parallelism helps or hurts performance.

This project is intentionally benchmark-driven: the current results show that small graphs do not benefit from extra MPI processes because communication and synchronization overhead dominate computation. That behavior is documented rather than hidden, because understanding the scaling limit is part of the engineering goal.

## Benchmark Snapshot

The table below summarizes the median runtime from three benchmark runs. Speedup is calculated relative to the single-process runtime for the same graph and algorithm.

| Dataset | Algorithm | 1 Process | Best Parallel Run | Speedup | Main Observation |
|---|---|---:|---:|---:|---|
| Medium: 10k vertices, 120k edges | PageRank | 2.011 ms | 1.477 ms with 2 processes | 1.36x | Modest improvement; repeated communication limits scaling |
| Medium: 10k vertices, 120k edges | Triangle Counting | 11.591 ms | 2.979 ms with 4 processes | 3.89x | Clear scaling from heavier local computation |
| Large: 100k vertices, 1M edges | PageRank | 21.349 ms | 12.836 ms with 2 processes | 1.66x | Two processes help, while four-process runs are more variable |
| Large: 100k vertices, 1M edges | Triangle Counting | 99.736 ms | 34.784 ms with 4 processes | 2.87x | Consistent scaling across increasing process counts |

These results show that scalability depends on the algorithm's computation-to-communication ratio. Triangle Counting benefits more consistently from additional MPI processes, while iterative PageRank is more sensitive to communication and synchronization overhead.

Detailed measurements and interpretation are available in [docs/performance.md](docs/performance.md).

## Features

- Distributed PageRank implemented in C++ with MPI
- Distributed Triangle Counting implemented in C++ with MPI
- Edge-aware vertex partitioning to balance edge-processing work across processes
- MPI communication strategies for combining partial results
- Correctness checks across different process counts
- Benchmarks across 1, 2, and 4 MPI processes
- Docker-based reproducible environment

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
