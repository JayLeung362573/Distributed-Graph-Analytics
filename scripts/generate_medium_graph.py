import os
import random
import struct

os.makedirs("data", exist_ok=True)

NUM_VERTICES = 10000
NUM_EDGES = 120000

random.seed(42)

edges = set()

while len(edges) < NUM_EDGES:
    src = random.randint(0, NUM_VERTICES - 1)
    dst = random.randint(0, NUM_VERTICES - 1)

    if src != dst:
        edges.add((src, dst))

edges = list(edges)

print(f"Generated {len(edges)} edges")


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


csr_offsets, csr_edges = build_csr(NUM_VERTICES, edges)

reversed_edges = [(dst, src) for src, dst in edges]

csc_offsets, csc_edges = build_csr(NUM_VERTICES, reversed_edges)

write_binary_graph(
    "data/medium_graph.csr",
    NUM_VERTICES,
    csr_offsets,
    csr_edges
)

write_binary_graph(
    "data/medium_graph.csc",
    NUM_VERTICES,
    csc_offsets,
    csc_edges
)

print("Generated:")
print("data/medium_graph.csr")
print("data/medium_graph.csc")
print(f"Vertices: {NUM_VERTICES}")
print(f"Edges: {NUM_EDGES}")