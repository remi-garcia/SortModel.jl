include("src/SortModel.jl"); using .SortModel; using JuMP

function all_constraints_affexpr(model::Model)
    cstr = Vector{ConstraintRef}()
    for (F, S) in list_of_constraint_types(model)
        if F == AffExpr
            append!(cstr, all_constraints(model, F, S))
        end
    end
    return cstr
end


model = Model();

@variable(model, x, Int)
@variable(model, y >= 0)
@variable(model, z <= 50, Int)
@variable(model, a, Bin)

@constraint(model, x + y <= 20)
@constraint(model, x + 3*z >= 0)
@constraint(model, 12*a + y == 13)
@constraint(model, y <= 25)
write_to_file(model, "model.mps")
write_to_file(model, "model.lp")

println(model)
A = all_constraints_affexpr(model)
for i in 1:length(A)
    println(A[i])
end
println()
sort!(model, integer_variables_first=true, less_variables_first=true, merge_inequalities=true)
write_to_file(model, "modelsorted.mps")
write_to_file(model, "modelsorted.lp")
println(model)
A = all_constraints_affexpr(model)
for i in 1:length(A)
    println(A[i])
end
