#!/bin/bash

set -euo pipefail

GRAPH="data/small_graph"
PAGERANK_TOLERANCE="0.0001"
EXPECTED_PAGERANK_SUM="6.000000"
EXPECTED_TRIANGLE_COUNT="2"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

MPI_RUN=(
    mpirun
    --allow-run-as-root
    --oversubscribe
)

echo "======================================"
echo "Running graph analytics correctness tests"
echo "======================================"

echo ""
echo "Building executables..."
make

assert_close() {
    local actual="$1"
    local expected="$2"
    local tolerance="$3"
    local description="$4"

    awk \
        -v actual="$actual" \
        -v expected="$expected" \
        -v tolerance="$tolerance" \
        -v description="$description" '
        BEGIN {
            difference = actual - expected

            if (difference < 0) {
                difference = -difference
            }

            if (difference <= tolerance) {
                print "[PASS] " description
                exit 0
            }

            print "[FAIL] " description
            print "Expected: " expected
            print "Actual:   " actual
            print "Difference: " difference
            exit 1
        }
    '
}

assert_equal() {
    local actual="$1"
    local expected="$2"
    local description="$3"

    if [ "$actual" = "$expected" ]; then
        echo "[PASS] $description"
        return
    fi

    echo "[FAIL] $description"
    echo "Expected: $expected"
    echo "Actual:   $actual"
    exit 1
}

run_page_rank() {
    local partition="$1"
    local processes="$2"
    local output_file="$3"

    "${MPI_RUN[@]}" \
        -np "$processes" \
        ./page_rank_parallel \
        --inputFile "$GRAPH" \
        --nIterations 20 \
        --strategy 2 \
        --partition "$partition" \
        > "$output_file"
}

run_triangle_counting() {
    local partition="$1"
    local processes="$2"
    local output_file="$3"

    "${MPI_RUN[@]}" \
        -np "$processes" \
        ./triangle_counting_parallel \
        --inputFile "$GRAPH" \
        --strategy 2 \
        --partition "$partition" \
        > "$output_file"
}

for partition in edge vertex; do
    echo ""
    echo "======================================"
    echo "Partition strategy: $partition"
    echo "======================================"

    page_rank_1_output="$TEMP_DIR/pr_${partition}_1.txt"
    page_rank_4_output="$TEMP_DIR/pr_${partition}_4.txt"

    echo ""
    echo "Running PageRank with 1 process..."
    run_page_rank "$partition" 1 "$page_rank_1_output"

    echo "Running PageRank with 4 processes..."
    run_page_rank "$partition" 4 "$page_rank_4_output"

    page_rank_sum_1=$(
        grep "Sum of page rank" "$page_rank_1_output" |
            awk '{print $6}'
    )

    page_rank_sum_4=$(
        grep "Sum of page rank" "$page_rank_4_output" |
            awk '{print $6}'
    )

    echo "PageRank results:"
    echo "1 process: $page_rank_sum_1"
    echo "4 processes: $page_rank_sum_4"

    assert_close \
        "$page_rank_sum_1" \
        "$EXPECTED_PAGERANK_SUM" \
        "$PAGERANK_TOLERANCE" \
        "PageRank result is correct with 1 process and $partition partitioning"

    assert_close \
        "$page_rank_sum_4" \
        "$EXPECTED_PAGERANK_SUM" \
        "$PAGERANK_TOLERANCE" \
        "PageRank result is correct with 4 processes and $partition partitioning"

    assert_close \
        "$page_rank_sum_1" \
        "$page_rank_sum_4" \
        "$PAGERANK_TOLERANCE" \
        "PageRank matches across process counts with $partition partitioning"

    triangle_1_output="$TEMP_DIR/tc_${partition}_1.txt"
    triangle_4_output="$TEMP_DIR/tc_${partition}_4.txt"

    echo ""
    echo "Running Triangle Counting with 1 process..."
    run_triangle_counting "$partition" 1 "$triangle_1_output"

    echo "Running Triangle Counting with 4 processes..."
    run_triangle_counting "$partition" 4 "$triangle_4_output"

    triangle_count_1=$(
        grep "Number of unique triangles" "$triangle_1_output" |
            awk '{print $6}'
    )

    triangle_count_4=$(
        grep "Number of unique triangles" "$triangle_4_output" |
            awk '{print $6}'
    )

    echo "Triangle Counting results:"
    echo "1 process: $triangle_count_1"
    echo "4 processes: $triangle_count_4"

    assert_equal \
        "$triangle_count_1" \
        "$EXPECTED_TRIANGLE_COUNT" \
        "Triangle count is correct with 1 process and $partition partitioning"

    assert_equal \
        "$triangle_count_4" \
        "$EXPECTED_TRIANGLE_COUNT" \
        "Triangle count is correct with 4 processes and $partition partitioning"

    assert_equal \
        "$triangle_count_1" \
        "$triangle_count_4" \
        "Triangle count matches across process counts with $partition partitioning"
done

echo ""
echo "======================================"
echo "All correctness tests passed."
echo "======================================"