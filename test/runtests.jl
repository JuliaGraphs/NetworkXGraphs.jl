using Test
using CondaPkg
using Base.Threads: @threads, nthreads, threadid

CondaPkg.add("networkx")
CondaPkg.resolve()

using Graphs
using GraphsInterfaceChecker
using Interfaces
using NetworkX
using PythonCall

@testset "NetworkX.jl" begin
    nx = pyimport("networkx")

    @testset "Constructors and basic API" begin
        pyg = nx.Graph()
        pyg.add_edges_from([(10, 20), (20, 30), (30, 40)])
        gw = wrap_networkx(pyg)
        @test gw isa NetworkXGraph
        @test !is_directed(gw)
        @test nv(gw) == 4
        @test ne(gw) == 3
        @test collect(vertices(gw)) == [1, 2, 3, 4]
        @test has_vertex(gw, 1)
        @test !has_vertex(gw, 5)
        @test has_edge(gw, 1, 2)
        @test !has_edge(gw, 1, 4)
        @test sort(outneighbors(gw, 2)) == [1, 3]

        pydg = nx.DiGraph()
        pydg.add_edges_from([(1, 2), (2, 3), (4, 2)])
        dgw = wrap_networkx(pydg)
        @test dgw isa NetworkXDiGraph
        @test is_directed(dgw)
        @test nv(dgw) == 4
        @test ne(dgw) == 3
        @test outneighbors(dgw, 2) == [3]
        @test sort(inneighbors(dgw, 2)) == [1, 4]

        # Graphs.jl -> networkx -> wrapper roundtrip on basic structure.
        g = path_graph(5)
        gw2 = wrap_networkx(networkx_graph(g))
        @test nv(gw2) == 5
        @test ne(gw2) == 4
        @test has_edge(gw2, 2, 3)
    end


    @testset "Threaded isolation" begin
        if nthreads() > 1
            results = Vector{Bool}(undef, nthreads())
            @threads for _ in 1:nthreads()
                try
                    nx_local = pyimport("networkx")
                    ok = true
                    for i in 1:50
                        pyg = nx_local.Graph()
                        pyg.add_edges_from([(1, 2), (2, 3), (3, 4), (4, 5), (5, 5 + i)])
                        gw = wrap_networkx(pyg)
                        ok &= nv(gw) == 6
                        ok &= ne(gw) == 5
                        ok &= has_edge(gw, 1, 2)
                        ok &= !is_directed(gw)

                        pydg = nx_local.DiGraph()
                        pydg.add_edges_from([(1, 2), (2, 3), (3, 1)])
                        dgw = wrap_networkx(pydg)
                        ok &= is_directed(dgw)
                        ok &= outneighbors(dgw, 2) == [3]
                        ok &= inneighbors(dgw, 2) == [1]
                    end
                    results[threadid()] = ok
                catch
                    results[threadid()] = false
                end
            end
            @test all(results)
        else
            @test true
        end
    end

    @testset "Interface checker" begin
        ug1 = nx.path_graph(5)
        ug2 = nx.complete_graph(4)
        dg1 = nx.DiGraph()
        dg1.add_edges_from([(1, 2), (2, 3), (3, 4)])
        dg2 = nx.complete_graph(4, create_using=nx.DiGraph())
        test_ugraphs = [wrap_networkx(ug1), wrap_networkx(ug2)]
        test_dgraphs = [wrap_networkx(dg1), wrap_networkx(dg2)]

        @test Interfaces.test(AbstractGraphInterface, NetworkXGraph, test_ugraphs)
        @test Interfaces.test(AbstractGraphInterface, NetworkXDiGraph, test_dgraphs)
    end
end
