#!/bin/bash

set -e

echo "======================================"
echo "Running graph analytics benchmarks"
echo "======================================"

GRAPH="data/medium_graph"
PAGERANK_ITERATIONS=20
PROCESSES="1 2 4"
RUNS=3

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

    for r in $(seq 1 $RUNS)
    do
        OUTPUT=$(mpirun --allow-run-as-root -np "$p" ./page_rank_parallel \
            --inputFile "$GRAPH" \
            --nIterations "$PAGERANK_ITERATIONS" \
            --strategy 2)

        SUM=$(echo "$OUTPUT" | grep "Sum of page rank" | awk '{print $6}')
        TIME=$(echo "$OUTPUT" | grep "Time taken" | awk '{print $6}')

        echo "Run $r: Sum = $SUM, Time = ${TIME}s"
    done
done

echo ""
echo "======================================"
echo "Triangle Counting Benchmark"
echo "======================================"

for p in $PROCESSES
do
    echo ""
    echo "Processes: $p"

    for r in $(seq 1 $RUNS)
    do
        OUTPUT=$(mpirun --allow-run-as-root -np "$p" ./triangle_counting_parallel \
            --inputFile "$GRAPH" \
            --strategy 2)

        TRIANGLES=$(echo "$OUTPUT" | grep "Number of unique triangles" | awk '{print $6}')
        TIME=$(echo "$OUTPUT" | grep "Time taken" | awk '{print $6}')

        echo "Run $r: Unique triangles = $TRIANGLES, Time = ${TIME}s"
    done
done

echo ""
echo "Benchmark completed."