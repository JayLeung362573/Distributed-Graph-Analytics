#include <iostream>
#include <cstdio>
#include "core/utils.h"
#include "core/graph.h"
#include <mpi.h>
#include <vector>

long countTriangles(uintV *array1, uintE len1, uintV *array2, uintE len2,
                     uintV u, uintV v) {
  uintE i = 0, j = 0; // indexes for array1 and array2
  long count = 0;

  if (u == v)
    return count;

  while ((i < len1) && (j < len2)) {
    if (array1[i] == array2[j]) {
      if ((array1[i] != u) && (array1[i] != v)) {
        count++;
      } else {
        // triangle with self-referential edge -> ignore
      }
      i++;
      j++;
    } else if (array1[i] < array2[j]) {
      i++;
    } else {
      j++;
    }
  }
  return count;
}

void getVertexRange(Graph& g, int world_rank, int world_size, 
    uintV &start_vertex, uintV &end_vertex){
        start_vertex = 0;
        end_vertex = 0;

        uintV n = g.n_;
        long m = g.m_;

        for(int i = 0; i < world_size; i++){
            start_vertex = end_vertex;
            long count = 0;
            
            while(end_vertex < n){
                count += g.vertices_[end_vertex].getOutDegree();
                end_vertex += 1;
                if(count >= m / world_size){
                    break;
                }
            }

            if(i == world_rank){
                break;
            }
        }
}

void triangleCountParallel(Graph &g, int world_rank, int world_size, int strategy)
{
    timer total_timer;
    total_timer.start();

    uintV start_vertex, end_vertex;
    getVertexRange(g, world_rank, world_size, start_vertex, end_vertex);

    long local_triangle_count = 0;    
    long edges_processed = 0;

    for (uintV u = start_vertex; u < end_vertex; u++)
    {
        uintE out_degree = g.vertices_[u].getOutDegree();
        edges_processed += out_degree;

        for (uintE i = 0; i < out_degree; i++)
        {
            uintV v = g.vertices_[u].getOutNeighbor(i);
            local_triangle_count += countTriangles(g.vertices_[u].getInNeighbors(),
                                             g.vertices_[u].getInDegree(),
                                             g.vertices_[v].getOutNeighbors(),
                                             g.vertices_[v].getOutDegree(),
                                             u,
                                             v);
        }
    }

    long global_triangle_count = 0;
    double communication_time = 0.0;

    timer comm_timer;
    comm_timer.start();

    if(strategy == 1){
        long* gather_counts = nullptr;
        if(world_rank == 0){
            gather_counts = new long[world_size];
        }

        MPI_Gather(&local_triangle_count, 1, MPI_LONG, gather_counts, 1, MPI_LONG, 0, MPI_COMM_WORLD);

        if(world_rank == 0){
            for(int i = 0; i < world_size; i++){
                global_triangle_count += gather_counts[i];
            }
            delete[] gather_counts;
        }
    }else if(strategy == 2){
        MPI_Reduce(&local_triangle_count, &global_triangle_count, 1, MPI_LONG, MPI_SUM, 0, MPI_COMM_WORLD);
    }

    communication_time = comm_timer.stop();

    // For every thread, print out the following statistics:
    // rank, edges, triangle_count, communication_time
    // 0, 17248443, 144441858, 0.000074
    // 1, 17248443, 152103585, 0.000020
    // 2, 17248443, 225182666, 0.000034
    // 3, 17248444, 185596640, 0.000022

    // Print out overall statistics
    std::printf("%d, %ld, %ld, %f\n", world_rank, edges_processed, local_triangle_count, communication_time);

    if (world_rank == 0) {
        double total_time_taken = total_timer.stop();
        std::printf("Number of triangles : %ld\n", global_triangle_count);
        std::printf("Number of unique triangles : %ld\n", global_triangle_count / 3);
        std::printf("Time taken (in seconds) : %f\n", total_time_taken);
    }
}

int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);

    int world_rank, world_size;

    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    cxxopts::Options options("triangle_counting_parallel", "Count the number of triangles using MPI");    options.add_options("custom", {
                                      {"strategy", "Strategy to be used", cxxopts::value<uint>()->default_value(DEFAULT_STRATEGY)},
                                      {"inputFile", "Input graph file path", cxxopts::value<std::string>()->default_value("/scratch/input_graphs/roadNet-CA")},
                                  });

    auto cl_options = options.parse(argc, argv);
    uint strategy = cl_options["strategy"].as<uint>();
    std::string input_file_path = cl_options["inputFile"].as<std::string>();

    // Get the world size and print it out here
    // std::printf("World size : %d\n", world_size);
    if (world_rank == 0) {
        std::printf("World size : %d\n", world_size);
        std::printf("Communication strategy : %d\n", strategy);
        std::printf("rank, edges, triangle_count, communication_time\n");
    }

    Graph g;
    g.readGraphFromBinary<int>(input_file_path);

    triangleCountParallel(g, world_rank, world_size, strategy);

    MPI_Finalize();

    return 0;
}

