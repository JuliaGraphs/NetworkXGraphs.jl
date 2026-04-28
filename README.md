# NetworkX.jl

`NetworkX.jl` is a Julia wrapper around Python's `networkx` built on `PythonCall.jl`.
The current milestone is intentionally narrow: constructors plus the basic `Graphs.jl` API needed to pass `GraphsInterfaceChecker`.

## Features

- Wrap `networkx.Graph`/`networkx.DiGraph` as `Graphs.AbstractGraph`
- Convert between `Graphs.jl` graph types and Python `networkx` objects
- Validate interface conformance with `GraphsInterfaceChecker.jl`
- Stress-test multi-threaded use of independent graphs to catch Python/GIL integration regressions

## Quick start

```julia
using Graphs
using NetworkX

g = path_graph(5)

# Convert Graphs.jl -> Python networkx
pyg = networkx_graph(g)

# Wrap networkx -> Graphs.jl compatible graph
gw = wrap_networkx(pyg)

nv(gw) == nv(g)
```

## Notes

- Python package `networkx` must be available in the Python environment used by `PythonCall.jl`.
- No graph algorithms are implemented in this package at this stage.
