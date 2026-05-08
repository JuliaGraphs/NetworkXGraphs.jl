module NetworkXGraphsGraphsMatchingExt

using NetworkXGraphs
using PythonCall: pybuiltins, pyconvert
using Graphs: Graphs
using GraphsMatching: GraphsMatching

const _NX_WEIGHT_KEY = "weight"

_label_for_vertex(g::NetworkXGraphs.AbstractNetworkXGraph, v::Integer) = g.nodes[Int(v)]
_label_for_vertex(::Graphs.AbstractGraph, v::Integer) = Int(v)

function _index_for_label(g::NetworkXGraphs.AbstractNetworkXGraph, label)
    Int(g.node_to_index[label])
end
_index_for_label(::Graphs.AbstractGraph, label) = Int(label)

function _lookup_weight(
    w::Dict{E,U}, ::Type{E}, i::Integer, j::Integer
) where {E<:Graphs.AbstractEdge,U}
    return get(w, E(i, j), get(w, E(j, i), zero(U)))
end

function _matching_weighted_edges(
    g::Graphs.AbstractGraph, w::Dict{E,U}
) where {E<:Graphs.AbstractEdge,U<:Real}
    weighted = Tuple{Any,Any,U}[]
    keep = Set{Tuple{Any,Any}}()
    for (e, weight) in w
        src = Graphs.src(e)
        dst = Graphs.dst(e)
        Graphs.has_edge(g, src, dst) || continue
        ulab = _label_for_vertex(g, src)
        vlab = _label_for_vertex(g, dst)
        push!(weighted, (ulab, vlab, weight))
        push!(keep, (ulab, vlab))
        push!(keep, (vlab, ulab))
    end
    return weighted, keep
end

function _networkx_matching_graph(
    g::NetworkXGraphs.AbstractNetworkXGraph, w::Dict{E,U}
) where {E<:Graphs.AbstractEdge,U<:Real}
    pyg = g.pygraph.copy()
    weighted, keep = _matching_weighted_edges(g, w)
    existing = pyconvert(Vector{Tuple{Any,Any}}, pybuiltins.list(pyg.edges()))
    remove = Tuple{Any,Any}[(u, v) for (u, v) in existing if (u, v) ∉ keep]
    isempty(remove) || pyg.remove_edges_from(remove)
    isempty(weighted) || pyg.add_weighted_edges_from(weighted)
    return pyg
end

function _networkx_matching_graph(
    g::Graphs.AbstractGraph, w::Dict{E,U}
) where {E<:Graphs.AbstractEdge,U<:Real}
    pyg = NetworkXGraphs.networkx_graph(g)
    weighted, keep = _matching_weighted_edges(g, w)
    existing = pyconvert(Vector{Tuple{Any,Any}}, pybuiltins.list(pyg.edges()))
    remove = Tuple{Any,Any}[(u, v) for (u, v) in existing if (u, v) ∉ keep]
    isempty(remove) || pyg.remove_edges_from(remove)
    isempty(weighted) || pyg.add_weighted_edges_from(weighted)
    return pyg
end

function _matching_result(
    g::Graphs.AbstractGraph, w::Dict{E,U}, pyg
) where {E<:Graphs.AbstractEdge,U<:Integer}
    nx = NetworkXGraphs.PythonNetworkX.networkx
    pymatching = nx.algorithms.matching.min_weight_matching(pyg; weight=_NX_WEIGHT_KEY)
    pyconvert(Bool, nx.algorithms.matching.is_perfect_matching(pyg, pymatching)) || throw(
        ErrorException(
            "NetworkX's minimum-weight matching backend did not produce a perfect matching for this graph.",
        ),
    )

    mate = fill(-1, Graphs.nv(g))
    weight = zero(U)
    for (ulab, vlab) in pyconvert(Vector{Tuple{Any,Any}}, pybuiltins.list(pymatching))
        i = _index_for_label(g, ulab)
        j = _index_for_label(g, vlab)
        mate[i] = j
        mate[j] = i
        weight += _lookup_weight(w, E, i, j)
    end
    return GraphsMatching.MatchingResult(weight, mate)
end

