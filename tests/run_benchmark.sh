#!/bin/bash
set -e

echo "======================================"
echo "Running PageRank benchmark"
echo "======================================"

make

python3 scripts/generate_medium_graph.py

GRAPH="data/medium_graph"

for p in 1 2 4
do
    echo ""
    echo "Running PageRank with $p process(es)..."
    mpirun --allow-run-as-root -np $p ./page_rank_parallel --inputFile "$GRAPH"
done

echo ""
echo "Benchmark completed."