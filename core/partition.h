#pragma once

#include <cstdint>
#include <stdexcept>
#include <string>

#include "graph.h"

enum class PartitionStrategy {
    EdgeAware,
    EqualVertex
};

inline PartitionStrategy parsePartitionStrategy(
    const std::string& value
) {
    if (value == "edge") {
        return PartitionStrategy::EdgeAware;
    }

    if (value == "vertex") {
        return PartitionStrategy::EqualVertex;
    }

    throw std::invalid_argument(
        "Invalid partition strategy '" + value +
        "'. Expected 'edge' or 'vertex'."
    );
}

inline const char* partitionStrategyName(
    PartitionStrategy strategy
) {
    if (strategy == PartitionStrategy::EdgeAware) {
        return "edge-aware";
    }

    return "equal-vertex";
}

inline void getEqualVertexRange(
    Graph& graph,
    int world_rank,
    int world_size,
    uintV& start_vertex,
    uintV& end_vertex
) {
    const std::uint64_t vertex_count = graph.n_;

    start_vertex = static_cast<uintV>(
        vertex_count * world_rank / world_size
    );

    end_vertex = static_cast<uintV>(
        vertex_count * (world_rank + 1) / world_size
    );
}

inline void getEdgeAwareVertexRange(
    Graph& graph,
    int world_rank,
    int world_size,
    uintV& start_vertex,
    uintV& end_vertex
) {
    start_vertex = 0;
    end_vertex = 0;

    const uintV vertex_count = graph.n_;
    const std::uint64_t edge_count =
        static_cast<std::uint64_t>(graph.m_);

    for (int rank = 0; rank < world_size; rank++) {
        start_vertex = end_vertex;

        // The final rank owns every remaining vertex so that the
        // partition ranges always cover the entire graph.
        if (rank == world_size - 1) {
            end_vertex = vertex_count;
        } else {
            std::uint64_t assigned_edges = 0;

            while (end_vertex < vertex_count) {
                assigned_edges += static_cast<std::uint64_t>(
                    graph.vertices_[end_vertex].getOutDegree()
                );

                end_vertex++;

                if (assigned_edges >= edge_count / world_size) {
                    break;
                }
            }
        }

        if (rank == world_rank) {
            break;
        }
    }
}

inline void getVertexRange(
    Graph& graph,
    int world_rank,
    int world_size,
    PartitionStrategy strategy,
    uintV& start_vertex,
    uintV& end_vertex
) {
    if (strategy == PartitionStrategy::EdgeAware) {
        getEdgeAwareVertexRange(
            graph,
            world_rank,
            world_size,
            start_vertex,
            end_vertex
        );
        return;
    }

    getEqualVertexRange(
        graph,
        world_rank,
        world_size,
        start_vertex,
        end_vertex
    );
}