function _minimum_weight_perfect_matching(
    g::Graphs.AbstractGraph, w::Dict{E,U}
) where {E<:Graphs.AbstractEdge,U<:Integer}
    Graphs.is_directed(g) && throw(
        ArgumentError(
            "`NXAlgorithm()` only supports undirected graphs for minimum-weight perfect matching.",
        ),
    )
    return _matching_result(g, w, _networkx_matching_graph(g, w))
end

function GraphsMatching.minimum_weight_perfect_matching(
    g::Graphs.AbstractGraph,
    w::Dict{E,U},
    cutoff::Real,
    algorithm::NetworkXGraphs.NXAlgorithm=NetworkXGraphs.NXAlgorithm();
    kws...,
) where {E<:Graphs.AbstractEdge,U<:Real}
    wnew = Dict{E,U}()
    for (e, c) in w
        c <= cutoff || continue
        wnew[e] = c
    end
    return GraphsMatching.minimum_weight_perfect_matching(g, wnew, algorithm; kws...)
end

function GraphsMatching.minimum_weight_perfect_matching(
    g::Graphs.AbstractGraph,
    w::Dict{E,U},
    algorithm::NetworkXGraphs.NXAlgorithm=NetworkXGraphs.NXAlgorithm();
    tmaxscale=10.0,
) where {E<:Graphs.AbstractEdge,U<:AbstractFloat}
    wnew = Dict{E,Int32}()
    cmax = maximum(values(w))
    cmin = minimum(values(w))
    tmax = typemax(Int32) / tmaxscale
    for (e, c) in w
        wnew[e] = round(Int32, (c - cmin) / max(cmax - cmin, 1) * tmax)
    end
    match = GraphsMatching.minimum_weight_perfect_matching(g, wnew, algorithm)
    weight = zero(U)
    for i in 1:Graphs.nv(g)
        j = match.mate[i]
        if j > i
            weight += _lookup_weight(w, E, i, j)
        end
    end
    return GraphsMatching.MatchingResult(weight, match.mate)
end

function GraphsMatching.minimum_weight_perfect_matching(
    g::Graphs.AbstractGraph, w::Dict{E,U}, ::NetworkXGraphs.NXAlgorithm
) where {E<:Graphs.AbstractEdge,U<:Integer}
    return _minimum_weight_perfect_matching(g, w)
end

function GraphsMatching.minimum_weight_perfect_matching(
    g::Graphs.SimpleGraph, w::Dict{E,U}, algorithm::NetworkXGraphs.NXAlgorithm
) where {E<:Graphs.AbstractEdge,U<:Integer}
    return _minimum_weight_perfect_matching(g, w)
end

function GraphsMatching.minimum_weight_perfect_matching(
    g::Graphs.SimpleGraph,
    w::Dict{E,U},
    cutoff::Real,
    algorithm::NetworkXGraphs.NXAlgorithm=NetworkXGraphs.NXAlgorithm();
    kws...,
) where {E<:Graphs.AbstractEdge,U<:Real}
    return GraphsMatching.minimum_weight_perfect_matching(
        g, Dict{E,U}(e => c for (e, c) in w if c <= cutoff), algorithm; kws...
    )
end

function GraphsMatching.minimum_weight_perfect_matching(
    g::Graphs.SimpleGraph,
    w::Dict{E,U},
    algorithm::NetworkXGraphs.NXAlgorithm=NetworkXGraphs.NXAlgorithm();
    tmaxscale=10.0,
) where {E<:Graphs.AbstractEdge,U<:AbstractFloat}
    wnew = Dict{E,Int32}()
    cmax = maximum(values(w))
    cmin = minimum(values(w))
    tmax = typemax(Int32) / tmaxscale
    for (e, c) in w
        wnew[e] = round(Int32, (c - cmin) / max(cmax - cmin, 1) * tmax)
    end
    match = GraphsMatching.minimum_weight_perfect_matching(g, wnew, algorithm)
    weight = zero(U)
    for i in 1:Graphs.nv(g)
        j = match.mate[i]
        if j > i
            weight += _lookup_weight(w, E, i, j)
        end
    end
    return GraphsMatching.MatchingResult(weight, match.mate)
end

end # module
