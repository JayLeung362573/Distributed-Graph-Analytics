#!/usr/bin/env python3

from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
INPUT_PATH = (
    PROJECT_ROOT
    / "benchmarks"
    / "large_graph_runtime_medians.csv"
)
OUTPUT_PATH = (
    PROJECT_ROOT
    / "docs"
    / "images"
    / "large_graph_runtime_scaling.png"
)


def load_results(
    input_path: Path,
) -> dict[str, list[tuple[int, float]]]:
    """Load benchmark results grouped by algorithm."""

    if not input_path.exists():
        raise FileNotFoundError(
            f"Benchmark data file not found: {input_path}"
        )

    grouped_results: dict[str, list[tuple[int, float]]] = defaultdict(list)

    with input_path.open("r", encoding="utf-8", newline="") as csv_file:
        reader = csv.DictReader(csv_file)

        required_columns = {
            "algorithm",
            "processes",
            "median_runtime_ms",
        }

        if reader.fieldnames is None:
            raise ValueError("Benchmark CSV does not contain a header.")

        missing_columns = required_columns - set(reader.fieldnames)

        if missing_columns:
            missing = ", ".join(sorted(missing_columns))
            raise ValueError(f"Benchmark CSV is missing columns: {missing}")

        for row in reader:
            algorithm = row["algorithm"].strip()
            processes = int(row["processes"])
            runtime_ms = float(row["median_runtime_ms"])

            if processes <= 0:
                raise ValueError("Process count must be positive.")

            if runtime_ms < 0:
                raise ValueError("Runtime cannot be negative.")

            grouped_results[algorithm].append(
                (processes, runtime_ms)
            )

    for points in grouped_results.values():
        points.sort(key=lambda point: point[0])

    return dict(grouped_results)


def create_chart(
    results: dict[str, list[tuple[int, float]]],
    output_path: Path,
) -> None:
    """Create the process-count-versus-runtime chart."""

    try:
        import matplotlib.pyplot as plt
    except ImportError as error:
        raise RuntimeError(
            "matplotlib is required. "
            "Install it with: pip install -r requirements-dev.txt"
        ) from error

    figure, axis = plt.subplots(figsize=(8, 5))

    for algorithm, points in results.items():
        process_counts = [point[0] for point in points]
        runtimes = [point[1] for point in points]

        axis.plot(
            process_counts,
            runtimes,
            marker="o",
            label=algorithm,
        )

        for process_count, runtime in points:
            axis.annotate(
                f"{runtime:.1f} ms",
                (process_count, runtime),
                textcoords="offset points",
                xytext=(0, 7),
                ha="center",
            )

    axis.set_title(
        "Large Graph Runtime Scaling\n"
        "100k Vertices, 1M Directed Edges"
    )
    axis.set_xlabel("MPI Processes")
    axis.set_ylabel("Median Runtime (ms)")
    axis.set_xticks([1, 2, 4])
    axis.set_ylim(bottom=0)
    axis.legend()

    output_path.parent.mkdir(parents=True, exist_ok=True)
    figure.tight_layout()
    figure.savefig(output_path, dpi=180)
    plt.close(figure)


def main() -> None:
    results = load_results(INPUT_PATH)
    create_chart(results, OUTPUT_PATH)
    print(f"Chart written to: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()