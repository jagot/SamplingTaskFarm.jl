abstract type AbstractSampler{XT,YT} end

process_loaded_samples!(::AbstractSampler) = nothing

function load_samples!(s::AbstractSampler{<:Any,YT}) where YT
    if !isnothing(s.filename) && isfile(s.filename)
        @info "Loading previous calculation from $(s.filename)"
        data = readdlm(s.filename)
        n = size(data, 1)
        done = convert.(Int, data[:,1])
        data = data[:,2:end]
        if n > 0
            nc = size(data, 2)
            expected = YT <: Complex ? 3 : 2
            nc == expected ||
                throw(ArgumentError("Unexpected number of columns in $(s.filename), expected $(expected)"))
            xn = min(length(s.x), n)
            xn == 0 || s.x[done] ≈ data[:,1] ||
                throw(ArgumentError("Data stored in $(s.filename) does not match corresponding entries of x, delete file and try again"))
            xn < n &&
                throw(ArgumentError("More data stored ($(n)) than sampler supports ($(xn))"))

            s.y[done] = (YT <: Complex ?
                (data[:,2] + im*data[:,3]) :
                data[:,2])
            s.done[done] .= true
        end
    end
    process_loaded_samples!(s)
end

function save_samples!(s::AbstractSampler{<:Any,<:Real})
    isnothing(s.filename) && return
    sel = done(s)
    writedlm(s.filename, hcat(done(s), s.x[sel], s.y[sel]))
end

function save_samples!(s::AbstractSampler{<:Any,<:Complex})
    isnothing(s.filename) && return
    sel = done(s)
    y = s.y[sel]
    writedlm(s.filename, hcat(done(s), s.x[sel], real(y), imag(y)))
end

struct StaticSampler{XT<:Real, YT, X<:AbstractVector{XT}, Y<:AbstractVector{YT}, Done, Filename} <: AbstractSampler{XT,YT}
    x::X
    y::Y
    done::Done
    filename::Filename
end

function StaticSampler(::Type{YT}, x::AbstractVector, filename) where YT
    y = Vector{YT}(undef, length(x))
    done = falses(length(x))
    StaticSampler(x, y, done, filename)
end

StaticSampler(::Type{YT}, x::Interval, samples::Integer, filename) where YT =
    StaticSampler(YT, range(x, samples), filename)

Base.length(s::StaticSampler) = length(s.x)
done(s::StaticSampler) = findall(s.done)
not_done(s::StaticSampler) = findall(!, s.done)
isdone(s::StaticSampler) = all(s.done)

function Base.enumerate(s::StaticSampler)
    sel = not_done(s)
    zip(sel, view(s.x, sel))
end

get_sample!(s::StaticSampler, i) = s.x[i]

function Base.setindex!(s::StaticSampler, (x,y), i)
    @assert s.x[i] == x
    s.y[i] = y
    s.done[i] = true
end

function Base.map(f::Function, s::AbstractSampler; plot_fun::Union{Function,Nothing}=nothing)
    load_samples!(s)
    nx = length(s)
    for (i,x) in enumerate(s)
        println("Sample: ", i, "/", nx)
        s[i] = (x,f(x))
        save_samples!(s)
        isnothing(plot_fun) || plot_fun(view(s.x, 1:i), s.y)
    end
    isnothing(plot_fun) || plot_fun(s.x, s.y)
end

export StaticSampler
