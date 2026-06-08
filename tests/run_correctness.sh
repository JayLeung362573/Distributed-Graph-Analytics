#!/bin/bash

set -e
trap 'rm -f pr_1.txt pr_4.txt tc_1.txt tc_4.txt' EXIT

echo "======================================"
echo "Running correctness tests"
echo "======================================"

GRAPH="data/small_graph"
PAGERANK_TOLERANCE="0.0001"

echo ""
echo "Building executables..."
make

echo ""
echo "Running PageRank with 1 process..."
mpirun --allow-run-as-root --oversubscribe -np 1 ./page_rank_parallel --inputFile "$GRAPH" --nIterations 20 --strategy 2 > pr_1.txt

echo "Running PageRank with 4 processes..."
mpirun --allow-run-as-root --oversubscribe -np 4 ./page_rank_parallel --inputFile "$GRAPH" --nIterations 20 --strategy 2 > pr_4.txt

PR_SUM_1=$(grep "Sum of page rank" pr_1.txt | awk '{print $6}')
PR_SUM_4=$(grep "Sum of page rank" pr_4.txt | awk '{print $6}')

echo ""
echo "PageRank results:"
echo "1 process: $PR_SUM_1"
echo "4 processes: $PR_SUM_4"

awk -v a="$PR_SUM_1" -v b="$PR_SUM_4" -v tol="$PAGERANK_TOLERANCE" '
BEGIN {
    diff = a - b
    if (diff < 0) diff = -diff

    if (diff <= tol) {
        print "[PASS] PageRank sum matches across 1 and 4 processes"
        exit 0
    } else {
        print "[FAIL] PageRank sum mismatch"
        print "Difference: " diff
        exit 1
    }
}'

echo ""
echo "Running Triangle Counting with 1 process..."
mpirun --allow-run-as-root --oversubscribe -np 1 ./triangle_counting_parallel --inputFile "$GRAPH" --strategy 2 > tc_1.txt

echo "Running Triangle Counting with 4 processes..."
mpirun --allow-run-as-root --oversubscribe -np 4 ./triangle_counting_parallel --inputFile "$GRAPH" --strategy 2 > tc_4.txt

TC_UNIQUE_1=$(grep "Number of unique triangles" tc_1.txt | awk '{print $6}')
TC_UNIQUE_4=$(grep "Number of unique triangles" tc_4.txt | awk '{print $6}')

echo ""
echo "Triangle Counting results:"
echo "1 process: $TC_UNIQUE_1"
echo "4 processes: $TC_UNIQUE_4"

if [ "$TC_UNIQUE_1" = "$TC_UNIQUE_4" ]; then
    echo "[PASS] Triangle count matches across 1 and 4 processes"
else
    echo "[FAIL] Triangle count mismatch"
    exit 1
fi

echo ""
echo "All correctness tests passed."