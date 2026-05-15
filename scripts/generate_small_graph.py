import os
import struct

os.makedirs("data", exist_ok=True)

# Directed graph with triangles:
# Triangle: 0 -> 1 -> 2 -> 0
# Triangle: 2 -> 3 -> 4 -> 2
# Extra edges for PageRank variation
n = 6
edges = [
    (0, 1),
    (1, 2),
    (2, 0),

    (2, 3),
    (3, 4),
    (4, 2),

    (4, 5),
    (5, 0),
    (1, 4),
]


def build_csr(n, edges):
    adj = [[] for _ in range(n)]

    for src, dst in edges:
        adj[src].append(dst)

    for neighbors in adj:
        neighbors.sort()

    offsets = []
    flat_edges = []
    current_offset = 0

    for neighbors in adj:
        offsets.append(current_offset)
        flat_edges.extend(neighbors)
        current_offset += len(neighbors)

    return offsets, flat_edges


def write_binary_graph(path, n, offsets, flat_edges):
    values = [n, len(flat_edges)] + offsets + flat_edges

    with open(path, "wb") as f:
        for value in values:
            f.write(struct.pack("i", value))


# CSR: outgoing edges
csr_offsets, csr_edges = build_csr(n, edges)
write_binary_graph("data/small_graph.csr", n, csr_offsets, csr_edges)

# CSC: incoming edges = reverse graph
reversed_edges = [(dst, src) for src, dst in edges]
csc_offsets, csc_edges = build_csr(n, reversed_edges)
write_binary_graph("data/small_graph.csc", n, csc_offsets, csc_edges)

print("Generated:")
print("data/small_graph.csr")
print("data/small_graph.csc")
print(f"Vertices: {n}")
print(f"Edges: {len(edges)}")