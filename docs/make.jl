using SamplingTaskFarm
using Documenter

DocMeta.setdocmeta!(SamplingTaskFarm, :DocTestSetup, :(using SamplingTaskFarm); recursive=true)

makedocs(;
    modules=[SamplingTaskFarm],
    authors="Stefanos Carlström <stefanos.carlstrom@gmail.com> and contributors",
    repo="https://github.com/jagot/SamplingTaskFarm.jl/blob/{commit}{path}#{line}",
    sitename="SamplingTaskFarm.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://jagot.github.io/SamplingTaskFarm.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/jagot/SamplingTaskFarm.jl",
)
