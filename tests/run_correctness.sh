#!/bin/bash

echo "======================================"
echo "Running correctness tests"
echo "======================================"

GRAPH="../data/small_graph.txt"

echo ""
echo "Building executables..."
make

echo ""
echo "Running PageRank with 1 process..."
mpirun -np 1 ../page_rank_parallel -i $GRAPH > pr_1.txt

echo "Running PageRank with 4 processes..."
mpirun -np 4 ../page_rank_parallel -i $GRAPH > pr_4.txt

echo ""
echo "Comparing outputs..."

if diff pr_1.txt pr_4.txt > /dev/null; then
    echo "PageRank correctness test PASSED"
else
    echo "PageRank correctness test FAILED"
fi

echo ""
echo "Running Triangle Counting with 1 process..."
mpirun -np 1 ../triangle_counting_parallel -i $GRAPH > tc_1.txt

echo "Running Triangle Counting with 4 processes..."
mpirun -np 4 ../triangle_counting_parallel -i $GRAPH > tc_4.txt

echo ""
echo "Comparing outputs..."

if diff tc_1.txt tc_4.txt > /dev/null; then
    echo "Triangle Counting correctness test PASSED"
else
    echo "Triangle Counting correctness test FAILED"
fi

echo ""
echo "All tests completed."