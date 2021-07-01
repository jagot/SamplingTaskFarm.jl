function Sockets.connect(fun::Function, args...)
    client = connect(args...)
    res = fun(client)
    close(client)
    res
end

@enum Magic::Int NEW_WORKER NEW_TASK RESULT ALIVE FINISHED

struct Tasker{XT,YT,Sampler<:AbstractSampler{XT,YT},
              Server,ActiveTasks,
              LifeSigns,AliveThreshold,Mutex}
    sampler::Sampler
    server::Server
    active_tasks::ActiveTasks
    life_signs::LifeSigns
    alive_threshold::AliveThreshold
    mutex::Mutex
end

Tasker(sampler::AbstractSampler, server, alive_threshold::Number) =
    Tasker(sampler, server, Int[],
           Vector{typeof(now())}(), alive_threshold,
           Threads.SpinLock())

function Base.show(io::IO, t::Tasker)
    s = t.sampler
    n = length(s)
    write(io, "$(n) ($(count(s.done)) done) samples Tasker listening on ")
    show(io, t.server)
end

function Base.show(io::IO, ::MIME"text/plain", t::Tasker)
    show(io, t)
    println(io)

    tn = now()
    pretty_table(io,
                 hcat(eachindex(t.active_tasks), t.active_tasks,
                      tn .- t.life_signs),
                 header=["Worker id", "Current task", "Alive"],
                 hlines=[1], vlines=[])
    println(io)
end

function serve_tasks!(tasker::Tasker{XT,YT};
                      plot_fun::Union{Function,Nothing}=nothing) where {XT,YT}
    server = tasker.server
    s = tasker.sampler
    load_samples!(s)

    pf = () -> begin
        if !isnothing(plot_fun)
            sel = done(s)
            plot_fun(s.x[sel], s.y[sel])
        end
    end
    pf()

    # At the moment, we run the task server synchronously, i.e. we do
    # not allow any workers in the same Julia process.
    while !isdone(s) || any(!iszero, tasker.active_tasks)
        sock = accept(server)

        magic = read(sock, Magic)
        tasks_left = !isdone(s)
        @info "Got connected" sock magic tasks_left islocked(tasker.mutex)
        if magic == NEW_WORKER
            if tasks_left
                lock(tasker.mutex) do
                    push!(tasker.active_tasks, 0)
                    push!(tasker.life_signs, now())
                end
                worker_id = length(tasker.active_tasks)
                @info "Assigning new worker id #$(worker_id)"
                write(sock, NEW_WORKER, worker_id)
            else
                write(sock, FINISHED)
            end
        elseif magic == NEW_TASK
            worker_id = read(sock, Int)
            if tasks_left
                lock(tasker.mutex) do
                    nd = filter(∉(tasker.active_tasks), not_done(s))
                    if isempty(nd)
                        @warn "Could not find next sample, weird"
                        tasker.active_tasks[worker_id] = 0
                        write(sock, FINISHED)
                    else
                        i = first(nd)
                        tasker.active_tasks[worker_id] = i
                        tasker.life_signs[worker_id] = now()
                        x = get_sample!(s, i)
                        write(sock, NEW_TASK, i, x)
                        @info "Worker #$(worker_id) asks for work, gets it" i x
                    end
                end
            else
                tasker.active_tasks[worker_id] = 0
                write(sock, FINISHED)
                @info "Worker #$(worker_id) asks for work, none left"
            end
        elseif magic == RESULT
            worker_id = read(sock, Int)
            x = read(sock, XT)
            y = read(sock, YT)
            lock(tasker.mutex) do
                i = tasker.active_tasks[worker_id]
                @info "Worker #$(worker_id) tells us the following result" i x y
                s[i] = (x,y)
                tasker.life_signs[worker_id] = now()
                save_samples!(s)
            end
            pf()
        elseif magic == ALIVE
            worker_id = read(sock, Int)
            @info "Worker #$(worker_id) is still alive, nice"
            lock(tasker.mutex) do
                tasker.life_signs[worker_id] = now()
            end
        end
        horizontal_line(color=:red)
        display(tasker)
        horizontal_line()
        horizontal_line(color=:yellow)
    end
    close(server)
end

function task_farm(fun::Function, sampler::AbstractSampler{XT,YT};
                   port=2000,
                   alive_sleep=60, alive_threshold=3alive_sleep,
                   kwargs...) where {XT,YT}
    server = try
        listen(port)
    catch IOError
        nothing
    end

    if !isnothing(server)
        @info "We are the server, yay!"
        tasker = Tasker(sampler, server, alive_threshold)
        serve_tasks!(tasker; kwargs...)
    else
        @info "We are a measly worker"
        worker_id = connect(port) do client
            write(client, NEW_WORKER)
            response = read(client, Magic)
            if response == NEW_WORKER
                read(client, Int)
            elseif response == FINISHED
                @info "There's not even anything to do"
            end
        end

        if !isnothing(worker_id)
            @info "We are measly worker #$(worker_id)"

            @sync begin
                # @async while isopen(client)
                #     lock(mutex) do
                #         write(client, ALIVE, worker_id)
                #     end
                #     sleep(alive_sleep)
                # end

                while true
                    horizontal_line(color=:green)
                    ix = connect(port) do client
                        write(client, NEW_TASK, worker_id)
                        response = read(client, Magic)
                        @info "Requested work" response
                        if response == NEW_TASK
                            read(client, Int), read(client, XT)
                        elseif response == FINISHED
                            @info "We must go home"
                        end
                    end
                    isnothing(ix) && break

                    i,x = ix
                    @info "We are asked to work" i x
                    y = fun(i, x)

                    connect(port) do client
                        write(client, RESULT, worker_id, x, y)
                    end
                end
            end
        end
    end
    horizontal_line(color=:blue)
    @info "We are done"
end

export task_farm
