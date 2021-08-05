module SamplingTaskFarm

using IntervalSets
using DelimitedFiles

using Sockets
using Dates
using PrettyTables
using IOUtils

hostname() = strip(String(read(`hostname`)))
const localhost = ip"127.0.0.1"

include("samplers.jl")
include("task_farm.jl")

export ..

end
