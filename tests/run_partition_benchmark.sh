#!/usr/bin/env bash

set -euo pipefail

GRAPH="data/skewed_graph"
PROCESSES=4
EXPECTED_TOTAL_EDGES=118000
OUTPUT_FILE="benchmarks/partition_loads.csv"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

MPI_RUN=(
    mpirun
    --allow-run-as-root
    --oversubscribe
)

if [[ ! -f "${GRAPH}.csr" || ! -f "${GRAPH}.csc" ]]; then
    echo "[ERROR] Skewed graph files were not found."
    echo "Generate them first with:"
    echo "  make generate-skewed"
    exit 1
fi

echo "======================================"
echo "Partition workload benchmark"
echo "======================================"
echo "Graph: $GRAPH"
echo "Processes: $PROCESSES"

echo ""
echo "Building executables..."
make

mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "algorithm,partition,rank,edges_processed" \
    > "$OUTPUT_FILE"

extract_rank_edges() {
    local input_file="$1"

    awk -F',' '
        NF >= 3 {
            process_rank = $1
            edges = $2

            gsub(/^[[:space:]]+|[[:space:]]+$/, "", process_rank)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", edges)

            if (process_rank ~ /^[0-9]+$/ && edges ~ /^[0-9]+$/) {
                print process_rank "," edges
            }
        }
    ' "$input_file" |
        sort -t',' -k1,1n
}

record_results() {
    local algorithm="$1"
    local partition="$2"
    local input_file="$3"

    local extracted_file
    extracted_file="$TEMP_DIR/${algorithm}_${partition}_loads.csv"

    extract_rank_edges "$input_file" > "$extracted_file"

    local row_count
    row_count=$(
        wc -l < "$extracted_file" |
            tr -d ' '
    )

    if [[ "$row_count" -ne "$PROCESSES" ]]; then
        echo "[ERROR] Expected $PROCESSES rank rows for:"
        echo "  Algorithm: $algorithm"
        echo "  Partition: $partition"
        echo "  Found: $row_count"
        echo ""
        cat "$input_file"
        exit 1
    fi

    local total_edges
    total_edges=$(
        awk -F',' '
            {
                total += $2
            }
            END {
                print total + 0
            }
        ' "$extracted_file"
    )

    if [[ "$total_edges" -ne "$EXPECTED_TOTAL_EDGES" ]]; then
        echo "[ERROR] Partition did not cover all graph edges."
        echo "Expected: $EXPECTED_TOTAL_EDGES"
        echo "Actual:   $total_edges"
        exit 1
    fi

    while IFS=',' read -r rank edges; do
        echo \
            "$algorithm,$partition,$rank,$edges" \
            >> "$OUTPUT_FILE"
    done < "$extracted_file"
}

for partition in edge vertex; do
    echo ""
    echo "Running PageRank with $partition partitioning..."

    page_rank_output="$TEMP_DIR/page_rank_${partition}.txt"

    "${MPI_RUN[@]}" \
        -np "$PROCESSES" \
        ./page_rank_parallel \
        --inputFile "$GRAPH" \
        --nIterations 1 \
        --strategy 2 \
        --partition "$partition" \
        > "$page_rank_output"

    record_results \
        "page_rank" \
        "$partition" \
        "$page_rank_output"

    echo "Running Triangle Counting with $partition partitioning..."

    triangle_output="$TEMP_DIR/triangle_counting_${partition}.txt"

    "${MPI_RUN[@]}" \
        -np "$PROCESSES" \
        ./triangle_counting_parallel \
        --inputFile "$GRAPH" \
        --strategy 2 \
        --partition "$partition" \
        > "$triangle_output"

    record_results \
        "triangle_counting" \
        "$partition" \
        "$triangle_output"
done

echo ""
echo "Workload summary:"
printf \
    "%-20s %-10s %12s %12s %16s\n" \
    "Algorithm" \
    "Partition" \
    "Min edges" \
    "Max edges" \
    "Max / average"

for algorithm in page_rank triangle_counting; do
    for partition in edge vertex; do
        awk -F',' \
            -v target_algorithm="$algorithm" \
            -v target_partition="$partition" '
            NR > 1 &&
            $1 == target_algorithm &&
            $2 == target_partition {
                value = $4 + 0
                total += value

                if (count == 0 || value < minimum) {
                    minimum = value
                }

                if (count == 0 || value > maximum) {
                    maximum = value
                }

                count++
            }

            END {
                if (count == 0) {
                    exit 1
                }

                average = total / count
                printf "%-20s %-10s %12d %12d %15.2fx\n", target_algorithm, target_partition, minimum, maximum, maximum / average
            }
        ' "$OUTPUT_FILE"
    done
done

echo ""
echo "Detailed results written to:"
echo "$OUTPUT_FILE"