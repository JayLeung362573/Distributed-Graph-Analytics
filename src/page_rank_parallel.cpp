#include <iostream>
#include <cstdio>
#include <vector>
#include <mpi.h>
#include "core/utils.h"
#include "core/graph.h"

#ifdef USE_INT
#define INIT_PAGE_RANK 100000
#define EPSILON 1000
#define PAGE_RANK(x) (15000 + (5 * x) / 6)
#define CHANGE_IN_PAGE_RANK(x, y) std::abs(x - y)
#define PAGERANK_MPI_TYPE MPI_LONG
#define PR_FMT "%ld"
typedef int64_t PageRankType;
#else
#define INIT_PAGE_RANK 1.0
#define EPSILON 0.01
#define DAMPING 0.85
#define PAGE_RANK(x) (1 - DAMPING + DAMPING * x)
#define CHANGE_IN_PAGE_RANK(x, y) std::fabs(x - y)
#define PAGERANK_MPI_TYPE MPI_FLOAT
#define PR_FMT "%f"
typedef float PageRankType;
#endif

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

void buildScatter(const std::vector<uintV> &starts,
                      const std::vector<uintV> &ends,
                      std::vector<int> &sendcounts,
                      std::vector<int> &displacements){
    
    int p = (int)starts.size();
    sendcounts.resize(p);
    displacements.resize(p);

    for (int i = 0; i < p; i++){
        sendcounts[i] = (int)(ends[i] - starts[i]);
        displacements[i] = (int)starts[i];
    }
}

void pageRankParallel(Graph &g, int max_iters, int strategy, int world_rank, int world_size){
    timer total_timer;
    total_timer.start();

    uintV n = g.n_;
    uintV start_v, end_v;

    getVertexRange(g, world_rank, world_size, start_v, end_v);

    PageRankType *pr_curr = new PageRankType[n];
    PageRankType *pr_next = new PageRankType[n];

    for(uintV i = 0; i < n; i++){
        pr_curr[i] = INIT_PAGE_RANK;
        pr_next[i] = 0;
    }

    long edges_processed = 0;
    PageRankType global_sum = 0;
    double total_communication_time = 0.0;

    std::vector<uintV> all_starts(world_size), all_ends(world_size);
    std::vector<int> counts, displacements;

    for(int i = 0; i < world_size; i++) {
        getVertexRange(g, i, world_size, all_starts[i], all_ends[i]);
    }

    buildScatter(all_starts, all_ends, counts, displacements);

    std::vector<PageRankType> local_block(end_v - start_v);

    PageRankType* global_next = nullptr;
    if (strategy == 1 && world_rank == 0) {
        global_next = new PageRankType[n];
    }

    for(int iter = 0; iter < max_iters; iter++){
        
        for(uintV u = start_v; u < end_v; u++){
            uintE out_degree = g.vertices_[u].getOutDegree();
            edges_processed += out_degree;

            if (out_degree == 0) {
                continue;
            }

            PageRankType contribution = pr_curr[u] / out_degree;
            for (uintE i = 0; i < out_degree; i++) {
                uintV v = g.vertices_[u].getOutNeighbor(i);
                pr_next[v] += contribution;
            }
        }

        timer comm_timer;
        comm_timer.start();

        if(strategy == 1){
            MPI_Reduce(pr_next, global_next, (int)n, PAGERANK_MPI_TYPE, MPI_SUM, 0, MPI_COMM_WORLD);

            MPI_Scatterv(global_next, 
                counts.data(), 
                displacements.data(), 
                PAGERANK_MPI_TYPE, 
                local_block.data(), 
                counts[world_rank], 
                PAGERANK_MPI_TYPE, 0, MPI_COMM_WORLD);

        }else if(strategy == 2){
            for(int r = 0; r < world_size; r++){
                uintV block_start = all_starts[r];
                int block_len = counts[r];

                if(block_len == 0){
                    continue;
                }

                MPI_Reduce(pr_next + block_start,
                    local_block.data(), block_len, PAGERANK_MPI_TYPE, MPI_SUM, r, MPI_COMM_WORLD);
            }
        }
        
        total_communication_time += comm_timer.stop();

        for (uintV i = 0; i < end_v - start_v; i++) {
            uintV v = start_v + i;
            pr_curr[v] = PAGE_RANK(local_block[i]);
        }

        for (uintV i = 0; i < n; i++){
            pr_next[i] = 0;
        }
    }

    PageRankType local_sum = 0;

    for(uintV v = start_v; v < end_v; v++){
        local_sum += pr_curr[v];
    }

    MPI_Reduce(&local_sum, &global_sum, 1, PAGERANK_MPI_TYPE, MPI_SUM, 0, MPI_COMM_WORLD);

    std::printf("%d, %ld, %f\n", world_rank, edges_processed, total_communication_time);

    if (world_rank == 0) {
        double total_time_taken = total_timer.stop();

        std::printf("Sum of page rank : " PR_FMT "\n", global_sum);
        std::printf("Time taken (in seconds) : %f\n", total_time_taken);
    }

    if(global_next != nullptr) {
        delete[] global_next;
    } 

    delete[] pr_curr;
    delete[] pr_next;
}

int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);

    int world_rank, world_size;
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    cxxopts::Options options("page_rank_parallel", "Parallel PageRank using MPI");
    options.add_options("", {
                                {"nIterations", "Maximum number of iterations", cxxopts::value<uint>()->default_value(DEFAULT_MAX_ITER)},
                                {"strategy", "Strategy to be used", cxxopts::value<uint>()->default_value(DEFAULT_STRATEGY)},
                                {"inputFile", "Input graph file path", cxxopts::value<std::string>()->default_value("/scratch/input_graphs/roadNet-CA")},
                            });

    auto cl_options = options.parse(argc, argv);
    uint strategy = cl_options["strategy"].as<uint>();
    uint max_iterations = cl_options["nIterations"].as<uint>();
    std::string input_file_path = cl_options["inputFile"].as<std::string>();

    if (world_rank == 0) {
#ifdef USE_INT
        std::printf("Using INT\n");
#else
        std::printf("Using FLOAT\n");
#endif
        std::printf("World size : %d\n", world_size);
        std::printf("Communication strategy : %d\n", strategy);
        std::printf("Iterations : %d\n", max_iterations);
        std::printf("rank, num_edges, communication_time\n");
    }

    Graph g;
    g.readGraphFromBinary<int>(input_file_path);

    pageRankParallel(g, max_iterations, strategy, world_rank, world_size);

    MPI_Finalize();

    return 0;
}