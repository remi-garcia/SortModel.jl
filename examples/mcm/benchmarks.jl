using SortModel
using JuMP
using Gurobi

include("$(@__DIR__)/model.jl")


function main()
    all_benchmarks = Vector{Tuple{String, Vector{Int}}}()
    open("$(@__DIR__)/benchmarks.csv", "r") do file
        lines = readlines(file)
        for line in lines[2:end]
            line_data = strip.(split(line, ","))
            push!(all_benchmarks,
                (line_data[1], # name
                parse.(Int, split(line_data[2]))) # coefficients
            )
        end
    end
    sortname = ""

    for i in 1:length(all_benchmarks)
        benchmark_info = all_benchmarks[i]
        println("\n\n\n\n----- Problem $(benchmark_info[1]) -----\n\n")
        C = copy(benchmark_info[2])

        model = Model(Gurobi.Optimizer)
        #set_optimizer_attributes(model, "SolFiles" => "$(@__DIR__)/solutions/$(benchmark_info[1])$(benchmark_naming)")
        # set_optimizer_attributes(model, "SolutionLimit" => 1)
        set_optimizer_attributes(model, "Threads" => 4)
        set_optimizer_attributes(model, "PoolSolutions" => 100)
        #set_optimizer_attributes(model, "CPXPARAM_Threads" => 4)

        #set_silent(model)
        set_time_limit_sec(model, 600)
        set_model!(model, C, verbose=true)

        sortname = "rand1"
        sort!(model)
        optimize!(model)

        open("$(@__DIR__)/newresults_$(sortname).txt", "a") do writefile
            write(writefile, "$(benchmark_info[1]), ")
            if termination_status(model) == MOI.OPTIMAL
                write(writefile, "$(solve_time(model))")
            elseif has_values(model)
                write(writefile, "TO*")
            else
                write(writefile, "TO")
            end
            write(writefile, "\n")
        end
    end

    open("$(@__DIR__)/results.csv", "r") do file
        lines = strip.(readlines(file))
        time_results = Dict{String, String}()
        open("$(@__DIR__)/newresults_$(sortname).txt", "r") do readresultsfile
            resultlines = readlines(readresultsfile)
            for line in resultlines[1:end]
                line_data = strip.(split(line, ","))
                time_results[line_data[1]] = line_data[2]
            end
        end
        open("$(@__DIR__)/newresults.csv", "w") do writefile
            write(writefile, "$(lines[1]), $(sortname)\n")
            for line in lines[2:end]
                write(writefile, "$(line), $(get(time_results, strip(split(line, ",")[1]), ""))\n") #time_results[strip(split(line, ",")[1])]
            end
        end
    end
    mv("$(@__DIR__)/newresults.csv", "$(@__DIR__)/results.csv", force=true)
    rm("$(@__DIR__)/newresults_$(sortname).txt")

    return nothing
end
