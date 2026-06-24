#!/usr/bin/env python3

from __future__ import annotations

import csv
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]

INPUT_PATH = (
    PROJECT_ROOT
    / "benchmarks"
    / "partition_loads.csv"
)

OUTPUT_PATH = (
    PROJECT_ROOT
    / "docs"
    / "images"
    / "partition_workload_balance.png"
)

EXPECTED_PARTITIONS = {"edge", "vertex"}


def load_partition_loads(
    input_path: Path,
) -> dict[str, dict[int, int]]:
    """Load and validate per-rank partition workloads."""

    if not input_path.exists():
        raise FileNotFoundError(
            f"Partition benchmark data not found: {input_path}"
        )

    algorithm_results: dict[
        str,
        dict[str, dict[int, int]],
    ] = {}

    with input_path.open(
        "r",
        encoding="utf-8",
        newline="",
    ) as csv_file:
        reader = csv.DictReader(csv_file)

        required_columns = {
            "algorithm",
            "partition",
            "rank",
            "edges_processed",
        }

        if reader.fieldnames is None:
            raise ValueError(
                "Partition benchmark CSV does not contain a header."
            )

        missing_columns = (
            required_columns - set(reader.fieldnames)
        )

        if missing_columns:
            missing = ", ".join(sorted(missing_columns))
            raise ValueError(
                f"Partition benchmark CSV is missing columns: {missing}"
            )

        for row in reader:
            algorithm = row["algorithm"].strip()
            partition = row["partition"].strip()
            rank = int(row["rank"])
            edges_processed = int(row["edges_processed"])

            if not algorithm:
                raise ValueError("Algorithm name cannot be empty.")

            if partition not in EXPECTED_PARTITIONS:
                raise ValueError(
                    f"Unexpected partition strategy: {partition}"
                )

            if rank < 0:
                raise ValueError("MPI rank cannot be negative.")

            if edges_processed < 0:
                raise ValueError(
                    "Processed edge count cannot be negative."
                )

            partition_results = algorithm_results.setdefault(
                algorithm,
                {},
            )

            rank_results = partition_results.setdefault(
                partition,
                {},
            )

            if rank in rank_results:
                raise ValueError(
                    "Duplicate benchmark row for "
                    f"{algorithm}, {partition}, rank {rank}."
                )

            rank_results[rank] = edges_processed

    if not algorithm_results:
        raise ValueError(
            "Partition benchmark CSV contains no results."
        )

    reference_algorithm = next(iter(algorithm_results))
    reference_results = algorithm_results[reference_algorithm]

    for algorithm, results in algorithm_results.items():
        if results != reference_results:
            raise ValueError(
                "Partition workloads differ between algorithms. "
                f"{algorithm} does not match {reference_algorithm}."
            )

    if set(reference_results) != EXPECTED_PARTITIONS:
        raise ValueError(
            "Benchmark data must include both edge and vertex "
            "partitioning."
        )

    edge_ranks = set(reference_results["edge"])
    vertex_ranks = set(reference_results["vertex"])

    if edge_ranks != vertex_ranks:
        raise ValueError(
            "Partition strategies contain different MPI ranks."
        )

    if not edge_ranks:
        raise ValueError("No MPI rank data was found.")

    expected_ranks = set(range(len(edge_ranks)))

    if edge_ranks != expected_ranks:
        raise ValueError(
            "MPI ranks must be contiguous and start at zero."
        )

    return reference_results


def create_chart(
    results: dict[str, dict[int, int]],
    output_path: Path,
) -> None:
    """Create a grouped bar chart of per-rank workloads."""

    try:
        import matplotlib.pyplot as plt
    except ImportError as error:
        raise RuntimeError(
            "matplotlib is required. Install it with: "
            "python3 -m pip install -r requirements-dev.txt"
        ) from error

    ranks = sorted(results["edge"])
    edge_loads = [
        results["edge"][rank]
        for rank in ranks
    ]
    vertex_loads = [
        results["vertex"][rank]
        for rank in ranks
    ]

    positions = list(range(len(ranks)))
    bar_width = 0.36

    figure, axis = plt.subplots(figsize=(9, 5.5))

    edge_bars = axis.bar(
        [
            position - bar_width / 2
            for position in positions
        ],
        edge_loads,
        width=bar_width,
        label="Edge-aware",
    )

    vertex_bars = axis.bar(
        [
            position + bar_width / 2
            for position in positions
        ],
        vertex_loads,
        width=bar_width,
        label="Equal-vertex",
    )

    axis.bar_label(
        edge_bars,
        labels=[
            f"{value:,}"
            for value in edge_loads
        ],
        padding=3,
    )

    axis.bar_label(
        vertex_bars,
        labels=[
            f"{value:,}"
            for value in vertex_loads
        ],
        padding=3,
    )

    axis.set_title(
        "Partition Workload Balance on a Degree-Skewed Graph\n"
        "10,000 Vertices, 118,000 Directed Edges"
    )

    axis.set_xlabel("MPI Rank")
    axis.set_ylabel("Outgoing Edges Processed")

    axis.set_xticks(
        positions,
        [
            f"Rank {rank}"
            for rank in ranks
        ],
    )

    axis.set_ylim(
        bottom=0,
        top=max(edge_loads + vertex_loads) * 1.15,
    )

    axis.legend()

    output_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    figure.tight_layout()
    figure.savefig(
        output_path,
        dpi=180,
    )

    plt.close(figure)


def main() -> None:
    results = load_partition_loads(INPUT_PATH)
    create_chart(results, OUTPUT_PATH)

    print(f"Chart written to: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()