#!/usr/bin/env python3

from __future__ import annotations

import struct
from pathlib import Path


NUM_VERTICES = 10_000
HEAVY_VERTEX_COUNT = 1_000
HEAVY_OUT_DEGREE = 100
LIGHT_OUT_DEGREE = 2

PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_PREFIX = PROJECT_ROOT / "data" / "skewed_graph"


def generate_edges() -> list[tuple[int, int]]:
    """Generate a deterministic directed graph with skewed degrees."""

    edges: list[tuple[int, int]] = []

    for source in range(NUM_VERTICES):
        if source < HEAVY_VERTEX_COUNT:
            out_degree = HEAVY_OUT_DEGREE
        else:
            out_degree = LIGHT_OUT_DEGREE

        for step in range(1, out_degree + 1):
            destination = (
                source + step * 97
            ) % NUM_VERTICES

            if destination == source:
                raise RuntimeError(
                    f"Generated a self-loop for vertex {source}"
                )

            edges.append((source, destination))

    return edges


def build_csr(
    vertex_count: int,
    edges: list[tuple[int, int]],
) -> tuple[list[int], list[int]]:
    """Build CSR offsets and flattened adjacency data."""

    adjacency: list[list[int]] = [
        [] for _ in range(vertex_count)
    ]

    for source, destination in edges:
        adjacency[source].append(destination)

    offsets: list[int] = []
    flattened_edges: list[int] = []
    current_offset = 0

    for neighbors in adjacency:
        neighbors.sort()

        offsets.append(current_offset)
        flattened_edges.extend(neighbors)
        current_offset += len(neighbors)

    return offsets, flattened_edges


def write_binary_graph(
    output_path: Path,
    vertex_count: int,
    offsets: list[int],
    flattened_edges: list[int],
) -> None:
    """Write the graph using the project's binary graph format."""

    values = [
        vertex_count,
        len(flattened_edges),
        *offsets,
        *flattened_edges,
    ]

    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("wb") as output_file:
        for value in values:
            output_file.write(struct.pack("i", value))


def calculate_equal_vertex_loads(
    edges: list[tuple[int, int]],
    process_count: int,
) -> list[int]:
    """Calculate edge workloads under equal-vertex partitioning."""

    out_degrees = [0] * NUM_VERTICES

    for source, _ in edges:
        out_degrees[source] += 1

    loads: list[int] = []

    for rank in range(process_count):
        start_vertex = (
            NUM_VERTICES * rank // process_count
        )
        end_vertex = (
            NUM_VERTICES * (rank + 1) // process_count
        )

        loads.append(
            sum(out_degrees[start_vertex:end_vertex])
        )

    return loads


def main() -> None:
    edges = generate_edges()

    expected_edge_count = (
        HEAVY_VERTEX_COUNT * HEAVY_OUT_DEGREE
        + (NUM_VERTICES - HEAVY_VERTEX_COUNT)
        * LIGHT_OUT_DEGREE
    )

    if len(edges) != expected_edge_count:
        raise RuntimeError(
            "Generated edge count does not match the expected value."
        )

    if len(edges) != len(set(edges)):
        raise RuntimeError(
            "Generated graph contains duplicate edges."
        )

    csr_offsets, csr_edges = build_csr(
        NUM_VERTICES,
        edges,
    )

    reversed_edges = [
        (destination, source)
        for source, destination in edges
    ]

    csc_offsets, csc_edges = build_csr(
        NUM_VERTICES,
        reversed_edges,
    )

    csr_path = OUTPUT_PREFIX.with_suffix(".csr")
    csc_path = OUTPUT_PREFIX.with_suffix(".csc")

    write_binary_graph(
        csr_path,
        NUM_VERTICES,
        csr_offsets,
        csr_edges,
    )

    write_binary_graph(
        csc_path,
        NUM_VERTICES,
        csc_offsets,
        csc_edges,
    )

    equal_vertex_loads = calculate_equal_vertex_loads(
        edges,
        process_count=4,
    )

    print("Generated degree-skewed graph:")
    print(f"Vertices: {NUM_VERTICES}")
    print(f"Edges: {len(edges)}")
    print(
        f"Heavy vertices: 0-{HEAVY_VERTEX_COUNT - 1} "
        f"with out-degree {HEAVY_OUT_DEGREE}"
    )
    print(
        f"Remaining vertices: out-degree "
        f"{LIGHT_OUT_DEGREE}"
    )
    print(
        "Expected equal-vertex edge loads with 4 processes: "
        + ", ".join(
            str(load) for load in equal_vertex_loads
        )
    )
    print(f"Written: {csr_path}")
    print(f"Written: {csc_path}")


if __name__ == "__main__":
    main()