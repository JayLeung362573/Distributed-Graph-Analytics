#!/bin/bash

set -e

echo "======================================"
echo "Running graph analytics benchmarks"
echo "======================================"

GRAPH="data/medium_graph"
PAGERANK_ITERATIONS=20
PROCESSES="1 2 4"

echo ""
echo "Building executables..."
make

echo ""
echo "Benchmark graph:"
echo "$GRAPH"

if [ ! -f "${GRAPH}.csr" ] || [ ! -f "${GRAPH}.csc" ]; then
    echo "[ERROR] Benchmark graph files not found:"
    echo "Expected ${GRAPH}.csr and ${GRAPH}.csc"
    echo ""
    echo "Generate them first with:"
    echo "python3 scripts/generate_medium_graph.py"
    exit 1
fi

echo ""
echo "======================================"
echo "PageRank Benchmark"
echo "======================================"

for p in $PROCESSES
do
    echo ""
    echo "Processes: $p"
    OUTPUT=$(mpirun --allow-run-as-root -np "$p" ./page_rank_parallel \
        --inputFile "$GRAPH" \
        --nIterations "$PAGERANK_ITERATIONS" \
        --strategy 2)

    echo "$OUTPUT" | grep "Sum of page rank"
    echo "$OUTPUT" | grep "Time taken"
done

echo ""
echo "======================================"
echo "Triangle Counting Benchmark"
echo "======================================"

for p in $PROCESSES
do
    echo ""
    echo "Processes: $p"
    OUTPUT=$(mpirun --allow-run-as-root -np "$p" ./triangle_counting_parallel \
        --inputFile "$GRAPH" \
        --strategy 2)

    echo "$OUTPUT" | grep "Number of unique triangles"
    echo "$OUTPUT" | grep "Time taken"
done

echo ""
echo "Benchmark completed."