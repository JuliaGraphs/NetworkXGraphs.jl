module NetworkXGraphs

import Graphs
using PythonCall: Py, pybuiltins, pyconvert

export AbstractNetworkXGraph,
    NetworkXGraph,
    NetworkXDiGraph,
    NXAlgorithm,
    networkx_graph,
    refresh_index!

include("python_networkx.jl")
include("types.jl")
include("algorithms.jl")
include("graph_api.jl")
include("conversions.jl")

end # module NetworkXGraphs
