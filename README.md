# SamplingTaskFarm.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://jagot.github.io/SamplingTaskFarm.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jagot.github.io/SamplingTaskFarm.jl/dev)
[![Build Status](https://github.com/jagot/SamplingTaskFarm.jl/workflows/CI/badge.svg)](https://github.com/jagot/SamplingTaskFarm.jl/actions)
[![Coverage](https://codecov.io/gh/jagot/SamplingTaskFarm.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/jagot/SamplingTaskFarm.jl)

## Introduction

SamplingTaskFarm.jl is a simple Julia package that aids in the
computation of a function over an
[interval](https://github.com/JuliaMath/IntervalSets.jl). The interval
can be sampled using different strategies (currently only uniform
sampling is implemented), and the samples can be computed in a serial
fashion, or spread out over a "task farm", i.e. different Julia
instances on the same node that communicate over [TCP
sockets](https://docs.julialang.org/en/v1/manual/networking-and-streams/#A-simple-TCP-example). Finally,
after every finished sample, the results so far are saved to a file,
such that the calculation can be restarted if it is interrupted.

## Example

We create a Julia file with the following contents:

```julia
using SamplingTaskFarm

xs = StaticSampler(Float64, 0.0..1.0, 40, "datafile.txt")

work_fun = x -> begin
    println("Worker got sample: $x")
    sleep(0.5)
    sin(2π*x)
end

# Optional plotting
plot_fun = (x,y) -> begin
    p = sortperm(x)
    # plot(x[p], y[p]) using your favourite plotting package
end

task_farm(work_fun, xs, port=2000, plot_fun=plot_fun)
```

Running this file in a Julia instance will start a server listening on
`localhost:2000`. Running the same file again, in as many new Julia
instances as you wish on the same machine will connect to the server
and ask for tasks until all samples are computed. If you instead wish
to compute the samples in a serial fashion in one Julia process only,
simply replace `task_farm(...)` by

```julia
map(work_fun, xs, plot_fun=plot_fun)
```
